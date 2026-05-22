//
//  WatermarkManager.swift
//  Axiomora
//
//  Created by Pradumn Kapil on 15/05/26.
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

// MARK: - Supabase Data Transfer Object

struct FingerprintRecord: Codable {
    let signature_id: String
    let fingerprint_full: String
    let fingerprint_center: String
    let fingerprint_safe: String
}

// MARK: - Supabase Serializer

/// Helper class to archive and restore Vision observations to/from Supabase text fields
final class FingerprintSerializer {
    static func string(from observation: VNFeaturePrintObservation) -> String? {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true) else {
            return nil
        }
        return data.base64EncodedString()
    }
    
    static func observation(from base64String: String) -> VNFeaturePrintObservation? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }
}

// MARK: - WatermarkManager

public final class WatermarkManager {

    public static let shared = WatermarkManager()
    
    private let minImageSide = 512
    private let ciContext = CIContext(options: nil)

    // TODO: ⚠️ REPLACE THESE WITH YOUR ACTUAL SUPABASE URL AND ANON KEY
    private let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co/rest/v1/image_fingerprints")!
    private let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    private init() {}

    // MARK: - Public: Encode (Pushes to Supabase)

    public func encode(image: UIImage, uuid: UUID? = nil) async throws -> (UIImage, UUID) {
        let targetUUID = uuid ?? UUID()
        let signatureStringId = targetUUID.uuidString

        guard let cgImage = image.cgImage else {
            throw WatermarkError.imageConversionFailed
        }

        guard min(cgImage.width, cgImage.height) >= minImageSide else {
            throw WatermarkError.imageResolutionTooSmall
        }

        // 1. Generate the 3 color-blind concentric crops
        let crops = extractConcentricCrops(from: cgImage)
        let prints = try await generateFeaturePrints(for: crops)
        
        guard prints.count >= 3,
              let fullStr = FingerprintSerializer.string(from: prints[0]),
              let centerStr = FingerprintSerializer.string(from: prints[1]),
              let safeStr = FingerprintSerializer.string(from: prints[2]) else {
            throw WatermarkError.encodingFailed("Could not serialize Vision prints.")
        }
        
        // 2. Prepare payload for Supabase
        let record = FingerprintRecord(
            signature_id: signatureStringId,
            fingerprint_full: fullStr,
            fingerprint_center: centerStr,
            fingerprint_safe: safeStr
        )
        
        // 3. Network Request to insert into Supabase
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(record)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw WatermarkError.encodingFailed("Supabase server rejected record registration.")
        }

        print("[WatermarkManager] ✓ Fingerprint successfully registered in Supabase. ID: \(signatureStringId)")
        
        // Return the unmodified image
        return (image, targetUUID)
    }

    // MARK: - Public: Decode (Pulls from Supabase & Matches)

    public func decode(image: UIImage) async throws -> UUID? {
        guard let cgImage = image.cgImage else {
            throw WatermarkError.imageConversionFailed
        }

        // 1. Extract and process the screenshot's grayscale crops
        let queryCrops = extractConcentricCrops(from: cgImage)
        let queryPrints = try await generateFeaturePrints(for: queryCrops)
        
        // 2. Fetch all registered fingerprints from Supabase
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "GET"
        request.setValue("bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WatermarkError.decodingFailed("Could not sync with Supabase database server.")
        }
        
        let remoteRecords = try JSONDecoder().decode([FingerprintRecord].self, from: data)
        print("[WatermarkManager] Synced \(remoteRecords.count) reference footprints from Supabase.")
        
        var bestMatchStringID: String? = nil
        var absoluteLowestDistance: Float = 25.0
        
        // 3. Run "Closest Match Wins" over database records
        for record in remoteRecords {
            // Reconstruct the observations out of the downloaded text fields
            guard let fullObs = FingerprintSerializer.observation(from: record.fingerprint_full),
                  let centerObs = FingerprintSerializer.observation(from: record.fingerprint_center),
                  let safeObs = FingerprintSerializer.observation(from: record.fingerprint_safe) else {
                continue
            }
            
            let storedPrints = [fullObs, centerObs, safeObs]
            
            for queryPrint in queryPrints {
                for storedPrint in storedPrints {
                    var distance: Float = .infinity
                    try queryPrint.computeDistance(&distance, to: storedPrint)
                    
                    if distance < absoluteLowestDistance {
                        absoluteLowestDistance = distance
                        bestMatchStringID = record.signature_id
                    }
                }
            }
        }
        
        guard let matchedID = bestMatchStringID, let finalUUID = UUID(uuidString: matchedID) else {
            print("[WatermarkManager] ⚠️ Screenshot patterns did not match any database parameters.")
            throw WatermarkError.watermarkNotFound
        }

        print("[WatermarkManager] ✓ Supabase Match Verified! Distance: \(absoluteLowestDistance)")
        return finalUUID
    }

    // MARK: - Cropping & Grayscale Logic (Filter Immunity)

    private func extractConcentricCrops(from cgImage: CGImage) -> [CGImage] {
        var crops: [CGImage] = []
        
        func addColorBlindCrop(_ crop: CGImage) {
            if let grayCrop = convertToGrayscale(crop) {
                crops.append(grayCrop)
            } else {
                crops.append(crop)
            }
        }
        
        // 1. The Full Image
        addColorBlindCrop(cgImage)
        
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let minSide = min(w, h)
        
        // 2. Center Square (Chops off top/bottom letterbox bars)
        let centerRect = CGRect(x: (w - minSide)/2, y: (h - minSide)/2, width: minSide, height: minSide)
        if let centerCrop = cgImage.cropping(to: centerRect) {
            addColorBlindCrop(centerCrop)
        }
        
        // 3. Safe Zone Inner Square (60% size - Bypasses floating UI)
        let safeSide = minSide * 0.6
        let safeRect = CGRect(x: (w - safeSide)/2, y: (h - safeSide)/2, width: safeSide, height: safeSide)
        if let safeCrop = cgImage.cropping(to: safeRect) {
            addColorBlindCrop(safeCrop)
        }
        
        return crops
    }
    
    private func convertToGrayscale(_ cgImage: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // Removes color
        
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
