//
//  CameraViewController.swift
//  Axiomora
//
//  Created by Veer on 06/03/26.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, CameraManagerDelegate {
    
    @IBOutlet var thumbnailButton: UIButton!
    func cameraManager(_ manager: CameraManager, didCapture savedImage: Image) {
        updateThumbnail(with: savedImage)
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
        loadExistingThumbnail()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        cameraManager.startSession()
        loadExistingThumbnail()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        cameraManager.stopSession()
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
    
    @IBAction func captureButtonTapped(_ sender: Any) {
        
        let flashView = UIView(frame: self.livePreviewView.bounds)
        flashView.backgroundColor = .black
        flashView.alpha = 1.0
        
        self.livePreviewView.addSubview(flashView)
        
        #warning("Learn what is 'completion'")
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            flashView.alpha = 0.0
        }, completion: { _ in
            flashView.removeFromSuperview()
        })
        
        #warning("Learn Animate")
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                self.captureButton.transform = .identity
            })
        })
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        cameraManager.capturePhoto()
    }
    
    
    
    @IBAction func signatureNumberButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "SignaturesStoryboard", bundle: nil)
        guard let navVC = storyboard.instantiateInitialViewController() as? UINavigationController,
        let signatureVC = navVC.topViewController as? SignaturesViewController else {
            print ("Could not instantiate SignaturesViewController")
            return
        }
        
        guard let navController = navigationController else { return }
        navController.setNavigationBarHidden(false, animated: false)
        navController.pushViewController(signatureVC, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "segue_to_singleImage" {
                // Check if the destination is our SingleImageViewViewController
                if let singleImageVC = segue.destination as? SingleImageViewViewController {
                    
                    // 1. Fetch the latest images from the manager
                    let allImages = PhotoManager.shared.allImages()
                    
                    // 2. Pass the data!
                    singleImageVC.images = allImages
                    
                    // 3. Tapping the camera thumbnail always opens the most recent photo (index 0)
                    singleImageVC.startingIndex = 0
                }
            }
        }
}

/// Preview Layer
extension CameraViewController {
    
    #warning("Ask why do we need to specify main thread explicitly, does everything not happen on the main thread by default?")
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
    
    func didTapFlashButton() -> String {
        cameraManager.toggleFlash()
    }
    
    func didTapAspectRatioButton() {
        let newAspectRatio = cameraManager.changeAspectRatio()
        applyAspectRatio(newAspectRatio)
    }
}

extension CameraViewController {
    
    // Shows the last captured image on launch if photos already exist.
    private func loadExistingThumbnail() {
            // Check if there is at least one image
            guard let lastImage = PhotoManager.shared.allImages().first else {
                // IF NO IMAGES EXIST: Clear the background image from the configuration
                DispatchQueue.main.async {
                    var config = self.thumbnailButton.configuration ?? UIButton.Configuration.plain()
                    config.background.image = nil
                    self.thumbnailButton.configuration = config
                }
                return
            }
            
            // IF IMAGES EXIST: Proceed as normal
            updateThumbnail(with: lastImage)
        }
    
    // Updates the thumbnail circle with a newly captured image.
    // Called from cameraManager(_:didCapture:) after a successful save.
    func updateThumbnail(with image: Image) {
        guard let thumbURL = image.thumbnailFileURL, let uiImage = UIImage(contentsOfFile: thumbURL.path) else { return }
        
        DispatchQueue.main.async {
            self.thumbnailButton.alpha = 0
            
            // 1. Grab the existing configuration
            var config = self.thumbnailButton.configuration ?? UIButton.Configuration.plain()
            
            // 2. Apply the image to the BACKGROUND, not the foreground
            config.background.image = uiImage
            
            // 3. Tell the background exactly how to scale it!
            // .scaleAspectFill is what the native Apple Camera uses (fills the circle completely)
            // If you truly want to see the ENTIRE rectangle with empty space on the sides, change this to .scaleAspectFit
            config.background.imageContentMode = .scaleAspectFill
            
            // 4. Re-apply the updated configuration
            self.thumbnailButton.configuration = config
            
            // 5. Clear out any old foreground images so they don't overlap
            self.thumbnailButton.setImage(nil, for: .normal)
            
            UIView.animate(withDuration: 0.3) {
                self.thumbnailButton.alpha = 1
            }
        }
    }
}
