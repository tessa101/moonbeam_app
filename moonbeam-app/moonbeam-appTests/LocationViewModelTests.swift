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

    /// Los Angeles as it comes back from storage: never flagged as current.
    private static let savedLosAngeles: Place = {
        var saved = detectedLosAngeles
        saved.isCurrentLocation = false
        return saved
    }()

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
        #expect(viewModel.searchFieldTitle == LocationViewModel.searchPlaceholder)
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
        #expect(viewModel.searchFieldTitle == "Los Angeles")
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
        #expect(viewModel.searchFieldTitle == "Sydney")
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
        // SEARCH-RECENTS.md §3: the detected location never becomes a recent.
        #expect(store.recents.isEmpty)
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

    @Test("The chip returns to the saved place, makes it last-viewed again and adds it to recents")
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
        #expect(store.recents == [Self.sydney])
    }

    // MARK: - Search sheet flow (SEARCH-RECENTS.md §5)

    /// Opens the sheet and returns its model.
    private static func openSearch(_ viewModel: LocationViewModel) throws -> SearchSheetViewModel {
        viewModel.presentSearch()
        #expect(viewModel.isSearchPresented)
        return try #require(viewModel.searchSheet)
    }

    /// What SwiftUI does when the sheet finishes closing: the binding goes
    /// false (if it hasn't already), then `onDismiss` runs.
    private static func finishDismissingSearch(_ viewModel: LocationViewModel) async {
        viewModel.isSearchPresented = false
        await viewModel.searchDidDismiss()
    }

    @Test("Picking a suggestion from search shows it, closes the sheet and adds it to recents")
    func pickingFromSearchAddsToRecents() async throws {
        let store = InMemoryPlaceStore()
        let viewModel = Self.makeViewModel(search: Self.sydneySearch(), store: store)
        await viewModel.start()
        let sheet = try Self.openSearch(viewModel)

        sheet.query = "Syd"
        await sheet.searchTask?.value
        await sheet.pick(Self.sydneySuggestion)

        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.moonTable?.place == Self.sydney)
        #expect(viewModel.searchFieldTitle == "Sydney")
        #expect(!viewModel.isSearchPresented)
        #expect(store.lastViewed == Self.sydney)
        #expect(viewModel.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
    }

    @Test("Picking a recent moves it to the top of recents")
    func pickingARecentMovesItToTheTop() async throws {
        let store = InMemoryPlaceStore(recents: [Self.savedLosAngeles, Self.sydney])
        let viewModel = Self.makeViewModel(store: store)
        await viewModel.start()
        let sheet = try Self.openSearch(viewModel)

        sheet.pick(Self.sydney)

        #expect(viewModel.place == Self.sydney)
        #expect(store.recents == [Self.sydney, Self.savedLosAngeles])
        #expect(!viewModel.isSearchPresented)
    }

    @Test("A suggestion that won't resolve leaves the place, lastViewed and recents alone")
    func unresolvableSuggestionFromSearch() async throws {
        let search = Self.sydneySearch()
        search.resolveError = URLError(.notConnectedToInternet)
        let store = InMemoryPlaceStore()
        let viewModel = Self.makeViewModel(search: search, store: store)
        let sheet = try Self.openSearch(viewModel)

        await sheet.pick(Self.sydneySuggestion)

        #expect(viewModel.place == nil)
        #expect(store.lastViewed == nil)
        #expect(store.recents.isEmpty)
        // §8: the sheet stays open showing the failure.
        #expect(viewModel.isSearchPresented)
        #expect(sheet.listState == .failed)
    }

    @Test("Cancel leaves the place, lastViewed and recents unchanged")
    func cancelChangesNothing() async throws {
        let location = FakeLocationService(authorizationState: .denied)
        let store = InMemoryPlaceStore(lastViewed: Self.sydney, recents: [Self.sydney])
        let viewModel = Self.makeViewModel(location: location, store: store)
        await viewModel.start()
        let sheet = try Self.openSearch(viewModel)
        sheet.query = "Syd"

        await Self.finishDismissingSearch(viewModel)

        #expect(viewModel.place == Self.sydney)
        #expect(store.lastViewed == Self.sydney)
        #expect(store.recents == [Self.sydney])
        #expect(!viewModel.isSearchPresented)
        #expect(viewModel.locationOffDialog == nil)
        #expect(location.currentPlaceCount == 0)
    }

    /// §1: the sheet always opens with an empty field.
    @Test("Reopening the sheet starts with an empty field")
    func reopeningStartsEmpty() async throws {
        let viewModel = Self.makeViewModel(search: Self.sydneySearch())
        let first = try Self.openSearch(viewModel)
        first.query = "Syd"
        await Self.finishDismissingSearch(viewModel)

        let second = try Self.openSearch(viewModel)

        #expect(second.query.isEmpty)
    }

    // MARK: - Decision B

    @Test("The sheet hides the location row when the place is the detected location")
    func locationRowHiddenForDetectedPlace() async throws {
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(
                authorizationState: .authorized,
                placeResult: .success(Self.detectedLosAngeles)
            )
        )
        await viewModel.start()
        #expect(viewModel.place?.isCurrentLocation == true)

        #expect(try !Self.openSearch(viewModel).showsUseMyLocation)
    }

    @Test("The sheet shows the location row when the place was searched for")
    func locationRowShownForSearchedPlace() async throws {
        let viewModel = Self.makeViewModel(store: InMemoryPlaceStore(lastViewed: Self.sydney))
        await viewModel.start()

        #expect(try Self.openSearch(viewModel).showsUseMyLocation)
    }

    // MARK: - Decision A

    /// Nothing runs until the sheet has finished closing: the Location Off
    /// dialog can't present over a sheet that's still up.
    @Test("The location row closes the sheet, then runs the main-screen flow")
    func locationRowRunsFlowAfterDismiss() async throws {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let store = InMemoryPlaceStore(lastViewed: Self.sydney)
        let viewModel = Self.makeViewModel(location: location, store: store)
        await viewModel.start()
        // Launch detected Los Angeles; go back to Sydney so the row shows.
        viewModel.goBack()
        let fetchesBefore = location.currentPlaceCount
        let sheet = try Self.openSearch(viewModel)
        #expect(sheet.showsUseMyLocation)

        sheet.useMyLocation()

        #expect(!viewModel.isSearchPresented)
        #expect(location.currentPlaceCount == fetchesBefore)

        await viewModel.searchDidDismiss()

        #expect(location.currentPlaceCount == fetchesBefore + 1)
        #expect(viewModel.place == Self.detectedLosAngeles)
        // "Use my location" never adds to recents; Sydney is there from the chip.
        #expect(store.recents == [Self.sydney])
    }

    @Test("Location row with permission denied: the dialog shows, and Search instead reopens the sheet")
    func locationRowDeniedThenSearchInstead() async throws {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = Self.makeViewModel(
            location: location,
            store: InMemoryPlaceStore(lastViewed: Self.sydney)
        )
        await viewModel.start()
        let firstSheet = try Self.openSearch(viewModel)

        firstSheet.useMyLocation()
        #expect(viewModel.locationOffDialog == nil)
        await viewModel.searchDidDismiss()

        #expect(viewModel.locationOffDialog == .denied)
        #expect(!viewModel.isSearchPresented)

        viewModel.searchInsteadOfLocation()
        #expect(viewModel.locationOffDialog == nil)
        // Not until the dialog has finished closing.
        #expect(!viewModel.isSearchPresented)

        viewModel.locationOffDialogDidDismiss()

        #expect(viewModel.isSearchPresented)
        let reopened = try #require(viewModel.searchSheet)
        #expect(reopened !== firstSheet)
        #expect(reopened.query.isEmpty)
        #expect(viewModel.place == Self.sydney)
    }

    /// Open Settings and a drag-to-dismiss close the dialog too; neither
    /// should open the search sheet.
    @Test("Dismissing the dialog any other way doesn't open search")
    func dialogDismissedOtherwiseDoesNotOpenSearch() async {
        let viewModel = Self.makeViewModel(location: FakeLocationService(authorizationState: .denied))
        await viewModel.useMyLocation()
        #expect(viewModel.locationOffDialog == .denied)

        viewModel.dismissLocationOffDialog()
        viewModel.locationOffDialogDidDismiss()

        #expect(!viewModel.isSearchPresented)
    }

    // MARK: - Time zones (§5)

    /// The §5 case end to end: a Sydney place on a Los Angeles device reads
    /// in Sydney's clock and carries the label. Rise 14:24 AEST is the
    /// engine-derived ASTRONOMY.md §5 value (see PlaceTimeZoneTests).
    @Test("Sydney on a Los Angeles device: times in AEST and the label shown")
    func sydneyOnALosAngelesDevice() async throws {
        let viewModel = Self.makeViewModel()

        viewModel.select(Self.sydney)

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
