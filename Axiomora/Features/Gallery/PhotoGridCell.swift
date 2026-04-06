//
//  PhotoGridCell.swift
//  Axiomora
//
//  Created by geu on 01/04/26.
//

import UIKit

class PhotoGridCell: UICollectionViewCell {

    @IBOutlet var imageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configure(with image: Image) {
        guard let thumbURL = image.thumbnailFileURL, let uiImage  = UIImage(contentsOfFile: thumbURL.path) else {
            imageView?.image = nil
            return
        }
        imageView?.image = uiImage
    }

}
