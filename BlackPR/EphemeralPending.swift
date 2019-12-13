//
//  EphemeralPending.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 24..
//  Copyright © 2019. migmit. All rights reserved.
//

import Foundation

class EphemeralPending {
    
    let url: String
    let timestamp: Date
    
    init(url: String, timestamp: Date) {
        self.url = url
        self.timestamp = timestamp
    }
}
