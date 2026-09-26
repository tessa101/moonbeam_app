//
//  LocationViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation

/// Gets the user to a `Place`, by detecting it or by city search, and owns
/// the launch logic (LOCATION.md §3) and permission branches (§4) that decide
/// which.
///
/// The only writer of the place, `lastViewed` and recents. City search lives
/// in `SearchSheetViewModel`, which reports picks back here
/// (SEARCH-RECENTS.md §4).
///
/// Main-actor isolated (the project default), like the three location
/// services it drives. The services come in through the initializer, so
/// tests run the same logic against fakes.
@Observable
final class LocationViewModel {

    // MARK: - Types

    /// Which copy the custom Location Off dialog shows (§4).
    enum LocationOffVariant: Identifiable, Equatable {
        case denied
        case servicesOff
        case restricted

        var id: Self { self }

        /// Restricted is a device policy the user can't change, so Settings
        /// would be a dead end.
        var offersSettings: Bool { self != .restricted }
    }

    // MARK: - Constants

    /// §3: how long a launch waits for a fix before falling back to the
    /// last-viewed place.
    static let defaultFetchTimeout = Duration.seconds(10)

    static let searchPlaceholder = "Search for a city"

    /// Separates the city from the zone in the §3 label: "Sydney · AEST".
    private static let timeZoneLabelSeparator = " · "

    // MARK: - Observed state

    /// The place the moon table is for, or `nil` for the empty first-launch
    /// state.
    private(set) var place: Place?

    /// The moon table for `place`, rebuilt whenever the place changes.
    private(set) var moonTable: SpikeMoonTableViewModel?

    /// Mirrors `placeStore.lastViewed`, which isn't observable itself.
    private(set) var lastViewed: Place?

    /// A location fix is in flight.
    private(set) var isLocating = false

    /// A fix the user asked for didn't arrive. Launch fetches don't set this:
    /// §3 has them fall back quietly.
    private(set) var locationFailed = false

    /// Settable so the view's sheet binding can dismiss it.
    var locationOffDialog: LocationOffVariant?

    /// Settable so the view's sheet binding can dismiss it (Cancel, drag).
    var isSearchPresented = false

    /// The open (or most recently open) search sheet's model. Rebuilt on
    /// every `presentSearch()` so the field always opens empty
    /// (SEARCH-RECENTS.md §1).
    private(set) var searchSheet: SearchSheetViewModel?

    // MARK: - Dependencies

    private let locationService: any LocationService
    private let placeSearch: any PlaceSearchService
    @ObservationIgnored private let placeStore: any PlaceStore
    private let moonService: any MoonService
    private let fetchTimeout: Duration
    private let deviceTimeZone: TimeZone
    private let now: () -> Date

    // MARK: - Bookkeeping

    @ObservationIgnored private var locateTask: Task<Void, Never>?

    /// Decision A: the search sheet's location row closes the sheet, and the
    /// flow runs once it has gone, because the Location Off dialog can't
    /// present over a sheet that's still up.
    @ObservationIgnored private var useMyLocationAfterSearch = false

    /// "Search instead" reopens the search sheet once the dialog has gone,
    /// for the same reason in reverse.
    @ObservationIgnored private var presentSearchAfterDialog = false

    /// The system prompt briefly deactivates the scene. Its return to active
    /// mustn't count as "back from Settings" and start a second fetch.
    @ObservationIgnored private var isRequestingPermission = false

    /// The state last seen, so a return to the foreground can tell "newly
    /// authorized" (fetch) from "still authorized" (leave alone).
    @ObservationIgnored private var lastSeenAuthState: LocationAuthState

    // MARK: - Init

    /// - Parameters:
    ///   - fetchTimeout: injectable so tests needn't wait the full 10 s.
    ///   - deviceTimeZone: injectable because a test process can't change
    ///     `TimeZone.current`.
    ///   - now: the day the moon table is for.
    init(
        locationService: any LocationService,
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        moonService: any MoonService,
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout,
        deviceTimeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.locationService = locationService
        self.placeSearch = placeSearch
        self.placeStore = placeStore
        self.moonService = moonService
        self.fetchTimeout = fetchTimeout
        self.deviceTimeZone = deviceTimeZone
        self.now = now
        lastSeenAuthState = locationService.authorizationState
    }

    // MARK: - Derived state

    /// §3: shown whenever the place isn't the detected current location.
    /// Hidden while a fix is in flight, since tapping it would only restart it.
    var showsUseMyLocation: Bool {
        !isLocating && !(place?.isCurrentLocation ?? false)
    }

    /// The "Back to {City}" chip. Every place the user picks becomes
    /// `lastViewed`, so the two only differ after a launch detects somewhere
    /// else — exactly when §3 wants the chip.
    var backToPlace: Place? {
        guard let lastViewed, let place, lastViewed != place else { return nil }
        return lastViewed
    }

    /// §3: while a launch fetch runs, the last-viewed name stands in so the
    /// screen isn't blank.
    var searchPrompt: String {
        if isLocating, place == nil, let lastViewed { return lastViewed.shortName }
        return Self.searchPlaceholder
    }

    /// What the main-screen search button shows: the current city, or the
    /// prompt when there isn't one yet (SEARCH-RECENTS.md §1).
    var searchFieldTitle: String {
        place?.shortName ?? searchPrompt
    }

    /// "Sydney · AEST", only when the place's clock differs from the device's
    /// (§3, §5). The abbreviation is whatever the user's locale calls the
    /// zone, which for some locales is "GMT+10" rather than "AEST".
    var timeZoneLabel: String? {
        guard let place, let abbreviation = timeZoneAbbreviation(for: place) else { return nil }
        return place.shortName + Self.timeZoneLabelSeparator + abbreviation
    }

    var timeZoneAccessibilityLabel: String? {
        guard let place, let abbreviation = timeZoneAbbreviation(for: place) else { return nil }
        return "Times shown in \(place.shortName) time, \(abbreviation)"
    }

    // MARK: - Launch (§3)

    /// Runs once when the screen appears. Never prompts for permission.
    func start() async {
        lastViewed = placeStore.lastViewed
        let state = locationService.authorizationState
        lastSeenAuthState = state

        if state.isAuthorized {
            await locate(userInitiated: false)
        } else if let lastViewed {
            show(lastViewed, remember: false)
        }
    }

    // MARK: - Permission branches (§4)

    func useMyLocation() async {
        switch locationService.authorizationState {
        case .notDetermined:
            isRequestingPermission = true
            let state = await locationService.requestAuthorization()
            isRequestingPermission = false
            lastSeenAuthState = state
            // A refusal at the prompt ends here: the user has just answered,
            // so following up with the Location Off dialog would nag.
            if state.isAuthorized {
                await locate(userInitiated: true)
            }
        case .authorized:
            await locate(userInitiated: true)
        case .denied:
            locationOffDialog = .denied
        case .restricted:
            locationOffDialog = .restricted
        case .servicesOff:
            locationOffDialog = .servicesOff
        }
    }

    /// Call when the scene becomes active. §4: coming back from Settings with
    /// permission newly granted fetches without another tap.
    func sceneDidBecomeActive() async {
        guard !isRequestingPermission else { return }

        let state = locationService.authorizationState
        let wasAuthorized = lastSeenAuthState.isAuthorized
        lastSeenAuthState = state

        guard state.isAuthorized, !wasAuthorized else { return }
        locationOffDialog = nil
        guard !isLocating else { return }
        await locate(userInitiated: true)
    }

    func dismissLocationOffDialog() {
        locationOffDialog = nil
    }

    /// The dialog's "Search instead" / "Search for a city". The sheet opens
    /// in `locationOffDialogDidDismiss()`.
    func searchInsteadOfLocation() {
        presentSearchAfterDialog = true
        locationOffDialog = nil
    }

    /// Call from the dialog sheet's `onDismiss`.
    func locationOffDialogDidDismiss() {
        guard presentSearchAfterDialog else { return }
        presentSearchAfterDialog = false
        presentSearch()
    }

    // MARK: - Search sheet (SEARCH-RECENTS.md §2)

    func presentSearch() {
        searchSheet = SearchSheetViewModel(
            placeSearch: placeSearch,
            placeStore: placeStore,
            showsUseMyLocation: showsUseMyLocation,
            onPick: { [weak self] place in self?.select(place) },
            onUseMyLocation: { [weak self] in self?.useMyLocationFromSearch() }
        )
        isSearchPresented = true
    }

    /// Call from the search sheet's `onDismiss`. Runs the location flow if
    /// the sheet was closed by its location row (Decision A); Cancel, a drag
    /// and a pick all land here too and do nothing further.
    func searchDidDismiss() async {
        guard useMyLocationAfterSearch else { return }
        useMyLocationAfterSearch = false
        await useMyLocation()
    }

    private func useMyLocationFromSearch() {
        useMyLocationAfterSearch = true
        isSearchPresented = false
    }

    // MARK: - Choosing a place

    /// A place picked in the search sheet, from recents or a resolved
    /// suggestion. Closes the sheet.
    func select(_ place: Place) {
        stopLocating()
        show(place, remember: true)
        addToRecents(place)
        isSearchPresented = false
    }

    /// The "Back to {City}" chip.
    func goBack() {
        guard let backToPlace else { return }
        stopLocating()
        show(backToPlace, remember: true)
        addToRecents(backToPlace)
    }

    /// Only picked places become recents; a detected place never does
    /// (SEARCH-RECENTS.md §3). "Use my location" doesn't call this, and the
    /// guard covers a detected place reaching here some other way.
    private func addToRecents(_ place: Place) {
        guard !place.isCurrentLocation else { return }
        placeStore.addRecent(place)
    }

    // MARK: - Locating

    /// Runs one fix in a task of its own, so picking a place meanwhile can
    /// cancel it and a late fix can't overwrite the user's choice.
    private func locate(userInitiated: Bool) async {
        locateTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await performLocate(userInitiated: userInitiated)
        }
        locateTask = task
        await task.value
    }

    private func performLocate(userInitiated: Bool) async {
        isLocating = true
        locationFailed = false

        do {
            let detected = try await currentPlaceWithTimeout()
            guard !Task.isCancelled else { return }
            // Launch detection isn't a pick, so it doesn't replace the saved
            // place — that's what keeps "Back to {City}" one tap away.
            show(detected, remember: userInitiated)
        } catch {
            guard !Task.isCancelled else { return }
            if userInitiated {
                locationFailed = true
            } else if let lastViewed {
                show(lastViewed, remember: false)
            }
        }

        isLocating = false
    }

    /// `currentPlace()` with the §3 timeout.
    ///
    /// When the timeout fires it *cancels* the fetch, which is what stops
    /// CoreLocation's updates; just abandoning the await would leave them
    /// running. The fetch then finishes promptly by throwing.
    private func currentPlaceWithTimeout() async throws -> Place {
        let fetch = Task { try await locationService.currentPlace() }
        let timeout = fetchTimeout
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            fetch.cancel()
        }
        defer { watchdog.cancel() }

        return try await withTaskCancellationHandler {
            try await fetch.value
        } onCancel: {
            fetch.cancel()
        }
    }

    private func stopLocating() {
        locateTask?.cancel()
        locateTask = nil
        isLocating = false
    }

    // MARK: - Showing a place

    /// `remember` is true for anything the user picked (§3: search, detect
    /// or chip), which makes it the new last-viewed place.
    private func show(_ place: Place, remember: Bool) {
        self.place = place
        moonTable = SpikeMoonTableViewModel(moonService: moonService, place: place, today: now())
        locationFailed = false

        if remember {
            placeStore.lastViewed = place
            lastViewed = place
        }
    }

    private func timeZoneAbbreviation(for place: Place) -> String? {
        let date = now()
        guard place.isInDifferentTimeZone(from: deviceTimeZone, on: date) else { return nil }
        return place.timeZone.abbreviation(for: date)
    }
}
