//
//  LocationLoader.swift
//  moonbeam-app
//

import Foundation
import Observation

/// The loader screen's moon, glow and label (LOADER.md §10.2): what
/// `LaunchPhaseCycle` draws, and the timing between its steps.
///
/// `LocationViewModel` decides *what* the loader is for; this decides how it
/// moves. Its waits come through an injected `sleep` and its clock through
/// `now`, as in `LocationViewModel`, so tests step through it.
@Observable
final class LocationLoader {

    // MARK: - Timings (§10.2, the handoff's "Entrance")

    /// The label follows the moon in by this much.
    nonisolated static let labelEntranceDelay: TimeInterval = 0.32

    // MARK: - Observed state

    /// The moon's month over time.
    private(set) var moon: MoonMotion = .held(at: PhaseCycle.holdElapsed, since: .distantPast)

    /// The glow behind it.
    private(set) var glow: LoaderGlow = .breathing

    /// "Finding your location…" is up (or on its way in).
    private(set) var showsLabel = false

    /// When the loader last appeared: the entrance's time zero.
    private(set) var appearedAt: Date = .distantPast

    // MARK: - Dependencies

    @ObservationIgnored private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    // MARK: - Steps

    /// The entrance (§10.2): the moon appears at the hold phase, the label
    /// follows, and the cycle starts 840 ms in. Every time the loader shows.
    func appear() {
        let date = now()
        appearedAt = date
        moon = .entrance(at: date)
        glow = .breathing
        showsLabel = true
    }
}
