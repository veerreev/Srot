import UIKit

@IBDesignable
class RoundedTextField: UITextField {

    // Set defaults from our Theme file
    @IBInspectable var cornerRadius: CGFloat = Theme.TextField.cornerRadius {
        didSet { updateLayer() }
    }

    @IBInspectable var borderColor: UIColor? = Theme.TextField.borderColor { // Default to clear
        didSet {
            layer.borderColor = borderColor?.cgColor
        }
    }

    @IBInspectable var borderWidth: CGFloat = Theme.TextField.borderWidth {
        didSet {
            layer.borderWidth = borderWidth
        }
    }

    // Helper to keep code clean
    private func updateLayer() {
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = cornerRadius > 0
        layer.borderColor = borderColor?.cgColor
        layer.borderWidth = borderWidth
    }
    
    // Ensure the layer updates when the view is first loaded
    override func awakeFromNib() {
        super.awakeFromNib()
        updateLayer()
    }
}
