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

    /// The location-off prompt's Maybe later was tapped (LOCATION-OFF-FLOW.md
    /// §4): the compass guide row shows instead. Cleared when location is
    /// granted, and by the same DEBUG resets as `hasSeenFirstFindPass`.
    var locationPromptDismissed: Bool { get set }

    /// Onboarding ended on `noCity` (Got it or Search for a city instead) on
    /// a non-forced run, so a relaunch with no saved place and no location
    /// access lands there again rather than on the permission-off screen
    /// (STEP-5.14 §6.4). Cleared once a city is set or location is granted.
    var endedOnNoCity: Bool { get set }
}
