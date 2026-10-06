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

    var isPreciseLocationOff = false

    /// What the temporary Precise Location alert "decides": `false` grants
    /// it. Left `nil`, nothing changes, which models declining.
    var preciseOffAfterTemporaryRequest: Bool?

    /// What the system prompt "decides". Left `nil`, the state doesn't change,
    /// which models a user dismissing the prompt.
    var stateAfterRequest: LocationAuthState?

    /// What `currentPlace()` returns or throws.
    var placeResult: Result<Place, any Error>

    /// How long `currentPlace()` takes, so a caller's timeout can be tested.
    var fixDelay: Duration = .zero

    /// Holds every fix until `releaseFixes()`, so a test decides when it
    /// lands relative to the launch loader's waits (LOADER.md §7).
    var holdsFixes = false

    private var heldFixes: [CheckedContinuation<Void, Never>] = []

    /// Fixes waiting on `releaseFixes()`.
    var heldFixCount: Int { heldFixes.count }

    /// Lets every held fix finish with `placeResult`.
    func releaseFixes() {
        let held = heldFixes
        heldFixes = []
        held.forEach { $0.resume() }
    }

    /// Holds every `refreshAuthorizationState()` until
    /// `releaseAuthorizationRefreshes()`: a Location Services read that
    /// blocks, as it can on a device (LOADER.md §9).
    var holdsAuthorizationRefresh = false

    private var heldRefreshes: [CheckedContinuation<Void, Never>] = []

    /// Refreshes waiting on `releaseAuthorizationRefreshes()`.
    var heldRefreshCount: Int { heldRefreshes.count }

    func releaseAuthorizationRefreshes() {
        let held = heldRefreshes
        heldRefreshes = []
        held.forEach { $0.resume() }
    }

    // MARK: - Record

    private(set) var refreshCount = 0
    private(set) var requestAuthorizationCount = 0
    private(set) var currentPlaceCount = 0

    /// The purpose key of each temporary Precise Location request.
    private(set) var temporaryPrecisePurposeKeys: [String] = []

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

    func refreshAuthorizationState() async -> LocationAuthState {
        refreshCount += 1
        if holdsAuthorizationRefresh {
            await withCheckedContinuation { heldRefreshes.append($0) }
        }
        return authorizationState
    }

    func requestAuthorization() async -> LocationAuthState {
        requestAuthorizationCount += 1
        if let stateAfterRequest {
            authorizationState = stateAfterRequest
        }
        return authorizationState
    }

    func requestTemporaryPreciseLocation(purposeKey: String) async {
        temporaryPrecisePurposeKeys.append(purposeKey)
        if let preciseOffAfterTemporaryRequest {
            isPreciseLocationOff = preciseOffAfterTemporaryRequest
        }
    }

    func currentPlace() async throws -> Place {
        currentPlaceCount += 1

        if holdsFixes {
            await withCheckedContinuation { heldFixes.append($0) }
        }

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
