//
//  IndicatorLight.swift
//  BlackPR
//
//  Created by migmit on 2019. 12. 13..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa

class IndicatorLight: NSView {
    
    var status: IndicatorState = .none

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bounds = self.bounds
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let diameter = min(bounds.width, bounds.height)-2
        let radius = diameter/2
        
        let lightRect = CGRect(
            origin: CGPoint(x: bounds.midX - radius, y: bounds.midY - radius),
            size: CGSize(width: diameter, height: diameter)
        )
        
        if status == .mixed {
            NSColor.green.setFill()
            context.beginPath()
            context.move(to: CGPoint(x: bounds.midX, y: bounds.midY - radius))
            context.addLine(to: CGPoint(x: bounds.midX, y: bounds.midY + radius))
            context.addArc(
                tangent1End: CGPoint(x: bounds.midX - radius, y: bounds.midY + radius),
                tangent2End: CGPoint(x: bounds.midX - radius, y: bounds.midY),
                radius: radius
            )
            context.addArc(
                tangent1End: CGPoint(x: bounds.midX - radius, y: bounds.midY - radius),
                tangent2End: CGPoint(x: bounds.midX, y: bounds.midY - radius),
                radius: radius
            )
            context.fillPath()
            NSColor.red.setFill()
            context.beginPath()
            context.move(to: CGPoint(x: bounds.midX, y: bounds.midY - radius))
            context.addLine(to: CGPoint(x: bounds.midX, y: bounds.midY + radius))
            context.addArc(
                tangent1End: CGPoint(x: bounds.midX + radius, y: bounds.midY + radius),
                tangent2End: CGPoint(x: bounds.midX + radius, y: bounds.midY),
                radius: radius
            )
            context.addArc(
                tangent1End: CGPoint(x: bounds.midX + radius, y: bounds.midY - radius),
                tangent2End: CGPoint(x: bounds.midX, y: bounds.midY - radius),
                radius: radius
            )
            context.fillPath()
        }

        NSColor.black.setStroke()
        context.setLineWidth(1)
        
        context.beginPath()
        context.addEllipse(in: lightRect)
        switch status {
        case .approved:
            NSColor.green.setFill()
            context.drawPath(using: .fillStroke)
        case .rejected:
            NSColor.red.setFill()
            context.drawPath(using: .fillStroke)
        default:
            context.strokePath()
        }
        
    }
    
}

enum IndicatorState {
    case none
    case approved
    case rejected
    case mixed
}
