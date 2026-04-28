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
        
    static let shared = AuthManager()
    
    var currentUser: User?
    
    // Change this to your actual local IP or production domain
    private let baseURL = BASEURL
    
    private init() {
        self.currentUser = loadUserFromDefaults()
    }
    
    var isLoggedIn: Bool {
        return UserDefaults.standard.bool(forKey: UDKeys.isLoggedIn)
    }
    
    func register(username: String, password: String, email: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/register") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201, let data = data else {
                    print("Registration failed: \(error?.localizedDescription ?? "Unknown error")")
                    completion(false)
                    return
                }
                
                do {
                    // 1. Create a struct that exactly matches FastAPI's UserRead schema
                    struct BackendUser: Codable {
                        let id: String
                        let username: String
                        let email: String
                    }
                    
                    let decoder = JSONDecoder()
                    let backendUser = try decoder.decode(BackendUser.self, from: data)
                    
                    // 2. Map it to your app's existing User model
                    let userResponse = User(
                        userId: backendUser.id,
                        username: backendUser.username,
                        email: backendUser.email,
                        password: password // Keep the local password since the server (rightfully) didn't send it back
                    )
                    
                    self.currentUser = userResponse
                    self.saveUserToDefaults(userResponse)
                    
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: UDKeys.isLoggedIn)
                    defaults.set(userResponse.userId, forKey: UDKeys.currentUserId)
                    defaults.set(userResponse.username, forKey: UDKeys.currentUsername)
                    
                    completion(true)
                    
                } catch {
                    print("Decoding Error in Register: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/login") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                    print("Login failed: \(error?.localizedDescription ?? "Invalid credentials")")
                    completion(false)
                    return
                }
                
                do {
                    // 1. Match FastAPI's UserRead schema
                    struct BackendUser: Codable {
                        let id: String
                        let username: String
                        let email: String
                    }
                    
                    let decoder = JSONDecoder()
                    let backendUser = try decoder.decode(BackendUser.self, from: data)
                    
                    // 2. Map it to your app's existing User model
                    let userResponse = User(
                        userId: backendUser.id,
                        username: backendUser.username,
                        email: backendUser.email,
                        password: password
                    )
                    
                    self.currentUser = userResponse
                    self.saveUserToDefaults(userResponse)
                    
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: UDKeys.isLoggedIn)
                    defaults.set(userResponse.userId, forKey: UDKeys.currentUserId)
                    defaults.set(userResponse.username, forKey: UDKeys.currentUsername)
                    
                    completion(true)
                    
                } catch {
                    print("Decoding Error in Login: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func saveUserToDefaults(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        }
    }

    private func loadUserFromDefaults() -> User? {
        guard let data = UserDefaults.standard.data(forKey: "currentUser"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
}
