//
//  SingleImageViewViewController.swift
//  Axiomora
//
//  Created by geu on 17/03/26.
//

import UIKit

class SingleImageViewViewController: UIViewController {

    @IBOutlet var shareButtonItem: UIBarButtonItem!
    @IBOutlet var trashButtonItem: UIBarButtonItem!
    @IBOutlet var infoButtonItem: UIBarButtonItem!
    @IBOutlet var heartButtonItem: UIBarButtonItem!
    @IBOutlet var filmstripCollectionView: UICollectionView!
    @IBOutlet var toolbar: UIToolbar!
        
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
        
    // The date label set as navigationItem.titleView.
    // Created in code because it needs custom styling beyond what a standard title provides.
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        
        // Capsule background — matches Apple's camera date pill style
        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        
        // Padding inside the capsule
        label.layer.masksToBounds = true
        
        return label
    }()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        currentIndex = startingIndex
            
        setupNavigationBar()
        setupToolbar()
        setupPageViewController()
        setupFilmstrip()
        setupGestures()
        updateDateLabel(for: startingIndex)
        updateHeartButton(for: startingIndex)
        if images.isEmpty {
            showEmptyState()
        }
            
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
            
        // Restore opaque nav bar for the previous screen when navigating back.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
        
    private func setupNavigationBar() {
        // Transparent nav bar so the full screen image shows through behind it.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white
            
        // Date label as the navigation title — centered between back chevron and gallery button.
        navigationItem.titleView = dateLabel
    }
    
    private func setupToolbar() {
        let appearance = UIToolbarAppearance()
        appearance.configureWithTransparentBackground()
        toolbar.standardAppearance = appearance
        toolbar.compactAppearance = appearance
        toolbar.tintColor = .white
    }
        

        
    // MARK: - Page View Controller Setup
    private func setupPageViewController() {
        let pvc = SingleImagePageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
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
        
    // MARK: - Filmstrip Setup
    private func setupFilmstrip() {
        filmstripCollectionView.dataSource = self
        filmstripCollectionView.delegate = self
        filmstripCollectionView.backgroundColor = .clear
        filmstripCollectionView.showsHorizontalScrollIndicator = false
            
        filmstripCollectionView.register(
            UINib(nibName: "FilmstripCell", bundle: nil),
            forCellWithReuseIdentifier: FilmstripCell.reuseIdentifier
        )
            
        // Horizontal flow layout — cells scroll left and right.
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        filmstripCollectionView.collectionViewLayout = layout
            
        scrollFilmstrip(to: startingIndex, animated: false)
    }
        
    // MARK: - Gestures
    private func setupGestures() {
        // Single tap on the main area toggles chrome visibility.
        // The delegate allows this to coexist with the page VC's pan gesture.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMainTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
        
    // MARK: - Auto-Hide Chrome
    // Shows the nav bar, filmstrip and toolbar together with a fade-in,
    private func showChrome() {
        guard !isChromeVisible else { return }
        isChromeVisible = true
        UIView.animate(withDuration: 0.25) {
            self.navigationController?.navigationBar.alpha = 1
            self.filmstripCollectionView.alpha = 1
            self.toolbar.alpha = 1
        }
    }
            
    private func hideChrome() {
        guard isChromeVisible else { return }
        isChromeVisible = false
        UIView.animate(withDuration: 0.25) {
            self.navigationController?.navigationBar.alpha = 0
            self.filmstripCollectionView.alpha = 0
            self.toolbar.alpha = 0
        }
    }
        
    // MARK: - Gesture Handlers
    @objc private func handleMainTap() {
        if isChromeVisible {
            hideChrome()
        } else {
            showChrome()
        }
    }
        
    // MARK: - Helpers
    // Updates the date label in the nav bar title view to show
    // the capture date of the currently visible image.
    private func updateDateLabel(for index: Int) {
        guard images.indices.contains(index), let date = images[index].createdAt else {
            dateLabel.text = ""
            return
        }
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)
            
        if calendar.isDateInToday(date) {
            dateLabel.text = "Today, \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            dateLabel.text = "Yesterday, \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM yyyy"
            dateLabel.text = "\(dateFormatter.string(from: date)), \(timeString)"
        }
        dateLabel.sizeToFit()
        var frame = dateLabel.frame
        frame.size.width += 24
        frame.size.height = 28
        dateLabel.frame = frame
    }
        
    // Updates the heart button icon and tint to reflect the
    // current image's favourite state.
    private func updateHeartButton(for index: Int) {
        guard images.indices.contains(index) else { return }
        let isFavourite = images[index].isFavourite
        heartButtonItem.image = UIImage(systemName: isFavourite ? "heart.fill" : "heart")
        heartButtonItem.tintColor = isFavourite ? .systemRed : .white
    }
    
    private func scrollFilmstrip(to index: Int, animated: Bool) {
        guard images.indices.contains(index) else { return }
        filmstripCollectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally,animated: animated)
    }
    
    private func showEmptyState() {
        // Hide chrome elements that make no sense with no images.#imageLiteral(resourceName: "Screenshot 2026-03-19 at 11.14.59 AM.png")
        filmstripCollectionView.isHidden = true
        toolbar.isHidden = true
        
        // Show centred empty state label.
        let label = UILabel()
        label.text = "No Photos or Videos"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Toolbar Actions
    @IBAction func shareTapped(_ sender: UIBarButtonItem) {
        guard images.indices.contains(currentIndex), let fileURL = images[currentIndex].localFileURL else { return }
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        present(activityVC, animated: true)
    }
        
    @IBAction func heartTapped(_ sender: UIBarButtonItem) {
        guard images.indices.contains(currentIndex) else { return }
        PhotoManager.shared.toggleFavourite(images[currentIndex])
        // Refresh local array from PhotoManager after the toggle.
        images = PhotoManager.shared.allImages()
        updateHeartButton(for: currentIndex)
    }
        
    @IBAction func infoTapped(_ sender: UIBarButtonItem) {
        #warning("Info panel not yet implemented")
    }
        
    @IBAction func trashTapped(_ sender: UIBarButtonItem) {
        guard images.indices.contains(currentIndex) else { return }
            
        // Confirm before permanently deleting — matches native iOS behaviour.
        let alert = UIAlertController(
            title: "Delete Photo",
            message: "This photo will be permanently deleted from Axiomora.",
            preferredStyle: .actionSheet
        )
            
        alert.addAction(UIAlertAction(
            title: "Delete Photo",
            style: .destructive
        ) { [weak self] _ in
            guard let self = self else { return }
                
            PhotoManager.shared.deleteImage(self.images[self.currentIndex])
            self.images = PhotoManager.shared.allImages()
            
            if self.images.isEmpty {
                // No images left — pop back to camera.
                self.navigationController?.popViewController(animated: true)
            } else {
                // Adjust index if we deleted the last item in the array.
                let newIndex      = min(self.currentIndex, self.images.count - 1)
                self.currentIndex = newIndex
                self.pageVC?.images = self.images
                self.pageVC?.showImage(at: newIndex, animated: false)
                self.filmstripCollectionView.reloadData()
                self.scrollFilmstrip(to: newIndex, animated: false)
                self.updateDateLabel(for: newIndex)
                self.updateHeartButton(for: newIndex)
            }
        })
            
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
        
}

// MARK: - SingleImagePageChangeDelegate
// Called by SingleImagePageViewController when the user swipes to a new image.
// Updates all chrome elements to reflect the newly visible image.
extension SingleImageViewViewController: SingleImagePageChangeDelegate {
        
    func pageDidChange(to index: Int) {
        currentIndex = index
        updateDateLabel(for: index)
        updateHeartButton(for: index)
        scrollFilmstrip(to: index, animated: true)
        filmstripCollectionView.reloadData()
        showChrome()
    }
        
}

// MARK: - UICollectionViewDataSource
extension SingleImageViewViewController: UICollectionViewDataSource {
        
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
        
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilmstripCell.reuseIdentifier,for: indexPath) as!FilmstripCell
            
        cell.configure(
            with: images[indexPath.item],
            isSelected: indexPath.item == currentIndex
        )
        return cell
    }
        
}

// MARK: - UICollectionViewDelegate
extension SingleImageViewViewController: UICollectionViewDelegate {
        
    // Tapping a filmstrip cell jumps the page VC to that image
    // and syncs all chrome elements to the new current image.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        currentIndex = indexPath.item
        pageVC?.showImage(at: currentIndex, animated: true)
        updateDateLabel(for: currentIndex)
        updateHeartButton(for: currentIndex)
        scrollFilmstrip(to: currentIndex, animated: true)
        collectionView.reloadData()
        showChrome()
    }
        
}

// MARK: - UIGestureRecognizerDelegate
// Allows the single tap gesture and the page VC's pan gesture
// to be recognised simultaneously without conflicting.
extension SingleImageViewViewController: UIGestureRecognizerDelegate {
        
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
    }
