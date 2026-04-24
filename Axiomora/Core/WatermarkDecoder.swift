//
//  WatermarkDecoder.swift
//  Axiomora
//
//  Created by GEU on 24/04/26.
//

//
//  Pipeline:
//    1. Correct UIImage orientation into an up-right sRGB pixel buffer.
//    2. Tile into 256×256 patches (same grid as WatermarkEmbedder).
//    3. Feed each tile to AxiomarkDecoder.mlmodelc → [1, 256] bit probabilities.
//    4. Accumulate (sum) across all tiles, then divide by tile count.
//    5. Threshold averaged probabilities at 0.5 to get hard bits.
//    6. BCH(t=16, m=8) error correction → recover 16-byte UUID.
//    7. Match UUID against local signatures → build VerificationReport.
//
//  Requires: AxiomarkDecoder.mlpackage compiled into the bundle by Xcode.
//  Generate with: python export_coreml.py --ckpt_path ./ckpts/model-0099.ckpt

import UIKit
import CoreML

// MARK: - WatermarkDecoder

final class WatermarkDecoder {

    static let shared = WatermarkDecoder()
    private init() {}

    // ── CoreML I/O names — must match export_coreml.py ───────────────────────
    private enum ModelIO {
        static let image = "image"   // [1, 3, 256, 256] Float32 in [-1, 1]
        static let bits  = "bits"    // [1, 256]          Float32 in [ 0,  1]
    }

    private lazy var model: MLModel = {
        guard let url = Bundle.main.url(forResource: "AxiomoraDecoder",
                                        withExtension: "mlmodelc") else {
            fatalError(
                "[WatermarkDecoder] AxiomarkDecoder.mlmodelc not found.\n"
              + "Run: python export_coreml.py --ckpt_path ./ckpts/model-0099.ckpt\n"
              + "Then drag AxiomarkDecoder.mlpackage into Xcode and add to target."
            )
        }
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .all
        do {
            return try MLModel(contentsOf: url, configuration: cfg)
        } catch {
            fatalError("[WatermarkDecoder] Model load failed: \(error)")
        }
    }()

    private let bchDecoder = BCHDecoder()

    // MARK: - Public API

    /// Decode the watermark embedded in `image` and return a VerificationReport.
    ///
    /// - Parameter image: Any UIImage — HEIC, JPEG, PNG, any resolution.
    /// - Returns: A `VerificationReport` with status, confidence, and matched signature.
    ///
    /// Call from a background queue — this is CPU/GPU intensive.
    func decode(_ image: UIImage) -> VerificationReport {
        guard let cgImage = orientedCGImage(from: image) else {
            return report(status: .noWatermarkFound, uuid: nil, confidence: 0)
        }

        let W = cgImage.width
        let H = cgImage.height
        let T = WatermarkEmbedder.tileSize    // 256

        guard W >= T, H >= T else {
            return report(status: .noWatermarkFound, uuid: nil, confidence: 0)
        }

        let bpr = W * 4
        var px  = [UInt8](repeating: 0, count: H * bpr)
        guard drawIntoRGBA(cgImage: cgImage, buffer: &px, W: W, H: H, bpr: bpr) else {
            return report(status: .noWatermarkFound, uuid: nil, confidence: 0)
        }

        let nCols = W / T
        let nRows = H / T
        let nTiles = nCols * nRows
        var sumProbs = [Float](repeating: 0, count: 256)

        for row in 0..<nRows {
            for col in 0..<nCols {
                let tileProbs = decodeTile(&px, W: W, bpr: bpr,
                                           x0: col * T, y0: row * T, T: T)
                for i in 0..<256 { sumProbs[i] += tileProbs[i] }
            }
        }

        // Average across tiles for SNR improvement (√N gain)
        let n = Float(nTiles)
        let avgProbs = sumProbs.map { $0 / n }

        // Confidence: mean(|p - 0.5| × 2)  ∈ [0, 1]
        let confidence = Double(avgProbs.reduce(0) { $0 + abs($1 - 0.5) } / 128.0)

        // Hard-threshold at 0.5
        let hardBits = avgProbs.map { $0 >= 0.5 ? UInt8(1) : UInt8(0) }

        // BCH decode → UUID string
        let uuidString = bchDecoder.decode(bits: hardBits)

        if let uuid = uuidString {
            let matched = findSignature(for: uuid)
            let status: VerificationStatus = matched != nil ? .authentic : .noWatermarkFound
            var rep = report(status: status, uuid: uuid, confidence: confidence)
            rep.matchedSignature = matched
            return rep
        } else {
            // BCH correction failed — too many bit errors
            return report(status: .noWatermarkFound, uuid: nil, confidence: confidence)
        }
    }

    // MARK: - Per-tile inference

    private func decodeTile(_ px: inout [UInt8], W: Int, bpr: Int,
                             x0: Int, y0: Int, T: Int) -> [Float] {
        let n = T * T
        var r = [Float](repeating: 0, count: n)
        var g = [Float](repeating: 0, count: n)
        var b = [Float](repeating: 0, count: n)

        for ty in 0..<T {
            let row = (y0 + ty) * bpr + x0 * 4
            let dst = ty * T
            for tx in 0..<T {
                let s = row + tx * 4
                r[dst + tx] = Float(px[s])     / 127.5 - 1.0
                g[dst + tx] = Float(px[s + 1]) / 127.5 - 1.0
                b[dst + tx] = Float(px[s + 2]) / 127.5 - 1.0
            }
        }

        guard let arr   = try? makeImageArray(r: r, g: g, b: b, T: T),
              let prov  = try? MLDictionaryFeatureProvider(dictionary: [
                  ModelIO.image: MLFeatureValue(multiArray: arr)
              ]),
              let out   = try? model.prediction(from: prov),
              let multi = out.featureValue(for: ModelIO.bits)?.multiArrayValue
        else {
            return [Float](repeating: 0.5, count: 256)
        }

        var probs = [Float](repeating: 0.5, count: 256)
        multi.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            guard let base = ptr.baseAddress else { return }
            for i in 0..<256 { probs[i] = base[i] }
        }
        return probs
    }

    // MARK: - Signature lookup

    /// Look up the extracted UUID in the local SignatureManager store.
    /// On a production backend, this would be a network request instead.
    private func findSignature(for uuid: String) -> Signature? {
        let all = SignatureManager.shared.loadSignatures()
        return all.first(where: { $0.id.lowercased() == uuid.lowercased() })
    }

    // MARK: - VerificationReport factory

    private func report(status: VerificationStatus,
                        uuid: String?,
                        confidence: Double) -> VerificationReport {
        return VerificationReport(
            id:                   UUID().uuidString,
            scanDate:             Date(),
            status:               status,
            extractedSignatureId: uuid,
            matchedSignature:     nil,
            confidenceScore:      confidence
        )
    }

    // MARK: - CoreML array helpers

    private func makeImageArray(r: [Float], g: [Float], b: [Float],
                                 T: Int) throws -> MLMultiArray {
        let n = T * T
        let a = try MLMultiArray(shape: [1, 3, T, T] as [NSNumber],
                                  dataType: .float32)
        a.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
            guard let base = ptr.baseAddress else { return }
            for i in 0..<n { base[i] = r[i]; base[n+i] = g[i]; base[2*n+i] = b[i] }
        }
        return a
    }

    // MARK: - Pixel buffer helpers

    private func orientedCGImage(from image: UIImage) -> CGImage? {
        if let cg = image.cgImage, image.imageOrientation == .up { return cg }
        let W = Int(image.size.width  * image.scale)
        let H = Int(image.size.height * image.scale)
        guard let cs  = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: W, height: H,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: W, height: H))
        UIGraphicsPopContext()
        return ctx.makeImage()
    }

    private func drawIntoRGBA(cgImage: CGImage, buffer: inout [UInt8],
                               W: Int, H: Int, bpr: Int) -> Bool {
        guard let cs  = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &buffer, width: W, height: H,
                                  bitsPerComponent: 8, bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return false }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: W, height: H))
        return true
    }
}

// MARK: - BCH(t=16, m=8) Decoder
//
// Decodes 256 hard bits into a 16-byte UUID using BCH error correction.
// Implements: syndrome computation, Berlekamp-Massey algorithm, Chien search.
//
// Parameters match bchlib.BCH(t=16, m=8):
//   GF(2^8), primitive polynomial x^8+x^4+x^3+x^2+1 = 0x11D
//   n = 255, k = 127, t = 16 (corrects up to 16 bit errors)
//   ecc_bits = 128, data_bits = 128
//
// Bit layout (matches BCHWatermarkCoder.encode output):
//   bits[0..127]   = UUID bytes, MSB first per byte
//   bits[128..255] = ECC bytes,  MSB first per byte

private struct BCHDecoder {

    // GF(2^8) tables — identical to BCHWatermarkCoder
    private let gfExp: [UInt8]
    private let gfLog: [Int]
    private let t     = 16
    private let n     = 255   // code length

    init() {
        let prim = 0x11D
        var exp  = [UInt8](repeating: 0, count: 512)
        var log  = [Int](repeating: -1, count: 256)
        var x    = 1
        for i in 0..<255 {
            exp[i]       = UInt8(x)
            exp[i + 255] = UInt8(x)
            log[x]       = i
            x <<= 1; if x & 256 != 0 { x ^= prim }
        }
        gfExp = exp; gfLog = log
    }

    // GF multiply
    @inline(__always)
    private func mul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        guard a != 0, b != 0 else { return 0 }
        return gfExp[(gfLog[Int(a)] + gfLog[Int(b)]) % 255]
    }

    // GF power: α^exp
    @inline(__always)
    private func pow(_ exp: Int) -> UInt8 {
        let e = ((exp % 255) + 255) % 255
        return gfExp[e]
    }

    // MARK: Decode

    /// Decode 256 hard bits, correct up to 16 errors, return UUID string or nil.
    func decode(bits: [UInt8]) -> String? {
        guard bits.count == 256 else { return nil }

        // Pack 256 bits into 32 bytes.
        // Bits are MSB-first per byte: bit[i*8+j] → byte[i] bit (7-j).
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            for j in 0..<8 {
                bytes[i] |= bits[i * 8 + j] << (7 - j)
            }
        }

        // Compute syndromes.
        // The received polynomial r(x) = Σ_{i=0}^{255} r_i x^i,
        // where r_i = bits[255 - i] (coefficient convention: bit 0 = x^255).
        // S_k = r(α^k) for k = 1 .. 2t.
        let syndromes = computeSyndromes(bits: bits)

        // If all syndromes are zero, no errors — skip correction.
        let hasErrors = syndromes.contains { $0 != 0 }
        var corrected = bytes

        if hasErrors {
            // Find error locator polynomial σ(x) via Berlekamp-Massey.
            guard let sigma = berlekampMassey(syndromes: syndromes) else {
                return nil  // decoding failed
            }

            // Find error positions via Chien search.
            let errorPositions = chienSearch(sigma: sigma)
            guard !errorPositions.isEmpty else { return nil }

            // Correct: flip the bit at each error position.
            // errorPosition p → bit index = 255 - p → byte/bit in our array.
            for p in errorPositions {
                let bitIndex = 255 - p
                guard bitIndex >= 0, bitIndex < 256 else { continue }
                let byteIdx = bitIndex / 8
                let bitShift = UInt8(7 - bitIndex % 8)
                corrected[byteIdx] ^= (1 << bitShift)
            }
        }

        // Extract UUID from first 16 bytes.
        let uuidBytes = Array(corrected[0..<16])
        return uuidBytesToString(uuidBytes)
    }

    // MARK: - Syndrome computation

    private func computeSyndromes(bits: [UInt8]) -> [UInt8] {
        // S_k = r(α^k) = Σ_{i=0}^{255} r_i * α^(k*(255-i))
        // where r_i = bits[i] ∈ {0,1}, k = 1..2t.
        var S = [UInt8](repeating: 0, count: 2 * t + 1)
        for k in 1...(2 * t) {
            var s: UInt8 = 0
            for i in 0..<256 {
                guard bits[i] != 0 else { continue }
                let expVal = (k * (255 - i)) % 255
                s ^= gfExp[expVal]
            }
            S[k] = s
        }
        return S
    }

    // MARK: - Berlekamp-Massey

    private func berlekampMassey(syndromes S: [UInt8]) -> [UInt8]? {
        var C = [UInt8](repeating: 0, count: 2 * t + 1)   // error locator
        var B = [UInt8](repeating: 0, count: 2 * t + 1)   // previous C
        C[0] = 1; B[0] = 1
        var L = 0, m = 1
        var b: UInt8 = 1

        for n in 1...(2 * t) {
            // Discrepancy d = S[n] + Σ_{i=1}^{L} C[i]*S[n-i]
            var d: UInt8 = S[n]
            for i in 1...L where i < n {
                d ^= mul(C[i], S[n - i])
            }

            if d == 0 {
                m += 1
            } else if 2 * L <= n - 1 {
                let T = C
                // C ← C − (d/b) * x^m * B
                let coeff = mul(d, inverse(b))
                for i in m..<(2 * t + 1) { C[i] ^= mul(coeff, B[i - m]) }
                L = n - L
                B = T
                b = d
                m = 1
            } else {
                let coeff = mul(d, inverse(b))
                for i in m..<(2 * t + 1) { C[i] ^= mul(coeff, B[i - m]) }
                m += 1
            }
        }

        // Degree of σ(x) = L, which must be ≤ t to be correctable.
        guard L <= t else { return nil }
        return Array(C[0...L])
    }

    // GF inverse: α^(-log(a)) = α^(255 - log(a))
    private func inverse(_ a: UInt8) -> UInt8 {
        guard a != 0 else { fatalError("GF inverse of 0") }
        return gfExp[255 - gfLog[Int(a)]]
    }

    // MARK: - Chien search

    private func chienSearch(sigma: [UInt8]) -> [Int] {
        // Evaluate σ at α^(-i) for i = 0..254.
        // If σ(α^(-i)) = 0, position i is an error position.
        var errorPos: [Int] = []
        let degree = sigma.count - 1

        for i in 0..<255 {
            var s: UInt8 = 0
            for j in 0...degree {
                // α^(-i*j) = α^((255-i)*j mod 255)
                let expVal = (((255 - i) * j) % 255)
                s ^= mul(sigma[j], gfExp[expVal])
            }
            if s == 0 { errorPos.append(i) }
        }

        return errorPos
    }

    // MARK: - UUID reconstruction

    private func uuidBytesToString(_ bytes: [UInt8]) -> String? {
        guard bytes.count == 16 else { return nil }
        var t = (UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                 UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                 UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                 UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        t.0=bytes[0];  t.1=bytes[1];  t.2=bytes[2];  t.3=bytes[3]
        t.4=bytes[4];  t.5=bytes[5];  t.6=bytes[6];  t.7=bytes[7]
        t.8=bytes[8];  t.9=bytes[9];  t.10=bytes[10]; t.11=bytes[11]
        t.12=bytes[12]; t.13=bytes[13]; t.14=bytes[14]; t.15=bytes[15]
        return UUID(uuid: t).uuidString
    }
}
