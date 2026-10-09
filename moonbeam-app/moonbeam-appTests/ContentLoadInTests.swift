//
//  ContentLoadInTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The main screen loading in after launch (LOADER.md §2.1): sentence, card,
/// compass, top to bottom, each fading in with an 8 pt rise.
@Suite("Content load-in", .timeLimit(.minutes(1)))
@MainActor
struct ContentLoadInTests {

    private static let tolerance = 1e-9

    @Test("Top to bottom: sentence, card, compass")
    func order() {
        #expect(ContentLoadIn.Block.allCases == [.sentence, .card, .compass])
    }

    @Test("Staggered 150 ms (§11.2.7), the sentence first with no wait")
    func stagger() {
        #expect(ContentLoadIn.stagger == 0.15)
        #expect(ContentLoadIn.delay(for: .sentence) == 0)
        #expect(abs(ContentLoadIn.delay(for: .card) - 0.15) < Self.tolerance)
        #expect(abs(ContentLoadIn.delay(for: .compass) - 0.30) < Self.tolerance)
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

    @Test("The whole load-in is over in 0.6 s")
    func total() {
        let last = ContentLoadIn.delay(for: .compass) + ContentLoadIn.duration
        #expect(abs(last - 0.6) < Self.tolerance)
    }

    @Test("5.10a.9 card landing over the skeleton: a visible 16 pt rise, the skeleton leaving faster")
    func cardLandingOverSkeleton() {
        #expect(ContentLoadIn.cardLandingRise == 24)
        #expect(ContentLoadIn.cardLandingRise > ContentLoadIn.rise)
        #expect(ContentLoadIn.cardLandingDuration == 0.45)
        #expect(ContentLoadIn.skeletonExitDuration == 0.1)
        // The skeleton is gone before the card has finished arriving.
        #expect(ContentLoadIn.skeletonExitDuration < ContentLoadIn.cardLandingDuration)
        // The skeleton is gone before the card starts to move, so its frame
        // can't hide the card's own frame moving.
        #expect(ContentLoadIn.skeletonExitDuration <= ContentLoadIn.replayCardDelay)
        // Both start on the card's replay delay (+0.1 s).
        #expect(ContentLoadIn.replayCardDelay == 0.1)
    }

    @Test("5.10a.6 place-change landing: city line, then card, then compass, a little slower than launch")
    func placeChangeLanding() {
        #expect(ContentLoadIn.replayDuration == 0.4)
        #expect(ContentLoadIn.replayDelay(for: .card) == ContentLoadIn.replayCardDelay)
        #expect(ContentLoadIn.replayDelay(for: .compass) == ContentLoadIn.replayCompassDelay)
        #expect(ContentLoadIn.replayCardDelay == 0.1)
        #expect(ContentLoadIn.replayCompassDelay == 0.25)
        // The city line (delay 0) leads, then the card, then the compass.
        #expect(0 < ContentLoadIn.replayCardDelay)
        #expect(ContentLoadIn.replayCardDelay < ContentLoadIn.replayCompassDelay)
        #expect(ContentLoadIn.replayDuration > ContentLoadIn.duration)
    }
}
