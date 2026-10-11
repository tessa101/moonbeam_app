//
//  IllustrationSpecTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import SwiftUI
import Testing
@testable import moonbeam_app

/// STEP-5.10a, Chunk 4: each failure illustration's layers and pivots, as
/// ILLUSTRATIONS_MOTION.md gives them.
@Suite("Illustration spec")
struct IllustrationSpecTests {

    @Test("A viewBox pivot becomes a unit point of the frame")
    func pivotConversion() {
        #expect(IllustrationSpec.unitPoint(CGPoint(x: 0, y: 0)) == .topLeading)
        #expect(IllustrationSpec.unitPoint(CGPoint(x: 400, y: 520)) == .bottomTrailing)
        #expect(IllustrationSpec.unitPoint(CGPoint(x: 200, y: 260)) == .center)
        let lock = IllustrationSpec.restricted.anchor(for: .lock)
        #expect(lock == UnitPoint(x: 175.0 / 400, y: 298.0 / 520))
    }

    @Test("The motion doc's pivots, in viewBox coordinates")
    func pivots() {
        #expect(IllustrationSpec.locationNotFound.pivots[.head] == CGPoint(x: 170, y: 280))
        #expect(IllustrationSpec.locationNotFound.pivots[.question] == CGPoint(x: 255, y: 193))
        #expect(IllustrationSpec.locationNotFound.pivots[.tail] == CGPoint(x: 230, y: 455))
        #expect(IllustrationSpec.locationNotFound.pivots[.moonRing] == CGPoint(x: 173, y: 202))
        #expect(IllustrationSpec.permissionOff.pivots[.tube] == CGPoint(x: 155, y: 335))
        // Chunk 2b: the crescent moon is mirrored about x 200 (was 150, 212),
        // and the permission-off star with it (was 272, 122).
        for spec in [IllustrationSpec.permissionOff, .servicesOff, .restricted] {
            #expect(spec.pivots[.moonHalo] == CGPoint(x: 250, y: 212))
            #expect(spec.pivots[.moonDisc] == CGPoint(x: 250, y: 212))
        }
        #expect(IllustrationSpec.permissionOff.star?.centre == CGPoint(x: 128, y: 122))
    }

    @Test("Every part that rotates or scales has a pivot", arguments: LocationIllustration.Kind.allCases)
    func everyTurningPartHasAPivot(kind: LocationIllustration.Kind) {
        let spec = kind.spec
        // The map floats; the route and waypoints only change opacity.
        let pivotless: Set<IllustrationSpec.Part> = [
            .map, .route, .waypoint1, .waypoint2, .waypoint3,
        ]
        for layer in spec.layers {
            for part in layer.parts where !pivotless.contains(part) {
                #expect(spec.anchor(for: part) != nil, "\(layer.asset): \(part)")
            }
        }
    }

    @Test("Layers in the art's z-order, as sliced")
    func layerOrder() {
        #expect(IllustrationSpec.locationNotFound.layers.map(\.asset) == [
            "locNotFound_moonDisc", "locNotFound_moonRing", "locNotFound_tail",
            "locNotFound_body", "locNotFound_head", "locNotFound_question",
        ])
        #expect(IllustrationSpec.permissionOff.layers.map(\.asset) == [
            "permissionOff_moonHalo", "permissionOff_moonDisc", "permissionOff_stand", "permissionOff_tube",
        ])
        #expect(IllustrationSpec.servicesOff.layers.map(\.asset) == [
            "servicesOff_moonHalo", "servicesOff_moonDisc", "servicesOff_map", "servicesOff_route",
            "servicesOff_waypoint1", "servicesOff_waypoint2", "servicesOff_waypoint3",
        ])
        #expect(IllustrationSpec.restricted.layers.map(\.asset) == [
            "restricted_moonHalo", "restricted_moonDisc", "restricted_map", "restricted_route",
            "restricted_waypoint1", "restricted_waypoint2", "restricted_waypoint3", "restricted_lock",
        ])
    }

    @Test("Nested parts move with their parent: the route and lock with the map")
    func nestedParts() {
        let restricted = IllustrationSpec.restricted.layers
        #expect(restricted.first { $0.asset == "restricted_route" }?.parts == [.map, .route])
        #expect(restricted.first { $0.asset == "restricted_lock" }?.parts == [.map, .lock])
        #expect(IllustrationSpec.permissionOff.layers.first { $0.asset == "permissionOff_stand" }?.parts == [])
    }
}
