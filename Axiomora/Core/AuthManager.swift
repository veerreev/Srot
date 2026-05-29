//
//  AuthManager.swift
//  Axiomora
//
//  Created by GEU on 09/02/26.
//

import Foundation

// Represents the currently logged-in user in memory
struct CurrentUser: Codable {
    let userId: String
    let token: String
}

final class AuthManager {
    static let shared = AuthManager()
    
    // TODO: ⚠️ REPLACE THESE WITH YOUR ACTUAL SUPABASE URL AND ANON KEY
    private let supabaseURL = "https://mdmdecsljntrhxkyhjds.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kbWRlY3Nsam50cmh4a3loamRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwNzU0NTAsImV4cCI6MjA5NDY1MTQ1MH0.K7JTxmMRDvZR5lAQi3nnG3kF2Lf8hZmVwB3RAP2DAkI"
    
    // Auto-saves to UserDefaults whenever the user logs in or registers
    private(set) var currentUser: CurrentUser? {
        didSet {
            if let user = currentUser, let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: "axiomora_current_user")
            } else {
                UserDefaults.standard.removeObject(forKey: "axiomora_current_user")
            }
        }
    }
    
    private init() {
        // Automatically restore the user session from disk when the app restarts
        if let data = UserDefaults.standard.data(forKey: "axiomora_current_user"),
           let user = try? JSONDecoder().decode(CurrentUser.self, from: data) {
            self.currentUser = user
        }
    }
    
    // MARK: - Register
    
    func register(username: String, password: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        let endpoint = "\(supabaseURL)/auth/v1/signup"
        
        // Supabase expects email & password. We pass username into "data" (user_metadata)
        let payload: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["username": username]
        ]
        
        performAuthRequest(endpoint: endpoint, payload: payload) { [weak self] success, token, userId, errorMessage in
            guard let self = self else { return }
            
            if success, let userId = userId {
                self.currentUser = CurrentUser(userId: userId, token: token ?? "")
                
                // Create the public profile mapping so they can log in on different devices using username
                self.createProfileMapping(username: username, email: email, userId: userId) { profileSuccess in
                    DispatchQueue.main.async {
                        if profileSuccess {
                            // Upload any existing local offline signatures to their new account
                            self.syncAllLocalSignaturesToSupabase()
                            completion(true, nil)
                        } else {
                            completion(false, "Account created, but failed to establish username link.")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async { completion(false, errorMessage) }
            }
        }
    }
    
    // MARK: - Log In & Sync Signatures
    
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let cleanedInput = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the user entered an email directly, log in immediately
        if cleanedInput.contains("@") {
            self.performLogin(email: cleanedInput, password: password, completion: completion)
        } else {
            // If they entered a username, resolve it to their registered email first
            resolveUsernameToEmail(username: cleanedInput) { [weak self] resolvedEmail in
                guard let self = self else { return }
                guard let email = resolvedEmail else {
                    DispatchQueue.main.async {
                        completion(false, "No account found matching username '\(cleanedInput)'.")
                    }
                    return
                }
                self.performLogin(email: email, password: password, completion: completion)
            }
        }
    }
    
    // MARK: - Profile Mapping Helpers
    
    private func createProfileMapping(username: String, email: String, userId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/profiles") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let payload: [String: Any] = [
            "username": username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            "user_id": userId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[AuthManager] Profile mapping failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("[AuthManager] Profile mapping was rejected by Supabase database rules.")
                completion(false)
                return
            }
            completion(true)
        }.resume()
    }
    
    private func resolveUsernameToEmail(username: String, completion: @escaping (String?) -> Void) {
        let formattedUsername = username.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(supabaseURL)/rest/v1/profiles?username=eq.\(formattedUsername)&select=email") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstMatch = jsonArray.first,
                   let email = firstMatch["email"] as? String {
                    completion(email)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    private func performLogin(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let endpoint = "\(supabaseURL)/auth/v1/token?grant_type=password"
        let payload: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        performAuthRequest(endpoint: endpoint, payload: payload) { [weak self] success, token, userId, errorMessage in
            guard let self = self else { return }
            
            if success, let token = token, let userId = userId {
                self.currentUser = CurrentUser(userId: userId, token: token)
                
                // Fetch user's signatures from the database BEFORE confirming login success
                self.syncSignatures(token: token) {
                    // Upload any local signatures to the cloud if they aren't synced yet
                    self.syncAllLocalSignaturesToSupabase()
                    DispatchQueue.main.async { completion(true, nil) }
                }
            } else {
                DispatchQueue.main.async { completion(false, errorMessage) }
            }
        }
    }
    
    // MARK: - Signature Syncing
    
    /// Pulls the user's signatures from the Supabase database and stores them locally on the device.
    private func syncSignatures(token: String, completion: @escaping () -> Void) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/signatures?select=*") else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { completion() } // Always complete, even on error
            
            guard let data = data, error == nil else {
                print("[AuthManager] Signature sync failed: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    print("[AuthManager] Sync failed: response is not a valid JSON array.")
                    return
                }
                
                var fetchedSignatures: [Signature] = []
                let decoder = JSONDecoder()
                
                for dict in jsonArray {
                    // MAGIC DECODE: We extract the exact 1:1 Swift JSON from the payload column
                    if let payload = dict["payload"] as? [String: Any] {
                        do {
                            let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
                            let signature = try decoder.decode(Signature.self, from: payloadData)
                            fetchedSignatures.append(signature)
                        } catch {
                            print("[AuthManager] Failed to decode a signature payload: \(error)")
                        }
                    } else {
                        print("[AuthManager] Skipping a signature because 'payload' column is missing.")
                    }
                }
                
                // CRITICAL RACE CONDITION FIX: Write synchronously
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                if let fileURL = paths.first?.appendingPathComponent("saved_signatures.json") {
                    let fileData = try JSONEncoder().encode(fetchedSignatures)
                    try fileData.write(to: fileURL, options: .atomic)
                    print("[AuthManager] ✓ Synced and written \(fetchedSignatures.count) signatures directly to disk.")
                }
                
            } catch {
                print("[AuthManager] Failed to parse Supabase array: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Signature Cloud Upload Pipeline
    
    public func uploadSignature(_ signature: Signature) {
        guard let currentUser = self.currentUser, !currentUser.token.isEmpty else {
            print("[AuthManager] Cannot upload signature: No authenticated user session.")
            return
        }
        uploadSignatureToSupabase(signature, token: currentUser.token, userId: currentUser.userId)
    }
    
    public func syncAllLocalSignaturesToSupabase() {
        guard let currentUser = self.currentUser, !currentUser.token.isEmpty else { return }
        let localSignatures = SignatureManager.shared.loadSignatures()
        for signature in localSignatures {
            uploadSignatureToSupabase(signature, token: currentUser.token, userId: currentUser.userId)
        }
        print("[AuthManager] Background syncing \(localSignatures.count) signatures to cloud...")
    }
    
    /// Serializes a Swift Signature object into a JSON query payload for Supabase insertion.
    private func uploadSignatureToSupabase(_ signature: Signature, token: String, userId: String) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/signatures") else { return }
        
        guard let data = try? JSONEncoder().encode(signature),
              let originalDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let id = originalDict["id"] as? String else {
            print("[AuthManager] Error: Failed to serialize signature schema.")
            return
        }
        
        var dict: [String: Any] = [:]
        
        // Map top level columns for your Dashboard
        dict["id"] = id
        dict["user_id"] = userId
        dict["is_current"] = originalDict["isCurrent"] ?? originalDict["is_current"] ?? false
        dict["should_include_location"] = originalDict["shouldIncludeLocation"] ?? originalDict["should_include_location"] ?? false
        
        let potentialNames = ["name", "displayName", "display_name", "title"]
        for key in potentialNames {
            if let val = originalDict[key] as? String {
                dict["name"] = val; break
            }
        }
        
        // *** THE MAGIC FIX ***
        // We pack the entire unaltered Swift dictionary into a JSONB payload column.
        // This guarantees NO data is lost, regardless of what's inside the Signature struct.
        dict["payload"] = originalDict
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: dict, options: [])
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[AuthManager] Signature cloud backup failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("[AuthManager] ✓ Signature \(signature.id) verified in Supabase.")
            } else if let responseCode = (response as? HTTPURLResponse)?.statusCode {
                print("[AuthManager] ⚠️ Cloud signature upload returned HTTP status code: \(responseCode)")
            }
        }.resume()
    }
    
    // MARK: - Networking Helper
    
    private func performAuthRequest(endpoint: String, payload: [String: Any], completion: @escaping (Bool, String?, String?, String?) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(false, nil, nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(false, nil, nil, "Failed to encode request.")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, nil, nil, error.localizedDescription)
                return
            }
            
            guard let data = data else {
                completion(false, nil, nil, "No data received from server.")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                // Parse Supabase error message
                var errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
                               ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                               ?? "Authentication failed."
                
                // Intercept email rate limits and provide clear, actionable instructions
                if errorMsg.lowercased().contains("rate limit") || errorMsg.lowercased().contains("limit exceeded") {
                    errorMsg = "Email rate limit exceeded. Please disable 'Confirm Email' in your Supabase Auth Dashboard settings under Providers -> Email."
                }
                
                completion(false, nil, nil, errorMsg)
                return
            }
            
            // Parse successful token response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Scenario A: Access token returned directly (auto-confirm is enabled or standard login)
                    if let accessToken = json["access_token"] as? String,
                       let user = json["user"] as? [String: Any],
                       let userId = user["id"] as? String {
                        completion(true, accessToken, userId, nil)
                        return
                    }
                    
                    // Scenario B: Signup succeeded but requires email confirmation (user returned, no access_token yet)
                    if let user = json["user"] as? [String: Any],
                       let userId = user["id"] as? String {
                        completion(true, nil, userId, nil)
                        return
                    }
                    
                    // Fallback to direct root UUID key check
                    if let userId = json["id"] as? String {
                        completion(true, nil, userId, nil)
                        return
                    }
                }
                
                completion(false, nil, nil, "Invalid server response format.")
            } catch {
                completion(false, nil, nil, "Failed to decode server response.")
            }
        }.resume()
    }
}
