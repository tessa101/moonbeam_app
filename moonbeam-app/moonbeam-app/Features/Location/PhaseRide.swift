//
//  PhaseRide.swift
//  moonbeam-app
//

import Foundation

/// After "Aha", the loader moon runs forward to today's real phase and stops
/// there (LOADER.md §11.2.2), so it flies into the card already showing what
/// the card shows.
///
/// Worked in the loader's phase space, `0..<1` (0 new, 0.5 full), not its
/// month time: the ride has its own length and easing, and only ever goes
/// forward (new → lit on the right → full → lit on the left). The first ride
/// after install adds a whole lap, so it sweeps every phase at least once.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct PhaseRide: Equatable {

    // MARK: - Constants

    /// `D = clamp(0.9 + 2.0·T, 1.6, 4.2)` s for `T` laps (§11.2.2).
    static let baseDuration: TimeInterval = 0.9
    static let durationPerLap: TimeInterval = 2.0
    static let durationRange: ClosedRange<TimeInterval> = 1.6...4.2

    /// The moon rests this long at the real phase before it flies.
    static let restBeat: TimeInterval = 0.4

    // MARK: - State

    let startDate: Date
    /// Where it starts, `0..<1`.
    let fromPhase: Double
    /// Total travel, in laps: `0..<1`, or `1..<2` with the extra lap.
    let laps: Double

    /// - Parameters:
    ///   - fromPhase: where the moon is at `startDate`.
    ///   - target: the real phase, `0..<1`.
    ///   - extraLap: the first ride after install (`hasSeenFirstFindPass`).
    init(from fromPhase: Double, to target: Double, extraLap: Bool, startingAt startDate: Date) {
        self.startDate = startDate
        self.fromPhase = Self.wrapped(fromPhase)
        laps = Self.wrapped(target - fromPhase) + (extraLap ? 1 : 0)
    }

    // MARK: - Timing

    var duration: TimeInterval {
        Self.duration(laps: laps)
    }

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    static func duration(laps: Double) -> TimeInterval {
        min(max(baseDuration + durationPerLap * laps, durationRange.lowerBound), durationRange.upperBound)
    }

    // MARK: - Reading it

    /// The phase at `date`: at the start before it, at the target after, and
    /// between them on the handoff's in-out ease (`PhaseCycle.ease`).
    func phase(at date: Date) -> Double {
        let fraction = min(max(date.timeIntervalSince(startDate) / duration, 0), 1)
        return Self.wrapped(fromPhase + laps * PhaseCycle.ease(fraction))
    }

    func geometry(at date: Date) -> PhaseGlyphGeometry {
        PhaseCycle.geometry(forPhase: phase(at: date))
    }

    // MARK: - The real phase

    /// The phase, `0..<1`, whose 4b shape is `glyph`: `acos(1 − 2k) / 2π`
    /// while waxing (lit on the right), one minus that while waning.
    static func phase(of glyph: PhaseGlyphGeometry) -> Double {
        let waxing = acos(1 - 2 * glyph.litFraction) / (2 * .pi)
        return glyph.litSide == .right ? waxing : wrapped(1 - waxing)
    }

    /// Folded into `0..<1`.
    private static func wrapped(_ phase: Double) -> Double {
        let fraction = phase.truncatingRemainder(dividingBy: 1)
        return fraction < 0 ? fraction + 1 : fraction
    }
}
