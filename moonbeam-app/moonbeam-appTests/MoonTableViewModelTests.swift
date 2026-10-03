//
//  MoonTableViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The moon card's table (DESIGN-1.1.md §3.2): built for the day it's given,
/// bearings read like the compass's, missing events and the zone beside the
/// times. Carries over the spike table's tests (Steps 3 and 4).
@Suite("Moon table view model")
@MainActor
struct MoonTableViewModelTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let sydneyZone = TimeZone(identifier: "Australia/Sydney") ?? .gmt

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

    /// Deliberately far from the real clock, so "uses `Date()`" can't pass by
    /// accident.
    private static func farDay() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        return try #require(calendar.date(from: DateComponents(year: 2020, month: 1, day: 15)))
    }

    private static func makeTable(
        _ service: FakeMoonService,
        place: Place = marVista,
        day: Date
    ) -> MoonTableViewModel {
        MoonTableViewModel(
            moonService: service,
            place: place,
            day: day,
            deviceTimeZone: losAngelesZone,
            formatter: MoonTableFormatter(locale: Locale(identifier: "en_US"))
        )
    }

    // MARK: - Day

    /// `LocationViewModel`'s rollover check compares against `day`, so it
    /// has to be the day the table was built for.
    @Test("The day reaches the moon service and is kept")
    func dayReachesTheService() throws {
        let day = try Self.farDay()
        // A rise and a set, so there's no next-day lookup for "After midnight".
        let service = FakeMoonService(
            rise: MoonEvent(date: day, azimuth: 72),
            set: MoonEvent(date: day, azimuth: 288)
        )

        let table = Self.makeTable(service, day: day)

        #expect(service.requestedDates == [day])
        #expect(table.day == day)
    }

    // MARK: - Rise and set

    /// The table and the compass share `CompassFormatter.bearing(for:)`, so
    /// one azimuth never reads two ways on screen. 359.6° was "360° N" in the
    /// spike table before; 72.5° rounded half-to-even ("72°") there but
    /// half-away ("73°") on the compass.
    @Test("Rise and set bearings match the compass's", arguments: [359.6, 72.5, 105.0, 0.4])
    func bearingMatchesCompass(azimuth: Double) throws {
        let event = MoonEvent(date: try Self.farDay(), azimuth: azimuth)
        let table = Self.makeTable(FakeMoonService(rise: event, set: event), day: try Self.farDay())
        let bearing = CompassFormatter().bearing(for: azimuth)

        #expect(Self.direction(of: table.rise) == bearing)
        #expect(Self.direction(of: table.set) == bearing)
    }

    @Test("A bearing just short of north reads 0° N, not 360° N")
    func nearNorthReadsZero() throws {
        let event = MoonEvent(date: try Self.farDay(), azimuth: 359.6)
        let table = Self.makeTable(FakeMoonService(rise: event), day: try Self.farDay())

        #expect(Self.direction(of: table.rise) == "0° N")
    }

    /// The fake has no rise or set on any day, so the next is more than a
    /// day away: the polar case (COMPASS-1.1.md §9.10).
    @Test("A missing event with none the next day: \"Not today\"")
    func missingEventNotToday() throws {
        let table = Self.makeTable(FakeMoonService(), day: try Self.farDay())

        #expect(table.rise.detail == .missing("Not today", next: nil))
        #expect(table.set.detail == .missing("Not today", next: nil))
        #expect(table.rise.accessibilityLabel == "Moonrise, not today.")
        #expect(table.rise.title == "↑ Moonrise")
        #expect(table.set.title == "↓ Moonset")
    }

    /// No moonrise today, the next just after midnight: "After midnight"
    /// and when, in the place's zone (COMPASS-1.1.md §9.10).
    @Test("A missing event with one the next day: \"After midnight\" and the time")
    func missingEventAfterMidnight() throws {
        let day = try Self.farDay()
        let nextRise = try #require(Calendar.current.date(byAdding: .minute, value: 24 * 60 + 20, to: day))
        let service = NextDayRiseMoonService(day: day, nextRise: MoonEvent(date: nextRise, azimuth: 70))
        let table = MoonTableViewModel(
            moonService: service,
            place: Self.marVista,
            day: day,
            deviceTimeZone: Self.losAngelesZone,
            formatter: MoonTableFormatter(locale: Locale(identifier: "en_US"))
        )

        // 2020-01-16 is a Thursday.
        #expect(table.rise.detail == .missing("After midnight", next: "Thu 12:20\u{202F}AM"))
        #expect(table.rise.accessibilityLabel == "Moonrise, after midnight, Thursday 12:20\u{202F}AM.")
    }

    @Test("A time in the device's own zone has no abbreviation beside it")
    func noZoneAtHome() throws {
        let event = MoonEvent(date: try Self.farDay(), azimuth: 105)
        let table = Self.makeTable(FakeMoonService(rise: event), day: try Self.farDay())

        #expect(table.rise.detail == .time(Self.time("12:00\u{202F}", "AM"), timeZone: nil, direction: "105° ESE"))
        #expect(table.rise.accessibilityLabel == "Moonrise at 12:00\u{202F}AM, east-southeast, 105 degrees")
    }

    @Test("Sydney on an LA device: the zone beside the time and in the spoken label")
    func zoneAway() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.sydneyZone
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 23, minute: 13)))
        let event = MoonEvent(date: date, azimuth: 66)
        let table = Self.makeTable(FakeMoonService(rise: event), place: Self.sydney, day: date)
        let abbreviation = try #require(Self.sydneyZone.abbreviation(for: date))

        #expect(table.rise.detail == .time(Self.time("11:13\u{202F}", "PM"), timeZone: abbreviation, direction: "66° ENE"))
        #expect(table.rise.accessibilityLabel == "Moonrise at 11:13\u{202F}PM Sydney time, \(abbreviation), east-northeast, 66 degrees")
    }

    // MARK: - Phase

    @Test("Phase row text and glyph come from the day's phase")
    func phaseRow() throws {
        let service = FakeMoonService(phaseAngle: 240, illumination: 0.75)
        let table = Self.makeTable(service, day: try Self.farDay())

        #expect(table.phaseName == "Waning Gibbous")
        #expect(table.illuminationText == "75% lit")
        #expect(table.phaseAccessibilityLabel == "Waning Gibbous, 75% lit at midnight")
        #expect(table.glyph == PhaseGlyphGeometry(illumination: 0.75, phaseAngle: 240))
        #expect(table.glyph.litSide == .left)
    }

    // MARK: - Helpers

    private static func direction(of column: MoonTableViewModel.Column) -> String? {
        guard case let .time(_, _, direction) = column.detail else { return nil }
        return direction
    }

    /// A 12-hour `en_US` time: the digits (with their narrow space), then
    /// the day period as its own run.
    private static func time(_ digits: String, _ dayPeriod: String) -> TimeText {
        TimeText(runs: [
            TimeText.Run(text: digits, isDayPeriod: false),
            TimeText.Run(text: dayPeriod, isDayPeriod: true),
        ])
    }
}

/// No moonrise on `day`, one on the day after (`nextRise`); a moonset on both.
private struct NextDayRiseMoonService: MoonService {

    let day: Date
    let nextRise: MoonEvent

    func moonDay(for place: Place, on date: Date) -> MoonDay {
        MoonDay(
            place: place,
            rise: date > day ? nextRise : nil,
            set: MoonEvent(date: date, azimuth: 290),
            phase: .full,
            phaseAngle: FakeMoonService.fullMoonPhaseAngle,
            illumination: FakeMoonService.fullyLit
        )
    }

    func moonPosition(for place: Place, at date: Date) -> MoonPosition {
        MoonPosition(azimuth: 0, isUp: false)
    }

    func moonPass(for place: Place, containing date: Date) -> MoonPass? { nil }

    func nextMoonrise(for place: Place, after date: Date) -> MoonEvent? { nil }
}
