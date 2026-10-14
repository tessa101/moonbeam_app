//
//  CompassGhostMotion.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off prompt's ghosted compass turning (LOCATION-OFF-FLOW.md
/// §2, design 1.9 "S1: Prompt"): the ring swings left, holds, swings right,
/// holds, and comes home, like a phone slowly being turned. Pure numbers, so
/// the keyframes are testable without a view.
///
/// `nonisolated`: an inert table.
nonisolated enum CompassGhostMotion {

    /// One row of the handoff's table: the ring's turn, clockwise, at a time.
    nonisolated struct Keyframe: Equatable, Sendable {
        let seconds: TimeInterval
        let degrees: Double
    }

    // MARK: - Constants

    /// One loop, repeating forever.
    static let loopSeconds: TimeInterval = 12

    /// Reduce Motion, the background and off screen: north up.
    static let stillDegrees = 0.0

    /// Handoff table. The last row is the first again, so the loop closes;
    /// equal neighbours are the holds.
    static let keyframes: [Keyframe] = [
        Keyframe(seconds: 0, degrees: 0),
        Keyframe(seconds: 3, degrees: -70),
        Keyframe(seconds: 4.8, degrees: -70),
        Keyframe(seconds: 7.8, degrees: 40),
        Keyframe(seconds: 9.6, degrees: 40),
        Keyframe(seconds: 12, degrees: 0),
    ]

    /// Every move eases with cubic-bezier(.45, 0, .55, 1).
    private static let easing = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.45, y: 0),
        endControlPoint: UnitPoint(x: 0.55, y: 1)
    )

    // MARK: - Sampling

    /// The ring's turn `seconds` into the loop. Loops, so any value is fine.
    static func degrees(at seconds: TimeInterval) -> Double {
        let wrapped = seconds.truncatingRemainder(dividingBy: loopSeconds)
        let time = wrapped < 0 ? wrapped + loopSeconds : wrapped
        for (from, to) in zip(keyframes, keyframes.dropFirst()) where time <= to.seconds {
            let progress = easing.value(at: (time - from.seconds) / (to.seconds - from.seconds))
            return from.degrees + (to.degrees - from.degrees) * progress
        }
        return stillDegrees
    }
}
