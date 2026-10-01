//
//  MadlibScale.swift
//  moonbeam-app
//

import CoreGraphics

/// The one scale factor all three madlib lines share (DESIGN-1.1.md §3.1a),
/// so no line ever reads smaller than the others.
///
/// It's the smallest scale any line needs to fit on one line, but never
/// below `minimum`. A line that wouldn't fit even at `minimum` is left out:
/// it wraps anyway, and letting it drag the others down would shrink every
/// line to `minimum` whenever one wraps (always, at AX sizes). It's still
/// drawn at the shared scale, just on two lines.
///
/// `nonisolated` because it's a pure calculation over its inputs.
nonisolated enum MadlibScale {

    /// - Parameters:
    ///   - naturalWidths: each line's one-line width at full size.
    ///   - availableWidth: the width the lines get.
    ///   - minimum: the smallest allowed scale (0.8, §3.1a).
    static func shared(naturalWidths: [CGFloat], availableWidth: CGFloat, minimum: CGFloat) -> CGFloat {
        guard availableWidth > 0 else { return 1 }
        let fitting = naturalWidths
            .filter { $0 > 0 }
            .map { availableWidth / $0 }
            .filter { $0 >= minimum }
        return min(1, fitting.min() ?? 1)
    }
}
