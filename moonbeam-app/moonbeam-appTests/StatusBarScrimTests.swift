//
//  StatusBarScrimTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// The status bar scrim's opacity ramp (STEP-5.15 §4): clear at the top of
/// the scroll, full after the ramp distance, with no pop in between.
@Suite("Status bar scrim", .timeLimit(.minutes(1)))
struct StatusBarScrimTests {

    private static let tolerance = 1e-9

    @Test("Clear at rest and when overscrolled")
    func clearAtRest() {
        #expect(StatusBarScrim.opacity(forOffset: 0) == 0)
        #expect(StatusBarScrim.opacity(forOffset: -30) == 0)
    }

    @Test("Ramps linearly over the ramp distance")
    func ramps() {
        let half = StatusBarScrim.rampDistance / 2
        #expect(abs(StatusBarScrim.opacity(forOffset: half) - 0.5) < Self.tolerance)
    }

    @Test("Full from the ramp distance on")
    func fullAfterRamp() {
        #expect(StatusBarScrim.opacity(forOffset: StatusBarScrim.rampDistance) == 1)
        #expect(StatusBarScrim.opacity(forOffset: StatusBarScrim.rampDistance * 10) == 1)
    }

    @Test("Spec values: 24 pt extra height, 40 pt ramp")
    func specValues() {
        #expect(StatusBarScrim.extraHeight == 24)
        #expect(StatusBarScrim.rampDistance == 40)
    }

    @Test("Finger-sized steps track; jumps past the ramp cross-fade")
    func jumps() {
        #expect(!StatusBarScrim.isJump(from: 0, to: 5))
        #expect(!StatusBarScrim.isJump(from: 0, to: StatusBarScrim.rampDistance))
        #expect(StatusBarScrim.isJump(from: 0, to: StatusBarScrim.rampDistance + 1))
        #expect(StatusBarScrim.isJump(from: 600, to: 0))
    }
}
