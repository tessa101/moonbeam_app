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
        case map
        case route
        case waypoint1 = "waypoint-1"
        case waypoint2 = "waypoint-2"
        case waypoint3 = "waypoint-3"
        case lock
        /// 1k: the whole cat's breath, which carries every cat layer.
        case breath
        /// 1k: the left ear, which flicks on top of the head's tilt.
        case ear

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
        /// Where a raster slice sits in the viewBox, when it isn't a
        /// full-canvas vector: 1k's cat layers are drawn at their own rect
        /// so their pixels aren't resampled onto the canvas first.
        let placement: CGRect?

        init(_ asset: String, moves parts: [Part] = [], placement: CGRect? = nil) {
            self.asset = asset
            self.parts = parts
            self.placement = placement
        }
    }

    /// The 4-point sparkle on permission off: added over 1h's telescope,
    /// and carried over unchanged to 1k (Tessa, 2026-10-16).
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

    /// `layer`'s whole move at `time`, in viewBox points: its innermost
    /// part's move first, then each parent's, as nested SVG groups apply
    /// them. 1k's ear turns on the tilted head, which rides the breath.
    func transform(of layer: Layer, at time: TimeInterval?, canvasScale: CGFloat = 1) -> CGAffineTransform {
        layer.parts.reduce(CGAffineTransform.identity) { outer, part in
            pose(of: part, at: time)
                .scaledTransform(pivot: pivots[part], canvasScale: canvasScale)
                .concatenating(outer)
        }
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
    /// 1k's full moon, the same as the searching art's.
    private static let readyToLookMoonCentre = CGPoint(x: 215, y: 202)
    /// Where every 1k cat raster (800 × 860 px) sits in the viewBox: placed
    /// at (215, 250) under the foreground's `translate(-49 27.73)
    /// scale(0.415)`, so 332 × 356.9 units.
    private static let readyToLookCatScale = 0.415
    private static let readyToLookCatRect = CGRect(
        x: -49 + 215 * readyToLookCatScale,
        y: 27.73 + 250 * readyToLookCatScale,
        width: 800 * readyToLookCatScale,
        height: 860 * readyToLookCatScale
    )
    /// The star's loop: 1h's telescope loop, kept for the carried-over star.
    private static let starDuration: TimeInterval = 6.59

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
        case .searching: searching
        case .locationNotFound: locationNotFound
        case .permissionOff: readyToLook
        case .servicesOff: servicesOff
        case .restricted: restricted
        }
    }

    /// 1a "Look-around", simplified for the landing: shared moon breathing
    /// and only the calm independent tail sway. The head and paw stay still.
    static let searching = IllustrationSpec(
        layers: [
            Layer("searching_moonHalo", moves: [.moonHalo]),
            Layer("searching_moonDisc", moves: [.moonDisc]),
            Layer("searching_tail", moves: [.tail]),
            Layer("searching_body"),
            Layer("searching_look"),
        ],
        pivots: [
            .moonHalo: CGPoint(x: 215, y: 202),
            .moonDisc: CGPoint(x: 215, y: 202),
            .tail: CGPoint(x: 117, y: 452),
        ],
        motions: [
            .moonHalo: haloBreath,
            .moonDisc: discBreath,
            .tail: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 4.2, values: [0, 4, 0, -3, 0])
            ),
        ]
    )

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

    /// 1k "Ready to look" (replaces 1h, Tessa, 2026-10-16): the cat holds
    /// the telescope, breathes, lifts its head as if about to peek, flicks
    /// an ear and sways its tail, each on its own loop so the mix rarely
    /// repeats. The disc breathes; the art's halo is hidden in the source
    /// (`display="none"`), so there's none. The cat layers are the supplied
    /// rasters at native size; the moon stays vector.
    static let readyToLook = IllustrationSpec(
        layers: [
            Layer("readyToLook_moonDisc", moves: [.moonDisc]),
            Layer("readyToLook_tail", moves: [.breath, .tail], placement: readyToLookCatRect),
            Layer("readyToLook_body", moves: [.breath], placement: readyToLookCatRect),
            Layer("readyToLook_head", moves: [.breath, .head], placement: readyToLookCatRect),
            Layer("readyToLook_ear", moves: [.breath, .head, .ear], placement: readyToLookCatRect),
        ],
        pivots: [
            .moonDisc: readyToLookMoonCentre,
            .breath: CGPoint(x: 200, y: 478),
            .head: CGPoint(x: 205, y: 277),
            .ear: CGPoint(x: 163.5, y: 193),
            .tail: CGPoint(x: 97, y: 414.5),
        ],
        motions: [
            .moonDisc: discBreath,
            .breath: IllustrationMotion(
                scaleX: IllustrationKeyframes(duration: 4.47, values: [1, 1.006, 1]),
                scaleY: IllustrationKeyframes(duration: 4.47, values: [1, 1.014, 1])
            ),
            .head: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 8.82, [
                    (0, 0), (0.22, -3.2), (0.40, -2.2), (0.58, -3.6), (0.80, -1), (1, 0),
                ])
            ),
            .ear: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 6.24, [
                    (0, 0), (0.62, 0), (0.66, -9), (0.70, 3), (0.74, -4), (0.80, 0), (1, 0),
                ])
            ),
            .tail: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: 4.94, values: [0, 4, 0, -3, 0])
            ),
        ],
        star: Star(
            // 1h's sparkle and loop, unchanged. 1k's full disc covers its
            // old spot (326, 150), so it moves to open sky above the
            // telescope's tip: 32 clear of the disc's rim, well above the
            // tube, and away from the head, which tilts left.
            centre: CGPoint(x: 370, y: 118),
            motion: IllustrationMotion(
                rotation: IllustrationKeyframes(duration: starDuration, [
                    (0, 0), (0.26, 0), (0.36, 45), (0.46, 60), (0.54, 90), (0.66, 135), (1, 135),
                ]),
                scale: IllustrationKeyframes(duration: starDuration, [
                    (0, 0), (0.26, 0), (0.36, 1), (0.46, 0.7), (0.54, 1), (0.66, 0), (1, 0),
                ]),
                opacity: IllustrationKeyframes(duration: starDuration, [
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
