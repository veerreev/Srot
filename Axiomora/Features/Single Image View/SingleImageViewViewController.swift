//
//  SingleImageViewViewController.swift
//  Axiomora
//
//  Created by geu on 17/03/26.
//

import UIKit

class SingleImageViewViewController: UIViewController {
    
    @IBOutlet var timeSubtitleLabel: UILabel!
    @IBOutlet var dateTitleLabel: UILabel!
    @IBOutlet var customTitleView: UIView!
    @IBOutlet var shareButtonItem: UIBarButtonItem!
    @IBOutlet var trashButtonItem: UIBarButtonItem!
    @IBOutlet var filmstripCollectionView: UICollectionView!
    @IBOutlet var toolbar: UIToolbar!
    @IBOutlet var fluidBackgroundView: FluidBackgroundView!
    @IBOutlet weak var signatureNumberButton: UIBarButtonItem!
    
    // Set by whoever presents this VC before it appears.
    // CameraViewController sets startingIndex to the last captured image.
    // AllPhotosViewController sets it to the tapped cell's index.
    var images: [Image] = []
    var startingIndex: Int = 0
        
    // The embedded page view controller manages swiping between full screen images.
    private var pageVC: SingleImagePageViewController?
        
    // Tracks the currently visible image
    // Kept in sync with pageVC via the delegate.
    private var currentIndex: Int = 0
        
        
    // Tracks whether the chrome is currently visible.
    private var isChromeVisible: Bool = true
        
    // This object syncs the screen's transition with the user's finger
    private var interactor: UIPercentDrivenInteractiveTransition?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        currentIndex = startingIndex
        setupPageViewController()
        registerFilmstrip()
        updateTitle(for: startingIndex)
        showEmptyState()
        navigationItem.titleView = customTitleView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(!isChromeVisible, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.delegate = self
    }

    private func setupPageViewController() {
        let pvc = SingleImagePageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pvc.images = images
        pvc.pageChangeDelegate = self
            
        // Embed as a child view controller filling the entire screen.
        // Inserted at index 0 so all chrome views stay on top of it.
        addChild(pvc)
        pvc.view.frame = view.bounds
        pvc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(pvc.view, at: 0)
        pvc.didMove(toParent: self)
            
        pvc.showImage(at: startingIndex, animated: false)
        pageVC = pvc
    }
        
    private func registerFilmstrip() {
                       
        filmstripCollectionView.register(UINib(nibName: "FilmstripCell", bundle: nil), forCellWithReuseIdentifier: FilmstripCell.reuseIdentifier)
                
        scrollFilmstrip(to: startingIndex, animated: false)
    }
        
    // Shows the nav bar, filmstrip and toolbar together with a fade-in,
    private func showChrome() {
        guard !isChromeVisible else { return }
        isChromeVisible = true
                
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        UIView.animate(withDuration: 0.25) {
            self.filmstripCollectionView.alpha = 1
            self.toolbar.alpha = 1
        }
    }
            
    private func hideChrome() {
        guard isChromeVisible else { return }
        isChromeVisible = false
                
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        UIView.animate(withDuration: 0.25) {
            self.filmstripCollectionView.alpha = 0
            self.toolbar.alpha = 0
        }
    }
        
    private func updateTitle(for index: Int) {
        guard images.indices.contains(index),
        let date = images[index].createdAt else {
            dateTitleLabel.text = ""
            timeSubtitleLabel.text = ""
            return
        }
            
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)
        
        let datePart: String
        if calendar.isDateInToday(date) {
            datePart = "Today"
        } else if calendar.isDateInYesterday(date) {
            datePart = "Yesterday"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM yyyy"
            datePart = dateFormatter.string(from: date)
        }
            
        // Just hand the strings to your Storyboard labels!
        dateTitleLabel.text = datePart
        timeSubtitleLabel.text = timeString
    }
    
    private func scrollFilmstrip(to index: Int, animated: Bool) {
        guard images.indices.contains(index) else { return }
        filmstripCollectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally,animated: animated)
    }
    
    private func showEmptyState(animated: Bool = false) {
            let isEmpty = images.isEmpty
            
            // Group all the visibility changes together
            let stateChanges = {
                self.fluidBackgroundView.isHidden = !isEmpty
                self.toolbar.isHidden = isEmpty
                self.filmstripCollectionView.isHidden = isEmpty
                self.pageVC?.view.isHidden = isEmpty
            }
            
            // Perform the changes with or without animation
            if animated {
                UIView.transition(with: self.view, duration: 0.3, options: .transitionCrossDissolve, animations: stateChanges, completion: nil)
            } else {
                stateChanges()
            }
            
            if isEmpty {
                updateTitle(for: -1)
            }
        }
    
    @IBAction func shareTapped(_ sender: UIBarButtonItem) {
        guard images.indices.contains(currentIndex), let fileURL = images[currentIndex].localFileURL else { return }
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        present(activityVC, animated: true)
    }
                
        
    @IBAction func trashTapped(_ sender: UIBarButtonItem) {
        guard images.indices.contains(currentIndex) else { return }
                    
            let alert = UIAlertController(title: "Delete Photo", message: "This photo will be permanently deleted from Axiomora.", preferredStyle: .actionSheet)
                
            alert.addAction(UIAlertAction(title: "Delete Photo", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                    
            PhotoManager.shared.deleteImage(self.images[self.currentIndex])
            self.images = PhotoManager.shared.allImages()
                    
            if self.images.isEmpty {
                self.showEmptyState(animated: true)
            } else {
                let newIndex = min(self.currentIndex, self.images.count - 1)
                self.currentIndex = newIndex
                self.pageVC?.images = self.images
                self.pageVC?.showImage(at: newIndex, animated: false)
                self.filmstripCollectionView.reloadData()
                self.scrollFilmstrip(to: newIndex, animated: false)
                self.updateTitle(for: newIndex)
            }
        })
                    
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = sender
        }
                
        present(alert, animated: true)
    }
    
    
    @IBAction func handleMainTap(_ sender: Any) {
        guard !images.isEmpty else { return }
        if isChromeVisible {
                hideChrome()
            } else {
                showChrome()
            }
    }
    
    
    @IBAction func handlePan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        let verticalMovement = translation.y / view.bounds.height
        let progress = max(0.0, min(1.0, verticalMovement))

        let pageVC = self.children.first(where: { $0 is SingleImagePageViewController })

        switch sender.state {
            case .began:
                interactor = UIPercentDrivenInteractiveTransition()
                // Natively animate the nav bar away in perfect sync with the pull-down
                self.navigationController?.setNavigationBarHidden(true, animated: true)
                self.navigationController?.popViewController(animated: true)
                    
            case .changed:
                interactor?.update(progress)
                    
                // 1:1 Finger Tracking
                let scale = max(0.6, 1.0 - (progress * 0.5))
                pageVC?.view.transform = CGAffineTransform(translationX: translation.x, y: translation.y).scaledBy(x: scale, y: scale)
                    
            case .ended, .cancelled:
                let velocity = sender.velocity(in: view)
                let isDismissing = progress > 0.25 || velocity.y > 300
                            
                if isDismissing {
                    interactor?.finish()
                } else {
                    interactor?.cancel()
                    // Bring the nav bar back safely if the user cancels the swipe
                    self.navigationController?.setNavigationBarHidden(false, animated: true)
                }
                    
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                    if isDismissing {
                        let finalY = self.view.bounds.height
                        let finalX = translation.x + (velocity.x * 0.2)
                        pageVC?.view.transform = CGAffineTransform(translationX: finalX, y: finalY).scaledBy(x: 0.6, y: 0.6)
                    } else {
                        pageVC?.view.transform = .identity
                    }
                })
                    
                interactor = nil
                    
            default:
                break
        }
    }
    // Called when popping back from the Gallery to instantly update the screen
    func updateToDisplayImage(at index: Int, with newImages: [Image]) {
        self.images = newImages
        self.currentIndex = index
        self.startingIndex = index
            
        // Force the UI to immediately reflect the new image
        if let pageVC = self.pageVC {
            pageVC.images = newImages
            pageVC.showImage(at: index, animated: false)
            updateTitle(for: index)
            filmstripCollectionView.reloadData()
                
            // A slight delay ensures the collection view layout finishes before scrolling
            Task { @MainActor in
                // explicitly yield to the runloop to guarantee the layout pass finishes
                await Task.yield()
                self.scrollFilmstrip(to: index, animated: false)
            }
        }
    }
    
    // MARK: - Signature Preview

    @IBAction func signatureNumberTapped(_ sender: UIBarButtonItem) {
        guard images.indices.contains(currentIndex) else { return }
        performSegue(withIdentifier: "showSignaturePreview", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSignaturePreview",
           let previewVC = segue.destination as? SignaturePreviewViewController,
           images.indices.contains(currentIndex) {

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let image = images[currentIndex]
            let signatures = SignatureManager.shared.loadSignatures()
            
            previewVC.image = image

            if let matchedSig = signatures.first(where: { $0.id == image.signatureId }),
               let matchedIndex = signatures.firstIndex(where: { $0.id == image.signatureId }) {
                previewVC.signature = matchedSig
                previewVC.signatureIndex = matchedIndex
                previewVC.delegate = self
            }
            // If no match, previewVC.signature stays nil → shows the "deleted" message

            if let sheet = previewVC.sheetPresentationController {
                let detentHeight: CGFloat = previewVC.signature != nil ? 690 : 240
                let cardDetent = UISheetPresentationController.Detent.custom(
                    identifier: .init("signatureCard")
                ) { _ in
                    return detentHeight
                }
                sheet.detents = [cardDetent]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 56
            }
        }
    }
        
}

// Called by SingleImagePageViewController when the user swipes to a new image.
// Updates all chrome elements to reflect the newly visible image.
extension SingleImageViewViewController: SingleImagePageChangeDelegate {
        
    func pageDidChange(to index: Int) {
        currentIndex = index
        updateTitle(for: index)
        scrollFilmstrip(to: index, animated: true)
        filmstripCollectionView.reloadData()
        showChrome()
    }
        
}

extension SingleImageViewViewController: UICollectionViewDataSource {
        
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
        
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilmstripCell.reuseIdentifier,for: indexPath) as!FilmstripCell
            
        cell.configure(with: images[indexPath.item], isSelected: indexPath.item == currentIndex)
        return cell
    }
        
}

extension SingleImageViewViewController: UICollectionViewDelegate {
        
    // Tapping a filmstrip cell jumps the page VC to that image and syncs all chrome elements to the new current image.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item != currentIndex else { return }
        currentIndex = indexPath.item
        pageVC?.showImage(at: currentIndex, animated: true)
        updateTitle(for: currentIndex)
        scrollFilmstrip(to: currentIndex, animated: true)
        collectionView.reloadData()
        showChrome()
    }
        
}

//Custom Transitions
extension SingleImageViewViewController: UINavigationControllerDelegate {
    
    //Tell the nav controller to use our custom Slide Down animation instead of the default sideways pop
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .pop && fromVC === self {
            return SlideDownAnimator()
        }
        return nil
    }

    //Attach our finger-tracking interactor to the animation
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactor
    }
    //The actual animation that pushes the screen down
    class SlideDownAnimator: NSObject, UIViewControllerAnimatedTransitioning {
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.3
        }

        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let fromVC = transitionContext.viewController(forKey: .from) as? SingleImageViewViewController, let fromView = transitionContext.view(forKey: .from), let toView = transitionContext.view(forKey: .to) else { transitionContext.completeTransition(false)
                return
            }

            let containerView = transitionContext.containerView
            containerView.insertSubview(toView, belowSubview: fromView)

            let originalBackgroundColor = fromView.backgroundColor

            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: .curveEaseOut, animations: {
                
                fromView.backgroundColor = .clear
                fromVC.toolbar?.alpha = 0
                fromVC.filmstripCollectionView?.alpha = 0

                // NEW: Only let the animator handle the image movement if this was a BUTTON click (!isInteractive).
                // If it IS interactive, our handlePan gesture is already doing the math!
                if !transitionContext.isInteractive {
                    let translation = CGAffineTransform(translationX: 0, y: containerView.bounds.height)
                    let scale = CGAffineTransform(scaleX: 0.6, y: 0.6)
                    
                    if let pageView = fromVC.children.first(where: { $0 is SingleImagePageViewController })?.view {
                        pageView.transform = translation.concatenating(scale)
                    }
                }

            }, completion: { _ in
                let cancelled = transitionContext.transitionWasCancelled
                
                if cancelled {
                    fromView.backgroundColor = originalBackgroundColor
                    fromVC.toolbar?.alpha = 1
                    fromVC.filmstripCollectionView?.alpha = 1
                    
                    if let pageView = fromVC.children.first(where: { $0 is SingleImagePageViewController })?.view {
                        pageView.transform = .identity
                    }
                }
                transitionContext.completeTransition(!cancelled)
            })
        }
    }
}



// MARK: - Gesture Protections
extension SingleImageViewViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            
            // NEW: If the other gesture is our Double Tap, absolutely do NOT run simultaneously.
            // We want them to be mutually exclusive.
            if let tap = otherGestureRecognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                return false
            }
            
            // 1. We STILL want the Tap Gesture (to hide/show chrome) to work alongside scroll/pan gestures
            if gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer {
                return true
            }
            
            // 2. CRITICAL FIX: Force Pan Gestures (our vertical drag vs the Page View's horizontal swipe) to be mutually exclusive.
            return false
        }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: view)
            
            // 3. Only claim the gesture if the user is pulling DOWN, and doing so more vertically than horizontally.
            // If they swipe horizontally, this returns false, letting the Page View comfortably take over.
            return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // We only want to restrict the Tap Gesture
        if gestureRecognizer is UITapGestureRecognizer {
            
            // Find out exactly which view the user's finger touched
            if let touchedView = touch.view {
                
                // If they touched inside the filmstrip OR the toolbar, ignore the tap gesture!
                if touchedView.isDescendant(of: filmstripCollectionView) || touchedView.isDescendant(of: toolbar) {
                    return false // Let the tap pass through to the collection view cell
                }
            }
        }
        
        // For all other touches (like tapping the main image), allow the gesture to work
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // If our main gesture is a tap, and it encounters another tap gesture that requires 2 taps (our double tap)...
            if gestureRecognizer is UITapGestureRecognizer,
               let otherTap = otherGestureRecognizer as? UITapGestureRecognizer,
               otherTap.numberOfTapsRequired == 2 {
                // ...force the single tap to wait and fail if the double tap succeeds!
                return true
            }
            return false
        }
}

// MARK: - SignaturePreviewDelegate

extension SingleImageViewViewController: SignaturePreviewDelegate {

    func signaturePreview(
        _ vc: SignaturePreviewViewController,
        didTapSignature signature: Signature
    ) {
        // Dismiss the sheet, then push SingleSignatureViewController onto the existing nav stack
        vc.dismiss(animated: true) { [weak self] in
            let storyboard = UIStoryboard(name: "SignaturesStoryboard", bundle: nil)
            let singleSigVC = storyboard.instantiateViewController(
                withIdentifier: "SingleSignatureViewController"
            ) as! SingleSignatureViewController
            singleSigVC.signature = signature

            // Without this closure, NewSignatureTableViewController calls didUpdateSignature
            // which updates SingleSignatureVC's in-memory copy — so the UI temporarily looks
            // correct — but nothing writes to disk. The edit vanishes the next time the
            // signature is reloaded from disk. This closure is the missing link.
            singleSigVC.onSignatureUpdated = { updated in
                var all = SignatureManager.shared.loadSignatures()
                if let idx = all.firstIndex(where: { $0.id == updated.id }) {
                    all[idx] = updated
                    SignatureManager.shared.saveSignatures(all)
                    for sign in all {
                        Task { await SignatureManager.shared.syncNewSignature(sign) }
                    }
                }
            }

            self?.navigationController?.pushViewController(singleSigVC, animated: true)
        }
    }
}
