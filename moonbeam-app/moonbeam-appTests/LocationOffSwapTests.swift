//
//  LocationOffSwapTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// LOCATION-OFF-FLOW.md §5.2 (5.12b.3b): the location off ↔ on swap. Off to
/// on, the block is held (not interactive) over the compass until its
/// entrance leaves `.waitingForHeading`, then goes as the dial comes in; on to
/// off, the block shows at once. The timings are the app's existing ones, with
/// no rise under Reduce Motion. Plus the edge cases: revoked mid-swap, and the
/// app going to the background mid-swap.
///
/// The entrance's waits come from `EntranceSleeper`, ended by hand.
@Suite("Location off swap", .timeLimit(.minutes(1)))
@MainActor
struct LocationOffSwapTests {

    // MARK: - Timings

    @Test("Existing timings only: block in 300 ms after the dial's 200 ms, out 200 ms; dial in 300 ms")
    func timings() {
        #expect(LocationOffSwap.blockInDuration == ContentLoadIn.duration)
        #expect(LocationOffSwap.blockOutDuration == LaunchStage.phaseCycleFadeOutDuration)
        #expect(LocationOffSwap.dialOutDuration == LaunchStage.phaseCycleFadeOutDuration)
        #expect(LocationOffSwap.blockInDelay == LocationOffSwap.dialOutDuration)
        #expect(LocationOffSwap.dialInDuration == ContentLoadIn.duration)
        #expect(LocationOffSwap.heightDurationLocationOn == LocationOffSwap.dialInDuration)
        #expect(LocationOffSwap.heightDurationLocationOff == LocationOffSwap.dialOutDuration)
    }

    @Test("Reduce Motion: the same fades, no rise")
    func reduceMotionRise() {
        #expect(LocationOffSwap.blockInRise(reduceMotion: false) == ContentLoadIn.rise)
        #expect(LocationOffSwap.blockInRise(reduceMotion: true) == 0)
    }

    @Test("Ready only for a newer entrance that's past waiting")
    func readyRule() {
        let swap = LocationOffSwap(block: Self.someBlock, afterGeneration: 3)
        #expect(!swap.isReady(for: CompassEntrance(generation: 3, phase: .settled, startOffset: 0)))
        #expect(!swap.isReady(for: CompassEntrance(generation: 4, phase: .waitingForHeading, startOffset: 0)))
        #expect(swap.isReady(for: CompassEntrance(generation: 4, phase: .noHeading, startOffset: 0)))
        #expect(swap.isReady(for: CompassEntrance(generation: 4, phase: .settling, startOffset: 10)))
        #expect(swap.isReady(for: CompassEntrance(generation: 5, phase: .settled, startOffset: 0)))
    }

    // MARK: - Off to on

    @Test("Off to on: the block is held, unchanged and not interactive, until the dial comes in")
    func holdsUntilHeading() async {
        let harness = Self.makeOffHarness(dismissed: true)
        let before = harness.viewModel.locationOffBlock
        #expect(before?.isCollapsed == true)

        harness.viewModel.update(Self.context(auth: .authorized))

        // Granting clears the dismissed flag and the ghost, but the held
        // block is what was showing.
        #expect(harness.viewModel.visibility == .here)
        #expect(harness.viewModel.entrance.phase == .waitingForHeading)
        #expect(harness.viewModel.isLocationOffBlockHeld)
        #expect(harness.viewModel.locationOffBlock == before)
        #expect(harness.viewModel.bottomNote == nil)
        #expect(!harness.viewModel.showsPinnedBar)

        // Its taps do nothing while it's on its way out.
        harness.viewModel.reopenLocationPrompt()
        #expect(!harness.viewModel.isLocationPromptReopened)

        harness.heading.send(Self.reading(100))
        await waitUntil { !harness.viewModel.isLocationOffBlockHeld }

        #expect(harness.viewModel.entrance.phase == .settling)
        #expect(harness.viewModel.locationOffBlock == nil)
        #expect(harness.viewModel.locationOnCount == 1)
        harness.entrance.cancelAll()
    }

    @Test("Off to on with no heading: the block goes when the 0.5 s wait ends")
    func releasesAfterHeadingWait() async {
        let harness = Self.makeOffHarness()
        harness.viewModel.update(Self.context(auth: .authorized))
        #expect(harness.viewModel.isLocationOffBlockHeld)

        await waitUntil { harness.entrance.isWaiting }
        harness.entrance.fire()
        await waitUntil { !harness.viewModel.isLocationOffBlockHeld }

        #expect(harness.viewModel.entrance.phase == .noHeading)
        #expect(harness.viewModel.locationOnCount == 1)
        harness.entrance.cancelAll()
    }

    @Test("Reduce Motion: the same hold, and the block goes as the dial comes in aligned")
    func reduceMotionHold() async {
        let harness = Self.makeOffHarness(reducesMotion: true)
        harness.viewModel.update(Self.context(auth: .authorized))
        #expect(harness.viewModel.isLocationOffBlockHeld)
        #expect(harness.viewModel.entrance.phase == .waitingForHeading)

        harness.heading.send(Self.reading(100))
        await waitUntil { !harness.viewModel.isLocationOffBlockHeld }

        #expect(harness.viewModel.entrance.phase == .settled)
        #expect(harness.viewModel.locationOffBlock == nil)
        harness.entrance.cancelAll()
    }

    @Test("Back from Settings: a stale entrance from before doesn't end the hold")
    func staleEntranceDoesNotRelease() async {
        let harness = Self.makeOffHarness()
        harness.viewModel.sceneDidEnterBackground()
        // The context arrives before the scene is active again (§1).
        harness.viewModel.update(Self.context(auth: .authorized))
        #expect(harness.viewModel.isLocationOffBlockHeld)
        #expect(!harness.viewModel.isSensing)

        harness.viewModel.sceneDidBecomeActive()
        #expect(harness.viewModel.entrance.phase == .waitingForHeading)
        #expect(harness.viewModel.isLocationOffBlockHeld)

        harness.heading.send(Self.reading(100))
        await waitUntil { !harness.viewModel.isLocationOffBlockHeld }
        #expect(harness.viewModel.locationOnCount == 1)
        harness.entrance.cancelAll()
    }

    // MARK: - Edge cases

    @Test("Revoked again during the hold: the live block takes its place, S1 once more")
    func revokedDuringHold() async {
        let harness = Self.makeOffHarness(dismissed: true)
        harness.viewModel.update(Self.context(auth: .authorized))
        #expect(harness.viewModel.isLocationOffBlockHeld)

        harness.viewModel.update(Self.context(auth: .denied))

        #expect(!harness.viewModel.isLocationOffBlockHeld)
        #expect(harness.viewModel.visibility == .locationOff)
        // The grant cleared Maybe later (§4), so it's the prompt again.
        #expect(harness.viewModel.locationOffBlock?.isCollapsed == false)
        #expect(!harness.viewModel.isSensing)
        #expect(harness.viewModel.locationOnCount == 0)
        harness.entrance.cancelAll()
    }

    @Test("Background during the hold: still held; back, the new entrance ends it")
    func backgroundDuringHold() async {
        let harness = Self.makeOffHarness()
        harness.viewModel.update(Self.context(auth: .authorized))
        let generation = harness.viewModel.entrance.generation

        harness.viewModel.sceneDidEnterBackground()
        #expect(!harness.viewModel.isSensing)
        #expect(harness.viewModel.isLocationOffBlockHeld)

        harness.viewModel.sceneDidBecomeActive()
        #expect(harness.viewModel.entrance.generation == generation + 1)
        #expect(harness.viewModel.isLocationOffBlockHeld)

        harness.heading.send(Self.reading(100))
        await waitUntil { !harness.viewModel.isLocationOffBlockHeld }
        #expect(harness.viewModel.locationOnCount == 1)
        harness.entrance.cancelAll()
    }

    // MARK: - On to off

    @Test("On to off: no hold, the live block at once and the sensors stop")
    func onToOff() async {
        let harness = Self.makeHarness()
        harness.viewModel.update(Self.context(auth: .authorized))
        harness.viewModel.setOnScreen(true)
        harness.heading.send(Self.reading(100))
        await waitUntil { harness.viewModel.entrance.phase == .settling }
        #expect(harness.viewModel.locationOffBlock == nil)

        harness.viewModel.update(Self.context(auth: .denied))

        #expect(!harness.viewModel.isLocationOffBlockHeld)
        #expect(harness.viewModel.locationOffBlock?.showsPrompt == true)
        #expect(!harness.viewModel.isSensing)
        harness.entrance.cancelAll()
    }

    // MARK: - Fixtures

    private static let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)
    private static let maxYields = 100
    private static let goodAccuracy = 3.0

    /// Where the user is: so granting goes straight to `.here`.
    private static let here = Place(
        name: "Irvine",
        locality: "Irvine",
        region: "CA",
        country: "United States",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: zone,
        isCurrentLocation: true
    )

    private static let someBlock = LocationOffBlock(
        showsPrompt: true,
        isCollapsed: false,
        ghost: .empty,
        row: LocationOffGuideFormatter().row(for: .waiting),
        isRowActive: false
    )

    private static func context(auth: LocationAuthState) -> CompassContext {
        CompassContext(
            place: here,
            detectedPlace: here,
            authState: auth,
            moonDay: MoonDay(
                place: here,
                rise: MoonEvent(date: referenceDate, azimuth: 72),
                set: MoonEvent(date: referenceDate, azimuth: 288),
                phase: .full,
                phaseAngle: FakeMoonService.fullMoonPhaseAngle,
                illumination: FakeMoonService.fullyLit
            ),
            isToday: true
        )
    }

    private static func reading(_ heading: Double) -> HeadingReading {
        HeadingReading(trueHeading: heading, accuracy: goodAccuracy)
    }

    /// The entrance's waits, ended by hand.
    @MainActor
    private final class EntranceSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []

        /// A wait has started: `fire()` now ends it (not before its task runs).
        var isWaiting: Bool { !waiters.isEmpty }

        func sleep(_ duration: Duration) async throws {
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }

        func cancelAll() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume(throwing: CancellationError()) }
        }
    }

    private struct Harness {
        let viewModel: CompassViewModel
        let heading: FakeHeadingService
        let entrance: EntranceSleeper
    }

    private static func makeHarness(
        store: InMemoryOnboardingStore = InMemoryOnboardingStore(),
        reducesMotion: Bool = false
    ) -> Harness {
        let heading = FakeHeadingService()
        let entrance = EntranceSleeper()
        let viewModel = CompassViewModel(
            headingService: heading,
            moonService: FakeMoonService(position: MoonPosition(azimuth: 140, altitude: 23, isUp: true)),
            onboardingStore: store,
            now: { referenceDate },
            // The 30 s moon tick never comes during a test.
            sleep: { _ in try await Task.sleep(for: .seconds(3_600)) },
            entranceSleep: { [entrance] duration in try await entrance.sleep(duration) },
            reducesMotion: { reducesMotion }
        )
        return Harness(viewModel: viewModel, heading: heading, entrance: entrance)
    }

    /// Location off, the block on screen (the prompt, or the row after Maybe
    /// later).
    private static func makeOffHarness(dismissed: Bool = false, reducesMotion: Bool = false) -> Harness {
        let harness = makeHarness(
            store: InMemoryOnboardingStore(locationPromptDismissed: dismissed),
            reducesMotion: reducesMotion
        )
        harness.viewModel.update(context(auth: .denied))
        harness.viewModel.setOnScreen(true)
        return harness
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<Self.maxYields where !condition() {
            await Task.yield()
        }
    }
}
