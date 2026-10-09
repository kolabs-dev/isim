// isim Dispatch: DispatchData (immutable byte regions with value semantics) and DispatchIO channels, a Swift face for
// the C dispatch_io_t (Foundation, DispatchIO.mrc.m: stream and random-access I/O on a file descriptor, run on the
// channel's serial queue). DispatchData converts to and from dispatch_data_t without copying. Self-authored Swift.
import Darwin

// MARK: - DispatchData

final class _DispatchRegion: @unchecked Sendable {
    let base: UnsafeRawPointer
    let count: Int
    let release: (() -> Void)?
    init(copying p: UnsafeRawPointer?, count: Int) {
        let m = UnsafeMutableRawPointer.allocate(byteCount: Swift.max(count, 1), alignment: 16)
        if count > 0, let p { m.copyMemory(from: p, byteCount: count) }
        base = UnsafeRawPointer(m); self.count = count
        release = { m.deallocate() }
    }
    init(noCopy p: UnsafeRawPointer, count: Int, release: (() -> Void)?) { base = p; self.count = count; self.release = release }
    deinit { release?() }
}

public struct DispatchData: RandomAccessCollection, Sendable {
    public typealias Index = Int
    public typealias Indices = DefaultIndices<DispatchData>
    public typealias Iterator = DispatchDataIterator
    public typealias SubSequence = Slice<DispatchData>

    /// (region, offset into it, length)
    var parts: [(_DispatchRegion, Int, Int)]
    public private(set) var count: Int

    public static let empty = DispatchData(parts: [])

    public enum Deallocator {
        case free
        case unmap
        case custom(DispatchQueue?, @convention(block) () -> Void)
    }

    init(parts: [(_DispatchRegion, Int, Int)]) { self.parts = parts.filter { $0.2 > 0 }; count = self.parts.reduce(0) { $0 + $1.2 } }

    public init(bytes buffer: UnsafeBufferPointer<UInt8>) {
        self.init(parts: [(_DispatchRegion(copying: buffer.baseAddress.map(UnsafeRawPointer.init), count: buffer.count), 0, buffer.count)])
    }
    public init(bytes buffer: UnsafeRawBufferPointer) {
        self.init(parts: [(_DispatchRegion(copying: buffer.baseAddress, count: buffer.count), 0, buffer.count)])
    }
    public init(bytesNoCopy bytes: UnsafeBufferPointer<UInt8>, deallocator: Deallocator = .free) {
        self.init(bytesNoCopy: UnsafeRawBufferPointer(bytes), deallocator: deallocator)
    }
    public init(bytesNoCopy bytes: UnsafeRawBufferPointer, deallocator: Deallocator = .free) {
        guard let p = bytes.baseAddress else { self.init(parts: []); return }
        let release: () -> Void
        switch deallocator {
        case .free: release = { Darwin.free(UnsafeMutableRawPointer(mutating: p)) }
        case .unmap: let n = bytes.count; release = { _ = vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: p)), vm_size_t(n)) }   // isim: munmap
        case .custom(let q, let block): release = { if let q { q.async(execute: block) } else { block() } }
        }
        self.init(parts: [(_DispatchRegion(noCopy: p, count: bytes.count, release: release), 0, bytes.count)])
    }

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }
    public func index(before i: Int) -> Int { i - 1 }
    public func index(after i: Int) -> Int { i + 1 }

    public subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count, "DispatchData index out of range")
        var i = index
        for (r, off, len) in parts {
            if i < len { return r.base.load(fromByteOffset: off + i, as: UInt8.self) }
            i -= len
        }
        fatalError("unreachable")
    }
    public subscript(bounds: Range<Int>) -> Slice<DispatchData> { Slice(base: self, bounds: bounds) }

    public func makeIterator() -> DispatchDataIterator { DispatchDataIterator(data: self) }

    /// Each contiguous region as its own DispatchData.
    public var regions: [DispatchData] { parts.map { DispatchData(parts: [$0]) } }

    public func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Int, _ stop: inout Bool) -> Void) {
        var at = 0, stop = false
        for (r, off, len) in parts {
            block(UnsafeBufferPointer(start: (r.base + off).assumingMemoryBound(to: UInt8.self), count: len), at, &stop)
            if stop { return }
            at += len
        }
    }

    public func withUnsafeBytes<Result, ContentType>(body: (UnsafePointer<ContentType>) throws -> Result) rethrows -> Result {
        if parts.count == 1 { return try body((parts[0].0.base + parts[0].1).assumingMemoryBound(to: ContentType.self)) }
        let flat = contiguous()
        return try withExtendedLifetime(flat) { try body((flat.parts[0].0.base).assumingMemoryBound(to: ContentType.self)) }
    }

    /// A copy whose bytes are one region (`dispatch_data_create_map`).
    func contiguous() -> DispatchData {
        if parts.count <= 1 { return parts.isEmpty ? DispatchData(parts: [(_DispatchRegion(copying: nil, count: 0), 0, 0)]) : self }
        let m = UnsafeMutableRawPointer.allocate(byteCount: Swift.max(count, 1), alignment: 16)
        var at = 0
        for (r, off, len) in parts { (m + at).copyMemory(from: r.base + off, byteCount: len); at += len }
        return DispatchData(parts: [(_DispatchRegion(noCopy: UnsafeRawPointer(m), count: count, release: { m.deallocate() }), 0, count)])
    }

    public mutating func append(_ bytes: UnsafePointer<UInt8>, count: Int) {
        append(DispatchData(bytes: UnsafeBufferPointer(start: bytes, count: count)))
    }
    public mutating func append(_ bytes: UnsafeRawBufferPointer) { append(DispatchData(bytes: bytes)) }
    public mutating func append(_ other: DispatchData) { parts += other.parts; count += other.count }
    public mutating func append<SourceType>(_ buffer: UnsafeBufferPointer<SourceType>) {
        append(DispatchData(bytes: UnsafeRawBufferPointer(buffer)))
    }

    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) { copyBytes(to: pointer, from: 0..<count) }
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, from range: Range<Int>) {
        _copy(to: UnsafeMutableRawPointer(pointer), from: range)
    }
    public func copyBytes(to pointer: UnsafeMutableRawBufferPointer, count: Int) {
        precondition(count <= pointer.count)
        if let b = pointer.baseAddress { _copy(to: b, from: 0..<count) }
    }
    public func copyBytes(to pointer: UnsafeMutableRawBufferPointer, from range: Range<Int>) {
        precondition(range.count <= pointer.count)
        if let b = pointer.baseAddress { _copy(to: b, from: range) }
    }
    @discardableResult
    public func copyBytes<DestinationType>(to buffer: UnsafeMutableBufferPointer<DestinationType>, from range: Range<Int>? = nil) -> Int {
        let r = range ?? 0..<count
        let n = Swift.min(r.count, buffer.count * MemoryLayout<DestinationType>.stride)
        if n > 0, let b = buffer.baseAddress { _copy(to: UnsafeMutableRawPointer(b), from: r.lowerBound..<(r.lowerBound + n)) }
        return n
    }
    func _copy(to dst: UnsafeMutableRawPointer, from range: Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "DispatchData range out of bounds")
        var at = 0, out = 0
        for (r, off, len) in parts {
            let lo = Swift.max(range.lowerBound, at), hi = Swift.min(range.upperBound, at + len)
            if lo < hi { (dst + out).copyMemory(from: r.base + off + (lo - at), byteCount: hi - lo); out += hi - lo }
            at += len
            if at >= range.upperBound { break }
        }
    }

    public func subdata(in range: Range<Int>) -> DispatchData {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "DispatchData range out of bounds")
        var out: [(_DispatchRegion, Int, Int)] = []
        var at = 0
        for (r, off, len) in parts {
            let lo = Swift.max(range.lowerBound, at), hi = Swift.min(range.upperBound, at + len)
            if lo < hi { out.append((r, off + (lo - at), hi - lo)) }
            at += len
        }
        return DispatchData(parts: out)
    }

    /// The region containing `location` and that region's offset within this data.
    public func region(location: Int) -> (data: DispatchData, offset: Int) {
        var at = 0
        for p in parts {
            if location < at + p.2 { return (DispatchData(parts: [p]), at) }
            at += p.2
        }
        return (.empty, count)
    }
}

public struct DispatchDataIterator: IteratorProtocol, Sequence {
    let data: DispatchData
    var part = 0, index = 0
    init(data: DispatchData) { self.data = data }
    public mutating func next() -> UInt8? {
        while part < data.parts.count {
            let (r, off, len) = data.parts[part]
            if index < len { let b = r.base.load(fromByteOffset: off + index, as: UInt8.self); index += 1; return b }
            part += 1; index = 0
        }
        return nil
    }
}

// MARK: - dispatch_data_t

func _dispatchRelease(_ o: OpaquePointer) { dispatch_release(UnsafeMutableRawPointer(o)) }

extension DispatchData {
    /// A dispatch_data_t (+1) sharing this data's regions; each C region keeps its Swift region alive.
    func _cData() -> dispatch_data_t {
        var out = _isim_dispatch_data_empty()!
        for (r, off, len) in parts {
            let piece = dispatch_data_create(r.base + off, len, nil, { withExtendedLifetime(r) {} })!
            let joined = dispatch_data_create_concat(out, piece)!
            _dispatchRelease(piece); _dispatchRelease(out)
            out = joined
        }
        return out
    }
    /// The regions of a dispatch_data_t, shared (each keeps its C region alive).
    init(_cData d: dispatch_data_t?) {
        var parts: [(_DispatchRegion, Int, Int)] = []
        if let d {
            _ = dispatch_data_apply(d) { region, _, buffer, size in
                if let region, let buffer, size > 0 {
                    dispatch_retain(UnsafeMutableRawPointer(region))
                    parts.append((_DispatchRegion(noCopy: buffer, count: size, release: { _dispatchRelease(region) }), 0, size))
                }
                return true
            }
        }
        self.init(parts: parts)
    }
}

// MARK: - DispatchIO

public class DispatchIO: DispatchObject, @unchecked Sendable {
    public enum StreamType: UInt, Sendable {
        case stream = 0
        case random = 1
    }
    public struct CloseFlags: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let stop = CloseFlags(rawValue: 1)
    }
    public struct IntervalFlags: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let strictInterval = IntervalFlags(rawValue: 1)
    }

    var channel: dispatch_io_t { OpaquePointer(object) }
    init(channel: dispatch_io_t) { super.init(UnsafeMutableRawPointer(channel)) }
    deinit { dispatch_release(object) }

    /// The channel's descriptor; -1 once it is closed (or when a path could not be opened).
    public var fileDescriptor: Int32 { dispatch_io_get_descriptor(channel) }

    public convenience init(type: StreamType, fileDescriptor: Int32, queue: DispatchQueue, cleanupHandler: @escaping (_ error: Int32) -> Void) {
        self.init(channel: dispatch_io_create(type.rawValue, fileDescriptor, queue.queue, { cleanupHandler($0) })!)
    }
    /// nil only for a relative path (like Apple); an open error goes to the handlers and the cleanup handler.
    public convenience init?(type: StreamType, path: UnsafePointer<Int8>, oflag: Int32, mode: mode_t, queue: DispatchQueue,
                             cleanupHandler: @escaping (_ error: Int32) -> Void) {
        guard let c = dispatch_io_create_with_path(type.rawValue, path, oflag, mode, queue.queue, { cleanupHandler($0) }) else { return nil }
        self.init(channel: c)
    }
    public convenience init(type: StreamType, io: DispatchIO, queue: DispatchQueue, cleanupHandler: @escaping (_ error: Int32) -> Void) {
        self.init(channel: dispatch_io_create_with_io(type.rawValue, io.channel, queue.queue, { cleanupHandler($0) })!)
    }

    public func setLimit(highWater: Int) { dispatch_io_set_high_water(channel, Swift.max(1, highWater)) }
    public func setLimit(lowWater: Int) { dispatch_io_set_low_water(channel, Swift.max(0, lowWater)) }
    /// Partial results at least every `interval` (`.strictInterval`: even below the low-water mark).
    public func setInterval(interval: DispatchTimeInterval, flags: IntervalFlags = []) {
        dispatch_io_set_interval(channel, interval == .never ? 0 : UInt64(Swift.max(0, interval.nanos)), flags.rawValue)
    }

    public func read(offset: off_t, length: Int, queue: DispatchQueue, ioHandler: @escaping (_ done: Bool, _ data: DispatchData?, _ error: Int32) -> Void) {
        dispatch_io_read(channel, offset, length, queue.queue) { done, data, error in
            ioHandler(done, data.map { DispatchData(_cData: $0) }, error)
        }
    }

    public func write(offset: off_t, data: DispatchData, queue: DispatchQueue, ioHandler: @escaping (_ done: Bool, _ data: DispatchData?, _ error: Int32) -> Void) {
        let c = data._cData()
        dispatch_io_write(channel, offset, c, queue.queue) { done, rest, error in
            ioHandler(done, rest.map { DispatchData(_cData: $0) }, error)
        }
        _dispatchRelease(c)
    }

    /// Runs after the operations submitted before it (the channel's queue is serial).
    public func barrier(execute: @escaping () -> Void) { dispatch_io_barrier(channel, execute) }

    public func close(flags: CloseFlags = []) { dispatch_io_close(channel, flags.rawValue) }

    /// Reads until end of file or `maxLength` bytes; one handler call.
    public class func read(fromFileDescriptor fd: Int32, maxLength: Int, runningHandlerOn queue: DispatchQueue,
                           handler: @escaping (_ data: DispatchData, _ error: Int32) -> Void) {
        dispatch_read(fd, maxLength, queue.queue) { data, error in handler(DispatchData(_cData: data), error) }
    }
    /// Writes all of `data`; the handler gets the unwritten rest (nil when everything was written).
    public class func write(toFileDescriptor fd: Int32, data: DispatchData, runningHandlerOn queue: DispatchQueue,
                            handler: @escaping (_ data: DispatchData?, _ error: Int32) -> Void) {
        let c = data._cData()
        dispatch_write(fd, c, queue.queue) { rest, error in handler(rest.map { DispatchData(_cData: $0) }, error) }
        _dispatchRelease(c)
    }
}
