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
    /// Fails when the item has no name or, more importantly, no time zone: the
    /// whole app formats in the place's zone, so a place without one would
    /// silently show the wrong times. MapKit populates `timeZone` for
    /// geocoding and search results as a convenience.
    init?(mapItem: MKMapItem, isCurrentLocation: Bool = false) {
        let address = mapItem.addressRepresentations
        let cityName = address?.cityName

        guard let name = (cityName ?? mapItem.name)?.trimmed, !name.isEmpty else { return nil }
        guard let timeZone = mapItem.timeZone else { return nil }

        let coordinate = mapItem.location.coordinate

        self.init(
            name: name,
            locality: cityName?.trimmed,
            region: Self.regionComponent(cityWithContext: address?.cityWithContext, cityName: cityName),
            country: address?.regionName?.trimmed,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZone: timeZone,
            isCurrentLocation: isCurrentLocation
        )
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
