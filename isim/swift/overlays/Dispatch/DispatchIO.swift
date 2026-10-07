// isim Dispatch: DispatchData (immutable byte regions with value semantics) and DispatchIO channels (stream and
// random-access I/O on a file descriptor, run on a private serial queue with POSIX read/write/pread/pwrite).
// Self-authored Swift; the C dispatch_data_t / dispatch_io_t API is not provided.
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
        case .unmap: release = { Darwin.free(UnsafeMutableRawPointer(mutating: p)) }   // isim: no mmap'd data
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

    static let ECANCELED: Int32 = 89   // Darwin

    let type: StreamType
    public private(set) var fileDescriptor: Int32
    let ownsDescriptor: Bool
    let channelQueue: DispatchQueue
    let cleanupQueue: DispatchQueue
    let cleanup: (Int32) -> Void
    private let lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    private var closed = false, stopped = false, pending = 0, cleanedUp = false
    private var highWater = Int.max, lowWater = Int.max
    private var streamOffset: off_t = 0
    private var openError: Int32 = 0

    init(type: StreamType, fd: Int32, owns: Bool, queue: DispatchQueue, cleanup: @escaping (Int32) -> Void) {
        self.type = type; fileDescriptor = fd; ownsDescriptor = owns; cleanupQueue = queue; self.cleanup = cleanup
        channelQueue = DispatchQueue(label: "dev.isim.dispatch-io")
        pthread_mutex_init(lock, nil)
        super.init(UnsafeMutableRawPointer(dispatch_semaphore_create(0)!))
        if type == .random { streamOffset = 0 } else { streamOffset = lseek(fd, 0, 1 /* SEEK_CUR */) }
        if streamOffset < 0 { streamOffset = 0 }
    }
    deinit { pthread_mutex_destroy(lock); lock.deallocate() }

    public convenience init(type: StreamType, fileDescriptor: Int32, queue: DispatchQueue, cleanupHandler: @escaping (_ error: Int32) -> Void) {
        self.init(type: type, fd: fileDescriptor, owns: false, queue: queue, cleanup: cleanupHandler)
    }
    public convenience init?(type: StreamType, path: UnsafePointer<Int8>, oflag: Int32, mode: mode_t, queue: DispatchQueue,
                             cleanupHandler: @escaping (_ error: Int32) -> Void) {
        let fd = _isim_dispatch_open(path, oflag, mode)
        guard fd >= 0 else { return nil }
        self.init(type: type, fd: fd, owns: true, queue: queue, cleanup: cleanupHandler)
    }
    public convenience init(type: StreamType, io: DispatchIO, queue: DispatchQueue, cleanupHandler: @escaping (_ error: Int32) -> Void) {
        self.init(type: type, fd: io.fileDescriptor, owns: false, queue: queue, cleanup: cleanupHandler)
    }

    private func begin() -> Bool {
        pthread_mutex_lock(lock); defer { pthread_mutex_unlock(lock) }
        if closed { return false }
        pending += 1
        return true
    }
    private func end() {
        pthread_mutex_lock(lock)
        pending -= 1
        let finish = closed && pending == 0 && !cleanedUp
        if finish { cleanedUp = true }
        pthread_mutex_unlock(lock)
        if finish { runCleanup() }
    }
    private var isStopped: Bool { pthread_mutex_lock(lock); defer { pthread_mutex_unlock(lock) }; return stopped }
    private func runCleanup() {
        if ownsDescriptor { _ = Darwin.close(fileDescriptor) }
        let c = cleanup
        cleanupQueue.async { c(0) }
    }

    public func setLimit(highWater: Int) { pthread_mutex_lock(lock); self.highWater = Swift.max(1, highWater); pthread_mutex_unlock(lock) }
    public func setLimit(lowWater: Int) { pthread_mutex_lock(lock); self.lowWater = Swift.max(1, lowWater); pthread_mutex_unlock(lock) }
    /// Accepted; isim delivers partial results by size (high/low water), not on a timer.
    public func setInterval(interval: DispatchTimeInterval, flags: IntervalFlags = []) {}

    public func read(offset: off_t, length: Int, queue: DispatchQueue, ioHandler: @escaping (_ done: Bool, _ data: DispatchData?, _ error: Int32) -> Void) {
        guard begin() else { queue.async { ioHandler(true, nil, DispatchIO.ECANCELED) }; return }
        channelQueue.async { [self] in
            pthread_mutex_lock(lock); let hw = highWater, lw = lowWater; pthread_mutex_unlock(lock)
            var remaining = length
            var pos: off_t = type == .random ? offset : streamOffset
            var chunk = DispatchData.empty
            let bufSize = 64 * 1024
            let buf = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 16)
            defer { buf.deallocate() }
            var err: Int32 = 0
            while remaining > 0 {
                if isStopped { err = DispatchIO.ECANCELED; break }
                let want = Swift.min(bufSize, remaining)
                let n = type == .random ? pread(fileDescriptor, buf, want, pos) : Darwin.read(fileDescriptor, buf, want)
                if n < 0 { if __error().pointee == EINTR { continue }; err = __error().pointee; break }
                if n == 0 { break }   // end of file
                chunk.append(UnsafeRawBufferPointer(start: buf, count: n))
                remaining -= n; pos += off_t(n)
                // deliver partial results once the low-water mark (or the high-water mark) is reached
                let threshold = lw == Int.max ? (hw == Int.max ? Int.max : hw) : lw
                if chunk.count >= threshold && remaining > 0 {
                    let part = chunk; chunk = .empty
                    queue.async { ioHandler(false, part, 0) }
                }
            }
            if type == .stream { streamOffset = pos }
            let last = chunk
            queue.async { ioHandler(true, last, err) }
            end()
        }
    }

    public func write(offset: off_t, data: DispatchData, queue: DispatchQueue, ioHandler: @escaping (_ done: Bool, _ data: DispatchData?, _ error: Int32) -> Void) {
        guard begin() else { queue.async { ioHandler(true, data, DispatchIO.ECANCELED) }; return }
        channelQueue.async { [self] in
            var written = 0
            var pos: off_t = type == .random ? offset : streamOffset
            var err: Int32 = 0
            outer: for region in data.regions {
                var done = 0
                while done < region.count {
                    if isStopped { err = DispatchIO.ECANCELED; break outer }
                    let n: Int = region.withUnsafeBytes { (p: UnsafePointer<UInt8>) -> Int in
                        type == .random ? pwrite(fileDescriptor, p + done, region.count - done, pos)
                                        : Darwin.write(fileDescriptor, p + done, region.count - done)
                    }
                    if n < 0 { if __error().pointee == EINTR { continue }; err = __error().pointee; break outer }
                    done += n; written += n; pos += off_t(n)
                }
            }
            if type == .stream { streamOffset = pos }
            let rest: DispatchData? = written < data.count ? data.subdata(in: written..<data.count) : nil
            queue.async { ioHandler(true, rest, err) }
            end()
        }
    }

    /// Runs after the operations submitted before it (the channel's queue is serial).
    public func barrier(execute: @escaping () -> Void) { channelQueue.async(execute: execute) }

    public func close(flags: CloseFlags = []) {
        pthread_mutex_lock(lock)
        if closed { pthread_mutex_unlock(lock); return }
        closed = true
        if flags.contains(.stop) { stopped = true }
        let finish = pending == 0 && !cleanedUp
        if finish { cleanedUp = true }
        pthread_mutex_unlock(lock)
        if finish { channelQueue.async { [self] in runCleanup() } }
    }

    /// Reads until end of file or `maxLength` bytes; one handler call.
    public class func read(fromFileDescriptor fd: Int32, maxLength: Int, runningHandlerOn queue: DispatchQueue,
                           handler: @escaping (_ data: DispatchData, _ error: Int32) -> Void) {
        let io = DispatchIO(type: .stream, fd: fd, owns: false, queue: queue, cleanup: { _ in })
        var all = DispatchData.empty
        io.read(offset: 0, length: maxLength, queue: io.channelQueue) { done, data, error in
            if let data { all.append(data) }
            if done { let result = all; queue.async { handler(result, error) }; io.close() }
        }
    }
    /// Writes all of `data`; the handler gets the unwritten rest (nil when everything was written).
    public class func write(toFileDescriptor fd: Int32, data: DispatchData, runningHandlerOn queue: DispatchQueue,
                            handler: @escaping (_ data: DispatchData?, _ error: Int32) -> Void) {
        let io = DispatchIO(type: .stream, fd: fd, owns: false, queue: queue, cleanup: { _ in })
        io.write(offset: 0, data: data, queue: queue) { done, rest, error in
            if done { handler(rest, error); io.close() }
        }
    }
}
