//
//  MoonTableViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation

/// Presents one place's `MoonDay` for the moon card (DESIGN-1.1.md §3.2):
/// the phase row and the two rise/set columns, as display strings.
///
/// Built by `LocationViewModel` for the selected day and rebuilt when the
/// place or day changes, so it holds no state of its own beyond the day it
/// was built for. Replaces Step 2's spike table model.
@Observable
final class MoonTableViewModel {

    // MARK: - Types

    /// One rise/set column.
    struct Column: Equatable {

        /// What sits under the column label.
        enum Detail: Equatable {
            /// "9:10 PM" (its day period marked, to be set smaller), the
            /// place's zone abbreviation when it differs from the phone's
            /// ("AEST"), and "58° ENE".
            case time(TimeText, timeZone: String?, direction: String)
            /// "No moonrise today".
            case missing(String)
        }

        /// "↑ Moonrise".
        let title: String
        let detail: Detail
        let accessibilityLabel: String
    }

    // MARK: - State

    let place: Place

    /// The day this table is for, which is the selected day, not necessarily
    /// today. `LocationViewModel` compares against it to tell whether the day
    /// has rolled over.
    let day: Date

    let moonDay: MoonDay

    let rise: Column
    let set: Column

    /// "Waning Gibbous".
    let phaseName: String
    /// "75% lit at midnight".
    let illuminationText: String
    let phaseAccessibilityLabel: String
    let glyph: PhaseGlyphGeometry

    // MARK: - Init

    /// Computed once on construction. Safe because `moonDay(for:on:)` is
    /// synchronous, pure and well under the 50 ms budget in PRODUCT NFR2.
    ///
    /// - Parameters:
    ///   - deviceTimeZone: the phone's zone, which decides whether times
    ///     carry the place's zone abbreviation (§11 Q3).
    init(
        moonService: any MoonService,
        place: Place,
        day: Date,
        deviceTimeZone: TimeZone,
        formatter: MoonTableFormatter = MoonTableFormatter()
    ) {
        let moonDay = moonService.moonDay(for: place, on: day)
        self.place = place
        self.day = day
        self.moonDay = moonDay

        rise = Self.column(.rise, moonDay.rise, place: place, deviceTimeZone: deviceTimeZone, formatter: formatter)
        set = Self.column(.set, moonDay.set, place: place, deviceTimeZone: deviceTimeZone, formatter: formatter)

        phaseName = formatter.phaseName(for: moonDay.phase)
        illuminationText = formatter.illumination(moonDay.illumination)
        phaseAccessibilityLabel = formatter.phaseAccessibilityLabel(
            phase: moonDay.phase,
            illumination: moonDay.illumination
        )
        glyph = PhaseGlyphGeometry(illumination: moonDay.illumination, phaseAngle: moonDay.phaseAngle)
    }

    // MARK: - Helpers

    private static func column(
        _ event: MoonTableFormatter.Event,
        _ moonEvent: MoonEvent?,
        place: Place,
        deviceTimeZone: TimeZone,
        formatter: MoonTableFormatter
    ) -> Column {
        let abbreviation = moonEvent.flatMap {
            formatter.timeZoneAbbreviation(for: place, at: $0.date, deviceTimeZone: deviceTimeZone)
        }
        let detail: Column.Detail = if let moonEvent {
            .time(
                formatter.timeText(moonEvent.date, in: place.timeZone),
                timeZone: abbreviation,
                direction: formatter.direction(for: moonEvent.azimuth)
            )
        } else {
            .missing(formatter.missingText(event))
        }
        return Column(
            title: formatter.eventTitle(event),
            detail: detail,
            accessibilityLabel: formatter.accessibilityLabel(
                for: event,
                moonEvent,
                place: place,
                timeZoneAbbreviation: abbreviation
            )
        )
    }
}
