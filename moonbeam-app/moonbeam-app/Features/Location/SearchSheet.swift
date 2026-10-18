//
//  SearchSheet.swift
//  moonbeam-app
//

import SwiftUI
import UIKit

/// The city search sheet: a field pinned at the top, then the location row
/// and recents, or type-ahead suggestions (SEARCH-RECENTS.md §2).
///
/// Plain visuals, like the rest of Step 2. All decisions live in
/// `SearchSheetViewModel`; this view only owns focus.
struct SearchSheet: View {

    @Bindable var viewModel: SearchSheetViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding()
            list
        }
        .onAppear {
            // §2: the sheet opens with the keyboard up, except with no
            // recents, where it would cover the five cities (STEP-5.13 §6).
            isFieldFocused = viewModel.autoFocusesField
        }
        // The location row with no prompt possible: the app's Settings
        // page, sheet still up (STEP-5.13 §3).
        .onChange(of: viewModel.settingsRequestCount) {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            HStack {
                TextField(LocationViewModel.searchPlaceholder, text: $viewModel.query)
                    .focused($isFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !viewModel.query.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") {
                        viewModel.query = ""
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.inline(.secondary))
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.inline)
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            switch viewModel.listState {
            case .recents(let recents):
                ForEach(viewModel.zeroStateSections, id: \.self) { section in
                    switch section {
                    case .useMyLocation: useMyLocationSection
                    case .recents: recentsSection(recents)
                    case .suggestedCities: suggestedCitiesSection
                    }
                }
            case .filteredRecents(let recents):
                recentsSection(recents)
            case .suggestions(let suggestions):
                ForEach(suggestions) { suggestion in
                    suggestionRow(suggestion)
                }
            case .noResults:
                Text("No matching cities")
            case .failed:
                Text("Can't search right now. Check your connection.")
            }
        }
    }

    /// First in the 0-character view, with the place pin (STEP-5.13 §3).
    private var useMyLocationSection: some View {
        Section {
            Button {
                viewModel.useMyLocation()
            } label: {
                Label {
                    Text("Use my location")
                } icon: {
                    Image(SearchSheetViewModel.locationRowSymbol)
                }
            }
            // The row style leaves the color to the label; keep the tint.
            .foregroundStyle(.tint)
            .buttonStyle(.row)
        }
    }

    /// The five fixed cities, with no recents (STEP-5.13 §3).
    private var suggestedCitiesSection: some View {
        Section {
            ForEach(viewModel.suggestedCities, id: \.self) { city in
                Button {
                    viewModel.pick(city)
                } label: {
                    placeLabel(title: city.title, detail: city.detail)
                }
                .buttonStyle(.row)
                .accessibilityLabel(city.accessibilityLabel)
            }
        } header: {
            Text(SearchSheetViewModel.suggestedCitiesTitle)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Empty recents show no header at all: the 0-character view then has
    /// the five cities instead, and 1 character with no match is a blank list.
    @ViewBuilder
    private func recentsSection(_ recents: [Place]) -> some View {
        if !recents.isEmpty {
            Section("Recent") {
                ForEach(recents, id: \.self) { place in
                    Button {
                        viewModel.pick(place)
                    } label: {
                        placeLabel(title: place.shortName, detail: place.displayName)
                    }
                    .buttonStyle(.row)
                    .accessibilityLabel(place.displayName)
                }
                .onDelete { offsets in
                    for index in offsets {
                        viewModel.removeRecent(recents[index])
                    }
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: PlaceSuggestion) -> some View {
        Button {
            Task { await viewModel.pick(suggestion) }
        } label: {
            placeLabel(title: suggestion.title, detail: suggestion.subtitle)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .combine)
    }

    /// Fixed label colors rather than the hierarchical `.secondary`, which
    /// inside a button derives from the tint and renders as a faint blue.
    private func placeLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundStyle(Color.primary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("No recents") {
    SearchSheet(
        viewModel: SearchSheetViewModel(
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            showsUseMyLocation: true,
            onPick: { _ in },
            onUseMyLocation: {}
        )
    )
}

#Preview("Recents") {
    SearchSheet(
        viewModel: SearchSheetViewModel(
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(recents: [Place.marVista]),
            showsUseMyLocation: true,
            onPick: { _ in },
            onUseMyLocation: {}
        )
    )
}
#endif
