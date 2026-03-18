import UIKit

class AddEditSignatureViewController: UIViewController {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var websiteTextField: UITextField!
    @IBOutlet weak var copyrightTextField: UITextField!
    
    @IBOutlet weak var addSocialButton: UIButton!
    @IBOutlet weak var mainStackView: UIStackView!
    
    var selectedPlatforms: [SocialPlatform] = []
    var platformTextFields: [SocialPlatform: UITextField] = [:]
    
    var isEditMode: Bool = false
    var existingSignature: Signature?
    
    var onSave: ((Signature) -> Void)?
    var onDelete: ((String) -> Void)?   // 🔥 DELETE CALLBACK
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        populateIfEdit()
    }
}

// MARK: - UI
extension AddEditSignatureViewController {
    
    func setupUI() {
        title = isEditMode ? "Edit Signature" : "Add Signature"
        view.backgroundColor = .black
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        
        
        if isEditMode {
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

// MARK: - ADD SOCIAL MEDIA
extension AddEditSignatureViewController {
    
    @IBAction func addSocialTapped(_ sender: UIButton) {
        
        let alert = UIAlertController(title: "Select Platform", message: nil, preferredStyle: .actionSheet)
        
        
        let availablePlatforms = SocialPlatform.allCases.filter { !selectedPlatforms.contains($0) }
        
        // If all platforms already selected
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
        
        // 🔥 HORIZONTAL CONTAINER (Label + Delete Button)
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
        deleteButton.tag = selectedPlatforms.count - 1   // temporary tag
        
        headerStack.addArrangedSubview(label)
        headerStack.addArrangedSubview(deleteButton)
        
        // TEXTFIELD
        let textField = UITextField()
        textField.placeholder = "Enter \(platform.rawValue) username"
        textField.backgroundColor = .clear
        textField.textColor = .white

        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray2.cgColor
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
        
        // remove from UI
        mainStackView.removeArrangedSubview(container)
        container.removeFromSuperview()
        
        // remove from data
        selectedPlatforms.removeAll { $0 == platform }
        platformTextFields.removeValue(forKey: platform)
    }
}

// MARK: - EDIT MODE
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

// MARK: - SAVE
extension AddEditSignatureViewController {
    
    @objc func saveTapped() {
        
        let title = titleTextField.text ?? ""
        let name = nameTextField.text ?? ""
        let website = websiteTextField.text
        let copyright = copyrightTextField.text
        
        var handles: [SocialHandle] = []
        
        for (platform, textField) in platformTextFields {
            if let text = textField.text, !text.isEmpty {
                handles.append(SocialHandle(platform: platform, userInput: text))
            }
        }
        
        if isEditMode, var existing = existingSignature {
            
            existing.title = title
            existing.displayName = name
            existing.website = website
            existing.copyrightText = copyright
            existing.socialHandles = handles
            
            onSave?(existing)
            
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
            
            onSave?(newSignature)
        }
        
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - DELETE
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
            
            self.onDelete?(id)
            self.navigationController?.popViewController(animated: true)
        }))
        
        present(alert, animated: true)
    }
}
