//
//  LocationViewModelMapTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// Opening the map from the card (MAP.md §3.1): a tapped Moonrise or Moonset
/// cell builds the map for the card's own events, with that line emphasised.
@Suite("Location view model: map", .timeLimit(.minutes(1)))
@MainActor
struct LocationViewModelMapTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private static let irvine = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: losAngelesZone
    )

    private static func date(_ hour: Int, _ minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        let components = DateComponents(year: 2026, month: 11, day: 24, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }

    private static func makeViewModel(moonService: FakeMoonService, now: Date) -> LocationViewModel {
        LocationViewModel(
            locationService: FakeLocationService(),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: moonService,
            headingService: FakeHeadingService(),
            deviceTimeZone: losAngelesZone,
            now: { now }
        )
    }

    // MARK: - Tests

    @Test("No place, no map")
    func noPlace() throws {
        let viewModel = Self.makeViewModel(moonService: FakeMoonService(), now: try Self.date(12, 54))
        viewModel.presentMap(.rise)
        #expect(!viewModel.isMapPresented)
        #expect(viewModel.mapSheet == nil)
    }

    @Test("A tapped cell opens the map on the place, with the card's events", arguments: [
        MoonTableFormatter.Event.rise, .set
    ])
    func opensMap(event: MoonTableFormatter.Event) throws {
        let rise = MoonEvent(date: try Self.date(16, 42), azimuth: 58)
        let set = MoonEvent(date: try Self.date(6, 46), azimuth: 301)
        let viewModel = Self.makeViewModel(moonService: FakeMoonService(rise: rise, set: set), now: try Self.date(12, 54))
        viewModel.select(Self.irvine)

        viewModel.presentMap(event)

        #expect(viewModel.isMapPresented)
        let map = try #require(viewModel.mapSheet)
        #expect(map.place == Self.irvine)
        #expect(map.emphasised == event)
        #expect(map.lines.map(\.bearingLine.bearing) == [58, 301])
        #expect(map.pin == BearingLine.Coordinate(latitude: 33.68, longitude: -117.83))
    }

    @Test("A day without a moonrise in reach draws only the moonset")
    func missingRise() throws {
        let set = MoonEvent(date: try Self.date(6, 46), azimuth: 301)
        let viewModel = Self.makeViewModel(moonService: FakeMoonService(set: set), now: try Self.date(12, 54))
        viewModel.select(Self.irvine)

        viewModel.presentMap(.set)

        let map = try #require(viewModel.mapSheet)
        #expect(map.lines.map(\.event) == [.set])
    }
}
