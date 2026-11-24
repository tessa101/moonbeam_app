//
//  BearingLineTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The map's bearing line maths (MAP.md §3.4, §7). Known points on the
/// sphere, the antimeridian, and a round trip: the line's end must sit at
/// the given distance and the given starting bearing from its start, measured
/// with independent formulas.
@Suite("BearingLine")
nonisolated struct BearingLineTests {

    /// About 0.1 m on the ground, far finer than the map can show.
    private static let degreeTolerance = 1e-6
    /// Metres.
    private static let distanceTolerance = 0.01
    /// Degrees.
    private static let bearingTolerance = 1e-6

    /// One degree of arc on the sphere `BearingLine` uses.
    private static let oneDegree = BearingLine.earthRadius * .pi / 180

    private typealias Coordinate = BearingLine.Coordinate

    // MARK: - Known points

    @Test("Due east along the equator for one degree of arc")
    func eastAlongEquator() {
        let end = BearingLine.destination(from: Coordinate(latitude: 0, longitude: 0), bearing: 90, distance: Self.oneDegree)
        #expect(abs(end.latitude) < Self.degreeTolerance)
        #expect(abs(end.longitude - 1) < Self.degreeTolerance)
    }

    @Test("Due north from the equator for one degree of arc")
    func northFromEquator() {
        let end = BearingLine.destination(from: Coordinate(latitude: 0, longitude: 10), bearing: 0, distance: Self.oneDegree)
        #expect(abs(end.latitude - 1) < Self.degreeTolerance)
        #expect(abs(end.longitude - 10) < Self.degreeTolerance)
    }

    @Test("Zero length ends at the start")
    func zeroLength() {
        let start = Coordinate(latitude: 34.0, longitude: -118.43)
        let line = BearingLine(start: start, bearing: 105, length: 0)
        #expect(abs(line.end.latitude - start.latitude) < Self.degreeTolerance)
        #expect(abs(line.end.longitude - start.longitude) < Self.degreeTolerance)
    }

    // MARK: - Antimeridian

    /// Fiji-ish: a line east across 180° ends in the western hemisphere.
    @Test("Crossing the antimeridian wraps the longitude")
    func crossesAntimeridian() {
        let start = Coordinate(latitude: 0, longitude: 179.5)
        let end = BearingLine.destination(from: start, bearing: 90, distance: Self.oneDegree)
        #expect(abs(end.longitude - (-179.5)) < Self.degreeTolerance)
    }

    @Test("Longitudes wrap into −180..<180", arguments: [
        (180.0, -180.0), (180.5, -179.5), (-180.5, 179.5), (540.0, -180.0), (0.0, 0.0), (-179.0, -179.0)
    ])
    func normalizesLongitude(input: Double, expected: Double) {
        #expect(abs(BearingLine.normalizedLongitude(input) - expected) < Self.degreeTolerance)
    }

    // MARK: - Round trip

    /// Mar Vista's 2026-09-23 rise and set (ASTRONOMY.md §5), Irvine's
    /// 2026-11-24 rise and set, a southern-hemisphere city and a high latitude.
    @Test("The end lies at the line's length and bearing from the start", arguments: [
        (34.00, -118.43, 105.0),
        (34.00, -118.43, 252.0),
        (33.68, -117.83, 58.0),
        (33.68, -117.83, 301.0),
        (-33.87, 151.21, 120.0),
        (64.15, -21.94, 350.0)
    ])
    func roundTrip(latitude: Double, longitude: Double, bearing: Double) {
        let start = Coordinate(latitude: latitude, longitude: longitude)
        let line = BearingLine(start: start, bearing: bearing)
        let end = line.end

        #expect(abs(Self.haversineDistance(start, end) - BearingLine.defaultLength) < Self.distanceTolerance)
        #expect(abs(Self.angleBetween(Self.initialBearing(start, end), bearing)) < Self.bearingTolerance)
    }

    @Test("Default length is 30 km")
    func defaultLength() {
        #expect(BearingLine.defaultLength == 30_000)
    }

    // MARK: - Independent formulas

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func haversineDistance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let dLat = radians(b.latitude - a.latitude)
        let dLon = radians(b.longitude - a.longitude)
        let h = pow(sin(dLat / 2), 2) + cos(radians(a.latitude)) * cos(radians(b.latitude)) * pow(sin(dLon / 2), 2)
        return 2 * BearingLine.earthRadius * asin(min(1, sqrt(h)))
    }

    private static func initialBearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let dλ = radians(b.longitude - a.longitude)
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        return atan2(y, x) * 180 / .pi
    }

    /// The signed difference between two bearings, in −180..<180.
    private static func angleBetween(_ a: Double, _ b: Double) -> Double {
        let difference = (a - b).truncatingRemainder(dividingBy: 360)
        if difference >= 180 { return difference - 360 }
        if difference < -180 { return difference + 360 }
        return difference
    }
}
