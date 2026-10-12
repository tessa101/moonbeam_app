//
//  CompassEntrance.swift
//  moonbeam-app
//

import Foundation

/// How the compass comes in each time it reloads with new information
/// (LOADER.md §12.4, STEP-5.10a.3): launch, a place or date change, a
/// return to the foreground, a heading or location arriving late, recovery
/// from a failure screen. One entrance for all of them, so the dial never
/// shows north-up first and never counts up to the real heading.
///
/// Held out until the first heading (at most `headingWait`); then in about
/// `settleOffsetDegrees` off true, easing into the heading over
/// `settleDuration`, with the readout held until it has settled. No heading
/// in time: in with the no-heading look, turning the short way when one
/// arrives. `CompassViewModel` drives it; the view only animates it.
nonisolated struct CompassEntrance: Equatable, Sendable {

    // MARK: - Types

    enum Phase: Equatable, Sendable {
        /// Out (invisible) until the first heading or `headingWait`.
        case waitingForHeading

        /// In with the no-heading look; the turn starts when a heading comes.
        case noHeading

        /// In, turning by `startOffset` into the heading; readout held.
        case settling

        /// Live: the dial follows the heading and the readout shows.
        case settled
    }

    // MARK: - Constants (§12.4, proposed values)

    /// The longest the compass waits for its first heading.
    static let headingWait = Duration.milliseconds(500)

    /// The settle into the true heading.
    static let settleSeconds: TimeInterval = 0.5
    static let settleDuration = Duration.seconds(settleSeconds)

    /// How far off true the dial loads in.
    static let settleOffsetDegrees = 10.0

    private static let fullTurnDegrees = 360.0
    private static let halfTurnDegrees = 180.0

    /// Before anything has reloaded: live, nothing to settle.
    static let idle = CompassEntrance(generation: 0, phase: .settled, startOffset: 0)

    // MARK: - Values

    /// Goes up by one on each reload, so the view restarts its settle.
    let generation: Int

    let phase: Phase

    /// Degrees added to the heading where the dial starts its settle; the
    /// view animates it to 0. Only meaningful while `.settling`.
    let startOffset: Double

    // MARK: - Derived

    /// The compass (readout slot and dial) is drawn: anything but waiting.
    var showsCompass: Bool { phase != .waitingForHeading }

    /// The readout stays out until the dial has settled, so it shows the
    /// heading it lands on, not the readings on the way (179 → 185 → 190).
    var holdsReadout: Bool { phase != .settled }

    // MARK: - Rules

    /// Against the last heading change, so the settle reads as "finding"
    /// north (§12.4). No change seen yet: clockwise of true.
    static func settleOffset(lastHeadingChange: Double?) -> Double {
        guard let lastHeadingChange, lastHeadingChange != 0 else { return settleOffsetDegrees }
        return lastHeadingChange > 0 ? -settleOffsetDegrees : settleOffsetDegrees
    }

    /// The offset that starts the dial north-up (the no-heading look) and
    /// turns it the short way into `heading`.
    static func turnOffset(fromNorthUpTo heading: Double) -> Double {
        -shortestTurn(from: 0, to: heading)
    }

    /// The signed turn from one bearing to another the short way, in
    /// `(-180, 180]`: 350° → 10° is +20°, never −340°.
    static func shortestTurn(from start: Double, to end: Double) -> Double {
        var delta = (end - start).truncatingRemainder(dividingBy: fullTurnDegrees)
        if delta > halfTurnDegrees {
            delta -= fullTurnDegrees
        } else if delta <= -halfTurnDegrees {
            delta += fullTurnDegrees
        }
        return delta
    }
}
