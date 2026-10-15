//
//  PressHoldTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The 100 ms minimum hold on the shared pressed look (STEP-5.13 §4): a quick
/// tap still shows it for at least 100 ms; a long press shows it until release.
@Suite("Press hold", .timeLimit(.minutes(1)))
@MainActor
struct PressHoldTests {

    @Test("The minimum is at least 100 ms")
    func minimumIsAtLeast100ms() {
        #expect(PressHold.minimum >= .milliseconds(100))
    }

    @Test("At rest: no pressed look")
    func atRest() {
        #expect(PressHold().showsPressedLook == false)
    }

    @Test("Quick tap: the look stays on after release until the minimum passes")
    func quickTapHoldsUntilMinimum() {
        var hold = PressHold()
        let cycle = hold.fingerDown()
        #expect(hold.showsPressedLook)

        hold.fingerUp()
        #expect(hold.showsPressedLook, "released before 100 ms: still pressed")

        hold.minimumPassed(cycle: cycle)
        #expect(hold.showsPressedLook == false)
    }

    @Test("Long press: the look stays on past the minimum until release")
    func longPressHoldsUntilRelease() {
        var hold = PressHold()
        let cycle = hold.fingerDown()

        hold.minimumPassed(cycle: cycle)
        #expect(hold.showsPressedLook, "finger still down")

        hold.fingerUp()
        #expect(hold.showsPressedLook == false)
    }

    @Test("A timer from an earlier tap doesn't cut short the next one")
    func staleTimerIgnored() {
        var hold = PressHold()
        let first = hold.fingerDown()
        hold.fingerUp()
        let second = hold.fingerDown()
        hold.fingerUp()

        hold.minimumPassed(cycle: first)
        #expect(hold.showsPressedLook, "the second tap's 100 ms hasn't passed")

        hold.minimumPassed(cycle: second)
        #expect(hold.showsPressedLook == false)
    }

    @Test("Real time: a 1 ms tap shows the look for at least 100 ms")
    func quickTapRealTime() async throws {
        // Drives the hold the way PressFeedback does: a timer of `minimum`
        // from finger down, with the finger lifting almost at once.
        let clock = ContinuousClock()
        var hold = PressHold()
        let start = clock.now
        let cycle = hold.fingerDown()

        try await Task.sleep(for: .milliseconds(1))
        hold.fingerUp()
        #expect(hold.showsPressedLook)

        try await Task.sleep(for: PressHold.minimum)
        hold.minimumPassed(cycle: cycle)
        #expect(hold.showsPressedLook == false)
        #expect(start.duration(to: clock.now) >= .milliseconds(100))
    }
}
