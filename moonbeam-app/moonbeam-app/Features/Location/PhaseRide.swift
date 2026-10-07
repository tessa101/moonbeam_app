//
//  PhaseRide.swift
//  moonbeam-app
//

import Foundation

/// After a recovery's fix, the loader moon runs on to today's real phase and
/// stops there (LOADER.md §11.2.2, §11.2.3), so it flies into the card already
/// showing what the card shows.
///
/// Worked in the loader's phase space, `0..<1` (0 new, 0.5 full), not its
/// month time: the ride has its own length and easing, and only ever goes
/// forward (new → lit on the right → full → lit on the left). The first ride
/// after install adds a whole lap, so it sweeps every phase at least once.
///
/// It takes over from the running cycle at the cycle's own speed (no ease-in,
/// so no dip at the handover) and eases out to rest: a cubic with that start
/// speed and zero end speed. A start speed too fast to brake within the
/// ride without overshooting (more than 3× the ride's average) shortens the
/// ride instead, so the speed still carries on and it never runs backwards.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct PhaseRide: Equatable {

    // MARK: - Constants

    /// `D = clamp(0.9 + 2.0·T, 1.6, 4.2)` s for `T` laps (§11.2.2).
    static let baseDuration: TimeInterval = 0.9
    static let durationPerLap: TimeInterval = 2.0
    static let durationRange: ClosedRange<TimeInterval> = 1.6...4.2

    /// The moon rests this long at the real phase before it flies
    /// (§11.2.3; was 0.4 s).
    static let restBeat: TimeInterval = 0.6

    /// A cubic ease-out with start slope above this (in units of the average
    /// speed) would pass the target and come back.
    static let maximumStartSlope = 3.0

    // MARK: - State

    let startDate: Date
    /// Where it starts, `0..<1`.
    let fromPhase: Double
    /// Total travel, in laps: `0..<1`, or `1..<2` with the extra lap.
    let laps: Double
    let duration: TimeInterval
    /// The ease's start slope: start speed over average speed, `0...3`.
    let startSlope: Double

    /// - Parameters:
    ///   - fromPhase: where the moon is at `startDate`.
    ///   - target: the real phase, `0..<1`.
    ///   - extraLap: the first ride after install (`hasSeenFirstFindPass`).
    ///   - startSpeed: the cycle's speed at `startDate`, phases per second.
    init(
        from fromPhase: Double,
        to target: Double,
        extraLap: Bool,
        startSpeed: Double = 0,
        startingAt startDate: Date
    ) {
        self.startDate = startDate
        self.fromPhase = Self.wrapped(fromPhase)
        let laps = Self.wrapped(target - fromPhase) + (extraLap ? 1 : 0)
        self.laps = laps
        let speed = max(startSpeed, 0)
        let planned = Self.duration(laps: laps)
        guard laps > 0, speed > 0 else {
            duration = planned
            startSlope = 0
            return
        }
        // Too fast to brake in time: a shorter ride at the same start speed.
        duration = min(planned, Self.maximumStartSlope * laps / speed)
        startSlope = speed * duration / laps
    }

    // MARK: - Timing

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    static func duration(laps: Double) -> TimeInterval {
        min(max(baseDuration + durationPerLap * laps, durationRange.lowerBound), durationRange.upperBound)
    }

    // MARK: - Reading it

    /// The phase at `date`: at the start before it, at the target after, and
    /// between them on the ease-out.
    func phase(at date: Date) -> Double {
        let fraction = min(max(date.timeIntervalSince(startDate) / duration, 0), 1)
        return Self.wrapped(fromPhase + laps * Self.easeOut(fraction, startSlope: startSlope))
    }

    /// The cubic from 0 to 1 with slope `startSlope` at 0 and 0 at 1:
    /// `(c − 2)u³ + (3 − 2c)u² + cu`. Its slope is `(1 − u)(c + (6 − 3c)u)`,
    /// never negative for `c` in `0...3`, so it never runs backwards. `c = 0`
    /// is a smoothstep (from rest); `c = 3` is the fastest start that doesn't
    /// overshoot.
    static func easeOut(_ fraction: Double, startSlope c: Double) -> Double {
        let u = fraction
        return (c - 2) * u * u * u + (3 - 2 * c) * u * u + c * u
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
