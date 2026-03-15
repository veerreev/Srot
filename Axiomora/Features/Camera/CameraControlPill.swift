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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupAppearance()
    }
    
    private func setupAppearance() {
        
        self.effect = UIGlassEffect()
        self.layer.cornerRadius = self.frame.height / 2
        self.clipsToBounds = true
        
    }
    
    @IBAction func flashButtonTapped(_ sender: Any) {
        delegate?.didTapFlashButton()
    }
    
    @IBAction func aspectRatioButtonTapped(_ sender: Any) {
        delegate?.didTapAspectRatioButton()
    }
}
