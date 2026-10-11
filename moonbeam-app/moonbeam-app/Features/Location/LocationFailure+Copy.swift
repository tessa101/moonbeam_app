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
        // Chunk 2c (Tessa, 2026-10-11): no app name in the headline; the
        // chip and First ask keep `AppInfo.name`.
        case .permissionDenied, .restricted: ["Can’t see", "your location"]
        case .servicesOff: ["Location", "Services are off"]
        case .noFix: ["Couldn’t find", "your location"]
        }
    }

    var bodyLines: [String] {
        switch self {
        case .permissionDenied: ["Allow location access to see", "where the moon is from here."]
        case .servicesOff: ["Turn them on to see where", "the moon is from here."]
        // Chunk 2b (Tessa, 2026-10-10): offline, the fix needs a connection,
        // and the app looks again when the user comes back.
        case .noFix: ["Check your cellular or Wi-Fi", "connection. We’ll look again", "when you come back."]
        case .restricted: ["Location access is limited on", "this iPhone. You can still", "search for a city."]
        }
    }

    /// Where the switch is, for the causes Settings can fix.
    var pathChipLines: [String]? {
        switch self {
        // Chunk 2b (Tessa, 2026-10-10): any choice but Never works, so the
        // chip stops at the app's Location page.
        case .permissionDenied: ["Settings › \(AppInfo.name) ›", "Location"]
        // Chunk 2c (Tessa, 2026-10-11): Open Settings can only reach the
        // app's own page, and iOS has no public link to the device-wide
        // switch, so the chip starts with the way back from there.
        case .servicesOff: ["Back to Settings › Privacy & Security ›", "Location Services"]
        case .noFix, .restricted: nil
        }
    }

    // MARK: - Actions

    /// Open Settings only where the user can change it there; restricted
    /// can't, so its button is the search. No fix has none (Chunk 2b): the
    /// fix is a connection iOS can't open, and a foreground looks again.
    var primaryAction: LocationIssue.Action? {
        switch self {
        case .permissionDenied, .servicesOff: .openSettings
        case .noFix: nil
        case .restricted: .search
        }
    }

    var primaryTitle: String? {
        switch primaryAction {
        case .openSettings: "Open Settings"
        case .search, .requestPermission: LocationIssue.searchTitle
        case nil: nil
        }
    }

    /// "Search for a city instead" (Chunk 2c; was "Enter a city instead"),
    /// the secondary on every cause but restricted,
    /// whose button already searches.
    var showsSearchLink: Bool {
        primaryAction != .search
    }

    static let searchInsteadTitle = "Search for a city instead"

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
            linkTitle: Self.searchInsteadTitle,
            showsLink: showsSearchLink
        )
    }
}
