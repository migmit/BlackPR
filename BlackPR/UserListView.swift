//
//  UserListView.swift
//  BlackPR
//
//  Created by MigMit on 15.12.2019.
//  Copyright © 2019 migmit. All rights reserved.
//

import Cocoa

class UserListView: NSOutlineView {
    
    var oldHoverCell: NSView?

    override func updateTrackingAreas() {
        trackingAreas.forEach{removeTrackingArea($0)}
        addTrackingArea(NSTrackingArea(rect: frame, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil))
    }
    
    func showhide(cell: NSView, hide: Bool) {
        if let usersHeaderView = cell as? UsersHeaderView {
            usersHeaderView.AddButton.isHidden = hide
        } else if let userCellView = cell as? UserCellView {
            userCellView.RemoveButton.isHidden = hide
        }
    }
    
    func handleTracking(cellOpt: NSView?) {
        if cellOpt != oldHoverCell {
            oldHoverCell.map{showhide(cell: $0, hide: true)}
            oldHoverCell = cellOpt
            cellOpt.map{showhide(cell: $0, hide: false)}
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let hoverRow = row(at: location)
        handleTracking(cellOpt: hoverRow >= 0 ? view(atColumn: 0, row: hoverRow, makeIfNecessary: false) : nil)
        needsDisplay = true
        displayIfNeeded()
    }
    
    override func mouseEntered(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let hoverRow = row(at: location)
        handleTracking(cellOpt: hoverRow >= 0 ? view(atColumn: 0, row: hoverRow, makeIfNecessary: false) : nil)
        needsDisplay = true
        displayIfNeeded()
    }
    
    override func mouseExited(with event: NSEvent) {
        handleTracking(cellOpt: nil)
        needsDisplay = true
        displayIfNeeded()
    }
}
