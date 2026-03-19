//
//  AlbumModel.swift
//  Axiomora
//
//  Created by GEU on 31/01/26.
//

import Foundation

struct Album: Codable, Identifiable {
    
    //Identifiers
    let id: String
    var name: String // e.g., "All Photos" or "Studio Shoot"
    let creationDate: Date
    
    //Type
    var isSystemAlbum: Bool // System albums (e.g. Favourites) are created and managed by PhotoManager automatically. They cannot be renamed or deleted by the user.
    
    //Contents
    var imageIds: [String] // We only store the IDs of the images, NOT the actual ImageModel objects

    //Cover Image
    var coverImageLocalFilename: String? // Optional: The filename of the image to display as the album cover
    
    // The safely computed URL, just like in ImageModel
    var coverImageLocalFileURL: URL? {
        // If there is no cover image set yet, return nil
        guard let filename = coverImageLocalFilename else { return nil }
        
        // Dynamically fetch the current Documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(filename)
    }
    
    init(id: String = UUID().uuidString, name: String, isSystemAlbum: Bool = false) { // isSystemAlbum defaults to false, only PhotoManager passes true when creating Favourites.
        self.id = id
        self.name = name
        self.isSystemAlbum = isSystemAlbum
        self.creationDate = Date()
        self.imageIds = []
    }
}
