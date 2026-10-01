//
//  MadlibScaleTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
@testable import moonbeam_app

/// The madlib's shared scale (DESIGN-1.1.md §3.1a): at the default size,
/// every line at the smallest scale any line needs, between 0.7 and 1; at
/// every other size, full size.
@Suite("Madlib scale")
nonisolated struct MadlibScaleTests {

    private static let minimum: CGFloat = 0.7
    private static let available: CGFloat = 354

    private static func scale(_ widths: [CGFloat], size: DynamicTypeSize = .large) -> CGFloat {
        MadlibScale.shared(
            naturalWidths: widths,
            availableWidth: available,
            minimum: minimum,
            dynamicTypeSize: size
        )
    }

    // MARK: - Default size

    @Test("Everything fits: full size")
    func allFit() {
        #expect(Self.scale([300, 200, 250]) == 1)
    }

    /// e.g. "in 📍 Rancho Santa Margarita, CA?": all three lines take its
    /// scale, so no line reads smaller than the others.
    @Test("One line too wide: all lines take its scale")
    func oneLineSets() {
        let scale = Self.scale([300, 180, 420])
        #expect(abs(scale - 354.0 / 420.0) < 0.0001)
    }

    @Test("The smallest need wins")
    func smallestWins() {
        let scale = Self.scale([372, 180, 420])
        #expect(abs(scale - 354.0 / 420.0) < 0.0001)
    }

    @Test("Exactly at the minimum still fits")
    func atMinimum() {
        #expect(abs(Self.scale([354 / 0.7, 100]) - 0.7) < 0.0001)
    }

    /// Below 0.7 the sentence stops shrinking; that line wraps at 0.7 and
    /// the others stay at 0.7 with it.
    @Test("A line that needs less than 0.7 holds everything at 0.7")
    func clampsAtMinimum() {
        #expect(abs(Self.scale([700, 180, 250]) - 0.7) < 0.0001)
    }

    @Test("Before anything is measured: full size")
    func unmeasured() {
        #expect(Self.scale([]) == 1)
        let unsized = MadlibScale.shared(
            naturalWidths: [400], availableWidth: 0, minimum: Self.minimum, dynamicTypeSize: .large
        )
        #expect(unsized == 1)
    }

    // MARK: - Other sizes

    @Test("Only the default size shrinks")
    func onlyLargeShrinks() {
        #expect(MadlibScale.shrinks(at: .large))
        for size in DynamicTypeSize.allCases where size != .large {
            #expect(!MadlibScale.shrinks(at: size))
        }
    }

    @Test("Any other size stays full size, so long lines wrap", arguments: [
        DynamicTypeSize.xSmall, .medium, .xLarge, .xxxLarge, .accessibility1, .accessibility3, .accessibility5,
    ])
    func otherSizesDontShrink(size: DynamicTypeSize) {
        #expect(Self.scale([420, 180, 700], size: size) == 1)
    }
}
