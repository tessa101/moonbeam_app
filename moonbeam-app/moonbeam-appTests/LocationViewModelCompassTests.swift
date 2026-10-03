//
//  LocationViewModelCompassTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// How `LocationViewModel` feeds its compass (COMPASS.md §2, §6): the
/// visibility matrix end to end through detection, search and permission,
/// targets following the selected day, and the scene lifecycle.
///
/// The compass's own rules are in `CompassViewModelTests`; this suite only
/// checks the context reaching it is right.
@Suite("Location view model: compass wiring")
@MainActor
struct LocationViewModelCompassTests {

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

    /// The same city from search: same names, other coordinates, not
    /// marked as the current location.
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

    /// 2026-09-26 20:00 PDT: the moon is up in LA (it rose that afternoon).
    private static let referenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        let components = DateComponents(year: 2026, month: 9, day: 26, hour: 20)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    private struct Harness {
        let viewModel: LocationViewModel
        let location: FakeLocationService
        let heading: FakeHeadingService
    }

    private static func makeHarness(
        auth: LocationAuthState = .authorized,
        detected: Place? = detectedLosAngeles,
        store: InMemoryPlaceStore = InMemoryPlaceStore(),
        moonService: any MoonService = AstronomyEngineMoonService()
    ) -> Harness {
        let location = FakeLocationService(
            authorizationState: auth,
            placeResult: detected.map { .success($0) } ?? .failure(LocationError.locationUnavailable)
        )
        let heading = FakeHeadingService()
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: store,
            moonService: moonService,
            headingService: heading,
            deviceTimeZone: losAngelesZone,
            now: { referenceDate }
        )
        return Harness(viewModel: viewModel, location: location, heading: heading)
    }

    // MARK: - Visibility matrix, end to end (§2)

    @Test("First launch with no place: hidden")
    func firstLaunchHidden() async {
        let harness = Self.makeHarness(auth: .notDetermined, detected: nil)

        await harness.viewModel.start()

        #expect(harness.viewModel.compass.visibility == .hidden)
    }

    @Test("Detected location on launch: Here")
    func detectedOnLaunchShown() async {
        let harness = Self.makeHarness()

        await harness.viewModel.start()

        #expect(harness.viewModel.place?.isCurrentLocation == true)
        #expect(harness.viewModel.compass.visibility == .here)
    }

    @Test("Searching the city you're in: still Here")
    func searchedSameCityShown() async {
        let harness = Self.makeHarness()
        await harness.viewModel.start()

        harness.viewModel.select(Self.searchedLosAngeles)

        #expect(harness.viewModel.compass.visibility == .here)
    }

    @Test("Searching a far city: Far; back to your location: Here")
    func otherCityHiddenThenBack() async {
        let harness = Self.makeHarness()
        await harness.viewModel.start()

        harness.viewModel.select(Self.sydney)
        #expect(harness.viewModel.compass.visibility == .far)

        await harness.viewModel.useMyLocation()
        #expect(harness.viewModel.compass.visibility == .here)
    }

    /// Authorized, but the fix failed: nothing proves you're in the saved
    /// city, even if it's where you usually are.
    @Test("Authorized but detection failed: a saved city stays hidden")
    func detectionFailedHidden() async {
        let harness = Self.makeHarness(
            detected: nil,
            store: InMemoryPlaceStore(lastViewed: Self.searchedLosAngeles)
        )

        await harness.viewModel.start()

        #expect(harness.viewModel.place == Self.searchedLosAngeles)
        #expect(harness.viewModel.compass.visibility == .hidden)
    }

    @Test(
        "Location not authorized, with a saved place: the enable-location hint",
        arguments: [LocationAuthState.notDetermined, .denied, .restricted, .servicesOff]
    )
    func notAuthorizedHint(auth: LocationAuthState) async {
        let harness = Self.makeHarness(
            auth: auth,
            detected: nil,
            store: InMemoryPlaceStore(lastViewed: Self.searchedLosAngeles)
        )

        await harness.viewModel.start()

        #expect(harness.viewModel.compass.visibility == .locationOff)
    }

    @Test("Granting at the prompt from the main button: switches to your location, Here")
    func grantAtPrompt() async {
        let harness = Self.makeHarness(
            auth: .notDetermined,
            store: InMemoryPlaceStore(lastViewed: Self.searchedLosAngeles)
        )
        harness.location.stateAfterRequest = .authorized
        await harness.viewModel.start()
        #expect(harness.viewModel.compass.visibility == .locationOff)

        await harness.viewModel.useMyLocation()

        #expect(harness.viewModel.compass.visibility == .here)
    }

    @Test("Permission turned off in Settings: the hint on return, and the sensors stop")
    func revokedInSettings() async {
        let harness = Self.makeHarness()
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)
        #expect(harness.heading.isRunning)

        harness.location.authorizationState = .denied
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.compass.visibility == .locationOff)
        #expect(!harness.heading.isRunning)
    }

    // MARK: - Turn On Location from the compass hint (4.6)

    /// ~30 mi from LA: Nearby once detection finds LA.
    private static let huntingtonBeach = Place(
        name: "Huntington Beach",
        region: "CA",
        country: "United States",
        latitude: 33.66,
        longitude: -118.00,
        timeZone: losAngelesZone
    )

    @Test("Compass hint, granted at the prompt: keeps the searched city, and it's Nearby")
    func hintAtPromptKeepsSearchedCity() async {
        let harness = Self.makeHarness(
            auth: .notDetermined,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        harness.location.stateAfterRequest = .authorized
        await harness.viewModel.start()
        #expect(harness.viewModel.compass.visibility == .locationOff)

        await harness.viewModel.turnOnLocationForCompass()

        #expect(harness.viewModel.place == Self.huntingtonBeach)
        #expect(harness.viewModel.place?.isCurrentLocation == false)
        #expect(harness.viewModel.compass.visibility == .nearby)
        #expect(harness.viewModel.compass.nearbyNote == "You're in Los Angeles, CA but Huntington Beach, CA is nearby")
    }

    @Test("Compass hint via Settings: coming back keeps the searched city")
    func hintViaSettingsKeepsSearchedCity() async {
        let harness = Self.makeHarness(
            auth: .denied,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        await harness.viewModel.start()

        await harness.viewModel.turnOnLocationForCompass()
        #expect(harness.viewModel.locationOffDialog == .denied)

        // Permission granted in Settings, then back to the app.
        harness.location.authorizationState = .authorized
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 1)
        #expect(harness.viewModel.place == Self.huntingtonBeach)
        #expect(harness.viewModel.compass.visibility == .nearby)
    }

    @Test("Main button via Settings: coming back still switches to your location")
    func mainButtonViaSettingsSwitches() async {
        let harness = Self.makeHarness(
            auth: .denied,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        await harness.viewModel.start()

        await harness.viewModel.useMyLocation()
        harness.location.authorizationState = .authorized
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.place == Self.detectedLosAngeles)
        #expect(harness.viewModel.compass.visibility == .here)
    }

    /// The main button after a compass-hint dialog: the button's own
    /// behaviour wins, so the return from Settings switches.
    @Test("Main button after a compass-hint dialog: the return switches")
    func mainButtonOverridesHintFlag() async {
        let harness = Self.makeHarness(
            auth: .denied,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        await harness.viewModel.start()

        await harness.viewModel.turnOnLocationForCompass()
        harness.viewModel.dismissLocationOffDialog()
        await harness.viewModel.useMyLocation()
        harness.location.authorizationState = .authorized
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.place == Self.detectedLosAngeles)
    }

    @Test("Compass hint when detection fails: keeps the city, compass stays hidden")
    func hintDetectionFails() async {
        let harness = Self.makeHarness(
            auth: .notDetermined,
            detected: nil,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        harness.location.stateAfterRequest = .authorized
        await harness.viewModel.start()

        await harness.viewModel.turnOnLocationForCompass()

        #expect(harness.viewModel.place == Self.huntingtonBeach)
        #expect(harness.viewModel.compass.visibility == .hidden)
        #expect(harness.viewModel.locationFailed)
    }

    // MARK: - Recovering on foreground (4.8)

    /// The overnight case: the app relaunched, the launch fix failed, so
    /// nothing was detected and the compass stayed hidden with nothing to
    /// retry. The next foreground now retries, detection only.
    @Test("Foreground with nothing detected retries detection and keeps the place")
    func foregroundRetriesDetection() async {
        let harness = Self.makeHarness(
            detected: nil,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        await harness.viewModel.start()
        #expect(harness.viewModel.compass.visibility == .hidden)

        harness.location.placeResult = .success(Self.detectedLosAngeles)
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 2)
        #expect(harness.viewModel.place == Self.huntingtonBeach)
        #expect(harness.viewModel.compass.visibility == .nearby)
    }

    @Test("A failed quiet retry shows nothing and keeps the place")
    func foregroundRetryFailsQuietly() async {
        let harness = Self.makeHarness(
            detected: nil,
            store: InMemoryPlaceStore(lastViewed: Self.huntingtonBeach)
        )
        await harness.viewModel.start()

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.place == Self.huntingtonBeach)
        #expect(!harness.viewModel.locationFailed)
        #expect(harness.viewModel.compass.visibility == .hidden)
    }

    @Test("Foreground with a place already detected doesn't fetch again")
    func foregroundWithDetectionDoesNotRefetch() async {
        let harness = Self.makeHarness()
        await harness.viewModel.start()

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 1)
    }

    @Test("Precise Location off reaches the compass, and updates on foreground")
    func preciseLocationFlag() async {
        let harness = Self.makeHarness()
        harness.location.isPreciseLocationOff = true
        await harness.viewModel.start()
        #expect(harness.viewModel.compass.isPreciseLocationOff)

        harness.location.isPreciseLocationOff = false
        await harness.viewModel.sceneDidBecomeActive()

        #expect(!harness.viewModel.compass.isPreciseLocationOff)
    }

    // MARK: - Use Precise Location (4.12)

    @Test("Use Precise Location asks with the Compass purpose key; granting reaches the compass with the aha line")
    func usePreciseLocationGranted() async {
        let harness = Self.makeHarness()
        harness.location.isPreciseLocationOff = true
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)
        harness.location.preciseOffAfterTemporaryRequest = false

        await harness.viewModel.usePreciseLocationForCompass()

        #expect(harness.location.temporaryPrecisePurposeKeys == ["Compass"])
        #expect(!harness.viewModel.compass.isPreciseLocationOff)
        #expect(harness.viewModel.compass.preciseConfirmation != nil)
    }

    @Test("Declining the temporary alert leaves everything as it was")
    func usePreciseLocationDeclined() async {
        let harness = Self.makeHarness()
        harness.location.isPreciseLocationOff = true
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)

        await harness.viewModel.usePreciseLocationForCompass()

        #expect(harness.location.temporaryPrecisePurposeKeys == ["Compass"])
        #expect(harness.viewModel.compass.isPreciseLocationOff)
        #expect(harness.viewModel.compass.preciseConfirmation == nil)
        #expect(harness.viewModel.place == Self.detectedLosAngeles)
    }

    /// The purpose key has to exist in Info.plist, or iOS declines without
    /// showing anything. Tests run hosted in the app, so this is its plist.
    @Test("Info.plist: Precise on by default, a Compass purpose string, and a prompt that names the compass")
    func infoPlist() throws {
        let bundle = Bundle.main
        #expect(bundle.object(forInfoDictionaryKey: "NSLocationDefaultAccuracyReduced") == nil)

        let purposes = try #require(
            bundle.object(forInfoDictionaryKey: "NSLocationTemporaryUsageDescriptionDictionary") as? [String: String]
        )
        let purpose = try #require(purposes[LocationViewModel.compassPrecisePurposeKey])
        #expect(purpose.contains("We never see your location"))

        let prompt = try #require(bundle.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String)
        #expect(prompt.contains("compass"))
        #expect(prompt.contains("Precise Location"))
    }

    // MARK: - Targets follow the selected day

    @Test("Moonrise and moonset targets are the selected day's, from the table")
    func targetsFollowSelectedDay() async throws {
        let harness = Self.makeHarness()
        await harness.viewModel.start()
        let todayRise = try #require(harness.viewModel.compass.targets.first { $0.kind == .moonrise })

        harness.viewModel.nextDay()

        let table = try #require(harness.viewModel.moonTable?.moonDay)
        let tomorrowRise = try #require(harness.viewModel.compass.targets.first { $0.kind == .moonrise })
        #expect(tomorrowRise.azimuth == table.rise?.azimuth)
        #expect(tomorrowRise.azimuth != todayRise.azimuth)
    }

    @Test("The moon target only on today")
    func moonOnlyOnToday() async {
        let moon = FakeMoonService(
            rise: MoonEvent(date: Self.referenceDate, azimuth: 72),
            set: MoonEvent(date: Self.referenceDate, azimuth: 288),
            position: MoonPosition(azimuth: 140, isUp: true)
        )
        let harness = Self.makeHarness(moonService: moon)
        await harness.viewModel.start()
        #expect(harness.viewModel.compass.targets.map(\.kind).contains(.moon))

        harness.viewModel.nextDay()
        #expect(!harness.viewModel.compass.targets.map(\.kind).contains(.moon))

        harness.viewModel.previousDay()
        #expect(harness.viewModel.compass.targets.map(\.kind).contains(.moon))
    }

    /// The compass reads the table's `MoonDay`, so it adds no
    /// `moonDay(for:on:)` calls of its own. A rise and a set, so the table
    /// doesn't also look up the next day for "After midnight".
    @Test("The compass doesn't ask the moon service for the day again")
    func noExtraMoonDayCalls() async {
        let moon = FakeMoonService(
            rise: MoonEvent(date: Self.referenceDate, azimuth: 72),
            set: MoonEvent(date: Self.referenceDate, azimuth: 288)
        )
        let harness = Self.makeHarness(moonService: moon)

        await harness.viewModel.start()
        harness.viewModel.nextDay()

        #expect(moon.requestedDates.count == 2)
    }

    // MARK: - Scene lifecycle

    @Test("Background stops the compass sensors; foreground restarts them")
    func backgroundAndForeground() async {
        let harness = Self.makeHarness()
        await harness.viewModel.start()
        harness.viewModel.compass.setOnScreen(true)

        harness.viewModel.sceneDidEnterBackground()
        #expect(!harness.heading.isRunning)

        await harness.viewModel.sceneDidBecomeActive()
        #expect(harness.heading.isRunning)
    }
}
