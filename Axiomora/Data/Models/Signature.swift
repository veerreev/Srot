//
//  SignatureModel.swift
//  Axiomora
//
//  Created by GEU on 31/01/26.
//

import Foundation

// defining supported platforms.
#warning("The user might want to add more social platforms in the future.")

enum SocialPlatform: String, Codable, CaseIterable {
    case instagram = "Instagram"
    case x = "X (Twitter)"
    case facebook = "Facebook"
    case youtube = "YouTube"
    case linkedin = "LinkedIn"
    case pinterest = "Pinterest"
    case behance = "Behance"
    case flickr = "Flickr"
    case adobePortfolio = "Adobe Portfolio"
    case glass = "Glass"
    case telegram = "Telegram"
    
    
    var iconName: String {
        return self.rawValue.lowercased() // Useful for asset lookups, Self -> Refers to the specific case of the enum
    }
}

// The individual handle entry
struct SocialHandle: Codable {
    let platform: SocialPlatform
    var username: String
}

// The main Signature Model
struct Signature: Codable, Identifiable {
    var id: String // This ID will eventually map to the ML Watermark, Output like: "550e8400-e29b-41d4-a716-446655440000"
    var title: String // e.g.: "Professional Profile" or "Personal"
    var handles: [SocialHandle]
    var createdAt: Date // Do we need this??
    var personalPortfolio: URL?
    
    // Helper to get a specific handle if it exists
    func handle(for platform: SocialPlatform) -> String? {
        return handles.first(where: { $0.platform == platform })?.username
    }
}
