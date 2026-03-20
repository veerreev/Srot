import UIKit

class SignaturesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var signatures: [Signature] = []
    var selectedSignatureID: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        setupNavigationBar()
        loadData()
        
        tableView.backgroundColor = .clear
        view.backgroundColor = .black
        tableView.backgroundView = UIView()
        tableView.backgroundView?.backgroundColor = .black
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )

        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addSignatureTapped)
        )

        navigationItem.rightBarButtonItems = [settingsButton, addButton]
    }
}

//UI
extension SignaturesViewController {
    
    func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        
        tableView.register(
            UINib(nibName: "SignatureCellTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SignatureCellTableViewCell"
        )
    }
}

//loading mock data
extension SignaturesViewController {
    
    func loadData() {
        signatures = MockDataBase.shared.getSignatures()
        selectedSignatureID = signatures.first?.id
        tableView.reloadData()
    }
}

//TABLE
extension SignaturesViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        signatures.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "SignatureCellTableViewCell",
            for: indexPath
        ) as! SignatureCellTableViewCell
        
        let signature = signatures[indexPath.row]
        let isSelected = signature.id == selectedSignatureID
        
        cell.configure(
            with: signature,
            isSelected: isSelected,
            index: indexPath.row
        )
        
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 220
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedSignatureID = signatures[indexPath.row].id
        tableView.reloadData()
    }
}

//ACTIONS
extension SignaturesViewController {
    
    @objc func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func settingsTapped() {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SettingsViewController")
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func addSignatureTapped() {
        
        let storyboard = UIStoryboard(name: "AddEditSignatureStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddEditSignatureViewController") as! AddEditSignatureViewController
        
        vc.delegate = self
        
        navigationController?.pushViewController(vc, animated: true)
    }
}

//CELL DELEGATE
extension SignaturesViewController: SignatureCellDelegate {
    
    func didTapRadio(at index: Int) {
        let signature = signatures[index]
        selectedSignatureID = signature.id
        tableView.reloadData()
    }
    
    func didTapEdit(at index: Int) {
        let signature = signatures[index]
        
        let storyboard = UIStoryboard(name: "AddEditSignatureStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddEditSignatureViewController") as! AddEditSignatureViewController
        
        vc.existingSignature = signature
        vc.delegate = self
        
        navigationController?.pushViewController(vc, animated: true)
    }
}

//ADD/EDIT DELEGATE
extension SignaturesViewController: AddEditSignatureDelegate {
    
    func didSaveSignature(_ signature: Signature) {
        if let index = signatures.firstIndex(where: { $0.id == signature.id }) {
            signatures[index] = signature
        } else {
            signatures.append(signature)
        }
        tableView.reloadData()
    }
    
    func didDeleteSignature(_ id: String) {
        signatures.removeAll { $0.id == id }
        tableView.reloadData()
    }
}
