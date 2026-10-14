//
//  LocationOffGuideTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The location-off guide row (LOCATION-OFF-FLOW.md §3.1, 5.12b.2): which of S2
/// to S6 at fixed times, every boundary, the after-midnight rise, other dates,
/// the countdown wording, and the view model feeding it.
@Suite("Location-off guide", .timeLimit(.minutes(1)))
@MainActor
struct LocationOffGuideTests {

    // MARK: - Fixtures

    private static let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    /// 2026-10-02 at `hour:minute:second` in Irvine's zone (`day` 3 is the
    /// next day).
    private static func time(_ hour: Int, _ minute: Int, _ second: Int = 0, day: Int = 2) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(
            year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second
        )) ?? .distantPast
    }

    private static let now = time(18, 0)

    private static func down(nextRiseIn seconds: TimeInterval?, isToday: Bool = true) -> LocationOffGuide {
        LocationOffGuide.state(
            now: now,
            isToday: isToday,
            isMoonUp: false,
            passRise: nil,
            nextRise: seconds.map { now.addingTimeInterval($0) }
        )
    }

    private static func up(roseAgo seconds: TimeInterval?, isToday: Bool = true) -> LocationOffGuide {
        LocationOffGuide.state(
            now: now,
            isToday: isToday,
            isMoonUp: true,
            passRise: seconds.map { now.addingTimeInterval(-$0) },
            nextRise: nil
        )
    }

    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3600

    // MARK: - States and boundaries

    @Test("S2: moon down, no moonrise within 3 h, or none at all")
    func waiting() {
        #expect(Self.down(nextRiseIn: 5 * Self.hour) == .waiting)
        #expect(Self.down(nextRiseIn: nil) == .waiting)
        #expect(Self.down(nextRiseIn: 5 * Self.hour).stage == .s2)
    }

    @Test("3 h boundary: exactly 3 h is S3, a second more is S2")
    func threeHourBoundary() {
        #expect(Self.down(nextRiseIn: 3 * Self.hour) == .moonriseIn(minutes: 180))
        #expect(Self.down(nextRiseIn: 3 * Self.hour).stage == .s3)
        #expect(Self.down(nextRiseIn: 3 * Self.hour + 1) == .waiting)
    }

    @Test("60 / 59 min boundary: 60 min is S3, 59 min is S4")
    func hourBoundary() {
        #expect(Self.down(nextRiseIn: 60 * Self.minute).stage == .s3)
        #expect(Self.down(nextRiseIn: 59 * Self.minute) == .moonriseIn(minutes: 59))
        #expect(Self.down(nextRiseIn: 59 * Self.minute).stage == .s4)
        // Rounded up like the card: 59 min 30 s still reads an hour.
        #expect(Self.down(nextRiseIn: 59 * Self.minute + 30) == .moonriseIn(minutes: 60))
    }

    @Test("S4 down to a minute; under a minute away is S5")
    func underAMinute() {
        #expect(Self.down(nextRiseIn: Self.minute) == .moonriseIn(minutes: 1))
        #expect(Self.down(nextRiseIn: 59) == .rising)
        #expect(Self.down(nextRiseIn: 0) == .rising)
        // Just past the rise while the moon still reads down.
        #expect(Self.down(nextRiseIn: -30) == .rising)
    }

    @Test("+15 min boundary: S5 until 15 min after the pass's rise, then S6")
    func risingWindow() {
        #expect(Self.up(roseAgo: 0) == .rising)
        #expect(Self.up(roseAgo: 15 * Self.minute - 1) == .rising)
        #expect(Self.up(roseAgo: 15 * Self.minute) == .up)
        #expect(Self.up(roseAgo: 15 * Self.minute).stage == .s6)
    }

    @Test("A moon that rose last night is S6, not S5; no pass found is S6")
    func upSinceLastNight() {
        #expect(Self.up(roseAgo: 9 * Self.hour) == .up)
        #expect(Self.up(roseAgo: nil) == .up)
    }

    @Test("After moonset: back to S2 when the next rise is hours off")
    func afterMoonset() {
        #expect(Self.down(nextRiseIn: 20 * Self.hour) == .waiting)
    }

    @Test("Any other date is S2, up or down")
    func otherDate() {
        #expect(Self.down(nextRiseIn: 40 * Self.minute, isToday: false) == .waiting)
        #expect(Self.up(roseAgo: 5 * Self.minute, isToday: false) == .waiting)
    }

    @Test("The next rise may be after midnight: 10:30 PM with a 12:20 AM rise is 1 hr 50 min")
    func afterMidnight() {
        let guide = LocationOffGuide.state(
            now: Self.time(22, 30),
            isToday: true,
            isMoonUp: false,
            passRise: nil,
            nextRise: Self.time(0, 20, day: 3)
        )
        #expect(guide == .moonriseIn(minutes: 110))
        #expect(LocationOffGuideFormatter().row(for: guide).title == "Moonrise in 1 hr 50 min")
    }

    @Test("The row counts minutes exactly as the card's countdown does")
    func sameRoundingAsCard() {
        let rise = Self.now.addingTimeInterval(99 * Self.minute + 1)
        #expect(UpNowFormatter.countdownMinutes(until: rise, from: Self.now) == 100)
        let card = UpNowFormatter(locale: Locale(identifier: "en_US_POSIX"))
            .down(nextRise: rise, at: Self.now, in: Self.zone)
        #expect(card.detail == "in 1h 40m")
        #expect(LocationOffGuide.state(now: Self.now, isToday: true, isMoonUp: false, passRise: nil, nextRise: rise)
            == .moonriseIn(minutes: 100))
    }

    @Test("Active styling is S3 to S6")
    func activeStates() {
        #expect(!LocationOffGuide.waiting.isActive)
        #expect(LocationOffGuide.moonriseIn(minutes: 40).isActive)
        #expect(LocationOffGuide.rising.isActive)
        #expect(LocationOffGuide.up.isActive)
    }

    // MARK: - Wording

    @Test("Countdown: X hr Y min from an hour, 0 min dropped, X min under an hour")
    func countdownFormat() {
        #expect(LocationOffGuideFormatter.countdown(minutes: 135) == "2 hr 15 min")
        #expect(LocationOffGuideFormatter.countdown(minutes: 120) == "2 hr")
        #expect(LocationOffGuideFormatter.countdown(minutes: 61) == "1 hr 1 min")
        #expect(LocationOffGuideFormatter.countdown(minutes: 60) == "1 hr")
        #expect(LocationOffGuideFormatter.countdown(minutes: 40) == "40 min")
        #expect(LocationOffGuideFormatter.countdown(minutes: 1) == "1 min")
    }

    @Test("Each state's title and subtitle are the handoff's")
    func rows() {
        let formatter = LocationOffGuideFormatter()
        #expect(formatter.row(for: .waiting)
            == .init(title: "Compass guide is waiting", subtitle: "Tap whenever you want directions"))
        #expect(formatter.row(for: .moonriseIn(minutes: 135))
            == .init(title: "Moonrise in 2 hr 15 min", subtitle: "Want her to show you where?"))
        #expect(formatter.row(for: .moonriseIn(minutes: 40)).title == "Moonrise in 40 min")
        #expect(formatter.row(for: .rising).title == "The moon is rising now")
        #expect(formatter.row(for: .up).title == "The moon is up now")
        #expect(formatter.row(for: .up).accessibilityLabel == "The moon is up now, Want her to show you where?")
    }

    // MARK: - View model

    @Test("The view model gives the guide from the moon service, today only")
    func viewModelFeedsGuide() {
        let moon = FakeMoonService(position: MoonPosition(azimuth: 60, isUp: false))
        moon.nextRise = MoonEvent(date: Self.now.addingTimeInterval(40 * Self.minute), azimuth: 60)
        let viewModel = CompassViewModel(
            headingService: FakeHeadingService(),
            moonService: moon,
            now: { Self.now },
            sleep: { _ in try await Task.sleep(for: .seconds(3600)) }
        )
        viewModel.update(Self.context(isToday: true))
        #expect(viewModel.locationGuide == .moonriseIn(minutes: 40))

        viewModel.update(Self.context(isToday: false))
        #expect(viewModel.locationGuide == .waiting)
    }

    @Test("Moon up: the pass's rise decides rising vs up")
    func viewModelRising() {
        let rise = MoonEvent(date: Self.now.addingTimeInterval(-5 * Self.minute), azimuth: 60)
        let pass = MoonPass(
            rise: rise,
            set: MoonEvent(date: Self.now.addingTimeInterval(10 * Self.hour), azimuth: 300),
            path: [60, 180, 300]
        )
        let moon = FakeMoonService(position: MoonPosition(azimuth: 62, altitude: 1, isUp: true), pass: pass)
        let viewModel = CompassViewModel(
            headingService: FakeHeadingService(),
            moonService: moon,
            now: { Self.now },
            sleep: { _ in try await Task.sleep(for: .seconds(3600)) }
        )
        viewModel.update(Self.context(isToday: true))
        #expect(viewModel.locationGuide == .rising)
    }

    @Test("No guide where the prompt doesn't show (restricted)")
    func viewModelRestricted() {
        let moon = FakeMoonService(position: MoonPosition(azimuth: 60, isUp: false))
        moon.nextRise = MoonEvent(date: Self.now.addingTimeInterval(40 * Self.minute), azimuth: 60)
        let viewModel = CompassViewModel(headingService: FakeHeadingService(), moonService: moon, now: { Self.now })
        viewModel.update(Self.context(isToday: true, auth: .restricted))
        #expect(viewModel.locationGuide == .waiting)
    }

    private static func context(isToday: Bool, auth: LocationAuthState = .denied) -> CompassContext {
        CompassContext(
            place: .irvine,
            detectedPlace: nil,
            authState: auth,
            moonDay: MoonDay(
                place: .irvine,
                rise: MoonEvent(date: now, azimuth: 60),
                set: MoonEvent(date: now, azimuth: 300),
                phase: .full,
                phaseAngle: FakeMoonService.fullMoonPhaseAngle,
                illumination: FakeMoonService.fullyLit
            ),
            isToday: isToday
        )
    }
}
