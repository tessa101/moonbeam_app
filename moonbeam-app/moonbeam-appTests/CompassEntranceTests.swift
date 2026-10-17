//
//  CompassEntranceTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// LOADER.md §12.4 and §12.4.1 (STEP-5.10a.3): the compass entrance's rules,
/// its phases in `CompassViewModel`, the readout's fade, and one test per
/// reload trigger proving it goes through the same entrance.
///
/// The entrance's waits come from `EntranceSleeper`, fired by hand; the
/// trigger tests through `LocationViewModel` only check the entrance each
/// trigger begins, so its real 0.5 s waits never matter.
@Suite("Compass entrance", .timeLimit(.minutes(1)))
@MainActor
struct CompassEntranceTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private static let detectedLosAngeles = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: losAngelesZone,
        isCurrentLocation: true
    )

    private static let searchedLosAngeles = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.05,
        longitude: -118.24,
        timeZone: losAngelesZone
    )

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    private static let riseAzimuth = 72.0
    private static let setAzimuth = 288.0
    private static let moonAzimuth = 140.0
    private static let goodAccuracy = 3.0
    private static let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)
    private static let maxYields = 100
    private static let degreeTolerance = 1e-9
    private static let fullTurn = 360.0
    private static let awaitingHeading: [CompassEntrance.Phase] = [.waitingForHeading, .noHeading]

    /// 2026-09-26 20:00 PDT, as `LocationViewModelCompassTests`.
    private static let locationReferenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        let components = DateComponents(year: 2026, month: 9, day: 26, hour: 20)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    private static func moonDay(rise: Double = riseAzimuth) -> MoonDay {
        MoonDay(
            place: detectedLosAngeles,
            rise: MoonEvent(date: referenceDate, azimuth: rise),
            set: MoonEvent(date: referenceDate, azimuth: setAzimuth),
            phase: .full,
            phaseAngle: FakeMoonService.fullMoonPhaseAngle,
            illumination: FakeMoonService.fullyLit
        )
    }

    private static func context(
        place: Place? = detectedLosAngeles,
        moonDay: MoonDay = moonDay(),
        isToday: Bool = true
    ) -> CompassContext {
        CompassContext(
            place: place,
            detectedPlace: detectedLosAngeles,
            authState: .authorized,
            moonDay: moonDay,
            isToday: isToday
        )
    }

    private static func reading(_ heading: Double) -> HeadingReading {
        HeadingReading(trueHeading: heading, accuracy: goodAccuracy)
    }

    /// The entrance's waits, ended by hand.
    @MainActor
    private final class EntranceSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []
        private(set) var requestedDurations: [Duration] = []

        /// A wait has started: `fire()` now ends it (not before its task runs).
        var isWaiting: Bool { !waiters.isEmpty }

        func sleep(_ duration: Duration) async throws {
            requestedDurations.append(duration)
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        /// Ends every pending wait, as if it had passed. Waits whose task
        /// was superseded return and do nothing.
        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }

        func cancelAll() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume(throwing: CancellationError()) }
        }
    }

    private struct Harness {
        let viewModel: CompassViewModel
        let heading: FakeHeadingService
        let entrance: EntranceSleeper
    }

    private static func makeHarness(reducesMotion: Bool = false) -> Harness {
        let heading = FakeHeadingService()
        let entrance = EntranceSleeper()
        let viewModel = CompassViewModel(
            headingService: heading,
            moonService: FakeMoonService(position: MoonPosition(azimuth: moonAzimuth, altitude: 23, isUp: true)),
            now: { referenceDate },
            // The 30 s moon tick never comes during a test.
            sleep: { _ in try await Task.sleep(for: .seconds(3_600)) },
            entranceSleep: { [entrance] duration in try await entrance.sleep(duration) },
            reducesMotion: { reducesMotion }
        )
        return Harness(viewModel: viewModel, heading: heading, entrance: entrance)
    }

    /// Shown and on screen: the sensors are running, the entrance waiting.
    private static func makeRunningHarness(reducesMotion: Bool = false) -> Harness {
        let harness = makeHarness(reducesMotion: reducesMotion)
        harness.viewModel.update(context())
        harness.viewModel.setOnScreen(true)
        return harness
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<Self.maxYields where !condition() {
            await Task.yield()
        }
    }

    /// Heading delivered, settle waited out: the compass is live.
    private func settle(_ harness: Harness, at heading: Double) async {
        // The heading wait first, so the next request is the settle's own.
        // Both waits are 0.5 s, and the superseded heading wait stays
        // pending, so neither `isWaiting` nor the duration tells them apart.
        await waitUntil { harness.entrance.isWaiting }
        let requestsBefore = harness.entrance.requestedDurations.count
        harness.heading.send(Self.reading(heading))
        await waitUntil { harness.viewModel.heading == heading }
        await waitUntil { harness.entrance.requestedDurations.count > requestsBefore }
        harness.entrance.fire()
        await waitUntil { harness.viewModel.entrance.phase == .settled }
    }

    // MARK: - Rules

    @Test("Shortest turn across 0/360: 350° → 10° turns 20°, not 340°")
    func shortestTurnAcrossNorth() {
        #expect(CompassEntrance.shortestTurn(from: 350, to: 10) == 20)
        #expect(CompassEntrance.shortestTurn(from: 10, to: 350) == -20)
        #expect(CompassEntrance.shortestTurn(from: 0, to: 180) == 180)
        #expect(CompassEntrance.shortestTurn(from: 90, to: 90) == 0)
    }

    @Test("From north-up, the turn starts at 0° and goes the short way", arguments: [10.0, 185.0, 190.0, 350.0])
    func turnFromNorthUp(heading: Double) {
        let offset = CompassEntrance.turnOffset(fromNorthUpTo: heading)
        #expect(abs(offset) <= Self.fullTurn / 2)
        let start = (heading + offset).truncatingRemainder(dividingBy: Self.fullTurn)
        #expect(abs(start) < Self.degreeTolerance || abs(start - Self.fullTurn) < Self.degreeTolerance)
    }

    @Test("Settle offset is ~10° against the last heading change")
    func settleOffsetDirection() {
        #expect(CompassEntrance.settleOffset(lastHeadingChange: nil) == CompassEntrance.settleOffsetDegrees)
        #expect(CompassEntrance.settleOffset(lastHeadingChange: 5) == -CompassEntrance.settleOffsetDegrees)
        #expect(CompassEntrance.settleOffset(lastHeadingChange: -5) == CompassEntrance.settleOffsetDegrees)
    }

    // MARK: - Phases

    @Test("Waits for the first heading, out of sight, readout held")
    func waitsForHeading() async {
        let harness = Self.makeRunningHarness()
        await waitUntil { harness.entrance.isWaiting }

        #expect(harness.viewModel.entrance.phase == .waitingForHeading)
        #expect(!harness.viewModel.entrance.showsCompass)
        #expect(harness.viewModel.readoutOpacity == 0)
        #expect(harness.entrance.requestedDurations == [CompassEntrance.headingWait])
        harness.entrance.cancelAll()
    }

    @Test("First heading: in ~10° off, settles, then the readout shows the heading it landed on")
    func settlesIntoFirstHeading() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(Self.reading(179))
        await waitUntil { harness.viewModel.entrance.phase == .settling }
        #expect(harness.viewModel.entrance.showsCompass)
        #expect(harness.viewModel.entrance.startOffset == CompassEntrance.settleOffsetDegrees)
        #expect(harness.viewModel.readoutOpacity == 0)

        // The magnetometer settling during the entrance: never shown.
        for heading in [185.0, 190.0] {
            harness.heading.send(Self.reading(heading))
            await waitUntil { harness.viewModel.heading == heading }
            #expect(harness.viewModel.readoutOpacity == 0)
        }

        harness.entrance.fire()
        await waitUntil { harness.viewModel.entrance.phase == .settled }
        #expect(harness.viewModel.readoutOpacity == 1)
        #expect(harness.viewModel.headingReadout?.lead == "190°")
        #expect(harness.entrance.requestedDurations.last == CompassEntrance.settleDuration)
        harness.entrance.cancelAll()
    }

    @Test("Late heading: no-heading look after 0.5 s, then a short-way turn from north-up")
    func lateHeadingTurnsFromNorthUp() async {
        let harness = Self.makeRunningHarness()

        await waitUntil { harness.entrance.isWaiting }
        harness.entrance.fire()
        await waitUntil { harness.viewModel.entrance.phase == .noHeading }
        #expect(harness.viewModel.entrance.showsCompass)
        #expect(harness.viewModel.heading == nil)

        harness.heading.send(Self.reading(350))
        await waitUntil { harness.viewModel.entrance.phase == .settling }
        #expect(harness.viewModel.entrance.startOffset == CompassEntrance.turnOffset(fromNorthUpTo: 350))
        #expect(harness.viewModel.entrance.startOffset == 10)
        harness.entrance.cancelAll()
    }

    @Test("An unavailable reading doesn't end the wait")
    func unavailableKeepsWaiting() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(.unavailable)
        await waitUntil { harness.viewModel.reading != nil }
        #expect(harness.viewModel.entrance.phase == .waitingForHeading)
        harness.entrance.cancelAll()
    }

    @Test("Reduce Motion: in already aligned, no settle, readout at once")
    func reduceMotionNoSettle() async {
        let harness = Self.makeRunningHarness(reducesMotion: true)
        #expect(!harness.viewModel.entrance.showsCompass)

        harness.heading.send(Self.reading(185))
        await waitUntil { harness.viewModel.entrance.phase == .settled }
        #expect(harness.viewModel.entrance.startOffset == 0)
        #expect(harness.viewModel.entrance.showsCompass)
        #expect(harness.viewModel.readoutOpacity == 1)
        harness.entrance.cancelAll()
    }

    @Test("The settle's direction comes from the last heading change, kept across sessions")
    func settleAgainstLastChange() async {
        let harness = Self.makeRunningHarness()
        await settle(harness, at: 100)
        harness.heading.send(Self.reading(105))
        await waitUntil { harness.viewModel.heading == 105 }

        harness.viewModel.setOnScreen(false)
        harness.viewModel.setOnScreen(true)
        harness.heading.send(Self.reading(105))
        await waitUntil { harness.viewModel.entrance.phase == .settling }
        #expect(harness.viewModel.entrance.startOffset == -CompassEntrance.settleOffsetDegrees)
        harness.entrance.cancelAll()
    }

    // MARK: - §12.4.1 readout

    @Test("Readout: opacity 0 while locked, 1 otherwise")
    func readoutFadesWhileLocked() async {
        let harness = Self.makeRunningHarness()
        await settle(harness, at: Self.riseAzimuth + 90)
        #expect(harness.viewModel.readoutOpacity == 1)

        harness.heading.send(Self.reading(Self.riseAzimuth))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }
        #expect(harness.viewModel.readoutOpacity == 0)
        #expect(harness.viewModel.lockReadout != nil)

        harness.heading.send(Self.reading(Self.riseAzimuth + 90))
        await waitUntil { harness.viewModel.lockedKind == nil }
        #expect(harness.viewModel.readoutOpacity == 1)
        harness.entrance.cancelAll()
    }

    // MARK: - Triggers, compass level

    @Test("Repeated date steps update markers in place without restarting a settled compass")
    func dateStepsKeepSettledCompassSteady() async throws {
        let harness = Self.makeRunningHarness()
        await settle(harness, at: 185)
        let entrance = harness.viewModel.entrance
        let starts = harness.heading.startCount
        let stops = harness.heading.stopCount

        harness.viewModel.update(Self.context(
            moonDay: Self.moonDay(rise: Self.riseAzimuth + 3),
            isToday: false
        ))

        #expect(harness.viewModel.entrance == entrance)
        #expect(harness.viewModel.heading == 185)
        #expect(harness.viewModel.readoutOpacity == 1)
        #expect(try #require(harness.viewModel.targets.first { $0.kind == .moonrise }).azimuth == Self.riseAzimuth + 3)
        #expect(!harness.viewModel.targets.map(\.kind).contains(.moon))

        harness.viewModel.update(Self.context(
            moonDay: Self.moonDay(rise: Self.riseAzimuth - 4),
            isToday: true
        ))

        #expect(harness.viewModel.entrance == entrance)
        #expect(harness.viewModel.heading == 185)
        #expect(try #require(harness.viewModel.targets.first { $0.kind == .moonrise }).azimuth == Self.riseAzimuth - 4)
        #expect(harness.viewModel.targets.map(\.kind).contains(.moon))
        #expect(harness.heading.startCount == starts)
        #expect(harness.heading.stopCount == stops)
        harness.entrance.cancelAll()
    }

    @Test("A refresh with the same place and day isn't a reload")
    func sameContextNoEntrance() async {
        let harness = Self.makeRunningHarness()
        await settle(harness, at: 185)
        let before = harness.viewModel.entrance

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.entrance == before)
        harness.entrance.cancelAll()
    }

    @Test("Back on screen: a new entrance, waiting for a fresh heading")
    func backOnScreenBeginsEntrance() async {
        let harness = Self.makeRunningHarness()
        await settle(harness, at: 185)
        let before = harness.viewModel.entrance.generation

        harness.viewModel.setOnScreen(false)
        harness.viewModel.setOnScreen(true)

        #expect(harness.viewModel.entrance.generation == before + 1)
        #expect(harness.viewModel.entrance.phase == .waitingForHeading)
        harness.entrance.cancelAll()
    }

    // MARK: - Triggers, end to end

    private struct LocationHarness {
        let viewModel: LocationViewModel
        let location: FakeLocationService
        let heading: FakeHeadingService
    }

    private static func makeLocationHarness(
        detected: Place? = detectedLosAngeles,
        store: InMemoryPlaceStore = InMemoryPlaceStore()
    ) -> LocationHarness {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: detected.map { .success($0) } ?? .failure(LocationError.locationUnavailable)
        )
        let heading = FakeHeadingService()
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: store,
            moonService: AstronomyEngineMoonService(),
            headingService: heading,
            deviceTimeZone: losAngelesZone,
            now: { locationReferenceDate }
        )
        return LocationHarness(viewModel: viewModel, location: location, heading: heading)
    }

    /// Launched at the detected place, compass on screen, heading in hand.
    private func launchedWithHeading() async -> LocationHarness {
        let harness = Self.makeLocationHarness()
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)
        harness.heading.send(Self.reading(185))
        await waitUntil { harness.viewModel.compass.heading == 185 }
        return harness
    }

    @Test("Launch: the entrance waits for the first heading, then settles")
    func launchBeginsEntrance() async {
        let harness = Self.makeLocationHarness()
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)

        #expect(harness.viewModel.compass.entrance.generation == 1)
        #expect(harness.viewModel.compass.entrance.phase == .waitingForHeading)

        harness.heading.send(Self.reading(185))
        await waitUntil { harness.viewModel.compass.entrance.phase == .settling }
        #expect(harness.viewModel.compass.entrance.phase == .settling)
    }

    @Test("Place change, a picked city: a new entrance, settling")
    func pickedCityBeginsEntrance() async {
        let harness = await launchedWithHeading()
        let before = harness.viewModel.compass.entrance.generation

        harness.viewModel.select(Self.searchedLosAngeles)

        #expect(harness.viewModel.compass.entrance.generation == before + 1)
        #expect(harness.viewModel.compass.entrance.phase == .settling)
    }

    @Test("Place change, Use my location: the compass comes back through the entrance")
    func useMyLocationBeginsEntrance() async {
        let harness = await launchedWithHeading()
        harness.viewModel.select(Self.sydney)
        #expect(harness.viewModel.compass.visibility == .far)
        let before = harness.viewModel.compass.entrance.generation

        await harness.viewModel.useMyLocation()

        #expect(harness.viewModel.compass.visibility == .here)
        #expect(harness.viewModel.compass.entrance.generation == before + 1)
        // The Aha after the fix runs on real time, so the 0.5 s wait may be
        // over: either way, no heading yet and nothing settled.
        #expect(Self.awaitingHeading.contains(harness.viewModel.compass.entrance.phase))
    }

    @Test("Date step through LocationViewModel keeps the settled compass entrance")
    func dateStepEndToEndKeepsEntrance() async {
        let harness = await launchedWithHeading()
        let before = harness.viewModel.compass.entrance

        harness.viewModel.nextDay()

        #expect(harness.viewModel.compass.entrance == before)
        #expect(harness.viewModel.compass.heading == 185)

        harness.viewModel.previousDay()

        #expect(harness.viewModel.compass.entrance == before)
        #expect(harness.viewModel.compass.heading == 185)
    }

    @Test("Return to the foreground: a new entrance, waiting for a heading")
    func foregroundBeginsEntrance() async {
        let harness = await launchedWithHeading()
        let before = harness.viewModel.compass.entrance.generation

        harness.viewModel.sceneDidEnterBackground()
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.compass.entrance.generation == before + 1)
        #expect(harness.viewModel.compass.entrance.phase == .waitingForHeading)
    }

    @Test("Location arriving late: the compass appears through the entrance")
    func lateLocationBeginsEntrance() async {
        let harness = Self.makeLocationHarness(
            detected: nil,
            store: InMemoryPlaceStore(lastViewed: Self.searchedLosAngeles)
        )
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)
        #expect(harness.viewModel.compass.visibility == .hidden)
        let before = harness.viewModel.compass.entrance.generation

        harness.location.placeResult = .success(Self.detectedLosAngeles)
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.compass.visibility == .here)
        #expect(harness.viewModel.compass.entrance.generation == before + 1)
        #expect(harness.viewModel.compass.entrance.phase == .waitingForHeading)
    }

    @Test("Recovery from a failure screen: the compass comes in through the entrance")
    func failureRecoveryBeginsEntrance() async {
        let harness = Self.makeLocationHarness(detected: nil)
        await harness.viewModel.start()
        #expect(harness.viewModel.failureScreen != nil)
        harness.viewModel.compass.setOnScreen(true)
        let before = harness.viewModel.compass.entrance.generation

        harness.location.placeResult = .success(Self.detectedLosAngeles)
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.place == Self.detectedLosAngeles)
        #expect(harness.viewModel.compass.entrance.generation == before + 1)
        // The Aha after the fix runs on real time, so the 0.5 s wait may be
        // over: either way, no heading yet and nothing settled.
        #expect(Self.awaitingHeading.contains(harness.viewModel.compass.entrance.phase))
    }
}
