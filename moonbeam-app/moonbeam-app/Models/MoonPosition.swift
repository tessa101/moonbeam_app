//
//  MoonPosition.swift
//  moonbeam-app
//

import Foundation

/// Where the moon is in the sky at one moment, seen from one place.
///
/// Feeds the compass's live "Moon" target (COMPASS.md §4). `isUp` uses the
/// same definition as the moon table's rise and set, so the two never
/// disagree (COMPASS.md §3).
///
/// `nonisolated`: an inert value, not main-actor state.
nonisolated struct MoonPosition: Equatable {
    /// Degrees clockwise from true north (not magnetic).
    let azimuth: Double

    /// True when the moon is above the horizon, using the same definition as rise/set.
    let isUp: Bool
}
