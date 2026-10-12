//
//  IllustrationSpec.swift
//  moonbeam-app
//

import CoreGraphics
import SwiftUI

/// One failure illustration as layers and motion (STEP-5.10a, Chunks 4–5):
/// its slices in z-order, from `Illustrations.xcassets` (cut by
/// `scripts/slice_illustrations.py`), the pivot of every part that rotates
/// or scales, and every keyframe, all from `design/1.6-location-error-
/// illustrations/ILLUSTRATIONS_MOTION.md`, "Playful beats" at 0.85× (its
/// numbers are already scaled). No motion number lives in a view.
///
/// Every slice shares the art's 400 × 520 canvas, so stacking them with no
/// offsets redraws the whole illustration.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct IllustrationSpec: Equatable, Sendable {

    /// An animated part, by the art's `data-part` name (waypoints are the
    /// route's circles, numbered in document order).
    enum Part: String, Equatable, Hashable, Sendable {
        case moonHalo = "moon-halo"
        case moonDisc = "moon-disc"
        case moonRing = "moon-ring"
        case head
        case tail
        case question
        case tube
        /// The telescope's lens glint: rides on the tube and flickers.
        case lensGlint = "lens-glint"
        case map
        case route
        case waypoint1 = "waypoint-1"
        case waypoint2 = "waypoint-2"
        case waypoint3 = "waypoint-3"
        case lock

        /// A waypoint's index into the spark's waypoints.
        var waypointIndex: Int? {
            switch self {
            case .waypoint1: 0
            case .waypoint2: 1
            case .waypoint3: 2
            default: nil
            }
        }
    }

    /// One slice and the parts it moves with, outermost first: the route
    /// moves with the map. Empty for a static run.
    struct Layer: Equatable, Sendable {
        let asset: String
        let parts: [Part]

        init(_ asset: String, moves parts: [Part] = []) {
            self.asset = asset
            self.parts = parts
        }
    }

    /// 1h: the 4-point sparkle you add over the telescope.
    struct Star: Equatable, Sendable {
        /// The doc's path, centred on 0, 0.
        static let pathData = "M0 -11 Q1.4 -1.4 11 0 Q1.4 1.4 0 11 Q-1.4 1.4 -11 0 Q-1.4 -1.4 0 -11Z"
        static let colorHex: UInt32 = 0xF7E7BD
        /// Its centre, which is also its pivot.
        let centre: CGPoint
        let motion: IllustrationMotion
    }

    /// Bottom to top.
    let layers: [Layer]

    /// Pivots in the art's viewBox (0–400 × 0–520), as the motion doc gives
    /// them. The map's float and the waypoints' glow need none.
    let pivots: [Part: CGPoint]

    /// Each moving part's loops. The lock and the waypoints follow the
    /// spark instead.
    var motions: [Part: IllustrationMotion] = [:]

    var spark: IllustrationSpark?
    var star: Star?

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

    // MARK: - Poses

    /// `part` at `time` seconds into the motion; `nil` time is the Reduce
    /// Motion still: offset 0, spark hidden, the question mark shown at
    /// scale 1.
    func pose(of part: Part, at time: TimeInterval?) -> IllustrationMotion.Pose {
        guard let time else {
            if part == .question { return .rest }
            return motions[part]?.pose(at: 0) ?? .rest
        }
        if part == .lock, let spark {
            return IllustrationMotion.Pose(rotation: spark.lockAngle(at: time))
        }
        return motions[part]?.pose(at: time) ?? .rest
    }

    /// The spark at `time`; hidden in the still.
    func sparkState(at time: TimeInterval?) -> IllustrationSpark.State? {
        guard let spark, let time else { return nil }
        return spark.state(at: time)
    }

    // MARK: - States

    /// Shared by all states: the halo breathes and the disc brightens on
    /// one 5.88 s loop.
    private static let breathDuration: TimeInterval = 5.88
    private static let haloBreath = IllustrationMotion(
        scale: IllustrationKeyframes(duration: breathDuration, values: [0.95, 1.06, 0.95]),
        opacity: IllustrationKeyframes(duration: breathDuration, values: [0.7, 1, 0.7])
    )
    private static let discBreath = IllustrationMotion(
        brightness: IllustrationKeyframes(duration: breathDuration, values: [1, 1.06, 1])
    )

    /// The moon's centre on the services and restricted art:
    /// the halo and disc breathe around it. Chunk 2b (Tessa, 2026-10-10):
    /// the moon is mirrored about the art's centre line (x 200) so the
    /// crescent is lit on the right, the app's waxing side; was (150, 212).
    private static let crescentMoonCentre = CGPoint(x: 250, y: 212)
    /// The telescope art's own moon (STEP-5.10a telescope redraw, Tessa,
    /// 2026-10-12): redrawn to match the D2 original, lit on the left, so
    /// it doesn't share the mirrored `crescentMoonCentre`.
    private static let telescopeMoonCentre = CGPoint(x: 190, y: 203)
    /// The redrawn mount head's centre: the tube, and the glint riding on
    /// it, tilt about it. Was (155, 335).
    private static let telescopeMountCentre = CGPoint(x: 204, y: 330)
    /// The tube's tilt loop, which the glint's flicker shares.
    private static let telescopeDuration: TimeInterval = 6.59

    /// Not found's empty moon: the ring turns around it.
    private static let emptyMoonCentre = CGPoint(x: 173, y: 202)

    /// The map's route on the services-off and restricted art, as drawn
    /// (`data-part="route"`'s path), and the art's offsets.
    private static let routePathData = "M1198 479 C1268 407 1284 465 1321 499 S1422 474 1453 470 Q1478 478 1493 515"
    private static let servicesOffOffset = CGPoint(x: -1152, y: -130)
    private static let restrictedOffset = CGPoint(x: -1542, y: -130)
    private static let restrictedRoutePathData = "M1588 479 C1658 407 1674 465 1711 499 S1812 474 1843 470 Q1868 478 1883 515"
    /// The route's three circles, in viewBox units (the same on both maps).
    private static let waypoints = [CGPoint(x: 79, y: 324), CGPoint(x: 169, y: 373), CGPoint(x: 301, y: 340)]

    /// The spark's run: 4.71 s, travelling 3.06 s (fizzle) or 1.88 s
    /// (bump).
    private static let sparkCycle: TimeInterval = 4.71
    private static let fizzleTravel: TimeInterval = 3.06
    private static let bumpTravel: TimeInterval = 1.88
    /// 1j: the stop is the first point where x ≥ 154, just left of the lock.
    private static let lockStopX = 154.0

    static func spec(for kind: LocationIllustration.Kind) -> IllustrationSpec {
        switch kind {
        case .locationNotFound: locationNotFound
        case .permissionOff: permissionOff
        case .servicesOff: servicesOff
        case .restricted: restricted
        }
    }

    /// 1g "Huh?": no halo; the ring turns, the head tilts, the question
    /// pops as the head tilts, the tail swishes.
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
        ],
        motions: [
            .moonDisc: discBreath,
            .moonRing: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 56.5, values: [0, 360], curve: .linear)
            ),
            .head: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 5.18, [
                    (0, 0), (0.08, 0), (0.16, -10), (0.22, -8), (0.60, -8), (0.74, 0), (1, 0),
                ])
            ),
            .question: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 5.18, [
                    (0, -20), (0.10, -20), (0.20, 8), (0.27, 0), (0.62, 0), (0.74, 0), (1, 0),
                ]),
                scale: IllustrationKeyframes(duration: 5.18, [
                    (0, 0), (0.10, 0), (0.20, 1.2), (0.27, 1), (0.62, 1), (0.74, 0.6), (1, 0),
                ]),
                opacity: IllustrationKeyframes(duration: 5.18, [
                    (0, 0), (0.10, 0), (0.20, 1), (0.27, 1), (0.62, 1), (0.74, 0), (1, 0),
                ]),
                offsetY: IllustrationKeyframes(duration: 5.18, [
                    (0, 0), (0.62, 0), (0.74, -10), (1, 0),
                ])
            ),
            .tail: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 3.06, [
                    (0, 0), (0.2, 7), (0.45, -5), (0.7, 5), (1, 0),
                ])
            ),
        ]
    )

    /// 1h "Almost a star": the telescope tilts up on its mount, holds,
    /// wobbles and drops back; its lens glint warms up as it rises,
    /// flickers with the wobble and fades on the way down; a star
    /// sparkles. The stand stays.
    static let permissionOff = IllustrationSpec(
        layers: [
            Layer("permissionOff_moonHalo", moves: [.moonHalo]),
            Layer("permissionOff_moonDisc", moves: [.moonDisc]),
            Layer("permissionOff_stand"),
            Layer("permissionOff_tube", moves: [.tube]),
            Layer("permissionOff_lensGlint", moves: [.tube, .lensGlint]),
        ],
        pivots: [
            .moonHalo: telescopeMoonCentre,
            .moonDisc: telescopeMoonCentre,
            .tube: telescopeMountCentre,
            .lensGlint: telescopeMountCentre,
        ],
        motions: [
            .moonHalo: haloBreath,
            .moonDisc: discBreath,
            .tube: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: telescopeDuration, [
                    (0, 0), (0.22, -7), (0.50, -7), (0.56, -5.5), (0.62, -7.5),
                    (0.68, -6.5), (0.72, -7), (0.90, 0), (1, 0),
                ])
            ),
            // Opacity only: the tilt comes from the tube it rides on. 0 at
            // offset 0, so the Reduce Motion still shows no glint.
            .lensGlint: IllustrationMotion(
                opacity: IllustrationKeyframes(duration: telescopeDuration, [
                    (0, 0), (0.18, 0.10), (0.28, 0.85), (0.50, 0.80), (0.56, 0.55),
                    (0.62, 0.95), (0.68, 0.70), (0.74, 0.60), (0.90, 0), (1, 0),
                ])
            ),
        ],
        star: Star(
            // Top right of the redrawn art, clear of the left-lit crescent
            // and the tube at full tilt; was (128, 122).
            centre: CGPoint(x: 326, y: 150),
            motion: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: telescopeDuration, [
                    (0, 0), (0.26, 0), (0.36, 45), (0.46, 60), (0.54, 90), (0.66, 135), (1, 135),
                ]),
                scale: IllustrationKeyframes(duration: telescopeDuration, [
                    (0, 0), (0.26, 0), (0.36, 1), (0.46, 0.7), (0.54, 1), (0.66, 0), (1, 0),
                ]),
                opacity: IllustrationKeyframes(duration: telescopeDuration, [
                    (0, 0), (0.26, 0), (0.36, 1), (0.46, 0.8), (0.54, 1), (0.66, 0), (1, 0),
                ])
            )
        )
    )

    /// 1i "Fading trail": the map floats; a spark sets off along the
    /// route, lighting each waypoint, and fizzles out partway.
    static let servicesOff = IllustrationSpec(
        layers: [
            Layer("servicesOff_moonHalo", moves: [.moonHalo]),
            Layer("servicesOff_moonDisc", moves: [.moonDisc]),
            Layer("servicesOff_map", moves: [.map]),
            Layer("servicesOff_route", moves: [.map, .route]),
            Layer("servicesOff_waypoint1", moves: [.map, .waypoint1]),
            Layer("servicesOff_waypoint2", moves: [.map, .waypoint2]),
            Layer("servicesOff_waypoint3", moves: [.map, .waypoint3]),
        ],
        pivots: [
            .moonHalo: crescentMoonCentre,
            .moonDisc: crescentMoonCentre,
        ],
        motions: [
            .moonHalo: haloBreath,
            .moonDisc: discBreath,
            .map: IllustrationMotion(
                offsetY: IllustrationKeyframes(duration: 6.47, values: [0, -4, 0])
            ),
        ],
        spark: IllustrationSpark(
            route: SVGPathData.path(routePathData, offset: servicesOffOffset),
            ending: .fizzle,
            cycle: sparkCycle,
            travel: fizzleTravel,
            waypoints: waypoints
        )
    )

    /// 1j "Bump": the spark travels to the lock, bumps into it and bounces
    /// back; the lock shakes on its shackle. The map stays still.
    static let restricted = IllustrationSpec(
        layers: [
            Layer("restricted_moonHalo", moves: [.moonHalo]),
            Layer("restricted_moonDisc", moves: [.moonDisc]),
            Layer("restricted_map", moves: [.map]),
            Layer("restricted_route", moves: [.map, .route]),
            Layer("restricted_waypoint1", moves: [.map, .waypoint1]),
            Layer("restricted_waypoint2", moves: [.map, .waypoint2]),
            Layer("restricted_waypoint3", moves: [.map, .waypoint3]),
            Layer("restricted_lock", moves: [.map, .lock]),
        ],
        pivots: [
            .moonHalo: crescentMoonCentre,
            .moonDisc: crescentMoonCentre,
            .lock: CGPoint(x: 175, y: 298),
        ],
        motions: [
            .moonHalo: haloBreath,
            .moonDisc: discBreath,
        ],
        spark: IllustrationSpark(
            route: SVGPathData.path(restrictedRoutePathData, offset: restrictedOffset),
            ending: .bump(stopX: lockStopX),
            cycle: sparkCycle,
            travel: bumpTravel,
            waypoints: waypoints
        )
    )
}
