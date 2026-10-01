//
//  FakeMoonService.swift
//  moonbeam-app
//

import Foundation

/// Scriptable `MoonService` for tests and SwiftUI previews.
///
/// Records every date it's asked for, so a test can check which day reached
/// the service (DATE.md §6: "`MoonService` called with Sep 27 in the place's
/// time zone"). Returns the same scripted rise, set, phase and position for
/// any place and moment. Use `AstronomyEngineMoonService` where the values
/// matter.
///
/// `nonisolated` to match the protocol. Not `Sendable`: it's mutable and
/// meant to be used from one place, the main actor in the tests.
nonisolated final class FakeMoonService: MoonService {

    // MARK: - Defaults

    /// A full moon: halfway round the cycle, fully lit.
    static let fullMoonPhaseAngle = 180.0
    static let fullyLit = 1.0

    // MARK: - Script

    var rise: MoonEvent?
    var set: MoonEvent?
    var phaseAngle: Double
    var illumination: Double

    /// Returned by `moonPosition(for:at:)`. Change it between calls to have
    /// the moon rise or set while the compass is on screen.
    var position: MoonPosition

    /// Returned by `moonPass(for:containing:)` for any moment. `nil` by
    /// default: no arc.
    var pass: MoonPass?

    // MARK: - Record

    /// Every `date` passed to `moonDay(for:on:)`, oldest first.
    private(set) var requestedDates: [Date] = []

    /// Every `date` passed to `moonPosition(for:at:)`, oldest first.
    private(set) var requestedPositionDates: [Date] = []

    /// Every `date` passed to `moonPass(for:containing:)`, oldest first.
    private(set) var requestedPassDates: [Date] = []

    // MARK: - Init

    init(
        rise: MoonEvent? = nil,
        set: MoonEvent? = nil,
        phaseAngle: Double = FakeMoonService.fullMoonPhaseAngle,
        illumination: Double = FakeMoonService.fullyLit,
        position: MoonPosition = MoonPosition(azimuth: 0, isUp: false),
        pass: MoonPass? = nil
    ) {
        self.rise = rise
        self.set = set
        self.phaseAngle = phaseAngle
        self.illumination = illumination
        self.position = position
        self.pass = pass
    }

    // MARK: - MoonService

    func moonDay(for place: Place, on date: Date) -> MoonDay {
        requestedDates.append(date)
        return MoonDay(
            place: place,
            rise: rise,
            set: set,
            phase: MoonPhase(phaseAngle: phaseAngle),
            phaseAngle: phaseAngle,
            illumination: illumination
        )
    }

    func moonPosition(for place: Place, at date: Date) -> MoonPosition {
        requestedPositionDates.append(date)
        return position
    }

    func moonPass(for place: Place, containing date: Date) -> MoonPass? {
        requestedPassDates.append(date)
        return pass
    }
}
