//
//  UserModel.swift
//  Axiomora
//
//  Created by GEU on 31/01/26.
//

import Foundation

// Encodable is used for efficient conversion to JSON
struct UserModel: Encodable {
    
    let userId: String
    
    let username: String
    let email: String
    let createdAt: Date
    
    // Explicit init strictly for decoding or testing
    init(userId: String,
         username: String,
         email: String) {
        
        self.userId = userId
        self.username = username
        self.email = email
        self.createdAt = Date()
    }
}
