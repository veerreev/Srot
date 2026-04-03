//
//  SignatureCell.swift
//  Axiomora
//
//  Created by Veer on 02/04/26.
//

import UIKit

class SignatureCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var visualEffectViewBackground: UIVisualEffectView!
    
    @IBOutlet weak var nameStackView: UIStackView!
    @IBOutlet weak var nameEntryLabel: UILabel!
    @IBOutlet weak var nameEmailSeparator: UIView!
    
    @IBOutlet weak var emailStackView: UIStackView!
    @IBOutlet weak var emailEntryLabel: UILabel!
    @IBOutlet weak var emailPortfolioSeparator: UIView!
    
    @IBOutlet weak var portfolioStackView: UIStackView!
    @IBOutlet weak var portfolioEntryLabel: UILabel!
    @IBOutlet weak var portfolioCopyrightSeparator: UIView!
    
    @IBOutlet weak var copyrightEntryLabel: UILabel!
    @IBOutlet weak var chipFlowView: ChipFlowView!
    @IBOutlet weak var nameLabel: UILabel!
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupUI()
    }
    
    private func setupUI() {
        
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = Theme.Colors.signatureBackground
        visualEffectViewBackground.effect = glassEffect
        visualEffectViewBackground.layer.cornerRadius = 32
    }
    
    func configure(with signature: Signature) {
        
        titleLabel.text = signature.title
        nameEntryLabel.text = signature.displayName
        emailEntryLabel.text = signature.email
        portfolioEntryLabel.text = signature.website
        copyrightEntryLabel.text = "© " + (signature.copyrightText ?? "")
        
        
        chipFlowView.configure(with: signature.socialHandles)
        
    }

}
