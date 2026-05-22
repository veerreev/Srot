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

import Foundation

let BASEURL = "http://10.34.102.127:8000"

// ---------------------------------------------------------------------------
// MARK: - API Error
// ---------------------------------------------------------------------------

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case notFound
    case unauthorized

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
// ---------------------------------------------------------------------------

struct RegisterHashRequest: Encodable {
    let imageId: String
    let signatureId: String
    let tileHashes: [String]
}

struct VerifyHashRequest: Encodable {
    let candidateHashes: [String]
}

struct MatchResultResponse: Decodable {
    let imageId: String
    let signatureId: String
    let comparison: VerificationComparison
    
    struct VerificationComparison: Decodable {
        let matchedCount: Int
        let exactMatchedCount: Int
        let totalCount: Int
        let matchFraction: Double
        let damagedPercent: Int
        let signatureDetected: Bool
        let isPristine: Bool
        
        func toAppResult() -> ImageHasher.ComparisonResult {
            return ImageHasher.ComparisonResult(
                matchedCount: matchedCount,
                exactMatchedCount: exactMatchedCount,
                totalCount: totalCount
            )
        }
    }
}

struct RegisterSignatureRequest: Encodable {
    let id: String
    let creatorId: String
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

struct SignatureResponse: Decodable {
    let id: String
    let creatorId: String
    let displayName: String
    let email: String?
    let website: String?
    let copyrightText: String?
    let socialHandles: [SocialHandlePayload]
    let notes: String?
    let registeredAt: String

    struct SocialHandlePayload: Decodable {
        let platform: String
        let userInput: String
    }

    func toSignature() -> Signature {
        let handles: [SocialHandle] = socialHandles.compactMap { payload in
            guard let platform = SocialPlatform(rawValue: payload.platform) else { return nil }
            return SocialHandle(platform: platform, userInput: payload.userInput)
        }
        return Signature(
            id:                    id,
            creatorID:             creatorId,
            title:                 "Verified Profile",
            isCurrent:             false,
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

    private let baseURL = BASEURL
    private let apiKey: String? = nil

    // ── URLSession ─────────────────────────────────────────────────────────────

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        
        // 🚨 THE FIX FOR -1009 ERRORS ON STARTUP
        // This tells iOS to pause the network request and wait for the "Local Network"
        // permission prompt to be accepted, rather than instantly failing.
        config.waitsForConnectivity = true
        
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
    
    func registerImageHashes(imageId: String, signatureId: String, tileHashes: [String]) async throws {
        let payload = RegisterHashRequest(imageId: imageId, signatureId: signatureId, tileHashes: tileHashes)
        let request = try buildRequest(method: "POST", path: "/hashes", body: payload)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        print("[APIClient] ✓ Global hash registered on VPS for image \(imageId).")
    }

    func verifyImageHashes(candidateHashes: [String]) async throws -> MatchResultResponse {
        let payload = VerifyHashRequest(candidateHashes: candidateHashes)
        let request = try buildRequest(method: "POST", path: "/verify-hash", body: payload)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        return try decode(MatchResultResponse.self, from: data)
    }
    
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

    func patchSignature(_ signature: Signature) async throws {
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
        let request = try buildRequest(method: "PATCH", path: "/signatures/\(signature.id)", body: payload)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        print("[APIClient] ✓ Signature \(signature.id) patched on server.")
    }

    /// Fetch every registered signature UUID. Used by WatermarkDecoder for fuzzy matching.
    func fetchAllSignatureIds() async throws -> [String] {
        let request = try buildRequest(method: "GET", path: "/signatures/ids", body: Optional<String>.none)
        let (data, response) = try await perform(request)
        try checkHTTP(response, data: data)
        do {
            return try decoder.decode([String].self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[APIClient] fetchAllSignatureIds decode failed. Raw: \(raw)")
            throw APIError.decodingError(error)
        }
    }

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
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[APIClient] Decode failed. Raw response: \(raw)")
            throw APIError.decodingError(error)
        }
    }
}

private final class ATSBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
