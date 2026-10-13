//
//  CompassTeaserTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
@testable import moonbeam_app

/// The location-off teaser (design handoff, Location Off Teaser, 1b): the
/// "hunt, then find" keyframes, when the animation may run, and when the
/// teaser replaces the warning chip.
@Suite("Compass teaser")
@MainActor
struct CompassTeaserTests {

    // MARK: - Motion

    @Test("The loop hits the handoff's table at each stop")
    func keyframeStops() {
        for key in CompassTeaserMotion.keyframes {
            let frame = CompassTeaserMotion.frame(at: key.seconds)
            // 5.0 s wraps to 0 s, which is the same pose by design.
            #expect(frame.needleDegrees.isApproximately(key.frame.needleDegrees))
            #expect(frame.glowOpacity.isApproximately(key.frame.glowOpacity))
            #expect(frame.glowRadius.isApproximately(key.frame.glowRadius))
        }
    }

    @Test("The loop closes and repeats")
    func loops() {
        #expect(CompassTeaserMotion.keyframes.first?.frame == CompassTeaserMotion.keyframes.last?.frame)
        let a = CompassTeaserMotion.frame(at: 1.2)
        let b = CompassTeaserMotion.frame(at: 1.2 + CompassTeaserMotion.loopSeconds * 3)
        #expect(a.needleDegrees.isApproximately(b.needleDegrees))
        #expect(CompassTeaserMotion.frame(at: -3.8).needleDegrees.isApproximately(a.needleDegrees))
    }

    @Test("It overshoots the moon before settling on it")
    func overshoot() {
        let peak = CompassTeaserMotion.frame(at: 2.25)
        #expect(peak.needleDegrees.isApproximately(CompassTeaserMotion.keyframes[3].frame.needleDegrees))
        #expect(peak.needleDegrees > CompassTeaserMotion.settled.needleDegrees)
        #expect(CompassTeaserMotion.frame(at: 3.8).needleDegrees.isApproximately(62))
    }

    @Test("Each segment eases: slow at the ends, faster mid-way")
    func easing() {
        // 0 → 0.75 s goes -30° → 40°; the first tenth of the time covers far
        // less than a tenth of the way.
        let early = CompassTeaserMotion.frame(at: 0.075).needleDegrees
        #expect(early - -30 < 0.1 * 70)
        let middle = CompassTeaserMotion.frame(at: 0.375).needleDegrees
        #expect(middle.isApproximately(5, tolerance: 0.5))
    }

    @Test("The settled frame is the handoff's Reduce Motion pose")
    func settled() {
        #expect(CompassTeaserMotion.settled == .init(needleDegrees: 62, glowOpacity: 0.55, glowRadius: 19))
    }

    @Test("It only animates when motion is allowed, active and visible")
    func shouldAnimate() {
        #expect(CompassTeaser.shouldAnimate(reduceMotion: false, scenePhase: .active, isVisible: true))
        #expect(!CompassTeaser.shouldAnimate(reduceMotion: true, scenePhase: .active, isVisible: true))
        #expect(!CompassTeaser.shouldAnimate(reduceMotion: false, scenePhase: .background, isVisible: true))
        #expect(!CompassTeaser.shouldAnimate(reduceMotion: false, scenePhase: .inactive, isVisible: true))
        #expect(!CompassTeaser.shouldAnimate(reduceMotion: false, scenePhase: .active, isVisible: false))
    }

    // MARK: - When it shows

    @Test("The teaser replaces the chip wherever the user can turn location on")
    func showsWhenUserCanEnable() {
        for auth in [LocationAuthState.notDetermined, .denied, .servicesOff] {
            #expect(CompassViewModel.showsLocationOffTeaser(for: Self.context(auth: auth)))
        }
    }

    @Test("Restricted keeps the plain note, since turning on location can't help")
    func restrictedKeepsNote() {
        #expect(!CompassViewModel.showsLocationOffTeaser(for: Self.context(auth: .restricted)))
    }

    @Test("No teaser when location is on, or with no place yet")
    func hiddenOtherwise() {
        #expect(!CompassViewModel.showsLocationOffTeaser(for: Self.context(auth: .authorized)))
        #expect(!CompassViewModel.showsLocationOffTeaser(for: .empty))
    }

    @Test("The teaser copy is the handoff's")
    func copy() {
        #expect(CompassViewModel.locationOffTeaserTitle == "Point your phone at the moon")
        #expect(CompassViewModel.locationOffTeaserBody
            == "With location on, this becomes a live compass that turns you toward it.")
    }

    // MARK: - Fixtures

    private static func context(auth: LocationAuthState) -> CompassContext {
        CompassContext(
            place: .irvine,
            detectedPlace: nil,
            authState: auth,
            moonDay: nil,
            isToday: true
        )
    }
}

private extension Double {
    func isApproximately(_ other: Double, tolerance: Double = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}
