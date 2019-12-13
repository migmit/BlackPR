//
//  PullRequestListController.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 20..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa
import UserNotifications

class PullRequestListController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, UNUserNotificationCenterDelegate {
    
    let prCellId = NSUserInterfaceItemIdentifier("PRCell")
    let showCellId = NSUserInterfaceItemIdentifier("ShowCell")

    @IBOutlet weak var PRList: NSTableView!
    @IBOutlet weak var collapseButton: NSButton!
    
    var context: NSManagedObjectContext?
    var unCenter: UNUserNotificationCenter?

    var user: User?
    
    var waitingPRs: [PR] = []
    var dormantPRs: [PR] = []
    
    var showDormant = false

    override func viewDidLoad() {
        super.viewDidLoad()
        unCenter = UNUserNotificationCenter.current()
        unCenter?.requestAuthorization(options: [.alert, .badge, .sound]){_,_  in}
        unCenter?.delegate = self
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PRSaved"), object: nil, queue: OperationQueue.current) {notif in
            guard let prId = notif.userInfo?["prId"] as? NSManagedObjectID else {return}
            guard let pr = try? self.context?.existingObject(with: prId) as? PR else {return}
            let oldPR = notif.userInfo?["oldPR"] as? EphemeralPR
            if (pr.waiting && (oldPR.map{!$0.waiting} ?? true)) {
                self.notifyUser(pr: pr)
            }
            if (pr.requested == self.user) {
                if let old = oldPR {
                    if (pr.waiting && !old.waiting) {
                        self.makePRWaiting(pr: pr)
                    }
                    if (!pr.waiting && old.waiting) {
                        self.makePRDormant(pr: pr)
                    }
                } else {
                    self.insertPR(pr: pr)
                }
            }
            return
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("UserChanged"), object: nil, queue: nil){notif in
            guard let user = notif.userInfo?["user"] as? User else {return}
            self.displayPRs(user: user)
        }
    }
    
    override func viewWillAppear() {
        if context != nil { return }
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        context = appDelegate.persistentContainer.viewContext
    }
    
    func notifyUser(pr: PR) {
        let content = UNMutableNotificationContent()
        content.title = "\(pr.author ?? "Someone") requested your review on #\(pr.number) in \(pr.repo ?? "some repository")"
        content.body = pr.title ?? "No title"
        content.categoryIdentifier = "newPR"
        content.sound = .default
        content.userInfo = pr.httpUrl.map{["httpUrl": $0]} ?? [:]
        unCenter?.add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.001, repeats: false)
        )){_ in}
    }
        
    func insertPR(pr: PR) {
        if (pr.waiting) {
            waitingPRs.insert(pr, at: 0)
        } else {
            dormantPRs.insert(pr, at: 0)
        }
        if (showDormant || pr.waiting) {
            PRList.insertRows(at: IndexSet(integer: pr.waiting ? 0 : (waitingPRs.count + 1)), withAnimation: [.slideDown])
        }
    }
    
    func makePRWaiting(pr: PR) {
        guard let oldIndex = dormantPRs.firstIndex(of: pr) else {return}
        dormantPRs.remove(at: oldIndex)
        waitingPRs.insert(pr, at: 0)
        if (showDormant) {
            PRList.moveRow(at: oldIndex + waitingPRs.count, to: 0)
        } else {
            PRList.insertRows(at: IndexSet(integer: 0), withAnimation: .slideDown)
        }
        PRList.reloadData(forRowIndexes: IndexSet(integer: 0), columnIndexes: IndexSet(integer: 0))
    }
    
    func makePRDormant(pr: PR) {
        guard let oldIndex = waitingPRs.firstIndex(of: pr) else {return}
        waitingPRs.remove(at: oldIndex)
        dormantPRs.insert(pr, at: 0)
        if (showDormant) {
            PRList.moveRow(at: oldIndex, to: waitingPRs.count + 1)
            PRList.reloadData(forRowIndexes: IndexSet(integer: waitingPRs.count + 1), columnIndexes: IndexSet(integer: 0))
        } else {
            PRList.removeRows(at: IndexSet(integer: oldIndex), withAnimation: .slideUp)
        }
    }
    
    func displayPRs(user: User) {
        self.user = user
        waitingPRs = []
        dormantPRs = []
        (user.requests?.array as? [PR] ?? []).sorted(by: {
            if let f = $0.lastUpdated,
                let s = $1.lastUpdated {
                return f > s
            } else {
                return false
            }
        }).forEach{pr in
            if (pr.waiting) {
                waitingPRs.append(pr)
            } else {
                dormantPRs.append(pr)
            }
        }
        view.window?.title = user.name ?? "BlackPR"
        PRList.reloadData()
    }
    
    func createImageRect(bounds: CGSize, size: CGSize) -> CGRect {
        let hgt = bounds.height - 4
        let wdt = bounds.width - 4
        if (size.width * hgt < size.height * wdt) {
            let scaledWidth = size.width * hgt / size.height
            return CGRect(
                origin: CGPoint(x: (bounds.width - scaledWidth) / 2, y: 2),
                size: CGSize(width: scaledWidth, height: hgt)
            )
        } else {
            let scaledHeight = size.height * wdt / size.width
            return CGRect(
                origin: CGPoint(x: 2, y: (bounds.height - scaledHeight) / 2),
                size: CGSize(width: wdt, height: scaledHeight)
            )
        }
    }
    
    func redrawCollapseButton(collapsed: Bool) {
        if let image = NSImage(named: collapsed ? "NSRightFacingTriangleTemplate" : "NSLeftFacingTriangleTemplate") { // Alternative: NSEveryone
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {return}
            let size = collapseButton.bounds.size
            let bgImage = NSImage(size: size, flipped: false){bounds in
                let imageBounds = self.createImageRect(bounds: bounds.size, size: image.size)
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                NSColor.controlBackgroundColor.setFill()
                context.fill(bounds)
                context.setLineWidth(2)
                NSColor.controlTextColor.setStroke()
                context.stroke(bounds)
                NSColor.controlTextColor.set()
                context.clip(to: imageBounds, mask: cgImage)
                context.fill(bounds)
                return true
            }
            collapseButton.image = bgImage
        }
    }
    
    func collapseSidebar() {
        (parent as? MainViewController)?.collapseSidebar(doCollapse: true)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return lastRow() + 1
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return getPR(index: row)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if row == waitingPRs.count {
            let cell = tableView.makeView(withIdentifier: showCellId, owner: self) as? ShowDormantCellView
            cell?.showDormant.title = showDormant ? "Hide dormant requests" : "Show dormant requests"
            return cell
        }
        guard let pr = getPR(index: row) else { return nil }
        let cell = tableView.makeView(withIdentifier: prCellId, owner: self) as? PRCellView
        cell?.title.stringValue = pr.title ?? "No title"
        cell?.details.attributedStringValue =
            NSAttributedString(string: "\(pr.owner ?? "?")/\(pr.repo ?? "?")#\(pr.number) by ", attributes: [NSAttributedString.Key.font : NSFont.systemFont(ofSize: NSFont.systemFontSize)]) +
                NSAttributedString(string: pr.author ?? "?", attributes: [NSAttributedString.Key.font : NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)])
        cell?.pr = pr
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if let pr = getPR(index: row),
            let httpUrl = pr.httpUrl,
            let url = URL(string: httpUrl) {
            NSWorkspace.shared.open(url)
        }
        return false
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return row == waitingPRs.count ? 37 : 50
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let httpUrl = response.notification.request.content.userInfo["httpUrl"] as? String,
            let url = URL(string: httpUrl),
            response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            (NSApplication.shared.delegate as? AppDelegate)?.delayedUrls.append(url)
        }
        completionHandler()
    }
    
    @IBAction func collapseButtonClick(_ sender: NSButton) {
        collapseSidebar()
    }
    
    @IBAction func refreshMenu(_ sender: NSMenuItem) {
        let index = PRList.clickedRow
        if let pr = getPR(index: index),
            let ctx = context,
            let usr = user,
            let url = pr.apiUrl {
            Scheduler.updatePR(context: ctx, userId: usr.objectID, pending: EphemeralPending(url: url, timestamp: Date()), pendingId: nil)
        }
    }
    
    @IBAction func showDormantClick(_ sender: NSButton) {
        if (showDormant) {
            showDormant = false
            if (dormantPRs.count > 0) {
                PRList.removeRows(at: IndexSet(integersIn: (waitingPRs.count + 1)...prCount()), withAnimation: .slideUp)
            }
        } else {
            showDormant = true
            if (dormantPRs.count > 0) {
                PRList.insertRows(at: IndexSet(integersIn: (waitingPRs.count + 1)...prCount()), withAnimation: .slideDown)
            }
        }
        PRList.reloadData(forRowIndexes: IndexSet(integer: waitingPRs.count), columnIndexes: IndexSet(integer: 0))
    }
    
    func prCount() -> Int {
        return waitingPRs.count + dormantPRs.count
    }
    
    func getPR(index: Int) -> PR? {
        if index < 0 {
            return nil
        } else if index < waitingPRs.count {
            return waitingPRs[index]
        } else if index == waitingPRs.count {
            return nil
        } else if index <= waitingPRs.count + dormantPRs.count {
            return dormantPRs[index - waitingPRs.count - 1]
        } else {
            return nil
        }
    }
    
    func lastRow() -> Int {
        return showDormant ? prCount() : waitingPRs.count
    }
}
