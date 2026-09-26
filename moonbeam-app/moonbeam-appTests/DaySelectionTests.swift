//
//  DaySelectionTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `DaySelection`'s calendar-day math (DATE.md §3, §4, §6): the day belongs to
/// the place's time zone, moves by calendar days across DST, and stays within
/// ±366 days of the place's today.
@Suite("Day selection")
nonisolated struct DaySelectionTests {

    // MARK: - Fixtures

    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydney = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    /// Chile's DST starts at 00:00, so some days there have no midnight.
    private static let santiago = TimeZone(identifier: "America/Santiago") ?? .gmt

    private static let secondsPerHour = 3600.0

    // MARK: - Resolving today

    /// DATE.md §3: at 8 PM Sep 26 in LA, Sydney's today is already Sep 27.
    @Test("Today is the place's today, not one global day")
    func todayResolvesInThePlacesZone() throws {
        let now = try Self.date(2026, 9, 26, hour: 20, in: Self.losAngeles)

        #expect(DaySelection.today.resolvedDay(in: Self.losAngeles, now: now) == Self.day(2026, 9, 26))
        #expect(DaySelection.today.resolvedDay(in: Self.sydney, now: now) == Self.day(2026, 9, 27))
    }

    @Test("Start of day is local midnight in the place's zone")
    func startOfDayIsLocalMidnight() throws {
        let now = try Self.date(2026, 9, 26, hour: 20, in: Self.losAngeles)

        let start = DaySelection.today.startOfDay(in: Self.sydney, now: now)

        #expect(start == (try Self.date(2026, 9, 27, hour: 0, in: Self.sydney)))
    }

    @Test("Noon is local noon on the selected day")
    func noonIsLocalNoon() throws {
        let now = try Self.date(2026, 9, 26, hour: 20, in: Self.losAngeles)
        let selection = DaySelection.day(year: 2026, month: 10, day: 3)

        let noon = selection.noon(in: Self.losAngeles, now: now)

        #expect(noon == (try Self.date(2026, 10, 3, hour: 12, in: Self.losAngeles)))
    }

    // MARK: - Moving by a day

    @Test("Next day from today is a picked day; back again is today")
    func offsetFromTodayAndBack() throws {
        let now = try Self.date(2026, 9, 26, hour: 20, in: Self.losAngeles)

        let tomorrow = DaySelection.today.offset(by: 1, in: Self.losAngeles, now: now)
        #expect(tomorrow == .day(year: 2026, month: 9, day: 27))
        #expect(tomorrow.dayOffset(in: Self.losAngeles, now: now) == 1)

        let back = tomorrow.offset(by: -1, in: Self.losAngeles, now: now)
        #expect(back == .today)
        #expect(back.dayOffset(in: Self.losAngeles, now: now) == 0)
    }

    @Test("Picking today's date gives .today")
    func selectingTodayNormalizes() throws {
        let now = try Self.date(2026, 9, 26, hour: 20, in: Self.losAngeles)

        #expect(DaySelection.selecting(Self.day(2026, 9, 26), in: Self.losAngeles, now: now) == .today)
        #expect(
            DaySelection.selecting(Self.day(2026, 10, 3), in: Self.losAngeles, now: now)
                == .day(year: 2026, month: 10, day: 3)
        )
    }

    /// A picked day that is today counts as offset 0 even though it isn't
    /// `.today`, which is what the Today chip reads.
    @Test("A picked day equal to today has offset 0")
    func pickedTodayHasZeroOffset() throws {
        let now = try Self.date(2026, 9, 26, hour: 20, in: Self.losAngeles)
        let picked = DaySelection.day(year: 2026, month: 9, day: 26)

        #expect(picked.dayOffset(in: Self.losAngeles, now: now) == 0)
    }

    // MARK: - DST (DATE.md §6)

    /// LA falls back on 2026-11-01, so that day is 25 hours long.
    @Test("LA fall back: next and previous land on the right days and midnights")
    func losAngelesFallBack() throws {
        let now = try Self.date(2026, 10, 31, hour: 12, in: Self.losAngeles)

        let changeover = DaySelection.today.offset(by: 1, in: Self.losAngeles, now: now)
        #expect(changeover == .day(year: 2026, month: 11, day: 1))

        let after = changeover.offset(by: 1, in: Self.losAngeles, now: now)
        #expect(after == .day(year: 2026, month: 11, day: 2))
        #expect(after.offset(by: -1, in: Self.losAngeles, now: now) == changeover)

        let changeoverStart = changeover.startOfDay(in: Self.losAngeles, now: now)
        let afterStart = after.startOfDay(in: Self.losAngeles, now: now)
        #expect(changeoverStart == (try Self.date(2026, 11, 1, hour: 0, in: Self.losAngeles)))
        #expect(afterStart == (try Self.date(2026, 11, 2, hour: 0, in: Self.losAngeles)))
        #expect(afterStart.timeIntervalSince(changeoverStart) == 25 * Self.secondsPerHour)
    }

    /// Sydney springs forward on 2026-10-04, so that day is 23 hours long.
    @Test("Sydney spring forward: next and previous land on the right days and midnights")
    func sydneySpringForward() throws {
        let now = try Self.date(2026, 10, 3, hour: 12, in: Self.sydney)

        let changeover = DaySelection.today.offset(by: 1, in: Self.sydney, now: now)
        #expect(changeover == .day(year: 2026, month: 10, day: 4))

        let after = changeover.offset(by: 1, in: Self.sydney, now: now)
        #expect(after == .day(year: 2026, month: 10, day: 5))
        #expect(after.offset(by: -1, in: Self.sydney, now: now) == changeover)
        #expect(changeover.offset(by: -1, in: Self.sydney, now: now) == .today)

        let changeoverStart = changeover.startOfDay(in: Self.sydney, now: now)
        let afterStart = after.startOfDay(in: Self.sydney, now: now)
        #expect(changeoverStart == (try Self.date(2026, 10, 4, hour: 0, in: Self.sydney)))
        #expect(afterStart == (try Self.date(2026, 10, 5, hour: 0, in: Self.sydney)))
        #expect(afterStart.timeIntervalSince(changeoverStart) == 23 * Self.secondsPerHour)
    }

    /// Chile's DST starts at 00:00 on 2026-09-06, so that day has no
    /// midnight. The noon anchor still finds the day, and its start falls on
    /// it rather than the day before.
    @Test("A day with no midnight still resolves to itself")
    func dayWithNoMidnight() throws {
        let now = try Self.date(2026, 9, 5, hour: 12, in: Self.santiago)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.santiago

        let changeover = DaySelection.today.offset(by: 1, in: Self.santiago, now: now)
        #expect(changeover == .day(year: 2026, month: 9, day: 6))
        #expect(changeover.resolvedDay(in: Self.santiago, now: now) == Self.day(2026, 9, 6))

        let start = changeover.startOfDay(in: Self.santiago, now: now)
        #expect(calendar.dateComponents([.year, .month, .day], from: start) == Self.day(2026, 9, 6))
        #expect(changeover.offset(by: 1, in: Self.santiago, now: now) == .day(year: 2026, month: 9, day: 7))
    }

    // MARK: - Month and year boundaries

    @Test("Dec 31 → Jan 1 and back")
    func yearBoundary() throws {
        let now = try Self.date(2026, 12, 31, hour: 12, in: Self.losAngeles)

        let newYear = DaySelection.today.offset(by: 1, in: Self.losAngeles, now: now)
        #expect(newYear == .day(year: 2027, month: 1, day: 1))
        #expect(newYear.offset(by: -1, in: Self.losAngeles, now: now) == .today)

        let januaryFirst = try Self.date(2027, 1, 1, hour: 12, in: Self.losAngeles)
        #expect(
            DaySelection.today.offset(by: -1, in: Self.losAngeles, now: januaryFirst)
                == .day(year: 2026, month: 12, day: 31)
        )
    }

    @Test("Month ends roll into the next month")
    func monthBoundaries() throws {
        let now = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)

        let septemberEnd = DaySelection.day(year: 2026, month: 9, day: 30)
        #expect(septemberEnd.offset(by: 1, in: Self.losAngeles, now: now) == .day(year: 2026, month: 10, day: 1))

        let februaryEnd = DaySelection.day(year: 2027, month: 2, day: 28)
        #expect(februaryEnd.offset(by: 1, in: Self.losAngeles, now: now) == .day(year: 2027, month: 3, day: 1))
    }

    // MARK: - Range (±366)

    @Test("Moving past either end stops at ±366 days")
    func offsetClamps() throws {
        let now = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)
        let limit = DaySelection.maximumDayOffset

        let latest = DaySelection.today.offset(by: limit + 1, in: Self.losAngeles, now: now)
        #expect(latest.dayOffset(in: Self.losAngeles, now: now) == limit)
        #expect(latest.offset(by: 1, in: Self.losAngeles, now: now) == latest)

        let earliest = DaySelection.today.offset(by: -(limit + 1), in: Self.losAngeles, now: now)
        #expect(earliest.dayOffset(in: Self.losAngeles, now: now) == -limit)
        #expect(earliest.offset(by: -1, in: Self.losAngeles, now: now) == earliest)
    }

    @Test("Picking a date outside the range clamps it")
    func selectingClamps() throws {
        let now = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)
        let limit = DaySelection.maximumDayOffset

        let farFuture = DaySelection.selecting(Self.day(2030, 1, 1), in: Self.losAngeles, now: now)
        #expect(farFuture.dayOffset(in: Self.losAngeles, now: now) == limit)

        let farPast = DaySelection.selecting(Self.day(2020, 1, 1), in: Self.losAngeles, now: now)
        #expect(farPast.dayOffset(in: Self.losAngeles, now: now) == -limit)
    }

    /// A picked day can drift out of range when "today" moves on (a
    /// rollover or a city change). It resolves to the nearest end.
    @Test("A stored day outside the range resolves to the nearest end")
    func storedDayResolvesClamped() throws {
        let now = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)
        let stale = DaySelection.day(year: 2020, month: 1, day: 1)

        #expect(stale.dayOffset(in: Self.losAngeles, now: now) == -DaySelection.maximumDayOffset)
        #expect(stale.resolvedDay(in: Self.losAngeles, now: now) == Self.day(2025, 9, 25))
    }

    @Test("The picker range runs from the start of −366 to the start of +366")
    func pickerRange() throws {
        let now = try Self.date(2026, 9, 26, hour: 12, in: Self.losAngeles)

        let range = DaySelection.range(in: Self.losAngeles, now: now)

        #expect(range.lowerBound == (try Self.date(2025, 9, 25, hour: 0, in: Self.losAngeles)))
        #expect(range.upperBound == (try Self.date(2027, 9, 27, hour: 0, in: Self.losAngeles)))
    }

    // MARK: - Helpers

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

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
