//
//  MoonPassTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `MoonPass` and `moonPass(for:containing:)`, the moon arc's data
/// (DESIGN-1.1.md §3.3a).
///
/// The engine checks use the ASTRONOMY.md §5 reference row (Mar Vista,
/// 2026-09-23: set 03:37 at 252°, rise 17:18 at 105°) and take the
/// boundaries from `moonDay(for:on:)` itself, so they test agreement with the
/// table, within §5's tolerances. Sydney checks the direction only: its moon
/// always passes north, so the arc must run anticlockwise.
@Suite("MoonPass")
nonisolated struct MoonPassTests {

    // MARK: - Constants

    /// ASTRONOMY.md §5 tolerances.
    private static let timeToleranceSeconds = 120.0
    private static let azimuthToleranceDegrees = 2.0

    /// Within a rise or set, as in `MoonPositionTests`.
    private static let boundaryOffsetSeconds = 60.0

    private static let halfTurn = 180.0
    private static let fullTurn = 360.0

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    private let service = AstronomyEngineMoonService()

    private let marVista = Place(
        name: "Los Angeles (Mar Vista), CA",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: MoonPassTests.losAngelesZone
    )

    private let sydney = Place(
        name: "Sydney",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: MoonPassTests.sydneyZone
    )

    // MARK: - Unwrapping

    @Test("Unwrapping carries on past north instead of jumping back")
    func unwrapsClockwise() {
        #expect(MoonPass.unwrapped([350, 5, 20]) == [350, 365, 380])
    }

    @Test("Unwrapping an anticlockwise pass through north goes below zero")
    func unwrapsAnticlockwise() {
        #expect(MoonPass.unwrapped([60, 30, 0, 330, 300]) == [60, 30, 0, -30, -60])
    }

    @Test("Unwrapping leaves a pass that doesn't cross north alone")
    func unwrapsPlainPass() {
        #expect(MoonPass.unwrapped([105, 180, 252]) == [105, 180, 252])
        #expect(MoonPass.unwrapped([]).isEmpty)
    }

    @Test("The moon's azimuth goes next to the nearest sample in time")
    func pathAzimuthUsesNearestSample() {
        let rise = Date(timeIntervalSince1970: 1_790_000_000)
        let pass = MoonPass(
            rise: MoonEvent(date: rise, azimuth: 350),
            set: MoonEvent(date: rise + 2 * MoonPass.sampleInterval, azimuth: 20),
            path: [350, 365, 380]
        )

        #expect(pass.pathAzimuth(for: 5, at: rise + MoonPass.sampleInterval) == 365)
        #expect(pass.pathAzimuth(for: 355, at: rise) == 355)
        // Past the set: the last sample.
        #expect(pass.pathAzimuth(for: 25, at: rise + 10 * MoonPass.sampleInterval) == 385)
    }

    // MARK: - Engine: agreement with the table

    @Test("The evening's pass starts at the table's moonrise")
    func passStartsAtTableRise() throws {
        let rise = try #require(service.moonDay(for: marVista, on: try Self.date(2026, 9, 23, hour: 12)).rise)

        let pass = try #require(service.moonPass(for: marVista, containing: rise.date + Self.boundaryOffsetSeconds))

        #expect(abs(pass.rise.date.timeIntervalSince(rise.date)) <= Self.timeToleranceSeconds)
        #expect(abs(pass.rise.azimuth - rise.azimuth) <= Self.azimuthToleranceDegrees)
        #expect(pass.path.first == pass.rise.azimuth)
        #expect(pass.set.date > rise.date)
    }

    /// At 1 AM on the 23rd the moon is on the pass that began the evening
    /// before; it ends at the 23rd's 03:37 moonset.
    @Test("The pass under way after midnight ends at the table's moonset")
    func passEndsAtTableSet() throws {
        let set = try #require(service.moonDay(for: marVista, on: try Self.date(2026, 9, 23, hour: 12)).set)

        let pass = try #require(service.moonPass(for: marVista, containing: try Self.date(2026, 9, 23, hour: 1)))

        #expect(abs(pass.set.date.timeIntervalSince(set.date)) <= Self.timeToleranceSeconds)
        #expect(abs(pass.set.azimuth - set.azimuth) <= Self.azimuthToleranceDegrees)
        #expect(pass.rise.date < (try Self.date(2026, 9, 23, hour: 0)))
    }

    @Test("No pass while the moon is down")
    func noPassWhileDown() throws {
        #expect(service.moonPass(for: marVista, containing: try Self.date(2026, 9, 23, hour: 12)) == nil)
    }

    // MARK: - Engine: the path

    @Test("Los Angeles: the path runs clockwise through the south")
    func northernPassRunsThroughSouth() throws {
        let pass = try #require(service.moonPass(for: marVista, containing: try Self.date(2026, 9, 23, hour: 22)))
        let first = try #require(pass.path.first)
        let last = try #require(pass.path.last)

        #expect(last > first)
        #expect(pass.path.contains { $0 > Self.halfTurn - Self.azimuthToleranceDegrees })
        #expect(abs(last.truncatingRemainder(dividingBy: Self.fullTurn) - pass.set.azimuth) < 1e-9)
    }

    @Test("Sydney: the path runs anticlockwise through the north")
    func southernPassRunsThroughNorth() throws {
        let rise = try #require(service.moonDay(for: sydney, on: try Self.date(2026, 9, 23, hour: 12, in: Self.sydneyZone)).rise)
        let pass = try #require(service.moonPass(for: sydney, containing: rise.date + Self.boundaryOffsetSeconds))
        let first = try #require(pass.path.first)
        let last = try #require(pass.path.last)

        #expect(last < first)
        // Crosses north: some sample is at or below a multiple of 360° from
        // the rise's side.
        let northCrossing = (first / Self.fullTurn).rounded(.down) * Self.fullTurn
        #expect(pass.path.contains { $0 <= northCrossing })
    }

    @Test("Samples every 15 minutes, neighbours under half a turn apart")
    func pathSampling() throws {
        let pass = try #require(service.moonPass(for: marVista, containing: try Self.date(2026, 9, 23, hour: 22)))
        let duration = pass.set.date.timeIntervalSince(pass.rise.date)

        #expect(pass.path.count == Int((duration / MoonPass.sampleInterval).rounded(.up)) + 1)
        for (previous, next) in zip(pass.path, pass.path.dropFirst()) {
            #expect(abs(next - previous) < Self.halfTurn)
        }
    }

    @Test("High latitude does not crash")
    func highLatitudeDoesNotCrash() throws {
        let longyearbyen = Place(
            name: "Longyearbyen",
            latitude: 78.22,
            longitude: 15.65,
            timeZone: TimeZone(identifier: "Arctic/Longyearbyen") ?? .gmt
        )
        _ = service.moonPass(for: longyearbyen, containing: try Self.date(2026, 9, 23, hour: 12))
    }

    // MARK: - Fake

    @Test("Fake returns its scripted pass and records the moment")
    func fakeReturnsScriptedPass() throws {
        let moment = try Self.date(2026, 9, 23, hour: 21)
        let scripted = MoonPass(
            rise: MoonEvent(date: moment, azimuth: 72),
            set: MoonEvent(date: moment + MoonPass.sampleInterval, azimuth: 76),
            path: [72, 76]
        )
        let fake = FakeMoonService(pass: scripted)

        #expect(fake.moonPass(for: marVista, containing: moment) == scripted)
        #expect(fake.requestedPassDates == [moment])
        #expect(fake.requestedPositionDates.isEmpty)
    }

    // MARK: - Helpers

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        in zone: TimeZone = losAngelesZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }
}
