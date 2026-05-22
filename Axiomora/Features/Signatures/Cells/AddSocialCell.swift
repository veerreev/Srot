//
//  AddSocialCell.swift
//  Axiomora
//
//  Created by Veer on 30/03/26.
//

import UIKit

protocol AddSocialCellDelegate: AnyObject  {
    func didTapAddSocial(on cell: AddSocialCell)
    func didTapAddButton(on cell: AddSocialCell)
}

class AddSocialCell: UITableViewCell {

    weak var delegate: AddSocialCellDelegate?
    
    @IBAction func addSocialTapped(_ sender: Any) {
        delegate?.didTapAddSocial(on: self)
    }
    
    @IBAction func didTapAddButton(_ sender: Any) {
        delegate?.didTapAddButton(on: self)
    }
    
}
