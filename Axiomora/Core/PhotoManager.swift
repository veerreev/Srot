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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let watermarkedImage = image
            
            self.saveToLibrary(image: watermarkedImage) { success, error in
                
                DispatchQueue.main.async {
                    completion(success, error)
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
