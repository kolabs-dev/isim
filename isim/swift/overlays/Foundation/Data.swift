// isim Foundation: Data, String encodings, file reading/writing (self-authored, pure Swift over libc).
import Darwin

/// A byte buffer value type (Apple's Data). On isim it is backed by a Swift array and does not bridge to NSData.
public struct Data: Hashable, Sendable, RandomAccessCollection, MutableCollection, RangeReplaceableCollection,
                    ExpressibleByArrayLiteral, CustomStringConvertible, CustomDebugStringConvertible, ContiguousBytes {
    public typealias Index = Int
    public typealias Element = UInt8
    public typealias Indices = Range<Int>
    @usableFromInline var bytes: [UInt8]

    public init() { bytes = [] }
    public init(_ bytes: [UInt8]) { self.bytes = bytes }
    public init<S: Sequence>(_ elements: S) where S.Element == UInt8 { bytes = Array(elements) }
    public init(arrayLiteral elements: UInt8...) { bytes = elements }
    public init(count: Int) { bytes = [UInt8](repeating: 0, count: count) }
    public init(repeating value: UInt8, count: Int) { bytes = [UInt8](repeating: value, count: count) }
    public init(capacity: Int) { bytes = []; bytes.reserveCapacity(capacity) }
    public init(bytes: UnsafeRawPointer, count: Int) { self.bytes = Array(UnsafeRawBufferPointer(start: bytes, count: count)) }
    public init<T>(buffer: UnsafeBufferPointer<T>) { bytes = Array(UnsafeRawBufferPointer(buffer)) }
    public init(bytesNoCopy: UnsafeMutableRawPointer, count: Int, deallocator: Deallocator) {
        bytes = Array(UnsafeRawBufferPointer(start: bytesNoCopy, count: count))
        if case .free = deallocator { free(bytesNoCopy) }
    }
    public enum Deallocator { case virtualMemory, unmap, free, none, custom((UnsafeMutableRawPointer, Int) -> Void) }

    public var startIndex: Int { 0 }
    public var endIndex: Int { bytes.count }
    public var count: Int { bytes.count }
    public var isEmpty: Bool { bytes.isEmpty }
    public subscript(i: Int) -> UInt8 {
        get { bytes[i] }
        set { bytes[i] = newValue }
    }
    public subscript(r: Range<Int>) -> Data {
        get { Data(bytes[r]) }
        set { bytes.replaceSubrange(r, with: newValue.bytes) }
    }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public mutating func replaceSubrange<C: Collection>(_ r: Range<Int>, with c: C) where C.Element == UInt8 { bytes.replaceSubrange(r, with: c) }
    public mutating func append(_ other: Data) { bytes += other.bytes }
    public mutating func append(_ byte: UInt8) { bytes.append(byte) }
    public mutating func append<S: Sequence>(contentsOf s: S) where S.Element == UInt8 { bytes.append(contentsOf: s) }
    public mutating func append(_ p: UnsafePointer<UInt8>, count: Int) { bytes.append(contentsOf: UnsafeBufferPointer(start: p, count: count)) }
    public mutating func resetBytes(in r: Range<Int>) { for i in r { bytes[i] = 0 } }
    public func subdata(in r: Range<Int>) -> Data { Data(bytes[r]) }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeMutableBytes(body) }
    public func copyBytes(to p: UnsafeMutablePointer<UInt8>, count: Int) { bytes.withUnsafeBufferPointer { p.update(from: $0.baseAddress!, count: Swift.min(count, $0.count)) } }
    public func copyBytes(to p: UnsafeMutablePointer<UInt8>, from r: Range<Int>) { bytes[r].withUnsafeBufferPointer { p.update(from: $0.baseAddress!, count: $0.count) } }
    public var description: String { "\(count) bytes" }
    public var debugDescription: String { description }

    // MARK: base64
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    public struct Base64EncodingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let lineLength64Characters = Base64EncodingOptions(rawValue: 1)
        public static let lineLength76Characters = Base64EncodingOptions(rawValue: 2)
        public static let endLineWithCarriageReturn = Base64EncodingOptions(rawValue: 16)
        public static let endLineWithLineFeed = Base64EncodingOptions(rawValue: 32)
    }
    public struct Base64DecodingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let ignoreUnknownCharacters = Base64DecodingOptions(rawValue: 1)
    }
    public func base64EncodedString(options: Base64EncodingOptions = []) -> String {
        var out = [UInt8](); out.reserveCapacity((count + 2) / 3 * 4)
        var i = 0
        while i < count {
            let b0 = bytes[i], b1 = i + 1 < count ? bytes[i + 1] : 0, b2 = i + 2 < count ? bytes[i + 2] : 0
            out.append(Data.alphabet[Int(b0 >> 2)])
            out.append(Data.alphabet[Int((b0 & 3) << 4 | b1 >> 4)])
            out.append(i + 1 < count ? Data.alphabet[Int((b1 & 15) << 2 | b2 >> 6)] : UInt8(ascii: "="))
            out.append(i + 2 < count ? Data.alphabet[Int(b2 & 63)] : UInt8(ascii: "="))
            i += 3
        }
        return String(decoding: out, as: UTF8.self)
    }
    public func base64EncodedData(options: Base64EncodingOptions = []) -> Data { Data(base64EncodedString(options: options).utf8) }
    public init?(base64Encoded s: String, options: Base64DecodingOptions = []) { self.init(base64Encoded: Data(s.utf8), options: options) }
    public init?(base64Encoded d: Data, options: Base64DecodingOptions = []) {
        var table = [Int](repeating: -1, count: 256)
        for (i, c) in Data.alphabet.enumerated() { table[Int(c)] = i }
        var out = [UInt8](), acc = 0, bits = 0, pad = 0
        for c in d.bytes {
            if c == UInt8(ascii: "=") { pad += 1; continue }
            let v = table[Int(c)]
            if v < 0 {
                if options.contains(.ignoreUnknownCharacters) || c == 10 || c == 13 { continue }
                return nil
            }
            if pad > 0 { return nil }
            acc = (acc << 6) | v; bits += 6
            if bits >= 8 { bits -= 8; out.append(UInt8((acc >> bits) & 0xFF)) }
        }
        bytes = out
    }

    // MARK: files
    public struct ReadingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mappedIfSafe = ReadingOptions(rawValue: 1)
        public static let uncached = ReadingOptions(rawValue: 2)
        public static let alwaysMapped = ReadingOptions(rawValue: 8)
    }
    public struct WritingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let atomic = WritingOptions(rawValue: 1)
        public static let withoutOverwriting = WritingOptions(rawValue: 2)
        public static let noFileProtection = WritingOptions(rawValue: 0x10000000)
        public static let completeFileProtection = WritingOptions(rawValue: 0x20000000)
    }
    public init(contentsOf url: URL, options: ReadingOptions = []) throws {
        guard url.isFileURL || url.scheme == nil else { throw _fileError(256, url.absoluteString, "Only file URLs can be read on isim") }
        guard let d = _readFile(url.path) else { throw _fileError(260, url.path, "The file couldn’t be opened because there is no such file.") }
        self = d
    }
    public func write(to url: URL, options: WritingOptions = []) throws {
        let path = url.path
        if options.contains(.withoutOverwriting), access(path, F_OK) == 0 { throw _fileError(516, path, "The file already exists.") }
        let target = options.contains(.atomic) ? path + ".isim-tmp-\(getpid())" : path
        guard let f = fopen(target, "wb") else { throw _fileError(642, path, "You don’t have permission to save the file.") }
        let written = bytes.withUnsafeBytes { fwrite($0.baseAddress, 1, $0.count, f) }
        fclose(f)
        guard written == count else { unlink(target); throw _fileError(640, path, "The file couldn’t be saved.") }
        if options.contains(.atomic), rename(target, path) != 0 { unlink(target); throw _fileError(640, path, "The file couldn’t be saved.") }
    }
}

extension Data: Codable {
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var out = [UInt8]()
        while !c.isAtEnd { out.append(try c.decode(UInt8.self)) }
        bytes = out
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        for b in bytes { try c.encode(b) }
    }
}

public protocol ContiguousBytes {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}
extension Array: ContiguousBytes where Element == UInt8 {}

public let NSCocoaErrorDomain = "NSCocoaErrorDomain"
public let NSFilePathErrorKey = "NSFilePath"
func _fileError(_ code: Int, _ path: String, _ message: String) -> NSError {
    NSError(domain: NSCocoaErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message, NSFilePathErrorKey: path])
}
func _readFile(_ path: String) -> Data? {
    guard let f = fopen(path, "rb") else { return nil }
    defer { fclose(f) }
    var out = [UInt8]()
    var buf = [UInt8](repeating: 0, count: 65536)
    while true {
        let n = buf.withUnsafeMutableBytes { fread($0.baseAddress, 1, 65536, f) }
        if n <= 0 { break }
        out.append(contentsOf: buf[0..<n])
    }
    return Data(out)
}

/// Decodes UTF-8, or nil when the bytes are not valid UTF-8.
func _validUTF8<C: Collection>(_ bytes: C) -> String? where C.Element == UInt8 {
    var it = bytes.makeIterator()
    var dec = UTF8()
    var out = String.UnicodeScalarView()
    while true {
        switch dec.decode(&it) {
        case .scalarValue(let s): out.append(s)
        case .emptyInput: return String(out)
        case .error: return nil
        }
    }
}

// MARK: - String encodings

extension String {
    public struct Encoding: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let ascii = Encoding(rawValue: 1)
        public static let nextstep = Encoding(rawValue: 2)
        public static let utf8 = Encoding(rawValue: 4)
        public static let isoLatin1 = Encoding(rawValue: 5)
        public static let nonLossyASCII = Encoding(rawValue: 7)
        public static let unicode = Encoding(rawValue: 10)
        public static let windowsCP1252 = Encoding(rawValue: 12)
        public static let utf16 = Encoding(rawValue: 10)
        public static let utf16BigEndian = Encoding(rawValue: 0x90000100)
        public static let utf16LittleEndian = Encoding(rawValue: 0x94000100)
        public static let utf32 = Encoding(rawValue: 0x8c000100)
        public var description: String { "String.Encoding(\(rawValue))" }
    }

    public init?(data: Data, encoding: Encoding) {
        switch encoding {
        case .utf8:
            guard let s = _validUTF8(data.bytes) else { return nil }
            self = s
        case .ascii, .nonLossyASCII:
            guard data.bytes.allSatisfy({ $0 < 0x80 }) else { return nil }
            self = String(decoding: data.bytes, as: UTF8.self)
        case .isoLatin1, .windowsCP1252:
            self = String(String.UnicodeScalarView(data.bytes.map { Unicode.Scalar($0) }))
        case .utf16, .utf16LittleEndian, .utf16BigEndian:
            var b = data.bytes[...]
            var big = encoding == .utf16BigEndian
            if encoding == .utf16, b.count >= 2 {
                if b[b.startIndex] == 0xFE, b[b.startIndex + 1] == 0xFF { big = true; b = b.dropFirst(2) }
                else if b[b.startIndex] == 0xFF, b[b.startIndex + 1] == 0xFE { b = b.dropFirst(2) }
            }
            guard b.count % 2 == 0 else { return nil }
            var units = [UInt16]()
            var i = b.startIndex
            while i < b.endIndex { let x = UInt16(b[i]), y = UInt16(b[i + 1]); units.append(big ? x << 8 | y : y << 8 | x); i += 2 }
            self = String(decoding: units, as: UTF16.self)
        default:
            return nil
        }
    }
    public init?<S: Sequence>(bytes: S, encoding: Encoding) where S.Element == UInt8 { self.init(data: Data(bytes), encoding: encoding) }

    public func data(using encoding: Encoding, allowLossyConversion: Bool = false) -> Data? {
        switch encoding {
        case .utf8: return Data(utf8)
        case .ascii, .nonLossyASCII:
            var out = [UInt8]()
            for s in unicodeScalars { if s.value < 0x80 { out.append(UInt8(s.value)) } else if allowLossyConversion { out.append(UInt8(ascii: "?")) } else { return nil } }
            return Data(out)
        case .isoLatin1, .windowsCP1252:
            var out = [UInt8]()
            for s in unicodeScalars { if s.value < 0x100 { out.append(UInt8(s.value)) } else if allowLossyConversion { out.append(UInt8(ascii: "?")) } else { return nil } }
            return Data(out)
        case .utf16, .utf16LittleEndian, .utf16BigEndian:
            var out = [UInt8]()
            let big = encoding == .utf16BigEndian
            if encoding == .utf16 { out += [0xFF, 0xFE] }
            for u in utf16 { if big { out += [UInt8(u >> 8), UInt8(u & 0xFF)] } else { out += [UInt8(u & 0xFF), UInt8(u >> 8)] } }
            return Data(out)
        default: return nil
        }
    }
    public func lengthOfBytes(using encoding: Encoding) -> Int { data(using: encoding)?.count ?? 0 }
    public func cString(using encoding: Encoding) -> [CChar]? {
        guard let d = data(using: encoding) else { return nil }
        return d.bytes.map { CChar(bitPattern: $0) } + [0]
    }

    public init(contentsOf url: URL, encoding: Encoding) throws {
        let d = try Data(contentsOf: url)
        guard let s = String(data: d, encoding: encoding) else { throw _fileError(261, url.path, "The file couldn’t be opened using the specified text encoding.") }
        self = s
    }
    public init(contentsOf url: URL) throws { try self.init(contentsOf: url, encoding: .utf8) }
    public init(contentsOfFile path: String, encoding: Encoding) throws { try self.init(contentsOf: URL(fileURLWithPath: path), encoding: encoding) }
    public init(contentsOfFile path: String) throws { try self.init(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) }
    public func write(to url: URL, atomically: Bool, encoding: Encoding) throws {
        guard let d = data(using: encoding) else { throw _fileError(517, url.path, "The file couldn’t be saved using the specified text encoding.") }
        try d.write(to: url, options: atomically ? .atomic : [])
    }
    public func write(toFile path: String, atomically: Bool, encoding: Encoding) throws {
        try write(to: URL(fileURLWithPath: path), atomically: atomically, encoding: encoding)
    }
}
