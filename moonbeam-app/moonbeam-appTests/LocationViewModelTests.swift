//
//  LocationViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `LocationViewModel`'s launch logic (LOCATION.md §3), permission branches
/// (§4) and time zone label (§5), against the fakes from §7.
@Suite("Location view model")
@MainActor
struct LocationViewModelTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    /// What a fix in Mar Vista reverse geocodes to: the city, not the
    /// neighbourhood (see `Place.placeName`).
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

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: sydneyZone
    )

    private static let sydneySuggestion = PlaceSuggestion(title: "Sydney", subtitle: "NSW, Australia")

    /// 2026-09-23 12:00 in Sydney, the ASTRONOMY.md §5 date.
    private static let referenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sydneyZone
        let components = DateComponents(year: 2026, month: 9, day: 23, hour: 12)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    /// Short, so the timeout test doesn't take the real 10 s.
    private static let testTimeout = Duration.milliseconds(50)

    /// Far longer than `testTimeout`: if the timeout didn't cancel the fix,
    /// the test would sit out this whole delay.
    private static let hangingFixDelay = Duration.seconds(30)

    private static func makeViewModel(
        location: FakeLocationService = FakeLocationService(),
        search: FakePlaceSearchService = FakePlaceSearchService(),
        store: InMemoryPlaceStore = InMemoryPlaceStore(),
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout
    ) -> LocationViewModel {
        LocationViewModel(
            locationService: location,
            placeSearch: search,
            placeStore: store,
            moonService: AstronomyEngineMoonService(),
            fetchTimeout: fetchTimeout,
            deviceTimeZone: losAngelesZone,
            now: { referenceDate }
        )
    }

    private static func sydneySearch() -> FakePlaceSearchService {
        FakePlaceSearchService(
            suggestionsByQuery: ["Syd": [sydneySuggestion]],
            placesBySuggestion: [sydneySuggestion.id: sydney]
        )
    }

    // MARK: - Launch (§3)

    @Test("First launch: empty state, button visible, no permission request")
    func firstLaunch() async {
        let location = FakeLocationService()
        let viewModel = Self.makeViewModel(location: location)

        await viewModel.start()

        #expect(viewModel.place == nil)
        #expect(viewModel.moonTable == nil)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.searchPrompt == LocationViewModel.searchPlaceholder)
        #expect(viewModel.showsUseMyLocation)
        #expect(viewModel.backToPlace == nil)
        #expect(!location.didRequestAuthorization)
        #expect(location.currentPlaceCount == 0)
    }

    @Test("Authorized with no saved place: the current place loads, no chip")
    func authorizedFetchSucceeds() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let viewModel = Self.makeViewModel(location: location)

        await viewModel.start()

        #expect(viewModel.place == Self.detectedLosAngeles)
        #expect(viewModel.place?.isCurrentLocation == true)
        #expect(viewModel.moonTable?.place == Self.detectedLosAngeles)
        #expect(viewModel.searchText == "Los Angeles")
        #expect(!viewModel.showsUseMyLocation)
        #expect(viewModel.backToPlace == nil)
        #expect(!viewModel.isLocating)
    }

    @Test("Authorized with a different saved place: the chip offers it")
    func authorizedShowsChipForADifferentSavedPlace() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney)
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(
                authorizationState: .authorized,
                placeResult: .success(Self.detectedLosAngeles)
            ),
            store: store
        )

        await viewModel.start()

        #expect(viewModel.place == Self.detectedLosAngeles)
        #expect(viewModel.backToPlace == Self.sydney)
        // Launch detection isn't a pick, so the chip survives a relaunch.
        #expect(store.lastViewed == Self.sydney)
    }

    /// `isCurrentLocation` is outside equality, so the saved copy (which
    /// never has it set) still matches the fresh fix.
    @Test("Authorized with the same saved place: no chip")
    func authorizedHidesChipForTheSameSavedPlace() async {
        var saved = Self.detectedLosAngeles
        saved.isCurrentLocation = false
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(
                authorizationState: .authorized,
                placeResult: .success(Self.detectedLosAngeles)
            ),
            store: InMemoryPlaceStore(lastViewed: saved)
        )

        await viewModel.start()

        #expect(viewModel.backToPlace == nil)
    }

    @Test("Authorized but the fix fails: falls back to the saved place")
    func authorizedFetchFailsFallsBack() async {
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(authorizationState: .authorized),
            store: InMemoryPlaceStore(lastViewed: Self.sydney)
        )

        await viewModel.start()

        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.moonTable?.place == Self.sydney)
        #expect(viewModel.showsUseMyLocation)
        #expect(viewModel.backToPlace == nil)
        // A launch fallback is quiet; the failure message is for taps.
        #expect(!viewModel.locationFailed)
    }

    @Test("Authorized but the fix fails with nothing saved: the empty state")
    func authorizedFetchFailsWithNothingSaved() async {
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(authorizationState: .authorized)
        )

        await viewModel.start()

        #expect(viewModel.place == nil)
        #expect(viewModel.showsUseMyLocation)
    }

    /// The timeout has to *cancel* the fix, which is what stops location
    /// updates — not just stop waiting for it.
    @Test("Authorized but the fix times out: the fix is cancelled and the saved place shown")
    func authorizedFetchTimesOut() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        location.fixDelay = Self.hangingFixDelay
        let viewModel = Self.makeViewModel(
            location: location,
            store: InMemoryPlaceStore(lastViewed: Self.sydney),
            fetchTimeout: Self.testTimeout
        )

        let clock = ContinuousClock()
        let started = clock.now
        await viewModel.start()
        let elapsed = clock.now - started

        #expect(location.cancelledFixCount == 1)
        #expect(elapsed < Self.hangingFixDelay)
        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.showsUseMyLocation)
        #expect(!viewModel.isLocating)
    }

    @Test(
        "Not authorized with a saved place: the saved place, button visible, nothing asked",
        arguments: [
            LocationAuthState.notDetermined, .denied, .restricted, .servicesOff,
        ]
    )
    func notAuthorizedShowsTheSavedPlace(state: LocationAuthState) async {
        let location = FakeLocationService(authorizationState: state)
        let viewModel = Self.makeViewModel(
            location: location,
            store: InMemoryPlaceStore(lastViewed: Self.sydney)
        )

        await viewModel.start()

        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.searchText == "Sydney")
        #expect(viewModel.showsUseMyLocation)
        #expect(!location.didRequestAuthorization)
        #expect(location.currentPlaceCount == 0)
        #expect(viewModel.locationOffDialog == nil)
    }

    // MARK: - "Use my location" (§4)

    @Test("Not determined: prompts, then fetches when granted")
    func notDeterminedPromptsThenFetches() async {
        let location = FakeLocationService(placeResult: .success(Self.detectedLosAngeles))
        location.stateAfterRequest = .authorized
        let store = InMemoryPlaceStore()
        let viewModel = Self.makeViewModel(location: location, store: store)
        await viewModel.start()

        await viewModel.useMyLocation()

        #expect(location.requestAuthorizationCount == 1)
        #expect(location.currentPlaceCount == 1)
        #expect(viewModel.place == Self.detectedLosAngeles)
        #expect(store.lastViewed == Self.detectedLosAngeles)
    }

    @Test("Not determined, refused at the prompt: no fetch and no dialog")
    func notDeterminedRefusedDoesNothingMore() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let viewModel = Self.makeViewModel(location: location)
        await viewModel.start()

        await viewModel.useMyLocation()

        #expect(location.requestAuthorizationCount == 1)
        #expect(location.currentPlaceCount == 0)
        #expect(viewModel.locationOffDialog == nil)
        #expect(viewModel.showsUseMyLocation)
    }

    @Test("Authorized: fetches without prompting, and remembers the place")
    func authorizedTapFetches() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let store = InMemoryPlaceStore(lastViewed: Self.sydney)
        let viewModel = Self.makeViewModel(location: location, store: store)

        await viewModel.useMyLocation()

        #expect(!location.didRequestAuthorization)
        #expect(viewModel.place == Self.detectedLosAngeles)
        #expect(store.lastViewed == Self.detectedLosAngeles)
        #expect(viewModel.backToPlace == nil)
    }

    @Test("Authorized, but a tapped fix fails: the place stays and the failure shows")
    func authorizedTapFailureIsReported() async {
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(authorizationState: .authorized),
            store: InMemoryPlaceStore(lastViewed: Self.sydney)
        )
        await viewModel.start()

        await viewModel.useMyLocation()

        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.locationFailed)
        #expect(viewModel.showsUseMyLocation)
    }

    @Test(
        "Denied, services off and restricted each open their own dialog",
        arguments: [
            (LocationAuthState.denied, LocationViewModel.LocationOffVariant.denied),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
        ]
    )
    func blockedStatesOpenTheirDialog(
        state: LocationAuthState,
        expected: LocationViewModel.LocationOffVariant
    ) async {
        let location = FakeLocationService(authorizationState: state)
        let viewModel = Self.makeViewModel(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.locationOffDialog == expected)
        #expect(!location.didRequestAuthorization)
        #expect(location.currentPlaceCount == 0)
    }

    @Test("Only the restricted variant has no Settings button")
    func restrictedOffersNoSettings() {
        #expect(LocationViewModel.LocationOffVariant.denied.offersSettings)
        #expect(LocationViewModel.LocationOffVariant.servicesOff.offersSettings)
        #expect(!LocationViewModel.LocationOffVariant.restricted.offersSettings)
    }

    // MARK: - Back from Settings (§4)

    @Test("Foreground after Settings with permission newly granted: fetches automatically")
    func foregroundWithNewPermissionFetches() async {
        let location = FakeLocationService(
            authorizationState: .denied,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let viewModel = Self.makeViewModel(location: location)
        await viewModel.start()
        await viewModel.useMyLocation()
        #expect(viewModel.locationOffDialog == .denied)

        location.authorizationState = .authorized
        await viewModel.sceneDidBecomeActive()

        #expect(location.currentPlaceCount == 1)
        #expect(viewModel.place == Self.detectedLosAngeles)
        #expect(viewModel.locationOffDialog == nil)
    }

    @Test("Foreground with permission unchanged: no fetch", arguments: [
        LocationAuthState.denied, .authorized,
    ])
    func foregroundWithUnchangedPermissionDoesNothing(state: LocationAuthState) async {
        let location = FakeLocationService(
            authorizationState: state,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let viewModel = Self.makeViewModel(location: location)
        await viewModel.start()
        let fetchesAtLaunch = location.currentPlaceCount

        await viewModel.sceneDidBecomeActive()

        #expect(location.currentPlaceCount == fetchesAtLaunch)
    }

    // MARK: - Choosing a place

    @Test("Choosing a suggestion shows it and makes it the last-viewed place")
    func choosingASuggestionUpdatesLastViewed() async {
        let store = InMemoryPlaceStore()
        let viewModel = Self.makeViewModel(search: Self.sydneySearch(), store: store)
        await viewModel.start()

        await viewModel.choose(Self.sydneySuggestion)

        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.moonTable?.place == Self.sydney)
        #expect(viewModel.searchText == "Sydney")
        #expect(viewModel.suggestionsState == .hidden)
        #expect(store.lastViewed == Self.sydney)
        #expect(viewModel.lastViewed == Self.sydney)
    }

    @Test("A suggestion that won't resolve leaves the place alone")
    func unresolvableSuggestion() async {
        let search = Self.sydneySearch()
        search.resolveError = URLError(.notConnectedToInternet)
        let store = InMemoryPlaceStore()
        let viewModel = Self.makeViewModel(search: search, store: store)

        await viewModel.choose(Self.sydneySuggestion)

        #expect(viewModel.place == nil)
        #expect(viewModel.suggestionsState == .failed)
        #expect(store.lastViewed == nil)
    }

    @Test("The chip returns to the saved place and makes it last-viewed again")
    func chipReturnsToTheSavedPlace() async {
        let store = InMemoryPlaceStore(lastViewed: Self.sydney)
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(
                authorizationState: .authorized,
                placeResult: .success(Self.detectedLosAngeles)
            ),
            store: store
        )
        await viewModel.start()

        viewModel.goBack()

        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.backToPlace == nil)
        #expect(viewModel.showsUseMyLocation)
        #expect(store.lastViewed == Self.sydney)
    }

    @Test("Clearing the field clears the text, not the place")
    func clearingTheFieldKeepsThePlace() async {
        let viewModel = Self.makeViewModel(store: InMemoryPlaceStore(lastViewed: Self.sydney))
        await viewModel.start()

        viewModel.clearSearch()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.place == Self.sydney)
    }

    // MARK: - Suggestions list (§3)

    @Test("Suggestion list states: results, none, failure, and empty query")
    func suggestionStates() async {
        let search = Self.sydneySearch()
        let viewModel = Self.makeViewModel(search: search)

        await viewModel.updateSuggestions(for: "Syd")
        #expect(viewModel.suggestionsState == .results([Self.sydneySuggestion]))

        await viewModel.updateSuggestions(for: "Xyzzy")
        #expect(viewModel.suggestionsState == .noResults)

        await viewModel.updateSuggestions(for: "   ")
        #expect(viewModel.suggestionsState == .hidden)

        search.searchError = URLError(.notConnectedToInternet)
        await viewModel.updateSuggestions(for: "Syd")
        #expect(viewModel.suggestionsState == .failed)
    }

    // MARK: - Time zones (§5)

    /// The §5 case end to end: a Sydney place on a Los Angeles device reads
    /// in Sydney's clock and carries the label. Rise 14:24 AEST is the
    /// engine-derived ASTRONOMY.md §5 value (see PlaceTimeZoneTests).
    @Test("Sydney on a Los Angeles device: times in AEST and the label shown")
    func sydneyOnALosAngelesDevice() async throws {
        let viewModel = Self.makeViewModel(search: Self.sydneySearch())

        await viewModel.choose(Self.sydneySuggestion)

        let moonTable = try #require(viewModel.moonTable)
        let rise = try #require(moonTable.moonDay.rise)

        var sydneyCalendar = Calendar(identifier: .gregorian)
        sydneyCalendar.timeZone = Self.sydneyZone
        #expect(sydneyCalendar.component(.hour, from: rise.date) == 14)

        var sydneyStyle = Date.FormatStyle.dateTime.hour().minute()
        sydneyStyle.timeZone = Self.sydneyZone
        var losAngelesStyle = sydneyStyle
        losAngelesStyle.timeZone = Self.losAngelesZone
        #expect(moonTable.riseText.hasPrefix(rise.date.formatted(sydneyStyle)))
        #expect(!moonTable.riseText.hasPrefix(rise.date.formatted(losAngelesStyle)))

        let label = try #require(viewModel.timeZoneLabel)
        let abbreviation = try #require(Self.sydneyZone.abbreviation(for: Self.referenceDate))
        #expect(label == "Sydney · \(abbreviation)")
        #expect(viewModel.timeZoneAccessibilityLabel != nil)
    }

    @Test("Los Angeles on a Los Angeles device: no label")
    func losAngelesOnALosAngelesDevice() async {
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(
                authorizationState: .authorized,
                placeResult: .success(Self.detectedLosAngeles)
            )
        )

        await viewModel.start()

        #expect(viewModel.place != nil)
        #expect(viewModel.timeZoneLabel == nil)
        #expect(viewModel.timeZoneAccessibilityLabel == nil)
    }
}
