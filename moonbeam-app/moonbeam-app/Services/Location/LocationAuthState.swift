//
//  LocationAuthState.swift
//  moonbeam-app
//

import CoreLocation

/// The five permission states LOCATION.md §4 branches on.
///
/// Deliberately smaller than `CLAuthorizationStatus`: the app only ever needs
/// When In Use, and the three "can't use location" cases each get different
/// copy in the custom Location Off dialog.
///
/// `nonisolated` so the mapping can be reasoned about (and tested) without
/// hopping to the main actor.
nonisolated enum LocationAuthState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case servicesOff

    /// Maps CoreLocation's status plus the system-wide switch onto one state.
    ///
    /// Approximate location is *not* a state of its own: §4 treats reduced
    /// accuracy as authorized, because city-level precision is all the moon
    /// maths needs (and `NSLocationDefaultAccuracyReduced` asks for it).
    ///
    /// With Location Services off device-wide iOS reports the app's status as
    /// `denied`, so both `denied` and `notDetermined` have to be re-read
    /// against `servicesEnabled` — otherwise a user who never refused
    /// Moonbeam would get the dialog that blames Moonbeam's own setting.
    init(status: CLAuthorizationStatus, servicesEnabled: Bool) {
        switch status {
        case .notDetermined:
            self = servicesEnabled ? .notDetermined : .servicesOff
        case .restricted:
            self = .restricted
        case .denied:
            self = servicesEnabled ? .denied : .servicesOff
        case .authorizedAlways, .authorizedWhenInUse:
            self = .authorized
        @unknown default:
            // A status we don't know about is treated as "not asked yet", the
            // only state that leads to a system prompt rather than a dialog.
            self = .notDetermined
        }
    }

    /// Whether `currentPlace()` can be expected to return a fix.
    var isAuthorized: Bool { self == .authorized }
}
