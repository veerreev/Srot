//
//  WatermarkDecoder.swift
//  Axiomora
//
//  WatermarkDecoder.swift
//  Axiomora

import UIKit

final class WatermarkDecoder {

    static let shared = WatermarkDecoder()
    private init() {}

    // MARK: - Public API

    /// Decode the watermark in `image` and return a VerificationReport.
    /// Always returns a report — never throws. Call from any async context.
    func decode(_ image: UIImage) async -> VerificationReport {

        // ── Step 1: Run the Vision Matcher (Hits Supabase Database) ───────────────
        let decodedUUID: UUID?
        do {
            decodedUUID = try await WatermarkManager.shared.decode(image: image)
        } catch {
            print("[WatermarkDecoder] Vision match failed or no match found: \(error.localizedDescription)")
            return noWatermarkReport()
        }

        guard let verifiedUUID = decodedUUID else {
            print("[WatermarkDecoder] No matching fingerprints found in database.")
            return noWatermarkReport()
        }

        let matchedID = verifiedUUID.uuidString
        print("[WatermarkDecoder] ✓ Master match found: \(matchedID)")

        // ── Step 2: Resolve Signature profile locally ───────────────────────────
        let signature = SignatureManager.shared.loadSignatures()
            .first { $0.id.uppercased() == matchedID.uppercased() }

        if signature != nil {
            print("[WatermarkDecoder] ✓ Resolved profile identity locally.")
        } else {
            print("[WatermarkDecoder] ⚠️ Match found, but profile not in SignatureManager configuration.")
        }

        // ── Step 3: Return success report immediately ───────────────────────────
        return VerificationReport(
            id:                   UUID().uuidString,
            scanDate:             Date(),
            status:               .authentic,
            extractedSignatureId: matchedID,
            matchedSignature:     signature,
            confidenceScore:      1.0 // Vision match yields complete confidence for the demo
        )
    }

    // MARK: - Report factory

    private func noWatermarkReport() -> VerificationReport {
        VerificationReport(
            id:                   UUID().uuidString,
            scanDate:             Date(),
            status:               .noWatermarkFound,
            extractedSignatureId: nil,
            matchedSignature:     nil,
            confidenceScore:      0
        )
    }
}
