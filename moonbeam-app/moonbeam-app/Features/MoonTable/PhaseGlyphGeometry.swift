//
//  PhaseGlyphGeometry.swift
//  moonbeam-app
//

import CoreGraphics

/// The lit shape of the phase glyph (DESIGN-1.1.md §3.2): the real lit
/// fraction, bounded by the bright limb and an elliptical terminator.
///
/// Seen face-on, the terminator is half an ellipse whose horizontal
/// semi-axis is `|1 − 2k|` of the radius, for lit fraction `k`. Between it
/// and the limb lies exactly `k` of the disc's area, so the drawing matches
/// the "75% lit" beside it. Crescents bow the terminator toward the limb,
/// gibbous phases away from it.
///
/// Northern-hemisphere orientation for 1.1: waxing is lit on the right,
/// waning on the left. The southern flip is in the backlog.
///
/// `nonisolated`: pure geometry, testable without a view.
nonisolated struct PhaseGlyphGeometry: Equatable {

    // MARK: - Types

    enum LitSide: Equatable {
        case left
        case right
    }

    // MARK: - Constants

    /// Phase angles below this are waxing (0° new, 180° full).
    private static let fullMoonPhaseAngle = 180.0

    /// Points per half outline. Plenty for a 64 pt glyph, and keeps the
    /// polygon area within 0.1% of the true lit fraction.
    static let defaultSegments = 96

    // MARK: - State

    /// Fraction of the disc lit, clamped to `0...1`.
    let litFraction: Double

    let litSide: LitSide

    /// - Parameters:
    ///   - illumination: `MoonDay.illumination`, `0...1`.
    ///   - phaseAngle: `MoonDay.phaseAngle`; under 180° is waxing.
    init(illumination: Double, phaseAngle: Double) {
        litFraction = min(max(illumination, 0), 1)
        litSide = phaseAngle.wrappedIntoDegreeCircle < Self.fullMoonPhaseAngle ? .right : .left
    }

    // MARK: - Geometry

    /// The terminator's horizontal position as a fraction of the radius,
    /// toward the lit side: `1 − 2k`. 1 at new (on the limb, nothing lit),
    /// 0 at a quarter (a straight line), −1 at full (on the far limb).
    var terminatorOffset: Double {
        1 - 2 * litFraction
    }

    /// The lit region's outline in a unit circle centred on the origin, y
    /// down: the limb from top to bottom, then the terminator back up.
    func litOutline(segments: Int = PhaseGlyphGeometry.defaultSegments) -> [CGPoint] {
        let sign: Double = litSide == .right ? 1 : -1
        var points: [CGPoint] = []
        points.reserveCapacity(2 * (segments + 1))

        // θ runs top (−π/2) to bottom (π/2); cos θ is the half-width there.
        for step in 0...segments {
            let theta = angle(step: step, of: segments)
            points.append(CGPoint(x: sign * cos(theta), y: sin(theta)))
        }
        for step in (0...segments).reversed() {
            let theta = angle(step: step, of: segments)
            points.append(CGPoint(x: sign * terminatorOffset * cos(theta), y: sin(theta)))
        }
        return points
    }

    private func angle(step: Int, of segments: Int) -> Double {
        -Double.pi / 2 + Double.pi * Double(step) / Double(segments)
    }
}
