//
//  MoonCardCellTests.swift
//  moonbeam-appTests
//

import Testing
@testable import moonbeam_app

/// The lock highlight's mapping (COMPASS-1.1.md §3, §8): which moon card
/// cell is outlined for each lock.
@Suite("Moon card cell")
nonisolated struct MoonCardCellTests {

    @Test("Each lock outlines its own cell", arguments: [
        (CompassTarget.Kind.moonrise, MoonCardCell.moonrise),
        (.moonset, .moonset),
        (.moon, .upNow),
    ])
    func lockOutlinesItsCell(kind: CompassTarget.Kind, cell: MoonCardCell) {
        #expect(MoonCardCell(lockedOn: kind) == cell)
    }

    @Test("No lock, no highlight")
    func noLockNoHighlight() {
        #expect(MoonCardCell(lockedOn: nil) == nil)
    }
}
