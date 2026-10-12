//
//  RiseSetLayoutTests.swift
//  moonbeam-appTests
//

import Testing
@testable import moonbeam_app

/// The moon card's rise / set row (COMPASS-1.1.md §9.14): three cells with
/// the moon up, two otherwise, the connector, the reserved height and the
/// AX fallback.
@Suite("Rise / set layout")
nonisolated struct RiseSetLayoutTests {

    // MARK: - Fixtures

    private static let up = UpNow(
        state: .up(bearing: "266° W", altitude: "23° up", pass: nil),
        title: UpNowFormatter.upTitle,
        accessibilityLabel: "Moon up now, west, 266 degrees."
    )

    private static let down = UpNow(
        state: .notUpYet(countdown: "in 34 min"),
        title: UpNowFormatter.notUpYetTitle,
        accessibilityLabel: "Moon not up yet, rising in 34 minutes."
    )

    // MARK: - Cells

    @Test("Moon up: Moonrise, Up now, Moonset in order, with the live bearing")
    func upThreeCells() {
        let layout = RiseSetLayout(upNow: Self.up)

        #expect(layout.cells == [.moonrise, .upNow, .moonset])
        #expect(layout.bearing == "266° W")
        #expect(layout.connector == .travelled)
    }

    @Test("Moon down today: three cells with the dim line")
    func downThreeCells() {
        let layout = RiseSetLayout(upNow: Self.down)

        #expect(layout.cells == [.moonrise, .upNow, .moonset])
        #expect(layout.bearing == "in 34 min")
        #expect(layout.connector == .dim)
        #expect(layout.fallback.showsPillRow)
    }

    @Test("Other date (no Up now): two cells, nothing reserved")
    func otherDateTwoCells() {
        let layout = RiseSetLayout(upNow: nil)

        #expect(layout.cells == [.moonrise, .moonset])
        #expect(layout.connector == .dim)
        #expect(layout.twin == nil)
    }

    // MARK: - Equal height

    @Test("All today's states use the same three-column structure")
    func todayStatesUseThreeColumns() {
        let up = RiseSetLayout(upNow: Self.up)
        let down = RiseSetLayout(upNow: Self.down)

        #expect(up.cells == down.cells)
        #expect(up.twin == nil)
        #expect(down.twin == nil)
    }

    // MARK: - AX fallback

    @Test("Fallback with the moon up: rise and set, then the pill row")
    func fallbackPillRow() {
        let fallback = RiseSetLayout(upNow: Self.up).fallback

        #expect(fallback.cells == [.moonrise, .moonset])
        #expect(fallback.showsPillRow)
    }

    // MARK: - Lock

    @Test("Lock on the Moon outlines the middle cell; rise and set their own", arguments: [
        (CompassTarget.Kind.moon, MoonCardCell.upNow),
        (.moonrise, .moonrise),
        (.moonset, .moonset),
    ])
    func lockOutlinesShownCell(kind: CompassTarget.Kind, cell: MoonCardCell) {
        let layout = RiseSetLayout(upNow: Self.up)
        let highlighted = MoonCardCell(lockedOn: kind)

        #expect(highlighted == cell)
        #expect(highlighted.map(layout.cells.contains) == true)
    }
}
