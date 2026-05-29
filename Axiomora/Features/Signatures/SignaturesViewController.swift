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
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!

    private var signatures: [Signature] = []
    private var currentCenteredIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        signatures = SignatureManager.shared.loadSignatures()

        // If there's exactly one signature and nothing is marked current auto select it the app requires at least one selection at all times.
        autoSelectIfNeeded()

        collectionView.register(
            UINib(nibName: "SignatureCell", bundle: nil),
            forCellWithReuseIdentifier: "SignatureCell"
        )
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - UI Setup

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

        section.visibleItemsInvalidationHandler = { [weak self] visibleItems, scrollOffset, layoutEnvironment in
            guard let self else { return }

            let containerWidth = layoutEnvironment.container.effectiveContentSize.width
            let centerX = scrollOffset.x + containerWidth / 2.0

            guard let centeredItem = visibleItems.min(by: {
                abs($0.frame.midX - centerX) < abs($1.frame.midX - centerX)
            }) else { return }

            let newIndex = centeredItem.indexPath.item
            guard newIndex != self.currentCenteredIndex else { return }

            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
            
            self.currentCenteredIndex = newIndex

            // Update the select button every time the centred card changes.
            self.updateSelectButtonVisibility()
        }

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func updateEmptyState() {
        let isEmpty = signatures.isEmpty
        emptySignaturesStackView.isHidden = !isEmpty
        deleteButton.isHidden = signatures.count <= 1
        collectionView.isHidden = isEmpty

        updateSelectButtonVisibility()
    }
    
    private func updateSelectButtonVisibility() {
        guard !signatures.isEmpty,
              currentCenteredIndex < signatures.count else {
            selectButton.isHidden = true
            return
        }
        
        let shouldShow = !signatures[currentCenteredIndex].isCurrent && signatures.count > 1
        
        #warning("Learn animate")
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.selectButton.alpha = shouldShow ? 1 : 0
            self.selectButton.transform = shouldShow ? .identity : CGAffineTransform(translationX: 0, y: 8)
        }
    }

    // Ensures that exactly one signature is marked as current whenever the list is non-empty. Saves to disk only when a change is actually made.
    private func autoSelectIfNeeded() {
        guard !signatures.isEmpty else { return }

        // If no signature is selected yet, select the first one.
        let noneSelected = signatures.allSatisfy { !$0.isCurrent }
        if noneSelected {
            signatures[0].isCurrent = true
            SignatureManager.shared.saveSignatures(signatures)
            AuthManager.shared.uploadSignature(signatures[0])
        }
    }

    // MARK: - Navigation

    private func launchNewSignatureViewController(sourceView: UIView?) {
        let storyboard = UIStoryboard(name: "NewSignatureStoryboard", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController

        if let newSigVC = navController.viewControllers.first as? NewSignatureTableViewController {
            newSigVC.delegate = self
        }

        navController.preferredTransition = .zoom(options: .init()) { _ in sourceView }

        present(navController, animated: true)
    }

    // MARK: - Actions

    @IBAction func addButtonTapped(_ sender: Any) {
        let source = addBarButtonItem.value(forKey: "view") as? UIView
        launchNewSignatureViewController(sourceView: source)
    }

    @IBAction func createNewSignatureTapped(_ sender: UIButton) {
        launchNewSignatureViewController(sourceView: sender)
    }

    @IBAction func deleteButtonTapped(_ sender: Any) {
        let alert = UIAlertController(
            title: "Delete Signature?",
            message: "You will not be able to extract information from the images which contain this signature.",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Delete Signature", style: .destructive) { [weak self] _ in
            self?.deleteCurrentSignature()
        })
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = deleteButton
        }

        present(alert, animated: true)
    }

    private func deleteCurrentSignature() {
        let indexToDelete = currentCenteredIndex
        guard indexToDelete < signatures.count else { return }

        signatures.remove(at: indexToDelete)
        SignatureManager.shared.saveSignatures(signatures)
        // Deletion is local-only — surviving signatures are already on the server.
        // If you add a DELETE /signatures/{uuid} endpoint later, call it here.

        collectionView.deleteItems(at: [IndexPath(item: indexToDelete, section: 0)])

        currentCenteredIndex = min(indexToDelete, max(0, signatures.count - 1))

        autoSelectIfNeeded()

        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard let cell = collectionView.cellForItem(at: indexPath) as? SignatureCell else { return }
            cell.setAsCurrentSignature(indexPath.item == currentCenteredIndex && signatures[indexPath.item].isCurrent)
            cell.numberLabel.text = "\(indexPath.item + 1)"
        }

        updateEmptyState()
    }
    
    @IBAction func setAsCurrentTapped(_ sender: Any) {
        guard currentCenteredIndex < signatures.count else { return }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        
        // Deselect all, then select the centred one.
        for i in signatures.indices {
            signatures[i].isCurrent = (i == currentCenteredIndex)
        }
        SignatureManager.shared.saveSignatures(signatures)
        // isCurrent is device-local state — the server does not need to know about it.

        // Refresh visible cells.
        collectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard let cell = collectionView.cellForItem(at: indexPath) as? SignatureCell else { return }
            cell.setAsCurrentSignature(indexPath.item == currentCenteredIndex)
        }

        updateSelectButtonVisibility()
    }
}

// MARK: - UICollectionViewDataSource

extension SignaturesViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        signatures.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SignatureCell", for: indexPath) as! SignatureCell
        cell.configure(with: signatures[indexPath.item], index: indexPath.item)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension SignaturesViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "SignaturesStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SingleSignatureViewController") as! SingleSignatureViewController
        vc.signature = signatures[indexPath.item]
        
        vc.onSignatureUpdated = { [weak self] updated in
            guard let self else { return }
            self.signatures[indexPath.item] = updated
            SignatureManager.shared.saveSignatures(self.signatures)
            // Sync only the updated signature — its profile fields may have changed.
            AuthManager.shared.uploadSignature(signatures[0])
            self.collectionView.reloadItems(at: [indexPath])
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? SignatureCell else { return }
        cell.layoutIfNeeded()           // forces Auto Layout to resolve subview frames NOW
        cell.buildSocialStackIfNeeded() // measures socialStack1.bounds.width — now accurate
    }
}

// MARK: - NewSignatureDelegate

extension SignaturesViewController: NewSignatureDelegate {
    
    func didUpdateSignature(_ signature: Signature) {
        // Find the existing signature by id and replace it in the local array.
        guard let index = signatures.firstIndex(where: { $0.id == signature.id }) else { return }
        signatures[index] = signature
        SignatureManager.shared.saveSignatures(signatures)
        // Push the updated profile to the server so verifiers see the new data.
        AuthManager.shared.uploadSignature(signature)
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }

    func didCreateSignature(_ signature: Signature) {
        let isFirstSignature = signatures.isEmpty

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        var newSignature = signature

        // The very first signature a user creates must be auto-selected
        // because the app always requires at least one current signature.
        if isFirstSignature {
            newSignature.isCurrent = true
        }

        signatures.append(newSignature)
        SignatureManager.shared.saveSignatures(signatures)
        AuthManager.shared.uploadSignature(signature)

        let newIndex = IndexPath(item: signatures.count - 1, section: 0)
        collectionView.insertItems(at: [newIndex])

        updateEmptyState()

        if isFirstSignature && OnboardingManager.shared.isOnboardingActive {
            OnboardingManager.shared.completeOnboarding()

            let storyboard = UIStoryboard(name: "OnboardingSignatureStoryboard", bundle: nil)
            
            guard let viewController = storyboard.instantiateInitialViewController() else {
                print("Error: Could not instantiate the OnboardingSignatureStoryboard")
                return
            }
            
            viewController.modalTransitionStyle = .coverVertical
            viewController.modalPresentationStyle = .fullScreen
            present(viewController, animated: true)
        }
    }
}
