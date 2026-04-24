//
//  NewSignatureTableViewController.swift
//  Axiomora
//
//  Created by Veer on 26/03/26.
//

import UIKit

protocol NewSignatureDelegate: AnyObject {
    func didCreateSignature(_ signature: Signature)
    func didUpdateSignature(_ signature: Signature)
}

class NewSignatureTableViewController: UITableViewController, UINavigationControllerDelegate {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var portfolioTextField: UITextField!
    @IBOutlet weak var copyrightTextField: UITextField!
    @IBOutlet weak var locationSwitch: UISwitch!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    var signatureToEdit: Signature?
    
    private var editingSocialLinkIndex: IndexPath?
    private var socialHandles: [(platform: SocialPlatform, handle: String)] = []
    private let socialSectionIndex = 2
    private var didValuesChange: Bool = false
    weak var delegate: NewSignatureDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "SocialLinkCell", bundle: nil), forCellReuseIdentifier: "SocialLinkCell")
        tableView.register(UINib(nibName: "AddSocialCell", bundle: nil), forCellReuseIdentifier: "AddSocialCell")

        doneButton.isEnabled = false
        
        setupNotesTextView()
        
        if let sig = signatureToEdit {
            prefill(with: sig)
            title = "Edit Signature"
            doneButton.isEnabled = true
        }
    }
    
    private func prefill(with sig: Signature) {
        titleTextField.text = sig.title
        nameTextField.text = sig.displayName
        emailTextField.text = sig.email
        portfolioTextField.text = sig.website
        copyrightTextField.text = sig.copyrightText
        locationSwitch.isOn = sig.shouldIncludeLocation
        notesTextView.text = sig.notes

        socialHandles = sig.socialHandles.map { ($0.platform, $0.userInput) }
        tableView.reloadSections(IndexSet(integer: socialSectionIndex), with: .none)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == socialSectionIndex {
            return socialHandles.count == 11 ? socialHandles.count : socialHandles.count + 1
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == socialSectionIndex {
            
            if indexPath.row == socialHandles.count {
                
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "AddSocialCell", for: indexPath) as? AddSocialCell else {
                        fatalError("AddSocialCell not found")
                }
                
                cell.delegate = self
                return cell
                
            } else if indexPath.row < socialHandles.count {
                
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SocialLinkCell", for: indexPath) as? SocialLinkCell else {
                        fatalError ("Unable to find SocialLinkCell")
                }
                
                let entry = socialHandles[indexPath.row]
                cell.platformButton.setTitle(entry.platform.rawValue, for: .normal)
                cell.handleTextField.text = entry.handle
                cell.delegate = self
                return cell
                
            } else {
                return super.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: indexPath.section))
            }
        }
        return super.tableView(tableView, cellForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let isAddSocialTapped = indexPath.section == socialSectionIndex && indexPath.row == socialHandles.count
        
        if isAddSocialTapped {
//            tableView.deselectRow(at: indexPath, animated: true)
            addNewRow()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        if didValuesChange {
            let alert = UIAlertController(
                title: nil,
                message: "Are you sure you want to discard the changes?",
                preferredStyle: .actionSheet
            )

            alert.addAction(UIAlertAction(title: "Discard Changes", style: .destructive) { [weak self] _ in
                self?.dismiss(animated: true)
            })
            
            if let popover = alert.popoverPresentationController {
                popover.barButtonItem = cancelButton
            }

            present(alert, animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        guard let name = nameTextField.text, !name.isEmpty,
              let title = titleTextField.text, !title.isEmpty else {
            fatalError("Name, Title cannot be empty")
        }
        guard let userID = AuthManager.shared.currentUser?.userId else {
            fatalError("No user logged in")
        }

        let handles: [SocialHandle] = socialHandles
            .filter { !$0.handle.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { SocialHandle(platform: $0.platform, userInput: $0.handle) }

        if let existing = signatureToEdit {
            // Edit mode — preserve the original id and creatorID
            let updated = Signature(
                id: existing.id,
                creatorID: existing.creatorID,
                title: title,
                isCurrent: existing.isCurrent,
                displayName: name,
                copyrightText: copyrightTextField.text?.isEmpty == false ? copyrightTextField.text : nil,
                email: emailTextField.text?.isEmpty == false ? emailTextField.text : nil,
                website: portfolioTextField.text?.isEmpty == false ? portfolioTextField.text : nil,
                socialHandles: handles,
                shouldIncludeLocation: locationSwitch.isOn,
                notes: notesTextView.text?.isEmpty == false ? notesTextView.text : nil
            )
            dismiss(animated: true) { [weak self] in
                self?.delegate?.didUpdateSignature(updated)
            }
            
        } else {
            // Create mode
            let newSignature = Signature(
                id: UUID().uuidString,
                creatorID: userID,
                title: title,
                displayName: name,
                copyrightText: copyrightTextField.text?.isEmpty == false ? copyrightTextField.text : nil,
                email: emailTextField.text?.isEmpty == false ? emailTextField.text : nil,
                website: portfolioTextField.text?.isEmpty == false ? portfolioTextField.text : nil,
                socialHandles: handles,
                shouldIncludeLocation: locationSwitch.isOn,
                notes: notesTextView.text?.isEmpty == false ? notesTextView.text : nil
            )
            dismiss(animated: true) { [weak self] in
                self?.delegate?.didCreateSignature(newSignature)
            }
        }

        
    }
    
    @IBAction func valueChanged(_ sender: Any) {
        didValuesChange = true
        doneButton.isEnabled = true
    }
    
    // MARK: - Other functions (Helpers)
    
    private func addNewRow() {
        let oldAddSocialPath = IndexPath(row: socialHandles.count, section: socialSectionIndex)
        
        socialHandles.append((platform: .instagram, handle: ""))
        let newRowPath = IndexPath(row: socialHandles.count - 1, section: socialSectionIndex)
        
        tableView.beginUpdates()
        tableView.insertRows(at: [newRowPath], with: .fade)
        if socialHandles.count == 11 {
            tableView.deleteRows(at: [oldAddSocialPath], with: .fade)
        }
        tableView.endUpdates()
    }
}

// MARK: - Delegates

// Notes TextView: adjusting height of the row
extension NewSignatureTableViewController: UITextViewDelegate {
    
    private func setupNotesTextView() {
        
        notesTextView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // Tells the table view to re-evaluate cell heights without animation glitches
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
}

extension NewSignatureTableViewController: SocialLinkCellDelegate {

    func didTapPlatformButton(on cell: SocialLinkCell) {
        
        self.editingSocialLinkIndex = tableView.indexPath(for: cell)
        
        let storyboard = UIStoryboard(name: "PlatformPickerStoryboard", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController
        
        if let pickerVC = navController.viewControllers.first as? PlatformPickerTableViewController,
           let index = editingSocialLinkIndex {
            pickerVC.delegate = self
            pickerVC.selectedPlatform = socialHandles[index.row].platform
        }
        
        navController.delegate = self
        present(navController, animated: true)
    }
    
    func didTapMinusButton(on cell: SocialLinkCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        
        let wasAtLimit = socialHandles.count == 11
        socialHandles.remove(at: indexPath.row)
        let newAddSocialPath = IndexPath(row: socialHandles.count, section: socialSectionIndex)
        
        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .left)
        if wasAtLimit {
            tableView.insertRows(at: [newAddSocialPath], with: .fade)
        }
        tableView.endUpdates()
    }
    
    func didUpdateHandle(_ text: String, on cell: SocialLinkCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        socialHandles[indexPath.row].handle = text
    }
}

extension NewSignatureTableViewController: AddSocialCellDelegate {
    
    func didTapAddSocial(on cell: AddSocialCell) {
        addNewRow()
    }
    
    func didTapAddButton(on cell: AddSocialCell) {
        addNewRow()
    }
    
}

extension NewSignatureTableViewController: PlatformPickerDelegate {
    
    func didSelectPlatform(_ platform: SocialPlatform) {
        guard let index = editingSocialLinkIndex else { return }
        
        socialHandles[index.row].platform = platform
        
        if let cell = tableView.cellForRow(at: index) as? SocialLinkCell {
            cell.platformButton.setTitle(platform.rawValue, for: .normal)
            cell.platform = platform
        }
        self.editingSocialLinkIndex = nil
    }
    
}
