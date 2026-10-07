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
/// Each block fades in and rises 8 pt, 300 ms ease-out, 150 ms after the
/// one above it (§11.2.7, Tessa's starting value; was 70 ms): a light
/// stagger, not a sequence to watch. The rise is an offset, not layout, so nothing else moves.
/// Reduce Motion keeps the fade and the stagger but drops the rise.
///
/// Under "Aha"'s flying moon (§11.2.6, §11.2.7) the same stagger starts
/// 0.30 s into the flight, once "Aha" is gone: sentence 0.30 s, card 0.45 s,
/// compass 0.60 s. Same fade and rise.
struct ContentLoadIn: ViewModifier {

    /// The screen's blocks, in load-in order.
    enum Block: Int, CaseIterable {
        case sentence
        case card
        case compass
    }

    // MARK: - Timings (§2.1, proposed values)

    static let duration: TimeInterval = 0.3
    /// The one number to tune on the device (§11.2.7).
    static let stagger: TimeInterval = 0.15
    static let rise: CGFloat = 8

    /// How long after the screen arrives a block starts loading in.
    static func delay(for block: Block) -> TimeInterval {
        Double(block.rawValue) * stagger
    }

    /// Where a block starts, below its resting place. Reduce Motion: no rise.
    static func startOffset(reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : rise
    }

    // MARK: - After "Aha" (§11.2.6, §11.2.7, proposed values)

    /// The sentence starts this long into the flight, after "Aha" has gone
    /// (0.25 s).
    static let afterAhaStart: TimeInterval = 0.30

    /// How long after the flight starts a block starts loading in: the
    /// usual stagger, from `afterAhaStart`.
    static func afterAhaDelay(for block: Block) -> TimeInterval {
        afterAhaStart + delay(for: block)
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
