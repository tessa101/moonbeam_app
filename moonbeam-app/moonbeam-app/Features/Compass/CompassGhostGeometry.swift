//
//  CompassGhostGeometry.swift
//  moonbeam-app
//

import CoreGraphics

/// Where the location-off prompt's plain ring puts things (LOCATION-OFF-FLOW.md
/// §2, design 1.9 "S1: Prompt"), in the handoff's 260-unit space: the rise and
/// set dots, the arc between them and the moon marker, from the day's real
/// azimuths. Pure numbers, so the placement is testable without a view.
///
/// `nonisolated`: an inert value, like `CompassArc`.
nonisolated struct CompassGhostGeometry: Equatable, Sendable {

    // MARK: - Constants (design 1.9)

    /// The drawing space, square.
    static let space: CGFloat = 260
    static let centre = CGPoint(x: space / 2, y: space / 2)
    static let ringRadius: CGFloat = 104

    /// The arc is drawn as straight steps this many degrees long.
    static let arcStepDegrees = 1.0

    private static let fullTurnDegrees = 360.0

    // MARK: - Layout

    /// Moonrise's dot, or `nil` with no moonrise.
    let riseDot: CGPoint?

    /// Moonset's dot, or `nil` with no moonset.
    let setDot: CGPoint?

    /// Rise to set, clockwise, as points along the ring; empty unless the
    /// day has both.
    let arcPoints: [CGPoint]

    /// The live moon if it's up; otherwise the arc's midpoint; `nil` with
    /// neither.
    let moonMarker: CGPoint?

    /// - Parameters:
    ///   - rise, set: the selected day's azimuths, if it has them.
    ///   - moonAzimuth: the live moon's, only while it's up.
    init(rise: Double?, set: Double?, moonAzimuth: Double?) {
        riseDot = rise.map(Self.point(atAzimuth:))
        setDot = set.map(Self.point(atAzimuth:))
        var midpoint: CGPoint?
        if let rise, let set {
            let sweep = Self.clockwiseSweep(from: rise, to: set)
            let steps = max(Int((sweep / Self.arcStepDegrees).rounded(.up)), 1)
            arcPoints = (0...steps).map { step in
                Self.point(atAzimuth: rise + sweep * Double(step) / Double(steps))
            }
            midpoint = Self.point(atAzimuth: rise + sweep / 2)
        } else {
            arcPoints = []
        }
        moonMarker = moonAzimuth.map(Self.point(atAzimuth:)) ?? midpoint
    }

    // MARK: - Math

    /// On the ring at `azimuth` (0 is north, at the top, clockwise):
    /// (130 + 104 sin a, 130 − 104 cos a).
    static func point(atAzimuth azimuth: Double) -> CGPoint {
        let radians = azimuth * .pi / 180
        return CGPoint(
            x: centre.x + ringRadius * CGFloat(sin(radians)),
            y: centre.y - ringRadius * CGFloat(cos(radians))
        )
    }

    /// Degrees from `start` to `end` going clockwise, in 0..<360.
    static func clockwiseSweep(from start: Double, to end: Double) -> Double {
        let sweep = (end - start).truncatingRemainder(dividingBy: fullTurnDegrees)
        return sweep < 0 ? sweep + fullTurnDegrees : sweep
    }
}
