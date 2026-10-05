//
//  PhaseCycle.swift
//  moonbeam-app
//

import SwiftUI

/// The launch loader's moon over time (LOADER.md §3): a full lunar month
/// every 4.8 s, as in the design's 1a mock, with a glow that breathes on
/// the same loop and is brightest at full.
///
/// Runs forward, as the real month does (Tessa, 2026-10-03): new, lit on the
/// right, full, lit on the left, new. The mock's recording plays it in
/// reverse; only its timing and glow are followed.
///
/// `nonisolated`: pure functions of elapsed time, testable without a view.
nonisolated enum PhaseCycle {

    // MARK: - Constants

    /// One month, in seconds.
    static let period: TimeInterval = 4.8

    /// The mock eases each half month (new → full, full → new) with CSS
    /// `cubic-bezier(.45, 0, .55, 1)`, so the moon lingers at new and full.
    static let phaseCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.45, y: 0),
        endControlPoint: UnitPoint(x: 0.55, y: 1)
    )

    /// The glow's CSS `ease-in-out`, dim at new and brightest at full.
    static let glowCurve = UnitCurve.easeInOut

    /// The mock's `ms-breathe`: opacity .45 → 1, scale .92 → 1.06.
    static let glowOpacityRange: ClosedRange<Double> = 0.45...1
    static let glowScaleRange: ClosedRange<Double> = 0.92...1.06

    /// Phase angles: 0° new, 180° full (`MoonDay.phaseAngle`).
    private static let fullMoonPhaseAngle = 180.0

    /// Reduce Motion (§3): the glyph holds still at full.
    static let stillGeometry = PhaseGlyphGeometry(illumination: 1, phaseAngle: fullMoonPhaseAngle)

    // MARK: - Over time

    /// How far through the month, `0..<1`.
    static func progress(at elapsed: TimeInterval) -> Double {
        let fraction = (elapsed / period).truncatingRemainder(dividingBy: 1)
        return fraction < 0 ? fraction + 1 : fraction
    }

    /// The phase angle, `0..<360`, eased within each half month.
    static func phaseAngle(at elapsed: TimeInterval) -> Double {
        let (half, within) = halfMonth(at: elapsed)
        return fullMoonPhaseAngle * (Double(half) + phaseCurve.value(at: within))
    }

    /// The glyph at that moment. The lit fraction follows the angle as the
    /// real moon's does, `(1 − cos φ) / 2`, so the shape is always a true
    /// phase.
    static func geometry(at elapsed: TimeInterval) -> PhaseGlyphGeometry {
        let angle = phaseAngle(at: elapsed)
        let illumination = (1 - cos(angle * .pi / fullMoonPhaseAngle)) / 2
        return PhaseGlyphGeometry(illumination: illumination, phaseAngle: angle)
    }

    /// The glow's strength, `0...1`: 0 at new, 1 at full.
    static func glowLevel(at elapsed: TimeInterval) -> Double {
        let (half, within) = halfMonth(at: elapsed)
        let rising = glowCurve.value(at: within)
        return half == 0 ? rising : 1 - rising
    }

    /// Which half of the month (0 waxing, 1 waning) and how far through it.
    private static func halfMonth(at elapsed: TimeInterval) -> (half: Int, within: Double) {
        let doubled = progress(at: elapsed) * 2
        let half = doubled < 1 ? 0 : 1
        return (half, doubled - Double(half))
    }
}
