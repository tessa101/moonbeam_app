//
//  LocationScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Picks the place, then shows its moon table (LOCATION.md §3).
///
/// Functional and deliberately unstyled: the visual design is a later,
/// design-led pass. All decisions live in `LocationViewModel`; this view only
/// owns focus and text selection, which are view state.
struct LocationScreen: View {

    @Bindable var viewModel: LocationViewModel

    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isSearchFocused: Bool
    @State private var searchSelection: TextSelection?

    /// "Search instead" focuses the field, but only once the sheet has gone;
    /// focusing under a dismissing sheet is dropped.
    @State private var focusSearchAfterDialog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where are you watching the moon tonight?")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                searchField
                suggestions

                if viewModel.isLocating {
                    ProgressView("Finding your location…")
                }

                if viewModel.showsUseMyLocation {
                    Button("Use my location") {
                        Task { await viewModel.useMyLocation() }
                    }
                }

                if viewModel.locationFailed {
                    Text("Couldn't find your location. Try again, or search for a city.")
                }

                if let backToPlace = viewModel.backToPlace {
                    Button("Back to \(backToPlace.shortName)") {
                        viewModel.goBack()
                    }
                }

                if let timeZoneLabel = viewModel.timeZoneLabel {
                    Text(timeZoneLabel)
                        .accessibilityLabel(viewModel.timeZoneAccessibilityLabel ?? timeZoneLabel)
                }

                if let moonTable = viewModel.moonTable {
                    ContentView(viewModel: moonTable)
                }
            }
            .padding()
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.sceneDidBecomeActive() }
        }
        .sheet(item: $viewModel.locationOffDialog, onDismiss: focusSearchIfRequested) { variant in
            LocationOffDialog(
                variant: variant,
                onSearch: {
                    focusSearchAfterDialog = true
                    viewModel.dismissLocationOffDialog()
                },
                onOpenedSettings: viewModel.dismissLocationOffDialog
            )
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack {
            TextField(viewModel.searchPrompt, text: $viewModel.searchText, selection: $searchSelection)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: isSearchFocused) { _, isFocused in
                    // §3: tapping into a filled field selects its text, so
                    // typing replaces the city rather than appending to it.
                    guard isFocused else { return }
                    let text = viewModel.searchText
                    searchSelection = TextSelection(range: text.startIndex..<text.endIndex)
                }

            if !viewModel.searchText.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    viewModel.clearSearch()
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestions: some View {
        switch viewModel.suggestionsState {
        case .hidden:
            EmptyView()
        case .results(let suggestions):
            ForEach(suggestions) { suggestion in
                Button {
                    isSearchFocused = false
                    Task { await viewModel.choose(suggestion) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(suggestion.title)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        case .noResults:
            Text("No matching cities")
        case .failed:
            Text("Can't search right now. Check your connection.")
        }
    }

    // MARK: - Actions

    private func focusSearchIfRequested() {
        guard focusSearchAfterDialog else { return }
        focusSearchAfterDialog = false
        isSearchFocused = true
    }
}

#Preview("First launch") {
    LocationScreen(
        viewModel: LocationViewModel(
            locationService: FakeLocationService(),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService()
        )
    )
}

#Preview("Denied, saved place") {
    LocationScreen(
        viewModel: LocationViewModel(
            locationService: FakeLocationService(authorizationState: .denied),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: SpikeMoonTableViewModel.marVista),
            moonService: AstronomyEngineMoonService()
        )
    )
}
