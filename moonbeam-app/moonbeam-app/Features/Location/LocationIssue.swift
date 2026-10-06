//
//  LocationIssue.swift
//  moonbeam-app
//

import Foundation

/// Why the loader stopped and shows a message (LOADER.md §10.3): only with
/// no saved place (§10.1); with one, the app just opens it.
///
/// Copy is the handoff's (`design/1.4-location-flow/README.md`, "Message"),
/// with §10.1's amendment for restricted.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated enum LocationIssue: Equatable, Sendable {
    /// Existing installs that report `notDetermined` (Ask Next Time, an
    /// expired Allow Once). New installs get onboarding instead.
    case firstAsk
    /// The app's permission is off.
    case appDenied
    /// The device-wide Location Services switch is off.
    case servicesOff
    /// Parental controls or a profile: the user can't change it.
    case restricted
    /// Authorized, but no fix within 10 s, or the city couldn't be named
    /// (offline: reverse geocoding fails at once).
    case noFix

    /// What the primary button does.
    enum Action: Equatable {
        /// iOS's permission prompt.
        case requestPermission
        /// The app's page in Settings (iOS can't open the system switch).
        case openSettings
        /// Search again, in place.
        case tryAgain
        /// The city search sheet.
        case search
    }

    /// The message for a permission state that isn't authorized; `nil` when
    /// it is (an authorized launch only fails as `noFix`).
    init?(_ state: LocationAuthState) {
        switch state {
        case .authorized: return nil
        case .notDetermined: self = .firstAsk
        case .denied: self = .appDenied
        case .servicesOff: self = .servicesOff
        case .restricted: self = .restricted
        }
    }

    // MARK: - Copy

    var headline: String {
        switch self {
        case .firstAsk: "Find the moon from where you are"
        case .appDenied, .restricted: "\(AppInfo.name) can’t see your location"
        case .servicesOff: "Location Services are off"
        case .noFix: "Couldn’t find your location"
        }
    }

    var body: String {
        switch self {
        case .firstAsk: "\(AppInfo.name) uses your location to show when and where the moon rises and sets."
        case .appDenied: "Allow location access to see where the moon is from here."
        // Tessa, 2026-10-06: a restricted user can't allow it.
        case .restricted: "Location access is limited on this iPhone. You can still search for a city."
        case .servicesOff: "Turn them on to see where the moon is from here."
        case .noFix: "Check your signal and try again, or search for a city."
        }
    }

    var primaryAction: Action {
        switch self {
        case .firstAsk: .requestPermission
        case .appDenied, .servicesOff: .openSettings
        // §10.1: no Open Settings, since the user can't change it there.
        case .restricted: .search
        case .noFix: .tryAgain
        }
    }

    var primaryTitle: String {
        switch primaryAction {
        case .requestPermission: "Use my location"
        case .openSettings: "Open Settings"
        case .tryAgain: "Try again"
        case .search: Self.searchTitle
        }
    }

    /// "Search for a city instead", under the button; restricted already has
    /// search as its button, so it has none.
    var showsSearchLink: Bool {
        primaryAction != .search
    }

    static let searchLinkTitle = "Search for a city instead"
    private static let searchTitle = "Search for a city"
}
