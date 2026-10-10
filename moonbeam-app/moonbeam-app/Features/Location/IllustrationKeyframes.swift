//
//  IllustrationKeyframes.swift
//  moonbeam-app
//

import SwiftUI

/// One looping value of a failure illustration's motion (STEP-5.10a,
/// Chunk 5): stops at fractions of the loop, as ILLUSTRATIONS_MOTION.md
/// lists them, eased segment by segment like the reference's Web Animations
/// keyframes. The loop repeats forever and is seamless: the last stop's
/// value is the first's.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct IllustrationKeyframes: Equatable, Sendable {

    /// How each segment between two stops is timed.
    enum Curve: Equatable, Sendable {
        /// `cubic-bezier(.42, 0, .58, 1)`, the doc's default.
        case easeInOut
        /// The empty moon's ring turns at a steady speed.
        case linear
    }

    struct Stop: Equatable, Sendable {
        /// Fraction of the loop, 0…1.
        let offset: Double
        let value: Double
    }

    /// Seconds per loop, already at 0.85× ("Playful beats").
    let duration: TimeInterval
    let stops: [Stop]
    var curve: Curve = .easeInOut

    /// Stops spread evenly over the loop, e.g. 0.95 → 1.06 → 0.95.
    init(duration: TimeInterval, values: [Double], curve: Curve = .easeInOut) {
        let last = Double(max(values.count - 1, 1))
        self.init(
            duration: duration,
            stops: values.enumerated().map { Stop(offset: Double($0.offset) / last, value: $0.element) },
            curve: curve
        )
    }

    /// Stops at the doc's offsets: `[(offset, value)]`.
    init(duration: TimeInterval, _ stops: [(Double, Double)], curve: Curve = .easeInOut) {
        self.init(duration: duration, stops: stops.map { Stop(offset: $0.0, value: $0.1) }, curve: curve)
    }

    init(duration: TimeInterval, stops: [Stop], curve: Curve) {
        self.duration = duration
        self.stops = stops
        self.curve = curve
    }

    /// The value `time` seconds into the motion (any time, any number of
    /// loops in).
    func value(at time: TimeInterval) -> Double {
        guard let first = stops.first, let last = stops.last, duration > 0 else { return 0 }
        let loops = time / duration
        let fraction = loops - loops.rounded(.down)
        if fraction <= first.offset { return first.value }
        if fraction >= last.offset { return last.value }
        guard let end = stops.firstIndex(where: { $0.offset >= fraction }), end > 0 else { return last.value }
        let from = stops[end - 1]
        let to = stops[end]
        let span = to.offset - from.offset
        guard span > 0 else { return to.value }
        let progress = eased((fraction - from.offset) / span)
        return from.value + (to.value - from.value) * progress
    }

    private func eased(_ progress: Double) -> Double {
        switch curve {
        case .easeInOut: Self.easeInOut.value(at: progress)
        case .linear: progress
        }
    }

    /// CSS `ease-in-out`.
    private static let easeInOut = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.42, y: 0),
        endControlPoint: UnitPoint(x: 0.58, y: 1)
    )
}
