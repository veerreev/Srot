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

        // 1. Compute pHash tiles for the candidate image.
        guard let candidateHashes = ImageHasher.tileHashes(image) else {
            print("[Decoder+Hash] Image too small to tile-hash.")
            return noMatchReport()
        }
        print("[Decoder+Hash] Candidate: \(candidateHashes.count) tile hashes computed.")

        // 2. Find best match in the on-device HashStore.
        guard let match = HashStore.shared.bestMatch(for: candidateHashes) else {
            return noMatchReport()
        }

        let cmp = match.comparison
        print("[Decoder+Hash] Match: \(cmp.matchedCount)/\(cmp.totalCount) tiles "
            + "(\(cmp.damagedPercent)% damaged).")

        // 3. Resolve Signature (Local First, then Server)
        var signature: Signature? = SignatureManager.shared.loadSignatures()
            .first { $0.id.lowercased() == match.record.signatureId.lowercased() }

        if signature != nil {
            print("[Decoder+Hash] ✓ Found signature locally for \(match.record.signatureId)")
        } else {
            do {
                signature = try await AxiomoraAPIClient.shared.fetchSignature(uuid: match.record.signatureId)
                print("[Decoder+Hash] ✓ Server returned signature for \(match.record.signatureId)")
            } catch APIError.notFound {
                print("[Decoder+Hash] signatureId \(match.record.signatureId) not found on server.")
            } catch {
                print("[Decoder+Hash] Server error during hash fallback: \(error.localizedDescription)")
            }
        }

        // 4. Decide status.
        let status: VerificationStatus = cmp.isPristine ? .authentic : .tampered

        var rep = makeHashReport(status: status,
                                  uuid: match.record.signatureId,
                                  signature: signature,
                                  comparison: cmp)
        return rep
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
