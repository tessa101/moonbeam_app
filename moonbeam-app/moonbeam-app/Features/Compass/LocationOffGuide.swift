//
//  LocationOffGuide.swift
//  moonbeam-app
//

import Foundation

/// The location-off guide row's state after Maybe later (LOCATION-OFF-FLOW.md
/// §3.1, design 1.9 S2 to S6): waiting, a moonrise countdown, rising, or up.
/// Pure rules over "now", whether it's today, the moon's up/down (5.11's
/// rule, the compass's) and two rise times, so the row, the card and the
/// compass agree. The words are `LocationOffGuideFormatter`'s.
///
/// `nonisolated`: an inert value.
nonisolated enum LocationOffGuide: Hashable, Sendable {

    /// S2: moon down with no moonrise within 3 h (or none), after moonset,
    /// and on any date but today.
    case waiting

    /// S3 (60 min or more) and S4 (1 to 59 min): moonrise within 3 h, in
    /// whole minutes rounded up, as the card's countdown counts.
    case moonriseIn(minutes: Int)

    /// S5: from moonrise until 15 min after, including under a minute away.
    case rising

    /// S6: from 15 min after moonrise until moonset.
    case up

    /// The handoff's state names, for styling and tests.
    enum Stage: Equatable, Sendable {
        case s2, s3, s4, s5, s6
    }

    // MARK: - Constants (§3.1)

    /// A moonrise further off than this is S2.
    static let countdownWindowMinutes = 180

    /// From an hour out the countdown is S3, under it S4.
    static let minutesPerHour = 60

    /// S5 lasts this long after the pass's rise.
    static let risingWindow: TimeInterval = 15 * 60

    // MARK: - Rules

    /// - Parameters:
    ///   - now: the clock's time.
    ///   - isToday: the selected day is today in the place's zone.
    ///   - isMoonUp: 5.11's rule (`MoonPosition.isUp`), as the compass uses.
    ///   - passRise: while up, the rise of the pass it's on (the date behind
    ///     `UpNow.Pass.riseTime`), which may be last night.
    ///   - nextRise: while down, the next moonrise after `now`, which may be
    ///     after midnight.
    static func state(
        now: Date,
        isToday: Bool,
        isMoonUp: Bool,
        passRise: Date?,
        nextRise: Date?
    ) -> LocationOffGuide {
        guard isToday else { return .waiting }
        if isMoonUp {
            guard let passRise else { return .up }
            return now < passRise.addingTimeInterval(risingWindow) ? .rising : .up
        }
        guard let nextRise else { return .waiting }
        guard let minutes = UpNowFormatter.countdownMinutes(until: nextRise, from: now) else {
            // Under a minute away, or the moon still reads down just after
            // its rise: rising.
            return .rising
        }
        return minutes <= countdownWindowMinutes ? .moonriseIn(minutes: minutes) : .waiting
    }

    var stage: Stage {
        switch self {
        case .waiting: .s2
        case let .moonriseIn(minutes): minutes >= Self.minutesPerHour ? .s3 : .s4
        case .rising: .s5
        case .up: .s6
        }
    }

    /// S3 to S6 draw the warm, active row; S2 the quiet one.
    var isActive: Bool { self != .waiting }
}
