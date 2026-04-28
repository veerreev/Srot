//
//  WatermarkDecoder+Hash.swift
//  Axiomora
//
//  Two-stage verification pipeline:
//
//  STAGE 1 — Neural (WatermarkDecoder.decode)
//  ────────────────────────────────────────────
//  CoreML decoder → BCH correction → UUID → fetch Signature.
//
//  STAGE 2 — pHash fallback (this file)
//  ──────────────────────────────────────
//  Only reached when Stage 1 returns .noWatermarkFound.

import UIKit

// ---------------------------------------------------------------------------
// MARK: - VerificationMethod tag
// ---------------------------------------------------------------------------

enum VerificationMethod: String, Codable {
    case neural = "Neural Watermark"
    case hash   = "Hash Fingerprint"
    case none   = "None"
}

// ---------------------------------------------------------------------------
// MARK: - WatermarkDecoder extension
// ---------------------------------------------------------------------------

extension WatermarkDecoder {

    // MARK: - Two-stage decode

    /// Run Stage 1 (neural); fall back to Stage 2 (pHash).
    func decodeWithHashFallback(_ image: UIImage) async -> VerificationReport {

        // ── Stage 1: neural ───────────────────────────────────────────────────
        let neuralReport = await decode(image)

        if neuralReport.status != .noWatermarkFound {
            var tagged = neuralReport
            tagged.verificationMethod = .neural
            print("[Decoder+Hash] ✓ Neural path: \(neuralReport.status.rawValue)")
            return tagged
        }

        print("[Decoder+Hash] Neural path found nothing — running pHash fallback…")

        // ── Stage 2: pHash ────────────────────────────────────────────────────
        return await hashFallback(image)
    }

    // MARK: - Hash fallback

    private func hashFallback(_ image: UIImage) async -> VerificationReport {
        // 1. Compute hashes
        guard let candidateHashes = ImageHasher.tileHashes(image) else {
            print("[Decoder+Hash] Image too small to tile-hash.")
            return noMatchReport()
        }
        print("[Decoder+Hash] Candidate: \(candidateHashes.count) tile hashes computed.")

        var targetSignatureId: String
        var cmp: ImageHasher.ComparisonResult

        // 2. Try Local First
        if let localMatch = HashStore.shared.bestMatch(for: candidateHashes) {
            print("[Decoder+Hash] Match found locally!")
            targetSignatureId = localMatch.record.signatureId
            cmp = localMatch.comparison
        } else {
            // 3. If local fails, try the global VPS
            print("[Decoder+Hash] Local match failed. Querying VPS...")
            do {
                let serverMatch = try await AxiomoraAPIClient.shared.verifyImageHashes(candidateHashes: candidateHashes)
                print("[Decoder+Hash] ✓ Match found globally on VPS!")
                targetSignatureId = serverMatch.signatureId
                cmp = serverMatch.comparison.toAppResult()
            } catch {
                print("[Decoder+Hash] Global match failed: \(error.localizedDescription)")
                return noMatchReport()
            }
        }

        // 4. Resolve Signature
        var signature: Signature? = SignatureManager.shared.loadSignatures()
            .first { $0.id.lowercased() == targetSignatureId.lowercased() }

        if signature == nil {
            do {
                signature = try await AxiomoraAPIClient.shared.fetchSignature(uuid: targetSignatureId)
                print("[Decoder+Hash] ✓ Server returned signature for \(targetSignatureId)")
            } catch {
                print("[Decoder+Hash] ⚠️ Signature fetch failed.")
            }
        }

        // 5. Decide status and return
        let status: VerificationStatus = cmp.isPristine ? .authentic : .tampered
        return makeHashReport(status: status, uuid: targetSignatureId, signature: signature, comparison: cmp)
    }

    // MARK: - Helpers

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
