//
//  Updater.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 24..
//  Copyright © 2019. migmit. All rights reserved.
//

import CoreData

class Updater {
    
    func savePendings(context: NSManagedObjectContext, user: User, pendings: [EphemeralPending], status: FetchStatus) {
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
            let pendingRequest: NSFetchRequest<PendingPR> = PendingPR.fetchRequest()
            pendingRequest.predicate = NSPredicate(format: "apiUrl IN %@ AND reviewer == %@", newUrls.map{$0.url}, user)
            let pendingPRs = try context.fetch(pendingRequest)
            do {
                newUrls.forEach {newUrl in
                    if let existing = pendingPRs.first(where: {pending in
                        pending.apiUrl.flatMap{$0 == newUrl.url} ?? false
                    }) {
                        if (existing.timestamp.map{$0 < newUrl.timestamp} ?? true) {
                            existing.timestamp = newUrl.timestamp
                        }
                    } else {
                        let newPending = PendingPR(context: context)
                        newPending.apiUrl = newUrl.url
                        newPending.timestamp = newUrl.timestamp
                        newPending.reviewer = user
                    }
                }
                if let maxTime = pendings.map({$0.timestamp}).max() {
                    user.lastUpdated = user.lastUpdated.map{max($0 + 1, maxTime)} ?? maxTime
                }
                try context.save()
            } catch {}
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
        }
    }

    func savePR(context: NSManagedObjectContext, user: User, ephemeralPR: EphemeralPR?) -> (PR, EphemeralPR?)? {
        if let ephPR = ephemeralPR {
            do {
                let prPair: (PR, EphemeralPR?) = try {
                    let existingRequest: NSFetchRequest<PR> = PR.fetchRequest()
                    existingRequest.predicate = NSPredicate(format: "apiUrl == %@ AND requested == %@", ephPR.apiUrl, user)
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
                        newPR.apiUrl = ephPR.apiUrl
                        newPR.seqId = maxSeqId + 1
                        newPR.requested = user
                        return (newPR, nil)
                    }
                }()
                let pr = prPair.0
                pr.author = ephPR.author
                pr.httpUrl = ephPR.httpUrl
                pr.isApproved = ephPR.isApproved
                pr.isRejected = ephPR.isRejected
                pr.lastUpdated = ephPR.lastUpdated ?? Date()
                pr.number = Int32(ephPR.number)
                pr.owner = ephPR.owner
                pr.repo = ephPR.repo
                pr.title = ephPR.title
                pr.waiting = ephPR.waiting
                try context.save()
                return prPair
            } catch {
                return nil
            }
        }
        return nil
    }
}
