//
//  IllustrationTailBendTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// STEP-5.14 §5.1–5.2: 1k's bending tail, its joint weights and lag, and
/// that a stiff, unlagged bend is the old rigid swing.
@Suite("Illustration tail bend")
struct IllustrationTailBendTests {

    private static let spec = IllustrationSpec.readyToLook
    private static let tailLayer = spec.layers[1]
    /// Floating-point slack for derived geometry.
    private static let tolerance = 0.000_001
    /// §5.1's table, in the cat group's image space.
    private static let jointX = [350.5, 365.0, 366.1, 356.4, 324.7, 311.1]
    private static let spanBottom = 902.0
    private static let bandHeight = (902.0 - 639.0) / 7

    private func bend() throws -> IllustrationTailBend {
        try #require(Self.spec.tailBend)
    }

    private func track() throws -> IllustrationKeyframes {
        try #require(Self.spec.motions[.tail]?.rotation)
    }

    /// Image space (the rasters at 215, 250) to viewBox.
    private func viewBox(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * 0.415 - 49, y: y * 0.415 + 27.73)
    }

    private func expectClose(_ a: CGAffineTransform, _ b: CGAffineTransform, _ note: Comment? = nil) {
        for (x, y) in [(a.a, b.a), (a.b, b.b), (a.c, b.c), (a.d, b.d), (a.tx, b.tx), (a.ty, b.ty)] {
            #expect(abs(x - y) < Self.tolerance, note)
        }
    }

    @Test("1k bends its tail with §5.2's flex and lag; other causes don't")
    func readyToLookConstants() throws {
        let bend = try bend()
        #expect(bend.flex == 0.95)
        #expect(bend.lag == 0.30)
        #expect(IllustrationTailBend.bandCount == 7)
        for spec in [IllustrationSpec.searching, .locationNotFound, .servicesOff, .restricted] {
            #expect(spec.tailBend == nil)
            #expect(spec.layers.allSatisfy { spec.tailBands(of: $0, at: 1) == nil })
        }
        // Only the tail layer is cut into bands.
        let banded = Self.spec.layers.filter { Self.spec.tailBands(of: $0, at: 1) != nil }
        #expect(banded.map(\.asset) == ["readyToLook_tail"])
    }

    @Test("Joints: the existing pivot, then §5.1's x at each band's bottom")
    func joints() throws {
        let joints = try bend().joints
        #expect(joints.count == 7)
        #expect(joints[0] == CGPoint(x: 97, y: 414.5))
        #expect(joints[0] == Self.spec.pivots[.tail])
        for (offset, x) in Self.jointX.enumerated() {
            let expected = viewBox(x, Self.spanBottom - Double(offset + 1) * Self.bandHeight)
            #expect(abs(joints[offset + 1].x - expected.x) < Self.tolerance)
            #expect(abs(joints[offset + 1].y - expected.y) < Self.tolerance)
        }
    }

    @Test("Bands stack base to tip, overlap the band below by 4 px, and cover the whole slice")
    func bands() throws {
        let bands = try bend().bands
        let art = CGRect(x: 40.225, y: 131.48, width: 332, height: 356.9)
        let overlap = 4 * 0.415
        #expect(abs(bands[0].maxY - art.maxY) < Self.tolerance)
        #expect(abs(bands[6].minY - art.minY) < Self.tolerance)
        for index in 1..<7 {
            let joint = viewBox(0, Self.spanBottom - Double(index) * Self.bandHeight).y
            #expect(abs(bands[index].maxY - (joint + overlap)) < Self.tolerance)
            #expect(abs(bands[index - 1].minY - joint) < Self.tolerance)
        }
        for band in bands {
            #expect(abs(band.minX - art.minX) < Self.tolerance)
            #expect(abs(band.width - art.width) < Self.tolerance)
        }
    }

    @Test("Weights: the base keeps the stiff share; all seven sum to one")
    func weights() throws {
        let bend = try bend()
        #expect(abs(bend.weight(of: 0) - (0.05 + 0.95 / 7)) < Self.tolerance)
        for index in 1..<7 {
            #expect(abs(bend.weight(of: index) - 0.95 / 7) < Self.tolerance)
        }
        let total = (0..<7).map(bend.weight(of:)).reduce(0, +)
        #expect(abs(total - 1) < Self.tolerance)
    }

    @Test("Each joint trails the one below by lag × loop ÷ 6")
    func lagShift() throws {
        let bend = try bend()
        let track = try track()
        let time = 1.3
        for index in 0..<7 {
            let delay = 0.30 * 2.25 * Double(index) / 6
            let expected = track.value(at: time - delay) * bend.weight(of: index)
            #expect(abs(bend.angle(of: index, track: track, at: time) - expected) < Self.tolerance)
        }
        // The tip reaches the base's peak lag × loop later.
        let basePeak = 2.25 * 0.25
        #expect(abs(bend.angle(of: 0, track: track, at: basePeak) - 20 * bend.weight(of: 0)) < Self.tolerance)
        #expect(abs(bend.angle(of: 6, track: track, at: basePeak + 0.30 * 2.25) - 20 * bend.weight(of: 6))
            < Self.tolerance)
    }

    @Test("With no lag, the tip's total turn is the tuned swing", arguments: [0.25, 0.75])
    func tipSumsToTrack(offset: Double) throws {
        var bend = try bend()
        bend.lag = 0
        let track = try track()
        let time = 2.25 * offset
        let total = (0..<7).map { bend.angle(of: $0, track: track, at: time) }.reduce(0, +)
        #expect(abs(total - track.value(at: time)) < Self.tolerance)
    }

    @Test("Flex 0 and lag 0 reproduce the old rigid swing about the base pivot", arguments: [0.0, 0.4, 0.5625, 1.1, 1.6875, 2.0])
    func rigidCase(time: Double) throws {
        var rigid = Self.spec
        rigid.tailBend?.flex = 0
        rigid.tailBend?.lag = 0
        let rigidSwing = rigid.transform(of: Self.tailLayer, at: time, canvasScale: 0.6)
        let bands = try #require(rigid.tailBands(of: Self.tailLayer, at: time, canvasScale: 0.6))
        #expect(bands.count == 7)
        for band in bands {
            expectClose(band.transform, rigidSwing)
        }
    }

    @Test("A band turns on its own joint, inside the bands below and the breath")
    func nesting() throws {
        let bend = try bend()
        let track = try track()
        let time = 1.9
        let bands = try #require(Self.spec.tailBands(of: Self.tailLayer, at: time))
        let breath = Self.spec.pose(of: .breath, at: time).transform(pivot: Self.spec.pivots[.breath])
        var expected = CGAffineTransform.identity
        for index in 0..<7 {
            let joint = IllustrationMotion.Pose(rotation: bend.angle(of: index, track: track, at: time))
                .transform(pivot: bend.joints[index])
            // Inner first: this joint, then the chain below it.
            expected = joint.concatenating(expected)
            expectClose(bands[index].transform, expected.concatenating(breath), "band \(index)")
        }
    }

    @Test("Clips scale with the drawn frame")
    func clipsScale() throws {
        let bend = try bend()
        let bands = try #require(Self.spec.tailBands(of: Self.tailLayer, at: 0, canvasScale: 0.6))
        for (band, rect) in zip(bands, bend.bands) {
            #expect(abs(band.clip.minY - rect.minY * 0.6) < Self.tolerance)
            #expect(abs(band.clip.height - rect.height * 0.6) < Self.tolerance)
        }
    }
}
