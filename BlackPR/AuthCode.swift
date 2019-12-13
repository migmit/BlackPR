//
//  AuthCode.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 20..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

protocol AuthCodeDelegate {
    func accessTokenReceived(token: String)
}
