//
//  InMemoryOnboardingStore.swift
//  moonbeam-app
//

import Foundation

/// `OnboardingStore` that forgets everything on deinit, for tests and
/// previews.
final class InMemoryOnboardingStore: OnboardingStore {

    var isOnboardingCompleted: Bool

    init(isOnboardingCompleted: Bool = false) {
        self.isOnboardingCompleted = isOnboardingCompleted
    }
}
