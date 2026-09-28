//
//  CompassTarget.swift
//  moonbeam-app
//

import Foundation

/// A bearing the compass can lock onto (COMPASS.md §1): the selected day's
/// moonrise or moonset, or the moon itself on today while it's up.
///
/// `nonisolated`: an inert value, so the lock logic in `CompassLock` can be
/// tested without the main actor.
nonisolated struct CompassTarget: Equatable, Sendable {

    /// Declared in tie-break order: if two targets are exactly as near, the
    /// earlier one wins the lock.
    enum Kind: CaseIterable, Hashable, Sendable {
        case moonrise
        case moonset
        case moon
    }

    let kind: Kind

    /// Degrees clockwise from true north.
    let azimuth: Double
}
