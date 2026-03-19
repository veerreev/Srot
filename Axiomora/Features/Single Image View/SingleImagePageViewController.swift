//
//  SingleImagePageViewController.swift
//  Axiomora
//
//  Created by geu on 17/03/26.
//

import UIKit

// Implemented by SingleImageViewViewController to keep the filmstrip in sync.
protocol SingleImagePageChangeDelegate: AnyObject {
    func pageDidChange(to index: Int)
}

class SingleImagePageViewController: UIPageViewController {

    var images: [Image] = [] // The full array of images to page through.
    // Set by SingleImageViewViewController before this VC appears.
        
    private(set) var currentIndex: Int = 0 // The index of the image currently visible on screen.
    // Updated every time the user swipes to a new page.
        
    weak var pageChangeDelegate: SingleImagePageChangeDelegate? // Notifies SingleImageViewViewController when the page changes so the filmstrip can stay in sync.
        
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black //SingleImagePageViewController has no storyboard scene of its own, it's created and embedded entirely in code by SingleImageViewViewController.
        dataSource = self
        delegate = self
    }
        
    // Called by SingleImageViewViewController to show a specific image.
    // Used both on first appearance and when the user taps a filmstrip cell.
    func showImage(at index: Int, animated: Bool = false) {
        guard images.indices.contains(index) else { return }
            
        currentIndex = index
            
        let zoomVC = makeZoomVC(for: index)
            
        setViewControllers(
            [zoomVC],
            direction: .forward, // Direction doesn't matter for the initial display or filmstrip taps. Forward is used as a neutral default.
            animated: animated,
            completion: nil
        )
    }
        
    // Creates a SingleImageZoomViewController for a given index.
    // UIPageViewController calls this via the dataSource methods when it needs the next or previous page.
    private func makeZoomVC(for index: Int) -> SingleImageZoomViewController {
        let storyboard = UIStoryboard(name: "SingleImageZoom", bundle: nil)
        guard let zoomVC = storyboard.instantiateViewController(
            withIdentifier: "SingleImageZoomViewController"
        ) as? SingleImageZoomViewController else {
            fatalError("SingleImageZoom storyboard missing SingleImageZoomViewController")
        }
        zoomVC.image = images[index]
        zoomVC.pageIndex = index
        return zoomVC
    }
        
}

// Provides the previous and next pages when the user swipes.
extension SingleImagePageViewController: UIPageViewControllerDataSource {
        
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let zoomVC = viewController as? SingleImageZoomViewController else { return nil }
        let previousIndex = zoomVC.pageIndex - 1
        guard previousIndex >= 0 else { return nil }
        return makeZoomVC(for: previousIndex)
    }
        
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let zoomVC = viewController as? SingleImageZoomViewController else { return nil }
        let nextIndex = zoomVC.pageIndex + 1
        guard nextIndex < images.count else { return nil }
        return makeZoomVC(for: nextIndex)
    }
        
}

// Called after a swipe completes
// Updates currentIndex and notifies SingleImageViewViewController to sync the filmstrip.
extension SingleImagePageViewController: UIPageViewControllerDelegate {
        
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let zoomVC = pageViewController.viewControllers?.first as? SingleImageZoomViewController else { return }
            
        currentIndex = zoomVC.pageIndex
        pageChangeDelegate?.pageDidChange(to: currentIndex)
    }
        
}
