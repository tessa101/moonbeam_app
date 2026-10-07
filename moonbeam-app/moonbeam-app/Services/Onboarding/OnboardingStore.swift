//
//  OnboardingStore.swift
//  moonbeam-app
//

import Foundation

/// Remembers that onboarding has run (DESIGN-1.1.md §5), so leaving it any
/// way, including "Search for a city instead" and then cancelling the sheet,
/// means a relaunch doesn't show it again.
///
/// A store of its own rather than part of `PlaceStore`: it isn't about
/// places, and `PlaceStore`'s keys are shared with search and recents.
protocol OnboardingStore: AnyObject {
    var isOnboardingCompleted: Bool { get set }

    /// The first "Aha" ride after install has run, with its extra lap
    /// (LOADER.md §11.2.2). First-run state like onboarding, so it lives
    /// here, and the DEBUG reset and Show onboarding clear it too.
    var hasSeenFirstFindPass: Bool { get set }
}
