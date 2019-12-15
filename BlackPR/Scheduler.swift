//
//  Scheduler.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 24..
//  Copyright © 2019. migmit. All rights reserved.
//

import CoreData

class Scheduler {
    
    let context: NSManagedObjectContext
    let queue: OperationQueue
    
    var users: [NSManagedObjectID] = []
    var pendings: [Queued] = []
    var updateUsers = true
    
    let fetcher = Fetcher()
    let updater = Updater()
    
    static func updateUser(context: NSManagedObjectContext?, userId: NSManagedObjectID) {
        NotificationCenter.default.post(
            name: NSNotification.Name("updateUser"),
            object: nil,
            userInfo: Dictionary(flatten: ["userId": userId, "context": context]))
    }
    
    static func updatePR(context: NSManagedObjectContext?, userId: NSManagedObjectID, pending: EphemeralPending, pendingId: NSManagedObjectID?) {
        NotificationCenter.default.post(
            name: NSNotification.Name("updatePR"),
            object: nil,
            userInfo: Dictionary(flatten: ["userId": userId, "pending": pending, "pendingId": pendingId, "context": context])
        )
    }
    
    static func finalizeTransaction(transaction: NSManagedObjectContext, continuationHandler: @escaping () -> Void) {
        do {
            try transaction.save()
            if let parent = transaction.parent {
                parent.perform {
                    try? parent.save()
                    continuationHandler()
                }
            } else {
                continuationHandler()
            }
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
        }
    }
    
    init(context: NSManagedObjectContext, prSavedHandler: @escaping (NSManagedObjectID, EphemeralPR?) -> Void) {
        self.context = context
        queue = OperationQueue()
        queue.name = "Scheduler queue"
        queue.maxConcurrentOperationCount = 1
        NotificationCenter.default.addObserver(forName: NSNotification.Name("updateUser"), object: nil, queue: queue) {notif in
            guard let userId = notif.userInfo?["userId"] as? NSManagedObjectID else {return}
            let transaction = notif.userInfo?["context"] as? NSManagedObjectContext ?? {
                let t = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                t.parent = context
                return t
            }()
            transaction.perform {
                if let user = try? transaction.existingObject(with: userId) as? User,
                    !user.isFault,
                    let userName = user.name,
                    let token = user.token {
                    self.fetcher.fetchNotifications(
                        user: EphemeralUser(name: userName, token: token, lastUpdated: user.lastUpdated)
                    ) {eprs in
                        print("SAVE PENDINGS: \(eprs.map{$0.url})")
                        transaction.perform {
                            let newPendings = self.updater.savePendings(context: transaction, user: user, pendings: eprs)
                            do {
                                try transaction.obtainPermanentIDs(for: newPendings.map{$0.0})
                                newPendings.prefix(3).forEach{
                                    Scheduler.updatePR(context: nil, userId: userId, pending: $0.1, pendingId: $0.0.objectID)
                                }
                            } catch let error as NSError {
                                print("CoreData error: \(error), \(error.userInfo)")
                            }
                            Scheduler.finalizeTransaction(transaction: transaction){}
                        }
                    }
                }
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("updatePR"), object: nil, queue: queue) {notif in
            guard let userId = notif.userInfo?["userId"] as? NSManagedObjectID else {return}
            guard let pending = notif.userInfo?["pending"] as? EphemeralPending else {return}
            let transaction = notif.userInfo?["context"] as? NSManagedObjectContext ?? {
                let t = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                t.parent = context
                return t
            }()
            transaction.perform {
                if let user = try? transaction.existingObject(with: userId) as? User,
                    !user.isFault,
                    let userName = user.name,
                    let token = user.token {
                    self.fetcher.resolvePending(
                        reviewer: EphemeralUser(name: userName, token: token, lastUpdated: user.lastUpdated),
                        pending: pending
                    ) {prState in
                        transaction.perform {
                            if let pendingId = notif.userInfo?["pendingId"] as? NSManagedObjectID,
                                let pending = try? transaction.existingObject(with: pendingId) {
                                transaction.delete(pending)
                            }
                            let prPair: (PR, EphemeralPR?)? = {
                                switch(prState) {
                                case .found(let epr):
                                    print("SAVE PR: \(epr.apiUrl)")
                                    return self.updater.savePR(context: transaction, user: user, ephemeralPR: epr)
                                case .notFound:
                                    print("PR \(pending.url) NOT FOUND, MARKING DORMANT")
                                    return self.updater.markDormant(context: transaction, user: user, apiUrl: pending.url)
                                case .otherError:
                                    print("ERROR WHILE FETCHING PR \(pending.url) ")
                                    return nil
                                }
                            }()
                            prPair.map{try? transaction.obtainPermanentIDs(for: [$0.0])}
                            Scheduler.finalizeTransaction(transaction: transaction) {
                                prPair.map{prSavedHandler($0.0.objectID, $0.1)}
                            }
                        }
                    }
                }
            }
        }
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {_ in
            let transaction = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            transaction.parent = self.context
            if (self.updateUsers) {
                if (self.users.isEmpty) {
                    self.fetchUsers(context: transaction)
                }
                if let userId = self.users.popLast() {
                    Scheduler.updateUser(context: transaction, userId: userId)
                }
            } else {
                if (self.pendings.isEmpty) {
                    self.fetchPendings(context: transaction)
                }
                if let queued = self.pendings.popLast() {
                    Scheduler.updatePR(context: transaction, userId: queued.userId, pending: queued.pending, pendingId: queued.pendingId)
                }
            }
            self.updateUsers = !self.updateUsers
        }
    }
    
    func fetchUsers(context: NSManagedObjectContext) {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "seqId", ascending: false)]
        do {
            let userObjs = try context.fetch(request)
            users = userObjs.map{$0.objectID}
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
        }
    }
    
    func fetchPendings(context: NSManagedObjectContext) {
        let request: NSFetchRequest<PendingPR> = PendingPR.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        let now = Date()
        do {
            let pendingObjs = try context.fetch(request)
            pendings = pendingObjs.compactMap{obj in
                if let userId = obj.reviewer?.objectID,
                    let url = obj.apiUrl,
                    let timestamp = obj.timestamp {
                    return Queued(userId: userId, pendingId: obj.objectID, pending: EphemeralPending(url: url, timestamp: timestamp))
                } else {
                    return nil
                }
            }
            let prRequest: NSFetchRequest<PR> = PR.fetchRequest()
            prRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: true)]
            prRequest.predicate = NSPredicate(format: "waiting == true AND NOT (apiUrl IN %@)", pendings.map{$0.pending.url})
            do {
                let prs = try context.fetch(prRequest)
                prs.forEach{
                    if let user = $0.requested,
                        let url = $0.apiUrl {
                        pendings.append(Queued(userId: user.objectID, pendingId: nil, pending: EphemeralPending(url: url, timestamp: now)))
                    }
                }
            }
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
        }
    }
}

class Queued {
    
    let userId: NSManagedObjectID
    let pendingId: NSManagedObjectID?
    let pending: EphemeralPending
    
    init(userId: NSManagedObjectID, pendingId: NSManagedObjectID?, pending: EphemeralPending) {
        self.userId = userId
        self.pendingId = pendingId
        self.pending = pending
    }
}
