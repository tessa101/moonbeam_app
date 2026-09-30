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

                // Location controls and their status stay together, under
                // the search field that they're the alternative to. The
                // button is first-launch only (4.11); after that it's the
                // search sheet's row.
                if viewModel.showsUseMyLocationButton {
                    Button("Use my location") {
                        Task { await viewModel.useMyLocation() }
                    }
                }

                if viewModel.isLocating {
                    ProgressView("Finding your location…")
                }

                if viewModel.locationFailed {
                    Text("Couldn't find your location. Try again, or search for a city.")
                }

                // DATE.md §1: above the time zone label and the moon table.
                if viewModel.place != nil {
                    DateControl(viewModel: viewModel)
                }

                if let timeZoneLabel = viewModel.timeZoneLabel {
                    Text(timeZoneLabel)
                        .accessibilityLabel(viewModel.timeZoneAccessibilityLabel ?? timeZoneLabel)
                }

                if let moonTable = viewModel.moonTable {
                    ContentView(viewModel: moonTable)
                }

                // COMPASS.md §1: at the bottom, below the moon table. DEBUG
                // builds keep it in every state for its diagnostic readout;
                // the sensors still only run when it's shown.
                if viewModel.compass.visibility != .hidden || Self.showsDebugReadout {
                    compass
                }
            }
            .padding()
        }
        // 4.15: content mustn't slide under the clock unreadably. The
        // system's soft edge effect, as in system apps; styling is the
        // design pass.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .modifier(StatusBarBackdrop())
        .task {
            await viewModel.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await viewModel.sceneDidBecomeActive() }
            case .background:
                viewModel.sceneDidEnterBackground()
            default:
                // Inactive (Control Center, the permission prompt) keeps the
                // compass running; only the background stops it (§1).
                break
            }
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
        .sheet(isPresented: $viewModel.isCalendarPresented) {
            CalendarSheet(viewModel: viewModel)
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
        .accessibilityValue(viewModel.place?.nameWithRegion ?? "")
    }

    // MARK: - Compass

    #if DEBUG
    private static let showsDebugReadout = true
    #else
    private static let showsDebugReadout = false
    #endif

    /// Reports whether the compass is on screen, which (with foreground and
    /// visibility) decides whether its sensors run (COMPASS.md §1).
    ///
    /// The stack isn't lazy, so `onAppear` fires on insertion even when the
    /// compass is below the fold. It isn't used for "on screen", or the
    /// sensors would start off screen. `onScrollVisibilityChange` also fires
    /// on appearing when already past its threshold, which covers insertion.
    /// `onDisappear` covers removal.
    private var compass: some View {
        CompassView(
            viewModel: viewModel.compass,
            onTurnOnLocation: { Task { await viewModel.turnOnLocationForCompass() } },
            onUsePreciseLocation: { Task { await viewModel.usePreciseLocationForCompass() } }
        )
        .onScrollVisibilityChange { isVisible in
            viewModel.compass.setOnScreen(isVisible)
        }
        .onDisappear {
            viewModel.compass.setOnScreen(false)
        }
    }

    // MARK: - Actions

    private func searchDidDismiss() {
        Task { await viewModel.searchDidDismiss() }
    }
}

// MARK: - Status bar (4.15)

/// The fallback for iOS 26 (DECISIONS.md 2026-09-30): the device test on
/// iOS 26.6.2 showed no edge effect at all for this bare `ScrollView` under
/// the status bar, so the date control sat crisp behind the clock. There the
/// status bar gets the system bar material instead. iOS 27 draws the soft
/// edge effect itself, so it's left alone.
private struct StatusBarBackdrop: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                // Zero height: the material fills only the status bar,
                // since a background extends into the safe area it touches.
                Color.clear
                    .frame(height: 0)
                    .background(.bar)
            }
        }
    }
}

#Preview("First launch") {
    LocationScreen(
        viewModel: LocationViewModel(
            locationService: FakeLocationService(),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService()
        )
    )
}

#Preview("Denied, saved place") {
    LocationScreen(
        viewModel: LocationViewModel(
            locationService: FakeLocationService(authorizationState: .denied),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: SpikeMoonTableViewModel.marVista),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService()
        )
    )
}
