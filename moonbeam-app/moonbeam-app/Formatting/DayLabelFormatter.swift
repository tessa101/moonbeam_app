//
//  DayLabelFormatter.swift
//  moonbeam-app
//

import Foundation

/// Turns the selected day into the date control's label and its spoken form
/// (DATE.md §1, §5): "Sun, Sep 27" and "Tomorrow, Sunday, September 27,
/// 2026".
///
/// The visible label stays short: no relative word, and the year only when
/// the day is in a different year from the place's today ("Mon, Jan 4,
/// 2027"). The Today chip already says when you're off today. The spoken
/// form keeps the relative word and the year, since VoiceOver users don't see
/// the chip's context.
///
/// "Today" is the **place's** today: the caller works out the offset with
/// `DaySelection`. That's why this doesn't use `Date.RelativeFormatStyle`,
/// whose "today" is the device's. Dates are written in the place's zone, in
/// the locale's format and calendar.
///
/// `nonisolated` because it's a pure mapping over its inputs.
nonisolated struct DayLabelFormatter {

    // MARK: - Constants

    /// Between the relative word and the date when spoken.
    private static let spokenSeparator = ", "

    // MARK: - Configuration

    let locale: Locale

    /// - Parameter locale: injectable so tests can pin `en_US`.
    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    // MARK: - Formatting

    /// "Sun, Sep 27", or "Mon, Jan 4, 2027" when `day` is in a different
    /// year from `today`.
    ///
    /// - Parameter today: any moment in the place's today, such as now.
    func label(for day: Date, today: Date, timeZone: TimeZone) -> String {
        let style = dateStyle(timeZone: timeZone)
            .weekday(.abbreviated).month(.abbreviated).day()
        guard isSameYear(day, today, timeZone: timeZone) else {
            return day.formatted(style.year())
        }
        return day.formatted(style)
    }

    /// "Tomorrow, Sunday, September 27, 2026", for the date field's
    /// accessibility value. Always has the year; has the relative word when
    /// one applies.
    func accessibilityValue(for day: Date, dayOffset: Int, timeZone: TimeZone) -> String {
        let style = dateStyle(timeZone: timeZone)
            .weekday(.wide).month(.wide).day().year()
        let date = day.formatted(style)
        guard let word = Self.relativeWord(for: dayOffset) else { return date }
        return word + Self.spokenSeparator + date
    }

    // MARK: - Helpers

    /// The words DATE.md §5 uses when spoken; other offsets get none.
    private static func relativeWord(for dayOffset: Int) -> String? {
        switch dayOffset {
        case -1: "Yesterday"
        case 0: "Today"
        case 1: "Tomorrow"
        default: nil
        }
    }

    /// The locale's own calendar, set to the place's zone, so the date reads
    /// as that city's calendar day.
    private func dateStyle(timeZone: TimeZone) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: displayCalendar(timeZone: timeZone), timeZone: timeZone)
    }

    private func displayCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = locale.calendar
        calendar.timeZone = timeZone
        return calendar
    }

    /// Compared in the calendar the label is written in, so the year is
    /// shown exactly when the written year would differ.
    private func isSameYear(_ first: Date, _ second: Date, timeZone: TimeZone) -> Bool {
        displayCalendar(timeZone: timeZone).isDate(first, equalTo: second, toGranularity: .year)
    }
}
