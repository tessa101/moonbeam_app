//
//  CompassTargetLabels.swift
//  moonbeam-app
//

import CoreGraphics
import Foundation

/// Which targets on the arc carry a text label, what it says
/// (COMPASS-1.1.md §5): "↑ Rise", "↓ Set", "Now", outside the arc, and how
/// far out it sits so the gap to its mark is the same at every angle (§9.3).
///
/// - The locked target drops its label: the pill says the same.
/// - Two labels closer than `collisionDegrees` would overlap: "Now" keeps
///   its label and the other drops its text (its dot stays). Rise and set
///   that close (only near the poles) follow the lock's tie-break order,
///   so moonrise keeps its label.
///
/// `nonisolated`: a pure rule, testable without the main actor.
nonisolated enum CompassTargetLabels {

    /// About the width of a label at 138 pt from the centre.
    static let collisionDegrees = 15.0

    static func text(for kind: CompassTarget.Kind) -> String {
        switch kind {
        case .moonrise: "↑ Rise"
        case .moonset: "↓ Set"
        case .moon: "Now"
        }
    }

    /// The label each target shows; targets missing from the result show
    /// only their mark.
    static func labels(for targets: [CompassTarget], lockedKind: CompassTarget.Kind?) -> [CompassTarget.Kind: String] {
        // Highest priority first: Now, then the lock's order.
        let ranked = targets
            .filter { $0.kind != lockedKind }
            .sorted { priority(of: $0.kind) < priority(of: $1.kind) }
        var kept: [CompassTarget] = []
        for target in ranked where !kept.contains(where: {
            CompassLock.angularDistance($0.azimuth, target.azimuth) < collisionDegrees
        }) {
            kept.append(target)
        }
        return Dictionary(uniqueKeysWithValues: kept.map { ($0.kind, text(for: $0.kind)) })
    }

    // MARK: - Placement (COMPASS-1.1.md §9.3)

    /// From the mark's edge to the nearest point of the label's text.
    static let labelGap: CGFloat = 10

    /// Bisection steps for `centreDistance`: far below a point.
    private static let placementIterations = 32

    /// How far from the dial's centre to centre a label of `labelSize`, out
    /// along the radius through its mark at `angle` (on screen, clockwise
    /// from 12 o'clock), so the shortest distance from the mark's edge to
    /// the label's box is `labelGap` at any angle. 5.4.4 placed every label
    /// at one radius, so wide labels at 3 and 9 o'clock nearly touched
    /// their dots while those at 12 and 6 sat far off.
    ///
    /// - Parameters:
    ///   - trackRadius: the arc's track, where the marks sit.
    ///   - markRadius: the mark's radius (a dot's, or the Moon glyph's).
    static func centreDistance(
        trackRadius: CGFloat,
        markRadius: CGFloat,
        labelSize: CGSize,
        angle: Double
    ) -> CGFloat {
        let wanted = markRadius + labelGap
        // The box's distance from the mark's centre grows with the label's
        // distance out, so bisect it: lower is too close, upper far enough.
        var lower: CGFloat = 0
        var upper = wanted + labelSize.width + labelSize.height
        for _ in 0..<placementIterations {
            let middle = (lower + upper) / 2
            if gap(from: middle, labelSize: labelSize, angle: angle) < wanted {
                lower = middle
            } else {
                upper = middle
            }
        }
        return trackRadius + upper
    }

    /// The shortest distance from a mark's centre to a label's box centred
    /// `offset` further out along the radius at `angle`.
    static func gap(from offset: CGFloat, labelSize: CGSize, angle: Double) -> CGFloat {
        let radians = angle * .pi / 180
        let dx = max(abs(offset * CGFloat(sin(radians))) - labelSize.width / 2, 0)
        let dy = max(abs(offset * CGFloat(cos(radians))) - labelSize.height / 2, 0)
        return hypot(dx, dy)
    }

    private static func priority(of kind: CompassTarget.Kind) -> Int {
        switch kind {
        case .moon: 0
        case .moonrise: 1
        case .moonset: 2
        }
    }
}
