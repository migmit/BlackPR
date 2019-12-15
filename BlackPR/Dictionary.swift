//
//  Dictionary.swift
//  BlackPR
//
//  Created by MigMit on 15.12.2019.
//  Copyright © 2019 migmit. All rights reserved.
//

extension Dictionary {
    init(flatten: [Key: Value?]) {
        self.init()
        for (key, value) in flatten {
            if let v = value {
                self[key] = v
            }
        }
    }
}
