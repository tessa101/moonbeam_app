//
//  CoreLocationService.swift
//  moonbeam-app
//

import CoreLocation
import MapKit

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

    init() {
        let (changes, continuation) = AsyncStream<Void>.makeStream()
        authorizationChanges = changes
        observer = AuthorizationObserver(onChange: continuation)
        manager.delegate = observer
    }

    // MARK: - LocationService

    var authorizationState: LocationAuthState {
        LocationAuthState(
            status: manager.authorizationStatus,
            servicesEnabled: CLLocationManager.locationServicesEnabled()
        )
    }

    func requestAuthorization() async -> LocationAuthState {
        let current = authorizationState
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
            let state = authorizationState
            if state != .notDetermined { return state }
        }

        return authorizationState
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
