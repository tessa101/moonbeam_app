//
//  OnboardingViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// Onboarding routing (DESIGN-1.1.md §5, §8): when it shows, and where
/// Allow, Don't Allow, Search instead and a return from Settings lead.
/// Authorization comes from `FakeLocationService`, so no test reaches the
/// system alert.
@Suite("Onboarding view model")
@MainActor
struct OnboardingViewModelTests {

    // MARK: - Fixtures

    private static let savedPlace = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// Collects `onFinish` calls.
    private final class Outcomes {
        var received: [OnboardingViewModel.Outcome] = []
    }

    private static func makeViewModel(
        location: FakeLocationService = FakeLocationService(),
        placeStore: InMemoryPlaceStore = InMemoryPlaceStore(),
        onboardingStore: InMemoryOnboardingStore = InMemoryOnboardingStore(),
        outcomes: Outcomes = Outcomes()
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            locationService: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore,
            onFinish: { outcomes.received.append($0) }
        )
    }

    /// Onboarding taken to the upsell, as a tap on Get started does.
    private static func makeViewModelAtUpsell(
        location: FakeLocationService,
        onboardingStore: InMemoryOnboardingStore = InMemoryOnboardingStore(),
        outcomes: Outcomes = Outcomes()
    ) -> OnboardingViewModel {
        let viewModel = makeViewModel(location: location, onboardingStore: onboardingStore, outcomes: outcomes)
        viewModel.getStarted()
        return viewModel
    }

    // MARK: - When it shows

    @Test("Shows on a new install: no saved place, permission not determined, not completed")
    func showsOnNewInstall() {
        let viewModel = Self.makeViewModel()

        #expect(viewModel.isPresented)
        #expect(viewModel.step == .landing)
    }

    @Test("Skipped with a saved place")
    func skippedWithSavedPlace() {
        let viewModel = Self.makeViewModel(placeStore: InMemoryPlaceStore(lastViewed: Self.savedPlace))

        #expect(!viewModel.isPresented)
    }

    @Test("Skipped once permission has been decided", arguments: [
        LocationAuthState.authorized, .denied, .restricted, .servicesOff
    ])
    func skippedOncePermissionDecided(state: LocationAuthState) {
        let viewModel = Self.makeViewModel(location: FakeLocationService(authorizationState: state))

        #expect(!viewModel.isPresented)
    }

    @Test("Skipped once completed")
    func skippedOnceCompleted() {
        let viewModel = Self.makeViewModel(onboardingStore: InMemoryOnboardingStore(isOnboardingCompleted: true))

        #expect(!viewModel.isPresented)
    }

    @Test("Shows only when all three conditions hold", arguments: [false, true], [false, true])
    func showRule(hasSavedPlace: Bool, isCompleted: Bool) {
        let shows = OnboardingViewModel.shouldShow(
            hasSavedPlace: hasSavedPlace,
            authorizationState: .notDetermined,
            isCompleted: isCompleted
        )

        #expect(shows == (!hasSavedPlace && !isCompleted))
    }

    /// It runs in `App.init`, before the first frame (LOADER.md §9).
    @Test("An existing install decides without reading the permission", arguments: [(true, false), (false, true)])
    func existingInstallSkipsPermissionRead(hasSavedPlace: Bool, isCompleted: Bool) {
        var reads = 0
        let shows = OnboardingViewModel.shouldShow(
            hasSavedPlace: hasSavedPlace,
            authorizationState: {
                reads += 1
                return .notDetermined
            }(),
            isCompleted: isCompleted
        )

        #expect(!shows)
        #expect(reads == 0)
    }

    // MARK: - The prompt only comes from a tap

    @Test("Launch and Get started never prompt; Get started shows the upsell")
    func noPromptBeforeTap() {
        let location = FakeLocationService()
        let viewModel = Self.makeViewModel(location: location)

        viewModel.getStarted()

        #expect(viewModel.step == .locationUpsell)
        #expect(!location.didRequestAuthorization)
    }

    // MARK: - Allow

    @Test("Allow goes to the main screen and marks onboarding completed")
    func allowFinishes() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .authorized
        let store = InMemoryOnboardingStore()
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, onboardingStore: store, outcomes: outcomes)

        await viewModel.useMyLocation()

        #expect(location.requestAuthorizationCount == 1)
        #expect(outcomes.received == [.locationAllowed])
        #expect(!viewModel.isPresented)
        #expect(store.isOnboardingCompleted)
    }

    // MARK: - Don't Allow

    @Test("Don't Allow shows \"That's okay\" and stays in onboarding")
    func dontAllowShowsThatsOkay() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, outcomes: outcomes)

        await viewModel.useMyLocation()

        #expect(viewModel.step == .locationDeclined)
        #expect(viewModel.isPresented)
        #expect(outcomes.received.isEmpty)
    }

    @Test("Got it goes to the main screen's empty state and marks onboarding completed")
    func gotItFinishes() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let store = InMemoryOnboardingStore()
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, onboardingStore: store, outcomes: outcomes)
        await viewModel.useMyLocation()

        viewModel.gotIt()

        #expect(outcomes.received == [.locationDeclined])
        #expect(!viewModel.isPresented)
        #expect(store.isOnboardingCompleted)
    }

    @Test("A prompt dismissed unanswered stays on the upsell")
    func unansweredPromptStays() async {
        let location = FakeLocationService()
        let viewModel = Self.makeViewModelAtUpsell(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.step == .locationUpsell)
        #expect(viewModel.isPresented)
    }

    // MARK: - Search instead

    @Test("Search instead goes to the main screen with no prompt, and marks onboarding completed")
    func searchInsteadFinishes() {
        let location = FakeLocationService()
        let store = InMemoryOnboardingStore()
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, onboardingStore: store, outcomes: outcomes)

        viewModel.searchInstead()

        #expect(outcomes.received == [.searchInstead])
        #expect(!location.didRequestAuthorization)
        #expect(!viewModel.isPresented)
        #expect(store.isOnboardingCompleted)
    }

    @Test("After Search instead, a relaunch with nothing saved skips onboarding")
    func relaunchAfterSearchInsteadSkips() {
        let location = FakeLocationService()
        let placeStore = InMemoryPlaceStore()
        let store = InMemoryOnboardingStore()
        Self.makeViewModelAtUpsell(location: location, onboardingStore: store).searchInstead()

        let relaunched = Self.makeViewModel(location: location, placeStore: placeStore, onboardingStore: store)

        #expect(!relaunched.isPresented)
    }

    // MARK: - Back from Settings (Enable location)

    @Test("Back from Settings authorized: on to the main screen, as for Allow")
    func settingsReturnAuthorizedFinishes() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let store = InMemoryOnboardingStore()
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, onboardingStore: store, outcomes: outcomes)
        await viewModel.useMyLocation()

        location.authorizationState = .authorized
        viewModel.sceneDidBecomeActive()

        #expect(outcomes.received == [.locationAllowed])
        #expect(!viewModel.isPresented)
        #expect(store.isOnboardingCompleted)
    }

    @Test("Back from Settings still denied: stays on \"That's okay\"")
    func settingsReturnDeniedStays() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, outcomes: outcomes)
        await viewModel.useMyLocation()

        viewModel.sceneDidBecomeActive()

        #expect(viewModel.step == .locationDeclined)
        #expect(viewModel.isPresented)
        #expect(outcomes.received.isEmpty)
    }

    @Test("Becoming active on another screen changes nothing")
    func activeElsewhereIgnored() {
        let location = FakeLocationService()
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModel(location: location, outcomes: outcomes)

        viewModel.sceneDidBecomeActive()
        viewModel.getStarted()
        viewModel.sceneDidBecomeActive()

        #expect(viewModel.step == .locationUpsell)
        #expect(outcomes.received.isEmpty)
    }

    @Test("Finishes once: a second exit doesn't report again")
    func finishesOnce() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModelAtUpsell(location: location, outcomes: outcomes)
        await viewModel.useMyLocation()

        viewModel.gotIt()
        location.authorizationState = .authorized
        viewModel.sceneDidBecomeActive()

        #expect(outcomes.received == [.locationDeclined])
    }

    // MARK: - Location Services off / already denied (DECISIONS.md 2026-10-01)

    /// On the upsell with location already in `state`, as a forced run or a
    /// device whose state changed after launch would have it.
    private static func makeViewModelAtUpsell(
        startingIn state: LocationAuthState,
        outcomes: Outcomes = Outcomes()
    ) -> (OnboardingViewModel, FakeLocationService) {
        let location = FakeLocationService()
        let viewModel = makeViewModelAtUpsell(location: location, outcomes: outcomes)
        location.authorizationState = state
        return (viewModel, location)
    }

    @Test("Services off or already denied before the tap: Settings once, no prompt, upsell stays", arguments: [
        LocationAuthState.servicesOff, .denied,
    ])
    func noPromptPossibleOpensSettings(state: LocationAuthState) async {
        let outcomes = Outcomes()
        let (viewModel, location) = Self.makeViewModelAtUpsell(startingIn: state, outcomes: outcomes)

        await viewModel.useMyLocation()

        #expect(viewModel.settingsRequestCount == 1)
        #expect(location.requestAuthorizationCount == 0)
        #expect(viewModel.step == .locationUpsell)
        #expect(viewModel.isPresented)
        #expect(outcomes.received.isEmpty)
    }

    @Test("Services off reported after the request: Settings, upsell stays")
    func servicesOffAfterRequestOpensSettings() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .servicesOff
        let viewModel = Self.makeViewModelAtUpsell(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.settingsRequestCount == 1)
        #expect(viewModel.step == .locationUpsell)
    }

    @Test("A real Don't Allow still shows \"That's okay\", without opening Settings")
    func realDontAllowUnchanged() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let viewModel = Self.makeViewModelAtUpsell(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.step == .locationDeclined)
        #expect(viewModel.settingsRequestCount == 0)
    }

    @Test("Restricted keeps \"That's okay\": Settings can't fix it")
    func restrictedKeepsThatsOkay() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .restricted
        let viewModel = Self.makeViewModelAtUpsell(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.step == .locationDeclined)
        #expect(viewModel.settingsRequestCount == 0)
    }

    @Test("Back from Settings authorized: main screen as for Allow, completed", arguments: [
        LocationAuthState.servicesOff, .denied,
    ])
    func upsellSettingsReturnAuthorized(state: LocationAuthState) async {
        let store = InMemoryOnboardingStore()
        let outcomes = Outcomes()
        let location = FakeLocationService()
        let viewModel = Self.makeViewModelAtUpsell(location: location, onboardingStore: store, outcomes: outcomes)
        location.authorizationState = state
        await viewModel.useMyLocation()

        location.authorizationState = .authorized
        viewModel.sceneDidBecomeActive()

        #expect(!viewModel.isPresented)
        #expect(outcomes.received == [.locationAllowed])
        #expect(store.isOnboardingCompleted)
    }

    @Test("Back from Settings still off: upsell stays, and Use my location opens Settings again")
    func upsellSettingsReturnStillOff() async {
        let (viewModel, _) = Self.makeViewModelAtUpsell(startingIn: .servicesOff)
        await viewModel.useMyLocation()

        viewModel.sceneDidBecomeActive()
        #expect(viewModel.isPresented)
        #expect(viewModel.step == .locationUpsell)

        await viewModel.useMyLocation()
        #expect(viewModel.settingsRequestCount == 2)
    }

    @Test("The upsell doesn't leave on its own when authorized without a trip to Settings")
    func upsellNoSettingsTripStays() {
        let location = FakeLocationService()
        let viewModel = Self.makeViewModelAtUpsell(location: location)
        location.authorizationState = .authorized

        viewModel.sceneDidBecomeActive()

        #expect(viewModel.isPresented)
        #expect(viewModel.step == .locationUpsell)
    }

    // MARK: - Forced run, Release too (DECISIONS.md 2026-10-01 "TestFlight")

    /// What the Show onboarding button does in a TestFlight build: not
    /// DEBUG-only, so tested here as well as in `OnboardingDebugTriggerTests`.
    @Test("A forced run from the button shows it and finishes without writing the completed flag")
    func forceShowWritesNothing() {
        let store = InMemoryOnboardingStore(isOnboardingCompleted: true)
        let outcomes = Outcomes()
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(authorizationState: .authorized),
            placeStore: InMemoryPlaceStore(lastViewed: Self.savedPlace),
            onboardingStore: store,
            outcomes: outcomes
        )
        #expect(!viewModel.isPresented)
        store.isOnboardingCompleted = false

        viewModel.forceShow()
        #expect(viewModel.isPresented)
        #expect(viewModel.step == .landing)
        viewModel.getStarted()
        viewModel.searchInstead()

        #expect(!viewModel.isPresented)
        #expect(outcomes.received == [.searchInstead])
        #expect(!store.isOnboardingCompleted)
    }
}
