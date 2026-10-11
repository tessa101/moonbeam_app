//
//  ConnectivityService.swift
//  moonbeam-app
//

import Foundation

/// Whether the device has a network path, so city search can work
/// (STEP-5.10a-CHUNK-2C-OFFLINE-AND-COPY.md, item 2). A satisfied path
/// counts as online, however weak; recents work without one.
///
/// Observed only while a screen with a search action is up, so nothing
/// watches the network otherwise.
protocol ConnectivityService {

    /// The current state first, then every change: `true` when online. The
    /// observation ends when the consumer stops iterating (for example, its
    /// task is cancelled) or drops the stream.
    func pathUpdates() -> AsyncStream<Bool>
}
