//
//  LaunchLoaderTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The launch loader (LOADER.md §7): which stage shows for how long a launch
/// fetch takes, on a hand-fired clock and a fix the test lets land.
///
/// The 400 ms and 700 ms waits come from `ManualSleeper`, and the fix from
/// `FakeLocationService.holdsFixes`, so "the fix lands at 300 ms" is "release
/// the fix before firing the 400 ms wait".
@Suite("Launch loader", .timeLimit(.minutes(1)))
@MainActor
struct LaunchLoaderTests {

    // MARK: - Fixtures

    private static let detected = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
        isCurrentLocation: true
    )

    /// Short, so the timeout test doesn't take the real 10 s.
    private static let testTimeout = Duration.milliseconds(50)
    private static let hangingFixDelay = Duration.seconds(30)

    /// How many times `settle` yields before giving up.
    private static let settleLimit = 1_000

    /// A stand-in for `Task.sleep` that the test fires by hand.
    @MainActor
    private final class ManualSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []
        private(set) var requestedDurations: [Duration] = []

        var pendingCount: Int { waiters.count }

        func sleep(_ duration: Duration) async throws {
            requestedDurations.append(duration)
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        /// Ends every pending sleep, as if the interval had passed.
        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }

        /// Ends pending sleeps with cancellation, so nothing leaks.
        func cancelAll() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume(throwing: CancellationError()) }
        }
    }

    private struct Harness {
        let viewModel: LocationViewModel
        let location: FakeLocationService
        let sleeper: ManualSleeper
    }

    private static func makeHarness(
        authorizationState: LocationAuthState = .authorized,
        lastViewed: Place? = nil,
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout
    ) -> Harness {
        let location = FakeLocationService(authorizationState: authorizationState, placeResult: .success(detected))
        location.holdsFixes = true
        let sleeper = ManualSleeper()
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: lastViewed),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            fetchTimeout: fetchTimeout,
            sleep: { [sleeper] duration in try await sleeper.sleep(duration) }
        )
        return Harness(viewModel: viewModel, location: location, sleeper: sleeper)
    }

    /// Lets the main actor run the launch's tasks until `condition` holds.
    private static func settle(until condition: () -> Bool) async {
        for _ in 0..<settleLimit where !condition() {
            await Task.yield()
        }
    }

    /// Starts the launch and waits until the fix is in flight and the 400 ms
    /// wait has begun.
    private static func startLaunch(_ harness: Harness) async -> Task<Void, Never> {
        let viewModel = harness.viewModel
        let launch = Task { await viewModel.start() }
        await settle { harness.location.heldFixCount == 1 && harness.sleeper.pendingCount == 1 }
        return launch
    }

    // MARK: - Tiers (§2)

    @Test("Starts waiting, so nothing shows before the launch decides")
    func startsWaiting() {
        let harness = Self.makeHarness()
        #expect(harness.viewModel.launchStage == .waiting)
    }

    @Test("A fix inside 400 ms: no loader, straight to the screen")
    func fastFixShowsNoLoader() async {
        let harness = Self.makeHarness()
        let launch = await Self.startLaunch(harness)
        #expect(harness.viewModel.launchStage == .waiting)
        #expect(harness.sleeper.requestedDurations == [LaunchStage.phaseCycleDelay])

        // The fix lands at "300 ms": before the 400 ms wait fires.
        harness.location.releaseFixes()
        await launch.value

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        // The phase cycle never came, so there was no hold to wait for.
        #expect(harness.sleeper.requestedDurations == [LaunchStage.phaseCycleDelay])
        harness.sleeper.cancelAll()
    }

    @Test("A fix past 400 ms: the phase cycle, then the screen")
    func slowFixShowsPhaseCycle() async {
        let harness = Self.makeHarness()
        let launch = await Self.startLaunch(harness)

        harness.sleeper.fire()
        await Self.settle { harness.viewModel.launchStage == .phaseCycle }
        #expect(harness.viewModel.launchStage == .phaseCycle)

        // The 700 ms hold has already passed when the fix lands at "1 s".
        await Self.settle { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        harness.location.releaseFixes()
        await launch.value

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.sleeper.requestedDurations == [
            LaunchStage.phaseCycleDelay, LaunchStage.minimumPhaseCycleDuration
        ])
    }

    @Test("A fix just after 400 ms: the phase cycle stays its full 700 ms")
    func phaseCycleHeldAfterEarlyFix() async {
        let harness = Self.makeHarness()
        let launch = await Self.startLaunch(harness)

        harness.sleeper.fire()
        await Self.settle { harness.sleeper.pendingCount == 1 }

        // The fix lands at "450 ms", inside the hold.
        harness.location.releaseFixes()
        await Self.settle { harness.viewModel.place != nil }
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.viewModel.launchStage == .phaseCycle)

        harness.sleeper.fire()
        await launch.value
        #expect(harness.viewModel.launchStage == .ready)
    }

    // MARK: - Fallbacks (§1, §2)

    /// With no last-viewed place a timeout stops on No fix instead
    /// (LOADER.md §10.1): `LoaderFlowTests.noFix()`.
    @Test("The 10 s timeout falls back to the last-viewed place")
    func timeoutFallsBack() async {
        let harness = Self.makeHarness(lastViewed: Place.marVista, fetchTimeout: Self.testTimeout)
        harness.location.holdsFixes = false
        harness.location.fixDelay = Self.hangingFixDelay

        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Place.marVista)
        // LOCATION.md §3: a launch fetch falls back quietly.
        #expect(!harness.viewModel.locationFailed)
        #expect(harness.location.cancelledFixCount == 1)
        harness.sleeper.cancelAll()
    }

    @Test(
        "No fetch, no loader",
        arguments: [LocationAuthState.notDetermined, .denied, .restricted, .servicesOff]
    )
    func noFetchNoLoader(state: LocationAuthState) async {
        let harness = Self.makeHarness(authorizationState: state, lastViewed: Place.marVista)

        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == Place.marVista)
        #expect(harness.location.currentPlaceCount == 0)
        // The 400 ms clock starts on every launch (§9), but this one was
        // done before it ran out: no phase cycle, so no hold.
        #expect(!harness.sleeper.requestedDurations.contains(LaunchStage.minimumPhaseCycleDuration))
        harness.sleeper.cancelAll()
    }

    // MARK: - A slow permission read (LOADER.md §9, §10.7)

    /// The 5.9 device stall: the permission read sat on the main actor
    /// before the 400 ms clock started, so a slow read showed plain
    /// background for seconds and never the moon.
    @Test("The 400 ms clock runs while the permission read is slow")
    func slowPermissionReadShowsMoon() async {
        let harness = Self.makeHarness()
        harness.location.holdsAuthorizationRefresh = true
        let viewModel = harness.viewModel
        let launch = Task { await viewModel.start() }
        await Self.settle { harness.location.heldRefreshCount == 1 && harness.sleeper.pendingCount == 1 }

        // The read hasn't come back, and the clock is already running.
        #expect(harness.location.currentPlaceCount == 0)
        harness.sleeper.fire()
        await Self.settle { viewModel.launchStage == .phaseCycle }
        #expect(viewModel.launchStage == .phaseCycle)

        harness.location.releaseAuthorizationRefreshes()
        await Self.settle { harness.location.heldFixCount == 1 }
        harness.location.releaseFixes()
        await Self.settle { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await launch.value

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.place == Self.detected)
    }

    @Test("The launch reads the permission through the off-main refresh")
    func launchRefreshesPermission() async {
        let harness = Self.makeHarness(authorizationState: .denied, lastViewed: Place.marVista)
        await harness.viewModel.start()
        #expect(harness.location.refreshCount == 1)
        harness.sleeper.cancelAll()
    }

    @Test("The Location Services read runs off the main thread")
    nonisolated func servicesReadIsOffMain() async {
        let ranOnMain = await CoreLocationService.readOffMainActor { Thread.isMainThread }
        #expect(!ranOnMain)
    }

    @Test("After onboarding the screen waits again, for the first fetch")
    func onboardingResetsToWaiting() async {
        // A saved place, so the launch opens it (LOADER.md §10.1); with none
        // it would stop on a message and wait on the manual sleeper.
        let harness = Self.makeHarness(authorizationState: .denied, lastViewed: Place.marVista)
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)

        harness.viewModel.onboardingDidFinish(.locationAllowed)
        #expect(harness.viewModel.launchStage == .waiting)
        harness.sleeper.cancelAll()
    }

    // MARK: - Foreground during the launch (LOADER.md §9, LOCATION.md 4.8)

    /// On a device the scene turns active while the launch fetch runs. The
    /// 4.8 retry (nothing detected yet, nothing locating yet) used to start
    /// a detection-only fetch there, which cancelled the launch's own fetch:
    /// the launch then dropped its fix and opened with no place.
    @Test("A foreground during the launch fetch doesn't cancel it")
    func foregroundDuringLaunchKeepsLaunchFetch() async {
        let harness = Self.makeHarness(lastViewed: Place.marVista)
        let viewModel = harness.viewModel
        // Both queued before either runs, as when the scene activates right
        // after the screen appears: start() reaches its fetch first.
        let launch = Task { await viewModel.start() }
        let foreground = Task { await viewModel.sceneDidBecomeActive() }
        await Self.settle { harness.location.heldFixCount >= 1 && harness.sleeper.pendingCount == 1 }
        // Let the foreground run to wherever it stops (a retry's fix would
        // be held too, so it can't be awaited before the release).
        await Self.settle { false }

        harness.location.releaseFixes()
        await launch.value
        harness.location.releaseFixes()
        await foreground.value

        #expect(harness.location.currentPlaceCount == 1)
        #expect(harness.viewModel.place == Self.detected)
        #expect(harness.viewModel.launchStage == .ready)
        #expect(!harness.viewModel.isLocating)
        harness.sleeper.cancelAll()
    }

    @Test("A foreground after a failed launch fetch still retries (4.8)")
    func foregroundAfterFailedLaunchRetries() async {
        let harness = Self.makeHarness(lastViewed: Place.marVista)
        harness.location.holdsFixes = false
        harness.location.placeResult = .failure(LocationError.locationUnavailable)
        await harness.viewModel.start()
        #expect(harness.viewModel.place == Place.marVista)

        harness.location.placeResult = .success(Self.detected)
        await harness.viewModel.sceneDidBecomeActive()

        #expect(harness.location.currentPlaceCount == 2)
        // Detection only: the place stays the last-viewed one.
        #expect(harness.viewModel.place == Place.marVista)
        harness.sleeper.cancelAll()
    }

    // MARK: - What the loader shows (§3, §5)

    @Test("The loader never shows the last-viewed place or the compass")
    func loaderShowsNoPlace() async {
        let harness = Self.makeHarness(lastViewed: Place.marVista)
        let launch = await Self.startLaunch(harness)
        harness.sleeper.fire()
        await Self.settle { harness.viewModel.launchStage == .phaseCycle }

        #expect(harness.viewModel.place == nil)
        #expect(harness.viewModel.moonTable == nil)
        #expect(harness.viewModel.compass.visibility == .hidden)
        #expect(!harness.viewModel.compass.showsPinnedBar)
        #expect(!LaunchPhaseCycle.message.contains(Place.marVista.name))

        harness.sleeper.fire()
        harness.location.releaseFixes()
        await launch.value
    }

    // MARK: - Accessibility (§4)

    @Test("VoiceOver hears \"Finding your location\" once per launch")
    func announcesOnce() {
        let viewModel = Self.makeHarness().viewModel
        #expect(viewModel.phaseCycleDidAppear() == "Finding your location")
        #expect(viewModel.phaseCycleDidAppear() == nil)
    }

    // MARK: - Entrance (LOADER.md §10.2)

    @Test("The loader appearing starts the entrance at the hold phase, label up, breathing")
    func loaderAppears() {
        let date = Date(timeIntervalSinceReferenceDate: 100)
        let loader = LocationLoader(now: { date })
        loader.appear()
        #expect(loader.appearedAt == date)
        #expect(loader.moon == .entrance(at: date))
        #expect(loader.showsLabel)
        #expect(loader.glow.mode == .breathe)
    }

    @Test("A slow launch shows the loader with its entrance")
    func slowLaunchRunsEntrance() async {
        let harness = Self.makeHarness()
        harness.location.holdsFixes = true
        let viewModel = harness.viewModel
        let launch = Task { await viewModel.start() }
        await Self.settle { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await Self.settle { viewModel.launchStage == .phaseCycle }
        #expect(viewModel.loader.moon.elapsed(at: viewModel.loader.appearedAt) == PhaseCycle.holdElapsed)
        harness.location.releaseFixes()
        await Self.settle { harness.sleeper.pendingCount == 1 }
        harness.sleeper.fire()
        await launch.value
    }

}

/// The loader moon's month (LOADER.md §3): forward, 4.8 s, eased at new and
/// full, the glow brightest at full.
@Suite("Phase cycle")
struct PhaseCycleTests {

    private static let tolerance = 1e-6

    @Test("The month's zero is new, dark, with the glow at its dimmest")
    func startsAtNew() {
        let geometry = PhaseCycle.geometry(at: 0)
        #expect(geometry.litFraction < Self.tolerance)
        #expect(PhaseCycle.glowLevel(at: 0) < Self.tolerance)
    }

    @Test("Full at half the month, with the glow at its brightest")
    func fullAtHalf() {
        let half = PhaseCycle.period / 2
        #expect(abs(PhaseCycle.geometry(at: half).litFraction - 1) < Self.tolerance)
        #expect(abs(PhaseCycle.glowLevel(at: half) - 1) < Self.tolerance)
    }

    @Test("Runs forward: lit on the right while waxing, on the left while waning")
    func runsForward() {
        let quarter = PhaseCycle.period / 4
        let waxing = PhaseCycle.geometry(at: quarter)
        let waning = PhaseCycle.geometry(at: 3 * quarter)
        #expect(waxing.litSide == .right)
        #expect(waning.litSide == .left)
        // The curve is symmetric, so the quarters are half lit.
        #expect(abs(waxing.litFraction - 0.5) < Self.tolerance)
        #expect(abs(waning.litFraction - 0.5) < Self.tolerance)
    }

    @Test("Eases through new and full: slow at the ends of each half")
    func easesAtNewAndFull() {
        let step = PhaseCycle.period / 48
        let nearNew = PhaseCycle.phaseAngle(at: step)
        let midWaxing = PhaseCycle.phaseAngle(at: PhaseCycle.period / 4 + step)
            - PhaseCycle.phaseAngle(at: PhaseCycle.period / 4)
        #expect(nearNew < midWaxing)
    }

    @Test("Repeats every 4.8 s and never settles")
    func repeatsEveryPeriod() {
        let moment = 1.3
        #expect(PhaseCycle.period == 4.8)
        #expect(abs(PhaseCycle.phaseAngle(at: moment) - PhaseCycle.phaseAngle(at: moment + PhaseCycle.period)) < 1e-6)
        #expect(PhaseCycle.geometry(at: moment) != PhaseCycle.geometry(at: moment + PhaseCycle.period / 3))
    }

    // MARK: - The hold phase (LOADER.md §10.2)

    @Test("The hold phase is the onboarding moon: waning gibbous, dark sliver on the right")
    func holdPhaseIsOnboardingMoon() {
        let hold = PhaseCycle.geometry(at: PhaseCycle.holdElapsed)
        #expect(abs(hold.litFraction - OnboardingMoon.geometry.litFraction) < 1e-6)
        #expect(hold.litSide == OnboardingMoon.geometry.litSide)
        #expect(hold.litSide == .left)
        // Just past full, in the waning half.
        #expect(PhaseCycle.holdElapsed > PhaseCycle.fullElapsed)
        #expect(PhaseCycle.holdElapsed < PhaseCycle.period * 3 / 4)
    }

    @Test("The loader appears on the hold phase and holds it 840 ms, then runs forward")
    func entranceHoldsThenRuns() {
        let appeared = Date(timeIntervalSinceReferenceDate: 0)
        let motion = MoonMotion.entrance(at: appeared)
        #expect(motion.elapsed(at: appeared) == PhaseCycle.holdElapsed)
        #expect(motion.elapsed(at: appeared.addingTimeInterval(0.8)) == PhaseCycle.holdElapsed)
        let later = motion.elapsed(at: appeared.addingTimeInterval(0.84 + 0.3))
        #expect(abs(later - (PhaseCycle.holdElapsed + 0.3)) < 1e-9)
        // Forward from just past full: the lit part shrinks, still on the left.
        let shape = PhaseCycle.geometry(at: later)
        #expect(shape.litFraction < PhaseCycle.holdLitFraction)
        #expect(shape.litSide == .left)
    }

    @Test("Reduce Motion holds the glyph still at the hold phase")
    func reduceMotionHoldsHoldPhase() {
        #expect(PhaseCycle.stillGeometry == PhaseCycle.geometry(at: PhaseCycle.holdElapsed))
    }

    @Test("The loader's timings are the interim values in LOADER.md §2.1")
    func timings() {
        #expect(LaunchStage.phaseCycleDelay == .milliseconds(400))
        #expect(LaunchStage.minimumPhaseCycleDuration == .milliseconds(700))
        #expect(LaunchStage.fadeDuration == 0.25)
        #expect(LaunchStage.phaseCycleFadeOutDuration == 0.2)
    }
}
