//
//  CameraViewModel.swift
//  Axiomora
//
//  Created by Veer on 25/03/26.
//

import AVFoundation
import UIKit

class CameraViewModel: NSObject {

    private let cameraManager = CameraManager()

    var onPhotoCaptured: ((Image) -> Void)?
    var onUnauthorized: (() -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        cameraManager.delegate = self
    }

    func configureCamera() async {
        do {
            try await cameraManager.configureSession(for: .normal)
            startSession()
        } catch CameraError.unauthorized {
            await MainActor.run { onUnauthorized?() }
        } catch {
            await MainActor.run { onError?(error) }
        }
    }

    func startSession() {
        cameraManager.startSession()
    }

    func stopSession() {
        cameraManager.stopSession()
    }

    func capturePhoto() {
        cameraManager.capturePhoto()
    }

    func toggleFlash() -> String {
        cameraManager.toggleFlash()
    }

    func changeAspectRatio() -> CameraAspectRatio {
        cameraManager.changeAspectRatio()
    }

    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        cameraManager.createPreviewLayer()
    }

    func latestImage() -> Image? {
        PhotoManager.shared.allImages().first
    }

    func allImages() -> [Image] {
        PhotoManager.shared.allImages()
    }
}

extension CameraViewModel: CameraManagerDelegate {

    func cameraManager(_ manager: CameraManager, didCapture savedImage: Image) {
        onPhotoCaptured?(savedImage)
        
    }

    func cameraManager(_ manager: CameraManager, didFailWithError error: Error) {
        onError?(error)
    }

    func cameraManagerWillProcessPhoto(_ manager: CameraManager) {
        
    }
}
