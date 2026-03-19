//
//  ImageStorageManager.swift
//  Axiomora
//
//  Created by Veer on 06/03/26.
//

import Foundation
import Photos
import UIKit

enum PhotoLibraryAccessStatus {
    case authorized
    case limited
    case denied
}

class PhotoManager {
    
    static let shared = PhotoManager()
    
    private init() {}
    
    func applyWatermarkAndSave(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        
        // 1. Hop onto a background thread so we don't freeze the camera UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 2. Prepare the signature
                let dummySignature = Signature(
                    id: UUID().uuidString,
                    creatorID: "4321",
                    title: "Sign",
                    displayName: "John Doe",
                    socialHandles: [],
                    shouldIncludeLocation: false
                )
                
                print("Yet to be signed")
                // 3. Mark the call with 'try' inside the 'do' block
                let watermarkedImage = try WatermarkEmbedder.shared.embed(image, signature: dummySignature)
                print("Signed, yet to save")
                
                // 4. If successful, proceed to save to the library
                self.saveToLibrary(image: watermarkedImage) { success, error in
                    DispatchQueue.main.async {
                        completion(success, error)
                    }
                }
                
            } catch {
                // 5. If the embedder throws an error, catch it here and pass it to the completion handler
                print("WatermarkEngine Error: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
    
    private func saveToLibrary(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                let error = NSError(domain: "PhotoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied."])
                completion(false, error)
                return
            }
            
            // Perform the save request
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                completion(success, error)
            }
        }
    }
    
}

extension PhotoManager {
    
    func requestSavePhotoAccess() async -> PhotoLibraryAccessStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized:
            return .authorized
            
        case .notDetermined:
            return .denied
            
        case .denied, .restricted:
            return .denied
            
        case .limited:
            return .limited
                        
        @unknown default:
            return .denied
        }
        
    }
}

extension PhotoManager {
    
    func requestReadPhotoAccess() -> PhotoLibraryAccessStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized:
            return .authorized
            
        case .notDetermined, .denied, .restricted:
            return .denied
            
        #warning("Limited access is not handled")
        case .limited:
            return .limited
            
        @unknown default:
            return .denied
        }
    }
}
