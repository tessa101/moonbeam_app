//
//  LaunchStage.swift
//  moonbeam-app
//

import Foundation

/// What the main screen shows while the launch location fetch runs
/// (LOADER.md §2): nothing, then the phase-cycle loader, then the screen.
///
/// The fetch is the only wait at launch (moon data is computed on the
/// device), so the stage follows the fetch alone. `LocationViewModel`
/// moves it; the screen only draws it.
///
/// `nonisolated`: a plain value with constants, usable off the main actor.
nonisolated enum LaunchStage: Equatable {
    /// The first 400 ms of a fetch: plain background, so a fast fix never
    /// flashes a loader.
    case waiting
    /// The fetch has run past 400 ms: the centred phase-cycle moon (§3).
    case phaseCycle
    /// The real screen: sentence, card, compass.
    case ready

    // MARK: - Timings (§2.1, interim values; DECISIONS.md 2026-10-03)

    /// A fix inside this needs no loader.
    static let phaseCycleDelay = Duration.milliseconds(400)

    /// Once the phase cycle shows, it stays at least this long, so it never
    /// flashes.
    static let minimumPhaseCycleDuration = Duration.milliseconds(700)

    /// The phase cycle fades in over this, ease-out. The main screen doesn't
    /// fade as a whole: its blocks load in (`ContentLoadIn`, §2.1).
    static let fadeDuration: TimeInterval = 0.25

    /// The phase cycle fades out over this as the content loads in (§2.1).
    static let phaseCycleFadeOutDuration: TimeInterval = 0.2
}
