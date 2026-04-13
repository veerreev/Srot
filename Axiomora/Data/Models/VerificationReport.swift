//
//  VerificationReport.swift
//  Axiomora
//
//  Created by Veer on 02/03/26.
//

import Foundation

// The possible states of a scanned image
enum VerificationStatus: String, Codable {
    case authentic = "Authentic"
    case tampered = "Tampered / Altered"
    case noWatermarkFound = "No Signature Detected"
}

struct VerificationReport: Codable, Identifiable {
    let id: String
    let scanDate: Date // To store when the system validated the image
    let status: VerificationStatus
    
    // The raw ID extracted from the pixels by the ML Engine
    let extractedSignatureId: String?
    
    // The actual profile downloaded from Firebase using the ID above
    // Pass this to the UI to show their info like Social Handles, Email, Date, etc.
    var matchedSignature: Signature?
    
    // An optional confidence score from the ML model (e.g., 0.98)
    var confidenceScore: Double?
}
