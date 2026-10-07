//
//  LocationLoader.swift
//  moonbeam-app
//

import Foundation
import Observation
import os

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
        /// Found after a recovery (§10.4, §11.2.3): the line and city, near
        /// the end of the moon's ride to the real phase.
        case aha(AhaGreeting)

        var isAha: Bool {
            if case .aha = self { return true }
            return false
        }
    }

    // MARK: - Timings (§10.2, §10.3; the handoff's "Entrance" and "Search → message")

    /// The label follows the moon in by this much.
    nonisolated static let labelEntranceDelay: TimeInterval = 0.32

    /// Searching shows at least this long before any message, even when the
    /// reason is already known, so the app is seen to look first.
    nonisolated static let minimumSearchBeforeMessage: TimeInterval = 1.2

    /// Back from a message, the label comes in this long after it's gone.
    nonisolated static let resumeLabelDelay: TimeInterval = 0.2

    // MARK: - Timings (§10.4; the handoff's "Search → Aha → city")

    /// After a recovery, searching shows at least this long before "Aha",
    /// so a fast fix never flashes the label. Counted from the start of the
    /// search session (the Try again or return from Settings), not from the
    /// label's return 0.2 s later (§11.2.1). The handoff's 1.8 s made Aha
    /// late (Tessa, 2026-10-06).
    nonisolated static let minimumSearchBeforeAha: TimeInterval = 0.7

    /// "Aha" never starts fading in sooner than this after the label starts
    /// leaving, so the two overlap rather than collide (§11.2.1).
    nonisolated static let ahaFadeInDelay: TimeInterval = 0.15

    /// "Aha" starts fading in this long before the moon lands (§11.2.3), so
    /// it's fully in about 0.4 s before the landing.
    nonisolated static let ahaLeadBeforeLanding: TimeInterval = 1.0

    /// For the ride's start speed: the cycle's speed is read over this
    /// much month time. Far below a frame.
    nonisolated static let speedSampleInterval: TimeInterval = 1e-3

    /// Reduce Motion, with no ride: "Aha" holds this long before the
    /// screen.
    nonisolated static let ahaHold: TimeInterval = 2.0

    /// The fly into the card's phase slot.
    nonisolated static let flightDuration: TimeInterval = 0.85

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
    /// message once the label is back.
    private(set) var searchStartedAt: Date = .distantPast

    /// When the search session started: the entrance, or the moment a
    /// return from a message began (Try again, back from Settings). Aha's
    /// label minimum counts from here (§11.2.1).
    private(set) var sessionStartedAt: Date = .distantPast

    /// After a recovery's fix, the moon's run on to the real phase (§11.2.3);
    /// `nil` before, and with Reduce Motion.
    private(set) var ride: PhaseRide?

    /// When the moon started flying into the card after "Aha" (§10.4);
    /// `nil` once it has landed, or if it never flew. The screen is up
    /// under it meanwhile.
    private(set) var flightStartedAt: Date?

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
        sessionStartedAt = date
        ride = nil
        content = .searching
        moon = .entrance(at: date)
        glow = .breathing
        showsLabel = true
        flightStartedAt = nil
    }

    /// Search → message (§10.3): searching for at least 1.2 s, then the moon
    /// runs forward to the hold phase and freezes, the glow pulses, the label
    /// goes and the message comes in. Already on a message (Don't Allow
    /// after First ask), the message just changes.
    ///
    /// A reason known before the cycle starts (permission off at launch)
    /// keeps the moon at the hold phase: started, it would be just past the
    /// hold at 1.2 s and spin a whole month at 2.6× to get back, ~3.3 s to
    /// the message (Tessa, 2026-10-06). Held, the message is in at ~1.55 s.
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

        let date = now()
        if moon.isWaitingToStart(at: date) {
            moon = .held(at: PhaseCycle.holdElapsed, since: date)
        }

        let searched = date.timeIntervalSince(searchStartedAt)
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
        sessionStartedAt = date
        ride = nil
        content = .searching
        glow = glow.switching(to: .breathe, at: date, elapsed: moon.elapsed(at: date))
        guard await wait(Self.resumeLabelDelay, step: step) else { return false }

        let resumed = now()
        showsLabel = true
        searchStartedAt = resumed
        moon = moon.running(from: resumed)
        return true
    }

    /// Search → Aha (§10.4, §11.2.3), only after a recovery. Call it as the
    /// fix lands. The moon rides on to `realPhase` (the card's glyph) at
    /// once, at the cycle's speed, easing to rest; the label leaves as soon
    /// as the session has had its 0.7 s; "Aha" floats up 1 s before the
    /// landing; the moon rests 0.6 s, then it's time to fly.
    ///
    /// - Parameters:
    ///   - realPhase: the phase the card will show; `nil` (no moon table)
    ///     means no ride, and "Aha" just holds.
    ///   - extraLap: the first ride after install goes a lap further.
    ///   - reducesMotion: no ride; "Aha" holds and the view cross-fades
    ///     the moon to the real phase.
    /// - Returns: false if another step took over meanwhile. True means
    ///   it's time to fly (`flyAway()`).
    @discardableResult
    func showAha(
        _ greeting: AhaGreeting,
        realPhase: PhaseGlyphGeometry?,
        extraLap: Bool = false,
        reducesMotion: Bool = false
    ) async -> Bool {
        generation += 1
        let step = generation
        let fixDate = now()
        let labelWait = max(0, Self.minimumSearchBeforeAha - fixDate.timeIntervalSince(sessionStartedAt))
        let labelLeaves = fixDate.addingTimeInterval(labelWait)

        guard let realPhase, !reducesMotion else {
            guard await wait(labelWait, step: step) else { return false }
            leaveLabel()
            content = .aha(greeting)
            return await wait(Self.ahaHold, step: step)
        }

        let ride = PhaseRide(
            from: PhaseCycle.phase(at: moon.elapsed(at: fixDate)),
            to: PhaseRide.phase(of: realPhase),
            extraLap: extraLap,
            startSpeed: cycleSpeed(at: fixDate),
            startingAt: fixDate
        )
        self.ride = ride
        let ahaStart = max(
            ride.endDate.addingTimeInterval(-Self.ahaLeadBeforeLanding),
            labelLeaves.addingTimeInterval(Self.ahaFadeInDelay)
        )

        guard await wait(labelWait, step: step) else { return false }
        leaveLabel()
        guard await wait(ahaStart.timeIntervalSince(labelLeaves), step: step) else { return false }
        content = .aha(greeting)
        let flight = max(ride.endDate.addingTimeInterval(PhaseRide.restBeat), ahaStart)
        return await wait(flight.timeIntervalSince(ahaStart), step: step)
    }

    /// "Finding your location…" goes, for "Aha".
    private func leaveLabel() {
        LaunchSignposts.signposter.emitEvent("Aha label leaving")
        showsLabel = false
    }

    /// How fast the cycle is moving through the phases at `date`, phases per
    /// second: the ride starts at this speed.
    private func cycleSpeed(at date: Date) -> Double {
        let later = date.addingTimeInterval(Self.speedSampleInterval)
        let step = PhaseCycle.phase(at: moon.elapsed(at: later)) - PhaseCycle.phase(at: moon.elapsed(at: date))
        let forward = step < 0 ? step + 1 : step
        return forward / Self.speedSampleInterval
    }

    /// The moon leaves for the card's phase slot (§10.4). The caller brings
    /// the screen up under it in the same turn.
    func flyAway() {
        generation += 1
        flightStartedAt = now()
    }

    /// The flying moon has settled in the card.
    func didLand() {
        flightStartedAt = nil
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
