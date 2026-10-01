//
//  TimeText.swift
//  moonbeam-app
//

import Foundation

/// A formatted time split into runs, so the card can set the day period
/// ("AM", "오전", "ص") smaller than the digits (DESIGN-1.1.md §3.2) without
/// knowing where a locale puts it, or whether it has one.
///
/// Built by `MoonTableFormatter.timeText(_:in:)` from `Date.FormatStyle`'s
/// attributed output: a run is the day period exactly when the formatter
/// marks it as the `.amPM` date field. Everything else (digits, separators,
/// spaces) stays together as ordinary runs.
///
/// `nonisolated`: an inert value.
nonisolated struct TimeText: Equatable {

    /// One stretch of the time, in reading order.
    struct Run: Equatable {
        let text: String
        /// The `.amPM` field, drawn at the smaller day-period size.
        let isDayPeriod: Bool
    }

    let runs: [Run]

    /// The whole time as plain text, e.g. "9:10 PM": what VoiceOver hears.
    var string: String {
        runs.map(\.text).joined()
    }

    /// Splits `attributed` (a `Date.FormatStyle` attributed format) at the
    /// day period, merging every other field into ordinary runs.
    init(_ attributed: AttributedString) {
        var runs: [Run] = []
        for run in attributed.runs {
            let text = String(attributed[run.range].characters)
            let isDayPeriod = run.attributes.foundation.dateField == .amPM
            if let last = runs.last, last.isDayPeriod == isDayPeriod {
                runs[runs.count - 1] = Run(text: last.text + text, isDayPeriod: isDayPeriod)
            } else {
                runs.append(Run(text: text, isDayPeriod: isDayPeriod))
            }
        }
        self.runs = runs
    }

    init(runs: [Run]) {
        self.runs = runs
    }
}
