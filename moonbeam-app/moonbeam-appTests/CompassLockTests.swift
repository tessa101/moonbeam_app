//
//  CompassLockTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The lock rules in COMPASS.md §1 (§6: acquire within ±5°, release outside
/// ±8°, nearest wins, hold until release, no lock in low accuracy).
@Suite("Compass lock")
nonisolated struct CompassLockTests {

    // MARK: - Fixtures

    private static let moonrise = CompassTarget(kind: .moonrise, azimuth: 72)
    private static let moonset = CompassTarget(kind: .moonset, azimuth: 80)

    // MARK: - Angular distance

    @Test(
        "Angular distance is the smaller angle, across north too",
        arguments: [
            (355.0, 3.0, 8.0),
            (3.0, 355.0, 8.0),
            (0.0, 180.0, 180.0),
            (10.0, 10.0, 0.0),
            (725.0, 0.0, 5.0),
            (-5.0, 5.0, 10.0),
        ]
    )
    func angularDistance(a: Double, b: Double, expected: Double) {
        #expect(abs(CompassLock.angularDistance(a, b) - expected) < 1e-9)
    }

    // MARK: - Acquire

    @Test("Acquires within ±5°, inclusive", arguments: [67.0, 72.0, 77.0])
    func acquiresWithinFive(heading: Double) {
        let lock = CompassLock.next(locked: nil, heading: heading, isLowAccuracy: false, targets: [Self.moonrise])

        #expect(lock == .moonrise)
    }

    @Test("Doesn't acquire just beyond ±5°", arguments: [66.99, 77.01])
    func doesNotAcquireBeyondFive(heading: Double) {
        let lock = CompassLock.next(locked: nil, heading: heading, isLowAccuracy: false, targets: [Self.moonrise])

        #expect(lock == nil)
    }

    @Test("Acquires across north")
    func acquiresAcrossNorth() {
        let north = CompassTarget(kind: .moonset, azimuth: 358)

        #expect(CompassLock.next(locked: nil, heading: 2, isLowAccuracy: false, targets: [north]) == .moonset)
    }

    @Test("Nearest target wins on acquire")
    func nearestWins() {
        // 3.5° from moonrise (72), 2.5° from moonset (80).
        let lock = CompassLock.next(
            locked: nil,
            heading: 77.5, isLowAccuracy: false,
            targets: [Self.moonrise, Self.moonset]
        )

        #expect(lock == .moonset)
    }

    @Test("An exact tie goes to the earlier kind")
    func tieGoesToEarlierKind() {
        // 4° from each.
        let lock = CompassLock.next(
            locked: nil,
            heading: 76, isLowAccuracy: false,
            targets: [Self.moonset, Self.moonrise]
        )

        #expect(lock == .moonrise)
    }

    // MARK: - Hold and release

    @Test("Holds out to ±8°, inclusive", arguments: [64.0, 80.0, 75.0])
    func holdsWithinEight(heading: Double) {
        let lock = CompassLock.next(locked: .moonrise, heading: heading, isLowAccuracy: false, targets: [Self.moonrise])

        #expect(lock == .moonrise)
    }

    @Test("Releases just beyond ±8°", arguments: [63.99, 80.01])
    func releasesBeyondEight(heading: Double) {
        let lock = CompassLock.next(locked: .moonrise, heading: heading, isLowAccuracy: false, targets: [Self.moonrise])

        #expect(lock == nil)
    }

    /// No switching mid-lock: moonset (80) is nearer at 78, but moonrise
    /// (72) is still within 8°.
    @Test("Holds the current target even when another is nearer")
    func holdsDespiteNearerTarget() {
        let lock = CompassLock.next(
            locked: .moonrise,
            heading: 78, isLowAccuracy: false,
            targets: [Self.moonrise, Self.moonset]
        )

        #expect(lock == .moonrise)
    }

    @Test("After release, the next target in reach is acquired")
    func releaseThenAcquireOther() {
        // 9° from moonrise (released), 1° from moonset.
        let lock = CompassLock.next(
            locked: .moonrise,
            heading: 81, isLowAccuracy: false,
            targets: [Self.moonrise, Self.moonset]
        )

        #expect(lock == .moonset)
    }

    @Test("A locked target that's gone is released")
    func goneTargetReleases() {
        let lock = CompassLock.next(locked: .moon, heading: 72, isLowAccuracy: false, targets: [Self.moonrise])

        #expect(lock == .moonrise)
    }

    // MARK: - Accuracy

    @Test("No lock in low accuracy, even dead on target")
    func noLockInLowAccuracy() {
        #expect(CompassLock.next(locked: nil, heading: 72, isLowAccuracy: true, targets: [Self.moonrise]) == nil)
        #expect(CompassLock.next(locked: .moonrise, heading: 72, isLowAccuracy: true, targets: [Self.moonrise]) == nil)
    }

    @Test("No lock with no true heading")
    func noLockWithoutHeading() {
        #expect(CompassLock.next(locked: .moonrise, heading: nil, isLowAccuracy: false, targets: [Self.moonrise]) == nil)
    }

    @Test("No targets, no lock")
    func noTargets() {
        #expect(CompassLock.next(locked: nil, heading: 72, isLowAccuracy: false, targets: []) == nil)
    }
}
