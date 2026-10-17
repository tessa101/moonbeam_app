//
//  LocationViewModelOnboardingTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// How the main screen starts after each onboarding outcome (§5), and the
/// `noCity` state they land on (ONBOARDING-MOD-MAIN.md): the detected city,
/// or "a city" with its CTA, never First ask or a failure screen. Search
/// close always leaves `noCity`; a pick, a fix or "Start with" resolves it.
@Suite("Onboarding → main screen", .timeLimit(.minutes(1)))
@MainActor
struct OnboardingMainScreenTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private static let detected = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: losAngelesZone,
        isCurrentLocation: true
    )

    private static let sydney = Place(
        name: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    private static func makeLocationViewModel(
        location: FakeLocationService,
        placeStore: InMemoryPlaceStore = InMemoryPlaceStore(),
        onboardingStore: InMemoryOnboardingStore = InMemoryOnboardingStore(),
        deviceTimeZone: TimeZone = losAngelesZone
    ) -> LocationViewModel {
        LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: placeStore,
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            onboardingStore: onboardingStore,
            deviceTimeZone: deviceTimeZone
        )
    }

    /// Onboarding has ended with `outcome` and the screen has started.
    private static func started(
        after outcome: OnboardingViewModel.Outcome,
        location: FakeLocationService,
        placeStore: InMemoryPlaceStore = InMemoryPlaceStore(),
        deviceTimeZone: TimeZone = losAngelesZone
    ) async -> LocationViewModel {
        let viewModel = makeLocationViewModel(location: location, placeStore: placeStore, deviceTimeZone: deviceTimeZone)
        viewModel.onboardingDidFinish(outcome)
        await viewModel.start()
        return viewModel
    }

    /// Opens search from the city token, then closes it as Cancel or a drag
    /// does: the binding closes it, then its onDismiss runs.
    private static func openAndCloseSearch(on viewModel: LocationViewModel) async {
        viewModel.open(.place)
        #expect(viewModel.isSearchPresented)
        viewModel.isSearchPresented = false
        await viewModel.searchDidDismiss()
    }

    /// `noCity` with nothing else on screen.
    private static func expectNoCity(_ viewModel: LocationViewModel) {
        #expect(viewModel.isNoCity)
        #expect(viewModel.canReturnToOnboarding)
        #expect(viewModel.place == nil)
        #expect(viewModel.moonTable == nil)
        #expect(viewModel.cardPlaceholder == nil)
        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.failureScreen == nil)
        #expect(viewModel.loaderIssue == nil)
    }

    /// Resolved: the city is set and Back to onboarding is gone.
    private static func expectResolved(_ viewModel: LocationViewModel, on place: Place) {
        #expect(viewModel.place == place)
        #expect(!viewModel.isNoCity)
        #expect(!viewModel.canReturnToOnboarding)
        #expect(viewModel.noCityAction == nil)
        #expect(viewModel.noCityStartCity == nil)
    }

    // MARK: - Each outcome's landing

    @Test("Allow: the normal launch flow shows the detected city, resolved")
    func allowedShowsDetectedCity() async {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))

        let viewModel = await Self.started(after: .locationAllowed, location: location)

        Self.expectResolved(viewModel, on: Self.detected)
        #expect(!viewModel.isSearchPresented)
    }

    @Test("Allow with a missed fix: noCity, never the no-fix failure screen")
    func allowedMissStaysOnNoCity() async {
        let location = FakeLocationService(authorizationState: .authorized)

        let viewModel = await Self.started(after: .locationAllowed, location: location)

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .enableLocation)
    }

    @Test("Deny: noCity with Open Settings, no failure screen, no sheet, no prompt")
    func declinedShowsNoCity() async {
        let location = FakeLocationService(authorizationState: .denied)

        let viewModel = await Self.started(after: .locationDeclined, location: location)

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .openSettings)
        #expect(!viewModel.isSearchPresented)
        #expect(!location.didRequestAuthorization)
    }

    /// ONBOARDING-MOD-MAIN.md acceptance: both view models wired as the app
    /// does, from the upsell's Use my location to the main screen.
    @Test("Don't Allow shows That's okay; Got it lands on noCity with Open Settings")
    func dontAllowThenGotItLandsOnNoCity() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let viewModel = Self.makeLocationViewModel(location: location)
        let onboarding = OnboardingViewModel(
            locationService: location,
            placeStore: InMemoryPlaceStore(),
            onboardingStore: InMemoryOnboardingStore(),
            onFinish: { [weak viewModel] outcome in viewModel?.onboardingDidFinish(outcome) }
        )
        onboarding.getStarted()

        await onboarding.useMyLocation()
        #expect(onboarding.isPresented)
        #expect(onboarding.step == .locationDeclined)
        #expect(!viewModel.isNoCity)

        onboarding.gotIt()
        await viewModel.start()

        #expect(!onboarding.isPresented)
        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .openSettings)
    }

    @Test("Location Services off: Open Settings; restricted: no CTA, never a dead one", arguments: [
        (LocationAuthState.servicesOff, LocationViewModel.NoCityAction?.some(.openSettings)),
        (.restricted, nil),
    ])
    func blockedStatesCTA(state: LocationAuthState, action: LocationViewModel.NoCityAction?) async {
        let viewModel = await Self.started(after: .locationDeclined, location: FakeLocationService(authorizationState: state))

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == action)
    }

    @Test("Search instead: noCity with Enable location; search doesn't open, no prompt")
    func searchInsteadShowsNoCity() async {
        let location = FakeLocationService()

        let viewModel = await Self.started(after: .searchInstead, location: location)

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .enableLocation)
        #expect(!viewModel.isSearchPresented)
        #expect(!location.didRequestAuthorization)
    }

    @Test("Forced onboarding from a displayed and saved city → Search instead: fresh noCity, saved data intact")
    func replaySearchInsteadClearsDisplayedCity() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: store)
        await viewModel.start()
        Self.expectResolved(viewModel, on: Self.sydney)

        viewModel.onboardingDidFinish(.searchInstead)
        await viewModel.start()

        Self.expectNoCity(viewModel)
        #expect(store.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
        #expect(location.currentPlaceCount == 0)
    }

    @Test("Forced onboarding with only a persisted city → Got it: saved city is not restored into noCity")
    func replayDeclinedIgnoresPersistedOnlyCity() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let viewModel = Self.makeLocationViewModel(
            location: FakeLocationService(authorizationState: .denied),
            placeStore: store
        )

        viewModel.onboardingDidFinish(.locationDeclined)
        await viewModel.start()

        Self.expectNoCity(viewModel)
        #expect(store.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
    }

    @Test("Forced declined → Got it from an existing city: fresh noCity without deleting the saved city")
    func forcedDeclinedGotItClearsDisplayedCity() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: store)
        await viewModel.start()
        let onboarding = OnboardingViewModel(
            locationService: location,
            placeStore: store,
            onboardingStore: InMemoryOnboardingStore(isOnboardingCompleted: true),
            onFinish: { [weak viewModel] outcome in viewModel?.onboardingDidFinish(outcome) }
        )
        onboarding.forceShow(startingAt: .locationDeclined)

        onboarding.gotIt()
        await viewModel.start()

        Self.expectNoCity(viewModel)
        #expect(store.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
    }

    @Test("Authorized Search instead does not detect or restore a city until the user acts")
    func replaySearchInsteadAuthorizedStaysNoCity() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: store)
        viewModel.select(Self.sydney)

        viewModel.onboardingDidFinish(.searchInstead)
        await viewModel.start()
        await Self.openAndCloseSearch(on: viewModel)

        Self.expectNoCity(viewModel)
        #expect(location.currentPlaceCount == 0)
        #expect(store.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
    }

    @Test("LocationAllowed replay ignores the old city and resolves only the explicitly requested fix")
    func replayAllowedUsesExplicitGPS() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: store)
        viewModel.select(Self.sydney)

        viewModel.onboardingDidFinish(.locationAllowed)
        await viewModel.start()

        Self.expectResolved(viewModel, on: Self.detected)
        #expect(location.currentPlaceCount == 1)
        #expect(viewModel.loader.flightStartedAt != nil)
        #expect(store.lastViewed == Self.detected)
        #expect(store.recents == [Self.sydney])
    }

    @Test("LocationAllowed replay failure remains truly noCity and keeps the remembered city only in storage")
    func replayAllowedFailureStaysNoCity() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let location = FakeLocationService(authorizationState: .authorized)
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: store)
        viewModel.select(Self.sydney)

        viewModel.onboardingDidFinish(.locationAllowed)
        await viewModel.start()

        Self.expectNoCity(viewModel)
        #expect(location.currentPlaceCount == 1)
        #expect(store.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
    }

    @Test("A cancelled pre-replay fix cannot repopulate the fresh noCity page")
    func replayCancelsLateOldFix() async {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        location.holdsFixes = true
        let viewModel = Self.makeLocationViewModel(location: location)
        let oldLaunch = Task { await viewModel.start() }
        for _ in 0..<1_000 where location.heldFixCount == 0 {
            await Task.yield()
        }

        viewModel.onboardingDidFinish(.searchInstead)
        location.releaseFixes()
        await oldLaunch.value
        await viewModel.start()

        Self.expectNoCity(viewModel)
        #expect(location.currentPlaceCount == 1)
    }

    // MARK: - Search close and pick

    @Test("Search close from noCity leaves noCity, whichever way onboarding ended", arguments: [
        (OnboardingViewModel.Outcome.searchInstead, LocationAuthState.notDetermined),
        (.locationDeclined, .denied),
        (.locationAllowed, .authorized),
    ])
    func searchCloseLeavesNoCity(outcome: OnboardingViewModel.Outcome, state: LocationAuthState) async {
        let location = FakeLocationService(authorizationState: state)
        let viewModel = await Self.started(after: outcome, location: location)

        await Self.openAndCloseSearch(on: viewModel)

        Self.expectNoCity(viewModel)
        #expect(!viewModel.isSearchPresented)
        #expect(!location.didRequestAuthorization)
    }

    @Test("Search close twice in a row still leaves noCity")
    func searchCloseRepeated() async {
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService())

        await Self.openAndCloseSearch(on: viewModel)
        await Self.openAndCloseSearch(on: viewModel)

        Self.expectNoCity(viewModel)
    }

    @Test("Search pick: noCity → resolved, the city remembered and a recent")
    func searchPickResolves() async {
        let placeStore = InMemoryPlaceStore()
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService(), placeStore: placeStore)
        viewModel.open(.place)

        viewModel.select(Self.sydney)

        Self.expectResolved(viewModel, on: Self.sydney)
        #expect(!viewModel.isSearchPresented)
        #expect(placeStore.lastViewed == Self.sydney)
        #expect(placeStore.recents == [Self.sydney])
    }

    /// STEP-5.13 §3: shown on noCity too; denied and off open Settings from
    /// it. Restricted hides it, since Settings can't help.
    @Test("The sheet's Use my location row on noCity: shown unless restricted", arguments: [
        (LocationAuthState.notDetermined, true),
        (.denied, true),
        (.servicesOff, true),
        (.restricted, false),
    ])
    func searchRowOnNoCity(state: LocationAuthState, showsRow: Bool) async {
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService(authorizationState: state))

        viewModel.open(.place)

        #expect(viewModel.searchSheet?.showsUseMyLocation == showsRow)
    }

    @Test("On noCity the date token opens nothing; the place token opens search")
    func dateTokenInertOnNoCity() async {
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService())

        #expect(!viewModel.opens(.date))
        #expect(viewModel.opens(.place))
        viewModel.open(.date)
        #expect(!viewModel.isCalendarPresented)
        viewModel.open(.place)
        #expect(viewModel.isSearchPresented)
    }

    @Test("Once a city is set the date token opens the calendar again")
    func dateTokenOpensWhenResolved() async {
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService())
        viewModel.select(Self.sydney)

        #expect(viewModel.opens(.date))
        viewModel.open(.date)
        #expect(viewModel.isCalendarPresented)
    }

    // MARK: - The sheet's location row (STEP-5.13 §3)

    @Test("Row on noCity, not determined: the sheet closes, then Enable location's flow fills the city in")
    func rowNotDeterminedRunsEnableLocation() async throws {
        let location = FakeLocationService(placeResult: .success(Self.detected))
        location.stateAfterRequest = .authorized
        let viewModel = await Self.started(after: .searchInstead, location: location)
        viewModel.open(.place)
        let sheet = try #require(viewModel.searchSheet)

        sheet.useMyLocation()
        #expect(!viewModel.isSearchPresented)
        #expect(sheet.settingsRequestCount == 0)
        await viewModel.searchDidDismiss()

        #expect(location.requestAuthorizationCount == 1)
        Self.expectResolved(viewModel, on: Self.detected)
    }

    @Test("Row on noCity, denied: Settings and the sheet stays; back authorized, the sheet closes and the city fills in")
    func rowDeniedOpensSettingsThenFinishesAsAllow() async throws {
        let location = FakeLocationService(authorizationState: .denied, placeResult: .success(Self.detected))
        let viewModel = await Self.started(after: .locationDeclined, location: location)
        viewModel.open(.place)
        let sheet = try #require(viewModel.searchSheet)

        sheet.useMyLocation()

        #expect(sheet.settingsRequestCount == 1)
        #expect(viewModel.isSearchPresented)
        #expect(location.requestAuthorizationCount == 0)
        Self.expectNoCity(viewModel)

        location.authorizationState = .authorized
        await viewModel.sceneDidBecomeActive()
        #expect(!viewModel.isSearchPresented)
        await viewModel.searchDidDismiss()

        Self.expectResolved(viewModel, on: Self.detected)
    }

    @Test("Row on noCity, denied, back still denied: the sheet stays up on noCity")
    func rowDeniedStillDeniedKeepsSheet() async throws {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = await Self.started(after: .locationDeclined, location: location)
        viewModel.open(.place)
        try #require(viewModel.searchSheet).useMyLocation()

        await viewModel.sceneDidBecomeActive()

        #expect(viewModel.isSearchPresented)
        Self.expectNoCity(viewModel)
    }

    @Test("Row on noCity, Settings makes permission requestable: the sheet dismisses before one prompt, then Allow resolves")
    func rowSettingsRequestableThenAllow() async throws {
        let location = FakeLocationService(authorizationState: .denied, placeResult: .success(Self.detected))
        let viewModel = await Self.started(after: .locationDeclined, location: location)
        viewModel.open(.place)
        try #require(viewModel.searchSheet).useMyLocation()

        location.authorizationState = .notDetermined
        location.stateAfterRequest = .authorized
        location.holdsFixes = true
        await viewModel.sceneDidBecomeActive()

        #expect(!viewModel.isSearchPresented)
        #expect(location.requestAuthorizationCount == 0)
        let dismissal = Task { await viewModel.searchDidDismiss() }
        for _ in 0..<1_000 where location.heldFixCount == 0 {
            await Task.yield()
        }

        #expect(viewModel.launchStage == .phaseCycle)
        #expect(viewModel.loader.content == .searching)
        #expect(viewModel.loader.flightStartedAt == nil)
        location.releaseFixes()
        await dismissal.value

        #expect(location.requestAuthorizationCount == 1)
        Self.expectResolved(viewModel, on: Self.detected)
        #expect(viewModel.loader.flightStartedAt != nil)
    }

    @Test("Row on noCity, Settings makes permission requestable: Don't Allow stays on noCity")
    func rowSettingsRequestableThenDeny() async throws {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = await Self.started(after: .locationDeclined, location: location)
        viewModel.open(.place)
        try #require(viewModel.searchSheet).useMyLocation()

        location.authorizationState = .notDetermined
        location.stateAfterRequest = .denied
        await viewModel.sceneDidBecomeActive()
        #expect(!viewModel.isSearchPresented)
        await viewModel.searchDidDismiss()

        #expect(location.requestAuthorizationCount == 1)
        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .openSettings)
    }

    @Test("A suggested city picked on noCity resolves it and becomes a recent")
    func suggestedCityPickResolves() async throws {
        let placeStore = InMemoryPlaceStore()
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService(), placeStore: placeStore)
        viewModel.open(.place)
        let sheet = try #require(viewModel.searchSheet)
        let tokyo = try #require(sheet.suggestedCities.first { $0.place.name == "Tokyo" })

        sheet.pick(tokyo)

        Self.expectResolved(viewModel, on: tokyo.place)
        #expect(viewModel.place?.timeZone.identifier == "Asia/Tokyo")
        #expect(placeStore.recents == [tokyo.place])
        #expect(!viewModel.isSearchPresented)
    }

    // MARK: - Enable location

    @Test("Enable location → Allow: the prompt over this screen, then the city fills in")
    func enableLocationAllowResolves() async {
        let location = FakeLocationService(placeResult: .success(Self.detected))
        location.stateAfterRequest = .authorized
        let viewModel = await Self.started(after: .searchInstead, location: location)
        location.holdsFixes = true

        let request = Task { await viewModel.enableLocationFromNoCity() }
        for _ in 0..<1_000 where location.heldFixCount == 0 {
            await Task.yield()
        }

        #expect(viewModel.launchStage == .phaseCycle)
        #expect(viewModel.loader.content == .searching)
        #expect(viewModel.loader.flightStartedAt == nil)
        location.releaseFixes()
        await request.value

        #expect(location.requestAuthorizationCount == 1)
        Self.expectResolved(viewModel, on: Self.detected)
        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.loader.flightStartedAt != nil)
    }

    @Test("Enable location → Don't Allow: stays on noCity, CTA becomes Open Settings")
    func enableLocationDenyShowsOpenSettings() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let viewModel = await Self.started(after: .searchInstead, location: location)

        await viewModel.enableLocationFromNoCity()

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .openSettings)
        #expect(viewModel.locationOffDialog == nil)
    }

    @Test("Enable location with a missed fix: stays on noCity, no failure screen")
    func enableLocationMissStaysOnNoCity() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .authorized
        let viewModel = await Self.started(after: .searchInstead, location: location)

        await viewModel.enableLocationFromNoCity()

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .enableLocation)
    }

    @Test("Back from Settings with access granted: the city fills in on this screen")
    func settingsReturnAuthorizedResolves() async {
        let location = FakeLocationService(authorizationState: .denied, placeResult: .success(Self.detected))
        let viewModel = await Self.started(after: .locationDeclined, location: location)

        location.authorizationState = .authorized
        await viewModel.sceneDidBecomeActive()

        Self.expectResolved(viewModel, on: Self.detected)
    }

    @Test("Back from Settings still denied: noCity and Open Settings stay")
    func settingsReturnStillDenied() async {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = await Self.started(after: .locationDeclined, location: location)

        await viewModel.sceneDidBecomeActive()

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == .openSettings)
    }

    // MARK: - Start with [city]

    @Test("Start with: the device time zone's city, filled in place")
    func startWithResolves() async throws {
        let placeStore = InMemoryPlaceStore()
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService(), placeStore: placeStore)
        let city = try #require(TimeZoneCity.losAngeles)
        #expect(viewModel.noCityStartCity == city)
        let generation = viewModel.loadInGeneration

        viewModel.startWithSuggestedCity()

        Self.expectResolved(viewModel, on: city)
        #expect(placeStore.lastViewed == city)
        #expect(viewModel.loadInGeneration == generation + 1)
        #expect(viewModel.loader.flightStartedAt == nil)
    }

    @Test("Start with is hidden when the device time zone has no mapped city")
    func startWithHiddenForUnmappedZone() async {
        let viewModel = await Self.started(
            after: .searchInstead,
            location: FakeLocationService(),
            deviceTimeZone: TimeZone(identifier: "Europe/Paris") ?? .gmt
        )

        #expect(viewModel.noCityStartCity == nil)
        viewModel.startWithSuggestedCity()
        Self.expectNoCity(viewModel)
    }

    // MARK: - History and returning users

    @Test("Once resolved, a later start never returns to noCity or offers Back")
    func resolvedClearsOnboardingHistory() async {
        let placeStore = InMemoryPlaceStore()
        let viewModel = await Self.started(after: .searchInstead, location: FakeLocationService(), placeStore: placeStore)
        viewModel.select(Self.sydney)

        await viewModel.start()
        await Self.openAndCloseSearch(on: viewModel)

        Self.expectResolved(viewModel, on: Self.sydney)
    }

    @Test("A returning user with a saved city is unchanged: no noCity, no Back")
    func returningUserUnchanged() async {
        let viewModel = Self.makeLocationViewModel(
            location: FakeLocationService(authorizationState: .denied),
            placeStore: InMemoryPlaceStore(lastViewed: Self.sydney)
        )

        await viewModel.start()

        Self.expectResolved(viewModel, on: Self.sydney)
        #expect(viewModel.failureScreen == nil)
    }

    @Test("After onboarding, with no noCity, denied with nothing saved still gets its failure screen")
    func telescopeUnchangedAfterOnboarding() async {
        let viewModel = Self.makeLocationViewModel(location: FakeLocationService(authorizationState: .denied))

        await viewModel.start()

        #expect(!viewModel.isNoCity)
        #expect(viewModel.failureScreen == .permissionDenied)
    }

    // MARK: - Relaunch into noCity (STEP-5.14 §6.4)

    @Test("Relaunch after Got it or Search instead, nothing saved, no access: noCity with no loader or fix", arguments: [
        (LocationAuthState.denied, LocationViewModel.NoCityAction?.some(.openSettings)),
        (.notDetermined, .some(.enableLocation)),
        (.servicesOff, .some(.openSettings)),
        (.restricted, nil),
    ])
    func relaunchWithStoredNoCity(state: LocationAuthState, action: LocationViewModel.NoCityAction?) async {
        let onboardingStore = InMemoryOnboardingStore(isOnboardingCompleted: true, endedOnNoCity: true)
        let location = FakeLocationService(authorizationState: state)
        let viewModel = Self.makeLocationViewModel(location: location, onboardingStore: onboardingStore)

        await viewModel.start()

        Self.expectNoCity(viewModel)
        #expect(viewModel.noCityAction == action)
        #expect(location.currentPlaceCount == 0)
        #expect(!location.didRequestAuthorization)
        #expect(onboardingStore.endedOnNoCity)
    }

    @Test("Relaunch with the stored noCity but authorized: the normal launch, and the flag clears")
    func relaunchWithStoredNoCityAuthorized() async {
        let onboardingStore = InMemoryOnboardingStore(isOnboardingCompleted: true, endedOnNoCity: true)
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = Self.makeLocationViewModel(location: location, onboardingStore: onboardingStore)

        await viewModel.start()

        Self.expectResolved(viewModel, on: Self.detected)
        #expect(location.currentPlaceCount == 1)
        #expect(!onboardingStore.endedOnNoCity)
    }

    @Test("Relaunch with the stored noCity and a saved city: the saved city opens as usual")
    func relaunchWithStoredNoCityAndSavedPlace() async {
        let onboardingStore = InMemoryOnboardingStore(isOnboardingCompleted: true, endedOnNoCity: true)
        let viewModel = Self.makeLocationViewModel(
            location: FakeLocationService(authorizationState: .denied),
            placeStore: InMemoryPlaceStore(lastViewed: Self.sydney),
            onboardingStore: onboardingStore
        )

        await viewModel.start()

        Self.expectResolved(viewModel, on: Self.sydney)
        #expect(viewModel.failureScreen == nil)
        #expect(!onboardingStore.endedOnNoCity)
    }

    @Test("Picking a city on the relaunched noCity clears the flag; the next launch opens that city")
    func pickClearsStoredNoCity() async {
        let onboardingStore = InMemoryOnboardingStore(isOnboardingCompleted: true, endedOnNoCity: true)
        let placeStore = InMemoryPlaceStore()
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: placeStore, onboardingStore: onboardingStore)
        await viewModel.start()
        Self.expectNoCity(viewModel)

        viewModel.select(Self.sydney)

        Self.expectResolved(viewModel, on: Self.sydney)
        #expect(!onboardingStore.endedOnNoCity)

        let relaunched = Self.makeLocationViewModel(location: location, placeStore: placeStore, onboardingStore: onboardingStore)
        await relaunched.start()
        Self.expectResolved(relaunched, on: Self.sydney)
    }

    @Test("Granting access in Settings from the relaunched noCity clears the flag and fills the city")
    func settingsGrantClearsStoredNoCity() async {
        let onboardingStore = InMemoryOnboardingStore(isOnboardingCompleted: true, endedOnNoCity: true)
        let location = FakeLocationService(authorizationState: .denied, placeResult: .success(Self.detected))
        let viewModel = Self.makeLocationViewModel(location: location, onboardingStore: onboardingStore)
        await viewModel.start()
        Self.expectNoCity(viewModel)

        location.authorizationState = .authorized
        await viewModel.sceneDidBecomeActive()

        #expect(!onboardingStore.endedOnNoCity)
        #expect(viewModel.place == Self.detected)
        #expect(!viewModel.isNoCity)
    }

    @Test("Got it, then a relaunch: both view models wired as the app does land on noCity again")
    func gotItSurvivesRelaunch() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let placeStore = InMemoryPlaceStore()
        let onboardingStore = InMemoryOnboardingStore()
        let viewModel = Self.makeLocationViewModel(location: location, placeStore: placeStore, onboardingStore: onboardingStore)
        let onboarding = OnboardingViewModel(
            locationService: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore,
            onFinish: { [weak viewModel] outcome in viewModel?.onboardingDidFinish(outcome) }
        )
        onboarding.getStarted()
        await onboarding.useMyLocation()
        onboarding.gotIt()
        await viewModel.start()
        Self.expectNoCity(viewModel)

        let relaunchedOnboarding = OnboardingViewModel(
            locationService: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore
        )
        let relaunched = Self.makeLocationViewModel(location: location, placeStore: placeStore, onboardingStore: onboardingStore)
        await relaunched.start()

        #expect(!relaunchedOnboarding.isPresented)
        Self.expectNoCity(relaunched)
        #expect(relaunched.noCityAction == .openSettings)
    }

    @Test("Quit on That's okay before Got it, then a relaunch: the permission-off screen, unchanged")
    func quitOnDeclinedKeepsPermissionOffScreen() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let placeStore = InMemoryPlaceStore()
        let onboardingStore = InMemoryOnboardingStore()
        let onboarding = OnboardingViewModel(
            locationService: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore
        )
        onboarding.getStarted()
        await onboarding.useMyLocation()
        #expect(onboarding.step == .locationDeclined)

        let relaunchedOnboarding = OnboardingViewModel(
            locationService: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore
        )
        let relaunched = Self.makeLocationViewModel(location: location, placeStore: placeStore, onboardingStore: onboardingStore)
        await relaunched.start()

        #expect(!relaunchedOnboarding.isPresented)
        #expect(!relaunched.isNoCity)
        #expect(relaunched.failureScreen == .permissionDenied)
    }
}
