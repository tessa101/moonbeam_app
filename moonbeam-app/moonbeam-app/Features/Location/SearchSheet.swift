//
//  SearchSheet.swift
//  moonbeam-app
//

import SwiftUI

/// The city search sheet: a field pinned at the top, then the location row
/// and recents, or type-ahead suggestions (SEARCH-RECENTS.md §2).
///
/// Plain visuals, like the rest of Step 2. All decisions live in
/// `SearchSheetViewModel`; this view only owns focus.
struct SearchSheet: View {

    @Bindable var viewModel: SearchSheetViewModel

    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding()
            list
        }
        .onAppear {
            // §2: the sheet opens with the keyboard up.
            isFieldFocused = true
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
                    .foregroundStyle(.secondary)
                }
            }

            Button("Cancel") {
                dismiss()
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            switch viewModel.listState {
            case .recents(let recents):
                if viewModel.showsUseMyLocation {
                    Section {
                        Button("Use my location", systemImage: "location") {
                            viewModel.useMyLocation()
                        }
                    }
                }
                recentsSection(recents)
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

    /// Empty recents show no header at all: the 0-character view is then
    /// just the location row, and 1 character with no match is a blank list.
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

#Preview("Recents") {
    SearchSheet(
        viewModel: SearchSheetViewModel(
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(recents: [SpikeMoonTableViewModel.marVista]),
            showsUseMyLocation: true,
            onPick: { _ in },
            onUseMyLocation: {}
        )
    )
}
