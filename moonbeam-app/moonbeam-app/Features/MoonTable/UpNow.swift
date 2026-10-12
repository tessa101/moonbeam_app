//
//  UpNow.swift
//  moonbeam-app
//

import Foundation

/// The moon card's Up now (COMPASS-1.1.md §3, §9.14), as display values:
/// where the moon is now, when it rises later today, or when it returns after
/// midnight. Today always shows one of these states in the middle column.
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
        let riseTime: TimeText
        /// "1:28 PM", the next set.
        let setTime: TimeText
        let riseContext: String?
        let riseDirection: String
        let setDirection: String
        let riseAccessibilityLabel: String
        let setAccessibilityLabel: String
    }

    enum State: Equatable {
        /// "266° W", and the pass, when it was found.
        case up(bearing: String, pass: Pass?)
        /// "in 34 min" before today's rise.
        case notUpYet(countdown: String)
        case setForToday(nextRise: String?)
    }

    let state: State

    /// "Up now", "Not up yet", or "Set for today".
    let title: String

    /// "Moon up now, west, 266 degrees. Rose 10:06 PM, sets 1:28 PM."
    let accessibilityLabel: String

    var isUp: Bool {
        if case .up = state { return true }
        return false
    }

    var detail: String? {
        switch state {
        case let .up(bearing, _): bearing
        case let .notUpYet(countdown): countdown
        case let .setForToday(nextRise): nextRise
        }
    }

    /// Between the title and the bearing on the pill.
    static let separator = " · "

    /// The accessibility fallback pill's title and detail.
    var pillText: String {
        guard let detail else { return title }
        return title + Self.separator + detail
    }
}
