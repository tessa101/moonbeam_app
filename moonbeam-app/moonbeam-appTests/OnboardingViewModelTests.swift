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
}
