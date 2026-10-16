//
//  LandingTailBendTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// STEP-5.14 §5.1, §5.3: the landing's searching cat bends its vector tail
/// with its own geometry, flex and lag, starts at rest as its entrance lands
/// and is still under Reduce Motion.
@Suite("Landing tail bend")
struct LandingTailBendTests {

    private static let spec = IllustrationSpec.searching
    private static let tailLayer = spec.layers[2]
    private static let lookLayer = spec.layers[4]
    /// Floating-point slack for derived geometry.
    private static let tolerance = 0.000_001
    /// §5.1's table, in the art space inside `translate(-15 -130)`.
    private static let jointX = [110.9, 97.9, 96.9, 102.0, 105.2, 93.3]
    private static let spanBottom = 588.0
    private static let bandHeight = (588.0 - 402.2) / 7
    private static let loop = 1.40

    private func bend() throws -> IllustrationTailBend {
        try #require(Self.spec.tailBend)
    }

    private func track() throws -> IllustrationKeyframes {
        try #require(Self.spec.motions[.tail]?.rotation)
    }

    /// Art space to viewBox.
    private func viewBox(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x - 15, y: y - 130)
    }

    @Test("§5.3's flex and lag; only the tail layer is banded")
    func constants() throws {
        let bend = try bend()
        #expect(bend.flex == 1.00)
        #expect(bend.lag == 0.44)
        #expect(Self.tailLayer.asset == "searching_tail")
        let banded = Self.spec.layers.filter { Self.spec.tailBands(of: $0, at: 1) != nil }
        #expect(banded.map(\.asset) == ["searching_tail"])
    }

    @Test("Joints: the existing pivot (132, 582 in art space), then §5.1's x at each band's bottom")
    func joints() throws {
        let joints = try bend().joints
        #expect(joints.count == 7)
        #expect(joints[0] == viewBox(132, 582))
        #expect(joints[0] == Self.spec.pivots[.tail])
        for (offset, x) in Self.jointX.enumerated() {
            let expected = viewBox(x, Self.spanBottom - Double(offset + 1) * Self.bandHeight)
            #expect(abs(joints[offset + 1].x - expected.x) < Self.tolerance)
            #expect(abs(joints[offset + 1].y - expected.y) < Self.tolerance)
        }
    }

    @Test("Bands overlap the band below by 1.5 units and cover the whole canvas")
    func bands() throws {
        let bands = try bend().bands
        #expect(abs(bands[0].maxY - IllustrationSpec.viewBox.height) < Self.tolerance)
        #expect(abs(bands[6].minY) < Self.tolerance)
        for index in 1..<7 {
            let joint = viewBox(0, Self.spanBottom - Double(index) * Self.bandHeight).y
            #expect(abs(bands[index].maxY - (joint + 1.5)) < Self.tolerance)
            #expect(abs(bands[index - 1].minY - joint) < Self.tolerance)
        }
        for band in bands {
            #expect(abs(band.minX) < Self.tolerance)
            #expect(abs(band.width - IllustrationSpec.viewBox.width) < Self.tolerance)
        }
    }

    @Test("Weights: flex 1 shares the swing evenly, 1/7 per joint, summing to one")
    func weights() throws {
        let bend = try bend()
        #expect(abs(bend.weight(of: 0) - 1.0 / 7) < Self.tolerance)
        for index in 1..<7 {
            #expect(abs(bend.weight(of: index) - 1.0 / 7) < Self.tolerance)
        }
        #expect(abs((0..<7).map(bend.weight(of:)).reduce(0, +) - 1) < Self.tolerance)
    }

    @Test("Each joint reaches the base's +11.7° peak its lag later; the tip lag × loop later")
    func lagShift() throws {
        let bend = try bend()
        let track = try track()
        let basePeak = Self.loop * 0.25
        #expect(abs(bend.angle(of: 0, track: track, at: basePeak) - 11.7 * bend.weight(of: 0)) < Self.tolerance)
        for index in 1..<7 {
            let delay = 0.44 * Self.loop * Double(index) / 6
            #expect(abs(bend.angle(of: index, track: track, at: basePeak + delay) - 11.7 * bend.weight(of: index))
                < Self.tolerance)
        }
    }

    @Test("The tip repeats the base's turn lag × loop later (0.616 s)", arguments: [0.0, 0.1, 0.35, 0.6, 1.05, 1.3])
    func tipTrailsBase(time: Double) throws {
        let bend = try bend()
        let track = try track()
        let tipDelay = 0.44 * Self.loop
        // Flex 1: every joint has the same weight, so the tip's own turn is
        // the base's, shifted by the whole lag.
        #expect(abs(bend.angle(of: 6, track: track, at: time + tipDelay) - bend.angle(of: 0, track: track, at: time))
            < Self.tolerance)
    }

    @Test("The first second starts at rest and moves without a jump")
    func firstSecondHasNoJump() throws {
        let bend = try bend()
        let track = try track()
        let step = 1.0 / 120
        // At 120 Hz, the base's fastest turn (ease-in-out, 11.7° per quarter
        // loop, 1/7 weight) is well under 0.1° a frame for each joint.
        let maximumStep = 0.1
        var previous = (0..<7).map { bend.angle(of: $0, track: track, at: 0) }
        #expect(previous.allSatisfy { $0 == 0 })
        for frame in 1...120 {
            let angles = (0..<7).map { bend.angle(of: $0, track: track, at: Double(frame) * step) }
            for (now, before) in zip(angles, previous) {
                #expect(abs(now - before) < maximumStep, "frame \(frame)")
            }
            previous = angles
        }
    }

    @Test("Flex 0 and lag 0 reproduce a rigid swing about the base pivot", arguments: [0.0, 0.2, 0.35, 0.7, 1.05, 1.3])
    func rigidCase(time: Double) throws {
        var rigid = Self.spec
        rigid.tailBend?.flex = 0
        rigid.tailBend?.lag = 0
        let rigidSwing = rigid.transform(of: Self.tailLayer, at: time, canvasScale: 0.6)
        let bands = try #require(rigid.tailBands(of: Self.tailLayer, at: time, canvasScale: 0.6))
        for band in bands {
            for (a, b) in [
                (band.transform.a, rigidSwing.a), (band.transform.b, rigidSwing.b),
                (band.transform.c, rigidSwing.c), (band.transform.d, rigidSwing.d),
                (band.transform.tx, rigidSwing.tx), (band.transform.ty, rigidSwing.ty),
            ] {
                #expect(abs(a - b) < Self.tolerance)
            }
        }
    }

    @Test("The loop starts at rest as the entrance lands: every joint and the look at time 0")
    func startsAtRest() throws {
        let bands = try #require(Self.spec.tailBands(of: Self.tailLayer, at: 0))
        #expect(bands.allSatisfy { $0.transform == .identity })
        #expect(Self.spec.transform(of: Self.lookLayer, at: 0) == .identity)
    }

    @Test("Reduce Motion: still art, every joint and the look at identity")
    func reduceMotionStill() throws {
        // The halo's still is its breath's first stop (0.95), as before.
        for layer in Self.spec.layers.dropFirst() {
            #expect(Self.spec.transform(of: layer, at: nil) == .identity, "\(layer.asset)")
        }
        let bands = try #require(Self.spec.tailBands(of: Self.tailLayer, at: nil))
        #expect(bands.count == IllustrationTailBend.bandCount)
        #expect(bands.allSatisfy { $0.transform == .identity })
    }
}
