//
//  CompassViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `CompassViewModel` against fakes (COMPASS.md §6): the §2 visibility
/// matrix, targets from the selected day, the live "Moon" target and its
/// 30 s refresh, lock through real readings, and the sensor lifecycle.
///
/// The heading comes from `FakeHeadingService` (the simulator has no
/// compass), the moon's position from `FakeMoonService.position`, and the
/// 30 s wait from `ManualSleeper`, which the test fires by hand.
@Suite("Compass view model")
@MainActor
struct CompassViewModelTests {

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

    /// The same city picked from search: same names, slightly different
    /// coordinates, not marked as the current location.
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

    private static let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)

    private static let goodAccuracy = 3.0

    /// Main-actor turns to wait for a stream or task hop to land; it's one
    /// or two in practice. Only here so a broken implementation can't hang.
    private static let maxYields = 100

    private static func moonDay(
        for place: Place = detectedLosAngeles,
        rise: Double? = riseAzimuth,
        set: Double? = setAzimuth
    ) -> MoonDay {
        MoonDay(
            place: place,
            rise: rise.map { MoonEvent(date: referenceDate, azimuth: $0) },
            set: set.map { MoonEvent(date: referenceDate, azimuth: $0) },
            phase: .full,
            phaseAngle: FakeMoonService.fullMoonPhaseAngle,
            illumination: FakeMoonService.fullyLit
        )
    }

    private static func context(
        place: Place? = detectedLosAngeles,
        detected: Place? = detectedLosAngeles,
        auth: LocationAuthState = .authorized,
        moonDay: MoonDay? = moonDay(),
        isToday: Bool = true
    ) -> CompassContext {
        CompassContext(
            place: place,
            detectedPlace: detected,
            authState: auth,
            moonDay: moonDay,
            isToday: isToday
        )
    }

    private static func reading(_ heading: Double, accuracy: Double = goodAccuracy) -> HeadingReading {
        HeadingReading(trueHeading: heading, accuracy: accuracy)
    }

    private static let moonDown = MoonPosition(azimuth: moonAzimuth, isUp: false)
    private static let moonUp = MoonPosition(azimuth: moonAzimuth, isUp: true)

    /// A stand-in for `Task.sleep` that the test fires by hand, so the 30 s
    /// refresh can be ticked without waiting.
    @MainActor
    private final class ManualSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []
        private(set) var requestedDurations: [Duration] = []

        var pendingCount: Int { waiters.count }

        func sleep(_ duration: Duration) async throws {
            requestedDurations.append(duration)
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        /// Ends every pending sleep, as if the interval had passed.
        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }

        /// Ends pending sleeps with cancellation, so nothing leaks.
        func cancelAll() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume(throwing: CancellationError()) }
        }
    }

    private struct Harness {
        let viewModel: CompassViewModel
        let heading: FakeHeadingService
        let moon: FakeMoonService
        let sleeper: ManualSleeper
    }

    private static func makeHarness(position: MoonPosition = moonDown) -> Harness {
        let heading = FakeHeadingService()
        let moon = FakeMoonService(position: position)
        let sleeper = ManualSleeper()
        let viewModel = CompassViewModel(
            headingService: heading,
            moonService: moon,
            now: { referenceDate },
            sleep: { [sleeper] duration in try await sleeper.sleep(duration) }
        )
        return Harness(viewModel: viewModel, heading: heading, moon: moon, sleeper: sleeper)
    }

    /// Shown, on screen and in the foreground: the sensors are running.
    private static func makeRunningHarness(position: MoonPosition = moonDown) -> Harness {
        let harness = makeHarness(position: position)
        harness.viewModel.update(context())
        harness.viewModel.setOnScreen(true)
        return harness
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<Self.maxYields where !condition() {
            await Task.yield()
        }
    }

    // MARK: - Visibility (§2)

    @Test("Detected location: Here")
    func visibleAtDetectedLocation() {
        #expect(CompassViewModel.visibility(for: Self.context()) == .here)
    }

    @Test("Searched city matching the detected city: Here")
    func visibleAtSameCity() {
        let context = Self.context(place: Self.searchedLosAngeles)

        #expect(CompassViewModel.visibility(for: context) == .here)
    }

    @Test("A city on another continent: Far")
    func farForOtherContinent() {
        let context = Self.context(place: Self.sydney)

        #expect(CompassViewModel.visibility(for: context) == .far)
    }

    // MARK: - Proximity (§2, 4.6)

    /// ~30 mi from the detected location.
    private static let huntingtonBeach = Place(
        name: "Huntington Beach",
        region: "CA",
        country: "United States",
        latitude: 33.66,
        longitude: -118.00,
        timeZone: losAngelesZone
    )

    /// ~110 mi from the detected location.
    private static let sanDiego = Place(
        name: "San Diego",
        region: "CA",
        country: "United States",
        latitude: 32.72,
        longitude: -117.16,
        timeZone: losAngelesZone
    )

    /// Due north of the detected location by `degrees` of latitude:
    /// 0.868° is ~96.52 km (inside 96.56 km), 0.869° ~96.63 km (outside).
    private static func northOfDetected(byDegrees degrees: Double) -> Place {
        Place(
            name: "Test Town",
            region: "CA",
            country: "United States",
            latitude: detectedLosAngeles.latitude + degrees,
            longitude: detectedLosAngeles.longitude,
            timeZone: losAngelesZone
        )
    }

    @Test("Huntington Beach from LA: Nearby; San Diego from LA: Far")
    func referenceCities() {
        #expect(CompassViewModel.visibility(for: Self.context(place: Self.huntingtonBeach)) == .nearby)
        #expect(CompassViewModel.visibility(for: Self.context(place: Self.sanDiego)) == .far)
    }

    @Test("60 mi boundary: just inside is Nearby, just outside is Far")
    func sixtyMileBoundary() {
        let inside = Self.northOfDetected(byDegrees: 0.868)
        let outside = Self.northOfDetected(byDegrees: 0.869)

        #expect(inside.distanceMeters(to: Self.detectedLosAngeles) < CompassViewModel.nearbyRadiusMeters)
        #expect(outside.distanceMeters(to: Self.detectedLosAngeles) > CompassViewModel.nearbyRadiusMeters)
        #expect(CompassViewModel.visibility(for: Self.context(place: inside)) == .nearby)
        #expect(CompassViewModel.visibility(for: Self.context(place: outside)) == .far)
    }

    @Test("The radius is 60 miles")
    func radiusIsSixtyMiles() {
        #expect(abs(CompassViewModel.nearbyRadiusMeters - 96_560.64) < 0.01)
    }

    @Test("Nearby: compass shown, with a note naming the city and no distance")
    func nearbyNote() throws {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.huntingtonBeach))
        harness.viewModel.setOnScreen(true)

        let note = try #require(harness.viewModel.nearbyNote)
        #expect(note == "Directions for Huntington Beach")
        #expect(note.rangeOfCharacter(from: .decimalDigits) == nil)
        #expect(!note.contains("mi") && !note.contains("km"))
        #expect(harness.heading.isRunning)
        #expect(!harness.viewModel.targets.isEmpty)
    }

    @Test("Here has no note")
    func hereHasNoNote() {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.searchedLosAngeles))

        #expect(harness.viewModel.nearbyNote == nil)
    }

    @Test("Far: no compass, no targets, sensors off, and the Far message has no distance")
    func farHidesCompass() {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.viewModel.update(Self.context(place: Self.sanDiego))
        harness.viewModel.setOnScreen(true)

        #expect(!harness.viewModel.visibility.showsCompass)
        #expect(harness.viewModel.targets.isEmpty)
        #expect(harness.viewModel.nearbyNote == nil)
        #expect(!harness.heading.isRunning)
        #expect(CompassViewModel.farMessage.rangeOfCharacter(from: .decimalDigits) == nil)
    }

    @Test("Moving between two Nearby cities updates the note")
    func nearbyToNearbyUpdatesNote() {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.huntingtonBeach))

        harness.viewModel.update(Self.context(place: Self.northOfDetected(byDegrees: 0.5)))

        #expect(harness.viewModel.nearbyNote == "Directions for Test Town")
    }

    /// Location is on but detection hasn't found you (yet, or it failed):
    /// nothing proves you're in the searched city.
    @Test("Searched city with nothing detected: hidden")
    func hiddenWithNoDetectedPlace() {
        let context = Self.context(place: Self.searchedLosAngeles, detected: nil)

        #expect(CompassViewModel.visibility(for: context) == .hidden)
    }

    @Test(
        "Location off, denied or not determined: the enable-location hint",
        arguments: [LocationAuthState.notDetermined, .denied, .restricted, .servicesOff]
    )
    func hintWhenNotAuthorized(auth: LocationAuthState) {
        let detectedPlace = Self.context(auth: auth)
        let otherCity = Self.context(place: Self.sydney, auth: auth)

        #expect(CompassViewModel.visibility(for: detectedPlace) == .locationOff)
        #expect(CompassViewModel.visibility(for: otherCity) == .locationOff)
    }

    @Test("No place yet: hidden, even with location off")
    func hiddenWithNoPlace() {
        #expect(CompassViewModel.visibility(for: Self.context(place: nil)) == .hidden)
        #expect(CompassViewModel.visibility(for: Self.context(place: nil, auth: .denied)) == .hidden)
    }

    @Test("Before any context arrives: hidden")
    func hiddenInitially() {
        #expect(Self.makeHarness().viewModel.visibility == .hidden)
    }

    // MARK: - Targets

    @Test("Not today: moonrise and moonset only, and the moon isn't asked for")
    func notTodayHasNoMoon() {
        let harness = Self.makeHarness(position: Self.moonUp)

        harness.viewModel.update(Self.context(isToday: false))

        #expect(harness.viewModel.targets == [
            CompassTarget(kind: .moonrise, azimuth: Self.riseAzimuth),
            CompassTarget(kind: .moonset, azimuth: Self.setAzimuth),
        ])
        #expect(harness.moon.requestedPositionDates.isEmpty)
    }

    @Test("Today with the moon up: moonrise, moonset and the moon")
    func todayWithMoonUp() {
        let harness = Self.makeHarness(position: Self.moonUp)

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.targets.map(\.kind) == [.moonrise, .moonset, .moon])
        #expect(harness.viewModel.targets.last?.azimuth == Self.moonAzimuth)
        #expect(harness.moon.requestedPositionDates == [Self.referenceDate])
    }

    @Test("Today with the moon down: no moon target")
    func todayWithMoonDown() {
        let harness = Self.makeHarness(position: Self.moonDown)

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.targets.map(\.kind) == [.moonrise, .moonset])
    }

    @Test("A day with no moonrise has no moonrise target")
    func noMoonriseDay() {
        let harness = Self.makeHarness()

        harness.viewModel.update(Self.context(moonDay: Self.moonDay(rise: nil)))

        #expect(harness.viewModel.targets == [CompassTarget(kind: .moonset, azimuth: Self.setAzimuth)])
    }

    /// Target bearings come from the *selected* day's table, not always
    /// today's (§6).
    @Test("Targets follow the selected day")
    func targetsFollowSelectedDay() {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context())

        harness.viewModel.update(Self.context(moonDay: Self.moonDay(rise: 95, set: 265), isToday: false))

        #expect(harness.viewModel.targets == [
            CompassTarget(kind: .moonrise, azimuth: 95),
            CompassTarget(kind: .moonset, azimuth: 265),
        ])
    }

    @Test("Moving the selection to today adds the moon straight away")
    func becomingTodayAddsMoon() {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.viewModel.update(Self.context(isToday: false))

        harness.viewModel.update(Self.context(isToday: true))

        #expect(harness.viewModel.targets.map(\.kind).contains(.moon))
    }

    @Test("Hidden or hint: no targets", arguments: [false, true])
    func noTargetsWhenNotShown(locationOff: Bool) {
        let harness = Self.makeHarness(position: Self.moonUp)
        let context = locationOff ? Self.context(auth: .denied) : Self.context(place: Self.sydney)

        harness.viewModel.update(context)

        #expect(harness.viewModel.targets.isEmpty)
        #expect(harness.moon.requestedPositionDates.isEmpty)
    }

    // MARK: - Sensor lifecycle (§1)

    @Test("Shown and on screen: heading and location updates start")
    func startsWhenShownAndOnScreen() {
        let harness = Self.makeRunningHarness()

        #expect(harness.heading.isRunning)
        #expect(harness.heading.startCount == 1)
    }

    @Test("Shown but not on screen: sensors stay off")
    func offWhenNotOnScreen() {
        let harness = Self.makeHarness()

        harness.viewModel.update(Self.context())

        #expect(!harness.heading.isRunning)
        #expect(harness.heading.startCount == 0)
    }

    @Test("On screen but hidden (other city): sensors stay off")
    func offWhenHidden() {
        let harness = Self.makeHarness()

        harness.viewModel.update(Self.context(place: Self.sydney))
        harness.viewModel.setOnScreen(true)

        #expect(!harness.heading.isRunning)
    }

    @Test("Scrolling out stops the sensors; scrolling back starts them again")
    func scrollOutAndBack() {
        let harness = Self.makeRunningHarness()

        harness.viewModel.setOnScreen(false)
        #expect(!harness.heading.isRunning)
        #expect(harness.heading.stopCount == 1)

        harness.viewModel.setOnScreen(true)
        #expect(harness.heading.isRunning)
        #expect(harness.heading.startCount == 2)
    }

    @Test("Background stops the sensors; foreground starts them again")
    func backgroundAndForeground() {
        let harness = Self.makeRunningHarness()

        harness.viewModel.sceneDidEnterBackground()
        #expect(!harness.heading.isRunning)

        harness.viewModel.sceneDidBecomeActive()
        #expect(harness.heading.isRunning)
        #expect(harness.heading.startCount == 2)
    }

    @Test("Switching to another city stops the sensors")
    func otherCityStops() {
        let harness = Self.makeRunningHarness()

        harness.viewModel.update(Self.context(place: Self.sydney))

        #expect(!harness.heading.isRunning)
        #expect(harness.viewModel.visibility == .far)
    }

    @Test("Losing location permission stops the sensors and shows the hint")
    func permissionLostStops() {
        let harness = Self.makeRunningHarness()

        harness.viewModel.update(Self.context(auth: .denied))

        #expect(!harness.heading.isRunning)
        #expect(harness.viewModel.visibility == .locationOff)
    }

    @Test("Updates that keep it shown don't restart the sensors")
    func updatesDoNotRestart() {
        let harness = Self.makeRunningHarness()

        harness.viewModel.update(Self.context(isToday: false))
        harness.viewModel.update(Self.context(moonDay: Self.moonDay(rise: 95)))
        harness.viewModel.setOnScreen(true)

        #expect(harness.heading.startCount == 1)
        #expect(harness.heading.stopCount == 0)
    }

    /// The stream must be held while the compass is visible: dropping it
    /// ends the session (`HeadingService`), which would silently switch the
    /// compass off.
    @Test("The heading stream is held while visible")
    func streamIsHeld() async {
        let harness = Self.makeRunningHarness()

        for _ in 0..<Self.maxYields { await Task.yield() }
        #expect(harness.heading.isRunning)
        #expect(harness.heading.stopCount == 0)

        harness.heading.send(Self.reading(200))
        await waitUntil { harness.viewModel.heading == 200 }
        #expect(harness.viewModel.heading == 200)
    }

    @Test("Stopping clears the reading and the lock")
    func stopClearsReadingAndLock() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(Self.riseAzimuth))
        await waitUntil { harness.viewModel.lockedKind != nil }

        harness.viewModel.setOnScreen(false)

        #expect(harness.viewModel.reading == nil)
        #expect(harness.viewModel.lockedKind == nil)
        #expect(harness.viewModel.headingText == nil)
    }

    // MARK: - Lock through readings

    @Test("Pointing at moonrise locks, with the target's bearing in the copy")
    func locksOnMoonrise() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(Self.reading(74))
        await waitUntil { harness.viewModel.lockedKind != nil }

        #expect(harness.viewModel.lockedKind == .moonrise)
        #expect(harness.viewModel.lockText == "Moonrise · 72° ENE")
        #expect(harness.viewModel.headingText == "74° ENE")
        #expect(harness.viewModel.lockAccessibilityLabel == "Pointing at moonrise, 72 degrees east-northeast")
        #expect(harness.viewModel.headingAccessibilityLabel == "Heading 74 degrees east-northeast")
    }

    @Test("Holds, then releases, as the heading moves away")
    func holdsThenReleases() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(72))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }

        harness.heading.send(Self.reading(79))
        await waitUntil { harness.viewModel.heading == 79 }
        #expect(harness.viewModel.lockedKind == .moonrise)

        harness.heading.send(Self.reading(81))
        await waitUntil { harness.viewModel.heading == 81 }
        #expect(harness.viewModel.lockedKind == nil)
        #expect(harness.viewModel.lockText == nil)
    }

    // MARK: - Haptic on lock (4.5)

    @Test("The haptic fires once on acquire, not while holding or on release")
    func hapticOnAcquireOnly() async {
        let harness = Self.makeRunningHarness()
        #expect(harness.viewModel.lockAcquisitionCount == 0)

        harness.heading.send(Self.reading(72))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }
        #expect(harness.viewModel.lockAcquisitionCount == 1)

        // Holding across several readings, still within 8°.
        for heading in [73.0, 76.0, 79.0, 70.0] {
            harness.heading.send(Self.reading(heading))
            await waitUntil { harness.viewModel.heading == heading }
        }
        #expect(harness.viewModel.lockedKind == .moonrise)
        #expect(harness.viewModel.lockAcquisitionCount == 1)

        // Release.
        harness.heading.send(Self.reading(100))
        await waitUntil { harness.viewModel.lockedKind == nil }
        #expect(harness.viewModel.lockAcquisitionCount == 1)

        // A fresh acquire taps again.
        harness.heading.send(Self.reading(72))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }
        #expect(harness.viewModel.lockAcquisitionCount == 2)
    }

    /// Leaving one target and landing on another in a single reading is a
    /// new lock, so it gets its own tap.
    @Test("Switching straight to another target taps once")
    func hapticOnSwitch() async {
        let harness = Self.makeHarness(position: MoonPosition(azimuth: 82, isUp: true))
        harness.viewModel.update(Self.context())
        harness.viewModel.setOnScreen(true)
        harness.heading.send(Self.reading(72))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }

        // 9° from moonrise (released), 1° from the moon.
        harness.heading.send(Self.reading(81))
        await waitUntil { harness.viewModel.lockedKind == .moon }

        #expect(harness.viewModel.lockAcquisitionCount == 2)
    }

    @Test("Low accuracy and stopping the sensors don't tap")
    func noHapticOnLossOfLock() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(72))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }

        harness.heading.send(Self.reading(72, accuracy: 20))
        await waitUntil { harness.viewModel.lockedKind == nil }
        harness.viewModel.setOnScreen(false)

        #expect(harness.viewModel.lockAcquisitionCount == 1)
    }

    @Test("A target reads as name and bearing, the lock label's format")
    func targetTextCopy() {
        let viewModel = Self.makeHarness().viewModel
        let moonset = CompassTarget(kind: .moonset, azimuth: Self.setAzimuth)

        #expect(viewModel.targetText(for: moonset) == "Moonset · 288° WNW")
    }

    // MARK: - Dial VoiceOver label (4.7)

    /// With the rows gone, the dial is where VoiceOver hears every target,
    /// including the live moon, which the moon table doesn't have.
    @Test("The dial reads every target, including the moon, in words")
    func dialReadsTargets() {
        let harness = Self.makeHarness(position: Self.moonUp)

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.targetsAccessibilityLabel == """
            Targets: moonrise, 72 degrees east-northeast; \
            moonset, 288 degrees west-northwest; \
            moon, 140 degrees southeast
            """)
    }

    @Test("With no targets the dial has no label, so it's hidden from VoiceOver")
    func dialLabelWithoutTargets() {
        let harness = Self.makeHarness()

        harness.viewModel.update(Self.context(place: Self.sanDiego))

        #expect(harness.viewModel.targetsAccessibilityLabel == nil)
    }

    @Test("The dial label follows the moon as it rises")
    func dialLabelFollowsMoon() {
        let harness = Self.makeHarness(position: Self.moonDown)
        harness.viewModel.update(Self.context())
        #expect(harness.viewModel.targetsAccessibilityLabel?.contains("moon,") == false)

        harness.moon.position = Self.moonUp
        harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.targetsAccessibilityLabel?.hasSuffix("moon, 140 degrees southeast") == true)
    }

    @Test("Placeholder copy for the hint and low accuracy")
    func placeholderCopy() {
        #expect(CompassViewModel.locationOffHint == "Turn on location to use the compass.")
        #expect(CompassViewModel.turnOnLocationTitle == "Turn On Location")
        #expect(CompassViewModel.lowAccuracyText == "Compass accuracy is low")
    }

    @Test("Low accuracy: no lock, and VoiceOver says so")
    func lowAccuracyNoLock() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(Self.reading(72, accuracy: 20))
        await waitUntil { harness.viewModel.reading != nil }

        #expect(harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.lockedKind == nil)
        #expect(harness.viewModel.headingAccessibilityLabel == "Compass accuracy is low")
    }

    @Test("No compass (unavailable): low accuracy, no heading text")
    func unavailableReading() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(.unavailable)
        await waitUntil { harness.viewModel.reading != nil }

        #expect(harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.headingText == nil)
    }

    @Test("Changing the day re-checks the lock against the new bearings")
    func dayChangeRechecksLock() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(72))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }

        harness.viewModel.update(Self.context(moonDay: Self.moonDay(rise: 95), isToday: false))

        #expect(harness.viewModel.lockedKind == nil)
    }

    // MARK: - "Moon" refresh (30 s)

    @Test("The refresh waits 30 seconds")
    func refreshInterval() async {
        let harness = Self.makeRunningHarness()

        await waitUntil { harness.sleeper.pendingCount == 1 }

        #expect(harness.sleeper.requestedDurations == [.seconds(30)])
        harness.sleeper.cancelAll()
    }

    @Test("A tick adds the moon when it rises on screen, and removes it when it sets")
    func tickTracksMoonrise() async {
        let harness = Self.makeRunningHarness(position: Self.moonDown)
        #expect(!harness.viewModel.targets.map(\.kind).contains(.moon))

        harness.moon.position = Self.moonUp
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.targets.map(\.kind).contains(.moon) }
        #expect(harness.viewModel.targets.last == CompassTarget(kind: .moon, azimuth: Self.moonAzimuth))

        harness.moon.position = Self.moonDown
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { !harness.viewModel.targets.map(\.kind).contains(.moon) }
        #expect(harness.viewModel.targets.map(\.kind) == [.moonrise, .moonset])

        harness.sleeper.cancelAll()
    }

    @Test("A tick follows the moon's azimuth")
    func tickMovesMoon() async {
        let harness = Self.makeRunningHarness(position: Self.moonUp)

        harness.moon.position = MoonPosition(azimuth: 150, isUp: true)
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.targets.last?.azimuth == 150 }

        #expect(harness.viewModel.targets.last == CompassTarget(kind: .moon, azimuth: 150))
        harness.sleeper.cancelAll()
    }

    @Test("The moon setting while locked on it releases the lock")
    func moonSetReleasesLock() async {
        let harness = Self.makeRunningHarness(position: Self.moonUp)
        harness.heading.send(Self.reading(Self.moonAzimuth))
        await waitUntil { harness.viewModel.lockedKind == .moon }
        #expect(harness.viewModel.lockText == "Moon · 140° SE")

        harness.moon.position = Self.moonDown
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.lockedKind == nil }

        #expect(harness.viewModel.lockedKind == nil)
        harness.sleeper.cancelAll()
    }

    @Test("Coming back to the foreground recomputes the moon at once")
    func foregroundRecomputesMoon() {
        let harness = Self.makeRunningHarness(position: Self.moonDown)
        harness.viewModel.sceneDidEnterBackground()

        harness.moon.position = Self.moonUp
        harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.targets.map(\.kind).contains(.moon))
    }

    @Test("No ticks while the sensors are off")
    func noTicksWhenOff() async {
        let harness = Self.makeRunningHarness(position: Self.moonDown)
        await waitUntil { harness.sleeper.pendingCount == 1 }

        harness.viewModel.setOnScreen(false)
        harness.moon.position = Self.moonUp
        harness.sleeper.fire()
        for _ in 0..<Self.maxYields { await Task.yield() }

        #expect(!harness.viewModel.targets.map(\.kind).contains(.moon))
        #expect(harness.sleeper.pendingCount == 0)
    }
}
