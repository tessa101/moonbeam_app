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

    @Test("Nearby: compass shown, with a note naming both cities and no distance")
    func nearbyNote() throws {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.huntingtonBeach))
        harness.viewModel.setOnScreen(true)

        let note = try #require(harness.viewModel.nearbyNote)
        #expect(note == "You're in Los Angeles, CA but Huntington Beach, CA is nearby")
        #expect(harness.viewModel.farMessage == nil)
        #expect(note.rangeOfCharacter(from: .decimalDigits) == nil)
        #expect(!note.contains("mi") && !note.contains("km"))
        #expect(harness.heading.isRunning)
        #expect(!harness.viewModel.targets.isEmpty)
    }

    @Test("Here has no note and no Far message")
    func hereHasNoNote() {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.searchedLosAngeles))

        #expect(harness.viewModel.nearbyNote == nil)
        #expect(harness.viewModel.farMessage == nil)
    }

    @Test("Far: no compass, no targets, sensors off, and the Far message names the city, no distance")
    func farHidesCompass() throws {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.viewModel.update(Self.context(place: Self.sanDiego))
        harness.viewModel.setOnScreen(true)

        #expect(!harness.viewModel.visibility.showsCompass)
        #expect(harness.viewModel.targets.isEmpty)
        #expect(harness.viewModel.nearbyNote == nil)
        #expect(!harness.heading.isRunning)
        let message = try #require(harness.viewModel.farMessage)
        #expect(message == "You're a bit too far from San Diego, CA to view the compass accurately")
        #expect(message.rangeOfCharacter(from: .decimalDigits) == nil)
    }

    @Test("Leaving Far for Here clears the Far message")
    func farMessageClears() {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.sanDiego))

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.farMessage == nil)
    }

    @Test("Moving between two Nearby cities updates the note")
    func nearbyToNearbyUpdatesNote() {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(place: Self.huntingtonBeach))

        harness.viewModel.update(Self.context(place: Self.northOfDetected(byDegrees: 0.5)))

        #expect(harness.viewModel.nearbyNote == "You're in Los Angeles, CA but Test Town, CA is nearby")
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

        harness.heading.send(Self.reading(72, accuracy: 30))
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

    // MARK: - DEBUG readout (4.8/4.9)

    @Test("The DEBUG readout shows accuracy authorization, detection and sensor state")
    func debugReadout() async {
        let harness = Self.makeHarness()
        var context = Self.context()
        context.isPreciseLocationOff = true
        harness.viewModel.update(context)
        harness.viewModel.setOnScreen(true)
        harness.heading.send(Self.reading(74))
        await waitUntil { harness.viewModel.lockedKind != nil }

        let readout = harness.viewModel.debugReadout

        #expect(readout.contains("accuracyAuthorization: reduced"))
        #expect(readout.contains("visibility: here"))
        #expect(readout.contains("detected: yes"))
        #expect(readout.contains("sensors: running"))
        #expect(readout.contains("heading: 74.0° true"))
        #expect(readout.contains("lock: moonrise"))
    }

    @Test("The DEBUG readout when stopped and nothing detected")
    func debugReadoutStopped() {
        let harness = Self.makeHarness()

        harness.viewModel.update(Self.context(detected: nil))

        let readout = harness.viewModel.debugReadout
        #expect(readout.contains("accuracyAuthorization: full"))
        #expect(readout.contains("detected: no"))
        #expect(readout.contains("sensors: stopped"))
        #expect(readout.contains("heading: none"))
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
            Moon now, southeast, 140 degrees
            """)
    }

    /// §11 Q4 (revised): "now" and the direction first, so the live Moon
    /// isn't heard as another moonrise.
    @Test("The live Moon reads \"Moon now, west, 275 degrees\"")
    func dialReadsMoonNow() {
        let harness = Self.makeHarness(position: MoonPosition(azimuth: 275, isUp: true))

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.targetsAccessibilityLabel?.hasSuffix("; Moon now, west, 275 degrees") == true)
    }

    @Test("The Moon marker's phase is the moon card's: lit fraction and side from the day's table")
    func moonGlyphFollowsTable() {
        let harness = Self.makeHarness(position: Self.moonUp)
        let base = Self.moonDay()
        let waning = MoonDay(
            place: base.place, rise: base.rise, set: base.set,
            phase: .waningGibbous, phaseAngle: 240, illumination: 0.64
        )

        harness.viewModel.update(Self.context(moonDay: waning))

        #expect(harness.viewModel.moonGlyph == PhaseGlyphGeometry(illumination: 0.64, phaseAngle: 240))
        #expect(harness.viewModel.moonGlyph?.litSide == .left)

        harness.viewModel.update(Self.context(moonDay: nil))
        #expect(harness.viewModel.moonGlyph == nil)
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
        #expect(harness.viewModel.targetsAccessibilityLabel?.contains("Moon now") == false)

        harness.moon.position = Self.moonUp
        harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.targetsAccessibilityLabel?.hasSuffix("Moon now, southeast, 140 degrees") == true)
    }

    @Test("Placeholder copy for the hint and low accuracy")
    func placeholderCopy() {
        #expect(CompassViewModel.locationOffHint == "Turn on location to use the compass.")
        #expect(CompassViewModel.turnOnLocationTitle == "Turn On Location")
        #expect(CompassViewModel.lowAccuracyText == "Compass accuracy is low")
        #expect(CompassViewModel.preciseLocationOffText(city: "Irvine")
            == "We think you're near Irvine, but the compass needs Precise Location to point the right way.")
        #expect(CompassViewModel.usePreciseLocationTitle == "Use Precise Location")
        #expect(CompassViewModel.preciseConfirmationText == "There you are! The compass is happy now.")
        #expect(CompassViewModel.interferenceTip
            == "Move away from metal, magnets or a charger, or wave your phone in a figure 8")
    }

    /// The device test (2026-09-29): accuracy wandered ±11.8° → ±27.3°
    /// (charging) → ±13.4°. With hysteresis, a ±22° reading between good
    /// ones keeps the lock, and one between bad ones doesn't bring it back.
    @Test("Accuracy hysteresis through real readings: the lock survives the gap")
    func accuracyHysteresis() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(Self.reading(72, accuracy: 11.8))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }

        harness.heading.send(Self.reading(73, accuracy: 22))
        await waitUntil { harness.viewModel.heading == 73 }
        #expect(!harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.lockedKind == .moonrise)

        harness.heading.send(Self.reading(72, accuracy: 27.3))
        await waitUntil { harness.viewModel.isLowAccuracy }
        #expect(harness.viewModel.lockedKind == nil)

        harness.heading.send(Self.reading(71, accuracy: 22))
        await waitUntil { harness.viewModel.heading == 71 }
        #expect(harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.lockedKind == nil)

        harness.heading.send(Self.reading(72, accuracy: 13.4))
        await waitUntil { !harness.viewModel.isLowAccuracy }
        #expect(harness.viewModel.lockedKind == .moonrise)
        #expect(harness.viewModel.lockAcquisitionCount == 2)
    }

    @Test("Stopping the sensors puts accuracy back to low")
    func stopResetsAccuracy() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(72, accuracy: 5))
        await waitUntil { !harness.viewModel.isLowAccuracy }

        harness.viewModel.setOnScreen(false)

        #expect(harness.viewModel.isLowAccuracy)
    }

    @Test("Low accuracy: no lock, and VoiceOver says so")
    func lowAccuracyNoLock() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(Self.reading(72, accuracy: 30))
        await waitUntil { harness.viewModel.reading != nil }

        #expect(harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.lockedKind == nil)
        #expect(harness.viewModel.headingAccessibilityLabel == """
            Compass accuracy is low. \
            Move away from metal, magnets or a charger, or wave your phone in a figure 8
            """)
    }

    @Test("No compass (unavailable): low accuracy, no heading text, no reason")
    func unavailableReading() async {
        let harness = Self.makeRunningHarness()

        harness.heading.send(.unavailable)
        await waitUntil { harness.viewModel.reading != nil }

        #expect(harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.headingText == nil)
        #expect(harness.viewModel.lowAccuracyReason == nil)
        #expect(harness.viewModel.headingAccessibilityLabel == "Compass accuracy is low")
    }

    // MARK: - Low-accuracy reason (4.10)

    @Test("Precise Location off: the line names the place, offers the fix, and VoiceOver reads it")
    func reasonPreciseLocationOff() async {
        let harness = Self.makeHarness()
        var context = Self.context()
        context.isPreciseLocationOff = true
        harness.viewModel.update(context)
        harness.viewModel.setOnScreen(true)

        harness.heading.send(Self.reading(72, accuracy: 81.4))
        await waitUntil { harness.viewModel.reading != nil }

        let line = "We think you're near Los Angeles, CA, but the compass needs Precise Location to point the right way."
        #expect(harness.viewModel.lowAccuracyReason == .preciseLocationOff)
        #expect(harness.viewModel.lowAccuracyReasonText == line)
        #expect(harness.viewModel.statusLineText == line)
        #expect(harness.viewModel.offersPreciseLocation)
        #expect(harness.viewModel.headingAccessibilityLabel == "Compass accuracy is low. \(line)")
    }

    // MARK: - Aha line (4.12)

    /// Shown and on screen, Precise Location off, with a reading from iOS's
    /// ±81° reduced-accuracy heading.
    private func makePreciseOffHarness() async -> Harness {
        let harness = Self.makeHarness()
        var context = Self.context()
        context.isPreciseLocationOff = true
        harness.viewModel.update(context)
        harness.viewModel.setOnScreen(true)
        harness.heading.send(Self.reading(72, accuracy: 81.4))
        await waitUntil { harness.viewModel.reading != nil }
        return harness
    }

    @Test("Precise Location turning on while on screen: the aha line replaces the reason, then clears")
    func ahaOnPreciseOn() async {
        let harness = await makePreciseOffHarness()

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.preciseConfirmation == "There you are! The compass is happy now.")
        #expect(harness.viewModel.statusLineText == "There you are! The compass is happy now.")
        #expect(!harness.viewModel.offersPreciseLocation)

        await waitUntil { harness.sleeper.requestedDurations.contains(CompassViewModel.preciseConfirmationDuration) }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.preciseConfirmation == nil }

        #expect(harness.viewModel.preciseConfirmation == nil)
        harness.viewModel.setOnScreen(false)
        harness.sleeper.cancelAll()
    }

    @Test("The aha line lasts about 3 s")
    func ahaDuration() {
        #expect(CompassViewModel.preciseConfirmationDuration == .seconds(3))
    }

    @Test("No aha line on an ordinary recovery from low accuracy with Precise on throughout")
    func noAhaOnAccuracyRecovery() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(72, accuracy: 30))
        await waitUntil { harness.viewModel.isLowAccuracy && harness.viewModel.reading != nil }

        harness.heading.send(Self.reading(72, accuracy: 5))
        await waitUntil { !harness.viewModel.isLowAccuracy }
        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.preciseConfirmation == nil)
    }

    @Test("No aha line when Precise Location turns on with the compass off screen")
    func noAhaOffScreen() {
        let harness = Self.makeHarness()
        var context = Self.context()
        context.isPreciseLocationOff = true
        harness.viewModel.update(context)

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.preciseConfirmation == nil)
    }

    @Test("No aha line when Precise Location turns off")
    func noAhaOnPreciseOff() {
        let harness = Self.makeRunningHarness()
        var context = Self.context()
        context.isPreciseLocationOff = true

        harness.viewModel.update(context)

        #expect(harness.viewModel.preciseConfirmation == nil)
    }

    @Test("Precise Location on: the metal, magnets or charger tip")
    func reasonInterference() async throws {
        let harness = Self.makeRunningHarness()

        harness.heading.send(Self.reading(72, accuracy: 30))
        await waitUntil { harness.viewModel.reading != nil }

        #expect(harness.viewModel.lowAccuracyReason == .interference)
        let tip = try #require(harness.viewModel.lowAccuracyReasonText)
        #expect(tip.contains("metal"))
        #expect(tip.contains("magnets"))
        #expect(tip.contains("charger"))
        #expect(tip.contains("figure 8"))
    }

    @Test("Good accuracy: no reason, even with Precise Location off")
    func noReasonWhenGood() async {
        let harness = Self.makeHarness()
        var context = Self.context()
        context.isPreciseLocationOff = true
        harness.viewModel.update(context)
        harness.viewModel.setOnScreen(true)

        harness.heading.send(Self.reading(72, accuracy: 5))
        await waitUntil { !harness.viewModel.isLowAccuracy }

        #expect(harness.viewModel.lowAccuracyReason == nil)
        #expect(harness.viewModel.lowAccuracyReasonText == nil)
    }

    /// Before the first reading it's low only because nothing has arrived
    /// yet; a tip would flash up on every start.
    @Test("No reading yet: no reason")
    func noReasonBeforeFirstReading() {
        let harness = Self.makeRunningHarness()

        #expect(harness.viewModel.isLowAccuracy)
        #expect(harness.viewModel.lowAccuracyReason == nil)
    }

    @Test("The reason follows the hysteresis: gone once accuracy recovers below 20°")
    func reasonClearsOnRecovery() async {
        let harness = Self.makeRunningHarness()
        harness.heading.send(Self.reading(72, accuracy: 30))
        await waitUntil { harness.viewModel.lowAccuracyReason != nil }

        harness.heading.send(Self.reading(72, accuracy: 22))
        await waitUntil { harness.viewModel.reading?.accuracy == 22 }
        #expect(harness.viewModel.lowAccuracyReason == .interference)

        harness.heading.send(Self.reading(72, accuracy: 13))
        await waitUntil { !harness.viewModel.isLowAccuracy }
        #expect(harness.viewModel.lowAccuracyReason == nil)
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

    // MARK: - Moon arc (DESIGN-1.1.md §3.3a)

    /// Rise at 72°, south, set at 288°: the fixtures' bearings. The fake
    /// returns it for any moment, so the tests check which moment is asked.
    private static let scriptedPass = MoonPass(
        rise: MoonEvent(date: referenceDate - 4 * MoonPass.sampleInterval, azimuth: riseAzimuth),
        set: MoonEvent(date: referenceDate + 4 * MoonPass.sampleInterval, azimuth: setAzimuth),
        path: [riseAzimuth, 100, 120, 130, 140, 180, 220, 260, setAzimuth]
    )

    @Test("No pass from the service: no arc")
    func noPassNoArc() {
        let harness = Self.makeHarness(position: Self.moonUp)

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.arc == nil)
    }

    @Test("Moon up: the pass under way now, with the moon on it")
    func arcForMoonUp() {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.moon.pass = Self.scriptedPass

        harness.viewModel.update(Self.context())

        #expect(harness.moon.requestedPassDates == [Self.referenceDate])
        #expect(harness.viewModel.arc == CompassArc(
            startAzimuth: Self.riseAzimuth,
            endAzimuth: Self.setAzimuth,
            moonAzimuth: Self.moonAzimuth
        ))
    }

    @Test("Moon down: the pass from the day's moonrise, no moon on it")
    func arcForMoonDown() {
        let harness = Self.makeHarness(position: Self.moonDown)
        harness.moon.pass = Self.scriptedPass

        harness.viewModel.update(Self.context())

        #expect(harness.moon.requestedPassDates == [
            Self.referenceDate + CompassViewModel.passLookupDelayAfterRise,
        ])
        #expect(harness.viewModel.arc == CompassArc(
            startAzimuth: Self.riseAzimuth,
            endAzimuth: Self.setAzimuth,
            moonAzimuth: nil
        ))
    }

    @Test("Another day: the pass from that day's moonrise, never the live moon")
    func arcForOtherDay() {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.moon.pass = Self.scriptedPass

        harness.viewModel.update(Self.context(isToday: false))

        #expect(harness.moon.requestedPassDates == [
            Self.referenceDate + CompassViewModel.passLookupDelayAfterRise,
        ])
        #expect(harness.viewModel.arc?.moonAzimuth == nil)
    }

    @Test("No moonrise and the moon down: no arc, and no pass looked up")
    func noArcWithoutMoonrise() {
        let harness = Self.makeHarness(position: Self.moonDown)
        harness.moon.pass = Self.scriptedPass

        harness.viewModel.update(Self.context(moonDay: Self.moonDay(rise: nil)))

        #expect(harness.viewModel.arc == nil)
        #expect(harness.moon.requestedPassDates.isEmpty)
    }

    @Test("No compass (Far): no arc")
    func noArcWhenFar() {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.moon.pass = Self.scriptedPass

        harness.viewModel.update(Self.context(place: Self.sydney))

        #expect(harness.viewModel.arc == nil)
        #expect(harness.moon.requestedPassDates.isEmpty)
    }

    @Test("The moon's place on the arc is unwrapped onto the pass")
    func arcMoonIsUnwrapped() {
        let harness = Self.makeHarness(position: MoonPosition(azimuth: 5, isUp: true))
        harness.moon.pass = MoonPass(
            rise: MoonEvent(date: Self.referenceDate - MoonPass.sampleInterval, azimuth: 350),
            set: MoonEvent(date: Self.referenceDate + MoonPass.sampleInterval, azimuth: 20),
            path: [350, 365, 380]
        )

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.arc == CompassArc(startAzimuth: 350, endAzimuth: 380, moonAzimuth: 365))
    }

    @Test("A tick moves the moon along the arc without looking the pass up again")
    func tickMovesMoonOnArc() async {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.moon.pass = Self.scriptedPass
        harness.viewModel.update(Self.context())
        harness.viewModel.setOnScreen(true)

        harness.moon.position = MoonPosition(azimuth: 150, isUp: true)
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.arc?.moonAzimuth == 150 }

        #expect(harness.viewModel.arc?.moonAzimuth == 150)
        #expect(harness.moon.requestedPassDates.count == 1)
        harness.sleeper.cancelAll()
    }

    @Test("A tick where the moon sets switches to the next pass, dimmed")
    func tickMoonSetSwitchesPass() async {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.moon.pass = Self.scriptedPass
        harness.viewModel.update(Self.context())
        harness.viewModel.setOnScreen(true)

        harness.moon.position = Self.moonDown
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.arc?.moonAzimuth == nil }

        #expect(harness.viewModel.arc?.moonAzimuth == nil)
        #expect(harness.moon.requestedPassDates == [
            Self.referenceDate,
            Self.referenceDate + CompassViewModel.passLookupDelayAfterRise,
        ])
        harness.sleeper.cancelAll()
    }

    // MARK: - Up now (COMPASS-1.1.md §3)

    /// 34 minutes after the fixtures' clock.
    private static let soonRise = MoonEvent(date: referenceDate + 34 * 60, azimuth: riseAzimuth)

    @Test("Up now, moon up: its bearing, and the pass the arc draws")
    func upNowWhileUp() {
        let harness = Self.makeHarness(position: Self.moonUp)
        harness.moon.pass = Self.scriptedPass

        harness.viewModel.update(Self.context())

        guard case let .up(bearing, pass?) = harness.viewModel.upNow?.state else {
            Issue.record("Expected Up now with the moon up and its pass")
            return
        }
        #expect(bearing == "140° SE")
        // The fixtures' clock is halfway through the scripted pass.
        #expect(pass.progress == 0.5)
        #expect(harness.moon.requestedNextRiseDates.isEmpty)
    }

    @Test("Up now, moon down: when it rises next")
    func upNowWhileDown() {
        let harness = Self.makeHarness(position: Self.moonDown)
        harness.moon.nextRise = Self.soonRise

        harness.viewModel.update(Self.context())

        #expect(harness.viewModel.upNow?.state == .down(nextRise: "Rises in 34 min"))
        #expect(harness.moon.requestedNextRiseDates == [Self.referenceDate])
    }

    @Test("Up now is hidden on other dates")
    func upNowHiddenOnOtherDates() {
        let harness = Self.makeHarness(position: Self.moonUp)

        harness.viewModel.update(Self.context(isToday: false))

        #expect(harness.viewModel.upNow == nil)
    }

    @Test("Up now is hidden without the compass", arguments: [false, true])
    func upNowHiddenWithoutCompass(locationOff: Bool) {
        let harness = Self.makeHarness(position: Self.moonUp)
        let context = locationOff ? Self.context(auth: .denied) : Self.context(place: Self.sydney)

        harness.viewModel.update(context)

        #expect(harness.viewModel.upNow == nil)
        #expect(harness.moon.requestedNextRiseDates.isEmpty)
    }

    @Test("A tick turns Up now over when the moon rises, and back when it sets")
    func tickTurnsUpNowOver() async {
        let harness = Self.makeHarness(position: Self.moonDown)
        harness.moon.nextRise = Self.soonRise
        harness.viewModel.update(Self.context())
        harness.viewModel.setOnScreen(true)
        #expect(harness.viewModel.upNow?.isUp == false)

        harness.moon.position = Self.moonUp
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.upNow?.isUp == true }
        #expect(harness.viewModel.upNow?.state == .up(bearing: "140° SE", pass: nil))

        harness.moon.position = Self.moonDown
        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.viewModel.upNow?.isUp == false }
        #expect(harness.viewModel.upNow?.state == .down(nextRise: "Rises in 34 min"))

        harness.sleeper.cancelAll()
    }

    @Test("A tick while down keeps the next rise until it has passed")
    func tickKeepsNextRise() async {
        let harness = Self.makeHarness(position: Self.moonDown)
        harness.moon.nextRise = Self.soonRise
        harness.viewModel.update(Self.context())
        harness.viewModel.setOnScreen(true)

        await waitUntil { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await waitUntil { harness.sleeper.pendingCount == 1 }

        #expect(harness.moon.requestedNextRiseDates == [Self.referenceDate])
        harness.sleeper.cancelAll()
    }

    // MARK: - Moon pulse (COMPASS-1.1.md §5)

    @Test("Pulse: on with the moon up and no lock yet this launch")
    func pulseOnWhileUnlocked() {
        let harness = Self.makeRunningHarness(position: Self.moonUp)

        #expect(harness.viewModel.showsMoonPulse)
    }

    @Test("Pulse: off when the moon is down, or on another day")
    func pulseOffWithoutMoon() {
        let down = Self.makeRunningHarness(position: Self.moonDown)
        let otherDay = Self.makeHarness(position: Self.moonUp)
        otherDay.viewModel.update(Self.context(isToday: false))

        #expect(!down.viewModel.showsMoonPulse)
        #expect(!otherDay.viewModel.showsMoonPulse)
    }

    @Test("Pulse: off after the first lock on any target, and stays off")
    func pulseStopsAfterFirstLock() async {
        let harness = Self.makeRunningHarness(position: Self.moonUp)

        harness.heading.send(Self.reading(Self.riseAzimuth))
        await waitUntil { harness.viewModel.lockedKind == .moonrise }
        #expect(!harness.viewModel.showsMoonPulse)

        harness.heading.send(Self.reading(Self.riseAzimuth + 90))
        await waitUntil { harness.viewModel.lockedKind == nil }
        #expect(harness.viewModel.hasLockedThisLaunch)
        #expect(!harness.viewModel.showsMoonPulse)

        // Not even after the sensors stop and start again.
        harness.viewModel.setOnScreen(false)
        harness.viewModel.setOnScreen(true)
        #expect(!harness.viewModel.showsMoonPulse)
        harness.sleeper.cancelAll()
    }
}
