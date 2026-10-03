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
            /// No rise (or set) this day (COMPASS-1.1.md §9.10): "After
            /// midnight" and the next one, "Sun 12:20 AM"; or "Not today"
            /// and `nil` when the next is more than a day away.
            case missing(String, next: String?)
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
    /// "75% lit"; VoiceOver's label still says "at midnight".
    let illuminationText: String
    /// "75%", when even a shrunk header line has no room for " lit".
    let illuminationPercentText: String
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

        // Only a day missing a rise or set needs the next day's, for "After
        // midnight, Sun 12:20 AM" (COMPASS-1.1.md §9.10).
        let nextDay: MoonDay? = if moonDay.rise == nil || moonDay.set == nil {
            Self.dayAfter(day, in: place.timeZone).map { moonService.moonDay(for: place, on: $0) }
        } else {
            nil
        }
        rise = Self.column(
            .rise,
            moonDay.rise,
            next: nextDay?.rise,
            place: place,
            deviceTimeZone: deviceTimeZone,
            formatter: formatter
        )
        set = Self.column(
            .set,
            moonDay.set,
            next: nextDay?.set,
            place: place,
            deviceTimeZone: deviceTimeZone,
            formatter: formatter
        )

        phaseName = formatter.phaseName(for: moonDay.phase)
        illuminationText = formatter.lit(moonDay.illumination)
        illuminationPercentText = formatter.percentLit(moonDay.illumination)
        phaseAccessibilityLabel = formatter.phaseAccessibilityLabel(
            phase: moonDay.phase,
            illumination: moonDay.illumination
        )
        glyph = PhaseGlyphGeometry(illumination: moonDay.illumination, phaseAngle: moonDay.phaseAngle)
    }

    // MARK: - Helpers

    /// The start of the day after `day` in `timeZone`.
    private static func dayAfter(_ day: Date, in timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))
    }

    /// - Parameter next: the same event on the next day, for a day without
    ///   one; `nil` there means it's more than a day away.
    private static func column(
        _ event: MoonTableFormatter.Event,
        _ moonEvent: MoonEvent?,
        next: MoonEvent?,
        place: Place,
        deviceTimeZone: TimeZone,
        formatter: MoonTableFormatter
    ) -> Column {
        let abbreviation = moonEvent.flatMap {
            formatter.timeZoneAbbreviation(for: place, at: $0.date, deviceTimeZone: deviceTimeZone)
        }
        let title = formatter.eventTitle(event)
        guard let moonEvent else {
            let nextText = next.map { formatter.nextEventText($0.date, in: place.timeZone) }
            return Column(
                title: title,
                detail: .missing(
                    nextText == nil ? MoonTableFormatter.notTodayText : MoonTableFormatter.afterMidnightText,
                    next: nextText?.shown
                ),
                accessibilityLabel: formatter.missingAccessibilityLabel(for: event, nextSpoken: nextText?.spoken)
            )
        }
        return Column(
            title: title,
            detail: .time(
                formatter.timeText(moonEvent.date, in: place.timeZone),
                timeZone: abbreviation,
                direction: formatter.direction(for: moonEvent.azimuth)
            ),
            accessibilityLabel: formatter.accessibilityLabel(
                for: event,
                moonEvent,
                place: place,
                timeZoneAbbreviation: abbreviation
            )
        )
    }
}
