// isim Dispatch overlay: the Swift Dispatch API (DispatchQueue, DispatchTime, DispatchWorkItem, groups,
// semaphores, timer sources) over isim's libdispatch subset (C API in <dispatch/dispatch.h>).
// Self-authored; on isim dispatch objects are plain C objects wrapped by these classes.
@_exported import Dispatch
import Darwin

// MARK: - Time

public struct DispatchTime: Comparable, Hashable, Sendable {
    public let rawValue: dispatch_time_t
    public static func now() -> DispatchTime { DispatchTime(rawValue: dispatch_time(DISPATCH_TIME_NOW, 0)) }
    public static let distantFuture = DispatchTime(rawValue: DISPATCH_TIME_FOREVER)
    public init(rawValue: dispatch_time_t) { self.rawValue = rawValue }
    public init(uptimeNanoseconds: UInt64) { rawValue = uptimeNanoseconds == 0 ? 1 : uptimeNanoseconds }
    public var uptimeNanoseconds: UInt64 { rawValue == DISPATCH_TIME_FOREVER ? .max : rawValue }
    public static func < (a: DispatchTime, b: DispatchTime) -> Bool { a.uptimeNanoseconds < b.uptimeNanoseconds }
    public func advanced(by n: DispatchTimeInterval) -> DispatchTime { self + n }
    public func distance(to other: DispatchTime) -> DispatchTimeInterval {
        .nanoseconds(Int(Int64(bitPattern: other.uptimeNanoseconds &- uptimeNanoseconds)))
    }
}

public struct DispatchWallTime: Comparable, Hashable, Sendable {
    public let rawValue: dispatch_time_t
    public static func now() -> DispatchWallTime { DispatchWallTime(rawValue: dispatch_walltime(nil, 0)) }
    public static let distantFuture = DispatchWallTime(rawValue: DISPATCH_TIME_FOREVER)
    init(rawValue: dispatch_time_t) { self.rawValue = rawValue }
    public init(timespec: timespec) { var t = timespec; rawValue = dispatch_walltime(&t, 0) }
    public static func < (a: DispatchWallTime, b: DispatchWallTime) -> Bool {
        // wall times are stored negated
        Int64(bitPattern: a.rawValue) > Int64(bitPattern: b.rawValue)
    }
}

public enum DispatchTimeInterval: Equatable, Hashable, Sendable {
    case seconds(Int)
    case milliseconds(Int)
    case microseconds(Int)
    case nanoseconds(Int)
    case never
    var nanos: Int64 {
        switch self {
        case .seconds(let s): return Int64(s) * 1_000_000_000
        case .milliseconds(let ms): return Int64(ms) * 1_000_000
        case .microseconds(let us): return Int64(us) * 1_000
        case .nanoseconds(let ns): return Int64(ns)
        case .never: return .max
        }
    }
}

public func + (t: DispatchTime, i: DispatchTimeInterval) -> DispatchTime {
    i == .never ? .distantFuture : DispatchTime(rawValue: dispatch_time(t.rawValue, i.nanos))
}
public func - (t: DispatchTime, i: DispatchTimeInterval) -> DispatchTime { DispatchTime(rawValue: dispatch_time(t.rawValue, -i.nanos)) }
public func + (t: DispatchTime, seconds: Double) -> DispatchTime { DispatchTime(rawValue: dispatch_time(t.rawValue, Int64(seconds * 1e9))) }
public func - (t: DispatchTime, seconds: Double) -> DispatchTime { DispatchTime(rawValue: dispatch_time(t.rawValue, Int64(-seconds * 1e9))) }
public func + (t: DispatchWallTime, i: DispatchTimeInterval) -> DispatchWallTime { DispatchWallTime(rawValue: dispatch_time(t.rawValue, i.nanos)) }
public func + (t: DispatchWallTime, seconds: Double) -> DispatchWallTime { DispatchWallTime(rawValue: dispatch_time(t.rawValue, Int64(seconds * 1e9))) }

public enum DispatchTimeoutResult: Sendable { case success, timedOut }

// MARK: - QoS

public struct DispatchQoS: Equatable, Sendable {
    public enum QoSClass: Sendable {
        case background, utility, `default`, userInitiated, userInteractive, unspecified
        var raw: UInt32 {
            switch self {
            case .background: return 0x09
            case .utility: return 0x11
            case .default: return 0x15
            case .userInitiated: return 0x19
            case .userInteractive: return 0x21
            case .unspecified: return 0
            }
        }
    }
    public let qosClass: QoSClass
    public let relativePriority: Int
    public init(qosClass: QoSClass, relativePriority: Int) { self.qosClass = qosClass; self.relativePriority = relativePriority }
    public static let background = DispatchQoS(qosClass: .background, relativePriority: 0)
    public static let utility = DispatchQoS(qosClass: .utility, relativePriority: 0)
    public static let `default` = DispatchQoS(qosClass: .default, relativePriority: 0)
    public static let userInitiated = DispatchQoS(qosClass: .userInitiated, relativePriority: 0)
    public static let userInteractive = DispatchQoS(qosClass: .userInteractive, relativePriority: 0)
    public static let unspecified = DispatchQoS(qosClass: .unspecified, relativePriority: 0)
}

public struct DispatchWorkItemFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let barrier = DispatchWorkItemFlags(rawValue: 1)
    public static let detached = DispatchWorkItemFlags(rawValue: 2)
    public static let assignCurrentContext = DispatchWorkItemFlags(rawValue: 4)
    public static let noQoS = DispatchWorkItemFlags(rawValue: 8)
    public static let inheritQoS = DispatchWorkItemFlags(rawValue: 16)
    public static let enforceQoS = DispatchWorkItemFlags(rawValue: 32)
}

// MARK: - Objects

open class DispatchObject: @unchecked Sendable {
    let object: dispatch_object_t
    init(_ object: UnsafeMutableRawPointer) { self.object = object }
    public func activate() { dispatch_activate(object) }
    public func suspend() { dispatch_suspend(object) }
    public func resume() { dispatch_resume(object) }
}

public final class DispatchWorkItem: @unchecked Sendable {
    let block: () -> Void
    let flags: DispatchWorkItemFlags
    private let lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    private var cancelled = false
    private var done = false
    private var notifications: [(DispatchQueue, () -> Void)] = []
    public init(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], block: @escaping @convention(block) () -> Void) {
        self.block = block; self.flags = flags
        pthread_mutex_init(lock, nil)
    }
    deinit { pthread_mutex_destroy(lock); lock.deallocate() }
    public func perform() {
        if isCancelled { return }
        block()
        pthread_mutex_lock(lock); done = true; let n = notifications; notifications = []; pthread_mutex_unlock(lock)
        for (q, b) in n { q.async(execute: b) }
    }
    public func cancel() { pthread_mutex_lock(lock); cancelled = true; pthread_mutex_unlock(lock) }
    public var isCancelled: Bool { pthread_mutex_lock(lock); defer { pthread_mutex_unlock(lock) }; return cancelled }
    public func notify(queue: DispatchQueue, execute: DispatchWorkItem) { notify(queue: queue) { execute.perform() } }
    public func notify(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], queue: DispatchQueue, execute: @escaping @convention(block) () -> Void) {
        pthread_mutex_lock(lock)
        if done { pthread_mutex_unlock(lock); queue.async(execute: execute); return }
        notifications.append((queue, execute))
        pthread_mutex_unlock(lock)
    }
    public func wait() {
        while true {
            pthread_mutex_lock(lock); let d = done || cancelled; pthread_mutex_unlock(lock)
            if d { return }
            usleep(500)
        }
    }
}

public final class DispatchSpecificKey<T> {
    public init() {}
}

public final class DispatchQueue: DispatchObject, @unchecked Sendable {
    public struct Attributes: OptionSet, Sendable {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public static let concurrent = Attributes(rawValue: 1)
        public static let initiallyInactive = Attributes(rawValue: 2)
    }
    public enum AutoreleaseFrequency: Sendable { case inherit, workItem, never }
    public enum GlobalQueuePriority: Sendable { case high, `default`, low, background }

    var queue: dispatch_queue_t { OpaquePointer(object) }
    init(queue: dispatch_queue_t) { super.init(UnsafeMutableRawPointer(queue)) }

    public static let main = DispatchQueue(queue: _isim_dispatch_main_queue())
    nonisolated(unsafe) private static var globals: [UInt32: DispatchQueue] = [:]
    private static let globalsLock: UnsafeMutablePointer<pthread_mutex_t> = {
        let m = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1); pthread_mutex_init(m, nil); return m
    }()
    public class func global(qos: DispatchQoS.QoSClass = .default) -> DispatchQueue {
        pthread_mutex_lock(globalsLock); defer { pthread_mutex_unlock(globalsLock) }
        if let q = globals[qos.raw] { return q }
        let q = DispatchQueue(queue: dispatch_get_global_queue(Int(qos.raw), 0))
        globals[qos.raw] = q
        return q
    }
    public class func global(priority: GlobalQueuePriority) -> DispatchQueue {
        switch priority {
        case .high: return global(qos: .userInitiated)
        case .default: return global(qos: .default)
        case .low: return global(qos: .utility)
        case .background: return global(qos: .background)
        }
    }

    public convenience init(label: String, qos: DispatchQoS = .unspecified, attributes: Attributes = [],
                            autoreleaseFrequency: AutoreleaseFrequency = .inherit, target: DispatchQueue? = nil) {
        let attr: dispatch_queue_attr_t? = attributes.contains(.concurrent) ? _isim_dispatch_concurrent_attr() : nil
        let q = label.withCString { dispatch_queue_create_with_target($0, attr, target?.queue) }!
        self.init(queue: q)
    }

    public var label: String { String(cString: dispatch_queue_get_label(queue)) }

    public func async(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                      execute work: @escaping @convention(block) () -> Void) {
        if let g = group { dispatch_group_async(g.group, queue, work) }
        else if flags.contains(.barrier) { dispatch_barrier_async(queue, work) }
        else { dispatch_async(queue, work) }
    }
    public func async(execute workItem: DispatchWorkItem) {
        if workItem.flags.contains(.barrier) { dispatch_barrier_async(queue) { workItem.perform() } }
        else { dispatch_async(queue) { workItem.perform() } }
    }
    public func async(group: DispatchGroup, execute workItem: DispatchWorkItem) {
        dispatch_group_async(group.group, queue) { workItem.perform() }
    }
    public func asyncAfter(deadline: DispatchTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                           execute work: @escaping @convention(block) () -> Void) {
        dispatch_after(deadline.rawValue, queue, work)
    }
    public func asyncAfter(deadline: DispatchTime, execute: DispatchWorkItem) {
        dispatch_after(deadline.rawValue, queue) { execute.perform() }
    }
    public func asyncAfter(wallDeadline: DispatchWallTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                           execute work: @escaping @convention(block) () -> Void) {
        dispatch_after(wallDeadline.rawValue, queue, work)
    }
    public func asyncAfter(wallDeadline: DispatchWallTime, execute: DispatchWorkItem) {
        dispatch_after(wallDeadline.rawValue, queue) { execute.perform() }
    }

    public func sync(execute block: () -> Void) {
        withoutActuallyEscaping(block) { b in dispatch_sync(queue, b) }
    }
    public func sync(execute workItem: DispatchWorkItem) { sync { workItem.perform() } }
    public func sync(flags: DispatchWorkItemFlags, execute block: () -> Void) {
        withoutActuallyEscaping(block) { b in
            if flags.contains(.barrier) { dispatch_barrier_sync(queue, b) } else { dispatch_sync(queue, b) }
        }
    }
    public func sync<T>(execute work: () throws -> T) rethrows -> T {
        var result: Result<T, Error>?
        return try withoutActuallyEscaping(work) { w in
            sync { result = Result { try w() } }
            return try result!.get()
        }
    }
    public func sync<T>(flags: DispatchWorkItemFlags, execute work: () throws -> T) rethrows -> T {
        var result: Result<T, Error>?
        return try withoutActuallyEscaping(work) { w in
            sync(flags: flags) { result = Result { try w() } }
            return try result!.get()
        }
    }
    public class func concurrentPerform(iterations: Int, execute work: (Int) -> Void) {
        withoutActuallyEscaping(work) { w in dispatch_apply(iterations, dispatch_get_global_queue(0, 0)) { w($0) } }
    }

    // queue-specific data
    final class Box<T> { let value: T; init(_ v: T) { value = v } }
    public func setSpecific<T>(key: DispatchSpecificKey<T>, value: T?) {
        let k = Unmanaged.passUnretained(key).toOpaque()
        if let old = dispatch_queue_get_specific(queue, k) { Unmanaged<AnyObject>.fromOpaque(old).release() }
        let ctx = value.map { Unmanaged.passRetained(Box($0) as AnyObject).toOpaque() }
        dispatch_queue_set_specific(queue, k, ctx, nil)
    }
    public func getSpecific<T>(key: DispatchSpecificKey<T>) -> T? {
        guard let p = dispatch_queue_get_specific(queue, Unmanaged.passUnretained(key).toOpaque()) else { return nil }
        return (Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() as? Box<T>)?.value
    }
    public class func getSpecific<T>(key: DispatchSpecificKey<T>) -> T? {
        guard let p = dispatch_get_specific(Unmanaged.passUnretained(key).toOpaque()) else { return nil }
        return (Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() as? Box<T>)?.value
    }
}

public final class DispatchGroup: DispatchObject, @unchecked Sendable {
    var group: dispatch_group_t { OpaquePointer(object) }
    public init() { super.init(UnsafeMutableRawPointer(dispatch_group_create()!)) }
    public func enter() { dispatch_group_enter(group) }
    public func leave() { dispatch_group_leave(group) }
    public func wait() { _ = dispatch_group_wait(group, DISPATCH_TIME_FOREVER) }
    public func wait(timeout: DispatchTime) -> DispatchTimeoutResult { dispatch_group_wait(group, timeout.rawValue) == 0 ? .success : .timedOut }
    public func wait(wallTimeout: DispatchWallTime) -> DispatchTimeoutResult { dispatch_group_wait(group, wallTimeout.rawValue) == 0 ? .success : .timedOut }
    public func notify(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], queue: DispatchQueue,
                       execute work: @escaping @convention(block) () -> Void) {
        dispatch_group_notify(group, queue.queue, work)
    }
    public func notify(queue: DispatchQueue, work: DispatchWorkItem) { dispatch_group_notify(group, queue.queue) { work.perform() } }
}

public final class DispatchSemaphore: DispatchObject, @unchecked Sendable {
    var sema: dispatch_semaphore_t { OpaquePointer(object) }
    public init(value: Int) { super.init(UnsafeMutableRawPointer(dispatch_semaphore_create(value)!)) }
    @discardableResult public func signal() -> Int { dispatch_semaphore_signal(sema) }
    public func wait() { _ = dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER) }
    public func wait(timeout: DispatchTime) -> DispatchTimeoutResult { dispatch_semaphore_wait(sema, timeout.rawValue) == 0 ? .success : .timedOut }
    public func wait(wallTimeout: DispatchWallTime) -> DispatchTimeoutResult { dispatch_semaphore_wait(sema, wallTimeout.rawValue) == 0 ? .success : .timedOut }
}

// MARK: - Sources

public typealias DispatchSourceHandler = @convention(block) () -> Void

public protocol DispatchSourceProtocol {
    func setEventHandler(qos: DispatchQoS, flags: DispatchWorkItemFlags, handler: DispatchSourceHandler?)
    func setEventHandler(handler: DispatchWorkItem)
    func setCancelHandler(qos: DispatchQoS, flags: DispatchWorkItemFlags, handler: DispatchSourceHandler?)
    func setCancelHandler(handler: DispatchWorkItem)
    func setRegistrationHandler(qos: DispatchQoS, flags: DispatchWorkItemFlags, handler: DispatchSourceHandler?)
    func setRegistrationHandler(handler: DispatchWorkItem)
    func resume()
    func suspend()
    func activate()
    func cancel()
    var handle: UInt { get }
    var mask: UInt { get }
    var data: UInt { get }
    var isCancelled: Bool { get }
}
extension DispatchSourceProtocol {
    public func setEventHandler(handler: DispatchSourceHandler?) { setEventHandler(qos: .unspecified, flags: [], handler: handler) }
    public func setCancelHandler(handler: DispatchSourceHandler?) { setCancelHandler(qos: .unspecified, flags: [], handler: handler) }
    public func setRegistrationHandler(handler: DispatchSourceHandler?) { setRegistrationHandler(qos: .unspecified, flags: [], handler: handler) }
}
public protocol DispatchSourceTimer: DispatchSourceProtocol {
    func schedule(deadline: DispatchTime, repeating interval: DispatchTimeInterval, leeway: DispatchTimeInterval)
    func schedule(deadline: DispatchTime, repeating interval: Double, leeway: DispatchTimeInterval)
    func schedule(wallDeadline: DispatchWallTime, repeating interval: DispatchTimeInterval, leeway: DispatchTimeInterval)
    func schedule(wallDeadline: DispatchWallTime, repeating interval: Double, leeway: DispatchTimeInterval)
}
extension DispatchSourceTimer {
    public func schedule(deadline: DispatchTime, repeating interval: DispatchTimeInterval = .never, leeway: DispatchTimeInterval = .nanoseconds(0)) {
        schedule(deadline: deadline, repeating: interval, leeway: leeway)
    }
    public func schedule(deadline: DispatchTime, repeating interval: Double, leeway: DispatchTimeInterval = .nanoseconds(0)) {
        schedule(deadline: deadline, repeating: interval, leeway: leeway)
    }
    public func schedule(wallDeadline: DispatchWallTime, repeating interval: DispatchTimeInterval = .never, leeway: DispatchTimeInterval = .nanoseconds(0)) {
        schedule(wallDeadline: wallDeadline, repeating: interval, leeway: leeway)
    }
    public func schedule(wallDeadline: DispatchWallTime, repeating interval: Double, leeway: DispatchTimeInterval = .nanoseconds(0)) {
        schedule(wallDeadline: wallDeadline, repeating: interval, leeway: leeway)
    }
}
public protocol DispatchSourceUserDataAdd: DispatchSourceProtocol { func add(data: UInt) }
public protocol DispatchSourceUserDataOr: DispatchSourceProtocol { func or(data: UInt) }
public protocol DispatchSourceUserDataReplace: DispatchSourceProtocol { func replace(data: UInt) }
public protocol DispatchSourceRead: DispatchSourceProtocol {}
public protocol DispatchSourceWrite: DispatchSourceProtocol {}
public protocol DispatchSourceSignal: DispatchSourceProtocol {}
public protocol DispatchSourceProcess: DispatchSourceProtocol {}
public protocol DispatchSourceFileSystemObject: DispatchSourceProtocol {}
public protocol DispatchSourceMemoryPressure: DispatchSourceProtocol {}
public protocol DispatchSourceMachSend: DispatchSourceProtocol {}
public protocol DispatchSourceMachReceive: DispatchSourceProtocol {}
// typed views, like Apple's overlay (overloads of the UInt requirements)
extension DispatchSourceProcess {
    public var handle: pid_t { pid_t(truncatingIfNeeded: (self as DispatchSourceProtocol).handle) }
    public var data: DispatchSource.ProcessEvent { DispatchSource.ProcessEvent(rawValue: (self as DispatchSourceProtocol).data) }
    public var mask: DispatchSource.ProcessEvent { DispatchSource.ProcessEvent(rawValue: (self as DispatchSourceProtocol).mask) }
}
extension DispatchSourceFileSystemObject {
    public var handle: Int32 { Int32(truncatingIfNeeded: (self as DispatchSourceProtocol).handle) }
    public var data: DispatchSource.FileSystemEvent { DispatchSource.FileSystemEvent(rawValue: (self as DispatchSourceProtocol).data) }
    public var mask: DispatchSource.FileSystemEvent { DispatchSource.FileSystemEvent(rawValue: (self as DispatchSourceProtocol).mask) }
}
extension DispatchSourceMachSend {
    public var handle: mach_port_t { mach_port_t(truncatingIfNeeded: (self as DispatchSourceProtocol).handle) }
    public var data: DispatchSource.MachSendEvent { DispatchSource.MachSendEvent(rawValue: (self as DispatchSourceProtocol).data) }
    public var mask: DispatchSource.MachSendEvent { DispatchSource.MachSendEvent(rawValue: (self as DispatchSourceProtocol).mask) }
}
extension DispatchSourceMachReceive {
    public var handle: mach_port_t { mach_port_t(truncatingIfNeeded: (self as DispatchSourceProtocol).handle) }
}
extension DispatchSourceMemoryPressure {
    public var data: DispatchSource.MemoryPressureEvent { DispatchSource.MemoryPressureEvent(rawValue: (self as DispatchSourceProtocol).data) }
    public var mask: DispatchSource.MemoryPressureEvent { DispatchSource.MemoryPressureEvent(rawValue: (self as DispatchSourceProtocol).mask) }
}

public enum DispatchSource {
    public struct TimerFlags: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let strict = TimerFlags(rawValue: 1)
    }
    public struct ProcessEvent: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let exit = ProcessEvent(rawValue: 0x8000_0000)
        public static let fork = ProcessEvent(rawValue: 0x4000_0000)
        public static let exec = ProcessEvent(rawValue: 0x2000_0000)
        public static let signal = ProcessEvent(rawValue: 0x0800_0000)
        public static let all: ProcessEvent = [.exit, .fork, .exec, .signal]
    }
    public struct FileSystemEvent: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let delete = FileSystemEvent(rawValue: 0x1)
        public static let write = FileSystemEvent(rawValue: 0x2)
        public static let extend = FileSystemEvent(rawValue: 0x4)
        public static let attrib = FileSystemEvent(rawValue: 0x8)
        public static let link = FileSystemEvent(rawValue: 0x10)
        public static let rename = FileSystemEvent(rawValue: 0x20)
        public static let revoke = FileSystemEvent(rawValue: 0x40)
        public static let funlock = FileSystemEvent(rawValue: 0x100)
        public static let all: FileSystemEvent = [.delete, .write, .extend, .attrib, .link, .rename, .revoke]
    }
    public struct MachSendEvent: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let dead = MachSendEvent(rawValue: 0x1)
        public static let possible = MachSendEvent(rawValue: 0x2)
    }
    public struct MemoryPressureEvent: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let normal = MemoryPressureEvent(rawValue: 1)
        public static let warning = MemoryPressureEvent(rawValue: 2)
        public static let critical = MemoryPressureEvent(rawValue: 4)
        public static let all: MemoryPressureEvent = [.normal, .warning, .critical]
    }
    public static func makeTimerSource(flags: TimerFlags = [], queue: DispatchQueue? = nil) -> DispatchSourceTimer {
        _TimerSource(queue: queue ?? DispatchQueue.global())
    }
    public static func makeUserDataAddSource(queue: DispatchQueue? = nil) -> DispatchSourceUserDataAdd { _UserDataSource(kind: 1, queue: queue) }
    public static func makeUserDataOrSource(queue: DispatchQueue? = nil) -> DispatchSourceUserDataOr { _UserDataSource(kind: 2, queue: queue) }
    public static func makeUserDataReplaceSource(queue: DispatchQueue? = nil) -> DispatchSourceUserDataReplace { _UserDataSource(kind: 3, queue: queue) }
    public static func makeReadSource(fileDescriptor: Int32, queue: DispatchQueue? = nil) -> DispatchSourceRead {
        _FDSource(kind: 4, handle: UInt(bitPattern: Int(fileDescriptor)), mask: 0, queue: queue)
    }
    public static func makeWriteSource(fileDescriptor: Int32, queue: DispatchQueue? = nil) -> DispatchSourceWrite {
        _FDSource(kind: 5, handle: UInt(bitPattern: Int(fileDescriptor)), mask: 0, queue: queue)
    }
    public static func makeSignalSource(signal: Int32, queue: DispatchQueue? = nil) -> DispatchSourceSignal {
        _FDSource(kind: 6, handle: UInt(signal), mask: 0, queue: queue)
    }
    public static func makeProcessSource(identifier: pid_t, eventMask: ProcessEvent, queue: DispatchQueue? = nil) -> DispatchSourceProcess {
        _ProcessSource(kind: 7, handle: UInt(identifier), mask: eventMask.rawValue, queue: queue)
    }
    public static func makeFileSystemObjectSource(fileDescriptor: Int32, eventMask: FileSystemEvent, queue: DispatchQueue? = nil) -> DispatchSourceFileSystemObject {
        _FileSystemSource(kind: 8, handle: UInt(bitPattern: Int(fileDescriptor)), mask: eventMask.rawValue, queue: queue)
    }
    /// Fires on the Simulator's memory warning (script `memorywarning [warn|critical|normal]`).
    public static func makeMemoryPressureSource(eventMask: MemoryPressureEvent, queue: DispatchQueue? = nil) -> DispatchSourceMemoryPressure {
        _MemoryPressureSource(kind: 9, handle: 0, mask: eventMask.rawValue, queue: queue)
    }
    /// `.dead` when the port's receive right is destroyed (isim's in-process ports); `.possible` never fires.
    public static func makeMachSendSource(port: mach_port_t, eventMask: MachSendEvent, queue: DispatchQueue? = nil) -> DispatchSourceMachSend {
        _MachSource(kind: 10, handle: UInt(port), mask: eventMask.rawValue, queue: queue)
    }
    /// Fires while messages are queued on the port (receive them with `mach_msg` in the handler).
    public static func makeMachReceiveSource(port: mach_port_t, queue: DispatchQueue? = nil) -> DispatchSourceMachReceive {
        _MachSource(kind: 11, handle: UInt(port), mask: 0, queue: queue)
    }
}

class _SourceBase: DispatchObject, @unchecked Sendable {
    var source: dispatch_source_t { OpaquePointer(object) }
    init(type: dispatch_source_type_t, handle: UInt, mask: UInt, queue: DispatchQueue?) {
        // an invalid file descriptor or signal gives a source that never fires (Apple crashes instead)
        let q = (queue ?? DispatchQueue.global()).queue
        let s = dispatch_source_create(type, handle, mask, q) ?? dispatch_source_create(_isim_dispatch_source_type(1), 0, 0, q)!
        super.init(UnsafeMutableRawPointer(s))
    }
    deinit { dispatch_release(object) }
    func setEventHandler(qos: DispatchQoS, flags: DispatchWorkItemFlags, handler: DispatchSourceHandler?) {
        dispatch_source_set_event_handler(source, handler ?? {})
    }
    func setEventHandler(handler: DispatchWorkItem) { dispatch_source_set_event_handler(source) { handler.perform() } }
    func setCancelHandler(qos: DispatchQoS, flags: DispatchWorkItemFlags, handler: DispatchSourceHandler?) {
        dispatch_source_set_cancel_handler(source, handler ?? {})
    }
    func setCancelHandler(handler: DispatchWorkItem) { dispatch_source_set_cancel_handler(source) { handler.perform() } }
    func setRegistrationHandler(qos: DispatchQoS, flags: DispatchWorkItemFlags, handler: DispatchSourceHandler?) {
        dispatch_source_set_registration_handler(source, handler ?? {})
    }
    func setRegistrationHandler(handler: DispatchWorkItem) { dispatch_source_set_registration_handler(source) { handler.perform() } }
    func cancel() { dispatch_source_cancel(source) }
    var isCancelled: Bool { dispatch_source_testcancel(source) != 0 }
    var rawHandle: UInt { dispatch_source_get_handle(source) }
    var rawMask: UInt { dispatch_source_get_mask(source) }
    var rawData: UInt { dispatch_source_get_data(source) }
}

final class _TimerSource: _SourceBase, DispatchSourceTimer, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(queue: DispatchQueue) { super.init(type: _isim_dispatch_timer_type(), handle: 0, mask: 0, queue: queue) }
    func schedule(deadline: DispatchTime, repeating interval: DispatchTimeInterval, leeway: DispatchTimeInterval) {
        let i: UInt64 = interval == .never ? DISPATCH_TIME_FOREVER : UInt64(max(0, interval.nanos))
        dispatch_source_set_timer(source, deadline.rawValue, i, UInt64(max(0, leeway.nanos)))
    }
    func schedule(deadline: DispatchTime, repeating interval: Double, leeway: DispatchTimeInterval) {
        dispatch_source_set_timer(source, deadline.rawValue, interval.isInfinite ? DISPATCH_TIME_FOREVER : UInt64(interval * 1e9), UInt64(max(0, leeway.nanos)))
    }
    func schedule(wallDeadline: DispatchWallTime, repeating interval: DispatchTimeInterval, leeway: DispatchTimeInterval) {
        let i: UInt64 = interval == .never ? DISPATCH_TIME_FOREVER : UInt64(max(0, interval.nanos))
        dispatch_source_set_timer(source, wallDeadline.rawValue, i, UInt64(max(0, leeway.nanos)))
    }
    func schedule(wallDeadline: DispatchWallTime, repeating interval: Double, leeway: DispatchTimeInterval) {
        dispatch_source_set_timer(source, wallDeadline.rawValue, interval.isInfinite ? DISPATCH_TIME_FOREVER : UInt64(interval * 1e9), UInt64(max(0, leeway.nanos)))
    }
}

final class _UserDataSource: _SourceBase, DispatchSourceUserDataAdd, DispatchSourceUserDataOr, DispatchSourceUserDataReplace, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(kind: Int32, queue: DispatchQueue?) { super.init(type: _isim_dispatch_source_type(kind), handle: 0, mask: 0, queue: queue) }
    func add(data: UInt) { dispatch_source_merge_data(source, data) }
    func or(data: UInt) { dispatch_source_merge_data(source, data) }
    func replace(data: UInt) { dispatch_source_merge_data(source, data) }
}

final class _FDSource: _SourceBase, DispatchSourceRead, DispatchSourceWrite, DispatchSourceSignal, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(kind: Int32, handle: UInt, mask: UInt, queue: DispatchQueue?) { super.init(type: _isim_dispatch_source_type(kind), handle: handle, mask: mask, queue: queue) }
}

final class _ProcessSource: _SourceBase, DispatchSourceProcess, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(kind: Int32, handle: UInt, mask: UInt, queue: DispatchQueue?) { super.init(type: _isim_dispatch_source_type(kind), handle: handle, mask: mask, queue: queue) }
}

final class _FileSystemSource: _SourceBase, DispatchSourceFileSystemObject, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(kind: Int32, handle: UInt, mask: UInt, queue: DispatchQueue?) { super.init(type: _isim_dispatch_source_type(kind), handle: handle, mask: mask, queue: queue) }
}

final class _MemoryPressureSource: _SourceBase, DispatchSourceMemoryPressure, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(kind: Int32, handle: UInt, mask: UInt, queue: DispatchQueue?) { super.init(type: _isim_dispatch_source_type(kind), handle: handle, mask: mask, queue: queue) }
}

final class _MachSource: _SourceBase, DispatchSourceMachSend, DispatchSourceMachReceive, @unchecked Sendable {
    var handle: UInt { rawHandle }
    var mask: UInt { rawMask }
    var data: UInt { rawData }
    init(kind: Int32, handle: UInt, mask: UInt, queue: DispatchQueue?) { super.init(type: _isim_dispatch_source_type(kind), handle: handle, mask: mask, queue: queue) }
}

// MARK: - Preconditions

public enum DispatchPredicate {
    case onQueue(DispatchQueue)
    case onQueueAsBarrier(DispatchQueue)
    case notOnQueue(DispatchQueue)
}
public func dispatchPrecondition(condition: @autoclosure () -> DispatchPredicate) {
    switch condition() {
    case .onQueue(let q), .onQueueAsBarrier(let q): dispatch_assert_queue(q.queue)
    case .notOnQueue(let q): dispatch_assert_queue_not(q.queue)
    }
}
