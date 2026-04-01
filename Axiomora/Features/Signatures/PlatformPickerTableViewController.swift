//
//  PlatformPickerTableViewController.swift
//  Axiomora
//
//  Created by Veer on 31/03/26.
//

import UIKit

protocol PlatformPickerDelegate: AnyObject {
    func didSelectPlatform(_ platform: SocialPlatform)
}

class PlatformPickerTableViewController: UITableViewController {

    private var allPlatforms: [SocialPlatform] = []
    var selectedPlatform: SocialPlatform?
    var selectedCell: IndexPath?
    weak var delegate: PlatformPickerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "PlatformCell", bundle: nil), forCellReuseIdentifier: "PlatformCell")
        
        allPlatforms = SocialPlatform.allCases
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { return 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return SocialPlatform.allCases.count }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PlatformCell", for: indexPath) as? PlatformCell else {
            fatalError("Platform Cell not found")
        }
        
        cell.platformLabel.text = allPlatforms[indexPath.row].rawValue
        
        if let platformIcon = UIImage(named: allPlatforms[indexPath.row].iconName) {
            cell.platformIcon.image = platformIcon
        }
        
        if indexPath.row == allPlatforms.count - 1 {
            cell.separatorView.isHidden = true
        }
        
        if let selectedPlatform = selectedPlatform,
           let row = allPlatforms.firstIndex(of: selectedPlatform) {
                if indexPath.row == row {
                    cell.accessoryType = .checkmark
                    cell.backgroundColor = .secondaryBlue
                    cell.selectionStyle = .none
                }
            
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let cell = tableView.cellForRow(at: indexPath), let currentCell = tableView.cellForRow(at: selectedCell ?? IndexPath(row: 0, section: 0)), cell != currentCell {
            cell.accessoryType = .checkmark
            cell.backgroundColor = .secondaryBlue
            cell.selectionStyle = .none
            currentCell.accessoryType = .none
            selectedCell = indexPath
        }
        
        let selectedPlatform = allPlatforms[indexPath.row]
        delegate?.didSelectPlatform(selectedPlatform)
        dismiss(animated: true)
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}
