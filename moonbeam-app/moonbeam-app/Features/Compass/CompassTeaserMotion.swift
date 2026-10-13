//
//  CompassTeaserMotion.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off teaser's "hunt, then find" loop (design handoff,
/// Location Off Teaser, option 1b): the needle swings around searching,
/// overshoots, settles on the moon, the moon brightens, it holds, then
/// resets. Pure numbers, so the keyframes are testable without a view.
///
/// `nonisolated`: an inert table.
nonisolated enum CompassTeaserMotion {

    /// What the art needs at one instant.
    nonisolated struct Frame: Equatable, Sendable {
        /// Needle rotation about the hub; 0 is north, 62 points at the moon.
        var needleDegrees: Double
        /// The amber glow behind the moon, 0...1.
        var glowOpacity: Double
        /// The glow's radius in the art's 200-unit space.
        var glowRadius: Double
    }

    /// One row of the handoff's table.
    nonisolated struct Keyframe: Equatable, Sendable {
        let seconds: TimeInterval
        let frame: Frame
    }

    // MARK: - Constants

    /// One loop, repeating forever.
    static let loopSeconds: TimeInterval = 5.0

    /// The radius the moon-glow asset is drawn at; other radii are a scale of
    /// it (13 / 19 = .684 ... 1).
    static let glowAssetRadius = 19.0

    /// The resting pose: needle on the moon, glow lit. Reduce Motion, previews
    /// and the hold at the end of the loop.
    static let settled = Frame(needleDegrees: 62, glowOpacity: 0.55, glowRadius: 19)

    /// Handoff table. The last row is the first again, so the loop closes.
    static let keyframes: [Keyframe] = [
        Keyframe(seconds: 0.00, frame: Frame(needleDegrees: -30, glowOpacity: 0.12, glowRadius: 13)),
        Keyframe(seconds: 0.75, frame: Frame(needleDegrees: 40, glowOpacity: 0.12, glowRadius: 13)),
        Keyframe(seconds: 1.50, frame: Frame(needleDegrees: -12, glowOpacity: 0.12, glowRadius: 13)),
        Keyframe(seconds: 2.25, frame: Frame(needleDegrees: 78, glowOpacity: 0.12, glowRadius: 13)),
        Keyframe(seconds: 2.75, frame: Frame(needleDegrees: 56, glowOpacity: 0.35, glowRadius: 16)),
        Keyframe(seconds: 3.10, frame: settled),
        Keyframe(seconds: 4.50, frame: Frame(needleDegrees: 62, glowOpacity: 0.55, glowRadius: 17)),
        Keyframe(seconds: 5.00, frame: Frame(needleDegrees: -30, glowOpacity: 0.12, glowRadius: 13)),
    ]

    /// Every segment eases with cubic-bezier(.45, 0, .55, 1).
    private static let easing = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.45, y: 0),
        endControlPoint: UnitPoint(x: 0.55, y: 1)
    )

    // MARK: - Sampling

    /// The frame `seconds` into the animation. Loops, so any value is fine.
    static func frame(at seconds: TimeInterval) -> Frame {
        let wrapped = seconds.truncatingRemainder(dividingBy: loopSeconds)
        let time = wrapped < 0 ? wrapped + loopSeconds : wrapped
        for (from, to) in zip(keyframes, keyframes.dropFirst()) where time <= to.seconds {
            let progress = easing.value(at: (time - from.seconds) / (to.seconds - from.seconds))
            return Frame(
                needleDegrees: lerp(from.frame.needleDegrees, to.frame.needleDegrees, progress),
                glowOpacity: lerp(from.frame.glowOpacity, to.frame.glowOpacity, progress),
                glowRadius: lerp(from.frame.glowRadius, to.frame.glowRadius, progress)
            )
        }
        return keyframes[0].frame
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
