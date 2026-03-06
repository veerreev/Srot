//
//  CameraManager.swift
//  Axiomora
//
//  Created by Veer Krishna Sharma on 03/03/26.
//

import AVFoundation

final class CameraManager {
    
//    // Singleton instance similar to Authmanager. One camera, so, one instance
//    static let shared = CameraManager()
//    
//    // The core session tha coordinates data flow/data routing
//    let captureSession = AVCaptureSession()
//    // The output strictly for still photography
//    let photoOutput = AVCapturePhotoOutput()
//    
//    // A dedicated background serial thread (dispatch queue) for camera operations to avoid UI freezing
//    let sessionQueue = DispatchQueue(label: "com.axiomora.cameraManager.sessionQueue")
//    
//    private init() {}
//    
//    func setupSession(completion: @escaping (Bool) -> Void) {
//        sessionQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            // Lock the session for configuration
//            self.captureSession.beginConfiguration()
//            
//            // 1. Set the preset specifically for high-quality photography
//            self.captureSession.sessionPreset = .photo
//            
//            // 2. Configure the Input (Back Camera default)
//            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
//                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
//                  self.captureSession.canAddInput(videoDeviceInput) else {
//                print("Error: Could not configure camera input.")
//                self.captureSession.commitConfiguration()
//                DispatchQueue.main.async { completion(false) }
//                return
//            }
//            self.captureSession.addInput(videoDeviceInput)
//            
//            // 3. Configure the Output (Photo capture)
//            guard self.captureSession.canAddOutput(self.photoOutput) else {
//                print("Error: Could not configure photo output.")
//                self.captureSession.commitConfiguration()
//                DispatchQueue.main.async { completion(false) }
//                return
//            }
//            self.captureSession.addOutput(self.photoOutput)
//            
//            if #available(iOS 16.0, *) {
//                // 1. Get the highest available dimensions from the current camera format
//                if let maxDimensions = videoDevice.activeFormat.supportedMaxPhotoDimensions.last {
//                    // 2. Explicitly set the output to handle these dimensions
//                    self.photoOutput.maxPhotoDimensions = maxDimensions
//                }
//            } else {
//                // Fallback for iOS 15 and older
//                self.photoOutput.isHighResolutionCaptureEnabled = true
//            }
//            
//            // Unlock and apply configuration
//            self.captureSession.commitConfiguration()
//            
//            DispatchQueue.main.async { completion(true) }
//        }
//    }
//    
//    // Starts the flow of data from the camera to the session
//    func startSession() {
//        sessionQueue.async { [weak self] in
//            guard let self = self, !self.captureSession.isRunning else { return }
//            self.captureSession.startRunning()
//        }
//    }
//    
//    // Stops the flow of data to save battery when the view disappears
//    func stopSession() {
//        sessionQueue.async { [weak self] in
//            guard let self = self, self.captureSession.isRunning else { return }
//            self.captureSession.stopRunning()
//        }
//    }
    
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
