//
//  ContentLoadIn.swift
//  moonbeam-app
//

import SwiftUI

/// The main screen arriving after launch (LOADER.md §2.1, Tessa 2026-10-05):
/// each content block loads in where it will sit, top to bottom, rather than
/// the whole screen fading in like a scrim lifting. The background never
/// changes.
///
/// Each block fades in and rises 8 pt, 300 ms ease-out, 70 ms after the one
/// above it. The rise is an offset, not layout, so nothing else moves.
/// Reduce Motion keeps the fade and the stagger but drops the rise.
struct ContentLoadIn: ViewModifier {

    /// The screen's blocks, in load-in order.
    enum Block: Int, CaseIterable {
        case sentence
        case card
        case compass
    }

    // MARK: - Timings (§2.1, proposed values)

    static let duration: TimeInterval = 0.3
    static let stagger: TimeInterval = 0.07
    static let rise: CGFloat = 8

    /// How long after the screen arrives a block starts loading in.
    static func delay(for block: Block) -> TimeInterval {
        Double(block.rawValue) * stagger
    }

    /// Where a block starts, below its resting place. Reduce Motion: no rise.
    static func startOffset(reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : rise
    }

    // MARK: - Modifier

    let block: Block

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIn = false

    func body(content: Content) -> some View {
        content
            .opacity(isIn ? 1 : 0)
            .offset(y: isIn ? 0 : Self.startOffset(reduceMotion: reduceMotion))
            .onAppear {
                withAnimation(.easeOut(duration: Self.duration).delay(Self.delay(for: block))) {
                    isIn = true
                }
            }
    }
}

extension View {
    /// Loads this block in when the main screen arrives (LOADER.md §2.1).
    func contentLoadIn(_ block: ContentLoadIn.Block) -> some View {
        modifier(ContentLoadIn(block: block))
    }
}
