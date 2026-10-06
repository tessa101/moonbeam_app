//
//  AhaGreeting.swift
//  moonbeam-app
//

import Foundation

/// What "Aha" says when a fix lands after a recovery (LOADER.md §10.4): a
/// line, with the city under it.
///
/// The line rotates so the same one never shows twice in a row; Tessa may
/// add more to `lines`.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct AhaGreeting: Equatable, Sendable {

    /// §10.4's lines.
    static let lines = ["Aha, there you are!", "Hey, found you.", "There we are."]

    let line: String
    /// "City, ST" (`Place.nameWithRegion`).
    let city: String

    /// VoiceOver reads the two as one: "Aha, there you are! Irvine, CA".
    var accessibilityLabel: String {
        "\(line) \(city)"
    }

    /// A line other than `previous`, picked by `pick`, which returns an index
    /// below the count it's given (random in the app, fixed in tests).
    static func line(after previous: String?, pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        let candidates = lines.filter { $0 != previous }
        let index = min(max(pick(candidates.count), 0), candidates.count - 1)
        return candidates[index]
    }
}
