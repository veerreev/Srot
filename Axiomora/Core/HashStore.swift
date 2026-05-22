//
//  HashStore.swift
//  Axiomora
//
//  Persists a mapping from imageId → TileRecord (signatureId + tile hashes)
//  to a single JSON file in the app's Documents directory.
//
//  DESIGN
//  ──────
//  Each photo captured in the app gets a unique imageId (the Image.id from
//  your data model).  At signing time the full array of tile hashes for that
//  image is stored under that imageId.  At verification time we:
//    1. Extract the candidate image's tile hashes.
//    2. Compare against every TileRecord whose signatureId matches any known
//       local signature (or all records if we're doing a blind scan).
//    3. Return the best-matching record together with the ComparisonResult.
//
//  THREAD SAFETY
//  ─────────────
//  All reads and mutations run through a concurrent DispatchQueue with
//  barrier writes, so the store is safe to call from any thread.
//
//  USAGE
//  ─────
//  Embed side (after WatermarkEmbedder.embedAndRegister):
//
//      if let hashes = ImageHasher.tileHashes(watermarkedImage) {
//          HashStore.shared.register(imageId: image.id,
//                                   signatureId: signature.id,
//                                   tileHashes: hashes)
//      }
//
//  Verify side (called by WatermarkDecoder+Hash):
//
//      let result = HashStore.shared.bestMatch(for: candidateHashes)
//      // result?.comparison.signatureDetected  → signature found
//      // result?.comparison.isPristine         → no tampering
//      // result?.comparison.damagedPercent     → % of tiles that differ

import Foundation

// ---------------------------------------------------------------------------
// MARK: - TileRecord
// ---------------------------------------------------------------------------

/// Everything stored for one registered image.
struct TileRecord: Codable {
    /// The Image.id from your data model.
    let imageId: String
    /// The Signature.id embedded in this image.
    let signatureId: String
    /// Ordered tile hashes, produced by ImageHasher.tileHashes(_:).
    let tileHashes: [String]
    /// When the image was signed (for display / debugging).
    let registeredAt: Date
}

// ---------------------------------------------------------------------------
// MARK: - HashStore
// ---------------------------------------------------------------------------

final class HashStore {

    // MARK: Singleton

    static let shared = HashStore()
    private init() { load() }

    // MARK: Private state

    /// imageId → TileRecord
    private var records: [String: TileRecord] = [:]
    private let queue = DispatchQueue(label: "com.axiomora.HashStore",
                                      attributes: .concurrent)

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tile_hash_store.json")
    }

    // MARK: - Public API

    // ── Registration ──────────────────────────────────────────────────────────

    /// Store the tile hashes for a newly signed image.
    ///
    /// - Parameters:
    ///   - imageId:     Unique ID of the image (Image.id from your data model).
    ///   - signatureId: ID of the Signature embedded in the image.
    ///   - tileHashes:  Output of `ImageHasher.tileHashes(_:)`.
    func register(imageId: String, signatureId: String, tileHashes: [String]) {
        let record = TileRecord(imageId: imageId,
                                signatureId: signatureId,
                                tileHashes: tileHashes,
                                registeredAt: Date())

        // SYNC barrier: caller blocks until the in-memory dict is updated.
        // This guarantees that any subsequent bestMatch() call on any thread
        // sees the new record immediately — even before the disk write completes.
        queue.sync(flags: .barrier) {
            self.records[imageId] = record
        }

        // Disk write is fire-and-forget on a low-priority background queue.
        // It does NOT go through the concurrent queue (no reader contention)
        // because it encodes a snapshot taken after the barrier above finished.
        let snapshot = queue.sync { records }   // safe read after barrier
        DispatchQueue.global(qos: .utility).async {
            self.persistSnapshot(snapshot)
        }

        print("[HashStore] ✓ Registered \(tileHashes.count) tiles for image \(imageId) → sig \(signatureId)")
    }

    // ── Deletion ──────────────────────────────────────────────────────────────

    /// Remove the tile record for a specific image (call when image is deleted).
    func remove(imageId: String) {
        queue.sync(flags: .barrier) {
            self.records.removeValue(forKey: imageId)
        }
        let snapshot = queue.sync { records }
        DispatchQueue.global(qos: .utility).async { self.persistSnapshot(snapshot) }
    }

    /// Remove all tile records associated with a given signature
    /// (call when the user deletes a signature profile).
    func removeAll(forSignatureId signatureId: String) {
        queue.sync(flags: .barrier) {
            self.records = self.records.filter { $0.value.signatureId != signatureId }
        }
        let snapshot = queue.sync { records }
        DispatchQueue.global(qos: .utility).async { self.persistSnapshot(snapshot) }
    }

    // ── Lookup ────────────────────────────────────────────────────────────────

    /// The result of a best-match search.
    struct MatchResult {
        /// The stored record that scored highest.
        let record: TileRecord
        /// Tile-level comparison statistics.
        let comparison: ImageHasher.ComparisonResult
    }

    /// Find the stored TileRecord that best matches `candidateHashes`.
    ///
    /// Iterates all stored records, computes per-tile overlap, and returns
    /// the one with the highest match fraction — provided that fraction is
    /// at least 35 % (the minimum threshold for signature detection).
    ///
    /// Returns `nil` when no record reaches the 35 % threshold.
    func bestMatch(for candidateHashes: [String]) -> MatchResult? {
        // Read the full dictionary on the queue for thread safety.
        let snapshot = queue.sync { records }

        var best: MatchResult?

        for (_, record) in snapshot {
            let cmp = ImageHasher.compare(candidateHashes: candidateHashes,
                                          storedHashes: record.tileHashes)
            guard cmp.signatureDetected else { continue }
            if best == nil || cmp.matchFraction > best!.comparison.matchFraction {
                best = MatchResult(record: record, comparison: cmp)
            }
        }

        if let b = best {
            print("[HashStore] Best match → sig \(b.record.signatureId), "
                + "\(b.comparison.matchedCount)/\(b.comparison.totalCount) tiles "
                + "(\(b.comparison.damagedPercent)% damaged)")
        } else {
            print("[HashStore] No match above 35% threshold.")
        }

        return best
    }

    /// Directly look up the tile record for a known imageId.
    func record(for imageId: String) -> TileRecord? {
        queue.sync { records[imageId] }
    }

    /// Total number of registered images.
    var count: Int { queue.sync { records.count } }

    // MARK: - Persistence

    /// Write `snapshot` to disk.  Always called off the concurrent queue
    /// to avoid blocking readers.
    private func persistSnapshot(_ snapshot: [String: TileRecord]) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[HashStore] ⚠️ Save failed: \(error)")
        }
    }

    private func load() {
        guard let data    = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: TileRecord].self, from: data)
        else {
            print("[HashStore] No store found — starting fresh.")
            return
        }
        records = decoded
        print("[HashStore] Loaded \(records.count) image records.")
    }
}
