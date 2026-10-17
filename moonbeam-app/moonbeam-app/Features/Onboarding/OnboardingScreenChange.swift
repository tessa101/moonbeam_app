//
//  OnboardingScreenChange.swift
//  moonbeam-app
//

import SwiftUI

/// How one onboarding screen hands over to the next (STEP-5.14 §2): the
/// outgoing page fades out in 0.2 s, then the incoming page loads in with
/// `ContentLoadIn`'s stagger. No slide or push.
///
/// All three app-owned onboarding pages use the same handover. The system
/// permission prompt and sheets keep their native presentation motion.
enum OnboardingScreenChange {

    /// The skeleton-exit value, so every fade-out in the app matches.
    static let exitDuration = ContentLoadIn.skeletonExitDuration
    static let exitAnimation = ContentLoadIn.skeletonExitAnimation

    /// The block whose start VoiceOver waits for: the title, second on both
    /// screens. By then the stagger has started and the title is showing,
    /// so `ScreenChanged` lands on it rather than on a page still at 0.
    static let announcedBlockIndex = 1

    /// Whether a change to `step` fades the old page out and loads the new
    /// one in, or swaps at once as before.
    static func loadsIn(_ step: OnboardingViewModel.Step) -> Bool {
        switch step {
        case .landing, .locationUpsell, .locationDeclined: true
        }
    }

    /// How long after the new page is in place VoiceOver is told the screen
    /// changed.
    static func announceDelay(for step: OnboardingViewModel.Step) -> TimeInterval {
        loadsIn(step) ? ContentLoadIn.delay(forIndex: announcedBlockIndex) : 0
    }
}
