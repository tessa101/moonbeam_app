//
//  PlaceStore.swift
//  moonbeam-app
//

import Foundation

/// Remembers the place the user last looked at, so a relaunch has somewhere to
/// start (LOCATION.md §3, §6), and the cities they've recently picked
/// (SEARCH-RECENTS.md §3).
///
/// The two are separate lists because `lastViewed` can be a detected place
/// and recents never can.
///
/// Class-only: a store is shared storage, not a value, and it lets the
/// recents helpers below be called through a `let` reference.
protocol PlaceStore: AnyObject {
    /// May be a detected place ("Use my location" saves it).
    var lastViewed: Place? { get set }

    /// Raw storage, most recent first. Settable so both stores share the cap
    /// and dedupe below; callers should use `addRecent` / `removeRecent`
    /// (SEARCH-RECENTS.md §8).
    var recents: [Place] { get set }
}

// MARK: - Recents

extension PlaceStore {

    /// SEARCH-RECENTS.md §3: the oldest drops off when a 9th is added.
    static var maximumRecents: Int { 8 }

    /// Puts `place` at the front, replacing any entry for the same city
    /// rather than duplicating it, then applies the cap.
    func addRecent(_ place: Place) {
        var places = recents.filter { !$0.isSameCity(as: place) }
        places.insert(place, at: 0)
        recents = Array(places.prefix(Self.maximumRecents))
    }

    /// Exact match, so a swipe removes only the row it was on.
    func removeRecent(_ place: Place) {
        recents.removeAll { $0 == place }
    }
}
