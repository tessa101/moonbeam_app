//
//  InMemoryOnboardingStore.swift
//  moonbeam-app
//

import Foundation

/// `OnboardingStore` that forgets everything on deinit, for tests and
/// previews.
final class InMemoryOnboardingStore: OnboardingStore {

    var isOnboardingCompleted: Bool
    var hasSeenFirstFindPass: Bool

    init(isOnboardingCompleted: Bool = false, hasSeenFirstFindPass: Bool = false) {
        self.isOnboardingCompleted = isOnboardingCompleted
        self.hasSeenFirstFindPass = hasSeenFirstFindPass
    }
}
