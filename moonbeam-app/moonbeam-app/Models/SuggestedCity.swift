//
//  SuggestedCity.swift
//  moonbeam-app
//

import Foundation

/// One of the five cities the search sheet offers when there are no recents
/// (STEP-5.13 §3): a fixed `Place` in its own time zone, so a pick needs no
/// network and can't fail, plus the row's words.
///
/// The words are fixed with the place rather than derived, because VoiceOver
/// reads the state in full ("Los Angeles, California, United States") where
/// the row shows "CA".
nonisolated struct SuggestedCity: Hashable, Sendable {

    let place: Place
    /// "Los Angeles, CA", "Paris": the §3 table's Row column.
    let title: String
    /// The country, under the title.
    let detail: String
    let accessibilityLabel: String

    // MARK: - The five (§3 table)

    /// In the §3 order. A city whose zone the system doesn't know is left out
    /// rather than shown in the wrong zone.
    static let all: [SuggestedCity] = [
        make("Los Angeles", region: "CA", state: "California", country: "United States",
             34.0522, -118.2437, zone: "America/Los_Angeles"),
        make("New York", region: "NY", state: "New York", country: "United States",
             40.7128, -74.0060, zone: "America/New_York"),
        make("Paris", country: "France", 48.8566, 2.3522, zone: "Europe/Paris"),
        make("London", country: "United Kingdom", 51.5074, -0.1278, zone: "Europe/London"),
        make("Tokyo", country: "Japan", 35.6762, 139.6503, zone: "Asia/Tokyo"),
    ].compactMap { $0 }

    // MARK: - Building

    private static func make(
        _ name: String,
        region: String? = nil,
        state: String? = nil,
        country: String,
        _ latitude: Double,
        _ longitude: Double,
        zone identifier: String
    ) -> SuggestedCity? {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        let place = Place(
            name: name,
            region: region,
            country: country,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
        let spoken = [name, state, country].compactMap { $0 }.joined(separator: ", ")
        return SuggestedCity(place: place, title: place.nameWithRegion, detail: country, accessibilityLabel: spoken)
    }
}
