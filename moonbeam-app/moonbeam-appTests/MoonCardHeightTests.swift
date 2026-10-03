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
        let viewModel = makeViewModel(isMoonUp: isMoonUp)
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

    @Test("The setup really is up vs down, today with the compass")
    func fixtureStates() {
        #expect(Self.makeViewModel(isMoonUp: true).compass.upNow?.isUp == true)
        #expect(Self.makeViewModel(isMoonUp: false).compass.upNow?.isUp == false)
    }
}
