//
//  UpNowFormatterTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The Up now row's text (COMPASS-1.1.md §3, §8), pinned to `en_US` and Los
/// Angeles. The moon-up case is the design's own: Fri, Oct 2, 7:53 AM, the
/// moon at 266° on the pass from 10:06 PM the evening before to 1:28 PM.
@Suite("Up now formatter")
nonisolated struct UpNowFormatterTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let nbsp = "\u{202F}"
    private static let secondsPerMinute: TimeInterval = 60

    /// 587 of the pass's 922 minutes.
    private static let designProgress = 587.0 / 922.0
    private static let progressTolerance = 1e-9

    private let formatter = UpNowFormatter(locale: Locale(identifier: "en_US"))

    private static func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        return try #require(calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )))
    }

    private static func now() throws -> Date { try date(10, 2, 7, 53) }

    private static func pass() throws -> MoonPass {
        MoonPass(
            rise: MoonEvent(date: try date(10, 1, 22, 6), azimuth: 57),
            set: MoonEvent(date: try date(10, 2, 13, 28), azimuth: 304),
            path: [57, 304]
        )
    }

    private static func minutes(_ count: Double) -> TimeInterval { count * secondsPerMinute }

    // MARK: - Moon up

    @Test("Up: bearing, last rise and next set, and how far along")
    func upShowsBearingAndPass() throws {
        let upNow = formatter.up(azimuth: 266, pass: try Self.pass(), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.title == "Up now")
        #expect(upNow.isUp)
        guard case let .up(bearing, pass?) = upNow.state else {
            Issue.record("Expected the moon up with its pass")
            return
        }
        #expect(bearing == "266° W")
        #expect(pass.riseTime == "10:06\(Self.nbsp)PM")
        #expect(pass.setTime == "1:28\(Self.nbsp)PM")
        #expect(abs(pass.progress - Self.designProgress) < Self.progressTolerance)
    }

    @Test("Up: VoiceOver says the direction, degrees, rise and set")
    func upAccessibilityLabel() throws {
        let upNow = formatter.up(azimuth: 266, pass: try Self.pass(), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.accessibilityLabel
            == "Moon up now, west, 266 degrees. Rose 10:06\(Self.nbsp)PM, sets 1:28\(Self.nbsp)PM.")
    }

    @Test("Up with no pass found: bearing only")
    func upWithoutPass() throws {
        let upNow = formatter.up(azimuth: 266, pass: nil, at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .up(bearing: "266° W", pass: nil))
        #expect(upNow.accessibilityLabel == "Moon up now, west, 266 degrees.")
    }

    @Test("Progress stays within the bar outside the pass")
    func progressClamps() throws {
        let pass = try Self.pass()
        let before = formatter.up(azimuth: 57, pass: pass, at: pass.rise.date - Self.minutes(5), in: Self.losAngelesZone)
        let after = formatter.up(azimuth: 304, pass: pass, at: pass.set.date + Self.minutes(5), in: Self.losAngelesZone)

        guard case let .up(_, beforePass?) = before.state, case let .up(_, afterPass?) = after.state else {
            Issue.record("Expected the moon up with its pass")
            return
        }
        #expect(beforePass.progress == 0)
        #expect(afterPass.progress == 1)
    }

    // MARK: - Moon down

    @Test("Down, under an hour: a countdown")
    func downCountdown() throws {
        let now = try Self.now()
        let upNow = formatter.down(nextRise: now + Self.minutes(34), at: now, in: Self.losAngelesZone)

        #expect(upNow.title == "Below the horizon")
        #expect(!upNow.isUp)
        #expect(upNow.state == .down(nextRise: "Rises in 34 min"))
        #expect(upNow.accessibilityLabel == "Moon below the horizon, rises in 34 minutes.")
    }

    @Test("Down: the countdown rounds up and never says 0", arguments: [
        (0.5, "Rises in 1 min", "rises in 1 minute"),
        (33.2, "Rises in 34 min", "rises in 34 minutes"),
        (59.0, "Rises in 59 min", "rises in 59 minutes"),
    ])
    func countdownRounding(minutesAway: Double, shown: String, spoken: String) throws {
        let now = try Self.now()
        let upNow = formatter.down(nextRise: now + Self.minutes(minutesAway), at: now, in: Self.losAngelesZone)

        #expect(upNow.state == .down(nextRise: shown))
        #expect(upNow.accessibilityLabel == "Moon below the horizon, \(spoken).")
    }

    @Test("Down, an hour or more away today: the time")
    func downLaterToday() throws {
        let upNow = formatter.down(nextRise: try Self.date(10, 2, 22, 6), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .down(nextRise: "Rises 10:06\(Self.nbsp)PM"))
        #expect(upNow.accessibilityLabel == "Moon below the horizon, rises at 10:06\(Self.nbsp)PM.")
    }

    @Test("Down, rising tomorrow: \"tomorrow\" and the time")
    func downTomorrow() throws {
        let upNow = formatter.down(nextRise: try Self.date(10, 3, 9, 12), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .down(nextRise: "Rises tomorrow 9:12\(Self.nbsp)AM"))
        #expect(upNow.accessibilityLabel == "Moon below the horizon, rises tomorrow at 9:12\(Self.nbsp)AM.")
    }

    /// Tomorrow can have no moonrise; the next is then just after midnight.
    @Test("Down, rising after tomorrow: the weekday and the time")
    func downLaterInTheWeek() throws {
        let upNow = formatter.down(nextRise: try Self.date(10, 4, 0, 5), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .down(nextRise: "Rises Sun 12:05\(Self.nbsp)AM"))
        #expect(upNow.accessibilityLabel == "Moon below the horizon, rises Sunday at 12:05\(Self.nbsp)AM.")
    }

    @Test("Down with no rise in reach: no right side")
    func downWithoutRise() throws {
        let upNow = formatter.down(nextRise: nil, at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .down(nextRise: nil))
        #expect(upNow.accessibilityLabel == "Moon below the horizon.")
    }

    /// "Today" is the place's: at 12:10 AM in Sydney it's still Oct 2 in
    /// UTC and in Los Angeles, but a 9:12 AM rise there is today, so no
    /// "tomorrow".
    @Test("Today and tomorrow are the place's days")
    func daysAreThePlacesDays() throws {
        let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sydneyZone
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 0, minute: 10)))
        let rise = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 9, minute: 12)))

        let upNow = formatter.down(nextRise: rise, at: now, in: sydneyZone)

        #expect(upNow.state == .down(nextRise: "Rises 9:12\(Self.nbsp)AM"))
    }

    // MARK: - The card's line (COMPASS-1.1.md §9.2)

    @Test("Up: the pill reads \"Up now · 266° W\"")
    func upLine() throws {
        let upNow = formatter.up(azimuth: 266, pass: try Self.pass(), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.line == "Up now · 266° W")
    }

    @Test("Down: the line is the next rise, with no \"Below the horizon\"", arguments: [
        (34.0, "Rises in 34 min"),
        (853.0, "Rises 10:06\u{202F}PM"),
        (1519.0, "Rises tomorrow 9:12\u{202F}AM"),
    ])
    func downLine(minutesAway: Double, expected: String) throws {
        let now = try Self.now()
        let upNow = formatter.down(nextRise: now + Self.minutes(minutesAway), at: now, in: Self.losAngelesZone)

        #expect(upNow.line == expected)
    }

    @Test("Down with no rise in reach: no line")
    func downWithoutRiseHasNoLine() throws {
        let upNow = formatter.down(nextRise: nil, at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.line == nil)
    }
}
