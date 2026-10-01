//
//  PhaseGlyphGeometryTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// The phase glyph draws the real lit fraction (DESIGN-1.1.md §3.2, §8): the
/// outline's area is that fraction of the disc, on the right side waxing and
/// the left waning (northern hemisphere).
@Suite("Phase glyph geometry")
nonisolated struct PhaseGlyphGeometryTests {

    /// The polygon's area against the true fraction. 96 segments per half
    /// come within 0.1%; this leaves room without hiding a wrong shape.
    private static let areaTolerance = 0.005

    private static let waxingAngle = 90.0
    private static let waningAngle = 270.0

    @Test(
        "The outline covers the lit fraction of the disc",
        arguments: [0.0, 0.25, 0.5, 0.75, 1.0],
        [waxingAngle, waningAngle]
    )
    func areaMatchesLitFraction(litFraction: Double, phaseAngle: Double) {
        let geometry = PhaseGlyphGeometry(illumination: litFraction, phaseAngle: phaseAngle)

        let area = Self.area(of: geometry.litOutline())

        #expect(abs(area / Double.pi - litFraction) < Self.areaTolerance)
    }

    /// The outline reaches the bright limb and, short of full, never the dark
    /// one. At 0% there's nothing lit to place.
    @Test(
        "Waxing is lit on the right, waning on the left",
        arguments: [0.25, 0.5, 0.75, 1.0],
        [waxingAngle, waningAngle]
    )
    func litSide(litFraction: Double, phaseAngle: Double) {
        let geometry = PhaseGlyphGeometry(illumination: litFraction, phaseAngle: phaseAngle)
        let waxing = phaseAngle < 180

        #expect(geometry.litSide == (waxing ? .right : .left))
        let limbX = geometry.litOutline().map(\.x)
        if waxing {
            #expect(limbX.max() ?? 0 > 0.99)
        } else {
            #expect(limbX.min() ?? 0 < -0.99)
        }
        if litFraction < 1 {
            // The dark limb isn't reached.
            if waxing {
                #expect(limbX.min() ?? 0 > -0.99)
            } else {
                #expect(limbX.max() ?? 0 < 0.99)
            }
        }
    }

    @Test("Terminator: on the limb at new, straight at a quarter, on the far limb at full")
    func terminatorOffset() {
        #expect(PhaseGlyphGeometry(illumination: 0, phaseAngle: 0).terminatorOffset == 1)
        #expect(PhaseGlyphGeometry(illumination: 0.5, phaseAngle: 90).terminatorOffset == 0)
        #expect(PhaseGlyphGeometry(illumination: 1, phaseAngle: 180).terminatorOffset == -1)
    }

    @Test("Out-of-range illumination is clamped")
    func clamped() {
        #expect(PhaseGlyphGeometry(illumination: 1.2, phaseAngle: 180).litFraction == 1)
        #expect(PhaseGlyphGeometry(illumination: -0.1, phaseAngle: 0).litFraction == 0)
    }

    // MARK: - Helpers

    /// Shoelace formula: the polygon's area, whichever way it winds.
    private static func area(of points: [CGPoint]) -> Double {
        var twiceArea = 0.0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            twiceArea += Double(current.x * next.y - next.x * current.y)
        }
        return abs(twiceArea) / 2
    }
}
