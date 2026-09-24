//
//  Place.swift
//  moonbeam-app
//

import Foundation

/// A location the moon table is calculated for, with the time zone used for
/// every user-facing time in that table.
struct Place: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
}
