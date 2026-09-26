//
//  PlaceSearchService.swift
//  moonbeam-app
//

import Foundation

/// City type-ahead search, and resolving a picked suggestion into a `Place`
/// (LOCATION.md §6).
///
/// Main-actor isolated for the same reason as `LocationService`: the
/// implementation drives MapKit.
protocol PlaceSearchService {

    /// Suggestions for a query, debounced, delivered as the search engine
    /// refines them.
    ///
    /// An empty or whitespace-only query yields one empty batch and finishes,
    /// so a cleared field clears its list rather than keeping stale rows.
    ///
    /// The stream *throws* rather than being a plain `AsyncStream`: §3 calls
    /// for a "Can't search right now" state, and a non-throwing stream has no
    /// way to say that a search failed as opposed to matching nothing.
    func suggestions(for query: String) -> AsyncThrowingStream<[PlaceSuggestion], any Error>

    /// Looks up the coordinates and time zone behind a suggestion.
    func resolve(_ suggestion: PlaceSuggestion) async throws -> Place
}

/// Why a search or a resolve failed.
nonisolated enum PlaceSearchError: Error, Equatable {

    /// The query matched nothing — the "No matching cities" state in §3.
    case noResults

    /// A result came back, but without the name or time zone a `Place` needs.
    case incompleteResult
}
