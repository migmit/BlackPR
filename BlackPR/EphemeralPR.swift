//
//  EphemeralPR.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 24..
//  Copyright © 2019. migmit. All rights reserved.
//

import Foundation

class EphemeralPR {
    let apiUrl: String
    let author: String
    let httpUrl: String
    let isApproved: Bool
    let isRejected: Bool
    let lastUpdated: Date?
    let number: Int
    let owner: String
    let repo: String
    let title: String
    let waiting: Bool
    
    init(apiUrl: String, author: String, httpUrl: String, isApproved: Bool, isRejected: Bool, lastUpdated: Date?, number: Int, owner: String, repo: String, title: String, waiting: Bool) {
        self.apiUrl = apiUrl
        self.author = author
        self.httpUrl = httpUrl
        self.isApproved = isApproved
        self.isRejected = isRejected
        self.lastUpdated = lastUpdated
        self.number = number
        self.owner = owner
        self.repo = repo
        self.title = title
        self.waiting = waiting
    }
}
