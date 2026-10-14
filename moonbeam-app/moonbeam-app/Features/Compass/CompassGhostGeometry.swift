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

    /// Rise to set the way the moon crosses the sky (§8), as points along
    /// the ring; empty unless the day has both.
    let arcPoints: [CGPoint]

    /// The live moon if it's up; otherwise the arc's midpoint. `nil` with
    /// neither, and always on a day with no rise and no set (§8): a marker
    /// with nothing to anchor it reads as a stray dot.
    let moonMarker: CGPoint?

    /// - Parameters:
    ///   - rise, set: the selected day's azimuths, if it has them.
    ///   - moonAzimuth: the live moon's, only while it's up.
    ///   - crossesSouth: the place is at or north of the equator, so the
    ///     moon crosses the southern sky: rise to set clockwise on the ring.
    ///     South of it, via the north: anticlockwise.
    init(rise: Double?, set: Double?, moonAzimuth: Double?, crossesSouth: Bool) {
        riseDot = rise.map(Self.point(atAzimuth:))
        setDot = set.map(Self.point(atAzimuth:))
        var midpoint: CGPoint?
        if let rise, let set {
            let sweep = crossesSouth
                ? Self.clockwiseSweep(from: rise, to: set)
                : -Self.clockwiseSweep(from: set, to: rise)
            let steps = max(Int((abs(sweep) / Self.arcStepDegrees).rounded(.up)), 1)
            arcPoints = (0...steps).map { step in
                Self.point(atAzimuth: rise + sweep * Double(step) / Double(steps))
            }
            midpoint = Self.point(atAzimuth: rise + sweep / 2)
        } else {
            arcPoints = []
        }
        moonMarker = rise == nil && set == nil
            ? nil
            : moonAzimuth.map(Self.point(atAzimuth:)) ?? midpoint
    }

    /// Nothing to draw but the ring, N and tick.
    static let empty = CompassGhostGeometry(rise: nil, set: nil, moonAzimuth: nil, crossesSouth: true)

    /// At or north of the equator the moon crosses the southern sky.
    static func crossesSouth(latitude: Double) -> Bool {
        latitude >= 0
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
