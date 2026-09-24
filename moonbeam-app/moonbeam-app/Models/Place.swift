//
//  Place.swift
//  moonbeam-app
//

import Foundation

/// A location the moon table is calculated for, with the time zone used for
/// every user-facing time in that table.
///
/// `nonisolated` like the rest of the domain layer: it's an inert value, so it
/// shouldn't inherit main-actor isolation from
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
nonisolated struct Place: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
}
