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

    /// Accurate enough to lock.
    private static let goodAccuracy = 3.0

    private static func reading(_ heading: Double) -> HeadingReading {
        HeadingReading(trueHeading: heading, accuracy: goodAccuracy)
    }

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
        let lock = CompassLock.next(locked: nil, reading: Self.reading(heading), targets: [Self.moonrise])

        #expect(lock == .moonrise)
    }

    @Test("Doesn't acquire just beyond ±5°", arguments: [66.99, 77.01])
    func doesNotAcquireBeyondFive(heading: Double) {
        let lock = CompassLock.next(locked: nil, reading: Self.reading(heading), targets: [Self.moonrise])

        #expect(lock == nil)
    }

    @Test("Acquires across north")
    func acquiresAcrossNorth() {
        let north = CompassTarget(kind: .moonset, azimuth: 358)

        #expect(CompassLock.next(locked: nil, reading: Self.reading(2), targets: [north]) == .moonset)
    }

    @Test("Nearest target wins on acquire")
    func nearestWins() {
        // 3.5° from moonrise (72), 2.5° from moonset (80).
        let lock = CompassLock.next(
            locked: nil,
            reading: Self.reading(77.5),
            targets: [Self.moonrise, Self.moonset]
        )

        #expect(lock == .moonset)
    }

    @Test("An exact tie goes to the earlier kind")
    func tieGoesToEarlierKind() {
        // 4° from each.
        let lock = CompassLock.next(
            locked: nil,
            reading: Self.reading(76),
            targets: [Self.moonset, Self.moonrise]
        )

        #expect(lock == .moonrise)
    }

    // MARK: - Hold and release

    @Test("Holds out to ±8°, inclusive", arguments: [64.0, 80.0, 75.0])
    func holdsWithinEight(heading: Double) {
        let lock = CompassLock.next(locked: .moonrise, reading: Self.reading(heading), targets: [Self.moonrise])

        #expect(lock == .moonrise)
    }

    @Test("Releases just beyond ±8°", arguments: [63.99, 80.01])
    func releasesBeyondEight(heading: Double) {
        let lock = CompassLock.next(locked: .moonrise, reading: Self.reading(heading), targets: [Self.moonrise])

        #expect(lock == nil)
    }

    /// No switching mid-lock: moonset (80) is nearer at 78, but moonrise
    /// (72) is still within 8°.
    @Test("Holds the current target even when another is nearer")
    func holdsDespiteNearerTarget() {
        let lock = CompassLock.next(
            locked: .moonrise,
            reading: Self.reading(78),
            targets: [Self.moonrise, Self.moonset]
        )

        #expect(lock == .moonrise)
    }

    @Test("After release, the next target in reach is acquired")
    func releaseThenAcquireOther() {
        // 9° from moonrise (released), 1° from moonset.
        let lock = CompassLock.next(
            locked: .moonrise,
            reading: Self.reading(81),
            targets: [Self.moonrise, Self.moonset]
        )

        #expect(lock == .moonset)
    }

    @Test("A locked target that's gone is released")
    func goneTargetReleases() {
        let lock = CompassLock.next(locked: .moon, reading: Self.reading(72), targets: [Self.moonrise])

        #expect(lock == .moonrise)
    }

    // MARK: - Accuracy

    @Test("No lock in low accuracy, even dead on target")
    func noLockInLowAccuracy() {
        let poor = HeadingReading(trueHeading: 72, accuracy: 20)

        #expect(CompassLock.next(locked: nil, reading: poor, targets: [Self.moonrise]) == nil)
        #expect(CompassLock.next(locked: .moonrise, reading: poor, targets: [Self.moonrise]) == nil)
    }

    @Test("No lock with no reading or no true heading")
    func noLockWithoutHeading() {
        #expect(CompassLock.next(locked: .moonrise, reading: nil, targets: [Self.moonrise]) == nil)
        #expect(CompassLock.next(locked: nil, reading: .unavailable, targets: [Self.moonrise]) == nil)
    }

    @Test("No targets, no lock")
    func noTargets() {
        #expect(CompassLock.next(locked: nil, reading: Self.reading(72), targets: []) == nil)
    }
}
