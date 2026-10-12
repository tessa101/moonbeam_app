//
//  IllustrationMotionTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
@testable import moonbeam_app

/// STEP-5.10a, Chunk 5: the approved "Playful beats" timing and the
/// conditions under which no animation timeline may exist.
@Suite("Illustration motion")
struct IllustrationMotionTests {

    @Test("Keyframes land on the motion spec's exact stops")
    func keyframeStops() throws {
        let notFound = IllustrationSpec.locationNotFound
        let question = try #require(notFound.motions[.question])
        let questionTime = 5.18 * 0.20
        #expect(question.rotation?.value(at: questionTime) == 8)
        #expect(question.scale?.value(at: questionTime) == 1.2)
        #expect(question.opacity?.value(at: questionTime) == 1)

        let tube = try #require(IllustrationSpec.permissionOff.motions[.tube])
        #expect(tube.rotation?.value(at: 6.59 * 0.22) == -7)

        let disc = try #require(IllustrationSpec.permissionOff.motions[.moonDisc])
        #expect(disc.brightness?.value(at: 5.88 * 0.5) == 1.06)
    }

    /// Floating-point slack for sampling at a stop's time.
    private static let tolerance = 0.000_001

    @Test(
        "The lens glint warms up, flickers with the wobble and fades",
        arguments: [
            (0.0, 0.0), (0.18, 0.10), (0.28, 0.85), (0.50, 0.80), (0.56, 0.55),
            (0.62, 0.95), (0.68, 0.70), (0.74, 0.60), (0.90, 0.0), (1.0, 0.0),
        ]
    )
    func glintStops(offset: Double, opacity: Double) throws {
        let glint = try #require(IllustrationSpec.permissionOff.motions[.lensGlint]?.opacity)
        #expect(glint.duration == 6.59)
        #expect(abs(glint.value(at: 6.59 * offset) - opacity) < Self.tolerance)
    }

    @Test("The glint eases between stops on the tube's loop")
    func glintBetweenStops() throws {
        let glint = try #require(IllustrationSpec.permissionOff.motions[.lensGlint]?.opacity)
        // Halfway from .18 to .28: ease-in-out is symmetric, so the midpoint.
        #expect(abs(glint.value(at: 6.59 * 0.23) - 0.475) < Self.tolerance)
        // The next loop repeats it.
        #expect(abs(glint.value(at: 6.59 * 1.28) - 0.85) < Self.tolerance)
    }

    @Test("The glint only fades; its tilt comes from the tube it rides on")
    func glintRidesTheTube() throws {
        let spec = IllustrationSpec.permissionOff
        let glint = try #require(spec.motions[.lensGlint])
        #expect(glint.rotation == nil)
        #expect(glint.scale == nil)
        #expect(glint.offsetY == nil)
        let wobble = 6.59 * 0.62
        #expect(spec.pose(of: .lensGlint, at: wobble).rotation == 0)
        #expect(abs(spec.pose(of: .tube, at: wobble).rotation - -7.5) < Self.tolerance)
    }

    @Test("The empty moon ring turns linearly and loops seamlessly")
    func linearRing() throws {
        let ring = try #require(IllustrationSpec.locationNotFound.motions[.moonRing]?.rotation)
        #expect(ring.value(at: 56.5 * 0.25) == 90)
        #expect(ring.value(at: 56.5 * 0.5) == 180)
        #expect(ring.value(at: 56.5) == 0)
    }

    @Test("Reduce Motion uses the specified still poses")
    func staticPoses() {
        let notFound = IllustrationSpec.locationNotFound
        #expect(notFound.pose(of: .question, at: nil) == .rest)
        #expect(notFound.pose(of: .head, at: nil) == .rest)
        #expect(IllustrationSpec.servicesOff.sparkState(at: nil) == nil)
        #expect(IllustrationSpec.restricted.sparkState(at: nil) == nil)
    }

    @Test("Reduce Motion shows the telescope at rest with no glint")
    func telescopeStill() {
        let spec = IllustrationSpec.permissionOff
        #expect(spec.pose(of: .lensGlint, at: nil).opacity == 0)
        #expect(spec.pose(of: .tube, at: nil) == .rest)
        // The star's still frame is its first stop: hidden.
        #expect(spec.star?.motion.pose(at: 0).opacity == 0)
        #expect(spec.star?.motion.pose(at: 0).scale == 0)
    }

    @Test("Smoothstep follows x squared times three minus two x")
    func smoothstep() {
        #expect(IllustrationSpark.smoothstep(-1) == 0)
        #expect(IllustrationSpark.smoothstep(0.25) == 0.15625)
        #expect(IllustrationSpark.smoothstep(0.5) == 0.5)
        #expect(IllustrationSpark.smoothstep(1) == 1)
        #expect(IllustrationSpark.smoothstep(2) == 1)
    }

    @Test("Restricted spark reaches the lock, bounces, fades, then rests")
    func restrictedBounce() throws {
        let spark = try #require(IllustrationSpec.restricted.spark)
        let arrival = spark.state(at: spark.travel)
        #expect(arrival.progress == spark.reach)
        #expect(arrival.opacity == 1)

        let halfway = spark.state(at: spark.travel + IllustrationSpark.bounceDuration / 2)
        #expect(abs(halfway.progress - (spark.reach - 0.06)) < 0.000_001)
        #expect(abs(halfway.opacity - 0.5) < 0.000_001)

        let rested = spark.state(at: spark.travel + IllustrationSpark.bounceDuration)
        #expect(rested.progress == 0)
        #expect(rested.opacity == 0)
    }

    @Test("Lock shake starts on impact and is zero by 1.06 seconds")
    func lockShake() throws {
        let spark = try #require(IllustrationSpec.restricted.spark)
        #expect(spark.lockAngle(at: spark.travel) == 0)
        #expect(spark.lockAngle(at: spark.travel + 0.05) != 0)
        #expect(spark.lockAngle(at: spark.travel + IllustrationSpark.shakeDuration) == 0)
        #expect(spark.lockAngle(at: spark.travel + IllustrationSpark.shakeDuration + 0.1) == 0)
    }

    @Test("No timeline is selected for Reduce Motion, background, or dismissal")
    func animationLifecyclePolicy() {
        #expect(LocationIllustration.shouldAnimate(
            reduceMotion: false,
            scenePhase: .active,
            isVisible: true
        ))
        #expect(!LocationIllustration.shouldAnimate(
            reduceMotion: true,
            scenePhase: .active,
            isVisible: true
        ))
        #expect(!LocationIllustration.shouldAnimate(
            reduceMotion: false,
            scenePhase: .inactive,
            isVisible: true
        ))
        #expect(!LocationIllustration.shouldAnimate(
            reduceMotion: false,
            scenePhase: .background,
            isVisible: true
        ))
        #expect(!LocationIllustration.shouldAnimate(
            reduceMotion: false,
            scenePhase: .active,
            isVisible: false
        ))
    }
}
