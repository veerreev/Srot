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

class CameraViewController: UIViewController {

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
        Theme.Button.applyPrimaryBlueStyle(to: signatureNumberButton, title: "1")
        
        /// Setup captureButtonBackground theme
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = .systemGray4
        captureButtonBackground.effect = glassEffect
        captureButtonBackground.layer.cornerRadius = captureButtonBackground.frame.height / 2
        
        setupTabBarAppearance()
        
        /// Setup rotateButton theme
        var config = UIButton.Configuration.glass()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .large)
        let image = UIImage(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90", withConfiguration: symbolConfig)
        config.image = image
        rotateCameraButton.configuration = config
        
        /// Setup captureButton theme
        captureButton.tintColor = .white
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let layer = AVCaptureVideoPreviewLayer(session: self.cameraManager.captureSession)
            
            // Tell the layer to stretch/crop the video to fill the screen flawlessly without black bars
            layer.videoGravity = .resizeAspectFill
            layer.frame = self.livePreviewView.bounds
            
            // Insert the video feed as the absolute bottom layer of the previewView
            // This ensures your buttons and masks float ON TOP of the camera feed
            self.livePreviewView.layer.insertSublayer(layer, at: 0)
            
            self.previewLayer = layer
        }
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
