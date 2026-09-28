//
//  MoonPositionTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `moonPosition(for:at:)`, the compass's live "Moon" target (COMPASS.md §3,
/// §6).
///
/// The key property is agreement with the moon table: "up" must flip at the
/// table's own rise and set times, not a minute or two either side. These use
/// the ASTRONOMY.md §5 reference row (Mar Vista, 2026-09-23: set 03:37,
/// rise 17:18), and take the boundary times from `moonDay(for:on:)` itself, so
/// they test agreement rather than restating the reference values.
@Suite("MoonPosition")
nonisolated struct MoonPositionTests {

    // MARK: - Constants

    /// Either side of a rise or set: COMPASS.md §6's "down one minute before,
    /// up one minute after".
    private static let boundaryOffsetSeconds = 60.0

    /// ASTRONOMY.md §5 azimuth tolerance.
    private static let azimuthToleranceDegrees = 2.0

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

    private var referenceDay: MoonDay {
        get throws {
            service.moonDay(for: place, on: try localDate(hour: 12, minute: 0))
        }
    }

    // MARK: - Boundaries agree with the table

    @Test("Down just before the table's moonrise, up just after")
    func flipsAtRise() throws {
        let rise = try #require(try referenceDay.rise)

        let before = service.moonPosition(for: place, at: rise.date - Self.boundaryOffsetSeconds)
        let after = service.moonPosition(for: place, at: rise.date + Self.boundaryOffsetSeconds)

        #expect(!before.isUp)
        #expect(after.isUp)
    }

    @Test("Up just before the table's moonset, down just after")
    func flipsAtSet() throws {
        let set = try #require(try referenceDay.set)

        let before = service.moonPosition(for: place, at: set.date - Self.boundaryOffsetSeconds)
        let after = service.moonPosition(for: place, at: set.date + Self.boundaryOffsetSeconds)

        #expect(before.isUp)
        #expect(!after.isUp)
    }

    /// The case the selected day's rise/set times can't answer: at 1 AM the
    /// day's table has no rise yet (17:18), but the moon rose the evening
    /// before and doesn't set until 03:37.
    @Test("Up in the early morning after rising the night before")
    func upSinceLastNight() throws {
        let oneAM = try localDate(hour: 1, minute: 0)
        let rise = try #require(try referenceDay.rise)
        #expect(rise.date > oneAM, "precondition: the day's rise is later than 1 AM")

        #expect(service.moonPosition(for: place, at: oneAM).isUp)
    }

    @Test("Down at midday, between the day's set and rise")
    func downAtMidday() throws {
        #expect(!service.moonPosition(for: place, at: try localDate(hour: 12, minute: 0)).isUp)
    }

    // MARK: - Azimuth

    /// At the moment of moonrise, the live position points where the table
    /// says to look.
    @Test("Azimuth at moonrise matches the table's rise azimuth")
    func azimuthAtRise() throws {
        let rise = try #require(try referenceDay.rise)
        let position = service.moonPosition(for: place, at: rise.date)

        #expect(abs(position.azimuth - rise.azimuth) <= Self.azimuthToleranceDegrees)
    }

    @Test("Azimuth at moonset matches the table's set azimuth")
    func azimuthAtSet() throws {
        let set = try #require(try referenceDay.set)
        let position = service.moonPosition(for: place, at: set.date)

        #expect(abs(position.azimuth - set.azimuth) <= Self.azimuthToleranceDegrees)
    }

    @Test("Azimuth stays within 0..<360 through the day", arguments: [0, 3, 6, 9, 12, 15, 18, 21])
    func azimuthInRange(hour: Int) throws {
        let position = service.moonPosition(for: place, at: try localDate(hour: hour, minute: 0))

        #expect(position.azimuth >= 0 && position.azimuth < 360)
    }

    // MARK: - High latitude

    /// High latitudes are out of scope for V1 but must not crash or hang.
    @Test("High latitude does not crash")
    func highLatitudeDoesNotCrash() throws {
        let longyearbyen = Place(
            name: "Longyearbyen",
            latitude: 78.22,
            longitude: 15.65,
            timeZone: TimeZone(identifier: "Arctic/Longyearbyen") ?? .gmt
        )
        let position = service.moonPosition(for: longyearbyen, at: try localDate(hour: 12, minute: 0))

        #expect(position.azimuth >= 0 && position.azimuth < 360)
    }

    // MARK: - Fake

    @Test("Fake returns its scripted position and records the moment")
    func fakeReturnsScriptedPosition() throws {
        let scripted = MoonPosition(azimuth: 140, isUp: true)
        let fake = FakeMoonService(position: scripted)
        let moment = try localDate(hour: 21, minute: 30)

        #expect(fake.moonPosition(for: place, at: moment) == scripted)
        #expect(fake.requestedPositionDates == [moment])
        #expect(fake.requestedDates.isEmpty)
    }

    // MARK: - Helpers

    /// A moment on the reference day, 2026-09-23, in Los Angeles.
    private func localDate(hour: Int, minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: Self.timeZoneIdentifier) ?? .gmt
        let components = DateComponents(year: 2026, month: 9, day: 23, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }
}
