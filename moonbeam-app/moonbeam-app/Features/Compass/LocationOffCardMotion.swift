//
//  LocationOffCardMotion.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off card's collapse and expand (LOCATION-OFF-FLOW.md §5.3,
/// §5.4; design 1.9 TRANSITION.md option 1d, less the title track): one
/// table of tracks, each with a start and a duration on one curve, and one
/// function giving every track's value at a time. The view feeds it the time
/// since the swap began, so all tracks run off the same clock and can't
/// drift. Pure numbers, so the timing is testable without a view.
///
/// Every value is an *amount*: 0 is the expanded look, 1 the collapsed one.
///
/// `nonisolated`: an inert table.
nonisolated enum LocationOffCardMotion {

    enum Direction: Equatable, Sendable {
        /// Maybe later: S1 into the row.
        case collapse
        /// Tap the row: the row into S1, the collapse mirrored.
        case expand
    }

    enum Track: CaseIterable, Sendable {
        case maybeLater, turnOnLocation, body, preview
        /// The ring's move into the avatar slot (scale, travel, its fade).
        case compass
        /// The card's height and corner radius.
        case card
        case avatar, rowText, chevron
    }

    /// When a track runs, in seconds from the tap.
    struct Timing: Equatable, Sendable {
        let start: TimeInterval
        let duration: TimeInterval
        var end: TimeInterval { start + duration }
    }

    /// Everything the card draws at one instant.
    struct Frame: Equatable, Sendable {
        var maybeLater: Double
        var turnOnLocation: Double
        var body: Double
        var preview: Double
        var compass: Double
        var card: Double
        var avatar: Double
        var rowText: Double
        var chevron: Double
        /// Reduce Motion: fades only, no scale or travel.
        var isReduced: Bool

        /// At rest: all expanded (0) or all collapsed (1).
        static func rest(collapsed: Bool) -> Frame {
            let amount = collapsed ? 1.0 : 0.0
            return Frame(
                maybeLater: amount, turnOnLocation: amount, body: amount, preview: amount,
                compass: amount, card: amount, avatar: amount, rowText: amount, chevron: amount,
                isReduced: false
            )
        }

        // MARK: Drawn values

        /// The prompt's buttons and body fade and drop 10 pt.
        func promptOpacity(_ amount: Double) -> Double { 1 - amount }
        func promptOffsetY(_ amount: Double) -> CGFloat {
            isReduced ? 0 : LocationOffCardMotion.promptDrop * amount
        }

        var previewOpacity: Double { 1 - preview }

        /// The ring's scale toward the avatar's 52 / 180.
        var compassScale: CGFloat {
            isReduced ? 1 : 1 + (LocationOffCardMotion.compassEndScale - 1) * compass
        }

        /// How far along its travel to the avatar the ring is, 0...1.
        var compassTravel: CGFloat { isReduced ? 0 : compass }

        /// Holds at 1 until 60% of the move, then fades out with the rest.
        /// Reduce Motion: fades with the prompt.
        var compassOpacity: Double {
            if isReduced { return 1 - compass }
            let hold = LocationOffCardMotion.compassFadeFrom
            return compass <= hold ? 1 : max(0, 1 - (compass - hold) / (1 - hold))
        }

        /// From the expanded corner radius to the collapsed one.
        func cornerRadius(expanded: CGFloat, collapsed: CGFloat) -> CGFloat {
            expanded + (collapsed - expanded) * card
        }

        /// From the expanded height to the collapsed one.
        func height(expanded: CGFloat, collapsed: CGFloat) -> CGFloat {
            expanded + (collapsed - expanded) * card
        }

        var avatarOpacity: Double { avatar }
        var avatarScale: CGFloat {
            isReduced ? 1 : LocationOffCardMotion.avatarStartScale + (1 - LocationOffCardMotion.avatarStartScale) * avatar
        }
        var rowTextOpacity: Double { rowText }
        var rowTextOffsetX: CGFloat {
            isReduced ? 0 : LocationOffCardMotion.rowTextShift * (1 - rowText)
        }
        var chevronOpacity: Double { chevron }
    }

    // MARK: - Constants (§5.3)

    /// The collapse runs this long; the expand is its mirror, as long.
    static let duration: TimeInterval = 0.74

    /// Reduce Motion: one 200 ms crossfade, with the height on the same clock.
    static let reducedDuration: TimeInterval = 0.2

    /// cubic-bezier(0.32, 0.72, 0, 1), iOS's ease-out, for every track.
    static let curve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.32, y: 0.72),
        endControlPoint: UnitPoint(x: 0, y: 1)
    )

    /// The prompt's buttons and body drop this far as they fade.
    static let promptDrop: CGFloat = 10
    /// The ring ends at the avatar's size: `CompassGuideRow.avatarSize` (52)
    /// over `CompassGhost.artSize` (180), 0.2889. Spelled out: those are the
    /// views' (main-actor) constants; a test checks they still match.
    static let compassEndScale: CGFloat = 52.0 / 180.0
    /// The ring holds full opacity until this much of its move.
    static let compassFadeFrom = 0.6
    /// The avatar grows from this as it fades in.
    static let avatarStartScale: CGFloat = 0.85
    /// The row's text slides in from this far left.
    static let rowTextShift: CGFloat = -8

    private static let millisecond: TimeInterval = 0.001

    /// The collapse, from TRANSITION.md: start and duration in ms. The
    /// mock's title track (60 / 180) is dropped with the title.
    static let collapseTable: [Track: Timing] = [
        .maybeLater: timing(0, 180),
        .turnOnLocation: timing(20, 180),
        .body: timing(40, 180),
        .preview: timing(0, 140),
        .compass: timing(60, 560),
        .card: timing(60, 560),
        .avatar: timing(400, 320),
        .rowText: timing(440, 300),
        .chevron: timing(480, 260),
    ]

    private static func timing(_ startMilliseconds: Double, _ durationMilliseconds: Double) -> Timing {
        Timing(start: startMilliseconds * millisecond, duration: durationMilliseconds * millisecond)
    }

    // MARK: - Timing

    /// The whole swap's length.
    static func totalDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? reducedDuration : duration
    }

    /// When `track` runs. Expand mirrors the collapse: each track starts at
    /// 740 − (start + duration). Reduce Motion: every track over 0...200 ms.
    static func timing(of track: Track, _ direction: Direction, reduceMotion: Bool) -> Timing {
        if reduceMotion { return Timing(start: 0, duration: reducedDuration) }
        let collapse = collapseTable[track] ?? Timing(start: 0, duration: duration)
        switch direction {
        case .collapse:
            return collapse
        case .expand:
            return Timing(start: duration - collapse.end, duration: collapse.duration)
        }
    }

    /// How collapsed `track` looks `elapsed` seconds in: the curve run
    /// forward over its own window, from expanded to collapsed (or back, for
    /// expand, with from and to swapped). Clamped, so before its start and
    /// after its end it holds.
    static func amount(of track: Track, _ direction: Direction, at elapsed: TimeInterval, reduceMotion: Bool) -> Double {
        let window = timing(of: track, direction, reduceMotion: reduceMotion)
        let linear = min(max((elapsed - window.start) / window.duration, 0), 1)
        let eased = curve.value(at: linear)
        return direction == .collapse ? eased : 1 - eased
    }

    /// Every track at `elapsed` seconds into the swap.
    static func frame(_ direction: Direction, at elapsed: TimeInterval, reduceMotion: Bool) -> Frame {
        func value(_ track: Track) -> Double {
            amount(of: track, direction, at: elapsed, reduceMotion: reduceMotion)
        }
        return Frame(
            maybeLater: value(.maybeLater),
            turnOnLocation: value(.turnOnLocation),
            body: value(.body),
            preview: value(.preview),
            compass: value(.compass),
            card: value(.card),
            avatar: value(.avatar),
            rowText: value(.rowText),
            chevron: value(.chevron),
            isReduced: reduceMotion
        )
    }
}
