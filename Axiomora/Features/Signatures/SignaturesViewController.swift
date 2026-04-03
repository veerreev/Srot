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
        
        signatures = SignatureManager.shared.loadSignatures()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            UINib(nibName: "SignatureCell", bundle: nil),
            forCellWithReuseIdentifier: "SignatureCell"
        
        )
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
        collectionView.setCollectionViewLayout(generateLayout(), animated: true)
        updateEmptyState()
        
    }
    
    private func generateLayout() -> UICollectionViewLayout {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.85), heightDimension: .fractionalHeight(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        
        section.interGroupSpacing = 16
        
        section.orthogonalScrollingBehavior = .groupPagingCentered
        
        return UICollectionViewCompositionalLayout(section: section)
        
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
        
        if let newSigVC = navController.viewControllers.first as? NewSignatureTableViewController {
            newSigVC.delegate = self
        }
        
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SignatureCell", for: indexPath) as! SignatureCell
        cell.configure(with: signatures[indexPath.item])
        return cell
    }
    
}

extension SignaturesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
}

extension SignaturesViewController: NewSignatureDelegate {
    
    func didCreateSignature(_ signature: Signature) {
        
        signatures.append(signature)
        
        let newIndex = IndexPath(item: signatures.count - 1, section: 0)
        collectionView.insertItems(at: [newIndex])
        updateEmptyState()
        
        SignatureManager.shared.saveSignatures(signatures)
    }
    
}
