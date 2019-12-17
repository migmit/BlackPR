//
//  Updater.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 24..
//  Copyright © 2019. migmit. All rights reserved.
//

import CoreData

class Updater {
    
    static func savePendings(context: NSManagedObjectContext, user: User, pendings: [EphemeralPending]) -> [(PendingPR, EphemeralPending)] {
        let prRequest: NSFetchRequest<PR> = PR.fetchRequest()
        prRequest.predicate = NSPredicate(format: "apiUrl IN %@ AND requested == %@", pendings.map{$0.url}, user)
        do {
            let prs = try context.fetch(prRequest)
            let newUrls = pendings.filter {prUrl in
                prs.first(where: {pr in
                    let sameUrl = pr.apiUrl.flatMap{$0 == prUrl.url} ?? false
                    let alreadyUpdated = pr.lastUpdated.map{$0 >= prUrl.timestamp} ?? false
                    return sameUrl && alreadyUpdated
                }) == nil
            }
            let newPendings: [(PendingPR, EphemeralPending)] = newUrls.map {newUrl in
                let newPending = PendingPR(context: context)
                newPending.apiUrl = newUrl.url
                newPending.timestamp = newUrl.timestamp
                newPending.reviewer = user
                return (newPending, newUrl)
            }
            if let maxTime = pendings.map({$0.timestamp}).max() {
                user.lastUpdated = user.lastUpdated.map{max($0 + 1, maxTime)} ?? maxTime
            }
            return newPendings
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
            return []
        }
    }

    static func savePR(context: NSManagedObjectContext, user: User, ephemeralPR: EphemeralPR) -> (PR, EphemeralPR?)? {
        do {
            let prPair: (PR, EphemeralPR?) = try {
                let existingRequest: NSFetchRequest<PR> = PR.fetchRequest()
                existingRequest.predicate = NSPredicate(format: "apiUrl == %@ AND requested == %@", ephemeralPR.apiUrl, user)
                let existingPRs = try context.fetch(existingRequest)
                if (existingPRs.count > 0) {
                    let existingPR = existingPRs[0]
                    existingPRs.dropFirst().forEach{context.delete($0)}
                    if let apiUrl = existingPR.apiUrl,
                        let author = existingPR.author,
                        let httpUrl = existingPR.httpUrl,
                        let lastUpdated = existingPR.lastUpdated,
                        let owner = existingPR.owner,
                        let repo = existingPR.repo,
                        let title = existingPR.title {
                        return (existingPR, EphemeralPR(apiUrl: apiUrl, author: author, httpUrl: httpUrl, isApproved: existingPR.isApproved, isRejected: existingPR.isRejected, lastUpdated: lastUpdated, number: Int(existingPR.number), owner: owner, repo: repo, title: title, waiting: existingPR.waiting))
                        } else {
                            return (existingPR, nil)
                        }
                } else {
                    let seqRequest: NSFetchRequest<NSFetchRequestResult> = PR.fetchRequest()
                    seqRequest.resultType = .dictionaryResultType
                    seqRequest.predicate = NSPredicate(format: "requested == %@", user)
                    let maxExpression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "seqId")])
                    let maxKey = "maxSeq"
                    let expressionDescription = NSExpressionDescription()
                    expressionDescription.name = maxKey
                    expressionDescription.expression = maxExpression
                    expressionDescription.expressionResultType = .integer32AttributeType
                    seqRequest.propertiesToFetch = [expressionDescription]
                    let maxSeqId: Int32 = {
                        if let result = try? context.fetch(seqRequest) as? [[String: Int32]],
                            let dict = result.first {
                            return dict[maxKey] ?? 0
                        } else {
                            return 0
                        }
                    }()
                    let newPR = PR(context: context)
                    newPR.apiUrl = ephemeralPR.apiUrl
                    newPR.seqId = maxSeqId + 1
                    newPR.requested = user
                    return (newPR, nil)
                }
            }()
            let pr = prPair.0
            pr.author = ephemeralPR.author
            pr.httpUrl = ephemeralPR.httpUrl
            pr.isApproved = ephemeralPR.isApproved
            pr.isRejected = ephemeralPR.isRejected
            pr.lastUpdated = ephemeralPR.lastUpdated ?? Date()
            pr.number = Int32(ephemeralPR.number)
            pr.owner = ephemeralPR.owner
            pr.repo = ephemeralPR.repo
            pr.title = ephemeralPR.title
            pr.waiting = ephemeralPR.waiting
            return prPair
        } catch {
            return nil
        }
    }
    
    static func markDormant(context: NSManagedObjectContext, user: User, apiUrl: String) -> (PR, EphemeralPR)? {
        let existingRequest: NSFetchRequest<PR> = PR.fetchRequest()
        existingRequest.predicate = NSPredicate(format: "apiUrl == %@ AND requested == %@", apiUrl, user)
        guard let existingPRs = try? context.fetch(existingRequest) else { return nil }
        if (existingPRs.count > 0) {
            let existingPR = existingPRs[0]
            existingPRs.dropFirst().forEach{context.delete($0)}
            let waiting = existingPR.waiting
            existingPR.waiting = false
            if let apiUrl = existingPR.apiUrl,
                let author = existingPR.author,
                let httpUrl = existingPR.httpUrl,
                let lastUpdated = existingPR.lastUpdated,
                let owner = existingPR.owner,
                let repo = existingPR.repo,
                let title = existingPR.title {
                return (existingPR, EphemeralPR(apiUrl: apiUrl, author: author, httpUrl: httpUrl, isApproved: existingPR.isApproved, isRejected: existingPR.isRejected, lastUpdated: lastUpdated, number: Int(existingPR.number), owner: owner, repo: repo, title: title, waiting: waiting))
                } else {
                    return nil
                }
        } else {
            return nil
        }
    }
}
