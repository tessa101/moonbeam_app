//
//  TimeZoneCityTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The `noCity` state's "Start with [city]" lookup (ONBOARDING-MOD-MAIN.md):
/// mapped zones give their city, in that city's own zone; anything else hides
/// the link.
@Suite("Time zone → city")
struct TimeZoneCityTests {

    @Test("Mapped zones return the expected city", arguments: [
        ("America/Los_Angeles", "Los Angeles", "America/Los_Angeles"),
        ("America/Denver", "Denver", "America/Denver"),
        ("America/Phoenix", "Denver", "America/Denver"),
        ("America/Chicago", "Chicago", "America/Chicago"),
        ("America/New_York", "New York", "America/New_York"),
        ("America/Anchorage", "Anchorage", "America/Anchorage"),
        ("Pacific/Honolulu", "Honolulu", "Pacific/Honolulu"),
    ])
    func mappedZone(device: String, city: String, cityZone: String) throws {
        let zone = try #require(TimeZone(identifier: device))

        let place = try #require(TimeZoneCity.city(for: zone))

        #expect(place.name == city)
        #expect(place.timeZone.identifier == cityZone)
        #expect(!place.isCurrentLocation)
    }

    @Test("Unmapped zones return nil", arguments: [
        "Europe/London", "Europe/Paris", "Asia/Tokyo", "Australia/Sydney", "America/Toronto", "GMT",
    ])
    func unmappedZone(identifier: String) throws {
        let zone = try #require(TimeZone(identifier: identifier))

        #expect(TimeZoneCity.city(for: zone) == nil)
    }

    @Test("Every mapped city has a place, with its state and a US country")
    func everyEntryResolves() {
        for (identifier, city) in TimeZoneCity.citiesByZoneIdentifier {
            #expect(city != nil, "\(identifier) has no place")
            #expect(city?.country == "United States")
            #expect(city?.region?.isEmpty == false)
        }
    }
}
