//
//  UserDefaultsPlaceStore.swift
//  moonbeam-app
//

import Foundation

/// `PlaceStore` backed by `UserDefaults`.
///
/// One place is a few dozen bytes, read once at launch — `UserDefaults` is the
/// right size of tool, and avoids a schema (ARCHITECTURE.md §6 reserved
/// SwiftData for saved places, which V1 doesn't have).
///
/// Stored as a JSON **array** even though V1 only ever keeps one entry, so the
/// recent-searches feature deferred in §2 becomes a cap change rather than a
/// migration.
final class UserDefaultsPlaceStore: PlaceStore {

    // MARK: - Constants

    private static let storageKey = "lastViewedPlaces"

    /// V1 keeps one. Raising this is the whole of the recents feature's
    /// storage change.
    private static let maximumStoredPlaces = 1

    // MARK: - State

    private let defaults: UserDefaults

    /// Injectable so tests get their own suite instead of scribbling on the
    /// app's, and so "survives a relaunch" can be tested by building a second
    /// store over the same suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - PlaceStore

    var lastViewed: Place? {
        get { storedPlaces.first }
        set {
            guard let newValue else {
                storedPlaces = []
                return
            }
            // Moves an existing entry to the front rather than duplicating it,
            // which is the behaviour recents will want.
            var places = storedPlaces.filter { $0 != newValue }
            places.insert(newValue, at: 0)
            storedPlaces = Array(places.prefix(Self.maximumStoredPlaces))
        }
    }

    // MARK: - Storage

    /// Unreadable stored data is treated as empty rather than fatal: a stale
    /// or corrupt entry should cost the user their last city, not the launch.
    private var storedPlaces: [Place] {
        get {
            guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
            return (try? JSONDecoder().decode([Place].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
