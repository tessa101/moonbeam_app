//
//  CompassContext.swift
//  moonbeam-app
//

import Foundation

/// Everything the compass needs from the rest of the screen, pushed in by
/// `LocationViewModel` whenever any of it changes.
///
/// The compass never reads location state itself: `LocationViewModel` stays
/// the only owner of the place, the day and the permission state.
///
/// `nonisolated`: an inert value.
nonisolated struct CompassContext {

    /// The place the screen shows. `nil` in the first-launch empty state.
    var place: Place?

    /// The last place location detection found this session, if any. How a
    /// searched city is matched to "where you are" (COMPASS.md §2).
    var detectedPlace: Place?

    var authState: LocationAuthState

    /// The moon table for the selected day: where moonrise and moonset
    /// targets come from, so the compass always agrees with the table.
    var moonDay: MoonDay?

    /// The selected day is the place's today. The live "Moon" target only
    /// exists then (COMPASS.md §1).
    var isToday: Bool

    /// Before `LocationViewModel` has pushed anything: nothing to show.
    static let empty = CompassContext(
        place: nil,
        detectedPlace: nil,
        authState: .notDetermined,
        moonDay: nil,
        isToday: true
    )
}
