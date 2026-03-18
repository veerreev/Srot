import UIKit

class SignatureCellTableViewCell: UITableViewCell {

    @IBOutlet weak var cardView: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sourceLabel: UILabel!
    @IBOutlet weak var imageIdLabel: UILabel!
    @IBOutlet weak var socialLabel: UILabel!
    
    @IBOutlet weak var radioButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    
    var onRadioTapped: (() -> Void)?
    var onEditTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        cardView.layer.cornerRadius = 20
        
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.5
        cardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardView.layer.shadowRadius = 12
        cardView.layer.masksToBounds = false
        
        radioButton.setImage(UIImage(systemName: "circle"), for: .normal)
        radioButton.setImage(UIImage(systemName: "largecircle.fill.circle"), for: .selected)
    }

    func configure(with signature: Signature, isSelected: Bool) {
        
        titleLabel.text = signature.title
        nameLabel.text = "Name: \(signature.displayName)"
        imageIdLabel.text = "Image ID: \(signature.id)"
        
        sourceLabel.text = "Source: iPhone Camera"
        
        if let handle = signature.socialHandles.first {
            socialLabel.text = "\(handle.platform.rawValue): \(handle.userInput)"
        } else {
            socialLabel.text = "No social linked"
        }
        
        radioButton.isSelected = isSelected
    }

    @IBAction func radioTapped(_ sender: UIButton) {
        onRadioTapped?()
    }
    
    @IBAction func editTapped(_ sender: UIButton) {
        onEditTapped?()
    }
}
