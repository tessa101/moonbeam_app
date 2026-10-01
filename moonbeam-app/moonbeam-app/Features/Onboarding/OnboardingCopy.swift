//
//  OnboardingCopy.swift
//  moonbeam-app
//

import Foundation

/// Onboarding's words, from the design (`Moon Signal Madlib 1.0.dc.html`
/// §3d), as-is. Placeholder: the final copy comes from the designer later
/// (DECISIONS.md 2026-10-01 "5.7 onboarding"), so it all lives here, in one
/// place to swap.
nonisolated enum OnboardingCopy {

    // MARK: - Landing

    static let tagline = "When and where to find the moon, and which way to look."
    static let getStarted = "Get started"

    // MARK: - Location upsell

    static let upsellTitle = "Find the moon from where you are"
    static let upsellBody = "\(AppInfo.name) uses your location to show when and where the moon rises and sets, and to point the compass toward it."
    static let preciseNote = "Keep Precise Location on so the compass can find the moon."
    static let useMyLocation = "Use my location"
    static let searchInstead = "Search for a city instead"

    // MARK: - After Don't Allow

    static let declinedTitle = "That’s okay"
    static let declinedBody = "You can still look up locations, but to use the advanced features, like the compass, you'd need to enable location"
    static let gotIt = "Got it"
    static let enableLocation = "Enable location"
}
