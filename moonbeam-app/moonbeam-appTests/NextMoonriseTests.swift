//
//  NextMoonriseTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `nextMoonrise(for:after:)`, the Up now row's "Rises in …"
/// (COMPASS-1.1.md §3).
///
/// Uses the ASTRONOMY.md §5 reference row (Mar Vista, 2026-09-23: rise 17:18
/// at 105°) through `moonDay(for:on:)` itself, so it tests agreement with the
/// Moonrise column, within §5's tolerances.
@Suite("Next moonrise")
nonisolated struct NextMoonriseTests {

    // MARK: - Constants

    /// ASTRONOMY.md §5 tolerances.
    private static let timeToleranceSeconds = 120.0
    private static let azimuthToleranceDegrees = 2.0

    /// The moon rises about 50 minutes later each day, so the next day's
    /// rise is a little over a day after this one.
    private static let minimumGapToNextDaySeconds: TimeInterval = 23 * 60 * 60

    /// Just past a rise, as in `MoonPassTests`.
    private static let boundaryOffsetSeconds = 60.0
    private static let anHour: TimeInterval = 60 * 60

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private let service = AstronomyEngineMoonService()

    private let marVista = Place(
        name: "Los Angeles (Mar Vista), CA",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: NextMoonriseTests.losAngelesZone
    )

    // MARK: - Engine

    @Test("Before the day's moonrise: that moonrise")
    func beforeRiseFindsTablesRise() throws {
        let rise = try #require(service.moonDay(for: marVista, on: try Self.date(2026, 9, 23, hour: 12)).rise)

        let next = try #require(service.nextMoonrise(for: marVista, after: try Self.date(2026, 9, 23, hour: 12)))

        #expect(abs(next.date.timeIntervalSince(rise.date)) <= Self.timeToleranceSeconds)
        #expect(abs(next.azimuth - rise.azimuth) <= Self.azimuthToleranceDegrees)
    }

    @Test("After the day's moonrise: the next day's")
    func afterRiseFindsTomorrowsRise() throws {
        let rise = try #require(service.moonDay(for: marVista, on: try Self.date(2026, 9, 23, hour: 12)).rise)
        let tomorrow = try #require(service.moonDay(for: marVista, on: try Self.date(2026, 9, 24, hour: 12)).rise)

        let next = try #require(service.nextMoonrise(for: marVista, after: rise.date + Self.boundaryOffsetSeconds))

        #expect(abs(next.date.timeIntervalSince(tomorrow.date)) <= Self.timeToleranceSeconds)
        #expect(next.date.timeIntervalSince(rise.date) > Self.minimumGapToNextDaySeconds)
    }

    // MARK: - Fake

    @Test("Fake returns its scripted rise and records the moment")
    func fakeReturnsScriptedRise() throws {
        let moment = try Self.date(2026, 9, 23, hour: 12)
        let scripted = MoonEvent(date: moment + Self.anHour, azimuth: 105)
        let fake = FakeMoonService()
        fake.nextRise = scripted

        #expect(fake.nextMoonrise(for: marVista, after: moment) == scripted)
        #expect(fake.requestedNextRiseDates == [moment])
    }

    // MARK: - Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }
}
