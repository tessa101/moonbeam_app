//
//  PhaseCycle.swift
//  moonbeam-app
//

import SwiftUI

/// The launch loader's moon over time (LOADER.md §3, §11.3): a full lunar
/// month every 4.8 s, with a glow that follows how much of the moon is lit.
///
/// Timing and easing are the 5.9.3 handoff's (`design/1.5-loader-polish/
/// MoonLoader.swift`): a 2.2 s sweep new → full, 0.4 s at full, a 2.2 s
/// sweep full → new, each eased in and out so the moon lingers at new and
/// full. The shape is its 4b terminator, which is `PhaseGlyph`'s geometry, so
/// the loader moon lands on the card with no swap.
///
/// Runs forward, as the real month does (Tessa, 2026-10-03): new, lit on the
/// right, full, lit on the left, new.
///
/// `nonisolated`: pure functions of elapsed time, testable without a view.
nonisolated enum PhaseCycle {

    // MARK: - Constants

    /// One month, in seconds.
    static let period: TimeInterval = 4.8

    /// Each half month's sweep (new → full, full → new), and the pause at
    /// full between them: 2.2 + 0.4 + 2.2 = 4.8 s.
    static let sweepDuration: TimeInterval = 2.2
    static let fullHoldDuration: TimeInterval = 0.4

    /// The handoff's sweep easing, `q − a·sin(2πq)/2π`: 0 is linear, 1 comes
    /// to a full stop at each end.
    static let easeAmount = 0.85

    /// The halo follows the lit fraction `k` (§11.3): opacity 0.12 + 0.88k,
    /// scale 0.94 + 0.1k. Faint at new, full strength at full.
    static let glowOpacityRange: ClosedRange<Double> = 0.12...1
    static let glowScaleRange: ClosedRange<Double> = 0.94...1.04

    /// The tight glow around the disc (§11.3): accent at 0.35k.
    static let tightGlowOpacityAtFull = 0.35

    /// Phase angles: 0° new, 180° full (`MoonDay.phaseAngle`).
    private static let fullMoonPhaseAngle = 180.0

    /// The hold phase (LOADER.md §10.2): the onboarding moon, lit with a
    /// thin dark sliver on the left, a waxing gibbous just short of full
    /// (Tessa, 2026-10-06: mirrored from the waning one, so the month grows
    /// toward full from rest and "Aha" reaches full quickly). The loader
    /// appears on it, starts its month from it, and stops on it when
    /// searching stops. `OnboardingMoon`'s lit fraction (a test keeps the
    /// two in step).
    static let holdLitFraction = 0.83

    /// Halvings in the lit-fraction searches: far below a frame.
    private static let bisectionSteps = 40

    /// How far into the month the hold phase falls. Solved rather than
    /// written down, because the eased angle has no simple inverse.
    static let holdElapsed = elapsed(forWaxingLitFraction: holdLitFraction)

    /// Full moon, where "Aha" runs to (§10.4): the start of the pause at
    /// full, the first moment it's fully lit.
    static let fullElapsed = sweepDuration

    /// Reduce Motion (§10.6): the glyph holds still at the hold phase.
    static let stillGeometry = geometry(at: holdElapsed)

    // MARK: - Over time

    /// The moment in the waxing half when the moon is `fraction` lit. The lit
    /// fraction only grows there, so a bisection finds it.
    static func elapsed(forWaxingLitFraction fraction: Double) -> TimeInterval {
        bisect(from: 0, to: sweepDuration) { geometry(at: $0).litFraction < fraction }
    }

    /// The moment in the waning half when the moon is `fraction` lit. The lit
    /// fraction only shrinks there.
    static func elapsed(forWaningLitFraction fraction: Double) -> TimeInterval {
        bisect(from: sweepDuration + fullHoldDuration, to: period) { geometry(at: $0).litFraction > fraction }
    }

    /// The boundary in `low...high` where `isBefore` turns false.
    private static func bisect(
        from low: TimeInterval,
        to high: TimeInterval,
        isBefore: (TimeInterval) -> Bool
    ) -> TimeInterval {
        var low = low
        var high = high
        for _ in 0..<bisectionSteps {
            let middle = (low + high) / 2
            if isBefore(middle) {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }

    /// Month time folded into one month, `0..<period`.
    static func wrapped(_ elapsed: TimeInterval) -> TimeInterval {
        progress(at: elapsed) * period
    }

    /// How far through the month, `0..<1`.
    static func progress(at elapsed: TimeInterval) -> Double {
        let fraction = (elapsed / period).truncatingRemainder(dividingBy: 1)
        return fraction < 0 ? fraction + 1 : fraction
    }

    /// The phase angle, `0..<360`: an eased sweep to full, the pause, then an
    /// eased sweep back to new.
    static func phaseAngle(at elapsed: TimeInterval) -> Double {
        let time = wrapped(elapsed)
        if time < sweepDuration {
            return fullMoonPhaseAngle * ease(time / sweepDuration)
        }
        if time < sweepDuration + fullHoldDuration {
            return fullMoonPhaseAngle
        }
        let within = (time - sweepDuration - fullHoldDuration) / sweepDuration
        return fullMoonPhaseAngle * (1 + ease(within))
    }

    /// The handoff's sweep easing, `0...1` onto `0...1`.
    static func ease(_ fraction: Double) -> Double {
        fraction - easeAmount * sin(2 * .pi * fraction) / (2 * .pi)
    }

    /// The glyph at that moment. The lit fraction follows the angle as the
    /// real moon's does, `(1 − cos φ) / 2`, so the shape is always a true
    /// phase.
    static func geometry(at elapsed: TimeInterval) -> PhaseGlyphGeometry {
        geometry(forPhase: phase(at: elapsed))
    }

    /// The phase at that moment, `0..<1` (0 new, 0.5 full): where the "Aha"
    /// ride starts from (`PhaseRide`).
    static func phase(at elapsed: TimeInterval) -> Double {
        phaseAngle(at: elapsed) / (2 * fullMoonPhaseAngle)
    }

    /// The glyph for a phase `0..<1`, the 4b shape: lit fraction
    /// `(1 − cos 2πf) / 2`, lit on the right before full.
    static func geometry(forPhase phase: Double) -> PhaseGlyphGeometry {
        let angle = 2 * fullMoonPhaseAngle * phase
        let illumination = (1 - cos(angle * .pi / fullMoonPhaseAngle)) / 2
        return PhaseGlyphGeometry(illumination: illumination, phaseAngle: angle)
    }

    /// The glow's strength, `0...1`: the lit fraction, so it's dim at new,
    /// brightest at full, and never runs on a clock of its own (§11.3).
    static func glowLevel(at elapsed: TimeInterval) -> Double {
        geometry(at: elapsed).litFraction
    }
}
