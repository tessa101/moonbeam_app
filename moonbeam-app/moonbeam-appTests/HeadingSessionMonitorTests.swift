//
//  HeadingSessionMonitorTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// When a running heading session restarts itself (4.8, 4.9).
///
/// Reproduces the 2026-09-29 device bug at the level it can be reproduced:
/// the magnetometer keeps producing a magnetic heading, but true heading is
/// invalid (location updates have stopped delivering), so every reading is
/// low accuracy. Before the fix nothing restarted the session; toggling
/// Location in Settings did. The monitor must restart it on its own.
@Suite("Heading session monitor")
nonisolated struct HeadingSessionMonitorTests {

    // MARK: - Fixtures

    private static let start = Date(timeIntervalSince1970: 1_790_000_000)

    /// Magnetometer fine, true heading invalid: the stuck signature.
    private static func stuckReading(at seconds: TimeInterval) -> HeadingSessionMonitor.Event {
        .reading(rawTrueHeading: -1, rawMagneticHeading: 100, at: start + seconds)
    }

    private static func goodReading(at seconds: TimeInterval) -> HeadingSessionMonitor.Event {
        .reading(rawTrueHeading: 112, rawMagneticHeading: 100, at: start + seconds)
    }

    // MARK: - The stuck state

    @Test("Stuck: magnetic heading but no true heading for 5 s restarts location updates")
    func stuckRestartsLocation() {
        var monitor = HeadingSessionMonitor()

        let actions = [0.0, 1, 2, 3, 4].map { monitor.handle(Self.stuckReading(at: $0)) }
        let atThreshold = monitor.handle(Self.stuckReading(at: HeadingSessionMonitor.stuckThreshold))

        #expect(actions.allSatisfy { $0 == .none })
        #expect(atThreshold == .restartLocationUpdates)
    }

    @Test("Before the fix, the stuck state never recovered on its own; now it restarts repeatedly, throttled")
    func stuckKeepsRetryingThrottled() {
        var monitor = HeadingSessionMonitor()
        var restarts: [TimeInterval] = []

        // One stuck reading a second for a minute.
        for second in 0...60 {
            if monitor.handle(Self.stuckReading(at: TimeInterval(second))) == .restartLocationUpdates {
                restarts.append(TimeInterval(second))
            }
        }

        #expect(restarts.first == HeadingSessionMonitor.stuckThreshold)
        #expect(restarts.count > 1)
        for (earlier, later) in zip(restarts, restarts.dropFirst()) {
            #expect(later - earlier >= HeadingSessionMonitor.minimumRestartInterval)
        }
    }

    @Test("True heading coming back clears the stuck timer")
    func recoveryResets() {
        var monitor = HeadingSessionMonitor()
        _ = monitor.handle(Self.stuckReading(at: 0))
        _ = monitor.handle(Self.stuckReading(at: 4))

        _ = monitor.handle(Self.goodReading(at: 4.5))

        #expect(monitor.handle(Self.stuckReading(at: 5)) == .none)
        #expect(monitor.handle(Self.stuckReading(at: 9)) == .none)
        #expect(monitor.handle(Self.stuckReading(at: 10)) == .restartLocationUpdates)
    }

    @Test("Good readings never restart anything")
    func goodReadingsDoNothing() {
        var monitor = HeadingSessionMonitor()

        let actions = (0...30).map { monitor.handle(Self.goodReading(at: TimeInterval($0))) }

        #expect(actions.allSatisfy { $0 == .none })
    }

    /// Both invalid means no magnetometer data at all; a location restart
    /// can't fix that, so it isn't the stuck signature.
    @Test("No magnetic heading either: not the stuck signature")
    func noMagneticHeading() {
        var monitor = HeadingSessionMonitor()

        let actions = (0...10).map {
            monitor.handle(.reading(rawTrueHeading: -1, rawMagneticHeading: -1, at: Self.start + TimeInterval($0)))
        }

        #expect(actions.allSatisfy { $0 == .none })
    }

    // MARK: - Pause

    @Test("A location-updates pause restarts location updates at once")
    func pauseRestarts() {
        var monitor = HeadingSessionMonitor()

        #expect(monitor.handle(.locationUpdatesPaused) == .restartLocationUpdates)
    }

    // MARK: - Authorization and accuracy changes

    @Test("The first authorization callback is the starting state, not a change")
    func firstAuthorizationIsBaseline() {
        var monitor = HeadingSessionMonitor()

        #expect(monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: false)) == .none)
    }

    @Test("Precise Location turned on or off restarts the whole session")
    func accuracyChangeRestartsSession() {
        var monitor = HeadingSessionMonitor()
        _ = monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: false))

        #expect(monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: true)) == .restartSession)
        #expect(monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: false)) == .restartSession)
    }

    @Test("Permission granted again restarts the whole session")
    func reauthorizationRestartsSession() {
        var monitor = HeadingSessionMonitor()
        _ = monitor.handle(.authorizationChanged(isAuthorized: false, isPrecise: false))

        #expect(monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: true)) == .restartSession)
    }

    /// Losing permission hides the compass (`LocationViewModel`), which stops
    /// the session; restarting it here would be pointless.
    @Test("Permission lost: no restart")
    func deauthorizationDoesNothing() {
        var monitor = HeadingSessionMonitor()
        _ = monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: true))

        #expect(monitor.handle(.authorizationChanged(isAuthorized: false, isPrecise: true)) == .none)
    }

    @Test("A repeat of the same authorization: no restart")
    func sameAuthorizationDoesNothing() {
        var monitor = HeadingSessionMonitor()
        _ = monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: true))

        #expect(monitor.handle(.authorizationChanged(isAuthorized: true, isPrecise: true)) == .none)
    }
}
