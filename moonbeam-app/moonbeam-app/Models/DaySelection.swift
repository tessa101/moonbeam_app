//
//  DaySelection.swift
//  moonbeam-app
//

import Foundation

/// The day the moon table is for: a calendar day in the **place's** time
/// zone, not a moment in time (DATE.md §3).
///
/// `.today` follows the place's current day, so it moves when the city or the
/// clock does. `.day` is a picked calendar day that stays put when the city
/// changes (Oct 3 in LA → Oct 3 in Sydney).
///
/// All the math uses a Gregorian calendar in the place's zone and moves by
/// calendar days (`date(byAdding: .day, …)`), never by 86,400 seconds, so 23-
/// and 25-hour DST days land on the right day. Days are anchored at local
/// noon: noon always exists, whereas midnight doesn't in zones whose DST
/// starts at 00:00.
///
/// `nonisolated`: an inert value, not main-actor state.
nonisolated enum DaySelection: Equatable, Sendable {
    case today
    case day(year: Int, month: Int, day: Int)

    // MARK: - Constants

    /// DATE.md §1: today ±366 days.
    static let maximumDayOffset = 366

    /// The hour each day is anchored on. See the type comment.
    private static let anchorHour = 12

    private static let dayRange = -maximumDayOffset...maximumDayOffset

    // MARK: - Resolving

    /// The selected calendar day (year, month and day only), clamped to the
    /// range.
    func resolvedDay(in timeZone: TimeZone, now: Date) -> DateComponents {
        let calendar = Self.calendar(in: timeZone)
        return Self.dayComponents(of: noon(in: timeZone, now: now), calendar: calendar)
    }

    /// Local midnight at the start of the selected day, or the first moment
    /// of the day where midnight is skipped.
    func startOfDay(in timeZone: TimeZone, now: Date) -> Date {
        Self.calendar(in: timeZone).startOfDay(for: noon(in: timeZone, now: now))
    }

    /// Local noon on the selected day. The anchor for all the day math, and
    /// the moment the time zone label samples: DST changes happen overnight,
    /// so noon has the offset for nearly all of the day.
    func noon(in timeZone: TimeZone, now: Date) -> Date {
        let calendar = Self.calendar(in: timeZone)
        let todayNoon = Self.todayNoon(calendar: calendar, now: now)
        let offset = dayOffset(in: timeZone, now: now)
        return calendar.date(byAdding: .day, value: offset, to: todayNoon) ?? todayNoon
    }

    /// Calendar days from the place's today: 0 today, 1 tomorrow, -1
    /// yesterday. Clamped to ±`maximumDayOffset`.
    func dayOffset(in timeZone: TimeZone, now: Date) -> Int {
        guard case let .day(year, month, day) = self else { return 0 }
        let calendar = Self.calendar(in: timeZone)
        let components = DateComponents(year: year, month: month, day: day)
        return Self.clamped(Self.unclampedOffset(of: components, calendar: calendar, now: now))
    }

    // MARK: - Moving

    /// The selection `days` calendar days away, clamped to the range. Becomes
    /// `.today` when it lands on the place's today (DATE.md §3).
    func offset(by days: Int, in timeZone: TimeZone, now: Date) -> DaySelection {
        let target = Self.clamped(dayOffset(in: timeZone, now: now) + days)
        return Self.selection(atOffset: target, calendar: Self.calendar(in: timeZone), now: now)
    }

    /// The selection for a picked calendar day, clamped to the range, and
    /// `.today` if it is the place's today. Only year, month and day are read.
    static func selecting(_ day: DateComponents, in timeZone: TimeZone, now: Date) -> DaySelection {
        let calendar = calendar(in: timeZone)
        let offset = clamped(unclampedOffset(of: day, calendar: calendar, now: now))
        return selection(atOffset: offset, calendar: calendar, now: now)
    }

    /// Start of the first day to start of the last day in the range, for the
    /// calendar sheet's picker.
    static func range(in timeZone: TimeZone, now: Date) -> ClosedRange<Date> {
        let earliest = DaySelection.today.offset(by: -maximumDayOffset, in: timeZone, now: now)
        let latest = DaySelection.today.offset(by: maximumDayOffset, in: timeZone, now: now)
        return earliest.startOfDay(in: timeZone, now: now)...latest.startOfDay(in: timeZone, now: now)
    }

    // MARK: - Helpers

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func clamped(_ offset: Int) -> Int {
        min(max(offset, dayRange.lowerBound), dayRange.upperBound)
    }

    private static func dayComponents(of date: Date, calendar: Calendar) -> DateComponents {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return DateComponents(year: parts.year, month: parts.month, day: parts.day)
    }

    /// Noon on the given calendar day, or `nil` if the components don't make
    /// a date.
    private static func noon(of day: DateComponents, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: anchorHour
        ))
    }

    private static func todayNoon(calendar: Calendar, now: Date) -> Date {
        noon(of: dayComponents(of: now, calendar: calendar), calendar: calendar) ?? now
    }

    /// Calendar days from the place's today to `day`. Components that don't
    /// make a date count as today rather than failing.
    private static func unclampedOffset(of day: DateComponents, calendar: Calendar, now: Date) -> Int {
        guard let target = noon(of: day, calendar: calendar) else { return 0 }
        let today = todayNoon(calendar: calendar, now: now)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private static func selection(atOffset offset: Int, calendar: Calendar, now: Date) -> DaySelection {
        guard offset != 0 else { return .today }
        let today = todayNoon(calendar: calendar, now: now)
        guard let target = calendar.date(byAdding: .day, value: offset, to: today) else { return .today }
        let parts = calendar.dateComponents([.year, .month, .day], from: target)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return .today }
        return .day(year: year, month: month, day: day)
    }
}
