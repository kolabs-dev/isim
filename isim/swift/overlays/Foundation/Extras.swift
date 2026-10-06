// isim Foundation: UUID, CharacterSet, NSNumber conveniences, FileManager/Bundle URL APIs,
// Locale.Language, URL path helpers (self-authored).
import Darwin

// MARK: - UUID

public struct UUID: Hashable, Comparable, Sendable, CustomStringConvertible, Codable {
    public let uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    var bytes: [UInt8] {
        let u = uuid
        return [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
    }
    init(bytes b: [UInt8]) { uuid = (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]) }
    public init() {
        var g = SystemRandomNumberGenerator()
        var b = (0..<16).map { _ in UInt8.random(in: 0...255, using: &g) }
        b[6] = (b[6] & 0x0F) | 0x40      // version 4
        b[8] = (b[8] & 0x3F) | 0x80      // RFC 4122 variant
        self.init(bytes: b)
    }
    public init(uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) { self.uuid = uuid }
    public init?(uuidString s: String) {
        let hex = s.filter { $0 != "-" }
        guard s.count == 36, hex.count == 32 else { return nil }
        var b = [UInt8](); var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            guard let v = UInt8(hex[i..<j], radix: 16) else { return nil }
            b.append(v); i = j
        }
        self.init(bytes: b)
    }
    public var uuidString: String {
        let h = bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16, uppercase: true) }
        return h[0..<4].joined() + "-" + h[4..<6].joined() + "-" + h[6..<8].joined() + "-" + h[8..<10].joined() + "-" + h[10..<16].joined()
    }
    public var description: String { uuidString }
    public static func == (a: UUID, b: UUID) -> Bool { a.bytes == b.bytes }
    public static func < (a: UUID, b: UUID) -> Bool { a.bytes.lexicographicallyPrecedes(b.bytes) }
    public func hash(into h: inout Hasher) { h.combine(bytes) }
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let u = UUID(uuidString: s) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Attempted to decode UUID from invalid UUID string."))
        }
        self = u
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(uuidString) }
}

// MARK: - NSNumber conveniences (Apple's Swift overlay)

extension NSNumber {
    public convenience init(value: Int) { self.init(integer: value) }
    public convenience init(value: Int8) { self.init(integer: Int(value)) }
    public convenience init(value: Int16) { self.init(integer: Int(value)) }
    public convenience init(value: Int32) { self.init(integer: Int(value)) }
    public convenience init(value: Int64) { self.init(longLong: value) }
    public convenience init(value: UInt) { self.init(unsignedInteger: value) }
    public convenience init(value: UInt8) { self.init(unsignedInteger: UInt(value)) }
    public convenience init(value: UInt16) { self.init(unsignedInteger: UInt(value)) }
    public convenience init(value: UInt32) { self.init(unsignedInteger: UInt(value)) }
    public convenience init(value: UInt64) { self.init(unsignedLongLong: value) }
    public convenience init(value: Double) { self.init(double: value) }
    public convenience init(value: Float) { self.init(float: value) }
    public convenience init(value: Bool) { self.init(bool: value) }
    public var int64Value: Int64 { longLongValue }
    public var uint64Value: UInt64 { unsignedLongLongValue }
    public var int32Value: Int32 { intValue }
    public var uint32Value: UInt32 { unsignedIntValue }
    public var int16Value: Int16 { shortValue }
    public var int8Value: Int8 { Int8(truncatingIfNeeded: longLongValue) }
    public var uint8Value: UInt8 { unsignedCharValue }
    public var uintValue: UInt { unsignedLongValue }
}
extension Int64: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSNumber { NSNumber(value: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout Int64?) { result = x.longLongValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout Int64?) -> Bool { result = x.longLongValue; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> Int64 { s?.longLongValue ?? 0 }
}
extension UInt64: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSNumber { NSNumber(value: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout UInt64?) { result = x.unsignedLongLongValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout UInt64?) -> Bool { result = x.unsignedLongLongValue; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> UInt64 { s?.unsignedLongLongValue ?? 0 }
}
extension Int32: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSNumber { NSNumber(value: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout Int32?) { result = x.intValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout Int32?) -> Bool { result = x.intValue; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> Int32 { s?.intValue ?? 0 }
}
extension UInt: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSNumber { NSNumber(value: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout UInt?) { result = x.unsignedLongValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout UInt?) -> Bool { result = x.unsignedLongValue; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> UInt { s?.unsignedLongValue ?? 0 }
}
extension Float: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSNumber { NSNumber(value: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout Float?) { result = x.floatValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout Float?) -> Bool { result = x.floatValue; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> Float { s?.floatValue ?? 0 }
}

// MARK: - CharacterSet

/// A set of Unicode scalars (Apple's CharacterSet). Bridges to NSCharacterSet; sets that come from
/// Objective-C (e.g. a font's coverage) are queried through the object.
public struct CharacterSet: Hashable, Sendable, SetAlgebra {
    public typealias Element = Unicode.Scalar
    indirect enum Node: @unchecked Sendable {
        case ranges([ClosedRange<UInt32>])
        case predicate(String, @Sendable (Unicode.Scalar) -> Bool)
        case ns(NSCharacterSet)
        case not(Node)
        case union(Node, Node)
        case intersection(Node, Node)
        func contains(_ s: Unicode.Scalar) -> Bool {
            switch self {
            case .ranges(let r): return r.contains { $0.contains(s.value) }
            case .predicate(_, let p): return p(s)
            case .ns(let n): return n.longCharacterIsMember(s.value)
            case .not(let a): return !a.contains(s)
            case .union(let a, let b): return a.contains(s) || b.contains(s)
            case .intersection(let a, let b): return a.contains(s) && b.contains(s)
            }
        }
        var key: String {
            switch self {
            case .ranges(let r): return "r" + r.map { "\($0.lowerBound)-\($0.upperBound)" }.joined(separator: ",")
            case .predicate(let n, _): return "p:" + n
            case .ns(let o): return "ns:\(ObjectIdentifier(o))"
            case .not(let a): return "!(" + a.key + ")"
            case .union(let a, let b): return "(" + a.key + "|" + b.key + ")"
            case .intersection(let a, let b): return "(" + a.key + "&" + b.key + ")"
            }
        }
    }
    var node: Node
    init(node: Node) { self.node = node }
    public init() { node = .ranges([]) }
    public init(charactersIn s: String) { node = .ranges(s.unicodeScalars.map { $0.value...$0.value }) }
    public init(charactersIn r: ClosedRange<Unicode.Scalar>) { node = .ranges([r.lowerBound.value...r.upperBound.value]) }
    public init(charactersIn r: Range<Unicode.Scalar>) { node = .ranges(r.isEmpty ? [] : [r.lowerBound.value...(r.upperBound.value - 1)]) }
    public init<S: Sequence>(_ s: S) where S.Element == Unicode.Scalar { node = .ranges(s.map { $0.value...$0.value }) }
    public init(arrayLiteral elements: Unicode.Scalar...) { self.init(elements) }
    static func pred(_ name: String, _ p: @escaping @Sendable (Unicode.Scalar) -> Bool) -> CharacterSet { CharacterSet(node: .predicate(name, p)) }

    public static var whitespaces: CharacterSet { pred("ws") { $0.properties.isWhitespace && $0 != "\n" && $0 != "\r" && !(0x0A...0x0D).contains($0.value) && $0.value != 0x85 && $0.value != 0x2028 && $0.value != 0x2029 } }
    public static var newlines: CharacterSet { CharacterSet(node: .ranges([0x0A...0x0D, 0x85...0x85, 0x2028...0x2029])) }
    public static var whitespacesAndNewlines: CharacterSet { pred("wsnl") { $0.properties.isWhitespace } }
    public static var decimalDigits: CharacterSet { pred("digit") { $0.properties.numericType == .decimal } }
    public static var letters: CharacterSet { pred("letter") { $0.properties.isAlphabetic && $0.properties.generalCategory != .decimalNumber } }
    public static var lowercaseLetters: CharacterSet { pred("lower") { $0.properties.generalCategory == .lowercaseLetter } }
    public static var uppercaseLetters: CharacterSet { pred("upper") { [.uppercaseLetter, .titlecaseLetter].contains($0.properties.generalCategory) } }
    public static var alphanumerics: CharacterSet { pred("alnum") { s in
        switch s.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .decimalNumber, .letterNumber, .otherNumber,
             .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    } }
    public static var punctuationCharacters: CharacterSet { pred("punct") { s in
        switch s.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation: return true
        default: return false
        }
    } }
    public static var symbols: CharacterSet { pred("symbol") { s in
        switch s.properties.generalCategory { case .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol: return true; default: return false }
    } }
    public static var controlCharacters: CharacterSet { pred("control") { [.control, .format].contains($0.properties.generalCategory) } }
    public static var nonBaseCharacters: CharacterSet { pred("nonbase") { [.nonspacingMark, .spacingMark, .enclosingMark].contains($0.properties.generalCategory) } }
    public static var capitalizedLetters: CharacterSet { pred("title") { $0.properties.generalCategory == .titlecaseLetter } }
    public static var illegalCharacters: CharacterSet { pred("illegal") { $0.properties.generalCategory == .unassigned } }
    static func ascii(_ name: String, _ extra: String) -> CharacterSet {
        let allowed = Set(("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" + extra).unicodeScalars)
        return pred(name) { allowed.contains($0) }
    }
    public static var urlQueryAllowed: CharacterSet { ascii("query", "-._~!$&'()*+,;=:@/?") }
    public static var urlPathAllowed: CharacterSet { ascii("path", "-._~!$&'()*+,;=:@/") }
    public static var urlHostAllowed: CharacterSet { ascii("host", "-._~!$&'()*+,;=:[]") }
    public static var urlFragmentAllowed: CharacterSet { ascii("fragment", "-._~!$&'()*+,;=:@/?") }
    public static var urlUserAllowed: CharacterSet { ascii("user", "-._~!$&'()*+,;=") }
    public static var urlPasswordAllowed: CharacterSet { ascii("password", "-._~!$&'()*+,;=") }

    public func contains(_ s: Unicode.Scalar) -> Bool { node.contains(s) }
    public var inverted: CharacterSet { CharacterSet(node: .not(node)) }
    public func union(_ o: CharacterSet) -> CharacterSet { CharacterSet(node: .union(node, o.node)) }
    public func intersection(_ o: CharacterSet) -> CharacterSet { CharacterSet(node: .intersection(node, o.node)) }
    public func symmetricDifference(_ o: CharacterSet) -> CharacterSet { union(o).subtracting(intersection(o)) }
    public func subtracting(_ o: CharacterSet) -> CharacterSet { CharacterSet(node: .intersection(node, .not(o.node))) }
    public mutating func formUnion(_ o: CharacterSet) { self = union(o) }
    public mutating func formIntersection(_ o: CharacterSet) { self = intersection(o) }
    public mutating func formSymmetricDifference(_ o: CharacterSet) { self = symmetricDifference(o) }
    public mutating func subtract(_ o: CharacterSet) { self = subtracting(o) }
    @discardableResult public mutating func insert(_ s: Unicode.Scalar) -> (inserted: Bool, memberAfterInsert: Unicode.Scalar) {
        let had = contains(s); if !had { formUnion(CharacterSet([s])) }; return (!had, s)
    }
    @discardableResult public mutating func update(with s: Unicode.Scalar) -> Unicode.Scalar? { let had = contains(s); insert(s); return had ? s : nil }
    @discardableResult public mutating func remove(_ s: Unicode.Scalar) -> Unicode.Scalar? { let had = contains(s); subtract(CharacterSet([s])); return had ? s : nil }
    public mutating func insert(charactersIn s: String) { formUnion(CharacterSet(charactersIn: s)) }
    public mutating func remove(charactersIn s: String) { subtract(CharacterSet(charactersIn: s)) }
    public mutating func insert(charactersIn r: ClosedRange<Unicode.Scalar>) { formUnion(CharacterSet(charactersIn: r)) }
    public mutating func remove(charactersIn r: ClosedRange<Unicode.Scalar>) { subtract(CharacterSet(charactersIn: r)) }
    public var isEmpty: Bool { if case .ranges(let r) = node { return r.isEmpty }; return false }
    public func isSuperset(of o: CharacterSet) -> Bool { o.isSubset(of: self) }
    public func isSubset(of o: CharacterSet) -> Bool {
        // exact for explicit sets; otherwise checked over the Basic Multilingual Plane
        if case .ranges(let r) = node { return r.allSatisfy { $0.allSatisfy { Unicode.Scalar($0).map(o.contains) ?? true } } }
        for v in UInt32(0)...0xFFFF { if let s = Unicode.Scalar(v), contains(s), !o.contains(s) { return false } }
        return true
    }
    public func hasMember(inPlane p: UInt8) -> Bool {
        let base = UInt32(p) << 16
        for v in base...(base + 0xFFFF) { if let s = Unicode.Scalar(v), contains(s) { return true } }
        return false
    }
    public static func == (a: CharacterSet, b: CharacterSet) -> Bool { a.node.key == b.node.key }
    public func hash(into h: inout Hasher) { h.combine(node.key) }
}

/// NSCharacterSet view of a Swift CharacterSet.
final class _SwiftCharacterSet: NSCharacterSet {
    var set = CharacterSet()
    override func characterIsMember(_ c: unichar) -> Bool { Unicode.Scalar(UInt32(c)).map(set.contains) ?? false }
    override func longCharacterIsMember(_ c: UInt32) -> Bool { Unicode.Scalar(c).map(set.contains) ?? false }
}
extension CharacterSet: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSCharacterSet {
        if case .ns(let n) = node { return n }
        let o = _SwiftCharacterSet(); o.set = self; return o
    }
    public static func _forceBridgeFromObjectiveC(_ x: NSCharacterSet, result: inout CharacterSet?) {
        if let s = x as? _SwiftCharacterSet { result = s.set } else { result = CharacterSet(node: .ns(x)) }
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSCharacterSet, result: inout CharacterSet?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSCharacterSet?) -> CharacterSet {
        var r: CharacterSet?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? CharacterSet()
    }
}

extension StringProtocol {
    public func trimmingCharacters(in set: CharacterSet) -> String {
        let scalars = Array(String(self).unicodeScalars)
        var a = 0, b = scalars.count
        while a < b, set.contains(scalars[a]) { a += 1 }
        while b > a, set.contains(scalars[b - 1]) { b -= 1 }
        var v = String.UnicodeScalarView(); v.append(contentsOf: scalars[a..<b])
        return String(v)
    }
    public func components(separatedBy set: CharacterSet) -> [String] {
        var out: [String] = [], cur = String.UnicodeScalarView()
        for s in String(self).unicodeScalars {
            if set.contains(s) { out.append(String(cur)); cur = String.UnicodeScalarView() } else { cur.append(s) }
        }
        out.append(String(cur))
        return out
    }
    public func rangeOfCharacter(from set: CharacterSet, options: String.CompareOptions = [], range: Range<String.Index>? = nil) -> Range<String.Index>? {
        let s = String(self)
        let r = range ?? s.startIndex..<s.endIndex
        let scalars = s.unicodeScalars
        if options.contains(.backwards) {
            var i = r.upperBound
            while i > r.lowerBound { let p = scalars.index(before: i); if set.contains(scalars[p]) { return p..<i }; i = p }
        } else {
            var i = r.lowerBound
            while i < r.upperBound { let n = scalars.index(after: i); if set.contains(scalars[i]) { return i..<n }; i = n }
        }
        return nil
    }
    public func addingPercentEncoding(withAllowedCharacters allowed: CharacterSet) -> String? {
        var out = ""
        for s in String(self).unicodeScalars {
            if allowed.contains(s) { out.unicodeScalars.append(s) }
            else { for b in String(s).utf8 { out += "%" + (b < 16 ? "0" : "") + String(b, radix: 16, uppercase: true) } }
        }
        return out
    }
    public var removingPercentEncoding: String? {
        var bytes = [UInt8](); let u = Array(String(self).utf8); var i = 0
        while i < u.count {
            if u[i] == UInt8(ascii: "%") {
                guard i + 2 < u.count, let v = UInt8(String(decoding: u[i + 1...i + 2], as: UTF8.self), radix: 16) else { return nil }
                bytes.append(v); i += 3
            } else { bytes.append(u[i]); i += 1 }
        }
        return _validUTF8(bytes)
    }
}
extension String {
    public typealias CompareOptions = NSString.CompareOptions
    public typealias EnumerationOptions = NSString.EnumerationOptions
}

// MARK: - Locale.Language

extension Locale {
    public enum LanguageDirection: Int, Sendable { case unknown, leftToRight, rightToLeft, topToBottom, bottomToTop }
    public struct LanguageCode: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral s: String) { identifier = s }
        public var description: String { identifier }
    }
    public struct Region: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        public let identifier: String
        public init(_ identifier: String) { self.identifier = identifier }
        public init(stringLiteral s: String) { identifier = s }
        public var description: String { identifier }
    }
    public struct Language: Hashable, Sendable {
        let id: String
        public init(identifier: String) { id = String(identifier.map { $0 == "_" ? "-" : $0 }) }
        public var minimalIdentifier: String { id }
        public var maximalIdentifier: String { id }
        public var languageCode: LanguageCode? { id.split(separator: "-").first.map { LanguageCode(String($0)) } }
        public var region: Region? {
            id.split(separator: "-").dropFirst().first { $0.count == 2 && $0.uppercased() == $0 }.map { Region(String($0)) }
        }
        static let rtl: Set<String> = ["ar", "he", "iw", "fa", "ur", "yi", "ps", "sd", "ug", "dv", "ckb", "syr", "ks", "ku-Arab"]
        public var characterDirection: LanguageDirection {
            let code = languageCode?.identifier ?? ""
            let subtags = id.split(separator: "-").dropFirst().map(String.init)
            if subtags.contains("Arab") || subtags.contains("Hebr") { return .rightToLeft }
            if subtags.contains("Latn") || subtags.contains("Cyrl") { return .leftToRight }
            return Language.rtl.contains(code) ? .rightToLeft : .leftToRight
        }
        public var lineLayoutDirection: LanguageDirection { .topToBottom }
    }
    public var language: Language { Language(identifier: identifier) }
    public static func characterDirection(forLanguage code: String) -> LanguageDirection { Language(identifier: code).characterDirection }
}

// MARK: - URL helpers

extension URL: Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let u = URL(string: s) else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid URL string.")) }
        self = u
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(absoluteString) }
}
extension URL {
    public init(filePath path: String) { self.init(fileURLWithPath: path) }
    public func appendingPathComponent(_ c: String, isDirectory: Bool) -> URL { appendingPathComponent(c) }
    public func appending(path: String) -> URL { appendingPathComponent(path) }
    public func appending(component: String) -> URL { appendingPathComponent(component) }
    public func appendingPathExtension(_ ext: String) -> URL {
        isFileURL ? URL(fileURLWithPath: path + "." + ext) : (URL(string: absoluteString + "." + ext) ?? self)
    }
    public func deletingPathExtension() -> URL {
        let ext = pathExtension
        guard !ext.isEmpty else { return self }
        let p = String(path.dropLast(ext.count + 1))
        return isFileURL ? URL(fileURLWithPath: p) : (URL(string: String(absoluteString.dropLast(ext.count + 1))) ?? self)
    }
    public func deletingLastPathComponent() -> URL {
        var parts = path.split(separator: "/", omittingEmptySubsequences: true)
        if !parts.isEmpty { parts.removeLast() }
        let p = "/" + parts.joined(separator: "/")
        return isFileURL ? URL(fileURLWithPath: p) : (URL(string: (scheme.map { $0 + "://" } ?? "") + (host ?? "") + p) ?? self)
    }
    public var pathComponents: [String] {
        let parts = path.split(separator: "/").map(String.init)
        return path.hasPrefix("/") ? ["/"] + parts : parts
    }
    public var standardizedFileURL: URL { self }
    public var absoluteURL: URL { self }
    public var hasDirectoryPath: Bool { absoluteString.hasSuffix("/") }
    public func path(percentEncoded: Bool = true) -> String { path }
    public static var documentsDirectory: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    public static var applicationSupportDirectory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
    public static var cachesDirectory: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0] }
    public static var temporaryDirectory: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }
    public func checkResourceIsReachable() throws -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { throw _fileError(260, path, "The file doesn’t exist.") }
        return true
    }
}

// MARK: - FileManager

extension FileManager {
    public func contents(atPath path: String) -> Data? { _readFile(path) }
    @discardableResult
    public func createFile(atPath path: String, contents: Data?, attributes: [String: Any]? = nil) -> Bool {
        (try? (contents ?? Data()).write(to: URL(fileURLWithPath: path))) != nil
    }
    public func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [String: Any]? = nil) throws {
        try createDirectory(atPath: url.path, withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
    }
    public func removeItem(at url: URL) throws { try removeItem(atPath: url.path) }
    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [String]? = nil, options: Int = 0) throws -> [URL] {
        try contentsOfDirectory(atPath: url.path).map { url.appendingPathComponent($0) }
    }
    public func moveItem(atPath src: String, toPath dst: String) throws {
        guard rename(src, dst) == 0 else { throw _fileError(512, src, "The file couldn’t be moved.") }
    }
    public func moveItem(at src: URL, to dst: URL) throws { try moveItem(atPath: src.path, toPath: dst.path) }
    public func copyItem(atPath src: String, toPath dst: String) throws {
        guard let d = _readFile(src) else { throw _fileError(260, src, "The file doesn’t exist.") }
        guard !fileExists(atPath: dst) else { throw _fileError(516, dst, "The file already exists.") }
        try d.write(to: URL(fileURLWithPath: dst))
    }
    public func copyItem(at src: URL, to dst: URL) throws { try copyItem(atPath: src.path, toPath: dst.path) }
    public func isReadableFile(atPath path: String) -> Bool { access(path, R_OK) == 0 }
    public func isWritableFile(atPath path: String) -> Bool { access(path, W_OK) == 0 }
    public var temporaryDirectory: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }
}

// MARK: - Bundle resources

extension Bundle {
    public func url(forResource name: String?, withExtension ext: String?) -> URL? {
        url(forResource: name, withExtension: ext, subdirectory: nil)
    }
    public func url(forResource name: String?, withExtension ext: String?, subdirectory sub: String?) -> URL? {
        if let n = name, let p = path(forResource: n, ofType: ext, inDirectory: sub, forLocalization: nil) { return URL(fileURLWithPath: p) }
        if name == nil, let ext { return urls(forResourcesWithExtension: ext, subdirectory: sub)?.first }
        return nil
    }
    public func urls(forResourcesWithExtension ext: String?, subdirectory sub: String?) -> [URL]? {
        var dir = resourcePath ?? bundlePath
        if let s = sub, !s.isEmpty { dir = (dir as NSString).appendingPathComponent(s) }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }
        return names.sorted().filter { ext == nil || ext == "" || ($0 as NSString).pathExtension == ext }
            .map { URL(fileURLWithPath: (dir as NSString).appendingPathComponent($0)) }
    }
    public func paths(forResourcesOfType ext: String?, inDirectory sub: String?) -> [String] {
        (urls(forResourcesWithExtension: ext, subdirectory: sub) ?? []).map(\.path)
    }
    public var resourceURL: URL? { resourcePath.map { URL(fileURLWithPath: $0) } }
    public var bundleURL: URL { URL(fileURLWithPath: bundlePath) }
    public var executableURL: URL? { executablePath.map { URL(fileURLWithPath: $0) } }
}
