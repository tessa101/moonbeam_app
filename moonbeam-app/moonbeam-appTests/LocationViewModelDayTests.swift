//
//  LocationViewModelDayTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `LocationViewModel`'s day selection (DATE.md §3, §4, §6): the date control
/// state, which day reaches `MoonService`, the midnight rollover on
/// foreground, and the time zone label following the selected day.
///
/// Its own suite, separate from `LocationViewModelTests`, so the location
/// fixtures there stay as they are. Uses a clock the test can move forward.
@Suite("Location view model: day selection")
@MainActor
struct LocationViewModelDayTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

    /// No DST: the same offset as LA in summer, an hour apart in winter.
    private static let phoenixZone = TimeZone(identifier: "America/Phoenix") ?? .gmt

    /// The ASTRONOMY.md §5 reference location.
    private static let marVista = Place(
        name: "Mar Vista",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: losAngelesZone
    )

    private static let sydney = Place(
        name: "Sydney",
        locality: "Sydney",
        region: "NSW",
        country: "Australia",
        latitude: -33.87,
        longitude: 151.21,
        timeZone: sydneyZone
    )

    private static let phoenix = Place(
        name: "Phoenix",
        locality: "Phoenix",
        region: "AZ",
        country: "United States",
        latitude: 33.45,
        longitude: -112.07,
        timeZone: phoenixZone
    )

    /// ASTRONOMY.md §5.
    private static let timeToleranceSeconds = 120.0

    /// A clock the test moves forward, standing in for the view model's
    /// injected `now`.
    private final class TestClock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private static func makeViewModel(
        clock: TestClock,
        moonService: any MoonService = FakeMoonService()
    ) -> LocationViewModel {
        LocationViewModel(
            locationService: FakeLocationService(),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: moonService,
            deviceTimeZone: losAngelesZone,
            now: { clock.now }
        )
    }

    // MARK: - Default state

    @Test("Starts on today with no Today chip, and the service gets today")
    func startsOnToday() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)

        viewModel.select(Self.marVista)

        #expect(viewModel.daySelection == .today)
        #expect(!viewModel.showsTodayChip)
        #expect(viewModel.dateLabel.hasPrefix("Today · "))
        #expect(viewModel.dateAccessibilityValue.hasPrefix("Today, "))
        #expect(service.requestedDates.last == (try Self.date(2026, 9, 26, hour: 0, in: Self.losAngelesZone)))
    }

    @Test("A new view model (relaunch) opens on today")
    func relaunchOpensOnToday() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let first = Self.makeViewModel(clock: clock)
        first.select(Self.marVista)
        first.nextDay()
        #expect(first.daySelection != .today)

        let relaunched = Self.makeViewModel(clock: clock)

        #expect(relaunched.daySelection == .today)
    }

    // MARK: - Previous, next, Today chip

    @Test("Next day: Tomorrow label, chip shown, service gets Sep 27 in the place's zone")
    func nextDay() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)

        viewModel.nextDay()

        let sep27 = try Self.date(2026, 9, 27, hour: 0, in: Self.losAngelesZone)
        #expect(viewModel.daySelection == .day(year: 2026, month: 9, day: 27))
        #expect(viewModel.dateLabel.hasPrefix("Tomorrow · "))
        #expect(viewModel.showsTodayChip)
        #expect(service.requestedDates.last == sep27)
        #expect(viewModel.moonTable?.day == sep27)
    }

    @Test("Previous day: Yesterday label")
    func previousDay() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)

        viewModel.previousDay()

        #expect(viewModel.daySelection == .day(year: 2026, month: 9, day: 25))
        #expect(viewModel.dateLabel.hasPrefix("Yesterday · "))
        #expect(viewModel.showsTodayChip)
    }

    @Test("Today chip returns to today and hides itself")
    func todayChip() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        viewModel.nextDay()

        viewModel.goToToday()

        #expect(viewModel.daySelection == .today)
        #expect(!viewModel.showsTodayChip)
        #expect(service.requestedDates.last == (try Self.date(2026, 9, 26, hour: 0, in: Self.losAngelesZone)))
    }

    // MARK: - Calendar sheet

    @Test("A calendar pick sets the day and closes the sheet")
    func calendarPick() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.presentCalendar()
        #expect(viewModel.isCalendarPresented)

        viewModel.select(day: DateComponents(year: 2026, month: 10, day: 3))

        #expect(viewModel.daySelection == .day(year: 2026, month: 10, day: 3))
        #expect(!viewModel.isCalendarPresented)
        #expect(viewModel.dateLabel.hasSuffix("2026"))
        #expect(!viewModel.dateLabel.contains(" · "))
    }

    /// What the graphical picker does: sets a `Date` somewhere in the day.
    @Test("Setting the picker's date picks that calendar day in the place's zone")
    func calendarDateBinding() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.sydney)
        viewModel.presentCalendar()

        // 00:30 Oct 3 in Sydney is still Oct 2 on the device's LA clock.
        viewModel.calendarDate = try Self.date(2026, 10, 3, hour: 0, minute: 30, in: Self.sydneyZone)

        #expect(viewModel.daySelection == .day(year: 2026, month: 10, day: 3))
        #expect(!viewModel.isCalendarPresented)
        #expect(viewModel.calendarTimeZone == Self.sydneyZone)
        #expect(viewModel.calendarDate == (try Self.date(2026, 10, 3, hour: 12, in: Self.sydneyZone)))
    }

    @Test("Cancel closes the sheet and changes nothing")
    func calendarCancel() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        let requestsBefore = service.requestedDates.count
        viewModel.presentCalendar()

        viewModel.isCalendarPresented = false

        #expect(viewModel.daySelection == .day(year: 2026, month: 9, day: 27))
        #expect(service.requestedDates.count == requestsBefore)
    }

    @Test("Picking today in the calendar goes back to following today")
    func calendarPickToday() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        viewModel.presentCalendar()

        viewModel.select(day: DateComponents(year: 2026, month: 9, day: 26))

        #expect(viewModel.daySelection == .today)
        #expect(!viewModel.showsTodayChip)
        #expect(!viewModel.isCalendarPresented)
    }

    @Test("The sheet's Today button returns to today and closes the sheet")
    func calendarTodayButton() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.select(day: DateComponents(year: 2026, month: 10, day: 3))
        viewModel.presentCalendar()

        viewModel.goToToday()

        #expect(viewModel.daySelection == .today)
        #expect(!viewModel.isCalendarPresented)
    }

    // MARK: - Calendar sheet: the month/year wheel

    /// The graphical picker's wheel keeps the day number (Sep 27 → Oct 27).
    /// That only moves the highlight; the sheet stays open for Done.
    @Test("A wheel change moves the highlight without picking or closing")
    func wheelChangeIsADraft() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        let requestsBefore = service.requestedDates.count
        viewModel.presentCalendar()
        #expect(!viewModel.showsCalendarDone)

        viewModel.calendarDate = try Self.date(2026, 10, 27, hour: 12, in: Self.losAngelesZone)

        #expect(viewModel.isCalendarPresented)
        #expect(viewModel.showsCalendarDone)
        #expect(viewModel.daySelection == .day(year: 2026, month: 9, day: 27))
        #expect(service.requestedDates.count == requestsBefore)
        #expect(viewModel.calendarDate == (try Self.date(2026, 10, 27, hour: 12, in: Self.losAngelesZone)))
    }

    @Test("Done after a wheel change picks the highlighted day and closes")
    func doneConfirmsTheDraft() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        viewModel.presentCalendar()
        viewModel.calendarDate = try Self.date(2026, 10, 27, hour: 12, in: Self.losAngelesZone)

        viewModel.confirmCalendarDraft()

        #expect(viewModel.daySelection == .day(year: 2026, month: 10, day: 27))
        #expect(!viewModel.isCalendarPresented)
        #expect(!viewModel.showsCalendarDone)
    }

    @Test("A tap on a new day after a wheel change still picks it and closes")
    func tapAfterWheelChangePicks() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        viewModel.presentCalendar()
        viewModel.calendarDate = try Self.date(2026, 10, 27, hour: 12, in: Self.losAngelesZone)

        viewModel.calendarDate = try Self.date(2026, 10, 3, hour: 12, in: Self.losAngelesZone)

        #expect(viewModel.daySelection == .day(year: 2026, month: 10, day: 3))
        #expect(!viewModel.isCalendarPresented)
    }

    @Test("Cancel after a wheel change drops the draft; reopening starts from the selected day")
    func cancelDropsTheDraft() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.nextDay()
        viewModel.presentCalendar()
        viewModel.calendarDate = try Self.date(2026, 10, 27, hour: 12, in: Self.losAngelesZone)

        viewModel.isCalendarPresented = false
        viewModel.presentCalendar()

        #expect(viewModel.daySelection == .day(year: 2026, month: 9, day: 27))
        #expect(!viewModel.showsCalendarDone)
        #expect(viewModel.calendarDate == (try Self.date(2026, 9, 27, hour: 12, in: Self.losAngelesZone)))
    }

    /// Jan 31 → February: the wheel has to clamp to the 28th.
    @Test("A wheel change clamped to the month's last day is still a draft")
    func clampedWheelChangeIsADraft() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.select(day: DateComponents(year: 2027, month: 1, day: 31))
        viewModel.presentCalendar()

        viewModel.calendarDate = try Self.date(2027, 2, 28, hour: 12, in: Self.losAngelesZone)

        #expect(viewModel.isCalendarPresented)
        #expect(viewModel.showsCalendarDone)
        #expect(viewModel.daySelection == .day(year: 2027, month: 1, day: 31))
    }

    /// The accepted ambiguity: the same day number in another month looks
    /// like the wheel, so it waits for Done.
    @Test("Tapping the same day number in another month waits for Done")
    func sameDayNumberElsewhereIsADraft() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        viewModel.presentCalendar()

        viewModel.calendarDate = try Self.date(2026, 11, 26, hour: 12, in: Self.losAngelesZone)

        #expect(viewModel.isCalendarPresented)
        #expect(viewModel.showsCalendarDone)
        #expect(viewModel.daySelection == .today)
    }

    @Test("With no place there's no calendar to open")
    func noCalendarWithoutAPlace() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)

        viewModel.presentCalendar()

        #expect(!viewModel.isCalendarPresented)
        #expect(!viewModel.canGoBack)
        #expect(!viewModel.canGoForward)
        #expect(!viewModel.showsTodayChip)
    }

    // MARK: - City change (DATE.md §3)

    /// At 8 PM Sep 26 in LA, Sydney's today is Sep 27.
    @Test("City change while following today follows the new city's today")
    func cityChangeFollowingToday() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)

        viewModel.select(Self.sydney)

        #expect(viewModel.daySelection == .today)
        #expect(viewModel.dateLabel.hasPrefix("Today · "))
        #expect(service.requestedDates.last == (try Self.date(2026, 9, 27, hour: 0, in: Self.sydneyZone)))
    }

    @Test("City change on a picked date keeps the same calendar day")
    func cityChangeOnPickedDay() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)
        viewModel.select(day: DateComponents(year: 2026, month: 10, day: 3))

        viewModel.select(Self.sydney)

        #expect(viewModel.daySelection == .day(year: 2026, month: 10, day: 3))
        #expect(service.requestedDates.last == (try Self.date(2026, 10, 3, hour: 0, in: Self.sydneyZone)))
    }

    // MARK: - Midnight rollover, on foreground (DATE.md §3)

    @Test("Foreground after the place's midnight: following today moves to the new day")
    func rolloverFollowingToday() async throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 23, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)

        clock.now = try Self.date(2026, 9, 27, hour: 1, in: Self.losAngelesZone)
        await viewModel.sceneDidBecomeActive()

        let sep27 = try Self.date(2026, 9, 27, hour: 0, in: Self.losAngelesZone)
        #expect(viewModel.daySelection == .today)
        #expect(viewModel.moonTable?.day == sep27)
        #expect(service.requestedDates.last == sep27)
    }

    @Test("Foreground after the place's midnight: a picked date stays put")
    func rolloverOnPickedDay() async throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 23, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)
        viewModel.select(day: DateComponents(year: 2026, month: 10, day: 3))
        let requestsBefore = service.requestedDates.count

        clock.now = try Self.date(2026, 9, 27, hour: 1, in: Self.losAngelesZone)
        await viewModel.sceneDidBecomeActive()

        #expect(viewModel.daySelection == .day(year: 2026, month: 10, day: 3))
        #expect(service.requestedDates.count == requestsBefore)
    }

    @Test("Foreground before the place's midnight: nothing is rebuilt")
    func noRolloverSameDay() async throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 20, in: Self.losAngelesZone))
        let service = FakeMoonService()
        let viewModel = Self.makeViewModel(clock: clock, moonService: service)
        viewModel.select(Self.marVista)
        let requestsBefore = service.requestedDates.count

        clock.now = try Self.date(2026, 9, 26, hour: 23, in: Self.losAngelesZone)
        await viewModel.sceneDidBecomeActive()

        #expect(service.requestedDates.count == requestsBefore)
    }

    // MARK: - Range (±366)

    @Test("› is disabled at +366 and ‹ at −366")
    func rangeLimits() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 12, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.marVista)
        #expect(viewModel.canGoBack)
        #expect(viewModel.canGoForward)

        // +365, then one step to the limit.
        viewModel.select(day: DateComponents(year: 2027, month: 9, day: 26))
        #expect(viewModel.canGoForward)
        viewModel.nextDay()
        #expect(viewModel.daySelection == .day(year: 2027, month: 9, day: 27))
        #expect(!viewModel.canGoForward)
        #expect(viewModel.canGoBack)
        viewModel.nextDay()
        #expect(viewModel.daySelection == .day(year: 2027, month: 9, day: 27))

        // Past the far end clamps to −366.
        viewModel.select(day: DateComponents(year: 2020, month: 1, day: 1))
        #expect(viewModel.daySelection == .day(year: 2025, month: 9, day: 25))
        #expect(!viewModel.canGoBack)
        #expect(viewModel.canGoForward)
    }

    // MARK: - Time zone label on the selected day

    /// Phoenix has no DST. In September both are UTC−7; after LA falls back
    /// on Nov 1 they're an hour apart.
    @Test("Phoenix on an LA device: no label today, label on a day after LA falls back")
    func phoenixLabelFollowsTheDay() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 12, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.phoenix)

        #expect(viewModel.timeZoneLabel == nil)

        viewModel.select(day: DateComponents(year: 2026, month: 11, day: 5))

        let noon = try Self.date(2026, 11, 5, hour: 12, in: Self.phoenixZone)
        let abbreviation = try #require(Self.phoenixZone.abbreviation(for: noon))
        #expect(viewModel.timeZoneLabel == "Phoenix · \(abbreviation)")
        #expect(viewModel.timeZoneAccessibilityLabel != nil)
    }

    /// Sampled at noon, LA's changeover day counts as after the change (it
    /// falls back at 02:00).
    @Test("Phoenix on an LA device: label shown on LA's fall-back day")
    func phoenixLabelOnTheChangeoverDay() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 12, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.phoenix)

        viewModel.select(day: DateComponents(year: 2026, month: 11, day: 1))

        #expect(viewModel.timeZoneLabel != nil)
    }

    /// Sydney is on AEST (+10) in September and AEDT (+11) from Oct 4.
    @Test("Sydney on an LA device: a late-November day gets that day's abbreviation")
    func sydneyLabelUsesTheSelectedDay() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 12, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock)
        viewModel.select(Self.sydney)
        let todayAbbreviation = try #require(Self.sydneyZone.abbreviation(for: clock.now))

        viewModel.select(day: DateComponents(year: 2026, month: 11, day: 25))

        let noon = try Self.date(2026, 11, 25, hour: 12, in: Self.sydneyZone)
        let abbreviation = try #require(Self.sydneyZone.abbreviation(for: noon))
        #expect(abbreviation != todayAbbreviation)
        #expect(viewModel.timeZoneLabel == "Sydney · \(abbreviation)")
    }

    // MARK: - Values through the view model (engine-derived guards)

    /// ASTRONOMY.md §5 has no USNO row for this day yet. STATUS.md's engine
    /// prediction: no rise (23:12 on 10/2, 00:21 on 10/4), set 14:27. FR2's
    /// "No moonrise today" text.
    @Test("Mar Vista 2026-10-03: no moonrise (engine-derived)")
    func marVistaNoMoonrise() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 12, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock, moonService: AstronomyEngineMoonService())
        viewModel.select(Self.marVista)

        viewModel.select(day: DateComponents(year: 2026, month: 10, day: 3))

        let moonTable = try #require(viewModel.moonTable)
        #expect(moonTable.moonDay.rise == nil)
        #expect(moonTable.riseText == "No moonrise today")
        let set = try #require(moonTable.moonDay.set)
        try Self.expectNear(set.date, try Self.date(2026, 10, 3, hour: 14, minute: 27, in: Self.losAngelesZone))
    }

    /// Mar Vista rise and set are the §5 USNO row. Sydney is the engine
    /// prediction in STATUS.md, since §5's Sydney row isn't filled yet.
    @Test("2026-09-23 picked through the view model matches the reference rows")
    func referenceRowsBySelectedDate() throws {
        let clock = TestClock(try Self.date(2026, 9, 26, hour: 12, in: Self.losAngelesZone))
        let viewModel = Self.makeViewModel(clock: clock, moonService: AstronomyEngineMoonService())
        let sep23 = DateComponents(year: 2026, month: 9, day: 23)

        viewModel.select(Self.marVista)
        viewModel.select(day: sep23)
        let marVista = try #require(viewModel.moonTable?.moonDay)
        try Self.expectNear(try #require(marVista.rise).date, try Self.date(2026, 9, 23, hour: 17, minute: 19, in: Self.losAngelesZone))
        try Self.expectNear(try #require(marVista.set).date, try Self.date(2026, 9, 23, hour: 3, minute: 37, in: Self.losAngelesZone))

        viewModel.select(Self.sydney)
        #expect(viewModel.daySelection == .day(year: 2026, month: 9, day: 23))
        let sydney = try #require(viewModel.moonTable?.moonDay)
        try Self.expectNear(try #require(sydney.rise).date, try Self.date(2026, 9, 23, hour: 14, minute: 24, in: Self.sydneyZone))
        try Self.expectNear(try #require(sydney.set).date, try Self.date(2026, 9, 23, hour: 3, minute: 41, in: Self.sydneyZone))
    }

    // MARK: - Helpers

    private static func date(
        _ year: Int, _ month: Int, _ day: Int,
        hour: Int, minute: Int = 0,
        in timeZone: TimeZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }

    private static func expectNear(
        _ actual: Date,
        _ expected: Date,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #expect(
            abs(actual.timeIntervalSince(expected)) <= timeToleranceSeconds,
            "\(actual) is more than 2 minutes from \(expected)",
            sourceLocation: sourceLocation
        )
    }
}
