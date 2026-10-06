//
//  LoaderFlowTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Foundation
import Testing
@testable import moonbeam_app

/// The location flow (LOADER.md §10.1, §10.3): with no saved place the
/// loader stops on a message; its buttons, Settings and Try again bring it
/// back to searching; a pick or a fix ends it.
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
    }

    private static func makeHarness(
        _ state: LocationAuthState,
        lastViewed: Place? = nil,
        placeResult: Result<Place, any Error> = .success(detected)
    ) -> Harness {
        let location = FakeLocationService(authorizationState: state, placeResult: placeResult)
        let store = InMemoryPlaceStore(lastViewed: lastViewed)
        let sleeper = RecordingSleeper()
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: store,
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            now: { reference },
            sleep: { [sleeper] duration in await sleeper.sleep(duration) },
            loaderNow: { reference }
        )
        return Harness(viewModel: viewModel, location: location, store: store, sleeper: sleeper)
    }

    private static func settle(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    // MARK: - Which message (§10.1)

    @Test(
        "No saved place: the loader stops on the message for the permission state",
        arguments: [
            (LocationAuthState.notDetermined, LocationIssue.firstAsk),
            (.denied, .appDenied),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
        ]
    )
    func messageForState(state: LocationAuthState, issue: LocationIssue) async {
        let harness = Self.makeHarness(state)
        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .phaseCycle)
        #expect(harness.viewModel.loaderIssue == issue)
        #expect(harness.viewModel.place == nil)
        #expect(!harness.location.didRequestAuthorization)
        #expect(harness.location.currentPlaceCount == 0)
    }

    @Test("Authorized but no fix, nothing saved: No fix")
    func noFix() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        #expect(harness.viewModel.loaderIssue == .noFix)
    }

    /// Offline, reverse geocoding fails at once rather than waiting out
    /// the 10 s (§10.1).
    @Test("The city can't be named (offline): No fix")
    func offlineIsNoFix() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.couldNotIdentifyPlace))
        await harness.viewModel.start()
        #expect(harness.viewModel.loaderIssue == .noFix)
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
    }

    // MARK: - Search → message (§10.3)

    @Test("Searching shows 1.2 s before the message, even when the reason is known")
    func searchesFirst() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        #expect(harness.sleeper.durations.contains(.seconds(1.2)))
    }

    @Test("On the message: label gone, moon frozen at the hold phase, glow pulsing")
    func messageState() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        let loader = harness.viewModel.loader
        #expect(!loader.showsLabel)
        #expect(loader.glow.mode == .pulse)
        let later = Self.reference.addingTimeInterval(10)
        #expect(abs(loader.moon.elapsed(at: later) - PhaseCycle.holdElapsed) < 1e-9)
    }

    // MARK: - First ask

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

    @Test("First ask → Don't Allow: app permission off")
    func firstAskDeny() async {
        let harness = Self.makeHarness(.notDetermined)
        await harness.viewModel.start()
        harness.location.stateAfterRequest = .denied

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.launchStage == .phaseCycle)
        #expect(harness.viewModel.loaderIssue == .appDenied)
        #expect(harness.location.currentPlaceCount == 0)
    }

    // MARK: - Back from Settings

    @Test("Denied → Settings → back allowed: searching again, then the screen")
    func backFromSettingsAllowed() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        harness.location.authorizationState = .authorized

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
    }

    @Test("Back from Settings still off: the message stays, still pulsing")
    func backFromSettingsStillOff() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.loaderIssue == .appDenied)
        #expect(harness.viewModel.loader.glow.mode == .pulse)
        #expect(harness.location.currentPlaceCount == 0)
    }

    @Test("Services turned on, app never asked: the message becomes First ask")
    func servicesOnThenFirstAsk() async {
        let harness = Self.makeHarness(.servicesOff)
        await harness.viewModel.start()
        harness.location.authorizationState = .notDetermined

        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.loaderIssue == .firstAsk)
    }

    @Test("Open Settings is the view's: the view model does nothing for it")
    func openSettingsIsTheViews() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()
        await harness.viewModel.performLoaderAction()
        #expect(harness.viewModel.loaderIssue == .appDenied)
        #expect(harness.location.requestAuthorizationCount == 0)
    }

    // MARK: - No fix

    @Test("No fix → Try again → a fix: the screen")
    func tryAgainSucceeds() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
    }

    @Test("No fix → Try again → still nothing: No fix again")
    func tryAgainFails() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()

        await harness.viewModel.performLoaderAction()

        #expect(harness.viewModel.loaderIssue == .noFix)
        #expect(harness.location.currentPlaceCount == 2)
    }

    @Test("No fix waits for Try again: a foreground doesn't search by itself")
    func noFixWaitsForTryAgain() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        await harness.viewModel.sceneDidBecomeActive()
        #expect(harness.location.currentPlaceCount == 1)
        #expect(harness.viewModel.loaderIssue == .noFix)
    }

    // MARK: - Search for a city

    @Test("Search for a city, then a pick: the screen loads in for it")
    func searchThenPick() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()

        harness.viewModel.presentSearch()
        #expect(harness.viewModel.isSearchPresented)
        harness.viewModel.select(Place.marVista)

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Place.marVista)
        #expect(harness.viewModel.loaderIssue == nil)
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

    @Test("The search sheet's Use my location from No fix, still nothing: No fix again, no dialog")
    func searchRowFromNoFix() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()

        await harness.viewModel.useMyLocation()

        #expect(harness.viewModel.loaderIssue == .noFix)
        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(harness.location.currentPlaceCount == 2)
    }

    @Test("The search sheet's Use my location while denied: the dialog; back allowed closes it")
    func searchRowWhileDenied() async {
        let harness = Self.makeHarness(.denied)
        await harness.viewModel.start()

        await harness.viewModel.useMyLocation()
        #expect(harness.viewModel.locationOffDialog == .denied)

        harness.location.authorizationState = .authorized
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.viewModel.locationOffDialog == nil)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
    }

    @Test("Restricted: the button is the search")
    func restrictedSearches() async {
        let harness = Self.makeHarness(.restricted)
        await harness.viewModel.start()
        await harness.viewModel.performLoaderAction()
        #expect(harness.viewModel.isSearchPresented)
    }

    @Test("A pick while the loader is still searching: no message turns up later")
    func pickSupersedesMessage() async {
        let location = FakeLocationService(authorizationState: .denied)
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
        await Self.settle { viewModel.launchStage == .phaseCycle && sleeper.pendingCount == 1 }

        viewModel.select(Place.marVista)
        sleeper.fire()
        await launch.value

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.loader.content == .searching)
    }

    // MARK: - "Aha" (§10.4)

    @Test("A fix after a message: \"Aha\" with the city, then the moon flies as the screen comes up")
    func ahaAfterRecovery() async {
        let harness = Self.makeHarness(.authorized, placeResult: .failure(LocationError.locationUnavailable))
        await harness.viewModel.start()
        harness.location.placeResult = .success(Self.detected)

        await harness.viewModel.performLoaderAction()

        let loader = harness.viewModel.loader
        #expect(harness.sleeper.durations.contains(.seconds(1.8)))
        #expect(harness.sleeper.durations.contains(.seconds(2)))
        guard case .aha(let greeting) = loader.content else {
            Issue.record("expected Aha, got \(loader.content)")
            return
        }
        #expect(AhaGreeting.lines.contains(greeting.line))
        #expect(greeting.city == "Irvine, CA")
        #expect(loader.glow.mode == .flare)
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

    @Test("An ordinary launch with a fix: no \"Aha\", the content loads in")
    func noAhaOnOrdinaryLaunch() async {
        let harness = Self.makeHarness(.authorized)
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.loader.content == .searching)
        #expect(harness.viewModel.loader.flightStartedAt == nil)
        #expect(!harness.sleeper.durations.contains(.seconds(1.8)))
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

    @Test("The flight runs from the loader moon at full to the card's slot and phase")
    func flightEnds() {
        let start = CGRect(x: 126, y: 300, width: 140, height: 140)
        let slot = CGRect(x: 32, y: 120, width: 44, height: 44)
        let landing = PhaseGlyphGeometry(illumination: 0.53, phaseAngle: 270)
        let began = Self.reference

        #expect(AhaFlight.progress(since: began, at: began) == 0)
        #expect(AhaFlight.progress(since: began, at: began.addingTimeInterval(LocationLoader.flightDuration)) == 1)
        #expect(AhaFlight.frame(from: start, to: slot, progress: 0) == start)
        #expect(AhaFlight.frame(from: start, to: slot, progress: 1) == slot)
        #expect(AhaFlight.geometry(landingOn: landing, progress: 0).litFraction == 1)
        #expect(AhaFlight.geometry(landingOn: landing, progress: 1) == landing)
    }

    // MARK: - Copy and actions

    @Test("Each message has the handoff's copy and button")
    func copy() {
        #expect(LocationIssue.firstAsk.headline == "Find the moon from where you are")
        #expect(LocationIssue.firstAsk.primaryTitle == "Use my location")
        #expect(LocationIssue.appDenied.headline == "Moon Signal can’t see your location")
        #expect(LocationIssue.appDenied.primaryTitle == "Open Settings")
        #expect(LocationIssue.servicesOff.headline == "Location Services are off")
        #expect(LocationIssue.servicesOff.body == "Turn them on to see where the moon is from here.")
        #expect(LocationIssue.noFix.headline == "Couldn’t find your location")
        #expect(LocationIssue.noFix.primaryTitle == "Try again")
        // §10.1: restricted has the app-permission copy, and no Settings.
        #expect(LocationIssue.restricted.headline == LocationIssue.appDenied.headline)
        #expect(LocationIssue.restricted.body
            == "Location access is limited on this iPhone. You can still search for a city.")
        #expect(LocationIssue.restricted.primaryAction == .search)
        #expect(!LocationIssue.restricted.showsSearchLink)
        #expect(LocationIssue.appDenied.showsSearchLink)
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

    @Test("A running moon runs out at 2.6× to the hold phase before the message")
    func runsOutBeforeMessage() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        // 2 s in: the cycle started at 0.84 s, so it's 1.16 s past the hold.
        clock.date = clock.date.addingTimeInterval(2)
        await loader.showMessage(.noFix)
        let distance = PhaseCycle.period - 1.16
        let expected = distance / MoonMotion.runOutRate
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
        let after = clock.date.addingTimeInterval(1)
        #expect(loader.moon.elapsed(at: after) != loader.moon.elapsed(at: clock.date))
    }

    @Test("Aha: label up 1.8 s, the moon runs to full under it, then the glow flares and it holds 2 s")
    func ahaStep() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.appDenied)
        await loader.resume()
        clock.date = clock.date.addingTimeInterval(0.5)
        let waitsBefore = clock.waits.count

        let greeting = AhaGreeting(line: AhaGreeting.lines[1], city: "Irvine, CA")
        #expect(await loader.showAha(greeting))

        let waits = clock.waits.dropFirst(waitsBefore).map {
            Double($0.components.attoseconds) / 1e18 + Double($0.components.seconds)
        }
        // 1.8 s of normal running from the hold phase is past full, so the
        // run-out goes round through new: (period − (hold + 1.8 − full)) / 2.6.
        let pastFull = PhaseCycle.holdElapsed + LocationLoader.minimumSearchBeforeAha - PhaseCycle.fullElapsed
        let runOut = (PhaseCycle.period - pastFull) / MoonMotion.runOutRate
        #expect(waits.count == 3)
        #expect(abs((waits.first ?? 0) - 1.3) < 1e-6)
        #expect(abs(waits[1] - runOut) < 1e-6)
        #expect(abs((waits.last ?? 0) - LocationLoader.ahaHold) < 1e-6)
        #expect(loader.content == .aha(greeting))
        #expect(loader.glow.mode == .flare)
        #expect(!loader.showsLabel)
        #expect(abs(loader.moon.elapsed(at: clock.date) - PhaseCycle.fullElapsed) < 1e-6)

        loader.flyAway()
        #expect(loader.flightStartedAt == clock.date)
        loader.didLand()
        #expect(loader.flightStartedAt == nil)
    }

    @Test("Aha never comes in over a moon short of full: label and breathing glow through the run-out")
    func ahaWaitsForFull() async {
        let clock = Clock()
        let loader = Self.makeLoader(clock)
        loader.appear()
        await loader.showMessage(.noFix)
        await loader.resume()

        let greeting = AhaGreeting(line: AhaGreeting.lines[0], city: "Irvine, CA")
        let waitsBefore = clock.waits.count
        var checkedRunOut = false
        clock.onWait = { [clock] in
            // Aha's second wait is the run-out: still searching there.
            guard clock.waits.count == waitsBefore + 2 else { return }
            checkedRunOut = true
            #expect(loader.content == .searching)
            #expect(loader.showsLabel)
            #expect(loader.glow.mode == .breathe)
        }
        #expect(await loader.showAha(greeting))
        #expect(checkedRunOut)
        #expect(loader.content == .aha(greeting))
        #expect(abs(loader.moon.elapsed(at: clock.date) - PhaseCycle.fullElapsed) < 1e-6)
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
