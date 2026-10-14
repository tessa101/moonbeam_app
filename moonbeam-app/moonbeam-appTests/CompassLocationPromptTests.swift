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

    // MARK: - Ghost geometry (the plain ring, 5.12b.1a)

    @Test("Azimuth to point matches the mock: rise 115° at (224.3, 174), set 243° at (37.3, 177.2)")
    func azimuthToPoint() {
        let rise = CompassGhostGeometry.point(atAzimuth: 115)
        #expect(Double(rise.x).isApproximately(224.3, tolerance: 0.05))
        #expect(Double(rise.y).isApproximately(174, tolerance: 0.05))
        let set = CompassGhostGeometry.point(atAzimuth: 243)
        #expect(Double(set.x).isApproximately(37.3, tolerance: 0.05))
        #expect(Double(set.y).isApproximately(177.2, tolerance: 0.05))
        // North is the ring's top.
        let north = CompassGhostGeometry.point(atAzimuth: 0)
        #expect(Double(north.x).isApproximately(130))
        #expect(Double(north.y).isApproximately(26))
    }

    @Test("The arc runs clockwise from rise to set, end to end, through the south")
    func arcClockwise() throws {
        let geometry = CompassGhostGeometry(rise: 115, set: 243, moonAzimuth: nil)
        #expect(geometry.arcPoints.first == geometry.riseDot)
        let end = try #require(geometry.arcPoints.last)
        #expect(Double(end.x).isApproximately(37.3, tolerance: 0.05))
        #expect(Double(end.y).isApproximately(177.2, tolerance: 0.05))
        // Through due south (130, 234), the bottom of the ring.
        #expect(geometry.arcPoints.contains { abs($0.x - 130) < 1 && abs($0.y - 234) < 0.1 })
        // Across north, clockwise: 300° to 60° is 120°, not 240°.
        #expect(CompassGhostGeometry.clockwiseSweep(from: 300, to: 60) == 120)
        #expect(CompassGhostGeometry.clockwiseSweep(from: 115, to: 243) == 128)
    }

    @Test("Both rise and set: two dots and an arc")
    func bothEnds() {
        let geometry = CompassGhostGeometry(rise: 57, set: 304, moonAzimuth: nil)
        #expect(geometry.riseDot != nil)
        #expect(geometry.setDot != nil)
        #expect(!geometry.arcPoints.isEmpty)
    }

    @Test("No moonrise: the set dot only, no arc")
    func noRise() {
        let geometry = CompassGhostGeometry(rise: nil, set: 304, moonAzimuth: nil)
        #expect(geometry.riseDot == nil)
        #expect(geometry.setDot == CompassGhostGeometry.point(atAzimuth: 304))
        #expect(geometry.arcPoints.isEmpty)
        #expect(geometry.moonMarker == nil)
    }

    @Test("No moonset: the rise dot only, no arc")
    func noSet() {
        let geometry = CompassGhostGeometry(rise: 57, set: nil, moonAzimuth: nil)
        #expect(geometry.riseDot == CompassGhostGeometry.point(atAzimuth: 57))
        #expect(geometry.setDot == nil)
        #expect(geometry.arcPoints.isEmpty)
    }

    @Test("Moon up: the marker sits at the live moon's azimuth")
    func markerMoonUp() {
        let geometry = CompassGhostGeometry(rise: 115, set: 243, moonAzimuth: 200)
        #expect(geometry.moonMarker == CompassGhostGeometry.point(atAzimuth: 200))
    }

    @Test("Moon down: the marker sits at the arc's midpoint, across north too")
    func markerMoonDown() {
        let geometry = CompassGhostGeometry(rise: 115, set: 243, moonAzimuth: nil)
        #expect(geometry.moonMarker == CompassGhostGeometry.point(atAzimuth: 179))
        let acrossNorth = CompassGhostGeometry(rise: 300, set: 60, moonAzimuth: nil)
        #expect(acrossNorth.moonMarker == CompassGhostGeometry.point(atAzimuth: 360))
    }

    @Test("The view model feeds the ring the day's rise and set, and the moon only when up")
    func viewModelGhost() {
        let day = Self.moonDay(rise: 115, set: 243)
        let down = Self.makeViewModel(moon: FakeMoonService(position: MoonPosition(azimuth: 200, isUp: false)))
        down.update(Self.context(auth: .denied, moonDay: day))
        #expect(down.ghostGeometry == CompassGhostGeometry(rise: 115, set: 243, moonAzimuth: nil))

        let up = Self.makeViewModel(moon: FakeMoonService(position: MoonPosition(azimuth: 200, altitude: 20, isUp: true)))
        up.update(Self.context(auth: .denied, moonDay: day))
        #expect(up.ghostGeometry == CompassGhostGeometry(rise: 115, set: 243, moonAzimuth: 200))
        // The live dial's own data stays empty with location off.
        #expect(up.targets.isEmpty)
        #expect(up.arc == nil)
    }

    @Test("No ghost where the prompt doesn't show")
    func noGhostWhenRestricted() {
        let viewModel = Self.makeViewModel()
        viewModel.update(Self.context(auth: .restricted, moonDay: Self.moonDay(rise: 72, set: 288)))
        #expect(viewModel.ghostGeometry == CompassGhostGeometry(rise: nil, set: nil, moonAzimuth: nil))
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

    @Test("The still frame is north up")
    func stillFrame() {
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
