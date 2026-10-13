//
//  CompassLocationPromptTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The location-off prompt (LOCATION-OFF-FLOW.md §2 to §4, 5.12b.1): where it
/// shows, Maybe later and the guide row, the flag cleared on grant, the
/// ghost's data and its turning loop.
@Suite("Compass location prompt", .timeLimit(.minutes(1)))
@MainActor
struct CompassLocationPromptTests {

    // MARK: - Gating

    @Test("The prompt shows wherever the user can turn location on")
    func showsWhenUserCanEnable() {
        for auth in [LocationAuthState.notDetermined, .denied, .servicesOff] {
            #expect(CompassViewModel.showsLocationOffPrompt(for: Self.context(auth: auth)))
        }
    }

    @Test("Restricted keeps the chip: no prompt, and no row even after Maybe later")
    func restrictedKeepsChip() {
        #expect(!CompassViewModel.showsLocationOffPrompt(for: Self.context(auth: .restricted)))

        let store = InMemoryOnboardingStore(locationPromptDismissed: true)
        let viewModel = Self.makeViewModel(store: store)
        viewModel.update(Self.context(auth: .restricted))
        #expect(viewModel.visibility == .locationOff)
        #expect(!viewModel.showsLocationOffPrompt)
        #expect(!viewModel.showsLocationGuideRow)
    }

    @Test("No prompt when location is on, or with no place yet")
    func hiddenOtherwise() {
        #expect(!CompassViewModel.showsLocationOffPrompt(for: Self.context(auth: .authorized)))
        #expect(!CompassViewModel.showsLocationOffPrompt(for: .empty))
    }

    // MARK: - Maybe later and the row

    @Test("Maybe later shows the row and persists; a relaunch shows the row again")
    func maybeLaterPersists() {
        let store = InMemoryOnboardingStore()
        let viewModel = Self.makeViewModel(store: store)
        viewModel.update(Self.context(auth: .denied))
        #expect(viewModel.showsLocationOffPrompt)
        #expect(!viewModel.showsLocationGuideRow)

        viewModel.dismissLocationPrompt()

        #expect(store.locationPromptDismissed)
        #expect(viewModel.showsLocationGuideRow)

        let relaunched = Self.makeViewModel(store: store)
        relaunched.update(Self.context(auth: .denied))
        #expect(relaunched.showsLocationGuideRow)
    }

    @Test("Tapping the row shows the prompt again, without clearing the flag")
    func rowReopensPrompt() {
        let store = InMemoryOnboardingStore(locationPromptDismissed: true)
        let viewModel = Self.makeViewModel(store: store)
        viewModel.update(Self.context(auth: .denied))
        #expect(viewModel.showsLocationGuideRow)

        viewModel.reopenLocationPrompt()

        #expect(!viewModel.showsLocationGuideRow)
        #expect(viewModel.showsLocationOffPrompt)
        #expect(store.locationPromptDismissed)

        viewModel.dismissLocationPrompt()
        #expect(viewModel.showsLocationGuideRow)
    }

    @Test("Granting location clears the flag, so a later revoke shows the prompt")
    func grantClearsFlag() {
        let store = InMemoryOnboardingStore(locationPromptDismissed: true)
        let viewModel = Self.makeViewModel(store: store)
        viewModel.update(Self.context(auth: .denied))
        #expect(viewModel.showsLocationGuideRow)

        viewModel.update(Self.context(auth: .authorized))
        #expect(!store.locationPromptDismissed)
        #expect(!viewModel.isLocationPromptDismissed)

        viewModel.update(Self.context(auth: .denied))
        #expect(viewModel.showsLocationOffPrompt)
        #expect(!viewModel.showsLocationGuideRow)
    }

    @Test("A DEBUG reset of the store shows the prompt on the next update")
    func storeResetReadBack() {
        let store = InMemoryOnboardingStore(locationPromptDismissed: true)
        let viewModel = Self.makeViewModel(store: store)
        viewModel.update(Self.context(auth: .denied))
        #expect(viewModel.showsLocationGuideRow)

        store.locationPromptDismissed = false
        viewModel.update(Self.context(auth: .denied))
        #expect(!viewModel.showsLocationGuideRow)
    }

    // MARK: - Ghost data

    @Test("The ghost gets the day's rise and set and the arc between them")
    func ghostRiseAndSet() {
        let viewModel = Self.makeViewModel(moon: FakeMoonService(pass: Self.pass))
        viewModel.update(Self.context(auth: .denied, moonDay: Self.moonDay(rise: 72, set: 288)))

        #expect(viewModel.ghostTargets.map(\.kind) == [.moonrise, .moonset])
        #expect(viewModel.ghostArc == CompassArc(startAzimuth: 72, endAzimuth: 288, moonAzimuth: nil))
        // The live dial's own data stays empty with location off.
        #expect(viewModel.targets.isEmpty)
        #expect(viewModel.arc == nil)
    }

    @Test("No moonset: only the rise dot, no arc")
    func ghostWithoutSet() {
        let viewModel = Self.makeViewModel(moon: FakeMoonService(pass: Self.pass))
        viewModel.update(Self.context(auth: .denied, moonDay: Self.moonDay(rise: 72, set: nil)))

        #expect(viewModel.ghostTargets.map(\.kind) == [.moonrise])
        #expect(viewModel.ghostArc == nil)
    }

    @Test("No ghost where the prompt doesn't show")
    func noGhostWhenRestricted() {
        let viewModel = Self.makeViewModel(moon: FakeMoonService(pass: Self.pass))
        viewModel.update(Self.context(auth: .restricted, moonDay: Self.moonDay(rise: 72, set: 288)))

        #expect(viewModel.ghostTargets.isEmpty)
        #expect(viewModel.ghostArc == nil)
    }

    // MARK: - Copy

    @Test("The copy is the spec's, with no final period on the body")
    func copy() {
        #expect(CompassViewModel.locationPromptTitle == "Your moon compass is ready")
        #expect(CompassViewModel.locationPromptBody == "With location on, you'll see the live compass to point your way")
        #expect(CompassViewModel.maybeLaterTitle == "Maybe later")
        #expect(CompassViewModel.guideRowTitle == "Compass guide is waiting")
        #expect(CompassViewModel.guideRowSubtitle == "Tap whenever you want directions")
    }

    // MARK: - Motion

    @Test("The loop hits the handoff's table at each stop")
    func keyframeStops() {
        for key in CompassGhostMotion.keyframes.dropLast() {
            #expect(CompassGhostMotion.degrees(at: key.seconds).isApproximately(key.degrees))
        }
        // 12 s wraps to 0 s, which is the same pose by design.
        #expect(CompassGhostMotion.degrees(at: CompassGhostMotion.loopSeconds).isApproximately(0))
    }

    @Test("It holds, eases and loops")
    func holdsEasesLoops() {
        #expect(CompassGhostMotion.degrees(at: 4).isApproximately(-70))
        #expect(CompassGhostMotion.degrees(at: 9).isApproximately(40))
        // Half-way through a symmetric ease is half-way along.
        #expect(CompassGhostMotion.degrees(at: 1.5).isApproximately(-35, tolerance: 0.5))
        // The first tenth of a move covers far less than a tenth of it.
        #expect(abs(CompassGhostMotion.degrees(at: 0.3)) < 7)
        #expect(CompassGhostMotion.degrees(at: 1.5 + 12 * 3).isApproximately(CompassGhostMotion.degrees(at: 1.5)))
        #expect(CompassGhostMotion.degrees(at: -10.5).isApproximately(CompassGhostMotion.degrees(at: 1.5)))
    }

    @Test("Turning the ring is the opposite heading, and the still frame is north up")
    func ringToHeading() {
        #expect(CompassGhostMotion.heading(forRingDegrees: -70) == 70)
        #expect(CompassGhostMotion.stillDegrees == 0)
    }

    // MARK: - Fixtures

    private static func makeViewModel(
        store: InMemoryOnboardingStore = InMemoryOnboardingStore(),
        moon: FakeMoonService = FakeMoonService()
    ) -> CompassViewModel {
        CompassViewModel(
            headingService: FakeHeadingService(),
            moonService: moon,
            onboardingStore: store,
            sleep: { _ in try await Task.sleep(for: .seconds(3600)) }
        )
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)

    /// A pass from 72° to 288°, as the moon day below has it.
    private static let pass = MoonPass(
        rise: MoonEvent(date: referenceDate, azimuth: 72),
        set: MoonEvent(date: referenceDate.addingTimeInterval(MoonPass.sampleInterval * 2), azimuth: 288),
        path: [72, 180, 288]
    )

    private static func moonDay(rise: Double?, set: Double?) -> MoonDay {
        MoonDay(
            place: .irvine,
            rise: rise.map { MoonEvent(date: referenceDate, azimuth: $0) },
            set: set.map { MoonEvent(date: referenceDate, azimuth: $0) },
            phase: .full,
            phaseAngle: FakeMoonService.fullMoonPhaseAngle,
            illumination: FakeMoonService.fullyLit
        )
    }

    private static func context(auth: LocationAuthState, moonDay: MoonDay? = nil) -> CompassContext {
        CompassContext(
            place: .irvine,
            detectedPlace: nil,
            authState: auth,
            moonDay: moonDay,
            isToday: true
        )
    }
}

private extension Double {
    func isApproximately(_ other: Double, tolerance: Double = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}
