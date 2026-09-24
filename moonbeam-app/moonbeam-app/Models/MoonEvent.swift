//
//  MoonEvent.swift
//  moonbeam-app
//

import Foundation

/// A moonrise or moonset: when it happens and which way to look.
///
/// `nonisolated`: an inert value, not main-actor state.
nonisolated struct MoonEvent: Equatable {
    let date: Date

    /// Degrees clockwise from true north (not magnetic).
    let azimuth: Double
}
