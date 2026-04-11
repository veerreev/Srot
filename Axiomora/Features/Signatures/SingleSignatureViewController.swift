//
//  SingleSignatureViewController.swift
//  Axiomora
//
//  Created by Veer on 10/04/26.
//

import UIKit

class SingleSignatureViewController: UIViewController {

    var signature: Signature?
    var onSignatureUpdated: ((Signature) -> Void)?
    
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Data model

    private struct Row {
        let label: String
        let entry: String
        let iconName: String
    }

    private struct Section {
        let title: String
        let rows: [Row]
    }

    // Sections 1+ (index 0 is always the TopSingleSignatureCell header)
    private var contentSections: [Section] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSections()
        setupTableView()
    }

    @IBAction func editButtonTapped(_ sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "NewSignatureStoryboard", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController
        let editVC = navController.viewControllers.first as! NewSignatureTableViewController

        editVC.signatureToEdit = signature
        editVC.delegate = self
        navController.modalPresentationStyle = .fullScreen
        navController.modalTransitionStyle = .crossDissolve
        present(navController, animated: true)
    }
    
    // MARK: - Data building

    private func buildSections() {
        guard let sig = signature else { return }

        // ── Section 1: Identity & Contact ─────────────────────────
        var identityRows: [Row] = []

        identityRows.append(Row(label: "Name", entry: sig.displayName, iconName: "person"))

        if let email = sig.email, !email.isEmpty {
            identityRows.append(Row(label: "Email", entry: email, iconName: "envelope"))
        }

        if let website = sig.website, !website.isEmpty {
            identityRows.append(Row(label: "Portfolio", entry: website, iconName: "link"))
        }

        if let copyright = sig.copyrightText, !copyright.isEmpty {
            identityRows.append(Row(label: "Copyright", entry: "© \(copyright)", iconName: "c.circle"))
        }

        if !identityRows.isEmpty {
            contentSections.append(Section(title: "Identity", rows: identityRows))
        }

        // ── Section 2: Social Handles ──────────────────────────────
        let socialRows: [Row] = sig.socialHandles.map { handle in
            Row(
                label: handle.platform.rawValue,
                entry: handle.userInput,
                iconName: handle.platform.iconName
            )
        }

        if !socialRows.isEmpty {
            contentSections.append(Section(title: "Socials", rows: socialRows))
        }

        // ── Section 3: Notes ───────────────────────────────────────
        if let notes = sig.notes, !notes.isEmpty {
            contentSections.append(Section(title: "Notes", rows: [
                Row(label: "Notes", entry: notes, iconName: "note.text")
            ]))
        }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            UINib(nibName: "TopSingleSignatureCell", bundle: nil),
            forCellReuseIdentifier: "TopSignatureCell"
        )
        tableView.register(
            UINib(nibName: "SingleSignatureCell", bundle: nil),
            forCellReuseIdentifier: "SingleSignatureCell"
        )

        tableView.backgroundColor = .clear
        tableView.backgroundView = nil

        // Separator color — a subtle white line looks right on dark blurred cells
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.12)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
    }
}

// MARK: - UITableViewDataSource

extension SingleSignatureViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        // Section 0 (top cell) + content sections
        return 1 + contentSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : contentSections[section - 1].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TopSignatureCell", for: indexPath) as! TopSingleSignatureCell
            if let sig = signature {
                cell.titleLabel.text = sig.title
                if sig.shouldIncludeLocation {
                    cell.locationIcon.image = UIImage(systemName: "location")
                    cell.locationLabel.text = "Location included"
                } else {
                    cell.locationIcon.image = UIImage(systemName: "location.slash")
                    cell.locationLabel.text = "Location not included"
                }
            }
            return cell
        }

        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "SingleSignatureCell", for: indexPath
        ) as! SingleSignatureCell

        let row = contentSections[indexPath.section - 1].rows[indexPath.row]
        cell.label.text = row.label
        cell.labelEntry.text = row.entry


        return cell
    }
}

// MARK: - UITableViewDelegate

extension SingleSignatureViewController: UITableViewDelegate { }

extension SingleSignatureViewController: NewSignatureDelegate {
    func didCreateSignature(_ signature: Signature) { }  // not used here

    func didUpdateSignature(_ updated: Signature) {
        self.signature = updated
        contentSections.removeAll()
        buildSections()
        tableView.reloadData()
        onSignatureUpdated?(updated)
    }
}
