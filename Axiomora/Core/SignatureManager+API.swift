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
    /// • First attempt: POST /signatures  (register new)
    /// • If 409 (already exists): PUT /signatures/{uuid}  (update existing profile)
    ///
    /// Errors are logged but never thrown — a network failure never blocks the user.
    func syncNewSignature(_ signature: Signature) async {
        do {
            try await AxiomoraAPIClient.shared.registerSignature(signature)
            print("[SignatureManager] ✓ Registered signature \(signature.id) on server.")
        } catch APIError.httpError(let code, _) where code == 409 {
            // Already registered — update the profile in case the user edited it.
            do {
                try await AxiomoraAPIClient.shared.updateSignature(signature)
                print("[SignatureManager] ✓ Updated signature \(signature.id) on server.")
            } catch {
                print("[SignatureManager] ⚠️ Update failed: \(error.localizedDescription)")
            }
        } catch {
            print("[SignatureManager] ⚠️ Registration failed: \(error.localizedDescription)")
        }
    }
}
