//
//  MoonTableFormatter.swift
//  moonbeam-app
//

import Foundation

/// Turns a `MoonDay`'s values into the moon card's text (DESIGN-1.1.md §3.2):
/// the phase name, "75% lit at midnight", times in the place's zone, the zone
/// abbreviation beside them, and the spoken rise/set labels.
///
/// Times are always written in the **place's** zone (PRODUCT FR1), never the
/// device's. The zone abbreviation is the system's for the user's locale,
/// which for some locales is "GMT+10" rather than "AEST" (§3.2: show what
/// the formatter gives).
///
/// `nonisolated` because it's a pure mapping over its inputs.
nonisolated struct MoonTableFormatter {

    // MARK: - Types

    /// Which event a label is for.
    enum Event {
        case rise
        case set
    }

    // MARK: - Constants

    private static let secondsPerMinute: TimeInterval = 60

    private static let phaseNames: [MoonPhase: String] = [
        .new: "New Moon",
        .waxingCrescent: "Waxing Crescent",
        .firstQuarter: "First Quarter",
        .waxingGibbous: "Waxing Gibbous",
        .full: "Full Moon",
        .waningGibbous: "Waning Gibbous",
        .lastQuarter: "Last Quarter",
        .waningCrescent: "Waning Crescent"
    ]

    // MARK: - Configuration

    let locale: Locale

    private let compass = CompassFormatter()

    /// - Parameter locale: injectable so tests can pin `en_US`.
    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    // MARK: - Phase

    /// "Waning Gibbous".
    func phaseName(for phase: MoonPhase) -> String {
        Self.phaseNames[phase] ?? phase.rawValue
    }

    /// "75% lit at midnight": the illumination is sampled at the end of the
    /// selected day (DECISIONS.md 2026-09-23, PRODUCT FR5). Spoken only since
    /// the 5.4.6 card header, which shows `lit(_:)`.
    func illumination(_ fraction: Double) -> String {
        "\(lit(fraction)) at midnight"
    }

    /// "75% lit", for the card header (COMPASS-1.1.md §9.2).
    func lit(_ fraction: Double) -> String {
        "\(percent(fraction)) lit"
    }

    /// "Waning gibbous, 75% lit at midnight", for the phase row.
    func phaseAccessibilityLabel(phase: MoonPhase, illumination fraction: Double) -> String {
        "\(phaseName(for: phase)), \(illumination(fraction))"
    }

    // MARK: - Rise and set

    /// "Moonrise" or "Moonset".
    func eventName(_ event: Event) -> String {
        switch event {
        case .rise: "Moonrise"
        case .set: "Moonset"
        }
    }

    /// "↑ Moonrise" / "↓ Moonset", the column labels.
    func eventTitle(_ event: Event) -> String {
        switch event {
        case .rise: "↑ \(eventName(event))"
        case .set: "↓ \(eventName(event))"
        }
    }

    // MARK: - No rise or set (COMPASS-1.1.md §9.10)

    /// A day with no moonrise is one where the moon rose late the night
    /// before and next rises just after midnight (likewise moonset), so
    /// the card says when instead of "No moonrise today".
    static let afterMidnightText = "After midnight"
    /// The next one is more than a day away (polar edge).
    static let notTodayText = "Not today"

    /// "Sun 12:20 AM" and its spoken form "Sunday 12:20 AM": the next rise
    /// or set, on the day after a day without one, in the place's zone.
    func nextEventText(_ date: Date, in timeZone: TimeZone) -> (shown: String, spoken: String) {
        let time = time(date, in: timeZone)
        let weekday = Date.FormatStyle(locale: locale, timeZone: timeZone)
        let short = date.formatted(weekday.weekday(.abbreviated))
        let long = date.formatted(weekday.weekday(.wide))
        return ("\(short) \(time)", "\(long) \(time)")
    }

    /// "Moonrise, after midnight, Sunday 12:20 AM.", or with no next event
    /// in a day "Moonrise, not today."
    func missingAccessibilityLabel(for event: Event, nextSpoken: String?) -> String {
        guard let nextSpoken else {
            return "\(eventName(event)), \(Self.notTodayText.lowercased())."
        }
        return "\(eventName(event)), \(Self.afterMidnightText.lowercased()), \(nextSpoken)."
    }

    /// "9:10 PM" in the place's zone, rounded to the nearest minute.
    ///
    /// `Date.FormatStyle` drops the seconds, so 21:09:52 would read "9:09";
    /// USNO and the design brief round, so it reads "9:10". Half a minute
    /// rounds up (17:18:30 → "5:19", as USNO gives for the §5 reference row).
    func time(_ date: Date, in timeZone: TimeZone) -> String {
        timeText(date, in: timeZone).string
    }

    /// `time(_:in:)` split into runs, with the day period marked by the
    /// formatter itself (the `.amPM` date field), so the card can set it
    /// smaller wherever the locale puts it: after the digits ("9:10 PM"),
    /// before them ("오후 9:10"), or nowhere ("21:10").
    func timeText(_ date: Date, in timeZone: TimeZone) -> TimeText {
        let style = Date.FormatStyle(locale: locale, timeZone: timeZone).hour().minute()
        return TimeText(style.attributed.format(Self.roundedToMinute(date)))
    }

    /// "58° ENE", the compass's own formatting so one azimuth never reads two
    /// ways on screen (359.6° is "0° N" in both).
    func direction(for azimuth: Double) -> String {
        compass.bearing(for: azimuth)
    }

    /// The place's zone abbreviation at `date`, only when the place's clock
    /// differs from the device's then (§11 Q3). Sampled at the event itself,
    /// not the day, because a rise and a set can fall either side of a DST
    /// change.
    func timeZoneAbbreviation(for place: Place, at date: Date, deviceTimeZone: TimeZone) -> String? {
        guard place.isInDifferentTimeZone(from: deviceTimeZone, on: date) else { return nil }
        return place.timeZone.abbreviation(for: date)
    }

    /// "Moonrise at 5:19 PM, east-southeast, 105 degrees", plus the zone when
    /// shown: "Moonrise at 11:13 PM Sydney time, AEST, east-northeast, 56
    /// degrees" (the wording of the old "Times shown in Sydney time, AEST"
    /// label; §3.2). Directions are spoken in full, then the degrees.
    func accessibilityLabel(
        for event: Event,
        _ moonEvent: MoonEvent,
        place: Place,
        timeZoneAbbreviation: String?
    ) -> String {
        var time = time(moonEvent.date, in: place.timeZone)
        if let timeZoneAbbreviation {
            time += " \(place.shortName) time, \(timeZoneAbbreviation)"
        }
        let direction = "\(compass.spokenName(for: moonEvent.azimuth)), \(compass.spokenDegrees(for: moonEvent.azimuth))"
        return "\(eventName(event)) at \(time), \(direction)"
    }

    // MARK: - Helpers

    /// `date` moved to the nearest whole minute. The reference date is on a
    /// minute boundary, and every current zone offset is whole minutes, so
    /// this matches the minute the place's clock shows.
    private static func roundedToMinute(_ date: Date) -> Date {
        let minutes = (date.timeIntervalSinceReferenceDate / secondsPerMinute).rounded()
        return Date(timeIntervalSinceReferenceDate: minutes * secondsPerMinute)
    }

    private func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}
