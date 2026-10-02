//
//  MoonCardCell.swift
//  moonbeam-app
//

import Foundation

/// The moon card's three data cells, for the lock highlight
/// (COMPASS-1.1.md §3): on lock, the cell for the target the compass points
/// at is outlined in amber.
///
/// `nonisolated`: an inert value.
nonisolated enum MoonCardCell: Equatable {
    case moonrise
    case moonset
    case upNow

    /// The cell matching a lock, or `nil` with none: moonrise and moonset
    /// to their columns, the live Moon to Up now.
    init?(lockedOn kind: CompassTarget.Kind?) {
        switch kind {
        case .moonrise: self = .moonrise
        case .moonset: self = .moonset
        case .moon: self = .upNow
        case nil: return nil
        }
    }
}
