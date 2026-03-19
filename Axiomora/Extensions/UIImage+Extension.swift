//
//  UIImage+Extension.swift
//  Axiomora
//
//  Created by Veer on 18/03/26.
//

import UIKit

extension UIImage {

    /// Returns a copy of the image redrawn with `.up` orientation.
    ///
    /// Photos captured by AVFoundation are usually stored with `.right` orientation
    /// (the sensor is landscape, so the image data is rotated). `CGImage.cropping(to:)`
    /// ignores `imageOrientation` and operates directly on the raw pixel buffer,
    /// so calling `normalized()` first ensures crop rects are applied on the correct axis.
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()

        return normalizedImage
    }

}
