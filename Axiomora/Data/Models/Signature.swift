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
    
    // Each platform knows its root URL
    var baseURL: String {
        switch self {
        case .instagram: return "https://www.instagram.com/"
        case .x: return "https://x.com/"
        case .facebook: return "https://www.facebook.com/"
        case .youtube: return "https://www.youtube.com/"
        case .linkedin: return "https://www.linkedin.com/in/"
        case .pinterest: return "https://in.pinterest.com/"
        case .behance: return "https://www.behance.net/"
        case .flickr: return "https://www.flickr.com/"
        case .adobePortfolio: return "https://portfolio.adobe.com/"
        case .glass: return "https://glass.photo/"
        case .telegram: return "https://web.telegram.org/"
        }
    }
    
    var iconName: String {
        return self.rawValue.lowercased() // Useful for asset lookups, Self -> Refers to the specific case of the enum
    }
}


// The individual handle entry
struct SocialHandle: Codable {
    
    let platform: SocialPlatform
    var userInput: String // e.g., "https://instagram.com/pappu_photus"
    // using let handleURL: URL because decoding the object might cause errors if the URL is not perfect, e.g. the user missed https://
    
    var profileURL: URL? {
        // clean up accidental spaces and remove the "@" if they typed it
        var cleanInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanInput.hasPrefix("@") {
            cleanInput.removeFirst()
        }
        
        // did they paste a perfect, full link?
        if cleanInput.lowercased().hasPrefix("http://") || cleanInput.lowercased().hasPrefix("https://") {
            return URL(string: cleanInput)
        }
        
        // did they type 'instagram.com/axiomora' (Missing https)?
        if cleanInput.lowercased().contains(".com") || cleanInput.lowercased().contains(".net") {
            return URL(string: "https://\(cleanInput)")
        }
        
        // the "Best UX" Case - They just typed 'pappu_photus'
        // We combine the platform's base URL with their username
        return URL(string: platform.baseURL + cleanInput)
    }
    
//    // Example usage in a UI ViewController
//    func openSocialLink(handle: SocialHandle) {
//        guard let safeURL = handle.profileURL else {
//            print("Could not construct a valid URL for \(handle.platform.rawValue)")
//            return
//        }
//        
//        // Safely open the URL
//        UIApplication.shared.open(safeURL)
//    }
}


// The main Signature Model
struct Signature: Codable, Identifiable {
    
    let id: String // This ID will eventually map to the ML Watermark, Output like: "550e8400-e29b-41d4-a716-446655440000"
    let creatorID: String // Maps back to AuthManager.shared.currentUser.userId
    var title: String // e.g.: "Professional Profile" or "Personal"
    
    // Identity
    var displayName: String
    var copyrightText: String? // A photographing agency would want to add their copyright text, but a casual photographer might not want that
    
    // Contact
    var email: String?
    var website: String? // Personal Portfolio
        // The Computed Property, used by the UI when a button is tapped
        var websiteURL: URL? {
            guard let urlString = website, !urlString.isEmpty else { return nil }
            
            // If they forgot 'https://', we help them out so the link actually opens
            if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
                return URL(string: "https://\(urlString)")
            }
            
            return URL(string: urlString)
        }
    var socialHandles: [SocialHandle]
    
//    Moved this part to image model, because this is different for each image
//
//    // Metadata - Added at the exact moment of capture
//    var device: String?
//    var createdAt: Date? // Do we need this??
    
    
//    Helper to get a specific handle if it exists
    func handle(for platform: SocialPlatform) -> URL? {
        return socialHandles.first(where: { $0.platform == platform })?.profileURL
    }
}
