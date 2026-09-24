//
//  AstronomyEngineMoonServiceTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// Checks the vendored Astronomy Engine against the reference table in
/// ASTRONOMY.md §5, within the tolerances stated there.
///
/// Per CLAUDE.md, a failure here is never to be "fixed" by widening a
/// tolerance without logging the decision in DECISIONS.md.
@Suite("AstronomyEngineMoonService vs ASTRONOMY.md §5")
nonisolated struct AstronomyEngineMoonServiceTests {

    // MARK: - Tolerances (ASTRONOMY.md §5)

    private static let timeToleranceSeconds = 120.0
    private static let azimuthToleranceDegrees = 2.0
    private static let illuminationTolerance = 0.01

    // MARK: - Reference row: Los Angeles (Mar Vista), 2026-09-23

    private static let timeZoneIdentifier = "America/Los_Angeles"

    private let service = AstronomyEngineMoonService()

    private var place: Place {
        Place(
            name: "Los Angeles (Mar Vista), CA",
            latitude: 34.00,
            longitude: -118.43,
            timeZone: TimeZone(identifier: Self.timeZoneIdentifier) ?? .gmt
        )
    }

    /// Midday on the reference date, so the day itself is unambiguous.
    private var referenceDate: Date {
        get throws {
            try localDate(year: 2026, month: 9, day: 23, hour: 12, minute: 0)
        }
    }

    // MARK: - Rise

    @Test("Moonrise matches the reference time")
    func moonriseTime() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let rise = try #require(moonDay.rise, "expected a moonrise on 2026-09-23")
        let expected = try localDate(year: 2026, month: 9, day: 23, hour: 17, minute: 18)

        #expect(
            abs(rise.date.timeIntervalSince(expected)) <= Self.timeToleranceSeconds,
            "moonrise \(describe(rise.date)) differs from expected \(describe(expected)) by more than 2 minutes"
        )
    }

    @Test("Moonrise azimuth is east-southeast")
    func moonriseAzimuth() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let rise = try #require(moonDay.rise)
        let expectedAzimuth = 105.0

        #expect(abs(rise.azimuth - expectedAzimuth) <= Self.azimuthToleranceDegrees)
        #expect(CompassFormatter().abbreviation(for: rise.azimuth) == "ESE")
    }

    // MARK: - Set

    @Test("Moonset matches the reference time")
    func moonsetTime() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let set = try #require(moonDay.set, "expected a moonset on 2026-09-23")
        let expected = try localDate(year: 2026, month: 9, day: 23, hour: 3, minute: 37)

        #expect(
            abs(set.date.timeIntervalSince(expected)) <= Self.timeToleranceSeconds,
            "moonset \(describe(set.date)) differs from expected \(describe(expected)) by more than 2 minutes"
        )
    }

    @Test("Moonset azimuth is west-southwest")
    func moonsetAzimuth() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let set = try #require(moonDay.set)
        let expectedAzimuth = 252.0

        #expect(abs(set.azimuth - expectedAzimuth) <= Self.azimuthToleranceDegrees)
        #expect(CompassFormatter().abbreviation(for: set.azimuth) == "WSW")
    }

    /// ASTRONOMY.md §4: a set before a rise on the same day is normal.
    @Test("Set precedes rise on this day")
    func setPrecedesRise() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let rise = try #require(moonDay.rise)
        let set = try #require(moonDay.set)

        #expect(set.date < rise.date)
    }

    // MARK: - Phase and illumination

    /// Sampled at tonight's local midnight per PRODUCT FR5, which is what
    /// puts the reference value at 94% rather than 91%.
    @Test("Illumination matches the reference percentage")
    func illumination() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let expected = 0.94

        #expect(
            abs(moonDay.illumination - expected) <= Self.illuminationTolerance,
            "illumination \(moonDay.illumination) is more than 1% from \(expected)"
        )
    }

    @Test("Phase is waxing gibbous")
    func phase() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)

        #expect(moonDay.phase == .waxingGibbous)
        #expect(moonDay.phaseAngle > 96 && moonDay.phaseAngle < 174)
    }

    // MARK: - Conventions

    /// The day is anchored on the place's local midnight, so *any* instant
    /// within that local day must produce an identical table. This is what
    /// stops the answer drifting as the day wears on.
    @Test("Any instant in the local day gives the same table")
    func anyInstantInLocalDayGivesSameTable() throws {
        let justAfterMidnight = try localDate(
            year: 2026, month: 9, day: 23, hour: 0, minute: 30
        )
        let lateEvening = try localDate(
            year: 2026, month: 9, day: 23, hour: 23, minute: 30
        )

        let early = service.moonDay(for: place, on: justAfterMidnight)
        let late = service.moonDay(for: place, on: lateEvening)

        #expect(early.rise?.date == late.rise?.date)
        #expect(early.set?.date == late.set?.date)
        #expect(early.illumination == late.illumination)
        #expect(early.phaseAngle == late.phaseAngle)
    }

    /// The place's own time zone drives the calculation, so the same
    /// coordinates read against a different zone anchor on a different
    /// midnight and can yield a different illumination.
    @Test("The place's time zone drives the anchor")
    func placeTimeZoneDrivesTheAnchor() throws {
        let sameCoordinatesInUTC = Place(
            name: "Mar Vista coordinates, UTC clock",
            latitude: 34.00,
            longitude: -118.43,
            timeZone: .gmt
        )

        let local = service.moonDay(for: place, on: try referenceDate)
        let utc = service.moonDay(for: sameCoordinatesInUTC, on: try referenceDate)

        // Local midnight in Los Angeles is not midnight in UTC, so the
        // sampling moments differ and so must the illumination.
        #expect(local.illumination != utc.illumination)
    }

    /// High latitudes are out of scope for V1 but must not crash or hang.
    @Test("High latitude does not crash")
    func highLatitudeDoesNotCrash() throws {
        let reykjavik = Place(
            name: "Reykjavík",
            latitude: 64.15,
            longitude: -21.94,
            timeZone: TimeZone(identifier: "Atlantic/Reykjavik") ?? .gmt
        )
        let moonDay = service.moonDay(for: reykjavik, on: try referenceDate)

        #expect(moonDay.illumination >= 0 && moonDay.illumination <= 1)
        #expect(moonDay.phaseAngle >= 0 && moonDay.phaseAngle < 360)
    }

    // MARK: - Helpers

    private func localDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: Self.timeZoneIdentifier) ?? .gmt
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return try #require(calendar.date(from: components))
    }

    /// Formats in the place's zone, so failure messages read as local time.
    private func describe(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.month().day().hour().minute()
        style.timeZone = TimeZone(identifier: Self.timeZoneIdentifier) ?? .gmt
        return date.formatted(style)
    }
}
