//
//  UserCellView.swift
//  BlackPR
//
//  Created by MigMit on 15.12.2019.
//  Copyright © 2019 migmit. All rights reserved.
//

import Cocoa

class UserCellView: NSTableCellView {
    
    @IBOutlet weak var RemoveButton: NSButton!
    
    func handleHover(entered: Bool) {
        RemoveButton.isHidden = !entered
    }
}
