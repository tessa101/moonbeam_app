//
//  MessageCopy.swift
//  moonbeam-app
//

import Foundation

/// The words on one location message screen: the launch loader's messages
/// (LOADER.md §10.3) and the location failure screen
/// (STEP-5.10a-LOCATION-FAILURE.md, Chunk 2). Both draw them with the same
/// `MessageText` and `MessageActions`, so there's one message block, not two.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct MessageCopy: Equatable, Sendable {

    let headline: String
    /// The set lines at the default size; joined, they're `headline`.
    let headlineLines: [String]?
    let body: String
    /// The set lines at the default size; `nil` wraps naturally.
    let bodyLines: [String]?
    /// Where the switch is in Settings, on its set lines, in a chip under
    /// the body; `nil` shows none.
    var pathChipLines: [String]? = nil
    /// `nil`: no button, but its room is kept, so the link sits where it
    /// does on the other messages (No fix, Chunk 2b).
    let primaryTitle: String?
    let linkTitle: String
    /// Restricted has no link, but its room is kept, so the button sits
    /// where it does on the other messages (Tessa, 2026-10-06).
    var showsLink = true

    /// The chip as VoiceOver reads it: the steps as a list, not "›".
    var pathChipAccessibilityLabel: String? {
        guard let pathChipLines else { return nil }
        return pathChipLines
            .joined(separator: " ")
            .split(separator: Self.pathSeparator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Between the steps of a Settings path.
    static let pathSeparator: Character = "›"
}
