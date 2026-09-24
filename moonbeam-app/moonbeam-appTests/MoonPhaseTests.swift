//
//  MoonPhaseTests.swift
//  moonbeam-appTests
//

import Testing
@testable import moonbeam_app

/// Covers the phase-angle → phase-name table in ASTRONOMY.md §3.
///
/// `nonisolated` so these run off the main actor, which is the point of the
/// `nonisolated` annotations on the code under test.
@Suite("MoonPhase from phase angle")
nonisolated struct MoonPhaseTests {

    // MARK: - Table from ASTRONOMY.md §3

    /// Each principal phase owns a ±6° window; crescents and gibbous phases
    /// fill the gaps. Values are picked just inside each boundary.
    @Test("Angle maps to the documented phase", arguments: [
        (0.0, MoonPhase.new),
        (5.9, .new),
        (6.0, .waxingCrescent),
        (45.0, .waxingCrescent),
        (83.9, .waxingCrescent),
        (84.0, .firstQuarter),
        (90.0, .firstQuarter),
        (95.9, .firstQuarter),
        (96.0, .waxingGibbous),
        (139.0, .waxingGibbous),
        (173.9, .waxingGibbous),
        (174.0, .full),
        (180.0, .full),
        (185.9, .full),
        (186.0, .waningGibbous),
        (225.0, .waningGibbous),
        (263.9, .waningGibbous),
        (264.0, .lastQuarter),
        (270.0, .lastQuarter),
        (275.9, .lastQuarter),
        (276.0, .waningCrescent),
        (315.0, .waningCrescent),
        (353.9, .waningCrescent),
        (354.0, .new),
        (359.9, .new)
    ])
    func phaseForAngle(angle: Double, expected: MoonPhase) {
        #expect(MoonPhase(phaseAngle: angle) == expected)
    }

    // MARK: - Wraparound

    /// Angles outside `0..<360` are normalised, so callers never have to.
    @Test("Out-of-range angles wrap into the circle", arguments: [
        (360.0, MoonPhase.new),
        (720.0, .new),
        (370.0, .waxingCrescent),
        (450.0, .firstQuarter),
        (540.0, .full),
        (-10.0, .waningCrescent),
        (-90.0, .lastQuarter),
        (-180.0, .full),
        (-360.0, .new)
    ])
    func phaseWrapsAround(angle: Double, expected: MoonPhase) {
        #expect(MoonPhase(phaseAngle: angle) == expected)
    }

    /// An angle and that angle plus a full turn must agree.
    @Test("A full turn is a no-op", arguments: [0.0, 45.0, 137.5, 212.0, 359.0])
    func fullTurnMatchesOriginal(angle: Double) {
        let fullCircle = 360.0
        #expect(MoonPhase(phaseAngle: angle) == MoonPhase(phaseAngle: angle + fullCircle))
        #expect(MoonPhase(phaseAngle: angle) == MoonPhase(phaseAngle: angle - fullCircle))
    }
}
