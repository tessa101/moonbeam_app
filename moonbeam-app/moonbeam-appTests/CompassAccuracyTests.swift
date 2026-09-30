//
//  CompassAccuracyTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The low-accuracy rule with hysteresis (COMPASS.md §1 Accuracy): enter
/// above 25°, leave below 20°, keep the current state in between.
@Suite("Compass accuracy")
nonisolated struct CompassAccuracyTests {

    // MARK: - Fixtures

    private static func reading(accuracy: Double?) -> HeadingReading {
        HeadingReading(trueHeading: 72, accuracy: accuracy)
    }

    // MARK: - Constants

    @Test("Enter above 25°, leave below 20°")
    func thresholds() {
        #expect(CompassAccuracy.enterLowAboveDegrees == 25)
        #expect(CompassAccuracy.exitLowBelowDegrees == 20)
    }

    // MARK: - Entering

    @Test("From good: stays good up to 25°, inclusive", arguments: [3.0, 19.99, 20.0, 22.0, 25.0])
    func goodStaysGood(accuracy: Double) {
        #expect(!CompassAccuracy.isLow(after: Self.reading(accuracy: accuracy), wasLow: false))
    }

    @Test("From good: just above 25° enters low", arguments: [25.01, 27.3, 90.0])
    func goodEntersLow(accuracy: Double) {
        #expect(CompassAccuracy.isLow(after: Self.reading(accuracy: accuracy), wasLow: false))
    }

    // MARK: - Leaving

    @Test("From low: stays low down to 20°, inclusive", arguments: [30.0, 25.0, 22.0, 20.0])
    func lowStaysLow(accuracy: Double) {
        #expect(CompassAccuracy.isLow(after: Self.reading(accuracy: accuracy), wasLow: true))
    }

    @Test("From low: just below 20° leaves", arguments: [19.99, 13.4, 3.0])
    func lowLeaves(accuracy: Double) {
        #expect(!CompassAccuracy.isLow(after: Self.reading(accuracy: accuracy), wasLow: true))
    }

    // MARK: - Nothing to trust

    @Test("No reading, no true heading or unknown accuracy is always low", arguments: [false, true])
    func nothingToTrust(wasLow: Bool) {
        #expect(CompassAccuracy.isLow(after: nil, wasLow: wasLow))
        #expect(CompassAccuracy.isLow(after: .unavailable, wasLow: wasLow))
        #expect(CompassAccuracy.isLow(after: HeadingReading(trueHeading: nil, accuracy: 1), wasLow: wasLow))
        #expect(CompassAccuracy.isLow(after: Self.reading(accuracy: nil), wasLow: wasLow))
    }

    // MARK: - The device test

    /// 2026-09-29 readout: ±11.8° locked, ±27.3° while charging, ±13.4°
    /// locked again. With the old single 15° line anything in 15–25° flipped
    /// it; now 22° in between keeps whichever state it was in.
    @Test("The device test's sequence, plus values in the gap")
    func deviceSequence() {
        var low = true
        var states: [Bool] = []
        for accuracy in [11.8, 22.0, 27.3, 22.0, 13.4] {
            low = CompassAccuracy.isLow(after: Self.reading(accuracy: accuracy), wasLow: low)
            states.append(low)
        }

        #expect(states == [false, false, true, true, false])
    }

    /// The compass starts low (no reading yet), so a first reading in the
    /// gap doesn't count as good.
    @Test("A first reading in the gap stays low; a first good one isn't")
    func firstReading() {
        #expect(CompassAccuracy.isLow(after: Self.reading(accuracy: 22), wasLow: true))
        #expect(!CompassAccuracy.isLow(after: Self.reading(accuracy: 18), wasLow: true))
    }
}
