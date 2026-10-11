//
//  LocationFailureWiringTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// STEP-5.10a-LOCATION-FAILURE.md, Chunk 3: the failure screen in place of
/// the main content, the return from Settings, No fix's look on return and
/// Enter a city.
/// Recovery runs the existing loader → Aha (Tessa, 2026-10-10).
@Suite("Location failure wiring", .timeLimit(.minutes(1)))
@MainActor
struct LocationFailureWiringTests {

    // MARK: - Fixtures

    private static let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private static let detected = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: zone,
        isCurrentLocation: true
    )

    private static let saved = Place(
        name: "Sydney",
        region: "NSW",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    private static let entered = Place(
        name: "San Diego",
        region: "CA",
        latitude: 32.72,
        longitude: -117.16,
        timeZone: zone
    )

    private static let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func makeViewModel(location: FakeLocationService, lastViewed: Place? = nil) -> LocationViewModel {
        LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: lastViewed),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            deviceTimeZone: zone,
            now: { reference },
            // Loader, Aha and skeleton waits pass at once.
            sleep: { _ in },
            placeChangeSleep: { _ in },
            loaderNow: { reference }
        )
    }

    /// Ready on the saved place, then Use my location fails for `state`
    /// (or, authorized, for a fix that doesn't come).
    private static func makeFailedViewModel(
        _ state: LocationAuthState,
        location: FakeLocationService? = nil
    ) async -> (LocationViewModel, FakeLocationService) {
        let location = location ?? FakeLocationService(
            authorizationState: state,
            placeResult: .failure(LocationError.locationUnavailable)
        )
        let viewModel = makeViewModel(location: location, lastViewed: saved)
        await viewModel.start()
        await viewModel.useMyLocation()
        return (viewModel, location)
    }

    /// Stops on cancellation, so the suite's time limit can end it.
    private static func waitUntil(_ condition: () -> Bool) async {
        while !condition(), !Task.isCancelled {
            await Task.yield()
        }
    }

    // MARK: - Showing it

    @Test(
        "A failed Use my location on the main screen shows the failure screen; Open Settings only for denied and services off",
        arguments: [
            (LocationAuthState.denied, LocationFailure.permissionDenied, true),
            (.servicesOff, .servicesOff, true),
            (.restricted, .restricted, false),
            (.authorized, .noFix, false),
        ]
    )
    func showsFailureScreen(state: LocationAuthState, failure: LocationFailure, offersSettings: Bool) async {
        let (viewModel, _) = await Self.makeFailedViewModel(state)

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.failureScreen == failure)
        #expect((viewModel.failureScreen?.primaryAction == .openSettings) == offersSettings)
    }

    @Test("Main screen, permission off: the failure screen replaces the Location Off dialog", arguments: [
        LocationAuthState.denied, .servicesOff, .restricted,
    ])
    func noDialogOnMainScreen(state: LocationAuthState) async {
        let (viewModel, _) = await Self.makeFailedViewModel(state)
        #expect(viewModel.locationOffDialog == nil)
    }

    @Test("The compass's Turn On Location keeps its dialog, and no failure screen")
    func compassKeepsDialog() async {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = Self.makeViewModel(location: location, lastViewed: Self.saved)
        await viewModel.start()

        await viewModel.turnOnLocationForCompass()

        #expect(viewModel.locationOffDialog == .denied)
        #expect(viewModel.failureScreen == nil)
        #expect(viewModel.place == Self.saved)
    }

    @Test("A launch with no saved place opens the same failure screen, not the loader moon's message")
    func launchOpensFailureScreen() async {
        let viewModel = Self.makeViewModel(location: FakeLocationService(authorizationState: .denied))
        await viewModel.start()

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.failureScreen == .permissionDenied)
        #expect(viewModel.loaderIssue == nil)
    }

    // MARK: - Back from Settings

    @Test("Back from Settings with access granted: the screen goes, one fix, then Aha and the moon flies into the card")
    func backFromSettingsRecovers() async {
        let (viewModel, location) = await Self.makeFailedViewModel(.denied)
        #expect(viewModel.failureScreen == .permissionDenied)
        let fixesBefore = location.currentPlaceCount

        location.authorizationState = .authorized
        location.placeResult = .success(Self.detected)
        location.holdsFixes = true
        let foreground = Task { await viewModel.sceneDidBecomeActive() }
        await Self.waitUntil { location.heldFixCount > 0 }

        // The failure screen is gone at once and the loader is up.
        #expect(viewModel.failureScreen == nil)
        #expect(viewModel.launchStage == .phaseCycle)
        // A second foreground meanwhile doesn't start another fix.
        await viewModel.sceneDidBecomeActive()
        #expect(location.heldFixCount == 1)

        location.releaseFixes()
        await foreground.value

        #expect(location.currentPlaceCount == fixesBefore + 1)
        #expect(viewModel.place == Self.detected)
        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.loader.flightStartedAt != nil)
        #expect(viewModel.failureScreen == nil)
    }

    @Test("Back from Settings still off: the failure screen stays, with no fix")
    func backFromSettingsStillOff() async {
        let (viewModel, location) = await Self.makeFailedViewModel(.denied)
        let fixesBefore = location.currentPlaceCount

        await viewModel.sceneDidBecomeActive()

        #expect(viewModel.failureScreen == .permissionDenied)
        #expect(location.currentPlaceCount == fixesBefore)
    }

    @Test("Back from Settings with a different reason: the screen changes to it")
    func backFromSettingsDifferentReason() async {
        let (viewModel, location) = await Self.makeFailedViewModel(.denied)

        location.authorizationState = .servicesOff
        await viewModel.sceneDidBecomeActive()

        #expect(viewModel.failureScreen == .servicesOff)
    }

    // MARK: - No fix looks again (Chunk 2b, superseding §3 row 10)

    @Test("No fix, back in the app: the loader, one fix, then Aha into the card")
    func foregroundRetryRecovers() async {
        let (viewModel, location) = await Self.makeFailedViewModel(.authorized)
        let fixesBefore = location.currentPlaceCount
        location.placeResult = .success(Self.detected)

        await viewModel.sceneDidBecomeActive()

        #expect(location.currentPlaceCount == fixesBefore + 1)

        #expect(viewModel.place == Self.detected)
        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.loader.flightStartedAt != nil)
        #expect(viewModel.failureScreen == nil)
    }

    @Test("No fix, back in the app, still nothing: the failure screen comes back")
    func foregroundRetryFailsAgain() async {
        let (viewModel, _) = await Self.makeFailedViewModel(.authorized)

        await viewModel.sceneDidBecomeActive()

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.failureScreen == .noFix)
        #expect(viewModel.place == nil)
    }

    @Test("Two activations while No fix looks again: one fix, no stacking")
    func foregroundRetryDoesNotStack() async {
        let (viewModel, location) = await Self.makeFailedViewModel(.authorized)
        let fixesBefore = location.currentPlaceCount
        location.placeResult = .success(Self.detected)
        location.holdsFixes = true

        let first = Task { await viewModel.sceneDidBecomeActive() }
        await Self.waitUntil { location.heldFixCount > 0 }
        await viewModel.sceneDidBecomeActive()
        #expect(location.heldFixCount == 1)

        location.releaseFixes()
        await first.value
        #expect(location.currentPlaceCount == fixesBefore + 1)
        #expect(viewModel.place == Self.detected)
    }

    // MARK: - Foreground during Use my location

    @Test("A foreground's quiet detection retry doesn't cancel an in-flight Use my location")
    func foregroundRetryDoesNotCancelUseMyLocation() async {
        // Authorized, but the launch fix fails: the saved place opens and
        // nothing is detected, so a foreground would retry quietly (4.8).
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .failure(LocationError.locationUnavailable)
        )
        let viewModel = Self.makeViewModel(location: location, lastViewed: Self.saved)
        await viewModel.start()
        #expect(viewModel.place == Self.saved)
        location.placeResult = .success(Self.detected)
        let fixesBefore = location.currentPlaceCount

        // Queued back to back on the main actor, as traced in the app
        // (DECISIONS.md 2026-10-10): Use my location runs to `locate()`,
        // which queues its fix task; the foreground runs before that task
        // starts, while the replacement is pending and nothing is locating.
        let locate = Task { await viewModel.useMyLocation() }
        let foreground = Task { await viewModel.sceneDidBecomeActive() }
        await locate.value
        await foreground.value

        // The user's fix wasn't cancelled and the retry didn't start one;
        // their place landed.
        #expect(location.currentPlaceCount == fixesBefore + 1)
        #expect(location.cancelledFixCount == 0)
        #expect(viewModel.place == Self.detected)
        #expect(viewModel.cardPlaceholder == nil)
        #expect(viewModel.failureScreen == nil)
    }

    // MARK: - Search sheet

    @Test("Restricted: the search sheet has no Use my location row; denied keeps it", arguments: [
        (LocationAuthState.restricted, false),
        (.denied, true),
    ])
    func useMyLocationRowWhenRestricted(state: LocationAuthState, shows: Bool) async throws {
        let (viewModel, _) = await Self.makeFailedViewModel(state)

        viewModel.presentSearch()

        let sheet = try #require(viewModel.searchSheet)
        #expect(sheet.showsUseMyLocation == shows)
    }

    @Test("A launch with no saved place and restricted: its Search for a city has no Use my location row")
    func restrictedLaunchSearchHasNoRow() async throws {
        let viewModel = Self.makeViewModel(location: FakeLocationService(authorizationState: .restricted))
        await viewModel.start()
        #expect(viewModel.failureScreen == .restricted)

        // The screen's primary: `LocationFailureView` calls `onSearch`.
        viewModel.presentSearch()

        let sheet = try #require(viewModel.searchSheet)
        #expect(!sheet.showsUseMyLocation)
    }

    // MARK: - Enter a city

    @Test("Enter a city: the failure clears and the §12 place-change load-in plays; the old place stays out")
    func enterCityLoadsIn() async {
        let (viewModel, _) = await Self.makeFailedViewModel(.denied)
        let generation = viewModel.loadInGeneration
        let cardGeneration = viewModel.cardLoadInGeneration

        viewModel.presentSearch()
        #expect(viewModel.isSearchPresented)
        viewModel.select(Self.entered)

        #expect(viewModel.failureScreen == nil)
        #expect(viewModel.locationFailure == nil)
        #expect(viewModel.place == Self.entered)
        #expect(viewModel.loadInGeneration == generation + 1)
        #expect(viewModel.cardLoadInGeneration == cardGeneration + 1)
        #expect(viewModel.launchStage == .ready)
    }
}
