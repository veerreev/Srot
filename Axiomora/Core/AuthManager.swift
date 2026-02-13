//
//  AuthManager.swift
//  Axiomora
//
//  Created by GEU on 09/02/26.
//

import Foundation

class AuthManager {
    
    static let shared = AuthManager()
    
    // This tracks who is currently using the app
    var currentUser: User?
    
    private init() {}
    
    func pseudoSignUp(username: String, password: String, email: String, completion: @escaping (Bool) -> Void) { // (Result<User, Error>) -> Void)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            
            let newUser = User(
                userId: UUID().uuidString,
                username: username,
                email: email,
                password: password
            )
            
            MockDataBase.shared.registeredUsers[newUser.userId] = newUser
            
            self.currentUser = newUser
            
            print("Registered New User: \(username), with User ID: \(newUser.userId)")
            completion(true)
            
        })
    }
}

extension AuthManager {
    
    func pseudoLogin(username: String, password: String, completion: @escaping (Bool) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: { // 'execute' can be removed from the parameters (trailing closure syntax)
            
            guard let user = MockDataBase.shared.registeredUsers.values.first(where: { $0.username == username && $0.password == password }) else {
                print("Invalid Username or Password")
                completion(false)
                return
            }
            
            self.currentUser = user
            
            print("Successfully logged in as: \(user.username)")
            completion(true)
            
        })
    }
    
}
