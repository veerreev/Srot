//
//  Untitled.swift
//  Axiomora
//
//  Created by Veer on 22/04/26.
//

import UIKit

// MARK: - Aspect Ratio

extension WatermarkEmbedder {

    /// The three aspect ratios Axiomora recognises, detected with ±5 % tolerance.
    enum ImageAspectRatio: CustomStringConvertible {
        case square        // 1 : 1
        case fourThree     // 4 : 3
        case sixteenNine   // 16 : 9
        case other(Double) // anything else — still processed normally

        var description: String {
            switch self {
            case .square:          return "1:1"
            case .fourThree:       return "4:3"
            case .sixteenNine:     return "16:9"
            case .other(let r):    return String(format: "%.2f:1", r)
            }
        }
    }
}

// MARK: - Main Entry Point

extension WatermarkEmbedder {

    /// Embeds a watermark into `image` by trying each string in `candidates` (exactly 10)
    /// until `decode()` confirms a successful round-trip.
    ///
    /// Flow per candidate:
    ///   1. Split the pixel-accurate image into N non-overlapping 256 × 256 tiles.
    ///   2. Call `embedInTile(_:string:)` once for every tile  → N calls total.
    ///   3. Stitch the modified tiles back into a full image.
    ///   4. Call `decode(_:)` once and compare with the candidate string.
    ///   5. Match → return `"Encoding successful"`.  No match → try next candidate.
    ///
    /// - Parameters:
    ///   - image:      Source image.  Must be at least 256 × 256 pixels.
    ///   - candidates: Exactly 10 strings to try in order.
    /// - Returns: `"Encoding successful"` or a human-readable failure message.
    func embedWithFallback(image: UIImage, candidates: [String]) -> String {
        precondition(candidates.count == 10,
                     "embedWithFallback requires exactly 10 candidates, got \(candidates.count).")

        let T = WatermarkEmbedder.tileSize   // 256

        // ── Normalise to pixel buffer ────────────────────────────────────────────
        // Drawing through UIGraphicsImageRenderer bakes in orientation and works for
        // both cgImage-backed and ciImage-backed UIImages.
        guard let normalised = normalisedCGImage(from: image) else {
            return "Encoding failed: could not normalise source image."
        }

        let W = normalised.width
        let H = normalised.height

        guard W >= T, H >= T else {
            return "Encoding failed: image \(W)×\(H) px is smaller than one tile (\(T)×\(T) px)."
        }

        // ── Tile grid dimensions ─────────────────────────────────────────────────
        let numCols = W / T   // integer division → floor → no overlap
        let numRows = H / T
        let N       = numCols * numRows

        let aspectRatio = detectAspectRatio(width: W, height: H)
        print("[WatermarkEmbedder] Source: \(W)×\(H) px | Ratio: \(aspectRatio) | "
            + "Grid: \(numCols) col × \(numRows) row = \(N) tile(s)")

        // ── Candidate loop ───────────────────────────────────────────────────────
        for (index, candidate) in candidates.enumerated() {
            print("[WatermarkEmbedder] Candidate \(index + 1)/\(candidates.count): \"\(candidate)\"")

            // Step 1 & 2 — extract each tile, embed the candidate string into it.
            var tileGrid: [[UIImage]] = []
            var extractionFailed = false

            for row in 0..<numRows {
                var rowTiles: [UIImage] = []

                for col in 0..<numCols {
                    // Crop at pixel coordinates from the normalised CGImage.
                    guard let tile = extractTile(from: normalised, col: col, row: row, T: T,
                                                 scale: image.scale) else {
                        print("[WatermarkEmbedder] ✗ Tile (\(col),\(row)) extraction failed — skipping candidate.")
                        extractionFailed = true
                        break
                    }

                    // embedInTile() call #(row * numCols + col + 1) of N
                    let embeddedTile = embedInTile(tile, string: candidate)
                    rowTiles.append(embeddedTile)
                }

                if extractionFailed { break }
                tileGrid.append(rowTiles)
            }

            guard !extractionFailed else { continue }

            // Step 3 — stitch the N modified tiles back into a single image.
            guard let watermarked = stitchTiles(tileGrid,
                                                pixelWidth:  W,
                                                pixelHeight: H,
                                                scale: image.scale) else {
                print("[WatermarkEmbedder] ✗ Stitch failed for candidate \(index + 1) — skipping.")
                continue
            }

            // Step 4 — single decode call per candidate.
            let decoded = decode(watermarked)

            // Step 5 — verify.
            if decoded == candidate {
                print("[WatermarkEmbedder] ✓ Candidate \(index + 1) verified — encoding confirmed.")
                return "Encoding successful"
            } else {
                print("[WatermarkEmbedder] ✗ Mismatch on candidate \(index + 1): "
                    + "expected \"\(candidate)\", decode returned \"\(decoded ?? "nil")\".")
            }
        }

        return "Encoding failed: none of the \(candidates.count) candidates survived the decode check."
    }
}

// MARK: - Stubs (replace with real ML implementations)

extension WatermarkEmbedder {

    /// Embeds `string` into a single 256 × 256 tile and returns the modified tile.
    /// - TODO: Replace with the real ML-based per-tile embedding model.
    func embedInTile(_ tile: UIImage, string: String) -> UIImage {
        return tile
    }

    /// Attempts to decode the watermark string from `image`.
    /// Returns the decoded string, or `nil` if decoding fails.
    /// - TODO: Replace with the real ML-based decoder.
    func decode(_ image: UIImage) -> String? {
        return nil
    }
}

// MARK: - Private Helpers

private extension WatermarkEmbedder {

    // MARK: Aspect Ratio Detection

    /// Classifies width:height into one of the three supported ratios (±5 % tolerance).
    func detectAspectRatio(width: Int, height: Int) -> ImageAspectRatio {
        let ratio    = Double(width) / Double(height)
        let epsilon  = 0.05
        switch ratio {
        case let r where abs(r - 1.0)         < epsilon: return .square
        case let r where abs(r - 4.0 / 3.0)  < epsilon: return .fourThree
        case let r where abs(r - 16.0 / 9.0) < epsilon: return .sixteenNine
        default:                                          return .other(ratio)
        }
    }

    // MARK: Image Normalisation

    /// Returns a CGImage whose pixels exactly match what UIKit would render —
    /// orientation is baked in, and CIImage-backed UIImages are handled correctly.
    func normalisedCGImage(from image: UIImage) -> CGImage? {
        let W = Int(image.size.width  * image.scale)
        let H = Int(image.size.height * image.scale)

        // Render at 1× into a pixel-exact context so CGImage coordinates == pixel coordinates.
        let format        = UIGraphicsImageRendererFormat()
        format.scale      = 1
        format.opaque     = true
        let renderer      = UIGraphicsImageRenderer(size: CGSize(width: W, height: H),
                                                    format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: W, height: H))
        }.cgImage
    }

    // MARK: Tile Extraction

    /// Crops a T × T tile from `cg` at grid position (col, row).
    /// All coordinates are in pixel space (scale = 1).
    func extractTile(from cg: CGImage, col: Int, row: Int, T: Int, scale: CGFloat) -> UIImage? {
        let cropRect = CGRect(x: col * T, y: row * T, width: T, height: T)
        guard let croppedCG = cg.cropping(to: cropRect) else { return nil }
        // Restore the original display scale so downstream code sees the right point size.
        return UIImage(cgImage: croppedCG, scale: scale, orientation: .up)
    }

    // MARK: Tile Stitching

    /// Composites the 2-D grid of modified tiles back into a full-resolution image.
    ///
    /// - Parameters:
    ///   - tiles:       Row-major grid — `tiles[row][col]`.
    ///   - pixelWidth:  Full image width in pixels.
    ///   - pixelHeight: Full image height in pixels.
    ///   - scale:       Display scale to attach to the returned UIImage.
    func stitchTiles(_ tiles: [[UIImage]],
                     pixelWidth:  Int,
                     pixelHeight: Int,
                     scale: CGFloat) -> UIImage? {
        let T = WatermarkEmbedder.tileSize

        // Render at scale=1 so tile positions map 1:1 to pixels.
        let format        = UIGraphicsImageRendererFormat()
        format.scale      = 1
        format.opaque     = true
        let pointSize     = CGSize(width: pixelWidth, height: pixelHeight)
        let renderer      = UIGraphicsImageRenderer(size: pointSize, format: format)

        let stitched = renderer.image { _ in
            for (rowIdx, row) in tiles.enumerated() {
                for (colIdx, tile) in row.enumerated() {
                    let origin = CGPoint(x: colIdx * T, y: rowIdx * T)
                    tile.draw(at: origin)
                }
            }
        }

        // Re-attach the original display scale so callers get the right UIImage.size.
        guard let cg = stitched.cgImage else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}
