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

    @Test("displayName keeps a locality that differs from the name")
    func displayNameWithDistinctLocality() {
        let marVista = Place(
            name: "Mar Vista",
            locality: "Los Angeles",
            region: "CA",
            country: "United States",
            latitude: 34.00,
            longitude: -118.43,
            timeZone: .gmt
        )

        #expect(marVista.displayName == "Mar Vista, Los Angeles, CA, United States")
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
