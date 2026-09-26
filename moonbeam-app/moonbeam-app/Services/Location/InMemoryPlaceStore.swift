//
//  InMemoryPlaceStore.swift
//  moonbeam-app
//

import Foundation

/// `PlaceStore` that forgets everything on deinit, for tests and previews.
///
/// Note that `UserDefaultsPlaceStore` is itself testable (it takes a suite),
/// so this exists for the *callers* of a store — a view model test shouldn't
/// have to clean up a defaults suite to check its launch logic.
final class InMemoryPlaceStore: PlaceStore {

    var lastViewed: Place?

    init(lastViewed: Place? = nil) {
        self.lastViewed = lastViewed
    }
}
