//
//  MoonMotion.swift
//  moonbeam-app
//

import Foundation

/// Where the loader's moon is in its month at any moment (LOADER.md §10.2),
/// as a closed form of time rather than a frame-by-frame clock, so the view
/// reads it from a `TimelineView` and the view model can say exactly when it
/// will freeze.
///
/// One leg of motion: from `anchorElapsed` at `anchorDate`, moving forward at
/// `rate` months-per-month (1 the normal 4.8 s month, 2.6 the run-out), and,
/// with a `target`, stopping there. The stop is eased (§11.3): over the last
/// 0.4 s the run-out slows steadily to rest rather than freezing at speed. It never runs backwards and never stops
/// mid-cycle: a target is always reached going forward, a full month round
/// if need be. Before `anchorDate` it holds still, which is how the entrance
/// waits 840 ms at the hold phase before the cycle starts.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct MoonMotion: Equatable {

    // MARK: - Constants

    /// §10.2: the run-out to the hold phase (or to full, for "Aha") goes at
    /// 2.6× the normal speed.
    static let runOutRate = 2.6

    /// §11.3: the run-out's last stretch decelerates to rest over this long
    /// (shorter when the whole run-out is too short to fit it).
    static let stopEaseDuration: TimeInterval = 0.4

    /// The entrance (§10.2): the moon waits at the hold phase, then the
    /// cycle starts 840 ms after it appeared.
    static let cycleStartDelay: TimeInterval = 0.84

    // MARK: - State

    /// Month time (`PhaseCycle`'s elapsed) at `anchorDate`.
    let anchorElapsed: TimeInterval
    let anchorDate: Date
    /// 0 holds still.
    let rate: Double
    /// Month time to stop at, `0..<period`; `nil` runs on.
    let target: TimeInterval?

    // MARK: - Making one

    /// Still at `elapsed`.
    static func held(at elapsed: TimeInterval, since date: Date) -> MoonMotion {
        MoonMotion(anchorElapsed: elapsed, anchorDate: date, rate: 0, target: nil)
    }

    /// The entrance (§10.2): at the hold phase from `date`, and running
    /// forward from it 840 ms later.
    static func entrance(at date: Date) -> MoonMotion {
        MoonMotion(
            anchorElapsed: PhaseCycle.holdElapsed,
            anchorDate: date.addingTimeInterval(cycleStartDelay),
            rate: 1,
            target: nil
        )
    }

    /// Runs on at the normal speed from wherever it is at `date`.
    func running(from date: Date) -> MoonMotion {
        MoonMotion(anchorElapsed: elapsed(at: date), anchorDate: date, rate: 1, target: nil)
    }

    /// Runs forward at 2.6× from wherever it is at `date` until it reaches
    /// `target`, easing to rest there (§10.2 "Stopping", §11.3).
    func stopping(at target: TimeInterval, from date: Date) -> MoonMotion {
        MoonMotion(
            anchorElapsed: elapsed(at: date),
            anchorDate: date,
            rate: Self.runOutRate,
            target: PhaseCycle.wrapped(target)
        )
    }

    // MARK: - Reading it

    /// Month time at `date`, `0..<period`.
    func elapsed(at date: Date) -> TimeInterval {
        let start = PhaseCycle.wrapped(anchorElapsed)
        let seconds = max(0, date.timeIntervalSince(anchorDate))
        guard let distance = distanceToTarget else {
            return PhaseCycle.wrapped(start + rate * seconds)
        }
        return PhaseCycle.wrapped(start + Self.travelled(distance: distance, rate: rate, after: seconds))
    }

    /// When it reaches its target and freezes; `nil` if it runs on, or holds
    /// still with no target.
    var settleDate: Date? {
        guard let distance = distanceToTarget, rate > 0 else { return nil }
        return anchorDate.addingTimeInterval(Self.runOutDuration(distance: distance, rate: rate))
    }

    /// Still waiting to move at `date`: the entrance's 840 ms before the
    /// cycle starts.
    func isWaitingToStart(at date: Date) -> Bool {
        rate > 0 && date < anchorDate
    }

    /// How long from `date` until it freezes: zero once frozen.
    func timeToSettle(from date: Date) -> TimeInterval {
        guard let settleDate else { return 0 }
        return max(0, settleDate.timeIntervalSince(date))
    }

    // MARK: - The eased stop

    /// How long a stop `distance` ahead takes at `rate`: at speed, then a
    /// steady slowdown to rest, which covers half the ground it would at
    /// speed, so it adds half the slowdown's length.
    static func runOutDuration(distance: TimeInterval, rate: Double = runOutRate) -> TimeInterval {
        guard distance > 0, rate > 0 else { return 0 }
        let slowdown = slowdownDuration(distance: distance, rate: rate)
        return distance / rate + slowdown / 2
    }

    /// The slowdown's length: `stopEaseDuration`, or less when the stop is
    /// so near that the whole distance is the slowdown.
    private static func slowdownDuration(distance: TimeInterval, rate: Double) -> TimeInterval {
        min(stopEaseDuration, 2 * distance / rate)
    }

    /// Month time covered `seconds` into a stop `distance` ahead: constant
    /// speed, then speed falling linearly to zero (a quadratic ease-out), so
    /// the moon arrives with no jolt.
    private static func travelled(distance: TimeInterval, rate: Double, after seconds: TimeInterval) -> TimeInterval {
        guard rate > 0, distance > 0 else { return 0 }
        let slowdown = slowdownDuration(distance: distance, rate: rate)
        let atSpeed = runOutDuration(distance: distance, rate: rate) - slowdown
        if seconds <= atSpeed { return rate * seconds }
        let into = seconds - atSpeed
        guard into < slowdown else { return distance }
        return rate * atSpeed + rate * (into - into * into / (2 * slowdown))
    }

    /// Forward month time from the anchor to the target, `0..<period`.
    /// A target a hair behind (rounding, after a freeze) counts as reached,
    /// not a whole month away.
    private var distanceToTarget: TimeInterval? {
        guard let target else { return nil }
        let distance = PhaseCycle.wrapped(target - anchorElapsed)
        return PhaseCycle.period - distance < Self.reachedTolerance ? 0 : distance
    }

    /// Far below a frame.
    private static let reachedTolerance: TimeInterval = 1e-9
}
