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
    /// Connect this outlet in SignaturesStoryboard to the "Create New Signature"
    /// button inside emptySignaturesStackView.
    @IBOutlet weak var createNewSignatureButton: UIButton!

    private var signatures: [Signature] = []
    private var currentCenteredIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        signatures = SignatureManager.shared.loadSignatures()

        // If there's exactly one signature and nothing is marked current auto select it the app requires at least one selection at all times.
        autoSelectIfNeeded()

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            UINib(nibName: "SignatureCell", bundle: nil),
            forCellWithReuseIdentifier: "SignatureCell"
        )
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        refreshOnboardingState()
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

            self.currentCenteredIndex = newIndex

            // Update the select button every time the centred card changes.
            self.updateSelectButtonVisibility()
        }

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func updateEmptyState() {
        let isEmpty = signatures.isEmpty
        emptySignaturesStackView.isHidden = !isEmpty
        deleteButton.isHidden = isEmpty
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
        }
    }

    // MARK: - Onboarding

    private func refreshOnboardingState() {
        if OnboardingManager.shared.isOnboardingActive {
            applyOnboardingRestrictions()
        } else {
            removeOnboardingRestrictions()
        }
    }

    /// During onboarding only the "Create New Signature" button is active.
    /// Everything else is disabled so the user has exactly one thing to tap.
    private func applyOnboardingRestrictions() {
        // Disable the nav bar buttons
        addBarButtonItem.isEnabled = false
        deleteButton.isEnabled = false

        // The collection view is empty during onboarding so nothing to block there,
        // but disable selectButton for safety.
        selectButton.isEnabled = false

        // Find the create button: prefer the wired outlet, fall back to scanning
        // the empty-state stack view for the first UIButton.
        guard let createButton = createNewSignatureButton
                ?? emptySignaturesStackView.subviews.compactMap({ $0 as? UIButton }).first
        else { return }

        createButton.isEnabled = true
        createButton.alpha = 1.0

        // Pulsing shadow glow
        createButton.layer.masksToBounds = false
        createButton.layer.shadowColor = UIColor.systemBlue.cgColor
        createButton.layer.shadowOffset = .zero
        createButton.layer.shadowRadius = 8
        createButton.layer.shadowOpacity = 1.0

        let glow = CABasicAnimation(keyPath: "shadowRadius")
        glow.fromValue = 5
        glow.toValue = 18
        glow.duration = 0.85
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        createButton.layer.add(glow, forKey: "onboardingGlow")
    }

    private func removeOnboardingRestrictions() {
        addBarButtonItem.isEnabled = true
        deleteButton.isEnabled = true
        selectButton.isEnabled = true

        let createButton = createNewSignatureButton
            ?? emptySignaturesStackView.subviews.compactMap({ $0 as? UIButton }).first
        createButton?.layer.removeAnimation(forKey: "onboardingGlow")
        createButton?.layer.shadowOpacity = 0
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

        // Deselect all, then select the centred one.
        for i in signatures.indices {
            signatures[i].isCurrent = (i == currentCenteredIndex)
        }
        SignatureManager.shared.saveSignatures(signatures)

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
        
    }

    func didCreateSignature(_ signature: Signature) {
        let isFirstSignature = signatures.isEmpty

        var newSignature = signature

        // The very first signature a user creates must be auto-selected
        // because the app always requires at least one current signature.
        if isFirstSignature {
            newSignature.isCurrent = true
        }

        signatures.append(newSignature)
        SignatureManager.shared.saveSignatures(signatures)

        let newIndex = IndexPath(item: signatures.count - 1, section: 0)
        collectionView.insertItems(at: [newIndex])

        updateEmptyState()

        // ── Onboarding completion ────────────────────────────────────────────
        // The user has just created their very first signature.
        // Unlock the full app and send them back to the camera.
        if isFirstSignature && OnboardingManager.shared.isOnboardingActive {
            OnboardingManager.shared.completeOnboarding()

            let alert = UIAlertController(
                title: "You're all set! 🎉",
                message: "Your signature has been created. Head back to the camera — everything is now unlocked.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Go to Camera", style: .default) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            present(alert, animated: true)
        }
    }
}
