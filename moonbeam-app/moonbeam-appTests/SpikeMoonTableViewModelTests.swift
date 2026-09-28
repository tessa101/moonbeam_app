//
//  SpikeMoonTableViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The spike behaviours other features depend on: the table is for the day it
/// was built with (Step 3), and its bearings read exactly like the compass's
/// (Step 4). The rest of the spike is replaced in Task #4 and isn't tested
/// here.
@Suite("Spike moon table")
@MainActor
struct SpikeMoonTableViewModelTests {

    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    /// Deliberately far from the real clock, so "uses `Date()`" can't pass by
    /// accident.
    private static func farDay() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngeles
        return try #require(calendar.date(from: DateComponents(year: 2020, month: 1, day: 15)))
    }

    /// `LocationViewModel`'s rollover check compares against `day`, so it
    /// has to be the day the table was built for.
    @Test("The day reaches the moon service and is kept")
    func dayReachesTheService() throws {
        let service = FakeMoonService()
        let day = try Self.farDay()

        let table = SpikeMoonTableViewModel(moonService: service, place: SpikeMoonTableViewModel.marVista, day: day)

        #expect(service.requestedDates == [day])
        #expect(table.day == day)
    }

    /// The table and the compass share `CompassFormatter.bearing(for:)`, so
    /// one azimuth never reads two ways on screen. 359.6° was "360° N" in the
    /// table before; 72.5° rounded half-to-even ("72°") there but half-away
    /// ("73°") on the compass.
    @Test("Rise and set bearings match the compass's", arguments: [359.6, 72.5, 105.0, 0.4])
    func bearingMatchesCompass(azimuth: Double) throws {
        let event = MoonEvent(date: try Self.farDay(), azimuth: azimuth)
        let service = FakeMoonService(rise: event, set: event)
        let table = SpikeMoonTableViewModel(moonService: service, day: try Self.farDay())
        let bearing = CompassFormatter().bearing(for: azimuth)

        #expect(table.riseText.hasSuffix(" · \(bearing)"))
        #expect(table.setText.hasSuffix(" · \(bearing)"))
    }

    @Test("A bearing just short of north reads 0° N, not 360° N")
    func nearNorthReadsZero() throws {
        let event = MoonEvent(date: try Self.farDay(), azimuth: 359.6)
        let table = SpikeMoonTableViewModel(moonService: FakeMoonService(rise: event), day: try Self.farDay())

        #expect(table.riseText.hasSuffix(" · 0° N"))
    }
}
