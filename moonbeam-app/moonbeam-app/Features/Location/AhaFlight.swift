//
//  AhaFlight.swift
//  moonbeam-app
//

import SwiftUI

/// The loader moon's flight into the card's phase slot after "Aha"
/// (LOADER.md §10.4, §11.2.5; the handoff's "Search → Aha → city"): over
/// 0.85 s on `cubic-bezier(.3, .3, .25, 1)` it moves and shrinks into the slot's real
/// frame, keeps the real phase it rode to (§11.2.2), and its glow drops to
/// 0.35.
///
/// `nonisolated`: pure functions of time, testable without a view.
nonisolated enum AhaFlight {

    // MARK: - Constants

    /// §11.2.5: an ease-out that moves from the first frame (the handoff's
    /// `cubic-bezier(.65, 0, .25, 1)` started from rest, and with the ride
    /// easing to rest too the moon sat nearly still at the landing).
    static let curve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.3, y: 0.3),
        endControlPoint: UnitPoint(x: 0.25, y: 1)
    )

    /// The glow's opacity on landing.
    static let landingGlowOpacity = 0.35

    /// Phase angles for a lit side: any waxing or waning angle will do, as
    /// `PhaseGlyphGeometry` only keeps the side.
    private static let waxingPhaseAngle = 90.0
    private static let waningPhaseAngle = 270.0

    // MARK: - Over time

    /// How far along, eased, `0...1`.
    static func progress(since start: Date, at date: Date) -> Double {
        let fraction = date.timeIntervalSince(start) / LocationLoader.flightDuration
        return curve.value(at: min(max(fraction, 0), 1))
    }

    /// The moon from `start` (where the ride is at that moment) to
    /// `landing` (the card's glyph), lit on the landing's side. The ride
    /// finishes settling 0.25 s into the flight (§11.2.5), after which the
    /// two are the same.
    static func geometry(
        from start: PhaseGlyphGeometry,
        landingOn landing: PhaseGlyphGeometry,
        progress: Double
    ) -> PhaseGlyphGeometry {
        PhaseGlyphGeometry(
            illumination: interpolate(start.litFraction, landing.litFraction, progress),
            phaseAngle: landing.litSide == .right ? waxingPhaseAngle : waningPhaseAngle
        )
    }

    /// The moon's frame between where it was and the slot.
    static func frame(from start: CGRect, to end: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(progress)
        return CGRect(
            x: start.minX + (end.minX - start.minX) * t,
            y: start.minY + (end.minY - start.minY) * t,
            width: start.width + (end.width - start.width) * t,
            height: start.height + (end.height - start.height) * t
        )
    }

    static func interpolate(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from + (to - from) * progress
    }
}

// MARK: - The card's phase slot

/// Where the card's phase glyph sits, for the flight to land on.
struct CardPhaseSlotKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension EnvironmentValues {
    /// The card's phase glyph is hidden while the loader moon flies into
    /// its slot, so there's one moon on screen.
    @Entry var hidesCardPhaseGlyph = false
    /// 5.10a.4: the card landing over its skeleton. The card's frame is
    /// already there (the skeleton's), so only its content fades and rises.
    @Entry var risesCardContent = false

    /// The screen arrives under the flying "Aha" moon: its blocks fade in
    /// together, after a short delay, with no rise (§10.4).
    @Entry var contentArrivesAfterAha = false
}
