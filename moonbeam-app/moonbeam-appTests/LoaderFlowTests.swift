//
//  LoaderFlowTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Foundation
import Testing
@testable import moonbeam_app

/// The location flow (LOADER.md §10.1, §10.3;
/// STEP-5.10a-LOCATION-CONSOLIDATION.md §3): with no saved place the loader
/// stops on First ask, and a cause opens its failure screen; their buttons,
/// Settings and No fix's look on return bring it back to searching; a pick
/// or a fix ends it.
@Suite("Loader flow", .timeLimit(.minutes(1)))
@MainActor
struct LoaderFlowTests {

    // MARK: - Fixtures

    private static let detected = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
        isCurrentLocation: true
    )

    private static let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Records every wait and returns at once.
    @MainActor
    private final class RecordingSleeper {
        private(set) var durations: [Duration] = []
        func sleep(_ duration: Duration) {
            durations.append(duration)
        }
    }

    /// A stand-in for `Task.sleep` that the test fires by hand.
    @MainActor
    private final class ManualSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []
        var pendingCount: Int { waiters.count }

        func sleep(_ duration: Duration) async throws {
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }
    }

    private struct Harness {
        let viewModel: LocationViewModel
        let location: FakeLocationService
        let store: InMemoryPlaceStore
        let sleeper: RecordingSleeper
        let onboardingStore: InMemoryOnboardingStore
    }

    private static func makeHarness(
        _ state: LocationAuthState,
        lastViewed: Place? = nil,
        placeResult: Result<Place, any Error> = .success(detected),
        hasSeenFirstFindPass: Bool = false,
        reducesMotion: Bool = false
    ) -> Harness {
        let location = FakeLocationService(authorizationState: state, placeResult: placeResult)
        let store = InMemoryPlaceStore(lastViewed: lastViewed)
        let sleeper = RecordingSleeper()
        let onboardingStore = InMemoryOnboardingStore(hasSeenFirstFindPass: hasSeenFirstFindPass)
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: store,
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            onboardingStore: onboardingStore,
            reducesMotion: { reducesMotion },
            now: { reference },
            sleep: { [sleeper] duration in await sleeper.sleep(duration) },
            loaderNow: { reference }
        )
        return Harness(
            viewModel: viewModel,
            location: location,
            store: store,
            sleeper: sleeper,
            onboardingStore: onboardingStore
        )
    }

    private static func settle(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    // MARK: - Which destination (§10.1; STEP-5.10a-LOCATION-CONSOLIDATION.md §2–3)

    /// The minimum search before a failure, as `LocationLoader` asks for it
    /// with a clock that doesn't move.
    private static let searchMinimum = Duration.seconds(LocationLoader.minimumSearchBeforeMessage)

    @Test("No saved place, never asked: the loader stops on First ask")
    func firstAskOnLoader() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .phaseCycle)
        #expect(harness.viewModel.loaderIssue == .firstAsk)
        #expect(harness.viewModel.failureScreen == nil)
        #expect(harness.viewModel.place == nil)
        #expect(!harness.location.didRequestAuthorization)
        #expect(harness.location.currentPlaceCount == 0)
    }

    /// §3 row 1: known blocked, so no searching and no minimum.
    @Test(
        "No saved place, access blocked: its failure screen at once, no searching wait",
        arguments: [
            (LocationAuthState.denied, LocationFailure.permissionDenied),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
        ]
    )
    func blockedLaunchOpensFailureScreen(state: LocationAuthState, failure: LocationFailure) async {
        let harness = Self.makeHarness(state)
        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == failure)
        #expect(harness.viewModel.loaderIssue == nil)
        #expect(harness.viewModel.place == nil)
        #expect(!harness.sleeper.durations.contains(Self.searchMinimum))
        #expect(!harness.location.didRequestAuthorization)
        #expect(harness.location.currentPlaceCount == 0)
    }

    /// §3 row 2: a search ran, so it shows at least the minimum, even when
    /// the fix failed at once (inside the 400 ms grace).
    @Test(
        "Authorized but no fix, nothing saved: searching for the minimum, then the No fix screen",
        arguments: [LocationError.locationUnavailable, .couldNotIdentifyPlace]
    )
    func noFix(error: LocationError) async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(error))
        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == .noFix)
        #expect(harness.viewModel.loaderIssue == nil)
        #expect(harness.sleeper.durations.contains(Self.searchMinimum))
        #expect(harness.viewModel.loader.appearedAt == Self.reference)
    }

    @Test("A launch failure screen and an explicit request's are the same screen", arguments: [
        (LocationAuthState.denied, LocationFailure.permissionDenied),
        (.servicesOff, .servicesOff),
        (.restricted, .restricted),
        (.authorized, .noFix),
    ])
    func launchAndExplicitMatch(state: LocationAuthState, failure: LocationFailure) async {
        let result: Result<Place, any Error> = failure == .noFix
            ? .failure(LocationError.locationUnavailable)
            : .success(Self.detected)
        let launch = Self.makeHarness(state, placeResult: result)
        await launch.viewModel.start()
        let explicit = Self.makeHarness(state, lastViewed: Place.marVista, placeResult: result)
        await explicit.viewModel.start()
        await explicit.viewModel.useMyLocation()

        #expect(launch.viewModel.failureScreen == failure)
        #expect(explicit.viewModel.failureScreen == launch.viewModel.failureScreen)
        #expect(explicit.viewModel.failureScreen?.copy == launch.viewModel.failureScreen?.copy)
        #expect(explicit.viewModel.locationOffDialog == nil)
    }

    @Test("Search row dismissal reaches the matching destination without a dialog", arguments: [
        (LocationAuthState.denied, LocationFailure.permissionDenied),
        (.servicesOff, .servicesOff),
        (.authorized, .noFix),
    ])
    func searchRowBlockedDestinations(state: LocationAuthState, failure: LocationFailure) async throws {
        let harness = Self.makeHarness(state, lastViewed: Place.marVista,
            placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.viewModel.presentSearch()
        let sheet = try #require(harness.viewModel.searchSheet)
        #expect(sheet.showsUseMyLocation)
        sheet.useMyLocation()
        #expect(!harness.viewModel.isSearchPresented)
        await harness.viewModel.searchDidDismiss()

        #expect(harness.viewModel.failureScreen == failure)
        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(harness.viewModel.place == nil)
        #expect(harness.viewModel.loaderIssue == nil)
    }

    @Test(
        "A saved place opens directly, whatever the issue",
        arguments: [LocationAuthState.notDetermined, .denied, .servicesOff, .restricted]
    )
    func savedPlaceWins(state: LocationAuthState) async {
        let harness = Self.makeHarness(state, lastViewed: Place.marVista)
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Place.marVista)
        #expect(harness.viewModel.loaderIssue == nil)
        #expect(harness.viewModel.failureScreen == nil)
    }

    @Test("A saved place opens when the fix fails, too")
    func savedPlaceWinsOverNoFix() async {
        let harness = Self.makeHarness(
            .authorized,
            lastViewed: Place.marVista,
            placeResult: .failure(LocationError.locationUnavailable)
        )
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Place.marVista)
        #expect(harness.viewModel.failureScreen == nil)
    }

    // MARK: - Forget saved place (DEBUG / TestFlight, temporary)

    @Test("Forget saved place: last-viewed and recents cleared, then the launch's failure screen")
    func forgetSavedPlaceShowsFailure() async {
        let harness = Self.makeHarness(.denied, lastViewed: Place.marVista)
        harness.store.addRecent(Place.marVista)
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)

        await harness.viewModel.forgetSavedPlace()

        #expect(harness.store.lastViewed == nil)
        #expect(harness.store.recents.isEmpty)
        #expect(harness.viewModel.place == nil)
        #expect(harness.viewModel.moonTable == nil)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == .permissionDenied)
    }

    // MARK: - Chunk 2c item 3: two device checks

    /// 3a: First ask never needs the network or a fix. The cat there needs
    /// an authorized state (an Allow Once still active), not Ask.
    @Test("3a: not determined, no saved city, offline and a failing fix: First ask, no fix tried")
    func notDeterminedOfflineIsFirstAsk() async {
        let location = FakeLocationService(
            authorizationState: .notDetermined,
            placeResult: .failure(LocationError.couldNotIdentifyPlace)
        )
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            connectivity: FakeConnectivityService(isOnline: false),
            now: { Self.reference },
            sleep: { _ in },
            loaderNow: { Self.reference }
        )
        await viewModel.start()

        #expect(viewModel.loaderIssue == .firstAsk)
        #expect(viewModel.failureScreen == nil)
        #expect(location.currentPlaceCount == 0)
    }

    @Test("3a: the same launch, authorized (Allow Once still active) and offline: the cat")
    func allowOnceOfflineIsNoFix() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.couldNotIdentifyPlace))
        await harness.viewModel.start()
        #expect(harness.viewModel.failureScreen == .noFix)
    }

    /// 3b order 1: Never already set, then Forget saved place (or a launch
    /// with no saved city): the telescope at once, never First ask.
    @Test("3b order 1: Never set first, then Forget saved place: the telescope directly")
    func neverThenForgetIsTelescope() async {
        let harness = Self.makeHarness(.denied, lastViewed: Place.marVista)
        await harness.viewModel.start()

        await harness.viewModel.forgetSavedPlace()

        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.viewModel.loaderIssue == nil)
        // The loader never stopped on a message on the way.
        #expect(harness.viewModel.loader.content == .searching)
        #expect(!harness.sleeper.durations.contains(Self.searchMinimum))
    }

    /// 3b order 2: First ask is up (Ask Next Time, or an expired Allow
    /// Once), then Never in Settings, then back: First ask until the
    /// return, then the telescope.
    @Test("3b order 2: Forget saved place on First ask, then Never in Settings, back: the telescope")
    func forgetThenNeverIsTelescope() async {
        let harness = Self.makeHarness(.notDetermined, lastViewed: Place.marVista)
        await harness.viewModel.start()

        await harness.viewModel.forgetSavedPlace()
        #expect(harness.viewModel.loaderIssue == .firstAsk)

        harness.location.authorizationState = .denied
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.viewModel.loaderIssue == nil)
        #expect(!harness.location.didRequestAuthorization)
    }

    @Test("Forget saved place, authorized: the launch finds you again")
    func forgetSavedPlaceRelocates() async {
        let harness = Self.makeHarness(.authorized, lastViewed: Place.marVista)
        await harness.viewModel.start()
        let fixesBefore = harness.location.currentPlaceCount

        await harness.viewModel.forgetSavedPlace()

        #expect(harness.location.currentPlaceCount == fixesBefore + 1)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.store.recents.isEmpty)
    }

    // MARK: - First ask (§10.3; §3 rows 4 and 11)

    @Test("On First ask: label gone, moon frozen at the hold phase, glow pulsing")
    func messageState() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        #expect(harness.sleeper.durations.contains(Self.searchMinimum))
        let loader = harness.viewModel.loader
        #expect(!loader.showsLabel)
        #expect(loader.glow.mode == .pulse)
        let later = Self.reference.addingTimeInterval(10)
        #expect(abs(loader.moon.elapsed(at: later) - PhaseCycle.holdElapsed) < 1e-9)
    }

    @Test("First ask → Use my location → Allow: searching again, then the screen")
    func firstAskAllow() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        harness.location.stateAfterRequest = .authorized

        await harness.viewModel.performLoaderAction()

        #expect(harness.location.requestAuthorizationCount == 1)
        #expect(harness.sleeper.durations.contains(.seconds(0.2)))
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        // Asked for and found: remembered, so the next launch opens on it.
        #expect(harness.store.lastViewed == Self.detected)
    }

    @Test("First ask → Don't Allow: the app permission failure screen, no searching")
    func firstAskDeny() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        let waitsBefore = harness.sleeper.durations.count
        harness.location.stateAfterRequest = .denied

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.viewModel.loaderIssue == nil)
        #expect(harness.sleeper.durations.count == waitsBefore)
        #expect(harness.location.currentPlaceCount == 0)
    }

    @Test("First ask, the prompt left unanswered: First ask stays, not No fix")
    func firstAskUnanswered() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        harness.location.stateAfterRequest = .notDetermined

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.loaderIssue == .firstAsk)
        #expect(harness.viewModel.failureScreen == nil)
        #expect(harness.viewModel.locationFailure == nil)
        #expect(harness.location.currentPlaceCount == 0)
    }

    @Test("First ask → Allow → the fix fails: searching for the minimum, then No fix")
    func firstAskAllowThenMiss() async {
        let harness = Self.makeHarness(.notDetermined, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.stateAfterRequest = .authorized

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == .noFix)
        #expect(harness.location.currentPlaceCount == 1)
    }

    @Test("First ask → Settings → blocked: guidance without a tap or search", arguments: [
        (LocationAuthState.denied, LocationFailure.permissionDenied),
        (.servicesOff, .servicesOff),
        (.restricted, .restricted),
    ])
    func firstAskThenOffInSettings(state: LocationAuthState, failure: LocationFailure) async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        #expect(harness.viewModel.loaderIssue == .firstAsk)
        let waitsBeforeReturn = harness.sleeper.durations
        harness.viewModel.sceneDidEnterBackground()
        harness.location.authorizationState = state

        await harness.viewModel.sceneDidBecomeActive()
        // Unchanged repeated activation keeps guidance without a request.
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == failure)
        #expect(harness.viewModel.loaderIssue == nil)
        #expect(harness.location.currentPlaceCount == 0)
        #expect(harness.location.requestAuthorizationCount == 0)
        #expect(harness.sleeper.durations == waitsBeforeReturn)
    }

    // MARK: - Back from Settings (§3 rows 6–9)

    @Test("Denied → Settings → back allowed: searching again, then the screen")
    func backFromSettingsAllowed() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        harness.location.authorizationState = .authorized

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 1)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.viewModel.failureScreen == nil)
    }

    @Test("Denied → Settings → back allowed, but no fix: the No fix screen, after the minimum")
    func backFromSettingsAllowedThenMiss() async {
        let harness = Self.makeHarness(.denied, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.authorizationState = .authorized

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 1)
        #expect(harness.viewModel.failureScreen == .noFix)
        #expect(harness.sleeper.durations.contains(Self.searchMinimum))
    }

    @Test("Back from Settings still off: the screen stays, no fix")
    func backFromSettingsStillOff() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.location.currentPlaceCount == 0)
    }

    @Test("Back from Settings with another cause: that cause's screen")
    func backFromSettingsOtherCause() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        harness.location.authorizationState = .servicesOff

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.failureScreen == .servicesOff)
        #expect(harness.location.currentPlaceCount == 0)
    }

    /// Chunk 2b, superseding §3 row 9: Ask Next Time is not determined,
    /// where iOS can still prompt, so First ask, not the telescope.
    @Test("Services turned on, app never asked: First ask, no prompt by itself")
    func servicesOnGoesToFirstAsk() async {
        let harness = Self.makeHarness(.servicesOff)
        await harness.viewModel.start()
        harness.location.authorizationState = .notDetermined

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.loaderIssue == .firstAsk)
        #expect(harness.viewModel.failureScreen == nil)
        #expect(!harness.location.didRequestAuthorization)
        #expect(harness.location.currentPlaceCount == 0)
    }

    @Test("Denied, Ask Next Time in Settings, back: First ask; its button prompts, and Allow finds you")
    func askNextTimeGoesToFirstAsk() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        #expect(harness.viewModel.failureScreen == .permissionDenied)
        harness.location.authorizationState = .notDetermined

        await harness.viewModel.sceneDidBecomeActive()
        #expect(harness.viewModel.loaderIssue == .firstAsk)
        // Straight there: no searching label, no searching minimum.
        #expect(!harness.viewModel.loader.showsLabel)
        #expect(!harness.sleeper.durations.contains(Self.searchMinimum))
        #expect(harness.viewModel.loader.glow.mode == .pulse)
        // Another trip out and back doesn't loop to the telescope.
        await harness.viewModel.sceneDidBecomeActive()
        #expect(harness.viewModel.loaderIssue == .firstAsk)
        #expect(!harness.location.didRequestAuthorization)

        harness.location.stateAfterRequest = .authorized
        await harness.viewModel.performLoaderAction()

        #expect(harness.location.requestAuthorizationCount == 1)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.viewModel.launchStage == .ready)
    }

    @Test("After an explicit request: denied, Ask Next Time, back: First ask too; Don't Allow is the telescope again")
    func askNextTimeAfterExplicitRequest() async {
        let harness = Self.makeHarness(.denied, lastViewed: Place.marVista)
        await harness.viewModel.start()
        await harness.viewModel.useMyLocation()
        #expect(harness.viewModel.failureScreen == .permissionDenied)
        harness.location.authorizationState = .notDetermined

        await harness.viewModel.sceneDidBecomeActive()
        #expect(harness.viewModel.loaderIssue == .firstAsk)
        #expect(!harness.viewModel.loader.showsLabel)
        #expect(!harness.sleeper.durations.contains(Self.searchMinimum))
        // The explicit failure doesn't bring the old city back.
        #expect(harness.viewModel.place == nil)

        harness.location.stateAfterRequest = .denied
        await harness.viewModel.performLoaderAction()

        #expect(harness.location.requestAuthorizationCount == 1)
        #expect(harness.viewModel.failureScreen == .permissionDenied)
    }

    @Test("Open Settings is the view's: the view model does nothing for it")
    func openSettingsIsTheViews() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        await harness.viewModel.performLoaderAction()
        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.location.requestAuthorizationCount == 0)
        #expect(harness.location.currentPlaceCount == 0)
    }

    // MARK: - No fix (§3 row 5; Chunk 2b replaces row 10)

    @Test("No fix → back in the app (Control Center, Settings, another app) → a fix: the screen")
    func foregroundRetrySucceeds() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 2)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.viewModel.failureScreen == nil)
    }

    @Test("No fix → back in the app → still nothing: the same No fix screen, after the minimum")
    func foregroundRetryFails() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        let waitsBefore = harness.sleeper.durations.filter { $0 == Self.searchMinimum }.count

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.failureScreen == .noFix)
        #expect(harness.location.currentPlaceCount == 2)
        #expect(harness.sleeper.durations.filter { $0 == Self.searchMinimum }.count == waitsBefore + 1)
    }

    @Test("No fix, access now off: the foreground switches to that cause, with no search")
    func noFixThenOff() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.authorizationState = .denied

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.location.currentPlaceCount == 1)
    }

    @Test("No fix has no button, only Search for a city instead, which opens the search")
    func noFixOnlyLink() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.couldNotIdentifyPlace))
        await harness.viewModel.start()
        #expect(harness.viewModel.failureScreen == .noFix)
        #expect(LocationFailure.noFix.copy.primaryTitle == nil)
        #expect(LocationFailure.noFix.copy.showsLink)

        // The link: `LocationFailureView` calls `onSearch`.
        harness.viewModel.presentSearch()
        #expect(harness.viewModel.isSearchPresented)
        harness.viewModel.select(Place.marVista)
        #expect(harness.viewModel.place == Place.marVista)
        #expect(harness.viewModel.failureScreen == nil)
    }

    // MARK: - Search for a city (§3 rows 3 and 12)

    @Test("Search from each cause, then pick: city load-in without GPS Aha", arguments: [
        LocationAuthState.denied, .servicesOff, .restricted, .authorized,
    ])
    func searchThenPick(state: LocationAuthState) async {
        let harness = Self.makeHarness(state, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        let loadIns = harness.viewModel.loadInGeneration

        harness.viewModel.presentSearch()
        #expect(harness.viewModel.isSearchPresented)
        harness.viewModel.select(Place.marVista)

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Place.marVista)
        #expect(harness.viewModel.failureScreen == nil)
        #expect(harness.viewModel.loadInGeneration == loadIns + 1)
        // A city load-in, not GPS "Aha".
        #expect(harness.viewModel.loader.flightStartedAt == nil)
    }

    @Test("Search from each cause, then cancel: the original guidance stays", arguments: [
        LocationAuthState.denied, .servicesOff, .restricted, .authorized,
    ])
    func searchThenCancel(state: LocationAuthState) async {
        let harness = Self.makeHarness(state, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        let origin = harness.viewModel.failureScreen

        harness.viewModel.presentSearch()
        harness.viewModel.isSearchPresented = false
        await harness.viewModel.searchDidDismiss()

        #expect(origin != nil)
        #expect(harness.viewModel.failureScreen == origin)
        #expect(harness.viewModel.place == nil)
    }

    @Test("The search sheet's Use my location from First ask → Allow: the screen, not the message")
    func searchRowFromFirstAsk() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        harness.location.stateAfterRequest = .authorized

        await harness.viewModel.useMyLocation()

        #expect(harness.location.requestAuthorizationCount == 1)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
    }

    @Test("The search sheet's Use my location from First ask, now off: its failure screen, no dialog")
    func searchRowFromFirstAskWhileOff() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        harness.location.authorizationState = .denied

        await harness.viewModel.useMyLocation()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(!harness.viewModel.isReplacingPlace)
    }

    @Test("The search sheet's Use my location from No fix, still nothing: No fix again, no dialog")
    func searchRowFromNoFix() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()

        await harness.viewModel.useMyLocation()

        #expect(harness.viewModel.failureScreen == .noFix)
        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(harness.location.currentPlaceCount == 2)
    }

    @Test("The search sheet's Use my location while denied: the same failure screen, no dialog; back allowed recovers")
    func searchRowWhileDenied() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()

        await harness.viewModel.useMyLocation()
        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(harness.viewModel.failureScreen == .permissionDenied)

        harness.location.authorizationState = .authorized
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.location.currentPlaceCount == 1)
    }

    @Test("The search row from a failure screen: the screen stays while the sheet closes, then its flow runs")
    func searchRowKeepsFailureScreenUntilDismissed() async throws {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        harness.viewModel.presentSearch()
        let sheet = try #require(harness.viewModel.searchSheet)

        sheet.useMyLocation()

        // Under the closing sheet: no empty main screen or skeleton.
        #expect(!harness.viewModel.isSearchPresented)
        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(!harness.viewModel.isReplacingPlace)
        #expect(harness.viewModel.cardPlaceholder == nil)

        await harness.viewModel.searchDidDismiss()

        #expect(harness.viewModel.failureScreen == .permissionDenied)
        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(!harness.viewModel.isReplacingPlace)
    }

    @Test("Restricted: the button is the search")
    func restrictedSearches() async {
        let harness = Self.makeHarness(.restricted)
        await harness.viewModel.start()
        #expect(harness.viewModel.failureScreen?.primaryAction == .search)
        #expect(harness.viewModel.failureScreen?.showsSearchLink == false)
    }

    @Test("A pick while a failed launch is still searching: no failure screen turns up later")
    func pickSupersedesFailure() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .failure(LocationError.locationUnavailable)
        )
        let sleeper = ManualSleeper()
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            now: { Self.reference },
            sleep: { [sleeper] duration in try await sleeper.sleep(duration) },
            loaderNow: { Self.reference }
        )
        let launch = Task { await viewModel.start() }
        // The 400 ms clock, cancelled but never resumed, and the minimum.
        await Self.settle { viewModel.launchStage == .phaseCycle && sleeper.pendingCount == 2 }

        viewModel.select(Place.marVista)
        sleeper.fire()
        await launch.value

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.place == Place.marVista)
        #expect(viewModel.failureScreen == nil)
    }

    // MARK: - "Aha" (§10.4)

    @Test("A fix when No fix looks again: \"Aha\" with the city, then the moon flies as the screen comes up")
    func ahaAfterRecovery() async throws {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.sceneDidBecomeActive()

        let loader = harness.viewModel.loader
        #expect(harness.sleeper.durations.contains(.seconds(LocationLoader.minimumSearchBeforeAha)))
        guard case .aha(let greeting) = loader.content else {
            Issue.record("expected Aha, got \(loader.content)")
            return
        }
        #expect(AhaGreeting.lines.contains(greeting.line))
        #expect(greeting.city == "Irvine, CA")
        // §11.2.2: the glow follows the ride's lit fraction; the moon rode
        // to the card's phase.
        #expect(loader.glow.mode == .breathe)
        let ride = try #require(loader.ride)
        let card = try #require(harness.viewModel.moonTable?.glyph)
        #expect(abs(ride.geometry(at: ride.endDate).litFraction - card.litFraction) < 1e-9)
        #expect(ride.geometry(at: ride.endDate).litSide == card.litSide || card.litFraction > 0.999)
        #expect(!loader.showsLabel)
        #expect(loader.flightStartedAt == Self.reference)
        #expect(harness.viewModel.launchStage == .ready)
    }

    @Test("Allow at the iOS prompt from First ask: \"Aha\" too")
    func ahaAfterPrompt() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        harness.location.stateAfterRequest = .authorized

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.loader.flightStartedAt != nil)
        if case .aha = harness.viewModel.loader.content {} else {
            Issue.record("expected Aha")
        }
    }

    @Test("The first ride after install has the extra lap, and only then is it seen")
    func firstRideHasExtraLap() async throws {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        #expect(!harness.onboardingStore.hasSeenFirstFindPass)
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.sceneDidBecomeActive()

        let ride = try #require(harness.viewModel.loader.ride)
        #expect(ride.laps >= 1)
        #expect(harness.onboardingStore.hasSeenFirstFindPass)
    }

    @Test("Later rides go straight to the real phase, under a lap")
    func laterRideNoExtraLap() async throws {
        let harness = Self.makeHarness(
            .authorized,
            placeResult: .failure(LocationError.locationUnavailable),
            hasSeenFirstFindPass: true
        )
        await harness.viewModel.start()
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.sceneDidBecomeActive()

        let ride = try #require(harness.viewModel.loader.ride)
        #expect(ride.laps < 1)
    }

    @Test("Reduce Motion: no ride, no lap used up, Aha holds 2 s")
    func reduceMotionNoRide() async {
        let harness = Self.makeHarness(
            .authorized,
            placeResult: .failure(LocationError.locationUnavailable),
            reducesMotion: true
        )
        await harness.viewModel.start()
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.loader.ride == nil)
        #expect(harness.sleeper.durations.contains(.seconds(LocationLoader.ahaHold)))
        #expect(!harness.onboardingStore.hasSeenFirstFindPass)
        #expect(harness.viewModel.loader.flightStartedAt != nil)
    }

    @Test("An ordinary launch with a fix: no \"Aha\", the content loads in")
    func noAhaOnOrdinaryLaunch() async {
        let harness = Self.makeHarness(.authorized)
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.loader.content == .searching)
        #expect(harness.viewModel.loader.flightStartedAt == nil)
        #expect(!harness.sleeper.durations.contains(.seconds(LocationLoader.minimumSearchBeforeAha)))
        // No flight, so no landing haptic (§11.2.7).
        #expect(harness.viewModel.loader.landingCount == 0)
        // The loader was skipped: the first ride's lap is still to come.
        #expect(!harness.onboardingStore.hasSeenFirstFindPass)
    }

    @Test("Never the same line twice in a row")
    func linesRotate() {
        for previous in AhaGreeting.lines {
            for pick in 0..<(AhaGreeting.lines.count - 1) {
                #expect(AhaGreeting.line(after: previous, pick: { _ in pick }) != previous)
            }
        }
        // Out-of-range picks are clamped, not a crash.
        #expect(AhaGreeting.lines.contains(AhaGreeting.line(after: nil, pick: { _ in 99 })))
    }

    @Test("VoiceOver reads the line, then the city")
    func ahaAccessibilityLabel() {
        let greeting = AhaGreeting(line: "Aha, there you are!", city: "Rancho Santa Margarita, CA")
        #expect(greeting.accessibilityLabel == "Aha, there you are! Rancho Santa Margarita, CA")
    }

    @Test("The flight runs from where the ride left the moon to the card's slot and phase")
    func flightEnds() {
        let start = CGRect(x: 126, y: 300, width: 140, height: 140)
        let slot = CGRect(x: 32, y: 120, width: 44, height: 44)
        let landing = PhaseGlyphGeometry(illumination: 0.53, phaseAngle: 270)
        let began = Self.reference

        #expect(AhaFlight.progress(since: began, at: began) == 0)
        #expect(AhaFlight.progress(since: began, at: began.addingTimeInterval(LocationLoader.flightDuration)) == 1)
        #expect(AhaFlight.frame(from: start, to: slot, progress: 0) == start)
        #expect(AhaFlight.frame(from: start, to: slot, progress: 1) == slot)
        let full = PhaseGlyphGeometry(illumination: 1, phaseAngle: 180)
        #expect(AhaFlight.geometry(from: full, landingOn: landing, progress: 0).litFraction == 1)
        #expect(AhaFlight.geometry(from: full, landingOn: landing, progress: 1) == landing)
        // After a ride it's already there: nothing changes in flight.
        #expect(AhaFlight.geometry(from: landing, landingOn: landing, progress: 0.4) == landing)
    }

    // MARK: - Copy and actions

    @Test("Each message has the handoff's copy and button")
    func copy() {
        #expect(LocationIssue.firstAsk.headline == "Find the moon from where you are")
        #expect(LocationIssue.firstAsk.primaryTitle == "Use my location")
        #expect(LocationIssue.appDenied.headline == "Can’t see your location")
        #expect(LocationIssue.appDenied.primaryTitle == "Open Settings")
        #expect(LocationIssue.servicesOff.headline == "Location Services are off")
        #expect(LocationIssue.servicesOff.body == "Turn them on to see where the moon is from here.")
        #expect(LocationIssue.noFix.headline == "Couldn’t find your location")
        #expect(LocationIssue.noFix.primaryTitle == nil)
        #expect(LocationIssue.noFix.primaryAction == nil)
        // §10.1: restricted has the app-permission copy, and no Settings.
        #expect(LocationIssue.restricted.headline == LocationIssue.appDenied.headline)
        #expect(LocationIssue.restricted.body
            == "Location access is limited on this iPhone. You can still search for a city.")
        #expect(LocationIssue.restricted.primaryAction == .search)
        #expect(!LocationIssue.restricted.showsSearchLink)
        #expect(LocationIssue.appDenied.showsSearchLink)
        // As on the failure screens (Tessa, 2026-10-10).
        #expect(LocationIssue.appDenied.copy.linkTitle == "Search for a city instead")
        #expect(LocationIssue.restricted.copy.primaryTitle == "Search for a city")
    }

    @Test("Each message has the prototype's default-size line breaks")
    func messageLineBreaks() {
        #expect(LocationIssue.firstAsk.headlineLines == ["Find the moon", "from where you are"])
        #expect(LocationIssue.firstAsk.bodyLines == [
            "Moon Signal uses your location to show",
            "when and where the moon rises and sets."
        ])
        #expect(LocationIssue.appDenied.headlineLines == ["Can’t see", "your location"])
        #expect(LocationIssue.appDenied.bodyLines == [
            "Allow location access to see",
            "where the moon is from here."
        ])
        #expect(LocationIssue.servicesOff.headlineLines == ["Location", "Services are off"])
        #expect(LocationIssue.servicesOff.bodyLines == [
            "Turn them on to see where",
            "the moon is from here."
        ])
        #expect(LocationIssue.noFix.headlineLines == ["Couldn’t find", "your location"])
        #expect(LocationIssue.noFix.bodyLines == [
            "Check your cellular or Wi-Fi",
            "connection. We’ll look again",
            "when you come back."
        ])
        #expect(LocationIssue.restricted.bodyLines == [
            "Location access is limited on", "this iPhone. You can still", "search for a city.",
        ])
    }

    @Test(
        "Each cause message takes its words and actions from its failure screen",
        arguments: [
            (LocationIssue.appDenied, LocationFailure.permissionDenied),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
            (.noFix, .noFix),
        ]
    )
    func causeMessagesShareFailureCopy(issue: LocationIssue, failure: LocationFailure) {
        #expect(issue.failure == failure)
        // Consolidation Chunk 2: exactly the screen's, chip and lines too.
        #expect(issue.copy == failure.copy)
        #expect(issue.primaryAction == failure.primaryAction)
    }

    @Test("First ask is an invitation, not a cause")
    func firstAskIsNotACause() {
        #expect(LocationIssue.firstAsk.failure == nil)
        #expect(LocationIssue.firstAsk.primaryAction == .requestPermission)
        #expect(LocationIssue.firstAsk.copy.showsLink)
    }

    @Test("Authorized has no message")
    func authorizedHasNone() {
        #expect(LocationIssue(.authorized) == nil)
    }
}

/// `LocationLoader`'s steps on a clock the test moves.
@Suite("Location loader steps", .timeLimit(.minutes(1)))
@MainActor
struct LocationLoaderStepTests {

    @MainActor
    private final class Clock {
        var date = Date(timeIntervalSinceReferenceDate: 0)
        var waits: [Duration] = []
        /// Runs at the start of each wait, before the clock moves.
        var onWait: (() -> Void)?
    }

    private static func makeLoader(_ clock: Clock) -> LocationLoader {
        LocationLoader(
            now: { clock.date },
            sleep: { [clock] duration in
                await MainActor.run {
                    clock.waits.append(duration)
                    clock.onWait?()
                    clock.date = clock.date.addingTimeInterval(TimeInterval(duration.components.seconds)
                        + TimeInterval(duration.components.attoseconds) / 1e18)
                }
            }
        )
    }

    @Test("Time already spent searching counts towards the 1.2 s")
    func searchedTimeCounts() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        clock.date = clock.date.addingTimeInterval(0.5)
        await loader.showMessage(.noFix)
        let first = clock.waits.first.map { Double($0.components.attoseconds) / 1e18 + Double($0.components.seconds) }
        #expect(abs((first ?? 0) - 0.7) < 1e-6)
    }

    @Test("A reason known before the cycle starts: the moon stays at the hold, message after 1.2 s, no spin")
    func knownReasonHolds() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        let start = clock.date

        await loader.showMessage(.appDenied)

        let waits = clock.waits.map { Double($0.components.attoseconds) / 1e18 + Double($0.components.seconds) }
        #expect(waits.count == 1)
        #expect(abs((waits.first ?? 0) - LocationLoader.minimumSearchBeforeMessage) < 1e-6)
        #expect(abs(clock.date.timeIntervalSince(start) - LocationLoader.minimumSearchBeforeMessage) < 1e-6)
        // Never moved: at the hold phase all the way through.
        #expect(abs(loader.moon.elapsed(at: start.addingTimeInterval(1)) - PhaseCycle.holdElapsed) < 1e-6)
        #expect(loader.content == .message(.appDenied))
    }

    @Test("A running moon runs out at 2.6× (easing at the end) to the hold phase before the message")
    func runsOutBeforeMessage() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        // 2 s in: the cycle started at 0.84 s, so it's 1.16 s past the hold.
        clock.date = clock.date.addingTimeInterval(2)
        await loader.showMessage(.noFix)
        let distance = PhaseCycle.period - 1.16
        let expected = MoonMotion.runOutDuration(distance: distance)
        let runOut = clock.waits.last.map { Double($0.components.attoseconds) / 1e18 + Double($0.components.seconds) }
        #expect(abs((runOut ?? 0) - expected) < 1e-6)
        #expect(abs(loader.moon.elapsed(at: clock.date) - PhaseCycle.holdElapsed) < 1e-6)
        #expect(loader.content == .message(.noFix))
    }

    @Test("Resume: message gone at once, glow breathing, label and cycle back 0.2 s later")
    func resumes() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.appDenied)
        let resumeStart = clock.date

        await loader.resume()

        #expect(loader.content == .searching)
        #expect(loader.glow.mode == .breathe)
        #expect(loader.showsLabel)
        #expect(loader.searchStartedAt == resumeStart.addingTimeInterval(0.2))
        // §11.2.1: the session started at the tap, not at the label's return.
        #expect(loader.sessionStartedAt == resumeStart)
        let after = clock.date.addingTimeInterval(1)
        #expect(loader.moon.elapsed(at: after) != loader.moon.elapsed(at: clock.date))
    }

    /// A waning gibbous, as the card might show.
    private static let realPhase = PhaseGlyphGeometry(illumination: 0.7, phaseAngle: 230)

    private static func seconds(_ duration: Duration) -> TimeInterval {
        Double(duration.components.attoseconds) / 1e18 + Double(duration.components.seconds)
    }

    @Test("Recovery (§11.2.3, §11.2.5): ride at the fix, label goes at once, Aha 1 s before landing, flight 0.25 s before it")
    func ahaStep() async throws {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.appDenied)
        await loader.resume()
        clock.date = clock.date.addingTimeInterval(1.5)
        let fixDate = clock.date
        let waitsBefore = clock.waits.count
        var labelLeftAt: Date?
        var ahaAt: Date?
        clock.onWait = { [clock] in
            if labelLeftAt == nil, !loader.showsLabel { labelLeftAt = clock.date }
            if ahaAt == nil, loader.content.isAha { ahaAt = clock.date }
        }

        let greeting = AhaGreeting(line: AhaGreeting.lines[1], city: "Irvine, CA")
        #expect(await loader.showAha(greeting, realPhase: Self.realPhase))

        let ride = try #require(loader.ride)
        #expect(ride.startDate == fixDate)
        // The label leaves at the fix, with no wait.
        #expect(labelLeftAt == fixDate)
        // Aha 1 s before the landing (the ride is ≥ 1.6 s here).
        let expectedAha = ride.endDate.addingTimeInterval(-LocationLoader.ahaLeadBeforeLanding)
        #expect(abs((ahaAt ?? .distantPast).timeIntervalSince(expectedAha)) < 1e-6)
        // §11.2.5: it's time to fly 0.25 s before the moon lands, so the
        // phase settles during the flight and the moon reaches the real
        // phase well before the card (0.85 s).
        #expect(abs(clock.date.timeIntervalSince(ride.endDate) + LocationLoader.flightOverlapWithRide) < 1e-6)
        #expect(LocationLoader.flightOverlapWithRide < LocationLoader.flightDuration)
        _ = clock.waits.dropFirst(waitsBefore)
        #expect(loader.content == .aha(greeting))
        #expect(loader.glow.mode == .breathe)
        #expect(!loader.showsLabel)
        let landed = ride.geometry(at: ride.endDate)
        #expect(abs(landed.litFraction - Self.realPhase.litFraction) < 1e-9)
        #expect(landed.litSide == Self.realPhase.litSide)

        loader.flyAway()
        #expect(loader.flightStartedAt == clock.date)
        loader.didLand()
        #expect(loader.flightStartedAt == nil)
    }

    @Test("A fix right away: the ride starts at once, the label still gets 0.7 s from the session's start")
    func ahaFastFix() async throws {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.noFix)
        let tap = clock.date
        await loader.resume()
        let fixDate = clock.date
        let waitsBefore = clock.waits.count

        let greeting = AhaGreeting(line: AhaGreeting.lines[2], city: "Irvine, CA")
        #expect(await loader.showAha(greeting, realPhase: Self.realPhase))

        let ride = try #require(loader.ride)
        #expect(ride.startDate == fixDate)
        let waits = clock.waits.dropFirst(waitsBefore).map(Self.seconds)
        // resume() took 0.2 s of the 0.7 s already.
        #expect(abs((waits.first ?? 0) - (LocationLoader.minimumSearchBeforeAha - 0.2)) < 1e-6)
        #expect(abs(fixDate.timeIntervalSince(tap) - 0.2) < 1e-6)
        #expect(loader.content == .aha(greeting))
    }

    @Test("No dip at the handover: the ride starts at the cycle's speed", arguments: [0.4, 1.0, 1.9, 2.9, 3.6])
    func rideKeepsCycleSpeed(after seconds: TimeInterval) async throws {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.noFix)
        await loader.resume()
        clock.date = clock.date.addingTimeInterval(seconds)
        let fixDate = clock.date
        let frame = 1.0 / 240
        func step(_ phase: (Date) -> Double) -> Double {
            let delta = phase(fixDate.addingTimeInterval(frame)) - phase(fixDate)
            return (delta < 0 ? delta + 1 : delta) / frame
        }
        let cycleSpeed = step { PhaseCycle.phase(at: loader.moon.elapsed(at: $0)) }
        #expect(await loader.showAha(AhaGreeting(line: AhaGreeting.lines[0], city: "Irvine, CA"), realPhase: Self.realPhase))
        let ride = try #require(loader.ride)
        let rideSpeed = step { ride.phase(at: $0) }
        // Same speed within a frame's worth of change.
        #expect(abs(rideSpeed - cycleSpeed) < 0.02)
        // And the same place.
        #expect(abs(ride.fromPhase - PhaseCycle.phase(at: loader.moon.elapsed(at: fixDate))) < 1e-9)
    }

    @Test("§11.2.6: Aha leaves at the flight start and is gone before the sentence comes in")
    func ahaOutBeforeScreen() {
        #expect(LocationLoader.ahaLeaveDuration == 0.25)
        #expect(LocationLoader.ahaLeaveDrift == 6)
        #expect(LocationLoader.ahaLeaveDuration < ContentLoadIn.afterAhaDelay(for: .sentence))
    }

    @Test("§11.2.7: after Aha the screen loads in at 0.30 / 0.45 / 0.60 s, the same 150 ms stagger")
    func screenAroundFlight() {
        #expect(abs(ContentLoadIn.afterAhaDelay(for: .sentence) - 0.30) < 1e-9)
        #expect(abs(ContentLoadIn.afterAhaDelay(for: .card) - 0.45) < 1e-9)
        #expect(abs(ContentLoadIn.afterAhaDelay(for: .compass) - 0.60) < 1e-9)
        // The card is in (0.45 + 0.3 s) as the moon lands in its slot; the
        // compass starts just before the landing.
        #expect(ContentLoadIn.afterAhaDelay(for: .card) + ContentLoadIn.duration <= LocationLoader.flightDuration)
        #expect(ContentLoadIn.afterAhaDelay(for: .compass) < LocationLoader.flightDuration)
    }

    @Test("§11.2.7: one haptic per landing, none without a flight")
    func landingHaptic() {
        let loader = LocationLoader(now: { Date(timeIntervalSinceReferenceDate: 0) }, sleep: { _ in })
        loader.appear()
        // No flight: nothing to land, no tap.
        loader.didLand()
        #expect(loader.landingCount == 0)
        loader.flyAway()
        loader.didLand()
        #expect(loader.landingCount == 1)
        // A second report of the same landing doesn't tap again.
        loader.didLand()
        #expect(loader.landingCount == 1)
    }

    @Test("The flight moves from its first frame (§11.2.5)")
    func flightMovesAtOnce() {
        let began = Date(timeIntervalSinceReferenceDate: 0)
        let first = AhaFlight.progress(since: began, at: began.addingTimeInterval(0.02))
        // At least half the flight's average speed in its first 20 ms.
        #expect(first > 0.5 * 0.02 / LocationLoader.flightDuration)
    }

    @Test("The moon never comes to rest between ride and flight", arguments: [0.4, 1.0, 1.9, 2.9, 3.6])
    func neverAtRest(after seconds: TimeInterval) async throws {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.noFix)
        await loader.resume()
        clock.date = clock.date.addingTimeInterval(seconds)
        #expect(await loader.showAha(AhaGreeting(line: AhaGreeting.lines[0], city: "Irvine, CA"), realPhase: Self.realPhase))
        let ride = try #require(loader.ride)
        let flightStart = clock.date
        #expect(flightStart < ride.endDate)
        // Over the handover, each 50 ms step either the phase or the flight
        // moves by a visible amount.
        let step = 0.05
        for index in 0..<20 {
            let t = ride.startDate.addingTimeInterval(max(0, ride.duration - 0.5) + Double(index) * step)
            let phaseMove = abs(ride.phase(at: t.addingTimeInterval(step)) - ride.phase(at: t))
            let flightMove = AhaFlight.progress(since: flightStart, at: t.addingTimeInterval(step))
                - AhaFlight.progress(since: flightStart, at: t)
            // The handover only: the flight's own ease into the card slows
            // by design.
            guard t < flightStart.addingTimeInterval(LocationLoader.flightOverlapWithRide + step) else { break }
            #expect(phaseMove > 1e-3 || flightMove > 0.02)
        }
    }

    @Test("A ride under 0.5 s flies from its midpoint")
    func shortRideFliesFromMidpoint() async throws {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.noFix)
        await loader.resume()
        // Past the label's 0.7 s, mid-sweep, with the real phase just ahead:
        // a fast start that shortens the ride.
        clock.date = clock.date.addingTimeInterval(0.6)
        let fixDate = clock.date
        let here = PhaseCycle.phase(at: loader.moon.elapsed(at: fixDate))
        let justAhead = PhaseCycle.geometry(forPhase: here + 0.01)
        #expect(await loader.showAha(AhaGreeting(line: AhaGreeting.lines[0], city: "Irvine, CA"), realPhase: justAhead))
        let ride = try #require(loader.ride)
        #expect(ride.duration < 2 * LocationLoader.flightOverlapWithRide)
        #expect(abs(clock.date.timeIntervalSince(fixDate) - ride.duration / 2) < 1e-6)
    }

    @Test("Reduce Motion or no card phase: no ride, Aha holds 2 s")
    func ahaWithoutRide() async {
        for (phase, reduces) in [(Self.realPhase, true), (nil, false)] as [(PhaseGlyphGeometry?, Bool)] {
            let clock = Clock()
            let loader = Self.makeLoader(clock)
            loader.appear()
            await loader.showMessage(.noFix)
            await loader.resume()
            clock.date = clock.date.addingTimeInterval(1)
            let waitsBefore = clock.waits.count
            let greeting = AhaGreeting(line: AhaGreeting.lines[0], city: "Irvine, CA")
            #expect(await loader.showAha(greeting, realPhase: phase, extraLap: true, reducesMotion: reduces))
            #expect(loader.ride == nil)
            #expect(clock.waits.dropFirst(waitsBefore).map(Self.seconds) == [LocationLoader.ahaHold])
        }
    }

    @Test("Straight to a message (Chunk 2b): no label, no wait, the moon held at the hold phase, glow pulsing")
    func presentsMessageAtOnce() {
        let clock = Clock()
        let loader = Self.makeLoader(clock)

        loader.presentMessage(.firstAsk)

        #expect(loader.content == .message(.firstAsk))
        #expect(!loader.showsLabel)
        #expect(clock.waits.isEmpty)
        #expect(loader.glow.mode == .pulse)
        #expect(loader.appearedAt == clock.date)
        let later = clock.date.addingTimeInterval(10)
        #expect(abs(loader.moon.elapsed(at: later) - PhaseCycle.holdElapsed) < 1e-9)
    }

    @Test("Already on a message, a new one swaps in place, no wait")
    func swapsMessage() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.firstAsk)
        let waits = clock.waits.count
        await loader.showMessage(.appDenied)
        #expect(loader.content == .message(.appDenied))
        #expect(clock.waits.count == waits)
    }

    @Test("Ending the loader stops a waiting step")
    func endStops() async {
        let sleeper = Gate()
        let loader = LocationLoader(now: { .distantPast }, sleep: { [sleeper] _ in await sleeper.wait() })
        loader.appear()
        let step = Task { await loader.showMessage(.noFix) }
        for _ in 0..<1_000 where sleeper.count == 0 { await Task.yield() }
        loader.end()
        sleeper.open()
        #expect(await step.value == false)
        #expect(loader.content == .searching)
    }

    @MainActor
    private final class Gate {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        var count: Int { waiters.count }
        func wait() async { await withCheckedContinuation { waiters.append($0) } }
        func open() {
            let all = waiters
            waiters = []
            all.forEach { $0.resume() }
        }
    }
}
