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
@Suite("Launch loader")
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

    @Test("The 10 s timeout falls back to the last-viewed place", arguments: [true, false])
    func timeoutFallsBack(hasLastViewed: Bool) async {
        let harness = Self.makeHarness(
            lastViewed: hasLastViewed ? Place.marVista : nil,
            fetchTimeout: Self.testTimeout
        )
        harness.location.holdsFixes = false
        harness.location.fixDelay = Self.hangingFixDelay

        await harness.viewModel.start()

        #expect(harness.viewModel.launchStage == .ready)
        #expect(harness.viewModel.place == (hasLastViewed ? Place.marVista : nil))
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
        #expect(harness.sleeper.requestedDurations.isEmpty)
    }

    @Test("After onboarding the screen waits again, for the first fetch")
    func onboardingResetsToWaiting() async {
        let harness = Self.makeHarness(authorizationState: .denied)
        await harness.viewModel.start()
        #expect(harness.viewModel.launchStage == .ready)

        harness.viewModel.onboardingDidFinish(.locationAllowed)
        #expect(harness.viewModel.launchStage == .waiting)
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
}

/// The loader moon's month (LOADER.md §3): forward, 4.8 s, eased at new and
/// full, the glow brightest at full.
@Suite("Phase cycle")
struct PhaseCycleTests {

    private static let tolerance = 1e-6

    @Test("Starts at new, dark, with the glow at its dimmest")
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

    @Test("Reduce Motion holds the glyph still at full")
    func reduceMotionHoldsFull() {
        #expect(PhaseCycle.stillGeometry.litFraction == 1)
    }

    @Test("The loader's timings are the interim values in LOADER.md §2.1")
    func timings() {
        #expect(LaunchStage.phaseCycleDelay == .milliseconds(400))
        #expect(LaunchStage.minimumPhaseCycleDuration == .milliseconds(700))
        #expect(LaunchStage.fadeDuration == 0.25)
    }
}
