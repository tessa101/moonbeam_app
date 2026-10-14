//
//  LocationOffCardPhase.swift
//  moonbeam-app
//

import Foundation

/// Where the location-off card is in its swap (LOCATION-OFF-FLOW.md §5.4): at
/// rest expanded (S1) or collapsed (the row), or part-way through a collapse
/// or expand that began at a time. Pure rules for what that means: which
/// taps are live, which layers are drawn, which VoiceOver may read.
///
/// No interrupting: taps are off from the start of a swap until it ends.
///
/// `nonisolated`: an inert value.
nonisolated enum LocationOffCardPhase: Equatable, Sendable {
    case expanded
    case collapsing(since: Date)
    case collapsed
    case expanding(since: Date)

    /// At rest in the state the view model asks for.
    static func rest(collapsed: Bool) -> LocationOffCardPhase {
        collapsed ? .collapsed : .expanded
    }

    /// The view model's state changed: swap toward it, from now.
    static func swap(toCollapsed collapsed: Bool, at now: Date) -> LocationOffCardPhase {
        collapsed ? .collapsing(since: now) : .expanding(since: now)
    }

    /// When the swap began, or `nil` at rest.
    var startedAt: Date? {
        switch self {
        case .expanded, .collapsed: nil
        case let .collapsing(since), let .expanding(since): since
        }
    }

    var isAnimating: Bool { startedAt != nil }

    var direction: LocationOffCardMotion.Direction? {
        switch self {
        case .collapsing: .collapse
        case .expanding: .expand
        case .expanded, .collapsed: nil
        }
    }

    /// Turn On Location and Maybe later: only at rest, expanded.
    var isPromptInteractive: Bool { self == .expanded }

    /// The row: only at rest, collapsed.
    var isRowInteractive: Bool { self == .collapsed }

    /// The prompt is drawn except at rest, collapsed (so its ring isn't
    /// left turning under the row).
    var drawsPrompt: Bool { self != .collapsed }

    /// VoiceOver reads the layer being shown or arriving, never the one
    /// leaving or hidden.
    var promptIsAccessible: Bool {
        switch self {
        case .expanded, .expanding: true
        case .collapsing, .collapsed: false
        }
    }

    var rowIsAccessible: Bool { !promptIsAccessible }

    /// The swap's frame `now`; at rest, the rest frame.
    func frame(at now: Date, reduceMotion: Bool) -> LocationOffCardMotion.Frame {
        switch self {
        case .expanded:
            .rest(collapsed: false)
        case .collapsed:
            .rest(collapsed: true)
        case let .collapsing(since):
            LocationOffCardMotion.frame(.collapse, at: now.timeIntervalSince(since), reduceMotion: reduceMotion)
        case let .expanding(since):
            LocationOffCardMotion.frame(.expand, at: now.timeIntervalSince(since), reduceMotion: reduceMotion)
        }
    }

    /// Over once its whole timeline has run.
    func isFinished(at now: Date, reduceMotion: Bool) -> Bool {
        guard let startedAt else { return true }
        return now.timeIntervalSince(startedAt) >= LocationOffCardMotion.totalDuration(reduceMotion: reduceMotion)
    }

    /// Where it rests once the swap ends.
    var settled: LocationOffCardPhase {
        switch self {
        case .expanded, .expanding: .expanded
        case .collapsed, .collapsing: .collapsed
        }
    }
}
