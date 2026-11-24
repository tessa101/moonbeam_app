//
//  BearingLine.swift
//  moonbeam-app
//

import Foundation

/// A straight line on the ground from where you'd stand toward a moonrise or
/// moonset (MAP.md §3.4): start, bearing, length, and where it ends.
///
/// Within a city the bearing barely changes as you move, so the map just
/// redraws this line from wherever the pin is; nothing is recalculated
/// astronomically (MAP.md §2).
///
/// The end is found along a great circle, because an azimuth is the starting
/// direction of one. A sphere is plenty: over 30 km the difference from the
/// ellipsoid is metres, far below what the map can show.
///
/// Coordinates are plain degrees rather than `CLLocationCoordinate2D` so the
/// maths stays free of MapKit and easy to test.
///
/// `nonisolated`: an inert value.
nonisolated struct BearingLine: Equatable, Sendable {

    /// A point in degrees: latitude −90…90, longitude −180..<180.
    nonisolated struct Coordinate: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    /// The map's line length (MAP.md §3.4, Tessa 2026-11-24): long enough to
    /// reach a ridge or the far side of a bay, short enough to stay local.
    static let defaultLength: Double = 30_000

    /// Mean Earth radius in metres (IUGG).
    static let earthRadius: Double = 6_371_008.8

    let start: Coordinate
    /// Degrees clockwise from true north.
    let bearing: Double
    /// Metres along the ground.
    let length: Double

    init(start: Coordinate, bearing: Double, length: Double = Self.defaultLength) {
        self.start = start
        self.bearing = bearing
        self.length = length
    }

    /// Where the line ends.
    var end: Coordinate {
        Self.destination(from: start, bearing: bearing, distance: length)
    }

    // MARK: - Great-circle maths

    private static let fullTurn = 360.0
    private static let halfTurn = 180.0

    /// The point `distance` metres from `start`, setting off at `bearing`
    /// degrees from true north along a great circle.
    static func destination(from start: Coordinate, bearing: Double, distance: Double) -> Coordinate {
        let angularDistance = distance / earthRadius
        let φ1 = radians(start.latitude)
        let λ1 = radians(start.longitude)
        let θ = radians(bearing)

        let sinφ2 = sin(φ1) * cos(angularDistance) + cos(φ1) * sin(angularDistance) * cos(θ)
        let φ2 = asin(min(max(sinφ2, -1), 1))
        let λ2 = λ1 + atan2(
            sin(θ) * sin(angularDistance) * cos(φ1),
            cos(angularDistance) - sin(φ1) * sin(φ2)
        )

        return Coordinate(latitude: degrees(φ2), longitude: normalizedLongitude(degrees(λ2)))
    }

    /// Wraps a longitude into −180..<180, so a line across the antimeridian
    /// ends at −179.5 rather than 180.5.
    static func normalizedLongitude(_ longitude: Double) -> Double {
        let wrapped = (longitude + halfTurn).truncatingRemainder(dividingBy: fullTurn)
        return (wrapped < 0 ? wrapped + fullTurn : wrapped) - halfTurn
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / halfTurn }
    private static func degrees(_ radians: Double) -> Double { radians * halfTurn / .pi }
}
