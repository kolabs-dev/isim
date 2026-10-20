// isim Foundation Models: Generable, GenerationSchema (encoded as JSON Schema for a model backend), dynamic schemas
// and generation guides.
import Foundation

/// Types a language model can generate: their schema, made from and turned into generated content (`@Generable`).
@available(iOS 26.0, macOS 26.0, *)
public protocol Generable: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {
    /// what a response in progress holds (the type's properties all optional, as generated so far)
    associatedtype PartiallyGenerated: ConvertibleFromGeneratedContent = Self
    static var generationSchema: GenerationSchema { get }
}
@available(iOS 26.0, macOS 26.0, *)
extension Generable {
    public func asPartiallyGenerated() -> PartiallyGenerated {
        if let s = self as? PartiallyGenerated { return s }
        return try! PartiallyGenerated(generatedContent)
    }
}

/// the schema's tree
indirect enum _SchemaNode: Sendable {
    case any
    case object(name: String, properties: [_SchemaProperty])
    case string(choices: [String]?, constant: String?, hasPattern: Bool)
    case integer(minimum: Int?, maximum: Int?)
    case number(minimum: Double?, maximum: Double?)
    case boolean
    case array(element: _SchemaNode, minimumCount: Int?, maximumCount: Int?)
    case anyOf(name: String, [_SchemaNode])
    case optional(_SchemaNode)
    case named(String, _SchemaNode)               // a type's name around a node that has none (strings, arrays)

    var wrapped: _SchemaNode { if case .optional(let n) = self { return n }; return self }

    func json(_ description: String?) -> [String: Any] {
        var d: [String: Any]
        switch self {
        case .any: d = [:]
        case .object(let name, let props):
            var p: [String: Any] = [:]
            for q in props { p[q.name] = q.node.wrapped.json(q.description) }
            d = ["type": "object", "title": name, "properties": p, "required": props.filter { !$0.isOptional }.map(\.name),
                 "additionalProperties": false, "x-order": props.map(\.name)]
        case .string(let choices, let constant, _):
            d = ["type": "string"]
            if let choices { d["enum"] = choices }
            if let constant { d["const"] = constant }
        case .integer(let lo, let hi):
            d = ["type": "integer"]
            if let lo { d["minimum"] = lo }
            if let hi { d["maximum"] = hi }
        case .number(let lo, let hi):
            d = ["type": "number"]
            if let lo { d["minimum"] = lo }
            if let hi { d["maximum"] = hi }
        case .boolean: d = ["type": "boolean"]
        case .array(let e, let lo, let hi):
            d = ["type": "array", "items": e.json(nil)]
            if let lo { d["minItems"] = lo }
            if let hi { d["maxItems"] = hi }
        case .anyOf(let name, let nodes): d = ["title": name, "anyOf": nodes.map { $0.json(nil) }]
        case .optional(let n): d = ["anyOf": [n.json(nil), ["type": "null"]]]
        case .named(let name, let n): d = n.json(nil); d["title"] = name
        }
        if let description { d["description"] = description }
        return d
    }
}
struct _SchemaProperty: Sendable {
    let name: String, description: String?, node: _SchemaNode
    var isOptional: Bool { if case .optional = node { return true }; return false }
}

/// The shape of what a model generates: an object's properties, a choice of strings or types, with guides.
@available(iOS 26.0, macOS 26.0, *)
public struct GenerationSchema: Sendable, Codable, CustomDebugStringConvertible {
    let _node: _SchemaNode
    let _description: String?
    init(_node: _SchemaNode, description: String?) { self._node = _node; _description = description }

    public struct Property: Sendable {
        let _p: _SchemaProperty
        public init<Value: Generable>(name: String, description: String? = nil, type: Value.Type, guides: [GenerationGuide<Value>] = []) {
            _p = _SchemaProperty(name: name, description: description, node: guides.reduce(Value.generationSchema._node) { $1._apply($0) })
        }
        /// a String property that matches the regular expressions
        public init<RegexOutput>(name: String, description: String? = nil, type: String.Type, guides: [Regex<RegexOutput>] = []) {
            _p = _SchemaProperty(name: name, description: description, node: .string(choices: nil, constant: nil, hasPattern: !guides.isEmpty))
        }
    }
    public init(type: any Generable.Type, description: String? = nil, properties: [GenerationSchema.Property]) {
        self.init(_node: .object(name: String(describing: type), properties: properties.map(\._p)), description: description)
    }
    public init(type: any Generable.Type, description: String? = nil, anyOf choices: [String]) {
        self.init(_node: .named(String(describing: type), .string(choices: choices, constant: nil, hasPattern: false)), description: description)
    }
    public init(type: any Generable.Type, description: String? = nil, anyOf types: [any Generable.Type]) {
        self.init(_node: .anyOf(name: String(describing: type), types.map { $0.generationSchema._node }), description: description)
    }
    /// a schema built at run time, its references resolved from `dependencies`
    public init(root: DynamicGenerationSchema, dependencies: [DynamicGenerationSchema]) throws {
        var byName: [String: DynamicGenerationSchema] = [:]
        for d in [root] + dependencies {
            guard let n = d._name else { continue }
            if byName[n] != nil { throw SchemaError.duplicateType(schema: n, type: n, context: .init(debugDescription: "two schemas are named \(n)")) }
            byName[n] = d
        }
        var missing: [String] = []
        func resolve(_ d: DynamicGenerationSchema, _ seen: Set<String>) throws -> _SchemaNode {
            switch d._kind {
            case .reference(let name):
                guard let target = byName[name] else { missing.append(name); return .any }
                if seen.contains(name) { return .named(name, .any) }                  // a recursive reference: left open
                return try resolve(target, seen.union([name]))
            case .object(let name, let props):
                var names = Set<String>()
                for p in props where !names.insert(p.name).inserted {
                    throw SchemaError.duplicateProperty(schema: name, property: p.name, context: .init(debugDescription: "\(name) has two \(p.name) properties"))
                }
                return .object(name: name, properties: try props.map { p in
                    let node = try resolve(p.schema, seen)
                    return _SchemaProperty(name: p.name, description: p.description, node: p.isOptional ? .optional(node) : node)
                })
            case .strings(let name, let choices):
                if choices.isEmpty { throw SchemaError.emptyTypeChoices(schema: name, context: .init(debugDescription: "\(name) has no choices")) }
                return .named(name, .string(choices: choices, constant: nil, hasPattern: false))
            case .choices(let name, let schemas):
                if schemas.isEmpty { throw SchemaError.emptyTypeChoices(schema: name, context: .init(debugDescription: "\(name) has no choices")) }
                return .anyOf(name: name, try schemas.map { try resolve($0, seen) })
            case .array(let item, let lo, let hi): return .array(element: try resolve(item, seen), minimumCount: lo, maximumCount: hi)
            case .node(let n): return n
            }
        }
        let node = try resolve(root, Set(root._name.map { [$0] } ?? []))
        if !missing.isEmpty {
            throw SchemaError.undefinedReferences(schema: root._name, references: missing, context: .init(debugDescription: "undefined references: \(missing)"))
        }
        self.init(_node: node, description: root._description)
    }

    public enum SchemaError: Error, LocalizedError {
        public struct Context: Sendable {
            public let debugDescription: String
            public init(debugDescription: String) { self.debugDescription = debugDescription }
        }
        case duplicateType(schema: String?, type: String, context: Context)
        case duplicateProperty(schema: String, property: String, context: Context)
        case emptyTypeChoices(schema: String, context: Context)
        case undefinedReferences(schema: String?, references: [String], context: Context)
        public var errorDescription: String? {
            switch self {
            case .duplicateType(_, _, let c), .duplicateProperty(_, _, let c), .emptyTypeChoices(_, let c), .undefinedReferences(_, _, let c):
                return c.debugDescription
            }
        }
    }

    /// the schema as JSON Schema
    var _jsonObject: [String: Any] { _node.json(_description) }
    var _jsonString: String {
        (try? JSONSerialization.data(withJSONObject: _jsonObject, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
    public var debugDescription: String { _jsonString }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(_jsonString)
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let o = try JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any] else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "not a JSON Schema object")
        }
        self.init(_node: _SchemaNode.from(o), description: o["description"] as? String)
    }
}
extension _SchemaNode {
    static func from(_ o: [String: Any]) -> _SchemaNode {
        switch o["type"] as? String {
        case "object":
            let props = o["properties"] as? [String: Any] ?? [:], req = Set(o["required"] as? [String] ?? [])
            let order = o["x-order"] as? [String] ?? props.keys.sorted()
            return .object(name: o["title"] as? String ?? "Object", properties: order.compactMap { k in
                guard let p = props[k] as? [String: Any] else { return nil }
                let n = from(p)
                return _SchemaProperty(name: k, description: p["description"] as? String, node: req.contains(k) ? n : .optional(n))
            })
        case "string": return .string(choices: o["enum"] as? [String], constant: o["const"] as? String, hasPattern: o["pattern"] != nil)
        case "integer": return .integer(minimum: o["minimum"] as? Int, maximum: o["maximum"] as? Int)
        case "number": return .number(minimum: o["minimum"] as? Double, maximum: o["maximum"] as? Double)
        case "boolean": return .boolean
        case "array": return .array(element: from(o["items"] as? [String: Any] ?? [:]), minimumCount: o["minItems"] as? Int, maximumCount: o["maxItems"] as? Int)
        default:
            if let any = o["anyOf"] as? [[String: Any]] { return .anyOf(name: o["title"] as? String ?? "Choice", any.map(from)) }
            return .any
        }
    }
}

/// A schema made at run time (from data rather than a Swift type).
@available(iOS 26.0, macOS 26.0, *)
public struct DynamicGenerationSchema: Sendable {
    indirect enum Kind: Sendable {
        case object(String, [Property]), strings(String, [String]), choices(String, [DynamicGenerationSchema])
        case array(DynamicGenerationSchema, Int?, Int?), reference(String), node(_SchemaNode)
    }
    let _kind: Kind
    let _description: String?
    var _name: String? {
        switch _kind {
        case .object(let n, _), .strings(let n, _), .choices(let n, _): return n
        default: return nil
        }
    }
    public struct Property: Sendable {
        let name: String, description: String?, schema: DynamicGenerationSchema, isOptional: Bool
        public init(name: String, description: String? = nil, schema: DynamicGenerationSchema, isOptional: Bool = false) {
            self.name = name; self.description = description; self.schema = schema; self.isOptional = isOptional
        }
    }
    public init(name: String, description: String? = nil, properties: [DynamicGenerationSchema.Property]) {
        _kind = .object(name, properties); _description = description
    }
    public init(name: String, description: String? = nil, anyOf choices: [String]) { _kind = .strings(name, choices); _description = description }
    public init(name: String, description: String? = nil, anyOf choices: [DynamicGenerationSchema]) { _kind = .choices(name, choices); _description = description }
    public init(arrayOf itemSchema: DynamicGenerationSchema, minimumElements: Int? = nil, maximumElements: Int? = nil) {
        _kind = .array(itemSchema, minimumElements, maximumElements); _description = nil
    }
    public init<Value: Generable>(type: Value.Type, guides: [GenerationGuide<Value>] = []) {
        _kind = .node(guides.reduce(Value.generationSchema._node) { $1._apply($0) }); _description = nil
    }
    public init(referenceTo name: String) { _kind = .reference(name); _description = nil }
}

/// Constraints on a generated value (`@Guide(description:_:)`): ranges, counts, choices.
@available(iOS 26.0, macOS 26.0, *)
public struct GenerationGuide<Value>: Sendable {
    let _apply: @Sendable (_SchemaNode) -> _SchemaNode
    init(_ apply: @escaping @Sendable (_SchemaNode) -> _SchemaNode) { _apply = apply }
}
@available(iOS 26.0, macOS 26.0, *)
extension GenerationGuide where Value == String {
    public static func constant(_ value: String) -> GenerationGuide<String> { .init { _ in .string(choices: nil, constant: value, hasPattern: false) } }
    public static func anyOf(_ values: [String]) -> GenerationGuide<String> { .init { _ in .string(choices: values, constant: nil, hasPattern: false) } }
    /// adapted: recorded, but a Swift Regex has no pattern text to hand a model backend
    public static func pattern<Output>(_ regex: Regex<Output>) -> GenerationGuide<String> {
        .init { _ in .string(choices: nil, constant: nil, hasPattern: true) }
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension GenerationGuide where Value == Int {
    public static func minimum(_ value: Int) -> GenerationGuide<Int> { .init { n in if case .integer(_, let hi) = n { return .integer(minimum: value, maximum: hi) }; return n } }
    public static func maximum(_ value: Int) -> GenerationGuide<Int> { .init { n in if case .integer(let lo, _) = n { return .integer(minimum: lo, maximum: value) }; return n } }
    public static func range(_ range: ClosedRange<Int>) -> GenerationGuide<Int> { .init { _ in .integer(minimum: range.lowerBound, maximum: range.upperBound) } }
}
@available(iOS 26.0, macOS 26.0, *)
extension GenerationGuide where Value == Double {
    public static func minimum(_ value: Double) -> GenerationGuide<Double> { .init { n in if case .number(_, let hi) = n { return .number(minimum: value, maximum: hi) }; return n } }
    public static func maximum(_ value: Double) -> GenerationGuide<Double> { .init { n in if case .number(let lo, _) = n { return .number(minimum: lo, maximum: value) }; return n } }
    public static func range(_ range: ClosedRange<Double>) -> GenerationGuide<Double> { .init { _ in .number(minimum: range.lowerBound, maximum: range.upperBound) } }
}
@available(iOS 26.0, macOS 26.0, *)
extension GenerationGuide where Value == Float {
    public static func minimum(_ value: Float) -> GenerationGuide<Float> { .init { n in if case .number(_, let hi) = n { return .number(minimum: Double(value), maximum: hi) }; return n } }
    public static func maximum(_ value: Float) -> GenerationGuide<Float> { .init { n in if case .number(let lo, _) = n { return .number(minimum: lo, maximum: Double(value)) }; return n } }
    public static func range(_ range: ClosedRange<Float>) -> GenerationGuide<Float> { .init { _ in .number(minimum: Double(range.lowerBound), maximum: Double(range.upperBound)) } }
}
@available(iOS 26.0, macOS 26.0, *)
extension GenerationGuide where Value == Decimal {
    public static func minimum(_ value: Decimal) -> GenerationGuide<Decimal> {
        let v = NSDecimalNumber(decimal: value).doubleValue
        return .init { n in if case .number(_, let hi) = n { return .number(minimum: v, maximum: hi) }; return n }
    }
    public static func maximum(_ value: Decimal) -> GenerationGuide<Decimal> {
        let v = NSDecimalNumber(decimal: value).doubleValue
        return .init { n in if case .number(let lo, _) = n { return .number(minimum: lo, maximum: v) }; return n }
    }
    public static func range(_ range: ClosedRange<Decimal>) -> GenerationGuide<Decimal> {
        let lo = NSDecimalNumber(decimal: range.lowerBound).doubleValue, hi = NSDecimalNumber(decimal: range.upperBound).doubleValue
        return .init { _ in .number(minimum: lo, maximum: hi) }
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension GenerationGuide {
    public static func minimumCount<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
        .init { n in if case .array(let e, _, let hi) = n { return .array(element: e, minimumCount: count, maximumCount: hi) }; return n }
    }
    public static func maximumCount<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
        .init { n in if case .array(let e, let lo, _) = n { return .array(element: e, minimumCount: lo, maximumCount: count) }; return n }
    }
    public static func count<Element>(_ count: Int) -> GenerationGuide<[Element]> where Value == [Element] {
        .init { n in if case .array(let e, _, _) = n { return .array(element: e, minimumCount: count, maximumCount: count) }; return n }
    }
    public static func count<Element>(_ range: ClosedRange<Int>) -> GenerationGuide<[Element]> where Value == [Element] {
        .init { n in if case .array(let e, _, _) = n { return .array(element: e, minimumCount: range.lowerBound, maximumCount: range.upperBound) }; return n }
    }
    public static func element<Element>(_ guide: GenerationGuide<Element>) -> GenerationGuide<[Element]> where Value == [Element] {
        .init { n in if case .array(let e, let lo, let hi) = n { return .array(element: guide._apply(e), minimumCount: lo, maximumCount: hi) }; return n }
    }
}

// MARK: - the standard types

@available(iOS 26.0, macOS 26.0, *)
private func _decodeError(_ what: String, _ c: GeneratedContent) -> Error {
    LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "expected \(what), got \(c.jsonString)"))
}
@available(iOS 26.0, macOS 26.0, *)
extension String: Generable {
    public init(_ content: GeneratedContent) throws {
        switch content.kind {
        case .string(let s): self = s
        case .number, .bool: self = content.jsonString
        default: throw _decodeError("a string", content)
        }
    }
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .string(self)) }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .string(choices: nil, constant: nil, hasPattern: false), description: nil) }
    public var instructionsRepresentation: Instructions { Instructions(self) }
    public var promptRepresentation: Prompt { Prompt(self) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Bool: Generable {
    public init(_ content: GeneratedContent) throws {
        guard case .bool(let b) = content.kind else { throw _decodeError("a boolean", content) }
        self = b
    }
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .bool(self)) }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .boolean, description: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Int: Generable {
    public init(_ content: GeneratedContent) throws {
        guard case .number(let d) = content.kind, let i = Int(exactly: d.rounded()) else { throw _decodeError("an integer", content) }
        self = i
    }
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .number(Double(self))) }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .integer(minimum: nil, maximum: nil), description: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Double: Generable {
    public init(_ content: GeneratedContent) throws {
        guard case .number(let d) = content.kind else { throw _decodeError("a number", content) }
        self = d
    }
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .number(self)) }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .number(minimum: nil, maximum: nil), description: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Float: Generable {
    public init(_ content: GeneratedContent) throws {
        guard case .number(let d) = content.kind else { throw _decodeError("a number", content) }
        self = Float(d)
    }
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .number(Double(self))) }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .number(minimum: nil, maximum: nil), description: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Decimal: Generable {
    public init(_ content: GeneratedContent) throws {
        guard case .number = content.kind, let d = Decimal(string: content.jsonString) else { throw _decodeError("a number", content) }
        self = d
    }
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .number(NSDecimalNumber(decimal: self).doubleValue)) }
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .number(minimum: nil, maximum: nil), description: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Array: Generable where Element: Generable {
    public typealias PartiallyGenerated = [Element.PartiallyGenerated]
    public static var generationSchema: GenerationSchema {
        GenerationSchema(_node: .array(element: Element.generationSchema._node, minimumCount: nil, maximumCount: nil), description: nil)
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension Array: ConvertibleFromGeneratedContent where Element: ConvertibleFromGeneratedContent {
    public init(_ content: GeneratedContent) throws {
        guard case .array(let a) = content.kind else { throw _decodeError("an array", content) }
        self = try a.map { try Element($0) }
    }
}
@available(iOS 26.0, macOS 26.0, *)
extension Array: ConvertibleToGeneratedContent, InstructionsRepresentable, PromptRepresentable where Element: ConvertibleToGeneratedContent {
    public var generatedContent: GeneratedContent { GeneratedContent(kind: .array(map(\.generatedContent))) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Optional: Generable where Wrapped: Generable {
    public typealias PartiallyGenerated = Wrapped.PartiallyGenerated
    public static var generationSchema: GenerationSchema { GenerationSchema(_node: .optional(Wrapped.generationSchema._node), description: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Optional: ConvertibleFromGeneratedContent where Wrapped: ConvertibleFromGeneratedContent {
    public init(_ content: GeneratedContent) throws { self = content.kind == .null ? nil : try Wrapped(content) }
}
@available(iOS 26.0, macOS 26.0, *)
extension Optional: ConvertibleToGeneratedContent, InstructionsRepresentable, PromptRepresentable where Wrapped: ConvertibleToGeneratedContent {
    public var generatedContent: GeneratedContent { map(\.generatedContent) ?? GeneratedContent(kind: .null) }
}
