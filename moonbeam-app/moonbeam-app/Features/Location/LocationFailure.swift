//
//  LocationFailure.swift
//  moonbeam-app
//

import Foundation

/// Why a location search the user is waiting on ended without a place
/// (STEP-5.10a-LOCATION-FAILURE.md, Chunk 1). Each case gets its own
/// failure screen: art, copy and actions.
///
/// Narrower than `LocationIssue`: "not asked yet" isn't a failure, it's the
/// first-ask message, so it has no case here.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated enum LocationFailure: Equatable, Sendable, CaseIterable {
    /// The app's permission is off (`denied`).
    case permissionDenied
    /// The device-wide Location Services switch is off.
    case servicesOff
    /// Parental controls or a profile: the user can't change it.
    case restricted
    /// Allowed, but no place: no fix within the 10 s timeout, a CoreLocation
    /// error, or the city couldn't be named (offline reverse geocoding fails
    /// at once, with no 10 s wait).
    case noFix

    /// The failure a permission state stands for; `nil` when it isn't one.
    /// Authorized can still fail, but only as `noFix`, which comes from the
    /// fetch; not determined leads to the system prompt instead.
    init?(_ state: LocationAuthState) {
        switch state {
        case .denied: self = .permissionDenied
        case .servicesOff: self = .servicesOff
        case .restricted: self = .restricted
        case .authorized, .notDetermined: return nil
        }
    }

    /// The failure for a fetch that threw. Every error is `noFix`, the
    /// timeout's cancellation included, except a permission withdrawn while
    /// the fix was in flight: that's the permission's own failure, read from
    /// `state` (fresh, so services off isn't mistaken for denied).
    init(fixError: any Error, state: LocationAuthState) {
        if case LocationError.notAuthorized = fixError, let failure = LocationFailure(state) {
            self = failure
        } else {
            self = .noFix
        }
    }
}
