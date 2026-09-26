//
//  LocationScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Picks the place, then shows its moon table (LOCATION.md §3).
///
/// Functional and deliberately unstyled: the visual design is a later,
/// design-led pass. All decisions live in `LocationViewModel`, including
/// which sheet opens after another has finished closing.
struct LocationScreen: View {

    @Bindable var viewModel: LocationViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where are you watching the moon tonight?")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                searchButton

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
        .sheet(item: $viewModel.locationOffDialog, onDismiss: viewModel.locationOffDialogDidDismiss) { variant in
            LocationOffDialog(
                variant: variant,
                onSearch: viewModel.searchInsteadOfLocation,
                onOpenedSettings: viewModel.dismissLocationOffDialog
            )
        }
        .sheet(isPresented: $viewModel.isSearchPresented, onDismiss: searchDidDismiss) {
            if let searchSheet = viewModel.searchSheet {
                SearchSheet(viewModel: searchSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Search button

    /// Looks like a field but only opens the sheet; typing happens there
    /// (SEARCH-RECENTS.md §1).
    private var searchButton: some View {
        Button(action: viewModel.presentSearch) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                Text(viewModel.searchFieldTitle)
                    .foregroundStyle(viewModel.place == nil ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocationViewModel.searchPlaceholder)
        .accessibilityValue(viewModel.place?.shortName ?? "")
    }

    // MARK: - Actions

    private func searchDidDismiss() {
        Task { await viewModel.searchDidDismiss() }
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
