// isim Combine: the rest of Combine's operators (zip, scan, reduce, collect, delay, throttle, timeout, buffer,
// catch, retry, switchToLatest, decode/encode, values, print, breakpoint, ...). Independent implementation.
//
// Model: operators subscribe to their upstream with unlimited demand and hand values to the downstream through
// an `_Outlet`, which queues values until the downstream requests them (so nothing is lost when a subscriber
// asks for one value at a time, e.g. `.values`). Apple's operators propagate demand upstream instead; the
// observable difference is only in when upstream work happens, not in the values delivered.
import Darwin

// MARK: - Outlet (downstream side of an operator)

final class _Outlet<S: Subscriber>: Subscription, CustomStringConvertible {
    private let lock = _CombineLock(recursive: true)
    private var downstream: S?
    private var demand: Subscribers.Demand = .none
    private var queue: [S.Input] = []
    private var head = 0
    private var pending: Subscribers.Completion<S.Failure>?
    private var draining = false
    var onCancel: (() -> Void)?
    var onRequest: ((Subscribers.Demand) -> Void)?
    var name = "Outlet"

    init(_ s: S) { downstream = s }
    var description: String { name }

    /// The downstream has gone (cancelled or completed).
    var isClosed: Bool { lock.lock(); defer { lock.unlock() }; return downstream == nil || pending != nil }
    var queuedCount: Int { lock.lock(); defer { lock.unlock() }; return queue.count - head }
    func dropOldestQueued() { lock.lock(); if head < queue.count { head += 1 }; lock.unlock() }
    var currentDemand: Subscribers.Demand { lock.lock(); defer { lock.unlock() }; return demand }

    func request(_ d: Subscribers.Demand) {
        lock.lock(); demand += d; lock.unlock()
        onRequest?(d)
        drain()
    }
    func cancel() {
        lock.lock()
        let had = downstream != nil
        downstream = nil; queue = []; head = 0
        let c = onCancel; onCancel = nil; onRequest = nil
        lock.unlock()
        if had { c?() }
    }
    func send(_ v: S.Input) {
        lock.lock()
        guard downstream != nil, pending == nil else { lock.unlock(); return }
        queue.append(v)
        lock.unlock()
        drain()
    }
    /// `.finished` is delivered after queued values; a failure drops them and is delivered at once.
    func finish(_ c: Subscribers.Completion<S.Failure>) {
        lock.lock()
        guard downstream != nil, pending == nil else { lock.unlock(); return }
        pending = c
        if case .failure = c { queue = []; head = 0 }
        lock.unlock()
        drain()
    }
    /// Completes downstream and cancels the upstream (operators that finish early).
    func terminate(_ c: Subscribers.Completion<S.Failure>) {
        lock.lock(); let up = onCancel; onCancel = nil; lock.unlock()
        finish(c)
        up?()
    }
    private func drain() {
        lock.lock()
        if draining { lock.unlock(); return }
        draining = true
        while let s = downstream {
            if head < queue.count, demand > 0 {
                let v = queue[head]; head += 1
                if head > 64, head * 2 > queue.count { queue.removeFirst(head); head = 0 }
                demand -= 1
                lock.unlock()
                let more = s.receive(v)
                lock.lock()
                demand += more
                continue
            }
            if head >= queue.count, let c = pending {
                downstream = nil; queue = []; head = 0; onCancel = nil; onRequest = nil
                lock.unlock()
                s.receive(completion: c)
                lock.lock()
            }
            break
        }
        draining = false
        lock.unlock()
    }
}

/// Wires `upstream` → closures → outlet → `subscriber` (the common shape of single-upstream operators).
@discardableResult
func _operator<Upstream: Publisher, S: Subscriber>(_ upstream: Upstream, _ subscriber: S, name: String = "Operator",
    value: @escaping (Upstream.Output, _Outlet<S>) -> Void,
    completion: @escaping (Subscribers.Completion<Upstream.Failure>, _Outlet<S>) -> Void) -> _Outlet<S> {
    let out = _Outlet(subscriber)
    out.name = name
    // strong references: the cycle (outlet -> onCancel -> upstream subscriber -> closures -> outlet) is broken
    // when the outlet completes or is cancelled
    let up = _ClosureSubscriber<Upstream.Output, Upstream.Failure>(value: { v in value(v, out) }, completion: { c in completion(c, out) })
    out.onCancel = { up.cancel() }
    subscriber.receive(subscription: out)
    upstream.subscribe(up)
    return out
}

/// Maps a completion of one failure type to another (finished passes through).
@inline(__always)
func _mapCompletion<E: Error, F: Error>(_ c: Subscribers.Completion<E>, _ f: (E) -> F) -> Subscribers.Completion<F> {
    switch c { case .finished: return .finished; case .failure(let e): return .failure(f(e)) }
}

// MARK: - Scheduler additions

extension Scheduler {
    /// Repeating schedule (Apple's `Scheduler` requirement), built from one-shot `schedule(after:)` calls.
    public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        let state = _Ref(true)
        func step(_ at: SchedulerTimeType) {
            schedule(after: at, tolerance: tolerance, options: options) {
                guard state.value else { return }
                action()
                step(at.advanced(by: interval))
            }
        }
        step(date)
        return AnyCancellable { state.value = false }
    }
    public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, _ action: @escaping () -> Void) -> Cancellable {
        schedule(after: date, interval: interval, tolerance: minimumTolerance, options: nil, action)
    }
    public func schedule(after date: SchedulerTimeType, _ action: @escaping () -> Void) {
        schedule(after: date, tolerance: minimumTolerance, options: nil, action)
    }
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, _ action: @escaping () -> Void) {
        schedule(after: date, tolerance: tolerance, options: nil, action)
    }
}

// MARK: - Coding protocols (Foundation's JSON/property-list coders conform)

public protocol TopLevelDecoder<Input> {
    associatedtype Input
    func decode<T: Decodable>(_ type: T.Type, from: Input) throws -> T
}
public protocol TopLevelEncoder<Output> {
    associatedtype Output
    func encode<T: Encodable>(_ value: T) throws -> Output
}

// MARK: - Record

public struct Record<Output, Failure: Error>: Publisher {
    public struct Recording {
        public private(set) var output: [Output] = []
        public private(set) var completion: Subscribers.Completion<Failure> = .finished
        var done = false
        public init() {}
        public init(output: [Output], completion: Subscribers.Completion<Failure> = .finished) {
            self.output = output; self.completion = completion; done = true
        }
        public mutating func receive(_ input: Output) {
            precondition(!done, "Record.Recording: receive after completion"); output.append(input)
        }
        public mutating func receive(completion: Subscribers.Completion<Failure>) {
            precondition(!done, "Record.Recording: completed twice"); self.completion = completion; done = true
        }
    }
    public let recording: Recording
    public init(record: (inout Recording) -> Void) { var r = Recording(); record(&r); recording = r }
    public init(recording: Recording) { self.recording = recording }
    public init(output: [Output], completion: Subscribers.Completion<Failure>) { recording = Recording(output: output, completion: completion) }
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let out = _Outlet(subscriber); out.name = "Record"
        subscriber.receive(subscription: out)
        for v in recording.output { out.send(v) }
        out.finish(recording.completion)
    }
}

// MARK: - Operators

extension Publishers {

    // MARK: accumulate

    public struct Scan<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let initialResult: Output
        public let nextPartialResult: (Output, Upstream.Output) -> Output
        public init(upstream: Upstream, initialResult: Output, nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream; self.initialResult = initialResult; self.nextPartialResult = nextPartialResult
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let acc = _Ref(initialResult), f = nextPartialResult
            _operator(upstream, subscriber, name: "Scan", value: { v, o in acc.value = f(acc.value, v); o.send(acc.value) },
                      completion: { c, o in o.finish(c) })
        }
    }

    public struct TryScan<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Error
        public let upstream: Upstream
        public let initialResult: Output
        public let nextPartialResult: (Output, Upstream.Output) throws -> Output
        public init(upstream: Upstream, initialResult: Output, nextPartialResult: @escaping (Output, Upstream.Output) throws -> Output) {
            self.upstream = upstream; self.initialResult = initialResult; self.nextPartialResult = nextPartialResult
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let acc = _Ref(initialResult), f = nextPartialResult
            _operator(upstream, subscriber, name: "TryScan", value: { v, o in
                do { acc.value = try f(acc.value, v); o.send(acc.value) } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct Reduce<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let initial: Output
        public let nextPartialResult: (Output, Upstream.Output) -> Output
        public init(upstream: Upstream, initial: Output, nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream; self.initial = initial; self.nextPartialResult = nextPartialResult
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let acc = _Ref(initial), f = nextPartialResult
            _operator(upstream, subscriber, name: "Reduce", value: { v, _ in acc.value = f(acc.value, v) },
                      completion: { c, o in if case .finished = c { o.send(acc.value) }; o.finish(c) })
        }
    }

    public struct TryReduce<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Error
        public let upstream: Upstream
        public let initial: Output
        public let nextPartialResult: (Output, Upstream.Output) throws -> Output
        public init(upstream: Upstream, initial: Output, nextPartialResult: @escaping (Output, Upstream.Output) throws -> Output) {
            self.upstream = upstream; self.initial = initial; self.nextPartialResult = nextPartialResult
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let acc = _Ref(initial), f = nextPartialResult
            _operator(upstream, subscriber, name: "TryReduce", value: { v, o in
                do { acc.value = try f(acc.value, v) } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in if case .finished = c { o.send(acc.value) }; o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct Collect<Upstream: Publisher>: Publisher {
        public typealias Output = [Upstream.Output]
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let all = _Ref<[Upstream.Output]>([])
            _operator(upstream, subscriber, name: "Collect", value: { v, _ in all.value.append(v) },
                      completion: { c, o in if case .finished = c { o.send(all.value) }; o.finish(c) })
        }
    }

    public struct CollectByCount<Upstream: Publisher>: Publisher {
        public typealias Output = [Upstream.Output]
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let count: Int
        public init(upstream: Upstream, count: Int) { self.upstream = upstream; self.count = count }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let chunk = _Ref<[Upstream.Output]>([]), n = Swift.max(1, count)
            _operator(upstream, subscriber, name: "CollectByCount", value: { v, o in
                chunk.value.append(v)
                if chunk.value.count == n { let c = chunk.value; chunk.value = []; o.send(c) }
            }, completion: { c, o in
                if case .finished = c, !chunk.value.isEmpty { o.send(chunk.value) }
                o.finish(c)
            })
        }
    }

    public enum TimeGroupingStrategy<Context: Scheduler> {
        case byTime(Context, Context.SchedulerTimeType.Stride)
        case byTimeOrCount(Context, Context.SchedulerTimeType.Stride, Int)
    }

    public struct CollectByTime<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = [Upstream.Output]
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let strategy: TimeGroupingStrategy<Context>
        public let options: Context.SchedulerOptions?
        public init(upstream: Upstream, strategy: TimeGroupingStrategy<Context>, options: Context.SchedulerOptions?) {
            self.upstream = upstream; self.strategy = strategy; self.options = options
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch: Context, stride: Context.SchedulerTimeType.Stride, limit: Int
            switch strategy {
            case .byTime(let s, let t): sch = s; stride = t; limit = Int.max
            case .byTimeOrCount(let s, let t, let n): sch = s; stride = t; limit = Swift.max(1, n)
            }
            let lock = _CombineLock(recursive: true)
            let chunk = _Ref<[Upstream.Output]>([])
            let timer = _Ref<Cancellable?>(nil)
            let opts = options
            let out = _operator(upstream, subscriber, name: "CollectByTime", value: { v, o in
                lock.lock(); chunk.value.append(v)
                var full: [Upstream.Output]? = nil
                if chunk.value.count >= limit { full = chunk.value; chunk.value = [] }
                lock.unlock()
                if let full { o.send(full) }
            }, completion: { c, o in
                timer.value?.cancel(); timer.value = nil
                lock.lock(); let rest = chunk.value; chunk.value = []; lock.unlock()
                if case .finished = c, !rest.isEmpty { o.send(rest) }
                o.finish(c)
            })
            weak let weakOut = out
            timer.value = sch.schedule(after: sch.now.advanced(by: stride), interval: stride, tolerance: sch.minimumTolerance, options: opts) {
                guard let o = weakOut else { return }
                lock.lock(); let c = chunk.value; chunk.value = []; lock.unlock()
                if !c.isEmpty { o.send(c) }
            }
            let prev = out.onCancel
            out.onCancel = { timer.value?.cancel(); prev?() }
        }
    }

    // MARK: single-value results

    public struct Count<Upstream: Publisher>: Publisher {
        public typealias Output = Int
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Int, S.Failure == Failure {
            let n = _Ref(0)
            _operator(upstream, subscriber, name: "Count", value: { _, _ in n.value += 1 },
                      completion: { c, o in if case .finished = c { o.send(n.value) }; o.finish(c) })
        }
    }

    public struct Comparison<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        /// Returns true when the second value should replace the current best (Apple's `areInIncreasingOrder` shape).
        public let areInIncreasingOrder: (Upstream.Output, Upstream.Output) -> Bool
        public init(upstream: Upstream, areInIncreasingOrder: @escaping (Upstream.Output, Upstream.Output) -> Bool) {
            self.upstream = upstream; self.areInIncreasingOrder = areInIncreasingOrder
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let best = _Ref<Output?>(nil), f = areInIncreasingOrder
            _operator(upstream, subscriber, name: "Comparison", value: { v, _ in
                if let b = best.value { if f(b, v) { best.value = v } } else { best.value = v }
            }, completion: { c, o in if case .finished = c, let b = best.value { o.send(b) }; o.finish(c) })
        }
    }

    public struct TryComparison<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let areInIncreasingOrder: (Upstream.Output, Upstream.Output) throws -> Bool
        public init(upstream: Upstream, areInIncreasingOrder: @escaping (Upstream.Output, Upstream.Output) throws -> Bool) {
            self.upstream = upstream; self.areInIncreasingOrder = areInIncreasingOrder
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let best = _Ref<Output?>(nil), f = areInIncreasingOrder
            _operator(upstream, subscriber, name: "TryComparison", value: { v, o in
                do { if let b = best.value { if try f(b, v) { best.value = v } } else { best.value = v } }
                catch { o.terminate(.failure(error)) }
            }, completion: { c, o in if case .finished = c, let b = best.value { o.send(b) }; o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct ContainsWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Bool
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Upstream.Output) -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Bool, S.Failure == Failure {
            let p = predicate
            _operator(upstream, subscriber, name: "ContainsWhere", value: { v, o in if p(v) { o.send(true); o.terminate(.finished) } },
                      completion: { c, o in if case .finished = c { o.send(false) }; o.finish(c) })
        }
    }

    public struct TryContainsWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Bool
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Bool, S.Failure == Error {
            let p = predicate
            _operator(upstream, subscriber, name: "TryContainsWhere", value: { v, o in
                do { if try p(v) { o.send(true); o.terminate(.finished) } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in if case .finished = c { o.send(false) }; o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct AllSatisfy<Upstream: Publisher>: Publisher {
        public typealias Output = Bool
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Upstream.Output) -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Bool, S.Failure == Failure {
            let p = predicate
            _operator(upstream, subscriber, name: "AllSatisfy", value: { v, o in if !p(v) { o.send(false); o.terminate(.finished) } },
                      completion: { c, o in if case .finished = c { o.send(true) }; o.finish(c) })
        }
    }

    public struct TryAllSatisfy<Upstream: Publisher>: Publisher {
        public typealias Output = Bool
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Bool, S.Failure == Error {
            let p = predicate
            _operator(upstream, subscriber, name: "TryAllSatisfy", value: { v, o in
                do { if try !p(v) { o.send(false); o.terminate(.finished) } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in if case .finished = c { o.send(true) }; o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct FirstWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Upstream.Output) -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let p = predicate
            _operator(upstream, subscriber, name: "FirstWhere", value: { v, o in if p(v) { o.send(v); o.terminate(.finished) } },
                      completion: { c, o in o.finish(c) })
        }
    }

    public struct TryFirstWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let p = predicate
            _operator(upstream, subscriber, name: "TryFirstWhere", value: { v, o in
                do { if try p(v) { o.send(v); o.terminate(.finished) } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct Last<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let last = _Ref<Output?>(nil)
            _operator(upstream, subscriber, name: "Last", value: { v, _ in last.value = v },
                      completion: { c, o in if case .finished = c, let l = last.value { o.send(l) }; o.finish(c) })
        }
    }

    public struct LastWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Upstream.Output) -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let last = _Ref<Output?>(nil), p = predicate
            _operator(upstream, subscriber, name: "LastWhere", value: { v, _ in if p(v) { last.value = v } },
                      completion: { c, o in if case .finished = c, let l = last.value { o.send(l) }; o.finish(c) })
        }
    }

    public struct TryLastWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let last = _Ref<Output?>(nil), p = predicate
            _operator(upstream, subscriber, name: "TryLastWhere", value: { v, o in
                do { if try p(v) { last.value = v } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in if case .finished = c, let l = last.value { o.send(l) }; o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct IgnoreOutput<Upstream: Publisher>: Publisher {
        public typealias Output = Never
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Never, S.Failure == Failure {
            _operator(upstream, subscriber, name: "IgnoreOutput", value: { _, _ in }, completion: { c, o in o.finish(c) })
        }
    }

    // MARK: filtering

    public struct TryFilter<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let isIncluded: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, isIncluded: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.isIncluded = isIncluded }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let p = isIncluded
            _operator(upstream, subscriber, name: "TryFilter", value: { v, o in
                do { if try p(v) { o.send(v) } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct TryCompactMap<Upstream: Publisher, Output>: Publisher {
        public typealias Failure = Error
        public let upstream: Upstream
        public let transform: (Upstream.Output) throws -> Output?
        public init(upstream: Upstream, transform: @escaping (Upstream.Output) throws -> Output?) { self.upstream = upstream; self.transform = transform }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let t = transform
            _operator(upstream, subscriber, name: "TryCompactMap", value: { v, o in
                do { if let x = try t(v) { o.send(x) } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct TryRemoveDuplicates<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output, Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output, Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let last = _Ref<Output?>(nil), p = predicate
            _operator(upstream, subscriber, name: "TryRemoveDuplicates", value: { v, o in
                do {
                    if let l = last.value, try p(l, v) { return }
                    last.value = v; o.send(v)
                } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct PrefixWhile<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Upstream.Output) -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let p = predicate
            _operator(upstream, subscriber, name: "PrefixWhile", value: { v, o in if p(v) { o.send(v) } else { o.terminate(.finished) } },
                      completion: { c, o in o.finish(c) })
        }
    }

    public struct TryPrefixWhile<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let p = predicate
            _operator(upstream, subscriber, name: "TryPrefixWhile", value: { v, o in
                do { if try p(v) { o.send(v) } else { o.terminate(.finished) } } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct DropWhile<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let predicate: (Upstream.Output) -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let p = predicate, dropping = _Ref(true)
            _operator(upstream, subscriber, name: "DropWhile", value: { v, o in
                if dropping.value, p(v) { return }
                dropping.value = false; o.send(v)
            }, completion: { c, o in o.finish(c) })
        }
    }

    public struct TryDropWhile<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let predicate: (Upstream.Output) throws -> Bool
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) { self.upstream = upstream; self.predicate = predicate }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let p = predicate, dropping = _Ref(true)
            _operator(upstream, subscriber, name: "TryDropWhile", value: { v, o in
                do {
                    if dropping.value, try p(v) { return }
                    dropping.value = false; o.send(v)
                } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct DropUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher where Upstream.Failure == Other.Failure {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let other: Other
        public init(upstream: Upstream, other: Other) { self.upstream = upstream; self.other = other }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let open = _Ref(false)
            let trigger = _Ref<_ClosureSubscriber<Other.Output, Other.Failure>?>(nil)
            let out = _Outlet(subscriber); out.name = "DropUntilOutput"
            let up = _ClosureSubscriber<Upstream.Output, Upstream.Failure>(value: { v in if open.value { out.send(v) } },
                                                                         completion: { c in trigger.value?.cancel(); out.finish(c) })
            trigger.value = _ClosureSubscriber<Other.Output, Other.Failure>(value: { _ in open.value = true; trigger.value?.cancel() },
                                                                            completion: { c in if case .failure = c { up.cancel(); out.finish(c) } })
            out.onCancel = { up.cancel(); trigger.value?.cancel() }
            subscriber.receive(subscription: out)
            other.subscribe(trigger.value!)
            upstream.subscribe(up)
        }
    }

    public struct PrefixUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let other: Other
        public init(upstream: Upstream, other: Other) { self.upstream = upstream; self.other = other }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let out = _Outlet(subscriber); out.name = "PrefixUntilOutput"
            let up = _ClosureSubscriber<Upstream.Output, Upstream.Failure>(value: { out.send($0) }, completion: { out.finish($0) })
            let trigger = _ClosureSubscriber<Other.Output, Other.Failure>(value: { _ in up.cancel(); out.finish(.finished) }, completion: { _ in })
            out.onCancel = { up.cancel(); trigger.cancel() }
            subscriber.receive(subscription: out)
            other.subscribe(trigger)
            if !out.isClosed { upstream.subscribe(up) }
        }
    }

    // MARK: errors

    public struct MapError<Upstream: Publisher, Failure: Error>: Publisher {
        public typealias Output = Upstream.Output
        public let upstream: Upstream
        public let transform: (Upstream.Failure) -> Failure
        public init(upstream: Upstream, transform: @escaping (Upstream.Failure) -> Failure) { self.upstream = upstream; self.transform = transform }
        public init(upstream: Upstream, _ map: @escaping (Upstream.Failure) -> Failure) { self.upstream = upstream; transform = map }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let t = transform
            _operator(upstream, subscriber, name: "MapError", value: { v, o in o.send(v) }, completion: { c, o in o.finish(_mapCompletion(c, t)) })
        }
    }

    public struct ReplaceError<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Never
        public let upstream: Upstream
        public let output: Upstream.Output
        public init(upstream: Upstream, output: Upstream.Output) { self.upstream = upstream; self.output = output }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
            let r = output
            _operator(upstream, subscriber, name: "ReplaceError", value: { v, o in o.send(v) }, completion: { c, o in
                if case .failure = c { o.send(r) }
                o.finish(.finished)
            })
        }
    }

    public struct ReplaceEmpty<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let output: Upstream.Output
        public init(upstream: Upstream, output: Output) { self.upstream = upstream; self.output = output }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let r = output, any = _Ref(false)
            _operator(upstream, subscriber, name: "ReplaceEmpty", value: { v, o in any.value = true; o.send(v) }, completion: { c, o in
                if case .finished = c, !any.value { o.send(r) }
                o.finish(c)
            })
        }
    }

    public struct AssertNoFailure<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Never
        public let upstream: Upstream
        public let prefix: String
        public let file: StaticString
        public let line: UInt
        public init(upstream: Upstream, prefix: String, file: StaticString, line: UInt) {
            self.upstream = upstream; self.prefix = prefix; self.file = file; self.line = line
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
            let p = prefix, f = file, l = line
            _operator(upstream, subscriber, name: "AssertNoFailure", value: { v, o in o.send(v) }, completion: { c, o in
                if case .failure(let e) = c { fatalError("\(p.isEmpty ? "" : p + " ")\(e)", file: f, line: l) }
                o.finish(.finished)
            })
        }
    }

    public struct Catch<Upstream: Publisher, NewPublisher: Publisher>: Publisher where Upstream.Output == NewPublisher.Output {
        public typealias Output = Upstream.Output
        public typealias Failure = NewPublisher.Failure
        public let upstream: Upstream
        public let handler: (Upstream.Failure) -> NewPublisher
        public init(upstream: Upstream, handler: @escaping (Upstream.Failure) -> NewPublisher) { self.upstream = upstream; self.handler = handler }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let h = handler
            let replacement = _Ref<Cancellable?>(nil)
            let out = _operator(upstream, subscriber, name: "Catch", value: { v, o in o.send(v) }, completion: { c, o in
                switch c {
                case .finished: o.finish(.finished)
                case .failure(let e):
                    let s = _ClosureSubscriber<NewPublisher.Output, NewPublisher.Failure>(value: { o.send($0) },
                                                                                          completion: { o.finish($0) })
                    replacement.value = s
                    h(e).subscribe(s)
                }
            })
            let prev = out.onCancel
            out.onCancel = { prev?(); replacement.value?.cancel() }
        }
    }

    public struct TryCatch<Upstream: Publisher, NewPublisher: Publisher>: Publisher where Upstream.Output == NewPublisher.Output {
        public typealias Output = Upstream.Output
        public typealias Failure = Error
        public let upstream: Upstream
        public let handler: (Upstream.Failure) throws -> NewPublisher
        public init(upstream: Upstream, handler: @escaping (Upstream.Failure) throws -> NewPublisher) { self.upstream = upstream; self.handler = handler }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let h = handler
            let replacement = _Ref<Cancellable?>(nil)
            let out = _operator(upstream, subscriber, name: "TryCatch", value: { v, o in o.send(v) }, completion: { c, o in
                switch c {
                case .finished: o.finish(.finished)
                case .failure(let e):
                    do {
                        let p = try h(e)
                        let s = _ClosureSubscriber<NewPublisher.Output, NewPublisher.Failure>(value: { o.send($0) },
                            completion: { c in o.finish(_mapCompletion(c) { $0 }) })
                        replacement.value = s
                        p.subscribe(s)
                    } catch { o.finish(.failure(error)) }
                }
            })
            let prev = out.onCancel
            out.onCancel = { prev?(); replacement.value?.cancel() }
        }
    }

    public struct Retry<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let retries: Int?
        public init(upstream: Upstream, retries: Int?) { self.upstream = upstream; self.retries = retries }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let out = _Outlet(subscriber); out.name = "Retry"
            let left = _Ref(retries)
            let current = _Ref<Cancellable?>(nil)
            let up = upstream
            func attach() {
                let s = _ClosureSubscriber<Output, Failure>(value: { out.send($0) }, completion: { c in
                    if case .failure = c, !out.isClosed, left.value.map({ $0 > 0 }) ?? true {
                        left.value = left.value.map { $0 - 1 }
                        attach()
                    } else { out.finish(c) }
                })
                current.value = s
                up.subscribe(s)
            }
            out.onCancel = { current.value?.cancel() }
            subscriber.receive(subscription: out)
            attach()
        }
    }

    // MARK: combining

    public struct Zip<A: Publisher, B: Publisher>: Publisher where A.Failure == B.Failure {
        public typealias Output = (A.Output, B.Output)
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public init(_ a: A, _ b: B) { self.a = a; self.b = b }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let lock = _CombineLock(recursive: true)
            let st = _Ref((a: [A.Output](), b: [B.Output](), aDone: false, bDone: false))
            let out = _Outlet(subscriber); out.name = "Zip"
            var subs: [Cancellable] = []
            func pump() {
                lock.lock()
                var ready: [(A.Output, B.Output)] = []
                while !st.value.a.isEmpty, !st.value.b.isEmpty { ready.append((st.value.a.removeFirst(), st.value.b.removeFirst())) }
                let done = (st.value.aDone && st.value.a.isEmpty) || (st.value.bDone && st.value.b.isEmpty)
                lock.unlock()
                for r in ready { out.send(r) }
                if done { out.terminate(.finished) }
            }
            let sa = _ClosureSubscriber<A.Output, A.Failure>(value: { v in lock.lock(); st.value.a.append(v); lock.unlock(); pump() },
                completion: { c in if case .failure = c { out.terminate(c) } else { lock.lock(); st.value.aDone = true; lock.unlock(); pump() } })
            let sb = _ClosureSubscriber<B.Output, B.Failure>(value: { v in lock.lock(); st.value.b.append(v); lock.unlock(); pump() },
                completion: { c in if case .failure = c { out.terminate(c) } else { lock.lock(); st.value.bDone = true; lock.unlock(); pump() } })
            subs = [sa, sb]
            out.onCancel = { for s in subs { s.cancel() } }
            subscriber.receive(subscription: out)
            a.subscribe(sa); b.subscribe(sb)
        }
    }

    public struct Zip3<A: Publisher, B: Publisher, C: Publisher>: Publisher where A.Failure == B.Failure, B.Failure == C.Failure {
        public typealias Output = (A.Output, B.Output, C.Output)
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public init(_ a: A, _ b: B, _ c: C) { self.a = a; self.b = b; self.c = c }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            Zip(Zip(a, b), c).map { ($0.0.0, $0.0.1, $0.1) }.subscribe(subscriber)
        }
    }

    public struct Zip4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
        where A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {
        public typealias Output = (A.Output, B.Output, C.Output, D.Output)
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public init(_ a: A, _ b: B, _ c: C, _ d: D) { self.a = a; self.b = b; self.c = c; self.d = d }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            Zip(Zip(Zip(a, b), c), d).map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) }.subscribe(subscriber)
        }
    }

    public struct CombineLatest3<A: Publisher, B: Publisher, C: Publisher>: Publisher where A.Failure == B.Failure, B.Failure == C.Failure {
        public typealias Output = (A.Output, B.Output, C.Output)
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public init(_ a: A, _ b: B, _ c: C) { self.a = a; self.b = b; self.c = c }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            CombineLatest(a: CombineLatest(a: a, b: b), b: c).map { ($0.0.0, $0.0.1, $0.1) }.subscribe(subscriber)
        }
    }

    public struct CombineLatest4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
        where A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {
        public typealias Output = (A.Output, B.Output, C.Output, D.Output)
        public typealias Failure = A.Failure
        public let a: A
        public let b: B
        public let c: C
        public let d: D
        public init(_ a: A, _ b: B, _ c: C, _ d: D) { self.a = a; self.b = b; self.c = c; self.d = d }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            CombineLatest(a: CombineLatest(a: CombineLatest(a: a, b: b), b: c), b: d).map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) }.subscribe(subscriber)
        }
    }

    public struct MergeMany<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let publishers: [Upstream]
        public init(_ upstream: Upstream...) { publishers = upstream }
        public init<S: Swift.Sequence>(_ upstream: S) where S.Element == Upstream { publishers = Array(upstream) }
        public func merge(with other: Upstream) -> MergeMany { MergeMany(publishers + [other]) }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let lock = _CombineLock()
            let left = _Ref(publishers.count)
            let out = _Outlet(subscriber); out.name = "MergeMany"
            var subs: [_ClosureSubscriber<Output, Failure>] = []
            for _ in publishers {
                subs.append(_ClosureSubscriber<Output, Failure>(value: { out.send($0) }, completion: { c in
                    if case .failure = c { out.terminate(c); return }
                    lock.lock(); left.value -= 1; let done = left.value == 0; lock.unlock()
                    if done { out.finish(.finished) }
                }))
            }
            let all = subs
            out.onCancel = { for s in all { s.cancel() } }
            subscriber.receive(subscription: out)
            if publishers.isEmpty { out.finish(.finished); return }
            for (p, s) in Swift.zip(publishers, subs) { p.subscribe(s) }
        }
    }

    public struct Concatenate<Prefix: Publisher, Suffix: Publisher>: Publisher where Prefix.Output == Suffix.Output, Prefix.Failure == Suffix.Failure {
        public typealias Output = Suffix.Output
        public typealias Failure = Suffix.Failure
        public let prefix: Prefix
        public let suffix: Suffix
        public init(prefix: Prefix, suffix: Suffix) { self.prefix = prefix; self.suffix = suffix }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let out = _Outlet(subscriber); out.name = "Concatenate"
            let current = _Ref<Cancellable?>(nil)
            let suf = suffix
            let first = _ClosureSubscriber<Output, Failure>(value: { out.send($0) }, completion: { c in
                guard case .finished = c, !out.isClosed else { out.finish(c); return }
                let second = _ClosureSubscriber<Output, Failure>(value: { out.send($0) }, completion: { out.finish($0) })
                current.value = second
                suf.subscribe(second)
            })
            current.value = first
            out.onCancel = { current.value?.cancel() }
            subscriber.receive(subscription: out)
            prefix.subscribe(first)
        }
    }

    public struct SwitchToLatest<P: Publisher, Upstream: Publisher>: Publisher where Upstream.Output == P, P.Failure == Upstream.Failure {
        public typealias Output = P.Output
        public typealias Failure = P.Failure
        public let upstream: Upstream
        public init(upstream: Upstream) { self.upstream = upstream }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let lock = _CombineLock(recursive: true)
            let st = _Ref((gen: 0, inner: Cancellable?.none, innerActive: false, outerDone: false))
            let out = _operator(upstream, subscriber, name: "SwitchToLatest", value: { p, o in
                lock.lock()
                st.value.inner?.cancel()
                st.value.gen += 1
                let mine = st.value.gen
                st.value.innerActive = true
                lock.unlock()
                let s = _ClosureSubscriber<P.Output, P.Failure>(value: { v in
                    lock.lock(); let cur = st.value.gen == mine; lock.unlock()
                    if cur { o.send(v) }
                }, completion: { c in
                    lock.lock(); let cur = st.value.gen == mine
                    if cur { st.value.innerActive = false }
                    let finished = cur && st.value.outerDone
                    lock.unlock()
                    guard cur else { return }
                    if case .failure = c { o.terminate(c) } else if finished { o.finish(.finished) }
                })
                lock.lock(); st.value.inner = s; lock.unlock()
                p.subscribe(s)
            }, completion: { c, o in
                if case .failure = c { lock.lock(); st.value.inner?.cancel(); lock.unlock(); o.finish(c); return }
                lock.lock(); st.value.outerDone = true; let idle = !st.value.innerActive; lock.unlock()
                if idle { o.finish(.finished) }
            })
            let prev = out.onCancel
            out.onCancel = { prev?(); lock.lock(); let i = st.value.inner; lock.unlock(); i?.cancel() }
        }
    }

    // MARK: timing

    public struct Delay<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let interval: Context.SchedulerTimeType.Stride
        public let tolerance: Context.SchedulerTimeType.Stride
        public let scheduler: Context
        public let options: Context.SchedulerOptions?
        public init(upstream: Upstream, interval: Context.SchedulerTimeType.Stride, tolerance: Context.SchedulerTimeType.Stride,
                    scheduler: Context, options: Context.SchedulerOptions? = nil) {
            self.upstream = upstream; self.interval = interval; self.tolerance = tolerance; self.scheduler = scheduler; self.options = options
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch = scheduler, iv = interval, tol = tolerance, opt = options
            _operator(upstream, subscriber, name: "Delay", value: { v, o in
                sch.schedule(after: sch.now.advanced(by: iv), tolerance: tol, options: opt) { o.send(v) }
            }, completion: { c, o in
                sch.schedule(after: sch.now.advanced(by: iv), tolerance: tol, options: opt) { o.finish(c) }
            })
        }
    }

    public struct Throttle<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let interval: Context.SchedulerTimeType.Stride
        public let scheduler: Context
        public let latest: Bool
        public init(upstream: Upstream, interval: Context.SchedulerTimeType.Stride, scheduler: Context, latest: Bool) {
            self.upstream = upstream; self.interval = interval; self.scheduler = scheduler; self.latest = latest
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch = scheduler, iv = interval, keepLatest = latest
            let lock = _CombineLock(recursive: true)
            let st = _Ref((windowOpen: false, pending: Output?.none, done: Subscribers.Completion<Failure>?.none))
            func closeWindow(_ o: _Outlet<S>) {
                lock.lock()
                if let p = st.value.pending {
                    st.value.pending = nil
                    lock.unlock()
                    o.send(p)
                    sch.schedule(after: sch.now.advanced(by: iv), tolerance: sch.minimumTolerance, options: nil) { closeWindow(o) }
                    return
                }
                st.value.windowOpen = false
                let d = st.value.done
                lock.unlock()
                if let d { o.finish(d) }
            }
            _operator(upstream, subscriber, name: "Throttle", value: { v, o in
                lock.lock()
                if !st.value.windowOpen {
                    st.value.windowOpen = true
                    lock.unlock()
                    o.send(v)
                    sch.schedule(after: sch.now.advanced(by: iv), tolerance: sch.minimumTolerance, options: nil) { closeWindow(o) }
                    return
                }
                if keepLatest || st.value.pending == nil { st.value.pending = v }
                lock.unlock()
            }, completion: { c, o in
                lock.lock()
                if case .finished = c, st.value.windowOpen, st.value.pending != nil { st.value.done = c; lock.unlock(); return }
                lock.unlock()
                o.finish(c)
            })
        }
    }

    public struct Timeout<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let interval: Context.SchedulerTimeType.Stride
        public let scheduler: Context
        public let options: Context.SchedulerOptions?
        public let customError: (() -> Upstream.Failure)?
        public init(upstream: Upstream, interval: Context.SchedulerTimeType.Stride, scheduler: Context,
                    options: Context.SchedulerOptions?, customError: (() -> Upstream.Failure)?) {
            self.upstream = upstream; self.interval = interval; self.scheduler = scheduler; self.options = options; self.customError = customError
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch = scheduler, iv = interval, opt = options, err = customError
            let gen = _Ref(0)
            let lock = _CombineLock(recursive: true)
            let outRef = _Ref<_Outlet<S>?>(nil)
            func arm() {
                lock.lock(); gen.value += 1; let mine = gen.value; lock.unlock()
                sch.schedule(after: sch.now.advanced(by: iv), tolerance: sch.minimumTolerance, options: opt) {
                    lock.lock(); let fire = gen.value == mine; lock.unlock()
                    guard fire, let o = outRef.value else { return }
                    o.terminate(err.map { .failure($0()) } ?? .finished)
                }
            }
            let out = _Outlet(subscriber); out.name = "Timeout"
            outRef.value = out
            let up = _ClosureSubscriber<Output, Failure>(value: { v in arm(); out.send(v) },
                                                         completion: { c in lock.lock(); gen.value += 1; lock.unlock(); out.finish(c) })
            out.onCancel = { up.cancel(); lock.lock(); gen.value += 1; lock.unlock(); outRef.value = nil }
            subscriber.receive(subscription: out)
            arm()
            upstream.subscribe(up)
        }
    }

    public struct MeasureInterval<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Context.SchedulerTimeType.Stride
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let scheduler: Context
        public init(upstream: Upstream, scheduler: Context) { self.upstream = upstream; self.scheduler = scheduler }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch = scheduler
            let last = _Ref(sch.now)
            _operator(upstream, subscriber, name: "MeasureInterval", value: { _, o in
                let now = sch.now
                o.send(last.value.distance(to: now)); last.value = now
            }, completion: { c, o in o.finish(c) })
        }
    }

    public enum PrefetchStrategy: Equatable, Hashable, Sendable {
        case keepFull
        case byRequest
    }
    public enum BufferingStrategy<Failure: Error> {
        case dropNewest
        case dropOldest
        case customError(() -> Failure)
    }

    public struct Buffer<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let size: Int
        public let prefetch: PrefetchStrategy
        public let whenFull: BufferingStrategy<Failure>
        public init(upstream: Upstream, size: Int, prefetch: PrefetchStrategy, whenFull: BufferingStrategy<Failure>) {
            self.upstream = upstream; self.size = size; self.prefetch = prefetch; self.whenFull = whenFull
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let cap = Swift.max(0, size), policy = whenFull
            _operator(upstream, subscriber, name: "Buffer", value: { v, o in
                // values beyond the downstream's demand wait in the queue (at most `size` of them)
                let waiting = o.queuedCount
                let room = o.currentDemand > waiting
                if room || waiting < cap { o.send(v); return }
                switch policy {
                case .dropNewest: break
                case .dropOldest: o.dropOldestQueued(); o.send(v)
                case .customError(let f): o.terminate(.failure(f()))
                }
            }, completion: { c, o in o.finish(c) })
        }
    }

    // MARK: schedulers & sharing

    public struct SubscribeOn<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let scheduler: Context
        public let options: Context.SchedulerOptions?
        public init(upstream: Upstream, scheduler: Context, options: Context.SchedulerOptions?) {
            self.upstream = upstream; self.scheduler = scheduler; self.options = options
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let sch = scheduler, opt = options, up = upstream
            let out = _Outlet(subscriber); out.name = "SubscribeOn"
            let s = _ClosureSubscriber<Output, Failure>(value: { out.send($0) }, completion: { out.finish($0) })
            out.onCancel = { sch.schedule(options: opt) { s.cancel() } }
            subscriber.receive(subscription: out)
            sch.schedule(options: opt) { if !out.isClosed { up.subscribe(s) } }
        }
    }

    public final class Multicast<Upstream: Publisher, SubjectType: Subject>: ConnectablePublisher
        where Upstream.Output == SubjectType.Output, Upstream.Failure == SubjectType.Failure {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let createSubject: () -> SubjectType
        private lazy var subject: SubjectType = createSubject()
        private let lock = _CombineLock()
        public init(upstream: Upstream, createSubject: @escaping () -> SubjectType) { self.upstream = upstream; self.createSubject = createSubject }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            lock.lock(); let s = subject; lock.unlock()
            s.receive(subscriber: subscriber)
        }
        public func connect() -> Cancellable {
            lock.lock(); let subj = subject; lock.unlock()
            let s = _ClosureSubscriber<Output, Failure>(value: { subj.send($0) }, completion: { subj.send(completion: $0) })
            upstream.subscribe(s)
            return AnyCancellable(s)
        }
    }

    public struct MakeConnectable<Upstream: Publisher>: ConnectablePublisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        let inner: Multicast<Upstream, PassthroughSubject<Upstream.Output, Upstream.Failure>>
        public init(upstream: Upstream) { inner = Multicast(upstream: upstream) { PassthroughSubject() } }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure { inner.receive(subscriber: subscriber) }
        public func connect() -> Cancellable { inner.connect() }
    }

    // MARK: coding

    public struct Decode<Upstream: Publisher, Output: Decodable, Coder: TopLevelDecoder>: Publisher where Upstream.Output == Coder.Input {
        public typealias Failure = Error
        public let upstream: Upstream
        let decoder: Coder
        public init(upstream: Upstream, decoder: Coder) { self.upstream = upstream; self.decoder = decoder }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let d = decoder
            _operator(upstream, subscriber, name: "Decode", value: { v, o in
                do { o.send(try d.decode(Output.self, from: v)) } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    public struct Encode<Upstream: Publisher, Coder: TopLevelEncoder>: Publisher where Upstream.Output: Encodable {
        public typealias Output = Coder.Output
        public typealias Failure = Error
        public let upstream: Upstream
        let encoder: Coder
        public init(upstream: Upstream, encoder: Coder) { self.upstream = upstream; self.encoder = encoder }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Error {
            let e = encoder
            _operator(upstream, subscriber, name: "Encode", value: { v, o in
                do { o.send(try e.encode(v)) } catch { o.terminate(.failure(error)) }
            }, completion: { c, o in o.finish(_mapCompletion(c) { $0 }) })
        }
    }

    // MARK: debugging

    public struct Print<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let prefix: String
        public let upstream: Upstream
        public let stream: TextOutputStream?
        public init(upstream: Upstream, prefix: String, to stream: TextOutputStream? = nil) {
            self.upstream = upstream; self.prefix = prefix; self.stream = stream
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let p = prefix.isEmpty ? "" : prefix + ": "
            let sink = _Ref(stream)
            let log: (String) -> Void = { line in
                if sink.value != nil { sink.value!.write(p + line + "\n") } else { Swift.print(p + line) }
            }
            upstream.subscribe(_ProxySubscriber(subscriber,
                onSubscription: { log("receive subscription: (\($0))") },
                onValue: { log("receive value: (\($0))") },
                onCompletion: { c in
                    switch c { case .finished: log("receive finished"); case .failure(let e): log("receive error: (\(e))") }
                },
                onRequest: { log("request \($0)") },
                onCancel: { log("receive cancel") }))
        }
    }

    public struct Breakpoint<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        public let upstream: Upstream
        public let receiveSubscription: ((Subscription) -> Bool)?
        public let receiveOutput: ((Upstream.Output) -> Bool)?
        public let receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)?
        public init(upstream: Upstream, receiveSubscription: ((Subscription) -> Bool)? = nil, receiveOutput: ((Upstream.Output) -> Bool)? = nil,
                    receiveCompletion: ((Subscribers.Completion<Upstream.Failure>) -> Bool)? = nil) {
            self.upstream = upstream; self.receiveSubscription = receiveSubscription; self.receiveOutput = receiveOutput; self.receiveCompletion = receiveCompletion
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let rs = receiveSubscription, ro = receiveOutput, rc = receiveCompletion
            // like Apple's: SIGTRAP stops in a debugger (and ends the app without one)
            upstream.subscribe(_ProxySubscriber(subscriber,
                onSubscription: { if rs?($0) == true { raise(SIGTRAP) } },
                onValue: { if ro?($0) == true { raise(SIGTRAP) } },
                onCompletion: { if rc?($0) == true { raise(SIGTRAP) } }))
        }
    }
}

/// Passes everything through unchanged, demand included, calling hooks on the way (print, breakpoint, handleEvents).
final class _ProxySubscriber<S: Subscriber>: Subscriber, Subscription {
    typealias Input = S.Input
    typealias Failure = S.Failure
    let downstream: S
    var upstream: Subscription?
    let onSubscription: ((Subscription) -> Void)?
    let onValue: ((S.Input) -> Void)?
    let onCompletion: ((Subscribers.Completion<S.Failure>) -> Void)?
    let onRequest: ((Subscribers.Demand) -> Void)?
    let onCancel: (() -> Void)?
    init(_ d: S, onSubscription: ((Subscription) -> Void)? = nil, onValue: ((S.Input) -> Void)? = nil,
         onCompletion: ((Subscribers.Completion<S.Failure>) -> Void)? = nil, onRequest: ((Subscribers.Demand) -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        downstream = d; self.onSubscription = onSubscription; self.onValue = onValue; self.onCompletion = onCompletion
        self.onRequest = onRequest; self.onCancel = onCancel
    }
    func receive(subscription: Subscription) {
        upstream = subscription
        onSubscription?(subscription)
        downstream.receive(subscription: self)
    }
    func receive(_ input: S.Input) -> Subscribers.Demand {
        onValue?(input)
        let more = downstream.receive(input)
        if more > 0 { onRequest?(more) }
        return more
    }
    func receive(completion: Subscribers.Completion<S.Failure>) { onCompletion?(completion); upstream = nil; downstream.receive(completion: completion) }
    func request(_ demand: Subscribers.Demand) { onRequest?(demand); upstream?.request(demand) }
    func cancel() { onCancel?(); let u = upstream; upstream = nil; u?.cancel() }
}

// MARK: - Operator methods

extension Publisher {
    public func scan<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) -> T) -> Publishers.Scan<Self, T> {
        Publishers.Scan(upstream: self, initialResult: initialResult, nextPartialResult: nextPartialResult)
    }
    public func tryScan<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) throws -> T) -> Publishers.TryScan<Self, T> {
        Publishers.TryScan(upstream: self, initialResult: initialResult, nextPartialResult: nextPartialResult)
    }
    public func reduce<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) -> T) -> Publishers.Reduce<Self, T> {
        Publishers.Reduce(upstream: self, initial: initialResult, nextPartialResult: nextPartialResult)
    }
    public func tryReduce<T>(_ initialResult: T, _ nextPartialResult: @escaping (T, Output) throws -> T) -> Publishers.TryReduce<Self, T> {
        Publishers.TryReduce(upstream: self, initial: initialResult, nextPartialResult: nextPartialResult)
    }
    public func collect() -> Publishers.Collect<Self> { Publishers.Collect(upstream: self) }
    public func collect(_ count: Int) -> Publishers.CollectByCount<Self> { Publishers.CollectByCount(upstream: self, count: count) }
    public func collect<S: Scheduler>(_ strategy: Publishers.TimeGroupingStrategy<S>, options: S.SchedulerOptions? = nil) -> Publishers.CollectByTime<Self, S> {
        Publishers.CollectByTime(upstream: self, strategy: strategy, options: options)
    }
    public func count() -> Publishers.Count<Self> { Publishers.Count(upstream: self) }
    public func min(by areInIncreasingOrder: @escaping (Output, Output) -> Bool) -> Publishers.Comparison<Self> {
        Publishers.Comparison(upstream: self) { best, new in areInIncreasingOrder(new, best) }
    }
    public func max(by areInIncreasingOrder: @escaping (Output, Output) -> Bool) -> Publishers.Comparison<Self> {
        Publishers.Comparison(upstream: self) { best, new in areInIncreasingOrder(best, new) }
    }
    public func tryMin(by areInIncreasingOrder: @escaping (Output, Output) throws -> Bool) -> Publishers.TryComparison<Self> {
        Publishers.TryComparison(upstream: self) { best, new in try areInIncreasingOrder(new, best) }
    }
    public func tryMax(by areInIncreasingOrder: @escaping (Output, Output) throws -> Bool) -> Publishers.TryComparison<Self> {
        Publishers.TryComparison(upstream: self) { best, new in try areInIncreasingOrder(best, new) }
    }
    public func contains(where predicate: @escaping (Output) -> Bool) -> Publishers.ContainsWhere<Self> { Publishers.ContainsWhere(upstream: self, predicate: predicate) }
    public func tryContains(where predicate: @escaping (Output) throws -> Bool) -> Publishers.TryContainsWhere<Self> { Publishers.TryContainsWhere(upstream: self, predicate: predicate) }
    public func allSatisfy(_ predicate: @escaping (Output) -> Bool) -> Publishers.AllSatisfy<Self> { Publishers.AllSatisfy(upstream: self, predicate: predicate) }
    public func tryAllSatisfy(_ predicate: @escaping (Output) throws -> Bool) -> Publishers.TryAllSatisfy<Self> { Publishers.TryAllSatisfy(upstream: self, predicate: predicate) }
    public func first(where predicate: @escaping (Output) -> Bool) -> Publishers.FirstWhere<Self> { Publishers.FirstWhere(upstream: self, predicate: predicate) }
    public func tryFirst(where predicate: @escaping (Output) throws -> Bool) -> Publishers.TryFirstWhere<Self> { Publishers.TryFirstWhere(upstream: self, predicate: predicate) }
    public func last() -> Publishers.Last<Self> { Publishers.Last(upstream: self) }
    public func last(where predicate: @escaping (Output) -> Bool) -> Publishers.LastWhere<Self> { Publishers.LastWhere(upstream: self, predicate: predicate) }
    public func tryLast(where predicate: @escaping (Output) throws -> Bool) -> Publishers.TryLastWhere<Self> { Publishers.TryLastWhere(upstream: self, predicate: predicate) }
    public func ignoreOutput() -> Publishers.IgnoreOutput<Self> { Publishers.IgnoreOutput(upstream: self) }
    public func output(at index: Int) -> Publishers.Output<Self> { Publishers.Output(upstream: self, range: index..<(index + 1)) }
    public func output<R: RangeExpression>(in range: R) -> Publishers.Output<Self> where R.Bound == Int {
        Publishers.Output(upstream: self, range: range.relative(to: 0..<Int.max))
    }
    public func prefix(while predicate: @escaping (Output) -> Bool) -> Publishers.PrefixWhile<Self> { Publishers.PrefixWhile(upstream: self, predicate: predicate) }
    public func tryPrefix(while predicate: @escaping (Output) throws -> Bool) -> Publishers.TryPrefixWhile<Self> { Publishers.TryPrefixWhile(upstream: self, predicate: predicate) }
    public func drop(while predicate: @escaping (Output) -> Bool) -> Publishers.DropWhile<Self> { Publishers.DropWhile(upstream: self, predicate: predicate) }
    public func tryDrop(while predicate: @escaping (Output) throws -> Bool) -> Publishers.TryDropWhile<Self> { Publishers.TryDropWhile(upstream: self, predicate: predicate) }
    public func drop<P: Publisher>(untilOutputFrom publisher: P) -> Publishers.DropUntilOutput<Self, P> where Failure == P.Failure {
        Publishers.DropUntilOutput(upstream: self, other: publisher)
    }
    public func prefix<P: Publisher>(untilOutputFrom publisher: P) -> Publishers.PrefixUntilOutput<Self, P> {
        Publishers.PrefixUntilOutput(upstream: self, other: publisher)
    }
    public func tryFilter(_ isIncluded: @escaping (Output) throws -> Bool) -> Publishers.TryFilter<Self> { Publishers.TryFilter(upstream: self, isIncluded: isIncluded) }
    public func tryCompactMap<T>(_ transform: @escaping (Output) throws -> T?) -> Publishers.TryCompactMap<Self, T> { Publishers.TryCompactMap(upstream: self, transform: transform) }
    public func tryRemoveDuplicates(by predicate: @escaping (Output, Output) throws -> Bool) -> Publishers.TryRemoveDuplicates<Self> {
        Publishers.TryRemoveDuplicates(upstream: self, predicate: predicate)
    }
    public func map<T0, T1>(_ k0: KeyPath<Output, T0>, _ k1: KeyPath<Output, T1>) -> Publishers.Map<Self, (T0, T1)> {
        Publishers.Map(upstream: self) { ($0[keyPath: k0], $0[keyPath: k1]) }
    }
    public func map<T0, T1, T2>(_ k0: KeyPath<Output, T0>, _ k1: KeyPath<Output, T1>, _ k2: KeyPath<Output, T2>) -> Publishers.Map<Self, (T0, T1, T2)> {
        Publishers.Map(upstream: self) { ($0[keyPath: k0], $0[keyPath: k1], $0[keyPath: k2]) }
    }
    public func replaceNil<T>(with output: T) -> Publishers.Map<Self, T> where Output == T? {
        Publishers.Map(upstream: self) { $0 ?? output }
    }

    // errors
    public func mapError<E: Error>(_ transform: @escaping (Failure) -> E) -> Publishers.MapError<Self, E> { Publishers.MapError(upstream: self, transform: transform) }
    public func replaceError(with output: Output) -> Publishers.ReplaceError<Self> { Publishers.ReplaceError(upstream: self, output: output) }
    public func replaceEmpty(with output: Output) -> Publishers.ReplaceEmpty<Self> { Publishers.ReplaceEmpty(upstream: self, output: output) }
    public func assertNoFailure(_ prefix: String = "", file: StaticString = #file, line: UInt = #line) -> Publishers.AssertNoFailure<Self> {
        Publishers.AssertNoFailure(upstream: self, prefix: prefix, file: file, line: line)
    }
    public func `catch`<P: Publisher>(_ handler: @escaping (Failure) -> P) -> Publishers.Catch<Self, P> where P.Output == Output {
        Publishers.Catch(upstream: self, handler: handler)
    }
    public func tryCatch<P: Publisher>(_ handler: @escaping (Failure) throws -> P) -> Publishers.TryCatch<Self, P> where P.Output == Output {
        Publishers.TryCatch(upstream: self, handler: handler)
    }
    public func retry(_ retries: Int) -> Publishers.Retry<Self> { Publishers.Retry(upstream: self, retries: retries) }

    // combining
    public func zip<P: Publisher>(_ other: P) -> Publishers.Zip<Self, P> where P.Failure == Failure { Publishers.Zip(self, other) }
    public func zip<P: Publisher, T>(_ other: P, _ transform: @escaping (Output, P.Output) -> T) -> Publishers.Map<Publishers.Zip<Self, P>, T> where P.Failure == Failure {
        Publishers.Map(upstream: Publishers.Zip(self, other)) { transform($0.0, $0.1) }
    }
    public func zip<P: Publisher, Q: Publisher>(_ p: P, _ q: Q) -> Publishers.Zip3<Self, P, Q> where P.Failure == Failure, Q.Failure == Failure {
        Publishers.Zip3(self, p, q)
    }
    public func zip<P: Publisher, Q: Publisher, R: Publisher>(_ p: P, _ q: Q, _ r: R) -> Publishers.Zip4<Self, P, Q, R>
        where P.Failure == Failure, Q.Failure == Failure, R.Failure == Failure {
        Publishers.Zip4(self, p, q, r)
    }
    public func combineLatest<P: Publisher, T>(_ other: P, _ transform: @escaping (Output, P.Output) -> T) -> Publishers.Map<Publishers.CombineLatest<Self, P>, T> where P.Failure == Failure {
        Publishers.Map(upstream: Publishers.CombineLatest(a: self, b: other)) { transform($0.0, $0.1) }
    }
    public func combineLatest<P: Publisher, Q: Publisher>(_ p: P, _ q: Q) -> Publishers.CombineLatest3<Self, P, Q> where P.Failure == Failure, Q.Failure == Failure {
        Publishers.CombineLatest3(self, p, q)
    }
    public func combineLatest<P: Publisher, Q: Publisher, R: Publisher>(_ p: P, _ q: Q, _ r: R) -> Publishers.CombineLatest4<Self, P, Q, R>
        where P.Failure == Failure, Q.Failure == Failure, R.Failure == Failure {
        Publishers.CombineLatest4(self, p, q, r)
    }
    public func merge<B: Publisher, C: Publisher>(with b: B, _ c: C) -> Publishers.MergeMany<AnyPublisher<Output, Failure>>
        where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure {
        Publishers.MergeMany([eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher()])
    }
    public func merge<B: Publisher, C: Publisher, D: Publisher>(with b: B, _ c: C, _ d: D) -> Publishers.MergeMany<AnyPublisher<Output, Failure>>
        where B.Output == Output, B.Failure == Failure, C.Output == Output, C.Failure == Failure, D.Output == Output, D.Failure == Failure {
        Publishers.MergeMany([eraseToAnyPublisher(), b.eraseToAnyPublisher(), c.eraseToAnyPublisher(), d.eraseToAnyPublisher()])
    }
    public func append(_ elements: Output...) -> Publishers.Concatenate<Self, Publishers.Sequence<[Output], Failure>> {
        Publishers.Concatenate(prefix: self, suffix: Publishers.Sequence(sequence: elements))
    }
    public func append<S: Swift.Sequence>(_ elements: S) -> Publishers.Concatenate<Self, Publishers.Sequence<S, Failure>> where S.Element == Output {
        Publishers.Concatenate(prefix: self, suffix: Publishers.Sequence(sequence: elements))
    }
    public func append<P: Publisher>(_ publisher: P) -> Publishers.Concatenate<Self, P> where P.Output == Output, P.Failure == Failure {
        Publishers.Concatenate(prefix: self, suffix: publisher)
    }
    public func prepend(_ elements: Output...) -> Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Self> {
        Publishers.Concatenate(prefix: Publishers.Sequence(sequence: elements), suffix: self)
    }
    public func prepend<S: Swift.Sequence>(_ elements: S) -> Publishers.Concatenate<Publishers.Sequence<S, Failure>, Self> where S.Element == Output {
        Publishers.Concatenate(prefix: Publishers.Sequence(sequence: elements), suffix: self)
    }
    public func prepend<P: Publisher>(_ publisher: P) -> Publishers.Concatenate<P, Self> where P.Output == Output, P.Failure == Failure {
        Publishers.Concatenate(prefix: publisher, suffix: self)
    }

    // timing
    public func delay<S: Scheduler>(for interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil,
                                    scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.Delay<Self, S> {
        Publishers.Delay(upstream: self, interval: interval, tolerance: tolerance ?? scheduler.minimumTolerance, scheduler: scheduler, options: options)
    }
    public func throttle<S: Scheduler>(for interval: S.SchedulerTimeType.Stride, scheduler: S, latest: Bool) -> Publishers.Throttle<Self, S> {
        Publishers.Throttle(upstream: self, interval: interval, scheduler: scheduler, latest: latest)
    }
    public func timeout<S: Scheduler>(_ interval: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil,
                                      customError: (() -> Failure)? = nil) -> Publishers.Timeout<Self, S> {
        Publishers.Timeout(upstream: self, interval: interval, scheduler: scheduler, options: options, customError: customError)
    }
    public func measureInterval<S: Scheduler>(using scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.MeasureInterval<Self, S> {
        Publishers.MeasureInterval(upstream: self, scheduler: scheduler)
    }
    public func buffer(size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Failure>) -> Publishers.Buffer<Self> {
        Publishers.Buffer(upstream: self, size: size, prefetch: prefetch, whenFull: whenFull)
    }
    public func subscribe<S: Scheduler>(on scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.SubscribeOn<Self, S> {
        Publishers.SubscribeOn(upstream: self, scheduler: scheduler, options: options)
    }

    // sharing
    public func multicast<S: Subject>(_ createSubject: @escaping () -> S) -> Publishers.Multicast<Self, S> where S.Output == Output, S.Failure == Failure {
        Publishers.Multicast(upstream: self, createSubject: createSubject)
    }
    public func multicast<S: Subject>(subject: S) -> Publishers.Multicast<Self, S> where S.Output == Output, S.Failure == Failure {
        Publishers.Multicast(upstream: self) { subject }
    }

    // coding
    public func decode<Item: Decodable, Coder: TopLevelDecoder>(type: Item.Type, decoder: Coder) -> Publishers.Decode<Self, Item, Coder> where Output == Coder.Input {
        Publishers.Decode(upstream: self, decoder: decoder)
    }
    public func encode<Coder: TopLevelEncoder>(encoder: Coder) -> Publishers.Encode<Self, Coder> where Output: Encodable {
        Publishers.Encode(upstream: self, encoder: encoder)
    }

    // debugging
    public func print(_ prefix: String = "", to stream: TextOutputStream? = nil) -> Publishers.Print<Self> {
        Publishers.Print(upstream: self, prefix: prefix, to: stream)
    }
    public func breakpoint(receiveSubscription: ((Subscription) -> Bool)? = nil, receiveOutput: ((Output) -> Bool)? = nil,
                           receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)? = nil) -> Publishers.Breakpoint<Self> {
        Publishers.Breakpoint(upstream: self, receiveSubscription: receiveSubscription, receiveOutput: receiveOutput, receiveCompletion: receiveCompletion)
    }
    public func breakpointOnError() -> Publishers.Breakpoint<Self> {
        Publishers.Breakpoint(upstream: self, receiveCompletion: { if case .failure = $0 { return true }; return false })
    }
}

extension Publisher where Failure == Never {
    public func makeConnectable() -> Publishers.MakeConnectable<Self> { Publishers.MakeConnectable(upstream: self) }
}
extension Publisher where Output: Comparable {
    public func min() -> Publishers.Comparison<Self> { min(by: <) }
    public func max() -> Publishers.Comparison<Self> { max(by: <) }
}
extension Publisher where Output: Equatable {
    public func contains(_ output: Output) -> Publishers.ContainsWhere<Self> { contains { $0 == output } }
}

extension Publisher where Output: Publisher, Output.Failure == Failure {
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> { Publishers.SwitchToLatest(upstream: self) }
}
extension Publisher where Output: Publisher, Failure == Never {
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Publishers.SetFailureType<Self, Output.Failure>> {
        Publishers.SwitchToLatest(upstream: setFailureType(to: Output.Failure.self))
    }
}
extension Publisher where Output: Publisher, Failure == Never, Output.Failure == Never {
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> { Publishers.SwitchToLatest(upstream: self) }
}
extension Publisher where Output: Publisher, Output.Failure == Never {
    public func switchToLatest() -> Publishers.SwitchToLatest<Publishers.SetFailureType<Output, Failure>, Publishers.Map<Self, Publishers.SetFailureType<Output, Failure>>> {
        Publishers.SwitchToLatest(upstream: map { $0.setFailureType(to: Failure.self) })
    }
}

extension Publisher where Failure == Never {
    public func flatMap<P: Publisher>(maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P) -> Publishers.FlatMap<P, Publishers.SetFailureType<Self, P.Failure>> {
        var f = Publishers.FlatMap(upstream: setFailureType(to: P.Failure.self), transform: transform); f.maxPublishers = maxPublishers; return f
    }
}
extension Publisher {
    public func flatMap<P: Publisher>(maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P) -> Publishers.FlatMap<Publishers.SetFailureType<P, Failure>, Self>
        where P.Failure == Never {
        var f = Publishers.FlatMap(upstream: self, transform: { transform($0).setFailureType(to: Failure.self) }); f.maxPublishers = maxPublishers; return f
    }
}
extension Publisher where Failure == Never {
    public func flatMap<P: Publisher>(maxPublishers: Subscribers.Demand = .unlimited, _ transform: @escaping (Output) -> P) -> Publishers.FlatMap<P, Self>
        where P.Failure == Never {
        var f = Publishers.FlatMap(upstream: self, transform: transform); f.maxPublishers = maxPublishers; return f
    }
}

// MARK: - async bridge (.values)

/// The buffer between a publisher and an async iterator. isim requests unlimited demand and queues values
/// (Apple's requests one value per `next()`; values a PassthroughSubject sends in between are lost there).
final class _AsyncBridge<Output, Failure: Error>: Subscriber, Cancellable, @unchecked Sendable {
    typealias Input = Output
    private let lock = _CombineLock()
    private var buffer: [Output] = []
    private var completion: Subscribers.Completion<Failure>?
    private var waiter: CheckedContinuation<Result<Output?, Failure>, Never>?
    private var subscription: Subscription?
    private var cancelled = false

    func receive(subscription s: Subscription) {
        lock.lock()
        if cancelled { lock.unlock(); s.cancel(); return }
        subscription = s
        lock.unlock()
        s.request(.unlimited)
    }
    func receive(_ input: Output) -> Subscribers.Demand {
        lock.lock()
        if let w = waiter { waiter = nil; lock.unlock(); w.resume(returning: .success(input)); return .none }
        buffer.append(input)
        lock.unlock()
        return .none
    }
    func receive(completion c: Subscribers.Completion<Failure>) {
        lock.lock()
        completion = c; subscription = nil
        let w = waiter; waiter = nil
        lock.unlock()
        if let w { w.resume(returning: Self.result(c)) }
    }
    static func result(_ c: Subscribers.Completion<Failure>) -> Result<Output?, Failure> {
        switch c { case .finished: return .success(nil); case .failure(let e): return .failure(e) }
    }
    func cancel() {
        lock.lock()
        cancelled = true
        let s = subscription; subscription = nil
        let w = waiter; waiter = nil
        if completion == nil { completion = .finished }
        lock.unlock()
        s?.cancel()
        w?.resume(returning: .success(nil))
    }
    func next() async -> Result<Output?, Failure> {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (k: CheckedContinuation<Result<Output?, Failure>, Never>) in
                lock.lock()
                if !buffer.isEmpty { let v = buffer.removeFirst(); lock.unlock(); k.resume(returning: .success(v)); return }
                if let c = completion { lock.unlock(); k.resume(returning: Self.result(c)); return }
                waiter = k
                lock.unlock()
            }
        } onCancel: { self.cancel() }
    }
}

public struct AsyncPublisher<P: Publisher>: AsyncSequence where P.Failure == Never {
    public typealias Element = P.Output
    public typealias AsyncIterator = Iterator
    let publisher: P
    public init(_ publisher: P) { self.publisher = publisher }
    public struct Iterator: AsyncIteratorProtocol {
        let bridge: _AsyncBridge<P.Output, Never>
        public mutating func next() async -> P.Output? {
            switch await bridge.next() { case .success(let v): return v; case .failure: return nil }
        }
    }
    public func makeAsyncIterator() -> Iterator {
        let b = _AsyncBridge<P.Output, Never>()
        publisher.subscribe(b)
        return Iterator(bridge: b)
    }
}

public struct AsyncThrowingPublisher<P: Publisher>: AsyncSequence {
    public typealias Element = P.Output
    public typealias AsyncIterator = Iterator
    let publisher: P
    public init(_ publisher: P) { self.publisher = publisher }
    public struct Iterator: AsyncIteratorProtocol {
        let bridge: _AsyncBridge<P.Output, P.Failure>
        public mutating func next() async throws -> P.Output? { try await bridge.next().get() }
    }
    public func makeAsyncIterator() -> Iterator {
        let b = _AsyncBridge<P.Output, P.Failure>()
        publisher.subscribe(b)
        return Iterator(bridge: b)
    }
}

extension Publisher where Failure == Never {
    public var values: AsyncPublisher<Self> { AsyncPublisher(self) }
}
extension Publisher {
    public var values: AsyncThrowingPublisher<Self> { AsyncThrowingPublisher(self) }
}
