//
//  CameraControlPill.swift
//  Axiomora
//
//  Created by Veer on 11/03/26.
//


import UIKit

protocol CameraControlPillDelegate: AnyObject {
    func didTapFlashButton()
    func didTapAspectRatioButton()
}

@IBDesignable
class CameraControlPill: UIVisualEffectView {
    
    weak var delegate: CameraControlPillDelegate?
    
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var aspectRatioButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.frame.height / 2
    }
    
    private func setupAppearance() {
        
        let glassEffect = UIGlassEffect()
        glassEffect.isInteractive = true
        self.effect = glassEffect
        self.clipsToBounds = true
        
    }
    
    @IBAction func flashButtonTapped(_ sender: Any) {
        delegate?.didTapFlashButton()
    }
    
    @IBAction func aspectRatioButtonTapped(_ sender: Any) {
        delegate?.didTapAspectRatioButton()
    }
}
