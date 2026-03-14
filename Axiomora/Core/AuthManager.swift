//
//  AuthManager.swift
//  Axiomora
//
//  Created by GEU on 09/02/26.
//

import Foundation

class AuthManager {
    
    private enum UDKeys {
            static let isLoggedIn       = "isLoggedIn"
            static let currentUserId    = "currentUserId"
            static let currentUsername  = "currentUsername"
        }
        
    // The shared variable is a constant that holds a single, globally accessible instance of the AuthManager class
    static let shared = AuthManager()
    
    // This tracks who is currently using the app
    var currentUser: User?
    
    // Because the class has a private init(), no other part of the app can create a new instance of AuthManager using AuthManager(). This forces every view controller to use AuthManager.shared.
    private init() {}
    
    var isLoggedIn: Bool {
        return UserDefaults.standard.bool(forKey: UDKeys.isLoggedIn)
    }
    
    func pseudoRegister(username: String, password: String, email: String, completion: @escaping (Bool) -> Void) { // (Result<User, Error>) -> Void)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            
            let newUser = User(
                userId: UUID().uuidString,
                username: username,
                email: email,
                password: password
            )
            
            MockDataBase.shared.registeredUsers[newUser.userId] = newUser
            
            self.currentUser = newUser
            
            let defaults = UserDefaults.standard
                    defaults.set(true,           forKey: UDKeys.isLoggedIn)
                    defaults.set(newUser.userId, forKey: UDKeys.currentUserId)
                    defaults.set(newUser.username, forKey: UDKeys.currentUsername)
            
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
                #warning("Handle error here")
                completion(false)
                return
            }
            
            self.currentUser = user
            
            let defaults = UserDefaults.standard
                    defaults.set(true,          forKey: UDKeys.isLoggedIn)
                    defaults.set(user.userId,   forKey: UDKeys.currentUserId)
                    defaults.set(user.username, forKey: UDKeys.currentUsername)
            
            print("Successfully logged in as: \(user.username)")
            completion(true)
            
        })
    }
    
}
