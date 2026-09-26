//
//  SearchSheetViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `SearchSheetViewModel`'s list states and picks (SEARCH-RECENTS.md §2, §5,
/// §8), against the fakes.
@Suite("Search sheet view model")
@MainActor
struct SearchSheetViewModelTests {

    // MARK: - Fixtures

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    private static let lisbon = Place(
        name: "Lisbon",
        country: "Portugal",
        latitude: 38.72,
        longitude: -9.14,
        timeZone: TimeZone(identifier: "Europe/Lisbon") ?? .gmt
    )

    private static let evora = Place(
        name: "Évora",
        country: "Portugal",
        latitude: 38.57,
        longitude: -7.91,
        timeZone: TimeZone(identifier: "Europe/Lisbon") ?? .gmt
    )

    private static let sydneySuggestion = PlaceSuggestion(title: "Sydney", subtitle: "NSW, Australia")

    private static func sydneySearch() -> FakePlaceSearchService {
        FakePlaceSearchService(
            suggestionsByQuery: ["Sy": [sydneySuggestion], "Syd": [sydneySuggestion]],
            placesBySuggestion: [sydneySuggestion.id: sydney]
        )
    }

    /// Records picks, so tests can check both what was picked and that
    /// nothing was.
    @MainActor
    private final class PickRecorder {
        var picked: [Place] = []
    }

    private static func makeViewModel(
        search: FakePlaceSearchService = FakePlaceSearchService(),
        recents: [Place] = [],
        showsUseMyLocation: Bool = true,
        recorder: PickRecorder = PickRecorder()
    ) -> SearchSheetViewModel {
        SearchSheetViewModel(
            placeSearch: search,
            placeStore: InMemoryPlaceStore(recents: recents),
            showsUseMyLocation: showsUseMyLocation,
            onPick: { recorder.picked.append($0) }
        )
    }

    /// Sets the query and waits for any type-ahead it started.
    private static func type(_ query: String, into viewModel: SearchSheetViewModel) async {
        viewModel.query = query
        await viewModel.searchTask?.value
    }

    // MARK: - Empty query

    @Test("Empty query shows recents most recent first, without searching")
    func emptyQueryShowsRecents() {
        let search = FakePlaceSearchService()
        let viewModel = Self.makeViewModel(search: search, recents: [Self.lisbon, Self.sydney])

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.listState == .recents([Self.lisbon, Self.sydney]))
        #expect(search.searchedQueries.isEmpty)
    }

    @Test("Empty query with no recents shows only the location row")
    func emptyQueryNoRecents() {
        let viewModel = Self.makeViewModel()

        #expect(viewModel.listState == .recents([]))
        #expect(viewModel.showsUseMyLocation)
    }

    @Test("showsUseMyLocation passes through", arguments: [true, false])
    func showsUseMyLocationPassesThrough(shows: Bool) {
        #expect(Self.makeViewModel(showsUseMyLocation: shows).showsUseMyLocation == shows)
    }

    // MARK: - One character

    @Test("1 character filters recents without searching")
    func oneCharacterFiltersRecents() async {
        let search = Self.sydneySearch()
        let viewModel = Self.makeViewModel(search: search, recents: [Self.lisbon, Self.sydney])

        await Self.type("s", into: viewModel)

        #expect(viewModel.listState == .filteredRecents([Self.sydney]))
        #expect(search.searchedQueries.isEmpty)
    }

    /// Whitespace doesn't count towards the threshold.
    @Test("Padding around 1 character still filters without searching")
    func paddedOneCharacter() async {
        let search = Self.sydneySearch()
        let viewModel = Self.makeViewModel(search: search, recents: [Self.sydney])

        await Self.type("  s ", into: viewModel)

        #expect(viewModel.listState == .filteredRecents([Self.sydney]))
        #expect(search.searchedQueries.isEmpty)
    }

    /// §5's example is "syd", but at 3 characters that's type-ahead; the
    /// matcher is exercised with the single characters it actually receives.
    @Test(
        "Prefix match on any word of name, region or country, ignoring case",
        arguments: ["s", "S", "n", "a"]
    )
    func matchesAnyWord(query: String) async {
        let viewModel = Self.makeViewModel(recents: [Self.lisbon, Self.sydney])

        await Self.type(query, into: viewModel)

        #expect(viewModel.listState == .filteredRecents([Self.sydney]))
    }

    /// Only prefixes of words: "y" is inside "Sydney" but starts no word.
    @Test("A letter inside a word doesn't match")
    func midWordDoesNotMatch() async {
        let viewModel = Self.makeViewModel(recents: [Self.sydney])

        await Self.type("y", into: viewModel)

        #expect(viewModel.listState == .filteredRecents([]))
    }

    @Test("Diacritics are ignored in both directions")
    func diacriticsAreIgnored() async {
        let edinburgh = Place(name: "Edinburgh", country: "United Kingdom", latitude: 55.95, longitude: -3.19, timeZone: .gmt)
        let viewModel = Self.makeViewModel(recents: [Self.evora, edinburgh, Self.sydney])

        await Self.type("e", into: viewModel)
        #expect(viewModel.listState == .filteredRecents([Self.evora, edinburgh]))

        await Self.type("é", into: viewModel)
        #expect(viewModel.listState == .filteredRecents([Self.evora, edinburgh]))
    }

    @Test("No matching recents is an empty list, not an error")
    func noMatchingRecents() async {
        let viewModel = Self.makeViewModel(recents: [Self.sydney])

        await Self.type("x", into: viewModel)

        #expect(viewModel.listState == .filteredRecents([]))
    }

    // MARK: - Two or more characters

    @Test("2 characters search and show suggestions")
    func twoCharactersSearch() async {
        let search = Self.sydneySearch()
        let viewModel = Self.makeViewModel(search: search, recents: [Self.sydney])

        await Self.type("Sy", into: viewModel)

        #expect(search.searchedQueries == ["Sy"])
        #expect(viewModel.listState == .suggestions([Self.sydneySuggestion]))
    }

    /// §8: no blank flash while the service debounces.
    @Test("Going from 1 to 2 characters keeps the filtered recents until the first batch")
    func filteredRecentsStayUntilFirstBatch() async {
        let viewModel = Self.makeViewModel(search: Self.sydneySearch(), recents: [Self.lisbon, Self.sydney])

        await Self.type("S", into: viewModel)
        viewModel.query = "Sy"

        #expect(viewModel.listState == .filteredRecents([Self.sydney]))

        await viewModel.searchTask?.value
        #expect(viewModel.listState == .suggestions([Self.sydneySuggestion]))
    }

    @Test("Clearing the field goes back to recents")
    func clearingGoesBackToRecents() async {
        let search = Self.sydneySearch()
        let viewModel = Self.makeViewModel(search: search, recents: [Self.lisbon, Self.sydney])

        await Self.type("Syd", into: viewModel)
        await Self.type("", into: viewModel)

        #expect(viewModel.listState == .recents([Self.lisbon, Self.sydney]))
        #expect(search.searchedQueries == ["Syd"])
    }

    @Test("No-results and network-error states still map at 2+ characters")
    func noResultsAndErrorStates() async {
        let search = Self.sydneySearch()
        let viewModel = Self.makeViewModel(search: search)

        await Self.type("Xyzzy", into: viewModel)
        #expect(viewModel.listState == .noResults)

        search.searchError = URLError(.notConnectedToInternet)
        await Self.type("Syd", into: viewModel)
        #expect(viewModel.listState == .failed)
    }

    // MARK: - Picking

    @Test("Tapping a recent picks it without resolving")
    func pickingARecent() {
        let search = Self.sydneySearch()
        let recorder = PickRecorder()
        let viewModel = Self.makeViewModel(search: search, recents: [Self.sydney], recorder: recorder)

        viewModel.pick(Self.sydney)

        #expect(recorder.picked == [Self.sydney])
        #expect(search.resolvedSuggestions.isEmpty)
    }

    @Test("Tapping a suggestion resolves it, then picks the place")
    func pickingASuggestion() async {
        let search = Self.sydneySearch()
        let recorder = PickRecorder()
        let viewModel = Self.makeViewModel(search: search, recorder: recorder)

        await Self.type("Syd", into: viewModel)
        await viewModel.pick(Self.sydneySuggestion)

        #expect(search.resolvedSuggestions == [Self.sydneySuggestion])
        #expect(recorder.picked == [Self.sydney])
    }

    @Test("A suggestion that won't resolve shows .failed and picks nothing")
    func resolveFailure() async {
        let search = Self.sydneySearch()
        search.resolveError = URLError(.notConnectedToInternet)
        let recorder = PickRecorder()
        let viewModel = Self.makeViewModel(search: search, recorder: recorder)

        await Self.type("Syd", into: viewModel)
        await viewModel.pick(Self.sydneySuggestion)

        #expect(viewModel.listState == .failed)
        #expect(recorder.picked.isEmpty)
    }

    // MARK: - Removing recents

    @Test("Swiping a recent away removes it from the store and the list")
    func removingARecent() async {
        let store = InMemoryPlaceStore(recents: [Self.lisbon, Self.sydney])
        let viewModel = SearchSheetViewModel(
            placeSearch: FakePlaceSearchService(),
            placeStore: store,
            showsUseMyLocation: true,
            onPick: { _ in }
        )

        viewModel.removeRecent(Self.lisbon)
        #expect(store.recents == [Self.sydney])
        #expect(viewModel.listState == .recents([Self.sydney]))

        // Also from the filtered view.
        await Self.type("s", into: viewModel)
        viewModel.removeRecent(Self.sydney)
        #expect(viewModel.listState == .filteredRecents([]))
    }
}
