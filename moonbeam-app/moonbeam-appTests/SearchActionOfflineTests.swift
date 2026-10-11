//
//  SearchActionOfflineTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// STEP-5.10a-CHUNK-2C item 2: search actions show only when search can
/// work, online or with recents; their room is kept; the screen follows the
/// network live while it's up, and stops watching when it's gone.
@Suite("Search action offline", .timeLimit(.minutes(1)))
@MainActor
struct SearchActionOfflineTests {

    // MARK: - Which controls show

    /// Per cause, whether the button and link show when search can work and
    /// when it can't. Open Settings never depends on the network; No fix
    /// has no button; restricted's button is the search, and it has no link.
    @Test(
        "Each cause's controls, online and offline",
        arguments: [
            (LocationFailure.permissionDenied, true, true, true),
            (.permissionDenied, false, true, false),
            (.servicesOff, true, true, true),
            (.servicesOff, false, true, false),
            (.noFix, true, false, true),
            (.noFix, false, false, false),
            (.restricted, true, true, false),
            (.restricted, false, false, false),
        ]
    )
    func causeControls(failure: LocationFailure, searchAvailable: Bool, primary: Bool, link: Bool) {
        let visibility = MessageActionVisibility(
            copy: failure.copy,
            primaryIsSearch: failure.primaryAction == .search,
            searchAvailable: searchAvailable
        )
        #expect(visibility.showsPrimary == primary)
        #expect(visibility.showsLink == link)
    }

    @Test("First ask offline: Use my location stays, the search link goes")
    func firstAskKeepsUseMyLocation() {
        let issue = LocationIssue.firstAsk
        let offline = MessageActionVisibility(
            copy: issue.copy,
            primaryIsSearch: issue.primaryAction == .search,
            searchAvailable: false
        )
        #expect(offline.showsPrimary)
        #expect(!offline.showsLink)
        let online = MessageActionVisibility(copy: issue.copy, primaryIsSearch: false, searchAvailable: true)
        #expect(online.showsLink)
    }

    // MARK: - When search can work

    private static func makeViewModel(
        connectivity: FakeConnectivityService,
        recents: [Place] = []
    ) -> LocationViewModel {
        LocationViewModel(
            locationService: FakeLocationService(authorizationState: .denied),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(recents: recents),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            connectivity: connectivity,
            sleep: { _ in }
        )
    }

    private static func settle(until condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    @Test(
        "Search can work online, or offline with recents",
        arguments: [(true, false, true), (false, false, false), (false, true, true), (true, true, true)]
    )
    func offersCitySearch(online: Bool, hasRecents: Bool, offers: Bool) async {
        let connectivity = FakeConnectivityService(isOnline: online)
        let viewModel = Self.makeViewModel(connectivity: connectivity, recents: hasRecents ? [Place.marVista] : [])
        await viewModel.start()
        #expect(viewModel.showsSearchAction)

        let observing = Task { await viewModel.observeConnectivity() }
        await Self.settle { viewModel.isOnline == online }

        #expect(viewModel.offersCitySearch == offers)
        observing.cancel()
    }

    @Test("The screen follows the network live, and stops watching when the task ends")
    func followsLive() async {
        let connectivity = FakeConnectivityService(isOnline: true)
        let viewModel = Self.makeViewModel(connectivity: connectivity)
        await viewModel.start()
        let observing = Task { await viewModel.observeConnectivity() }
        await Self.settle { connectivity.observerCount == 1 }

        connectivity.isOnline = false
        await Self.settle { !viewModel.isOnline }
        #expect(!viewModel.offersCitySearch)

        connectivity.isOnline = true
        await Self.settle { viewModel.isOnline }
        #expect(viewModel.offersCitySearch)

        observing.cancel()
        await Self.settle { connectivity.observerCount == 0 }
        #expect(connectivity.observerCount == 0)
    }

    @Test("No screen with a search action, nothing to watch")
    func noSearchActionOnMainScreen() async {
        let viewModel = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .denied),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: Place.marVista),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            sleep: { _ in }
        )
        await viewModel.start()
        #expect(!viewModel.showsSearchAction)
    }
}
