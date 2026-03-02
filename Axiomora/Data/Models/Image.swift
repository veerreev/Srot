//
//  ImageModel.swift
//  Axiomora
//
//  Created by GEU on 31/01/26.
//

import Foundation

struct Image: Codable {
    
    // Identifiers
    let id: String
    let creatorId: String
    let signatureId: String
    
    // Storage
    let localFilename: String
    var remoteURL: String?
    
    // Metadata
    var createdAt: Date?
    var device: String?
    
    // Must include ISO/Shutter-Speed/etc. when implementing pro mode
    
    // Computed Property
    var localFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(localFilename)
    }
    
//    Using computed property because
//    When saving an image to the local "In-App Gallery," a junior developer will often get the file's path (e.g., file:///var/mobile/Containers/Data/Application/1234-ABCD/Documents/photo.jpg) and save that entire String to UserDefaults or a local database.
//    
//    It works perfectly in testing. But the moment the user downloads an app update from the App Store, iOS changes the app's internal sandbox UUID directory (1234-ABCD becomes 9999-WXYZ). Suddenly, every single saved URL is broken, and the user's entire In-App Gallery shows blank images.
    
}
