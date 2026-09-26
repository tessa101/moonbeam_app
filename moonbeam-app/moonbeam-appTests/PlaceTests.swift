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

    /// §6: the flag is presentation only and isn't persisted. If it took part
    /// in equality, a place would stop matching its own stored copy, and
    /// `PlaceStore.removeRecent` (exact match) could miss the swiped row.
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

    // MARK: - isSameCity (SEARCH-RECENTS.md §3, §8)

    /// ~0.0045° of latitude is ~500 m; ~0.0135° is ~1.5 km.
    private static let latitudeFor500Meters = 0.0045
    private static let latitudeFor1500Meters = 0.0135

    private static func sydney(latitudeOffset: Double) -> Place {
        Place(
            name: sydney.name,
            locality: sydney.locality,
            region: sydney.region,
            country: sydney.country,
            latitude: sydney.latitude + latitudeOffset,
            longitude: sydney.longitude,
            timeZone: sydney.timeZone
        )
    }

    @Test("A place is the same city as itself")
    func sameCityAsItself() {
        #expect(Self.sydney.isSameCity(as: Self.sydney))
    }

    /// Recents dedupe must survive a re-pick with slightly different
    /// coordinates, which `==` doesn't.
    @Test("Same name, region and country ~500 m apart is the same city, but not ==")
    func sameCityNearbyCoordinates() {
        let nearby = Self.sydney(latitudeOffset: Self.latitudeFor500Meters)

        #expect(nearby.isSameCity(as: Self.sydney))
        #expect(nearby != Self.sydney)
    }

    /// Names match, so distance doesn't matter (e.g. a city centroid vs a
    /// suburb result that MapKit names after the city).
    @Test("Same name, region and country far apart is still the same city")
    func sameCityByNameAlone() {
        #expect(Self.sydney(latitudeOffset: 1).isSameCity(as: Self.sydney))
    }

    /// Mar Vista keeps its own name but sits inside Los Angeles.
    @Test("Different names within 1 km are the same city")
    func sameCityByDistanceAlone() {
        let losAngeles = Place(
            name: "Los Angeles", region: "CA", country: "United States",
            latitude: 34.00, longitude: -118.43, timeZone: .gmt
        )
        let marVista = Place(
            name: "Mar Vista", region: "CA", country: "United States",
            latitude: 34.00 + Self.latitudeFor500Meters, longitude: -118.43, timeZone: .gmt
        )

        #expect(marVista.isSameCity(as: losAngeles))
        #expect(losAngeles.isSameCity(as: marVista))
    }

    @Test("Different names more than 1 km apart are different cities")
    func differentCityBeyondRadius() {
        let base = Place(name: "Here", latitude: 10, longitude: 10, timeZone: .gmt)
        let other = Place(
            name: "There", latitude: 10 + Self.latitudeFor1500Meters, longitude: 10, timeZone: .gmt
        )

        #expect(!other.isSameCity(as: base))
    }

    /// Portland, OR and Portland, ME: same name, different region.
    @Test("Same name in a different region is a different city")
    func sameNameDifferentRegion() {
        let oregon = Place(
            name: "Portland", region: "OR", country: "United States",
            latitude: 45.52, longitude: -122.68, timeZone: .gmt
        )
        let maine = Place(
            name: "Portland", region: "ME", country: "United States",
            latitude: 43.66, longitude: -70.26, timeZone: .gmt
        )

        #expect(!oregon.isSameCity(as: maine))
    }

    /// Longitude wraps: two points either side of the antimeridian are close.
    @Test("Distance is measured across the antimeridian")
    func sameCityAcrossAntimeridian() {
        let west = Place(name: "West", latitude: 0, longitude: 179.999, timeZone: .gmt)
        let east = Place(name: "East", latitude: 0, longitude: -179.999, timeZone: .gmt)

        #expect(west.isSameCity(as: east))
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
