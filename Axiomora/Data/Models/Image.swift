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
    let thumbnailFilename: String // Separate smaller file used exclusively for grid thumbnails generated once at capture time so the grid never loads full-res images.
    var remoteURL: String?
    
    // Metadata
    var createdAt: Date?
    var device: String?
    
    // Must include ISO/Shutter-Speed/etc. when implementing pro mode
    
    #warning("To be implemented in gallery")
    // State
    var isFavourite: Bool = false // Whether the user has hearted this image.
                                 // When toggled, PhotoManager automatically adds/removes it from the Favourites album.
    var albumIds: [String] = [] // IDs of every album this image belongs to.(An image can belong to multiple albums simultaneously.)
    
    // Computed URLs
    
    // Full-resolution image URL used in SingleImageViewController
    var localFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(localFilename)
    }
    //    Using computed property because
    //    When saving an image to the local "In-App Gallery," a junior developer will often get the file's path (e.g., file:///var/mobile/Containers/Data/Application/1234-ABCD/Documents/photo.jpg) and save that entire String to UserDefaults or a local database.
    //    Storing as a string works perfectly in testing. But the moment the user downloads an app update from the App Store, iOS changes the app's internal sandbox UUID directory (1234-ABCD becomes 9999-WXYZ). Suddenly, every single saved URL is broken, and the user's entire In-App Gallery shows blank images.
    
    
    // Thumbnail URL — used in FilmstripCell for display, CameraViewController for the last-captured thumbnail circle, and in deleteImage() for cleanup.
    // Will also be used in gallery grid cells when AllPhotosViewController is implemented.
    var thumbnailFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(thumbnailFilename)
    }
}
