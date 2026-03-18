//
//  EmbeddingEngine.swift
//  Axiomora
//
//  Created by Pradumn Kapil on 18/03/26.
//

import UIKit
import CoreML

enum WatermarkError: LocalizedError {
    case modelNotFound
    case pixelBufferFailed
    case inferenceFailed(Error)
    case outputMissing(String)
    case imageTooSmall(width: Int, height: Int)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "mlpackage file not found"
        case .pixelBufferFailed:
            return "Could not create buffer from UIImage object"
        case .inferenceFailed(let e):
            return "CoreML inference failed: \(e.localizedDescription)"
        case .outputMissing(let k):
            return "CoreML output '\(k)' missing"
        case .imageTooSmall(let w, let h):
            return "Image \(w)×\(h) is smaller than one tile (\(WatermarkEmbedder.tileSize)×\(WatermarkEmbedder.tileSize))."
        }
    }
}

private struct BCHWatermarkCoder {
    private let gfExp: [UInt8]  // antilog, length 512
    private let gfLog: [Int]    // log, length 256
    private let gPoly: [UInt8]
    private let eccBits: Int    // 128 for t=16, m=8

    init() {
        let primPoly = 0x11D
        var exp = [UInt8](repeating: 0, count: 512)
        var log = [Int](repeating: -1, count: 256)
        var x = 1
        for i in 0..<255 {
            exp[i]       = UInt8(x)
            exp[i + 255] = UInt8(x)
            log[x]       = i
            x <<= 1
            if x & 256 != 0 { x ^= primPoly }
        }
        gfExp = exp
        gfLog = log

        func mul(_ a: UInt8, _ b: UInt8) -> UInt8 {
            guard a != 0, b != 0 else { return 0 }
            return exp[(log[Int(a)] + log[Int(b)]) % 255]
        }

        var g: [UInt8] = [1]
        var processed = Set<Int>()
        for root in stride(from: 1, through: 31, by: 2) {
            guard !processed.contains(root) else { continue }
            var coset: [Int] = []
            var cur = root
            repeat { coset.append(cur); processed.insert(cur); cur = (cur * 2) % 255 }
            while cur != root

            var mp: [UInt8] = [1]
            for j in coset {
                let a = exp[j]
                var next = [UInt8](repeating: 0, count: mp.count + 1)
                for k in 0..<mp.count {
                    next[k]     ^= mul(mp[k], a)
                    next[k + 1] ^= mp[k]
                }
                mp = next
            }
            var ng = [UInt8](repeating: 0, count: g.count + mp.count - 1)
            for gi in 0..<g.count {
                guard g[gi] != 0 else { continue }
                for mi in 0..<mp.count { ng[gi + mi] ^= mp[mi] }
            }
            g = ng
        }
        gPoly   = g
        eccBits = g.count - 1
    }

    func encode(signature: Signature) -> [Float] {
        guard let uuid = UUID(uuidString: signature.id) else {
            assertionFailure("[BCHWatermarkCoder] '\(signature.id)' is not a valid UUID")
            return [Float](repeating: 0, count: 256)
        }
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: uuid.uuid) { for i in 0..<16 { uuidBytes[i] = $0[i] } }

        let d = eccBits
        var reg = [UInt8](repeating: 0, count: d)
        for byte in uuidBytes {
            for bp in stride(from: 7, through: 0, by: -1) {
                let fb = UInt8((Int(byte) >> bp) & 1) ^ reg[d - 1]
                for i in stride(from: d - 1, through: 1, by: -1) { reg[i] = reg[i-1] ^ (fb & gPoly[i]) }
                reg[0] = fb & gPoly[0]
            }
        }
//        var ecc = [UInt8](repeating: 0, count: eccBits / 8)
        #warning("Changed by Veer")
        let eccByteCount = (eccBits + 7) / 8
        var ecc = [UInt8](repeating: 0, count: eccByteCount)
        
        for i in 0..<eccBits { ecc[i / 8] |= reg[d - 1 - i] << (7 - i % 8) }

        return (uuidBytes + ecc).flatMap { byte in
            (0..<8).map { i in Float((byte >> (7 - i)) & 1) }
        }
    }
}

class WatermarkEmbedder {

    static let shared  = WatermarkEmbedder()
    static let tileSize = 256

    private init() {}

    private let bch = BCHWatermarkCoder()

    private enum ModelIO {
        static let image     = "image"
        static let watermark = "watermark"
        static let encoded   = "encoded"
    }

    private lazy var model: MLModel = {
        guard let url = Bundle.main.url(forResource: "AxiomarkEncoder",
                                        withExtension: "mlpackage") else {
            fatalError("[WatermarkEmbedder] AxiomarkEncoder.mlpackage not found. ")
        }
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .all
        return try! MLModel(contentsOf: url, configuration: cfg)
    }()

    func embed(_ image: UIImage, signature: Signature) throws -> UIImage {
        return try embedBits(bch.encode(signature: signature), into: image)
    }

    private func embedBits(_ bits: [Float], into image: UIImage) throws -> UIImage {
        guard let cg = orientedCGImage(from: image) else { throw WatermarkError.pixelBufferFailed }
        let W = cg.width, H = cg.height, T = Self.tileSize
        guard W >= T, H >= T else { throw WatermarkError.imageTooSmall(width: W, height: H) }

        let bpr = W * 4
        var px  = [UInt8](repeating: 255, count: H * bpr)
        guard draw(cg, into: &px, W: W, H: H, bpr: bpr) else { throw WatermarkError.pixelBufferFailed }

        let wmArray = try makeWatermarkArray(bits)

        for row in 0..<(H / T) {
            for col in 0..<(W / T) {
                try processTile(&px, W: W, bpr: bpr, x0: col*T, y0: row*T, T: T, wm: wmArray)
            }
        }

        guard let result = makeUIImage(px, W: W, H: H, bpr: bpr, scale: image.scale) else {
            throw WatermarkError.pixelBufferFailed
        }
        return result
    }

    private func processTile(_ px: inout [UInt8], W: Int, bpr: Int,
                              x0: Int, y0: Int, T: Int, wm: MLMultiArray) throws {
        let n = T * T
        var r = [Float](repeating: 0, count: n)
        var g = [Float](repeating: 0, count: n)
        var b = [Float](repeating: 0, count: n)
        for ty in 0..<T {
            let row = (y0 + ty) * bpr + x0 * 4
            let dst = ty * T
            for tx in 0..<T {
                let s = row + tx * 4
                r[dst+tx] = Float(px[s])   / 127.5 - 1
                g[dst+tx] = Float(px[s+1]) / 127.5 - 1
                b[dst+tx] = Float(px[s+2]) / 127.5 - 1
            }
        }

        let imgArray = try makeImageArray(r: r, g: g, b: b, T: T)
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            ModelIO.image:     MLFeatureValue(multiArray: imgArray),
            ModelIO.watermark: MLFeatureValue(multiArray: wm),
        ])
        let out: MLFeatureProvider
        do { out = try model.prediction(from: provider) }
        catch { throw WatermarkError.inferenceFailed(error) }

        guard let enc = out.featureValue(for: ModelIO.encoded)?.multiArrayValue else {
            throw WatermarkError.outputMissing(ModelIO.encoded)
        }

        enc.withUnsafeBufferPointer(ofType: Float.self) { ptr in
            guard let base = ptr.baseAddress else { return }
            for ty in 0..<T {
                let row = (y0 + ty) * bpr + x0 * 4
                let src = ty * T
                for tx in 0..<T {
                    let d = row + tx * 4
                    px[d]   = toU8(base[src+tx])
                    px[d+1] = toU8(base[n+src+tx])
                    px[d+2] = toU8(base[2*n+src+tx])
                }
            }
        }
    }

    @inline(__always) private func toU8(_ v: Float) -> UInt8 {
        UInt8(clamping: Int(((v.clamped(to: -1...1) + 1) * 127.5).rounded()))
    }

    private func makeImageArray(r: [Float], g: [Float], b: [Float], T: Int) throws -> MLMultiArray {
        let n = T * T
        let a = try MLMultiArray(shape: [1,3,T,T] as [NSNumber], dataType: .float32)
        a.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
            guard let base = ptr.baseAddress else { return }
            for i in 0..<n { base[i]=r[i]; base[n+i]=g[i]; base[2*n+i]=b[i] }
        }
        return a
    }

    private func makeWatermarkArray(_ bits: [Float]) throws -> MLMultiArray {
        let a = try MLMultiArray(shape: [1,256], dataType: .float32)
        a.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
            guard let base = ptr.baseAddress else { return }
            for i in 0..<256 { base[i] = bits[i] }
        }
        return a
    }

    private func orientedCGImage(from image: UIImage) -> CGImage? {
        let W = Int(image.size.width * image.scale)
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

    private func draw(_ cg: CGImage, into buf: inout [UInt8],
                       W: Int, H: Int, bpr: Int) -> Bool {
        guard let cs  = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &buf, width: W, height: H,
                                  bitsPerComponent: 8, bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
        return true
    }

    private func makeUIImage(_ px: [UInt8], W: Int, H: Int,
                              bpr: Int, scale: CGFloat) -> UIImage? {
        guard let cs  = CGColorSpace(name: CGColorSpace.sRGB),
              let dp  = CGDataProvider(data: Data(px) as CFData),
              let cg  = CGImage(width: W, height: H, bitsPerComponent: 8,
                                bitsPerPixel: 32, bytesPerRow: bpr, space: cs,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                provider: dp, decode: nil,
                                shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}

private extension Float {
    func clamped(to r: ClosedRange<Float>) -> Float { min(r.upperBound, max(r.lowerBound, self)) }
}
