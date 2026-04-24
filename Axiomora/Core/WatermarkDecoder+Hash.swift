//
//  WatermarkDecoder+Hash.swift
//  Axiomora
//
//  Adds `decodeWithHashFallback(_:)` — a two-stage verification pipeline
//  that combines the neural watermark decoder with tile-hash tamper detection.
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  STAGE 1 — Neural (existing WatermarkDecoder.decode)                │
//  │  Runs the CoreML decoder, averages tile bit-probabilities, applies   │
//  │  BCH error correction, and looks up the UUID in SignatureManager.    │
//  │  Survives: JPEG compression, rotation, crop, colour shifts, blur.   │
//  │  Does NOT produce tamper-damage percentage.                          │
//  ├─────────────────────────────────────────────────────────────────────┤
//  │  STAGE 2 — Tile-hash fallback (this file)                           │
//  │  Only reached when Stage 1 returns .noWatermarkFound.               │
//  │  Recomputes per-tile SHA-256 hashes of the candidate image and       │
//  │  compares against every TileRecord in HashStore.                     │
//  │                                                                     │
//  │  Decision table:                                                     │
//  │    ≥ 35% tiles match  AND  100% match → .authentic  (pristine)      │
//  │    ≥ 35% tiles match  AND  < 100%     → .tampered   (with % damage) │
//  │    < 35% tiles match                  → .noWatermarkFound           │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  USAGE
//  ─────
//  Replace every call to `WatermarkDecoder.shared.decode(_:)` with:
//
//      Task.detached(priority: .userInitiated) {
//          let report = await WatermarkDecoder.shared.decodeWithHashFallback(image)
//          await MainActor.run { self.handleReport(report) }
//      }
//
//  Then read `report.hashComparison` for the tile-level statistics and
//  `report.verificationMethod` to know which pipeline produced the result.

import UIKit

// ---------------------------------------------------------------------------
// MARK: - Supporting types
// ---------------------------------------------------------------------------

/// Which pipeline produced a VerificationReport.
enum VerificationMethod: String, Codable {
    case neural = "Neural Watermark"
    case hash   = "Hash Fingerprint"
    case none   = "None"
}

// ---------------------------------------------------------------------------
// MARK: - WatermarkDecoder extension
// ---------------------------------------------------------------------------

extension WatermarkDecoder {

    // MARK: Two-stage decode

    /// Run Stage 1 (neural); if it fails, run Stage 2 (tile-hash fallback).
    ///
    /// Always returns a `VerificationReport`.  Check:
    ///   • `report.status`              → .authentic / .tampered / .noWatermarkFound
    ///   • `report.verificationMethod`  → .neural / .hash / .none
    ///   • `report.hashComparison`      → tile-level stats (hash path only)
    ///   • `report.damagedPercent`      → convenience accessor for UI display
    func decodeWithHashFallback(_ image: UIImage) async -> VerificationReport {

        // ── Stage 1: neural ───────────────────────────────────────────────────
        let neuralReport = await Task.detached(priority: .userInitiated) {
            self.decode(image)
        }.value

        if neuralReport.status != .noWatermarkFound {
            var tagged = neuralReport
            tagged.verificationMethod = .neural
            print("[Decoder+Hash] ✓ Neural path: \(neuralReport.status.rawValue)")
            return tagged
        }

        print("[Decoder+Hash] Neural path found nothing — running tile-hash fallback…")

        // ── Stage 2: tile-hash ─────────────────────────────────────────────────
        return await Task.detached(priority: .userInitiated) {
            self.hashFallback(image)
        }.value
    }

    // MARK: Hash fallback (private)

    private func hashFallback(_ image: UIImage) -> VerificationReport {

        // 1. Hash the candidate image.
        guard let candidateHashes = ImageHasher.tileHashes(image) else {
            print("[Decoder+Hash] Image too small to tile-hash.")
            return noMatchReport()
        }
        print("[Decoder+Hash] Candidate: \(candidateHashes.count) tile hashes computed.")

        // 2. Find best match in HashStore.
        guard let match = HashStore.shared.bestMatch(for: candidateHashes) else {
            return noMatchReport()
        }

        let cmp = match.comparison
        print("[Decoder+Hash] Match: \(cmp.matchedCount)/\(cmp.totalCount) tiles "
            + "(\(cmp.damagedPercent)% damaged).")

        // 3. Resolve Signature from SignatureManager.
        let signature = resolveSignature(id: match.record.signatureId)

        // 4. Choose status.
        //    • 100 % match  → .authentic  (pixel-perfect, no tampering)
        //    • ≥ 35 % match → .tampered   (signature present but image was altered)
        //    (< 35 % is ruled out by bestMatch returning nil)
        let status: VerificationStatus = cmp.isPristine ? .authentic : .tampered

        var report = makeHashReport(status: status,
                                    uuid: match.record.signatureId,
                                    signature: signature,
                                    comparison: cmp)
        return report
    }

    // MARK: Helpers

    private func resolveSignature(id: String) -> Signature? {
        SignatureManager.shared.loadSignatures()
            .first { $0.id.lowercased() == id.lowercased() }
    }

    private func noMatchReport() -> VerificationReport {
        var r = VerificationReport(
            id:                   UUID().uuidString,
            scanDate:             Date(),
            status:               .noWatermarkFound,
            extractedSignatureId: nil,
            matchedSignature:     nil,
            confidenceScore:      0
        )
        r.verificationMethod = .none
        return r
    }

    private func makeHashReport(status: VerificationStatus,
                                 uuid: String,
                                 signature: Signature?,
                                 comparison: ImageHasher.ComparisonResult) -> VerificationReport {
        // Confidence = match fraction (0 – 1).
        var r = VerificationReport(
            id:                   UUID().uuidString,
            scanDate:             Date(),
            status:               status,
            extractedSignatureId: uuid,
            matchedSignature:     signature,
            confidenceScore:      comparison.matchFraction
        )
        r.verificationMethod = .hash
        r.hashComparison     = comparison
        return r
    }
}
