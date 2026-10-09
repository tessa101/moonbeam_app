//
//  PlaceSkeletonTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// LOADER.md §12.2–12.3 and §12.5: the card skeleton during an explicit
/// "Use my location" replacement. The 400 ms threshold is injected, so each
/// test decides whether it has passed.
@Suite("Place change card skeleton", .timeLimit(.minutes(1)))
@MainActor
struct PlaceSkeletonTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    private static let detectedLosAngeles = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: losAngelesZone,
        isCurrentLocation: true
    )

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: sydneyZone
    )

    /// 2026-09-23 12:00 in Sydney, the ASTRONOMY.md §5 date.
    private static let referenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sydneyZone
        let components = DateComponents(year: 2026, month: 9, day: 23, hour: 12)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    /// The threshold passes at once.
    private static let thresholdPassed: @Sendable (Duration) async throws -> Void = { _ in }

    /// The threshold never passes within a test; a landed fix cancels it.
    private static let thresholdPending: @Sendable (Duration) async throws -> Void = { _ in
        try await Task.sleep(for: .seconds(30))
    }

    /// Showing Sydney, ready, with `location` answering the next fix.
    private static func makeReadyViewModel(
        location: FakeLocationService,
        placeChangeSleep: @escaping @Sendable (Duration) async throws -> Void
    ) async -> LocationViewModel {
        let viewModel = LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: sydney),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            deviceTimeZone: losAngelesZone,
            now: { referenceDate },
            placeChangeSleep: placeChangeSleep
        )
        await viewModel.start()
        viewModel.select(sydney)
        return viewModel
    }

    private static func waitUntil(_ condition: () -> Bool) async {
        while !condition() {
            await Task.yield()
        }
    }

    // MARK: - Tests

    @Test("§12.2 under 400 ms: no skeleton, straight to the card")
    func fastFixShowsNoSkeleton() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let viewModel = await Self.makeReadyViewModel(location: location, placeChangeSleep: Self.thresholdPending)
        location.holdsFixes = true

        let locate = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { location.heldFixCount > 0 }
        #expect(viewModel.moonTable == nil)
        #expect(viewModel.cardPlaceholder == nil)

        location.releaseFixes()
        await locate.value

        #expect(viewModel.cardPlaceholder == nil)
        #expect(viewModel.showsPlaceSkeleton == false)
        #expect(viewModel.moonTable != nil)
        #expect(viewModel.place == Self.detectedLosAngeles)
    }

    @Test("§12.2 over 400 ms: skeleton sized by the old card, then the new card")
    func slowFixShowsSkeletonThenCard() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let viewModel = await Self.makeReadyViewModel(location: location, placeChangeSleep: Self.thresholdPassed)
        let generation = viewModel.loadInGeneration
        location.holdsFixes = true

        let locate = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { location.heldFixCount > 0 && viewModel.cardPlaceholder != nil }

        #expect(viewModel.cardPlaceholder == .finding)
        #expect(viewModel.skeletonLayoutTable != nil)
        #expect(viewModel.moonTable == nil)
        // No compass while the skeleton holds the slot (§12.3).
        #expect(viewModel.isReplacingPlace)

        location.releaseFixes()
        await locate.value

        #expect(viewModel.cardPlaceholder == nil)
        #expect(viewModel.skeletonLayoutTable == nil)
        #expect(viewModel.moonTable != nil)
        // One replay for the old place going, one for the new place landing.
        #expect(viewModel.loadInGeneration == generation + 2)
    }

    @Test("§12.2 step 5: a failed fix shows the failure in the skeleton; the old place stays gone")
    func failedFixShowsFailureInSkeleton() async {
        let location = FakeLocationService(authorizationState: .authorized)
        let viewModel = await Self.makeReadyViewModel(location: location, placeChangeSleep: Self.thresholdPending)

        await viewModel.useMyLocation()

        #expect(viewModel.cardPlaceholder == .failed)
        #expect(viewModel.skeletonLayoutTable != nil)
        #expect(viewModel.place == nil)
        #expect(viewModel.moonTable == nil)
    }

    @Test("§12.2 step 5: Location Off ends the replacement as a failure, not an endless Finding")
    func blockedReplacementShowsFailure() async {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = await Self.makeReadyViewModel(location: location, placeChangeSleep: Self.thresholdPassed)

        await viewModel.useMyLocation()

        #expect(viewModel.locationOffDialog == .denied)
        #expect(viewModel.cardPlaceholder == .failed)
        #expect(viewModel.place == nil)
    }

    @Test("A retry after a failure shows Finding at once, with no empty slot")
    func retryAfterFailureShowsFindingImmediately() async {
        let location = FakeLocationService(authorizationState: .authorized)
        let viewModel = await Self.makeReadyViewModel(location: location, placeChangeSleep: Self.thresholdPending)
        await viewModel.useMyLocation()
        #expect(viewModel.cardPlaceholder == .failed)

        location.placeResult = .success(Self.detectedLosAngeles)
        location.holdsFixes = true
        let retry = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { location.heldFixCount > 0 }

        #expect(viewModel.cardPlaceholder == .finding)

        location.releaseFixes()
        await retry.value
        #expect(viewModel.cardPlaceholder == nil)
        #expect(viewModel.place == Self.detectedLosAngeles)
    }

    @Test("Picking a city while the skeleton shows replaces it with the city's card")
    func pickDuringSkeletonClearsIt() async {
        let location = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.detectedLosAngeles)
        )
        let viewModel = await Self.makeReadyViewModel(location: location, placeChangeSleep: Self.thresholdPassed)
        location.holdsFixes = true

        let locate = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { location.heldFixCount > 0 && viewModel.cardPlaceholder != nil }

        viewModel.select(Self.sydney)
        #expect(viewModel.cardPlaceholder == nil)
        #expect(viewModel.place == Self.sydney)

        location.releaseFixes()
        await locate.value
        #expect(viewModel.place == Self.sydney)
        #expect(viewModel.cardPlaceholder == nil)
    }
}
