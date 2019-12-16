//
//  PRCellView.swift
//  BlackPR
//
//  Created by migmit on 2019. 12. 12..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

class PRCellView: NSTableCellView {

    @IBOutlet weak var title: NSTextField!
    
    @IBOutlet weak var details: NSTextField!
    
    @IBOutlet weak var statusLight: IndicatorLight!
    var pr: PR?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bounds = self.bounds
        let radius: CGFloat = 10
        let margin: CGFloat = 1
        let offset = radius + margin

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        ((pr?.waiting ?? true) ? NSColor.controlBackgroundColor : NSColor.unemphasizedSelectedTextBackgroundColor).setFill()
        NSColor.textColor.setStroke()
        context.setLineWidth(2)
        context.beginPath()
        context.move(to: CGPoint(x: bounds.minX + offset, y: bounds.minY + margin))
        context.addLine(to: CGPoint(x: bounds.maxX - offset, y: bounds.minY + margin))
        context.addArc(
            tangent1End: CGPoint(x: bounds.maxX - margin, y: bounds.minY + margin),
            tangent2End: CGPoint(x: bounds.maxX - margin, y: bounds.minY + offset),
            radius: radius
        )
        context.addLine(to: CGPoint(x: bounds.maxX - margin, y: bounds.maxY - offset))
        context.addArc(
            tangent1End: CGPoint(x: bounds.maxX - margin, y: bounds.maxY - margin),
            tangent2End: CGPoint(x: bounds.maxX - offset, y: bounds.maxY - margin),
            radius: radius
        )
        context.addLine(to: CGPoint(x: bounds.minX + offset, y: bounds.maxY - margin))
        context.addArc(
            tangent1End: CGPoint(x: bounds.minX + margin, y: bounds.maxY - margin),
            tangent2End: CGPoint(x: bounds.minX + margin, y: bounds.maxY - offset),
            radius: radius
        )
        context.addLine(to: CGPoint(x: bounds.minX + margin, y: bounds.minY + offset))
        context.addArc(
            tangent1End: CGPoint(x: bounds.minX + margin, y: bounds.minY + margin),
            tangent2End: CGPoint(x: bounds.minX + offset, y: bounds.minY + margin),
            radius: radius
        )
        context.drawPath(using: .fillStroke)
        
        if let p = pr {
            if p.isApproved && p.isRejected {
                statusLight.status = .mixed
            } else if p.isApproved {
                statusLight.status = .approved
            } else if p.isRejected {
                statusLight.status = .rejected
            } else {
                statusLight.status = .none
            }
        }

        statusLight.setNeedsDisplay(dirtyRect)
    }
    
}
