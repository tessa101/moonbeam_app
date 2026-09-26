//
//  LocationService.swift
//  moonbeam-app
//

import Foundation

/// Reads the device's permission state and, when allowed, turns a one-shot
/// location fix into a `Place` (LOCATION.md §6).
///
/// Main-actor isolated, unlike `MoonService`: the implementation drives
/// `CLLocationManager` and MapKit, both of which expect a single, UI-bound
/// home. `Place` itself stays `nonisolated`, so results cross back out to the
/// domain layer freely.
///
/// Nothing here requests permission implicitly. `requestAuthorization()` is
/// the only call that can show the system prompt, so the "no prompt at launch"
/// rule in §3 is enforced by the call site, not by luck.
protocol LocationService {

    /// The current permission state, read fresh each time. Cheap.
    var authorizationState: LocationAuthState { get }

    /// Shows the system prompt when the state is `notDetermined`, and returns
    /// the state the user settled on. A no-op returning the current state
    /// otherwise — iOS only ever prompts once.
    func requestAuthorization() async -> LocationAuthState

    /// One-shot fix, reverse geocoded into a `Place` whose
    /// `isCurrentLocation` is `true`.
    ///
    /// Has no timeout of its own: the 10-second fallback in §3 is a launch
    /// policy, so it belongs to the view model that owns the launch sequence.
    func currentPlace() async throws -> Place
}

/// Why a location fix or reverse geocode couldn't produce a `Place`.
nonisolated enum LocationError: Error, Equatable {

    /// Permission was refused or withdrawn while the fix was in flight.
    case notAuthorized

    /// The device couldn't determine where it is.
    case locationUnavailable

    /// There was a fix, but no map item with enough detail to name it
    /// (see `Place.init?(mapItem:isCurrentLocation:)`).
    case couldNotIdentifyPlace
}
