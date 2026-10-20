// The Swift Compression module on isim (issue #264): Algorithm, FilterOperation, OutputFilter and InputFilter for every
// algorithm, FilterError on bad data, the C API from Swift, and NSData.compressed(using:) / decompressed(using:).
import Compression
import Foundation

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

let text = (0..<3000).map { "record \($0 % 50): isim compresses this line\n" }.joined()
let input = Data(text.utf8)

/// compresses with an OutputFilter fed in 1000-byte pieces, then decompresses with an InputFilter read 700 bytes at a time
func filterRoundTrip(_ algorithm: Algorithm) throws -> (compressed: Data, back: Data) {
    var compressed = Data()
    var sawEnd = false
    let out = try OutputFilter(.compress, using: algorithm, bufferCapacity: 4096) { chunk in
        if let chunk = chunk { compressed.append(chunk) } else { sawEnd = true }
    }
    var at = 0
    while at < input.count {
        let n = min(1000, input.count - at)
        try out.write(input.subdata(in: at..<at + n))
        at += n
    }
    try out.finalize()
    check(sawEnd, "\(algorithm): the write closure gets nil at the end")

    var read = 0
    let inFilter = try InputFilter(.decompress, using: algorithm, bufferCapacity: 512) { (length: Int) -> Data? in
        let n = min(length, compressed.count - read)
        defer { read += n }
        return n > 0 ? compressed.subdata(in: read..<read + n) : nil
    }
    var back = Data()
    while let piece = try inFilter.readData(ofLength: 700) {
        back.append(piece)
    }
    return (compressed, back)
}

@main
struct Main {
    static func main() {
        check(Algorithm.allCases.count == 4, "Algorithm has lzfse, zlib, lz4, lzma")
        check(Algorithm.lzfse.rawValue == COMPRESSION_LZFSE && Algorithm(rawValue: COMPRESSION_LZMA) == .lzma &&
              Algorithm(rawValue: COMPRESSION_BROTLI) == nil, "Algorithm raw values are compression_algorithm")
        check(FilterOperation.compress.rawValue == COMPRESSION_STREAM_ENCODE && FilterOperation(rawValue: COMPRESSION_STREAM_DECODE) == .decompress,
              "FilterOperation raw values are compression_stream_operation")
        for algorithm in Algorithm.allCases {
            do {
                let (compressed, back) = try filterRoundTrip(algorithm)
                check(compressed.count > 0 && compressed.count < input.count / 4, "\(algorithm): OutputFilter compresses (\(input.count) -> \(compressed.count) bytes)")
                check(back == input, "\(algorithm): InputFilter decompresses it back")
                let viaNS = try (input as NSData).compressed(using: NSData.CompressionAlgorithm(algorithm)) as Data
                let backNS = try (viaNS as NSData).decompressed(using: NSData.CompressionAlgorithm(algorithm)) as Data
                check(backNS == input, "\(algorithm): NSData.compressed(using:) / decompressed(using:)")
                let filterOut = try decompressWithOutputFilter(viaNS, algorithm)
                check(filterOut == input, "\(algorithm): NSData's output decodes with an OutputFilter")
            } catch {
                check(false, "\(algorithm): \(error)")
            }
        }
        // bad data
        do {
            _ = try decompressWithOutputFilter(Data(repeating: 0xA5, count: 100), .lzfse)
            check(false, "bad data throws")
        } catch FilterError.invalidData {
            check(true, "bad data throws FilterError.invalidData")
        } catch {
            check(false, "bad data throws \(error)")
        }
        do {
            let out = try OutputFilter(.compress, using: .zlib) { _ in }
            try out.finalize()
            try out.write(Data([1, 2, 3]))
            check(false, "writing after finalize throws")
        } catch FilterError.invalidState {
            check(true, "writing after finalize throws FilterError.invalidState")
        } catch {
            check(false, "writing after finalize throws \(error)")
        }
        do {
            _ = try (Data("plain".utf8) as NSData).decompressed(using: .lzma)
            check(false, "NSData bad data throws")
        } catch {
            check((error as NSError).domain == NSCocoaErrorDomain, "NSData bad data throws a Cocoa error")
        }
        // the C API from Swift
        let bytes = [UInt8](input)
        var encoded = [UInt8](repeating: 0, count: bytes.count)
        let n = compression_encode_buffer(&encoded, encoded.count, bytes, bytes.count, nil, COMPRESSION_LZ4)
        var decoded = [UInt8](repeating: 0, count: bytes.count)
        let m = compression_decode_buffer(&decoded, decoded.count, encoded, n, nil, COMPRESSION_LZ4)
        check(n > 0 && m == bytes.count && decoded == bytes, "compression_encode_buffer / decode_buffer from Swift")
        var stream = compression_stream()
        check(compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZMA) == COMPRESSION_STATUS_OK &&
              compression_stream_destroy(&stream) == COMPRESSION_STATUS_OK, "compression_stream from Swift")
        print("swift compression test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}

func decompressWithOutputFilter(_ data: Data, _ algorithm: Algorithm) throws -> Data {
    var out = Data()
    let filter = try OutputFilter(.decompress, using: algorithm) { if let c = $0 { out.append(c) } }
    try filter.write(data)
    try filter.finalize()
    return out
}

extension NSData.CompressionAlgorithm {
    init(_ a: Algorithm) {
        if a == .lzfse { self = .lzfse } else if a == .lz4 { self = .lz4 } else if a == .lzma { self = .lzma } else { self = .zlib }
    }
}
