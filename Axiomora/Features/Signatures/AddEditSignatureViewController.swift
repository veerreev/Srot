import UIKit

protocol AddEditSignatureDelegate: AnyObject {
    func didSaveSignature(_ signature: Signature)
    func didDeleteSignature(_ id: String)
}

class AddEditSignatureViewController: UIViewController {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var websiteTextField: UITextField!
    @IBOutlet weak var copyrightTextField: UITextField!
    
    @IBOutlet weak var addSocialButton: UIButton!
    @IBOutlet weak var mainStackView: UIStackView!
    
    var selectedPlatforms: [SocialPlatform] = []
    var platformTextFields: [SocialPlatform: UITextField] = [:]
    
    var existingSignature: Signature?
    
    weak var delegate: AddEditSignatureDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateIfEdit()
    }
}

// MARK: - UI
extension AddEditSignatureViewController {
    
    func setupUI() {
        
        //view.backgroundColor = .black
        
        titleLabel.text = existingSignature != nil ? "Edit Signature" : "Add Signature"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        titleLabel.alpha = 1
        titleLabel.isHidden = false
        titleLabel.numberOfLines = 1
        
        // Optional: debug background (remove later if needed)
        // titleLabel.backgroundColor = .red
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .prominent,
            target: self,
            action: #selector(saveTapped)
        )
        
        if existingSignature != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Delete",
                style: .plain,
                target: self,
                action: #selector(deleteTapped)
            )
            navigationItem.leftBarButtonItem?.tintColor = .red
        }
    }
}

//ADD SOCIAL MEDIA
extension AddEditSignatureViewController {
    
    @IBAction func addSocialTapped(_ sender: UIButton) {
        
        let alert = UIAlertController(title: "Select Platform", message: nil, preferredStyle: .actionSheet)
        
        let availablePlatforms = SocialPlatform.allCases.filter { !selectedPlatforms.contains($0) }
        
        if availablePlatforms.isEmpty {
            let noMore = UIAlertController(title: "All platforms added", message: nil, preferredStyle: .alert)
            noMore.addAction(UIAlertAction(title: "OK", style: .default))
            present(noMore, animated: true)
            return
        }
        
        for platform in availablePlatforms {
            alert.addAction(UIAlertAction(title: platform.rawValue, style: .default, handler: { _ in
                self.addPlatformField(platform)
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func addPlatformField(_ platform: SocialPlatform) {
        
        if selectedPlatforms.contains(platform) { return }
        
        selectedPlatforms.append(platform)
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        
        let label = UILabel()
        label.text = platform.rawValue
        label.textColor = .white
        
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("✕", for: .normal)
        deleteButton.setTitleColor(.red, for: .normal)
        
        headerStack.addArrangedSubview(label)
        headerStack.addArrangedSubview(deleteButton)
        
        let textField = UITextField()
        textField.placeholder = "  Enter \(platform.rawValue) username"
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 0.5
        textField.layer.borderColor = UIColor.systemGray2.cgColor
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        platformTextFields[platform] = textField
        
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        
        container.addArrangedSubview(headerStack)
        container.addArrangedSubview(textField)
        
        deleteButton.addAction(UIAction(handler: { [weak self] _ in
            self?.removePlatform(platform, container: container)
        }), for: .touchUpInside)
        
        mainStackView.addArrangedSubview(container)
    }
    
    func removePlatform(_ platform: SocialPlatform, container: UIStackView) {
        mainStackView.removeArrangedSubview(container)
        container.removeFromSuperview()
        
        selectedPlatforms.removeAll { $0 == platform }
        platformTextFields.removeValue(forKey: platform)
    }
}

// EDIT MODE
extension AddEditSignatureViewController {
    
    func populateIfEdit() {
        guard let signature = existingSignature else { return }
        
        titleTextField.text = signature.title
        nameTextField.text = signature.displayName
        websiteTextField.text = signature.website
        copyrightTextField.text = signature.copyrightText
        
        for handle in signature.socialHandles {
            addPlatformField(handle.platform)
            platformTextFields[handle.platform]?.text = handle.userInput
        }
    }
}

// SAVE BUTTON
extension AddEditSignatureViewController {
    
    @objc func saveTapped() {
        
        let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if title.isEmpty {
            showAlert(message: "Please enter a signature title")
            return
        }
        
        if name.isEmpty {
            showAlert(message: "Please enter your name")
            return
        }
        
        let website = websiteTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let copyright = copyrightTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var handles: [SocialHandle] = []
        
        for (platform, textField) in platformTextFields {
            if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                handles.append(SocialHandle(platform: platform, userInput: text))
            }
        }
        
        if let existing = existingSignature {
            
            var updated = existing
            updated.title = title
            updated.displayName = name
            updated.website = website
            updated.copyrightText = copyright
            updated.socialHandles = handles
            
            delegate?.didSaveSignature(updated)
            
        } else {
            
            let newSignature = Signature(
                id: UUID().uuidString,
                creatorID: "1",
                title: title,
                displayName: name,
                copyrightText: copyright,
                email: nil,
                website: website,
                socialHandles: handles,
                shouldIncludeLocation: false
            )
            
            delegate?.didSaveSignature(newSignature)
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(
            title: "Missing Information",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}

// delete signature button
extension AddEditSignatureViewController {
    
    @objc func deleteTapped() {
        
        guard let id = existingSignature?.id else { return }
        
        let alert = UIAlertController(
            title: "Delete Signature",
            message: "Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.delegate?.didDeleteSignature(id)
            self.navigationController?.popViewController(animated: true)
        }))
        
        present(alert, animated: true)
    }
}
