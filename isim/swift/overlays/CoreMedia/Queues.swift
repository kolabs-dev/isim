// isim Core Media: simple queues (CMSimpleQueue.h) and buffer queues (CMBufferQueue.h), adapted: in-process queues with
// Apple's ordering, timestamps, end-of-data and trigger rules, locked so that producers and consumers may run on
// different threads. One implementation serves Swift and C: the C functions (frameworks/CoreMedia/CMBufferQueue.m and
// the @_cdecl entry points below) work on the same objects. Buffer callbacks are Swift closures here because CMTime is a
// Swift struct in isim's Swift (Apple's are C function pointers); C callers pass C function pointers.
import CoreVideo
import AudioToolbox

// MARK: - CMSimpleQueue

public var kCMSimpleQueueError_AllocationFailed: OSStatus { -12770 }
public var kCMSimpleQueueError_RequiredParameterMissing: OSStatus { -12771 }
public var kCMSimpleQueueError_ParameterOutOfRange: OSStatus { -12772 }
public var kCMSimpleQueueError_QueueIsFull: OSStatus { -12773 }

let _kCMSimpleQueueTypeID: CFTypeID = 0x5c01
let _kCMBufferQueueTypeID: CFTypeID = 0x5c02

/// a fixed-capacity FIFO of pointer-sized elements
public final class CMSimpleQueue: @unchecked Sendable {
    let _lock = NSLock()
    let _capacity: Int
    var _elements: [UnsafeRawPointer?]
    var _head = 0, _count = 0
    init(_capacity: Int) { self._capacity = _capacity; _elements = Array(repeating: nil, count: _capacity) }

    public struct Error {
        public static let allocationFailed = NSError(domain: NSOSStatusErrorDomain, code: Int(kCMSimpleQueueError_AllocationFailed))
        public static let requiredParameterMissing = NSError(domain: NSOSStatusErrorDomain, code: Int(kCMSimpleQueueError_RequiredParameterMissing))
        public static let parameterOutOfRange = NSError(domain: NSOSStatusErrorDomain, code: Int(kCMSimpleQueueError_ParameterOutOfRange))
        public static let queueIsFull = NSError(domain: NSOSStatusErrorDomain, code: Int(kCMSimpleQueueError_QueueIsFull))
    }
    /// throws CMSimpleQueue.Error.parameterOutOfRange for a capacity below 1
    public convenience init(capacity: Int) throws {
        guard capacity > 0, capacity <= Int(Int32.max) else { throw Error.parameterOutOfRange }
        self.init(_capacity: capacity)
    }

    func _enqueue(_ e: UnsafeRawPointer) -> OSStatus {
        _lock.lock(); defer { _lock.unlock() }
        guard _count < _capacity else { return kCMSimpleQueueError_QueueIsFull }
        _elements[(_head + _count) % _capacity] = e
        _count += 1
        return noErr
    }
    func _dequeue() -> UnsafeRawPointer? {
        _lock.lock(); defer { _lock.unlock() }
        guard _count > 0 else { return nil }
        let e = _elements[_head]
        _elements[_head] = nil
        _head = (_head + 1) % _capacity; _count -= 1
        return e
    }
    func _reset() { _lock.lock(); _elements = Array(repeating: nil, count: _capacity); _head = 0; _count = 0; _lock.unlock() }

    public func enqueue(_ element: UnsafeRawPointer) throws {
        if _enqueue(element) != noErr { throw Error.queueIsFull }
    }
    public func dequeue() -> UnsafeRawPointer? { _dequeue() }
    public func reset() throws { _reset() }
    public var head: UnsafeRawPointer? { _lock.lock(); defer { _lock.unlock() }; return _count > 0 ? _elements[_head] : nil }
    public var capacity: Int { _capacity }
    public var count: Int { _lock.lock(); defer { _lock.unlock() }; return _count }
    /// count / capacity, 0 for an empty queue
    public var fullness: Float { capacity > 0 ? Float(count) / Float(capacity) : 0 }
    public static var typeID: CFTypeID { _kCMSimpleQueueTypeID }
}

public func CMSimpleQueueCreate(allocator: CFAllocator?, capacity: Int32, queueOut: UnsafeMutablePointer<CMSimpleQueue?>) -> OSStatus {
    guard capacity > 0 else { return kCMSimpleQueueError_ParameterOutOfRange }
    queueOut.pointee = CMSimpleQueue(_capacity: Int(capacity))
    return noErr
}
public func CMSimpleQueueEnqueue(_ queue: CMSimpleQueue, element: UnsafeRawPointer) -> OSStatus { queue._enqueue(element) }
public func CMSimpleQueueDequeue(_ queue: CMSimpleQueue) -> UnsafeRawPointer? { queue._dequeue() }
public func CMSimpleQueueGetHead(_ queue: CMSimpleQueue) -> UnsafeRawPointer? { queue.head }
public func CMSimpleQueueReset(_ queue: CMSimpleQueue) -> OSStatus { queue._reset(); return noErr }
public func CMSimpleQueueGetCapacity(_ queue: CMSimpleQueue) -> Int32 { Int32(queue.capacity) }
public func CMSimpleQueueGetCount(_ queue: CMSimpleQueue) -> Int32 { Int32(queue.count) }
public func CMSimpleQueueGetTypeID() -> CFTypeID { _kCMSimpleQueueTypeID }

// the C interface (<CoreMedia/CMSimpleQueue.h>): a CMSimpleQueueRef is the Swift object, +1 from Create (CFRelease)
private func _sq(_ p: UnsafeRawPointer) -> CMSimpleQueue { Unmanaged<CMSimpleQueue>.fromOpaque(p).takeUnretainedValue() }
@_cdecl("CMSimpleQueueCreate")
public func _c_CMSimpleQueueCreate(_ allocator: UnsafeRawPointer?, _ capacity: Int32, _ queueOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> OSStatus {
    guard let queueOut else { return kCMSimpleQueueError_RequiredParameterMissing }
    guard capacity > 0 else { return kCMSimpleQueueError_ParameterOutOfRange }
    queueOut.pointee = Unmanaged.passRetained(CMSimpleQueue(_capacity: Int(capacity))).toOpaque()
    return noErr
}
@_cdecl("CMSimpleQueueEnqueue")
public func _c_CMSimpleQueueEnqueue(_ q: UnsafeRawPointer?, _ element: UnsafeRawPointer?) -> OSStatus {
    guard let q, let element else { return kCMSimpleQueueError_RequiredParameterMissing }
    return _sq(q)._enqueue(element)
}
@_cdecl("CMSimpleQueueDequeue") public func _c_CMSimpleQueueDequeue(_ q: UnsafeRawPointer?) -> UnsafeRawPointer? { q.flatMap { _sq($0)._dequeue() } }
@_cdecl("CMSimpleQueueGetHead") public func _c_CMSimpleQueueGetHead(_ q: UnsafeRawPointer?) -> UnsafeRawPointer? { q.flatMap { _sq($0).head } }
@_cdecl("CMSimpleQueueReset")
public func _c_CMSimpleQueueReset(_ q: UnsafeRawPointer?) -> OSStatus {
    guard let q else { return kCMSimpleQueueError_RequiredParameterMissing }
    _sq(q)._reset(); return noErr
}
@_cdecl("CMSimpleQueueGetCapacity") public func _c_CMSimpleQueueGetCapacity(_ q: UnsafeRawPointer?) -> Int32 { q.map { Int32(_sq($0).capacity) } ?? 0 }
@_cdecl("CMSimpleQueueGetCount") public func _c_CMSimpleQueueGetCount(_ q: UnsafeRawPointer?) -> Int32 { q.map { Int32(_sq($0).count) } ?? 0 }
@_cdecl("CMSimpleQueueGetTypeID") public func _c_CMSimpleQueueGetTypeID() -> CFTypeID { _kCMSimpleQueueTypeID }

// MARK: - CMBufferQueue types

public typealias CMBuffer = CFTypeRef
public typealias CMBufferGetTimeCallback = (CMBuffer, UnsafeMutableRawPointer?) -> CMTime
public typealias CMBufferGetBooleanCallback = (CMBuffer, UnsafeMutableRawPointer?) -> Bool
public typealias CMBufferCompareCallback = (CMBuffer, CMBuffer, UnsafeMutableRawPointer?) -> CFComparisonResult
public typealias CMBufferGetSizeCallback = (CMBuffer, UnsafeMutableRawPointer?) -> Int
public typealias CMBufferGetTimeHandler = (CMBuffer) -> CMTime
public typealias CMBufferGetBooleanHandler = (CMBuffer) -> Bool
public typealias CMBufferCompareHandler = (CMBuffer, CMBuffer) -> CFComparisonResult
public typealias CMBufferGetSizeHandler = (CMBuffer) -> Int
public typealias CMBufferQueueTriggerToken = OpaquePointer
public typealias CMBufferQueueTriggerCallback = @convention(c) (UnsafeMutableRawPointer?, CMBufferQueueTriggerToken) -> Void
public typealias CMBufferQueueTriggerHandler = (CMBufferQueueTriggerToken) -> Void
public typealias CMBufferValidationCallback = (CMBufferQueue, CMBuffer, UnsafeMutableRawPointer?) -> OSStatus
public typealias CMBufferValidationHandler = (CMBufferQueue, CMBuffer) -> OSStatus
public typealias CMBufferQueueTriggerCondition = Int32

public var kCMBufferQueueTrigger_WhenDurationBecomesLessThan: CMBufferQueueTriggerCondition { 1 }
public var kCMBufferQueueTrigger_WhenDurationBecomesLessThanOrEqualTo: CMBufferQueueTriggerCondition { 2 }
public var kCMBufferQueueTrigger_WhenDurationBecomesGreaterThan: CMBufferQueueTriggerCondition { 3 }
public var kCMBufferQueueTrigger_WhenDurationBecomesGreaterThanOrEqualTo: CMBufferQueueTriggerCondition { 4 }
public var kCMBufferQueueTrigger_WhenMinPresentationTimeStampChanges: CMBufferQueueTriggerCondition { 5 }
public var kCMBufferQueueTrigger_WhenMaxPresentationTimeStampChanges: CMBufferQueueTriggerCondition { 6 }
public var kCMBufferQueueTrigger_WhenDataBecomesReady: CMBufferQueueTriggerCondition { 7 }
public var kCMBufferQueueTrigger_WhenEndOfDataReached: CMBufferQueueTriggerCondition { 8 }
public var kCMBufferQueueTrigger_WhenReset: CMBufferQueueTriggerCondition { 9 }
public var kCMBufferQueueTrigger_WhenBufferCountBecomesLessThan: CMBufferQueueTriggerCondition { 10 }
public var kCMBufferQueueTrigger_WhenBufferCountBecomesGreaterThan: CMBufferQueueTriggerCondition { 11 }
public var kCMBufferQueueTrigger_WhenDurationBecomesGreaterThanOrEqualToAndBufferCountBecomesGreaterThan: CMBufferQueueTriggerCondition { 12 }

public var kCMBufferQueueError_AllocationFailed: OSStatus { -12760 }
public var kCMBufferQueueError_RequiredParameterMissing: OSStatus { -12761 }
public var kCMBufferQueueError_InvalidCMBufferCallbacksStruct: OSStatus { -12762 }
public var kCMBufferQueueError_EnqueueAfterEndOfData: OSStatus { -12763 }
public var kCMBufferQueueError_QueueIsFull: OSStatus { -12764 }
public var kCMBufferQueueError_BadTriggerDuration: OSStatus { -12765 }
public var kCMBufferQueueError_CannotModifyQueueFromTriggerCallback: OSStatus { -12766 }
public var kCMBufferQueueError_InvalidTriggerCondition: OSStatus { -12767 }
public var kCMBufferQueueError_InvalidTriggerToken: OSStatus { -12768 }
public var kCMBufferQueueError_InvalidBuffer: OSStatus { -12769 }

/// how a buffer queue reads its buffers' timestamps, readiness, order and size
public struct CMBufferCallbacks {
    public var version: UInt32
    public var refcon: UnsafeMutableRawPointer?
    public var getDecodeTimeStamp: CMBufferGetTimeCallback?
    public var getPresentationTimeStamp: CMBufferGetTimeCallback?
    public var getDuration: CMBufferGetTimeCallback
    public var isDataReady: CMBufferGetBooleanCallback?
    public var compare: CMBufferCompareCallback?
    public var dataBecameReadyNotification: Unmanaged<CFString>?
    public var getSize: CMBufferGetSizeCallback?
    public init(version: UInt32, refcon: UnsafeMutableRawPointer?, getDecodeTimeStamp: CMBufferGetTimeCallback?,
                getPresentationTimeStamp: CMBufferGetTimeCallback?, getDuration: @escaping CMBufferGetTimeCallback,
                isDataReady: CMBufferGetBooleanCallback?, compare: CMBufferCompareCallback?,
                dataBecameReadyNotification: Unmanaged<CFString>?, getSize: CMBufferGetSizeCallback?) {
        self.version = version; self.refcon = refcon; self.getDecodeTimeStamp = getDecodeTimeStamp
        self.getPresentationTimeStamp = getPresentationTimeStamp; self.getDuration = getDuration; self.isDataReady = isDataReady
        self.compare = compare; self.dataBecameReadyNotification = dataBecameReadyNotification; self.getSize = getSize
    }
}

// the sample-buffer callbacks: timestamps are the output (presentation) ones; the sorted variant orders by output PTS
private func _sb(_ b: CMBuffer) -> CMSampleBuffer? { b as? CMSampleBuffer }
private func _sampleBufferCallbacks(sorted: Bool) -> UnsafePointer<CMBufferCallbacks> {
    let p = UnsafeMutablePointer<CMBufferCallbacks>.allocate(capacity: 1)
    p.initialize(to: CMBufferCallbacks(
        version: 1, refcon: nil,
        getDecodeTimeStamp: { b, _ in _sb(b)?.decodeTimeStamp ?? .invalid },
        getPresentationTimeStamp: { b, _ in _sb(b)?.outputPresentationTimeStamp ?? .invalid },
        getDuration: { b, _ in _sb(b)?.outputDuration ?? .invalid },
        isDataReady: { b, _ in _sb(b)?.dataIsReady ?? true },
        compare: sorted ? { a, b, _ in
            let c = CMTimeCompare(_sb(a)?.outputPresentationTimeStamp ?? .invalid, _sb(b)?.outputPresentationTimeStamp ?? .invalid)
            return c < 0 ? .compareLessThan : c > 0 ? .compareGreaterThan : .compareEqualTo
        } : nil,
        dataBecameReadyNotification: nil,
        getSize: { b, _ in _sb(b)?.totalSampleSize ?? 0 }))
    return UnsafePointer(p)
}
private let _unsortedSampleBufferCallbacks = _sampleBufferCallbacks(sorted: false)
private let _sortedSampleBufferCallbacks = _sampleBufferCallbacks(sorted: true)
public func CMBufferQueueGetCallbacksForUnsortedSampleBuffers() -> UnsafePointer<CMBufferCallbacks> { _unsortedSampleBufferCallbacks }
public func CMBufferQueueGetCallbacksForSampleBuffersSortedByOutputPTS() -> UnsafePointer<CMBufferCallbacks> { _sortedSampleBufferCallbacks }

// MARK: - CMBufferQueue

/// a queue of Core Media buffers (sample buffers or any CF object the callbacks understand), ordered by enqueue or by
/// the compare callback, with triggers that fire when its duration, count or timestamps cross a threshold
public final class CMBufferQueue: @unchecked Sendable {
    final class _Trigger {
        let condition: CMBufferQueueTriggerCondition
        let time: CMTime
        let count: Int
        let fire: (CMBufferQueueTriggerToken) -> Void
        var last = false
        init(_ condition: CMBufferQueueTriggerCondition, _ time: CMTime, _ count: Int, _ fire: @escaping (CMBufferQueueTriggerToken) -> Void) {
            self.condition = condition; self.time = time; self.count = count; self.fire = fire
        }
        var token: CMBufferQueueTriggerToken { OpaquePointer(Unmanaged.passUnretained(self).toOpaque()) }
    }

    let _lock = NSRecursiveLock()
    let _capacity: Int
    let _getDTS: CMBufferGetTimeHandler?
    let _getPTS: CMBufferGetTimeHandler?
    let _getDuration: CMBufferGetTimeHandler
    let _isReady: CMBufferGetBooleanHandler?
    let _compare: CMBufferCompareHandler?
    let _getSize: CMBufferGetSizeHandler?
    let _readyNotification: String?
    var _buffers: [CMBuffer] = []
    var _endOfData = false
    var _triggers: [_Trigger] = []
    var _inTrigger = 0
    var _validate: CMBufferValidationHandler?
    var _observer: NSObjectProtocol?
    var _headWasReady = false

    init(_capacity: Int, dts: CMBufferGetTimeHandler?, pts: CMBufferGetTimeHandler?, duration: @escaping CMBufferGetTimeHandler,
         ready: CMBufferGetBooleanHandler?, compare: CMBufferCompareHandler?, size: CMBufferGetSizeHandler?, notification: String?) {
        self._capacity = _capacity; _getDTS = dts; _getPTS = pts; _getDuration = duration; _isReady = ready; _compare = compare
        _getSize = size; _readyNotification = notification
        if let notification {
            // a buffer whose data becomes ready posts this notification with itself as the object
            _observer = NotificationCenter.default.addObserver(forName: Notification.Name(notification), object: nil, queue: nil) { [weak self] _ in
                self?._changed(event: nil)
            }
        }
    }
    deinit { if let _observer { NotificationCenter.default.removeObserver(_observer) } }

    convenience init(_capacity: Int, callbacks c: CMBufferCallbacks) {
        let r = c.refcon
        self.init(_capacity: _capacity, dts: c.getDecodeTimeStamp.map { f in { f($0, r) } }, pts: c.getPresentationTimeStamp.map { f in { f($0, r) } },
                  duration: { [d = c.getDuration] in d($0, r) }, ready: c.isDataReady.map { f in { f($0, r) } },
                  compare: c.compare.map { f in { f($0, $1, r) } }, size: c.getSize.map { f in { f($0, r) } },
                  notification: c.dataBecameReadyNotification.map { $0.takeUnretainedValue() as String })
    }

    public struct Error {
        static func _e(_ s: OSStatus) -> NSError { NSError(domain: NSOSStatusErrorDomain, code: Int(s)) }
        public static let allocationFailed = _e(kCMBufferQueueError_AllocationFailed)
        public static let requiredParameterMissing = _e(kCMBufferQueueError_RequiredParameterMissing)
        public static let invalidCMBufferCallbacksStruct = _e(kCMBufferQueueError_InvalidCMBufferCallbacksStruct)
        public static let enqueueAfterEndOfData = _e(kCMBufferQueueError_EnqueueAfterEndOfData)
        public static let queueIsFull = _e(kCMBufferQueueError_QueueIsFull)
        public static let badTriggerDuration = _e(kCMBufferQueueError_BadTriggerDuration)
        public static let cannotModifyQueueFromTriggerCallback = _e(kCMBufferQueueError_CannotModifyQueueFromTriggerCallback)
        public static let invalidTriggerCondition = _e(kCMBufferQueueError_InvalidTriggerCondition)
        public static let invalidTriggerToken = _e(kCMBufferQueueError_InvalidTriggerToken)
        public static let invalidBuffer = _e(kCMBufferQueueError_InvalidBuffer)
    }
    static func _throw(_ s: OSStatus) throws {
        guard s != noErr else { return }
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(s))
    }

    /// the handlers a queue reads its buffers with (Swift's form of CMBufferCallbacks)
    public struct Handlers {
        public let getDecodeTimeStamp: CMBufferGetTimeHandler?
        public let getPresentationTimeStamp: CMBufferGetTimeHandler?
        public let getDuration: CMBufferGetTimeHandler
        public let isDataReady: CMBufferGetBooleanHandler?
        public let compare: CMBufferCompareHandler?
        public let dataBecameReadyNotification: String?
        public let getSize: CMBufferGetSizeHandler?

        public struct Builder {
            var dts: CMBufferGetTimeHandler?, pts: CMBufferGetTimeHandler?, duration: CMBufferGetTimeHandler?
            var ready: CMBufferGetBooleanHandler?, cmp: CMBufferCompareHandler?, size: CMBufferGetSizeHandler?
            public var dataBecameReadyNotification: String?
            init(_ h: Handlers?) {
                dts = h?.getDecodeTimeStamp; pts = h?.getPresentationTimeStamp; duration = h?.getDuration
                ready = h?.isDataReady; cmp = h?.compare; size = h?.getSize; dataBecameReadyNotification = h?.dataBecameReadyNotification
            }
            public mutating func getDecodeTimeStamp(_ handler: @escaping CMBufferGetTimeHandler) { dts = handler }
            public mutating func getPresentationTimeStamp(_ handler: @escaping CMBufferGetTimeHandler) { pts = handler }
            public mutating func getDuration(_ handler: @escaping CMBufferGetTimeHandler) { duration = handler }
            public mutating func isDataReady(_ handler: @escaping CMBufferGetBooleanHandler) { ready = handler }
            public mutating func compare(_ handler: @escaping CMBufferCompareHandler) { cmp = handler }
            public mutating func getSize(_ handler: @escaping CMBufferGetSizeHandler) { size = handler }
        }
        init(_ b: Builder) {
            getDecodeTimeStamp = b.dts; getPresentationTimeStamp = b.pts; getDuration = b.duration ?? { _ in .invalid }
            isDataReady = b.ready; compare = b.cmp; dataBecameReadyNotification = b.dataBecameReadyNotification; getSize = b.size
        }
        public init(withHandlers build: (inout Builder) -> Void) {
            var b = Builder(nil); build(&b); self.init(b)
        }
        public func withHandlers(_ build: (inout Builder) -> Void) -> Handlers {
            var b = Builder(self); build(&b); return Handlers(b)
        }
        static func _sampleBuffers(_ sorted: Bool) -> Handlers {
            Handlers { b in
                b.getDecodeTimeStamp { _sb($0)?.decodeTimeStamp ?? .invalid }
                b.getPresentationTimeStamp { _sb($0)?.outputPresentationTimeStamp ?? .invalid }
                b.getDuration { _sb($0)?.outputDuration ?? .invalid }
                b.isDataReady { _sb($0)?.dataIsReady ?? true }
                b.getSize { _sb($0)?.totalSampleSize ?? 0 }
                if sorted {
                    b.compare { x, y in
                        let c = CMTimeCompare(_sb(x)?.outputPresentationTimeStamp ?? .invalid, _sb(y)?.outputPresentationTimeStamp ?? .invalid)
                        return c < 0 ? .compareLessThan : c > 0 ? .compareGreaterThan : .compareEqualTo
                    }
                }
            }
        }
        public static let unsortedSampleBuffers = _sampleBuffers(false)
        public static let outputPTSSortedSampleBuffers = _sampleBuffers(true)
    }

    /// capacity 0: the queue grows as needed
    public convenience init(capacity: CMItemCount = 0, handlers: Handlers) throws {
        guard capacity >= 0 else { throw Error.requiredParameterMissing }
        self.init(_capacity: capacity, dts: handlers.getDecodeTimeStamp, pts: handlers.getPresentationTimeStamp, duration: handlers.getDuration,
                  ready: handlers.isDataReady, compare: handlers.compare, size: handlers.getSize, notification: handlers.dataBecameReadyNotification)
    }

    public enum TriggerCondition {
        case whenDurationBecomesLessThan(CMTime)
        case whenDurationBecomesLessThanOrEqualTo(CMTime)
        case whenDurationBecomesGreaterThan(CMTime)
        case whenDurationBecomesGreaterThanOrEqualTo(CMTime)
        case whenMinPresentationTimeStampChanges
        case whenMaxPresentationTimeStampChanges
        case whenDataBecomesReady
        case whenEndOfDataReached
        case whenReset
        case whenBufferCountBecomesLessThan(CMItemCount)
        case whenBufferCountBecomesGreaterThan(CMItemCount)
        var _raw: (CMBufferQueueTriggerCondition, CMTime, Int) {
            switch self {
            case .whenDurationBecomesLessThan(let t): return (1, t, 0)
            case .whenDurationBecomesLessThanOrEqualTo(let t): return (2, t, 0)
            case .whenDurationBecomesGreaterThan(let t): return (3, t, 0)
            case .whenDurationBecomesGreaterThanOrEqualTo(let t): return (4, t, 0)
            case .whenMinPresentationTimeStampChanges: return (5, .invalid, 0)
            case .whenMaxPresentationTimeStampChanges: return (6, .invalid, 0)
            case .whenDataBecomesReady: return (7, .invalid, 0)
            case .whenEndOfDataReached: return (8, .invalid, 0)
            case .whenReset: return (9, .invalid, 0)
            case .whenBufferCountBecomesLessThan(let n): return (10, .invalid, n)
            case .whenBufferCountBecomesGreaterThan(let n): return (11, .invalid, n)
            }
        }
    }
    public typealias TriggerToken = CMBufferQueueTriggerToken

    /// a snapshot of the queue's buffers, head first
    public struct Buffers: RandomAccessCollection {
        let _items: [CMBuffer]
        public var startIndex: Int { 0 }
        public var endIndex: Int { _items.count }
        public subscript(position: Int) -> CMBuffer { _items[position] }
    }

    // MARK: state (under the lock)

    func _pts(_ b: CMBuffer) -> CMTime { _getPTS?(b) ?? .invalid }
    func _dts(_ b: CMBuffer) -> CMTime { _getDTS?(b) ?? _pts(b) }
    var _duration: CMTime { _buffers.reduce(CMTime.zero) { let d = _getDuration($1); return d.isNumeric ? $0 + d : $0 } }
    var _minPTS: CMTime { _buffers.map(_pts).filter(\.isNumeric).min() ?? .invalid }
    var _maxPTS: CMTime { _buffers.map(_pts).filter(\.isNumeric).max() ?? .invalid }
    var _headReady: Bool { _buffers.first.map { _isReady?($0) ?? true } ?? false }

    func _state(_ t: _Trigger) -> Bool {
        let d = _duration, n = _buffers.count
        switch t.condition {
        case 1: return CMTimeCompare(d, t.time) < 0
        case 2: return CMTimeCompare(d, t.time) <= 0
        case 3: return CMTimeCompare(d, t.time) > 0
        case 4: return CMTimeCompare(d, t.time) >= 0
        case 7: return _headReady
        case 8: return _endOfData && _buffers.isEmpty
        case 10: return n < t.count
        case 11: return n > t.count
        case 12: return CMTimeCompare(d, t.time) >= 0 && n > t.count
        default: return false                                   // events: timestamps changed, reset
        }
    }
    /// fires the triggers whose condition became true, and those of `event` (5, 6, 9)
    func _changed(event: Set<CMBufferQueueTriggerCondition>?, before: (min: CMTime, max: CMTime)? = nil) {
        _lock.lock()
        var fire: [_Trigger] = []
        let minPTS = _minPTS, maxPTS = _maxPTS
        for t in _triggers {
            let now = _state(t)
            switch t.condition {
            case 5: if let before, CMTimeCompare(before.min, minPTS) != 0 { fire.append(t) }
            case 6: if let before, CMTimeCompare(before.max, maxPTS) != 0 { fire.append(t) }
            case 9: if event?.contains(9) == true { fire.append(t) }
            default: if now && !t.last { fire.append(t) }
            }
            t.last = now
        }
        _inTrigger += 1
        for t in fire { t.fire(t.token) }
        _inTrigger -= 1
        _lock.unlock()
    }
    func _modify(event: Set<CMBufferQueueTriggerCondition>? = nil, _ body: () -> OSStatus) -> OSStatus {
        _lock.lock(); defer { _lock.unlock() }
        guard _inTrigger == 0 else { return kCMBufferQueueError_CannotModifyQueueFromTriggerCallback }
        let before = (_minPTS, _maxPTS)
        let s = body()
        if s == noErr { _changed(event: event, before: before) }
        return s
    }

    func _enqueue(_ b: CMBuffer) -> OSStatus {
        _modify {
            if _endOfData { return kCMBufferQueueError_EnqueueAfterEndOfData }
            if _capacity > 0 && _buffers.count >= _capacity { return kCMBufferQueueError_QueueIsFull }
            if let v = _validate, v(self, b) != noErr { return kCMBufferQueueError_InvalidBuffer }
            if let cmp = _compare, let i = _buffers.firstIndex(where: { cmp(b, $0) == .compareLessThan }) {
                _buffers.insert(b, at: i)                       // after the buffers that compare equal
            } else {
                _buffers.append(b)
            }
            return noErr
        }
    }
    func _dequeue(ifReady: Bool) -> CMBuffer? {
        var out: CMBuffer?
        _ = _modify {
            guard let h = _buffers.first, !ifReady || (_isReady?(h) ?? true) else { return -1 }
            out = _buffers.removeFirst()
            return noErr
        }
        return out
    }
    func _reset(_ each: ((CMBuffer) -> Void)?) -> OSStatus {
        _modify(event: [9]) {
            let old = _buffers
            _buffers = []; _endOfData = false
            if let each { old.forEach(each) }
            return noErr
        }
    }
    func _install(_ condition: CMBufferQueueTriggerCondition, _ time: CMTime, _ count: Int,
                  _ fire: @escaping (CMBufferQueueTriggerToken) -> Void, _ tokenOut: UnsafeMutablePointer<CMBufferQueueTriggerToken?>?) -> OSStatus {
        guard (1...12).contains(condition) else { return kCMBufferQueueError_InvalidTriggerCondition }
        if [1, 2, 3, 4, 12].contains(condition) && !time.isNumeric { return kCMBufferQueueError_BadTriggerDuration }
        _lock.lock(); defer { _lock.unlock() }
        guard _inTrigger == 0 else { return kCMBufferQueueError_CannotModifyQueueFromTriggerCallback }
        let t = _Trigger(condition, time, count, fire)
        t.last = _state(t)
        _triggers.append(t)
        tokenOut?.pointee = t.token
        return noErr
    }
    func _trigger(_ token: CMBufferQueueTriggerToken) -> _Trigger? {
        _triggers.first { $0.token == token }
    }
    func _remove(_ token: CMBufferQueueTriggerToken) -> OSStatus {
        _lock.lock(); defer { _lock.unlock() }
        guard _inTrigger == 0 else { return kCMBufferQueueError_CannotModifyQueueFromTriggerCallback }
        guard let i = _triggers.firstIndex(where: { $0.token == token }) else { return kCMBufferQueueError_InvalidTriggerToken }
        _triggers.remove(at: i)
        return noErr
    }
    func _test(_ token: CMBufferQueueTriggerToken) -> Bool {
        _lock.lock(); defer { _lock.unlock() }
        return _trigger(token).map(_state) ?? false
    }
    func _locked<T>(_ body: () -> T) -> T { _lock.lock(); defer { _lock.unlock() }; return body() }

    // MARK: Swift API (iOS 13)

    public func enqueue(_ buffer: CMBuffer) throws { try Self._throw(_enqueue(buffer)) }
    public func dequeue() -> CMBuffer? { _dequeue(ifReady: false) }
    public func dequeueIfDataReady() -> CMBuffer? { _dequeue(ifReady: true) }
    public func markEndOfData() throws { try Self._throw(_modify { _endOfData = true; return noErr }) }
    public func reset() throws { try Self._throw(_reset(nil)) }
    /// resets the queue, handing each buffer it held to the handler
    public func reset(_ handler: (CMBuffer) throws -> ()) throws {
        var thrown: Swift.Error?
        try withoutActuallyEscaping(handler) { h in
            try Self._throw(_reset { b in if thrown == nil { do { try h(b) } catch { thrown = error } } })
        }
        if let thrown { throw thrown }
    }
    public func installTrigger(condition: TriggerCondition, _ handler: CMBufferQueueTriggerHandler?) throws -> TriggerToken {
        let (c, t, n) = condition._raw
        var token: CMBufferQueueTriggerToken?
        try Self._throw(_install(c, t, n, { handler?($0) }, &token))
        return token!
    }
    public func removeTrigger(_ triggerToken: TriggerToken) throws { try Self._throw(_remove(triggerToken)) }
    public func testTrigger(_ triggerToken: TriggerToken) -> Bool { _test(triggerToken) }
    public func setValidationHandler(_ handler: @escaping (CMBufferQueue, CMBuffer) throws -> Void) {
        _locked { _validate = { q, b in (try? handler(q, b)) != nil ? noErr : kCMBufferQueueError_InvalidBuffer } }
    }

    public var duration: CMTime { _locked { _duration } }
    public var totalSize: Int { _locked { _buffers.reduce(0) { $0 + (_getSize?($1) ?? 0) } } }
    public var firstDecodeTimeStamp: CMTime { _locked { _buffers.first.map(_dts) ?? .invalid } }
    public var firstPresentationTimeStamp: CMTime { _locked { _buffers.first.map(_pts) ?? .invalid } }
    public var minDecodeTimeStamp: CMTime { _locked { _buffers.map(_dts).filter(\.isNumeric).min() ?? .invalid } }
    public var minPresentationTimeStamp: CMTime { _locked { _minPTS } }
    public var maxPresentationTimeStamp: CMTime { _locked { _maxPTS } }
    /// the greatest presentation time stamp plus duration
    public var endPresentationTimeStamp: CMTime {
        _locked {
            _buffers.compactMap { b -> CMTime? in
                let p = _pts(b), d = _getDuration(b)
                return p.isNumeric ? (d.isNumeric ? p + d : p) : nil
            }.max() ?? .invalid
        }
    }
    public var isEmpty: Bool { _locked { _buffers.isEmpty } }
    public var bufferCount: CMItemCount { _locked { _buffers.count } }
    public var head: CMBuffer? { _locked { _buffers.first } }
    public var containsEndOfData: Bool { _locked { _endOfData } }
    public var isAtEndOfData: Bool { _locked { _endOfData && _buffers.isEmpty } }
    public var buffers: Buffers { _locked { Buffers(_items: _buffers) } }
    public class var typeID: CFTypeID { _kCMBufferQueueTypeID }
}

// MARK: - CMBufferQueue functions

public func CMBufferQueueCreate(allocator: CFAllocator?, capacity: CMItemCount, callbacks: UnsafePointer<CMBufferCallbacks>,
                                queueOut: UnsafeMutablePointer<CMBufferQueue?>) -> OSStatus {
    guard capacity >= 0 else { return kCMBufferQueueError_RequiredParameterMissing }
    guard callbacks.pointee.version <= 1 else { return kCMBufferQueueError_InvalidCMBufferCallbacksStruct }
    queueOut.pointee = CMBufferQueue(_capacity: capacity, callbacks: callbacks.pointee)
    return noErr
}
/// handlers: a pointer to a CMBufferQueue.Handlers value (Apple's C CMBufferHandlers struct is not imported into Swift)
public func CMBufferQueueCreateWithHandlers(_ allocator: CFAllocator?, _ capacity: CMItemCount, _ handlers: OpaquePointer,
                                            _ queueOut: UnsafeMutablePointer<CMBufferQueue?>) -> OSStatus {
    let h = UnsafePointer<CMBufferQueue.Handlers>(handlers).pointee
    guard let q = try? CMBufferQueue(capacity: capacity, handlers: h) else { return kCMBufferQueueError_RequiredParameterMissing }
    queueOut.pointee = q
    return noErr
}
public func CMBufferQueueGetTypeID() -> CFTypeID { _kCMBufferQueueTypeID }
public func CMBufferQueueEnqueue(_ queue: CMBufferQueue, buffer: CMBuffer) -> OSStatus { queue._enqueue(buffer) }
public func CMBufferQueueDequeue(_ queue: CMBufferQueue) -> CMBuffer? { queue._dequeue(ifReady: false) }
public func CMBufferQueueDequeueIfDataReady(_ queue: CMBufferQueue) -> CMBuffer? { queue._dequeue(ifReady: true) }
public func CMBufferQueueGetHead(_ queue: CMBufferQueue) -> CMBuffer? { queue.head }
public func CMBufferQueueCopyHead(_ queue: CMBufferQueue) -> CMBuffer? { queue.head }
public func CMBufferQueueIsEmpty(_ queue: CMBufferQueue) -> Bool { queue.isEmpty }
public func CMBufferQueueMarkEndOfData(_ queue: CMBufferQueue) -> OSStatus { queue._modify { queue._endOfData = true; return noErr } }
public func CMBufferQueueContainsEndOfData(_ queue: CMBufferQueue) -> Bool { queue.containsEndOfData }
public func CMBufferQueueIsAtEndOfData(_ queue: CMBufferQueue) -> Bool { queue.isAtEndOfData }
public func CMBufferQueueReset(_ queue: CMBufferQueue) -> OSStatus { queue._reset(nil) }
public func CMBufferQueueResetWithCallback(_ queue: CMBufferQueue, callback: (CMBuffer, UnsafeMutableRawPointer?) -> Void,
                                           refcon: UnsafeMutableRawPointer?) -> OSStatus {
    withoutActuallyEscaping(callback) { cb in queue._reset { cb($0, refcon) } }
}
public func CMBufferQueueGetBufferCount(_ queue: CMBufferQueue) -> CMItemCount { queue.bufferCount }
/// calls the callback for each buffer, head first, until it returns an error (which this returns)
public func CMBufferQueueCallForEachBuffer(_ queue: CMBufferQueue, callback: (CMBuffer, UnsafeMutableRawPointer?) -> OSStatus,
                                           refcon: UnsafeMutableRawPointer?) -> OSStatus {
    for b in queue.buffers { let s = callback(b, refcon); if s != noErr { return s } }
    return noErr
}
public func CMBufferQueueSetValidationCallback(_ queue: CMBufferQueue, callback: @escaping CMBufferValidationCallback, refcon: UnsafeMutableRawPointer?) -> OSStatus {
    queue._locked { queue._validate = { callback($0, $1, refcon) } }
    return noErr
}
public func CMBufferQueueSetValidationHandler(_ queue: CMBufferQueue, _ handler: @escaping CMBufferValidationHandler) -> OSStatus {
    queue._locked { queue._validate = handler }
    return noErr
}
public func CMBufferQueueGetDuration(_ queue: CMBufferQueue) -> CMTime { queue.duration }
public func CMBufferQueueGetMinDecodeTimeStamp(_ queue: CMBufferQueue) -> CMTime { queue.minDecodeTimeStamp }
public func CMBufferQueueGetFirstDecodeTimeStamp(_ queue: CMBufferQueue) -> CMTime { queue.firstDecodeTimeStamp }
public func CMBufferQueueGetMinPresentationTimeStamp(_ queue: CMBufferQueue) -> CMTime { queue.minPresentationTimeStamp }
public func CMBufferQueueGetFirstPresentationTimeStamp(_ queue: CMBufferQueue) -> CMTime { queue.firstPresentationTimeStamp }
public func CMBufferQueueGetMaxPresentationTimeStamp(_ queue: CMBufferQueue) -> CMTime { queue.maxPresentationTimeStamp }
public func CMBufferQueueGetEndPresentationTimeStamp(_ queue: CMBufferQueue) -> CMTime { queue.endPresentationTimeStamp }
public func CMBufferQueueGetTotalSize(_ queue: CMBufferQueue) -> Int { queue.totalSize }
public func CMBufferQueueInstallTrigger(_ queue: CMBufferQueue, callback: CMBufferQueueTriggerCallback?, refcon: UnsafeMutableRawPointer?,
                                        condition: CMBufferQueueTriggerCondition, time: CMTime,
                                        triggerTokenOut: UnsafeMutablePointer<CMBufferQueueTriggerToken?>?) -> OSStatus {
    queue._install(condition, time, 0, { callback?(refcon, $0) }, triggerTokenOut)
}
public func CMBufferQueueInstallTriggerWithIntegerThreshold(_ queue: CMBufferQueue, callback: CMBufferQueueTriggerCallback?, refcon: UnsafeMutableRawPointer?,
                                                            condition: CMBufferQueueTriggerCondition, threshold: CMItemCount,
                                                            triggerTokenOut: UnsafeMutablePointer<CMBufferQueueTriggerToken?>?) -> OSStatus {
    guard condition == 10 || condition == 11 else { return kCMBufferQueueError_InvalidTriggerCondition }
    return queue._install(condition, .invalid, threshold, { callback?(refcon, $0) }, triggerTokenOut)
}
public func CMBufferQueueInstallTriggerHandler(_ queue: CMBufferQueue, _ condition: CMBufferQueueTriggerCondition, _ time: CMTime,
                                               _ triggerTokenOut: UnsafeMutablePointer<CMBufferQueueTriggerToken?>?,
                                               _ handler: CMBufferQueueTriggerHandler?) -> OSStatus {
    queue._install(condition, time, 0, { handler?($0) }, triggerTokenOut)
}
public func CMBufferQueueInstallTriggerHandlerWithIntegerThreshold(_ queue: CMBufferQueue, _ condition: CMBufferQueueTriggerCondition, _ threshold: CMItemCount,
                                                                   _ triggerTokenOut: UnsafeMutablePointer<CMBufferQueueTriggerToken?>?,
                                                                   _ handler: CMBufferQueueTriggerHandler?) -> OSStatus {
    guard condition == 10 || condition == 11 else { return kCMBufferQueueError_InvalidTriggerCondition }
    return queue._install(condition, .invalid, threshold, { handler?($0) }, triggerTokenOut)
}
public func CMBufferQueueRemoveTrigger(_ queue: CMBufferQueue, triggerToken: CMBufferQueueTriggerToken) -> OSStatus { queue._remove(triggerToken) }
public func CMBufferQueueTestTrigger(_ queue: CMBufferQueue, triggerToken: CMBufferQueueTriggerToken) -> Bool { queue._test(triggerToken) }

// MARK: - the C interface (<CoreMedia/CMBufferQueue.h>, frameworks/CoreMedia/CMBufferQueue.m)
// A CMBufferQueueRef is the Swift object (+1 from Create). Buffers are CF objects, retained while queued. C callbacks that
// return a CMTime go through a C trampoline (`callTime`) that writes the result where Swift reads it: the C and Swift
// CMTime have the same 24-byte layout.

public typealias _CMCallTime = @convention(c) (UnsafeRawPointer?, UnsafeRawPointer, UnsafeMutableRawPointer?, UnsafeMutableRawPointer) -> Void
private func _bq(_ p: UnsafeRawPointer) -> CMBufferQueue { Unmanaged<CMBufferQueue>.fromOpaque(p).takeUnretainedValue() }
private func _obj(_ p: UnsafeRawPointer) -> CMBuffer { Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() }
private func _ptr(_ b: CMBuffer) -> UnsafeRawPointer { UnsafeRawPointer(Unmanaged.passUnretained(b).toOpaque()) }

@_cdecl("_isim_CMBufferQueueCreate")
public func _c_CMBufferQueueCreate(_ capacity: Int, _ version: UInt32, _ refcon: UnsafeMutableRawPointer?, _ callTime: _CMCallTime,
                                   _ dts: UnsafeRawPointer?, _ pts: UnsafeRawPointer?, _ duration: UnsafeRawPointer?,
                                   _ ready: (@convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer?) -> UInt8)?,
                                   _ compare: (@convention(c) (UnsafeRawPointer, UnsafeRawPointer, UnsafeMutableRawPointer?) -> Int)?,
                                   _ notification: UnsafeRawPointer?,
                                   _ size: (@convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer?) -> Int)?,
                                   _ queueOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> OSStatus {
    guard capacity >= 0 else { return kCMBufferQueueError_RequiredParameterMissing }
    guard version <= 1, let duration else { return kCMBufferQueueError_InvalidCMBufferCallbacksStruct }
    func time(_ f: UnsafeRawPointer?) -> CMBufferGetTimeHandler? {
        guard let f else { return nil }
        return { b in
            var t = CMTime.invalid
            withUnsafeMutableBytes(of: &t) { callTime(f, _ptr(b), refcon, $0.baseAddress!) }
            return t
        }
    }
    let q = CMBufferQueue(_capacity: capacity, dts: time(dts), pts: time(pts), duration: time(duration)!,
                          ready: ready.map { f in { f(_ptr($0), refcon) != 0 } },
                          compare: compare.map { f in { CFComparisonResult(rawValue: f(_ptr($0), _ptr($1), refcon)) ?? .compareEqualTo } },
                          size: version >= 1 ? size.map { f in { f(_ptr($0), refcon) } } : nil,
                          notification: notification.map { Unmanaged<NSString>.fromOpaque($0).takeUnretainedValue() as String })
    queueOut.pointee = Unmanaged.passRetained(q).toOpaque()
    return noErr
}
@_cdecl("CMBufferQueueGetTypeID") public func _c_CMBufferQueueGetTypeID() -> CFTypeID { _kCMBufferQueueTypeID }
@_cdecl("CMBufferQueueEnqueue")
public func _c_CMBufferQueueEnqueue(_ q: UnsafeRawPointer?, _ b: UnsafeRawPointer?) -> OSStatus {
    guard let q, let b else { return kCMBufferQueueError_RequiredParameterMissing }
    return _bq(q)._enqueue(_obj(b))
}
/// +1: the caller releases a dequeued buffer
@_cdecl("CMBufferQueueDequeueAndRetain")
public func _c_CMBufferQueueDequeueAndRetain(_ q: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    q.flatMap { _bq($0)._dequeue(ifReady: false) }.map { Unmanaged.passRetained($0).toOpaque() }
}
@_cdecl("CMBufferQueueDequeueIfDataReadyAndRetain")
public func _c_CMBufferQueueDequeueIfDataReadyAndRetain(_ q: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    q.flatMap { _bq($0)._dequeue(ifReady: true) }.map { Unmanaged.passRetained($0).toOpaque() }
}
/// not retained: valid while the buffer stays in the queue
@_cdecl("CMBufferQueueGetHead")
public func _c_CMBufferQueueGetHead(_ q: UnsafeRawPointer?) -> UnsafeRawPointer? { q.flatMap { _bq($0).head }.map(_ptr) }
@_cdecl("CMBufferQueueCopyHead")
public func _c_CMBufferQueueCopyHead(_ q: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    q.flatMap { _bq($0).head }.map { Unmanaged.passRetained($0).toOpaque() }
}
@_cdecl("CMBufferQueueIsEmpty") public func _c_CMBufferQueueIsEmpty(_ q: UnsafeRawPointer?) -> UInt8 { q.map { _bq($0).isEmpty ? 1 : 0 } ?? 1 }
@_cdecl("CMBufferQueueMarkEndOfData")
public func _c_CMBufferQueueMarkEndOfData(_ q: UnsafeRawPointer?) -> OSStatus {
    guard let q else { return kCMBufferQueueError_RequiredParameterMissing }
    return CMBufferQueueMarkEndOfData(_bq(q))
}
@_cdecl("CMBufferQueueContainsEndOfData") public func _c_CMBufferQueueContainsEndOfData(_ q: UnsafeRawPointer?) -> UInt8 { q.map { _bq($0).containsEndOfData ? 1 : 0 } ?? 0 }
@_cdecl("CMBufferQueueIsAtEndOfData") public func _c_CMBufferQueueIsAtEndOfData(_ q: UnsafeRawPointer?) -> UInt8 { q.map { _bq($0).isAtEndOfData ? 1 : 0 } ?? 0 }
@_cdecl("CMBufferQueueReset")
public func _c_CMBufferQueueReset(_ q: UnsafeRawPointer?) -> OSStatus {
    guard let q else { return kCMBufferQueueError_RequiredParameterMissing }
    return _bq(q)._reset(nil)
}
@_cdecl("CMBufferQueueResetWithCallback")
public func _c_CMBufferQueueResetWithCallback(_ q: UnsafeRawPointer?, _ cb: (@convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer?) -> Void)?,
                                              _ refcon: UnsafeMutableRawPointer?) -> OSStatus {
    guard let q, let cb else { return kCMBufferQueueError_RequiredParameterMissing }
    return _bq(q)._reset { cb(_ptr($0), refcon) }
}
@_cdecl("CMBufferQueueGetBufferCount") public func _c_CMBufferQueueGetBufferCount(_ q: UnsafeRawPointer?) -> Int { q.map { _bq($0).bufferCount } ?? 0 }
@_cdecl("CMBufferQueueGetTotalSize") public func _c_CMBufferQueueGetTotalSize(_ q: UnsafeRawPointer?) -> Int { q.map { _bq($0).totalSize } ?? 0 }
@_cdecl("CMBufferQueueCallForEachBuffer")
public func _c_CMBufferQueueCallForEachBuffer(_ q: UnsafeRawPointer?, _ cb: (@convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer?) -> OSStatus)?,
                                              _ refcon: UnsafeMutableRawPointer?) -> OSStatus {
    guard let q, let cb else { return kCMBufferQueueError_RequiredParameterMissing }
    return CMBufferQueueCallForEachBuffer(_bq(q), callback: { b, r in cb(_ptr(b), r) }, refcon: refcon)
}
@_cdecl("CMBufferQueueSetValidationCallback")
public func _c_CMBufferQueueSetValidationCallback(_ q: UnsafeRawPointer?,
                                                  _ cb: (@convention(c) (UnsafeRawPointer, UnsafeRawPointer, UnsafeMutableRawPointer?) -> OSStatus)?,
                                                  _ refcon: UnsafeMutableRawPointer?) -> OSStatus {
    guard let q, let cb else { return kCMBufferQueueError_RequiredParameterMissing }
    let queue = _bq(q)
    queue._locked { queue._validate = { [unowned queue] _, b in cb(UnsafeRawPointer(Unmanaged.passUnretained(queue).toOpaque()), _ptr(b), refcon) } }
    return noErr
}
/// which: 0 duration, 1 min DTS, 2 first DTS, 3 min PTS, 4 first PTS, 5 max PTS, 6 end PTS
@_cdecl("_isim_CMBufferQueueGetTime")
public func _c_CMBufferQueueGetTime(_ q: UnsafeRawPointer?, _ which: Int32, _ out: UnsafeMutableRawPointer) {
    var t = CMTime.invalid
    if let q {
        let queue = _bq(q)
        switch which {
        case 0: t = queue.duration
        case 1: t = queue.minDecodeTimeStamp
        case 2: t = queue.firstDecodeTimeStamp
        case 3: t = queue.minPresentationTimeStamp
        case 4: t = queue.firstPresentationTimeStamp
        case 5: t = queue.maxPresentationTimeStamp
        default: t = queue.endPresentationTimeStamp
        }
    }
    out.storeBytes(of: t, as: CMTime.self)
}
@_cdecl("_isim_CMBufferQueueInstallTrigger")
public func _c_CMBufferQueueInstallTrigger(_ q: UnsafeRawPointer?, _ cb: CMBufferQueueTriggerCallback?, _ refcon: UnsafeMutableRawPointer?,
                                           _ condition: Int32, _ time: UnsafeRawPointer?, _ threshold: Int,
                                           _ tokenOut: UnsafeMutablePointer<CMBufferQueueTriggerToken?>?) -> OSStatus {
    guard let q else { return kCMBufferQueueError_RequiredParameterMissing }
    if time == nil && condition != 10 && condition != 11 { return kCMBufferQueueError_InvalidTriggerCondition }
    let t = time.map { $0.loadUnaligned(as: CMTime.self) } ?? .invalid
    return _bq(q)._install(condition, t, threshold, { cb?(refcon, $0) }, tokenOut)
}
@_cdecl("CMBufferQueueRemoveTrigger")
public func _c_CMBufferQueueRemoveTrigger(_ q: UnsafeRawPointer?, _ token: CMBufferQueueTriggerToken?) -> OSStatus {
    guard let q, let token else { return kCMBufferQueueError_RequiredParameterMissing }
    return _bq(q)._remove(token)
}
@_cdecl("CMBufferQueueTestTrigger")
public func _c_CMBufferQueueTestTrigger(_ q: UnsafeRawPointer?, _ token: CMBufferQueueTriggerToken?) -> UInt8 {
    guard let q, let token else { return 0 }
    return _bq(q)._test(token) ? 1 : 0
}
