//
//  UserListController.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 19..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa
import CoreData

class UserListController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, AuthCodeDelegate {
    
    let headerCellId = NSUserInterfaceItemIdentifier("HeaderCell")
    let dataCellId = NSUserInterfaceItemIdentifier("DataCell")
    
    @IBOutlet weak var UserList: NSOutlineView!
    
    var context: NSManagedObjectContext?
    
    var users: [User] = []
    
    var addingUserDisabled: Bool = false
    
    override func viewWillAppear() {
        if context != nil { return }
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        context = appDelegate.persistentContainer.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "seqId", ascending: true)]
        do {
            users = try context!.fetch(request)
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
        }
        DispatchQueue.main.async {
            self.UserList.registerForDraggedTypes([UserDrag.pasteboardType])
            self.UserList.reloadItem(nil, reloadChildren: true)
            self.UserList.expandItem(nil, expandChildren: true)
            if (!self.users.isEmpty) {
                let firstUserRow = self.UserList.row(forItem: self.users[0])
                self.UserList.selectRowIndexes(IndexSet(integer: firstUserRow), byExtendingSelection: false)
            }
        }
        if (users.isEmpty) {
            addingUserDisabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.addingUserDisabled = false
                self.addUser()
            }
        }
        (parent as? MainViewController)?.collapseSidebar(doCollapse: users.count == 1)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshAppBadge()
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PRSaved"), object: nil, queue: OperationQueue.current) {notif in
            guard let prId = notif.userInfo?["prId"] as? NSManagedObjectID else {return}
            guard let pr = try? self.context?.existingObject(with: prId) as? PR else {return}
            let oldPR = notif.userInfo?["oldPR"] as? EphemeralPR
            if oldPR.map({$0.waiting != pr.waiting}) ?? true {
                self.refreshAppBadge()
            }
            return
        }
    }
    
    func refreshAppBadge() {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        let cntContext = appDelegate.persistentContainer.viewContext
        let cntRequest: NSFetchRequest<NSFetchRequestResult> = PR.fetchRequest()
        cntRequest.resultType = .dictionaryResultType
        cntRequest.predicate = NSPredicate(format: "waiting == true")
        let cntExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "seqId")])
        let cntKey = "cntSeq"
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = cntKey
        expressionDescription.expression = cntExpression
        expressionDescription.expressionResultType = .integer32AttributeType
        cntRequest.propertiesToFetch = [expressionDescription]
        let count: Int32 = {
            if let result = try? cntContext.fetch(cntRequest) as? [[String: Int32]],
                let dict = result.first {
                return dict[cntKey] ?? 0
            } else {
                return 0
            }
        }()
        let dockTile = NSApplication.shared.dockTile
        dockTile.badgeLabel = count > 0 ? String(count) : nil
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let sheet = segue.destinationController as? SheetController {
            sheet.delegate = self
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return 1
        } else if item is UsersSection {
            return users.count
        } else {
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return UsersSection.instance
        } else {
            return users[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is UsersSection
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor: NSTableColumn?, item: Any) -> NSView? {
        if item is UsersSection {
            return outlineView.makeView(withIdentifier: headerCellId, owner: self) as? NSTableCellView
        } else if let user = item as? User {
            let cell = outlineView.makeView(withIdentifier: dataCellId, owner: self) as? NSTableCellView
            cell?.textField?.stringValue = user.name ?? "Unknown"
            return cell
        } else {
            return nil
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item as? User != nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        if let user = item as? User {
            return UserDrag(user: user)
        } else {
            return nil
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if item is UsersSection && index != NSOutlineViewDropOnItemIndex {
            return .move
        } else {
            return []
        }
    }
    
    func moveUser(fromIdx: Int, toIdx: Int) {
        let from = fromIdx < 0 ? 0 : fromIdx >= users.count ? users.count - 1 : fromIdx
        let to = toIdx < 0 ? 0 : toIdx >= users.count ? users.count - 1 : toIdx
        let user = users[from]
        let lastSeqId = users[to].seqId
        if (to >= from) {
            for i in from..<to { users[i+1].seqId = users[i].seqId }
        } else {
            for i in to..<from { users[i].seqId = users[i+1].seqId }
        }
        user.seqId = lastSeqId
        users.remove(at: from)
        users.insert(user, at: to)
        do {
            try context!.save()
        } catch let error as NSError {
            print("CoreData error: \(error), \(error.userInfo)")
        }
        UserList.moveItem(at: from, inParent: UsersSection.instance, to: to, inParent: UsersSection.instance)
        let row = UserList.row(forItem: user)
        if (row >= 0) {
            UserList.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            UserList.deselectAll(nil)
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        if item is UsersSection && index != NSOutlineViewDropOnItemIndex {
            if let userDrags = info.draggingPasteboard.readObjects(forClasses: [UserDrag.self], options: nil),
                userDrags.count == 1,
                let userDrag = userDrags[0] as? UserDrag,
                let seqId = userDrag.seqId,
                let originalUserIndex = users.firstIndex(where: {$0.seqId == seqId}) {
                moveUser(fromIdx: originalUserIndex, toIdx: index > originalUserIndex ? index-1 : index)
                return true
            }
        }
        return false
    }
    
    func displayPRs() {
        if let user = UserList.item(atRow: UserList.selectedRow) as? User {
            NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil, userInfo: ["user": user])
        }
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        displayPRs()
    }
    
    @IBAction func addButtonClick(_ sender: NSButton) {
        addUser()
    }
    
    @IBAction func removeButtonClick(_ sender: NSButton) {
        let row = UserList.row(for: sender)
        if let user = UserList.item(atRow: row) as? User {
            let confirmation = NSAlert()
            confirmation.alertStyle = .warning
            confirmation.messageText = "Delete account"
            confirmation.informativeText = "Do you want to remove \(user.name ?? "Unknown")"
            confirmation.addButton(withTitle: "Yes")
            confirmation.addButton(withTitle: "No")
            confirmation.beginSheetModal(for: view.window!) {answer in
                if answer == .alertFirstButtonReturn {
                    DispatchQueue.main.async {
                        self.removeUser(row: row, user: user)
                    }
                }
            }
        }
    }
    
    func removeUser(row: Int, user: User) {
        context!.delete(user)
        do {
            try context!.save()
            let index = users.firstIndex(of: user)
            if let i = index {
                users.remove(at: i)
            }
            let listIndex = UserList.childIndex(forItem: user)
            if (listIndex >= 0) {
                UserList.removeItems(at: IndexSet(integer: listIndex), inParent: UsersSection.instance, withAnimation: [])
            }
            let idx = index ?? 0
            let nextUser = idx < users.count ? users[idx] : idx > 0 ? users[idx - 1] : nil
            let row = UserList.row(forItem: nextUser)
            if (row >= 0) {
                UserList.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            } else {
                UserList.deselectAll(nil)
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error saving data"
            alert.informativeText = "Could not remove the user \(user.name ?? "Unknown") to the database"
            alert.beginSheetModal(for: view.window!) {_ in ()}
        }
    }
    
    func addUser() {
        if (!addingUserDisabled) {
            performSegue(withIdentifier: "AddUserSegue", sender: nil)
        }
    }
    
    func userAdded(name: String, token: String) {
        if let existing = users.first(where: {$0.name == name}) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Duplicate user"
            alert.informativeText = "User \(name) already exists"
            alert.beginSheetModal(for: view.window!) {_ in
                let row = self.UserList.row(forItem: existing)
                if (row >= 0) {
                    self.UserList.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                }
            }
        } else {
            let newUser = User(context: context!)
            newUser.name = name
            newUser.token = token
            newUser.seqId = (users.map{$0.seqId}.max() ?? 0) + 1
            do {
                try context!.save()
                let newIndexSet = IndexSet(integer: UserList.numberOfChildren(ofItem: UsersSection.instance))
                users.append(newUser)
                UserList.insertItems(at: newIndexSet, inParent: UsersSection.instance, withAnimation: [])
                let row = UserList.row(forItem: newUser)
                if (row >= 0) {
                    UserList.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                } else {
                    UserList.deselectAll(nil)
                }
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Error saving data"
                alert.informativeText = "Could not save the user \(name) to the database"
                alert.beginSheetModal(for: view.window!) {_ in ()}
            }
        }
    }
    
    func accessTokenReceived(token: String) {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) {(data, response, error) in
            if error == nil {
                if let rawData = data,
                    let jsonData = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [String:Any],
                    let name = jsonData["login"] as? String {
                    DispatchQueue.main.async { self.userAdded(name: name, token: token) }
                }
                return
            }
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Invalid token"
                alert.informativeText = "Couldn't get the login name from GitHub"
                alert.beginSheetModal(for: self.view.window!) {_ in ()}
            }
        }.resume()
    }
}
