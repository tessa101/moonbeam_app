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

        let disc = try #require(IllustrationSpec.readyToLook.motions[.moonDisc])
        #expect(disc.brightness?.value(at: 5.88 * 0.5) == 1.06)
    }

    /// Floating-point slack for sampling at a stop's time.
    private static let tolerance = 0.000_001

    @Test(
        "1k's head lifts twice as if about to peek",
        arguments: [(0.0, 0.0), (0.22, -3.2), (0.40, -2.2), (0.58, -3.6), (0.80, -1.0), (1.0, 0.0)]
    )
    func readyToLookHead(offset: Double, degrees: Double) throws {
        let head = try #require(IllustrationSpec.readyToLook.motions[.head]?.rotation)
        #expect(head.duration == 8.82)
        #expect(abs(head.value(at: 8.82 * offset) - degrees) < Self.tolerance)
    }

    @Test(
        "1k's ear rests, then flicks hard and settles (STEP-5.14 §5.2)",
        arguments: [(0.0, 0.0), (0.55, 0.0), (0.60, -21.0), (0.65, 7.0), (0.70, -8.7), (0.76, 0.0), (1.0, 0.0)]
    )
    func readyToLookEar(offset: Double, degrees: Double) throws {
        let ear = try #require(IllustrationSpec.readyToLook.motions[.ear]?.rotation)
        #expect(ear.duration == 5.35)
        #expect(abs(ear.value(at: 5.35 * offset) - degrees) < Self.tolerance)
    }

    @Test("1k breathes taller than wide, and sways its tail, each on its own loop")
    func readyToLookBreathAndTail() throws {
        let spec = IllustrationSpec.readyToLook
        let breath = spec.pose(of: .breath, at: 4.47 * 0.5)
        #expect(abs(breath.scaleX - 1.006) < Self.tolerance)
        #expect(abs(breath.scaleY - 1.014) < Self.tolerance)
        #expect(breath.scale == 1)
        let tail = try #require(spec.motions[.tail]?.rotation)
        // STEP-5.14 §5.2: the base swing the bending tail spreads.
        #expect(tail.duration == 2.25)
        #expect(abs(tail.value(at: 2.25 * 0.25) - 20) < Self.tolerance)
        #expect(abs(tail.value(at: 2.25 * 0.5)) < Self.tolerance)
        #expect(abs(tail.value(at: 2.25 * 0.75) - -15) < Self.tolerance)
        // Four independent lengths, so the mix rarely repeats.
        let durations = [
            spec.motions[.breath]?.scaleY?.duration, spec.motions[.head]?.rotation?.duration,
            spec.motions[.ear]?.rotation?.duration, tail.duration,
        ]
        #expect(Set(durations.compactMap { $0 }).count == 4)
    }

    @Test("The star keeps 1h's sparkle loop")
    func readyToLookStarLoop() throws {
        let star = try #require(IllustrationSpec.readyToLook.star)
        #expect(star.motion.rotation?.duration == 6.59)
        #expect(star.motion.scale?.value(at: 6.59 * 0.36) == 1)
        #expect(star.motion.rotation?.value(at: 6.59 * 0.54) == 90)
        #expect(star.motion.opacity?.value(at: 6.59 * 0.46) == 0.8)
    }

    @Test("Per-axis scale stretches about the pivot")
    func perAxisScaleTransform() {
        let pose = IllustrationMotion.Pose(scaleX: 1.5, scaleY: 2)
        let pivot = CGPoint(x: 10, y: 20)
        #expect(CGPoint(x: 10, y: 20).applying(pose.transform(pivot: pivot)) == pivot)
        #expect(CGPoint(x: 12, y: 21).applying(pose.transform(pivot: pivot)) == CGPoint(x: 13, y: 22))
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

    @Test("Reduce Motion shows ready to look at offset zero, with no star")
    func readyToLookStill() {
        let spec = IllustrationSpec.readyToLook
        for part in [IllustrationSpec.Part.breath, .head, .ear, .tail] {
            #expect(spec.pose(of: part, at: nil) == .rest, "\(part)")
        }
        for layer in spec.layers {
            #expect(spec.transform(of: layer, at: nil) == .identity, "\(layer.asset)")
        }
        // Every tail joint too.
        let tail = spec.layers[1]
        let bands = spec.tailBands(of: tail, at: nil)
        #expect(bands?.count == IllustrationTailBend.bandCount)
        #expect(bands?.allSatisfy { $0.transform == .identity } == true)
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
