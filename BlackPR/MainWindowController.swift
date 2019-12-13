//
//  MainWindowController.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 21..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate {
    
    var attempts = 10

    override func windowDidLoad() {
        super.windowDidLoad()
    
        shouldCascadeWindows = false
        windowFrameAutosaveName = "MainWindow"
        window?.delegate = self
        if (UserDefaults.standard.bool(forKey: "FullScreen")) {
            window?.toggleFullScreen(nil)
        }
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        if (attempts == 0) { return }
        attempts -= 1
        window.toggleFullScreen(nil)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "FullScreen")
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "FullScreen")
    }

}
