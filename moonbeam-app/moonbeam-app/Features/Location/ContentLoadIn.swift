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

    /// Where a block sits in its screen's load-in: one of the main screen's
    /// blocks, or the nth block of another screen (onboarding, STEP-5.14 §2).
    /// An indexed block loads in once, on appearance, with the usual stagger;
    /// it never replays and ignores "Aha".
    enum Position: Equatable {
        case main(Block)
        case index(Int)
    }

    // MARK: - Timings (§2.1, proposed values)

    static let duration: TimeInterval = 0.3
    /// The one number to tune on the device (§11.2.7).
    static let stagger: TimeInterval = 0.15
    static let rise: CGFloat = 8

    /// How long after the screen arrives a block starts loading in.
    static func delay(for block: Block) -> TimeInterval {
        delay(forIndex: block.rawValue)
    }

    /// The same stagger for a screen's nth block, counting from 0.
    static func delay(forIndex index: Int) -> TimeInterval {
        Double(index) * stagger
    }

    /// How a screen's nth block comes in: the usual load-in.
    static func animation(forIndex index: Int) -> Animation {
        .easeOut(duration: duration).delay(delay(forIndex: index))
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

    // MARK: - Place change replay (LOADER.md §12.9)

    /// The sentence stays through a place change (only its city token
    /// cross-fades), so it loads in once per screen arrival; the blocks
    /// below it replay.
    static func replaysOnPlaceChange(_ block: Block) -> Bool {
        block != .sentence
    }

    /// 5.10a.4 (Tessa, 2026-10-09): a place change lands gently, in order:
    /// the city line (its own reveal, `MadlibSentence.placeRevealFade`),
    /// then the card, then the compass, each a slow fade with the usual
    /// 8 pt rise. Slower than the launch load-in on purpose.
    static let replayDuration: TimeInterval = 0.4
    /// The card starts this long after the city line begins to show.
    static let replayCardDelay: TimeInterval = 0.1
    /// The compass starts this long after the city line begins to show.
    static let replayCompassDelay: TimeInterval = 0.25

    /// A replay starts at the card, after the city line has begun.
    static func replayDelay(for block: Block) -> TimeInterval {
        switch block {
        case .sentence: 0
        case .card: replayCardDelay
        case .compass: replayCompassDelay
        }
    }

    static func replayAnimation(for block: Block) -> Animation {
        .easeOut(duration: replayDuration).delay(replayDelay(for: block))
    }

    /// 5.10a.13 (Tessa, 2026-10-09, video 9): the real card lands with the
    /// ordinary replay (`replayAnimation(for: .card)`: 8 pt rise, 0.4 s,
    /// 0.1 s delay), as for a searched city. Only the skeleton's exit is its
    /// own: it fades out over the card's arrival.
    static let skeletonExitDuration: TimeInterval = 0.2
    static let skeletonExitAnimation = Animation.easeOut(duration: skeletonExitDuration)

    // MARK: - Modifier

    /// What re-runs the load-in: a new generation, or the block being let in.
    private struct Trigger: Equatable {
        let generation: Int
        let isActive: Bool
    }

    let position: Position
    let generation: Int
    /// While false the block stays out (opacity 0) and loads in when it
    /// turns true, e.g. the compass until a replacement's place lands.
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.contentArrivesAfterAha) private var afterAha
    @State private var isIn = false
    /// The first load-in uses the launch stagger (or "Aha"'s); later ones
    /// are place-change replays.
    @State private var hasLoadedIn = false
    /// When the latest load-in starts to show, after its delay; `nil` until
    /// one runs. The compass starts its settle then (LOADER.md §12.4).
    @State private var revealsAt: Date?

    func body(content: Content) -> some View {
        content
            // 5.10a.14 (Tessa, 2026-10-09, video 10): measured frame by frame,
            // the card's frame, glyph, ‹ ›, date line and hairline rose with
            // the offset, but the phase line and the whole rise/set area
            // (both built in ViewThatFits) stayed where they end up. The
            // offset's animation reached only the children outside
            // ViewThatFits. `.geometryGroup()` resolves the block's geometry
            // first, so every child, ViewThatFits ones included, moves with
            // it as one unit.
            .geometryGroup()
            .opacity(isIn ? 1 : 0)
            .offset(y: isIn ? 0 : Self.startOffset(reduceMotion: reduceMotion))
            .environment(\.contentRevealsAt, revealsAt)
            .task(id: Trigger(generation: generation, isActive: isActive)) {
                let isReplay = hasLoadedIn
                if isReplay, !replays { return }
                // Snap out without animating, then let the stagger bring the
                // new generation in.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isIn = false
                }
                guard isActive else { return }
                hasLoadedIn = true
                await Task.yield()
                let timing = timing(isReplay: isReplay)
                revealsAt = Date.now.addingTimeInterval(timing.delay)
                withAnimation(timing.animation) {
                    isIn = true
                }
            }
    }

    /// Indexed blocks load in once; main-screen blocks per §12.9.
    private var replays: Bool {
        switch position {
        case .main(let block): Self.replaysOnPlaceChange(block)
        case .index: false
        }
    }

    /// This load-in's animation and the delay before it shows.
    private func timing(isReplay: Bool) -> (animation: Animation, delay: TimeInterval) {
        switch position {
        case .index(let index):
            return (Self.animation(forIndex: index), Self.delay(forIndex: index))
        case .main(let block) where isReplay:
            return (Self.replayAnimation(for: block), Self.replayDelay(for: block))
        case .main(let block):
            let delay = afterAha ? Self.afterAhaDelay(for: block) : Self.delay(for: block)
            return (Self.animation(for: block, afterAha: afterAha), delay)
        }
    }
}

extension EnvironmentValues {
    /// When the enclosing `ContentLoadIn` block starts to show, or `nil`
    /// outside one. A reload that coincides with a load-in times its own
    /// motion from here, so it isn't spent while the block is still out.
    @Entry var contentRevealsAt: Date?
}

extension View {
    /// Loads this block in when the main screen arrives (LOADER.md §2.1),
    /// and again for each new `generation` unless it's the sentence (§12.9).
    func contentLoadIn(
        _ block: ContentLoadIn.Block,
        generation: Int = 0,
        isActive: Bool = true
    ) -> some View {
        modifier(ContentLoadIn(position: .main(block), generation: generation, isActive: isActive))
    }

    /// Loads this block in as the nth of its screen (0 first) when the screen
    /// appears, with the main screen's fade, rise and stagger (STEP-5.14 §2).
    func contentLoadIn(index: Int) -> some View {
        modifier(ContentLoadIn(position: .index(index), generation: 0, isActive: true))
    }
}
