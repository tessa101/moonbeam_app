//
//  IllustrationMotion.swift
//  moonbeam-app
//

import CoreGraphics
import Foundation

/// How one part of a failure illustration moves (STEP-5.10a, Chunk 5):
/// any of its tracks, each a loop of its own. A missing track stays at
/// rest. All numbers come from ILLUSTRATIONS_MOTION.md through
/// `IllustrationSpec`; none live in a view.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct IllustrationMotion: Equatable, Sendable {

    /// Degrees, clockwise, about the part's pivot.
    var rotation: IllustrationKeyframes?
    /// About the part's pivot.
    var scale: IllustrationKeyframes?
    /// Per-axis factors on top of `scale`, for 1k's breath (CSS
    /// `scale(x, y)`), which stretches more in height than width.
    var scaleX: IllustrationKeyframes?
    var scaleY: IllustrationKeyframes?
    var opacity: IllustrationKeyframes?
    /// ViewBox units, before the scale (CSS `scale(s) translateY(y)`), so
    /// it shrinks with the part.
    var offsetY: IllustrationKeyframes?
    /// CSS `brightness()`: 1 is as drawn.
    var brightness: IllustrationKeyframes?

    /// Where a part is, at one moment.
    struct Pose: Equatable, Sendable {
        var rotation: Double = 0
        var scale: Double = 1
        var scaleX: Double = 1
        var scaleY: Double = 1
        var opacity: Double = 1
        var offsetY: Double = 0
        var brightness: Double = 1

        static let rest = Pose()

        /// The pose's move in viewBox points, about `pivot`: translate, then
        /// rotate and scale, as CSS applies `scale() rotate() translateY()`
        /// with its transform origin at the pivot.
        func transform(pivot: CGPoint?) -> CGAffineTransform {
            let origin = pivot ?? .zero
            return CGAffineTransform(translationX: -origin.x, y: -origin.y)
                .concatenating(CGAffineTransform(translationX: 0, y: offsetY))
                .concatenating(CGAffineTransform(rotationAngle: rotation * .pi / 180))
                .concatenating(CGAffineTransform(scaleX: scale * scaleX, y: scale * scaleY))
                .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
        }

        /// `transform(pivot:)` in a frame drawn `canvasScale` points per
        /// viewBox unit.
        func scaledTransform(pivot: CGPoint?, canvasScale: CGFloat) -> CGAffineTransform {
            var scaledPose = self
            scaledPose.offsetY *= canvasScale
            let scaledPivot = pivot.map {
                CGPoint(x: $0.x * canvasScale, y: $0.y * canvasScale)
            }
            return scaledPose.transform(pivot: scaledPivot)
        }
    }

    func pose(at time: TimeInterval) -> Pose {
        Pose(
            rotation: rotation?.value(at: time) ?? 0,
            scale: scale?.value(at: time) ?? 1,
            scaleX: scaleX?.value(at: time) ?? 1,
            scaleY: scaleY?.value(at: time) ?? 1,
            opacity: opacity?.value(at: time) ?? 1,
            offsetY: offsetY?.value(at: time) ?? 0,
            brightness: brightness?.value(at: time) ?? 1
        )
    }
}
