//
//  PlaceTimeZoneTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The rule from LOCATION.md §5 and PRODUCT FR1: moon times belong to the
/// **place**, not the device.
///
/// The device zone is passed in rather than read from `TimeZone.current`,
/// because a test process can't reliably change its own. That's the point of
/// the seam: the decision is a pure comparison, so it's testable without
/// relocating the simulator.
///
/// The Sydney rise/set values are **engine-derived**, not USNO: STATUS.md
/// still lists the Sydney row of ASTRONOMY.md §5 as unfilled, with the engine
/// predicting rise 14:24 and set 03:41 AEST. They're a regression guard on
/// the place's time zone reaching the calculation, which is what this suite is
/// about — not an independent check of the astronomy.
@Suite("Place time zones")
nonisolated struct PlaceTimeZoneTests {

    // MARK: - Fixtures

    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    /// ASTRONOMY.md §5 / STATUS.md: -33.87, 151.21, AEST (DST starts in
    /// October, so 2026-09-23 is +10).
    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: sydneyZone
    )

    private static let marVista = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: losAngeles
    )

    /// ASTRONOMY.md §5.
    private static let timeToleranceSeconds = 120.0

    private let service = AstronomyEngineMoonService()

    // MARK: - The time zone label (§3)

    @Test("Sydney on a Los Angeles device is flagged as elsewhere")
    func sydneyOnALosAngelesDeviceShowsTheLabel() {
        #expect(Self.sydney.isInDifferentTimeZone(from: Self.losAngeles))
    }

    @Test("Mar Vista on a Los Angeles device is not")
    func marVistaOnALosAngelesDeviceHidesTheLabel() {
        #expect(!Self.marVista.isInDifferentTimeZone(from: Self.losAngeles))
    }

    /// Compared by offset, so an alias identifier doesn't read as elsewhere.
    @Test("An aliased identifier for the same offset is not elsewhere")
    func aliasedIdentifierIsNotElsewhere() throws {
        let aliased = try #require(TimeZone(identifier: "US/Pacific"))
        #expect(!Self.marVista.isInDifferentTimeZone(from: aliased))
    }

    // MARK: - Sydney times, on an LA device

    /// The end-to-end version: `place.timeZone` reaches `MoonService`, anchors
    /// the day on Sydney's local midnight, and the results read as AEST wall
    /// clock — whatever the device's zone is.
    @Test("Sydney's moon times are calculated and read in AEST")
    func sydneyTimesAreInAEST() throws {
        let moonDay = service.moonDay(for: Self.sydney, on: try Self.sydneyDate(hour: 12, minute: 0))

        let rise = try #require(moonDay.rise, "expected a moonrise in Sydney on 2026-09-23")
        let set = try #require(moonDay.set, "expected a moonset in Sydney on 2026-09-23")

        let expectedRise = try Self.sydneyDate(hour: 14, minute: 24)
        let expectedSet = try Self.sydneyDate(hour: 3, minute: 41)

        #expect(
            abs(rise.date.timeIntervalSince(expectedRise)) <= Self.timeToleranceSeconds,
            "moonrise \(Self.describe(rise.date)) is more than 2 minutes from 14:24 AEST"
        )
        #expect(
            abs(set.date.timeIntervalSince(expectedSet)) <= Self.timeToleranceSeconds,
            "moonset \(Self.describe(set.date)) is more than 2 minutes from 03:41 AEST"
        )

        // Read in the place's zone these are Sydney afternoon and small
        // hours; on the device's Los Angeles clock the same instants fall in
        // different hours entirely. Asserted on the hour rather than the
        // minute because the reference values above are rounded, and the
        // ±2 minute checks already cover the minutes.
        #expect(Self.hour(of: rise.date, in: Self.sydneyZone) == 14)
        #expect(Self.hour(of: set.date, in: Self.sydneyZone) == 3)

        // AEST, not AEDT: Sydney's DST starts in October.
        #expect(Self.sydneyZone.secondsFromGMT(for: rise.date) == 10 * 3600)
    }

    /// The same instants formatted in the *device's* zone read differently —
    /// which is exactly why §5 insists on the place's zone, and why showing
    /// the "Sydney · AEST" label matters.
    @Test("The same instants read differently on a Los Angeles clock")
    func theDeviceZoneWouldShowDifferentTimes() throws {
        let moonDay = service.moonDay(for: Self.sydney, on: try Self.sydneyDate(hour: 12, minute: 0))
        let rise = try #require(moonDay.rise)

        #expect(
            Self.wallClock(rise.date, in: Self.sydneyZone)
                != Self.wallClock(rise.date, in: Self.losAngeles)
        )
    }

    /// What reaches `MoonService` is the place's *offset*, via the local
    /// midnight it anchors the day on. A fixed +10 zone and
    /// `Australia/Sydney` therefore produce the same table on this date — and
    /// neither depends on the device.
    @Test("Only the place's offset reaches the calculation")
    func onlyThePlacesOffsetReachesTheCalculation() throws {
        let fixedOffsetSydney = Place(
            name: "Sydney",
            latitude: -33.87,
            longitude: 151.21,
            timeZone: TimeZone(secondsFromGMT: 10 * 3600) ?? .gmt
        )

        let noon = try Self.sydneyDate(hour: 12, minute: 0)
        let canonical = service.moonDay(for: Self.sydney, on: noon)
        let fixedOffset = service.moonDay(for: fixedOffsetSydney, on: noon)

        #expect(canonical.rise?.date == fixedOffset.rise?.date)
        #expect(canonical.set?.date == fixedOffset.set?.date)
    }

    // MARK: - Helpers

    /// A wall-clock time on 2026-09-23 in Sydney.
    private static func sydneyDate(hour: Int, minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sydneyZone
        let components = DateComponents(
            year: 2026, month: 9, day: 23, hour: hour, minute: minute
        )
        return try #require(calendar.date(from: components))
    }

    /// 24-hour "HH:mm", so the assertions don't depend on the test runner's
    /// locale.
    private static func wallClock(_ date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private static func hour(of date: Date, in timeZone: TimeZone) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.hour], from: date).hour
    }

    /// Failure messages read as Sydney wall clock.
    private static func describe(_ date: Date) -> String {
        wallClock(date, in: sydneyZone)
    }
}
