//
//  CompassReadout.swift
//  moonbeam-app
//

import Foundation

/// The heading readout or the lock pill's text, split so the view can set
/// the direction letters smaller, like a time's day period
/// (COMPASS-1.1.md §9.10): "Moonrise · 58°" then "ENE".
///
/// Built by `CompassViewModel` from `CompassFormatter`, so it always reads
/// like `headingText` / `lockText`, which stay the plain forms.
///
/// `nonisolated`: an inert value.
nonisolated struct CompassReadout: Equatable {

    /// "72°", or with a lock "Moonrise · 58°".
    let lead: String
    /// "ENE".
    let direction: String

    /// Between `lead` and `direction`, as in `CompassFormatter.bearing(for:)`.
    static let separator = " "

    /// The whole line as plain text: "Moonrise · 58° ENE".
    var string: String {
        lead + Self.separator + direction
    }
}
