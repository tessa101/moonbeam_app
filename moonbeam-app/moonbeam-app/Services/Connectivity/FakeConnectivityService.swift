//
//  FakeConnectivityService.swift
//  moonbeam-app
//

import Foundation

#if DEBUG
/// Scriptable `ConnectivityService` for tests, previews and DEBUG screen
/// states: online unless told otherwise. `isOnline` changes reach every
/// open stream, as a real path change would.
final class FakeConnectivityService: ConnectivityService {

    var isOnline: Bool {
        didSet { continuations.values.forEach { $0.yield(isOnline) } }
    }

    /// How many streams are open now: a test can check the observation
    /// stops with the screen.
    var observerCount: Int { continuations.count }

    private var continuations: [Int: AsyncStream<Bool>.Continuation] = [:]
    private var nextID = 0

    init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }

    func pathUpdates() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let id = nextID
        nextID += 1
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        continuation.yield(isOnline)
        return stream
    }
}
#endif
