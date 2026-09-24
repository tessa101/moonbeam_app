//
//  CompassFormatterTests.swift
//  moonbeam-appTests
//

import Testing
@testable import moonbeam_app

/// Covers the 16-point compass convention in ASTRONOMY.md §3, with the
/// emphasis on sector edges, where an off-by-half-a-sector bug would hide.
@Suite("CompassFormatter")
nonisolated struct CompassFormatterTests {

    private let formatter = CompassFormatter()

    // MARK: - Sector centres

    /// Each sector is centred on its heading, so the exact cardinal and
    /// intercardinal bearings must land mid-sector.
    @Test("Headings map to their own sector", arguments: [
        (0.0, "N"), (22.5, "NNE"), (45.0, "NE"), (67.5, "ENE"),
        (90.0, "E"), (112.5, "ESE"), (135.0, "SE"), (157.5, "SSE"),
        (180.0, "S"), (202.5, "SSW"), (225.0, "SW"), (247.5, "WSW"),
        (270.0, "W"), (292.5, "WNW"), (315.0, "NW"), (337.5, "NNW")
    ])
    func headingMapsToOwnSector(azimuth: Double, expected: String) {
        #expect(formatter.abbreviation(for: azimuth) == expected)
    }

    // MARK: - Sector edges

    /// N spans 348.75°–11.25°. The boundary belongs to the *next* sector, so
    /// 11.24° is still N while 11.25° has become NNE.
    @Test("Boundaries fall into the next sector", arguments: [
        (11.24, "N"),
        (11.25, "NNE"),
        (33.74, "NNE"),
        (33.75, "NE"),
        (101.24, "E"),
        (101.25, "ESE"),
        (123.74, "ESE"),
        (123.75, "SE"),
        (348.74, "NNW"),
        (348.75, "N")
    ])
    func boundaryFallsIntoNextSector(azimuth: Double, expected: String) {
        #expect(formatter.abbreviation(for: azimuth) == expected)
    }

    /// 348.75° is the start of N's sector and must wrap to N, not NNW.
    @Test("North wraps across zero")
    func northWrapsAcrossZero() {
        #expect(formatter.abbreviation(for: 348.75) == "N")
        #expect(formatter.abbreviation(for: 359.9) == "N")
        #expect(formatter.abbreviation(for: 0.0) == "N")
        #expect(formatter.abbreviation(for: 11.24) == "N")
    }

    // MARK: - Wraparound

    @Test("Out-of-range azimuths wrap", arguments: [
        (360.0, "N"),
        (371.25, "NNE"),
        (405.0, "NE"),
        (465.0, "ESE"),
        (-11.25, "N"),
        (-22.5, "NNW"),
        (-90.0, "W")
    ])
    func outOfRangeAzimuthWraps(azimuth: Double, expected: String) {
        #expect(formatter.abbreviation(for: azimuth) == expected)
    }

    /// Every sector is exactly `compassSectorWidth` wide, so stepping a full
    /// turn must visit all 16 abbreviations and return to N.
    @Test("A full turn visits 16 distinct sectors")
    func fullTurnVisitsAllSectors() {
        let width = CompassFormatter.compassSectorWidth
        let sectorCount = 16
        let visited = (0..<sectorCount).map { index in
            formatter.abbreviation(for: Double(index) * width)
        }

        #expect(Set(visited).count == sectorCount)
        #expect(visited.first == "N")
        #expect(formatter.abbreviation(for: Double(sectorCount) * width) == "N")
    }

    // MARK: - Accessibility

    /// NFR4 requires VoiceOver to read "east-southeast", not "ESE".
    @Test("Spoken names are spelled out", arguments: [
        (0.0, "north"),
        (105.0, "east-southeast"),
        (252.0, "west-southwest"),
        (337.5, "north-northwest")
    ])
    func spokenNameIsSpelledOut(azimuth: Double, expected: String) {
        #expect(formatter.spokenName(for: azimuth) == expected)
    }

    /// The reference row's azimuths, as they appear in the moon table.
    @Test("Reference azimuths render as documented")
    func referenceAzimuths() {
        #expect(formatter.abbreviation(for: 105.0) == "ESE")
        #expect(formatter.abbreviation(for: 252.0) == "WSW")
    }
}
