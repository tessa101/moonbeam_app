//
//  FakeLocationService.swift
//  moonbeam-app
//

import Foundation

/// Scriptable `LocationService` for tests and SwiftUI previews.
///
/// Every permission state in LOCATION.md §4 is reachable by setting
/// `authorizationState`, and the launch-logic branches in §3 by setting
/// `placeResult` and `fixDelay`.
final class FakeLocationService: LocationService {

    // MARK: - Script

    var authorizationState: LocationAuthState

    /// What the system prompt "decides". Left `nil`, the state doesn't change,
    /// which models a user dismissing the prompt.
    var stateAfterRequest: LocationAuthState?

    /// What `currentPlace()` returns or throws.
    var placeResult: Result<Place, any Error>

    /// How long `currentPlace()` takes, so a caller's timeout can be tested.
    var fixDelay: Duration = .zero

    // MARK: - Record

    private(set) var requestAuthorizationCount = 0
    private(set) var currentPlaceCount = 0

    /// Fixes that were cancelled mid-flight. The view model's timeout has to
    /// *cancel* the fix — stopping location updates — not merely stop waiting
    /// for it, and this is how a test tells the two apart.
    private(set) var cancelledFixCount = 0

    /// True if the system prompt was never triggered — what the "no permission
    /// prompt at launch" test in §7 asserts.
    var didRequestAuthorization: Bool { requestAuthorizationCount > 0 }

    // MARK: - Init

    init(
        authorizationState: LocationAuthState = .notDetermined,
        placeResult: Result<Place, any Error> = .failure(LocationError.locationUnavailable)
    ) {
        self.authorizationState = authorizationState
        self.placeResult = placeResult
    }

    // MARK: - LocationService

    func requestAuthorization() async -> LocationAuthState {
        requestAuthorizationCount += 1
        if let stateAfterRequest {
            authorizationState = stateAfterRequest
        }
        return authorizationState
    }

    func currentPlace() async throws -> Place {
        currentPlaceCount += 1

        if fixDelay > .zero {
            do {
                try await Task.sleep(for: fixDelay)
            } catch {
                cancelledFixCount += 1
                throw error
            }
        }

        return try placeResult.get()
    }
}
