//
//  OnboardingManager.swift
//  Axiomora
//

import Foundation

/// Tracks whether the user still needs to complete the first-launch onboarding flow.
/// State is persisted in UserDefaults so it survives app kills.
final class OnboardingManager {

    static let shared = OnboardingManager()
    private init() {}

    private let key = "isOnboardingActive"

    /// `true` from the moment a new user registers until they create their first signature.
    var isOnboardingActive: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    /// Call right after a successful registration to kick off the flow.
    func beginOnboarding() {
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Call after the user creates their first signature to unlock the full app.
    func completeOnboarding() {
        UserDefaults.standard.set(false, forKey: key)
    }
}
