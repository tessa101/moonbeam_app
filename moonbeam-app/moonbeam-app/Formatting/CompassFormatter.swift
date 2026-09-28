//
//  CompassFormatter.swift
//  moonbeam-app
//

import Foundation

/// Turns an azimuth into a 16-point compass abbreviation and a spoken name,
/// or a whole-degree bearing ("72° ENE") for the compass.
///
/// Sectors are `compassSectorWidth` wide and centred on their heading, so N
/// spans 348.75°–11.25° rather than starting at 0°. See ASTRONOMY.md §3.
///
/// `nonisolated` because it's a pure lookup over its input, so it doesn't
/// belong on the main actor under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
nonisolated struct CompassFormatter {

    // MARK: - Constants

    static let compassSectorWidth = 22.5

    private static let fullTurnDegrees = 360.0

    private static let abbreviations = [
        "N", "NNE", "NE", "ENE",
        "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW",
        "W", "WNW", "NW", "NNW"
    ]

    private static let spokenNames = [
        "north", "north-northeast", "northeast", "east-northeast",
        "east", "east-southeast", "southeast", "south-southeast",
        "south", "south-southwest", "southwest", "west-southwest",
        "west", "west-northwest", "northwest", "north-northwest"
    ]

    // MARK: - Formatting

    /// The compass abbreviation for an azimuth, for example `"ESE"`.
    func abbreviation(for azimuth: Double) -> String {
        Self.abbreviations[Self.sectorIndex(for: azimuth)]
    }

    /// The spelled-out direction for accessibility labels, for example
    /// `"east-southeast"`.
    func spokenName(for azimuth: Double) -> String {
        Self.spokenNames[Self.sectorIndex(for: azimuth)]
    }

    /// Whole degrees then the abbreviation, for example `"72° ENE"`: the
    /// compass's heading and lock copy, in the moon table's order
    /// (COMPASS.md §1).
    func bearing(for azimuth: Double) -> String {
        "\(Self.wholeDegrees(azimuth).formatted())° \(abbreviation(for: azimuth))"
    }

    /// The spoken form of `bearing(for:)`, for example
    /// `"72 degrees east-northeast"`.
    func spokenBearing(for azimuth: Double) -> String {
        "\(Self.wholeDegrees(azimuth).formatted()) degrees \(spokenName(for: azimuth))"
    }

    /// Rounded to a whole degree in `0..<360`, so 359.6° reads "0°", not
    /// "360°".
    private static func wholeDegrees(_ azimuth: Double) -> Int {
        Int(azimuth.wrappedIntoDegreeCircle.rounded()) % Int(fullTurnDegrees)
    }

    /// Index of the 16-point sector containing `azimuth`.
    ///
    /// Offsetting by half a sector before dividing makes each sector centred
    /// on its heading; the modulo brings 348.75°–360° back around to N.
    private static func sectorIndex(for azimuth: Double) -> Int {
        let sectorCount = abbreviations.count
        let shifted = (azimuth + compassSectorWidth / 2).wrappedIntoDegreeCircle
        return Int(shifted / compassSectorWidth) % sectorCount
    }
}
