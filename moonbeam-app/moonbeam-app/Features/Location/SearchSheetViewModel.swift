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
        case recents([Place])               // 0 chars; empty → location row and the five cities
        case filteredRecents([Place])       // 1 char; empty → blank list, no error copy
        case suggestions([PlaceSuggestion]) // 2+ chars
        case noResults
        case failed                         // search or resolve failed
    }

    /// The 0-character view's sections, top to bottom (STEP-5.13 §3).
    enum ZeroStateSection: Equatable {
        /// Use my location, with the place pin.
        case useMyLocation
        /// Recent, when there are recents.
        case recents
        /// "Search for your city or choose one of these", with no recents.
        case suggestedCities
    }

    // MARK: - Constants

    /// Shorter queries never reach the search service. One constant so the
    /// threshold can move to 3 after device testing (§2, §7).
    static let searchMinimumCharacters = 2

    /// The location row's icon: the main page's place-token pin, not the
    /// arrow (STEP-5.13 §3).
    static let locationRowSymbol = MadlibFormatter.placeSymbol

    static let suggestedCitiesTitle = "Search for your city or choose one of these"

    // MARK: - Observed state

    /// The sheet's field. Always starts empty (§1).
    var query = "" {
        didSet { queryDidChange(from: oldValue) }
    }

    private(set) var listState: ListState

    /// Mirrors the main screen: hidden when the current place is already the
    /// detected location (Decision B).
    let showsUseMyLocation: Bool

    /// SEARCH-RECENTS.md §2 opens with the keyboard up, but with no recents
    /// it would cover the suggested cities (STEP-5.13 §6), so the field
    /// waits for a tap then. Decided once, as the sheet opens.
    let autoFocusesField: Bool

    /// The five fixed cities, offered while there are no recents.
    let suggestedCities = SuggestedCity.all

    /// Goes up by one each time the location row can't show a prompt
    /// (denied, Location Services off): the view opens the app's Settings
    /// page and the sheet stays, as on the onboarding upsell.
    private(set) var settingsRequestCount = 0

    // MARK: - Dependencies

    private let placeSearch: any PlaceSearchService
    private let placeStore: any PlaceStore
    private let onPick: (Place) -> Void
    private let onUseMyLocation: () -> Void
    /// Asked at each location-row tap: true when no prompt can show, so the
    /// row opens Settings instead of closing the sheet. The owner records
    /// the trip so a return authorized can finish as Allow.
    private let locationRowOpensSettings: () -> Bool

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
        onUseMyLocation: @escaping () -> Void,
        locationRowOpensSettings: @escaping () -> Bool = { false }
    ) {
        self.placeSearch = placeSearch
        self.placeStore = placeStore
        self.showsUseMyLocation = showsUseMyLocation
        self.onPick = onPick
        self.onUseMyLocation = onUseMyLocation
        self.locationRowOpensSettings = locationRowOpensSettings
        autoFocusesField = !placeStore.recents.isEmpty
        listState = .recents(placeStore.recents)
    }

    // MARK: - 0-character view (STEP-5.13 §3)

    /// What the 0-character view shows, in order: the location row first,
    /// then Recent, or the five cities when there are no recents. Typing
    /// leaves this view, so the cities go with it.
    var zeroStateSections: [ZeroStateSection] {
        guard case .recents(let recents) = listState else { return [] }
        var sections: [ZeroStateSection] = []
        if showsUseMyLocation { sections.append(.useMyLocation) }
        if recents.isEmpty {
            if !suggestedCities.isEmpty { sections.append(.suggestedCities) }
        } else {
            sections.append(.recents)
        }
        return sections
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

    /// The location row. Where no prompt can show, Settings opens and the
    /// sheet stays (STEP-5.13 §3). Otherwise the owner closes the sheet
    /// before running the main-screen flow (Decision A), so this only
    /// reports the tap.
    func useMyLocation() {
        searchTask?.cancel()
        if locationRowOpensSettings() {
            settingsRequestCount += 1
        } else {
            onUseMyLocation()
        }
    }

    /// One of the five cities: a fixed place, picked like a recent, so it
    /// becomes one (the owner adds it).
    func pick(_ city: SuggestedCity) {
        pick(city.place)
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
