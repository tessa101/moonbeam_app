//
//  LocationServiceTests.swift
//  moonbeam-appTests
//

import CoreLocation
import Foundation
import Testing
@testable import moonbeam_app

/// The permission-state mapping in LOCATION.md §4, and the `LocationService`
/// contract the view-model tests will lean on.
///
/// `CoreLocationService` itself isn't exercised here: it can't be, without a
/// device fix and a live geocoder. What *is* testable is the decision it
/// makes — `LocationAuthState(status:servicesEnabled:)` — which is where the
/// §4 table actually lives.
@Suite("Location permission")
@MainActor
struct LocationServiceTests {

    // MARK: - Fixtures

    private static let marVista = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
        isCurrentLocation: true
    )

    // MARK: - The §4 table

    @Test(
        "CoreLocation status maps onto the five states",
        arguments: [
            (CLAuthorizationStatus.notDetermined, true, LocationAuthState.notDetermined),
            (.authorizedWhenInUse, true, .authorized),
            (.denied, true, .denied),
            (.restricted, true, .restricted),
        ]
    )
    func statusMapping(
        status: CLAuthorizationStatus,
        servicesEnabled: Bool,
        expected: LocationAuthState
    ) {
        #expect(LocationAuthState(status: status, servicesEnabled: servicesEnabled) == expected)
    }

    /// Always authorization is not something the app asks for, but honouring
    /// it costs nothing and refusing it would be a bug.
    @Test("Always authorization counts as authorized")
    func alwaysAuthorizationIsAuthorized() {
        #expect(LocationAuthState(status: .authorizedAlways, servicesEnabled: true) == .authorized)
    }

    /// §4: Location Services off device-wide gets its own dialog variant, and
    /// iOS reports that as `denied` — so the app's status alone isn't enough
    /// to tell "you refused us" from "the whole device is off".
    @Test(
        "Location Services off device-wide outranks the app's own status",
        arguments: [CLAuthorizationStatus.notDetermined, .denied]
    )
    func servicesOffOutranksTheAppStatus(status: CLAuthorizationStatus) {
        #expect(LocationAuthState(status: status, servicesEnabled: false) == .servicesOff)
    }

    /// Restricted is a device policy, so it stands whether or not Location
    /// Services are on: its dialog has no Settings button either way.
    @Test("Restricted survives Location Services being off")
    func restrictedSurvivesServicesOff() {
        #expect(LocationAuthState(status: .restricted, servicesEnabled: false) == .restricted)
    }

    @Test("Only authorized reports as authorized")
    func isAuthorized() {
        #expect(LocationAuthState.authorized.isAuthorized)
        #expect(!LocationAuthState.notDetermined.isAuthorized)
        #expect(!LocationAuthState.denied.isAuthorized)
        #expect(!LocationAuthState.restricted.isAuthorized)
        #expect(!LocationAuthState.servicesOff.isAuthorized)
    }

    // MARK: - The fake's contract

    /// §7 asserts that first launch makes no permission request. That test
    /// belongs to the view model, but it can only be written if the fake
    /// records the call — so the recording is pinned here.
    @Test("The fake starts undetermined and unasked")
    func fakeStartsUnasked() {
        let service = FakeLocationService()

        #expect(service.authorizationState == .notDetermined)
        #expect(!service.didRequestAuthorization)
    }

    @Test("Requesting authorization records the call and applies the outcome")
    func requestingAuthorizationAppliesTheOutcome() async {
        let service = FakeLocationService()
        service.stateAfterRequest = .authorized

        let state = await service.requestAuthorization()

        #expect(state == .authorized)
        #expect(service.authorizationState == .authorized)
        #expect(service.requestAuthorizationCount == 1)
    }

    /// A dismissed prompt leaves the state alone, which is how the view model
    /// will end up showing "Use my location" again rather than a dialog.
    @Test("A prompt with no outcome leaves the state undetermined")
    func promptWithNoOutcomeChangesNothing() async {
        let service = FakeLocationService()

        let state = await service.requestAuthorization()

        #expect(state == .notDetermined)
        #expect(service.requestAuthorizationCount == 1)
    }

    @Test("A successful fix returns the scripted place")
    func successfulFixReturnsThePlace() async throws {
        let service = FakeLocationService(
            authorizationState: .authorized,
            placeResult: .success(Self.marVista)
        )

        let place = try await service.currentPlace()

        #expect(place == Self.marVista)
        #expect(place.isCurrentLocation)
        #expect(service.currentPlaceCount == 1)
    }

    /// The fallback branch in §3 — the view model's cue to use the last-viewed
    /// place instead.
    @Test("A failed fix throws")
    func failedFixThrows() async {
        let service = FakeLocationService(authorizationState: .authorized)

        await #expect(throws: LocationError.locationUnavailable) {
            try await service.currentPlace()
        }
    }
}
