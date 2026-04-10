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
    
    private let viewModel = CameraViewModel()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
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
//        The alternative would be to have the ViewModel call a method on the ViewController directly, but then the ViewModel would need to import and know about the ViewController, which defeats the whole point of separation
        viewModel.onPhotoCaptured = { [weak self] savedImage in
            self?.updateThumbnail(with: savedImage)
        }
        
        //Start the spinner and dim the thumbnail
        viewModel.onProcessingStarted = { [weak self] in
            self?.progressSpinner.startAnimating()
            UIView.animate(withDuration: 0.2) {
                self?.thumbnailButton.alpha = 0.5
            }
        }
 
        viewModel.onUnauthorized = { [weak self] in
            self?.presentCameraSettingsAlert()
        }
 
        viewModel.onError = { [weak self] error in
                    print("Camera error: \(error.localizedDescription)")
                    self?.progressSpinner.stopAnimating()
                    UIView.animate(withDuration: 0.2) {
                        self?.thumbnailButton.alpha = 1.0
                    }
                }
    }
    
    // MARK: - SETUP
    
    private func setupCamera() {
        Task {
            await viewModel.configureCamera()
            setupPreviewLayer()
        }
    }
    
    #warning("Why do we need to specify this explicitly?")
    @MainActor
    private func setupPreviewLayer() {
        
        let layer = viewModel.createPreviewLayer()
        layer.frame = livePreviewView.bounds
            
        livePreviewView.layer.insertSublayer(layer, at: 0)
            
        previewLayer = layer
    }
    
    // MARK: - UI Setting up
    
    private func setupUI() {
        // Setup signatureNumberButton theme
        let symbolConfigSignatureButton = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .small)
        let imageSignatureButton = UIImage(systemName: "plus", withConfiguration: symbolConfigSignatureButton)
        Theme.Button.applyGlassStyle(to: signatureNumberButton, image: imageSignatureButton, color: Theme.Colors.systemBlue)
        
        // Setup captureButtonBackground theme
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = Theme.Colors.blobBlue
        captureButtonBackground.effect = glassEffect
        captureButtonBackground.layer.cornerRadius = captureButtonBackground.frame.height / 2
                
        // Setup rotateButton theme
        let symbolConfigRotateButton = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .large)
        let imageRotateButton = UIImage(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90", withConfiguration: symbolConfigRotateButton)
        Theme.Button.applyGlassStyle(to: rotateCameraButton, image: imageRotateButton)
        
        // verify button theme
//        Theme.Button.applyGlassStyle(to: verifyButton, title: "Verify", color: .systemBlue)
        
        // Setup captureButton theme
        captureButton.configuration?.baseBackgroundColor = Theme.Colors.white
    }
    
    // MARK: - Thumbnail
    
    // Shows the last captured image on launch if photos already exist.
    private func loadThumbnail() {
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
        
        Task { @MainActor in
            
            self.progressSpinner.stopAnimating()
            
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SegueToSingleImage" {
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
    
    // MARK: - Aspect Ratio
    
    #warning("Why do we need to specify this explicitly?")
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
    
    // MARK: -  Actions
    
    @IBAction func rotateButtonTapped(_ sender: Any) {
        rotateCameraButton.shake()
    }
    
    @IBAction func captureButtonTapped(_ sender: Any) {
        
        let flashView = UIView(frame: self.livePreviewView.bounds)
        flashView.backgroundColor = Theme.Colors.black
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
            
            // Push SingleImageViewViewController onto the existing nav stack
            // by setting our nav controller's view controllers directly.
            // This gives the back chevron automatically.
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
