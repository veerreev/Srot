//
//  ImageHasher.swift
//  Axiomora
//
//  Replaced SHA-256 with Perceptual Hashing (pHash) using a 2D DCT.
//
//  ALGORITHM
//  ─────────
//  1. Normalise: strip EXIF orientation, render to a canonical sRGB RGBA
//     pixel buffer at the image's native pixel resolution.
//  2. Divide into non-overlapping 32×32 tiles.
//  3. Convert each tile to grayscale (Luma).
//  4. Compute the 2D Discrete Cosine Transform (DCT) to extract structural frequencies.
//  5. Take the top-left 8x8 low-frequency coefficients (ignoring the DC component).
//  6. Generate a 64-bit integer hash: bit is 1 if coefficient > median, else 0.
//  7. Compare hashes using Hamming Distance.
//
//  TAMPER DETECTION MODEL
//  ──────────────────────
//  Because pHash focuses on structural frequencies rather than exact byte values,
//  it naturally ignores high-frequency noise introduced by:
//    - JPEG / HEIC compression
//    - Gaussian Blur
//    - Minor colour grading / shifts
//
//  Hashes are compared across the entire set. If a tile moved slightly due to cropping,
//  the O(N*M) lookup will still find its original counterpart.

import UIKit

struct ImageHasher {

    /// Side length of each tile in pixels.
    static let tileSize: Int = 256
    
    /// Maximum bit difference (out of 64) to consider two tiles identical.
    /// 12 bits allows for moderate JPEG compression and blur.
    static let maxHammingDistance = 12

    // -------------------------------------------------------------------------
    // MARK: - Primary API
    // -------------------------------------------------------------------------

    /// Compute one 64-bit pHash (represented as a 16-char hex string) per tile.
    static func tileHashes(_ image: UIImage) -> [String]? {
        guard let pixels = renderToRGBA(image) else { return nil }
        let T    = tileSize
        let cols = pixels.width  / T
        let rows = pixels.height / T
        guard cols > 0, rows > 0 else { return nil }

        var hashes = [String]()
        hashes.reserveCapacity(rows * cols)

        for row in 0..<rows {
            for col in 0..<cols {
                let hexString = hashTile(pixels: pixels.bytes,
                                         stride: pixels.bytesPerRow,
                                         x0: col * T, y0: row * T, T: T)
                hashes.append(hexString)
            }
        }
        return hashes
    }

    // -------------------------------------------------------------------------
    // MARK: - Comparison
    // -------------------------------------------------------------------------

    struct ComparisonResult {
        let matchedCount: Int
        let exactMatchedCount: Int
        let totalCount: Int
        
        var matchFraction: Double {
            totalCount == 0 ? 0 : Double(matchedCount) / Double(totalCount)
        }
        var damagedPercent: Int {
            Int(((1.0 - matchFraction) * 100).rounded())
        }
        var signatureDetected: Bool { matchFraction >= 0.35 }
        var isPristine: Bool { exactMatchedCount == totalCount && totalCount > 0 }
    }

    /// Compare candidate hashes against stored hashes using Hamming Distance.
    static func compare(candidateHashes: [String],
                        storedHashes: [String]) -> ComparisonResult {
        
        let candidateInts = candidateHashes.compactMap { UInt64($0, radix: 16) }
        let storedInts = storedHashes.compactMap { UInt64($0, radix: 16) }

        var matchedCount = 0
        var exactMatchedCount = 0

        for stored in storedInts {
            var bestDist = 65 // Max distance for 64-bit is 64
            
            for cand in candidateInts {
                // XOR the bits, then count how many 1s are left (the difference)
                let dist = (stored ^ cand).nonzeroBitCount
                if dist < bestDist {
                    bestDist = dist
                }
            }
            
            if bestDist <= maxHammingDistance {
                matchedCount += 1
            }
            if bestDist == 0 {
                exactMatchedCount += 1
            }
        }

        return ComparisonResult(matchedCount: matchedCount,
                                exactMatchedCount: exactMatchedCount,
                                totalCount: storedInts.count)
    }

    // -------------------------------------------------------------------------
    // MARK: - Perceptual Hashing Math (DCT)
    // -------------------------------------------------------------------------

    /// Precomputed Cosine tables for lightning-fast DCT execution on the CPU.
    private static let dctCosines: [[Double]] = {
        var table = [[Double]](repeating: [Double](repeating: 0, count: 32), count: 8)
        let N = 32.0
        let pi = Double.pi
        for u in 0..<8 {
            for x in 0..<32 {
                table[u][x] = cos((Double(2 * x + 1) * Double(u) * pi) / (2.0 * N))
            }
        }
        return table
    }()

    private static func pHashTile(luma: [Double]) -> UInt64 {
        var dct = [Double](repeating: 0, count: 64)

        // Compute top-left 8x8 DCT coefficients of the 32x32 block
        for u in 0..<8 {
            for v in 0..<8 {
                var sum = 0.0
                for x in 0..<32 {
                    let cosX = dctCosines[u][x]
                    for y in 0..<32 {
                        let val = luma[y * 32 + x]
                        let cosY = dctCosines[v][y]
                        sum += val * cosX * cosY
                    }
                }
                dct[v * 8 + u] = sum
            }
        }

        // 1. Exclude the DC component (u=0, v=0) from median calculation
        var validCoeffs = Array(dct[1...63])

        // 2. Calculate the median of the remaining 63 frequencies
        validCoeffs.sort()
        let median = validCoeffs[31] // Middle value

        // 3. Construct the 64-bit fingerprint
        var hash: UInt64 = 0
        for i in 0..<64 {
            if dct[i] > median {
                hash |= (UInt64(1) << i)
            }
        }
        return hash
    }

    private static func hashTile(pixels: UnsafePointer<UInt8>,
                                  stride: Int,
                                  x0: Int, y0: Int, T: Int) -> String {
        // Convert the 32x32 RGB block to Grayscale (Luma)
        var luma = [Double](repeating: 0, count: T * T)
        var idx = 0
        
        for ty in 0..<T {
            let rowStart = (y0 + ty) * stride + x0 * 4
            for tx in 0..<T {
                let src = rowStart + tx * 4
                let r = Double(pixels[src])
                let g = Double(pixels[src + 1])
                let b = Double(pixels[src + 2])
                
                // Standard luminosity weighting
                luma[idx] = 0.299 * r + 0.587 * g + 0.114 * b
                idx += 1
            }
        }

        let hashValue = pHashTile(luma: luma)
        // Pad to exactly 16 hexadecimal characters (64 bits)
        return String(format: "%016llx", hashValue)
    }

    // -------------------------------------------------------------------------
    // MARK: - Pixel buffer
    // -------------------------------------------------------------------------

    private struct PixelBuffer {
        let bytes: UnsafePointer<UInt8>
        let width: Int
        let height: Int
        let bytesPerRow: Int
        private let storage: Data   // keeps the allocation alive

        init?(bytes: Data, width: Int, height: Int, bytesPerRow: Int) {
            self.storage     = bytes
            self.width       = width
            self.height      = height
            self.bytesPerRow = bytesPerRow
            self.bytes       = bytes.withUnsafeBytes {
                $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
            }
        }
    }

    private static func renderToRGBA(_ image: UIImage) -> PixelBuffer? {
        let W = Int(image.size.width  * image.scale)
        let H = Int(image.size.height * image.scale)
        guard W > 0, H > 0 else { return nil }
        let bpr = W * 4
        var storage = Data(count: H * bpr)

        let ok = storage.withUnsafeMutableBytes { raw -> Bool in
            guard let ptr = raw.baseAddress,
                  let cs  = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: ptr,
                                      width: W, height: H,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bpr,
                                      space: cs,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return false }
            UIGraphicsPushContext(ctx)
            image.draw(in: CGRect(x: 0, y: 0, width: W, height: H))
            UIGraphicsPopContext()
            return true
        }

        guard ok else { return nil }
        return PixelBuffer(bytes: storage, width: W, height: H, bytesPerRow: bpr)
    }
}
