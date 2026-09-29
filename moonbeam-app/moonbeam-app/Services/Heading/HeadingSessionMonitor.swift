//
//  HeadingSessionMonitor.swift
//  moonbeam-app
//

import Foundation

/// Decides when a running heading session needs restarting (4.8, 4.9).
///
/// Device test 2026-09-29: "Compass accuracy is low" stuck until Location
/// was toggled in Settings, which restarted the session. Nothing in the
/// session restarted itself. True heading is only valid while location
/// updates run, so anything that silently stops them (CoreLocation's
/// automatic pause, an authorization or accuracy change) leaves every
/// reading without a true heading.
///
/// Pure and `nonisolated`, so the stuck state can be reproduced in a test.
/// `CoreLocationHeadingService` feeds it events and acts on the answer.
nonisolated struct HeadingSessionMonitor {

    // MARK: - Types

    enum Event: Equatable, Sendable {
        /// One `CLHeading`, raw: negative means invalid.
        case reading(rawTrueHeading: Double, rawMagneticHeading: Double, at: Date)

        /// CoreLocation paused location updates.
        case locationUpdatesPaused

        /// `locationManagerDidChangeAuthorization`, with what it now reports.
        case authorizationChanged(isAuthorized: Bool, isPrecise: Bool)
    }

    enum Action: Equatable, Sendable {
        case none

        /// Stop and start location updates; heading keeps running.
        case restartLocationUpdates

        /// Stop and start both, as a Settings toggle would.
        case restartSession
    }

    // MARK: - Constants

    /// How long a valid magnetic heading can arrive without a true heading
    /// before the location side counts as stuck. Long enough to ride out the
    /// first fix after starting.
    static let stuckThreshold: TimeInterval = 5

    /// At most one location restart this often, so a device that can't get
    /// a fix at all isn't restarted in a loop.
    static let minimumRestartInterval: TimeInterval = 10

    // MARK: - State

    private var trueHeadingMissingSince: Date?
    private var lastRestart: Date?
    private var lastAuthorization: (isAuthorized: Bool, isPrecise: Bool)?

    // MARK: - Rules

    mutating func handle(_ event: Event) -> Action {
        switch event {
        case let .reading(rawTrueHeading, rawMagneticHeading, now):
            return handleReading(trueValid: rawTrueHeading >= 0, magneticValid: rawMagneticHeading >= 0, now: now)

        case .locationUpdatesPaused:
            trueHeadingMissingSince = nil
            return .restartLocationUpdates

        case let .authorizationChanged(isAuthorized, isPrecise):
            defer { lastAuthorization = (isAuthorized, isPrecise) }
            // The first callback arrives when the delegate is set; it's the
            // starting state, not a change.
            guard let last = lastAuthorization else { return .none }
            guard last.isAuthorized != isAuthorized || last.isPrecise != isPrecise else { return .none }
            trueHeadingMissingSince = nil
            // Losing permission is `LocationViewModel`'s to handle (it hides
            // the compass); only a still-authorized change needs a restart.
            return isAuthorized ? .restartSession : .none
        }
    }

    /// The stuck signature: the magnetometer works (magnetic heading is
    /// valid) but true heading isn't, so location updates aren't delivering.
    private mutating func handleReading(trueValid: Bool, magneticValid: Bool, now: Date) -> Action {
        guard magneticValid, !trueValid else {
            trueHeadingMissingSince = nil
            return .none
        }
        guard let since = trueHeadingMissingSince else {
            trueHeadingMissingSince = now
            return .none
        }
        guard now.timeIntervalSince(since) >= Self.stuckThreshold else { return .none }
        if let lastRestart, now.timeIntervalSince(lastRestart) < Self.minimumRestartInterval {
            return .none
        }
        lastRestart = now
        trueHeadingMissingSince = now
        return .restartLocationUpdates
    }
}
