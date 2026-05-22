//
//  VerificationReport+Hash.swift
//  Axiomora
//
//  Attaches hash-system metadata to VerificationReport without modifying the
//  original model file.
//
//  Because Swift does not allow stored properties in struct extensions, these
//  properties are backed by a thread-safe global dictionary keyed on report.id
//  (which is set once at creation and never mutated).
//
//  ── CLEANER ALTERNATIVE ──────────────────────────────────────────────────────
//  If you prefer, open Data/Models/VerificationReport.swift and add directly:
//
//      var verificationMethod: VerificationMethod  = .none
//      var hashComparison: ImageHasher.ComparisonResult? = nil
//
//  Then delete this file entirely.  That is the preferred approach for a
//  production codebase; this extension exists only to avoid touching the
//  original model file.
//  ─────────────────────────────────────────────────────────────────────────────

import Foundation

// ---------------------------------------------------------------------------
// MARK: - Backing stores
// ---------------------------------------------------------------------------

private struct ReportMeta {
    var method:     VerificationMethod            = .none
    var comparison: ImageHasher.ComparisonResult? = nil
}

private var _metaStore: [String: ReportMeta] = [:]
private let _metaLock = NSLock()

// ---------------------------------------------------------------------------
// MARK: - VerificationReport extension
// ---------------------------------------------------------------------------

extension VerificationReport {

    // MARK: verificationMethod

    /// Which pipeline produced this report (.neural / .hash / .none).
    var verificationMethod: VerificationMethod {
        get {
            _metaLock.lock(); defer { _metaLock.unlock() }
            return _metaStore[id]?.method ?? .none
        }
        set {
            _metaLock.lock(); defer { _metaLock.unlock() }
            _metaStore[id, default: ReportMeta()].method = newValue
        }
    }

    // MARK: hashComparison

    /// Tile-level comparison statistics, set only when verificationMethod == .hash.
    var hashComparison: ImageHasher.ComparisonResult? {
        get {
            _metaLock.lock(); defer { _metaLock.unlock() }
            return _metaStore[id]?.comparison
        }
        set {
            _metaLock.lock(); defer { _metaLock.unlock() }
            _metaStore[id, default: ReportMeta()].comparison = newValue
        }
    }

    // MARK: damagedPercent — convenience for the UI

    /// Percentage of the image area that appears to have been altered (0–100).
    /// Returns `nil` when no hash comparison was performed.
    /// Returns 0 when the image is pixel-perfect.
    var damagedPercent: Int? {
        hashComparison?.damagedPercent
    }

    // MARK: Human-readable tamper message

    /// Ready-made string for display in an alert or label.
    /// e.g. "~42% of the image was damaged."
    /// Returns `nil` when the image is authentic and pristine.
    var tamperMessage: String? {
        guard status == .tampered,
              let pct = damagedPercent else { return nil }
        return "~\(pct)% of the image was damaged."
    }
}
