//
//  MoonEntryTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// Got it → `noCity` through the moon (STEP-5.14 §6.3): the stages and their
/// order, the hold, the Reduce Motion path, that the loader takes over the
/// declined moon's phase, and that quitting or backgrounding mid-way still
/// ends on `noCity` with no "Finding your location".
@Suite("Got it moon entry", .timeLimit(.minutes(1)))
@MainActor
struct MoonEntryTests {

    // MARK: - Fixtures

    private static let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A stand-in for `Task.sleep` that records each wait and holds it until
    /// the test fires it.
    @MainActor
    private final class ManualSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []
        private(set) var durations: [Duration] = []
        var pendingCount: Int { waiters.count }

        func sleep(_ duration: Duration) async throws {
            durations.append(duration)
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }
    }

    private static func makeViewModel(
        location: FakeLocationService = FakeLocationService(authorizationState: .denied),
        placeStore: InMemoryPlaceStore = InMemoryPlaceStore(),
        onboardingStore: InMemoryOnboardingStore = InMemoryOnboardingStore(),
        sleeper: ManualSleeper,
        reducesMotion: Bool = false
    ) -> LocationViewModel {
        LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: placeStore,
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            onboardingStore: onboardingStore,
            reducesMotion: { reducesMotion },
            now: { reference },
            sleep: { [sleeper] duration in try await sleeper.sleep(duration) },
            loaderNow: { reference }
        )
    }

    private static func settle(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    /// The stages met sampling from Got it to past the end, in order.
    private static func stages(reducesMotion: Bool) -> [MoonEntry.Stage] {
        let step = 0.01
        let end = MoonEntry.duration(reducesMotion: reducesMotion) + 0.5
        var seen: [MoonEntry.Stage] = []
        for elapsed in stride(from: 0, through: end, by: step) {
            let stage = MoonEntry.stage(atElapsed: elapsed, reducesMotion: reducesMotion)
            if seen.last != stage { seen.append(stage) }
        }
        return seen
    }

    // MARK: - Sequence (§6.2, §6.3)

    @Test("Stages run text exit → flight → hold → exit, each once", arguments: [false, true])
    func stageOrder(reducesMotion: Bool) {
        #expect(Self.stages(reducesMotion: reducesMotion) == MoonEntry.Stage.allCases)
    }

    @Test("§6.2 starting values: text exit 0.2 s, flight 0.85 s on the Aha flight's length, hold 0.6 s, exit 0.25 s")
    func startingValues() {
        #expect(MoonEntry.textExitDuration == OnboardingScreenChange.exitDuration)
        #expect(MoonEntry.textExitDuration == 0.2)
        #expect(MoonEntry.flightDuration == LocationLoader.flightDuration)
        #expect(MoonEntry.holdDuration == 0.6)
        #expect(MoonEntry.exitFadeDuration == 0.25)
    }

    @Test("The moon holds on the loader's frame at least the hold before the exit")
    func minimumHold() {
        let landing = MoonEntry.landingTime(reducesMotion: false)
        let exit = MoonEntry.duration(reducesMotion: false)
        // Sums of the durations round: 0.5999… for 0.6.
        #expect(exit - landing >= MoonEntry.holdDuration - 1e-9)
        #expect(MoonEntry.stage(atElapsed: landing, reducesMotion: false) == .hold)
        #expect(MoonEntry.stage(atElapsed: exit - 0.001, reducesMotion: false) == .hold)
        #expect(MoonEntry.stage(atElapsed: exit, reducesMotion: false) == .exit)
    }

    @Test("Flight progress: still through the text exit, landed at the landing, never back")
    func flightProgress() {
        let start = Self.reference
        #expect(MoonEntry.flightProgress(since: start, at: start) == 0)
        #expect(MoonEntry.flightProgress(since: start, at: start.addingTimeInterval(MoonEntry.textExitDuration)) == 0)
        let landing = start.addingTimeInterval(MoonEntry.landingTime(reducesMotion: false))
        #expect(MoonEntry.flightProgress(since: start, at: landing) == 1)
        var last = 0.0
        for elapsed in stride(from: 0, through: MoonEntry.duration(reducesMotion: false), by: 0.01) {
            let progress = MoonEntry.flightProgress(since: start, at: start.addingTimeInterval(elapsed))
            #expect(progress >= last)
            last = progress
        }
    }

    @Test("Reduce Motion: no flight, a cross-fade and a shorter hold")
    func reduceMotionTimings() {
        #expect(MoonEntry.landingTime(reducesMotion: true)
            == MoonEntry.textExitDuration + MoonEntry.reduceMotionCrossFadeDuration)
        #expect(MoonEntry.reduceMotionHoldDuration < MoonEntry.holdDuration)
        #expect(MoonEntry.duration(reducesMotion: true) < MoonEntry.duration(reducesMotion: false))
    }

    // MARK: - Phase (§6.3 step 3)

    @Test("The loader starts on the declined moon's phase and holds it until the landing, then rides on")
    func startsOnDeclinedPhase() {
        let loader = LocationLoader(now: { Self.reference }, sleep: { _ in })
        loader.enterFromOnboarding()

        let start = PhaseCycle.geometry(at: loader.moon.elapsed(at: Self.reference))
        #expect(abs(start.litFraction - OnboardingMoon.geometry.litFraction) < 1e-6)
        #expect(start.litSide == OnboardingMoon.geometry.litSide)

        let landing = Self.reference.addingTimeInterval(MoonEntry.landingTime(reducesMotion: false))
        #expect(loader.moon.elapsed(at: landing.addingTimeInterval(-0.01)) == PhaseCycle.holdElapsed)
        #expect(loader.moon.elapsed(at: landing.addingTimeInterval(MoonEntry.holdDuration)) > PhaseCycle.holdElapsed)
    }

    // MARK: - The flow

    @Test("Got it: the loader is up at once with no label, holds for the entry, then noCity loads in")
    func gotItRunsTheEntry() async {
        let sleeper = ManualSleeper()
        let viewModel = Self.makeViewModel(sleeper: sleeper)

        viewModel.onboardingDidFinish(.locationDeclined)

        #expect(viewModel.launchStage == .phaseCycle)
        #expect(viewModel.entersThroughMoon)
        #expect(!viewModel.loader.showsLabel)
        #expect(viewModel.loader.content == .searching)
        #expect(viewModel.phaseCycleDidAppear() == nil)

        let start = Task { await viewModel.start() }
        await Self.settle { sleeper.pendingCount == 1 }
        #expect(sleeper.durations == [.seconds(MoonEntry.duration(reducesMotion: false))])
        #expect(viewModel.launchStage == .phaseCycle)
        #expect(!viewModel.loader.showsLabel)

        sleeper.fire()
        await start.value

        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.isNoCity)
        #expect(viewModel.noCityAction == .openSettings)
        #expect(viewModel.failureScreen == nil)
        #expect(!viewModel.loader.showsLabel)
    }

    @Test("Reduce Motion: the shorter entry, then noCity")
    func reduceMotionEntry() async {
        let sleeper = ManualSleeper()
        let viewModel = Self.makeViewModel(sleeper: sleeper, reducesMotion: true)

        viewModel.onboardingDidFinish(.locationDeclined)
        let start = Task { await viewModel.start() }
        await Self.settle { sleeper.pendingCount == 1 }

        #expect(sleeper.durations == [.seconds(MoonEntry.duration(reducesMotion: true))])
        sleeper.fire()
        await start.value
        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.isNoCity)
    }

    @Test("Backgrounded mid-entry: the return doesn't restart it, and it ends on noCity")
    func backgroundMidEntry() async {
        let sleeper = ManualSleeper()
        let viewModel = Self.makeViewModel(sleeper: sleeper)
        viewModel.onboardingDidFinish(.locationDeclined)
        let began = viewModel.loader.entryStartedAt
        let start = Task { await viewModel.start() }
        await Self.settle { sleeper.pendingCount == 1 }

        viewModel.sceneDidEnterBackground()
        await viewModel.sceneDidBecomeActive()

        #expect(viewModel.launchStage == .phaseCycle)
        #expect(viewModel.loader.entryStartedAt == began)
        #expect(sleeper.durations.count == 1)

        sleeper.fire()
        await start.value
        #expect(viewModel.launchStage == .ready)
        #expect(viewModel.isNoCity)
    }

    @Test("Quit mid-entry: noCity is already stored, so the relaunch lands on it")
    func quitMidEntry() async {
        let location = FakeLocationService()
        location.stateAfterRequest = .denied
        let placeStore = InMemoryPlaceStore()
        let onboardingStore = InMemoryOnboardingStore()
        let sleeper = ManualSleeper()
        let viewModel = Self.makeViewModel(
            location: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore,
            sleeper: sleeper
        )
        let onboarding = OnboardingViewModel(
            locationService: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore,
            onFinish: { [weak viewModel] outcome in viewModel?.onboardingDidFinish(outcome) }
        )
        onboarding.getStarted()
        await onboarding.useMyLocation()

        onboarding.gotIt()

        #expect(viewModel.entersThroughMoon)
        #expect(onboardingStore.endedOnNoCity)

        let relaunched = Self.makeViewModel(
            location: location,
            placeStore: placeStore,
            onboardingStore: onboardingStore,
            sleeper: ManualSleeper()
        )
        await relaunched.start()
        #expect(relaunched.isNoCity)
        #expect(relaunched.launchStage == .ready)
        #expect(!relaunched.entersThroughMoon)
    }

    @Test("Only Got it gets the moon: Search instead and Allow keep their handovers", arguments: [
        OnboardingViewModel.Outcome.searchInstead, .locationAllowed
    ])
    func otherOutcomesSkipTheEntry(outcome: OnboardingViewModel.Outcome) {
        let viewModel = Self.makeViewModel(sleeper: ManualSleeper())

        viewModel.onboardingDidFinish(outcome)

        #expect(viewModel.launchStage == .waiting)
        #expect(!viewModel.entersThroughMoon)
        #expect(viewModel.loader.entryStartedAt == nil)
    }

    @Test("A later search from noCity gets the ordinary loader, label and announcement")
    func laterLoaderIsOrdinary() async {
        let sleeper = ManualSleeper()
        let viewModel = Self.makeViewModel(sleeper: sleeper)
        viewModel.onboardingDidFinish(.locationDeclined)
        let start = Task { await viewModel.start() }
        await Self.settle { sleeper.pendingCount == 1 }
        sleeper.fire()
        await start.value

        viewModel.loader.appear()

        #expect(viewModel.loader.entryStartedAt == nil)
        #expect(viewModel.loader.showsLabel)
        #expect(viewModel.phaseCycleDidAppear() == LocationViewModel.phaseCycleAnnouncement)
    }
}
