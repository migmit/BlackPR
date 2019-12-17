//
//  Updater.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 22..
//  Copyright © 2019. migmit. All rights reserved.
//

import Foundation

class Fetcher {

    static let urlSession = URLSession(configuration: .ephemeral)
    static let nextSuffix = "; rel=\"next\""
    
    static func resolvePending(reviewer: EphemeralUser, pending: EphemeralPending, completionHandler: @escaping (_ prState: PRState) -> Void) {
        print("Resolving PR: \(pending.url)")
        if let url = URL(string: pending.url) {
            var request = URLRequest(url: url)
            request.addValue("token \(reviewer.token)", forHTTPHeaderField: "Authorization")
            urlSession.dataTask(with: request) {(data, response, error) in
                if error == nil {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 404 {
                            completionHandler(.notFound)
                        } else {
                            if let rawData = data,
                                let jsonData = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any],
                                let user = jsonData["user"] as? [String: Any],
                                let author = user["login"] as? String,
                                let number = jsonData["number"] as? Int,
                                let base = jsonData["base"] as? [String: Any],
                                let repo = base["repo"] as? [String: Any],
                                let owner = repo["owner"] as? [String: Any],
                                let ownerName = owner["login"] as? String,
                                let repoName = repo["name"] as? String,
                                let title = jsonData["title"] as? String,
                                let requestedReviewers = jsonData["requested_reviewers"] as? [[String: Any]],
                                let state = jsonData["state"] as? String {
                                let reviewerNames = requestedReviewers.compactMap{$0["login"] as? String}
                                let waiting = state == "open" && reviewerNames.contains(reviewer.name)
                                let httpUrl = jsonData["html_url"] as? String ?? "https://github.com/\(ownerName)/\(repoName)/pull/\(number)"
                                let lastUpdated = (jsonData["updated_at"] as? String).flatMap{ISO8601DateFormatter().date(from: $0)} ?? pending.timestamp
                                if let reviewsUrl = URL(string:"\(pending.url)/reviews") {
                                    var reviewsRequest = URLRequest(url: reviewsUrl)
                                    reviewsRequest.addValue("token \(reviewer.token)", forHTTPHeaderField: "Authorization")
                                    self.urlSession.dataTask(with: reviewsRequest) {(rData, rResponse, rError) in
                                        let reviews: [Review] = {
                                            if let rawRData = rData,
                                                rError == nil,
                                                let jsonRData = try? JSONSerialization.jsonObject(with: rawRData, options: []) as? [[String: Any]] {
                                                return jsonRData.compactMap {reviewJson in
                                                    if let status = reviewJson["state"] as? String,
                                                        let reviewAuthor = reviewJson["user"] as? [String: Any],
                                                        let reviewAuthorName = reviewAuthor["login"] as? String,
                                                        let submittedAt = reviewJson["submitted_at"] as? String,
                                                        let timestamp = ISO8601DateFormatter().date(from: submittedAt) {
                                                        return Review(status: status, reviewer: reviewAuthorName, timestamp: timestamp)
                                                    } else {
                                                        return nil
                                                    }
                                                }
                                            } else {
                                                return []
                                            }
                                        } ()
                                        let reviewsMap: [String: Review] = reviews.reduce([:]) {(accumulator, nextReview) in
                                            if (accumulator[nextReview.reviewer].map{$0.timestamp < nextReview.timestamp}) ?? true {
                                                return accumulator.merging([nextReview.reviewer : nextReview]) {$1}
                                            } else {
                                                return accumulator
                                            }
                                        }
                                        let ephPR = EphemeralPR(
                                            apiUrl: pending.url,
                                            author: author,
                                            httpUrl: httpUrl,
                                            isApproved: reviewsMap.contains{$1.approved},
                                            isRejected: reviewsMap.contains{$1.rejected},
                                            lastUpdated: lastUpdated,
                                            number: number,
                                            owner: ownerName,
                                            repo: repoName,
                                            title: title,
                                            waiting: waiting
                                        )
                                        completionHandler(.found(ephPR))
                                    }.resume()
                                }
                            } else {
                                completionHandler(.otherError)
                            }
                        }
                    }
                }
            }.resume()
        }
    }
    
    static func fetchNotifications(user: EphemeralUser, completionHandler: @escaping (_ pendings: [EphemeralPending]) -> Void) {
        print("Resolving user: \(user.name)")
        let since = user.lastUpdated.map{"&since=\(ISO8601DateFormatter().string(from: $0 - 1))"} ?? ""
        let url = URL(string: "https://api.github.com/notifications?all=true\(since)")!
        fetchNotificationWorker(url: url, token: user.token, acc: [], completionHandler: completionHandler)
    }
    
    static func fetchNotificationWorker(url: URL, token: String, acc: [EphemeralPending],
                                 completionHandler: @escaping (_ pendings: [EphemeralPending]) -> Void
    ) {
        var request = URLRequest(url: url)
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        urlSession.dataTask(with: request) {(data, response, error) in
            if (error != nil) {
                completionHandler(acc)
            } else {
                if let rawData = data,
                    let httpResponse = response as? HTTPURLResponse,
                    let jsonData = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [[String: Any]]{
                    let link = (httpResponse.allHeaderFields["Link"] as? String).flatMap {linksStr in
                        linksStr
                            .components(separatedBy: ", ")
                            .first(where: {$0.hasSuffix(self.nextSuffix)})?
                            .dropLast(self.nextSuffix.count)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                    }
                    let newAcc: [EphemeralPending] = jsonData.compactMap {(notification) in
                        if let reason = notification["reason"] as? String,
                            reason == "review_requested",
                            let updatedAt = notification["updated_at"] as? String,
                            let timestamp = ISO8601DateFormatter().date(from: updatedAt),
                            let subject = notification["subject"] as? [String: Any],
                            let subjectType = subject["type"] as? String,
                            subjectType == "PullRequest",
                            let url = subject["url"] as? String {
                            return EphemeralPending(url: url, timestamp: timestamp)
                        } else {
                            return nil
                        }
                    }
                    if let next = link,
                        let nextUrl = URL(string: next){
                        self.fetchNotificationWorker(url: nextUrl, token: token, acc: acc + newAcc, completionHandler: completionHandler)
                    } else {
                        completionHandler(acc + newAcc)
                    }
                } else {
                    completionHandler(acc)
                }
            }
        }.resume()
    }
    
}

class Review {
    let approved: Bool
    let rejected: Bool
    let reviewer: String
    let timestamp: Date
    
    init(status: String, reviewer: String, timestamp: Date) {
        approved = status == "APPROVED"
        rejected = status == "CHANGES_REQUESTED"
        self.reviewer = reviewer
        self.timestamp = timestamp
    }
}
