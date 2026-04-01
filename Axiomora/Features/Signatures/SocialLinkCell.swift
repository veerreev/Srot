//
//  SocialLinkCell.swift
//  Axiomora
//
//  Created by Veer on 27/03/26.
//

import UIKit

protocol SocialLinkCellDelegate: AnyObject {
    func didTapPlatformButton(on cell: SocialLinkCell)
    func didTapMinusButton(on cell: SocialLinkCell)
}

class SocialLinkCell: UITableViewCell {

    @IBOutlet weak var platformButton: UIButton!
    @IBOutlet weak var handleTextField: UITextField!
    var platform: SocialPlatform?

    weak var delegate: SocialLinkCellDelegate?

    // Called when the platform button is tapped
    @IBAction func platformButtonTapped(_ sender: UIButton) {
        delegate?.didTapPlatformButton(on: self)
    }
    
    @IBAction func minusButtonTapped(_ sender: Any) {
        delegate?.didTapMinusButton(on: self)
    }
}
