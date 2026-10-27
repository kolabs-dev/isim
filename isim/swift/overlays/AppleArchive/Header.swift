// isim AppleArchive: the Swift side of `import AppleArchive` (ArchiveHeader and its fields, keys, key sets, entry types,
// messages and XAT blobs; ArchiveFlags, ArchiveCompression, ArchiveHash, ArchiveError), over isim's C framework
// (frameworks/AppleArchive, re-exported). Self-authored, iOS API names. Adapted: archives are AppleArchive's "AA01"
// entries written and read by isim. Not in isim: ArchiveEncryptionContext (Apple Encrypted Archive).
@_exported import AppleArchive
import Compression
import Darwin
import System

/// The errors AppleArchive's Swift API throws.
public enum ArchiveError: Error {
    case invalidValue
    case ioError
}

/// Options of the stream and archive operations.
public struct ArchiveFlags: OptionSet, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let ignoreOperationNotPermitted = ArchiveFlags(rawValue: 1 << 0)
    public static let archiveDeduplicateData = ArchiveFlags(rawValue: 1 << 1)
    public static let extractNoAutoDeduplicate = ArchiveFlags(rawValue: 1 << 3)
    public static let replaceAttributes = ArchiveFlags(rawValue: 1 << 5)
    public static let extractNoAutoSparse = ArchiveFlags(rawValue: 1 << 8)
    /// The level of messages written while working (0 to 3).
    public static func verbosity(level: Int) -> ArchiveFlags { ArchiveFlags(rawValue: UInt64(max(0, min(level, 3))) << 62) }
}

/// The compression of a compression stream.
public struct ArchiveCompression: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: AACompressionAlgorithm
    public init(rawValue: AACompressionAlgorithm) { self.rawValue = rawValue }
    public static let none = ArchiveCompression(rawValue: 0)
    public static let lz4 = ArchiveCompression(rawValue: 0x100)
    public static let zlib = ArchiveCompression(rawValue: 0x505)
    public static let lzma = ArchiveCompression(rawValue: 0x306)
    public static let lzfse = ArchiveCompression(rawValue: 0x801)
    public static let lzbitmap = ArchiveCompression(rawValue: 0x702)
    public static let lzraven = ArchiveCompression(rawValue: 0x80a)
    /// The compression of a Compression framework algorithm.
    public init(algo: Algorithm) {
        switch algo {
        case .lzfse: self = .lzfse
        case .zlib: self = .zlib
        case .lz4: self = .lz4
        case .lzma: self = .lzma
        @unknown default: self = ArchiveCompression(rawValue: algo.rawValue.rawValue)
        }
    }
    public var description: String {
        switch self {
        case .none: return "none"
        case .lz4: return "lz4"
        case .zlib: return "zlib"
        case .lzma: return "lzma"
        case .lzfse: return "lzfse"
        case .lzbitmap: return "lzbitmap"
        case .lzraven: return "lzraven"
        default: return "ArchiveCompression(\(rawValue))"
        }
    }
}

/// The hash functions of hash fields.
public struct ArchiveHash: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let crc32 = ArchiveHash(rawValue: 1)
    public static let sha1 = ArchiveHash(rawValue: 2)
    public static let sha256 = ArchiveHash(rawValue: 3)
    public static let sha384 = ArchiveHash(rawValue: 4)
    public static let sha512 = ArchiveHash(rawValue: 5)
    /// The largest size of a hash value, in bytes.
    public static let maxSize = 64
    /// The size of this function's values, in bytes (0: unknown).
    public var size: Int {
        switch self {
        case .crc32: return 4
        case .sha1: return 20
        case .sha256: return 32
        case .sha384: return 48
        case .sha512: return 64
        default: return 0
        }
    }
    public var description: String {
        switch self {
        case .crc32: return "crc32"
        case .sha1: return "sha1"
        case .sha256: return "sha256"
        case .sha384: return "sha384"
        case .sha512: return "sha512"
        default: return "ArchiveHash(\(rawValue))"
        }
    }
}

/// An entry's header: its fields, each a key and a value.
public class ArchiveHeader {
    let header: OpaquePointer

    public init() { header = AAHeaderCreate()! }
    /// The header of the file at `path` under `directory`, with the fields of `keySet`.
    public init?(keySet: ArchiveHeader.FieldKeySet, directory: FilePath, path: FilePath, flags: ArchiveFlags = []) {
        guard let h = directory.withCString({ d in path.withCString { AAHeaderCreateWithPath(keySet.keySet, d, $0, flags.rawValue) } }) else { return nil }
        header = h
    }
    /// A header decoded from AppleArchive's encoding.
    public init?(withAAEncodedData data: UnsafeBufferPointer<UInt8>) {
        guard let base = data.baseAddress, let h = AAHeaderCreateWithEncodedData(data.count, base) else { return nil }
        header = h
    }
    public init(copying other: ArchiveHeader) { header = AAHeaderClone(other.header)! }
    init?(cloning pointer: OpaquePointer?) {
        guard let pointer, let h = AAHeaderClone(pointer) else { return nil }
        header = h
    }
    deinit { AAHeaderDestroy(header) }

    /// The field of `key`, if the header has one.
    public func field(forKey key: ArchiveHeader.FieldKey) -> ArchiveHeader.Field? {
        let i = AAHeaderGetKeyIndex(header, key.cKey)
        return i < 0 ? nil : field(at: UInt32(i))
    }
    func field(at i: UInt32) -> ArchiveHeader.Field? {
        let key = FieldKey(AAHeaderGetFieldKey(header, i))
        switch ArchiveHeader.FieldType(rawValue: UInt32(bitPattern: AAHeaderGetFieldType(header, i))) {
        case .flag:
            return .flag(key: key)
        case .uint:
            var v: UInt64 = 0
            return AAHeaderGetFieldUInt(header, i, &v) == 0 ? .uint(key: key, value: v) : nil
        case .string:
            var length = 0
            guard AAHeaderGetFieldString(header, i, 0, nil, &length) == 0 else { return nil }
            var chars = [CChar](repeating: 0, count: length + 1)
            guard AAHeaderGetFieldString(header, i, chars.count, &chars, &length) == 0 else { return nil }
            return .string(key: key, value: String(decoding: chars[0..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self))
        case .hash:
            var function: AAHashFunction = 0
            var digest = [UInt8](repeating: 0, count: ArchiveHash.maxSize)
            guard AAHeaderGetFieldHash(header, i, digest.count, &function, &digest) == 0 else { return nil }
            let hash = ArchiveHash(rawValue: function)
            return .hash(key: key, hashFunction: hash, value: ContiguousArray(digest[0..<hash.size]))
        case .timespec:
            var ts = timespec()
            return AAHeaderGetFieldTimespec(header, i, &ts) == 0 ? .timespec(key: key, value: ts) : nil
        case .blob:
            var size: UInt64 = 0, offset: UInt64 = 0
            return AAHeaderGetFieldBlob(header, i, &size, &offset) == 0 ? .blob(key: key, size: size, offset: offset) : nil
        default:
            return nil
        }
    }

    /// The entry type (the TYP field).
    public var entryType: ArchiveHeader.EntryType? {
        guard case .uint(_, let v)? = field(forKey: FieldKey("TYP")) else { return nil }
        return EntryType(rawValue: UInt32(truncatingIfNeeded: v))
    }
    /// The entry's path (the PAT field).
    public var entryPath: FilePath? {
        guard case .string(_, let v)? = field(forKey: FieldKey("PAT")) else { return nil }
        return FilePath(v)
    }

    /// Calls `body` with the header's encoding.
    public func withAAEncodedData<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
        let size = AAHeaderGetEncodedSize(header)
        return try body(UnsafeBufferPointer(start: size > 0 ? AAHeaderGetEncodedData(header) : nil, count: size))
    }

    /// Adds a field at the end, or replaces the field of its key.
    public func append(_ field: ArchiveHeader.Field) {
        let at = AAHeaderGetKeyIndex(header, field.key.cKey) >= 0 ? UInt32.max : UInt32(AAHeaderGetFieldCount(header))
        set(field, at: at)
    }
    func set(_ field: ArchiveHeader.Field, at i: UInt32) {
        switch field {
        case .flag(let key): AAHeaderSetFieldFlag(header, i, key.cKey)
        case .uint(let key, let value): AAHeaderSetFieldUInt(header, i, key.cKey, value)
        case .string(let key, let value):
            var s = value
            s.withUTF8 { b in b.withMemoryRebound(to: CChar.self) { _ = AAHeaderSetFieldString(header, i, key.cKey, $0.baseAddress, $0.count) } }
        case .hash(let key, let function, let value):
            var digest = Array(value)
            digest += [UInt8](repeating: 0, count: Swift.max(0, function.size - digest.count))
            AAHeaderSetFieldHash(header, i, key.cKey, function.rawValue, digest)
        case .timespec(let key, var value): AAHeaderSetFieldTimespec(header, i, key.cKey, &value)
        case .blob(let key, let size, _): AAHeaderSetFieldBlob(header, i, key.cKey, size)
        }
    }
    /// Removes and returns the field at `index`.
    @discardableResult
    public func remove(at index: Int) -> ArchiveHeader.Field {
        let f = self[index]
        AAHeaderRemoveField(header, UInt32(index))
        return f
    }
    public func removeAll() { AAHeaderClear(header) }
}

extension ArchiveHeader: RandomAccessCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { Int(AAHeaderGetFieldCount(header)) }
    public subscript(position: Int) -> ArchiveHeader.Field {
        precondition(position >= 0 && position < endIndex, "ArchiveHeader index out of range")
        return field(at: UInt32(position))!
    }
}

extension ArchiveHeader {
    /// A field key: three characters ("TYP", "PAT", "DAT", …).
    public struct FieldKey: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        let ikey: UInt32
        public init(_ key: String) {
            var v: UInt32 = 0
            for (i, b) in key.utf8.prefix(3).enumerated() { v |= UInt32(b) << (8 * UInt32(i)) }
            ikey = v
        }
        public init(stringLiteral value: String) { self.init(value) }
        init(_ key: AAFieldKey) { ikey = key.ikey & 0x00ff_ffff }
        var cKey: AAFieldKey { var k = AAFieldKey(); k.ikey = ikey; return k }
        public var description: String {
            String(decoding: (0..<3).map { UInt8(truncatingIfNeeded: ikey >> (8 * $0)) }.filter { $0 != 0 }, as: UTF8.self)
        }
        public static func == (lhs: FieldKey, rhs: FieldKey) -> Bool { lhs.ikey == rhs.ikey }
        public func hash(into hasher: inout Hasher) { hasher.combine(ikey) }
    }

    /// A field's type.
    public struct FieldType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let flag = FieldType(rawValue: 0)
        public static let uint = FieldType(rawValue: 1)
        public static let string = FieldType(rawValue: 2)
        public static let hash = FieldType(rawValue: 3)
        public static let timespec = FieldType(rawValue: 4)
        public static let blob = FieldType(rawValue: 5)
        public var description: String {
            ["flag", "uint", "string", "hash", "timespec", "blob"].indices.contains(Int(rawValue))
                ? ["flag", "uint", "string", "hash", "timespec", "blob"][Int(rawValue)] : "FieldType(\(rawValue))"
        }
    }

    /// A field: its key and value.
    public enum Field {
        case flag(key: ArchiveHeader.FieldKey)
        case uint(key: ArchiveHeader.FieldKey, value: UInt64)
        case string(key: ArchiveHeader.FieldKey, value: String)
        case hash(key: ArchiveHeader.FieldKey, hashFunction: ArchiveHash, value: ContiguousArray<UInt8>)
        case timespec(key: ArchiveHeader.FieldKey, value: timespec)
        /// A blob: its size, and its offset in the entry's payload (the blobs follow the header in field order).
        case blob(key: ArchiveHeader.FieldKey, size: UInt64, offset: UInt64)

        public var key: ArchiveHeader.FieldKey {
            switch self {
            case .flag(let k), .uint(let k, _), .string(let k, _), .hash(let k, _, _), .timespec(let k, _), .blob(let k, _, _): return k
            }
        }
        public var type: ArchiveHeader.FieldType {
            switch self {
            case .flag: return .flag
            case .uint: return .uint
            case .string: return .string
            case .hash: return .hash
            case .timespec: return .timespec
            case .blob: return .blob
            }
        }
    }

    /// A set of field keys.
    public class FieldKeySet {
        let keySet: OpaquePointer
        public init() { keySet = AAFieldKeySetCreate()! }
        /// The keys of a comma-separated list ("TYP,PAT,DAT").
        public init?(_ keys: String) {
            guard let s = AAFieldKeySetCreateWithString(keys) else { return nil }
            keySet = s
        }
        public init(copying other: ArchiveHeader.FieldKeySet) { keySet = AAFieldKeySetClone(other.keySet)! }
        deinit { AAFieldKeySetDestroy(keySet) }
        /// The keys archives store by default: type, path, link, device, data, ownership, mode, flags and times.
        public static var defaultForArchive: ArchiveHeader.FieldKeySet { FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")! }
        /// The keys of a manifest: the attributes, sizes and hashes of the entries, without their data.
        public static var defaultForManifest: ArchiveHeader.FieldKeySet { FieldKeySet("TYP,PAT,LNK,DEV,UID,GID,MOD,FLG,MTM,BTM,CTM,SIZ,CKS,SH2")! }
    }

    /// An entry's type (its TYP field).
    public struct EntryType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let regularFile = EntryType(rawValue: UInt32(UInt8(ascii: "F")))
        public static let directory = EntryType(rawValue: UInt32(UInt8(ascii: "D")))
        public static let link = EntryType(rawValue: UInt32(UInt8(ascii: "L")))
        public static let fifo = EntryType(rawValue: UInt32(UInt8(ascii: "P")))
        public static let characterSpecial = EntryType(rawValue: UInt32(UInt8(ascii: "C")))
        public static let blockSpecial = EntryType(rawValue: UInt32(UInt8(ascii: "B")))
        public static let socket = EntryType(rawValue: UInt32(UInt8(ascii: "S")))
        public static let whiteout = EntryType(rawValue: UInt32(UInt8(ascii: "W")))
        public static let door = EntryType(rawValue: UInt32(UInt8(ascii: "R")))
        public static let port = EntryType(rawValue: UInt32(UInt8(ascii: "T")))
        public static let metadata = EntryType(rawValue: UInt32(UInt8(ascii: "M")))
        public var description: String {
            switch self {
            case .regularFile: return "regularFile"
            case .directory: return "directory"
            case .link: return "link"
            case .fifo: return "fifo"
            case .characterSpecial: return "characterSpecial"
            case .blockSpecial: return "blockSpecial"
            case .socket: return "socket"
            case .whiteout: return "whiteout"
            case .door: return "door"
            case .port: return "port"
            case .metadata: return "metadata"
            default: return "EntryType(\(rawValue))"
            }
        }
    }

    /// What is happening to an entry, told to an entry filter.
    public struct EntryMessage: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let searchPruneDirectory = EntryMessage(rawValue: 10)
        public static let searchExclude = EntryMessage(rawValue: 11)
        public static let searchFail = EntryMessage(rawValue: 12)
        public static let extractBegin = EntryMessage(rawValue: 20)
        public static let extractEnd = EntryMessage(rawValue: 21)
        public static let extractFail = EntryMessage(rawValue: 22)
        public static let extractAttributes = EntryMessage(rawValue: 23)
        public static let extractXAT = EntryMessage(rawValue: 24)
        public static let extractACL = EntryMessage(rawValue: 25)
        public static let encodeScanning = EntryMessage(rawValue: 30)
        public static let encodeWriting = EntryMessage(rawValue: 31)
        public static let decodeReading = EntryMessage(rawValue: 40)
        public static let convertExclude = EntryMessage(rawValue: 50)
        public static let processExclude = EntryMessage(rawValue: 60)
        public var description: String {
            let names: [UInt32: String] = [10: "searchPruneDirectory", 11: "searchExclude", 12: "searchFail", 20: "extractBegin",
                                           21: "extractEnd", 22: "extractFail", 23: "extractAttributes", 24: "extractXAT",
                                           25: "extractACL", 30: "encodeScanning", 31: "encodeWriting", 40: "decodeReading",
                                           50: "convertExclude", 60: "processExclude"]
            return names[rawValue] ?? "EntryMessage(\(rawValue))"
        }
    }

    /// An entry filter's answer: go on, skip the entry, or cancel.
    public struct EntryMessageStatus: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        public static let ok = EntryMessageStatus(rawValue: 0)
        public static let skip = EntryMessageStatus(rawValue: 1)
        public static let cancel = EntryMessageStatus(rawValue: -1)
        public var description: String { rawValue == 0 ? "ok" : rawValue > 0 ? "skip" : "cancel" }
    }

    /// What an entry filter is told about the entry.
    public enum EntryFilterData {
        case header(ArchiveHeader)
        case entryAttributes(ArchiveHeader.EntryAttributes)
        case entryXAT(ArchiveHeader.EntryXATBlob)
    }

    /// Decides, for each message, what happens to an entry.
    public typealias EntryFilter = (ArchiveHeader.EntryMessage, FilePath, ArchiveHeader.EntryFilterData?) -> ArchiveHeader.EntryMessageStatus

    /// An entry filter kept alive while a stream uses it.
    public final class _EntryFilterWrapper {
        let filter: EntryFilter
        public init(_ filter: @escaping EntryFilter) { self.filter = filter }
        var context: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }
    }

    /// An entry's attributes as extraction sets them.
    public class EntryAttributes {
        public var uid: UInt32?
        public var gid: UInt32?
        public var flg: UInt32?
        public var mod: UInt32?
        public var btm: timespec?
        public var ctm: timespec?
        public var mtm: timespec?
        init() {}
    }

    /// An entry's extended attributes (the XAT blob).
    public class EntryXATBlob {
        let blob: OpaquePointer

        public init() { blob = AAEntryXATBlobCreate()! }
        /// The extended attributes of the file at `path` under `directory`.
        public init?(directory: FilePath, path: FilePath, flags: ArchiveFlags = []) {
            guard let b = directory.withCString({ d in path.withCString { AAEntryXATBlobCreateWithPath(d, $0, flags.rawValue) } }) else { return nil }
            blob = b
        }
        public init?(withAAEncodedData data: UnsafeBufferPointer<UInt8>) {
            guard let base = data.baseAddress ?? (data.isEmpty ? UnsafePointer(bitPattern: 1) : nil),
                  let b = AAEntryXATBlobCreateWithEncodedData(base, data.count) else { return nil }
            blob = b
        }
        deinit { AAEntryXATBlobDestroy(blob) }

        /// Sets the attributes on the file at `path` under `directory`.
        public func apply(directory: FilePath, path: FilePath, flags: ArchiveFlags = []) throws {
            let r = directory.withCString { d in path.withCString { AAEntryXATBlobApplyToPath(blob, d, $0, flags.rawValue) } }
            if r < 0 { throw ArchiveError.ioError }
        }

        /// An extended attribute: its name and value.
        public struct ExtendedAttribute {
            public var key: String
            public var data: ContiguousArray<UInt8>
            public init(key: String, data: ContiguousArray<UInt8>) { self.key = key; self.data = data }
        }

        public func append(_ attribute: ArchiveHeader.EntryXATBlob.ExtendedAttribute) {
            let data = Array(attribute.data)
            _ = data.withUnsafeBufferPointer { AAEntryXATBlobAppendEntry(blob, attribute.key, $0.baseAddress ?? UnsafePointer(bitPattern: 1)!, $0.count) }
        }
        @discardableResult
        public func remove(at index: Int) -> ArchiveHeader.EntryXATBlob.ExtendedAttribute {
            let a = self[index]
            AAEntryXATBlobRemoveEntry(blob, UInt32(index))
            return a
        }
        public func removeAll() { AAEntryXATBlobClear(blob) }
        public func withAAEncodedData<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
            let size = AAEntryXATBlobGetEncodedSize(blob)
            return try body(UnsafeBufferPointer(start: size > 0 ? AAEntryXATBlobGetEncodedData(blob) : nil, count: size))
        }
    }
}

extension ArchiveHeader.EntryXATBlob: RandomAccessCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { Int(AAEntryXATBlobGetEntryCount(blob)) }
    public subscript(position: Int) -> ArchiveHeader.EntryXATBlob.ExtendedAttribute {
        precondition(position >= 0 && position < endIndex, "EntryXATBlob index out of range")
        var klen = 0, dsize = 0
        AAEntryXATBlobGetEntry(blob, UInt32(position), 0, nil, &klen, 0, nil, &dsize)
        var key = [CChar](repeating: 0, count: klen + 1)
        var data = [UInt8](repeating: 0, count: dsize)
        AAEntryXATBlobGetEntry(blob, UInt32(position), key.count, &key, &klen, data.count, &data, &dsize)
        return .init(key: String(cString: key), data: ContiguousArray(data))
    }
}

/// The C callback of every stream with an entry filter: the wrapper in `arg` answers.
let entryMessageProc: AAEntryMessageProc = { arg, message, path, data in
    guard let arg else { return 0 }
    let wrapper = Unmanaged<ArchiveHeader._EntryFilterWrapper>.fromOpaque(arg).takeUnretainedValue()
    let m = ArchiveHeader.EntryMessage(rawValue: message)
    var filterData: ArchiveHeader.EntryFilterData?
    if let data {
        if m == .extractXAT {
            let xat = OpaquePointer(data)
            let size = AAEntryXATBlobGetEncodedSize(xat)
            if let blob = ArchiveHeader.EntryXATBlob(withAAEncodedData: UnsafeBufferPointer(start: size > 0 ? AAEntryXATBlobGetEncodedData(xat) : nil, count: size)) {
                filterData = .entryXAT(blob)
            }
        } else if let header = ArchiveHeader(cloning: OpaquePointer(data)) {
            filterData = .header(header)
        }
    }
    return wrapper.filter(m, FilePath(String(cString: path)), filterData).rawValue
}
