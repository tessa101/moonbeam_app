//
//  IllustrationSpec.swift
//  moonbeam-app
//

import CoreGraphics
import SwiftUI

/// One failure illustration as layers (STEP-5.10a, Chunk 4): its slices
/// in z-order, from `Illustrations.xcassets` (cut by
/// `scripts/slice_illustrations.py`), and the pivot of every part that
/// rotates or scales, from `design/1.6-location-error-illustrations/
/// ILLUSTRATIONS_MOTION.md`. Chunk 5 adds the keyframes here too, so no
/// motion number lives in a view.
///
/// Every slice shares the art's 400 × 520 canvas, so stacking them with no
/// offsets redraws the whole illustration.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct IllustrationSpec: Equatable, Sendable {

    /// An animated part, by the art's `data-part` name.
    enum Part: String, Equatable, Hashable, Sendable {
        case moonHalo = "moon-halo"
        case moonDisc = "moon-disc"
        case moonRing = "moon-ring"
        case head
        case tail
        case question
        case tube
        case map
        case route
        case lock
    }

    /// One slice and the parts it moves with, outermost first: the route
    /// moves with the map, then on its own. Empty for a static run.
    struct Layer: Equatable, Sendable {
        let asset: String
        let parts: [Part]

        init(_ asset: String, moves parts: [Part] = []) {
            self.asset = asset
            self.parts = parts
        }
    }

    /// Bottom to top.
    let layers: [Layer]

    /// Pivots in the art's viewBox (0–400 × 0–520), as the motion doc gives
    /// them. The map's float and the route's glow need none.
    let pivots: [Part: CGPoint]

    // MARK: - Canvas

    /// The art's viewBox, shared by every state and slice.
    static let viewBox = CGSize(width: 400, height: 520)

    /// A viewBox point as a unit point of the drawn frame, for
    /// `rotationEffect` / `scaleEffect` anchors.
    static func unitPoint(_ point: CGPoint) -> UnitPoint {
        UnitPoint(x: point.x / viewBox.width, y: point.y / viewBox.height)
    }

    /// `part`'s anchor, if it has a pivot.
    func anchor(for part: Part) -> UnitPoint? {
        pivots[part].map(Self.unitPoint)
    }

    // MARK: - States

    /// The moon's centre on the permission, services and restricted art:
    /// the halo and disc breathe around it.
    private static let crescentMoonCentre = CGPoint(x: 150, y: 212)
    /// Not found's empty moon: the ring turns around it.
    private static let emptyMoonCentre = CGPoint(x: 173, y: 202)

    static func spec(for kind: LocationIllustration.Kind) -> IllustrationSpec {
        switch kind {
        case .locationNotFound: locationNotFound
        case .permissionOff: permissionOff
        case .servicesOff: servicesOff
        case .restricted: restricted
        }
    }

    /// "Huh?": no halo; the ring turns, the head tilts, the question pops.
    static let locationNotFound = IllustrationSpec(
        layers: [
            Layer("locNotFound_moonDisc", moves: [.moonDisc]),
            Layer("locNotFound_moonRing", moves: [.moonRing]),
            Layer("locNotFound_tail", moves: [.tail]),
            Layer("locNotFound_body"),
            Layer("locNotFound_head", moves: [.head]),
            Layer("locNotFound_question", moves: [.question]),
        ],
        pivots: [
            .moonDisc: emptyMoonCentre,
            .moonRing: emptyMoonCentre,
            .head: CGPoint(x: 170, y: 280),
            .question: CGPoint(x: 255, y: 193),
            .tail: CGPoint(x: 230, y: 455),
        ]
    )

    /// "Almost a star": the telescope tilts on its mount; the stand stays.
    static let permissionOff = IllustrationSpec(
        layers: [
            Layer("permissionOff_moonHalo", moves: [.moonHalo]),
            Layer("permissionOff_moonDisc", moves: [.moonDisc]),
            Layer("permissionOff_stand"),
            Layer("permissionOff_tube", moves: [.tube]),
        ],
        pivots: [
            .moonHalo: crescentMoonCentre,
            .moonDisc: crescentMoonCentre,
            .tube: CGPoint(x: 155, y: 335),
        ]
    )

    /// "Fading trail": the map floats; the route's waypoints glow.
    static let servicesOff = IllustrationSpec(
        layers: [
            Layer("servicesOff_moonHalo", moves: [.moonHalo]),
            Layer("servicesOff_moonDisc", moves: [.moonDisc]),
            Layer("servicesOff_map", moves: [.map]),
            Layer("servicesOff_route", moves: [.map, .route]),
        ],
        pivots: [
            .moonHalo: crescentMoonCentre,
            .moonDisc: crescentMoonCentre,
        ]
    )

    /// "Bump": the spark stops at the lock, which shakes on its shackle.
    static let restricted = IllustrationSpec(
        layers: [
            Layer("restricted_moonHalo", moves: [.moonHalo]),
            Layer("restricted_moonDisc", moves: [.moonDisc]),
            Layer("restricted_map", moves: [.map]),
            Layer("restricted_route", moves: [.map, .route]),
            Layer("restricted_lock", moves: [.map, .lock]),
        ],
        pivots: [
            .moonHalo: crescentMoonCentre,
            .moonDisc: crescentMoonCentre,
            .lock: CGPoint(x: 175, y: 298),
        ]
    )
}
