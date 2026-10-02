//
//  CompassTargetLabels.swift
//  moonbeam-app
//

import Foundation

/// Which targets on the arc carry a text label, and what it says
/// (COMPASS-1.1.md §5): "↑ Rise", "↓ Set", "Now", outside the arc.
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

    private static func priority(of kind: CompassTarget.Kind) -> Int {
        switch kind {
        case .moon: 0
        case .moonrise: 1
        case .moonset: 2
        }
    }
}
