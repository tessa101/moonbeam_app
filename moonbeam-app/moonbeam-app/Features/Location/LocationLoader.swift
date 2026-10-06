//
//  LocationLoader.swift
//  moonbeam-app
//

import Foundation
import Observation

/// The loader screen's moon, glow, label and message (LOADER.md §10): what
/// `LaunchPhaseCycle` draws, and the timing between its steps.
///
/// `LocationViewModel` decides *what* the loader is for (searching, which
/// message); this decides how it moves from one to the next. Its waits come
/// through an injected `sleep` and its clock through `now`, as in
/// `LocationViewModel`, so tests step through it.
///
/// Each step supersedes the one before: a step still waiting when another
/// starts (or the loader ends) stops there, so a late wait never puts back a
/// message the user has moved past.
@Observable
final class LocationLoader {

    // MARK: - Types

    enum Content: Equatable {
        /// "Finding your location…" (when `showsLabel`).
        case searching
        /// Stopped, with a message (§10.3).
        case message(LocationIssue)
    }

    // MARK: - Timings (§10.2, §10.3; the handoff's "Entrance" and "Search → message")

    /// The label follows the moon in by this much.
    nonisolated static let labelEntranceDelay: TimeInterval = 0.32

    /// Searching shows at least this long before any message, even when the
    /// reason is already known, so the app is seen to look first.
    nonisolated static let minimumSearchBeforeMessage: TimeInterval = 1.2

    /// Back from a message, the label comes in this long after it's gone.
    nonisolated static let resumeLabelDelay: TimeInterval = 0.2

    // MARK: - Observed state

    private(set) var content: Content = .searching

    /// The moon's month over time.
    private(set) var moon: MoonMotion = .held(at: PhaseCycle.holdElapsed, since: .distantPast)

    /// The glow behind it.
    private(set) var glow: LoaderGlow = .breathing

    /// "Finding your location…" is up (or on its way in).
    private(set) var showsLabel = false

    /// When the loader last appeared: the entrance's time zero.
    private(set) var appearedAt: Date = .distantPast

    /// When searching last started: the entrance, or a return from a
    /// message.
    private(set) var searchStartedAt: Date = .distantPast

    // MARK: - Dependencies

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    /// Bumped by every step; a waiting step that sees it change stops.
    @ObservationIgnored private var generation = 0

    init(
        now: @escaping () -> Date = Date.init,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.now = now
        self.sleep = sleep
    }

    // MARK: - Steps

    /// The entrance (§10.2): the moon appears at the hold phase, the label
    /// follows, and the cycle starts 840 ms in. Every time the loader shows.
    func appear() {
        generation += 1
        let date = now()
        appearedAt = date
        searchStartedAt = date
        content = .searching
        moon = .entrance(at: date)
        glow = .breathing
        showsLabel = true
    }

    /// Search → message (§10.3): searching for at least 1.2 s, then the moon
    /// runs forward to the hold phase and freezes, the glow pulses, the label
    /// goes and the message comes in. Already on a message (Don't Allow
    /// after First ask), the message just changes.
    ///
    /// - Returns: false if another step took over meanwhile.
    @discardableResult
    func showMessage(_ issue: LocationIssue) async -> Bool {
        generation += 1
        let step = generation
        if case .message = content {
            content = .message(issue)
            return true
        }

        let searched = now().timeIntervalSince(searchStartedAt)
        guard await wait(Self.minimumSearchBeforeMessage - searched, step: step) else { return false }

        let stopDate = now()
        moon = moon.stopping(at: PhaseCycle.holdElapsed, from: stopDate)
        guard await wait(moon.timeToSettle(from: stopDate), step: step) else { return false }

        let frozen = now()
        glow = glow.switching(to: .pulse, at: frozen, elapsed: moon.elapsed(at: frozen))
        showsLabel = false
        content = .message(issue)
        return true
    }

    /// Return after a fix (§10.3, the handoff's "gone instantly"): the
    /// message goes at once, the glow breathes again, and 0.2 s later the
    /// label comes back and the cycle resumes.
    ///
    /// - Returns: false if another step took over meanwhile.
    @discardableResult
    func resume() async -> Bool {
        generation += 1
        let step = generation
        let date = now()
        content = .searching
        glow = glow.switching(to: .breathe, at: date, elapsed: moon.elapsed(at: date))
        guard await wait(Self.resumeLabelDelay, step: step) else { return false }

        let resumed = now()
        showsLabel = true
        searchStartedAt = resumed
        moon = moon.running(from: resumed)
        return true
    }

    /// The loader is going: any step still waiting stops.
    func end() {
        generation += 1
    }

    // MARK: - Waiting

    /// Sleeps `seconds` (none if not positive), then reports whether `step`
    /// is still the latest.
    private func wait(_ seconds: TimeInterval, step: Int) async -> Bool {
        if seconds > 0 {
            do {
                try await sleep(.seconds(seconds))
            } catch {
                return false
            }
        }
        return step == generation
    }
}
