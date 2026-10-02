//
//  CompassTargetLabelsTests.swift
//  moonbeam-appTests
//

import Testing
@testable import moonbeam_app

/// The labels outside the arc (COMPASS-1.1.md §5, §8): text, the locked
/// target dropping its label, and the collision rule.
@Suite("Compass target labels")
nonisolated struct CompassTargetLabelsTests {

    private static let rise = CompassTarget(kind: .moonrise, azimuth: 72)
    private static let set = CompassTarget(kind: .moonset, azimuth: 288)

    private static func moon(at azimuth: Double) -> CompassTarget {
        CompassTarget(kind: .moon, azimuth: azimuth)
    }

    @Test("Apart and unlocked: every target is labelled")
    func allLabelled() {
        let labels = CompassTargetLabels.labels(for: [Self.rise, Self.set, Self.moon(at: 140)], lockedKind: nil)

        #expect(labels == [.moonrise: "↑ Rise", .moonset: "↓ Set", .moon: "Now"])
    }

    @Test("The locked target drops its label", arguments: [CompassTarget.Kind.moonrise, .moonset, .moon])
    func lockedDropsLabel(kind: CompassTarget.Kind) {
        let labels = CompassTargetLabels.labels(for: [Self.rise, Self.set, Self.moon(at: 140)], lockedKind: kind)

        #expect(labels[kind] == nil)
        #expect(labels.count == 2)
    }

    @Test("Within the threshold, Now keeps its label", arguments: [275.0, 300.0, 288.0])
    func nowWinsCollision(moonAzimuth: Double) {
        let labels = CompassTargetLabels.labels(for: [Self.rise, Self.set, Self.moon(at: moonAzimuth)], lockedKind: nil)

        #expect(labels[.moon] == "Now")
        #expect(labels[.moonset] == nil)
        #expect(labels[.moonrise] == "↑ Rise")
    }

    @Test("Just past the threshold, both keep their labels")
    func noCollisionPastThreshold() {
        let moon = Self.moon(at: Self.set.azimuth - CompassTargetLabels.collisionDegrees)
        let labels = CompassTargetLabels.labels(for: [Self.set, moon], lockedKind: nil)

        #expect(labels.count == 2)
    }

    @Test("Collisions count across north")
    func collisionAcrossNorth() {
        let rise = CompassTarget(kind: .moonrise, azimuth: 355)
        let labels = CompassTargetLabels.labels(for: [rise, Self.moon(at: 5)], lockedKind: nil)

        #expect(labels == [.moon: "Now"])
    }

    @Test("A locked Now frees its neighbour's label")
    func lockedNowFreesNeighbour() {
        let labels = CompassTargetLabels.labels(for: [Self.set, Self.moon(at: 280)], lockedKind: .moon)

        #expect(labels == [.moonset: "↓ Set"])
    }
}
