//
//  SignatureManager.swift
//  Axiomora
//
//  Created by Veer on 03/04/26.
//


import Foundation

class SignatureManager {
    
    static let shared = SignatureManager()
    
    // The file path where our JSON will live on the device
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("saved_signatures.json")
    }
    
    private init() {} // Prevents accidental instantiation elsewhere
    
    func saveSignatures(_ signatures: [Signature]) {
        // Pushing file I/O to a background thread so the UI never stutters
        #warning("Replace with async/await")
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(signatures)
                // .atomic ensures it writes to a temp file first, preventing data corruption if the app crashes mid-write
                try data.write(to: self.fileURL, options: .atomic) 
            } catch {
                print("Failed to save signatures: \(error)")
            }
        }
    }
    
    func loadSignatures() -> [Signature] {
        do {
            let data = try Data(contentsOf: fileURL)
            let signatures = try JSONDecoder().decode([Signature].self, from: data)
            return signatures
        } catch {
            print("No signatures found or failed to load. Returning empty array.")
            return [] // Returns empty if it's the user's first time opening the app
        }
    }
}
