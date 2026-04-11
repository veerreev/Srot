//
//  VerifyViewController.swift
//  Axiomora
//
//  Created by Veer on 05/04/26.
//

import UIKit
import PhotosUI

class VerifyViewController: UIViewController {

    @IBOutlet weak var uploadVisualEffectBackground: UIVisualEffectView!
    @IBOutlet weak var uploadViewBackground: UIView!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var plusImage: UIImageView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var infoMessageLabel: UILabel!
    @IBOutlet weak var imageViewAspectRatio: NSLayoutConstraint!
    @IBOutlet weak var trashBarItem: UIBarButtonItem!
    
    private var isImageSelected: Bool = false
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    private func setupUI() {
        
        Theme.Button.applyGlassStyle(to: verifyButton, title: "Verify", color: .systemBlue)

    }
    
    private func presentImagePicker() {
        
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func animateBlink(on view: UIImageView, completion: @escaping () -> Void) {
        
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut], animations: {
            view.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseIn], animations: {
                view.alpha = 1.0
            }) { _ in
                completion()
            }
        }
    }
    
    @IBAction func verifyButtonTapped(_ sender: Any) {
        if !isImageSelected {
            infoMessageLabel.shake()
        }
    }
    
    @IBAction func uploadViewTapped(_ sender: UITapGestureRecognizer) {
        animateBlink(on: plusImage) { [weak self] in
            self?.presentImagePicker()
        }
    }

    @IBAction func deleteButtonTapped(_ sender: Any) {
        
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut], animations: {
            self.uploadVisualEffectBackground.isHidden = false
            self.imageView.isHidden = true
        })
        
        imageView.image = nil
        trashBarItem.isHidden = true
        verifyButton.isEnabled = false
        
    }
}

extension VerifyViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
        
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                return
            }
            
            guard let self = self, let selectedImage = image as? UIImage else { return }
            
            #warning("Replace with Task")
            DispatchQueue.main.async {
                self.isImageSelected = true
                self.handleSelectedImage(selectedImage)
                picker.dismiss(animated: true)
            }
        }
    }
    
    private func handleSelectedImage(_ image: UIImage) {
        
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut], animations: {
            self.uploadVisualEffectBackground.isHidden = true
            self.imageView.isHidden = false
        })
        
        verifyButton.isEnabled = true
        trashBarItem.isHidden = false
        imageView.image =  image
        imageView.layer.borderColor = Theme.Colors.white.cgColor

    }
}
