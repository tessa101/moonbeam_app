//
//  CompassAccuracy.swift
//  moonbeam-app
//

import Foundation

/// When the compass counts as low accuracy (COMPASS.md §1 Accuracy), with
/// hysteresis like the lock's.
///
/// Device test 2026-09-29: iOS's reported heading accuracy wandered between
/// about ±11° and ±27° (worst while charging), so a single 15° line flipped
/// the compass in and out of low accuracy. It now **enters** low accuracy
/// above 25° and **leaves** only below 20°; in between it keeps its state.
///
/// No true heading or unknown accuracy is always low: there's nothing to
/// trust.
///
/// Pure and `nonisolated`, so the rule is testable without the main actor.
nonisolated enum CompassAccuracy {

    // MARK: - Constants

    /// Worse than this enters low accuracy. Exclusive.
    static let enterLowAboveDegrees = 25.0

    /// Better than this leaves it. Exclusive. The 5° gap stops flicker.
    static let exitLowBelowDegrees = 20.0

    // MARK: - Rule

    /// Whether the compass is in low accuracy after `reading`.
    ///
    /// - Parameter wasLow: the state before this reading. The compass starts
    ///   low (no reading yet), so a first reading has to be better than 20°.
    static func isLow(after reading: HeadingReading?, wasLow: Bool) -> Bool {
        guard let reading, reading.trueHeading != nil, let accuracy = reading.accuracy else {
            return true
        }
        if accuracy > enterLowAboveDegrees { return true }
        if accuracy < exitLowBelowDegrees { return false }
        return wasLow
    }
}
