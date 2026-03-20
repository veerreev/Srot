import UIKit

protocol SignatureCellDelegate: AnyObject {
    func didTapRadio(at index: Int)
    func didTapEdit(at index: Int)
}

class SignatureCellTableViewCell: UITableViewCell {

    @IBOutlet weak var cardView: UIView!
    
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sourceLabel: UILabel!
    @IBOutlet weak var imageIdLabel: UILabel!
    @IBOutlet weak var socialLabel: UILabel!
    
    @IBOutlet weak var radioButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    
    weak var delegate: SignatureCellDelegate?
    var index: Int = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        setupCardView()
        setupLabels()
        setupRadioButton()
        setupNumberLabel()
        
        //target action
        radioButton.addTarget(self, action: #selector(radioTapped), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
    }
    
    // UI SETUP
    
    func setupCardView() {
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        cardView.layer.cornerRadius = 16
        
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.25
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.layer.masksToBounds = false
    }
    
    func setupLabels() {
        let labels = [titleLabel, nameLabel, sourceLabel, imageIdLabel, socialLabel]
        
        labels.forEach {
            $0?.textColor = .white
            $0?.numberOfLines = 0
            $0?.setContentHuggingPriority(.required, for: .vertical)
            $0?.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    }
    
    func setupNumberLabel() {
        numberLabel.textColor = .systemBlue
        numberLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
    }
    
    func setupRadioButton() {
        radioButton.setImage(UIImage(systemName: "circle"), for: .normal)
        radioButton.setImage(UIImage(systemName: "largecircle.fill.circle"), for: .selected)
        radioButton.tintColor = .systemBlue
    }

    // CONFIGURE
    
    func configure(with signature: Signature, isSelected: Bool, index: Int) {
        
        self.index = index
        
        numberLabel.text = "\(index + 1)"
        
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

    //ACTIONS (Target-Action)
    
    @objc func radioTapped() {
        delegate?.didTapRadio(at: index)
    }
    
    @objc func editTapped() {
        delegate?.didTapEdit(at: index)
    }
}
