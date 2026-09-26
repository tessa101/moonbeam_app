//
//  MapKitPlaceSearchService.swift
//  moonbeam-app
//

import MapKit

/// `PlaceSearchService` backed by `MKLocalSearchCompleter` (type-ahead) and
/// `MKLocalSearch` (resolve).
///
/// Main-actor isolated (the project default), which both MapKit types expect:
/// the completer delivers to its delegate on the main queue and
/// `MKLocalSearch` documents its completion handler as main-actor.
final class MapKitPlaceSearchService: PlaceSearchService {

    // MARK: - Constants

    /// LOCATION.md §6. Without it, "San Francisco" is 13 network requests.
    private static let debounceInterval = Duration.milliseconds(250)

    /// Cities and neighbourhoods only, per §3 — no cafés, no street numbers,
    /// and no whole states or countries.
    private static let addressFilter = MKAddressFilter(including: [.locality, .subLocality])

    // MARK: - State

    /// The live query. Replacing it tears down the previous completer, which
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
            continuation: continuation,
            addressFilter: Self.addressFilter
        )
        self.session = session
        session.start(query: trimmed, after: Self.debounceInterval)

        // Runs off the main actor when the consumer stops iterating, so the
        // teardown has to hop back. `SuggestionSession` is main-actor
        // isolated, and therefore `Sendable`, so capturing it is fine.
        continuation.onTermination = { _ in
            Task { @MainActor in session.cancel() }
        }

        return stream
    }

    func resolve(_ suggestion: PlaceSuggestion) async throws -> Place {
        // A natural-language search over the suggestion's own two lines. The
        // completion object could be replayed instead, but it can't cross an
        // isolation boundary, and rejoined address text resolves city
        // suggestions just as well while keeping `PlaceSuggestion` a value.
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = suggestion.searchQuery
        request.resultTypes = .address
        request.addressFilter = Self.addressFilter

        let response = try await MKLocalSearch(request: request).start()

        guard let mapItem = response.mapItems.first else {
            throw PlaceSearchError.noResults
        }
        guard let place = Place(mapItem: mapItem) else {
            throw PlaceSearchError.incompleteResult
        }

        return place
    }
}

// MARK: - One query

/// One `MKLocalSearchCompleter` query, its delegate, and the stream they feed.
///
/// Grouped so all three are torn down together: cancelling stops the debounce
/// timer, cancels the completer, and finishes the stream.
private final class SuggestionSession {

    private let completer = MKLocalSearchCompleter()
    private let delegate: CompleterDelegate
    private let continuation: AsyncThrowingStream<[PlaceSuggestion], any Error>.Continuation
    private var debounce: Task<Void, Never>?

    init(
        continuation: AsyncThrowingStream<[PlaceSuggestion], any Error>.Continuation,
        addressFilter: MKAddressFilter
    ) {
        self.continuation = continuation
        delegate = CompleterDelegate(continuation: continuation)

        completer.delegate = delegate
        completer.resultTypes = .address
        completer.addressFilter = addressFilter
    }

    deinit {
        debounce?.cancel()
    }

    /// Waits out the debounce, then hands the query to MapKit. Setting
    /// `queryFragment` is what starts the search.
    func start(query: String, after delay: Duration) {
        debounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            completer.queryFragment = query
        }
    }

    func cancel() {
        debounce?.cancel()
        completer.cancel()
        continuation.finish()
    }
}

// MARK: - Delegate bridging

/// Forwards the completer's delegate callbacks into the stream.
///
/// `nonisolated` because the imported MapKit protocol carries no actor
/// annotation, so main-actor methods can't satisfy its requirements. Reading
/// `completer.results` here is safe: MapKit calls back on the main queue, and
/// the results are mapped to values before anything leaves the method.
private nonisolated final class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {

    private let continuation: AsyncThrowingStream<[PlaceSuggestion], any Error>.Continuation

    init(continuation: AsyncThrowingStream<[PlaceSuggestion], any Error>.Continuation) {
        self.continuation = continuation
        super.init()
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.map {
            PlaceSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        continuation.yield(suggestions)
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        continuation.finish(throwing: error)
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
