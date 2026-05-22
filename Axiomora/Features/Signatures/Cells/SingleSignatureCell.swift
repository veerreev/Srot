import UIKit

class SingleSignatureCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var labelEntry: UILabel!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var icon: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(label labelText: String, entry: String, url: URL?) {
        label.text = labelText
        labelEntry.text = entry
        // Show the arrow only for tappable rows (those with a destination URL).
        icon.isHidden = url == nil
        selectionStyle = url == nil ? .none : .default
    }
}
