//
//  WatermarkEmbedder+Hash.swift
//  Axiomora
//
//  Extends WatermarkEmbedder with `embedAndRegister(_:imageId:signature:)`,
//  which combines neural watermarking with tile-hash registration in one call.
//
//  WHAT IT DOES
//  ────────────
//  1. Calls the existing `embed(_:signature:)` → gets the watermarked UIImage.
//  2. Computes per-tile SHA-256 hashes of the watermarked image via ImageHasher.
//  3. Stores the tile hashes in HashStore, keyed by imageId and signatureId.
//
//  CALL SITE
//  ─────────
//  Replace every:
//      let watermarked = try WatermarkEmbedder.shared.embed(image, signature: sig)
//
//  With:
//      let result = try WatermarkEmbedder.shared
//                       .embedAndRegister(image, imageId: image.id, signature: sig)
//      let watermarked = result.watermarkedImage
//
//  Run this on a background queue — CoreML inference + hashing can take
//  100–400 ms depending on image resolution.

import UIKit

extension WatermarkEmbedder {

    // MARK: - Result

    /// Returned by `embedAndRegister`.
    struct EmbedResult {
        /// The watermarked image, ready to save or display.
        let watermarkedImage: UIImage
        /// The tile hashes registered in HashStore, in row-major order.
        /// `nil` only if the image was smaller than one 32×32 tile (extremely unlikely).
        let tileHashes: [String]?
    }

    // MARK: - Combined embed + register

    /// Embed a watermark and register all tile hashes for tamper detection.
    ///
    /// - Parameters:
    ///   - image:     The original, un-watermarked UIImage.
    ///   - imageId:   Stable unique identifier for this image (`Image.id`).
    ///   - signature: The Signature whose UUID will be embedded.
    /// - Returns:     An `EmbedResult` with the watermarked image and tile hashes.
    /// - Throws:      `WatermarkError` if CoreML inference fails.
    @discardableResult
    func embedAndRegister(_ image: UIImage,
                          imageId: String,
                          signature: Signature) throws -> EmbedResult {

        // ── 1. Neural watermark ───────────────────────────────────────────────
        let watermarked = try embed(image, signature: signature)
        print("[Embedder+Hash] ✓ Neural watermark embedded.")

        // ── 2. Tile hashing ───────────────────────────────────────────────────
        guard let hashes = ImageHasher.tileHashes(watermarked) else {
            print("[Embedder+Hash] ⚠️ Image too small to tile-hash — skipping HashStore.")
            return EmbedResult(watermarkedImage: watermarked, tileHashes: nil)
        }
        print("[Embedder+Hash] Hashed \(hashes.count) tiles.")

        // ── 3. Register ───────────────────────────────────────────────────────
        HashStore.shared.register(imageId: imageId,
                                  signatureId: signature.id,
                                  tileHashes: hashes)

        return EmbedResult(watermarkedImage: watermarked, tileHashes: hashes)
    }
}
