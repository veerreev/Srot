//
//  FilmstripCell.swift
//  Axiomora
//
//  Created by geu on 19/03/26.
//

import UIKit

class FilmstripCell: UICollectionViewCell {
    
    static let reuseIdentifier = "FilmstripCell"

    @IBOutlet var selectionBorderView: UIView!
    @IBOutlet var imageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Border width and color can't be set in the xib so they're configured here once after the nib loads.
        selectionBorderView.layer.borderColor = UIColor.white.cgColor
        selectionBorderView.layer.borderWidth = 2
        selectionBorderView.isHidden = true
    }
            
    // Called by SingleImageViewViewController for each filmstrip cell.
    func configure(with image: Image, isSelected: Bool) {
        // Load thumbnail(not full-res) for smooth scrolling performance(memory efficiency)
        if let thumbURL = image.thumbnailFileURL, let uiImage  = UIImage(contentsOfFile: thumbURL.path) {
            imageView.image = uiImage
        } else {
            imageView.image = nil
        }
                
        // Dim non-selected cells so the current image stands out clearly.
        contentView.alpha = isSelected ? 1.0 : 0.6
        selectionBorderView.isHidden = !isSelected
    }
            
}
