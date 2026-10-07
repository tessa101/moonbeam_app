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
///
/// Under "Aha"'s flying moon (§11.2.6) the blocks are timed around the
/// flight instead (its start is time zero): the sentence once "Aha" is gone,
/// the card as the moon reaches its slot, the compass after the landing.
/// Same fade and rise.
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

    // MARK: - After "Aha" (§11.2.6, proposed values)

    /// How long after the flight starts a block starts loading in: the
    /// sentence after "Aha" has gone (0.25 s), the card so it's in as the
    /// moon lands in its slot (0.85 s), the compass after the landing.
    static func afterAhaDelay(for block: Block) -> TimeInterval {
        switch block {
        case .sentence: 0.30
        case .card: 0.45
        case .compass: 1.0
        }
    }

    /// How a block comes in: after "Aha", or the usual load-in.
    static func animation(for block: Block, afterAha: Bool) -> Animation {
        .easeOut(duration: duration).delay(afterAha ? afterAhaDelay(for: block) : delay(for: block))
    }

    // MARK: - Modifier

    let block: Block

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.contentArrivesAfterAha) private var afterAha
    @State private var isIn = false

    func body(content: Content) -> some View {
        content
            .opacity(isIn ? 1 : 0)
            .offset(y: isIn ? 0 : Self.startOffset(reduceMotion: reduceMotion))
            .onAppear {
                withAnimation(Self.animation(for: block, afterAha: afterAha)) {
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
