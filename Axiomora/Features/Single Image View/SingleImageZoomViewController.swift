//
//  SingleImageZoomViewController.swift
//  Axiomora
//
//  Created by geu on 17/03/26.
//

import UIKit

class SingleImageZoomViewController: UIViewController {

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var scrollView: UIScrollView!
   
    var image: Image? // This is the single image this page is responsible for displaying.
    // Set by SingleImagePageViewController before this VC appears.
    
    var pageIndex: Int = 0
    // Set by SingleImagePageViewController so the page VC knows which index this page represents.
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupGestures()
        loadImage()
        }
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews() // Called every time the view's bounds change including the first appearance.
        // Recalculate zoom scale and centering each time so the image always fits correctly regardless of screen size or orientation.
        updateMinZoomScale()
        centerImageInScrollView()
    }
        
    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        // Prevents the scroll view from adding automatic insets for the nav bar, i.e it does not put a gap below the nav bar.
        // We want the image to go fully edge to edge including behind the nav bar.
        scrollView.contentInsetAdjustmentBehavior = .never
    }
        
    private func setupGestures() {
        // Double tap to zoom into the tapped point at 2x, or back out to fit.
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }
        
    private func loadImage() {
        guard let image = image, let fileURL = image.localFileURL, let uiImage = UIImage(contentsOfFile: fileURL.path) else {
            imageView.image = nil
            return
        }
        imageView.image = uiImage
        // Recalculate after the image is set so the zoom scale is based on the actual image dimensions.
        updateMinZoomScale()
        centerImageInScrollView()
    }
        
    // Calculates the zoom scale at which the image exactly fits the screen.
    // Sets this as both the minimum zoom scale and the starting zoom scale so the image is always fully visible on first appearance.
    private func updateMinZoomScale() {
        guard let image = imageView.image else { return }
            
        let scrollSize = scrollView.bounds.size
        let imageSize  = image.size
            
        guard imageSize.width > 0, imageSize.height > 0 else { return }
            
        let widthScale = scrollSize.width / imageSize.width
        let heightScale = scrollSize.height / imageSize.height
            
        // The smaller scale ensures the entire image is visible — aspect fit behaviour.
        let minScale = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale // This needs to be done programatically because this is dynamic
        scrollView.zoomScale = minScale
    }
        
    // When the image is smaller than the scroll view bounds (at minimum zoom), this keeps it centered rather than letting it sit at the top-left corner.
    // Called after every zoom change via scrollViewDidZoom.
    private func centerImageInScrollView() {
        let scrollSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
            
        let horizontalInset = max(0, (scrollSize.width  - contentSize.width)  / 2)
        let verticalInset   = max(0, (scrollSize.height - contentSize.height) / 2)
            
        scrollView.contentInset = UIEdgeInsets(
            top:    verticalInset,
            left:   horizontalInset,
            bottom: verticalInset,
            right:  horizontalInset
        )
    }
        
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // Image is already zoomed in => animate back to fit.
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // Zoom into the exact point the user double tapped, at 2x.
            let tapPoint = gesture.location(in: imageView)
            let zoomRect = zoomRect(for: 2.0, centeredAt: tapPoint)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
        
    // Calculates the CGRect to pass to scrollView.zoom(to:) for a given scale and center point. The rectangle represents the portion of the image view that will fill the scroll view at the target zoom scale.
    private func zoomRect(for scale: CGFloat, centeredAt center: CGPoint) -> CGRect {
        let width  = scrollView.bounds.width  / scale
        let height = scrollView.bounds.height / scale
        return CGRect(
            x:      center.x - (width  / 2),
            y:      center.y - (height / 2),
            width:  width,
            height: height
        )
    }
        
}

extension SingleImageZoomViewController: UIScrollViewDelegate {
        
    // Required — tells the scroll view which view to scale during pinch.
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
        
    // Called continuously as the user pinches.
    // Keeps the image centered throughout the zoom gesture.
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageInScrollView()
    }
        
}
