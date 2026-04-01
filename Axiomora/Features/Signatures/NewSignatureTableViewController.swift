//
//  NewSignatureTableViewController.swift
//  Axiomora
//
//  Created by Veer on 26/03/26.
//

import UIKit

class NewSignatureTableViewController: UITableViewController, UINavigationControllerDelegate {

    @IBOutlet weak var notesTextView: UITextView!
    
    private var editingSocialLinkIndex: IndexPath?
    private var socialHandles: [(platform: SocialPlatform, handle: String)] = []
    private let socialSectionIndex = 2
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "SocialLinkCell", bundle: nil), forCellReuseIdentifier: "SocialLinkCell")
        tableView.register(UINib(nibName: "AddSocialCell", bundle: nil), forCellReuseIdentifier: "AddSocialCell")
        
        setupNotesTextView()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == socialSectionIndex {
            return socialHandles.count + 1
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - Actions
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
    private func addNewRow() {
        if socialHandles.count <= 10 {
            socialHandles.append((platform: .instagram, handle: ""))
            
            let targetIndexPath = IndexPath(row: socialHandles.count - 1, section: socialSectionIndex)
            tableView.insertRows(at: [targetIndexPath], with: .fade)
        }
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
        
        socialHandles.remove(at: indexPath.row)
        
        tableView.deleteRows(at: [indexPath], with: .left)
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
