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
                guard let image = imageView.image else { return }
        
                let report = await WatermarkDecoder.shared.decodeWithHashFallback(image)
        
                self.fluidBackgroundView.stopVerifyingAnimation()
                self.scannerOverlayView.stopScanning()
                self.verifyButton.isEnabled = true
        
                self.presentVerificationResult(report)
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
    
    // MARK: - Verification Result
    
    private func presentVerificationResult(_ report: VerificationReport) {

        let storyboard = UIStoryboard(name: "SingleImageViewStoryboard", bundle: nil)
        guard let previewVC = storyboard.instantiateViewController(
            withIdentifier: "SignaturePreviewViewController"
        ) as? SignaturePreviewViewController else { return }

        // Card is never tappable from the verify flow
        previewVC.isCardTappable = false

        switch report.status {

        case .authentic, .tampered:
            if let sig = report.matchedSignature {
                let all = SignatureManager.shared.loadSignatures()
                previewVC.signature     = sig
                previewVC.signatureIndex = all.firstIndex(where: { $0.id == sig.id }) ?? 0
            }
            // If matchedSignature is nil despite a watermark being found, fall through to
            // the default empty-state strings (extremely unlikely, but safe).

        case .noWatermarkFound:
            // Leave signature = nil so the empty-state path is taken
            previewVC.emptyTitle = "No Signature Found"
            previewVC.emptyBody  = "This image does not appear to contain an embedded signature."
        }

        let hasCard = report.matchedSignature != nil && report.status != .noWatermarkFound
        let detentHeight: CGFloat = hasCard ? 690 : 240

        if let sheet = previewVC.sheetPresentationController {
            let cardDetent = UISheetPresentationController.Detent.custom(
                identifier: .init("verifyResultCard")
            ) { _ in detentHeight }
            sheet.detents            = [cardDetent]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 56
        }

        present(previewVC, animated: true)
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
