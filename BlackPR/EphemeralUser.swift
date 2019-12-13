//
//  EphemeralUser.swift
//  BlackPR
//
//  Created by migmit on 2019. 12. 11..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

class EphemeralUser {
    
    let name: String
    let token: String
    let lastUpdated: Date?
    
    init(name: String, token: String, lastUpdated: Date?) {
        self.name = name
        self.token = token
        self.lastUpdated = lastUpdated
    }
}
