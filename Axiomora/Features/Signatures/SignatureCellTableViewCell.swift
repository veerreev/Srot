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
        
        // Background
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Card styling
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        cardView.layer.cornerRadius = 16
        
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        
        // Shadow (performance safe)
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.25
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.layer.masksToBounds = false
        
        // Labels setup (IMPORTANT FOR STACK VIEW)
        setupLabels()
        
        // Radio button setup
        setupRadioButton()
    }
    
    func setupLabels() {
        let labels = [titleLabel, nameLabel, sourceLabel, imageIdLabel, socialLabel]
        
        labels.forEach {
            $0?.textColor = .white
            $0?.numberOfLines = 0
            
            // 🔥 Prevent stretching issue
            $0?.setContentHuggingPriority(.required, for: .vertical)
            $0?.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        
        // Title slightly bold
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    }
    
    func setupRadioButton() {
        radioButton.setImage(UIImage(systemName: "circle"), for: .normal)
        radioButton.setImage(UIImage(systemName: "largecircle.fill.circle"), for: .selected)
        radioButton.tintColor = .systemBlue
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
