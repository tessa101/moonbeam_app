//
//  CoreLocationService.swift
//  moonbeam-app
//

import CoreLocation
import MapKit
import os

/// `LocationService` backed by CoreLocation and MapKit.
///
/// Main-actor isolated (the project default), which is also where
/// `CLLocationManager` wants to live: it delivers its delegate callbacks on
/// the thread that created it.
///
/// Two deliberate API choices, both from LOCATION.md §6:
/// - the fix comes from `CLLocationUpdate.liveUpdates()`, stopped after the
///   first location, rather than from `startUpdatingLocation` — it's the
///   async-native path, so there's no delegate bridging for the fix itself
/// - reverse geocoding uses `MKReverseGeocodingRequest`, not the
///   `CLGeocoder`/`MKPlacemark` pair that iOS 26 deprecates
final class CoreLocationService: LocationService {

    // MARK: - State

    private let manager = CLLocationManager()

    /// Retained because `CLLocationManager.delegate` is weak.
    private let observer: AuthorizationObserver

    /// Authorization-change notifications, one long-lived stream. Only
    /// `awaitDecision()` consumes it, and `pendingAuthorization` guarantees
    /// there's never more than one consumer at a time.
    private let authorizationChanges: AsyncStream<Void>

    /// The in-flight permission request, if any, so two callers share one
    /// prompt instead of both iterating `authorizationChanges`.
    private var pendingAuthorization: Task<LocationAuthState, Never>?

    /// The device-wide Location Services switch, as last read off the main
    /// actor by `refreshAuthorizationState()`. Assumed on until then: it's
    /// only consulted for `notDetermined` and `denied`, and every caller that
    /// branches on those refreshes first.
    private var servicesEnabled = true

    init() {
        let (changes, continuation) = AsyncStream<Void>.makeStream()
        authorizationChanges = changes
        observer = AuthorizationObserver(onChange: continuation)
        manager.delegate = observer
    }

    // MARK: - LocationService

    var authorizationState: LocationAuthState {
        let signposter = LaunchSignposts.signposter
        let read = signposter.beginInterval("authorizationState")
        defer { signposter.endInterval("authorizationState", read) }
        return LocationAuthState(status: manager.authorizationStatus, servicesEnabled: servicesEnabled)
    }

    func refreshAuthorizationState() async -> LocationAuthState {
        let status = manager.authorizationStatus
        // Only `notDetermined` and `denied` change with the switch, so an
        // authorized launch never reads it at all.
        if status == .notDetermined || status == .denied {
            let signposter = LaunchSignposts.signposter
            let read = signposter.beginInterval("locationServicesEnabled")
            servicesEnabled = await Self.readOffMainActor { CLLocationManager.locationServicesEnabled() }
            signposter.endInterval("locationServicesEnabled", read)
        }
        return authorizationState
    }

    /// Runs a read that may block on a detached task, so the main actor
    /// (and the launch loader's 400 ms clock) keeps running meanwhile.
    /// `CLLocationManager.locationServicesEnabled()` is a synchronous call
    /// into the location daemon; Xcode flags it as able to make the UI
    /// unresponsive on the main thread (LOADER.md §9, §10.7).
    nonisolated static func readOffMainActor<Value: Sendable>(
        _ read: @escaping @Sendable () -> Value
    ) async -> Value {
        await Task.detached(priority: .userInitiated, operation: read).value
    }

    var isPreciseLocationOff: Bool {
        manager.accuracyAuthorization == .reducedAccuracy
    }

    func requestAuthorization() async -> LocationAuthState {
        // With the switch off iOS shows no prompt, so know it first.
        let current = await refreshAuthorizationState()
        guard current == .notDetermined else { return current }

        if let pendingAuthorization {
            return await pendingAuthorization.value
        }

        let request = Task { await awaitDecision() }
        pendingAuthorization = request
        let state = await request.value
        pendingAuthorization = nil
        return state
    }

    /// The async form returns after the user answers. It throws when iOS
    /// doesn't show the alert (already precise, missing key, backgrounded),
    /// and in each case there's nothing to do but read the state again.
    func requestTemporaryPreciseLocation(purposeKey: String) async {
        try? await manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey)
    }

    func currentPlace() async throws -> Place {
        let location = try await currentLocation()
        return try await place(for: location)
    }

    // MARK: - Authorization

    /// Prompts, then waits for the first delegate callback that moves the
    /// state off `notDetermined`.
    private func awaitDecision() async -> LocationAuthState {
        manager.requestWhenInUseAuthorization()

        for await _ in authorizationChanges {
            let state = await refreshAuthorizationState()
            if state != .notDetermined { return state }
        }

        return await refreshAuthorizationState()
    }

    // MARK: - One-shot fix

    /// Takes the first location `liveUpdates()` produces and stops.
    ///
    /// The other `CLLocationUpdate` flags matter because the sequence doesn't
    /// end when a fix becomes impossible — it just stops yielding locations,
    /// which would hang the caller forever.
    private func currentLocation() async throws -> CLLocation {
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location { return location }

            if update.authorizationDenied
                || update.authorizationDeniedGlobally
                || update.authorizationRestricted {
                throw LocationError.notAuthorized
            }

            if update.locationUnavailable {
                throw LocationError.locationUnavailable
            }
        }

        throw LocationError.locationUnavailable
    }

    // MARK: - Reverse geocoding

    private func place(for location: CLLocation) async throws -> Place {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw LocationError.couldNotIdentifyPlace
        }

        let mapItems = try await request.mapItems

        // The first item is the closest match; anything further out would name
        // somewhere the user isn't.
        guard
            let mapItem = mapItems.first,
            let place = Place(mapItem: mapItem, isCurrentLocation: true)
        else {
            throw LocationError.couldNotIdentifyPlace
        }

        return place
    }
}

// MARK: - Delegate bridging

/// Forwards `CLLocationManagerDelegate`'s authorization callback into an
/// `AsyncStream`.
///
/// `nonisolated` because the imported protocol carries no actor annotation, so
/// its requirements can't be satisfied by main-actor methods. Yielding into a
/// continuation is safe from any isolation, which is why the stream carries
/// nothing: the service re-reads `authorizationState` on the main actor
/// instead of shipping CoreLocation types across the boundary.
private nonisolated final class AuthorizationObserver: NSObject, CLLocationManagerDelegate {

    private let onChange: AsyncStream<Void>.Continuation

    init(onChange: AsyncStream<Void>.Continuation) {
        self.onChange = onChange
        super.init()
    }

    deinit {
        onChange.finish()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onChange.yield()
    }
}
