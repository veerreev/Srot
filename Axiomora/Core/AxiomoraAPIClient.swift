//
//  AxiomoraAPIClient.swift
//  Axiomora
//
//  The single point of contact between the app and the Axiomora VPS backend.
//
//  ENDPOINTS
//  ─────────
//  POST /signatures          Register a new signature (called once when user creates a Signature profile)
//  GET  /signatures/{uuid}   Look up a signature by the UUID embedded in the image watermark
//
//  All requests are JSON over HTTPS.  The client uses Swift Concurrency (async/await)
//  so callers never need to think about threads or DispatchQueues.
//
//  CONFIGURATION
//  ─────────────
//  Change `baseURL` to your VPS address. During development you can point it
//  at http://localhost:8000 with App Transport Security disabled for localhost.
//  In production, always use HTTPS.

import Foundation

// ---------------------------------------------------------------------------
// MARK: - API Error
// ---------------------------------------------------------------------------

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case notFound          // 404 — signature UUID not registered on the server
    case unauthorized      // 401 — bad API key

    var errorDescription: String? {
        switch self {
        case .invalidURL:                       return "Invalid server URL."
        case .networkError(let e):              return "Network error: \(e.localizedDescription)"
        case .httpError(let c, let b):          return "Server returned \(c): \(b)"
        case .decodingError(let e):             return "Response decode error: \(e.localizedDescription)"
        case .notFound:                         return "Signature not found on server."
        case .unauthorized:                     return "Unauthorized — check API key."
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Wire types
//
//  These match the JSON shapes defined in the Python backend exactly.
//  Keep them in sync with backend/models.py.
// ---------------------------------------------------------------------------

/// Sent to POST /signatures when a user creates a new Signature profile.
struct RegisterSignatureRequest: Encodable {
    let id: String                   // UUID string — the watermark payload
    let creatorId: String            // AuthManager.shared.currentUser.userId
    let displayName: String
    let email: String?
    let website: String?
    let copyrightText: String?
    let socialHandles: [SocialHandlePayload]
    let notes: String?

    struct SocialHandlePayload: Encodable {
        let platform: String
        let userInput: String
    }
}

/// Returned by GET /signatures/{uuid}.
/// A subset of the full Signature model — only what the server stores.
struct SignatureResponse: Decodable {
    let id: String
    let creatorId: String
    let displayName: String
    let email: String?
    let website: String?
    let copyrightText: String?
    let socialHandles: [SocialHandlePayload]
    let notes: String?
    let registeredAt: String         // ISO-8601 date string

    struct SocialHandlePayload: Decodable {
        let platform: String
        let userInput: String
    }

    /// Convert the server response back into the app's rich Signature model.
    func toSignature() -> Signature {
        let handles: [SocialHandle] = socialHandles.compactMap { payload in
            guard let platform = SocialPlatform(rawValue: payload.platform) else { return nil }
            return SocialHandle(platform: platform, userInput: payload.userInput)
        }
        return Signature(
            id:                    id,
            creatorID:             creatorId,
            title:                 "Verified Profile",
            isCurrent:             false,   // doesn't matter on the verify side
            displayName:           displayName,
            copyrightText:         copyrightText,
            email:                 email,
            website:               website,
            socialHandles:         handles,
            shouldIncludeLocation: false,
            notes:                 notes
        )
    }
}

// ---------------------------------------------------------------------------
// MARK: - Client
// ---------------------------------------------------------------------------

final class AxiomoraAPIClient {

    static let shared = AxiomoraAPIClient()
    private init() {}

    // ── Configuration ─────────────────────────────────────────────────────────

    /// Your VPS address.  No trailing slash.
    /// Change to https://your-domain.com in production.
    private let baseURL = "http://172.16.10.201:8000"      // ← Use https only with a real TLS certificate

    /// Optional bearer token for write endpoints (registration).
    /// Store this in the Keychain in production — UserDefaults is acceptable
    /// only for local development.
    private let apiKey: String? = nil                    // ← SET THIS if your backend requires auth

    // ── URLSession ─────────────────────────────────────────────────────────────

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        // Allow plain HTTP to local/development servers.
        // For production HTTPS servers this delegate is never called.
        return URLSession(configuration: config, delegate: ATSBypassDelegate(), delegateQueue: nil)
    }()

    // ── JSON coders ────────────────────────────────────────────────────────────

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // =========================================================================
    // MARK: - Public API
    // =========================================================================

    // ── POST /signatures ───────────────────────────────────────────────────────

    /// Register a new signature profile on the server.
    ///
    /// Call this once right after the user creates a `Signature` locally,
    /// so the server can return the full profile when any verifier queries it.
    ///
    /// - Parameter signature: The local Signature model to upload.
    /// - Throws: `APIError`
    func registerSignature(_ signature: Signature) async throws {
        let payload = RegisterSignatureRequest(
            id:            signature.id,
            creatorId:     signature.creatorID,
            displayName:   signature.displayName,
            email:         signature.email,
            website:       signature.website,
            copyrightText: signature.copyrightText,
            socialHandles: signature.socialHandles.map {
                .init(platform: $0.platform.rawValue, userInput: $0.userInput)
            },
            notes: signature.notes
        )

        let request = try buildRequest(method: "POST", path: "/signatures", body: payload)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        print("[APIClient] ✓ Signature \(signature.id) registered on server.")
    }

    // ── PUT /signatures/{uuid} ────────────────────────────────────────────────

    /// Update an existing signature profile (called when the user edits their profile).
    func updateSignature(_ signature: Signature) async throws {
        let payload = RegisterSignatureRequest(
            id:            signature.id,
            creatorId:     signature.creatorID,
            displayName:   signature.displayName,
            email:         signature.email,
            website:       signature.website,
            copyrightText: signature.copyrightText,
            socialHandles: signature.socialHandles.map {
                .init(platform: $0.platform.rawValue, userInput: $0.userInput)
            },
            notes: signature.notes
        )
        let request = try buildRequest(method: "PUT", path: "/signatures/\(signature.id)", body: payload)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        print("[APIClient] ✓ Signature \(signature.id) updated on server.")
    }

    // ── GET /signatures/{uuid} ─────────────────────────────────────────────────

    /// Look up a signature by the UUID extracted from a watermarked image.
    ///
    /// - Parameter uuid: The UUID string decoded from the watermark bits.
    /// - Returns: The full `Signature` model, reconstructed from the server response.
    /// - Throws: `APIError.notFound` if the UUID is not in the server database.
    func fetchSignature(uuid: String) async throws -> Signature {
        let request = try buildRequest(method: "GET", path: "/signatures/\(uuid)", body: Optional<String>.none)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        let decoded = try decode(SignatureResponse.self, from: data)
        return decoded.toSignature()
    }

    // =========================================================================
    // MARK: - Private helpers
    // =========================================================================

    private func buildRequest<Body: Encodable>(method: String,
                                               path: String,
                                               body: Body?) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = apiKey {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func checkHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401:       throw APIError.unauthorized
        case 404:       throw APIError.notFound
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            // Log the raw response so decoding failures are easy to diagnose.
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[APIClient] Decode failed. Raw response: \(raw)")
            throw APIError.decodingError(error)
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - ATS bypass for plain HTTP (development only)
// ---------------------------------------------------------------------------
// In production, delete this class and use HTTPS exclusively.
// In Info.plist, add NSAppTransportSecurity > NSAllowsArbitraryLoads = YES
// for local testing, OR use a proper TLS certificate on the server.

private final class ATSBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accept self-signed certs in development.
        // REMOVE THIS IN PRODUCTION.
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
