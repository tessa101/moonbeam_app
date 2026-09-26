//
//  Place+MapKit.swift
//  moonbeam-app
//

import CoreLocation
import MapKit

/// Turns MapKit's `MKMapItem` into a `Place`.
///
/// Lives next to the services rather than in `Models/` so `Place` itself stays
/// a Foundation-only value type, and lives outside both services because
/// `CoreLocationService` (reverse geocoding) and `MapKitPlaceSearchService`
/// (city search) both need it.
///
/// `nonisolated`, like `Place` itself: this is pure mapping over its inputs,
/// and an extension would otherwise pick up main-actor isolation from
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` even though the type it extends
/// is nonisolated.
nonisolated extension Place {

    // MARK: - Coordinates

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Mapping

    /// Builds a `Place` from a map item returned by reverse geocoding or a
    /// local search.
    ///
    /// Fails when the item has no usable name or, more importantly, no time
    /// zone: the whole app formats in the place's zone, so a place without one
    /// would silently show the wrong times. MapKit populates `timeZone` for
    /// geocoding and search results as a convenience. `CoreLocationService`
    /// turns a failure into `LocationError.couldNotIdentifyPlace`.
    init?(mapItem: MKMapItem, isCurrentLocation: Bool = false) {
        let address = mapItem.addressRepresentations

        guard
            let name = Self.placeName(
                cityName: address?.cityName,
                cityWithContext: address?.cityWithContext,
                mapItemName: mapItem.name,
                isCurrentLocation: isCurrentLocation
            )
        else { return nil }
        guard let timeZone = mapItem.timeZone else { return nil }

        // The city the name came from, when it came from a city at all (a
        // search result can fall back to the map item's own name).
        let cityName = address?.cityName?.trimmed
            ?? (isCurrentLocation ? name : nil)
        let coordinate = mapItem.location.coordinate

        self.init(
            name: name,
            locality: cityName,
            region: Self.regionComponent(cityWithContext: address?.cityWithContext, cityName: cityName),
            country: address?.regionName?.trimmed,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZone: timeZone,
            isCurrentLocation: isCurrentLocation
        )
    }

    /// Chooses the name a mapped place goes by, or `nil` if there isn't a
    /// safe one.
    ///
    /// The city comes first. After that the two sources differ:
    /// - a **current location** never uses `mapItemName`: for a reverse
    ///   geocode that's the nearest address ("1600 Main St"), which would put
    ///   the user's street in the search field and in storage. It falls back
    ///   to the leading component of `cityWithContext` instead, and to nothing
    ///   at all after that
    /// - a **search result** can use `mapItemName`: it's the name of the
    ///   locality the user searched for and picked
    static func placeName(
        cityName: String?,
        cityWithContext: String?,
        mapItemName: String?,
        isCurrentLocation: Bool
    ) -> String? {
        if let city = cityName?.trimmed { return city }

        guard isCurrentLocation else { return mapItemName?.trimmed }

        return cityWithContext?
            .split(separator: ",")
            .first
            .flatMap { String($0).trimmed }
    }

    /// Extracts the administrative area ("NSW") from MapKit's address parts.
    ///
    /// iOS 26's `MKAddressRepresentations` exposes no discrete
    /// administrative-area property — only `cityName` ("Sydney") and
    /// `cityWithContext` ("Sydney, NSW") — and the deprecated `MKPlacemark`
    /// route is the one LOCATION.md §6 tells us to avoid. So the region is
    /// whatever `cityWithContext` has beyond the city.
    ///
    /// Returns `nil` unless the city is confirmed to be the leading
    /// component, so an unexpected format yields no region rather than a
    /// wrong one.
    static func regionComponent(cityWithContext: String?, cityName: String?) -> String? {
        guard let cityWithContext, let cityName = cityName?.trimmed else { return nil }

        let parts = cityWithContext
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard parts.count > 1, parts[0] == cityName else { return nil }
        return parts.dropFirst().joined(separator: ", ")
    }
}

// MARK: - Helpers

private nonisolated extension String {

    /// Trimmed, or `nil` if nothing is left. MapKit occasionally returns
    /// padded or empty address components.
    var trimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
