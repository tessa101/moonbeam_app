//
//  MoonMapViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The map sheet's state (MAP.md §3, §7): lines from the pin for the events
/// the card shows, labels in the place's zone, the tapped line emphasised,
/// Follow me only with location, and the offline state.
///
/// Irvine on 2026-11-24, as in Tessa's screenshot: moonrise 4:42 PM at 58°
/// ENE, moonset 6:46 AM at 301° WNW. The events are fixed inputs here; the
/// engine's own values are `AstronomyEngineMoonServiceTests`' business.
@Suite("MoonMapViewModel", .timeLimit(.minutes(1)))
@MainActor
struct MoonMapViewModelTests {

    // MARK: - Fixtures

    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let formatter = MoonTableFormatter(locale: Locale(identifier: "en_US"))

    private static let irvine = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: losAngeles
    )

    private static let day = date(2026, 11, 24, 0, 0)
    private static let rise = MoonEvent(date: date(2026, 11, 24, 16, 42), azimuth: 58)
    private static let set = MoonEvent(date: date(2026, 11, 24, 6, 46), azimuth: 301)

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngeles
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? .distantPast
    }

    private static func makeViewModel(
        place: Place = irvine,
        rise: MoonEvent? = rise,
        set: MoonEvent? = set,
        emphasised: MoonTableFormatter.Event = .rise,
        canFollowUser: Bool = true,
        connectivity: FakeConnectivityService = FakeConnectivityService()
    ) -> MoonMapViewModel {
        MoonMapViewModel(
            place: place,
            day: day,
            rise: rise,
            set: set,
            emphasised: emphasised,
            canFollowUser: canFollowUser,
            connectivity: connectivity,
            formatter: formatter
        )
    }

    // MARK: - Pin and lines

    @Test("Opens in satellite, with the pin on the place")
    func initialState() {
        let model = Self.makeViewModel()
        #expect(model.style == .satellite)
        #expect(model.pin == BearingLine.Coordinate(latitude: 33.68, longitude: -117.83))
        #expect(model.isOnline)
    }

    @Test("Rise then set, each from the pin at its own bearing, 30 km long")
    func linesFromPin() {
        let model = Self.makeViewModel()
        let lines = model.lines
        #expect(lines.map(\.event) == [.rise, .set])
        #expect(lines.map(\.bearingLine.bearing) == [58, 301])
        #expect(lines.allSatisfy { $0.bearingLine.start == model.pin })
        #expect(lines.allSatisfy { $0.bearingLine.length == BearingLine.defaultLength })
    }

    @Test("Moving the pin moves both lines; the bearings stay")
    func pinMoves() {
        let model = Self.makeViewModel()
        let beach = BearingLine.Coordinate(latitude: 33.59, longitude: -117.87)
        model.pinMoved(to: beach)
        #expect(model.pin == beach)
        #expect(model.lines.allSatisfy { $0.bearingLine.start == beach })
        #expect(model.lines.map(\.bearingLine.bearing) == [58, 301])
    }

    @Test("The tapped cell's line is emphasised", arguments: [MoonTableFormatter.Event.rise, .set])
    func emphasis(event: MoonTableFormatter.Event) {
        let model = Self.makeViewModel(emphasised: event)
        #expect(model.lines.filter(\.isEmphasised).map(\.event) == [event])
    }

    @Test("No event, no line")
    func missingEvent() {
        let model = Self.makeViewModel(set: nil)
        #expect(model.lines.map(\.event) == [.rise])
        let empty = Self.makeViewModel(rise: nil, set: nil)
        #expect(empty.lines.isEmpty)
        #expect(empty.mapAccessibilityLabel == "Map. No moonrise or moonset to show.")
    }

    // MARK: - Labels

    @Test("Labels give the time in the place's zone and the bearing")
    func labels() {
        let model = Self.makeViewModel()
        let rise = model.lines[0]
        #expect(rise.title == "↑ Moonrise")
        #expect(rise.detail == "4:42\u{202F}PM · 58° ENE")
        #expect(rise.accessibilityLabel == "Moonrise at 4:42\u{202F}PM, east-northeast, 58 degrees.")
        let set = model.lines[1]
        #expect(set.title == "↓ Moonset")
        #expect(set.detail == "6:46\u{202F}AM · 301° WNW")
    }

    /// A day without a moonrise shows the next one, after midnight (FR2).
    @Test("An event on another day carries its weekday")
    func nextDayLabel() {
        let afterMidnight = MoonEvent(date: Self.date(2026, 11, 25, 0, 20), azimuth: 62)
        let model = Self.makeViewModel(rise: afterMidnight)
        let rise = model.lines[0]
        #expect(rise.detail == "Wed 12:20\u{202F}AM · 62° ENE")
        #expect(rise.accessibilityLabel == "Moonrise Wednesday 12:20\u{202F}AM, east-northeast, 62 degrees.")
    }

    @Test("The map's VoiceOver summary reads every line")
    func mapSummary() {
        let model = Self.makeViewModel()
        #expect(model.mapAccessibilityLabel.hasPrefix("Map. Lines from the pin: Moonrise at"))
        #expect(model.mapAccessibilityLabel.contains("Moonset at 6:46\u{202F}AM, west-northwest, 301 degrees."))
    }

    // MARK: - Follow me

    @Test(
        "Follow me needs location; it starts on only at your own position",
        arguments: [(true, true, true), (true, false, false), (false, true, false), (false, false, false)]
    )
    func followMe(canFollow: Bool, isCurrentLocation: Bool, startsFollowing: Bool) {
        var place = Self.irvine
        place.isCurrentLocation = isCurrentLocation
        let model = Self.makeViewModel(place: place, canFollowUser: canFollow)
        #expect(model.canFollowUser == canFollow)
        #expect(model.startsFollowingUser == startsFollowing)
    }

    // MARK: - Offline

    private static func settle(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    @Test("Follows the network while the sheet is open")
    func offline() async {
        let connectivity = FakeConnectivityService(isOnline: false)
        let model = Self.makeViewModel(connectivity: connectivity)
        let observation = Task { await model.observeConnectivity() }
        await Self.settle { !model.isOnline }
        #expect(!model.isOnline)

        connectivity.isOnline = true
        await Self.settle { model.isOnline }
        #expect(model.isOnline)
        observation.cancel()
    }
}
