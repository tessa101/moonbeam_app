//
//  CoreLocationHeadingService.swift
//  moonbeam-app
//

import CoreLocation

/// `HeadingService` backed by `CLLocationManager`.
///
/// Uses the delegate API: CoreLocation has no async heading sequence, and
/// `CLLocationUpdate.liveUpdates()` doesn't carry headings. Heading and
/// location updates run on the same manager, started and stopped together,
/// because `trueHeading` is only valid while location updates run.
///
/// Has its own manager, separate from `CoreLocationService`'s one-shot fix, so
/// stopping the compass can never cut off a location fetch in flight.
///
/// Main-actor isolated (the project default), which is where
/// `CLLocationManager` wants to live.
final class CoreLocationHeadingService: HeadingService {

    // MARK: - Constants

    /// True heading only needs a rough position (for magnetic declination),
    /// so city-level accuracy is enough and cheaper on power.
    private static let locationAccuracy = kCLLocationAccuracyKilometer

    // MARK: - State

    private let manager = CLLocationManager()

    /// The current session's delegate, retained because
    /// `CLLocationManager.delegate` is weak. One per session, so its stream
    /// continuation never has to change.
    private var observer: HeadingObserver?

    /// Bumped on every start and stop, so a stream that ends late (its
    /// `onTermination` hops to the main actor) can't stop a newer session.
    private var session = 0

    private(set) var isRunning = false

    init() {
        manager.desiredAccuracy = Self.locationAccuracy
    }

    // MARK: - HeadingService

    func start() -> AsyncStream<HeadingReading> {
        stop()

        session += 1
        let current = session
        isRunning = true

        let (stream, continuation) = AsyncStream<HeadingReading>.makeStream()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.stop(session: current) }
        }

        let observer = HeadingObserver(continuation: continuation)
        self.observer = observer

        // No compass hardware: start neither sensor, so they stay paired.
        guard CLLocationManager.headingAvailable() else {
            continuation.yield(.unavailable)
            return stream
        }

        manager.delegate = observer
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        return stream
    }

    func stop() {
        guard isRunning else { return }

        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
        manager.delegate = nil

        isRunning = false
        session += 1

        let finished = observer
        observer = nil
        finished?.finish()
    }

    // MARK: - Session ending from the stream side

    /// Stops only if `session` is still the current one.
    private func stop(session ended: Int) {
        guard ended == session else { return }
        stop()
    }
}

// MARK: - Delegate bridging

/// Forwards heading callbacks into the session's stream as `HeadingReading`s.
///
/// `nonisolated` because the imported delegate protocol has no actor
/// annotation. `CLHeading` is mapped to a `Sendable` `HeadingReading` here, so
/// no CoreLocation type crosses the boundary; yielding into a continuation is
/// safe from any isolation.
private nonisolated final class HeadingObserver: NSObject, CLLocationManagerDelegate {

    private let continuation: AsyncStream<HeadingReading>.Continuation

    init(continuation: AsyncStream<HeadingReading>.Continuation) {
        self.continuation = continuation
        super.init()
    }

    func finish() {
        continuation.finish()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        continuation.yield(
            HeadingReading(
                rawTrueHeading: newHeading.trueHeading,
                rawAccuracy: newHeading.headingAccuracy
            )
        )
    }

    /// A heading failure (e.g. strong magnetic interference) or lost
    /// permission leaves no usable heading, which the compass shows as low
    /// accuracy. Other errors, like a transient "location unknown", are
    /// ignored: the next heading callback says whether true heading survived.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        guard let code = (error as? CLError)?.code,
              code == .headingFailure || code == .denied
        else { return }
        continuation.yield(.unavailable)
    }
}
