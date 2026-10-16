//
//  CompassDialSizeTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// The dial's face size from the compass block's width (COMPASS-1.1.md
/// §9.3): as big as the side labels allow, within its bounds.
@Suite("Compass dial size")
@MainActor
struct CompassDialSizeTests {

    @Test("Sized by the width: 402 pt and 375 pt phones less 20 pt margins", arguments: [
        (CGFloat(362), CGFloat(260)),
        (335, 233),
    ])
    func sizedByWidth(width: CGFloat, expected: CGFloat) {
        #expect(CompassDial.faceDiameter(forWidth: width) == expected)
    }

    @Test("Never smaller than the 196 pt dial, never bigger than 300 pt", arguments: [CGFloat(0), 200, 1_000])
    func bounded(width: CGFloat) {
        let diameter = CompassDial.faceDiameter(forWidth: width)

        #expect(diameter >= CompassDial.minFaceDiameter)
        #expect(diameter <= CompassDial.maxFaceDiameter)
    }

    @Test("AX dial keeps its target size despite a tall card, within the side-label width", arguments: [
        (CGFloat(335), CGFloat(233)), (362, 260), (1_000, 260),
    ])
    func accessibilitySize(width: CGFloat, expected: CGFloat) {
        for budget: CGFloat? in [nil, 100, 1_000] {
            #expect(CompassDial.faceDiameter(forWidth: width, dialHeightBudget: budget,
                                            isAccessibilitySize: true) == expected)
        }
    }

    // MARK: - Height (DECISIONS.md 2026-10-14)

    @Test("No height budget: the width alone sizes the dial")
    func noBudget() {
        #expect(CompassDial.faceDiameter(forWidth: 362, dialHeightBudget: nil) == 260)
    }

    @Test("A roomy budget leaves the width's size; a tight one shrinks the dial to fit")
    func budgetShrinksTheDial() {
        #expect(CompassDial.faceDiameter(forWidth: 362, dialHeightBudget: 1_000) == 260)

        // 108 pt of arc and label room beyond the face: 240 + 108 = 348 pt.
        #expect(CompassDial.faceDiameter(forWidth: 362, dialHeightBudget: 348) == 240)
    }

    @Test("The height never takes the dial under 196 pt")
    func budgetFloor() {
        #expect(CompassDial.faceDiameter(forWidth: 362, dialHeightBudget: 100) == CompassDial.minFaceDiameter)
    }

    @Test("The budget is the screen less its bottom padding, less where the compass starts")
    func budget() {
        let budget = CompassDial.heightBudget(viewportHeight: 800, compassTop: 400)

        #expect(budget == 800 * (1 - CompassDial.bottomPaddingFraction) - 400)
    }
}
