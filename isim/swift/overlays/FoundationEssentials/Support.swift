// isim: support for the Predicate sources vendored from swift-foundation (FoundationEssentials/*.swift and
// Foundation/SFPredicate_*.swift, Apache License v2.0 with Runtime Library Exception; see NOTICE): the small part of
// swift-foundation's LockedState they use. Foundation is not available here (it imports this module), so a pthread mutex.
import Darwin

struct LockedState<State>: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        var state: State
        init(_ state: State) { self.state = state; pthread_mutex_init(mutex, nil) }
        deinit { pthread_mutex_destroy(mutex); mutex.deallocate() }
    }
    private let box: Box
    init(initialState: State) { box = Box(initialState) }
    func withLock<T>(_ body: (inout State) throws -> T) rethrows -> T {
        pthread_mutex_lock(box.mutex); defer { pthread_mutex_unlock(box.mutex) }
        return try body(&box.state)
    }
}

/// Captured values whose type lives in Foundation (Date, Data, UUID) describe themselves in a Predicate's description.
@_spi(ISIMFoundation) public protocol _PredicateCaptureDescribable {
    var _predicateCaptureDescription: String { get }
}
