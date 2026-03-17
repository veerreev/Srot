//
//  settingsViewController.swift
//  Axiomora
//
//  Created by Dhruv Negi on 16/03/26.
//
import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!

    let sections = [
        ["Email address", "Password", "Change profile picture"],
        ["Deactivate account", "Delete your data and account"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()

        view.backgroundColor = .black

        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        

        view.insertSubview(blurView, at: 0)
    }
    func deleteAccount() {
        
        guard let url = URL(string: "https://api.yourapp.com/deleteAccount") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            DispatchQueue.main.async {
                
                if error != nil {
                    print("Delete failed")
                    return
                }
                
                print("Account deleted")
            }
            
        }.resume()
    }
    func confirmDelete() {

        let alert = UIAlertController(
            title: "Delete Account",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteAccount()
        })

        present(alert, animated: true)
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)

        let title = sections[indexPath.section][indexPath.row]

        cell.textLabel?.text = title
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .disclosureIndicator

        if title == "Email address" {
            cell.detailTextLabel?.text = "john@gmail.com"
        }

        if title == "Delete your data and account" {
            cell.textLabel?.textColor = .systemRed
        } else {
            cell.textLabel?.textColor = .white
        }

        cell.backgroundColor = UIColor(white: 0.15, alpha: 1)

        let totalRows = tableView.numberOfRows(inSection: indexPath.section)

        if indexPath.row == 0 {
            cell.layer.cornerRadius = 16
            cell.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        else if indexPath.row == totalRows - 1 {
            cell.layer.cornerRadius = 16
            cell.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        else {
            cell.layer.cornerRadius = 0
        }

        cell.layer.masksToBounds = true

        return cell
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {

        if section == 0 {
            return "Personal information"
        } else {
            return "Deactivate and deletion"
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)

        let option = sections[indexPath.section][indexPath.row]

        if option == "Email address" {
            print("Email tapped")
        }

        else if option == "Password" {

            let storyboard = UIStoryboard(name: "ChangePasswordStoryboard", bundle: nil)

            guard let vc = storyboard.instantiateViewController(
                withIdentifier: "ChangePasswordViewController"
            ) as? ChangePasswordViewController else { return }

            navigationController?.pushViewController(vc, animated: true)
        }

        else if option == "Change profile picture" {
            openImagePicker()
        }

        else if option == "Deactivate account" {

            let alert = UIAlertController(
                title: "Deactivate Account",
                message: "Your account will be temporarily disabled.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            alert.addAction(UIAlertAction(title: "Deactivate", style: .destructive) { _ in
                print("Account Deactivated")
            })

            present(alert, animated: true)
        }

        else if option == "Delete your data and account" {
            confirmDelete()
        }
    }
    func openImagePicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }
}
extension SettingsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if let image = info[.originalImage] as? UIImage {
            print("Profile image selected")
        }

        picker.dismiss(animated: true)
    }
}
