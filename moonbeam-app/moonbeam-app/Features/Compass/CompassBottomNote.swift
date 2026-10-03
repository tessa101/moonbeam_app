//
//  CompassBottomNote.swift
//  moonbeam-app
//

import Foundation

/// The one note the compass shows in the bar fixed above the home indicator
/// (COMPASS-1.1.md §9.4): Precise Location off, low accuracy, Nearby or the
/// aha line. Chosen by `CompassViewModel.bottomNote`, one at a time.
///
/// `nonisolated`: an inert value.
nonisolated struct CompassBottomNote: Equatable {

    enum Kind: Equatable {
        /// With the Use Precise button.
        case preciseOff
        case lowAccuracy
        case nearby
        /// "There you are!…", for a few seconds after Precise turns on.
        case aha
    }

    let kind: Kind
    let text: String

    /// Only Precise off has a button.
    var offersPreciseLocation: Bool {
        kind == .preciseOff
    }
}
