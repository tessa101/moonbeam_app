//
//  TimeZoneCity.swift
//  moonbeam-app
//

import Foundation

/// The major city for the device's time zone, behind the `noCity` state's
/// "Start with [city]" link (ONBOARDING-MOD-MAIN.md). The time zone needs no
/// permission, so it's a fair guess before the user has picked anything.
///
/// One lookup, as the doc asks. A zone with no mapped city returns `nil` and
/// the link is hidden (V1). Fixed `Place` values with no network, so a tap
/// can't fail; each carries the city's own zone, not the device's (Phoenix
/// gets Denver in Denver's zone).
nonisolated enum TimeZoneCity {

    // MARK: - Cities

    static let losAngeles = city("Los Angeles", region: "CA", 34.0522, -118.2437, zone: "America/Los_Angeles")
    static let denver = city("Denver", region: "CO", 39.7392, -104.9903, zone: "America/Denver")
    static let chicago = city("Chicago", region: "IL", 41.8781, -87.6298, zone: "America/Chicago")
    static let newYork = city("New York", region: "NY", 40.7128, -74.0060, zone: "America/New_York")
    static let anchorage = city("Anchorage", region: "AK", 61.2181, -149.9003, zone: "America/Anchorage")
    static let honolulu = city("Honolulu", region: "HI", 21.3069, -157.8583, zone: "Pacific/Honolulu")

    /// Device zone identifier → city (ONBOARDING-MOD-MAIN.md, starting point).
    static let citiesByZoneIdentifier: [String: Place?] = [
        "America/Los_Angeles": losAngeles,
        "America/Denver": denver,
        "America/Phoenix": denver,
        "America/Chicago": chicago,
        "America/New_York": newYork,
        "America/Anchorage": anchorage,
        "Pacific/Honolulu": honolulu,
    ]

    // MARK: - Lookup

    /// The major city for `timeZone`, or `nil` when it has none mapped.
    static func city(for timeZone: TimeZone) -> Place? {
        citiesByZoneIdentifier[timeZone.identifier] ?? nil
    }

    // MARK: - Building

    private static let country = "United States"

    /// `nil` only if the zone identifier were unknown to the system, which
    /// would hide the link rather than show a city in the wrong zone.
    private static func city(
        _ name: String,
        region: String,
        _ latitude: Double,
        _ longitude: Double,
        zone identifier: String
    ) -> Place? {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        return Place(
            name: name,
            locality: name,
            region: region,
            country: country,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
    }
}
