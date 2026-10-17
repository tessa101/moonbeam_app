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

    /// The `noCity` headline (ONBOARDING-MOD-MAIN.md): `shared`'s scale, but
    /// grown past full size until the widest line fills `availableWidth` or
    /// the lines fill `availableHeight`, up to `maximum`. Where the sentence
    /// doesn't fit at full size it's `shared` unchanged (shrink at `.large`,
    /// wrap elsewhere). Accessibility sizes never grow: the text is already
    /// large, and wrapping keeps it readable.
    ///
    /// - Parameter naturalHeight: the three lines' total height at full size.
    static func filling(
        naturalWidths: [CGFloat],
        naturalHeight: CGFloat,
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let fitted = shared(
            naturalWidths: naturalWidths,
            availableWidth: availableWidth,
            minimum: minimum,
            dynamicTypeSize: dynamicTypeSize
        )
        guard !dynamicTypeSize.isAccessibilitySize,
              availableWidth > 0, availableHeight > 0, naturalHeight > 0,
              let widest = naturalWidths.max(), widest > 0
        else { return fitted }
        let grown = min(availableWidth / widest, availableHeight / naturalHeight, maximum)
        return grown > 1 ? grown : fitted
    }
}
