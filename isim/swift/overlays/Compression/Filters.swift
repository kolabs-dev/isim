// isim Compression: the Swift side of `import Compression` (Algorithm, FilterOperation, FilterError, InputFilter,
// OutputFilter), over libcompression's streams (compression.h, re-exported). Self-authored, iOS API names. Adapted: the
// streams are isim's libcompression (runtime/host_compression.inc), so the data is in Apple's formats.
@_exported import Compression
import Foundation

/// The algorithms the filters use.
public enum Algorithm: CaseIterable, RawRepresentable {
    case lzfse, zlib, lz4, lzma

    public init?(rawValue: compression_algorithm) {
        switch rawValue {
        case COMPRESSION_LZFSE: self = .lzfse
        case COMPRESSION_ZLIB: self = .zlib
        case COMPRESSION_LZ4: self = .lz4
        case COMPRESSION_LZMA: self = .lzma
        default: return nil
        }
    }
    public var rawValue: compression_algorithm {
        switch self {
        case .lzfse: return COMPRESSION_LZFSE
        case .zlib: return COMPRESSION_ZLIB
        case .lz4: return COMPRESSION_LZ4
        case .lzma: return COMPRESSION_LZMA
        }
    }
}

/// Whether a filter compresses or decompresses.
public enum FilterOperation: RawRepresentable {
    case compress, decompress

    public init?(rawValue: compression_stream_operation) {
        switch rawValue {
        case COMPRESSION_STREAM_ENCODE: self = .compress
        case COMPRESSION_STREAM_DECODE: self = .decompress
        default: return nil
        }
    }
    public var rawValue: compression_stream_operation {
        switch self {
        case .compress: return COMPRESSION_STREAM_ENCODE
        case .decompress: return COMPRESSION_STREAM_DECODE
        }
    }
}

/// The errors the filters throw.
public enum FilterError: Error {
    /// The filter could not be set up, or was used after it ended.
    case invalidState
    /// The data could not be compressed or decompressed.
    case invalidData
}

/// One libcompression stream and its output buffer.
private final class _Stream {
    var stream = compression_stream()
    let buffer: UnsafeMutablePointer<UInt8>
    let capacity: Int
    var ended = false

    init(_ operation: FilterOperation, _ algorithm: Algorithm, _ capacity: Int) throws {
        guard capacity > 0 else { throw FilterError.invalidState }
        self.capacity = capacity
        buffer = .allocate(capacity: capacity)
        guard compression_stream_init(&stream, operation.rawValue, algorithm.rawValue) == COMPRESSION_STATUS_OK else {
            buffer.deallocate()
            throw FilterError.invalidState
        }
    }
    deinit {
        compression_stream_destroy(&stream)
        buffer.deallocate()
    }

    /// Runs `input` through the stream (all of it), handing each full or final buffer to `emit`.
    func process(_ input: [UInt8], finalize: Bool, emit: (Data) throws -> Void) throws {
        try input.withUnsafeBufferPointer { src in
            stream.src_ptr = src.baseAddress ?? UnsafePointer(buffer)
            stream.src_size = src.count
            while true {
                stream.dst_ptr = buffer
                stream.dst_size = capacity
                let before = stream.src_size
                let status = compression_stream_process(&stream, finalize ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0)
                let produced = capacity - stream.dst_size
                if produced > 0 { try emit(Data(bytes: buffer, count: produced)) }
                switch status {
                case COMPRESSION_STATUS_END:
                    ended = true
                    return
                case COMPRESSION_STATUS_OK:
                    if produced == capacity { continue }                          /* more output may be waiting */
                    if stream.src_size == 0 && !finalize { return }               /* wants more input */
                    if produced == 0 && stream.src_size == before { throw FilterError.invalidData }   /* no progress */
                default:
                    throw FilterError.invalidData
                }
            }
        }
    }
}

/// A filter that compresses or decompresses the data written to it, and hands the result to a closure.
public class OutputFilter {
    private let stream: _Stream
    private let writeFunc: (Data?) throws -> Void
    private var finalized = false

    /// - Parameters:
    ///   - writeFunc: called with each piece of output, then with nil once the filter is finalized.
    public init(_ operation: FilterOperation, using algorithm: Algorithm, bufferCapacity: Int = 65536,
                writingTo writeFunc: @escaping (Data?) throws -> Void) throws {
        stream = try _Stream(operation, algorithm, bufferCapacity)
        self.writeFunc = writeFunc
    }

    /// Filters `data`; nil or empty data finalizes the filter.
    public func write<D: DataProtocol>(_ data: D?) throws {
        guard let data = data, !data.isEmpty else { return try finalize() }
        guard !finalized, !stream.ended else { throw FilterError.invalidState }
        try stream.process(Array(data), finalize: false, emit: writeFunc)
    }

    /// Ends the input: writes the rest of the output, then calls the write closure with nil. Further writes throw.
    public func finalize() throws {
        guard !finalized else { return }
        finalized = true
        if !stream.ended { try stream.process([], finalize: true, emit: writeFunc) }
        try writeFunc(nil)
    }
}

/// A filter that reads data through a closure and gives it back compressed or decompressed.
public class InputFilter<D: DataProtocol> {
    private let stream: _Stream
    private let readFunc: (Int) throws -> D?
    private let readCapacity: Int
    private var pending = Data()
    private var inputEnded = false

    /// - Parameters:
    ///   - readFunc: asked for up to the given number of input bytes; nil or empty data at the end of the input.
    public init(_ operation: FilterOperation, using algorithm: Algorithm, bufferCapacity: Int = 65536,
                readingFrom readFunc: @escaping (Int) throws -> D?) throws {
        stream = try _Stream(operation, algorithm, bufferCapacity)
        self.readFunc = readFunc
        readCapacity = bufferCapacity
    }

    /// Up to `count` bytes of output; nil once all of it was read.
    public func readData(ofLength count: Int) throws -> Data? {
        while pending.count < count && !stream.ended {
            if inputEnded {
                try stream.process([], finalize: true) { pending.append($0) }
                if !stream.ended { throw FilterError.invalidData }
                break
            }
            let chunk = try readFunc(readCapacity)
            if let chunk = chunk, !chunk.isEmpty {
                try stream.process(Array(chunk), finalize: false) { pending.append($0) }
            } else {
                inputEnded = true
            }
        }
        if pending.isEmpty { return nil }
        let n = min(count, pending.count)
        let out = Data(pending.prefix(n))
        pending.removeFirst(n)
        return out
    }
}
