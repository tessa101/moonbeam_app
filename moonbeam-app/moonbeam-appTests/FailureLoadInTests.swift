//
//  FailureLoadInTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// STEP-5.10a Chunk 6: the failure entrance is the existing location-screen
/// load-in, extended across the illustration and message children.
@Suite("Failure load-in", .timeLimit(.minutes(1)))
@MainActor
struct FailureLoadInTests {
    private static let tolerance = 1e-9

    private actor WaitRecorder {
        private(set) var values: [Duration] = []
        func record(_ duration: Duration) { values.append(duration) }
    }

    @Test("Illustration leads; text and actions follow with ContentLoadIn's stagger")
    func orderAndStarts() {
        let blocks: [FailureLoadIn.Block] = [.illustration, .headline, .body, .path, .primary, .secondary]
        let starts = blocks.map { FailureLoadIn.delay(for: $0, hasPath: true) }
        let expected = [0.0, 0.15, 0.30, 0.45, 0.60, 0.75]
        #expect(zip(starts, expected).allSatisfy { abs($0 - $1) < Self.tolerance })
        #expect(abs((starts[1] - starts[0]) - ContentLoadIn.stagger) < Self.tolerance)
        #expect(ContentLoadIn.duration == 0.3)
    }

    @Test("Without a path chip, the primary follows the body on the next beat")
    func skipsAbsentPath() {
        #expect(
            FailureLoadIn.delay(for: .primary, hasPath: false)
                == FailureLoadIn.delay(for: .body, hasPath: false) + ContentLoadIn.stagger
        )
        #expect(
            FailureLoadIn.delay(for: .secondary, hasPath: false)
                == FailureLoadIn.delay(for: .primary, hasPath: false) + ContentLoadIn.stagger
        )
    }

    @Test("Reduce Motion keeps order and opacity timing but drops the rise")
    func reduceMotion() {
        #expect(FailureLoadIn.startOffset(reduceMotion: false) == ContentLoadIn.rise)
        #expect(FailureLoadIn.startOffset(reduceMotion: true) == 0)
        #expect(
            FailureLoadIn.delay(for: .headline, hasPath: true)
                > FailureLoadIn.delay(for: .illustration, hasPath: true)
        )
    }

    @Test("Searching failures reuse the message minimum; instant failures need no loader wait")
    func searchMinimumAndInstantFailure() async {
        let waits = WaitRecorder()
        let reference = Date(timeIntervalSinceReferenceDate: 1_000)
        let loader = LocationLoader(
            now: { reference },
            sleep: { duration in await waits.record(duration) }
        )
        loader.appear()

        #expect(await loader.prepareFailure())
        #expect(await waits.values == [.seconds(LocationLoader.minimumSearchBeforeMessage)])
        #expect(LocationLoader.minimumSearchBeforeMessage >= 1.2)
    }
}
