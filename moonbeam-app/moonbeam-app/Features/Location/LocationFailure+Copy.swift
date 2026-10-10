//
//  LocationFailure+Copy.swift
//  moonbeam-app
//

import Foundation

/// Each failure screen's art, words and actions, all in one place
/// (STEP-5.10a-LOCATION-FAILURE.md, "Causes, copy, art and actions"). Line
/// breaks are the doc's, at the default size; the app name is
/// `AppInfo.name`.
nonisolated extension LocationFailure {

    // MARK: - Art

    /// The calico still for the cause: no fix is "Huh?", permission off the
    /// telescope, services off the map, restricted the map with a lock.
    var illustration: LocationIllustration.Kind {
        switch self {
        case .noFix: .locationNotFound
        case .permissionDenied: .permissionOff
        case .servicesOff: .servicesOff
        case .restricted: .restricted
        }
    }

    // MARK: - Copy

    var headlineLines: [String] {
        switch self {
        case .permissionDenied, .restricted: ["\(AppInfo.name) can’t", "see your location"]
        case .servicesOff: ["Location", "Services are off"]
        case .noFix: ["Couldn’t find", "your location"]
        }
    }

    var bodyLines: [String] {
        switch self {
        case .permissionDenied: ["Allow location access to see", "where the moon is from here."]
        case .servicesOff: ["Turn them on to see where", "the moon is from here."]
        case .noFix: ["Check your signal and try", "again, or search for a city."]
        case .restricted: ["Location access is limited on", "this iPhone. You can still", "search for a city."]
        }
    }

    /// Where the switch is, for the causes Settings can fix.
    var pathChipLines: [String]? {
        switch self {
        case .permissionDenied: ["Settings › \(AppInfo.name) ›", "Location › While Using the App"]
        case .servicesOff: ["Settings › Privacy & Security ›", "Location Services"]
        case .noFix, .restricted: nil
        }
    }

    // MARK: - Actions

    /// Open Settings only where the user can change it there; restricted
    /// can't, so its button is the search.
    var primaryAction: LocationIssue.Action {
        switch self {
        case .permissionDenied, .servicesOff: .openSettings
        case .noFix: .tryAgain
        case .restricted: .search
        }
    }

    var primaryTitle: String {
        switch primaryAction {
        case .openSettings: "Open Settings"
        case .tryAgain: "Try again"
        case .search, .requestPermission: LocationIssue.searchTitle
        }
    }

    /// "Enter a city instead", the secondary on every cause but restricted,
    /// whose button already searches.
    var showsEnterCityLink: Bool {
        primaryAction != .search
    }

    static let enterCityTitle = "Enter a city instead"

    /// Everything above, for the shared message block. VoiceOver reads the
    /// headline and body as one sentence each.
    var copy: MessageCopy {
        MessageCopy(
            headline: headlineLines.joined(separator: " "),
            headlineLines: headlineLines,
            body: bodyLines.joined(separator: " "),
            bodyLines: bodyLines,
            pathChipLines: pathChipLines,
            primaryTitle: primaryTitle,
            linkTitle: Self.enterCityTitle,
            showsLink: showsEnterCityLink
        )
    }
}
