//
//  LocationOffBlock.swift
//  moonbeam-app
//

import Foundation

/// What the compass's location-off slot draws (LOCATION-OFF-FLOW.md §2, §3):
/// the prompt card (S1, or after Maybe later the guide row) where the user can
/// turn location on, or the plain note where they can't (restricted).
///
/// A value, so the view model can hold the one that was showing while the
/// compass comes in behind it (§5.2): granting location clears the prompt's
/// state at once (the ghost, the row, the dismissed flag), and the block mustn't
/// change under the user in the moment before it goes.
///
/// `nonisolated`: an inert value.
nonisolated struct LocationOffBlock: Equatable, Sendable {

    /// The prompt card, not the restricted note.
    let showsPrompt: Bool

    /// The card collapsed into the guide row (S2 to S6).
    let isCollapsed: Bool

    let ghost: CompassGhostGeometry
    let row: LocationOffGuideFormatter.Row

    /// S3 to S6: the row's warm look.
    let isRowActive: Bool
}
