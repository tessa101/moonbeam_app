//
//  NWPathMonitorConnectivityService.swift
//  moonbeam-app
//

import Foundation
import Network

/// `ConnectivityService` on Apple's Network framework: one `NWPathMonitor`
/// per stream, cancelled when the stream ends. A system framework, not a
/// third-party dependency (Chunk 2c, reversing 2b's "no connectivity
/// monitor" on purpose).
final class NWPathMonitorConnectivityService: ConnectivityService {

    /// Path events arrive here, off the main actor.
    private static let queueLabel = "moonbeam.connectivity"

    func pathUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue(label: Self.queueLabel))
        }
    }
}
