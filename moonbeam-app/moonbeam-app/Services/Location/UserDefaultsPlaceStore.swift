//
//  UserDefaultsPlaceStore.swift
//  moonbeam-app
//

import Foundation

/// `PlaceStore` backed by `UserDefaults`.
///
/// A handful of places is a few hundred bytes, read once at launch —
/// `UserDefaults` is the right size of tool, and avoids a schema
/// (ARCHITECTURE.md §6 reserved SwiftData for saved places, which V1 doesn't
/// have).
///
/// `lastViewed` and recents live under separate keys: `lastViewed` can be a
/// detected place and recents can't, so one list can't serve both
/// (SEARCH-RECENTS.md §8).
final class UserDefaultsPlaceStore: PlaceStore {

    // MARK: - Constants

    /// Still a JSON array capped at one, as before recents existed, so
    /// launch logic reads exactly what it always has.
    private static let lastViewedKey = "lastViewedPlaces"
    private static let maximumLastViewed = 1

    /// Its *absence* is what marks a store that predates recents; see
    /// `migrateRecentsIfNeeded()`.
    private static let recentsKey = "recentPlaces"

    // MARK: - State

    private let defaults: UserDefaults

    /// Injectable so tests get their own suite instead of scribbling on the
    /// app's, and so "survives a relaunch" can be tested by building a second
    /// store over the same suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateRecentsIfNeeded()
    }

    // MARK: - PlaceStore

    var lastViewed: Place? {
        get { storedPlaces(forKey: Self.lastViewedKey).first }
        set {
            guard let newValue else {
                setStoredPlaces([], forKey: Self.lastViewedKey)
                return
            }
            var places = storedPlaces(forKey: Self.lastViewedKey).filter { $0 != newValue }
            places.insert(newValue, at: 0)
            setStoredPlaces(Array(places.prefix(Self.maximumLastViewed)), forKey: Self.lastViewedKey)
        }
    }

    var recents: [Place] {
        get { storedPlaces(forKey: Self.recentsKey) }
        set { setStoredPlaces(newValue, forKey: Self.recentsKey) }
    }

    // MARK: - Migration

    /// First run after the recents update: seed recents with the existing
    /// `lastViewed`, so the user isn't greeted by an empty list.
    ///
    /// Whether that place was detected can't be known (`isCurrentLocation`
    /// isn't persisted), so it's seeded regardless (SEARCH-RECENTS.md §4, §8).
    /// The key is written even when empty so this runs once.
    private func migrateRecentsIfNeeded() {
        guard defaults.object(forKey: Self.recentsKey) == nil else { return }
        recents = lastViewed.map { [$0] } ?? []
    }

    // MARK: - Storage

    /// Unreadable stored data is treated as empty rather than fatal: a stale
    /// or corrupt entry should cost the user their saved cities, not the
    /// launch.
    private func storedPlaces(forKey key: String) -> [Place] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Place].self, from: data)) ?? []
    }

    private func setStoredPlaces(_ places: [Place], forKey key: String) {
        guard let data = try? JSONEncoder().encode(places) else { return }
        defaults.set(data, forKey: key)
    }
}
