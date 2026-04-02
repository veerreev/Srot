//
//  SignaturesViewController.swift
//  Axiomora
//
//  Created by Veer on 26/03/26.
//

import UIKit

class SignaturesViewController: UIViewController {

    @IBOutlet weak var emptySignaturesStackView: UIStackView!
    @IBOutlet weak var addBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var selectButton: UIBarButtonItem!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var signatures: [Signature] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        let source = addBarButtonItem.value(forKey: "view") as? UIView
        launchNewSignatureViewController(sourceView: source)
    }
    
    @IBAction func createNewSignatureTapped(_ sender: UIButton) {
        launchNewSignatureViewController(sourceView: sender)
    }
    
    private func setupUI() {
        addBarButtonItem.style = .prominent
//        selectButton.style = .prominent
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        
        let isEmpty = signatures.isEmpty
        emptySignaturesStackView.isHidden = !isEmpty
        selectButton.isHidden = isEmpty
        editButton.isHidden = isEmpty
        collectionView.isHidden = isEmpty
        
    }
    
    private func launchNewSignatureViewController(sourceView: UIView?) {
        let storyboard = UIStoryboard(name: "NewSignatureStoryboard", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController
        
        navController.preferredTransition = .zoom(options: .init()) { context in
            sourceView
        }
        
        present(navController, animated: true)
    }
}

extension SignaturesViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return signatures.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        <#code#>
    }
    
}

extension SignaturesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
}
