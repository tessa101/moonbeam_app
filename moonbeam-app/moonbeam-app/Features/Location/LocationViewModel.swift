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
/// Also owns the selected day (DATE.md): a calendar day in the place's time
/// zone that the moon table follows.
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

    /// The compass's key in Info.plist's
    /// `NSLocationTemporaryUsageDescriptionDictionary` (COMPASS.md 4.12).
    /// Must match it, or iOS declines the request without showing anything.
    static let compassPrecisePurposeKey = "Compass"

    // MARK: - Observed state

    /// The place the moon table is for, or `nil` for the empty first-launch
    /// state.
    private(set) var place: Place?

    /// The moon card's table for `place` on the selected day, rebuilt
    /// whenever either changes.
    private(set) var moonTable: MoonTableViewModel?

    /// The day the moon table is for. Not persisted: every launch opens on
    /// today (DATE.md §3).
    private(set) var daySelection: DaySelection = .today

    /// Settable so the view's sheet binding can dismiss it (Cancel, drag).
    var isCalendarPresented = false

    /// A day highlighted in the calendar sheet but not yet picked: the
    /// picker moved without a clear tap on a new day (see `calendarDate`).
    /// Confirmed with Done, dropped by Cancel. `nil` otherwise.
    private(set) var calendarDraft: DateComponents?

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

    /// The compass under the moon table (COMPASS.md). Fed a
    /// `CompassContext` on every place, day or permission change, so this
    /// stays the only owner of that state.
    let compass: CompassViewModel

    // MARK: - Dependencies

    private let locationService: any LocationService
    private let placeSearch: any PlaceSearchService
    @ObservationIgnored private let placeStore: any PlaceStore
    private let moonService: any MoonService
    private let fetchTimeout: Duration
    private let deviceTimeZone: TimeZone
    private let now: () -> Date
    private let dayLabelFormatter = DayLabelFormatter()

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

    /// The last place a location fix found this session. A searched city
    /// matching it counts as "where you are" for the compass
    /// (COMPASS.md §2). Kept when you then search elsewhere; not persisted.
    @ObservationIgnored private var detectedPlace: Place?

    /// The Location Off dialog was opened from the compass hint, so the fetch
    /// after coming back from Settings updates detection only and keeps the
    /// searched city (COMPASS.md §2, 4.6). The main "Use my location" button
    /// clears it.
    @ObservationIgnored private var detectionOnlyAfterSettings = false

    // MARK: - Init

    /// - Parameters:
    ///   - fetchTimeout: injectable so tests needn't wait the full 10 s.
    ///   - deviceTimeZone: injectable because a test process can't change
    ///     `TimeZone.current`.
    ///   - now: the clock. It decides the place's today, which the day
    ///     selection resolves against (DATE.md §3).
    init(
        locationService: any LocationService,
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        moonService: any MoonService,
        headingService: any HeadingService,
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
        compass = CompassViewModel(headingService: headingService, moonService: moonService, now: now)
    }

    // MARK: - Derived state

    /// The search sheet's "Use my location" row (Decision B): shown whenever
    /// the place isn't the detected current location. Hidden while a fix is
    /// in flight, since tapping it would only restart it.
    var showsUseMyLocation: Bool {
        !isLocating && !(place?.isCurrentLocation ?? false)
    }

    /// The main-screen "Use my location" button: only on the empty
    /// first-launch state (COMPASS.md 4.11). Next to the Nearby note it read
    /// as confusing, so everywhere else the sheet's row is the way back.
    var showsUseMyLocationButton: Bool {
        place == nil && showsUseMyLocation
    }

    /// §3: while a launch fetch runs, the last-viewed name stands in so the
    /// screen isn't blank.
    var searchPrompt: String {
        if isLocating, place == nil, let lastViewed { return lastViewed.nameWithRegion }
        return Self.searchPlaceholder
    }

    /// What the main-screen search button shows: the current city as
    /// "City, ST" (4.13), or the prompt when there isn't one yet
    /// (SEARCH-RECENTS.md §1).
    var searchFieldTitle: String {
        place?.nameWithRegion ?? searchPrompt
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

    /// The main "Use my location" button: detects and switches to the
    /// detected place.
    func useMyLocation() async {
        detectionOnlyAfterSettings = false
        await runLocationFlow(detectionOnly: false)
    }

    /// The compass hint's Turn On Location (COMPASS.md §2, 4.6): the same
    /// permission flow, but a fix only updates detection. The searched city
    /// stays selected, and Here / Nearby / Far then apply to it. That holds
    /// for the return from Settings too.
    func turnOnLocationForCompass() async {
        await runLocationFlow(detectionOnly: true)
    }

    /// The compass's Use Precise Location (COMPASS.md 4.12): iOS's in-app
    /// alert, then the compass hears the outcome straight away rather than
    /// at the next foreground. Declining leaves everything as it was.
    func usePreciseLocationForCompass() async {
        await locationService.requestTemporaryPreciseLocation(purposeKey: Self.compassPrecisePurposeKey)
        updateCompass()
    }

    private func runLocationFlow(detectionOnly: Bool) async {
        switch locationService.authorizationState {
        case .notDetermined:
            isRequestingPermission = true
            let state = await locationService.requestAuthorization()
            isRequestingPermission = false
            lastSeenAuthState = state
            updateCompass()
            // A refusal at the prompt ends here: the user has just answered,
            // so following up with the Location Off dialog would nag.
            if state.isAuthorized {
                await locate(userInitiated: true, detectionOnly: detectionOnly)
            }
        case .authorized:
            await locate(userInitiated: true, detectionOnly: detectionOnly)
        case .denied:
            detectionOnlyAfterSettings = detectionOnly
            locationOffDialog = .denied
        case .restricted:
            detectionOnlyAfterSettings = detectionOnly
            locationOffDialog = .restricted
        case .servicesOff:
            detectionOnlyAfterSettings = detectionOnly
            locationOffDialog = .servicesOff
        }
    }

    /// Call when the scene becomes active. §4: coming back from Settings with
    /// permission newly granted fetches without another tap. Also where the
    /// selected day rolls over past the place's midnight (DATE.md §3), and
    /// where the compass re-checks permission and restarts its sensors.
    func sceneDidBecomeActive() async {
        refreshDayIfNeeded()
        // Permission may have changed in Settings; the compass hides or shows
        // its hint before anything else.
        updateCompass()
        compass.sceneDidBecomeActive()

        guard !isRequestingPermission else { return }

        let state = locationService.authorizationState
        let wasAuthorized = lastSeenAuthState.isAuthorized
        lastSeenAuthState = state

        guard state.isAuthorized else { return }
        guard !wasAuthorized else {
            // 4.8: authorized all along but nothing detected, e.g. a launch
            // fix that failed or timed out after an overnight relaunch. The
            // compass stays hidden until something detects you, so retry
            // quietly. Detection only: the selected place never changes, and
            // a failure shows nothing.
            if detectedPlace == nil, !isLocating {
                await locate(userInitiated: false, detectionOnly: true)
            }
            return
        }
        locationOffDialog = nil
        guard !isLocating else { return }
        let detectionOnly = detectionOnlyAfterSettings
        detectionOnlyAfterSettings = false
        await locate(userInitiated: true, detectionOnly: detectionOnly)
    }

    /// Call when the scene moves to the background: the compass stops its
    /// sensors (COMPASS.md §1).
    func sceneDidEnterBackground() {
        compass.sceneDidEnterBackground()
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

    /// Only picked places become recents; a detected place never does
    /// (SEARCH-RECENTS.md §3). "Use my location" doesn't call this, and the
    /// guard covers a detected place reaching here some other way.
    private func addToRecents(_ place: Place) {
        guard !place.isCurrentLocation else { return }
        placeStore.addRecent(place)
    }

    // MARK: - Day selection (DATE.md)

    /// The date control's label: "Sun, Sep 27", with the year only when it
    /// differs from the place's today. Empty with no place; the control is
    /// hidden then.
    var dateLabel: String {
        guard let place else { return "" }
        return dayLabelFormatter.label(
            for: selectedStartOfDay(for: place),
            today: now(),
            timeZone: place.timeZone
        )
    }

    /// The moon card's header: "Today · Wed, Sep 30" on the place's today,
    /// otherwise as `dateLabel` (DESIGN-1.1.md §3.2).
    var cardDateLabel: String {
        guard let place else { return "" }
        return dayLabelFormatter.cardLabel(
            for: selectedStartOfDay(for: place),
            dayOffset: selectedDayOffset(for: place),
            today: now(),
            timeZone: place.timeZone
        )
    }

    /// The date field's accessibility value: "Tomorrow, Sunday, September
    /// 27, 2026". It's a value, not the label, so VoiceOver reads the new date
    /// after each adjustable swipe (DATE.md §5).
    var dateAccessibilityValue: String {
        guard let place else { return "" }
        return dayLabelFormatter.accessibilityValue(
            for: selectedStartOfDay(for: place),
            dayOffset: selectedDayOffset(for: place),
            timeZone: place.timeZone
        )
    }

    /// The selected day is the place's today, so the calendar sheet's Today
    /// button is disabled. Reads the resolved day rather than the case, so a
    /// picked day that has become today counts too. With no place there's
    /// nothing to go back to.
    var isOnToday: Bool {
        guard let place else { return true }
        return selectedDayOffset(for: place) == 0
    }

    var canGoBack: Bool {
        guard let place else { return false }
        return selectedDayOffset(for: place) > -DaySelection.maximumDayOffset
    }

    var canGoForward: Bool {
        guard let place else { return false }
        return selectedDayOffset(for: place) < DaySelection.maximumDayOffset
    }

    func previousDay() {
        moveDay(by: -1)
    }

    func nextDay() {
        moveDay(by: 1)
    }

    /// The calendar sheet's Today button, the only "back to today" control.
    /// Closes the sheet like any other pick.
    func goToToday() {
        setDaySelection(.today)
        calendarDraft = nil
        isCalendarPresented = false
    }

    /// A day picked in the calendar sheet. Closes the sheet. Picking the
    /// place's today goes back to following today.
    func select(day: DateComponents) {
        calendarDraft = nil
        isCalendarPresented = false
        guard let place else { return }
        setDaySelection(.selecting(day, in: place.timeZone, now: now()))
    }

    /// Every opening starts from the selected day, so a draft left by
    /// Cancel or a drag is gone.
    func presentCalendar() {
        guard place != nil else { return }
        calendarDraft = nil
        isCalendarPresented = true
    }

    // MARK: - Calendar sheet (DATE.md §2)

    /// The graphical picker's selection. It works in `Date`, so the setter
    /// turns the picked moment into a calendar day in the place's zone. The
    /// getter gives local noon on the highlighted day, safely inside it.
    ///
    /// The picker reports a tap on a day and a turn of its month/year wheel
    /// the same way. The wheel keeps the day number (Sep 27 → Oct 27), or
    /// clamps it to the month's last day (Jan 31 → Feb 28). So those changes
    /// only move the highlight into `calendarDraft`, and the sheet stays open
    /// for Done. Any other change is a tap on a new day: it's picked and the
    /// sheet closes (§2). The one tap that can't be told apart, the same day
    /// number in another month, also becomes a draft.
    var calendarDate: Date {
        get {
            guard let place else { return now() }
            guard let calendarDraft else { return daySelection.noon(in: place.timeZone, now: now()) }
            return DaySelection.selecting(calendarDraft, in: place.timeZone, now: now())
                .noon(in: place.timeZone, now: now())
        }
        set {
            guard let place else { return }
            let calendar = placeCalendar(for: place.timeZone)
            let picked = calendar.dateComponents([.year, .month, .day], from: newValue)
            let highlighted = calendar.dateComponents([.year, .month, .day], from: calendarDate)
            guard picked != highlighted else { return }

            if Self.isWheelChange(from: highlighted, to: picked, calendar: calendar) {
                calendarDraft = picked
            } else {
                select(day: picked)
            }
        }
    }

    /// Done appears only while there's a draft to confirm.
    var showsCalendarDone: Bool {
        calendarDraft != nil
    }

    /// The sheet's Done: picks the highlighted day and closes.
    func confirmCalendarDraft() {
        guard let calendarDraft else { return }
        select(day: calendarDraft)
    }

    /// Today ±366 days in the place's zone, for the picker.
    var calendarRange: ClosedRange<Date> {
        DaySelection.range(in: calendarTimeZone, now: now())
    }

    /// The picker has to show the place's days, not the device's.
    var calendarTimeZone: TimeZone {
        place?.timeZone ?? deviceTimeZone
    }

    // MARK: - Day selection helpers

    private func moveDay(by days: Int) {
        guard let place else { return }
        setDaySelection(daySelection.offset(by: days, in: place.timeZone, now: now()))
    }

    private func setDaySelection(_ selection: DaySelection) {
        daySelection = selection
        reloadMoonTable()
    }

    private func selectedStartOfDay(for place: Place) -> Date {
        daySelection.startOfDay(in: place.timeZone, now: now())
    }

    private func selectedDayOffset(for place: Place) -> Int {
        daySelection.dayOffset(in: place.timeZone, now: now())
    }

    private func placeCalendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// True if a picker change looks like the month/year wheel rather than a
    /// tap: the day number is kept, or clamped to the new month's last day.
    private static func isWheelChange(
        from old: DateComponents,
        to new: DateComponents,
        calendar: Calendar
    ) -> Bool {
        guard let oldDay = old.day, let newDay = new.day else { return false }
        if newDay == oldDay { return true }
        guard newDay < oldDay,
              let newDate = calendar.date(from: new),
              let daysInMonth = calendar.range(of: .day, in: .month, for: newDate)?.count
        else { return false }
        return newDay == daysInMonth
    }

    /// Foreground only (DECISIONS.md 2026-09-26): a following-today
    /// selection moves to the place's new day. A picked day stays put, so
    /// its table isn't rebuilt unless clamping moved it.
    private func refreshDayIfNeeded() {
        guard let place, let moonTable else { return }
        guard selectedStartOfDay(for: place) != moonTable.day else { return }
        reloadMoonTable()
    }

    /// Every place and day change comes through here, so this is also where
    /// the compass hears about them.
    private func reloadMoonTable() {
        defer { updateCompass() }
        guard let place else {
            moonTable = nil
            return
        }
        moonTable = MoonTableViewModel(
            moonService: moonService,
            place: place,
            day: selectedStartOfDay(for: place),
            deviceTimeZone: deviceTimeZone
        )
    }

    /// The compass's targets come from the table's own `MoonDay`, so the two
    /// always agree and the moon service isn't asked twice.
    private func updateCompass() {
        compass.update(
            CompassContext(
                place: place,
                detectedPlace: detectedPlace,
                authState: locationService.authorizationState,
                isPreciseLocationOff: locationService.isPreciseLocationOff,
                moonDay: moonTable?.moonDay,
                isToday: isOnToday
            )
        )
    }

    // MARK: - Locating

    /// Runs one fix in a task of its own, so picking a place meanwhile can
    /// cancel it and a late fix can't overwrite the user's choice.
    /// - Parameter detectionOnly: record the fix for the compass without
    ///   showing it; the selected place stays put (COMPASS.md §2, 4.6).
    private func locate(userInitiated: Bool, detectionOnly: Bool = false) async {
        locateTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await performLocate(userInitiated: userInitiated, detectionOnly: detectionOnly)
        }
        locateTask = task
        await task.value
    }

    private func performLocate(userInitiated: Bool, detectionOnly: Bool) async {
        isLocating = true
        locationFailed = false

        do {
            let detected = try await currentPlaceWithTimeout()
            guard !Task.isCancelled else { return }
            detectedPlace = detected
            if detectionOnly {
                updateCompass()
                isLocating = false
                return
            }
            // Launch detection isn't a pick, so it doesn't replace the saved
            // place.
            show(detected, remember: userInitiated)
        } catch {
            guard !Task.isCancelled else { return }
            if userInitiated {
                locationFailed = true
            } else if !detectionOnly, let lastViewed {
                // A quiet detection-only retry (4.8) never touches the place.
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

    /// `remember` is true for anything the user picked (§3: search or
    /// detect), which makes it the new last-viewed place.
    private func show(_ place: Place, remember: Bool) {
        // The selection carries over: following today resolves to the new
        // city's today, a picked day stays the same calendar day (DATE.md §3).
        self.place = place
        reloadMoonTable()
        locationFailed = false

        if remember {
            placeStore.lastViewed = place
            lastViewed = place
        }
    }
}
