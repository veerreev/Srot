//
//  CameraViewController.swift
//  Axiomora
//
//  Created by Veer on 06/03/26.
//

import UIKit
import AVFoundation

enum CameraAspectRatio: CGFloat {
    case standard = 1.333333333 // 4:3 (Native Sensor)
    case square = 1.0           // 1:1
    case widescreen = 1.7777777 // 16:9
}

class CameraViewController: UIViewController, CameraManagerDelegate {
    
    func cameraManager(_ manager: CameraManager, didCapture photo: UIImage) {
        
    }
    
    func cameraManager(_ manager: CameraManager, didFailWithError error: any Error) {
        
    }
    
    func cameraManagerWillProcessPhoto(_ manager: CameraManager) {
        
    }
    

    @IBOutlet weak var tabBar: UITabBar!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var livePreviewView: UIView!
    @IBOutlet weak var captureButtonBackground: UIVisualEffectView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var signatureNumberButton: UIButton!
    @IBOutlet weak var cameraControlPillVisualEffectView: UIVisualEffectView!
    @IBOutlet weak var topMaskViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomMaskViewHeightConstraint: NSLayoutConstraint!
    
    private let cameraManager = CameraManager()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraManager.delegate = self
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
        let symbolConfigSignatureButton = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium, scale: .large)
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
    
    private func setupPreviewLayer() {
            
        let layer = cameraManager.createPreviewLayer()
        layer.frame = livePreviewView.bounds
            
        livePreviewView.layer.insertSublayer(layer, at: 0)
            
        previewLayer = layer
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
