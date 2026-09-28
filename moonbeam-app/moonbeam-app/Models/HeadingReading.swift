//
//  HeadingReading.swift
//  moonbeam-app
//

import Foundation

/// One compass reading: which way the top of the phone points, and how far
/// to trust it (COMPASS.md §1 Accuracy).
///
/// True north only (COMPASS.md §3): there's deliberately no magnetic heading
/// here, so nothing downstream can fall back to one.
///
/// `nonisolated`: an inert value, not main-actor state. `Sendable` because it
/// crosses from CoreLocation's delegate callback into an `AsyncStream`.
nonisolated struct HeadingReading: Equatable, Sendable {

    // MARK: - Constants

    /// Accuracy worse than this puts the compass in its low-accuracy state.
    /// Locking to ±5° means little beyond it. A starting value, to tune on
    /// device (COMPASS.md §1).
    static let lowAccuracyThresholdDegrees = 15.0

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

    // MARK: - Derived

    /// True when the compass can't be trusted enough to lock: no true
    /// heading, unknown accuracy, or accuracy worse than the threshold.
    var isLowAccuracy: Bool {
        guard trueHeading != nil, let accuracy else { return true }
        return accuracy > Self.lowAccuracyThresholdDegrees
    }
}
