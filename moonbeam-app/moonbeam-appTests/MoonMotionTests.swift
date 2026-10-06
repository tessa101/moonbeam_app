//
//  MoonMotionTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The loader moon's motion and glow (LOADER.md §10.2, §10.4).
@Suite("Moon motion and glow")
struct MoonMotionTests {

    private static let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private static let tolerance = 1e-9

    private static func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    // MARK: - Running and stopping

    @Test("Running moves forward at the normal speed and loops every 4.8 s")
    func runs() {
        let motion = MoonMotion.held(at: 1, since: Self.t0).running(from: Self.t0)
        #expect(abs(motion.elapsed(at: Self.at(0.5)) - 1.5) < Self.tolerance)
        #expect(abs(motion.elapsed(at: Self.at(PhaseCycle.period)) - 1) < Self.tolerance)
        #expect(motion.settleDate == nil)
    }

    @Test("Stopping runs forward at 2.6× to the hold phase, then freezes there")
    func stopsAtHold() throws {
        let running = MoonMotion.held(at: 1, since: Self.t0).running(from: Self.t0)
        let stopping = running.stopping(at: PhaseCycle.holdElapsed, from: Self.at(1))
        // At 1 s the moon is at 2 s into the month, past the hold phase, so
        // it goes round.
        let distance = PhaseCycle.wrapped(PhaseCycle.holdElapsed - 2)
        let settle = try #require(stopping.settleDate)
        #expect(abs(settle.timeIntervalSince(Self.at(1)) - distance / MoonMotion.runOutRate) < Self.tolerance)
        #expect(abs(stopping.elapsed(at: Self.at(1.1)) - (2 + 0.1 * MoonMotion.runOutRate)) < Self.tolerance)
        #expect(abs(stopping.elapsed(at: settle) - PhaseCycle.holdElapsed) < Self.tolerance)
        #expect(abs(stopping.elapsed(at: settle.addingTimeInterval(5)) - PhaseCycle.holdElapsed) < Self.tolerance)
    }

    @Test("Just past the hold phase, stopping goes round the month rather than back")
    func neverRunsBackwards() {
        let justPast = PhaseCycle.holdElapsed + 0.1
        let stopping = MoonMotion.held(at: justPast, since: Self.t0).stopping(at: PhaseCycle.holdElapsed, from: Self.t0)
        let expected = (PhaseCycle.period - 0.1) / MoonMotion.runOutRate
        #expect(abs(stopping.timeToSettle(from: Self.t0) - expected) < Self.tolerance)
        // Halfway it's moved on, not back.
        let halfway = stopping.elapsed(at: Self.at(expected / 2))
        #expect(PhaseCycle.wrapped(halfway - justPast) > 0)
    }

    @Test("Never stops mid-cycle: until it settles it's moving, after it's on the target")
    func noMidCycleStop() {
        let stopping = MoonMotion.held(at: 0.3, since: Self.t0).stopping(at: PhaseCycle.holdElapsed, from: Self.t0)
        let settle = stopping.timeToSettle(from: Self.t0)
        var previous = stopping.elapsed(at: Self.t0)
        for step in 1...20 {
            let value = stopping.elapsed(at: Self.at(settle * Double(step) / 20))
            #expect(value > previous - Self.tolerance)
            previous = value
        }
        #expect(abs(previous - PhaseCycle.holdElapsed) < 1e-6)
    }

    @Test("Already frozen at the hold phase, stopping there again is instant")
    func stopWhereFrozen() {
        let frozen = MoonMotion.held(at: 1, since: Self.t0).stopping(at: PhaseCycle.holdElapsed, from: Self.t0)
        let settled = frozen.timeToSettle(from: Self.t0)
        let again = frozen.stopping(at: PhaseCycle.holdElapsed, from: Self.at(settled + 1))
        #expect(again.timeToSettle(from: Self.at(settled + 1)) == 0)
    }

    @Test("Running to full for Aha stops at full")
    func runsToFull() {
        let motion = MoonMotion.held(at: PhaseCycle.holdElapsed, since: Self.t0)
            .stopping(at: PhaseCycle.fullElapsed, from: Self.t0)
        let settle = motion.timeToSettle(from: Self.t0)
        #expect(PhaseCycle.geometry(at: motion.elapsed(at: Self.at(settle))).litFraction > 0.999_999)
        // From the waxing hold phase, full is just ahead: well under a
        // quarter of the run-out's month (§10.2).
        #expect(settle < PhaseCycle.period / MoonMotion.runOutRate / 4)
    }

    @Test("Run-out speed and cycle start are the handoff's")
    func constants() {
        #expect(MoonMotion.runOutRate == 2.6)
        #expect(MoonMotion.cycleStartDelay == 0.84)
        #expect(LocationLoader.labelEntranceDelay == 0.32)
    }

    // MARK: - Glow

    @Test("Breathing follows the month: brightest at full")
    func breathesWithMonth() {
        let glow = LoaderGlow.breathing
        let full = glow.look(at: Self.t0, elapsed: PhaseCycle.fullElapsed)
        let new = glow.look(at: Self.t0, elapsed: 0)
        #expect(abs(full.opacity - 1) < Self.tolerance)
        #expect(abs(new.opacity - 0.45) < Self.tolerance)
    }

    @Test("The pulse loops every 1.8 s between its ranges")
    func pulses() {
        #expect(LoaderGlow.pulseLevel(at: 0) == 0)
        #expect(abs(LoaderGlow.pulseLevel(at: 0.9) - 1) < Self.tolerance)
        #expect(abs(LoaderGlow.pulseLevel(at: 1.8)) < Self.tolerance)
        let glow = LoaderGlow.breathing.switching(to: .pulse, at: Self.t0, elapsed: PhaseCycle.holdElapsed)
        let peak = glow.look(at: Self.at(0.9), elapsed: PhaseCycle.holdElapsed)
        #expect(abs(peak.opacity - 1) < Self.tolerance)
        #expect(abs(peak.scale - 1.18) < Self.tolerance)
    }

    @Test("Switching mode blends from where the glow was, so it never jumps")
    func switchBlends() {
        let elapsed = PhaseCycle.holdElapsed
        let before = LoaderGlow.breathing.look(at: Self.t0, elapsed: elapsed)
        let pulse = LoaderGlow.breathing.switching(to: .pulse, at: Self.t0, elapsed: elapsed)
        #expect(pulse.look(at: Self.t0, elapsed: elapsed) == before)
        let back = pulse.switching(to: .breathe, at: Self.at(2), elapsed: elapsed)
        #expect(back.look(at: Self.at(2), elapsed: elapsed) == pulse.look(at: Self.at(2), elapsed: elapsed))
        #expect(back.look(at: Self.at(2.5), elapsed: elapsed) == before)
    }

    @Test("The flare goes .5 → 1 → .8 and 1 → 1.7 → 1.15 once, then holds")
    func flares() {
        #expect(LoaderGlow.flare(at: 0) == LoaderGlow.flareStart)
        #expect(LoaderGlow.flare(at: LoaderGlow.flareDuration) == LoaderGlow.flareEnd)
        #expect(LoaderGlow.flare(at: 5) == LoaderGlow.flareEnd)
        let peakish = (0...140).map { LoaderGlow.flare(at: Double($0) / 100).scale }.max() ?? 0
        #expect(abs(peakish - 1.7) < 0.01)
    }
}
