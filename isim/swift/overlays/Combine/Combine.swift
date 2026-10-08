// isim Combine: an independent implementation of a Combine subset (Combine is closed source).
// Publishers, subscribers with demand, subjects, common operators, @Published and ObservableObject.
// Not Apple's Combine; see docs/COVERAGE.md for the supported API.
// Like Apple's, this module does not depend on Foundation; Foundation re-exports it and adds the
// Foundation publishers and schedulers (Timer.publish, NotificationCenter.publisher, RunLoop, DispatchQueue).
import Darwin

/// A mutex (optionally recursive) for the subjects and subscriptions.
final class _CombineLock: @unchecked Sendable {
    private let m = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    init(recursive: Bool = false) {
        var a = pthread_mutexattr_t()
        pthread_mutexattr_init(&a)
        if recursive { pthread_mutexattr_settype(&a, Int32(PTHREAD_MUTEX_RECURSIVE)) }
        pthread_mutex_init(m, &a)
        pthread_mutexattr_destroy(&a)
    }
    deinit { pthread_mutex_destroy(m); m.deallocate() }
    func lock() { pthread_mutex_lock(m) }
    func unlock() { pthread_mutex_unlock(m) }
}

// MARK: - Core protocols

public protocol Cancellable {
    func cancel()
}

public struct CombineIdentifier: Hashable, CustomStringConvertible, Sendable {
    let value: UInt64
    private static let lock = _CombineLock()
    nonisolated(unsafe) private static var next: UInt64 = 0
    public init() {
        CombineIdentifier.lock.lock(); CombineIdentifier.next += 1; value = CombineIdentifier.next; CombineIdentifier.lock.unlock()
    }
    public init(_ obj: AnyObject) { value = UInt64(UInt(bitPattern: ObjectIdentifier(obj).hashValue)) }
    public var description: String { "0x\(String(value, radix: 16))" }
}

public protocol CustomCombineIdentifierConvertible {
    var combineIdentifier: CombineIdentifier { get }
}
extension CustomCombineIdentifierConvertible where Self: AnyObject {
    public var combineIdentifier: CombineIdentifier { CombineIdentifier(self) }
}

public enum Subscribers {}

extension Subscribers {
    public struct Demand: Equatable, Comparable, Hashable, Sendable, CustomStringConvertible {
        let raw: Int?            // nil = unlimited
        public static let unlimited = Demand(raw: nil)
        public static let none = Demand(raw: 0)
        public static func max(_ value: Int) -> Demand { Demand(raw: value) }
        public var max: Int? { raw }
        public var description: String { raw.map { "max(\($0))" } ?? "unlimited" }
        public static func + (a: Demand, b: Demand) -> Demand {
            guard let x = a.raw, let y = b.raw else { return .unlimited }
            return Demand(raw: x + y)
        }
        public static func + (a: Demand, b: Int) -> Demand { a + .max(b) }
        public static func += (a: inout Demand, b: Demand) { a = a + b }
        public static func += (a: inout Demand, b: Int) { a = a + b }
        public static func - (a: Demand, b: Int) -> Demand { a.raw.map { Demand(raw: Swift.max(0, $0 - b)) } ?? a }
        public static func -= (a: inout Demand, b: Int) { a = a - b }
        public static func < (a: Demand, b: Demand) -> Bool {
            switch (a.raw, b.raw) {
            case (nil, _): return false
            case (_, nil): return true
            case let (x?, y?): return x < y
            }
        }
        public static func > (a: Demand, b: Int) -> Bool { a.raw.map { $0 > b } ?? true }
        public static func == (a: Demand, b: Int) -> Bool { a.raw == b }
    }

    @frozen public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
extension Subscribers.Completion: Equatable where Failure: Equatable {}
extension Subscribers.Completion: Sendable where Failure: Sendable {}

public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {
    func request(_ demand: Subscribers.Demand)
}

public protocol Subscriber<Input, Failure>: CustomCombineIdentifierConvertible {
    associatedtype Input
    associatedtype Failure: Error
    func receive(subscription: Subscription)
    func receive(_ input: Input) -> Subscribers.Demand
    func receive(completion: Subscribers.Completion<Failure>)
}

public protocol Publisher<Output, Failure> {
    associatedtype Output
    associatedtype Failure: Error
    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure
}

extension Publisher {
    public func subscribe<S: Subscriber>(_ subscriber: S) where S.Input == Output, S.Failure == Failure {
        receive(subscriber: subscriber)
    }
}

public enum Subscriptions {
    public static var empty: Subscription { _EmptySubscription() }
}
final class _EmptySubscription: Subscription {
    func request(_ demand: Subscribers.Demand) {}
    func cancel() {}
}

// MARK: - AnyCancellable

public final class AnyCancellable: Cancellable, Hashable {
    private var action: (() -> Void)?
    public init(_ cancel: @escaping () -> Void) { action = cancel }
    public init<C: Cancellable>(_ canceller: C) { action = { canceller.cancel() } }
    deinit { action?() }
    public func cancel() { let a = action; action = nil; a?() }
    public func store(in set: inout Set<AnyCancellable>) { set.insert(self) }
    public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == AnyCancellable { collection.append(self) }
    public static func == (a: AnyCancellable, b: AnyCancellable) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}
extension Cancellable {
    public func store(in set: inout Set<AnyCancellable>) { AnyCancellable(self).store(in: &set) }
    public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == AnyCancellable { collection.append(AnyCancellable(self)) }
}

// MARK: - Subscribers.Sink / Assign

extension Subscribers {
    public final class Sink<Input, Failure: Error>: Subscriber, Cancellable {
        public let receiveValue: (Input) -> Void
        public let receiveCompletion: (Subscribers.Completion<Failure>) -> Void
        private var subscription: Subscription?
        private var done = false
        public init(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void, receiveValue: @escaping (Input) -> Void) {
            self.receiveCompletion = receiveCompletion; self.receiveValue = receiveValue
        }
        public func receive(subscription: Subscription) {
            guard self.subscription == nil, !done else { subscription.cancel(); return }
            self.subscription = subscription
            subscription.request(.unlimited)
        }
        public func receive(_ value: Input) -> Subscribers.Demand { if !done { receiveValue(value) }; return .none }
        public func receive(completion: Subscribers.Completion<Failure>) {
            guard !done else { return }
            done = true; subscription = nil
            receiveCompletion(completion)
        }
        public func cancel() { done = true; let s = subscription; subscription = nil; s?.cancel() }
    }

    public final class Assign<Root, Input>: Subscriber, Cancellable {
        public typealias Failure = Never
        public private(set) var object: Root?
        public let keyPath: ReferenceWritableKeyPath<Root, Input>
        private var subscription: Subscription?
        public init(object: Root, keyPath: ReferenceWritableKeyPath<Root, Input>) { self.object = object; self.keyPath = keyPath }
        public func receive(subscription: Subscription) { self.subscription = subscription; subscription.request(.unlimited) }
        public func receive(_ value: Input) -> Subscribers.Demand { object?[keyPath: keyPath] = value; return .none }
        public func receive(completion: Subscribers.Completion<Never>) { object = nil; subscription = nil }
        public func cancel() { let s = subscription; subscription = nil; object = nil; s?.cancel() }
    }
}

extension Publisher {
    public func sink(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
                     receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        let s = Subscribers.Sink<Output, Failure>(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
        subscribe(s)
        return AnyCancellable(s)
    }
}
extension Publisher where Failure == Never {
    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        sink(receiveCompletion: { _ in }, receiveValue: receiveValue)
    }
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on object: Root) -> AnyCancellable {
        let s = Subscribers.Assign(object: object, keyPath: keyPath)
        subscribe(s)
        return AnyCancellable(s)
    }
    public func assign(to published: inout Published<Output>.Publisher) {
        let subject = published.subject
        subscribe(_ClosureSubscriber<Output, Never>(value: { subject.send($0) }, completion: { _ in }))
    }
}

/// Internal building block: a subscriber driven by closures, requesting unlimited demand.
final class _ClosureSubscriber<Input, Failure: Error>: Subscriber, Cancellable {
    let value: (Input) -> Void
    let completion: (Subscribers.Completion<Failure>) -> Void
    var subscription: Subscription?
    var onSubscribe: ((Subscription) -> Void)?
    init(value: @escaping (Input) -> Void, completion: @escaping (Subscribers.Completion<Failure>) -> Void) {
        self.value = value; self.completion = completion
    }
    func receive(subscription: Subscription) {
        self.subscription = subscription
        if let f = onSubscribe { f(subscription) } else { subscription.request(.unlimited) }
    }
    func receive(_ input: Input) -> Subscribers.Demand { value(input); return .none }
    func receive(completion c: Subscribers.Completion<Failure>) { subscription = nil; completion(c) }
    func cancel() { let s = subscription; subscription = nil; s?.cancel() }
}

/// A subscription whose values are pushed by the owner; buffers nothing, honours demand by dropping.
final class _ForwardingSubscription<S: Subscriber>: Subscription {
    var downstream: S?
    var demand: Subscribers.Demand = .none
    let onCancel: () -> Void
    init(_ s: S, onCancel: @escaping () -> Void = {}) { downstream = s; self.onCancel = onCancel }
    func request(_ d: Subscribers.Demand) { demand += d }
    func cancel() { if downstream != nil { downstream = nil; onCancel() } }
    func send(_ v: S.Input) {
        guard let s = downstream, demand > 0 else { return }
        demand -= 1
        demand += s.receive(v)
    }
    func finish(_ c: Subscribers.Completion<S.Failure>) { let s = downstream; downstream = nil; s?.receive(completion: c) }
}

/// Operators: subscribe upstream with a closure subscriber that forwards to a downstream subscription.
func _relay<Upstream: Publisher, S: Subscriber>(_ upstream: Upstream, to subscriber: S,
    value: @escaping (Upstream.Output, @escaping (S.Input) -> Void, @escaping (Subscribers.Completion<S.Failure>) -> Void) -> Void,
    completion: @escaping (Subscribers.Completion<Upstream.Failure>, @escaping (Subscribers.Completion<S.Failure>) -> Void) -> Void) {
    var up: _ClosureSubscriber<Upstream.Output, Upstream.Failure>!
    let sub = _ForwardingSubscription(subscriber, onCancel: { up?.cancel() })
    up = _ClosureSubscriber(value: { v in value(v, { sub.send($0) }, { sub.finish($0) }) },
                            completion: { c in completion(c, { sub.finish($0) }) })
    subscriber.receive(subscription: sub)
    upstream.subscribe(up)
}

/// A mutable reference used by operator closures.
final class _Ref<T> { var value: T; init(_ v: T) { value = v } }

// MARK: - AnyPublisher

public struct AnyPublisher<Output, Failure: Error>: Publisher, CustomStringConvertible {
    let subscribeImpl: (AnySubscriber<Output, Failure>) -> Void
    public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
        subscribeImpl = { publisher.subscribe($0) }
    }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        subscribeImpl(AnySubscriber(subscriber))
    }
    public var description: String { "AnyPublisher" }
}
extension Publisher {
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> { AnyPublisher(self) }
}

public struct AnySubscriber<Input, Failure: Error>: Subscriber {
    public let combineIdentifier: CombineIdentifier
    let subscriptionImpl: (Subscription) -> Void
    let valueImpl: (Input) -> Subscribers.Demand
    let completionImpl: (Subscribers.Completion<Failure>) -> Void
    public init<S: Subscriber>(_ s: S) where S.Input == Input, S.Failure == Failure {
        combineIdentifier = s.combineIdentifier
        subscriptionImpl = s.receive(subscription:); valueImpl = s.receive(_:); completionImpl = s.receive(completion:)
    }
    public init(receiveSubscription: ((Subscription) -> Void)? = nil, receiveValue: ((Input) -> Subscribers.Demand)? = nil,
                receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil) {
        combineIdentifier = CombineIdentifier()
        subscriptionImpl = receiveSubscription ?? { _ in }
        valueImpl = receiveValue ?? { _ in .none }
        completionImpl = receiveCompletion ?? { _ in }
    }
    public func receive(subscription: Subscription) { subscriptionImpl(subscription) }
    public func receive(_ input: Input) -> Subscribers.Demand { valueImpl(input) }
    public func receive(completion: Subscribers.Completion<Failure>) { completionImpl(completion) }
}

// MARK: - Subjects

public protocol Subject<Output, Failure>: AnyObject, Publisher {
    func send(_ value: Output)
    func send(completion: Subscribers.Completion<Failure>)
    func send(subscription: Subscription)
}
extension Subject where Output == Void {
    public func send() { send(()) }
}

/// Shared subscriber bookkeeping for subjects.
final class _SubjectCore<Output, Failure: Error> {
    final class Conduit: Subscription {
        var demand: Subscribers.Demand = .none
        weak var core: _SubjectCore?
        var active = true
        let subscriber: AnySubscriber<Output, Failure>
        init<S: Subscriber>(_ s: S, core: _SubjectCore) where S.Input == Output, S.Failure == Failure {
            self.core = core
            subscriber = AnySubscriber(s)
        }
        func deliver(_ v: Output) {
            guard active, demand > 0 else { return }
            demand -= 1
            demand += subscriber.receive(v)
        }
        func request(_ d: Subscribers.Demand) { demand += d }
        func cancel() { active = false; core?.remove(self) }
    }
    let lock = _CombineLock(recursive: true)
    var conduits: [Conduit] = []
    var completion: Subscribers.Completion<Failure>?
    func add<S: Subscriber>(_ s: S, initial: ((Conduit) -> Void)? = nil) where S.Input == Output, S.Failure == Failure {
        lock.lock()
        if let c = completion {
            lock.unlock()
            s.receive(subscription: Subscriptions.empty)
            s.receive(completion: c)
            return
        }
        let conduit = Conduit(s, core: self)
        conduits.append(conduit)
        lock.unlock()
        s.receive(subscription: conduit)
        initial?(conduit)
    }
    func remove(_ c: Conduit) { lock.lock(); conduits.removeAll { $0 === c }; lock.unlock() }
    func send(_ v: Output) {
        lock.lock(); let list = completion == nil ? conduits : []; lock.unlock()
        for c in list { c.deliver(v) }
    }
    func finish(_ c: Subscribers.Completion<Failure>) {
        lock.lock()
        guard completion == nil else { lock.unlock(); return }
        completion = c
        let list = conduits; conduits = []
        lock.unlock()
        for x in list where x.active { x.active = false; x.subscriber.receive(completion: c) }
    }
}

public final class PassthroughSubject<Output, Failure: Error>: Subject {
    let core = _SubjectCore<Output, Failure>()
    public init() {}
    public func send(_ value: Output) { core.send(value) }
    public func send(completion: Subscribers.Completion<Failure>) { core.finish(completion) }
    public func send(subscription: Subscription) { subscription.request(.unlimited) }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure { core.add(subscriber) }
}

public final class CurrentValueSubject<Output, Failure: Error>: Subject {
    let core = _SubjectCore<Output, Failure>()
    private var current: Output
    public init(_ value: Output) { current = value }
    public var value: Output {
        get { current }
        set { send(newValue) }
    }
    public func send(_ value: Output) { current = value; core.send(value) }
    public func send(completion: Subscribers.Completion<Failure>) { core.finish(completion) }
    public func send(subscription: Subscription) { subscription.request(.unlimited) }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        core.add(subscriber) { [unowned self] conduit in
            // the current value goes out once demand arrives (the subscriber requested it in receive(subscription:))
            conduit.deliver(self.current)
        }
    }
}

// MARK: - Basic publishers

public struct Just<Output>: Publisher {
    public typealias Failure = Never
    public let output: Output
    public init(_ output: Output) { self.output = output }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
        let sub = _Outlet(subscriber); sub.name = "Just"
        subscriber.receive(subscription: sub)
        sub.send(output)
        sub.finish(.finished)
    }
}

public struct Empty<Output, Failure: Error>: Publisher {
    public let completeImmediately: Bool
    public init(completeImmediately: Bool = true) { self.completeImmediately = completeImmediately }
    public init(completeImmediately: Bool = true, outputType: Output.Type, failureType: Failure.Type) { self.completeImmediately = completeImmediately }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        subscriber.receive(subscription: Subscriptions.empty)
        if completeImmediately { subscriber.receive(completion: .finished) }
    }
}

public struct Fail<Output, Failure: Error>: Publisher {
    public let error: Failure
    public init(error: Failure) { self.error = error }
    public init(outputType: Output.Type, failure: Failure) { error = failure }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        subscriber.receive(subscription: Subscriptions.empty)
        subscriber.receive(completion: .failure(error))
    }
}

public final class Future<Output, Failure: Error>: Publisher {
    public typealias Promise = (Result<Output, Failure>) -> Void
    private let core = _SubjectCore<Output, Failure>()
    private var result: Result<Output, Failure>?
    private let lock = _CombineLock()
    public init(_ attemptToFulfill: @escaping (@escaping Promise) -> Void) {
        attemptToFulfill { [weak self] r in self?.fulfill(r) }
    }
    private func fulfill(_ r: Result<Output, Failure>) {
        lock.lock(); guard result == nil else { lock.unlock(); return }; result = r; lock.unlock()
        switch r {
        case .success(let v): core.send(v); core.finish(.finished)
        case .failure(let e): core.finish(.failure(e))
        }
    }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        lock.lock(); let r = result; lock.unlock()
        if let r {
            let sub = _ForwardingSubscription(subscriber)
            subscriber.receive(subscription: sub)
            switch r {
            case .success(let v): sub.send(v); sub.finish(.finished)
            case .failure(let e): sub.finish(.failure(e))
            }
        } else {
            core.add(subscriber)
        }
    }
}

public struct Deferred<DeferredPublisher: Publisher>: Publisher {
    public typealias Output = DeferredPublisher.Output
    public typealias Failure = DeferredPublisher.Failure
    public let createPublisher: () -> DeferredPublisher
    public init(createPublisher: @escaping () -> DeferredPublisher) { self.createPublisher = createPublisher }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        createPublisher().subscribe(subscriber)
    }
}

extension Sequence {
    public var publisher: Publishers.Sequence<Self, Never> { Publishers.Sequence(sequence: self) }
}
extension Optional {
    public var publisher: Optional.Publisher { Optional.Publisher(self) }
    public struct Publisher: Combine.Publisher {
        public typealias Output = Wrapped
        public typealias Failure = Never
        public let output: Wrapped?
        public init(_ output: Wrapped?) { self.output = output }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Wrapped, S.Failure == Never {
            let sub = _ForwardingSubscription(subscriber)
            subscriber.receive(subscription: sub)
            if let o = output { sub.send(o) }
            sub.finish(.finished)
        }
    }
}

// MARK: - Operators

public enum Publishers {}

/// Emits a sequence's elements lazily as the subscriber requests them (infinite sequences work).
final class _SequenceSubscription<S: Subscriber, I: IteratorProtocol>: Subscription, CustomStringConvertible where I.Element == S.Input {
    private let lock = _CombineLock(recursive: true)
    private var downstream: S?
    private var iterator: I
    private var lookahead: I.Element?
    private var demand: Subscribers.Demand = .none
    private var emitting = false
    private var started = false
    init(_ s: S, _ it: I) { downstream = s; iterator = it }
    var description: String { "Sequence" }
    func start() { lock.lock(); started = true; lock.unlock(); emit() }
    func request(_ d: Subscribers.Demand) { lock.lock(); demand += d; lock.unlock(); emit() }
    func cancel() { lock.lock(); downstream = nil; lock.unlock() }
    private func nextElement() -> I.Element? {
        if let l = lookahead { lookahead = nil; return l }
        return iterator.next()
    }
    private func emit() {
        lock.lock()
        guard started, !emitting else { lock.unlock(); return }
        emitting = true
        while let s = downstream {
            if demand > 0 {
                guard let v = nextElement() else {
                    downstream = nil; lock.unlock()
                    s.receive(completion: .finished)
                    lock.lock(); break
                }
                demand -= 1
                lock.unlock()
                let more = s.receive(v)
                lock.lock()
                demand += more
                continue
            }
            // no demand: finish now if the sequence is exhausted (like Apple's, completion needs no demand)
            if lookahead == nil { lookahead = iterator.next() }
            if lookahead == nil { downstream = nil; lock.unlock(); s.receive(completion: .finished); lock.lock() }
            break
        }
        emitting = false
        lock.unlock()
    }
}

extension Publishers {
    public struct Sequence<Elements: Swift.Sequence, Failure: Error>: Publisher {
        public typealias Output = Elements.Element
        public let sequence: Elements
        public init(sequence: Elements) { self.sequence = sequence }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sub = _SequenceSubscription(subscriber, sequence.makeIterator())
            subscriber.receive(subscription: sub)
            sub.start()
        }
    }

    public struct Map<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let transform: (Upstream.Output) -> Output
        public init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Output) { self.upstream = upstream; self.transform = transform }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let t = transform
            _relay(upstream, to: subscriber, value: { v, send, _ in send(t(v)) }, completion: { c, finish in finish(c) })
        }
    }

    public struct TryMap<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Error
        public let upstream: Upstream
        public let transform: (Upstream.Output) throws -> Output
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let t = transform
            _relay(upstream, to: subscriber, value: { v, send, finish in
                do { send(try t(v)) } catch { finish(.failure(error)) }
            }, completion: { c, finish in
                switch c { case .finished: finish(.finished); case .failure(let e): finish(.failure(e)) }
            })
        }
    }

    public struct CompactMap<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let transform: (Upstream.Output) -> Output?
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let t = transform
            _relay(upstream, to: subscriber, value: { v, send, _ in if let o = t(v) { send(o) } }, completion: { c, finish in finish(c) })
        }
    }

    public struct Filter<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let isIncluded: (Upstream.Output) -> Bool
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let f = isIncluded
            _relay(upstream, to: subscriber, value: { v, send, _ in if f(v) { send(v) } }, completion: { c, finish in finish(c) })
        }
    }

    public struct RemoveDuplicates<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Output, Output) -> Bool
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let p = predicate
            let last = _Ref<Output?>(nil)
            _relay(upstream, to: subscriber, value: { v, send, _ in
                if let l = last.value, p(l, v) { return }
                last.value = v
                send(v)
            }, completion: { c, finish in finish(c) })
        }
    }

    public struct Drop<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let count: Int
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let c = _Ref(0), limit = count
            _relay(upstream, to: subscriber, value: { v, send, _ in
                if c.value < limit { c.value += 1 } else { send(v) }
            }, completion: { x, finish in finish(x) })
        }
    }

    public struct Output<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let range: Range<Int>
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Upstream.Output, S.Failure == Failure {
            let c = _Ref(0), r = range
            _relay(upstream, to: subscriber, value: { v, send, finish in
                if r.contains(c.value) { send(v) }
                c.value += 1
                if c.value >= r.upperBound { finish(.finished) }
            }, completion: { x, finish in finish(x) })
        }
    }

    public struct HandleEvents<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public var receiveOutput: ((Output) -> Void)?
        public var receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?
        public var receiveSubscription: ((Subscription) -> Void)? = nil
        public var receiveCancel: (() -> Void)? = nil
        public var receiveRequest: ((Subscribers.Demand) -> Void)? = nil
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            upstream.subscribe(_ProxySubscriber(subscriber, onSubscription: receiveSubscription, onValue: receiveOutput,
                                                onCompletion: receiveCompletion, onRequest: receiveRequest, onCancel: receiveCancel))
        }
    }

    public struct SetFailureType<Upstream: Publisher, Failure: Error>: Publisher where Upstream.Failure == Never {
        public typealias Output = Upstream.Output
        public let upstream: Upstream
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            _relay(upstream, to: subscriber, value: { v, send, _ in send(v) }, completion: { _, finish in finish(.finished) })
        }
    }

    /// Delivers values and completion on a scheduler (DispatchQueue, RunLoop, OperationQueue, ImmediateScheduler).
    public struct ReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let scheduler: Context
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch = scheduler
            _relay(upstream, to: subscriber, value: { v, send, _ in sch.schedule { send(v) } },
                   completion: { c, finish in sch.schedule { finish(c) } })
        }
    }

    /// Emits the latest value after `dueTime` without new values.
    public struct Debounce<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let dueTime: Context.SchedulerTimeType.Stride
        public let scheduler: Context
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let g = _Ref(0), sch = scheduler, due = dueTime
            _relay(upstream, to: subscriber, value: { v, send, _ in
                g.value += 1
                let mine = g.value
                sch.schedule(after: sch.now.advanced(by: due), tolerance: sch.minimumTolerance, options: nil) {
                    if g.value == mine { send(v) }
                }
            }, completion: { c, finish in finish(c) })
        }
    }

    /// Combines the latest values of two publishers once both have produced one.
    public struct CombineLatest<A: Publisher, B: Publisher>: Publisher where A.Failure == B.Failure {
        public typealias Output = (A.Output, B.Output)
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let st = _Ref((a: A.Output?.none, b: B.Output?.none, done: 0))
            let sub = _ForwardingSubscription(subscriber)
            var subs: [Cancellable] = []
            let sa = _ClosureSubscriber<A.Output, A.Failure>(value: { v in st.value.a = v; if let y = st.value.b { sub.send((v, y)) } },
                completion: { c in if case .failure = c { sub.finish(c) } else { st.value.done += 1; if st.value.done == 2 { sub.finish(.finished) } } })
            let sb = _ClosureSubscriber<B.Output, B.Failure>(value: { v in st.value.b = v; if let x = st.value.a { sub.send((x, v)) } },
                completion: { c in if case .failure(let e) = c { sub.finish(.failure(e)) } else { st.value.done += 1; if st.value.done == 2 { sub.finish(.finished) } } })
            subs = [sa, sb]
            _ = subs
            subscriber.receive(subscription: sub)
            a.subscribe(sa); b.subscribe(sb)
        }
    }

    public struct Merge<A: Publisher, B: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure {
        public typealias Output = A.Output
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public init(_ a: A, _ b: B) { self.a = a; self.b = b }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let st = _Ref((a: 0, b: 0, done: 0))
            let sub = _ForwardingSubscription(subscriber)
            let sa = _ClosureSubscriber<A.Output, A.Failure>(value: { sub.send($0) },
                completion: { c in if case .failure = c { sub.finish(c) } else { st.value.done += 1; if st.value.done == 2 { sub.finish(.finished) } } })
            let sb = _ClosureSubscriber<B.Output, B.Failure>(value: { sub.send($0) },
                completion: { c in if case .failure(let e) = c { sub.finish(.failure(e)) } else { st.value.done += 1; if st.value.done == 2 { sub.finish(.finished) } } })
            subscriber.receive(subscription: sub)
            a.subscribe(sa); b.subscribe(sb)
        }
    }

    public struct FlatMap<NewPublisher: Publisher, Upstream: Publisher>: Publisher where NewPublisher.Failure == Upstream.Failure {
        public typealias Output = NewPublisher.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let transform: (Upstream.Output) -> NewPublisher
        /// At most this many inner publishers are subscribed at once; later upstream values wait their turn.
        public var maxPublishers: Subscribers.Demand = .unlimited
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let t = transform, limit = maxPublishers
            let lock = _CombineLock(recursive: true)
            let st = _Ref((active: 0, waiting: [Upstream.Output](), outerDone: false, inner: [ObjectIdentifier: Cancellable]()))
            func start(_ v: Upstream.Output, _ o: _Outlet<S>) {
                let idBox = _Ref<ObjectIdentifier?>(nil)
                let inner = _ClosureSubscriber<NewPublisher.Output, NewPublisher.Failure>(value: { o.send($0) }, completion: { c in
                    if case .failure = c { o.terminate(c); return }
                    lock.lock()
                    if let id = idBox.value { st.value.inner[id] = nil }
                    st.value.active -= 1
                    var next: Upstream.Output? = nil
                    if !st.value.waiting.isEmpty { next = st.value.waiting.removeFirst(); st.value.active += 1 }
                    let done = st.value.outerDone && st.value.active == 0
                    lock.unlock()
                    if let next { start(next, o) } else if done { o.finish(.finished) }
                })
                idBox.value = ObjectIdentifier(inner)
                lock.lock(); st.value.inner[ObjectIdentifier(inner)] = inner; lock.unlock()
                t(v).subscribe(inner)
            }
            let out = _operator(upstream, subscriber, name: "FlatMap", value: { v, o in
                lock.lock()
                if limit > st.value.active { st.value.active += 1; lock.unlock(); start(v, o) }
                else { st.value.waiting.append(v); lock.unlock() }
            }, completion: { c, o in
                if case .failure = c { o.terminate(c); return }
                lock.lock(); st.value.outerDone = true; let done = st.value.active == 0; lock.unlock()
                if done { o.finish(.finished) }
            })
            let prev = out.onCancel
            out.onCancel = { prev?(); lock.lock(); let all = Array(st.value.inner.values); st.value.inner = [:]; lock.unlock(); for c in all { c.cancel() } }
        }
    }

    /// Shares one upstream subscription among subscribers.
    public final class Share<Upstream: Publisher>: Publisher, Equatable {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        private let subject = PassthroughSubject<Output, Failure>()
        private var connection: Cancellable?
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            subject.receive(subscriber: subscriber)
            if connection == nil {
                let subj = subject
                let s = _ClosureSubscriber<Output, Failure>(value: { subj.send($0) }, completion: { subj.send(completion: $0) })
                connection = s
                upstream.subscribe(s)
            }
        }
        public static func == (a: Share, b: Share) -> Bool { a === b }
    }

    public final class Autoconnect<Upstream: ConnectablePublisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        private var connection: Cancellable?
        private var count = 0
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            count += 1
            // the subscription keeps the publisher (and its connection) alive until it is cancelled
            let wrapped = _AutoconnectSubscriber(subscriber, onCancel: {
                self.count -= 1
                if self.count == 0 { self.connection?.cancel(); self.connection = nil }
            })
            upstream.subscribe(wrapped)
            if connection == nil { connection = upstream.connect() }
        }
    }
}

final class _AutoconnectSubscriber<S: Subscriber>: Subscriber {
    let downstream: S
    let onCancel: () -> Void
    init(_ s: S, onCancel: @escaping () -> Void) { downstream = s; self.onCancel = onCancel }
    func receive(subscription: Subscription) { downstream.receive(subscription: _CancelHook(subscription, onCancel)) }
    func receive(_ input: S.Input) -> Subscribers.Demand { downstream.receive(input) }
    func receive(completion: Subscribers.Completion<S.Failure>) { downstream.receive(completion: completion) }
}
final class _CancelHook: Subscription {
    let inner: Subscription; let hook: () -> Void
    init(_ inner: Subscription, _ hook: @escaping () -> Void) { self.inner = inner; self.hook = hook }
    func request(_ d: Subscribers.Demand) { inner.request(d) }
    func cancel() { inner.cancel(); hook() }
}

extension Publisher {
    public func map<T>(_ transform: @escaping (Output) -> T) -> Publishers.Map<Self, T> { Publishers.Map(upstream: self, transform: transform) }
    public func map<T>(_ keyPath: KeyPath<Output, T>) -> Publishers.Map<Self, T> { Publishers.Map(upstream: self) { $0[keyPath: keyPath] } }
    public func tryMap<T>(_ transform: @escaping (Output) throws -> T) -> Publishers.TryMap<Self, T> { Publishers.TryMap(upstream: self, transform: transform) }
    public func compactMap<T>(_ transform: @escaping (Output) -> T?) -> Publishers.CompactMap<Self, T> { Publishers.CompactMap(upstream: self, transform: transform) }
    public func filter(_ isIncluded: @escaping (Output) -> Bool) -> Publishers.Filter<Self> { Publishers.Filter(upstream: self, isIncluded: isIncluded) }
    public func removeDuplicates(by predicate: @escaping (Output, Output) -> Bool) -> Publishers.RemoveDuplicates<Self> {
        Publishers.RemoveDuplicates(upstream: self, predicate: predicate)
    }
    public func dropFirst(_ count: Int = 1) -> Publishers.Drop<Self> { Publishers.Drop(upstream: self, count: count) }
    public func prefix(_ maxLength: Int) -> Publishers.Output<Self> { Publishers.Output(upstream: self, range: 0..<maxLength) }
    public func first() -> Publishers.Output<Self> { prefix(1) }
    public func handleEvents(receiveSubscription: ((Subscription) -> Void)? = nil, receiveOutput: ((Output) -> Void)? = nil,
                             receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
                             receiveCancel: (() -> Void)? = nil, receiveRequest: ((Subscribers.Demand) -> Void)? = nil) -> Publishers.HandleEvents<Self> {
        Publishers.HandleEvents(upstream: self, receiveOutput: receiveOutput, receiveCompletion: receiveCompletion,
                                receiveSubscription: receiveSubscription, receiveCancel: receiveCancel, receiveRequest: receiveRequest)
    }
    public func receive<S: Scheduler>(on scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.ReceiveOn<Self, S> {
        Publishers.ReceiveOn(upstream: self, scheduler: scheduler)
    }
    public func debounce<S: Scheduler>(for dueTime: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.Debounce<Self, S> {
        Publishers.Debounce(upstream: self, dueTime: dueTime, scheduler: scheduler)
    }
    public func combineLatest<P: Publisher>(_ other: P) -> Publishers.CombineLatest<Self, P> where P.Failure == Failure {
        Publishers.CombineLatest(a: self, b: other)
    }
    public func merge<P: Publisher>(with other: P) -> Publishers.Merge<Self, P> where P.Output == Output, P.Failure == Failure {
        Publishers.Merge(self, other)
    }
    @_disfavoredOverload   // kept for binary compatibility; the maxPublishers form below is Apple's
    public func flatMap<P: Publisher>(_ transform: @escaping (Output) -> P) -> Publishers.FlatMap<P, Self> where P.Failure == Failure {
        Publishers.FlatMap(upstream: self, transform: transform)
    }
    public func flatMap<P: Publisher>(maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P) -> Publishers.FlatMap<P, Self> where P.Failure == Failure {
        Publishers.FlatMap(upstream: self, transform: transform, maxPublishers: maxPublishers)
    }
    public func share() -> Publishers.Share<Self> { Publishers.Share(upstream: self) }
}
extension Publisher where Output: Equatable {
    public func removeDuplicates() -> Publishers.RemoveDuplicates<Self> { removeDuplicates(by: ==) }
}
extension Publisher where Failure == Never {
    public func setFailureType<E: Error>(to failureType: E.Type) -> Publishers.SetFailureType<Self, E> { Publishers.SetFailureType(upstream: self) }
}

// MARK: - Connectable

public protocol ConnectablePublisher: Publisher {
    func connect() -> Cancellable
}
extension ConnectablePublisher {
    public func autoconnect() -> Publishers.Autoconnect<Self> { Publishers.Autoconnect(upstream: self) }
}

// MARK: - Schedulers

public protocol SchedulerTimeIntervalConvertible {
    static func seconds(_ s: Int) -> Self
    static func seconds(_ s: Double) -> Self
    static func milliseconds(_ ms: Int) -> Self
    static func microseconds(_ us: Int) -> Self
    static func nanoseconds(_ ns: Int) -> Self
}

public protocol Scheduler<SchedulerTimeType> {
    associatedtype SchedulerTimeType: Strideable where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
    associatedtype SchedulerOptions
    var now: SchedulerTimeType { get }
    var minimumTolerance: SchedulerTimeType.Stride { get }
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)
    func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void)
}
extension Scheduler {
    public func schedule(_ action: @escaping () -> Void) { schedule(options: nil, action) }
}

public struct ImmediateScheduler: Scheduler {
    public struct SchedulerTimeType: Strideable {
        public struct Stride: SchedulerTimeIntervalConvertible, Comparable, SignedNumeric, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
            public var magnitude: Int
            public init(_ v: Int) { magnitude = v }
            public init(integerLiteral v: Int) { magnitude = v }
            public init(floatLiteral v: Double) { magnitude = Int(v) }
            public init?<T: BinaryInteger>(exactly s: T) { magnitude = Int(s) }
            public static func seconds(_ s: Int) -> Stride { Stride(0) }
            public static func seconds(_ s: Double) -> Stride { Stride(0) }
            public static func milliseconds(_ ms: Int) -> Stride { Stride(0) }
            public static func microseconds(_ us: Int) -> Stride { Stride(0) }
            public static func nanoseconds(_ ns: Int) -> Stride { Stride(0) }
            public static func < (a: Stride, b: Stride) -> Bool { a.magnitude < b.magnitude }
            public static func + (a: Stride, b: Stride) -> Stride { Stride(a.magnitude + b.magnitude) }
            public static func - (a: Stride, b: Stride) -> Stride { Stride(a.magnitude - b.magnitude) }
            public static func * (a: Stride, b: Stride) -> Stride { Stride(a.magnitude * b.magnitude) }
            public static func += (a: inout Stride, b: Stride) { a = a + b }
            public static func -= (a: inout Stride, b: Stride) { a = a - b }
            public static func *= (a: inout Stride, b: Stride) { a = a * b }
        }
        public func distance(to other: SchedulerTimeType) -> Stride { Stride(0) }
        public func advanced(by n: Stride) -> SchedulerTimeType { self }
    }
    public typealias SchedulerOptions = Never
    public static let shared = ImmediateScheduler()
    public var now: SchedulerTimeType { SchedulerTimeType() }
    public var minimumTolerance: SchedulerTimeType.Stride { 0 }
    public func schedule(options: Never?, _ action: @escaping () -> Void) { action() }
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: Never?, _ action: @escaping () -> Void) { action() }
}

// MARK: - ObservableObject and @Published

public final class ObservableObjectPublisher: Publisher {
    public typealias Output = Void
    public typealias Failure = Never
    private let subject = PassthroughSubject<Void, Never>()
    public init() {}
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Void, S.Failure == Never { subject.receive(subscriber: subscriber) }
    public func send() { subject.send(()) }
}

public protocol ObservableObject: AnyObject {
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher where ObjectWillChangePublisher.Failure == Never
    var objectWillChange: ObjectWillChangePublisher { get }
}

/// @Published storage that can carry the enclosing object's objectWillChange publisher.
protocol _PublishedStorage: AnyObject {
    var _objectWillChange: ObservableObjectPublisher? { get set }
}

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// Like Combine: the publisher lives in the object's @Published properties (found by reflection, once);
    /// an object without @Published properties gets a fresh publisher each time.
    public var objectWillChange: ObservableObjectPublisher {
        var boxes: [_PublishedStorage] = []
        var mirror: Mirror? = Mirror(reflecting: self)
        while let m = mirror {
            for child in m.children {
                if let p = child.value as? _PublishedBoxProvider { boxes.append(p._box) }
            }
            mirror = m.superclassMirror
        }
        if let existing = boxes.lazy.compactMap({ $0._objectWillChange }).first {
            for b in boxes where b._objectWillChange == nil { b._objectWillChange = existing }
            return existing
        }
        let p = ObservableObjectPublisher()
        for b in boxes { b._objectWillChange = p }
        return p
    }
}

protocol _PublishedBoxProvider { var _box: _PublishedStorage { get } }

@propertyWrapper
public struct Published<Value> {
    final class Box: _PublishedStorage {
        var value: Value
        var _objectWillChange: ObservableObjectPublisher?
        lazy var subject = CurrentValueSubject<Value, Never>(value)
        var hasSubject = false
        init(_ v: Value) { value = v }
        func set(_ v: Value) {
            _objectWillChange?.send()
            value = v
            if hasSubject { subject.send(v) }
        }
    }
    let box: Box

    public init(wrappedValue: Value) { box = Box(wrappedValue) }
    public init(initialValue: Value) { box = Box(initialValue) }

    @available(*, unavailable, message: "@Published is only available on properties of classes")
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    public static subscript<EnclosingSelf: AnyObject>(_enclosingInstance object: EnclosingSelf,
                                                      wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
                                                      storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>) -> Value {
        get { object[keyPath: storageKeyPath].box.value }
        set {
            let box = object[keyPath: storageKeyPath].box
            if box._objectWillChange == nil, let o = object as? any ObservableObject {
                _ = _installObjectWillChange(o)
            }
            box.set(newValue)
        }
    }

    public var projectedValue: Publisher {
        get { box.hasSubject = true; return Publisher(box: box) }
        set {}
    }

    public struct Publisher: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never
        let box: Box
        var subject: CurrentValueSubject<Value, Never> { box.subject }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Value, S.Failure == Never {
            box.hasSubject = true
            box.subject.value = box.value
            box.subject.receive(subscriber: subscriber)
        }
    }
}
extension Published: _PublishedBoxProvider { var _box: _PublishedStorage { box } }

/// Touches objectWillChange so every @Published box shares the object's publisher.
func _installObjectWillChange<O: ObservableObject>(_ o: O) -> Any { o.objectWillChange }
