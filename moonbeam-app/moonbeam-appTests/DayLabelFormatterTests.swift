//
//  DayLabelFormatterTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The date control's label and spoken value (DATE.md §1, §5), pinned to
/// `en_US` so the strings don't depend on the test runner's locale.
@Suite("Day label formatter")
nonisolated struct DayLabelFormatterTests {

    // MARK: - Fixtures

    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydney = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    private let formatter = DayLabelFormatter(locale: Locale(identifier: "en_US"))

    // MARK: - Visible label

    /// No relative word, whatever the offset: the Today chip covers that.
    @Test("Same year: weekday, month and day only", arguments: [
        (9, 26, "Sat, Sep 26"),
        (9, 27, "Sun, Sep 27"),
        (9, 25, "Fri, Sep 25"),
        (10, 3, "Sat, Oct 3"),
    ])
    func sameYearLabel(month: Int, day: Int, expected: String) throws {
        let today = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)
        let selected = try Self.date(2026, month, day, hour: 0, in: Self.losAngeles)

        #expect(formatter.label(for: selected, today: today, timeZone: Self.losAngeles) == expected)
    }

    @Test("A different year adds the year")
    func differentYearLabel() throws {
        let today = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)

        let next = try Self.date(2027, 1, 4, hour: 0, in: Self.losAngeles)
        #expect(formatter.label(for: next, today: today, timeZone: Self.losAngeles) == "Mon, Jan 4, 2027")

        let last = try Self.date(2025, 12, 1, hour: 0, in: Self.losAngeles)
        #expect(formatter.label(for: last, today: today, timeZone: Self.losAngeles) == "Mon, Dec 1, 2025")
    }

    /// Dec 31 → Jan 1: the year appears as soon as the day crosses it, in
    /// either direction.
    @Test("Year boundary: Dec 31 → Jan 1 and back")
    func yearBoundary() throws {
        let newYearsEve = try Self.date(2026, 12, 31, hour: 0, in: Self.losAngeles)
        let newYearsDay = try Self.date(2027, 1, 1, hour: 0, in: Self.losAngeles)

        let todayDec31 = try Self.date(2026, 12, 31, hour: 12, in: Self.losAngeles)
        #expect(formatter.label(for: newYearsEve, today: todayDec31, timeZone: Self.losAngeles) == "Thu, Dec 31")
        #expect(formatter.label(for: newYearsDay, today: todayDec31, timeZone: Self.losAngeles) == "Fri, Jan 1, 2027")

        let todayJan1 = try Self.date(2027, 1, 1, hour: 12, in: Self.losAngeles)
        #expect(formatter.label(for: newYearsDay, today: todayJan1, timeZone: Self.losAngeles) == "Fri, Jan 1")
        #expect(formatter.label(for: newYearsEve, today: todayJan1, timeZone: Self.losAngeles) == "Thu, Dec 31, 2026")
    }

    // MARK: - Spoken value

    @Test("The spoken value keeps the relative word and the year", arguments: [
        (0, 9, 26, "Today, Saturday, September 26, 2026"),
        (1, 9, 27, "Tomorrow, Sunday, September 27, 2026"),
        (-1, 9, 25, "Yesterday, Friday, September 25, 2026"),
        (7, 10, 3, "Saturday, October 3, 2026"),
    ])
    func spokenValue(dayOffset: Int, month: Int, day: Int, expected: String) throws {
        let selected = try Self.date(2026, month, day, hour: 0, in: Self.losAngeles)

        #expect(formatter.accessibilityValue(for: selected, dayOffset: dayOffset, timeZone: Self.losAngeles) == expected)
    }

    // MARK: - Place's zone

    /// Sydney's midnight starting Sep 27 is still Sep 26 on an LA clock. The
    /// label must read Sydney's day.
    @Test("The date is written in the place's zone, not the device's")
    func usesThePlacesZone() throws {
        let sydneyDay = try Self.date(2026, 9, 27, hour: 0, in: Self.sydney)

        #expect(formatter.label(for: sydneyDay, today: sydneyDay, timeZone: Self.sydney) == "Sun, Sep 27")
        #expect(formatter.label(for: sydneyDay, today: sydneyDay, timeZone: Self.losAngeles) == "Sat, Sep 26")
    }

    /// At 8 PM Dec 31 in LA it's already Jan 1 in Sydney. Sydney's today is
    /// in 2027, so its Jan 1 shows no year.
    @Test("The year is compared in the place's zone")
    func yearComparedInThePlacesZone() throws {
        let now = try Self.date(2026, 12, 31, hour: 20, in: Self.losAngeles)
        let sydneyNewYear = try Self.date(2027, 1, 1, hour: 0, in: Self.sydney)

        #expect(formatter.label(for: sydneyNewYear, today: now, timeZone: Self.sydney) == "Fri, Jan 1")
    }

    // MARK: - Helpers

    private static func date(
        _ year: Int, _ month: Int, _ day: Int,
        hour: Int,
        in timeZone: TimeZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }
}
