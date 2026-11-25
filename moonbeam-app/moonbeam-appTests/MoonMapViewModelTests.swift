//
//  MoonMapViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The map sheet's state (MAP.md §3, §7): lines from the pin for the events
/// the card shows, labels in the place's zone, the selected line, Follow me
/// (on by default, undone far from the place), the lock and turn hints while
/// the map turns with the phone, and the offline state.
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
        selected: MoonTableFormatter.Event = .rise,
        canFollowUser: Bool = true,
        connectivity: FakeConnectivityService = FakeConnectivityService()
    ) -> MoonMapViewModel {
        MoonMapViewModel(
            place: place,
            day: day,
            rise: rise,
            set: set,
            selected: selected,
            canFollowUser: canFollowUser,
            connectivity: connectivity,
            headingService: FakeHeadingService(),
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

    @Test("The style switch reads Satellite, Explore, 3D")
    func styles() {
        #expect(MoonMapViewModel.Style.allCases == [.satellite, .explore, .threeD])
        #expect(MoonMapViewModel.Style.allCases.map(\.title) == ["Satellite", "Explore", "3D"])
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
        model.cameraChanged(center: beach, heading: 0, distance: 6_000, followsHeading: false)
        #expect(model.pin == beach)
        #expect(model.lines.allSatisfy { $0.bearingLine.start == beach })
        #expect(model.lines.map(\.bearingLine.bearing) == [58, 301])
    }

    @Test("The tapped cell's line starts selected", arguments: [MoonTableFormatter.Event.rise, .set])
    func initialSelection(event: MoonTableFormatter.Event) {
        let model = Self.makeViewModel(selected: event)
        #expect(model.lines.filter(\.isSelected).map(\.event) == [event])
    }

    @Test("The map's own switch changes the selected line")
    func switchSelection() {
        let model = Self.makeViewModel(selected: .rise)
        model.select(.set)
        #expect(model.selected == .set)
        #expect(model.lines.filter(\.isSelected).map(\.event) == [.set])
    }

    @Test("Each line has a tag near the pin, a quarter of the view away")
    func mapLabels() {
        let model = Self.makeViewModel()
        model.cameraChanged(center: model.pin, heading: 0, distance: 8_000, followsHeading: false)
        let rise = model.lines[0]
        #expect(rise.mapLabel == "Moonrise 58°")
        let away = BearingLine.distance(from: model.pin, to: rise.mapLabelCoordinate)
        #expect(abs(away - 2_000) < 0.01)
        #expect(model.lines[1].mapLabel == "Moonset 301°")
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

    @Test("Follow me is on by default whenever location is allowed", arguments: [true, false])
    func followMeDefault(canFollow: Bool) {
        let model = Self.makeViewModel(canFollowUser: canFollow)
        #expect(model.canFollowUser == canFollow)
        #expect(model.startsFollowingUser == canFollow)
    }

    @Test("Following you far from the place sends the map back to the place, once")
    func farFromPlace() {
        let model = Self.makeViewModel()
        let sydney = BearingLine.Coordinate(latitude: -33.87, longitude: 151.21)
        model.cameraChanged(center: sydney, heading: 0, distance: 6_000, followsHeading: true)
        #expect(model.returnToPlaceCount == 1)

        // A later, deliberate Follow me there is left alone.
        model.cameraChanged(center: sydney, heading: 0, distance: 6_000, followsHeading: true)
        #expect(model.returnToPlaceCount == 1)
    }

    @Test("A zoomed-out camera while MapKit finds you doesn't count as far away")
    func zoomedOutDoesNotReturn() {
        let model = Self.makeViewModel()
        let middleOfNowhere = BearingLine.Coordinate(latitude: 39, longitude: -98)
        model.cameraChanged(center: middleOfNowhere, heading: 0, distance: 5_000_000, followsHeading: true)
        #expect(model.returnToPlaceCount == 0)
        // Found you, nearby: still following.
        let beach = BearingLine.Coordinate(latitude: 33.59, longitude: -117.87)
        model.cameraChanged(center: beach, heading: 0, distance: 1_500, followsHeading: true)
        #expect(model.returnToPlaceCount == 0)
    }

    @Test("Following you near the place stays put")
    func nearPlace() {
        let model = Self.makeViewModel()
        let beach = BearingLine.Coordinate(latitude: 33.59, longitude: -117.87)
        model.cameraChanged(center: beach, heading: 0, distance: 6_000, followsHeading: true)
        #expect(model.returnToPlaceCount == 0)
    }

    // MARK: - Lock and turn hints

    /// Good accuracy, well under the compass's 20° exit from low accuracy.
    private static let goodAccuracy = 5.0

    /// The phone points at `heading`.
    private static func turn(_ model: MoonMapViewModel, to heading: Double) {
        model.headingChanged(HeadingReading(trueHeading: heading, accuracy: goodAccuracy))
    }

    @Test("Pointing along a line locks it, once per acquisition, with the compass's ±5° / ±8°")
    func lock() {
        let model = Self.makeViewModel()
        Self.turn(model, to: 40)
        #expect(model.locked == nil)
        #expect(model.lockAcquisitionCount == 0)

        Self.turn(model, to: 55)
        #expect(model.locked == .rise)
        #expect(model.lockAcquisitionCount == 1)
        #expect(model.lines[0].isLocked)
        #expect(!model.lines[1].isLocked)

        Self.turn(model, to: 51)
        #expect(model.locked == .rise)
        #expect(model.lockAcquisitionCount == 1)

        Self.turn(model, to: 49)
        #expect(model.locked == nil)

        Self.turn(model, to: 300)
        #expect(model.locked == .set)
        #expect(model.lockAcquisitionCount == 2)
    }

    @Test("No lock or hints with turning off; they come back when it's on")
    func noLockWithoutTurning() {
        let model = Self.makeViewModel()
        model.turnsWithPhone = false
        Self.turn(model, to: 58)
        #expect(model.heading == nil)
        #expect(model.locked == nil)
        #expect(model.lines.allSatisfy { $0.turnHint == nil })

        model.turnsWithPhone = true
        #expect(model.heading == 58)
        #expect(model.locked == .rise)
    }

    @Test("Turning is on by default only with location", arguments: [true, false])
    func turningDefault(canFollow: Bool) {
        #expect(Self.makeViewModel(canFollowUser: canFollow).turnsWithPhone == canFollow)
    }

    @Test("No lock in low accuracy, as on the compass")
    func lowAccuracy() {
        let model = Self.makeViewModel()
        model.headingChanged(HeadingReading(trueHeading: 58, accuracy: 40))
        #expect(model.locked == nil)
        Self.turn(model, to: 58)
        #expect(model.locked == .rise)
    }

    // MARK: - Turning at a chosen spot (MAP.md §3.10)

    @Test("Away from your location the map is turned for you, in 3° steps")
    func turnsCameraAtSpot() {
        let model = Self.makeViewModel()
        model.cameraChanged(center: model.pin, heading: 0, distance: 6_000, followsHeading: false)
        Self.turn(model, to: 40)
        #expect(model.cameraHeadingRequest == 40)
        Self.turn(model, to: 42)
        #expect(model.cameraHeadingRequest == 40)
        Self.turn(model, to: 43.5)
        #expect(model.cameraHeadingRequest == 43.5)
        #expect(model.locked == nil)
    }

    @Test("The shown heading changes only by whole degrees; the lock still sees every reading")
    func headingThrottle() {
        let model = Self.makeViewModel()
        Self.turn(model, to: 40.1)
        #expect(model.heading == 40.1)
        Self.turn(model, to: 40.3)
        #expect(model.heading == 40.1)
        Self.turn(model, to: 41.2)
        #expect(model.heading == 41.2)
        Self.turn(model, to: 53.2)
        #expect(model.locked == .rise)
    }

    @Test("While following you MapKit turns the map; locking still works")
    func followingLeavesCameraToMapKit() {
        let model = Self.makeViewModel()
        model.cameraChanged(center: model.pin, heading: 0, distance: 6_000, followsHeading: true)
        Self.turn(model, to: 58)
        #expect(model.cameraHeadingRequest == nil)
        #expect(model.locked == .rise)
    }

    @Test("Dragging off your location keeps turning and locking at the new spot")
    func dragKeepsTurning() {
        let model = Self.makeViewModel()
        model.cameraChanged(center: model.pin, heading: 0, distance: 6_000, followsHeading: true)
        Self.turn(model, to: 58)
        let beach = BearingLine.Coordinate(latitude: 33.59, longitude: -117.87)
        model.cameraChanged(center: beach, heading: 58, distance: 6_000, followsHeading: false)
        #expect(model.pin == beach)
        #expect(model.cameraHeadingRequest == 58)
        #expect(model.locked == .rise)
        #expect(model.lines.allSatisfy { $0.bearingLine.start == beach })
    }

    @Test("A tap moves the pin; looking along, it re-aims from there")
    func tapToStand() throws {
        let model = Self.makeViewModel()
        let spot = BearingLine.Coordinate(latitude: 33.62, longitude: -117.93)
        #expect(model.standHere(spot) == nil)
        #expect(model.pin == spot)

        model.style = .threeD
        _ = model.lookAlong()
        let other = BearingLine.Coordinate(latitude: 33.65, longitude: -117.90)
        let request = try #require(model.standHere(other))
        #expect(model.pin == other)
        #expect(request.heading == 58)
    }

    @Test("Looking along pauses turning and the lock")
    func lookAlongPausesTurning() {
        let model = Self.makeViewModel()
        Self.turn(model, to: 58)
        #expect(model.locked == .rise)
        model.style = .threeD
        _ = model.lookAlong()
        #expect(model.locked == nil)
        #expect(model.heading == nil)
        model.stopLookingAlong()
        #expect(model.locked == .rise)
    }

    @Test("Turn hints say which way and how far, the short way round", arguments: [
        (35.0, "Turn 23° right", "Turn 94° left"),
        (80.0, "Turn 22° left", "Turn 139° left"),
        (350.0, "Turn 68° right", "Turn 49° left")
    ])
    func turnHints(heading: Double, rise: String, set: String) {
        let model = Self.makeViewModel()
        Self.turn(model, to: heading)
        #expect(model.lines.map(\.turnHint) == [rise, set])
    }

    @Test("A locked line says you're facing it, in words for VoiceOver too")
    func facingIt() {
        let model = Self.makeViewModel()
        Self.turn(model, to: 58)
        #expect(model.lines[0].turnHint == "Facing it")
        #expect(model.lines[0].accessibilityLabel.hasSuffix("You're facing it."))
    }

    // MARK: - Look along the line (6.3)

    @Test("Look along is offered only in 3D")
    func lookAlongNeeds3D() {
        let model = Self.makeViewModel()
        #expect(!model.canLookAlong)
        #expect(model.lookAlong() == nil)
        #expect(model.lookingAlong == nil)
        model.style = .threeD
        #expect(model.canLookAlong)
    }

    @Test("The camera faces the selected line, looking at a point ahead along it")
    func lookAlongCamera() throws {
        let model = Self.makeViewModel(selected: .set)
        model.style = .threeD
        let request = try #require(model.lookAlong())
        #expect(model.lookingAlong == .set)
        #expect(request.heading == 301)
        #expect(request.pitch == MoonMapViewModel.lookAlongPitch)
        #expect(request.distance == MoonMapViewModel.lookAlongDistance)
        let ahead = MoonMapViewModel.lookAlongDistance * sin(MoonMapViewModel.lookAlongPitch * .pi / 180)
        let expected = BearingLine.destination(from: model.pin, bearing: 301, distance: ahead)
        #expect(abs(request.center.latitude - expected.latitude) < 1e-9)
        #expect(abs(request.center.longitude - expected.longitude) < 1e-9)
    }

    @Test("While looking along, the pin is the ground under the camera, so dragging moves it")
    func lookAlongPinFollowsEye() {
        let model = Self.makeViewModel()
        model.style = .threeD
        _ = model.lookAlong()
        let center = BearingLine.Coordinate(latitude: 33.70, longitude: -117.80)
        model.cameraChanged(center: center, heading: 58, distance: 250, pitch: 80, followsHeading: false)

        let back = 250 * sin(80 * Double.pi / 180)
        let expected = BearingLine.destination(from: center, bearing: 238, distance: back)
        #expect(abs(model.pin.latitude - expected.latitude) < 1e-9)
        #expect(abs(model.pin.longitude - expected.longitude) < 1e-9)
        #expect(abs((model.eyeHeight ?? 0) - 250 * cos(80 * Double.pi / 180)) < 1e-9)
        #expect(model.locked == nil)
        #expect(model.lines.allSatisfy { $0.bearingLine.start == model.pin })
    }

    @Test("The note gives the eye height in the locale's road units")
    func lookAlongNote() {
        let model = Self.makeViewModel()
        #expect(model.lookAlongNote == nil)
        model.style = .threeD
        _ = model.lookAlong()
        model.cameraChanged(center: model.pin, heading: 58, distance: 250, pitch: 60, followsHeading: false)
        let note = model.lookAlongNote ?? ""
        #expect(note.hasPrefix("Seen from about "))
        #expect(note.contains("ft"))
        #expect(note.hasSuffix(" up · drag to move"))
        _ = model.stopLookingAlong()
        #expect(model.lookAlongNote == nil)
    }

    @Test("Stopping goes back over the pin, still tilted for 3D")
    func stopLookingAlong() {
        let model = Self.makeViewModel()
        model.style = .threeD
        _ = model.lookAlong()
        let request = model.stopLookingAlong()
        #expect(model.lookingAlong == nil)
        #expect(request.center == model.pin)
        #expect(request.pitch == MoonMapViewModel.threeDPitch)
    }

    @Test("The 3D overview points at the binoculars; looking along, it doesn't")
    func threeDHint() {
        let model = Self.makeViewModel(selected: .set)
        #expect(model.threeDHint == nil)
        model.style = .threeD
        #expect(model.threeDHint == "Tap the binoculars to look along the moonset line")
        _ = model.lookAlong()
        #expect(model.threeDHint == nil)
    }

    @Test("Leaving 3D ends looking along")
    func leaving3DStops() {
        let model = Self.makeViewModel()
        model.style = .threeD
        _ = model.lookAlong()
        model.style = .satellite
        #expect(model.lookingAlong == nil)
        #expect(!model.canLookAlong)
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
