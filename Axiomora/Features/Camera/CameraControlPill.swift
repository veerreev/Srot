//
//  CameraControlPill.swift
//  Axiomora
//
//  Created by Veer on 11/03/26.
//


import UIKit

@IBDesignable
class CameraControlPill: UIVisualEffectView {
    
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var expandButton: UIButton!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupAppearance()
    }
    
    private func setupAppearance() {
        
        self.effect = UIGlassEffect()
        self.layer.cornerRadius = self.frame.height / 2
        self.clipsToBounds = true
        
    }
}
