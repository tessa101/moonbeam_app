//
//  PhaseRideTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// After "Aha", the moon's ride forward to the real phase (LOADER.md §11.2.2).
@Suite("Phase ride")
struct PhaseRideTests {

    private static let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private static let tolerance = 1e-9

    @Test(
        "The real phase round-trips through the 4b shape, waxing and waning",
        arguments: [0.0, 0.25, 0.5, 0.75, 1.0], [90.0, 270.0]
    )
    func realPhaseRoundTrips(lit: Double, angle: Double) {
        let card = PhaseGlyphGeometry(illumination: lit, phaseAngle: angle)
        let phase = PhaseRide.phase(of: card)
        #expect(phase >= 0 && phase < 1)
        let drawn = PhaseCycle.geometry(forPhase: phase)
        #expect(abs(drawn.litFraction - lit) < 1e-9)
        // At new and full the lit side doesn't show.
        if lit > 0, lit < 1 {
            #expect(drawn.litSide == card.litSide)
        }
    }

    @Test("Waxing lands before full, waning after: lit on the right, then the left")
    func realPhaseHalves() {
        #expect(PhaseRide.phase(of: PhaseGlyphGeometry(illumination: 0.3, phaseAngle: 60)) < 0.5)
        #expect(PhaseRide.phase(of: PhaseGlyphGeometry(illumination: 0.3, phaseAngle: 300)) > 0.5)
    }

    @Test("Always forward: under a lap normally, a lap more on the first ride")
    func travelIsForward() {
        for (from, to) in [(0.1, 0.4), (0.4, 0.1), (0.7, 0.7), (0.95, 0.05)] {
            let ride = PhaseRide(from: from, to: to, extraLap: false, startingAt: Self.t0)
            let first = PhaseRide(from: from, to: to, extraLap: true, startingAt: Self.t0)
            #expect(ride.laps >= 0 && ride.laps < 1)
            #expect(abs(first.laps - ride.laps - 1) < Self.tolerance)
            // Both end on the target.
            for leg in [ride, first] {
                #expect(abs(PhaseCycle.wrapped(leg.phase(at: leg.endDate) * PhaseCycle.period)
                    - PhaseCycle.wrapped(to * PhaseCycle.period)) < 1e-6)
            }
        }
        // Backwards from waning to waxing means round through new, not back.
        #expect(abs(PhaseRide(from: 0.8, to: 0.2, extraLap: false, startingAt: Self.t0).laps - 0.4) < Self.tolerance)
    }

    @Test("Duration 0.9 + 2.0·T s, clamped to 1.6…4.2 s")
    func durationClamps() {
        #expect(PhaseRide.duration(laps: 0) == 1.6)
        #expect(abs(PhaseRide.duration(laps: 0.5) - 1.9) < Self.tolerance)
        #expect(abs(PhaseRide.duration(laps: 1.3) - 3.5) < Self.tolerance)
        #expect(PhaseRide.duration(laps: 1.9) == 4.2)
    }

    @Test("Takes over at the given speed and eases out to rest")
    func startsAtSpeed() {
        let speed = 0.3
        let ride = PhaseRide(from: 0.2, to: 0.9, extraLap: false, startSpeed: speed, startingAt: Self.t0)
        #expect(ride.duration == PhaseRide.duration(laps: 0.7))
        let frame = 1e-4
        let start = (ride.phase(at: Self.t0.addingTimeInterval(frame)) - ride.phase(at: Self.t0)) / frame
        #expect(abs(start - speed) < 1e-3)
        let end = ride.endDate
        let last = (ride.phase(at: end) - ride.phase(at: end.addingTimeInterval(-frame))) / frame
        #expect(last < 1e-3)
    }

    @Test("Too fast to brake within the ride: a shorter ride at the same speed, never overshooting")
    func fastStartShortens() {
        // 0.05 laps ahead at 0.42 phases/s: braking in 1.6 s would overshoot.
        let ride = PhaseRide(from: 0.3, to: 0.35, extraLap: false, startSpeed: 0.42, startingAt: Self.t0)
        #expect(ride.duration < PhaseRide.durationRange.lowerBound)
        #expect(abs(ride.startSlope - PhaseRide.maximumStartSlope) < Self.tolerance)
        var previous = ride.fromPhase
        for index in 1...200 {
            let now = ride.phase(at: Self.t0.addingTimeInterval(ride.duration * Double(index) / 200))
            #expect(now >= previous - Self.tolerance)
            #expect(now <= 0.35 + Self.tolerance)
            previous = now
        }
        #expect(abs(previous - 0.35) < 1e-9)
    }

    @Test("The ease-out never runs backwards for start slopes 0…3", arguments: [0.0, 0.5, 1.5, 2.5, 3.0])
    func easeOutMonotonic(slope: Double) {
        var previous = 0.0
        for index in 1...100 {
            let value = PhaseRide.easeOut(Double(index) / 100, startSlope: slope)
            #expect(value >= previous - Self.tolerance)
            previous = value
        }
        #expect(abs(previous - 1) < Self.tolerance)
    }

    @Test("From rest it eases in and out, and never runs backwards")
    func easedForward() {
        let ride = PhaseRide(from: 0.3, to: 0.2, extraLap: true, startingAt: Self.t0)
        var travelled = 0.0
        var previous = ride.phase(at: Self.t0)
        var steps: [Double] = []
        for index in 1...100 {
            let now = ride.phase(at: Self.t0.addingTimeInterval(ride.duration * Double(index) / 100))
            let step = (now - previous + 1).truncatingRemainder(dividingBy: 1)
            #expect(step >= 0 && step < 0.5)
            steps.append(step)
            travelled += step
            previous = now
        }
        #expect(abs(travelled - ride.laps) < 1e-6)
        // Slow at both ends, fastest in the middle.
        #expect(steps[0] < steps[50] && steps[99] < steps[50])
        // Held at the start before it, and at the target after.
        #expect(ride.phase(at: Self.t0.addingTimeInterval(-1)) == ride.fromPhase)
        #expect(abs(ride.phase(at: ride.endDate.addingTimeInterval(3)) - 0.2) < 1e-9)
    }
}
