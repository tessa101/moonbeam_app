//
//  HeadingService.swift
//  moonbeam-app
//

import Foundation

/// Live true-north heading for the compass (COMPASS.md §1, §4).
///
/// True heading is only valid while location updates run, so a session always
/// drives both: `start()` begins heading *and* location updates, and `stop()`
/// ends both (COMPASS.md §1 Sensor lifecycle). Nothing here can leave one
/// running without the other.
///
/// Main-actor isolated, like `LocationService`: the implementation drives a
/// `CLLocationManager`, which delivers callbacks on the thread that made it.
///
/// Doesn't request permission. The compass only shows when location is
/// already authorized (COMPASS.md §2); without it, readings carry no true
/// heading and so read as low accuracy.
protocol HeadingService {

    /// True between `start()` and the session ending.
    var isRunning: Bool { get }

    /// Starts heading and location updates, and returns the readings.
    ///
    /// One session at a time: calling this while running ends the previous
    /// session's stream and starts a new one. With no compass hardware (the
    /// simulator), neither sensor starts and the stream yields a single
    /// `HeadingReading.unavailable`.
    ///
    /// The session also ends if the consumer stops iterating (for example,
    /// its task is cancelled) or drops the stream unread, so an abandoned
    /// stream never leaves the sensors on. Keep the stream until you're done.
    func start() -> AsyncStream<HeadingReading>

    /// Stops heading and location updates and finishes the stream. A no-op
    /// when not running.
    func stop()
}
