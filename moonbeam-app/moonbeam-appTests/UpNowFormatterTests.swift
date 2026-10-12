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
        let upNow = formatter.up(azimuth: 266, altitude: 22.6, pass: try Self.pass(), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.title == "Up now")
        #expect(upNow.isUp)
        guard case let .up(bearing, altitude, pass?) = upNow.state else {
            Issue.record("Expected the moon up with its pass")
            return
        }
        #expect(bearing == "266° W")
        #expect(altitude == "23° up")
        #expect(pass.riseTime.string == "10:06\(Self.nbsp)PM")
        #expect(pass.setTime.string == "1:28\(Self.nbsp)PM")
        #expect(pass.riseContext == "last night")
        #expect(pass.riseAccessibilityLabel == "Moonrise, last night, 10:06\(Self.nbsp)PM.")
        #expect(abs(pass.progress - Self.designProgress) < Self.progressTolerance)
    }

    @Test("Up: VoiceOver says the direction, bearing and altitude")
    func upAccessibilityLabel() throws {
        let upNow = formatter.up(azimuth: 266, altitude: 22.6, pass: try Self.pass(), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.accessibilityLabel
            == "Moon up now, west, 266 degrees, 23 degrees above the horizon.")
    }

    @Test("Up with no pass found: bearing only")
    func upWithoutPass() throws {
        let upNow = formatter.up(azimuth: 266, altitude: 22.6, pass: nil, at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .up(bearing: "266° W", altitude: "23° up", pass: nil))
        #expect(upNow.accessibilityLabel == "Moon up now, west, 266 degrees, 23 degrees above the horizon.")
    }

    @Test("Altitude rounds to whole degrees and never displays below 1° while up", arguments: [
        (-0.4, "1° up"),
        (0.4, "1° up"),
        (1.5, "2° up"),
        (22.4, "22° up"),
        (22.6, "23° up"),
    ])
    func altitudeFormatting(raw: Double, shown: String) throws {
        let upNow = formatter.up(
            azimuth: 266,
            altitude: raw,
            pass: nil,
            at: try Self.now(),
            in: Self.losAngelesZone
        )

        guard case let .up(_, altitude, _) = upNow.state else {
            Issue.record("Expected the moon up")
            return
        }
        #expect(altitude == shown)
    }

    @Test("Progress stays within the bar outside the pass")
    func progressClamps() throws {
        let pass = try Self.pass()
        let before = formatter.up(azimuth: 57, altitude: 1, pass: pass, at: pass.rise.date - Self.minutes(5), in: Self.losAngelesZone)
        let after = formatter.up(azimuth: 304, altitude: 1, pass: pass, at: pass.set.date + Self.minutes(5), in: Self.losAngelesZone)

        guard case let .up(_, _, beforePass?) = before.state, case let .up(_, _, afterPass?) = after.state else {
            Issue.record("Expected the moon up with its pass")
            return
        }
        #expect(beforePass.progress == 0)
        #expect(afterPass.progress == 1)
    }

    // MARK: - Moon down

    @Test("Not up yet counts down under an hour")
    func downCountdown() throws {
        let now = try Self.now()
        let upNow = formatter.down(nextRise: now + Self.minutes(34), at: now, in: Self.losAngelesZone)

        #expect(upNow.title == "Not up yet")
        #expect(!upNow.isUp)
        #expect(upNow.state == .notUpYet(countdown: "in 34 min"))
        #expect(upNow.accessibilityLabel == "Moon not up yet, rising in 34 minutes.")
    }

    @Test("Countdown boundary formatting", arguments: [
        (0.5, "Rising now", "rising now"),
        (33.2, "in 34 min", "rising in 34 minutes"),
        (59.0, "in 59 min", "rising in 59 minutes"),
        (60.0, "in 1h 0m", "rising in 1 hour and 0 minutes"),
        (200.0, "in 3h 20m", "rising in 3 hours and 20 minutes"),
    ])
    func countdownRounding(minutesAway: Double, shown: String, spoken: String) throws {
        let now = try Self.now()
        let upNow = formatter.down(nextRise: now + Self.minutes(minutesAway), at: now, in: Self.losAngelesZone)

        #expect(upNow.state == .notUpYet(countdown: shown))
        #expect(upNow.accessibilityLabel == "Moon not up yet, \(spoken).")
    }

    @Test("Not up yet uses a countdown beyond an hour")
    func downLaterToday() throws {
        let upNow = formatter.down(nextRise: try Self.date(10, 2, 22, 6), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .notUpYet(countdown: "in 14h 13m"))
    }

    @Test("Set for today uses the confirmed late-tonight wording after midnight")
    func downTomorrow() throws {
        let upNow = formatter.down(nextRise: try Self.date(10, 3, 9, 12), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .setForToday(nextRise: "Back late tonight, 9:12\(Self.nbsp)AM"))
        #expect(upNow.accessibilityLabel == "Moon set for today. Back late tonight at 9:12\(Self.nbsp)AM.")
    }

    /// Tomorrow can have no moonrise; the next is then just after midnight.
    @Test("Down, rising after tomorrow: the weekday and the time")
    func downLaterInTheWeek() throws {
        let upNow = formatter.down(nextRise: try Self.date(10, 4, 0, 5), at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .setForToday(nextRise: "Back late tonight, 12:05\(Self.nbsp)AM"))
    }

    @Test("Down with no rise in reach: no right side")
    func downWithoutRise() throws {
        let upNow = formatter.down(nextRise: nil, at: try Self.now(), in: Self.losAngelesZone)

        #expect(upNow.state == .setForToday(nextRise: nil))
        #expect(upNow.accessibilityLabel == "Moon set for today.")
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

        #expect(upNow.state == .notUpYet(countdown: "in 9h 2m"))
    }

    // MARK: - The AX fallback's pill (COMPASS-1.1.md §9.2, §9.14)

    @Test("Up: the pill includes bearing and altitude")
    func upPillText() throws {
        let upNow = formatter.up(azimuth: 266, altitude: 22.6, pass: try Self.pass(), at: try Self.now(), in: Self.losAngelesZone)
        guard case let .up(bearing, altitude, _) = upNow.state else {
            Issue.record("Expected the moon up")
            return
        }

        #expect(bearing == "266° W")
        #expect(altitude == "23° up")
        #expect(upNow.pillText == "Up now · 266° W · 23° up")
    }

    @Test("Today down keeps the middle column", arguments: [34.0, 853.0])
    func downHasMiddleColumn(minutesAway: Double) throws {
        let now = try Self.now()
        let upNow = formatter.down(nextRise: now + Self.minutes(minutesAway), at: now, in: Self.losAngelesZone)
        let layout = RiseSetLayout(upNow: upNow)

        #expect(layout.cells == [.moonrise, .upNow, .moonset])
        #expect(layout.fallback.showsPillRow)
    }
}
