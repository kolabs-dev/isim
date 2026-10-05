// isim Foundation: JSONSerialization, JSONEncoder, JSONDecoder (self-authored, pure Swift).
// JSONSerialization returns numbers as NSNumber and null as NSNull, like Apple's.

// MARK: - JSON values

enum _JSON {
    case null
    case bool(Bool)
    case int(Int64)
    case uint(UInt64)
    case double(Double)
    case string(String)
    case array([_JSON])
    case object([(String, _JSON)])

    var objectValue: [String: _JSON]? {
        guard case .object(let pairs) = self else { return nil }
        var d = [String: _JSON](minimumCapacity: pairs.count)
        for (k, v) in pairs { d[k] = v }
        return d
    }
}

struct _JSONParser {
    let b: [UInt8]
    var i = 0
    init(_ data: Data) { b = data.bytes }

    static func error(_ msg: String, _ at: Int) -> NSError {
        NSError(domain: NSCocoaErrorDomain, code: 3840, userInfo: [NSLocalizedDescriptionKey: "The data couldn’t be read because it isn’t in the correct format.",
                                                                   "NSDebugDescription": "\(msg) around character \(at)."])
    }
    mutating func ws() { while i < b.count, b[i] == 0x20 || b[i] == 0x0A || b[i] == 0x0D || b[i] == 0x09 { i += 1 } }
    mutating func parseDocument(allowFragments: Bool) throws -> _JSON {
        // skip a UTF-8 BOM
        if b.count >= 3, b[0] == 0xEF, b[1] == 0xBB, b[2] == 0xBF { i = 3 }
        ws()
        let v = try value()
        ws()
        if i != b.count { throw _JSONParser.error("Garbage at end", i) }
        if !allowFragments { switch v { case .array, .object: break; default: throw _JSONParser.error("JSON text did not start with array or object and option to allow fragments not set", 0) } }
        return v
    }
    mutating func value() throws -> _JSON {
        guard i < b.count else { throw _JSONParser.error("Unexpected end of file", i) }
        switch b[i] {
        case UInt8(ascii: "{"):
            i += 1; ws()
            var pairs: [(String, _JSON)] = []
            if i < b.count, b[i] == UInt8(ascii: "}") { i += 1; return .object(pairs) }
            while true {
                ws()
                guard i < b.count, b[i] == UInt8(ascii: "\"") else { throw _JSONParser.error("No string key for value in object", i) }
                let k = try string()
                ws()
                guard i < b.count, b[i] == UInt8(ascii: ":") else { throw _JSONParser.error("No value for key in object", i) }
                i += 1; ws()
                pairs.append((k, try value()))
                ws()
                guard i < b.count else { throw _JSONParser.error("Unexpected end of file", i) }
                if b[i] == UInt8(ascii: ",") { i += 1; continue }
                if b[i] == UInt8(ascii: "}") { i += 1; return .object(pairs) }
                throw _JSONParser.error("Badly formed object", i)
            }
        case UInt8(ascii: "["):
            i += 1; ws()
            var items: [_JSON] = []
            if i < b.count, b[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
            while true {
                ws()
                items.append(try value())
                ws()
                guard i < b.count else { throw _JSONParser.error("Unexpected end of file", i) }
                if b[i] == UInt8(ascii: ",") { i += 1; continue }
                if b[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
                throw _JSONParser.error("Badly formed array", i)
            }
        case UInt8(ascii: "\""): return .string(try string())
        case UInt8(ascii: "t"): try literal("true"); return .bool(true)
        case UInt8(ascii: "f"): try literal("false"); return .bool(false)
        case UInt8(ascii: "n"): try literal("null"); return .null
        default: return try number()
        }
    }
    mutating func literal(_ s: String) throws {
        let u = Array(s.utf8)
        guard i + u.count <= b.count, Array(b[i..<i + u.count]) == u else { throw _JSONParser.error("Invalid value", i) }
        i += u.count
    }
    mutating func number() throws -> _JSON {
        let start = i
        var isFloat = false
        if i < b.count, b[i] == UInt8(ascii: "-") { i += 1 }
        while i < b.count {
            let c = b[i]
            if c >= 0x30 && c <= 0x39 { i += 1 }
            else if c == UInt8(ascii: ".") || c == UInt8(ascii: "e") || c == UInt8(ascii: "E") || c == UInt8(ascii: "+") || c == UInt8(ascii: "-") { isFloat = true; i += 1 }
            else { break }
        }
        guard i > start else { throw _JSONParser.error("Invalid value", start) }
        let text = String(decoding: b[start..<i], as: UTF8.self)
        if !isFloat {
            if let v = Int64(text) { return .int(v) }
            if let v = UInt64(text) { return .uint(v) }
        }
        guard let d = Double(text) else { throw _JSONParser.error("Invalid number", start) }
        return .double(d)
    }
    mutating func string() throws -> String {
        i += 1   // opening quote
        var out = [UInt8]()
        while i < b.count {
            let c = b[i]
            if c == UInt8(ascii: "\"") { i += 1; return String(decoding: out, as: UTF8.self) }
            if c == UInt8(ascii: "\\") {
                i += 1
                guard i < b.count else { break }
                let e = b[i]; i += 1
                switch e {
                case UInt8(ascii: "\""): out.append(0x22)
                case UInt8(ascii: "\\"): out.append(0x5C)
                case UInt8(ascii: "/"): out.append(0x2F)
                case UInt8(ascii: "b"): out.append(0x08)
                case UInt8(ascii: "f"): out.append(0x0C)
                case UInt8(ascii: "n"): out.append(0x0A)
                case UInt8(ascii: "r"): out.append(0x0D)
                case UInt8(ascii: "t"): out.append(0x09)
                case UInt8(ascii: "u"):
                    var u = try hex4()
                    if u >= 0xD800 && u < 0xDC00, i + 1 < b.count, b[i] == UInt8(ascii: "\\"), b[i + 1] == UInt8(ascii: "u") {
                        i += 2
                        let lo = try hex4()
                        u = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
                    }
                    out += Array(String(Character(Unicode.Scalar(u) ?? "\u{FFFD}")).utf8)
                default: throw _JSONParser.error("Invalid escape sequence", i - 1)
                }
                continue
            }
            out.append(c); i += 1
        }
        throw _JSONParser.error("Unterminated string", i)
    }
    mutating func hex4() throws -> UInt32 {
        guard i + 4 <= b.count, let v = UInt32(String(decoding: b[i..<i + 4], as: UTF8.self), radix: 16) else { throw _JSONParser.error("Invalid unicode escape", i) }
        i += 4
        return v
    }
}

struct _JSONWriter {
    var out = [UInt8]()
    let pretty: Bool, sorted: Bool, escapeSlashes: Bool
    mutating func write(_ v: _JSON, depth: Int = 0) {
        switch v {
        case .null: out += Array("null".utf8)
        case .bool(let x): out += Array((x ? "true" : "false").utf8)
        case .int(let x): out += Array(String(x).utf8)
        case .uint(let x): out += Array(String(x).utf8)
        case .double(let x): out += Array(_JSONWriter.format(x).utf8)
        case .string(let s): string(s)
        case .array(let items):
            if items.isEmpty { out += Array("[]".utf8); return }
            out.append(UInt8(ascii: "["))
            for (n, item) in items.enumerated() {
                if n > 0 { out.append(UInt8(ascii: ",")) }
                newline(depth + 1)
                write(item, depth: depth + 1)
            }
            newline(depth)
            out.append(UInt8(ascii: "]"))
        case .object(var pairs):
            if pairs.isEmpty { out += Array("{}".utf8); return }
            if sorted { pairs.sort { $0.0.utf16.lexicographicallyPrecedes($1.0.utf16) } }
            out.append(UInt8(ascii: "{"))
            for (n, (k, item)) in pairs.enumerated() {
                if n > 0 { out.append(UInt8(ascii: ",")) }
                newline(depth + 1)
                string(k)
                out += Array((pretty ? " : " : ":").utf8)
                write(item, depth: depth + 1)
            }
            newline(depth)
            out.append(UInt8(ascii: "}"))
        }
    }
    mutating func newline(_ depth: Int) {
        guard pretty else { return }
        out.append(0x0A)
        out += [UInt8](repeating: 0x20, count: depth * 2)
    }
    mutating func string(_ s: String) {
        out.append(0x22)
        for u in s.utf8 {
            switch u {
            case 0x22: out += [0x5C, 0x22]
            case 0x5C: out += [0x5C, 0x5C]
            case 0x2F: if escapeSlashes { out += [0x5C, 0x2F] } else { out.append(u) }
            case 0x0A: out += [0x5C, UInt8(ascii: "n")]
            case 0x0D: out += [0x5C, UInt8(ascii: "r")]
            case 0x09: out += [0x5C, UInt8(ascii: "t")]
            case 0x08: out += [0x5C, UInt8(ascii: "b")]
            case 0x0C: out += [0x5C, UInt8(ascii: "f")]
            case 0..<0x20: out += Array(("\\u00" + (u < 16 ? "0" : "") + String(u, radix: 16)).utf8)
            default: out.append(u)
            }
        }
        out.append(0x22)
    }
    static func format(_ d: Double) -> String {
        if d.isFinite, d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        return String(d)
    }
}

// MARK: - JSONSerialization

open class JSONSerialization: NSObject {
    public struct ReadingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mutableContainers = ReadingOptions(rawValue: 1)
        public static let mutableLeaves = ReadingOptions(rawValue: 2)
        public static let fragmentsAllowed = ReadingOptions(rawValue: 4)
        public static let allowFragments = ReadingOptions(rawValue: 4)
        public static let json5Allowed = ReadingOptions(rawValue: 8)
        public static let topLevelDictionaryAssumed = ReadingOptions(rawValue: 16)
    }
    public struct WritingOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let prettyPrinted = WritingOptions(rawValue: 1)
        public static let sortedKeys = WritingOptions(rawValue: 2)
        public static let fragmentsAllowed = WritingOptions(rawValue: 4)
        public static let withoutEscapingSlashes = WritingOptions(rawValue: 8)
    }

    open class func jsonObject(with data: Data, options: ReadingOptions = []) throws -> Any {
        var p = _JSONParser(data)
        return toFoundation(try p.parseDocument(allowFragments: options.contains(.fragmentsAllowed)))
    }
    open class func data(withJSONObject obj: Any, options: WritingOptions = []) throws -> Data {
        guard let v = fromFoundation(obj) else {
            throw NSError(domain: NSCocoaErrorDomain, code: 3851, userInfo: [NSLocalizedDescriptionKey: "Invalid type in JSON write"])
        }
        if !options.contains(.fragmentsAllowed) {
            switch v { case .array, .object: break; default: throw NSError(domain: NSCocoaErrorDomain, code: 3851, userInfo: [NSLocalizedDescriptionKey: "Invalid top-level type in JSON write"]) }
        }
        var w = _JSONWriter(pretty: options.contains(.prettyPrinted), sorted: options.contains(.sortedKeys),
                            escapeSlashes: !options.contains(.withoutEscapingSlashes))
        w.write(v)
        return Data(w.out)
    }
    open class func isValidJSONObject(_ obj: Any) -> Bool {
        guard let v = fromFoundation(obj) else { return false }
        switch v { case .array, .object: return true; default: return false }
    }

    static func toFoundation(_ v: _JSON) -> Any {
        switch v {
        case .null: return NSNull()
        case .bool(let b): return NSNumber(value: b)
        case .int(let x): return NSNumber(value: x)
        case .uint(let x): return NSNumber(value: x)
        case .double(let x): return NSNumber(value: x)
        case .string(let s): return s
        case .array(let a): return a.map(toFoundation)
        case .object(let pairs):
            var d = [String: Any](minimumCapacity: pairs.count)
            for (k, x) in pairs { d[k] = toFoundation(x) }
            return d
        }
    }
    static func fromFoundation(_ obj: Any) -> _JSON? {
        switch obj {
        case let s as String: return .string(s)
        case let b as Bool where !(obj is NSNumber): return .bool(b)
        case let n as NSNumber: return _numberJSON(n)
        case let i as Int: return .int(Int64(i))
        case let d as Double: return d.isFinite ? .double(d) : nil
        case is NSNull: return .null
        case let d as [String: Any]:
            var pairs: [(String, _JSON)] = []
            for (k, x) in d { guard let j = fromFoundation(x) else { return nil }; pairs.append((k, j)) }
            return .object(pairs)
        case let a as [Any]:
            var items: [_JSON] = []
            for x in a { guard let j = fromFoundation(x) else { return nil }; items.append(j) }
            return .array(items)
        case let o as Optional<Any>:
            if case .some(let x) = o { return fromFoundation(x) }
            return .null
        default: return nil
        }
    }
}

/// NSNumber -> JSON number/bool, by its stored type.
func _numberJSON(_ n: NSNumber) -> _JSON {
    if n._isim_isBool { return .bool(n.boolValue) }
    switch n.objCType.pointee {
    case CChar(UInt8(ascii: "d")), CChar(UInt8(ascii: "f")): return .double(n.doubleValue)
    case CChar(UInt8(ascii: "Q")): return .uint(n.unsignedLongLongValue)
    default: return .int(n.longLongValue)
    }
}

// MARK: - Encoder

open class JSONEncoder {
    public struct OutputFormatting: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let prettyPrinted = OutputFormatting(rawValue: 1)
        public static let sortedKeys = OutputFormatting(rawValue: 2)
        public static let withoutEscapingSlashes = OutputFormatting(rawValue: 8)
    }
    public enum DateEncodingStrategy {
        case deferredToDate, secondsSince1970, millisecondsSince1970, iso8601
        case formatted(DateFormatterLike)
        case custom((Date, Encoder) throws -> Void)
    }
    public enum DataEncodingStrategy { case deferredToData, base64, custom((Data, Encoder) throws -> Void) }
    public enum NonConformingFloatEncodingStrategy { case `throw`, convertToString(positiveInfinity: String, negativeInfinity: String, nan: String) }
    public enum KeyEncodingStrategy {
        case useDefaultKeys, convertToSnakeCase
        case custom((_ codingPath: [CodingKey]) -> CodingKey)
    }

    open var outputFormatting: OutputFormatting = []
    open var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate
    open var dataEncodingStrategy: DataEncodingStrategy = .base64
    open var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw
    open var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    public init() {}

    open func encode<T: Encodable>(_ value: T) throws -> Data {
        let e = _JSONEncoderImpl(options: self, codingPath: [])
        let v = try e.box(value)
        var w = _JSONWriter(pretty: outputFormatting.contains(.prettyPrinted), sorted: outputFormatting.contains(.sortedKeys),
                            escapeSlashes: !outputFormatting.contains(.withoutEscapingSlashes))
        w.write(v.json)
        return Data(w.out)
    }

    static func snakeCase(_ key: String) -> String {
        guard !key.isEmpty else { return key }
        var out = ""
        var prevLower = false
        for c in key {
            if c.isUppercase {
                if prevLower { out.append("_") }
                out += c.lowercased()
                prevLower = false
            } else { out.append(c); prevLower = c.isLowercase || c.isNumber }
        }
        return out
    }
}

/// A formatter usable by .formatted date strategies (DateFormatter on Apple).
public protocol DateFormatterLike {
    func string(from date: Date) -> String
    func date(from string: String) -> Date?
}

/// Mutable JSON tree used while encoding (containers share boxes).
final class _Box {
    enum Kind { case value(_JSON), array([_Box]), object([(String, _Box)]) }
    var kind: Kind
    init(_ k: Kind) { kind = k }
    var json: _JSON {
        switch kind {
        case .value(let v): return v
        case .array(let a): return .array(a.map(\.json))
        case .object(let o): return .object(o.map { ($0.0, $0.1.json) })
        }
    }
    func set(_ key: String, _ b: _Box) {
        guard case .object(var o) = kind else { return }
        if let i = o.firstIndex(where: { $0.0 == key }) { o[i].1 = b } else { o.append((key, b)) }
        kind = .object(o)
    }
    func append(_ b: _Box) {
        guard case .array(var a) = kind else { return }
        a.append(b); kind = .array(a)
    }
    var count: Int { if case .array(let a) = kind { return a.count }; return 0 }
}

struct _JSONKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init(intValue: Int) { stringValue = "\(intValue)"; self.intValue = intValue }
    init(index: Int) { stringValue = "Index \(index)"; intValue = index }
    static let `super` = _JSONKey(stringValue: "super")
}

final class _JSONEncoderImpl: Encoder {
    let options: JSONEncoder
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { options.userInfo }
    var root: _Box?
    init(options: JSONEncoder, codingPath: [CodingKey]) { self.options = options; self.codingPath = codingPath }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let b: _Box
        if let r = root, case .object = r.kind { b = r } else { b = _Box(.object([])); root = b }
        return KeyedEncodingContainer(_KeyedEncoder<Key>(encoder: self, box: b, codingPath: codingPath))
    }
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let b: _Box
        if let r = root, case .array = r.kind { b = r } else { b = _Box(.array([])); root = b }
        return _UnkeyedEncoder(encoder: self, box: b, codingPath: codingPath)
    }
    func singleValueContainer() -> SingleValueEncodingContainer { _SingleEncoder(encoder: self, codingPath: codingPath) }

    func key(_ k: CodingKey) -> String {
        switch options.keyEncodingStrategy {
        case .useDefaultKeys: return k.stringValue
        case .convertToSnakeCase: return JSONEncoder.snakeCase(k.stringValue)
        case .custom(let f): return f(codingPath + [k]).stringValue
        }
    }

    func boxDouble(_ d: Double) throws -> _JSON {
        if d.isFinite { return .double(d) }
        if case .convertToString(let pos, let neg, let nan) = options.nonConformingFloatEncodingStrategy {
            return .string(d.isNaN ? nan : (d > 0 ? pos : neg))
        }
        throw EncodingError.invalidValue(d, EncodingError.Context(codingPath: codingPath, debugDescription: "Unable to encode \(d) directly in JSON."))
    }

    /// Encodes a value into a box, handling Foundation types JSONEncoder treats specially.
    func box<T: Encodable>(_ value: T, at extra: CodingKey? = nil) throws -> _Box {
        let path = extra.map { codingPath + [$0] } ?? codingPath
        switch value {
        case let d as Date:
            switch options.dateEncodingStrategy {
            case .deferredToDate: break
            case .secondsSince1970: return _Box(.value(.double(d.timeIntervalSince1970)))
            case .millisecondsSince1970: return _Box(.value(.double(d.timeIntervalSince1970 * 1000)))
            case .iso8601: return _Box(.value(.string(_ISO8601.string(d))))
            case .formatted(let f): return _Box(.value(.string(f.string(from: d))))
            case .custom(let f):
                let e = _JSONEncoderImpl(options: options, codingPath: path)
                try f(d, e)
                return e.root ?? _Box(.value(.object([])))
            }
        case let d as Data:
            switch options.dataEncodingStrategy {
            case .deferredToData: break
            case .base64: return _Box(.value(.string(d.base64EncodedString())))
            case .custom(let f):
                let e = _JSONEncoderImpl(options: options, codingPath: path)
                try f(d, e)
                return e.root ?? _Box(.value(.object([])))
            }
        case let u as URL: return _Box(.value(.string(u.absoluteString)))
        case let d as Decimal: return _Box(.value(Double(d.description).map { .double($0) } ?? .string(d.description)))
        default: break
        }
        let e = _JSONEncoderImpl(options: options, codingPath: path)
        try value.encode(to: e)
        return e.root ?? _Box(.value(.object([])))
    }
}

struct _KeyedEncoder<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _JSONEncoderImpl
    let box: _Box
    var codingPath: [CodingKey]
    func put(_ k: Key, _ v: _JSON) { box.set(encoder.key(k), _Box(.value(v))) }
    mutating func encodeNil(forKey k: Key) throws { put(k, .null) }
    mutating func encode(_ v: Bool, forKey k: Key) throws { put(k, .bool(v)) }
    mutating func encode(_ v: String, forKey k: Key) throws { put(k, .string(v)) }
    mutating func encode(_ v: Double, forKey k: Key) throws { put(k, try encoder.boxDouble(v)) }
    mutating func encode(_ v: Float, forKey k: Key) throws { put(k, try encoder.boxDouble(Double(v))) }
    mutating func encode(_ v: Int, forKey k: Key) throws { put(k, .int(Int64(v))) }
    mutating func encode(_ v: Int8, forKey k: Key) throws { put(k, .int(Int64(v))) }
    mutating func encode(_ v: Int16, forKey k: Key) throws { put(k, .int(Int64(v))) }
    mutating func encode(_ v: Int32, forKey k: Key) throws { put(k, .int(Int64(v))) }
    mutating func encode(_ v: Int64, forKey k: Key) throws { put(k, .int(v)) }
    mutating func encode(_ v: UInt, forKey k: Key) throws { put(k, .uint(UInt64(v))) }
    mutating func encode(_ v: UInt8, forKey k: Key) throws { put(k, .uint(UInt64(v))) }
    mutating func encode(_ v: UInt16, forKey k: Key) throws { put(k, .uint(UInt64(v))) }
    mutating func encode(_ v: UInt32, forKey k: Key) throws { put(k, .uint(UInt64(v))) }
    mutating func encode(_ v: UInt64, forKey k: Key) throws { put(k, .uint(v)) }
    mutating func encode<T: Encodable>(_ v: T, forKey k: Key) throws {
        encoder.codingPath.append(k); defer { encoder.codingPath.removeLast() }
        box.set(encoder.key(k), try encoder.box(v))
    }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy t: NestedKey.Type, forKey k: Key) -> KeyedEncodingContainer<NestedKey> {
        let b = _Box(.object([])); box.set(encoder.key(k), b)
        return KeyedEncodingContainer(_KeyedEncoder<NestedKey>(encoder: encoder, box: b, codingPath: codingPath + [k]))
    }
    mutating func nestedUnkeyedContainer(forKey k: Key) -> UnkeyedEncodingContainer {
        let b = _Box(.array([])); box.set(encoder.key(k), b)
        return _UnkeyedEncoder(encoder: encoder, box: b, codingPath: codingPath + [k])
    }
    mutating func superEncoder() -> Encoder { let b = box; return _SubEncoder(parent: encoder, codingPath: codingPath + [_JSONKey.super]) { b.set("super", $0) } }
    mutating func superEncoder(forKey k: Key) -> Encoder { let key = encoder.key(k), b = box; return _SubEncoder(parent: encoder, codingPath: codingPath + [k]) { b.set(key, $0) } }
}

struct _UnkeyedEncoder: UnkeyedEncodingContainer {
    let encoder: _JSONEncoderImpl
    let box: _Box
    var codingPath: [CodingKey]
    var count: Int { box.count }
    func put(_ v: _JSON) { box.append(_Box(.value(v))) }
    mutating func encodeNil() throws { put(.null) }
    mutating func encode(_ v: Bool) throws { put(.bool(v)) }
    mutating func encode(_ v: String) throws { put(.string(v)) }
    mutating func encode(_ v: Double) throws { put(try encoder.boxDouble(v)) }
    mutating func encode(_ v: Float) throws { put(try encoder.boxDouble(Double(v))) }
    mutating func encode(_ v: Int) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int8) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int16) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int32) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int64) throws { put(.int(v)) }
    mutating func encode(_ v: UInt) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt8) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt16) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt32) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt64) throws { put(.uint(v)) }
    mutating func encode<T: Encodable>(_ v: T) throws {
        let k = _JSONKey(index: count)
        encoder.codingPath.append(k); defer { encoder.codingPath.removeLast() }
        box.append(try encoder.box(v))
    }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy t: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let b = _Box(.object([])); let k = _JSONKey(index: count); box.append(b)
        return KeyedEncodingContainer(_KeyedEncoder<NestedKey>(encoder: encoder, box: b, codingPath: codingPath + [k]))
    }
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let b = _Box(.array([])); let k = _JSONKey(index: count); box.append(b)
        return _UnkeyedEncoder(encoder: encoder, box: b, codingPath: codingPath + [k])
    }
    mutating func superEncoder() -> Encoder {
        let placeholder = _Box(.value(.null)); box.append(placeholder)
        return _SubEncoder(parent: encoder, codingPath: codingPath + [_JSONKey(index: count - 1)]) { placeholder.kind = $0.kind }
    }
}

struct _SingleEncoder: SingleValueEncodingContainer {
    let encoder: _JSONEncoderImpl
    var codingPath: [CodingKey]
    func put(_ v: _JSON) { encoder.root = _Box(.value(v)) }
    mutating func encodeNil() throws { put(.null) }
    mutating func encode(_ v: Bool) throws { put(.bool(v)) }
    mutating func encode(_ v: String) throws { put(.string(v)) }
    mutating func encode(_ v: Double) throws { put(try encoder.boxDouble(v)) }
    mutating func encode(_ v: Float) throws { put(try encoder.boxDouble(Double(v))) }
    mutating func encode(_ v: Int) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int8) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int16) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int32) throws { put(.int(Int64(v))) }
    mutating func encode(_ v: Int64) throws { put(.int(v)) }
    mutating func encode(_ v: UInt) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt8) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt16) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt32) throws { put(.uint(UInt64(v))) }
    mutating func encode(_ v: UInt64) throws { put(.uint(v)) }
    mutating func encode<T: Encodable>(_ v: T) throws { encoder.root = try encoder.box(v) }
}

/// Encoder for superEncoder(): writes its result into the parent when deinitialized.
final class _SubEncoder: Encoder {
    let inner: _JSONEncoderImpl
    let commit: (_Box) -> Void
    var codingPath: [CodingKey] { inner.codingPath }
    var userInfo: [CodingUserInfoKey: Any] { inner.userInfo }
    init(parent: _JSONEncoderImpl, codingPath: [CodingKey], commit: @escaping (_Box) -> Void) {
        inner = _JSONEncoderImpl(options: parent.options, codingPath: codingPath); self.commit = commit
    }
    deinit { commit(inner.root ?? _Box(.value(.object([])))) }
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> { inner.container(keyedBy: type) }
    func unkeyedContainer() -> UnkeyedEncodingContainer { inner.unkeyedContainer() }
    func singleValueContainer() -> SingleValueEncodingContainer { inner.singleValueContainer() }
}

// MARK: - Decoder

open class JSONDecoder {
    public enum DateDecodingStrategy {
        case deferredToDate, secondsSince1970, millisecondsSince1970, iso8601
        case formatted(DateFormatterLike)
        case custom((Decoder) throws -> Date)
    }
    public enum DataDecodingStrategy { case deferredToData, base64, custom((Decoder) throws -> Data) }
    public enum NonConformingFloatDecodingStrategy { case `throw`, convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String) }
    public enum KeyDecodingStrategy {
        case useDefaultKeys, convertFromSnakeCase
        case custom((_ codingPath: [CodingKey]) -> CodingKey)
    }
    open var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    open var dataDecodingStrategy: DataDecodingStrategy = .base64
    open var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw
    open var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    open var allowsJSON5 = false
    open var assumesTopLevelDictionary = false
    public init() {}

    open func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        var p = _JSONParser(data)
        let root: _JSON
        do { root = try p.parseDocument(allowFragments: true) }
        catch { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON.", underlyingError: error)) }
        return try _JSONDecoderImpl(options: self, value: root, codingPath: []).unbox(type)
    }

    static func camelCase(_ key: String) -> String {
        guard key.contains("_") else { return key }
        let parts = key.split(separator: "_", omittingEmptySubsequences: true)
        guard let first = parts.first else { return key }
        let leading = key.prefix(while: { $0 == "_" }), trailing = String(key.reversed().prefix(while: { $0 == "_" }))
        return leading + first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined() + trailing
    }
}

final class _JSONDecoderImpl: Decoder {
    let options: JSONDecoder
    let value: _JSON
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { options.userInfo }
    init(options: JSONDecoder, value: _JSON, codingPath: [CodingKey]) { self.options = options; self.value = value; self.codingPath = codingPath }

    func mismatch(_ t: Any.Type, _ v: _JSON) -> DecodingError {
        let desc: String
        switch v {
        case .null: return DecodingError.valueNotFound(t, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(t) value but found null instead."))
        case .bool: desc = "bool"
        case .int, .uint, .double: desc = "number"
        case .string: desc = "a string"
        case .array: desc = "an array"
        case .object: desc = "a dictionary"
        }
        return DecodingError.typeMismatch(t, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected to decode \(t) but found \(desc) instead."))
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let pairs) = value else { throw mismatch([String: Any].self, value) }
        var dict = [String: _JSON](minimumCapacity: pairs.count)
        for (k, v) in pairs {
            let key: String
            switch options.keyDecodingStrategy {
            case .useDefaultKeys: key = k
            case .convertFromSnakeCase: key = JSONDecoder.camelCase(k)
            case .custom(let f): key = f(codingPath + [_JSONKey(stringValue: k)]).stringValue
            }
            dict[key] = v
        }
        return KeyedDecodingContainer(_KeyedDecoder<Key>(decoder: self, dict: dict, codingPath: codingPath))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let items) = value else { throw mismatch([Any].self, value) }
        return _UnkeyedDecoder(decoder: self, items: items, codingPath: codingPath)
    }
    func singleValueContainer() throws -> SingleValueDecodingContainer { _SingleDecoder(decoder: self) }

    // scalars
    func bool(_ v: _JSON) throws -> Bool { if case .bool(let b) = v { return b }; throw mismatch(Bool.self, v) }
    func string(_ v: _JSON) throws -> String { if case .string(let s) = v { return s }; throw mismatch(String.self, v) }
    func double(_ v: _JSON) throws -> Double {
        switch v {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .uint(let u): return Double(u)
        case .string(let s):
            if case .convertFromString(let pos, let neg, let nan) = options.nonConformingFloatDecodingStrategy {
                if s == pos { return .infinity }; if s == neg { return -.infinity }; if s == nan { return .nan }
            }
            throw mismatch(Double.self, v)
        default: throw mismatch(Double.self, v)
        }
    }
    func integer<T: FixedWidthInteger>(_ v: _JSON, _ t: T.Type) throws -> T {
        let r: T?
        switch v {
        case .int(let i): r = T(exactly: i)
        case .uint(let u): r = T(exactly: u)
        case .double(let d): r = T(exactly: d)
        default: throw mismatch(T.self, v)
        }
        guard let x = r else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Parsed JSON number <\(v)> does not fit in \(T.self)."))
        }
        return x
    }

    func unbox<T: Decodable>(_ t: T.Type) throws -> T {
        if t == Date.self {
            switch options.dateDecodingStrategy {
            case .deferredToDate: break
            case .secondsSince1970: return Date(timeIntervalSince1970: try double(value)) as! T
            case .millisecondsSince1970: return Date(timeIntervalSince1970: try double(value) / 1000) as! T
            case .iso8601:
                let s = try string(value)
                guard let d = _ISO8601.date(s) else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Expected date string to be ISO8601-formatted.")) }
                return d as! T
            case .formatted(let f):
                let s = try string(value)
                guard let d = f.date(from: s) else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Date string does not match format expected by formatter.")) }
                return d as! T
            case .custom(let f): return try f(self) as! T
            }
        }
        if t == Data.self {
            switch options.dataDecodingStrategy {
            case .deferredToData: break
            case .base64:
                guard let d = Data(base64Encoded: try string(value)) else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Encountered Data is not valid Base64.")) }
                return d as! T
            case .custom(let f): return try f(self) as! T
            }
        }
        if t == URL.self {
            guard let u = URL(string: try string(value)) else { throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid URL string.")) }
            return u as! T
        }
        if t == Decimal.self {
            switch value {
            case .int(let i): return Decimal(Int(i)) as! T
            case .double(let d): return Decimal(d) as! T
            case .string(let s): if let d = Decimal(string: s) { return d as! T }
            default: break
            }
        }
        return try T(from: self)
    }
    func decode<T: Decodable>(_ t: T.Type, _ v: _JSON, key: CodingKey) throws -> T {
        try _JSONDecoderImpl(options: options, value: v, codingPath: codingPath + [key]).unbox(t)
    }
}

struct _KeyedDecoder<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: _JSONDecoderImpl
    let dict: [String: _JSON]
    var codingPath: [CodingKey]
    var allKeys: [Key] { dict.keys.compactMap { Key(stringValue: $0) } }
    func contains(_ k: Key) -> Bool { dict[k.stringValue] != nil }
    func get(_ k: Key) throws -> _JSON {
        guard let v = dict[k.stringValue] else {
            throw DecodingError.keyNotFound(k, DecodingError.Context(codingPath: codingPath, debugDescription: "No value associated with key \(k) (\"\(k.stringValue)\")."))
        }
        return v
    }
    func sub(_ k: Key) throws -> _JSONDecoderImpl { _JSONDecoderImpl(options: decoder.options, value: try get(k), codingPath: codingPath + [k]) }
    func decodeNil(forKey k: Key) throws -> Bool { if case .null = try get(k) { return true }; return false }
    func decode(_ t: Bool.Type, forKey k: Key) throws -> Bool { try sub(k).bool(try get(k)) }
    func decode(_ t: String.Type, forKey k: Key) throws -> String { try sub(k).string(try get(k)) }
    func decode(_ t: Double.Type, forKey k: Key) throws -> Double { try sub(k).double(try get(k)) }
    func decode(_ t: Float.Type, forKey k: Key) throws -> Float { Float(try sub(k).double(try get(k))) }
    func decode(_ t: Int.Type, forKey k: Key) throws -> Int { try sub(k).integer(try get(k), t) }
    func decode(_ t: Int8.Type, forKey k: Key) throws -> Int8 { try sub(k).integer(try get(k), t) }
    func decode(_ t: Int16.Type, forKey k: Key) throws -> Int16 { try sub(k).integer(try get(k), t) }
    func decode(_ t: Int32.Type, forKey k: Key) throws -> Int32 { try sub(k).integer(try get(k), t) }
    func decode(_ t: Int64.Type, forKey k: Key) throws -> Int64 { try sub(k).integer(try get(k), t) }
    func decode(_ t: UInt.Type, forKey k: Key) throws -> UInt { try sub(k).integer(try get(k), t) }
    func decode(_ t: UInt8.Type, forKey k: Key) throws -> UInt8 { try sub(k).integer(try get(k), t) }
    func decode(_ t: UInt16.Type, forKey k: Key) throws -> UInt16 { try sub(k).integer(try get(k), t) }
    func decode(_ t: UInt32.Type, forKey k: Key) throws -> UInt32 { try sub(k).integer(try get(k), t) }
    func decode(_ t: UInt64.Type, forKey k: Key) throws -> UInt64 { try sub(k).integer(try get(k), t) }
    func decode<T: Decodable>(_ t: T.Type, forKey k: Key) throws -> T { try sub(k).unbox(t) }
    func nestedContainer<NestedKey: CodingKey>(keyedBy t: NestedKey.Type, forKey k: Key) throws -> KeyedDecodingContainer<NestedKey> { try sub(k).container(keyedBy: t) }
    func nestedUnkeyedContainer(forKey k: Key) throws -> UnkeyedDecodingContainer { try sub(k).unkeyedContainer() }
    func superDecoder() throws -> Decoder { _JSONDecoderImpl(options: decoder.options, value: dict["super"] ?? .null, codingPath: codingPath + [_JSONKey.super]) }
    func superDecoder(forKey k: Key) throws -> Decoder { _JSONDecoderImpl(options: decoder.options, value: dict[k.stringValue] ?? .null, codingPath: codingPath + [k]) }
}

struct _UnkeyedDecoder: UnkeyedDecodingContainer {
    let decoder: _JSONDecoderImpl
    let items: [_JSON]
    var codingPath: [CodingKey]
    var currentIndex = 0
    var count: Int? { items.count }
    var isAtEnd: Bool { currentIndex >= items.count }
    init(decoder: _JSONDecoderImpl, items: [_JSON], codingPath: [CodingKey]) { self.decoder = decoder; self.items = items; self.codingPath = codingPath }
    mutating func next<T>(_ t: T.Type) throws -> (_JSONDecoderImpl, _JSON) {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(t, DecodingError.Context(codingPath: codingPath + [_JSONKey(index: currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        let v = items[currentIndex]
        let d = _JSONDecoderImpl(options: decoder.options, value: v, codingPath: codingPath + [_JSONKey(index: currentIndex)])
        currentIndex += 1
        return (d, v)
    }
    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return false }
        if case .null = items[currentIndex] { currentIndex += 1; return true }
        return false
    }
    mutating func decode(_ t: Bool.Type) throws -> Bool { let (d, v) = try next(t); return try d.bool(v) }
    mutating func decode(_ t: String.Type) throws -> String { let (d, v) = try next(t); return try d.string(v) }
    mutating func decode(_ t: Double.Type) throws -> Double { let (d, v) = try next(t); return try d.double(v) }
    mutating func decode(_ t: Float.Type) throws -> Float { let (d, v) = try next(t); return Float(try d.double(v)) }
    mutating func decode(_ t: Int.Type) throws -> Int { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: Int8.Type) throws -> Int8 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: Int16.Type) throws -> Int16 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: Int32.Type) throws -> Int32 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: Int64.Type) throws -> Int64 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: UInt.Type) throws -> UInt { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: UInt8.Type) throws -> UInt8 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: UInt16.Type) throws -> UInt16 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: UInt32.Type) throws -> UInt32 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode(_ t: UInt64.Type) throws -> UInt64 { let (d, v) = try next(t); return try d.integer(v, t) }
    mutating func decode<T: Decodable>(_ t: T.Type) throws -> T { let (d, _) = try next(t); return try d.unbox(t) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy t: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let (d, _) = try next([String: Any].self); return try d.container(keyedBy: t)
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { let (d, _) = try next([Any].self); return try d.unkeyedContainer() }
    mutating func superDecoder() throws -> Decoder { let (d, _) = try next(Any.self); return d }
}

struct _SingleDecoder: SingleValueDecodingContainer {
    let decoder: _JSONDecoderImpl
    var codingPath: [CodingKey] { decoder.codingPath }
    func decodeNil() -> Bool { if case .null = decoder.value { return true }; return false }
    func decode(_ t: Bool.Type) throws -> Bool { try decoder.bool(decoder.value) }
    func decode(_ t: String.Type) throws -> String { try decoder.string(decoder.value) }
    func decode(_ t: Double.Type) throws -> Double { try decoder.double(decoder.value) }
    func decode(_ t: Float.Type) throws -> Float { Float(try decoder.double(decoder.value)) }
    func decode(_ t: Int.Type) throws -> Int { try decoder.integer(decoder.value, t) }
    func decode(_ t: Int8.Type) throws -> Int8 { try decoder.integer(decoder.value, t) }
    func decode(_ t: Int16.Type) throws -> Int16 { try decoder.integer(decoder.value, t) }
    func decode(_ t: Int32.Type) throws -> Int32 { try decoder.integer(decoder.value, t) }
    func decode(_ t: Int64.Type) throws -> Int64 { try decoder.integer(decoder.value, t) }
    func decode(_ t: UInt.Type) throws -> UInt { try decoder.integer(decoder.value, t) }
    func decode(_ t: UInt8.Type) throws -> UInt8 { try decoder.integer(decoder.value, t) }
    func decode(_ t: UInt16.Type) throws -> UInt16 { try decoder.integer(decoder.value, t) }
    func decode(_ t: UInt32.Type) throws -> UInt32 { try decoder.integer(decoder.value, t) }
    func decode(_ t: UInt64.Type) throws -> UInt64 { try decoder.integer(decoder.value, t) }
    func decode<T: Decodable>(_ t: T.Type) throws -> T { try decoder.unbox(t) }
}

// MARK: - ISO 8601 (UTC, "yyyy-MM-dd'T'HH:mm:ssZ")

enum _ISO8601 {
    static func string(_ d: Date) -> String {
        let secs = Int64(floor(d.timeIntervalSince1970))
        let (y, m, day) = _civil(fromDays: Int(floorDiv(secs, 86400)))
        let rem = Int(secs - floorDiv(secs, 86400) * 86400)
        func p2(_ x: Int) -> String { x < 10 ? "0\(x)" : "\(x)" }
        return "\(y)-\(p2(m))-\(p2(day))T\(p2(rem / 3600)):\(p2(rem / 60 % 60)):\(p2(rem % 60))Z"
    }
    static func date(_ s: String) -> Date? {
        let u = Array(s.utf8)
        func num(_ a: Int, _ n: Int) -> Int? { guard a + n <= u.count else { return nil }; return Int(String(decoding: u[a..<a + n], as: UTF8.self)) }
        guard u.count >= 19, let y = num(0, 4), let mo = num(5, 2), let d = num(8, 2), let h = num(11, 2), let mi = num(14, 2), let se = num(17, 2) else { return nil }
        var i = 19
        var frac = 0.0
        if i < u.count, u[i] == UInt8(ascii: ".") {
            var j = i + 1
            while j < u.count, u[j] >= 0x30, u[j] <= 0x39 { j += 1 }
            frac = Double("0" + String(decoding: u[i..<j], as: UTF8.self)) ?? 0
            i = j
        }
        var offset = 0
        if i < u.count, u[i] == UInt8(ascii: "+") || u[i] == UInt8(ascii: "-") {
            let sign = u[i] == UInt8(ascii: "-") ? -1 : 1
            guard let oh = num(i + 1, 2) else { return nil }
            let om = num(i + 4, 2) ?? num(i + 3, 2) ?? 0
            offset = sign * (oh * 3600 + om * 60)
        }
        let days = _days(fromCivil: y, mo, d)
        let t = Double(days * 86400 + h * 3600 + mi * 60 + se - offset) + frac
        return Date(timeIntervalSince1970: t)
    }
    static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 { a >= 0 ? a / b : -((-a + b - 1) / b) }
}

// Proleptic Gregorian civil-date conversions (days since 1970-01-01).
func _days(fromCivil y0: Int, _ m: Int, _ d: Int) -> Int {
    let y = m <= 2 ? y0 - 1 : y0
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let mp = (m + 9) % 12
    let doy = (153 * mp + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
}
func _civil(fromDays z0: Int) -> (Int, Int, Int) {
    let z = z0 + 719468
    let era = (z >= 0 ? z : z - 146096) / 146097
    let doe = z - era * 146097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    let y = yoe + era * 400
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    return (m <= 2 ? y + 1 : y, m, d)
}
