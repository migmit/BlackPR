//
//  UsersHeaderView.swift
//  BlackPR
//
//  Created by MigMit on 15.12.2019.
//  Copyright © 2019 migmit. All rights reserved.
//

import Cocoa

class UsersHeaderView: NSTableCellView {
    
    @IBOutlet weak var AddButton: NSButton!
    
    func handleHover(entered: Bool) {
        AddButton.isHidden = !entered
    }
}
