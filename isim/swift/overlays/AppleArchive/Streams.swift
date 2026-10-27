// isim AppleArchive: ArchiveByteStream and ArchiveStream (files, compression, encoding, decoding, extraction,
// conversion, custom streams) over isim's C streams (frameworks/AppleArchive). Self-authored, iOS API names. Adapted.
import Darwin
import System

public enum _AAByteStreamTraits {}
public enum _AAArchiveStreamTraits {}
/// The C object a stream wraps (an AAByteStream or AAArchiveStream).
public enum _AAOptionalObjectWrapper<Traits> { public typealias AAType = OpaquePointer }
public enum _AAOptionalObjectWrapperWithFilter<Traits> { public typealias AAType = OpaquePointer }

/// What a custom byte stream does; ArchiveByteStream.customStream(instance:) wraps one.
public protocol ArchiveByteStreamProtocol: AnyObject {
    func read(into buffer: UnsafeMutableRawBufferPointer) throws -> Int
    func read(into buffer: UnsafeMutableRawBufferPointer, atOffset offset: Int64) throws -> Int
    func write(from buffer: UnsafeRawBufferPointer) throws -> Int
    func write(from buffer: UnsafeRawBufferPointer, atOffset offset: Int64) throws -> Int
    func seek(toOffset offset: Int64, relativeTo whence: FileDescriptor.SeekOrigin) throws -> Int64
    func cancel()
    func close() throws
}
extension ArchiveByteStreamProtocol {
    public func read(into buffer: UnsafeMutableRawBufferPointer) throws -> Int { throw ArchiveError.ioError }
    public func read(into buffer: UnsafeMutableRawBufferPointer, atOffset offset: Int64) throws -> Int { throw ArchiveError.ioError }
    public func write(from buffer: UnsafeRawBufferPointer) throws -> Int { throw ArchiveError.ioError }
    public func write(from buffer: UnsafeRawBufferPointer, atOffset offset: Int64) throws -> Int { throw ArchiveError.ioError }
    public func seek(toOffset offset: Int64, relativeTo whence: FileDescriptor.SeekOrigin) throws -> Int64 { throw ArchiveError.ioError }
    public func cancel() {}
    public func close() throws {}
}

/// What a custom archive stream does; ArchiveStream.customStream(instance:) wraps one.
public protocol ArchiveStreamProtocol: AnyObject {
    func writeHeader(_ header: ArchiveHeader) throws
    func writeBlob(key: ArchiveHeader.FieldKey, from buffer: UnsafeRawBufferPointer) throws
    func readHeader() throws -> ArchiveHeader?
    func readBlob(key: ArchiveHeader.FieldKey, into buffer: UnsafeMutableRawBufferPointer) throws
    func cancel()
    func close() throws
}
extension ArchiveStreamProtocol {
    public func writeHeader(_ header: ArchiveHeader) throws { throw ArchiveError.ioError }
    public func writeBlob(key: ArchiveHeader.FieldKey, from buffer: UnsafeRawBufferPointer) throws { throw ArchiveError.ioError }
    public func readHeader() throws -> ArchiveHeader? { throw ArchiveError.ioError }
    public func readBlob(key: ArchiveHeader.FieldKey, into buffer: UnsafeMutableRawBufferPointer) throws { throw ArchiveError.ioError }
    public func cancel() {}
    public func close() throws {}
}

/// Runs `body` with a stream and closes it after (cancelling it when `body` throws).
private func using<S: AnyObject, E>(_ stream: S?, close: (S) throws -> Void, cancel: (S) -> Void, _ body: (S) throws -> E) throws -> E {
    guard let stream else { throw ArchiveError.invalidValue }
    let result: E
    do {
        result = try body(stream)
    } catch {
        cancel(stream)
        try? close(stream)
        throw error
    }
    try close(stream)
    return result
}

/// A stream of bytes: a file, a compression or decompression stream, a pipe, or a custom stream.
public class ArchiveByteStream: ArchiveByteStreamProtocol {
    var object: OpaquePointer?
    let owned: Bool
    var keep: [AnyObject] = []                   // what the C stream uses: the stream it wraps, a custom instance

    public init(object: _AAOptionalObjectWrapper<_AAByteStreamTraits>.AAType?, owned: Bool) {
        self.object = object
        self.owned = owned
    }
    deinit { if owned, let object { AAByteStreamClose(object) } }

    func live() throws -> OpaquePointer {
        guard let object else { throw ArchiveError.invalidValue }
        return object
    }
    public func read(into buffer: UnsafeMutableRawBufferPointer) throws -> Int {
        let o = try live()
        guard let base = buffer.baseAddress else { return 0 }
        let n = AAByteStreamRead(o, base, buffer.count)
        if n < 0 { throw ArchiveError.ioError }
        return n
    }
    public func read(into buffer: UnsafeMutableRawBufferPointer, atOffset offset: Int64) throws -> Int {
        let o = try live()
        guard let base = buffer.baseAddress else { return 0 }
        let n = AAByteStreamPRead(o, base, buffer.count, off_t(offset))
        if n < 0 { throw ArchiveError.ioError }
        return n
    }
    public func write(from buffer: UnsafeRawBufferPointer) throws -> Int {
        let o = try live()
        guard let base = buffer.baseAddress else { return 0 }
        let n = AAByteStreamWrite(o, base, buffer.count)
        if n < 0 { throw ArchiveError.ioError }
        return n
    }
    public func write(from buffer: UnsafeRawBufferPointer, atOffset offset: Int64) throws -> Int {
        let o = try live()
        guard let base = buffer.baseAddress else { return 0 }
        let n = AAByteStreamPWrite(o, base, buffer.count, off_t(offset))
        if n < 0 { throw ArchiveError.ioError }
        return n
    }
    public func seek(toOffset offset: Int64, relativeTo whence: FileDescriptor.SeekOrigin) throws -> Int64 {
        let r = AAByteStreamSeek(try live(), off_t(offset), whence.rawValue)
        if r < 0 { throw ArchiveError.ioError }
        return Int64(r)
    }
    public func cancel() { if let object { AAByteStreamCancel(object) } }
    /// Closes the stream: a compression stream writes its last block. Closing again does nothing.
    public func close() throws {
        guard let o = object else { return }
        object = nil
        let r = owned ? AAByteStreamClose(o) : 0
        keep = []
        if r < 0 { throw ArchiveError.ioError }
    }

    static func wrap(_ object: OpaquePointer?, keeping: [AnyObject] = []) -> ArchiveByteStream? {
        guard let object else { return nil }
        let s = ArchiveByteStream(object: object, owned: true)
        s.keep = keeping
        return s
    }

    // ---- compression ----
    /// Compresses what is written to it into `stream`, in blocks of `blockSize` bytes.
    public static func compressionStream(using compression: ArchiveCompression, writingTo stream: ArchiveByteStream, blockSize: Int = 1 << 22,
                                         flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveByteStream? {
        guard let o = stream.object else { return nil }
        return wrap(AACompressionOutputStreamOpen(o, compression.rawValue, blockSize, flags.rawValue, Int32(threadCount)), keeping: [stream])
    }
    public static func withCompressionStream<E>(using compression: ArchiveCompression, writingTo stream: ArchiveByteStream, blockSize: Int = 1 << 22,
                                                flags: ArchiveFlags = [], threadCount: Int = 0, _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(compressionStream(using: compression, writingTo: stream, blockSize: blockSize, flags: flags, threadCount: threadCount),
                  close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Compresses what is written to it after the compressed data already in `stream` (same algorithm and block size).
    public static func compressionStream(appendingTo stream: ArchiveByteStream, flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveByteStream? {
        guard let o = stream.object else { return nil }
        return wrap(AACompressionOutputStreamOpenExisting(o, flags.rawValue, Int32(threadCount)), keeping: [stream])
    }
    public static func withCompressionStream<E>(appendingTo stream: ArchiveByteStream, flags: ArchiveFlags = [], threadCount: Int = 0,
                                                _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(compressionStream(appendingTo: stream, flags: flags, threadCount: threadCount), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Decompresses what it reads from `stream`.
    public static func decompressionStream(readingFrom stream: ArchiveByteStream, flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveByteStream? {
        guard let o = stream.object else { return nil }
        return wrap(AADecompressionInputStreamOpen(o, flags.rawValue, Int32(threadCount)), keeping: [stream])
    }
    public static func withDecompressionStream<E>(readingFrom stream: ArchiveByteStream, flags: ArchiveFlags = [], threadCount: Int = 0,
                                                  _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(decompressionStream(readingFrom: stream, flags: flags, threadCount: threadCount), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Decompresses any range of `stream` (read(into:atOffset:) and seek), keeping up to `allocationLimit` bytes of blocks.
    public static func randomAccessDecompressionStream(readingFrom stream: ArchiveByteStream, allocationLimit: Int = 1 << 28, flags: ArchiveFlags = [],
                                                       threadCount: Int = 0) -> ArchiveByteStream? {
        guard let o = stream.object else { return nil }
        return wrap(AADecompressionRandomAccessInputStreamOpen(o, allocationLimit, flags.rawValue, Int32(threadCount)), keeping: [stream])
    }
    public static func withRandomAccessDecompressionStream<E>(readingFrom stream: ArchiveByteStream, allocationLimit: Int = 1 << 28, flags: ArchiveFlags = [],
                                                              threadCount: Int = 0, _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(randomAccessDecompressionStream(readingFrom: stream, allocationLimit: allocationLimit, flags: flags, threadCount: threadCount),
                  close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Copies `input` to its end into `output`: the number of bytes.
    public static func process(readingFrom input: ArchiveByteStream, writingTo output: ArchiveByteStream) throws -> Int64 {
        let n = AAByteStreamProcess(try input.live(), try output.live())
        if n < 0 { throw ArchiveError.ioError }
        return Int64(n)
    }

    // ---- files ----
    public static func fileStream(fd: FileDescriptor, automaticClose: Bool) -> ArchiveByteStream? {
        wrap(AAFileStreamOpenWithFD(fd.rawValue, automaticClose ? 1 : 0))
    }
    public static func withFileStream<E>(fd: FileDescriptor, automaticClose: Bool, _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(fileStream(fd: fd, automaticClose: automaticClose), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    public static func fileStream(path: FilePath, mode: FileDescriptor.AccessMode, options: FileDescriptor.OpenOptions,
                                  permissions: FilePermissions) -> ArchiveByteStream? {
        wrap(path.withCString { AAFileStreamOpenWithPath($0, mode.rawValue | options.rawValue, permissions.rawValue) })
    }
    public static func withFileStream<E>(path: FilePath, mode: FileDescriptor.AccessMode, options: FileDescriptor.OpenOptions,
                                         permissions: FilePermissions, _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(fileStream(path: path, mode: mode, options: options, permissions: permissions), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// A stream over a temporary file, removed when it closes.
    public static func temporaryFileStream() -> ArchiveByteStream? { wrap(AATempFileStreamOpen()) }
    public static func withTemporaryFileStream<E>(_ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(temporaryFileStream(), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// A pipe: what is written to `output` is read from `input` (another thread), through a buffer of `capacity` bytes.
    public static func sharedBufferPipe(capacity: Int) -> (output: ArchiveByteStream, input: ArchiveByteStream)? {
        var o: OpaquePointer?, i: OpaquePointer?
        guard AASharedBufferPipeOpen(&o, &i, capacity) == 0, let output = wrap(o), let input = wrap(i) else { return nil }
        return (output, input)
    }

    // ---- custom streams ----
    final class Custom {
        let instance: ArchiveByteStreamProtocol
        init(_ instance: ArchiveByteStreamProtocol) { self.instance = instance }
        static func of(_ arg: UnsafeMutableRawPointer?) -> ArchiveByteStreamProtocol { Unmanaged<Custom>.fromOpaque(arg!).takeUnretainedValue().instance }
    }
    /// A stream whose reads, writes and seeks call `instance`.
    public static func customStream<C: ArchiveByteStreamProtocol>(instance: C) -> ArchiveByteStream? {
        guard let s = AACustomByteStreamOpen() else { return nil }
        let custom = Custom(instance)
        AACustomByteStreamSetData(s, Unmanaged.passUnretained(custom).toOpaque())
        AACustomByteStreamSetReadProc(s) { arg, buf, n in
            (try? Custom.of(arg).read(into: UnsafeMutableRawBufferPointer(start: buf, count: n))) ?? -1
        }
        AACustomByteStreamSetPReadProc(s) { arg, buf, n, offset in
            (try? Custom.of(arg).read(into: UnsafeMutableRawBufferPointer(start: buf, count: n), atOffset: Int64(offset))) ?? -1
        }
        AACustomByteStreamSetWriteProc(s) { arg, buf, n in
            (try? Custom.of(arg).write(from: UnsafeRawBufferPointer(start: buf, count: n))) ?? -1
        }
        AACustomByteStreamSetPWriteProc(s) { arg, buf, n, offset in
            (try? Custom.of(arg).write(from: UnsafeRawBufferPointer(start: buf, count: n), atOffset: Int64(offset))) ?? -1
        }
        AACustomByteStreamSetSeekProc(s) { arg, offset, whence in
            (try? off_t(Custom.of(arg).seek(toOffset: Int64(offset), relativeTo: FileDescriptor.SeekOrigin(rawValue: whence)))) ?? -1
        }
        AACustomByteStreamSetCancelProc(s) { arg in Custom.of(arg).cancel() }
        AACustomByteStreamSetCloseProc(s) { arg in (try? Custom.of(arg).close()) == nil ? -1 : 0 }
        return wrap(s, keeping: [custom])
    }
    public static func withStream<C: ArchiveByteStreamProtocol, E>(wrapping instance: C, _ body: (ArchiveByteStream) throws -> E) throws -> E {
        try using(customStream(instance: instance), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
}

/// A stream of archive entries: encoding to a byte stream, decoding from one, extraction to a directory, conversion to
/// another archive stream, or a custom stream.
public class ArchiveStream: ArchiveStreamProtocol {
    var object: OpaquePointer?
    let owned: Bool
    let messageProc: ArchiveHeader._EntryFilterWrapper?
    var keep: [AnyObject] = []
    var lastHeader: ArchiveHeader?

    public init(object: _AAOptionalObjectWrapperWithFilter<_AAArchiveStreamTraits>.AAType?, owned: Bool, messageProc: ArchiveHeader._EntryFilterWrapper?) {
        self.object = object
        self.owned = owned
        self.messageProc = messageProc
    }
    deinit { if owned, let object { AAArchiveStreamClose(object) } }

    func live() throws -> OpaquePointer {
        guard let object else { throw ArchiveError.invalidValue }
        return object
    }
    public func writeHeader(_ header: ArchiveHeader) throws {
        if AAArchiveStreamWriteHeader(try live(), header.header) < 0 { throw ArchiveError.ioError }
    }
    public func writeBlob(key: ArchiveHeader.FieldKey, from buffer: UnsafeRawBufferPointer) throws {
        let o = try live()
        guard let base = buffer.baseAddress else { return }
        if AAArchiveStreamWriteBlob(o, key.cKey, base, buffer.count) < 0 { throw ArchiveError.ioError }
    }
    /// The next entry's header, or nil at the end.
    public func readHeader() throws -> ArchiveHeader? {
        var h: OpaquePointer?
        let r = AAArchiveStreamReadHeader(try live(), &h)
        if r < 0 { throw ArchiveError.ioError }
        return r == 0 ? nil : ArchiveHeader(cloning: h)
    }
    /// Reads the next bytes of the current entry's blob of `key` (blobs are read in the header's order).
    public func readBlob(key: ArchiveHeader.FieldKey, into buffer: UnsafeMutableRawBufferPointer) throws {
        let o = try live()
        guard let base = buffer.baseAddress else { return }
        if AAArchiveStreamReadBlob(o, key.cKey, base, buffer.count) < 0 { throw ArchiveError.ioError }
    }
    public func cancel() { if let object { AAArchiveStreamCancel(object) } }
    /// Closes the stream: an extraction stream finishes its last entry and sets directory attributes.
    public func close() throws {
        guard let o = object else { return }
        object = nil
        let r = owned ? AAArchiveStreamClose(o) : 0
        keep = []
        if r < 0 { throw ArchiveError.ioError }
    }

    /// Archives `path` under `directory` (nil: the directory itself) and everything under it, with the fields of
    /// `keySet`, writing one entry per file to this stream.
    public func writeDirectoryContents(archiveFrom directory: FilePath, path: FilePath? = nil, keySet: ArchiveHeader.FieldKeySet,
                                       selectUsing filter: ArchiveHeader.EntryFilter? = nil, flags: ArchiveFlags = [], threadCount: Int = 0) throws {
        let o = try live()
        let wrapper = filter.map { ArchiveHeader._EntryFilterWrapper($0) }
        let proc = wrapper == nil ? nil : entryMessageProc
        let r: Int32 = withExtendedLifetime(wrapper) {
            directory.withCString { dir in
                let list: OpaquePointer?
                if let path {
                    list = path.withCString { AAPathListCreateWithDirectoryContents(dir, $0, wrapper?.context, proc, flags.rawValue, Int32(threadCount)) }
                } else {
                    list = AAPathListCreateWithDirectoryContents(dir, nil, wrapper?.context, proc, flags.rawValue, Int32(threadCount))
                }
                guard let list else { return -1 }
                defer { AAPathListDestroy(list) }
                return AAArchiveStreamWritePathList(o, list, keySet.keySet, dir, wrapper?.context, proc, flags.rawValue, Int32(threadCount))
            }
        }
        if r < 0 { throw ArchiveError.ioError }
    }

    static func wrap(_ object: OpaquePointer?, filter: ArchiveHeader._EntryFilterWrapper?, keeping: [AnyObject] = []) -> ArchiveStream? {
        guard let object else { return nil }
        let s = ArchiveStream(object: object, owned: true, messageProc: filter)
        s.keep = keeping
        return s
    }

    /// Makes the files of the entries written to it under `directory` (paths that leave it are refused).
    public static func extractStream(extractingTo directory: FilePath, selectUsing filter: ArchiveHeader.EntryFilter? = nil,
                                     flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveStream? {
        let w = filter.map { ArchiveHeader._EntryFilterWrapper($0) }
        return wrap(directory.withCString { AAExtractArchiveOutputStreamOpen($0, w?.context, w == nil ? nil : entryMessageProc, flags.rawValue, Int32(threadCount)) }, filter: w)
    }
    public static func withExtractStream<E>(extractingTo directory: FilePath, selectUsing filter: ArchiveHeader.EntryFilter? = nil, flags: ArchiveFlags = [],
                                            threadCount: Int = 0, _ body: (ArchiveStream) throws -> E) throws -> E {
        try using(extractStream(extractingTo: directory, selectUsing: filter, flags: flags, threadCount: threadCount),
                  close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Encodes the entries written to it into `stream`.
    public static func encodeStream(writingTo stream: ArchiveByteStream, selectUsing filter: ArchiveHeader.EntryFilter? = nil,
                                    flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveStream? {
        guard let o = stream.object else { return nil }
        let w = filter.map { ArchiveHeader._EntryFilterWrapper($0) }
        return wrap(AAEncodeArchiveOutputStreamOpen(o, w?.context, w == nil ? nil : entryMessageProc, flags.rawValue, Int32(threadCount)), filter: w, keeping: [stream])
    }
    public static func withEncodeStream<E>(writingTo stream: ArchiveByteStream, selectUsing filter: ArchiveHeader.EntryFilter? = nil, flags: ArchiveFlags = [],
                                           threadCount: Int = 0, _ body: (ArchiveStream) throws -> E) throws -> E {
        try using(encodeStream(writingTo: stream, selectUsing: filter, flags: flags, threadCount: threadCount), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Decodes the entries of `stream`.
    public static func decodeStream(readingFrom stream: ArchiveByteStream, selectUsing filter: ArchiveHeader.EntryFilter? = nil,
                                    flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveStream? {
        guard let o = stream.object else { return nil }
        let w = filter.map { ArchiveHeader._EntryFilterWrapper($0) }
        return wrap(AADecodeArchiveInputStreamOpen(o, w?.context, w == nil ? nil : entryMessageProc, flags.rawValue, Int32(threadCount)), filter: w, keeping: [stream])
    }
    public static func withDecodeStream<E>(readingFrom stream: ArchiveByteStream, selectUsing filter: ArchiveHeader.EntryFilter? = nil, flags: ArchiveFlags = [],
                                           threadCount: Int = 0, _ body: (ArchiveStream) throws -> E) throws -> E {
        try using(decodeStream(readingFrom: stream, selectUsing: filter, flags: flags, threadCount: threadCount), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Passes the entries written to it on to `stream`, with the fields of `removeKeySet` removed and those of
    /// `insertKeySet` added when they can be computed from the entry (SIZ and the hashes, from DAT).
    public static func convertStream(writingTo stream: ArchiveStream, insertKeySet: ArchiveHeader.FieldKeySet, removeKeySet: ArchiveHeader.FieldKeySet,
                                     selectUsing filter: ArchiveHeader.EntryFilter? = nil, flags: ArchiveFlags = [], threadCount: Int = 0) -> ArchiveStream? {
        guard let o = stream.object else { return nil }
        let w = filter.map { ArchiveHeader._EntryFilterWrapper($0) }
        return wrap(AAConvertArchiveOutputStreamOpen(o, insertKeySet.keySet, removeKeySet.keySet, w?.context, w == nil ? nil : entryMessageProc,
                                                     flags.rawValue, Int32(threadCount)), filter: w, keeping: [stream])
    }
    public static func withConvertStream<E>(writingTo stream: ArchiveStream, insertKeySet: ArchiveHeader.FieldKeySet, removeKeySet: ArchiveHeader.FieldKeySet,
                                            selectUsing filter: ArchiveHeader.EntryFilter? = nil, flags: ArchiveFlags = [], threadCount: Int = 0,
                                            _ body: (ArchiveStream) throws -> E) throws -> E {
        try using(convertStream(writingTo: stream, insertKeySet: insertKeySet, removeKeySet: removeKeySet, selectUsing: filter, flags: flags, threadCount: threadCount),
                  close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
    /// Copies every entry of `input` to `output`: the number of entries.
    public static func process(readingFrom input: ArchiveStream, writingTo output: ArchiveStream, selectUsing filter: ArchiveHeader.EntryFilter? = nil,
                               flags: ArchiveFlags = [], threadCount: Int = 0) throws -> Int {
        let w = filter.map { ArchiveHeader._EntryFilterWrapper($0) }
        let n = withExtendedLifetime(w) {
            AAArchiveStreamProcess(input.object!, output.object!, w?.context, w == nil ? nil : entryMessageProc, flags.rawValue, Int32(threadCount))
        }
        if n < 0 { throw ArchiveError.ioError }
        return n
    }

    // ---- custom streams ----
    final class Custom {
        let instance: ArchiveStreamProtocol
        var header: ArchiveHeader?                // the last header read, owned until the next read
        init(_ instance: ArchiveStreamProtocol) { self.instance = instance }
        static func of(_ arg: UnsafeMutableRawPointer?) -> Custom { Unmanaged<Custom>.fromOpaque(arg!).takeUnretainedValue() }
    }
    /// A stream whose header and blob reads and writes call `instance`.
    public static func customStream<C: ArchiveStreamProtocol>(instance: C) -> ArchiveStream? {
        guard let s = AACustomArchiveStreamOpen() else { return nil }
        let custom = Custom(instance)
        AACustomArchiveStreamSetData(s, Unmanaged.passUnretained(custom).toOpaque())
        AACustomArchiveStreamSetWriteHeaderProc(s) { arg, h in
            guard let copy = ArchiveHeader(cloning: h) else { return -1 }
            return (try? Custom.of(arg).instance.writeHeader(copy)) == nil ? -1 : 0
        }
        AACustomArchiveStreamSetWriteBlobProc(s) { arg, key, buf, n in
            (try? Custom.of(arg).instance.writeBlob(key: ArchiveHeader.FieldKey(key), from: UnsafeRawBufferPointer(start: buf, count: n))) == nil ? -1 : 0
        }
        AACustomArchiveStreamSetReadHeaderProc(s) { arg, out in
            let c = Custom.of(arg)
            do {
                c.header = try c.instance.readHeader()
            } catch {
                return -1
            }
            guard let h = c.header else { return 0 }
            out.pointee = h.header
            return 1
        }
        AACustomArchiveStreamSetReadBlobProc(s) { arg, key, buf, n in
            (try? Custom.of(arg).instance.readBlob(key: ArchiveHeader.FieldKey(key), into: UnsafeMutableRawBufferPointer(start: buf, count: n))) == nil ? -1 : 0
        }
        AACustomArchiveStreamSetCancelProc(s) { arg in Custom.of(arg).instance.cancel() }
        AACustomArchiveStreamSetCloseProc(s) { arg in (try? Custom.of(arg).instance.close()) == nil ? -1 : 0 }
        return wrap(s, filter: nil, keeping: [custom])
    }
    public static func withStream<C: ArchiveStreamProtocol, E>(wrapping instance: C, _ body: (ArchiveStream) throws -> E) throws -> E {
        try using(customStream(instance: instance), close: { try $0.close() }, cancel: { $0.cancel() }, body)
    }
}
