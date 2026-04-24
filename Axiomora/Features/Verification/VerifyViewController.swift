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
    @IBOutlet weak var verificationReportStatusLabel: UILabel!
    @IBOutlet weak var signatureIDLabel: UILabel!
    
    @IBOutlet weak var fluidBackgroundView: FluidBackgroundView!
    @IBOutlet weak var scannerOverlayView: ScannerOverlayView!
    
    private var isImageSelected: Bool = false
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
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
            return
        }
        
        verifyButton.isEnabled = false
        fluidBackgroundView.startVerifyingAnimation()
        scannerOverlayView.startScanning()

        Task { @MainActor in
            // Run the engine off the main thread so the animations aren't blocked.
            var verificationReport: VerificationReport?
            await Task.detached(priority: .userInitiated) {
                verificationReport = await WatermarkDecoder.shared.decode(self.imageView.image!)
            }.value

            self.fluidBackgroundView.stopVerifyingAnimation()
            self.scannerOverlayView.stopScanning()
            
            if verificationReport?.status == .authentic {
                verificationReportStatusLabel.isHidden = false
                signatureIDLabel.isHidden = false
                verificationReportStatusLabel.text = "Signature Found"
                verificationReportStatusLabel.textColor = .systemGreen
                signatureIDLabel.text = verificationReport?.extractedSignatureId
            } else {
                verificationReportStatusLabel.isHidden = false
                verificationReportStatusLabel.text = "Signature Not Found"
                verificationReportStatusLabel.textColor = .systemRed
                signatureIDLabel.isHidden = true
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                    self.verificationReportStatusLabel.alpha = 1
                    self.verificationReportStatusLabel.transform = CGAffineTransform(translationX: 0, y: 8)
                }
//                verificationReportStatusLabel.shake()
            }
            self.verifyButton.isEnabled = true
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
