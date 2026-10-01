//
//  MadlibScale.swift
//  moonbeam-app
//

import SwiftUI

/// The one scale factor all three madlib lines share (DESIGN-1.1.md §3.1a),
/// so no line ever reads smaller than the others.
///
/// Only at the default Dynamic Type size (`.large`): there the sentence
/// shrinks to the smallest scale any line needs to fit on one line, but
/// never below `minimum` (0.7, about 19 pt); a line that still doesn't fit
/// wraps at `minimum`. At every other size the sentence is full size and
/// long lines wrap: the reader chose that size, so it isn't undone.
///
/// `nonisolated` because it's a pure calculation over its inputs.
nonisolated enum MadlibScale {

    /// Whether the sentence shrinks to fit at `size`.
    static func shrinks(at size: DynamicTypeSize) -> Bool {
        size == .large
    }

    /// - Parameters:
    ///   - naturalWidths: each line's one-line width at full size.
    ///   - availableWidth: the width the lines get.
    ///   - minimum: the smallest allowed scale (0.7, §3.1a).
    ///   - dynamicTypeSize: the reader's size; only `.large` shrinks.
    static func shared(
        naturalWidths: [CGFloat],
        availableWidth: CGFloat,
        minimum: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        guard shrinks(at: dynamicTypeSize), availableWidth > 0 else { return 1 }
        let needed = naturalWidths
            .filter { $0 > 0 }
            .map { availableWidth / $0 }
            .min() ?? 1
        return min(1, max(minimum, needed))
    }
}
