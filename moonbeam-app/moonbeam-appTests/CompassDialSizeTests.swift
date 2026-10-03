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
}
