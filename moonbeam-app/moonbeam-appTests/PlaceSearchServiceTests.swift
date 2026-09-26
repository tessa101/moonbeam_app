//
//  PlaceSearchServiceTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// City search (LOCATION.md §6, §7).
///
/// The empty-query case is checked against the **real**
/// `MapKitPlaceSearchService`, because it short-circuits before touching
/// MapKit and so needs no network. Resolution is checked against the fake:
/// §7 asks for "fake completer results", and a live `MKLocalSearch` would make
/// the suite depend on the network and on Apple's data.
@Suite("Place search")
@MainActor
struct PlaceSearchServiceTests {

    // MARK: - Fixtures

    private static let sydneySuggestion = PlaceSuggestion(
        title: "Sydney",
        subtitle: "NSW, Australia"
    )

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    // MARK: - Suggestions

    /// §7: "Empty query → no suggestions." One empty batch, then finish, so a
    /// cleared field clears its list instead of keeping stale rows.
    @Test("An empty query yields one empty batch", arguments: ["", "   ", "\n"])
    func emptyQueryYieldsNothing(query: String) async throws {
        let service = MapKitPlaceSearchService()

        var batches: [[PlaceSuggestion]] = []
        for try await batch in service.suggestions(for: query) {
            batches.append(batch)
        }

        #expect(batches == [[]])
    }

    @Test("The fake returns the scripted suggestions for a query")
    func fakeReturnsScriptedSuggestions() async throws {
        let service = FakePlaceSearchService(
            suggestionsByQuery: ["Syd": [Self.sydneySuggestion]]
        )

        var batches: [[PlaceSuggestion]] = []
        for try await batch in service.suggestions(for: " Syd ") {
            batches.append(batch)
        }

        #expect(batches == [[Self.sydneySuggestion]])
    }

    /// The "No matching cities" state in §3: a successful search with nothing
    /// in it, which is not the same as a failure.
    @Test("An unmatched query yields an empty batch, not an error")
    func unmatchedQueryYieldsEmptyBatch() async throws {
        let service = FakePlaceSearchService()

        var batches: [[PlaceSuggestion]] = []
        for try await batch in service.suggestions(for: "Xyzzy") {
            batches.append(batch)
        }

        #expect(batches == [[]])
    }

    /// The "Can't search right now" state in §3 — the reason the stream
    /// throws rather than being a plain `AsyncStream`.
    @Test("A search failure throws")
    func searchFailureThrows() async {
        let service = FakePlaceSearchService()
        service.searchError = URLError(.notConnectedToInternet)

        await #expect(throws: URLError.self) {
            for try await _ in service.suggestions(for: "Sydney") {}
        }
    }

    // MARK: - Resolve

    /// §7: "Resolve maps coordinates + time zone correctly."
    @Test("Resolving a suggestion yields coordinates and a time zone")
    func resolveYieldsCoordinatesAndTimeZone() async throws {
        let service = FakePlaceSearchService(
            placesBySuggestion: [Self.sydneySuggestion.id: Self.sydney]
        )

        let place = try await service.resolve(Self.sydneySuggestion)

        #expect(place.latitude == -33.87)
        #expect(place.longitude == 151.21)
        #expect(place.timeZone.identifier == "Australia/Sydney")
        #expect(place.displayName == "Sydney, NSW, Australia")
        // A searched place is not a detected one.
        #expect(place.isCurrentLocation == false)
        #expect(service.resolvedSuggestions == [Self.sydneySuggestion])
    }

    @Test("Resolving something that matches nothing throws")
    func resolveWithoutAMatchThrows() async {
        let service = FakePlaceSearchService()

        await #expect(throws: PlaceSearchError.noResults) {
            try await service.resolve(Self.sydneySuggestion)
        }
    }

    // MARK: - PlaceSuggestion

    /// Title and subtitle carry the identity, since MapKit's completions have
    /// no stable identifier of their own.
    @Test("Suggestions with the same two lines are the same suggestion")
    func suggestionIdentity() {
        let other = PlaceSuggestion(title: "Sydney", subtitle: "NSW, Australia")
        let elsewhere = PlaceSuggestion(title: "Sydney", subtitle: "NS, Canada")

        #expect(other.id == Self.sydneySuggestion.id)
        #expect(elsewhere.id != Self.sydneySuggestion.id)
    }

    /// What `resolve(_:)` sends to MapKit: the two displayed lines rejoined.
    @Test("The search query rejoins the two lines")
    func searchQuery() {
        #expect(Self.sydneySuggestion.searchQuery == "Sydney, NSW, Australia")
        #expect(PlaceSuggestion(title: "Sydney", subtitle: "").searchQuery == "Sydney")
    }
}
