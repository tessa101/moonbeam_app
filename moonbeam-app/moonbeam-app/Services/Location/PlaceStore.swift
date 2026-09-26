//
//  PlaceStore.swift
//  moonbeam-app
//

import Foundation

/// Remembers the place the user last looked at, so a relaunch has somewhere to
/// start (LOCATION.md §3, §6).
///
/// V1 holds exactly one place. The protocol says so plainly rather than
/// pretending to be a list — the *storage* is already shaped as a list, so
/// adding recent searches later is a change here and not a migration.
protocol PlaceStore {
    var lastViewed: Place? { get set }
}
