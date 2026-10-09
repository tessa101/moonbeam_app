//
//  MoonCardHeightTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
@testable import moonbeam_app

/// COMPASS-1.1.md §9.14: the moon card is the same height with the moon up
/// (three columns, or the AX pill fallback) as down, so nothing below it
/// moves when the moon rises or sets. Rendered for real with `ImageRenderer`
/// at the card's width on the iPhone 17 and the SE 3.
@Suite("Moon card height")
@MainActor
struct MoonCardHeightTests {

    // MARK: - Fixtures

    /// The card's width: the screen less the 20 pt margins.
    nonisolated private static let iPhone17CardWidth: CGFloat = 362
    nonisolated private static let se3CardWidth: CGFloat = 335

    private static let zone = Place.irvine.timeZone

    private static func time(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))
            ?? Date(timeIntervalSince1970: 0)
    }

    /// The design's sky (as `MoonCard`'s previews): Irvine, detected, 7:53 AM
    /// on Fri, Oct 2; moonrise 11:10 PM, moonset 1:28 PM; the moon at 266°.
    private static func makeViewModel(isMoonUp: Bool) -> LocationViewModel {
        let now = time(2, 7, 53)
        let here = Place(
            name: "Irvine",
            region: "CA",
            latitude: Place.irvine.latitude,
            longitude: Place.irvine.longitude,
            timeZone: zone,
            isCurrentLocation: true
        )
        let moon = FakeMoonService(
            rise: MoonEvent(date: time(2, 23, 10), azimuth: 57),
            set: MoonEvent(date: time(2, 13, 28), azimuth: 304),
            phaseAngle: 270,
            illumination: 0.53,
            position: MoonPosition(azimuth: 266, isUp: isMoonUp),
            pass: MoonPass(
                rise: MoonEvent(date: time(1, 22, 6), azimuth: 56),
                set: MoonEvent(date: time(2, 13, 28), azimuth: 304),
                path: [56, 304]
            )
        )
        moon.nextRise = MoonEvent(date: now.addingTimeInterval(34 * 60), azimuth: 57)
        let viewModel = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: moon,
            headingService: FakeHeadingService(),
            deviceTimeZone: zone,
            now: { now }
        )
        viewModel.select(here)
        return viewModel
    }

    private static func cardHeight(isMoonUp: Bool, width: CGFloat, size: DynamicTypeSize) throws -> CGFloat {
        try render(makeViewModel(isMoonUp: isMoonUp), width: width, size: size)
    }

    private static func render(_ viewModel: LocationViewModel, width: CGFloat, size: DynamicTypeSize) throws -> CGFloat {
        let table = try #require(viewModel.moonTable)
        let renderer = ImageRenderer(
            content: MoonCard(viewModel: viewModel, table: table)
                .environment(\.dynamicTypeSize, size)
                .frame(width: width)
        )
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        let image = try #require(renderer.uiImage)
        return image.size.height
    }

    /// Irvine, detected, at 7:53 AM on `day` (Oct 2026), on the real engine.
    private static func realEngineViewModel(day: Int) -> LocationViewModel {
        let now = time(day, 7, 53)
        let here = Place(
            name: "Irvine",
            region: "CA",
            latitude: Place.irvine.latitude,
            longitude: Place.irvine.longitude,
            timeZone: zone,
            isCurrentLocation: true
        )
        let viewModel = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            deviceTimeZone: zone,
            now: { now }
        )
        viewModel.select(here)
        return viewModel
    }

    private static func realEngineCardHeight(day: Int, width: CGFloat) throws -> CGFloat {
        let viewModel = realEngineViewModel(day: day)
        return try render(viewModel, width: width, size: .large)
    }

    // MARK: - Tests

    @Test("Up and down render the same card height", arguments: [
        (iPhone17CardWidth, DynamicTypeSize.large),
        (se3CardWidth, .large),
        (iPhone17CardWidth, .accessibility1),
        (se3CardWidth, .accessibility5),
    ])
    func upEqualsDown(width: CGFloat, size: DynamicTypeSize) throws {
        let up = try Self.cardHeight(isMoonUp: true, width: width, size: size)
        let down = try Self.cardHeight(isMoonUp: false, width: width, size: size)

        #expect(up == down)
    }

    /// COMPASS-1.1.md §9.16 (5.4.8): "After midnight" at its own size fits
    /// one line and leaves the other columns at full size, so the no-rise
    /// day's card is no taller (nor shorter) than the day before's. Real
    /// engine, Irvine at 7:53 AM, moon up both days.
    @Test("The no-rise day renders the same card height as a normal day", arguments: [
        iPhone17CardWidth,
        se3CardWidth,
    ])
    func noRiseDayKeepsHeight(width: CGFloat) throws {
        let normal = try Self.realEngineCardHeight(day: 2, width: width)
        let noRise = try Self.realEngineCardHeight(day: 3, width: width)

        #expect(noRise == normal)
    }

    /// COMPASS-1.1.md §9.16 item 2: exercise the real card layout across the
    /// full 30-days-either-side stepping range, including Oct 3 and Oct 25 →
    /// 26. A fixed card height keeps the header buttons and everything below
    /// the card on the same y coordinates; each button's hit frame is a fixed
    /// 44 points in `DayStepButtonStyle`.
    @Test("Sixty-one stepped days keep the rendered card layout fixed", arguments: [
        iPhone17CardWidth,
        se3CardWidth,
    ])
    func dayStepsKeepLayoutFixed(width: CGFloat) throws {
        let viewModel = Self.realEngineViewModel(day: 3)
        for _ in 0..<30 {
            viewModel.previousDay()
        }

        var heights: [CGFloat] = []
        for offset in -30...30 {
            heights.append(try Self.render(viewModel, width: width, size: .large))
            if offset < 30 {
                viewModel.nextDay()
            }
        }

        let expected = try #require(heights.first)
        #expect(heights.allSatisfy { abs($0 - expected) < 0.01 })
    }

    @Test("Sat, Oct 3 really has no moonrise and the moon up; Fri, Oct 2 has both")
    func realEngineFixture() throws {
        let noRise = try #require(Self.realEngineViewModel(day: 3).moonTable)
        let normal = try #require(Self.realEngineViewModel(day: 2).moonTable)

        guard case .missing = noRise.rise.detail else {
            Issue.record("Expected no moonrise on Sat, Oct 3")
            return
        }
        guard case .time = normal.rise.detail else {
            Issue.record("Expected a moonrise on Fri, Oct 2")
            return
        }
        #expect(Self.realEngineViewModel(day: 3).compass.upNow?.isUp == true)
        #expect(Self.realEngineViewModel(day: 2).compass.upNow?.isUp == true)
    }

    @Test("The setup really is up vs down, today with the compass")
    func fixtureStates() {
        #expect(Self.makeViewModel(isMoonUp: true).compass.upNow?.isUp == true)
        #expect(Self.makeViewModel(isMoonUp: false).compass.upNow?.isUp == false)
    }
}
