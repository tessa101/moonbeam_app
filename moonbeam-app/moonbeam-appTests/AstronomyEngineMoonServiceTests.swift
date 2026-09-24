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
/// Rise/set times and the local-noon illumination are checked against **USNO**,
/// an independent source. Azimuths and tonight's-midnight illumination have no
/// USNO equivalent — USNO publishes no rise/set azimuth at all, and its
/// `fracillum` is sampled at local noon — so those are engine-derived
/// regression guards, labelled as such.
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

    /// USNO publishes 17:19 for this location and date. The engine returns
    /// 17:18:30, which rounds to 17:18 — a 30-second difference, comfortably
    /// inside the ±2 minute tolerance.
    @Test("Moonrise matches USNO")
    func moonriseTime() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let rise = try #require(moonDay.rise, "expected a moonrise on 2026-09-23")
        let usno = try localDate(year: 2026, month: 9, day: 23, hour: 17, minute: 19)

        #expect(
            abs(rise.date.timeIntervalSince(usno)) <= Self.timeToleranceSeconds,
            "moonrise \(describe(rise.date)) differs from USNO \(describe(usno)) by more than 2 minutes"
        )
    }

    /// Engine-derived: USNO publishes no rise/set azimuth, which is precisely
    /// why the app calculates on device (ASTRONOMY.md §1).
    @Test("Moonrise azimuth is east-southeast (engine-derived)")
    func moonriseAzimuth() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let rise = try #require(moonDay.rise)
        let expectedAzimuth = 105.0

        #expect(abs(rise.azimuth - expectedAzimuth) <= Self.azimuthToleranceDegrees)
        #expect(CompassFormatter().abbreviation(for: rise.azimuth) == "ESE")
    }

    // MARK: - Set

    /// USNO publishes 03:37; the engine returns 03:37:09.
    @Test("Moonset matches USNO")
    func moonsetTime() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let set = try #require(moonDay.set, "expected a moonset on 2026-09-23")
        let usno = try localDate(year: 2026, month: 9, day: 23, hour: 3, minute: 37)

        #expect(
            abs(set.date.timeIntervalSince(usno)) <= Self.timeToleranceSeconds,
            "moonset \(describe(set.date)) differs from USNO \(describe(usno)) by more than 2 minutes"
        )
    }

    /// Engine-derived, for the same reason as the moonrise azimuth.
    @Test("Moonset azimuth is west-southwest (engine-derived)")
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

    /// The real external check on illumination: USNO reports `fracillum` 91%
    /// for this date, sampled at **local noon**. Verifying at that moment is
    /// what proves the engine's illumination maths, independent of which
    /// moment the app chooses to display (ASTRONOMY.md §3).
    @Test("Illumination at local noon matches USNO")
    func illuminationAtLocalNoonMatchesUSNO() throws {
        let localNoon = try localDate(year: 2026, month: 9, day: 23, hour: 12, minute: 0)
        let usnoFracillum = 0.91

        let engine = service.illumination(at: localNoon)

        #expect(
            abs(engine - usnoFracillum) <= Self.illuminationTolerance,
            "illumination at local noon \(engine) is more than 1% from USNO's \(usnoFracillum)"
        )
    }

    /// Engine-derived regression guard, not a USNO check. The app displays
    /// tonight's local midnight per PRODUCT FR5, which reads ~93.6% and so
    /// rounds to 94% — a different moment from USNO's noon sample, hence the
    /// three-point gap. Pins the displayed value against drift.
    @Test("Illumination at tonight's midnight stays at 94% (engine-derived)")
    func illuminationAtTonightsMidnight() throws {
        let moonDay = service.moonDay(for: place, on: try referenceDate)
        let expected = 0.94

        #expect(
            abs(moonDay.illumination - expected) <= Self.illuminationTolerance,
            "illumination \(moonDay.illumination) is more than 1% from \(expected)"
        )
    }

    /// The gap between the two moments is real, not rounding: it's what makes
    /// the sampling moment worth pinning down in the first place.
    @Test("Noon and midnight illumination differ measurably")
    func noonAndMidnightDiffer() throws {
        let localNoon = try localDate(year: 2026, month: 9, day: 23, hour: 12, minute: 0)
        let moonDay = service.moonDay(for: place, on: try referenceDate)

        let gap = moonDay.illumination - service.illumination(at: localNoon)
        let minimumExpectedGap = 0.02

        // Waxing, so the later sample must be brighter.
        #expect(gap > minimumExpectedGap)
    }

    /// USNO reports "Waxing Gibbous" for this date, with the next full moon on
    /// 2026-09-26 — consistent with a phase angle short of 180°.
    @Test("Phase is waxing gibbous, matching USNO")
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
