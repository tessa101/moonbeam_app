//
//  PlaceTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `Place`'s names, equality and persistence shape (LOCATION.md §6).
@Suite("Place")
nonisolated struct PlaceTests {

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

    // MARK: - Names

    /// The example from §6, including the `locality == name` dedup that a
    /// plain city search produces.
    @Test("displayName reads city, region, country")
    func displayName() {
        #expect(Self.sydney.displayName == "Sydney, NSW, Australia")
    }

    @Test("displayName omits missing parts")
    func displayNameOmitsMissingParts() {
        let singapore = Place(
            name: "Singapore",
            country: "Singapore",
            latitude: 1.35,
            longitude: 103.82,
            timeZone: .gmt
        )
        let bare = Place(name: "Nowhere", latitude: 0, longitude: 0, timeZone: .gmt)

        #expect(singapore.displayName == "Singapore, Singapore")
        #expect(bare.displayName == "Nowhere")
    }

    @Test("shortName is the bare city")
    func shortName() {
        #expect(Self.sydney.shortName == "Sydney")
    }

    // MARK: - isCurrentLocation

    /// §6: the flag is presentation only. If it took part in equality, the
    /// "Back to {City}" chip would appear even when the saved place and the
    /// detected place are the same city.
    @Test("isCurrentLocation is outside equality")
    func isCurrentLocationIsOutsideEquality() {
        var detected = Self.sydney
        detected.isCurrentLocation = true

        #expect(detected == Self.sydney)
        #expect(detected.hashValue == Self.sydney.hashValue)
    }

    @Test("isCurrentLocation is not persisted")
    func isCurrentLocationIsNotPersisted() throws {
        var detected = Self.sydney
        detected.isCurrentLocation = true

        let data = try JSONEncoder().encode(detected)
        let decoded = try JSONDecoder().decode(Place.self, from: data)

        #expect(decoded.isCurrentLocation == false)
    }

    // MARK: - Codable

    /// The time zone is the part that matters: it drives every displayed time,
    /// so losing it in storage would silently show the device's clock.
    @Test("Round-trips through JSON including the time zone")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(Self.sydney)
        let decoded = try JSONDecoder().decode(Place.self, from: data)

        #expect(decoded == Self.sydney)
        #expect(decoded.timeZone.identifier == "Australia/Sydney")
        #expect(decoded.displayName == "Sydney, NSW, Australia")
    }

    // MARK: - MapKit name mapping

    /// A reverse geocode's `mapItem.name` is the nearest address, so a
    /// current location must never be named after it.
    @Test("A current location without a city name uses cityWithContext, never the map item's name")
    func currentLocationNeverUsesTheMapItemName() {
        #expect(
            Place.placeName(
                cityName: nil,
                cityWithContext: "Sydney, NSW",
                mapItemName: "1 Macquarie St",
                isCurrentLocation: true
            ) == "Sydney"
        )
        // Nothing city-like at all: no name, so the mapping fails and
        // CoreLocationService throws couldNotIdentifyPlace.
        #expect(
            Place.placeName(
                cityName: nil,
                cityWithContext: nil,
                mapItemName: "1 Macquarie St",
                isCurrentLocation: true
            ) == nil
        )
        #expect(
            Place.placeName(
                cityName: "  ",
                cityWithContext: " , NSW",
                mapItemName: "1 Macquarie St",
                isCurrentLocation: true
            ) == nil
        )
    }

    /// A search result's map item names the locality that was searched for,
    /// so it keeps the fallback.
    @Test("A search result without a city name falls back to the map item's name")
    func searchResultKeepsTheMapItemNameFallback() {
        #expect(
            Place.placeName(
                cityName: nil,
                cityWithContext: "Mar Vista, CA",
                mapItemName: "Mar Vista",
                isCurrentLocation: false
            ) == "Mar Vista"
        )
    }

    @Test("The city name wins for both sources", arguments: [true, false])
    func cityNameWins(isCurrentLocation: Bool) {
        #expect(
            Place.placeName(
                cityName: "Sydney",
                cityWithContext: "Sydney, NSW",
                mapItemName: "1 Macquarie St",
                isCurrentLocation: isCurrentLocation
            ) == "Sydney"
        )
    }

    // MARK: - MapKit region mapping

    /// `Place.regionComponent` exists because iOS 26's
    /// `MKAddressRepresentations` has no administrative-area property; see the
    /// doc comment there.
    @Test(
        "Region is what cityWithContext has beyond the city",
        arguments: [
            ("Sydney, NSW", "Sydney", "NSW"),
            ("Cupertino, CA", "Cupertino", "CA"),
            ("Kansas City, MO, United States", "Kansas City", "MO, United States"),
        ]
    )
    func regionComponent(cityWithContext: String, cityName: String, expected: String) {
        #expect(
            Place.regionComponent(cityWithContext: cityWithContext, cityName: cityName) == expected
        )
    }

    /// Conservative on anything unexpected: no region beats a wrong one.
    @Test("Region is nil when the format isn't city-first")
    func regionComponentRejectsUnexpectedFormats() {
        // Nothing beyond the city.
        #expect(Place.regionComponent(cityWithContext: "Singapore", cityName: "Singapore") == nil)
        // The city isn't the leading component.
        #expect(Place.regionComponent(cityWithContext: "NSW, Sydney", cityName: "Sydney") == nil)
        // Nothing to work from.
        #expect(Place.regionComponent(cityWithContext: nil, cityName: "Sydney") == nil)
        #expect(Place.regionComponent(cityWithContext: "Sydney, NSW", cityName: nil) == nil)
    }
}
