//
//  MainViewController.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 19..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

class MainViewController: NSSplitViewController {
    
    var firstTimeLayout = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func collapseSidebar() {
        let listItem = splitViewItems[0]
        let prItem = splitViewItems[1]
        listItem.isCollapsed.toggle()
        (prItem.viewController as? PullRequestListController)?.redrawCollapseButton(collapsed: listItem.isCollapsed)
    }
    
}
