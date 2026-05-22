//
//  SignatureManager+API.swift
//  Axiomora
//
//  Extension that uploads a newly created Signature to the VPS immediately
//  after it is saved locally.  Drop this file into the project — no changes
//  to SignatureManager.swift required.
//
//  CALL SITE
//  ─────────
//  In NewSignatureTableViewController (or wherever you call
//  SignatureManager.shared.saveSignatures), add one line after the save:
//
//      SignatureManager.shared.saveSignatures(updatedSignatures)
//      Task { await SignatureManager.shared.syncNewSignature(signature) }  // ← add this
//
//  That's the only change needed in your existing view controllers.

import Foundation

extension SignatureManager {

    /// Upload or update `signature` on the VPS.
    ///
    /// Strategy:
    ///   1. POST /signatures  — register new. Returns 201 on success.
    ///   2. If 409 (UUID already on server) — PATCH /signatures/{uuid} to overwrite
    ///      all fields. This fixes corrupt rows (e.g. display_name='bbd') caused by
    ///      previous partial writes, and also handles legitimate profile edits.
    ///
    /// PATCH is used instead of PUT because PUT was blocked by the server's old CORS
    /// config. PATCH is additive-safe and works even on partial rows.
    ///
    /// Errors are logged but never thrown — a network failure never blocks the user.
    func syncNewSignature(_ signature: Signature) async {
        do {
            try await AxiomoraAPIClient.shared.registerSignature(signature)
            print("[SignatureManager] ✓ Registered signature \(signature.id) on server.")
        } catch APIError.httpError(let code, _) where code == 409 {
            // UUID already exists — patch all fields to fix any corrupt data.
            do {
                try await AxiomoraAPIClient.shared.patchSignature(signature)
                print("[SignatureManager] ✓ Patched signature \(signature.id) on server.")
            } catch {
                print("[SignatureManager] ⚠️ Patch failed: \(error.localizedDescription)")
            }
        } catch {
            print("[SignatureManager] ⚠️ Registration failed: \(error.localizedDescription)")
        }
    }

    /// Call once at app startup to ensure every local signature is correctly
    /// registered on the server — fixes silent failures from previous sessions.
    func syncAllSignaturesOnStartup() {
        let all = loadSignatures()
        guard !all.isEmpty else { return }
        for signature in all {
            Task { await syncNewSignature(signature) }
        }
        print("[SignatureManager] Startup sync: queued \(all.count) signature(s).")
    }
}
