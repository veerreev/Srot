//
//  FilmstripCell.swift
//  Axiomora
//
//  Created by geu on 19/03/26.
//

import UIKit

class FilmstripCell: UICollectionViewCell {
    
    static let reuseIdentifier = "FilmstripCell"

    @IBOutlet var imageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
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
        contentView.alpha = isSelected ? 1.0 : 0.3
        //selectionBorderView.isHidden = !isSelected
    }
            
}
