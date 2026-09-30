//
//  HeadingReading.swift
//  moonbeam-app
//

import Foundation

/// One compass reading: which way the top of the phone points, and how far
/// to trust it (COMPASS.md §1 Accuracy).
///
/// Just the values. Whether that counts as low accuracy depends on the
/// previous state too (hysteresis), so the rule lives in `CompassAccuracy`.
///
/// True north only (COMPASS.md §3): there's deliberately no magnetic heading
/// here, so nothing downstream can fall back to one.
///
/// `nonisolated`: an inert value, not main-actor state. `Sendable` because it
/// crosses from CoreLocation's delegate callback into an `AsyncStream`.
nonisolated struct HeadingReading: Equatable, Sendable {

    // MARK: - Constants

    /// No usable heading: no compass hardware, or CoreLocation reported an
    /// error.
    static let unavailable = HeadingReading(trueHeading: nil, accuracy: nil)

    // MARK: - Values

    /// Degrees clockwise from true north, `0..<360`. `nil` when true heading
    /// is unavailable, which happens whenever location updates aren't
    /// running.
    let trueHeading: Double?

    /// Maximum error of `trueHeading`, in degrees. `nil` when unknown.
    let accuracy: Double?

    // MARK: - Init

    init(trueHeading: Double?, accuracy: Double?) {
        self.trueHeading = trueHeading?.wrappedIntoDegreeCircle
        self.accuracy = accuracy
    }

    /// From CoreLocation's raw `CLHeading` values, where a negative number
    /// means "invalid" rather than a direction or an error size.
    init(rawTrueHeading: Double, rawAccuracy: Double) {
        self.init(
            trueHeading: rawTrueHeading < 0 ? nil : rawTrueHeading,
            accuracy: rawAccuracy < 0 ? nil : rawAccuracy
        )
    }
}
