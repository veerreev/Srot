//
//  WatermarkManager.swift
//  Axiomora
//
//  Created by Pradumn Kapil on 15/05/26.
//
//

import Foundation
import Vision
import CoreImage
import UIKit

// MARK: - Errors

public enum WatermarkError: LocalizedError {
    case imageConversionFailed
    case encodingFailed(String)
    case decodingFailed(String)
    case watermarkNotFound
    case imageResolutionTooSmall

    public var errorDescription: String? {
        switch self {
        case .imageConversionFailed:        return "Failed to convert UIImage to CGImage."
        case .encodingFailed(let msg):      return "Encoding failed: \(msg)"
        case .decodingFailed(let msg):      return "Decoding failed: \(msg)"
        case .watermarkNotFound:            return "No valid watermark/fingerprint found in image."
        case .imageResolutionTooSmall:      return "Image must be at least 512×512 px."
        }
    }
}

// MARK: - Demo Backend Simulator

/// For the 3-day demo, we simulate the backend mapping of "Feature Prints -> UUID".
actor MockBackendDatabase {
    static let shared = MockBackendDatabase()
    
    // Maps a UUID to an array of feature prints (Full, Center, Safe-Zone) from the original image.
    private var database: [UUID: [VNFeaturePrintObservation]] = [:]
    
    func save(uuid: UUID, featurePrints: [VNFeaturePrintObservation]) {
        database[uuid] = featurePrints
    }
    
    func getAllRecords() -> [UUID: [VNFeaturePrintObservation]] {
        return database
    }
}

// MARK: - WatermarkManager

public final class WatermarkManager {

    public static let shared = WatermarkManager()
    
    private let minImageSide = 512
    
    // Core Image context used for stripping colors from the image
    private let ciContext = CIContext(options: nil)

    private init() {}

    // MARK: - Public: Encode (Simulated)

    public func encode(image: UIImage, uuid: UUID? = nil) async throws -> (UIImage, UUID) {
        let targetUUID = uuid ?? UUID()

        guard let cgImage = image.cgImage else {
            throw WatermarkError.imageConversionFailed
        }

        guard min(cgImage.width, cgImage.height) >= minImageSide else {
            throw WatermarkError.imageResolutionTooSmall
        }

        // Extract 3 different structural perspectives of the image (automatically converted to Grayscale)
        let crops = extractConcentricCrops(from: cgImage)
        let featurePrints = try await generateFeaturePrints(for: crops)
        
        await MockBackendDatabase.shared.save(uuid: targetUUID, featurePrints: featurePrints)

        print("[WatermarkManager] ✓ Encoded image with \(crops.count) target zones. UUID: \(targetUUID)")
        
        return (image, targetUUID)
    }

    // MARK: - Public: Decode ("Closest Match Wins")

    public func decode(image: UIImage) async throws -> UUID? {
        guard let cgImage = image.cgImage else {
            throw WatermarkError.imageConversionFailed
        }

        // Extract the same 3 perspectives from the screenshot (automatically converted to Grayscale)
        let queryCrops = extractConcentricCrops(from: cgImage)
        let queryPrints = try await generateFeaturePrints(for: queryCrops)
        let database = await MockBackendDatabase.shared.getAllRecords()
        
        var bestMatchUUID: UUID? = nil
        
        // 25.0 allows for slight compression shifts. Because color is removed,
        // distance scores for filters will plummet back down to < 5.0.
        var absoluteLowestDistance: Float = 25.0
        
        for (storedUUID, storedPrints) in database {
            for queryPrint in queryPrints {
                for storedPrint in storedPrints {
                    var distance: Float = .infinity
                    try queryPrint.computeDistance(&distance, to: storedPrint)
                    
                    // If ANY of our crops match ANY of their crops, track the lowest distance
                    if distance < absoluteLowestDistance {
                        absoluteLowestDistance = distance
                        bestMatchUUID = storedUUID
                    }
                }
            }
        }
        
        guard let finalUUID = bestMatchUUID else {
            print("[WatermarkManager] ⚠️ No match found. Lowest distance was too high.")
            throw WatermarkError.watermarkNotFound
        }

        print("[WatermarkManager] ✓ Decoded successfully! Best match distance: \(absoluteLowestDistance)")
        return finalUUID
    }

    // MARK: - Cropping & Grayscale Logic (Filter Immunity)

    /// Returns 3 variations of the image: Full, Center Square, and Tight "Safe Zone".
    /// Every crop is converted to pure grayscale to ensure Apple/Instagram filters don't break the match.
    private func extractConcentricCrops(from cgImage: CGImage) -> [CGImage] {
        var crops: [CGImage] = []
        
        // Helper to strip color before adding it to the list
        func addColorBlindCrop(_ crop: CGImage) {
            if let grayCrop = convertToGrayscale(crop) {
                crops.append(grayCrop)
            } else {
                crops.append(crop) // Fallback to color if CI fails (rare)
            }
        }
        
        // 1. The Full Image
        addColorBlindCrop(cgImage)
        
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let minSide = min(w, h)
        
        // 2. Center Square (Chops off top/bottom letterbox bars on tall screenshots)
        let centerRect = CGRect(x: (w - minSide)/2, y: (h - minSide)/2, width: minSide, height: minSide)
        if let centerCrop = cgImage.cropping(to: centerRect) {
            addColorBlindCrop(centerCrop)
        }
        
        // 3. Safe Zone Inner Square (60% size - Bypasses floating UI, dynamic island, text overlays)
        let safeSide = minSide * 0.6
        let safeRect = CGRect(x: (w - safeSide)/2, y: (h - safeSide)/2, width: safeSide, height: safeSide)
        if let safeCrop = cgImage.cropping(to: safeRect) {
            addColorBlindCrop(safeCrop)
        }
        
        return crops
    }
    
    /// Converts an image to pure grayscale using CoreImage. This makes the Vision framework
    /// completely ignore color filters (Vivid, Warm, Cool, etc.).
    private func convertToGrayscale(_ cgImage: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        // Set saturation to 0 to completely remove all color data
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        
        guard let output = filter.outputImage,
              let grayCG = ciContext.createCGImage(output, from: output.extent) else {
            return nil
        }
        return grayCG
    }

    // MARK: - Vision Logic

    private func generateFeaturePrints(for images: [CGImage]) async throws -> [VNFeaturePrintObservation] {
        var prints: [VNFeaturePrintObservation] = []
        
        for image in images {
            let request = VNGenerateImageFeaturePrintRequest()
            request.revision = VNGenerateImageFeaturePrintRequestRevision1
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            
            if let result = request.results?.first as? VNFeaturePrintObservation {
                prints.append(result)
            }
        }
        
        return prints
    }
}

// MARK: - Convenience Extensions
extension WatermarkManager {
    public func encodeAndSave(image: UIImage, uuid: UUID? = nil) async throws -> UUID {
        let (watermarked, embeddedUUID) = try await encode(image: image, uuid: uuid)
        UIImageWriteToSavedPhotosAlbum(watermarked, nil, nil, nil)
        return embeddedUUID
    }

    public func hasWatermark(image: UIImage) async -> Bool {
        guard let uuid = try? await decode(image: image) else { return false }
        return uuid != nil
    }
}

