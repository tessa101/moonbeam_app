//
//  FakeHeadingService.swift
//  moonbeam-app
//

import Foundation

/// Scriptable `HeadingService` for tests and SwiftUI previews. The simulator
/// has no compass, so this is how lock, release and low accuracy get
/// exercised (COMPASS.md §6).
///
/// `send(_:)` pushes a reading to the running session. Start and stop counts
/// let a test check the sensor lifecycle (COMPASS.md §1): every start is
/// matched by a stop on hide, scroll-out and background.
final class FakeHeadingService: HeadingService {

    // MARK: - Record

    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    // MARK: - State

    private var continuation: AsyncStream<HeadingReading>.Continuation?

    /// Same guard as the real service: a stream that ends late can't stop a
    /// newer session.
    private var session = 0

    // MARK: - Script

    /// Delivers `reading` to the running session. Ignored when stopped, like
    /// a real sensor that's switched off.
    func send(_ reading: HeadingReading) {
        continuation?.yield(reading)
    }

    // MARK: - HeadingService

    func start() -> AsyncStream<HeadingReading> {
        stop()

        startCount += 1
        session += 1
        let current = session
        isRunning = true

        let (stream, continuation) = AsyncStream<HeadingReading>.makeStream()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.stop(session: current) }
        }
        self.continuation = continuation
        return stream
    }

    func stop() {
        guard isRunning else { return }

        stopCount += 1
        isRunning = false
        session += 1

        let finished = continuation
        continuation = nil
        finished?.finish()
    }

    // MARK: - Session ending from the stream side

    private func stop(session ended: Int) {
        guard ended == session else { return }
        stop()
    }
}
