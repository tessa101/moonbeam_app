//
//  MessageActionVisibility.swift
//  moonbeam-app
//

import Foundation

/// Which of a message's two controls show (STEP-5.10a-CHUNK-2C, item 2).
/// A search action (the "Search for a city instead" link, and restricted's
/// "Search for a city" button) shows only when search can work: online, or
/// with recents to pick from. A hidden control keeps its room, so nothing
/// moves when it comes back.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct MessageActionVisibility: Equatable, Sendable {

    let showsPrimary: Bool
    let showsLink: Bool

    /// - Parameters:
    ///   - primaryIsSearch: the button opens the search (restricted);
    ///     Open Settings and Use my location never depend on the network.
    ///   - searchAvailable: online, or recents to pick from.
    init(copy: MessageCopy, primaryIsSearch: Bool, searchAvailable: Bool) {
        showsPrimary = copy.primaryTitle != nil && (searchAvailable || !primaryIsSearch)
        showsLink = copy.showsLink && searchAvailable
    }
}
