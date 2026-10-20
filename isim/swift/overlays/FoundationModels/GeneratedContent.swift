// isim Foundation Models (self-authored, Apple's API names): GeneratedContent, the structured value a language model
// generates, with an order-keeping JSON reader that also accepts the unfinished JSON of a response in progress.
import Foundation

@available(iOS 26.0, macOS 26.0, *)
public struct GenerationID: Sendable, Hashable {
    let _id: UUID
    public init() { _id = UUID() }
}

/// Types made from generated content (a model's output, a tool's arguments).
@available(iOS 26.0, macOS 26.0, *)
public protocol ConvertibleFromGeneratedContent: Sendable {
    init(_ content: GeneratedContent) throws
}
/// Types that are generated content, and so can go into prompts and instructions.
@available(iOS 26.0, macOS 26.0, *)
public protocol ConvertibleToGeneratedContent: InstructionsRepresentable, PromptRepresentable {
    var generatedContent: GeneratedContent { get }
}
@available(iOS 26.0, macOS 26.0, *)
extension ConvertibleToGeneratedContent {
    public var instructionsRepresentation: Instructions { Instructions(generatedContent.jsonString) }
    public var promptRepresentation: Prompt { Prompt(generatedContent.jsonString) }
}

@available(iOS 26.0, macOS 26.0, *)
public struct GeneratedContent: Sendable, Equatable, Generable, CustomDebugStringConvertible {
    public enum Kind: Equatable, Sendable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([GeneratedContent])
        case structure(properties: [String: GeneratedContent], orderedKeys: [String])
    }
    public var kind: Kind
    public var id: GenerationID?
    /// false while a response is still being generated (the JSON so far was closed off to read it)
    public var isComplete: Bool

    public init(kind: Kind, id: GenerationID? = nil) { self.kind = kind; self.id = id; isComplete = true }
    public init(properties: KeyValuePairs<String, any ConvertibleToGeneratedContent>, id: GenerationID? = nil) {
        var props: [String: GeneratedContent] = [:], keys: [String] = []
        for (k, v) in properties { if props[k] == nil { keys.append(k) }; props[k] = v.generatedContent }
        self.init(kind: .structure(properties: props, orderedKeys: keys), id: id)
    }
    public init<S: Sequence>(elements: S, id: GenerationID? = nil) where S.Element == any ConvertibleToGeneratedContent {
        self.init(kind: .array(elements.map(\.generatedContent)), id: id)
    }
    public init(_ value: some ConvertibleToGeneratedContent) { self = value.generatedContent }
    public init(_ value: some ConvertibleToGeneratedContent, id: GenerationID) { self = value.generatedContent; self.id = id }
    /// parses JSON (keeping the order of object keys); unfinished JSON is closed off and `isComplete` is false
    public init(json: String) throws {
        var p = _JSONReader(Array(json.utf8))
        p.skipSpace()
        guard !p.atEnd else { throw LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "empty JSON")) }
        let v = try p.value()
        p.skipSpace()
        guard p.atEnd || p.truncated else { throw LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "trailing characters after the JSON value")) }
        self = v
        if p.truncated { self.isComplete = false }
    }

    public static func == (a: GeneratedContent, b: GeneratedContent) -> Bool { a.kind == b.kind }

    public var jsonString: String {
        switch kind {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let d):
            if d.isFinite, d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
            return d.isFinite ? "\(d)" : "null"
        case .string(let s): return _jsonQuote(s)
        case .array(let a): return "[" + a.map(\.jsonString).joined(separator: ", ") + "]"
        case .structure(let props, let keys):
            return "{" + keys.compactMap { k in props[k].map { "\(_jsonQuote(k)): \($0.jsonString)" } }.joined(separator: ", ") + "}"
        }
    }
    public var debugDescription: String { jsonString }

    /// the content as `Value`
    public func value<Value: ConvertibleFromGeneratedContent>(_ type: Value.Type = Value.self) throws -> Value { try Value(self) }
    /// a property of structured content as `Value` (a missing property is nil for optional `Value`s)
    public func value<Value: ConvertibleFromGeneratedContent>(_ type: Value.Type = Value.self, forProperty property: String) throws -> Value {
        guard case .structure(let props, _) = kind else {
            throw LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "\(jsonString) is not an object with a \"\(property)\" property"))
        }
        guard let v = props[property] else {
            if let none = (Value.self as? _GeneratedOptional.Type)?._none as? Value { return none }
            throw LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "the generated object has no \"\(property)\" property"))
        }
        return try Value(v)
    }
    public func value<Value: ConvertibleFromGeneratedContent>(_ type: Value?.Type = Value?.self, forProperty property: String) throws -> Value? {
        guard case .structure(let props, _) = kind else {
            throw LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "\(jsonString) is not an object with a \"\(property)\" property"))
        }
        guard let v = props[property], v.kind != .null else { return nil }
        return try Value(v)
    }

    // Generable
    public init(_ content: GeneratedContent) throws { self = content }
    public var generatedContent: GeneratedContent { self }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .any, description: nil) }
}

func _jsonQuote(_ s: String) -> String {
    var out = "\""
    for u in s.unicodeScalars {
        switch u {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
        }
    }
    return out + "\""
}

/// A JSON reader keeping object key order; at the end of unfinished input it closes what is open and sets `truncated`.
@available(iOS 26.0, macOS 26.0, *)
struct _JSONReader {
    let b: [UInt8]
    var i = 0
    var truncated = false
    init(_ b: [UInt8]) { self.b = b }
    var atEnd: Bool { i >= b.count }
    mutating func skipSpace() { while i < b.count, [0x20, 0x0A, 0x0D, 0x09].contains(b[i]) { i += 1 } }
    func fail(_ m: String) -> Error { LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "invalid JSON at \(i): \(m)")) }
    mutating func value() throws -> GeneratedContent {
        skipSpace()
        guard i < b.count else { truncated = true; return GeneratedContent(kind: .null) }
        switch b[i] {
        case UInt8(ascii: "{"):
            i += 1
            var props: [String: GeneratedContent] = [:], keys: [String] = []
            while true {
                skipSpace()
                if i >= b.count { truncated = true; break }
                if b[i] == UInt8(ascii: "}") { i += 1; break }
                if b[i] == UInt8(ascii: ",") { i += 1; continue }
                guard b[i] == UInt8(ascii: "\"") else { throw fail("expected a key") }
                let k = try string()
                skipSpace()
                if i >= b.count { truncated = true; break }
                guard b[i] == UInt8(ascii: ":") else { throw fail("expected ':'") }
                i += 1
                skipSpace()
                if i >= b.count { truncated = true; break }
                let v = try value()
                if props[k] == nil { keys.append(k) }
                props[k] = v
                if truncated { break }
            }
            return GeneratedContent(kind: .structure(properties: props, orderedKeys: keys))
        case UInt8(ascii: "["):
            i += 1
            var items: [GeneratedContent] = []
            while true {
                skipSpace()
                if i >= b.count { truncated = true; break }
                if b[i] == UInt8(ascii: "]") { i += 1; break }
                if b[i] == UInt8(ascii: ",") { i += 1; continue }
                items.append(try value())
                if truncated { break }
            }
            return GeneratedContent(kind: .array(items))
        case UInt8(ascii: "\""):
            return GeneratedContent(kind: .string(try string()))
        case UInt8(ascii: "t"): return try literal("true", .bool(true))
        case UInt8(ascii: "f"): return try literal("false", .bool(false))
        case UInt8(ascii: "n"): return try literal("null", .null)
        default:
            let s = i
            while i < b.count, "+-0123456789.eE".utf8.contains(b[i]) { i += 1 }
            guard i > s, let d = Double(String(decoding: b[s..<i], as: UTF8.self)) else {
                if i >= b.count && i > s { truncated = true; return GeneratedContent(kind: .number(Double(String(decoding: b[s..<i], as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "+-.eE"))) ?? 0)) }
                throw fail("unexpected character")
            }
            if i >= b.count { truncated = true }
            return GeneratedContent(kind: .number(d))
        }
    }
    mutating func literal(_ word: String, _ k: GeneratedContent.Kind) throws -> GeneratedContent {
        let w = Array(word.utf8)
        for c in w {
            if i >= b.count { truncated = true; return GeneratedContent(kind: k) }
            guard b[i] == c else { throw fail("expected \(word)") }
            i += 1
        }
        return GeneratedContent(kind: k)
    }
    mutating func string() throws -> String {
        i += 1
        var out: [UInt8] = []
        while i < b.count {
            let c = b[i]
            if c == UInt8(ascii: "\"") { i += 1; return String(decoding: out, as: UTF8.self) }
            if c == UInt8(ascii: "\\") {
                i += 1
                guard i < b.count else { break }
                switch b[i] {
                case UInt8(ascii: "n"): out.append(0x0A)
                case UInt8(ascii: "t"): out.append(0x09)
                case UInt8(ascii: "r"): out.append(0x0D)
                case UInt8(ascii: "b"): out.append(0x08)
                case UInt8(ascii: "f"): out.append(0x0C)
                case UInt8(ascii: "u"):
                    guard i + 4 < b.count, let v = UInt32(String(decoding: b[(i + 1)...(i + 4)], as: UTF8.self), radix: 16) else { i = b.count; break }
                    i += 4
                    var code = v
                    /* a surrogate pair */
                    if (0xD800..<0xDC00).contains(v), i + 6 < b.count, b[i + 1] == UInt8(ascii: "\\"), b[i + 2] == UInt8(ascii: "u"),
                       let lo = UInt32(String(decoding: b[(i + 3)...(i + 6)], as: UTF8.self), radix: 16), (0xDC00..<0xE000).contains(lo) {
                        code = 0x10000 + ((v - 0xD800) << 10) + (lo - 0xDC00); i += 6
                    }
                    out += Array(String(Unicode.Scalar(code).map(Character.init) ?? "\u{FFFD}").utf8)
                default: out.append(b[i])
                }
                i += 1
                continue
            }
            out.append(c); i += 1
        }
        truncated = true
        return String(decoding: out, as: UTF8.self)
    }
}

/// Optional's "no value", for a property a generated object leaves out
protocol _GeneratedOptional { static var _none: Any { get } }
@available(iOS 26.0, macOS 26.0, *)
extension Optional: _GeneratedOptional where Wrapped: ConvertibleFromGeneratedContent {
    static var _none: Any { Optional<Wrapped>.none as Any }
}
