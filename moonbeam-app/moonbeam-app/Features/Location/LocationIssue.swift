//
//  LocationIssue.swift
//  moonbeam-app
//

import Foundation

/// Why a launch with no saved place found nothing (LOADER.md §10.1); with
/// one, the app just opens it. Only First ask stops the loader on a
/// message; the four causes open their failure screen
/// (STEP-5.10a-LOCATION-CONSOLIDATION.md §2).
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

    /// The body's lines at the default size (§11.1.3).
    var bodyLines: [String]? {
        failure?.bodyLines ?? ["\(AppInfo.name) uses your location to show", "when and where the moon rises and sets."]
    }

    /// `nil` for No fix, which has no button (Chunk 2b).
    var primaryAction: Action? {
        guard let failure else { return .requestPermission }
        return failure.primaryAction
    }

    var primaryTitle: String? {
        guard let failure else { return "Use my location" }
        return failure.primaryTitle
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

    /// All of the above, for the shared message block: a cause's is its
    /// failure screen's exactly, Settings path chip included
    /// (STEP-5.10a-LOCATION-CONSOLIDATION.md, Chunk 2).
    var copy: MessageCopy {
        if let failure { return failure.copy }
        return MessageCopy(
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
