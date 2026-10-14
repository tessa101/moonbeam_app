//
//  UpNowFormatter.swift
//  moonbeam-app
//

import Foundation

/// Turns the moon's live state into the Up now row's text (COMPASS-1.1.md
/// §3): the bearing and the pass's ends while it's up, when it rises next
/// while it's down, and the spoken forms of both.
///
/// Times are in the **place's** zone, like the rest of the card, and come
/// from `MoonTableFormatter` so the bar's rise time reads exactly like the
/// Moonrise column's would.
///
/// `nonisolated` because it's a pure mapping over its inputs.
nonisolated struct UpNowFormatter {

    // MARK: - Copy

    static let upTitle = "Up now"
    static let notUpYetTitle = "Not up yet"
    static let setForTodayTitle = "Set for today"
    static let risingNowText = "Rising now"

    // MARK: - Constants

    private static let secondsPerMinute: TimeInterval = 60

    // MARK: - Configuration

    private let times: MoonTableFormatter
    private let compass = CompassFormatter()

    /// - Parameter locale: injectable so tests can pin `en_US`.
    init(locale: Locale = .autoupdatingCurrent) {
        times = MoonTableFormatter(locale: locale)
    }

    // MARK: - Moon up

    /// "266° W · 23° up", and the bar from the pass's rise to its set.
    ///
    /// - Parameters:
    ///   - azimuth: the moon's direction now, the dial's Moon target.
    ///   - altitude: the moon centre's geometric altitude; display stays at
    ///     least 1° while the rise/set rule says it is up.
    ///   - pass: the pass it's on; `nil` draws no bar.
    func up(azimuth: Double, altitude: Double, pass: MoonPass?, at now: Date, in timeZone: TimeZone) -> UpNow {
        let shownAltitude = max(1, Int(altitude.rounded()))
        let barPass = pass.map { pass in
            UpNow.Pass(
                progress: Self.progress(of: now, from: pass.rise.date, to: pass.set.date),
                riseTime: times.timeText(pass.rise.date, in: timeZone),
                setTime: times.timeText(pass.set.date, in: timeZone),
                riseContext: Self.isPreviousDay(pass.rise.date, relativeTo: now, in: timeZone) ? "last night" : nil,
                riseDirection: compass.bearing(for: pass.rise.azimuth),
                setDirection: compass.bearing(for: pass.set.azimuth),
                riseAccessibilityLabel: Self.riseAccessibilityLabel(pass.rise.date, relativeTo: now, times: times, in: timeZone),
                setAccessibilityLabel: "Moonset, \(times.time(pass.set.date, in: timeZone))."
            )
        }
        return UpNow(
            state: .up(
                bearing: compass.bearing(for: azimuth),
                altitude: "\(shownAltitude)° up",
                pass: barPass
            ),
            title: Self.upTitle,
            accessibilityLabel: "Moon up now, \(compass.spokenName(for: azimuth)), \(compass.spokenDegrees(for: azimuth)), \(shownAltitude) degrees above the horizon."
        )
    }

    // MARK: - Moon down

    /// A minute-updated countdown before today's rise, or the confirmed
    /// late-tonight return wording after today's set.
    ///
    /// - Parameter nextRise: the next moonrise after `now`; `nil` leaves the
    ///   right side empty.
    func down(nextRise: Date?, at now: Date, in timeZone: TimeZone) -> UpNow {
        guard let nextRise else {
            return UpNow(
                state: .setForToday(nextRise: nil),
                title: Self.setForTodayTitle,
                accessibilityLabel: "Moon set for today."
            )
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(nextRise, inSameDayAs: now) {
            let countdown = Self.countdown(until: nextRise, from: now)
            return UpNow(
                state: .notUpYet(countdown: countdown.shown),
                title: Self.notUpYetTitle,
                accessibilityLabel: "Moon not up yet, \(countdown.spoken)."
            )
        }
        let time = times.time(nextRise, in: timeZone)
        let shown = "Back late tonight, \(time)"
        return UpNow(
            state: .setForToday(nextRise: shown),
            title: Self.setForTodayTitle,
            accessibilityLabel: "Moon set for today. Back late tonight at \(time)."
        )
    }

    // MARK: - Helpers

    /// Whole minutes to `date`, rounded up, so a countdown never says
    /// "0 min" while the moon is still down; `nil` under a minute away
    /// ("rising now"). The card's countdown and the location-off guide row
    /// (`LocationOffGuide`) both count this way, so they never disagree.
    static func countdownMinutes(until date: Date, from now: Date) -> Int? {
        let interval = max(0, date.timeIntervalSince(now))
        guard interval >= secondsPerMinute else { return nil }
        return Int((interval / secondsPerMinute).rounded(.up))
    }

    private static func countdown(until date: Date, from now: Date) -> (shown: String, spoken: String) {
        guard let minutes = countdownMinutes(until: date, from: now) else { return (risingNowText, "rising now") }
        guard minutes >= 60 else { return ("in \(minutes) min", "rising in \(minutes) minutes") }
        let hours = minutes / 60
        let remainder = minutes % 60
        let hourWord = hours == 1 ? "hour" : "hours"
        let minuteWord = remainder == 1 ? "minute" : "minutes"
        return ("in \(hours)h \(remainder)m", "rising in \(hours) \(hourWord) and \(remainder) \(minuteWord)")
    }

    private static func isPreviousDay(_ date: Date, relativeTo now: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        return calendar.isDate(date, inSameDayAs: yesterday)
    }

    private static func riseAccessibilityLabel(
        _ date: Date,
        relativeTo now: Date,
        times: MoonTableFormatter,
        in timeZone: TimeZone
    ) -> String {
        let context = isPreviousDay(date, relativeTo: now, in: timeZone) ? "last night, " : ""
        return "Moonrise, \(context)\(times.time(date, in: timeZone))."
    }

    /// Where `now` sits from `start` to `end`, clamped to `0...1`.
    private static func progress(of now: Date, from start: Date, to end: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(now.timeIntervalSince(start) / duration, 0), 1)
    }
}
