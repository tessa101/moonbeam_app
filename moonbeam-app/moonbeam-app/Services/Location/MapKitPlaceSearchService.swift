//
//  MapKitPlaceSearchService.swift
//  moonbeam-app
//

import MapKit

/// `PlaceSearchService` backed by `MKLocalSearchCompleter` (type-ahead) and
/// `MKLocalSearch` (resolve).
///
/// Type-ahead asks MapKit once per address level and merges the batches with
/// `PlaceSuggestionRanking` (SEARCH-RECENTS.md §0, Step 2.2): cities alone
/// missed city-states and metro-level cities (Singapore, Tokyo), while
/// regions and countries have to be kept to a name match.
///
/// Main-actor isolated (the project default), which both MapKit types expect:
/// the completer delivers to its delegate on the main queue and
/// `MKLocalSearch` documents its completion handler as main-actor.
final class MapKitPlaceSearchService: PlaceSearchService {

    // MARK: - Constants

    /// LOCATION.md §6. Without it, "San Francisco" is 13 network requests
    /// per level, and there are three levels.
    private static let debounceInterval = Duration.milliseconds(250)

    /// Towns and cities (§3): no cafés, no street numbers.
    private static let localityFilter = MKAddressFilter(including: [.locality])

    /// Neighbourhoods and districts, asked for separately so they can be
    /// listed below the towns and cities (Step 2.2 fix 2).
    private static let subLocalityFilter = MKAddressFilter(including: [.subLocality])

    /// States, counties and countries. Only shown on a name match, which is
    /// how Singapore, Tokyo and London, England get in (Step 2.2).
    private static let regionFilter = MKAddressFilter(
        including: [.administrativeArea, .subAdministrativeArea, .country]
    )

    /// All of the above, for resolving a row from any level.
    private static let anyLevelFilter = MKAddressFilter(
        including: [.locality, .subLocality, .administrativeArea, .subAdministrativeArea, .country]
    )

    // MARK: - State

    /// The live query. Replacing it tears down the previous completers, which
    /// is what stops an abandoned query from delivering late results.
    private var session: SuggestionSession?

    // MARK: - PlaceSearchService

    func suggestions(for query: String) -> AsyncThrowingStream<[PlaceSuggestion], any Error> {
        session?.cancel()
        session = nil

        guard let trimmed = query.trimmedOrNil else {
            return AsyncThrowingStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        }

        let (stream, continuation) = AsyncThrowingStream<[PlaceSuggestion], any Error>.makeStream()

        let session = SuggestionSession(
            query: trimmed,
            continuation: continuation,
            localityFilter: Self.localityFilter,
            subLocalityFilter: Self.subLocalityFilter,
            regionFilter: Self.regionFilter
        )
        self.session = session
        session.start(after: Self.debounceInterval)

        // Runs off the main actor when the consumer stops iterating, so the
        // teardown has to hop back. `SuggestionSession` is main-actor
        // isolated, and therefore `Sendable`, so capturing it is fine.
        continuation.onTermination = { _ in
            Task { @MainActor in session.cancel() }
        }

        return stream
    }

    /// Replays the tapped completion (Step 2.2 fix 3), so the row loads
    /// exactly that place. A fresh text search over the row's two lines
    /// could land elsewhere: "London, England" came back as Southwark.
    ///
    /// The completion never leaves the main actor: the session keeps it,
    /// keyed by the row's id, and `PlaceSuggestion` stays a plain value.
    /// The text search is only a fallback, for a row whose query has since
    /// been replaced.
    func resolve(_ suggestion: PlaceSuggestion) async throws -> Place {
        let request: MKLocalSearch.Request
        if let completion = session?.completion(for: suggestion.id) {
            request = MKLocalSearch.Request(completion: completion)
        } else {
            // Every level the list can show, or Tokyo, Japan and Mexico
            // City, which are region-level to MapKit, fail to resolve.
            request = MKLocalSearch.Request()
            request.naturalLanguageQuery = suggestion.searchQuery
            request.addressFilter = Self.anyLevelFilter
        }
        request.resultTypes = .address

        let response = try await MKLocalSearch(request: request).start()

        guard let mapItem = response.mapItems.first else {
            throw PlaceSearchError.noResults
        }
        guard let place = Place(mapItem: mapItem) else {
            throw PlaceSearchError.incompleteResult
        }

        return place.named(after: suggestion)
    }
}

// MARK: - One query

/// One query across the address levels: a completer per level, the latest
/// batch from each, and the stream they feed.
///
/// Grouped so everything is torn down together: cancelling stops the
/// debounce timer, cancels every completer, and finishes the stream.
private final class SuggestionSession {

    private let query: String
    private let continuation: AsyncThrowingStream<[PlaceSuggestion], any Error>.Continuation
    private let localities: LevelCompleter
    private let subLocalities: LevelCompleter
    private let regions: LevelCompleter
    private var debounce: Task<Void, Never>?

    private var levels: [LevelCompleter] { [localities, subLocalities, regions] }

    init(
        query: String,
        continuation: AsyncThrowingStream<[PlaceSuggestion], any Error>.Continuation,
        localityFilter: MKAddressFilter,
        subLocalityFilter: MKAddressFilter,
        regionFilter: MKAddressFilter
    ) {
        self.query = query
        self.continuation = continuation
        localities = LevelCompleter(filter: localityFilter)
        subLocalities = LevelCompleter(filter: subLocalityFilter)
        regions = LevelCompleter(filter: regionFilter)
        for level in levels {
            level.onChange = { [weak self] in self?.levelDidChange() }
        }
    }

    deinit {
        debounce?.cancel()
    }

    /// Waits out the debounce, then hands the query to every level.
    func start(after delay: Duration) {
        let query = query
        debounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            for level in levels {
                level.start(query: query)
            }
        }
    }

    func cancel() {
        debounce?.cancel()
        for level in levels {
            level.cancel()
        }
        continuation.finish()
    }

    /// The completion behind a row, from whichever level returned it. Kept
    /// after `cancel()`: picking a row ends the stream before it resolves.
    func completion(for id: PlaceSuggestion.ID) -> MKLocalSearchCompletion? {
        levels.lazy.compactMap { $0.completions[id] }.first
    }

    /// Waits until every level has answered once, so the list doesn't open
    /// with London, ON and then have London, England jump above it, or
    /// Venice Beach above Venice, Italy. After that, each refinement goes
    /// straight out. A level that failed counts as empty; only all of them
    /// failing is a failed search.
    private func levelDidChange() {
        guard levels.allSatisfy(\.hasAnswered) else { return }
        if levels.allSatisfy({ $0.error != nil }), let error = localities.error {
            continuation.finish(throwing: error)
            return
        }
        continuation.yield(
            PlaceSuggestionRanking.merged(
                query: query,
                localities: localities.suggestions,
                subLocalities: subLocalities.suggestions,
                regions: regions.suggestions
            )
        )
    }
}

/// One `MKLocalSearchCompleter` for one address level, and its latest batch.
///
/// Main-actor isolated, with a `@preconcurrency` delegate conformance: MapKit
/// calls back on the main queue, and the batches have to reach the session
/// there.
private final class LevelCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {

    private let completer = MKLocalSearchCompleter()

    private(set) var suggestions: [PlaceSuggestion] = []

    /// The latest batch's completions by row id, for resolving a pick.
    private(set) var completions: [PlaceSuggestion.ID: MKLocalSearchCompletion] = [:]

    private(set) var error: (any Error)?

    /// Results or an error have arrived at least once.
    private(set) var hasAnswered = false

    var onChange: (() -> Void)?

    init(filter: MKAddressFilter) {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.addressFilter = filter
    }

    /// Setting `queryFragment` is what starts the search.
    func start(query: String) {
        completer.queryFragment = query
    }

    func cancel() {
        completer.cancel()
        onChange = nil
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        suggestions = results.map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle) }
        // First one wins if two rows read the same, matching the list.
        completions = Dictionary(zip(suggestions.map(\.id), results)) { first, _ in first }
        error = nil
        hasAnswered = true
        onChange?()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        suggestions = []
        completions = [:]
        self.error = error
        hasAnswered = true
        onChange?()
    }
}

// MARK: - Helpers

private extension String {

    /// Trimmed, or `nil` when the query is empty or just whitespace.
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
