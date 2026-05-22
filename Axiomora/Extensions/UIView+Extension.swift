//
//  UIView+Extension.swift
//  Axiomora
//
//  Created by GEU on 12/02/26.
//

import UIKit

extension UIView {
    func shake() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.07
        animation.repeatCount = 2
        animation.autoreverses = true
        animation.fromValue = NSValue(cgPoint: CGPoint(x: self.center.x - 10, y: self.center.y))
        animation.toValue = NSValue(cgPoint: CGPoint(x: self.center.x + 10, y: self.center.y))
        self.layer.add(animation, forKey: "position")
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

    }
}
