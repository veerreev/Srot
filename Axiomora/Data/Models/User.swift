//
//  UserModel.swift
//  Axiomora
//
//  Created by GEU on 31/01/26.
//

import Foundation

// Codable is used for efficient conversion to JSON
struct User: Codable {
    
    let userId: String
    let username: String
    let email: String
    let createdAt: Date?
    let password: String // To be removed later, only using for pseudoRegister
    
    // Explicit init strictly for decoding or testing
    init(userId: String,
         username: String,
         email: String, password: String) {
        
        self.userId = userId
        self.username = username
        self.email = email
        self.password = password
        self.createdAt = Date()
    }
}
