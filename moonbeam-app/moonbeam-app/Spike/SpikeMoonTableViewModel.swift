//
//  SpikeMoonTableViewModel.swift
//  moonbeam-app
//
//  ⚠️ SPIKE UI — replace in task #4 ("Build the SwiftUI table").
//
//  This exists only to get real moon data on screen while the table is being
//  designed. It hardcodes one city, has no loading or error states, and does
//  its own string formatting. The real MoonTableViewModel belongs in
//  Features/MoonTable/ with the State enum from ARCHITECTURE.md §5, and the
//  formatting belongs in Formatting/ where it can be localized and tested.
//

import Foundation
import Observation

/// Presents one `MoonDay` as display strings for the spike UI.
///
/// Takes its `MoonService` through the initializer, like the real view model
/// will, so the dependency seam is right even though the rest is throwaway.
@Observable
final class SpikeMoonTableViewModel {

    // MARK: - Fixture

    /// The reference location from ASTRONOMY.md §5. Hardcoded until geocoding
    /// arrives; the real view model will take the place from a search.
    static let marVista = Place(
        name: "Los Angeles (Mar Vista), CA",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    private static let percentMultiplier = 100.0

    // MARK: - State

    let place: Place
    let moonDay: MoonDay

    private let compass = CompassFormatter()

    /// Computed once on construction. Safe here because `moonDay(for:on:)` is
    /// synchronous, pure and well under the 50 ms budget in PRODUCT NFR2. The
    /// real view model will load on demand so the date can change.
    init(moonService: MoonService, place: Place = SpikeMoonTableViewModel.marVista, today: Date = Date()) {
        self.place = place
        self.moonDay = moonService.moonDay(for: place, on: today)
    }

    // MARK: - Display strings

    var dayText: String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).month().day()
        style.timeZone = place.timeZone
        return Date().formatted(style)
    }

    var riseText: String { text(for: moonDay.rise, missing: "No moonrise today") }

    var setText: String { text(for: moonDay.set, missing: "No moonset today") }

    /// `MoonPhase.rawValue` is camelCase, so it needs splitting for display.
    /// A stopgap: the real version goes in `Formatting/` as a localized table.
    var phaseText: String {
        moonDay.phase.rawValue
            .replacing(#/([a-z])([A-Z])/#) { match in
                "\(match.output.1) \(match.output.2.lowercased())"
            }
            .capitalized
    }

    var illuminationText: String {
        let percent = moonDay.illumination * Self.percentMultiplier
        return "\(percent.formatted(.number.precision(.fractionLength(0))))%"
    }

    // MARK: - Accessibility (CLAUDE.md: not optional, even here)

    var riseAccessibilityLabel: String {
        accessibilityLabel(for: moonDay.rise, event: "Moonrise", missing: "No moonrise today")
    }

    var setAccessibilityLabel: String {
        accessibilityLabel(for: moonDay.set, event: "Moonset", missing: "No moonset today")
    }

    var illuminationAccessibilityLabel: String {
        "\(illuminationText) illuminated"
    }

    // MARK: - Helpers

    private func text(for event: MoonEvent?, missing: String) -> String {
        guard let event else { return missing }
        let degrees = event.azimuth.formatted(.number.precision(.fractionLength(0)))
        return "\(time(event.date)) · \(degrees)° \(compass.abbreviation(for: event.azimuth))"
    }

    private func accessibilityLabel(
        for event: MoonEvent?,
        event name: String,
        missing: String
    ) -> String {
        guard let event else { return missing }
        return "\(name) at \(time(event.date)), \(compass.spokenName(for: event.azimuth))"
    }

    /// Always the place's zone, never the device's (PRODUCT FR1).
    private func time(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = place.timeZone
        return date.formatted(style)
    }
}
