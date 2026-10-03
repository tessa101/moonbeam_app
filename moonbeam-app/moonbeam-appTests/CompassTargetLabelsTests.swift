//
//  CompassTargetLabelsTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
@testable import moonbeam_app

/// The labels outside the arc (COMPASS-1.1.md §5, §8, §9.9): text, the
/// locked target dropping its label, the collision rule, and an even gap to
/// the mark at every angle.
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

    // MARK: - Placement (§9.3, §9.9)

    /// "↑ Rise" at 12 pt bold, about; a tall-and-narrow and a wide label too.
    private static let labelSizes = [CGSize(width: 38, height: 16), CGSize(width: 28, height: 16), CGSize(width: 60, height: 30)]
    private static let trackRadius: CGFloat = 146
    private static let dotRadius: CGFloat = 7
    private static let gapTolerance: CGFloat = 1

    @Test(
        "The label's gap to its mark is the same at every angle",
        arguments: [0.0, 45, 90, 135, 180, 225, 270, 315], [0, 1, 2]
    )
    func evenGap(angle: Double, sizeIndex: Int) {
        let size = Self.labelSizes[sizeIndex]
        let distance = CompassTargetLabels.centreDistance(
            trackRadius: Self.trackRadius,
            markRadius: Self.dotRadius,
            labelSize: size,
            angle: angle
        )

        let gap = CompassTargetLabels.gap(from: distance - Self.trackRadius, labelSize: size, angle: angle)
            - Self.dotRadius

        #expect(abs(gap - CompassTargetLabels.labelGap) <= Self.gapTolerance)
    }

    /// At 3 o'clock a wide label sits further out than at 12, where its
    /// height, not its width, faces the mark (5.4.4's one radius didn't).
    @Test("Wide labels sit further out at the sides than at the top")
    func sidesFurtherOut() {
        let size = Self.labelSizes[0]
        let top = CompassTargetLabels.centreDistance(trackRadius: Self.trackRadius, markRadius: Self.dotRadius, labelSize: size, angle: 0)
        let side = CompassTargetLabels.centreDistance(trackRadius: Self.trackRadius, markRadius: Self.dotRadius, labelSize: size, angle: 90)

        let expectedTop = Self.trackRadius + Self.dotRadius + CompassTargetLabels.labelGap + size.height / 2
        #expect(abs(top - expectedTop) < Self.gapTolerance)
        #expect(side > top)
    }
}
