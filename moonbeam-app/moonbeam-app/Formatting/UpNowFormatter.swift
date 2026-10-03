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
    static let downTitle = "Below the horizon"

    // MARK: - Constants

    /// Under this many minutes away, the next rise is a countdown ("Rises
    /// in 34 min"); from here on it's a time.
    static let countdownLimitMinutes = 60

    private static let secondsPerMinute: TimeInterval = 60
    private static let daysToTomorrow = 1

    // MARK: - Configuration

    let locale: Locale

    private let times: MoonTableFormatter
    private let compass = CompassFormatter()

    /// - Parameter locale: injectable so tests can pin `en_US`.
    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
        times = MoonTableFormatter(locale: locale)
    }

    // MARK: - Moon up

    /// "266° W", and the bar from the pass's rise to its set.
    ///
    /// - Parameters:
    ///   - azimuth: the moon's direction now, the dial's Moon target.
    ///   - pass: the pass it's on; `nil` draws no bar.
    func up(azimuth: Double, pass: MoonPass?, at now: Date, in timeZone: TimeZone) -> UpNow {
        let barPass = pass.map { pass in
            UpNow.Pass(
                progress: Self.progress(of: now, from: pass.rise.date, to: pass.set.date),
                riseTime: times.time(pass.rise.date, in: timeZone),
                setTime: times.time(pass.set.date, in: timeZone)
            )
        }
        var label = "Moon up now, \(compass.spokenName(for: azimuth)), \(compass.spokenDegrees(for: azimuth))."
        if let barPass {
            label += " Rose \(barPass.riseTime), sets \(barPass.setTime)."
        }
        return UpNow(
            state: .up(bearing: compass.bearing(for: azimuth), pass: barPass),
            title: Self.upTitle,
            accessibilityLabel: label
        )
    }

    // MARK: - Moon down

    /// "Rises in 34 min", "Rises 10:06 PM", "Rises tomorrow 9:12 AM", or
    /// further out (a day with no moonrise in between) "Rises Sat 12:05 AM".
    ///
    /// - Parameter nextRise: the next moonrise after `now`; `nil` leaves the
    ///   right side empty.
    func down(nextRise: Date?, at now: Date, in timeZone: TimeZone) -> UpNow {
        guard let nextRise else {
            return UpNow(
                state: .down(nextRise: nil),
                title: Self.downTitle,
                accessibilityLabel: "Moon below the horizon."
            )
        }
        let (shown, spoken) = riseText(nextRise, at: now, in: timeZone)
        return UpNow(
            state: .down(nextRise: shown),
            title: Self.downTitle,
            accessibilityLabel: "Moon below the horizon, \(spoken)."
        )
    }

    /// The shown and spoken forms of the next rise.
    private func riseText(_ rise: Date, at now: Date, in timeZone: TimeZone) -> (shown: String, spoken: String) {
        let minutes = Self.minutesUntil(rise, from: now)
        if minutes < Self.countdownLimitMinutes {
            let unit = minutes == 1 ? "minute" : "minutes"
            return ("Rises in \(minutes) min", "rises in \(minutes) \(unit)")
        }

        let time = times.time(rise, in: timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(rise, inSameDayAs: now) {
            // COMPASS-1.1.md §9.2: no "at" on screen; VoiceOver keeps it.
            return ("Rises \(time)", "rises at \(time)")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: Self.daysToTomorrow, to: now),
           calendar.isDate(rise, inSameDayAs: tomorrow) {
            return ("Rises tomorrow \(time)", "rises tomorrow at \(time)")
        }
        let weekday = Date.FormatStyle(locale: locale, timeZone: timeZone)
        let short = rise.formatted(weekday.weekday(.abbreviated))
        let long = rise.formatted(weekday.weekday(.wide))
        return ("Rises \(short) \(time)", "rises \(long) at \(time)")
    }

    // MARK: - Helpers

    /// Whole minutes to go, rounded up and never below 1, so the countdown
    /// never says "0 min" while the moon is still down.
    private static func minutesUntil(_ date: Date, from now: Date) -> Int {
        let minutes = (date.timeIntervalSince(now) / secondsPerMinute).rounded(.up)
        return max(1, Int(minutes))
    }

    /// Where `now` sits from `start` to `end`, clamped to `0...1`.
    private static func progress(of now: Date, from start: Date, to end: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(now.timeIntervalSince(start) / duration, 0), 1)
    }
}
