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
    
    func pingServerForPermissions() {
        guard let url = URL(string: "\(baseURL)/health") else { return }
        // Firing this silently in the background will force iOS to ask for
        // Local Network permissions if you are using a 192.168.x.x IP address.
        URLSession.shared.dataTask(with: url).resume()
    }
    
    func register(username: String, password: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 1. Check for Internet First!
        if !NetworkMonitor.shared.isConnected {
            completion(false, "No internet connection. Please check your settings.")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/register") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["username": username, "email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201, let data = data else {
                    // Check if it's a 409 Conflict (Username/Email taken)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 409 {
                        completion(false, "Username or email is already taken.")
                    } else {
                        completion(false, "Server error. Please try again later.")
                    }
                    return
                }
                
                do {
                    struct BackendUser: Codable { let id: String; let username: String; let email: String }
                    let backendUser = try JSONDecoder().decode(BackendUser.self, from: data)
                    
                    let userResponse = User(userId: backendUser.id, username: backendUser.username, email: backendUser.email, password: password)
                    self.currentUser = userResponse
                    self.saveUserToDefaults(userResponse)
                    
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: UDKeys.isLoggedIn)
                    defaults.set(userResponse.userId, forKey: UDKeys.currentUserId)
                    defaults.set(userResponse.username, forKey: UDKeys.currentUsername)
                    
                    completion(true, nil)
                } catch {
                    completion(false, "Data processing error.")
                }
            }
        }.resume()
    }
    
    // UPDATE the signature to include a String? for error messages
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 1. Check for Internet First!
        if !NetworkMonitor.shared.isConnected {
            completion(false, "No internet connection. Please check your settings.")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/login") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                        completion(false, "Invalid username or password.")
                    } else {
                        completion(false, "Server error. Please try again later.")
                    }
                    return
                }
                
                do {
                    struct BackendUser: Codable { let id: String; let username: String; let email: String }
                    let backendUser = try JSONDecoder().decode(BackendUser.self, from: data)
                    
                    let userResponse = User(userId: backendUser.id, username: backendUser.username, email: backendUser.email, password: password)
                    self.currentUser = userResponse
                    self.saveUserToDefaults(userResponse)
                    
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: UDKeys.isLoggedIn)
                    defaults.set(userResponse.userId, forKey: UDKeys.currentUserId)
                    defaults.set(userResponse.username, forKey: UDKeys.currentUsername)
                    
                    completion(true, nil)
                } catch {
                    completion(false, "Data processing error.")
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
