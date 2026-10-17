//
//  MadlibFillScaleTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
@testable import moonbeam_app

/// The `noCity` headline's scale (ONBOARDING-MOD-MAIN.md): the shared madlib
/// scale grown to fill the width or the height budget, whichever binds
/// first, up to the maximum; never grown at accessibility sizes.
@Suite("Madlib fill scale")
nonisolated struct MadlibFillScaleTests {

    private static let minimum: CGFloat = 0.7
    private static let maximum: CGFloat = 2.5
    private static let available: CGFloat = 354

    private static func scale(
        _ widths: [CGFloat],
        height: CGFloat = 100,
        availableHeight: CGFloat = 600,
        size: DynamicTypeSize = .large
    ) -> CGFloat {
        MadlibScale.filling(
            naturalWidths: widths,
            naturalHeight: height,
            availableWidth: available,
            availableHeight: availableHeight,
            minimum: minimum,
            maximum: maximum,
            dynamicTypeSize: size
        )
    }

    @Test("Short lines grow until the widest fills the width")
    func growsToWidth() {
        let scale = Self.scale([200, 160, 177])
        #expect(abs(scale - 354.0 / 200.0) < 0.0001)
    }

    @Test("A short height budget binds before the width")
    func heightBinds() {
        let scale = Self.scale([200, 160, 177], height: 100, availableHeight: 150)
        #expect(abs(scale - 1.5) < 0.0001)
    }

    @Test("Growth stops at the maximum")
    func cappedAtMaximum() {
        #expect(Self.scale([60, 50, 40], height: 30, availableHeight: 2000) == Self.maximum)
    }

    @Test("Too wide at full size: the shared scale, as on the resolved screen")
    func tooWideFallsBackToShared() {
        let widths: [CGFloat] = [300, 180, 420]
        let shared = MadlibScale.shared(
            naturalWidths: widths,
            availableWidth: Self.available,
            minimum: Self.minimum,
            dynamicTypeSize: .large
        )
        #expect(Self.scale(widths) == shared)
    }

    @Test("Larger non-accessibility sizes still grow when the lines fit", arguments: [
        DynamicTypeSize.xLarge, .xxLarge, .xxxLarge,
    ])
    func largerSizesGrow(size: DynamicTypeSize) {
        #expect(Self.scale([200, 160, 177], size: size) > 1)
    }

    @Test("Accessibility sizes never grow", arguments: [
        DynamicTypeSize.accessibility1, .accessibility3, .accessibility5,
    ])
    func accessibilitySizesDontGrow(size: DynamicTypeSize) {
        #expect(Self.scale([200, 160, 177], size: size) == 1)
    }

    @Test("Nothing measured yet: the shared scale")
    func unmeasured() {
        #expect(Self.scale([], height: 0) == 1)
        #expect(Self.scale([200, 160, 177], availableHeight: 0) == 1)
    }
}
