//
//  LocationIssue.swift
//  moonbeam-app
//

import Foundation

/// Why the loader stopped and shows a message (LOADER.md §10.3): only with
/// no saved place (§10.1); with one, the app just opens it.
///
/// First ask's copy is the handoff's (`design/1.4-location-flow/README.md`,
/// "Message"). The other four are causes, so their words and actions are
/// `LocationFailure`'s (STEP-5.10a-LOCATION-CONSOLIDATION.md, Chunk 1).
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

    /// The shared cause behind the four messages that are also failure
    /// screens; `nil` for first ask, an invitation with its own copy
    /// (STEP-5.10a-LOCATION-CONSOLIDATION.md §1). The cause's words and
    /// actions come only from `LocationFailure`, so the two can't drift.
    var failure: LocationFailure? {
        switch self {
        case .firstAsk: nil
        case .appDenied: .permissionDenied
        case .servicesOff: .servicesOff
        case .restricted: .restricted
        case .noFix: .noFix
        }
    }

    // MARK: - Copy

    var headline: String {
        failure?.copy.headline ?? "Find the moon from where you are"
    }

    var body: String {
        failure?.copy.body ?? "\(AppInfo.name) uses your location to show when and where the moon rises and sets."
    }

    /// The headline's lines at the default size (LOADER.md §11.1.3, from
    /// the prototype's balanced wrapping). Joined, they're `headline`.
    var headlineLines: [String] {
        failure?.headlineLines ?? ["Find the moon", "from where you are"]
    }

    /// The body's lines at the default size (§11.1.3). Restricted keeps
    /// wrapping naturally under the moon until Consolidation Chunk 2 moves
    /// it to the failure screen, which sets its lines; the words are the
    /// same either way.
    var bodyLines: [String]? {
        switch failure {
        case nil: ["\(AppInfo.name) uses your location to show", "when and where the moon rises and sets."]
        case .restricted: nil
        case let failure?: failure.bodyLines
        }
    }

    var primaryAction: Action {
        failure?.primaryAction ?? .requestPermission
    }

    var primaryTitle: String {
        failure?.primaryTitle ?? "Use my location"
    }

    /// "Enter a city instead", under the button; restricted already has
    /// search as its button, so it has none.
    var showsSearchLink: Bool {
        failure?.showsEnterCityLink ?? true
    }

    /// The failure screens' words, so the two read the same (Tessa,
    /// 2026-10-10, from the Chunk 3 recordings; was "Search for a city
    /// instead").
    static let searchLinkTitle = LocationFailure.enterCityTitle
    /// Restricted's button, here, on its failure screen and in the
    /// Location Off dialog.
    static let searchTitle = "Search for a city"

    /// All of the above, for the shared message block. The Settings path
    /// chip is left off under the moon until Consolidation Chunk 2 moves
    /// these causes to the failure screen, which shows it.
    var copy: MessageCopy {
        MessageCopy(
            headline: headline,
            headlineLines: headlineLines,
            body: body,
            bodyLines: bodyLines,
            primaryTitle: primaryTitle,
            linkTitle: Self.searchLinkTitle,
            showsLink: showsSearchLink
        )
    }
}
