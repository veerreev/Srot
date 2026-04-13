//
//  ImageStorageManager.swift
//  Axiomora
//
//  Created by Veer on 06/03/26.
//

import Foundation
import Photos
import UIKit
import AVFoundation
import ImageIO

// Used by ViewControllers to decide whether to proceed or show a permissions prompt.
enum PhotoLibraryAccessStatus {
    case authorized
    case limited
    case denied
}

// Describes what went wrong when PhotoManager fails to save an image to disk.
enum ImageSaveError: Error {
    case thumbnailGenerationFailed
    case fileWriteFailed
    case documentsDirectoryUnavailable
}

class PhotoManager {
    
    static let shared = PhotoManager()
    
    private init() {
        loadFromDisk()
    }
    
    
    // Filenames for the two JSON persistence files in the Documents directory.
    private let imagesFileName  = "images.json"
        
    private let thumbnailSize = CGSize(width: 300, height: 300)
        
    // Single source of truth for the entire app.
    // All ViewControllers read from here, never maintain their own copies.
    private(set) var images: [Image] = []
}

//Persistence
// Reads and writes the images and albums arrays to JSON files in the Documents directory.
// JSON files are used instead of UserDefaults because these arrays can grow large over time and UserDefaults is not designed for high-volume data storage.
extension PhotoManager {
    
    private var documentsDirectory: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // Called once on init, loads both arrays from disk into memory.
    private func loadFromDisk() {
        images = load([Image].self, from: imagesFileName) ?? []
    }
    
    // Generic decode helper reads a JSON file from Documents and decodes it.
    // Returns nil if the file doesn't exist yet (e.g. on first launch).
    private func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        guard let directory = documentsDirectory else { return nil }
        let fileURL = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    // Writes both arrays to disk after every mutation.
    // Called at the end of every save/delete/toggle/album operation.
    private func saveToDisk() {
        save(images, to: imagesFileName)
    }
    
    private func save<T: Encodable>(_ value: T, to filename: String) {
        guard let directory = documentsDirectory else {
            print("PhotoManager: Documents directory unavailable — could not save \(filename)")
            return
        }
        let fileURL = directory.appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(value) else {
            print("PhotoManager: Encoding failed for \(filename)")
            return
        }
        try? data.write(to: fileURL, options: .atomic)// .atomic writes to a temp file first, then renames it. This prevents corruption if the app is killed mid-write.
    }
    
}

//Image Operations
extension PhotoManager {
    
    // Deletes an image's files from disk, removes it from all albums, and removes it from the in-memory array.
    // Called by the trash button in SingleImageViewController.
    func deleteImage(_ image: Image) {
        // Delete both the full-res file and the thumbnail from disk.
        if let fileURL = image.localFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let thumbURL = image.thumbnailFileURL {
            try? FileManager.default.removeItem(at: thumbURL)
        }
                
        // Remove from in-memory array and persist.
        images.removeAll { $0.id == image.id }
        saveToDisk()
        
        print("PhotoManager: Deleted image \(image.id)")
    }
    
    // Deletes multiple images at once
    // Implemented when multi-select is used in the gallery.
    func deleteImages(_ imagesToDelete: [Image]) {
        imagesToDelete.forEach { deleteImage($0) }
    }
        
    // Thumbnail Generation
    // Draws the full-res image into a smaller CGSize context.
    // Using UIGraphicsImageRenderer is the modern recommended approach since it handles screen scale and color space automatically.
    private func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func saveImage(_ uiImage: UIImage, creatorId: String, signatureId: String, device: String?) throws -> Image {
        guard let directory = documentsDirectory else {
            throw ImageSaveError.documentsDirectoryUnavailable
        }
        
        let imageId = UUID().uuidString
        let filename = "\(imageId).heic"
        let thumbnailFilename = "\(imageId)_thumb.heic"
        
        let imageURL = directory.appendingPathComponent(filename)
        let normalizedImage = uiImage.normalized()
        guard let cgImage = normalizedImage.cgImage else {
            throw ImageSaveError.fileWriteFailed
        }

        let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, AVFileType.heic as CFString, 1, nil)
        guard let dest = destination else { throw ImageSaveError.fileWriteFailed }
        let orientationValue = CGImagePropertyOrientation(normalizedImage.imageOrientation).rawValue
        let options: [CFString: Any] = [
            kCGImagePropertyOrientation: orientationValue
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ImageSaveError.fileWriteFailed }
        
        guard let thumbnail = generateThumbnail(from: uiImage, size: thumbnailSize),
              let thumbCGImage = thumbnail.cgImage else {
            throw ImageSaveError.thumbnailGenerationFailed
        }

        let thumbURL = directory.appendingPathComponent(thumbnailFilename)
        let thumbDestination = CGImageDestinationCreateWithURL(thumbURL as CFURL, AVFileType.heic as CFString, 1, nil)
        guard let thumbDest = thumbDestination else { throw ImageSaveError.thumbnailGenerationFailed }
        
        let thumbOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.7]
        CGImageDestinationAddImage(thumbDest, thumbCGImage, thumbOptions as CFDictionary)
        guard CGImageDestinationFinalize(thumbDest) else { throw ImageSaveError.thumbnailGenerationFailed }
        
        let newImage = Image(
            id:                imageId,
            creatorId:         creatorId,
            signatureId:       signatureId,
            localFilename:     filename,
            thumbnailFilename: thumbnailFilename,
            remoteURL:         nil,
            createdAt:         Date(),
            device:            device,
            isFavourite:       false,
            albumIds:          []
        )
        
        images.append(newImage)
        saveToDisk()
        print("PhotoManager: Saved image \(imageId)")
        return newImage
    }
    
}

// Image Retrieval
extension PhotoManager {
    
    // Returns all images sorted newest first.
    func allImages() -> [Image] {
        return images.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }
    
    // Groups all images by date for the AllPhotosViewController date-sectioned grid.
    // Returns an array of (sectionTitle, images) tuples sorted newest section first.
    // Section titles: "Today", "Yesterday", or "March 10, 2026" for older dates.
    func imagesGroupedByDate() -> [(sectionTitle: String, images: [Image])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        
        // Group images into a dictionary keyed by their calendar day (year + month + day).
        var groups: [DateComponents: [Image]] = [:]
        for image in allImages() {
            let date = image.createdAt ?? Date.distantPast
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            groups[components, default: []].append(image)
        }
        
        // Sort the groups newest first and build the section title for each.
        return groups
            .sorted { a, b in
                let dateA = calendar.date(from: a.key) ?? .distantPast
                let dateB = calendar.date(from: b.key) ?? .distantPast
                return dateA > dateB
            }
            .map { (components, groupImages) in
                let date = calendar.date(from: components) ?? .distantPast
                let title = sectionTitle(for: date, calendar: calendar, formatter: formatter)
                return (sectionTitle: title, images: groupImages)
            }
    }
    
    // Returns the human-readable section header for a given date.
    private func sectionTitle(for date: Date, calendar: Calendar, formatter: DateFormatter) -> String {
        if calendar.isDateInToday(date)     { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return formatter.string(from: date)
    }
        
}
extension PhotoManager{
    
    func applyWatermarkAndSave(image: UIImage, completion: @escaping (Bool, Image?, Error?) -> Void) {
        
        // 1. Hop onto a background thread so we don't freeze the camera UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var watermarkedImage: UIImage!
            do {
                let dummySignature = Signature(
                    id: UUID().uuidString,
                    creatorID: "1234",
                    title: "dummy",
                    displayName: "John",
                    socialHandles: [],
                    shouldIncludeLocation: false
                )
                
                print ("Yet to be signed")
                
                watermarkedImage = try WatermarkEmbedder.shared.embed(image, signature: dummySignature)
                print ("Signed yet to save")
            } catch {
                print("Watermark Engine Error: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
                
            }
            
            let savedImage: Image?
            do {
                savedImage = try self.saveImage(
                    watermarkedImage,
                    creatorId:   AuthManager.shared.currentUser?.userId ?? "unknown",
                    signatureId: "pending",
                    device:      UIDevice.current.name
                )
            } catch {
                print("PhotoManager: Failed to save to in-app gallery — \(error)")
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
                return
            }
            
            self.saveToLibrary(image: watermarkedImage) { success, error in
                DispatchQueue.main.async {
                    completion(success, savedImage, error)
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

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .down:          self = .down
        case .left:          self = .left
        case .right:         self = .right
        case .upMirrored:    self = .upMirrored
        case .downMirrored:  self = .downMirrored
        case .leftMirrored:  self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
