//
//  MoonTableFormatterTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The moon card's text (DESIGN-1.1.md §3.2), pinned to `en_US` so the
/// strings don't depend on the test runner's locale.
@Suite("Moon table formatter")
nonisolated struct MoonTableFormatterTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: sydneyZone
    )

    private static let losAngeles = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.05,
        longitude: -118.24,
        timeZone: losAngelesZone
    )

    private let formatter = MoonTableFormatter(locale: Locale(identifier: "en_US"))

    // MARK: - Phase

    @Test("Every phase has a display name", arguments: [
        (MoonPhase.new, "New Moon"),
        (.waxingCrescent, "Waxing Crescent"),
        (.firstQuarter, "First Quarter"),
        (.waxingGibbous, "Waxing Gibbous"),
        (.full, "Full Moon"),
        (.waningGibbous, "Waning Gibbous"),
        (.lastQuarter, "Last Quarter"),
        (.waningCrescent, "Waning Crescent"),
    ])
    func phaseName(phase: MoonPhase, expected: String) {
        #expect(formatter.phaseName(for: phase) == expected)
    }

    @Test("Illumination reads as a whole percent at midnight", arguments: [
        (0.75, "75% lit at midnight"),
        (0.0, "0% lit at midnight"),
        (1.0, "100% lit at midnight"),
        (0.944, "94% lit at midnight"),
    ])
    func illumination(fraction: Double, expected: String) {
        #expect(formatter.illumination(fraction) == expected)
    }

    @Test("The card header shows the percent lit without \"at midnight\"", arguments: [
        (0.53, "53% lit"),
        (0.0, "0% lit"),
        (1.0, "100% lit"),
    ])
    func lit(fraction: Double, expected: String) {
        #expect(formatter.lit(fraction) == expected)
    }

    @Test("The phase row is spoken as one line")
    func phaseAccessibilityLabel() {
        let label = formatter.phaseAccessibilityLabel(phase: .waningGibbous, illumination: 0.75)
        #expect(label == "Waning Gibbous, 75% lit at midnight")
    }

    // MARK: - Rise and set

    @Test("Column titles and missing-event text")
    func titlesAndMissingText() {
        #expect(formatter.eventTitle(.rise) == "↑ Moonrise")
        #expect(formatter.eventTitle(.set) == "↓ Moonset")
        #expect(MoonTableFormatter.afterMidnightText == "After midnight")
        #expect(MoonTableFormatter.notTodayText == "Not today")
    }

    @Test("The next rise or set reads as weekday and time, in the place's zone")
    func nextEventText() throws {
        // 2026-10-04 00:20 in Los Angeles is 07:20 UTC.
        let date = try Self.date(2026, 10, 4, hour: 0, minute: 20, in: Self.losAngeles.timeZone)
        let text = formatter.nextEventText(date, in: Self.losAngeles.timeZone)

        #expect(text.shown == "Sun 12:20\u{202F}AM")
        #expect(text.spoken == "Sunday 12:20\u{202F}AM")
    }

    /// 2026-09-23 23:13 in Sydney is 06:13 in Los Angeles: the place's clock
    /// wins (PRODUCT FR1).
    @Test("Times are written in the place's zone")
    func timeInPlaceZone() throws {
        let date = try Self.date(2026, 9, 23, hour: 23, minute: 13, in: Self.sydneyZone)

        #expect(formatter.time(date, in: Self.sydneyZone) == "11:13\u{202F}PM")
        #expect(formatter.time(date, in: Self.losAngelesZone) == "6:13\u{202F}AM")
    }

    // MARK: - Day period runs

    /// The day period is found by its `.amPM` field, not by matching "AM":
    /// it can come last, first, or not at all.
    @Test("The day period is its own run, wherever the locale puts it", arguments: [
        ("en_US", ["9:10\u{202F}", "PM"], [false, true]),
        ("ko_KR", ["오후", " 9:10"], [true, false]),
        ("en_GB", ["21:10"], [false]),
        ("de_DE", ["21:10"], [false]),
    ])
    func dayPeriodRuns(locale: String, texts: [String], dayPeriods: [Bool]) throws {
        let formatter = MoonTableFormatter(locale: Locale(identifier: locale))
        let date = try Self.date(2026, 9, 30, hour: 21, minute: 10, in: Self.losAngelesZone)

        let time = formatter.timeText(date, in: Self.losAngelesZone)

        #expect(time.runs.map(\.text) == texts)
        #expect(time.runs.map(\.isDayPeriod) == dayPeriods)
        #expect(time.string == formatter.time(date, in: Self.losAngelesZone))
    }

    /// The engine's LA times for Sep 30 and Oct 3, 2026 (21:09:52, 14:26:33),
    /// which USNO and the brief give as 9:10 and 2:27. Truncating the seconds
    /// showed 9:09 and 2:26 (5.2 follow-up).
    @Test("Times round to the nearest minute", arguments: [
        (21, 9, 52, "9:10\u{202F}PM"),
        (14, 26, 33, "2:27\u{202F}PM"),
        (17, 18, 30, "5:19\u{202F}PM"),
        (17, 18, 29, "5:18\u{202F}PM"),
        (23, 59, 45, "12:00\u{202F}AM"),
    ])
    func timeRoundsToNearestMinute(hour: Int, minute: Int, second: Int, expected: String) throws {
        let date = try Self.date(2026, 9, 30, hour: hour, minute: minute, second: second, in: Self.losAngelesZone)
        #expect(formatter.time(date, in: Self.losAngelesZone) == expected)
    }

    @Test("Directions match the compass's bearing", arguments: [359.6, 72.5, 105.0, 0.4])
    func directionMatchesCompass(azimuth: Double) {
        #expect(formatter.direction(for: azimuth) == CompassFormatter().bearing(for: azimuth))
    }

    // MARK: - Time zone (§11 Q3)

    @Test("A zone only when the place's clock differs from the device's")
    func timeZoneOnlyWhenDifferent() throws {
        let date = try Self.date(2026, 9, 23, hour: 23, minute: 13, in: Self.sydneyZone)

        let sydney = formatter.timeZoneAbbreviation(for: Self.sydney, at: date, deviceTimeZone: Self.losAngelesZone)
        #expect(sydney == Self.sydneyZone.abbreviation(for: date))
        #expect(sydney != nil)

        let local = formatter.timeZoneAbbreviation(for: Self.losAngeles, at: date, deviceTimeZone: Self.losAngelesZone)
        #expect(local == nil)
    }

    // MARK: - Accessibility

    @Test("Spoken label without a zone: time, then the direction in full and its degrees")
    func accessibilityWithoutZone() throws {
        let date = try Self.date(2026, 9, 23, hour: 17, minute: 18, in: Self.losAngelesZone)
        let event = MoonEvent(date: date, azimuth: 105)

        let label = formatter.accessibilityLabel(for: .rise, event, place: Self.losAngeles, timeZoneAbbreviation: nil)

        #expect(label == "Moonrise at 5:18\u{202F}PM, east-southeast, 105 degrees")
    }

    @Test("Spoken label with a zone: the place's time and its abbreviation")
    func accessibilityWithZone() throws {
        let date = try Self.date(2026, 9, 23, hour: 23, minute: 13, in: Self.sydneyZone)
        let event = MoonEvent(date: date, azimuth: 66)

        let label = formatter.accessibilityLabel(for: .set, event, place: Self.sydney, timeZoneAbbreviation: "AEST")

        #expect(label == "Moonset at 11:13\u{202F}PM Sydney time, AEST, east-northeast, 66 degrees")
    }

    @Test("Spoken label for a missing event")
    func accessibilityMissing() {
        #expect(formatter.missingAccessibilityLabel(for: .rise, nextSpoken: "Sunday 12:20\u{202F}AM")
            == "Moonrise, after midnight, Sunday 12:20\u{202F}AM.")
        #expect(formatter.missingAccessibilityLabel(for: .set, nextSpoken: nil) == "Moonset, not today.")
    }

    // MARK: - Helpers

    private static func date(
        _ year: Int, _ month: Int, _ day: Int,
        hour: Int, minute: Int = 0, second: Int = 0,
        in timeZone: TimeZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        )
        return try #require(calendar.date(from: components))
    }
}
