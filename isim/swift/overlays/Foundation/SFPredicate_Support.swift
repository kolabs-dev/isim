// isim: support for the Predicate sources vendored from swift-foundation (SFPredicate_*.swift, Apache License v2.0
// with Runtime Library Exception; see NOTICE): the small part of swift-foundation's LockedState they use.

struct LockedState<State>: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        let lock = NSLock()
        var state: State
        init(_ state: State) { self.state = state }
    }
    private let box: Box
    init(initialState: State) { box = Box(initialState) }
    func withLock<T>(_ body: (inout State) throws -> T) rethrows -> T {
        box.lock.lock(); defer { box.lock.unlock() }
        return try body(&box.state)
    }
}
