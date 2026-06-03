//
//  CameraViewController.swift
//  Axiomora
//
//  Created by Veer on 06/03/26.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    
    @IBOutlet var progressSpinner: UIActivityIndicatorView!
    @IBOutlet var thumbnailButton: UIButton!
    @IBOutlet weak var livePreviewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var livePreviewAspectRatioConstraint: NSLayoutConstraint!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var livePreviewView: UIView!
    @IBOutlet weak var captureButtonBackground: UIVisualEffectView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var signatureNumberButton: UIButton!
    @IBOutlet weak var cameraControlPillVisualEffectView: CameraControlPill!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var onboardingTooltipContainer: UIView!
    
    private let viewModel = CameraViewModel()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Tracks how many images are currently being processed by the ML model
        private var processingCount: Int = 0 {
            didSet {
                // Safety check to ensure it never goes negative
                if processingCount < 0 { processingCount = 0 }
                
                if processingCount > 0 {
                    thumbnailButton.isUserInteractionEnabled = false
                    progressSpinner.startAnimating()
                    UIView.animate(withDuration: 0.2) {
                        self.thumbnailButton.alpha = 0.5
                    }
                } else {
                    thumbnailButton.isUserInteractionEnabled = true
                    progressSpinner.stopAnimating()
                    UIView.animate(withDuration: 0.2) {
                        self.thumbnailButton.alpha = 1.0
                    }
                }
            }
        }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraControlPillVisualEffectView.delegate = self
        setupUI()
        bindViewModel()
        setupCamera()
        loadThumbnail()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadThumbnail()
        viewModel.startSession()
        updateSignatureNumberButton()
        // Button enable/disable doesn't need resolved frames — safe in viewWillAppear.
        refreshOnboardingButtonStates()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = livePreviewView.bounds
    }
    
    private func bindViewModel() {
            viewModel.onPhotoCaptured = { [weak self] savedImage in
                Task { @MainActor in
                    self?.processingCount -= 1
                    self?.updateThumbnail(with: savedImage)
                }
            }
            
            viewModel.onProcessingStarted = { [weak self] in
                Task { @MainActor in
                    self?.processingCount += 1
                }
            }
     
            viewModel.onUnauthorized = { [weak self] in
                self?.presentCameraSettingsAlert()
            }
     
        viewModel.onError = { [weak self] error in
            Task { @MainActor in
                self?.processingCount -= 1
                
                let alert = UIAlertController(
                    title: "Capture Failed",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    // MARK: - SETUP
    
    private func setupCamera() {
        Task {
            await viewModel.configureCamera()
            LocationManager.shared.requestPermissionIfNeeded()
            setupPreviewLayer()
        }
    }
    
//    #warning("Why do we need to specify this explicitly?")
    @MainActor
    private func setupPreviewLayer() {
        let layer = viewModel.createPreviewLayer()
        layer.frame = livePreviewView.bounds
        livePreviewView.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }
    
    // MARK: - UI
    
    private func setupUI() {
        let symbolConfigSignatureButton = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .small)
        let imageSignatureButton = UIImage(systemName: "plus", withConfiguration: symbolConfigSignatureButton)
        Theme.Button.applyGlassStyle(to: signatureNumberButton, image: imageSignatureButton, color: Theme.Colors.tertiaryBlue)
        
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = Theme.Colors.blobBlue
        captureButtonBackground.effect = glassEffect
        captureButtonBackground.layer.cornerRadius = captureButtonBackground.frame.height / 2
                
        let symbolConfigRotateButton = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .large)
        let imageRotateButton = UIImage(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90", withConfiguration: symbolConfigRotateButton)
        Theme.Button.applyGlassStyle(to: rotateCameraButton, image: imageRotateButton)
        
        captureButton.configuration?.baseBackgroundColor = Theme.Colors.white
    }
    
    private func updateSignatureNumberButton() {
        let signatures = SignatureManager.shared.loadSignatures()
        
        if let currentIndex = signatures.firstIndex(where: { $0.isCurrent }) {
            Theme.Button.applyGlassStyle(
                to: signatureNumberButton,
                title: "\(currentIndex + 1)",
                color: Theme.Colors.systemBlue
            )
        } else {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .medium)
            let plusImage = UIImage(systemName: "plus", withConfiguration: symbolConfig)
            Theme.Button.applyGlassStyle(to: signatureNumberButton, image: plusImage, color: Theme.Colors.systemBlue)
        }
    }
    
    // MARK: - Onboarding

    /// Handles button enable/disable — no frame needed, safe in viewWillAppear.
    private func refreshOnboardingButtonStates() {
        let active = OnboardingManager.shared.isOnboardingActive
        onboardingTooltipContainer.isHidden = !active   // ← entire tooltip logic now

        if active {
            applyOnboardingRestrictions()
        } else {
            removeOnboardingRestrictions()
        }
    }

    

    /// Disables every interactive element except `signatureNumberButton` and
    /// adds a pulsing blue glow to it so the user knows exactly what to tap.
    private func applyOnboardingRestrictions() {
        let lockedButtons: [UIButton] = [captureButton, rotateCameraButton, thumbnailButton, verifyButton]
        for button in lockedButtons {
            button.isEnabled = false
            button.alpha = 0.35
        }
        cameraControlPillVisualEffectView.isUserInteractionEnabled = false
        cameraControlPillVisualEffectView.alpha = 0.35

        signatureNumberButton.isEnabled = true
        signatureNumberButton.alpha = 1.0

        signatureNumberButton.layer.masksToBounds = false
        signatureNumberButton.layer.shadowColor = UIColor.systemBlue.cgColor
        signatureNumberButton.layer.shadowOffset = .zero
        signatureNumberButton.layer.shadowRadius = 8
        signatureNumberButton.layer.shadowOpacity = 1.0
        

        let glow = CABasicAnimation(keyPath: "shadowRadius")
        glow.fromValue = 5
        glow.toValue = 18
        glow.duration = 0.85
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        signatureNumberButton.layer.add(glow, forKey: "onboardingGlow")
    }

    /// Restores every control to its normal enabled state and removes the glow.
    private func removeOnboardingRestrictions() {
        let allButtons: [UIButton] = [captureButton, rotateCameraButton, thumbnailButton, verifyButton]
        for button in allButtons {
            button.isEnabled = true
            button.alpha = 1.0
        }
        cameraControlPillVisualEffectView.isUserInteractionEnabled = true
        cameraControlPillVisualEffectView.alpha = 1.0

        signatureNumberButton.layer.removeAnimation(forKey: "onboardingGlow")
        signatureNumberButton.layer.shadowOpacity = 0
    }

    // MARK: - Thumbnail
    
    private func loadThumbnail() {
        guard let lastImage = PhotoManager.shared.allImages().first else {
            DispatchQueue.main.async {
                var config = self.thumbnailButton.configuration ?? UIButton.Configuration.plain()
                config.background.image = nil
                self.thumbnailButton.configuration = config
            }
            return
        }
        updateThumbnail(with: lastImage)
    }
    
    func updateThumbnail(with image: Image) {
            guard let thumbURL = image.thumbnailFileURL, let uiImage = UIImage(contentsOfFile: thumbURL.path) else { return }
            
            Task { @MainActor in
                var config = self.thumbnailButton.configuration ?? UIButton.Configuration.plain()
                config.background.image = uiImage
                config.background.imageContentMode = .scaleAspectFill
                
                // Smoothly cross-dissolve the image while keeping the spinner overlay intact
                UIView.transition(with: self.thumbnailButton, duration: 0.3, options: .transitionCrossDissolve) {
                    self.thumbnailButton.configuration = config
                    self.thumbnailButton.setImage(nil, for: .normal)
                }
            }
        }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SegueToSingleImage" {
            if let singleImageVC = segue.destination as? SingleImageViewViewController {
                let allImages = PhotoManager.shared.allImages()
                singleImageVC.images = allImages
                singleImageVC.startingIndex = 0
            }
        }
    }
    
    // MARK: - Aspect Ratio
    
//    #warning("Why do we need to specify this explicitly?")
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
        livePreviewTopConstraint = livePreviewView.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: constant
        )
        livePreviewTopConstraint.isActive = true
        livePreviewAspectRatioConstraint.isActive = true

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
            self.previewLayer?.frame = self.livePreviewView.bounds
        }
    }
    
    // MARK: - Alert
    
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
    
    // MARK: - Actions
    
    @IBAction func rotateButtonTapped(_ sender: Any) {
        rotateCameraButton.isEnabled = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Fade out the preview, switch cameras, fade back in — mimics the native camera flip feel
        UIView.animate(withDuration: 0.15, animations: {
            self.livePreviewView.alpha = 0
        }) { _ in
            Task {
                do {
                    try await self.viewModel.switchCamera()
                } catch {
                    print("Camera switch failed: \(error)")
                }
                
                await MainActor.run {
                    UIView.animate(withDuration: 0.2) {
                        self.livePreviewView.alpha = 1
                    }
                    self.rotateCameraButton.isEnabled = true
                }
            }
        }
    }
    
    @IBAction func captureButtonTapped(_ sender: Any) {
        let flashView = UIView(frame: self.livePreviewView.bounds)
        flashView.backgroundColor = Theme.Colors.black
        flashView.alpha = 1.0
        self.livePreviewView.addSubview(flashView)
        
//        #warning("Learn what is 'completion'")
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            flashView.alpha = 0.0
        }, completion: { _ in
            flashView.removeFromSuperview()
        })
        
//        #warning("Learn Animate")
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                self.captureButton.transform = .identity
            })
        })
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        viewModel.capturePhoto()
    }
    
    @IBAction func thumbnailTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "SingleImageViewStoryboard", bundle: nil)
        guard let navVC = storyboard.instantiateInitialViewController() as? UINavigationController,
              let singleImageVC = navVC.topViewController as? SingleImageViewViewController else {
            print("Could not instantiate SingleImageViewViewController")
            return
        }
        
        let allImages = PhotoManager.shared.allImages()
        singleImageVC.images = allImages
        singleImageVC.startingIndex = 0
        
        guard let navController = navigationController else { return }
        navController.setNavigationBarHidden(false, animated: false)
        navController.pushViewController(singleImageVC, animated: true)
    }
    
    @IBAction func verifyButtonChanged(_ sender: UIButton) {
        performSegue(withIdentifier: "showVerify", sender: nil)
    }
}

extension CameraViewController: CameraControlPillDelegate {
    
    func didTapFlashButton() -> String {
        viewModel.toggleFlash()
    }
    
    func didTapAspectRatioButton() {
        let newAspectRatio = viewModel.changeAspectRatio()
        applyAspectRatio(newAspectRatio)
    }
}
