//
//  CameraManager.swift
//  Axiomora
//
//  Created by Veer Krishna Sharma on 03/03/26.
//

import AVFoundation
import UIKit

enum CameraError: Error {
    case unauthorized
    case configurationFailed
    case deviceUnavailable
}

enum CameraMode {
    case normal // Uses "Virtual Cameras"
    case pro    // To be implemented in the future
}

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didCapture photo: UIImage)
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
    func cameraManagerWillProcessPhoto(_ manager: CameraManager)
}

final class CameraManager {
    
    let captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    weak var delegate: CameraManagerDelegate?
    
    private var isConfigured = false
    private(set) var currentMode: CameraMode = .normal // 'set' forces the controller to use configureSession to change to '.pro' mode
    private var videoDeviceInput: AVCaptureDeviceInput? // Need to track for changing modes without error, will be useful when '.pro' mode is implemented
    
    private let sessionQueue = DispatchQueue(label: "com.axiomora.invismark.cameraQueue", qos: .userInitiated)
    
    func configureSession(for mode: CameraMode = .normal) async throws {
        guard await requestCameraAccess() == .authorized else {
            throw CameraError.unauthorized // Now the CameraViewControlelr catches this error and shows the user how to navigate to the settings and grant camera access
        }

        /// could have used RETURN TRY AWAIT here. It is a better approach.
        // return serves the following purpose:
        // 1) Communicates intent - Anyone would know that this is the final statement of the function
        // 2) Prevents others from adding extra functionalities at the end of this code block by throwing a compiler error:
        // Error - "Code after 'return' will never be executed"
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else { return }

                self.currentMode = mode
                self.captureSession.beginConfiguration()

                // Note from Documentation:  You can nest beginConfiguration() and commitConfiguration() pairs, and the system applies the changes when you call the outermost commit.

                self.captureSession.sessionPreset = .photo

                do {
                    try self.setupInput(for: mode)
                    try self.setupOutput()

                    self.captureSession.commitConfiguration()
                    self.isConfigured = true
                    continuation.resume()
                } catch {
                    self.captureSession.commitConfiguration()
                    continuation.resume(throwing: error)
                }

            }
        }
    }

    private func setupInput(for mode: CameraMode) throws {
        // Remove existing input if we are switching modes, will be used later in '.pro' mode
        if let existingInput = videoDeviceInput {
            captureSession.removeInput(existingInput)
        }

        guard let videoDevice = discoverDevice(for: mode) else { throw CameraError.deviceUnavailable }

        let newInput = try AVCaptureDeviceInput(device: videoDevice)
        guard captureSession.canAddInput(newInput) else {
            throw CameraError.configurationFailed
        }

        captureSession.addInput(newInput)
        self.videoDeviceInput = newInput
    }

    private func setupOutput() throws {
        guard !captureSession.outputs.contains(photoOutput) else { return }

        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraError.configurationFailed
        }
        captureSession.addOutput(photoOutput)

        // Need to look into this part further. This is where the image will be configured for best ML output (based on speed, quality and precision)
        guard let activeDevice = videoDeviceInput?.device else { return }
        if let maxDimensions = activeDevice.activeFormat.supportedMaxPhotoDimensions.last {
            photoOutput.maxPhotoDimensions = maxDimensions
        }
        photoOutput.maxPhotoQualityPrioritization = .quality // This is default to .balanced, we might need it later (.qualilty, .balanced, .speed)
    }

    private func discoverDevice(for mode: CameraMode) -> AVCaptureDevice? {
        switch mode {
        case .normal:
            if let triple = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
                return triple
            } else if let dual = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                return dual
            } else {
                return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            }
        case .pro:
            // To be implemented later, return the default .builtInWideAngleCamera to avoid errors
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in 
            guard let self = self, self.isConfigured, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in 
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }
    
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspect // .resizeAspectFill cause unnecessary zoom
        return layer
    }
}

enum CameraAccessStatus {
    case authorized
    case denied // Covers both .denied and .restricted
}

extension CameraManager {
    
    func requestCameraAccess() async -> CameraAccessStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return .authorized
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
            
        case .denied, .restricted: // restricted is for when the system blocks it (e.g., parental controls)
            return .denied
            
        @unknown default: // @unknown generates a compiler warning if a known case is not used
            return .denied
        }
    }
}
