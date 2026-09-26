//
//  Place.swift
//  moonbeam-app
//

import Foundation

/// A location the moon table is calculated for, with the time zone used for
/// every user-facing time in that table.
///
/// `Codable` so `PlaceStore` can persist the last-viewed place, and `Hashable`
/// so places can key a `List` or be compared for the "Back to {City}" chip
/// (LOCATION.md §3).
///
/// `nonisolated` like the rest of the domain layer: it's an inert value, so it
/// shouldn't inherit main-actor isolation from
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
nonisolated struct Place: Codable, Hashable, Sendable {

    // MARK: - Stored properties

    /// The label the place is known by, e.g. "Sydney". Usually the city, but
    /// it can be a neighbourhood when that's what the user searched for.
    let name: String

    /// The city, when MapKit reports one. The MapKit mapping always names a
    /// place after its city when there is one, so in practice this either
    /// repeats `name` or is `nil`; `displayName` skips the repeat.
    let locality: String?

    /// State, province or other primary administrative area, e.g. "NSW".
    let region: String?

    /// Country or region name, e.g. "Australia".
    let country: String?

    let latitude: Double
    let longitude: Double

    /// The place's *own* zone. Every time the app shows for this place is
    /// formatted in it, never in the device's (LOCATION.md §5, PRODUCT FR1).
    let timeZone: TimeZone

    /// True when this place came from a location fix rather than a search.
    ///
    /// Presentation only, and deliberately excluded from `Codable` and from
    /// equality: a saved place and the same place freshly detected have to
    /// compare equal, because that comparison is what decides whether the
    /// "Back to {City}" chip appears (LOCATION.md §3, §6).
    var isCurrentLocation: Bool = false

    // MARK: - Init

    init(
        name: String,
        locality: String? = nil,
        region: String? = nil,
        country: String? = nil,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        isCurrentLocation: Bool = false
    ) {
        self.name = name
        self.locality = locality
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.isCurrentLocation = isCurrentLocation
    }

    // MARK: - Names

    /// "Sydney, NSW, Australia", with missing parts left out.
    ///
    /// `locality` is skipped when it just repeats `name`, which is the common
    /// case for a city search.
    var displayName: String {
        var parts = [name]
        if let locality, locality != name { parts.append(locality) }
        if let region, region != name { parts.append(region) }
        if let country { parts.append(country) }
        return parts.joined(separator: ", ")
    }

    /// "Sydney" — what the search field and the "Back to {City}" chip show.
    var shortName: String { name }

    // MARK: - Time zones

    /// Whether to show the time zone label from LOCATION.md §3.
    ///
    /// Compared by *offset* rather than identifier: what matters to the reader
    /// is whether the clock differs, and identifiers have aliases
    /// ("US/Pacific" vs "America/Los_Angeles") that would otherwise label a
    /// place as elsewhere while showing identical times. The date matters
    /// because offsets move with DST.
    func isInDifferentTimeZone(from deviceTimeZone: TimeZone, on date: Date = Date()) -> Bool {
        timeZone.secondsFromGMT(for: date) != deviceTimeZone.secondsFromGMT(for: date)
    }

    // MARK: - Codable

    /// `isCurrentLocation` is absent, so a decoded place is never "current"
    /// until something detects it again. Its default value is what lets the
    /// synthesised `init(from:)` skip it.
    private enum CodingKeys: String, CodingKey {
        case name
        case locality
        case region
        case country
        case latitude
        case longitude
        case timeZone
    }

    // MARK: - Hashable

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.name == rhs.name
            && lhs.locality == rhs.locality
            && lhs.region == rhs.region
            && lhs.country == rhs.country
            && lhs.latitude == rhs.latitude
            && lhs.longitude == rhs.longitude
            && lhs.timeZone == rhs.timeZone
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(locality)
        hasher.combine(region)
        hasher.combine(country)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(timeZone)
    }
}
