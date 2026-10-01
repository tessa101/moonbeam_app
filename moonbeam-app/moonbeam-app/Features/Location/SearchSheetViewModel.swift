//
//  SearchSheetViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation

/// Drives the city search sheet: recents with no typing, filtered recents at
/// one character, type-ahead from two (SEARCH-RECENTS.md §2, §8).
///
/// Reports picks through `onPick` and the location row through
/// `onUseMyLocation`, and changes nothing else:
/// `LocationViewModel` stays the only writer of the place, `lastViewed` and
/// recents. The one exception is swipe-to-delete, which removes a recent
/// here because it doesn't involve the current place at all.
@Observable
final class SearchSheetViewModel {

    // MARK: - Types

    /// What the list under the field shows.
    enum ListState: Equatable {
        case recents([Place])               // 0 chars; empty → location row only
        case filteredRecents([Place])       // 1 char; empty → blank list, no error copy
        case suggestions([PlaceSuggestion]) // 2+ chars
        case noResults
        case failed                         // search or resolve failed
    }

    // MARK: - Constants

    /// Shorter queries never reach the search service. One constant so the
    /// threshold can move to 3 after device testing (§2, §7).
    static let searchMinimumCharacters = 2

    // MARK: - Observed state

    /// The sheet's field. Always starts empty (§1).
    var query = "" {
        didSet { queryDidChange(from: oldValue) }
    }

    private(set) var listState: ListState

    /// Mirrors the main screen: hidden when the current place is already the
    /// detected location (Decision B).
    let showsUseMyLocation: Bool

    // MARK: - Dependencies

    private let placeSearch: any PlaceSearchService
    private let placeStore: any PlaceStore
    private let onPick: (Place) -> Void
    private let onUseMyLocation: () -> Void

    // MARK: - Bookkeeping

    /// The in-flight type-ahead. Readable so tests can await the batch a
    /// query change started.
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        showsUseMyLocation: Bool,
        onPick: @escaping (Place) -> Void,
        onUseMyLocation: @escaping () -> Void
    ) {
        self.placeSearch = placeSearch
        self.placeStore = placeStore
        self.showsUseMyLocation = showsUseMyLocation
        self.onPick = onPick
        self.onUseMyLocation = onUseMyLocation
        listState = .recents(placeStore.recents)
    }

    // MARK: - Picking

    /// A recent is already a `Place`, so there's nothing to resolve.
    func pick(_ recent: Place) {
        searchTask?.cancel()
        onPick(recent)
    }

    /// Resolves first; on failure the sheet stays open showing `.failed`
    /// and nothing is picked (§8).
    func pick(_ suggestion: PlaceSuggestion) async {
        // A late type-ahead batch mustn't overwrite the outcome.
        searchTask?.cancel()
        do {
            let place = try await placeSearch.resolve(suggestion)
            onPick(place)
        } catch {
            listState = .failed
        }
    }

    /// The location row. The owner closes the sheet before running the
    /// main-screen flow (Decision A), so this only reports the tap.
    func useMyLocation() {
        searchTask?.cancel()
        onUseMyLocation()
    }

    // MARK: - Removing recents

    /// Swipe-to-delete (§2).
    func removeRecent(_ place: Place) {
        placeStore.removeRecent(place)
        showRecentsIfUnderThreshold()
    }

    // MARK: - Query changes

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func queryDidChange(from oldValue: String) {
        guard query != oldValue else { return }
        searchTask?.cancel()
        searchTask = nil

        if showRecentsIfUnderThreshold() { return }

        // Whatever is showing stays until the first batch arrives, so the
        // list doesn't flash blank during the service's debounce (§8). But
        // recents still on screen are narrowed to the full query: left as
        // the one-letter list ("S" matches every "United States"), they sat
        // under the finger until the batch swapped them for other rows, and
        // a tap meant for a recent could land on a suggestion.
        narrowShownRecents()

        let query = trimmedQuery
        searchTask = Task { [weak self] in
            guard let self else { return }
            await updateSuggestions(for: query)
        }
    }

    /// Recents views are computed synchronously from the store. Returns
    /// whether the query was short enough for one of them.
    @discardableResult
    private func showRecentsIfUnderThreshold() -> Bool {
        let query = trimmedQuery
        if query.isEmpty {
            listState = .recents(placeStore.recents)
        } else if query.count < Self.searchMinimumCharacters {
            listState = .filteredRecents(placeStore.recents.filter { Self.place($0, matches: query) })
        } else {
            return false
        }
        return true
    }

    /// At 2+ characters, before the first batch: recents on screen shrink to
    /// those matching the whole query. If none match, the list is left as
    /// it is rather than going blank; suggestions are never replaced.
    private func narrowShownRecents() {
        switch listState {
        case .recents, .filteredRecents:
            let matching = placeStore.recents.filter { Self.place($0, matches: trimmedQuery) }
            if !matching.isEmpty {
                listState = .filteredRecents(matching)
            }
        case .suggestions, .noResults, .failed:
            break
        }
    }

    private func updateSuggestions(for query: String) async {
        do {
            for try await batch in placeSearch.suggestions(for: query) {
                guard !Task.isCancelled else { return }
                listState = batch.isEmpty ? .noResults : .suggestions(batch)
            }
        } catch {
            guard !Task.isCancelled else { return }
            listState = .failed
        }
    }

    // MARK: - Filtering

    /// Case- and diacritic-insensitive prefix match on any word of the name,
    /// region or country, so "s" finds "Sydney" and "n" finds "NSW" (§2).
    /// With several words ("Sydney NSW"), each must start some word.
    private static func place(_ place: Place, matches query: String) -> Bool {
        let words = [place.name, place.region, place.country]
            .compactMap { $0 }
            .flatMap { $0.components(separatedBy: CharacterSet.alphanumerics.inverted) }
        return query
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .allSatisfy { prefix in
                words.contains { word in
                    word.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
                }
            }
    }
}
