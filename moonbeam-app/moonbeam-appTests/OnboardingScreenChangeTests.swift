//
//  OnboardingScreenChangeTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// Onboarding load-ins and the handover between screens (STEP-5.14 §2,
/// Build 5.14.1): `ContentLoadIn` by block index, a 0.2 s fade-out, and
/// VoiceOver told once the title has started.
@Suite("Onboarding screen change", .timeLimit(.minutes(1)))
@MainActor
struct OnboardingScreenChangeTests {

    private static let tolerance = 1e-9

    @Test("Indexed blocks use the main screen's stagger, from 0")
    func indexedStagger() {
        #expect(ContentLoadIn.delay(forIndex: 0) == 0)
        #expect(abs(ContentLoadIn.delay(forIndex: 1) - 0.15) < Self.tolerance)
        #expect(abs(ContentLoadIn.delay(forIndex: 5) - 0.75) < Self.tolerance)
        // The main screen's blocks are indices 0-2 of the same rule.
        for block in ContentLoadIn.Block.allCases {
            #expect(ContentLoadIn.delay(for: block) == ContentLoadIn.delay(forIndex: block.rawValue))
        }
    }

    @Test("The upsell's six blocks are all in by 1.05 s")
    func upsellTotal() {
        let lastIndex = 5
        let last = ContentLoadIn.delay(forIndex: lastIndex) + ContentLoadIn.duration
        #expect(abs(last - 1.05) < Self.tolerance)
    }

    @Test("The outgoing page fades out in the skeleton-exit 0.2 s")
    func exit() {
        #expect(OnboardingScreenChange.exitDuration == 0.2)
        #expect(OnboardingScreenChange.exitDuration == ContentLoadIn.skeletonExitDuration)
    }

    @Test("5.14.1 covers the landing and upsell; That's okay for now swaps as before")
    func scope() {
        #expect(OnboardingScreenChange.loadsIn(.landing))
        #expect(OnboardingScreenChange.loadsIn(.locationUpsell))
        #expect(!OnboardingScreenChange.loadsIn(.locationDeclined))
    }

    @Test("VoiceOver: ScreenChanged once the title has started; at once for That's okay for now")
    func announce() {
        #expect(abs(OnboardingScreenChange.announceDelay(for: .locationUpsell) - 0.15) < Self.tolerance)
        #expect(abs(OnboardingScreenChange.announceDelay(for: .landing) - 0.15) < Self.tolerance)
        #expect(OnboardingScreenChange.announceDelay(for: .locationDeclined) == 0)
        // Announced after the stagger starts, and before the title has finished.
        #expect(OnboardingScreenChange.announceDelay(for: .locationUpsell) > 0)
        #expect(
            OnboardingScreenChange.announceDelay(for: .locationUpsell)
                < ContentLoadIn.delay(forIndex: OnboardingScreenChange.announcedBlockIndex) + ContentLoadIn.duration
        )
    }
}
