//
//  CameraViewController.swift
//  Axiomora
//
//  Created by Veer on 06/03/26.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, CameraManagerDelegate {
    
    func cameraManager(_ manager: CameraManager, didCapture photo: UIImage) {
        
    }
    
    func cameraManager(_ manager: CameraManager, didFailWithError error: any Error) {
        
    }
    
    func cameraManagerWillProcessPhoto(_ manager: CameraManager) {
        
    }
    
    @IBOutlet weak var livePreviewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var livePreviewAspectRatioConstraint: NSLayoutConstraint!
    @IBOutlet weak var tabBar: UITabBar!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var livePreviewView: UIView!
    @IBOutlet weak var captureButtonBackground: UIVisualEffectView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var signatureNumberButton: UIButton!
    @IBOutlet weak var cameraControlPillVisualEffectView: CameraControlPill!
    
    private let cameraManager = CameraManager()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraManager.delegate = self
        cameraControlPillVisualEffectView.delegate = self
        setupUI()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let previewLayer = previewLayer {
            previewLayer.frame = livePreviewView.bounds
        }
    }
    
    private func setupUI() {
        /// Setup signatureNumberButton theme
        let symbolConfigSignatureButton = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .small)
        let imageSignatureButton = UIImage(systemName: "plus", withConfiguration: symbolConfigSignatureButton)
        Theme.Button.applyGlassStyle(to: signatureNumberButton, image: imageSignatureButton, color: .primaryBlue)
        
        /// Setup captureButtonBackground theme
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = .secondaryBlue
        captureButtonBackground.effect = glassEffect
        captureButtonBackground.layer.cornerRadius = captureButtonBackground.frame.height / 2
        
        setupTabBarAppearance()
        
        /// Setup rotateButton theme
        let symbolConfigRotateButton = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .large)
        let imageRotateButton = UIImage(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90", withConfiguration: symbolConfigRotateButton)
        Theme.Button.applyGlassStyle(to: rotateCameraButton, image: imageRotateButton)
        
        /// Setup captureButton theme
//        captureButton.tintColor = .white
        captureButton.configuration?.baseBackgroundColor = .white
    }
    
    private func setupCamera() {
        Task {
            do {
                try await cameraManager.configureSession(for: .normal)
                
                setupPreviewLayer()
                
                cameraManager.startSession()
                
            } catch CameraError.unauthorized {
                presentCameraSettingsAlert()
            } catch {
                print("Failed to configure camera: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func rotateButtonTapped(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        rotateCameraButton.shake()
    }
    
    private func presentCameraSettingsAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Camera Access Denied",
                message: "InvisMark needs access to your camera to capture secure photos. Please enable it in Settings.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            
            self.present(alert, animated: true)
        }
    }
}

/// Preview Layer
extension CameraViewController {
    
    @MainActor
    private func setupPreviewLayer() {
            
        let layer = cameraManager.createPreviewLayer()
        layer.frame = livePreviewView.bounds
            
        livePreviewView.layer.insertSublayer(layer, at: 0)
            
        previewLayer = layer
    }
    
    @MainActor
    private func applyAspectRatio(_ ratio: CameraAspectRatio) {
        guard let previewLayer = previewLayer else { return }

        livePreviewAspectRatioConstraint.isActive = false
        livePreviewTopConstraint.isActive = false
        
        let videoGravity: AVLayerVideoGravity
        let constant: CGFloat
        switch ratio {
        case .standard:
            constant = 116
            videoGravity = .resizeAspect
        case .widescreen:
            constant = 56
            videoGravity = .resizeAspectFill
        case .square:
            constant = 160
            videoGravity = .resizeAspectFill
        }
        
        
        previewLayer.videoGravity = videoGravity
        
        livePreviewAspectRatioConstraint = livePreviewView.heightAnchor.constraint(
            equalTo: livePreviewView.widthAnchor,
            multiplier: ratio.rawValue
        )
        
        livePreviewTopConstraint = livePreviewView.topAnchor.constraint( equalTo: view.topAnchor,
            constant: constant
        )
        
        livePreviewTopConstraint.isActive = true
        livePreviewAspectRatioConstraint.isActive = true

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
            self.previewLayer?.frame = self.livePreviewView.bounds
        }
    }
}

extension CameraViewController {
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = textAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = textAttributes
        
        let verticalOffset = UIOffset(horizontal: 0, vertical: -5)
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = verticalOffset
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = verticalOffset
        
        tabBar.standardAppearance = appearance
        
        if let items = tabBar.items, !items.isEmpty {
            tabBar.selectedItem = items[0]
        }
    }
    
}

extension CameraViewController: CameraControlPillDelegate {
    
    func didTapFlashButton() {
        
    }
    
    func didTapAspectRatioButton() {
        let newAspectRatio = cameraManager.changeAspectRatio()
        applyAspectRatio(newAspectRatio)
    }
}
