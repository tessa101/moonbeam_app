//
//  LocationOffGuideFormatter.swift
//  moonbeam-app
//

import Foundation

/// The location-off guide row's words (LOCATION-OFF-FLOW.md §3.1, design 1.9
/// S2 to S6): its title and subtitle for each `LocationOffGuide`, and what
/// VoiceOver reads.
///
/// The countdown's wording lives only in `countdown(minutes:)`, so switching
/// to the card's "2h 15m" form (§7, open) is one function.
///
/// `nonisolated` because it's a pure mapping over its input.
nonisolated struct LocationOffGuideFormatter {

    /// What the row shows.
    struct Row: Equatable, Sendable {
        let title: String
        let subtitle: String

        /// The row is one button: its title, then its subtitle.
        var accessibilityLabel: String { "\(title), \(subtitle)" }
    }

    // MARK: - Copy (design 1.9)

    static let waitingTitle = "Compass guide is waiting"
    static let waitingSubtitle = "Tap whenever you want directions"
    static let risingTitle = "The moon is rising now"
    static let upTitle = "The moon is up now"
    static let activeSubtitle = "Want her to show you where?"
    static let rowHint = "Shows the moon compass preview."

    private static let minutesPerHour = 60

    // MARK: - Formatting

    func row(for guide: LocationOffGuide) -> Row {
        switch guide {
        case .waiting:
            Row(title: Self.waitingTitle, subtitle: Self.waitingSubtitle)
        case let .moonriseIn(minutes):
            Row(title: "Moonrise in \(Self.countdown(minutes: minutes))", subtitle: Self.activeSubtitle)
        case .rising:
            Row(title: Self.risingTitle, subtitle: Self.activeSubtitle)
        case .up:
            Row(title: Self.upTitle, subtitle: Self.activeSubtitle)
        }
    }

    /// "2 hr 15 min" from an hour; "2 hr" with no minutes left over; "40 min"
    /// under an hour (the handoff's form).
    static func countdown(minutes: Int) -> String {
        guard minutes >= minutesPerHour else { return "\(minutes) min" }
        let hours = minutes / minutesPerHour
        let remainder = minutes % minutesPerHour
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }
}
