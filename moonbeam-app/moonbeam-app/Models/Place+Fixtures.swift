//
//  Place+Fixtures.swift
//  moonbeam-app
//

import Foundation

/// Fixed places for SwiftUI previews. Tests keep their own, so a preview
/// change can't move a test.
nonisolated extension Place {

    /// The reference location from ASTRONOMY.md §5.
    static let marVista = Place(
        name: "Los Angeles (Mar Vista), CA",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// A short "City, ST" for the madlib sentence.
    static let irvine = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// A long "City, ST": the sentence's widest line.
    static let ranchoSantaMargarita = Place(
        name: "Rancho Santa Margarita",
        region: "CA",
        latitude: 33.64,
        longitude: -117.60,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )
}
