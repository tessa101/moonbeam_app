//
//  LocationViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation
import os

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

        /// The shared cause, whose words the dialog uses
        /// (STEP-5.10a-LOCATION-CONSOLIDATION.md, Chunk 1).
        var failure: LocationFailure {
            switch self {
            case .denied: .permissionDenied
            case .servicesOff: .servicesOff
            case .restricted: .restricted
            }
        }

        /// Restricted is a device policy the user can't change, so Settings
        /// would be a dead end; its cause offers no Open Settings either.
        var offersSettings: Bool { failure.primaryAction == .openSettings }
    }

    // MARK: - Constants

    /// §3: how long a launch waits for a fix before falling back to the
    /// last-viewed place.
    static let defaultFetchTimeout = Duration.seconds(10)

    /// LOADER.md §12.9 (proposed, tune on device): the skeleton shows the
    /// moment a replacement begins (5.10a.7; no 400 ms wait) and stays this
    /// long, so a quick fix doesn't flash it.
    static let placeSkeletonMinimum = Duration.milliseconds(350)

    static let searchPlaceholder = "Search for a city"

    /// The compass's key in Info.plist's
    /// `NSLocationTemporaryUsageDescriptionDictionary` (COMPASS.md 4.12).
    /// Must match it, or iOS declines the request without showing anything.
    static let compassPrecisePurposeKey = "Compass"

    /// LOADER.md §4: what VoiceOver says when the phase cycle appears.
    static let phaseCycleAnnouncement = "Finding your location"

    // MARK: - Observed state

    /// What the screen shows while the launch fetch runs (LOADER.md §2).
    /// Starts out waiting, so nothing flashes before `start()` decides.
    private(set) var launchStage: LaunchStage = .waiting {
        didSet {
            guard launchStage != oldValue else { return }
            LaunchSignposts.signposter.emitEvent("launchStage", "\(String(describing: self.launchStage))")
        }
    }

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

    /// Why a search the user is waiting on ended without a place: Use my
    /// location, a recovery, the permission flows, or a launch with no saved
    /// place (STEP-5.10a-LOCATION-FAILURE.md, Chunk 1). A launch with a saved
    /// place never sets it; it opens that place instead (LOADER.md §10.1).
    /// Cleared when a new search starts or a place lands.
    private(set) var locationFailure: LocationFailure?

    /// The failure screen, shown in place of the main content (STEP-5.10a
    /// Chunk 3): after an explicit request, and at a launch with no saved
    /// place (STEP-5.10a-LOCATION-CONSOLIDATION.md §2). Only once the screen
    /// is up: a search or recovery is on the loader, so it's `nil`
    /// meanwhile.
    var failureScreen: LocationFailure? {
        launchStage == .ready ? locationFailure : nil
    }

    /// The one main-screen entrance replays when the selected place changes,
    /// never for a date or same-place refresh (LOADER.md §12.1).
    private(set) var loadInGeneration = 0

    /// The card block's own replay (LOADER.md §12.9). Bumps with a place
    /// change unless a skeleton is holding the slot when the place lands:
    /// then the skeleton cross-fades into the card instead, with no blank
    /// frame between them.
    private(set) var cardLoadInGeneration = 0

    /// During an explicit switch back to GPS, the old place is removed at
    /// once and the sentence names the pending destination.
    private(set) var isReplacingPlace = false

    /// LOADER.md §12.2–12.3: the replacement has taken past the threshold
    /// (or ended without a place), so the card's slot holds the skeleton.
    private(set) var showsPlaceSkeleton = false

    /// The card being replaced, kept only as an invisible size template so
    /// the skeleton matches the real card's frame (§12.3).
    private(set) var skeletonLayoutTable: MoonTableViewModel?

    /// The replaced place's zone, so the pending sentence keeps reading the
    /// selected date ("on Fri, Oct 16") rather than "today" (§12.9).
    private var replacedTimeZone: TimeZone?

    /// What fills the card's slot while a replacement has no place yet.
    enum CardPlaceholder: Equatable {
        case finding
        case failed
    }

    /// `nil` while the real card shows, or before the §12.2 threshold.
    var cardPlaceholder: CardPlaceholder? {
        guard isReplacingPlace || locationFailed else { return nil }
        if locationFailed { return .failed }
        return showsPlaceSkeleton ? .finding : nil
    }

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

    /// The loader screen's moon, glow and label (LOADER.md §10.2).
    let loader: LocationLoader

    // MARK: - Dependencies

    private let locationService: any LocationService
    private let placeSearch: any PlaceSearchService
    @ObservationIgnored private let placeStore: any PlaceStore
    /// First-run state: the first "Aha" ride's extra lap (LOADER.md §11.2.2).
    @ObservationIgnored private let onboardingStore: any OnboardingStore
    /// Reduce Motion: "Aha" without the ride (§11.2.2). Read when it's needed.
    @ObservationIgnored private let reducesMotion: () -> Bool
    private let moonService: any MoonService
    private let fetchTimeout: Duration
    private let fetchTimeoutSleep: @Sendable (Duration) async throws -> Void
    private let deviceTimeZone: TimeZone
    private let now: () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void
    private let placeChangeSleep: @Sendable (Duration) async throws -> Void
    private let dayLabelFormatter = DayLabelFormatter()
    private let madlibFormatter = MadlibFormatter()

    // MARK: - Bookkeeping

    @ObservationIgnored private var locateTask: Task<Void, Never>?
    @ObservationIgnored private var placeSkeletonTask: Task<Void, Never>?

    /// Decision A: the search sheet's location row closes the sheet, and the
    /// flow runs once it has gone, because the Location Off dialog can't
    /// present over a sheet that's still up.
    @ObservationIgnored private var useMyLocationAfterSearch = false

    /// An explicit Use my location is under way: it ends on the screen, with
    /// "Aha", or on its failure screen, never the Location Off dialog.
    @ObservationIgnored private var failureSearchInProgress = false

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

    /// Onboarding ended with "Search for a city instead" (DESIGN-1.1.md §5):
    /// the screen opens with the search sheet up.
    @ObservationIgnored private var presentsSearchOnStart = false

    /// LOADER.md §4: the announcement is made once per launch, however many
    /// times the phase cycle shows (Show onboarding brings it back).
    @ObservationIgnored private var hasAnnouncedPhaseCycle = false

    /// The last "Aha" line, so the next is a different one (LOADER.md
    /// §10.4). This session only.
    @ObservationIgnored private var lastAhaLine: String?

    // MARK: - Init

    /// - Parameters:
    ///   - fetchTimeout: injectable so tests needn't wait the full 10 s.
    ///   - fetchTimeoutSleep: the timeout's wait, so a test can fire the
    ///     10 s by hand.
    ///   - deviceTimeZone: injectable because a test process can't change
    ///     `TimeZone.current`.
    ///   - now: the clock. It decides the place's today, which the day
    ///     selection resolves against (DATE.md §3).
    ///   - sleep: the launch loader's waits (LOADER.md §2), so tests can
    ///     decide when 400 ms and 700 ms have passed.
    ///   - placeChangeSleep: the card skeleton's 400 ms threshold during a
    ///     place replacement (LOADER.md §12.2), so tests can decide it.
    ///   - onboardingStore: first-run state, for the first "Aha" ride's
    ///     extra lap.
    ///   - reducesMotion: the Reduce Motion setting; the app passes
    ///     `UIAccessibility`'s.
    ///   - loaderNow: the loader's own clock. Its moon is drawn against the
    ///     display's real time, so it stays real when `now` is a fixed
    ///     "today" (DEBUG screen states); tests pin both.
    init(
        locationService: any LocationService,
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        moonService: any MoonService,
        headingService: any HeadingService,
        onboardingStore: any OnboardingStore = InMemoryOnboardingStore(),
        reducesMotion: @escaping () -> Bool = { false },
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout,
        fetchTimeoutSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        deviceTimeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        placeChangeSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        loaderNow: @escaping () -> Date = Date.init
    ) {
        self.locationService = locationService
        self.placeSearch = placeSearch
        self.placeStore = placeStore
        self.onboardingStore = onboardingStore
        self.reducesMotion = reducesMotion
        self.moonService = moonService
        self.fetchTimeout = fetchTimeout
        self.fetchTimeoutSleep = fetchTimeoutSleep
        self.deviceTimeZone = deviceTimeZone
        self.now = now
        self.sleep = sleep
        self.placeChangeSleep = placeChangeSleep
        // `start()` reads the real state, off the main actor where it can
        // block; nothing reads this before then (LOADER.md §9).
        lastSeenAuthState = .notDetermined
        compass = CompassViewModel(headingService: headingService, moonService: moonService, now: now)
        loader = LocationLoader(now: loaderNow, sleep: sleep)
    }

    // MARK: - Derived state

    /// The search sheet's "Use my location" row (Decision B): shown whenever
    /// the place isn't the detected current location. Hidden while a fix is
    /// in flight, since tapping it would only restart it.
    var showsUseMyLocation: Bool {
        // Restricted can't be changed by the user, so the row could never
        // work (Tessa, 2026-10-10, from the Chunk 3 recordings).
        !isLocating && !(place?.isCurrentLocation ?? false) && lastSeenAuthState != .restricted
    }

    /// The madlib sentence, the screen's header (DESIGN-1.1.md §3.1): "Where
    /// can I find the moon 📅 today in 📍 Los Angeles, CA?". The place token
    /// is "City, ST" (4.13), or "a city" with no place yet. §3: while a
    /// launch fetch runs, the last-viewed name stands in so it isn't blank.
    ///
    /// - Parameter allowsBreaksInsideTokens: true at AX sizes, where a token
    ///   may wrap between its words (§3.1).
    func madlibSentence(allowsBreaksInsideTokens: Bool) -> MadlibFormatter.Sentence {
        let standIn = isLocating ? lastViewed : nil
        guard let place else {
            // A pending replacement keeps the selected date in the zone it
            // was read in (§12.9); only the city token changes. A failed
            // replacement keeps it too; its place token is "a city" again.
            let zone = isReplacingPlace || locationFailed ? replacedTimeZone : nil
            return madlibFormatter.sentence(
                place: nil,
                standIn: standIn,
                placePending: isReplacingPlace,
                dateTimeZone: zone,
                day: zone.map { daySelection.startOfDay(in: $0, now: now()) } ?? now(),
                dayOffset: zone.map { daySelection.dayOffset(in: $0, now: now()) } ?? 0,
                today: now(),
                allowsBreaksInsideTokens: allowsBreaksInsideTokens
            )
        }
        return madlibFormatter.sentence(
            place: place,
            day: selectedStartOfDay(for: place),
            dayOffset: selectedDayOffset(for: place),
            today: now(),
            allowsBreaksInsideTokens: allowsBreaksInsideTokens
        )
    }

    /// A tap on a madlib token: the date opens the calendar, the place opens
    /// the search sheet (§3.1, SEARCH-RECENTS.md §1).
    func open(_ token: MadlibFormatter.Token.Kind) {
        switch token {
        case .date: presentCalendar()
        case .place: presentSearch()
        }
    }

    // MARK: - Launch (§3)

    /// Runs once when the screen appears. Never prompts for permission.
    ///
    /// The loader is timed around the whole launch (LOADER.md §2): no loader
    /// if it's done inside 400 ms; past that the phase cycle, held at least
    /// 700 ms. Its clock starts before anything that could block, the
    /// permission read included, so any wait past 400 ms shows the moon
    /// (§9). A fetch that fails or times out falls back as before; the
    /// loader only decides what shows meanwhile.
    func start() async {
        let signposter = LaunchSignposts.signposter
        let interval = signposter.beginInterval("start")
        defer { signposter.endInterval("start", interval) }

        launchStage = .waiting
        let loader = startLoaderClock()

        let state = await locationService.refreshAuthorizationState()
        lastSeenAuthState = state
        lastViewed = placeStore.lastViewed

        if presentsSearchOnStart {
            presentsSearchOnStart = false
            presentSearch()
        }

        if state.isAuthorized {
            let fetch = signposter.beginInterval("locateAtLaunch")
            await locate(userInitiated: false)
            signposter.endInterval("locateAtLaunch", fetch)
        } else if let lastViewed {
            show(lastViewed, remember: false)
        }

        // §10.1: no saved place and nothing found. First ask stops the
        // loader on its invitation; a cause opens its failure screen, the
        // same one an explicit request gets
        // (STEP-5.10a-LOCATION-CONSOLIDATION.md §2–3).
        if place == nil {
            loader.cancel()
            if state == .notDetermined {
                await showLoaderMessage(.firstAsk)
                return
            }
            // A failed fetch has already said why, from its error.
            if locationFailure == nil {
                locationFailure = LocationFailure(state) ?? .noFix
            }
            await showFailureScreen(afterSearch: state.isAuthorized)
            return
        }

        if launchStage == .phaseCycle {
            await loader.value
        } else {
            loader.cancel()
        }
        finishLoader()
    }

    /// Call before the screen appears, with how onboarding ended (§5).
    /// Allowed and declined need nothing extra: `start()`'s normal launch
    /// flow finds the city, or stops the loader on a message (LOADER.md §10).
    ///
    /// The screen goes back to waiting, so `start()`'s fetch after onboarding
    /// gets the launch loader too (LOADER.md §1), and a forced onboarding
    /// doesn't flash the old screen first.
    func onboardingDidFinish(_ outcome: OnboardingViewModel.Outcome) {
        presentsSearchOnStart = outcome == .searchInstead
        launchStage = .waiting
    }

    /// The Forget saved place button: DEBUG and TestFlight only, temporary,
    /// removed with Show onboarding before 1.0 (DECISIONS.md 2026-10-06).
    /// Clears the last-viewed place and recents, then runs the launch flow
    /// again, so the no-saved-place loader and its messages can be tried
    /// without reinstalling. Permission and onboarding are left alone.
    func forgetSavedPlace() async {
        stopLocating()
        placeStore.lastViewed = nil
        placeStore.recents = []
        lastViewed = nil
        place = nil
        detectedPlace = nil
        locationFailed = false
        locationFailure = nil
        daySelection = .today
        reloadMoonTable()
        await start()
    }

    /// The loader's clock: the phase cycle at 400 ms, then its 1.1 s hold.
    /// Cancelled if the launch is done first.
    private func startLoaderClock() -> Task<Void, Never> {
        let signposter = LaunchSignposts.signposter
        let sleep = sleep
        return Task { [weak self] in
            do {
                try await sleep(LaunchStage.phaseCycleDelay)
                signposter.emitEvent("phaseCycleDelay elapsed", "cancelled: \(Task.isCancelled)")
                // The launch may finish just as the delay ends; cancelled
                // means it won.
                guard let self, !Task.isCancelled else { return }
                showLoader()
                try await sleep(LaunchStage.minimumPhaseCycleDuration)
            } catch {
                // Cancelled: nothing more to show.
            }
        }
    }

    /// The loader comes on screen, with its entrance (§10.2).
    private func showLoader() {
        guard launchStage != .phaseCycle else { return }
        loader.appear()
        launchStage = .phaseCycle
    }

    /// The real screen, and the loader's waits stop.
    private func finishLoader() {
        loader.end()
        launchStage = .ready
    }

    /// `locationFailure`'s screen, timed by whether a search ran
    /// (STEP-5.10a-LOCATION-CONSOLIDATION.md §3). A known blocked state
    /// needs no searching: straight from the neutral frame (or the loader
    /// already up) to the screen. A search that came up empty shows the
    /// searching moon at least `LocationLoader.minimumSearchBeforeMessage`,
    /// even when it failed inside the 400 ms grace, so it reads as an
    /// attempt; then the loader cross-fades into the illustration.
    /// A pick meanwhile ends the loader, and with it the wait.
    private func showFailureScreen(afterSearch: Bool) async {
        if afterSearch {
            showLoader()
            guard await loader.prepareFailure() else { return }
        }
        finishLoader()
    }

    // MARK: - Loader messages (LOADER.md §10)

    /// The message the loader is showing, if it's stopped on one.
    var loaderIssue: LocationIssue? {
        guard launchStage == .phaseCycle, case .message(let issue) = loader.content else { return nil }
        return issue
    }

    /// Shows the loader at once if it isn't up (a known issue needs no
    /// 400 ms grace: nothing fast is coming), then stops it on `issue`.
    private func showLoaderMessage(_ issue: LocationIssue) async {
        showLoader()
        await loader.showMessage(issue)
    }

    /// The message's primary button. Only First ask stops the loader now
    /// (STEP-5.10a-LOCATION-CONSOLIDATION.md §2); the causes' search and
    /// Open Settings are the failure screen's.
    func performLoaderAction() async {
        guard let issue = loaderIssue, issue.primaryAction == .requestPermission else { return }
        await askFromLoader()
    }

    /// First ask's Use my location: iOS's prompt over the stopped loader,
    /// message still up. Allow searches again; Don't Allow opens the app
    /// permission failure screen, with no searching (§3). Left unanswered,
    /// First ask stays: that isn't No fix.
    private func askFromLoader() async {
        isRequestingPermission = true
        let state = await locationService.requestAuthorization()
        isRequestingPermission = false
        lastSeenAuthState = state
        updateCompass()
        if state.isAuthorized {
            await recoverFromLoader()
        } else if let failure = LocationFailure(state) {
            failReplacement(failure)
            await showFailureScreen(afterSearch: false)
        }
    }

    /// Back to searching from First ask, then the fix: "Aha" and the screen
    /// if it lands, the cause's failure screen if not, after the searching
    /// minimum (§3).
    private func recoverFromLoader() async {
        guard await loader.resume() else { return }
        await locate(userInitiated: true)
        LaunchSignposts.signposter.emitEvent("Recovery fix received")
        guard launchStage == .phaseCycle else { return }
        if let place {
            await finishWithAha(for: place)
            return
        }
        // The failed fix has said why; a cancelled one hasn't.
        if locationFailure == nil {
            let state = await locationService.refreshAuthorizationState()
            // A pick meanwhile has already ended the loader.
            guard launchStage == .phaseCycle else { return }
            locationFailure = LocationFailure(state) ?? .noFix
        }
        await showFailureScreen(afterSearch: true)
    }

    /// LOADER.md §10.4, §11.2: a fix after a message (or the iOS prompt)
    /// gets "Aha" before the screen while the moon rides to the card's
    /// phase; then it flies into the card as the screen comes up under it.
    /// A pick meanwhile ends the loader, and with it the wait.
    ///
    /// The first ride after install goes a lap further; it counts as seen
    /// only once it has run to the end.
    private func finishWithAha(for place: Place) async {
        let line = AhaGreeting.line(after: lastAhaLine)
        lastAhaLine = line
        let realPhase = moonTable?.glyph
        let rides = realPhase != nil && !reducesMotion()
        let shown = await loader.showAha(
            AhaGreeting(line: line, city: place.nameWithRegion),
            realPhase: realPhase,
            extraLap: !onboardingStore.hasSeenFirstFindPass,
            reducesMotion: !rides
        )
        guard shown else { return }
        if rides { onboardingStore.hasSeenFirstFindPass = true }
        guard launchStage == .phaseCycle else { return }
        loader.flyAway()
        finishLoader()
    }

    /// Back in the foreground on First ask, the only message left: access
    /// granted in Settings searches again; turned off there, the cause's
    /// failure screen, with no searching (§3).
    private func loaderDidBecomeActive(state: LocationAuthState) async {
        lastSeenAuthState = state
        if state.isAuthorized {
            await recoverFromLoader()
        } else if let failure = LocationFailure(state) {
            locationFailure = failure
            await showFailureScreen(afterSearch: false)
        }
    }

    // MARK: - Failure screen (STEP-5.10a Chunk 3)

    /// Back in the foreground with access (from Settings, or No fix's
    /// connection fixed in Control Center or elsewhere): the failure screen goes
    /// at once and the existing recovery runs, as after a launch message:
    /// the loader with its entrance, then "Aha" and the moon's flight into
    /// the card as the screen loads in (Tessa, 2026-10-10). Another miss
    /// brings the failure screen back.
    ///
    /// The screen is out from here on (`launchStage` back to the loader), so
    /// a second foreground finds no failure screen and doesn't stack a fix.
    private func recoverFromFailureScreen() async {
        locationFailure = nil
        locationFailed = false
        showLoader()
        await locate(userInitiated: true)
        LaunchSignposts.signposter.emitEvent("Failure screen recovery fix received")
        // A pick meanwhile has already ended the loader.
        guard launchStage == .phaseCycle else { return }
        if let place {
            await finishWithAha(for: place)
        } else {
            guard await loader.prepareFailure() else { return }
            finishLoader()
        }
    }

    /// Back in the foreground on the failure screen: with access, one search
    /// (access granted in Settings, or No fix looking again, since it has no
    /// button: Chunk 2b, superseding §3 row 10); a different reason changes
    /// the screen. Once per activation: the search takes the screen away, so
    /// the next activation finds none, and none starts while one runs.
    ///
    /// Not determined (Ask Next Time) goes to First ask, whose button can
    /// show iOS's prompt; Open Settings would loop back to the same screen
    /// (Chunk 2b, superseding §3 row 9). No prompt by itself.
    private func failureScreenDidBecomeActive(on failure: LocationFailure, state: LocationAuthState) async {
        lastSeenAuthState = state
        detectionOnlyAfterSettings = false
        if state.isAuthorized {
            guard !isLocating else { return }
            await recoverFromFailureScreen()
        } else if state == .notDetermined {
            locationFailure = nil
            await showLoaderMessage(.firstAsk)
        } else if let current = LocationFailure(state), current != failure {
            locationFailure = current
        }
    }

    /// Call when the phase cycle comes on screen. Returns what VoiceOver
    /// should announce the first time per launch, `nil` after (LOADER.md §4).
    func phaseCycleDidAppear() -> String? {
        guard !hasAnnouncedPhaseCycle else { return nil }
        hasAnnouncedPhaseCycle = true
        return Self.phaseCycleAnnouncement
    }

    // MARK: - Permission branches (§4)

    /// The main "Use my location" button: detects and switches to the
    /// detected place.
    func useMyLocation() async {
        detectionOnlyAfterSettings = false
        // The search sheet's row, opened from First ask: the loader asks or
        // searches, so a fix opens the screen and a miss its failure
        // screen. Off goes straight to its failure screen, with no Location
        // Off dialog (STEP-5.10a-LOCATION-CONSOLIDATION.md §3).
        if loaderIssue != nil {
            let state = await locationService.refreshAuthorizationState()
            lastSeenAuthState = state
            switch state {
            case .notDetermined:
                await askFromLoader()
            case .authorized:
                await recoverFromLoader()
            case .denied, .restricted, .servicesOff:
                // The row began a replacement; it ends here, as any miss.
                failReplacement(LocationFailure(state))
                await showFailureScreen(afterSearch: false)
            }
            return
        }
        beginReplacingPlace()
        // Leave the old screen in the same turn the replacement begins, so an
        // empty sentence/card cannot flash. Known off/restricted states go
        // straight from this neutral frame to their failure screen.
        if launchStage == .ready { launchStage = .waiting }
        failureSearchInProgress = true
        defer { failureSearchInProgress = false }
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
        // "Off" and "denied" get different dialogs, so read the switch now.
        var settledState = await locationService.refreshAuthorizationState()
        switch settledState {
        case .notDetermined:
            isRequestingPermission = true
            let state = await locationService.requestAuthorization()
            isRequestingPermission = false
            lastSeenAuthState = state
            settledState = state
            updateCompass()
            // A refusal at the prompt ends here: the user has just answered,
            // so following up with the Location Off dialog would nag.
            if state.isAuthorized {
                if !detectionOnly { showLoader() }
                await locate(userInitiated: true, detectionOnly: detectionOnly)
            }
        case .authorized:
            if !detectionOnly { showLoader() }
            await locate(userInitiated: true, detectionOnly: detectionOnly)
        case .denied:
            offerLocationOff(.denied, detectionOnly: detectionOnly)
        case .restricted:
            offerLocationOff(.restricted, detectionOnly: detectionOnly)
        case .servicesOff:
            offerLocationOff(.servicesOff, detectionOnly: detectionOnly)
        }
        // A refused prompt or a Location Off dialog leaves the replacement
        // with no fix coming; without this the skeleton would keep saying
        // "Finding your location…" (LOADER.md §12.2 step 5). A fetch that
        // superseded this one (`isLocating`) still decides for itself.
        if isReplacingPlace, !locationFailed, !isLocating {
            failReplacement(LocationFailure(settledState))
        }
        if failureSearchInProgress, launchStage == .waiting {
            // Instant permission/services failures never showed the loader.
            finishLoader()
        } else if failureSearchInProgress, launchStage == .phaseCycle, locationFailure != nil {
            guard await loader.prepareFailure() else { return }
            finishLoader()
        } else if failureSearchInProgress, launchStage == .phaseCycle, let place {
            await finishWithAha(for: place)
        }
    }

    /// The Location Off dialog, for the compass's Turn On Location only: it
    /// keeps the selected city, so it has no failure screen. Every explicit
    /// Use my location gets the cause's failure screen instead, which says
    /// the same with the same actions (STEP-5.10a-LOCATION-CONSOLIDATION.md
    /// §3–4).
    private func offerLocationOff(_ variant: LocationOffVariant, detectionOnly: Bool) {
        detectionOnlyAfterSettings = detectionOnly
        guard detectionOnly else { return }
        locationOffDialog = variant
    }

    /// Call when the scene becomes active. §4: coming back from Settings with
    /// permission newly granted fetches without another tap. Also where the
    /// selected day rolls over past the place's midnight (DATE.md §3), and
    /// where the compass re-checks permission and restarts its sensors.
    func sceneDidBecomeActive() async {
        LaunchSignposts.signposter.emitEvent("sceneDidBecomeActive", "isLocating: \(self.isLocating)")
        refreshDayIfNeeded()
        // Permission or the device-wide switch may have changed in Settings;
        // the compass hides or shows its hint before anything else.
        let state = await locationService.refreshAuthorizationState()
        updateCompass()
        compass.sceneDidBecomeActive()

        guard !isRequestingPermission else { return }
        if loaderIssue != nil {
            await loaderDidBecomeActive(state: state)
            return
        }
        // The scene turns active while the launch is still loading. The
        // launch's own fetch decides the place then; a retry here would
        // cancel it, and the launch would open with no place (LOADER.md §9).
        guard launchStage == .ready else { return }

        if let failure = failureScreen {
            await failureScreenDidBecomeActive(on: failure, state: state)
            return
        }

        let wasAuthorized = lastSeenAuthState.isAuthorized
        lastSeenAuthState = state

        guard state.isAuthorized else { return }
        guard !wasAuthorized else {
            // 4.8: authorized all along but nothing detected, e.g. a launch
            // fix that failed or timed out after an overnight relaunch. The
            // compass stays hidden until something detects you, so retry
            // quietly. Detection only: the selected place never changes, and
            // a failure shows nothing.
            //
            // Not while Use my location is under way (`isReplacingPlace`):
            // its fix task may be queued but not started (`isLocating` still
            // false), and `locate()` would cancel it, ending the replacement
            // with no place and no failure screen (DECISIONS.md 2026-10-10).
            // That fix detects you anyway.
            if detectedPlace == nil, !isLocating, !isReplacingPlace {
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
        // The old card goes at once (§12.2). With no place (a failure
        // screen, First ask) there's nothing to remove, and starting now
        // would swap the failure screen for an empty main screen under the
        // closing sheet; `useMyLocation()` starts it once the sheet has gone.
        if place != nil { beginReplacingPlace() }
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
        // Picked from the loader's "Search for a city": the screen loads
        // in for it (§10.3).
        if launchStage != .ready {
            finishLoader()
        }
    }

    /// Only picked places become recents; a detected place never does
    /// (SEARCH-RECENTS.md §3). "Use my location" doesn't call this, and the
    /// guard covers a detected place reaching here some other way.
    private func addToRecents(_ place: Place) {
        guard !place.isCurrentLocation else { return }
        placeStore.addRecent(place)
    }

    // MARK: - Day selection (DATE.md)

    /// The selected day: "Sun, Sep 27", with the year only when it differs
    /// from the place's today. The card's header builds on it. Empty with no
    /// place; the card is hidden then.
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

    /// The card header's accessibility value: "Tomorrow, Sunday, September
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

    /// The moon card's cell to outline for the compass's lock
    /// (COMPASS-1.1.md §3), or `nil` while unlocked.
    var highlightedCardCell: MoonCardCell? {
        MoonCardCell(lockedOn: compass.lockedKind)
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
        if locateTask != nil {
            LaunchSignposts.signposter.emitEvent("locate cancels previous", "detectionOnly: \(detectionOnly)")
        }
        locateTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await performLocate(userInitiated: userInitiated, detectionOnly: detectionOnly)
        }
        locateTask = task
        await task.value
    }

    private func performLocate(userInitiated: Bool, detectionOnly: Bool) async {
        let signposter = LaunchSignposts.signposter
        let interval = signposter.beginInterval("performLocate", "detectionOnly: \(detectionOnly)")
        defer { signposter.endInterval("performLocate", interval, "cancelled: \(Task.isCancelled)") }

        isLocating = true
        locationFailed = false
        // A fresh search: the last one's failure no longer stands. A quiet
        // detection-only fix isn't the search the user is waiting on.
        if !detectionOnly {
            locationFailure = nil
        }

        do {
            let detected = try await currentPlaceWithTimeout()
            guard !Task.isCancelled else { return }
            detectedPlace = detected
            if detectionOnly {
                updateCompass()
                isLocating = false
                return
            }
            // §12.9: a skeleton that has just appeared stays its minimum
            // before the card replaces it.
            if isReplacingPlace, showsPlaceSkeleton, let placeSkeletonTask {
                await placeSkeletonTask.value
                guard !Task.isCancelled else { return }
            }
            // Launch detection isn't a pick, so it doesn't replace the saved
            // place.
            show(detected, remember: userInitiated)
        } catch {
            guard !Task.isCancelled else { return }
            if !detectionOnly, !userInitiated, let lastViewed {
                // A launch with a saved place opens it, with no failure.
                // A quiet detection-only retry (4.8) never touches the place.
                show(lastViewed, remember: false)
            } else if userInitiated || !detectionOnly {
                // A search the user is waiting on, or a launch with nothing
                // to fall back to. Detection only (the compass) has no
                // failure screen.
                let failure = detectionOnly ? nil : await failure(after: error)
                guard !Task.isCancelled else { return }
                if userInitiated {
                    failReplacement(failure)
                } else {
                    locationFailure = failure
                }
            }
        }

        isLocating = false
    }

    /// Why a fetch failed. Only a permission withdrawn mid-fix needs a fresh
    /// read, to tell services off from denied; everything else is No fix at
    /// once, with no wait.
    private func failure(after error: any Error) async -> LocationFailure {
        guard case LocationError.notAuthorized = error else {
            return LocationFailure(fixError: error, state: .authorized)
        }
        return LocationFailure(fixError: error, state: await locationService.refreshAuthorizationState())
    }

    /// `currentPlace()` with the §3 timeout.
    ///
    /// When the timeout fires it *cancels* the fetch, which is what stops
    /// CoreLocation's updates; just abandoning the await would leave them
    /// running. The fetch then finishes promptly by throwing.
    private func currentPlaceWithTimeout() async throws -> Place {
        let fetch = Task { try await locationService.currentPlace() }
        let timeout = fetchTimeout
        let timeoutSleep = fetchTimeoutSleep
        let watchdog = Task {
            try await timeoutSleep(timeout)
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
        // No place before (on the ready screen, only after a failure): a city
        // entered from the failure screen is a place change too (STEP-5.10a
        // Chunk 3, §12).
        let wasReplacingPlace = isReplacingPlace
        let changesWhere = wasReplacingPlace || self.place.map { !$0.isSameCity(as: place) } ?? true
        // The selection carries over: following today resolves to the new
        // city's today, a picked day stays the same calendar day (DATE.md §3).
        self.place = place
        isReplacingPlace = false
        replacedTimeZone = nil
        showsPlaceSkeleton = false
        skeletonLayoutTable = nil
        placeSkeletonTask?.cancel()
        placeSkeletonTask = nil
        reloadMoonTable()
        locationFailed = false
        locationFailure = nil

        if changesWhere, launchStage == .ready || wasReplacingPlace {
            loadInGeneration += 1
            // 5.10a.13: the card always replays its load-in when it lands,
            // over the skeleton or not, like a searched city.
            cardLoadInGeneration += 1
        }

        if remember {
            placeStore.lastViewed = place
            lastViewed = place
        }
    }

    private func beginReplacingPlace() {
        guard !isReplacingPlace else { return }
        isReplacingPlace = true
        skeletonLayoutTable = moonTable ?? skeletonLayoutTable
        replacedTimeZone = place?.timeZone ?? replacedTimeZone
        // 5.10a.7 (Tessa, 2026-10-09): the skeleton is there from the same
        // frame the old card goes, with no empty gap before it (it used to
        // wait 400 ms). A fix that lands inside the minimum waits it out
        // (`performLocate`), so it never flashes.
        showsPlaceSkeleton = true
        place = nil
        moonTable = nil
        locationFailed = false
        locationFailure = nil
        updateCompass()
        if launchStage == .ready {
            loadInGeneration += 1
        }

        let placeChangeSleep = placeChangeSleep
        placeSkeletonTask?.cancel()
        placeSkeletonTask = Task {
            try? await placeChangeSleep(Self.placeSkeletonMinimum)
        }
    }

    /// A replacement that ends without a place (a failed fix, a refused
    /// prompt, location off). STEP-5.10a Chunk 1 supersedes §12.2 step 5's
    /// failure inside the skeleton: the replacement ends cleanly (no
    /// skeleton, no size template, the token back to "a city") and the old
    /// place stays gone. The fix and its timeout have already ended; a
    /// superseding fetch never gets here (see `runLocationFlow`).
    ///
    /// `locationFailed` stays the "it failed" flag the card slot reads, so
    /// the failure card shows until the failure screen replaces it
    /// (Chunk 3). `failure` is `nil` for the compass's detection-only fix
    /// and a prompt left unanswered: no failure screen for those.
    private func failReplacement(_ failure: LocationFailure?) {
        if let failure {
            locationFailure = failure
        }
        locationFailed = true
        isReplacingPlace = false
        showsPlaceSkeleton = false
        skeletonLayoutTable = nil
        placeSkeletonTask?.cancel()
        placeSkeletonTask = nil
    }
}
