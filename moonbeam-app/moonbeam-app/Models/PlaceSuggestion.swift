//
//  PlaceSuggestion.swift
//  moonbeam-app
//

import Foundation

/// One type-ahead row in the city search list (LOCATION.md §3).
///
/// A suggestion is not yet a `Place`: it has no coordinates and no time zone.
/// `PlaceSearchService.resolve(_:)` turns it into one when the user picks it,
/// which keeps the expensive lookup off every keystroke.
///
/// `nonisolated` and a plain value, so suggestions can cross isolation
/// boundaries as stream elements.
nonisolated struct PlaceSuggestion: Identifiable, Hashable, Sendable {

    /// "Sydney"
    let title: String

    /// "NSW, Australia"
    let subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    /// MapKit's completions carry no stable identifier, so the pair the user
    /// actually reads is the identity. The separator is a newline because
    /// neither component can contain one.
    var id: String { "\(title)\n\(subtitle)" }

    /// The query `resolve(_:)` hands to MapKit: the two lines rejoined into
    /// the single address string a geocoder expects.
    var searchQuery: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}
