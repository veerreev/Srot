//
//  AllPhotosViewController.swift
//  Axiomora
//
//  Created by geu on 16/03/26.
//

import UIKit

class AllPhotosViewController: UIViewController {
    
    @IBOutlet var collectionView: UICollectionView!
    
    @IBOutlet var fluidBackgroundView: FluidBackgroundView!
    var images: [Image] = []
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.images = PhotoManager.shared.allImages()
        
        fluidBackgroundView.isHidden = !images.isEmpty
        
        self.collectionView.reloadData()
    }
    

    @IBAction func openCameraTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "CameraStoryboard", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController
        
        navController.preferredTransition = .crossDissolve
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true)
    }
}

extension AllPhotosViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoGridCell", for: indexPath) as? PhotoGridCell else {
            return UICollectionViewCell()
        }
        
        let imageModel = images[indexPath.row]
        cell.configure(with: imageModel)
        
        return cell
    }
}

extension AllPhotosViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 1
        let totalSpacing = spacing * 2
        
        let width = (collectionView.bounds.width - totalSpacing) / 3
        
        return CGSize(width: width, height: width)
    }
}

extension AllPhotosViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let navController = navigationController else { return }
        
        // 1. Look back down the stack to find the existing Single Image View
        if let singleImageVC = navController.viewControllers.first(where: { $0 is SingleImageViewViewController }) as? SingleImageViewViewController {
            
            // 2. Hand it the fresh data and the exact image index you just tapped
            singleImageVC.updateToDisplayImage(at: indexPath.row, with: self.images)
            
            // 3. Pop the Gallery completely off the stack, revealing the updated Single Image screen!
            navController.popToViewController(singleImageVC, animated: true)
        }
    }
}
