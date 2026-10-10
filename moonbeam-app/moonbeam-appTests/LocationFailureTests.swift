//
//  LocationFailureTests.swift
//  moonbeam-appTests
//

import CoreLocation
import Foundation
import Testing
@testable import moonbeam_app

/// STEP-5.10a-LOCATION-FAILURE.md, Chunk 1: which failure each permission
/// state and fetch error is, and when the view model sets it.
@Suite("Location failure", .timeLimit(.minutes(1)))
@MainActor
struct LocationFailureTests {

    // MARK: - Fixtures

    private static let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private static let detected = Place(
        name: "Irvine",
        region: "CA",
        latitude: 33.68,
        longitude: -117.83,
        timeZone: zone,
        isCurrentLocation: true
    )

    private static let saved = Place(
        name: "Sydney",
        region: "NSW",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: TimeZone(identifier: "Australia/Sydney") ?? .gmt
    )

    private static let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Far past any timeout here: a fix that lands only if nothing cancels it.
    private static let hangingFixDelay = Duration.seconds(30)

    /// A stand-in for the timeout's `Task.sleep` that the test fires by
    /// hand: the fake clock for the 10 s.
    @MainActor
    private final class ManualSleeper {
        private var waiters: [CheckedContinuation<Void, any Error>] = []
        private(set) var durations: [Duration] = []
        var pendingCount: Int { waiters.count }

        func sleep(_ duration: Duration) async throws {
            durations.append(duration)
            try await withCheckedThrowingContinuation { waiters.append($0) }
        }

        func fire() {
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume() }
        }
    }

    /// The timeout never fires within a test.
    private static let timeoutPending: @Sendable (Duration) async throws -> Void = { _ in
        try await Task.sleep(for: .seconds(60))
    }

    private static func makeViewModel(
        location: FakeLocationService,
        lastViewed: Place? = nil,
        fetchTimeoutSleep: @escaping @Sendable (Duration) async throws -> Void = timeoutPending
    ) -> LocationViewModel {
        LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: lastViewed),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            fetchTimeoutSleep: fetchTimeoutSleep,
            deviceTimeZone: zone,
            now: { reference },
            // Loader and skeleton waits pass at once.
            sleep: { _ in },
            placeChangeSleep: { _ in },
            loaderNow: { reference }
        )
    }

    /// Ready on `saved`, with `location` answering the next fix.
    private static func makeReadyViewModel(location: FakeLocationService) async -> LocationViewModel {
        let viewModel = makeViewModel(location: location, lastViewed: saved)
        await viewModel.start()
        viewModel.select(saved)
        return viewModel
    }

    /// Stops on cancellation, so the suite's time limit can end it.
    private static func waitUntil(_ condition: () -> Bool) async {
        while !condition(), !Task.isCancelled {
            await Task.yield()
        }
    }

    private static func placeTokenText(_ viewModel: LocationViewModel) -> String? {
        viewModel.madlibSentence(allowsBreaksInsideTokens: true).tokens.first { $0.kind == .place }?.text
    }

    // MARK: - Mapping

    @Test(
        "Each permission state maps to its failure",
        arguments: [
            (LocationAuthState.denied, LocationFailure?.some(.permissionDenied)),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
            (.authorized, nil),
            (.notDetermined, nil),
        ]
    )
    func stateMapping(state: LocationAuthState, failure: LocationFailure?) {
        #expect(LocationFailure(state) == failure)
    }

    @Test(
        "Every fetch error is No fix",
        arguments: [
            LocationError.locationUnavailable as any Error,
            LocationError.couldNotIdentifyPlace,
            CancellationError(),
            CLError(.locationUnknown),
            URLError(.notConnectedToInternet),
        ]
    )
    func errorMapping(error: any Error) {
        #expect(LocationFailure(fixError: error, state: .authorized) == .noFix)
    }

    @Test(
        "Permission withdrawn mid-fix is the permission's own failure",
        arguments: [
            (LocationAuthState.denied, LocationFailure.permissionDenied),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
            (.authorized, .noFix),
        ]
    )
    func withdrawnMapping(state: LocationAuthState, failure: LocationFailure) {
        #expect(LocationFailure(fixError: LocationError.notAuthorized, state: state) == failure)
    }

    // MARK: - Use my location

    @Test(
        "Use my location, fix fails: No fix, no stale skeleton, token back to \"a city\", old place gone",
        arguments: [LocationError.locationUnavailable, .couldNotIdentifyPlace]
    )
    func useMyLocationFixFails(error: LocationError) async {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = await Self.makeReadyViewModel(location: location)
        location.placeResult = .failure(error)

        await viewModel.useMyLocation()

        #expect(viewModel.locationFailure == .noFix)
        #expect(viewModel.place == nil)
        #expect(viewModel.moonTable == nil)
        #expect(!viewModel.isLocating)
        #expect(!viewModel.isReplacingPlace)
        #expect(!viewModel.showsPlaceSkeleton)
        #expect(viewModel.skeletonLayoutTable == nil)
        #expect(Self.placeTokenText(viewModel) == "a city")
        #expect(!viewModel.madlibSentence(allowsBreaksInsideTokens: true).placeIsPending)
    }

    @Test(
        "Use my location, permission off: the failure for the state",
        arguments: [
            (LocationAuthState.denied, LocationFailure.permissionDenied),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
        ]
    )
    func useMyLocationBlocked(state: LocationAuthState, failure: LocationFailure) async {
        let location = FakeLocationService(authorizationState: state)
        let viewModel = await Self.makeReadyViewModel(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.locationFailure == failure)
        #expect(viewModel.place == nil)
        #expect(!viewModel.isReplacingPlace)
        #expect(viewModel.skeletonLayoutTable == nil)
        #expect(location.currentPlaceCount == 0)
    }

    @Test("Don't Allow at the prompt: app permission off")
    func promptRefused() async {
        let location = FakeLocationService(authorizationState: .notDetermined)
        location.stateAfterRequest = .denied
        let viewModel = await Self.makeReadyViewModel(location: location)

        await viewModel.useMyLocation()

        #expect(viewModel.locationFailure == .permissionDenied)
        #expect(viewModel.place == nil)
    }

    @Test("Permission withdrawn while the fix is out: read fresh, so services off isn't called denied")
    func withdrawnMidFix() async {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = await Self.makeReadyViewModel(location: location)
        location.placeResult = .failure(LocationError.notAuthorized)
        location.holdsFixes = true

        let locate = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { location.heldFixCount > 0 }
        location.authorizationState = .servicesOff
        location.releaseFixes()
        await locate.value

        #expect(viewModel.locationFailure == .servicesOff)
    }

    // MARK: - Timeout

    @Test("No fix within 10 s: the timeout cancels the fix and it's No fix")
    func timeoutIsNoFix() async {
        let timeout = ManualSleeper()
        // Off at launch, so the launch takes no fix (and no timeout); on
        // before the tap.
        let location = FakeLocationService(authorizationState: .denied, placeResult: .success(Self.detected))
        let viewModel = Self.makeViewModel(
            location: location,
            lastViewed: Self.saved,
            fetchTimeoutSleep: { duration in try await timeout.sleep(duration) }
        )
        await viewModel.start()
        location.authorizationState = .authorized
        location.fixDelay = Self.hangingFixDelay

        let locate = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { timeout.pendingCount > 0 }
        #expect(timeout.durations.last == .seconds(10))
        #expect(viewModel.isLocating)
        #expect(viewModel.locationFailure == nil)

        timeout.fire()
        await locate.value

        #expect(viewModel.locationFailure == .noFix)
        #expect(location.cancelledFixCount == 1)
        #expect(!viewModel.isLocating)
        #expect(viewModel.place == nil)
    }

    // MARK: - Launch

    @Test(
        "Launch with no saved place: the failure for the state; not asked yet is no failure",
        arguments: [
            (LocationAuthState.denied, LocationFailure?.some(.permissionDenied)),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
            (.notDetermined, nil),
        ]
    )
    func launchNoSavedPlace(state: LocationAuthState, failure: LocationFailure?) async {
        let viewModel = Self.makeViewModel(location: FakeLocationService(authorizationState: state))
        await viewModel.start()
        #expect(viewModel.locationFailure == failure)
    }

    @Test(
        "Launch with no saved place, the fix fails: No fix",
        arguments: [LocationError.locationUnavailable, .couldNotIdentifyPlace]
    )
    func launchNoSavedPlaceFixFails(error: LocationError) async {
        let viewModel = Self.makeViewModel(
            location: FakeLocationService(authorizationState: .authorized, placeResult: .failure(error))
        )
        await viewModel.start()
        #expect(viewModel.locationFailure == .noFix)
        #expect(viewModel.loaderIssue == .noFix)
    }

    @Test(
        "Launch with a saved place: opens it, no failure",
        arguments: [LocationAuthState.authorized, .denied, .servicesOff, .restricted, .notDetermined]
    )
    func launchWithSavedPlace(state: LocationAuthState) async {
        let location = FakeLocationService(
            authorizationState: state,
            placeResult: .failure(LocationError.locationUnavailable)
        )
        let viewModel = Self.makeViewModel(location: location, lastViewed: Self.saved)
        await viewModel.start()

        #expect(viewModel.locationFailure == nil)
        #expect(viewModel.place == Self.saved)
        #expect(viewModel.launchStage == .ready)
    }

    @Test("The compass's detection-only fix failing sets no failure")
    func compassDetectionSetsNone() async {
        let location = FakeLocationService(authorizationState: .authorized)
        let viewModel = Self.makeViewModel(location: location, lastViewed: Self.saved)
        await viewModel.start()

        await viewModel.turnOnLocationForCompass()

        #expect(viewModel.locationFailure == nil)
        #expect(viewModel.place == Self.saved)
    }

    // MARK: - Try again

    @Test("Try again: the failure clears as the fresh search starts, and a double tap doesn't stack fixes")
    func tryAgainDoesNotStack() async {
        let location = FakeLocationService(authorizationState: .authorized)
        let viewModel = Self.makeViewModel(location: location)
        await viewModel.start()
        #expect(viewModel.locationFailure == .noFix)
        let launchFixes = location.currentPlaceCount

        location.placeResult = .success(Self.detected)
        location.holdsFixes = true
        let first = Task { await viewModel.performLoaderAction() }
        let second = Task { await viewModel.performLoaderAction() }
        await Self.waitUntil { location.heldFixCount > 0 }
        for _ in 0..<100 { await Task.yield() }

        #expect(location.heldFixCount == 1)
        #expect(location.currentPlaceCount == launchFixes + 1)
        #expect(viewModel.locationFailure == nil)

        location.releaseFixes()
        await first.value
        await second.value
        #expect(viewModel.place == Self.detected)
        #expect(viewModel.locationFailure == nil)
    }

    @Test("Use my location twice: the first fix is cancelled, one search stands")
    func useMyLocationTwiceCancelsFirst() async {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detected))
        let viewModel = await Self.makeReadyViewModel(location: location)
        location.fixDelay = Self.hangingFixDelay
        let fixesBefore = location.currentPlaceCount

        let first = Task { await viewModel.useMyLocation() }
        await Self.waitUntil { location.currentPlaceCount > fixesBefore }
        location.fixDelay = .zero
        await viewModel.useMyLocation()
        await first.value

        #expect(location.cancelledFixCount == 1)
        #expect(viewModel.place == Self.detected)
        #expect(viewModel.locationFailure == nil)
    }

    @Test("A place landing clears the failure")
    func pickClearsFailure() async {
        let location = FakeLocationService(authorizationState: .denied)
        let viewModel = await Self.makeReadyViewModel(location: location)
        await viewModel.useMyLocation()
        #expect(viewModel.locationFailure == .permissionDenied)

        viewModel.select(Self.saved)

        #expect(viewModel.locationFailure == nil)
        #expect(viewModel.place == Self.saved)
    }
}
