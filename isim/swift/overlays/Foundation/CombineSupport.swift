// isim Foundation: the Combine schedulers and publishers that Foundation provides on Apple platforms
// (DispatchQueue and RunLoop as Schedulers, Timer.publish, NotificationCenter.publisher).
@_exported import Combine

extension DispatchQueue: Scheduler {
    public struct SchedulerTimeType: Strideable, Hashable {
        public var dispatchTime: DispatchTime
        public init(_ time: DispatchTime) { dispatchTime = time }
        public func distance(to other: SchedulerTimeType) -> Stride {
            Stride(Int(other.dispatchTime.uptimeNanoseconds) - Int(dispatchTime.uptimeNanoseconds))
        }
        public func advanced(by n: Stride) -> SchedulerTimeType {
            SchedulerTimeType(DispatchTime(uptimeNanoseconds: UInt64(max(0, Int(dispatchTime.uptimeNanoseconds) + n.magnitude))))
        }
        public static func == (a: SchedulerTimeType, b: SchedulerTimeType) -> Bool { a.dispatchTime.uptimeNanoseconds == b.dispatchTime.uptimeNanoseconds }
        public func hash(into h: inout Hasher) { h.combine(dispatchTime.uptimeNanoseconds) }
        public struct Stride: SchedulerTimeIntervalConvertible, Comparable, SignedNumeric, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, Hashable {
            /// nanoseconds
            public var magnitude: Int
            public init(_ ns: Int) { magnitude = ns }
            public init(integerLiteral s: Int) { magnitude = s * 1_000_000_000 }
            public init(floatLiteral s: Double) { magnitude = Int(s * 1e9) }
            public init?<T: BinaryInteger>(exactly s: T) { magnitude = Int(s) * 1_000_000_000 }
            public var timeInterval: Double { Double(magnitude) / 1e9 }
            public static func seconds(_ s: Int) -> Stride { Stride(s * 1_000_000_000) }
            public static func seconds(_ s: Double) -> Stride { Stride(Int(s * 1e9)) }
            public static func milliseconds(_ ms: Int) -> Stride { Stride(ms * 1_000_000) }
            public static func microseconds(_ us: Int) -> Stride { Stride(us * 1_000) }
            public static func nanoseconds(_ ns: Int) -> Stride { Stride(ns) }
            public static func < (a: Stride, b: Stride) -> Bool { a.magnitude < b.magnitude }
            public static func + (a: Stride, b: Stride) -> Stride { Stride(a.magnitude + b.magnitude) }
            public static func - (a: Stride, b: Stride) -> Stride { Stride(a.magnitude - b.magnitude) }
            public static func * (a: Stride, b: Stride) -> Stride { Stride(Int(Double(a.magnitude) * b.timeInterval)) }
            public static func += (a: inout Stride, b: Stride) { a = a + b }
            public static func -= (a: inout Stride, b: Stride) { a = a - b }
            public static func *= (a: inout Stride, b: Stride) { a = a * b }
        }
    }
    public struct SchedulerOptions {}
    public var now: SchedulerTimeType { SchedulerTimeType(DispatchTime.now()) }
    public var minimumTolerance: SchedulerTimeType.Stride { .nanoseconds(0) }
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) { async(execute: action) }
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        asyncAfter(deadline: date.dispatchTime, execute: action)
    }
}

extension RunLoop: Scheduler {
    public struct SchedulerTimeType: Strideable, Hashable {
        public var date: Date
        public init(_ date: Date) { self.date = date }
        public func distance(to other: SchedulerTimeType) -> Stride { Stride(other.date.timeIntervalSince(date)) }
        public func advanced(by n: Stride) -> SchedulerTimeType { SchedulerTimeType(date.addingTimeInterval(n.timeInterval)) }
        public struct Stride: SchedulerTimeIntervalConvertible, Comparable, SignedNumeric, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, Hashable {
            public var magnitude: Double
            public var timeInterval: Double { magnitude }
            public init(_ s: Double) { magnitude = s }
            public init(integerLiteral s: Int) { magnitude = Double(s) }
            public init(floatLiteral s: Double) { magnitude = s }
            public init?<T: BinaryInteger>(exactly s: T) { magnitude = Double(s) }
            public static func seconds(_ s: Int) -> Stride { Stride(Double(s)) }
            public static func seconds(_ s: Double) -> Stride { Stride(s) }
            public static func milliseconds(_ ms: Int) -> Stride { Stride(Double(ms) / 1e3) }
            public static func microseconds(_ us: Int) -> Stride { Stride(Double(us) / 1e6) }
            public static func nanoseconds(_ ns: Int) -> Stride { Stride(Double(ns) / 1e9) }
            public static func < (a: Stride, b: Stride) -> Bool { a.magnitude < b.magnitude }
            public static func + (a: Stride, b: Stride) -> Stride { Stride(a.magnitude + b.magnitude) }
            public static func - (a: Stride, b: Stride) -> Stride { Stride(a.magnitude - b.magnitude) }
            public static func * (a: Stride, b: Stride) -> Stride { Stride(a.magnitude * b.magnitude) }
            public static func += (a: inout Stride, b: Stride) { a = a + b }
            public static func -= (a: inout Stride, b: Stride) { a = a - b }
            public static func *= (a: inout Stride, b: Stride) { a = a * b }
        }
    }
    public struct SchedulerOptions {}
    public var now: SchedulerTimeType { SchedulerTimeType(Date()) }
    public var minimumTolerance: SchedulerTimeType.Stride { 0 }
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        nonisolated(unsafe) let action = action
        perform { action() }                            // this run loop's common modes
    }
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        nonisolated(unsafe) let action = action
        add(Timer(fire: date.date, interval: 0, repeats: false) { _ in action() }, forMode: .default)
    }
}

// MARK: - Timer.publish, NotificationCenter.publisher

extension Timer {
    /// isim: a block timer on the current run loop in its common modes, for isim's system frameworks: their timers keep
    /// running while the user scrolls (the main run loop's tracking mode), as on iOS. Apps' scheduledTimer uses the default mode.
    @discardableResult
    public static func _isimScheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping @Sendable (Timer) -> Void) -> Timer {
        let t = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.current.add(t, forMode: .common)
        return t
    }
}

extension Timer {
    public static func publish(every interval: TimeInterval, tolerance: TimeInterval? = nil, on runLoop: RunLoop,
                               in mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil) -> TimerPublisher {
        TimerPublisher(interval: interval, runLoop: runLoop, mode: mode)
    }

    public final class TimerPublisher: ConnectablePublisher {
        public typealias Output = Date
        public typealias Failure = Never
        public let interval: TimeInterval
        public let runLoop: RunLoop
        public let mode: RunLoop.Mode
        private let subject = PassthroughSubject<Date, Never>()
        public init(interval: TimeInterval, tolerance: TimeInterval? = nil, runLoop: RunLoop, mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil) {
            self.interval = interval; self.runLoop = runLoop; self.mode = mode
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Date, S.Failure == Never { subject.receive(subscriber: subscriber) }
        public func connect() -> Cancellable {
            let subj = subject
            let timer = Timer(timeInterval: interval, repeats: true) { _ in subj.send(Date()) }
            runLoop.add(timer, forMode: mode)              // the run loop and mode it was published on
            return AnyCancellable { timer.invalidate() }
        }
    }
}

extension NotificationCenter {
    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> Publisher {
        Publisher(center: self, name: name, object: object)
    }
    public struct Publisher: Combine.Publisher {
        public typealias Output = Notification
        public typealias Failure = Never
        public let center: NotificationCenter
        public let name: Notification.Name
        public let object: AnyObject?
        public init(center: NotificationCenter, name: Notification.Name, object: AnyObject? = nil) {
            self.center = center; self.name = name; self.object = object
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Notification, S.Failure == Never {
            let token = _FoundationRef<NSObjectProtocol?>(nil), c = center
            let sub = _FoundationForwardingSubscription(subscriber, onCancel: { if let o = token.value { c.removeObserver(o) } })
            subscriber.receive(subscription: sub)
            token.value = center.addObserver(forName: name, object: object, queue: nil) { n in sub.send(n) }
        }
    }
}


final class _FoundationRef<T> { var value: T; init(_ v: T) { value = v } }

/// Pushes values to one subscriber while it has demand.
final class _FoundationForwardingSubscription<S: Subscriber>: Subscription {
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
}

// Combine's decode(type:decoder:) / encode(encoder:)
extension JSONDecoder: TopLevelDecoder { public typealias Input = Data }
extension JSONEncoder: TopLevelEncoder { public typealias Output = Data }
extension PropertyListDecoder: TopLevelDecoder { public typealias Input = Data }
extension PropertyListEncoder: TopLevelEncoder { public typealias Output = Data }
