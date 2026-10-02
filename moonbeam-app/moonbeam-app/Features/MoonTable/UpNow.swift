//
//  UpNow.swift
//  moonbeam-app
//

import Foundation

/// The moon card's Up now row (COMPASS-1.1.md §3), as display values: where
/// the moon is now, or when it rises next.
///
/// Built by `CompassViewModel` from the same moon position as the dial's
/// live Moon target, so the card's bearing and the lock pill never disagree.
///
/// `nonisolated`: an inert value.
nonisolated struct UpNow: Equatable {

    /// The pass the moon is on, for the progress bar.
    struct Pass: Equatable {
        /// How far from the last rise to the next set, `0...1`.
        let progress: Double
        /// "10:06 PM", the last rise (often the evening before).
        let riseTime: String
        /// "1:28 PM", the next set.
        let setTime: String
    }

    enum State: Equatable {
        /// "266° W", and the pass, when it was found.
        case up(bearing: String, pass: Pass?)
        /// "Rises in 34 min", or `nil` when no rise was found in reach.
        case down(nextRise: String?)
    }

    let state: State

    /// "Up now" or "Below the horizon".
    let title: String

    /// "Moon up now, west, 266 degrees. Rose 10:06 PM, sets 1:28 PM."
    let accessibilityLabel: String

    var isUp: Bool {
        if case .up = state { return true }
        return false
    }
}
