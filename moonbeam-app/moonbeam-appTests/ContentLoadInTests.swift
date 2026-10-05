//
//  ContentLoadInTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The main screen loading in after launch (LOADER.md §2.1): sentence, card,
/// compass, top to bottom, each fading in with an 8 pt rise.
@Suite("Content load-in")
@MainActor
struct ContentLoadInTests {

    private static let tolerance = 1e-9

    @Test("Top to bottom: sentence, card, compass")
    func order() {
        #expect(ContentLoadIn.Block.allCases == [.sentence, .card, .compass])
    }

    @Test("Staggered 70 ms, the sentence first with no wait")
    func stagger() {
        #expect(ContentLoadIn.delay(for: .sentence) == 0)
        #expect(abs(ContentLoadIn.delay(for: .card) - 0.07) < Self.tolerance)
        #expect(abs(ContentLoadIn.delay(for: .compass) - 0.14) < Self.tolerance)
    }

    @Test("Each block: 300 ms, rising 8 pt")
    func values() {
        #expect(ContentLoadIn.duration == 0.3)
        #expect(ContentLoadIn.rise == 8)
        #expect(ContentLoadIn.startOffset(reduceMotion: false) == 8)
    }

    @Test("Reduce Motion: no rise, the stagger stays")
    func reduceMotion() {
        #expect(ContentLoadIn.startOffset(reduceMotion: true) == 0)
        #expect(ContentLoadIn.delay(for: .compass) > ContentLoadIn.delay(for: .sentence))
    }

    @Test("The whole load-in is over within half a second")
    func total() {
        let last = ContentLoadIn.delay(for: .compass) + ContentLoadIn.duration
        #expect(last < 0.5)
    }
}
