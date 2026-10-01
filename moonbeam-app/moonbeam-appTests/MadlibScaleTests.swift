//
//  MadlibScaleTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// The madlib's shared scale (DESIGN-1.1.md §3.1a): every line at the
/// smallest scale any line needs, between 0.8 and 1.
@Suite("Madlib scale")
nonisolated struct MadlibScaleTests {

    private static let minimum: CGFloat = 0.8
    private static let available: CGFloat = 354

    private static func scale(_ widths: [CGFloat]) -> CGFloat {
        MadlibScale.shared(naturalWidths: widths, availableWidth: available, minimum: minimum)
    }

    @Test("Everything fits: full size")
    func allFit() {
        #expect(Self.scale([300, 200, 250]) == 1)
    }

    /// The 5.3 case: line 1 slightly too wide on a 402 pt phone. All three
    /// lines take its scale, so line 1 no longer reads smaller.
    @Test("One line slightly too wide: all lines take its scale")
    func oneLineSets() {
        let scale = Self.scale([372, 180, 250])
        #expect(abs(scale - 354.0 / 372.0) < 0.0001)
    }

    @Test("The smallest need wins")
    func smallestWins() {
        let scale = Self.scale([372, 180, 420])
        #expect(abs(scale - 354.0 / 420.0) < 0.0001)
    }

    /// A line that can't fit even at 0.8 wraps, so it doesn't drag the
    /// others down to 0.8.
    @Test("A line that must wrap anyway doesn't set the scale")
    func wrappingLineIgnored() {
        let scale = Self.scale([600, 180, 372])
        #expect(abs(scale - 354.0 / 372.0) < 0.0001)
        #expect(Self.scale([600, 180, 250]) == 1)
    }

    @Test("Exactly at the minimum still counts")
    func atMinimum() {
        #expect(abs(Self.scale([354 / 0.8, 100]) - 0.8) < 0.0001)
    }

    @Test("Before anything is measured: full size")
    func unmeasured() {
        #expect(Self.scale([]) == 1)
        #expect(MadlibScale.shared(naturalWidths: [400], availableWidth: 0, minimum: Self.minimum) == 1)
    }
}
