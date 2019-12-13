//
//  UserDrag.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 20..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

class UserDrag: NSObject, NSPasteboardReading, NSPasteboardWriting {
    
    static let pasteboardType = NSPasteboard.PasteboardType("com.kinja.blackpr.UserDrag")
    
    let seqId: Int32?
    
    init(user: User) {
        self.seqId = user.seqId
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        if type == UserDrag.pasteboardType {
            self.seqId = propertyList as? Int32
        } else {
            return nil
        }
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [UserDrag.pasteboardType]
    }
    
    static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        if type == UserDrag.pasteboardType {
            return NSPasteboard.ReadingOptions.asPropertyList
        } else {
            return []
        }
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [UserDrag.pasteboardType]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == UserDrag.pasteboardType {
            return seqId
        }
        return nil
    }
    
}
