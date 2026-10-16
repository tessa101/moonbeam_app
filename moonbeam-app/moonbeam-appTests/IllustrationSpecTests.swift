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

    @Test("Permission off draws 1k ready to look, not the telescope")
    func permissionOffIsReadyToLook() {
        #expect(LocationIllustration.Kind.permissionOff.spec == IllustrationSpec.readyToLook)
    }

    @Test("The motion doc's pivots, in viewBox coordinates")
    func pivots() {
        #expect(IllustrationSpec.locationNotFound.pivots[.head] == CGPoint(x: 170, y: 280))
        #expect(IllustrationSpec.locationNotFound.pivots[.question] == CGPoint(x: 255, y: 193))
        #expect(IllustrationSpec.locationNotFound.pivots[.tail] == CGPoint(x: 230, y: 455))
        #expect(IllustrationSpec.locationNotFound.pivots[.moonRing] == CGPoint(x: 173, y: 202))
        // 1k: the feet, neck, ear base and tail root.
        let readyToLook = IllustrationSpec.readyToLook
        #expect(readyToLook.pivots[.breath] == CGPoint(x: 200, y: 478))
        #expect(readyToLook.pivots[.head] == CGPoint(x: 205, y: 277))
        #expect(readyToLook.pivots[.ear] == CGPoint(x: 163.5, y: 193))
        #expect(readyToLook.pivots[.tail] == CGPoint(x: 97, y: 414.5))
        // Chunk 2b: the crescent moon is mirrored about x 200 (was 150, 212).
        for spec in [IllustrationSpec.servicesOff, .restricted] {
            #expect(spec.pivots[.moonHalo] == CGPoint(x: 250, y: 212))
            #expect(spec.pivots[.moonDisc] == CGPoint(x: 250, y: 212))
        }
        // 1k shares the searching moon; its halo is hidden in the source.
        // The carried-over star moves off the full disc (was 326, 150).
        #expect(readyToLook.pivots[.moonDisc] == CGPoint(x: 215, y: 202))
        #expect(readyToLook.pivots[.moonHalo] == nil)
        #expect(readyToLook.star?.centre == CGPoint(x: 370, y: 118))
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
        #expect(IllustrationSpec.searching.layers.map(\.asset) == [
            "searching_moonHalo", "searching_moonDisc", "searching_tail", "searching_body", "searching_look",
        ])
        #expect(IllustrationSpec.readyToLook.layers.map(\.asset) == [
            "readyToLook_moonDisc", "readyToLook_tail", "readyToLook_body", "readyToLook_head", "readyToLook_ear",
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
    }

    @Test("1k's breath carries the cat, and the ear rides the head")
    func readyToLookNesting() {
        let layers = IllustrationSpec.readyToLook.layers
        #expect(layers.map(\.parts) == [
            [.moonDisc], [.breath, .tail], [.breath], [.breath, .head], [.breath, .head, .ear],
        ])
    }

    @Test("1k's cat rasters share the foreground's rect; the moon fills the canvas")
    func readyToLookPlacement() throws {
        let layers = IllustrationSpec.readyToLook.layers
        #expect(layers[0].placement == nil)
        let rect = try #require(layers[1].placement)
        #expect(layers.dropFirst().allSatisfy { $0.placement == rect })
        // translate(-49 27.73) scale(0.415) of an 800 × 860 image at (215, 250).
        #expect(abs(rect.minX - 40.225) < Self.tolerance)
        #expect(abs(rect.minY - 131.48) < Self.tolerance)
        #expect(abs(rect.width - 332) < Self.tolerance)
        #expect(abs(rect.height - 356.9) < Self.tolerance)
    }

    /// Floating-point slack for derived geometry.
    private static let tolerance = 0.000_001

    @Test("Nested moves compose inside out: the ear turns on the tilted, breathing head")
    func nestedComposition() {
        let spec = IllustrationSpec.readyToLook
        let ear = spec.layers[4]
        // Mid flick, mid lift, mid breath, so all three are off rest.
        let time = 6.24 * 0.66
        let expected = spec.pose(of: .ear, at: time).transform(pivot: spec.pivots[.ear])
            .concatenating(spec.pose(of: .head, at: time).transform(pivot: spec.pivots[.head]))
            .concatenating(spec.pose(of: .breath, at: time).transform(pivot: spec.pivots[.breath]))
        let actual = spec.transform(of: ear, at: time)
        for (a, b) in [(actual.a, expected.a), (actual.b, expected.b), (actual.c, expected.c),
                       (actual.d, expected.d), (actual.tx, expected.tx), (actual.ty, expected.ty)] {
            #expect(abs(a - b) < Self.tolerance)
        }
        // Outer-first order would differ: the order is observable.
        let outerFirst = spec.pose(of: .breath, at: time).transform(pivot: spec.pivots[.breath])
            .concatenating(spec.pose(of: .head, at: time).transform(pivot: spec.pivots[.head]))
            .concatenating(spec.pose(of: .ear, at: time).transform(pivot: spec.pivots[.ear]))
        #expect(abs(actual.tx - outerFirst.tx) > Self.tolerance || abs(actual.ty - outerFirst.ty) > Self.tolerance)
    }

    @Test("The carried-over star clears the moon, the head and the telescope")
    func readyToLookStarClearance() throws {
        let star = try #require(IllustrationSpec.readyToLook.star)
        let starRadius = 11.0
        let moonCentre = CGPoint(x: 215, y: 202)
        let moonRadius = 135.0
        #expect(hypot(star.centre.x - moonCentre.x, star.centre.y - moonCentre.y) > moonRadius + starRadius)
        // The head layer's opaque bounds at rest reach x 262.7; the tube's
        // top edge is at y 216 (measured from the supplied rasters).
        #expect(star.centre.x - starRadius > 262.7)
        #expect(star.centre.y + starRadius < 216)
        #expect(star.centre.x + starRadius < IllustrationSpec.viewBox.width)
    }

    @Test("Landing searching art keeps head and paw still with the calm tail sway")
    func landingSearchingMotion() throws {
        let spec = IllustrationSpec.searching
        #expect(spec.motions[.head] == nil)
        #expect(spec.layers.first { $0.asset == "searching_look" }?.parts == [])
        let tail = try #require(spec.motions[.tail]?.rotation)
        #expect(tail.duration == 4.2)
        #expect(tail.value(at: 4.2 * 0.25) == 4)
        #expect(tail.value(at: 4.2 * 0.75) == -3)
        #expect(spec.motions[.moonHalo] != nil)
    }
}
