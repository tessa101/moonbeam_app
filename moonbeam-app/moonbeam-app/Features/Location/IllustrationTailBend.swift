//
//  IllustrationTailBend.swift
//  moonbeam-app
//

import CoreGraphics
import Foundation

/// A tail that bends as it sways (STEP-5.14 §5.1): the tail slice is cut
/// into horizontal bands, base to tip, each nested in the one below and
/// turning about its own joint, so the tail curls and the tip trails the
/// base. The tail part's rotation track is the base swing; this spreads it
/// over the joints.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct IllustrationTailBend: Equatable, Sendable {

    /// Bands, base (0) to tip, and so joints too.
    static let bandCount = 7

    /// How much of the swing moves off the base joint into the bands
    /// above it: 0 is a rigid tail, 1 spreads it evenly.
    var flex: Double
    /// How far the tip trails the base, as a fraction of the loop.
    var lag: Double
    /// Each band's joint in viewBox points, base first. Joint 0 is the
    /// tail's existing pivot.
    let joints: [CGPoint]
    /// Each band's clip in viewBox points, base first. Each overlaps the
    /// band below so no seam opens as they turn; the base band reaches the
    /// art's bottom and the tip band its top.
    let bands: [CGRect]

    /// The geometry in the art's own space, as §5.1's table gives it.
    /// - Parameters:
    ///   - basePivot: joint 0, in viewBox points.
    ///   - jointX: joints 1…6's x, in art space.
    ///   - span: the tail's top and bottom y, in art space.
    ///   - overlap: how far each band reaches into the one below, in art space.
    ///   - art: the slice's whole rect, in art space.
    ///   - toViewBox: art space to viewBox points.
    init(
        flex: Double,
        lag: Double,
        basePivot: CGPoint,
        jointX: [Double],
        span: ClosedRange<Double>,
        overlap: Double,
        art: CGRect,
        toViewBox: CGAffineTransform
    ) {
        self.flex = flex
        self.lag = lag
        let bandHeight = (span.upperBound - span.lowerBound) / Double(Self.bandCount)
        let jointY = { (index: Int) in span.upperBound - Double(index) * bandHeight }
        joints = [basePivot] + jointX.enumerated().map { offset, x in
            CGPoint(x: x, y: jointY(offset + 1)).applying(toViewBox)
        }
        bands = (0..<Self.bandCount).map { index in
            let top = index == Self.bandCount - 1 ? art.minY : jointY(index + 1)
            let bottom = index == 0 ? art.maxY : jointY(index) + overlap
            return CGRect(x: art.minX, y: top, width: art.width, height: bottom - top)
                .applying(toViewBox)
        }
    }

    // MARK: - Motion

    /// Joint `index`'s share of the base swing. The shares sum to 1, so with
    /// no lag the tip's total swing is the track's.
    func weight(of index: Int) -> Double {
        let share = flex / Double(Self.bandCount)
        return index == 0 ? (1 - flex) + share : share
    }

    /// Joint `index`'s own turn, in degrees, at `time`: the track, delayed
    /// toward the tip, times its weight. `nil` time is the Reduce Motion
    /// still, with every joint at the track's first stop.
    func angle(of index: Int, track: IllustrationKeyframes, at time: TimeInterval?) -> Double {
        guard let time else { return track.value(at: 0) * weight(of: index) }
        let delay = lag * track.duration * Double(index) / Double(Self.bandCount - 1)
        return track.value(at: time - delay) * weight(of: index)
    }

    /// Band `index`'s move: its own joint's turn first, then each band
    /// below it, down to the base, as nested groups apply them.
    func transform(
        throughBand index: Int,
        track: IllustrationKeyframes,
        at time: TimeInterval?,
        canvasScale: CGFloat = 1
    ) -> CGAffineTransform {
        (0...index).reversed().reduce(CGAffineTransform.identity) { inner, joint in
            inner.concatenating(
                IllustrationMotion.Pose(rotation: angle(of: joint, track: track, at: time))
                    .scaledTransform(pivot: joints[joint], canvasScale: canvasScale)
            )
        }
    }
}
