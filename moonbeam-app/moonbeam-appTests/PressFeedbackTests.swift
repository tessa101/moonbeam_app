//
//  PressFeedbackTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The shared pressed-state look (DECISIONS.md 2026-10-01 "Tap animation on
/// buttons"): scale 0.96 and opacity 0.8 while pressed; with Reduce Motion,
/// opacity only.
@Suite("Press feedback")
@MainActor
struct PressFeedbackTests {

    @Test("At rest: full size, full opacity, with or without Reduce Motion", arguments: [false, true])
    func atRest(reduceMotion: Bool) {
        #expect(PressFeedback.scale(isPressed: false, reduceMotion: reduceMotion) == 1)
        #expect(PressFeedback.opacity(isPressed: false) == 1)
    }

    @Test("Pressed: shrinks to 0.96 and dims to 0.8")
    func pressed() {
        #expect(PressFeedback.scale(isPressed: true, reduceMotion: false) == 0.96)
        #expect(PressFeedback.opacity(isPressed: true) == 0.8)
    }

    @Test("Pressed with Reduce Motion: dims, doesn't shrink")
    func pressedReduceMotion() {
        #expect(PressFeedback.scale(isPressed: true, reduceMotion: true) == 1)
        #expect(PressFeedback.opacity(isPressed: true) == 0.8)
    }
}
