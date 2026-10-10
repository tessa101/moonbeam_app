//
//  IllustrationSpark.swift
//  moonbeam-app
//

import SwiftUI

/// The spark that rides the map's route on the services-off and restricted
/// illustrations (ILLUSTRATIONS_MOTION.md 1i "Fading trail" and 1j "Bump"),
/// with the waypoints' glow and, for restricted, the lock's shake. Times
/// are already at 0.85×.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct IllustrationSpark: Equatable, Sendable {

    /// How the run ends.
    enum Ending: Equatable, Sendable {
        /// 1i: fades out over the last part of the travel, partway along.
        case fizzle
        /// 1j: stops at the first point where x reaches `stopX` (just left
        /// of the lock), bounces back and fades.
        case bump(stopX: Double)
    }

    /// The route, in viewBox units.
    let route: Path
    let ending: Ending
    /// Seconds per run, rest included.
    let cycle: TimeInterval
    /// Seconds of travel.
    let travel: TimeInterval
    /// The waypoints' centres, in viewBox units.
    let waypoints: [CGPoint]

    // MARK: - Constants (ILLUSTRATIONS_MOTION.md)

    /// 1i: how far along the route a fizzling spark gets.
    static let fizzleReach = 0.62
    /// 1i: the fade-out runs over the last 35% of the travel.
    static let fizzleShare = 0.35
    /// Fades in over the first 0.25 s of each run.
    static let fadeIn: TimeInterval = 0.25
    /// 1j: the bounce after the bump.
    static let bounceDuration: TimeInterval = 0.82
    static let bounceDip = 0.05
    static let bounceDrift = 0.02
    /// The reference searches for the stop in steps of 0.5% of the route.
    static let stopSearchStep = 0.005
    /// Waypoints rest at 0.45 and light up to 1 within 40 units of the
    /// spark.
    static let waypointRest = 0.45
    static let waypointGlowRange: CGFloat = 40
    /// 1j: the lock's shake, from the spark's arrival.
    static let shakeAmplitude = 10.0
    static let shakeFrequency = 23.8
    static let shakeDecay = 3.83
    static let shakeDuration: TimeInterval = 1.06

    /// The spark's look: a cream core in a faint amber glow.
    static let coreRadius: CGFloat = 6.5
    static let coreColorHex: UInt32 = 0xF7E7BD
    static let glowRadius: CGFloat = 16
    static let glowColorHex: UInt32 = 0xF2C27B
    static let glowOpacity = 0.22

    // MARK: - Run

    /// Where the spark is.
    struct State: Equatable {
        /// Fraction of the route's length.
        var progress: Double
        var opacity: Double
        var point: CGPoint
    }

    /// x² (3 − 2x), clamped to 0…1.
    static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// The fraction of the route the spark travels to. Found once: the
    /// stop search trims the route up to 200 times.
    let reach: Double

    init(route: Path, ending: Ending, cycle: TimeInterval, travel: TimeInterval, waypoints: [CGPoint]) {
        self.route = route
        self.ending = ending
        self.cycle = cycle
        self.travel = travel
        self.waypoints = waypoints
        switch ending {
        case .fizzle:
            reach = Self.fizzleReach
        case .bump(let stopX):
            reach = Self.stop(on: route, atX: stopX)
        }
    }

    /// The first point (in the reference's 0.5% steps) where x reaches
    /// `x`; the fizzle's reach if the route never gets there.
    private static func stop(on route: Path, atX x: Double) -> Double {
        var fraction = stopSearchStep
        while fraction < 1 {
            if let point = route.trimmedPath(from: 0, to: fraction).currentPoint, point.x >= x {
                return fraction
            }
            fraction += stopSearchStep
        }
        return fizzleReach
    }

    /// The spark `time` seconds into the motion; hidden (opacity 0) at
    /// rest.
    func state(at time: TimeInterval) -> State {
        let t = time.truncatingRemainder(dividingBy: cycle)
        let fadeIn = min(1, t / Self.fadeIn)
        var progress = 0.0
        var opacity = 0.0
        if t < travel {
            let x = t / travel
            progress = Self.smoothstep(x) * reach
            opacity = fadeIn
            if ending == .fizzle {
                opacity *= 1 - max(0, (x - (1 - Self.fizzleShare)) / Self.fizzleShare)
            }
        } else if case .bump = ending, t < travel + Self.bounceDuration {
            let u = (t - travel) / Self.bounceDuration
            progress = reach - sin(u * .pi) * Self.bounceDip - u * Self.bounceDrift
            opacity = 1 - u
        }
        return State(progress: progress, opacity: max(0, opacity), point: point(at: progress))
    }

    /// `fraction` of the way along the route, by length.
    func point(at fraction: Double) -> CGPoint {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return startPoint }
        return route.trimmedPath(from: 0, to: clamped).currentPoint ?? startPoint
    }

    /// The route's first point.
    private var startPoint: CGPoint {
        var start: CGPoint?
        route.forEach { element in
            if start == nil, case .move(let to) = element { start = to }
        }
        return start ?? .zero
    }

    /// A waypoint's opacity: lit by a nearby, visible spark.
    func waypointOpacity(_ index: Int, spark: State) -> Double {
        guard waypoints.indices.contains(index) else { return Self.waypointRest }
        let waypoint = waypoints[index]
        let distance = hypot(waypoint.x - spark.point.x, waypoint.y - spark.point.y)
        let near = max(0, 1 - Double(distance / Self.waypointGlowRange))
        return Self.waypointRest + (1 - Self.waypointRest) * near * spark.opacity
    }

    /// 1j: the lock's angle in degrees, shaking from the spark's arrival
    /// and still again by 1.06 s. 0 for a fizzling spark.
    func lockAngle(at time: TimeInterval) -> Double {
        guard case .bump = ending else { return 0 }
        let s = time.truncatingRemainder(dividingBy: cycle) - travel
        guard s > 0, s < Self.shakeDuration else { return 0 }
        return Self.shakeAmplitude * sin(Self.shakeFrequency * s) * exp(-Self.shakeDecay * s)
    }
}
