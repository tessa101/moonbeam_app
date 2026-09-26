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

    @Test("Relative words for today, tomorrow and yesterday", arguments: [
        (0, "Today · Sat, Sep 26, 2026"),
        (1, "Tomorrow · Sat, Sep 26, 2026"),
        (-1, "Yesterday · Sat, Sep 26, 2026"),
    ])
    func relativeLabels(dayOffset: Int, expected: String) throws {
        let day = try Self.startOfDay(2026, 9, 26, in: Self.losAngeles)

        #expect(formatter.label(for: day, dayOffset: dayOffset, timeZone: Self.losAngeles) == expected)
    }

    @Test("Other days get the date alone", arguments: [2, -2, 7, 366])
    func plainLabel(dayOffset: Int) throws {
        let day = try Self.startOfDay(2026, 10, 3, in: Self.losAngeles)

        #expect(formatter.label(for: day, dayOffset: dayOffset, timeZone: Self.losAngeles) == "Sat, Oct 3, 2026")
    }

    // MARK: - Spoken value

    @Test("The spoken value spells out the weekday and month")
    func spokenValue() throws {
        let day = try Self.startOfDay(2026, 9, 26, in: Self.losAngeles)

        #expect(
            formatter.accessibilityValue(for: day, dayOffset: 0, timeZone: Self.losAngeles)
                == "Today, Saturday, September 26, 2026"
        )
        #expect(
            formatter.accessibilityValue(for: day, dayOffset: 3, timeZone: Self.losAngeles)
                == "Saturday, September 26, 2026"
        )
    }

    // MARK: - Place's zone

    /// Sydney's midnight starting Sep 27 is still Sep 26 on an LA clock. The
    /// label must read Sydney's day.
    @Test("The date is written in the place's zone, not the device's")
    func usesThePlacesZone() throws {
        let sydneyDay = try Self.startOfDay(2026, 9, 27, in: Self.sydney)

        #expect(formatter.label(for: sydneyDay, dayOffset: 0, timeZone: Self.sydney) == "Today · Sun, Sep 27, 2026")
        #expect(formatter.label(for: sydneyDay, dayOffset: 0, timeZone: Self.losAngeles) == "Today · Sat, Sep 26, 2026")
    }

    // MARK: - Helpers

    private static func startOfDay(_ year: Int, _ month: Int, _ day: Int, in timeZone: TimeZone) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
