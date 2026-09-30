//
//  CompassLock.swift
//  moonbeam-app
//

import Foundation

/// The lock rules from COMPASS.md §1, as a pure function of the current lock,
/// the heading, the accuracy state and the targets.
///
/// - **Acquire** within ±5° of a target; the nearest one wins.
/// - **Hold** the locked target until the heading is more than ±8° from it,
///   even if another target becomes nearer. The 3° gap stops flicker at the
///   edge.
/// - **No lock** in low accuracy (`CompassAccuracy`, with its own
///   hysteresis): a ±5° lock means little when the heading could be 25° out.
///
/// `nonisolated` so it's testable without the main actor.
nonisolated enum CompassLock {

    // MARK: - Constants

    static let acquireToleranceDegrees = 5.0
    static let releaseToleranceDegrees = 8.0

    private static let fullTurnDegrees = 360.0
    private static let halfTurnDegrees = 180.0

    // MARK: - Rules

    /// The target to be locked onto, or `nil` for no lock.
    ///
    /// A locked target that's no longer in `targets` (the moon set, or the
    /// day changed and it has no moonrise) is released.
    ///
    /// - Parameters:
    ///   - heading: true heading, `nil` with none.
    ///   - isLowAccuracy: the compass's current accuracy state.
    static func next(
        locked: CompassTarget.Kind?,
        heading: Double?,
        isLowAccuracy: Bool,
        targets: [CompassTarget]
    ) -> CompassTarget.Kind? {
        guard !isLowAccuracy, let heading else { return nil }

        if let locked,
           let current = targets.first(where: { $0.kind == locked }),
           angularDistance(heading, current.azimuth) <= releaseToleranceDegrees {
            return locked
        }

        let inReach = targets
            .map { (target: $0, distance: angularDistance(heading, $0.azimuth)) }
            .filter { $0.distance <= acquireToleranceDegrees }

        // Nearest first; exact ties go to the earlier `Kind`.
        let nearest = inReach.min { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return order(of: lhs.target.kind) < order(of: rhs.target.kind)
        }
        return nearest?.target.kind
    }

    /// The smaller angle between two bearings, `0...180`, so 355° and 3° are
    /// 8° apart, not 352°.
    static func angularDistance(_ a: Double, _ b: Double) -> Double {
        let difference = (a - b).truncatingRemainder(dividingBy: fullTurnDegrees)
        let positive = difference < 0 ? difference + fullTurnDegrees : difference
        return positive > halfTurnDegrees ? fullTurnDegrees - positive : positive
    }

    // MARK: - Helpers

    private static func order(of kind: CompassTarget.Kind) -> Int {
        CompassTarget.Kind.allCases.firstIndex(of: kind) ?? 0
    }
}
