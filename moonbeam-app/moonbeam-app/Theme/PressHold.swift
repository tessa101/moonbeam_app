//
//  PressHold.swift
//  moonbeam-app
//

import Foundation

/// When the shared pressed look shows (STEP-5.13 §4, DECISIONS.md
/// 2026-10-14/15 "Tap feedback"). A quick tap lifts the finger within a frame
/// or two, so following `isPressed` alone hides the look before anyone sees
/// it. The look therefore stays on for at least `minimum` after the finger
/// goes down, and for as long as it stays down after that.
///
/// Only the look is held: the button's action still fires on release, from
/// SwiftUI, untouched by this.
///
/// A value type driven by three events so the rule is testable without a
/// view or a clock. `PressFeedback` feeds it and schedules the timer.
struct PressHold: Equatable {

    /// The shortest time the pressed look shows, however quick the tap.
    static let minimum = Duration.milliseconds(100)

    /// Whether the pressed look shows now.
    private(set) var showsPressedLook = false
    private var isDown = false
    private var minimumElapsed = false
    /// Counts presses, so a timer from an earlier press can't end a later one.
    private(set) var cycle = 0

    /// The finger went down. Returns the cycle to pass to `minimumPassed(cycle:)`
    /// once `minimum` has passed.
    mutating func fingerDown() -> Int {
        cycle += 1
        isDown = true
        minimumElapsed = false
        showsPressedLook = true
        return cycle
    }

    /// The finger lifted (or the press was cancelled). Ends the look only if
    /// the minimum has already passed.
    mutating func fingerUp() {
        isDown = false
        if minimumElapsed {
            showsPressedLook = false
        }
    }

    /// `minimum` has passed since `fingerDown()` returned `cycle`. Ends the
    /// look if the finger has already lifted; a stale cycle is ignored.
    mutating func minimumPassed(cycle: Int) {
        guard cycle == self.cycle else { return }
        minimumElapsed = true
        if !isDown {
            showsPressedLook = false
        }
    }
}
