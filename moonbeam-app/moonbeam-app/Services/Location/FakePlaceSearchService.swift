//
//  FakePlaceSearchService.swift
//  moonbeam-app
//

import Foundation

/// Scriptable `PlaceSearchService` for tests and SwiftUI previews.
///
/// Reaches all three suggestion-list states from LOCATION.md §3: results
/// (`suggestionsByQuery`), no results (an unknown query), and search failure
/// (`searchError`).
final class FakePlaceSearchService: PlaceSearchService {

    // MARK: - Script

    /// Keyed by the trimmed query.
    var suggestionsByQuery: [String: [PlaceSuggestion]] = [:]

    /// What each suggestion resolves to, keyed by `PlaceSuggestion.id`.
    var placesBySuggestion: [PlaceSuggestion.ID: Place] = [:]

    var searchError: (any Error)?
    var resolveError: (any Error)?

    // MARK: - Record

    /// Every query handed to `suggestions(for:)`, so tests can check that
    /// short queries never reach the search engine (SEARCH-RECENTS.md §8).
    private(set) var searchedQueries: [String] = []

    private(set) var resolvedSuggestions: [PlaceSuggestion] = []

    // MARK: - Init

    init(
        suggestionsByQuery: [String: [PlaceSuggestion]] = [:],
        placesBySuggestion: [PlaceSuggestion.ID: Place] = [:]
    ) {
        self.suggestionsByQuery = suggestionsByQuery
        self.placesBySuggestion = placesBySuggestion
    }

    // MARK: - PlaceSearchService

    func suggestions(for query: String) -> AsyncThrowingStream<[PlaceSuggestion], any Error> {
        searchedQueries.append(query)
        return AsyncThrowingStream { continuation in
            if let searchError {
                continuation.finish(throwing: searchError)
                return
            }

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continuation.yield([])
            } else {
                continuation.yield(suggestionsByQuery[trimmed] ?? [])
            }
            continuation.finish()
        }
    }

    func resolve(_ suggestion: PlaceSuggestion) async throws -> Place {
        resolvedSuggestions.append(suggestion)

        if let resolveError { throw resolveError }

        guard let place = placesBySuggestion[suggestion.id] else {
            throw PlaceSearchError.noResults
        }
        return place
    }
}
