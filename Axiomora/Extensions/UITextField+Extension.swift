//
//  UITextField+Extension.swift
//  Axiomora
//
//  Created by Veer Krishna Sharma on 12/02/26.
//

import UIKit

extension UITextField {
    @IBInspectable var placeholderColor: UIColor? {
        get {
            return self.attributedPlaceholder?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        }
        set {
            guard let placeholder = self.placeholder, let color = newValue else { return }
            self.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: color]
            )
        }
    }
}
