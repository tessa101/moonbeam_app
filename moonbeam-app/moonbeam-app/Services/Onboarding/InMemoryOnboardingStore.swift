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
    var locationPromptDismissed: Bool
    var endedOnNoCity: Bool

    init(
        isOnboardingCompleted: Bool = false,
        hasSeenFirstFindPass: Bool = false,
        locationPromptDismissed: Bool = false,
        endedOnNoCity: Bool = false
    ) {
        self.isOnboardingCompleted = isOnboardingCompleted
        self.hasSeenFirstFindPass = hasSeenFirstFindPass
        self.locationPromptDismissed = locationPromptDismissed
        self.endedOnNoCity = endedOnNoCity
    }
}
