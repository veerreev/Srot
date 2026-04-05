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
        setupGestures()
        loadImage()
    }
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews() // Called every time the view's bounds change including the first appearance.
        // Only recalculate if an image is loaded and scroll view has valid bounds.
        guard imageView.image != nil, scrollView.bounds.width > 0 else { return }
        updateMinZoomScale()
        centerImageInScrollView()
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
        
        let normalizedImage = uiImage.normalized()
        imageView.image = normalizedImage        
        // Set the imageView frame to the actual image size.
        // This is what makes the scroll view content the right size.
        imageView.frame = CGRect(origin: .zero, size: normalizedImage.size)
        scrollView.contentSize = normalizedImage.size
        
        updateMinZoomScale()
        centerImageInScrollView()
    }

    private func updateMinZoomScale() {
        guard let image = imageView.image else { return }
            
        let scrollSize = scrollView.bounds.size
        let imageSize  = image.size
            
        guard imageSize.width > 0, imageSize.height > 0, scrollSize.width > 0, scrollSize.height > 0 else { return }
            
        let widthScale  = scrollSize.width  / imageSize.width
        let heightScale = scrollSize.height / imageSize.height
        let minScale = min(widthScale, heightScale)
            
        scrollView.minimumZoomScale = minScale
            
        // NEW: Prevent infinite pinch-zooming by capping the max zoom.
        // max(1.0, ...) ensures that small images can still be zoomed up to their true size,
        // while massive images get capped at 4x their "fit" size.
        scrollView.maximumZoomScale = max(1.0, minScale * 4.0)
            
        scrollView.zoomScale = minScale
    }
        
    // When the image is smaller than the scroll view bounds (at minimum zoom), this keeps it centered rather than letting it sit at the top-left corner.
    // Called after every zoom change via scrollViewDidZoom.
    private func centerImageInScrollView() {
        let scrollSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
            
        let horizontalInset = max(0, (scrollSize.width  - contentSize.width)  / 2)
        let verticalInset = max(0, (scrollSize.height - contentSize.height) / 2)
            
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right:  horizontalInset)
    }
        
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // Add a small tolerance margin for the float comparison
        if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
            // Image is already zoomed in => animate back to fit.
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // Zoom in to a comfortable level: 3x the "fit on screen" size
            let targetScale = scrollView.minimumZoomScale * 2.0
                
            let tapPoint = gesture.location(in: imageView)
            let zoomRect = zoomRect(for: targetScale, centeredAt: tapPoint)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
        
    // Calculates the CGRect to pass to scrollView.zoom(to:) for a given scale and center point. The rectangle represents the portion of the image view that will fill the scroll view at the target zoom scale.
    private func zoomRect(for scale: CGFloat, centeredAt center: CGPoint) -> CGRect {
        let width  = scrollView.bounds.width  / scale
        let height = scrollView.bounds.height / scale
        return CGRect(x: center.x - (width / 2),y: center.y - (height / 2), width: width, height: height)
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
