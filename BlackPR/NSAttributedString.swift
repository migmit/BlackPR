//
//  NSAttributedString.swift
//  BlackPR
//
//  Created by migmit on 2019. 12. 12..
//  Copyright © 2019. migmit. All rights reserved.
//

import Foundation

extension NSAttributedString {
    static func +(first: NSAttributedString, second: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(first)
        result.append(second)
        return result
    }
}
