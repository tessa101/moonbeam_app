//
//  PlaceStoreTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `UserDefaultsPlaceStore` (LOCATION.md §6, §7).
///
/// A `final class` rather than a struct so `deinit` can delete the throwaway
/// defaults suite each test runs against. `@MainActor` because `PlaceStore`
/// inherits the project's default isolation, like the other location services.
@Suite("UserDefaultsPlaceStore")
@MainActor
final class PlaceStoreTests {

    // MARK: - Fixtures

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    private static let marVista = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// A suite per test, so tests never see each other's writes and never
    /// touch the app's own defaults.
    private let suiteName = "PlaceStoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Round-trip

    @Test("Starts empty")
    func startsEmpty() {
        #expect(UserDefaultsPlaceStore(defaults: defaults).lastViewed == nil)
    }

    /// The time zone is the part worth guarding: it drives every displayed
    /// time (§5).
    @Test("Round-trips a place including its time zone")
    func roundTripsAPlace() throws {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.lastViewed = Self.sydney

        let stored = try #require(store.lastViewed)
        #expect(stored == Self.sydney)
        #expect(stored.timeZone.identifier == "Australia/Sydney")
        #expect(stored.region == "NSW")
        #expect(stored.country == "Australia")
    }

    /// §7: "Survives a relaunch (new store instance)."
    @Test("Survives a relaunch")
    func survivesARelaunch() throws {
        let first = UserDefaultsPlaceStore(defaults: defaults)
        first.lastViewed = Self.sydney

        let second = UserDefaultsPlaceStore(defaults: defaults)

        #expect(try #require(second.lastViewed) == Self.sydney)
    }

    /// A detected place is saved as a plain place, so a relaunch doesn't claim
    /// the user is still standing there (§6).
    @Test("A detected place is stored without its current-location flag")
    func detectedPlaceLosesItsFlag() throws {
        var detected = Self.marVista
        detected.isCurrentLocation = true

        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.lastViewed = detected

        #expect(try #require(store.lastViewed).isCurrentLocation == false)
    }

    // MARK: - Replacing and clearing

    @Test("A new place replaces the old one")
    func newPlaceReplacesOld() throws {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.lastViewed = Self.sydney
        store.lastViewed = Self.marVista

        #expect(try #require(store.lastViewed) == Self.marVista)
    }

    @Test("Setting nil clears the store")
    func settingNilClears() {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.lastViewed = Self.sydney
        store.lastViewed = nil

        #expect(store.lastViewed == nil)
        #expect(UserDefaultsPlaceStore(defaults: defaults).lastViewed == nil)
    }

    // MARK: - Robustness

    /// Unreadable data should cost the user their last city, not the launch.
    ///
    /// The key is repeated here because it's private to the store; if it's
    /// ever renamed this test stops testing anything, so rename both.
    @Test("Unreadable stored data reads as empty")
    func unreadableDataReadsAsEmpty() throws {
        defaults.set(Data("not json".utf8), forKey: "lastViewedPlaces")

        let store = UserDefaultsPlaceStore(defaults: defaults)
        #expect(store.lastViewed == nil)

        // And it recovers: writing over it works.
        store.lastViewed = Self.sydney
        #expect(try #require(store.lastViewed) == Self.sydney)
    }

    // MARK: - Recents (SEARCH-RECENTS.md §3, §5)

    /// Distinct cities a degree of longitude apart on the equator (~111 km),
    /// so none of them dedupe by distance.
    private static func cities(_ count: Int) -> [Place] {
        (0..<count).map { index in
            Place(name: "City \(index)", latitude: 0, longitude: Double(index), timeZone: .gmt)
        }
    }

    @Test("Recents start empty")
    func recentsStartEmpty() {
        #expect(UserDefaultsPlaceStore(defaults: defaults).recents.isEmpty)
    }

    @Test("Recents are most recent first")
    func recentsAreMostRecentFirst() {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.addRecent(Self.sydney)
        store.addRecent(Self.marVista)

        #expect(store.recents == [Self.marVista, Self.sydney])
    }

    @Test("Adding a 9th recent drops the oldest")
    func ninthRecentDropsOldest() {
        let places = Self.cities(UserDefaultsPlaceStore.maximumRecents + 1)
        let store = UserDefaultsPlaceStore(defaults: defaults)
        for place in places { store.addRecent(place) }

        #expect(store.recents.count == UserDefaultsPlaceStore.maximumRecents)
        #expect(store.recents.first == places.last)
        #expect(!store.recents.contains(places[0]))
    }

    @Test("Re-adding an existing recent moves it to the top without duplicating")
    func reAddingMovesToTop() {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.addRecent(Self.sydney)
        store.addRecent(Self.marVista)
        store.addRecent(Self.sydney)

        #expect(store.recents == [Self.sydney, Self.marVista])
    }

    /// The same city re-picked from search rarely has identical coordinates;
    /// the newer entry replaces the older one.
    @Test("A near-duplicate of the same city dedupes")
    func nearDuplicateDedupes() {
        // ~0.0045° of latitude is ~500 m.
        let nearbySydney = Place(
            name: "Sydney",
            locality: "Sydney",
            region: "NSW",
            country: "Australia",
            latitude: -33.8745,
            longitude: 151.21,
            timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
        )
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.addRecent(Self.sydney)
        store.addRecent(Self.marVista)
        store.addRecent(nearbySydney)

        #expect(store.recents == [nearbySydney, Self.marVista])
    }

    @Test("Removing a recent leaves the others in order")
    func removeRecent() {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.addRecent(Self.sydney)
        store.addRecent(Self.marVista)
        store.removeRecent(Self.marVista)

        #expect(store.recents == [Self.sydney])
    }

    @Test("Recents survive a relaunch, including a removal")
    func recentsSurviveARelaunch() {
        let first = UserDefaultsPlaceStore(defaults: defaults)
        first.addRecent(Self.sydney)
        first.addRecent(Self.marVista)
        first.removeRecent(Self.sydney)

        #expect(UserDefaultsPlaceStore(defaults: defaults).recents == [Self.marVista])
    }

    /// Recents and `lastViewed` are separate lists: saving a detected place as
    /// `lastViewed` mustn't leak it into recents (§3).
    @Test("Setting lastViewed doesn't touch recents")
    func lastViewedDoesNotTouchRecents() {
        let store = UserDefaultsPlaceStore(defaults: defaults)
        store.addRecent(Self.sydney)
        store.lastViewed = Self.marVista

        #expect(store.recents == [Self.sydney])
        #expect(store.lastViewed == Self.marVista)
    }

    /// The in-memory store shares the protocol extension; one check that it's
    /// wired to it, rather than repeating every rule.
    @Test("InMemoryPlaceStore applies the same cap")
    func inMemoryStoreCaps() {
        let places = Self.cities(InMemoryPlaceStore.maximumRecents + 1)
        let store = InMemoryPlaceStore()
        for place in places { store.addRecent(place) }

        #expect(store.recents == Array(places.reversed().prefix(InMemoryPlaceStore.maximumRecents)))
    }

    // MARK: - Recents migration (SEARCH-RECENTS.md §8)

    /// Keys repeated here because they're private to the store; rename both.
    private static let recentsKey = "recentPlaces"

    /// A store written before recents existed has `lastViewedPlaces` and no
    /// `recentPlaces` key. Building the store once and then deleting the key
    /// recreates exactly that.
    private func makeLegacyStore(lastViewed: Place) {
        UserDefaultsPlaceStore(defaults: defaults).lastViewed = lastViewed
        defaults.removeObject(forKey: Self.recentsKey)
    }

    @Test("Migration seeds recents from an existing lastViewed")
    func migrationSeedsFromLastViewed() {
        makeLegacyStore(lastViewed: Self.sydney)

        let store = UserDefaultsPlaceStore(defaults: defaults)

        #expect(store.recents == [Self.sydney])
        #expect(store.lastViewed == Self.sydney)
    }

    /// Otherwise swiping the seeded city away would bring it back next launch.
    @Test("Migration runs only once")
    func migrationRunsOnce() {
        makeLegacyStore(lastViewed: Self.sydney)
        UserDefaultsPlaceStore(defaults: defaults).removeRecent(Self.sydney)

        #expect(UserDefaultsPlaceStore(defaults: defaults).recents.isEmpty)
    }

    @Test("Migration with no lastViewed leaves recents empty")
    func migrationWithNothingToSeed() {
        let store = UserDefaultsPlaceStore(defaults: defaults)

        #expect(store.recents.isEmpty)
        #expect(defaults.object(forKey: Self.recentsKey) != nil)
    }

    @Test("Unreadable recents data reads as empty")
    func unreadableRecentsReadAsEmpty() {
        defaults.set(Data("not json".utf8), forKey: Self.recentsKey)

        let store = UserDefaultsPlaceStore(defaults: defaults)
        #expect(store.recents.isEmpty)

        store.addRecent(Self.sydney)
        #expect(store.recents == [Self.sydney])
    }
}
