//
//  LocationViewModelOnboardingTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// How the main screen starts after each onboarding outcome (§5): the
/// detected city, the empty "a city" state, or the search sheet open.
@Suite("Onboarding → main screen")
@MainActor
struct OnboardingMainScreenTests {

    private static let detected = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
        isCurrentLocation: true
    )

    private static func makeLocationViewModel(location: FakeLocationService) -> LocationViewModel {
        LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService()
        )
    }

    @Test("Allow: the normal launch flow shows the detected city")
    func allowedShowsDetectedCity() async {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = Self.makeLocationViewModel(location: location)

        viewModel.onboardingDidFinish(.locationAllowed)
        await viewModel.start()

        #expect(viewModel.place == Self.detected)
        #expect(!viewModel.isSearchPresented)
    }

    @Test("Got it: the empty \"a city\" state, no sheet, no prompt")
    func declinedShowsEmptyState() async {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = Self.makeLocationViewModel(location: location)

        viewModel.onboardingDidFinish(.locationDeclined)
        await viewModel.start()

        #expect(viewModel.place == nil)
        #expect(viewModel.showsUseMyLocationButton)
        #expect(!viewModel.isSearchPresented)
        #expect(!location.didRequestAuthorization)
    }

    @Test("Search instead: the search sheet opens, no prompt; cancelling leaves the empty state")
    func searchInsteadOpensSheet() async {
        let location = FakeLocationService()
        let viewModel = Self.makeLocationViewModel(location: location)

        viewModel.onboardingDidFinish(.searchInstead)
        await viewModel.start()

        #expect(viewModel.isSearchPresented)
        #expect(viewModel.searchSheet != nil)
        #expect(!location.didRequestAuthorization)

        // Cancel: the sheet's binding closes it, then its onDismiss runs.
        viewModel.isSearchPresented = false
        await viewModel.searchDidDismiss()

        #expect(viewModel.place == nil)
        #expect(viewModel.showsUseMyLocationButton)
        #expect(!location.didRequestAuthorization)
    }

    @Test("The sheet opens on that start only, not on later ones")
    func searchOnStartOnce() async {
        let viewModel = Self.makeLocationViewModel(location: FakeLocationService())
        viewModel.onboardingDidFinish(.searchInstead)
        await viewModel.start()
        viewModel.isSearchPresented = false

        await viewModel.start()

        #expect(!viewModel.isSearchPresented)
    }
}
