//
//  UpNow.swift
//  moonbeam-app
//

import Foundation

/// The moon card's Up now line (COMPASS-1.1.md §3, §9.2), as display values:
/// where the moon is now, or when it rises next.
///
/// Built by `CompassViewModel` from the same moon position as the dial's
/// live Moon target, so the card's bearing and the lock pill never disagree.
///
/// `nonisolated`: an inert value.
nonisolated struct UpNow: Equatable {

    /// The pass the moon is on. Spoken only since 5.4.6 dropped the progress
    /// bar; `progress` is kept for now (unused on screen).
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

    /// Between the title and the bearing on the pill.
    static let separator = " · "

    /// The card's one line (COMPASS-1.1.md §9.2): "Up now · 266° W" on the
    /// pill, or "Rises 11:10 PM" while down. `nil` when the moon is down with
    /// no rise in reach, since there's then nothing to show ("Below the
    /// horizon" is no longer shown).
    var line: String? {
        switch state {
        case let .up(bearing, _): title + Self.separator + bearing
        case let .down(nextRise): nextRise
        }
    }
}
