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
}
