//
//  OnboardingDebugTriggerTests.swift
//  moonbeam-appTests
//

#if DEBUG
import Foundation
import Testing
@testable import moonbeam_app

/// The DEBUG onboarding trigger (DECISIONS.md 2026-10-01): `-forceOnboarding`,
/// `-onboardingPage`, and the main screen's Show onboarding button
/// (`forceShow`). A forced run shows whatever the stored state says, and
/// never writes the store. DEBUG only, like the trigger.
@Suite("Onboarding DEBUG trigger")
@MainActor
struct OnboardingDebugTriggerTests {

    // MARK: - Fixtures

    private static let savedPlace = Place(
        name: "Los Angeles",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// Counts writes, so "never writes" means never, not "wrote the same
    /// value back".
    private final class RecordingOnboardingStore: OnboardingStore {
        private(set) var writeCount = 0
        var isOnboardingCompleted: Bool {
            didSet { writeCount += 1 }
        }
        var hasSeenFirstFindPass = true

        init(isOnboardingCompleted: Bool) {
            self.isOnboardingCompleted = isOnboardingCompleted
        }
    }

    private final class Outcomes {
        var received: [OnboardingViewModel.Outcome] = []
    }

    private struct Harness {
        let viewModel: OnboardingViewModel
        let location: FakeLocationService
        let store: RecordingOnboardingStore
        let outcomes: Outcomes
    }

    /// An existing install: saved place, permission decided, onboarding
    /// completed. Onboarding wouldn't show on its own.
    private static func makeExistingInstall(
        authorization: LocationAuthState = .authorized,
        isCompleted: Bool = true
    ) -> Harness {
        let location = FakeLocationService(authorizationState: authorization)
        let store = RecordingOnboardingStore(isOnboardingCompleted: isCompleted)
        let outcomes = Outcomes()
        let viewModel = OnboardingViewModel(
            locationService: location,
            placeStore: InMemoryPlaceStore(lastViewed: savedPlace),
            onboardingStore: store,
            onFinish: { outcomes.received.append($0) }
        )
        return Harness(viewModel: viewModel, location: location, store: store, outcomes: outcomes)
    }

    // MARK: - -forceOnboarding

    @Test("-forceOnboarding shows it on an existing install, on the landing")
    func forceShowsOnExistingInstall() {
        let harness = Self.makeExistingInstall()
        #expect(!harness.viewModel.isPresented)

        harness.viewModel.applyDebugLaunchArguments(["app", "-forceOnboarding"])

        #expect(harness.viewModel.isPresented)
        #expect(harness.viewModel.step == .landing)
        #expect(harness.store.writeCount == 0)
        // Show onboarding makes the next "Aha" a first one (LOADER.md §11.2.2).
        #expect(!harness.store.hasSeenFirstFindPass)
    }

    @Test("Without -forceOnboarding nothing changes")
    func noArgumentsNoChange() {
        let harness = Self.makeExistingInstall()

        harness.viewModel.applyDebugLaunchArguments(["app", "-onboardingPage", "upsell"])

        #expect(!harness.viewModel.isPresented)
    }

    // MARK: - -onboardingPage

    @Test("-onboardingPage picks the starting page", arguments: [
        ("landing", OnboardingViewModel.Step.landing),
        ("upsell", .locationUpsell),
        ("declined", .locationDeclined),
    ])
    func pageArgument(name: String, step: OnboardingViewModel.Step) {
        let harness = Self.makeExistingInstall(authorization: .denied)

        harness.viewModel.applyDebugLaunchArguments(["app", "-forceOnboarding", "-onboardingPage", name])

        #expect(harness.viewModel.step == step)
    }

    @Test("An unknown or missing page name is the landing", arguments: [
        ["app", "-forceOnboarding", "-onboardingPage", "settings"],
        ["app", "-forceOnboarding", "-onboardingPage"],
    ])
    func unknownPageIsLanding(arguments: [String]) {
        let harness = Self.makeExistingInstall()

        harness.viewModel.applyDebugLaunchArguments(arguments)

        #expect(harness.viewModel.step == .landing)
    }

    @Test("-onboardingPage alone picks the page of a natural first run")
    func pageOnNaturalRun() {
        let viewModel = OnboardingViewModel(
            locationService: FakeLocationService(),
            placeStore: InMemoryPlaceStore(),
            onboardingStore: InMemoryOnboardingStore()
        )

        viewModel.applyDebugLaunchArguments(["app", "-onboardingPage", "upsell"])

        #expect(viewModel.isPresented)
        #expect(viewModel.step == .locationUpsell)
    }

    // MARK: - No stored state

    @Test("Every exit from a forced run leaves the completed flag unwritten", arguments: [false, true])
    func forcedExitsNeverWrite(isCompleted: Bool) async {
        // Got it.
        let declined = Self.makeExistingInstall(authorization: .denied, isCompleted: isCompleted)
        declined.viewModel.forceShow(startingAt: .locationDeclined)
        declined.viewModel.gotIt()

        // Search instead.
        let search = Self.makeExistingInstall(isCompleted: isCompleted)
        search.viewModel.forceShow(startingAt: .locationUpsell)
        search.viewModel.searchInstead()

        // Use my location, already allowed: no prompt is needed.
        let allowed = Self.makeExistingInstall(isCompleted: isCompleted)
        allowed.viewModel.forceShow(startingAt: .locationUpsell)
        await allowed.viewModel.useMyLocation()

        for harness in [declined, search, allowed] {
            #expect(!harness.viewModel.isPresented)
            #expect(harness.store.writeCount == 0)
            #expect(harness.store.isOnboardingCompleted == isCompleted)
        }
        #expect(declined.outcomes.received == [.locationDeclined])
        #expect(search.outcomes.received == [.searchInstead])
        #expect(allowed.outcomes.received == [.locationAllowed])
    }

    @Test("-onboardingPage alone isn't forced: finishing a natural run still marks completed")
    func pageAloneStillWrites() {
        let store = RecordingOnboardingStore(isOnboardingCompleted: false)
        let viewModel = OnboardingViewModel(
            locationService: FakeLocationService(),
            placeStore: InMemoryPlaceStore(),
            onboardingStore: store
        )
        viewModel.applyDebugLaunchArguments(["app", "-onboardingPage", "upsell"])

        viewModel.searchInstead()

        #expect(store.isOnboardingCompleted)
        #expect(store.writeCount == 1)
    }

    // MARK: - The Show onboarding button

    @Test("Show onboarding reopens it after it was left, from the landing")
    func buttonReopens() {
        let harness = Self.makeExistingInstall()
        harness.viewModel.forceShow()
        harness.viewModel.getStarted()
        harness.viewModel.searchInstead()
        #expect(!harness.viewModel.isPresented)

        harness.viewModel.forceShow()

        #expect(harness.viewModel.isPresented)
        #expect(harness.viewModel.step == .landing)
        #expect(harness.store.writeCount == 0)
    }

    // MARK: - "That's okay" while allowed

    @Test("Forced \"That's okay\" with location allowed stays up when the scene becomes active")
    func forcedDeclinedHoldsWhileAuthorized() {
        let harness = Self.makeExistingInstall(authorization: .authorized)
        harness.viewModel.forceShow(startingAt: .locationDeclined)

        harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.isPresented)
        #expect(harness.viewModel.step == .locationDeclined)
    }

    @Test("Forced run: denied at the prompt, then allowed in Settings, still returns to the app")
    func forcedSettingsReturnStillWorks() async {
        let harness = Self.makeExistingInstall(authorization: .notDetermined)
        harness.location.stateAfterRequest = .denied
        harness.viewModel.forceShow(startingAt: .locationUpsell)
        await harness.viewModel.useMyLocation()
        #expect(harness.viewModel.step == .locationDeclined)

        harness.location.authorizationState = .authorized
        harness.viewModel.sceneDidBecomeActive()

        #expect(!harness.viewModel.isPresented)
        #expect(harness.outcomes.received == [.locationAllowed])
        #expect(harness.store.writeCount == 0)
    }
}
#endif
