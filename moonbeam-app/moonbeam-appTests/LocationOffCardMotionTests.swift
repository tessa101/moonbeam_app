//
//  LocationOffCardMotionTests.swift
//  moonbeam-appTests
//

import Foundation
import SwiftUI
import Testing
@testable import moonbeam_app

/// The location-off card's swap (LOCATION-OFF-FLOW.md §5.3, §5.4): the
/// collapse table, its mirror for expand, the curve, the drawn values, Reduce
/// Motion, and the phase rules (which layer, which taps, what VoiceOver
/// reads).
@Suite("Location-off card motion", .timeLimit(.minutes(1)))
@MainActor
struct LocationOffCardMotionTests {

    private typealias Motion = LocationOffCardMotion

    // MARK: - Table

    @Test("The collapse table is the handoff's, in ms, less the title track")
    func collapseTable() {
        func ms(_ track: Motion.Track) -> (Int, Int) {
            let timing = Motion.timing(of: track, .collapse, reduceMotion: false)
            return (Int((timing.start * 1000).rounded()), Int((timing.duration * 1000).rounded()))
        }
        #expect(ms(.maybeLater) == (0, 180))
        #expect(ms(.turnOnLocation) == (20, 180))
        #expect(ms(.body) == (40, 180))
        #expect(ms(.preview) == (0, 140))
        #expect(ms(.compass) == (60, 560))
        #expect(ms(.card) == (60, 560))
        #expect(ms(.avatar) == (400, 320))
        #expect(ms(.rowText) == (440, 300))
        #expect(ms(.chevron) == (480, 260))
        #expect(Motion.Track.allCases.count == 9)
    }

    @Test("About 740 ms: every track ends by then, and the last ones at it")
    func totalDuration() {
        #expect(Motion.totalDuration(reduceMotion: false) == 0.74)
        let ends = Motion.Track.allCases.map { Motion.timing(of: $0, .collapse, reduceMotion: false).end }
        #expect(ends.allSatisfy { $0 <= 0.74 + 1e-9 })
        #expect(abs((ends.max() ?? 0) - 0.74) < 1e-9)
    }

    @Test("Expand mirrors the collapse: start at 740 − (start + duration), same duration")
    func expandMirrors() {
        for track in Motion.Track.allCases {
            let collapse = Motion.timing(of: track, .collapse, reduceMotion: false)
            let expand = Motion.timing(of: track, .expand, reduceMotion: false)
            #expect(abs(expand.start - (0.74 - collapse.end)) < 1e-9)
            #expect(expand.duration == collapse.duration)
        }
        // Chevron and text go first, Maybe later comes in last.
        #expect(Motion.timing(of: .chevron, .expand, reduceMotion: false).start == 0)
        #expect(abs(Motion.timing(of: .maybeLater, .expand, reduceMotion: false).start - 0.56) < 1e-9)
        #expect(abs(Motion.timing(of: .compass, .expand, reduceMotion: false).start - 0.12) < 1e-9)
    }

    // MARK: - Curve and amounts

    @Test("Every track uses cubic-bezier(0.32, 0.72, 0, 1): fast out, slow in")
    func curve() {
        #expect(Motion.curve.value(at: 0) == 0)
        #expect(abs(Motion.curve.value(at: 1) - 1) < 1e-9)
        // An ease-out: well past half-way at half time.
        #expect(Motion.curve.value(at: 0.5) > 0.8)
        #expect(Motion.curve.value(at: 0.1) > 0.25)
    }

    @Test("A track holds before its start and after its end")
    func clampsOutsideItsWindow() {
        #expect(Motion.amount(of: .avatar, .collapse, at: 0.2, reduceMotion: false) == 0)
        #expect(Motion.amount(of: .avatar, .collapse, at: 0.9, reduceMotion: false) == 1)
        #expect(Motion.amount(of: .maybeLater, .collapse, at: 0.3, reduceMotion: false) == 1)
    }

    @Test("Collapse goes 0 → 1 and expand 1 → 0, on the same curve")
    func directions() {
        let midCompass = 0.06 + 0.28
        let collapse = Motion.amount(of: .compass, .collapse, at: midCompass, reduceMotion: false)
        #expect(abs(collapse - Motion.curve.value(at: 0.5)) < 1e-9)
        let expandMid = 0.12 + 0.28
        let expand = Motion.amount(of: .compass, .expand, at: expandMid, reduceMotion: false)
        #expect(abs(expand - (1 - Motion.curve.value(at: 0.5))) < 1e-9)
        #expect(Motion.frame(.collapse, at: 0, reduceMotion: false).card == 0)
        #expect(Motion.frame(.collapse, at: 0.74, reduceMotion: false) == .rest(collapsed: true).withReduced(false))
        #expect(Motion.frame(.expand, at: 0.74, reduceMotion: false) == .rest(collapsed: false).withReduced(false))
    }

    @Test("Frames change smoothly: no track jumps between 60 fps frames")
    func noJumps() {
        let step = 1.0 / 60
        for direction in [Motion.Direction.collapse, .expand] {
            var previous = Motion.frame(direction, at: 0, reduceMotion: false)
            var time = step
            while time <= 0.76 {
                let frame = Motion.frame(direction, at: time, reduceMotion: false)
                for (a, b) in zip(previous.amounts, frame.amounts) {
                    // The steepest step is the first frame of the shortest
                    // track (PREVIEW's 140 ms fade) on the ease-out: about
                    // 42% of that fade. A cut would be 100%.
                    #expect(abs(a - b) < 0.5)
                }
                // The height, which moves the layout below: the curve's
                // steepest 60 fps step on its 560 ms window is 12.4% of the
                // travel (5 frames in; about 38 pt of 303), so it glides
                // over some 34 frames rather than cutting.
                #expect(abs(previous.card - frame.card) < 0.13)
                previous = frame
                time += step
            }
        }
    }

    // MARK: - Drawn values

    @Test("The ring scales 1 → 52/180 and travels the whole way")
    func compassScaleAndTravel() {
        let start = Motion.Frame.rest(collapsed: false)
        let end = Motion.Frame.rest(collapsed: true)
        #expect(start.compassScale == 1)
        #expect(abs(end.compassScale - 52.0 / 180.0) < 1e-9)
        #expect(abs(Motion.compassEndScale - CompassGuideRow.avatarSize / CompassGhost.artSize) < 1e-9)
        #expect(start.compassTravel == 0)
        #expect(end.compassTravel == 1)
    }

    @Test("The ring holds full opacity until 60% of its move, then fades")
    func compassFade() {
        var frame = Motion.Frame.rest(collapsed: false)
        frame.compass = 0.6
        #expect(frame.compassOpacity == 1)
        frame.compass = 0.8
        #expect(abs(frame.compassOpacity - 0.5) < 1e-9)
        frame.compass = 1
        #expect(frame.compassOpacity == 0)
    }

    @Test("Prompt pieces fade and drop 10 pt; the avatar grows from 0.85; the text slides in from −8")
    func drawnValues() {
        let half = Motion.Frame(
            maybeLater: 0.5, turnOnLocation: 0.5, body: 0.5, preview: 0.5, compass: 0.5,
            card: 0.5, avatar: 0.5, rowText: 0.5, chevron: 0.5, isReduced: false
        )
        #expect(half.promptOpacity(half.body) == 0.5)
        #expect(half.promptOffsetY(half.body) == 5)
        #expect(abs(half.avatarScale - 0.925) < 1e-9)
        #expect(half.rowTextOffsetX == -4)
        #expect(half.height(expanded: 381, collapsed: 78) == 229.5)
        #expect(half.cornerRadius(expanded: 24, collapsed: 20) == 22)
    }

    // MARK: - Reduce Motion

    @Test("Reduce Motion: a 200 ms crossfade plus the height; no scale, travel or offsets")
    func reduceMotion() {
        #expect(Motion.totalDuration(reduceMotion: true) == 0.2)
        for track in Motion.Track.allCases {
            #expect(Motion.timing(of: track, .collapse, reduceMotion: true) == .init(start: 0, duration: 0.2))
        }
        let mid = Motion.frame(.collapse, at: 0.1, reduceMotion: true)
        #expect(mid.compassScale == 1)
        #expect(mid.compassTravel == 0)
        #expect(mid.promptOffsetY(mid.body) == 0)
        #expect(mid.rowTextOffsetX == 0)
        #expect(mid.avatarScale == 1)
        #expect(mid.card > 0 && mid.card < 1)
        #expect(abs(mid.compassOpacity - (1 - mid.compass)) < 1e-9)
    }

    // MARK: - Phase

    @Test("At rest: one layer, its taps live, VoiceOver on it")
    func restPhases() {
        let expanded = LocationOffCardPhase.rest(collapsed: false)
        #expect(expanded.isPromptInteractive && !expanded.isRowInteractive)
        #expect(expanded.drawsPrompt && expanded.promptIsAccessible && !expanded.rowIsAccessible)
        let collapsed = LocationOffCardPhase.rest(collapsed: true)
        #expect(!collapsed.isPromptInteractive && collapsed.isRowInteractive)
        #expect(!collapsed.drawsPrompt && !collapsed.promptIsAccessible && collapsed.rowIsAccessible)
    }

    @Test("Mid-swap: no taps anywhere, VoiceOver only on the arriving layer")
    func swapPhases() {
        let now = Date(timeIntervalSince1970: 1000)
        let collapsing = LocationOffCardPhase.swap(toCollapsed: true, at: now)
        #expect(!collapsing.isPromptInteractive && !collapsing.isRowInteractive)
        #expect(collapsing.drawsPrompt && !collapsing.promptIsAccessible && collapsing.rowIsAccessible)
        let expanding = LocationOffCardPhase.swap(toCollapsed: false, at: now)
        #expect(!expanding.isPromptInteractive && !expanding.isRowInteractive)
        #expect(expanding.drawsPrompt && expanding.promptIsAccessible && !expanding.rowIsAccessible)
    }

    @Test("A swap runs from its start, finishes at 740 ms, and settles where it was going")
    func swapTimeline() {
        let now = Date(timeIntervalSince1970: 1000)
        let collapsing = LocationOffCardPhase.swap(toCollapsed: true, at: now)
        #expect(collapsing.frame(at: now, reduceMotion: false).card == 0)
        #expect(!collapsing.isFinished(at: now.addingTimeInterval(0.739), reduceMotion: false))
        #expect(collapsing.isFinished(at: now.addingTimeInterval(0.74), reduceMotion: false))
        #expect(collapsing.isFinished(at: now.addingTimeInterval(0.2), reduceMotion: true))
        #expect(collapsing.settled == .collapsed)
        #expect(LocationOffCardPhase.swap(toCollapsed: false, at: now).settled == .expanded)
        #expect(LocationOffCardPhase.expanded.frame(at: now, reduceMotion: false) == .rest(collapsed: false))
    }
}

private extension LocationOffCardMotion.Frame {
    var amounts: [Double] {
        [maybeLater, turnOnLocation, body, preview, compass, card, avatar, rowText, chevron]
    }

    func withReduced(_ reduced: Bool) -> Self {
        var copy = self
        copy.isReduced = reduced
        return copy
    }
}
