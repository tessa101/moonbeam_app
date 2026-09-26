//
//  DayLabelFormatter.swift
//  moonbeam-app
//

import Foundation

/// Turns the selected day into the date control's label and its spoken form
/// (DATE.md §1, §5): "Today · Sat, Sep 26, 2026" and "Today, Saturday,
/// September 26, 2026".
///
/// The relative word comes from the day's offset from the **place's** today,
/// which the caller works out with `DaySelection`. That's why this doesn't
/// use `Date.RelativeFormatStyle`: its "today" is the device's. Dates are
/// written in the place's zone, in the locale's format and calendar.
///
/// `nonisolated` because it's a pure mapping over its inputs.
nonisolated struct DayLabelFormatter {

    // MARK: - Constants

    /// Between the relative word and the date in the visible label.
    private static let labelSeparator = " · "

    /// Between the relative word and the date when spoken.
    private static let spokenSeparator = ", "

    // MARK: - Configuration

    let locale: Locale

    /// - Parameter locale: injectable so tests can pin `en_US`.
    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    // MARK: - Formatting

    /// "Today · Sat, Sep 26, 2026", or just "Sat, Oct 3, 2026" when no
    /// relative word applies.
    func label(for day: Date, dayOffset: Int, timeZone: TimeZone) -> String {
        let style = dateStyle(timeZone: timeZone)
            .weekday(.abbreviated).month(.abbreviated).day().year()
        return joined(day.formatted(style), dayOffset: dayOffset, separator: Self.labelSeparator)
    }

    /// "Today, Saturday, September 26, 2026", for the date field's
    /// accessibility value.
    func accessibilityValue(for day: Date, dayOffset: Int, timeZone: TimeZone) -> String {
        let style = dateStyle(timeZone: timeZone)
            .weekday(.wide).month(.wide).day().year()
        return joined(day.formatted(style), dayOffset: dayOffset, separator: Self.spokenSeparator)
    }

    // MARK: - Helpers

    /// The words DATE.md §1 uses; other offsets get none.
    private static func relativeWord(for dayOffset: Int) -> String? {
        switch dayOffset {
        case -1: "Yesterday"
        case 0: "Today"
        case 1: "Tomorrow"
        default: nil
        }
    }

    private func joined(_ date: String, dayOffset: Int, separator: String) -> String {
        guard let word = Self.relativeWord(for: dayOffset) else { return date }
        return word + separator + date
    }

    /// The locale's own calendar, set to the place's zone, so the date reads
    /// as that city's calendar day.
    private func dateStyle(timeZone: TimeZone) -> Date.FormatStyle {
        var calendar = locale.calendar
        calendar.timeZone = timeZone
        return Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
    }
}
