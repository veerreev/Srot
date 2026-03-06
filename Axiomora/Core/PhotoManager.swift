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
    
    func requestSavePhotoAccess() async -> PhotoLibraryAccessStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized:
            return .authorized
            
        case .notDetermined, .denied, .restricted:
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
