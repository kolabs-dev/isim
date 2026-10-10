// isim Foundation: AttributedString (characters + attribute runs), AttributeContainer, attribute keys and
// scopes, Foundation's attributes (link, inline/presentation intents, ...), conversion to and from
// NSAttributedString. Markdown parsing lives in Markdown.swift.
// Codable (AttributedStringCodable.swift) and the iOS 17 attribute rules (run boundaries, inheritance by added
// text, invalidation conditions) follow Apple's behaviour. Simplified: scopes passed to NSAttributedString
// conversions are accepted but every registered key converts.

// MARK: - keys and scopes
public protocol AttributedStringKey {
  associatedtype Value: Hashable
  static var name: String { get }
  /// iOS 17: the value is constant within each paragraph (or between occurrences of a character)
  static var runBoundaries: AttributedString.AttributeRunBoundaries? { get }
  /// iOS 17: whether text added next to a run (typed into the character view) takes the attribute
  static var inheritedByAddedText: Bool { get }
  /// iOS 17: changes that remove the attribute from a run (its text or another attribute changing)
  static var invalidationConditions: Set<AttributedString.AttributeInvalidationCondition>? { get }
}
extension AttributedStringKey {
  public static var runBoundaries: AttributedString.AttributeRunBoundaries? { nil }
  public static var inheritedByAddedText: Bool { true }
  public static var invalidationConditions: Set<AttributedString.AttributeInvalidationCondition>? { nil }
}
extension AttributedString {
  public struct AttributeRunBoundaries: Hashable, Sendable {
    let _separator: Character?   // nil: paragraphs
    public static var paragraph: AttributeRunBoundaries { AttributeRunBoundaries(_separator: nil) }
    public static func character(_ character: Character) -> AttributeRunBoundaries { AttributeRunBoundaries(_separator: character) }
  }
  public struct AttributeInvalidationCondition: Hashable, Sendable {
    let _attribute: String?      // nil: the text changed
    public static let textChanged = AttributeInvalidationCondition(_attribute: nil)
    public static func attributeChanged<T: AttributedStringKey>(_ attribute: T.Type) -> AttributeInvalidationCondition {
      AttributeInvalidationCondition(_attribute: T.name)
    }
  }
}

/// Key types seen by name, for the iOS 17 rules (and Codable, which also finds keys through scopes).
final class _AttrKeyRegistry: @unchecked Sendable {
  let lock = NSLock()
  var types: [String: any AttributedStringKey.Type] = [:]
  var ruled: [String: any AttributedStringKey.Type] = [:]   // keys with a rule
  func register<K: AttributedStringKey>(_ k: K.Type) {
    lock.lock(); defer { lock.unlock() }
    guard types[K.name] == nil else { return }
    types[K.name] = k
    if K.runBoundaries != nil || !K.inheritedByAddedText || K.invalidationConditions != nil { ruled[K.name] = k }
  }
  var ruledTypes: [String: any AttributedStringKey.Type] { lock.lock(); defer { lock.unlock() }; return ruled }
}
let _attrKeys = _AttrKeyRegistry()
func _registerAttributeKey<K: AttributedStringKey>(_ k: K.Type) { _attrKeys.register(k) }
public protocol ObjectiveCConvertibleAttributedStringKey: AttributedStringKey {
  associatedtype ObjectiveCValue: NSObject
  static func objectiveCValue(for value: Value) throws -> ObjectiveCValue
  static func value(for object: ObjectiveCValue) throws -> Value
}
public protocol MarkdownDecodableAttributedStringKey: AttributedStringKey {
  static var markdownName: String { get }
  /// decodes the value of an extended attribute (`^[text](name: value)`)
  static func decodeMarkdown(from decoder: Decoder) throws -> Value
}
extension MarkdownDecodableAttributedStringKey {
  public static var markdownName: String { name }
  public static func decodeMarkdown(from decoder: Decoder) throws -> Value {
    guard let d = Value.self as? Decodable.Type, let v = try d.init(from: decoder) as? Value else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "\(Value.self) is not Decodable"))
    }
    return v
  }
}
public protocol AttributeScope {}
public enum AttributeScopes {}

extension AttributeScopes {
  public var foundation: FoundationAttributes.Type { FoundationAttributes.self }
  public struct FoundationAttributes: AttributeScope {
    public let link: LinkAttribute
    public let inlinePresentationIntent: InlinePresentationIntentAttribute
    public let presentationIntent: PresentationIntentAttribute
    public let alternateDescription: AlternateDescriptionAttribute
    public let imageURL: ImageURLAttribute
    public let languageIdentifier: LanguageIdentifierAttribute
    public let markdownSourcePosition: MarkdownSourcePositionAttribute

    /// where a run's text came from in the Markdown source (MarkdownParsingOptions.appliesSourcePositionAttributes)
    public enum MarkdownSourcePositionAttribute: AttributedStringKey {
      public typealias Value = AttributedString.MarkdownSourcePosition
      public static let name = "NSMarkdownSourcePosition"
    }

    public enum LinkAttribute: ObjectiveCConvertibleAttributedStringKey {
      public typealias Value = URL
      public typealias ObjectiveCValue = NSObject
      public static let name = "NSLink"
      public static func objectiveCValue(for value: URL) throws -> NSObject { value._bridgeToObjectiveC() }
      public static func value(for object: NSObject) throws -> URL {
        if let u = object as? NSURL { return URL._unconditionallyBridgeFromObjectiveC(u) }
        if let s = object as? NSString, let u = URL(string: s as String) { return u }
        throw NSError(domain: NSCocoaErrorDomain, code: 4866, userInfo: nil)
      }
    }
    public enum InlinePresentationIntentAttribute: ObjectiveCConvertibleAttributedStringKey {
      public typealias Value = InlinePresentationIntent
      public typealias ObjectiveCValue = NSNumber
      public static let name = "NSInlinePresentationIntent"
      public static func objectiveCValue(for value: InlinePresentationIntent) throws -> NSNumber { NSNumber(value: value.rawValue) }
      public static func value(for object: NSNumber) throws -> InlinePresentationIntent { InlinePresentationIntent(rawValue: object.uintValue) }
    }
    public enum PresentationIntentAttribute: AttributedStringKey {
      public typealias Value = PresentationIntent
      public static let name = "NSPresentationIntent"
    }
    public enum AlternateDescriptionAttribute: ObjectiveCConvertibleAttributedStringKey {
      public typealias Value = String
      public typealias ObjectiveCValue = NSString
      public static let name = "NSAlternateDescription"
      public static func objectiveCValue(for value: String) throws -> NSString { value as NSString }
      public static func value(for object: NSString) throws -> String { object as String }
    }
    public enum ImageURLAttribute: ObjectiveCConvertibleAttributedStringKey {
      public typealias Value = URL
      public typealias ObjectiveCValue = NSURL
      public static let name = "NSImageURL"
      public static func objectiveCValue(for value: URL) throws -> NSURL { value._bridgeToObjectiveC() }
      public static func value(for object: NSURL) throws -> URL { URL._unconditionallyBridgeFromObjectiveC(object) }
    }
    public enum LanguageIdentifierAttribute: ObjectiveCConvertibleAttributedStringKey {
      public typealias Value = String
      public typealias ObjectiveCValue = NSString
      public static let name = "NSLanguage"
      public static func objectiveCValue(for value: String) throws -> NSString { value as NSString }
      public static func value(for object: NSString) throws -> String { object as String }
    }
  }
}

/// Resolves `container.link`-style key paths to attribute keys (frameworks extend it with their scopes).
@dynamicMemberLookup
public enum AttributeDynamicLookup {
  public subscript<T: AttributedStringKey>(_: T.Type) -> T { fatalError("AttributeDynamicLookup is only used in key paths") }
  public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.FoundationAttributes, T>) -> T { self[T.self] }
}

// Value conversions to / from Objective-C for keys we know about (by name).
struct _AttrConverter {
  let toObjC: (AnyHashable) -> AnyObject?
  let fromObjC: (AnyObject) -> AnyHashable?
}
nonisolated(unsafe) var _attrConverters: [String: _AttrConverter] = {
  var d: [String: _AttrConverter] = [:]
  func reg<K: ObjectiveCConvertibleAttributedStringKey>(_ k: K.Type) {
    d[K.name] = _AttrConverter(
      toObjC: { v in (v.base as? K.Value).flatMap { try? K.objectiveCValue(for: $0) } },
      fromObjC: { o in (o as? K.ObjectiveCValue).flatMap { try? K.value(for: $0) }.map { AnyHashable($0) } })
  }
  reg(AttributeScopes.FoundationAttributes.LinkAttribute.self)
  reg(AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute.self)
  reg(AttributeScopes.FoundationAttributes.AlternateDescriptionAttribute.self)
  reg(AttributeScopes.FoundationAttributes.ImageURLAttribute.self)
  reg(AttributeScopes.FoundationAttributes.LanguageIdentifierAttribute.self)
  return d
}()
/// Registers an Objective-C conversion for a framework's attribute key (UIKit / SwiftUI scopes).
public func _isimRegisterAttributeKey<K: ObjectiveCConvertibleAttributedStringKey>(_ k: K.Type) {
  _attrConverters[K.name] = _AttrConverter(
    toObjC: { v in (v.base as? K.Value).flatMap { try? K.objectiveCValue(for: $0) } },
    fromObjC: { o in (o as? K.ObjectiveCValue).flatMap { try? K.value(for: $0) }.map { AnyHashable($0) } })
}

extension AttributedString {
  /// 1-based lines and columns (UTF-8 bytes) of the first and last character, both inclusive
  public struct MarkdownSourcePosition: Hashable, Codable, Sendable, CustomStringConvertible {
    public let startLine: Int, startColumn: Int, endLine: Int, endColumn: Int
    public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
      self.startLine = startLine; self.startColumn = startColumn; self.endLine = endLine; self.endColumn = endColumn
    }
    public var description: String { "\(startLine):\(startColumn)-\(endLine):\(endColumn)" }
  }
}

// MARK: - InlinePresentationIntent / PresentationIntent
extension InlinePresentationIntent: Hashable, @unchecked Sendable {}

public struct PresentationIntent: Hashable, CustomDebugStringConvertible, @unchecked Sendable {
  public struct TableColumn: Hashable, Sendable {
    public enum Alignment: Int, Hashable, Sendable { case left, center, right }
    public var alignment: Alignment
    public init(alignment: Alignment) { self.alignment = alignment }
  }
  public enum Kind: Hashable, CustomDebugStringConvertible, Sendable {
    case paragraph, header(level: Int), orderedList, unorderedList, listItem(ordinal: Int), codeBlock(languageHint: String?)
    case blockQuote, thematicBreak, table(columns: [TableColumn]), tableHeaderRow, tableRow(rowIndex: Int), tableCell(columnIndex: Int)
    public var debugDescription: String {
      switch self {
      case .paragraph: return "paragraph"
      case .header(let l): return "header \(l)"
      case .orderedList: return "orderedList"
      case .unorderedList: return "unorderedList"
      case .listItem(let o): return "listItem \(o)"
      case .codeBlock(let h): return "codeBlock '\(h ?? "")'"
      case .blockQuote: return "blockQuote"
      case .thematicBreak: return "thematicBreak"
      case .table(let c): return "table [\(c.map { "\($0.alignment)" }.joined(separator: ", "))]"
      case .tableHeaderRow: return "tableHeaderRow"
      case .tableRow(let r): return "tableRow \(r)"
      case .tableCell(let c): return "tableCell \(c)"
      }
    }
  }
  public struct IntentType: Hashable, CustomDebugStringConvertible, Sendable {
    public var kind: Kind
    public var identity: Int
    public init(kind: Kind, identity: Int) { self.kind = kind; self.identity = identity }
    public var debugDescription: String { "\(kind.debugDescription) (id \(identity))" }
  }
  /// Innermost block first.
  public var components: [IntentType]
  public init() { components = [] }
  public init(types: [IntentType]) { components = types }
  public init(_ kind: Kind, identity: Int, parent: PresentationIntent? = nil) {
    components = [IntentType(kind: kind, identity: identity)] + (parent?.components ?? [])
  }
  public var indentationLevel: Int { components.filter { if case .listItem = $0.kind { return true }; if case .blockQuote = $0.kind { return true }; return false }.count }
  public func isEquivalent(_ other: PresentationIntent) -> Bool { components.map(\.kind) == other.components.map(\.kind) }
  public var debugDescription: String { components.map(\.debugDescription).joined(separator: ", ") }
}

extension PresentationIntent: Codable {}
extension PresentationIntent.Kind: Codable {}
extension PresentationIntent.IntentType: Codable {}
extension PresentationIntent.TableColumn: Codable {}
extension PresentationIntent.TableColumn.Alignment: Codable {}

// MARK: - AttributeContainer
@dynamicMemberLookup
public struct AttributeContainer: Hashable, CustomStringConvertible, @unchecked Sendable {
  var _storage: [String: AnyHashable]
  public init() { _storage = [:] }
  init(_storage: [String: AnyHashable]) { self._storage = _storage }
  public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? {
    get { _storage[K.name]?.base as? K.Value }
    set { _registerAttributeKey(K.self); _storage[K.name] = newValue.map { AnyHashable($0) } }
  }
  public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? {
    get { self[K.self] }
    set { self[K.self] = newValue }
  }
  public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> Builder<K> { Builder(container: self) }
  public struct Builder<T: AttributedStringKey> {
    var container: AttributeContainer
    public func callAsFunction(_ value: T.Value) -> AttributeContainer { var c = container; c[T.self] = value; return c }
  }
  public mutating func merge(_ other: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy = .keepNew) {
    for (k, v) in other._storage where mergePolicy == .keepNew || _storage[k] == nil { _storage[k] = v }
  }
  public func merging(_ other: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy = .keepNew) -> AttributeContainer {
    var c = self; c.merge(other, mergePolicy: mergePolicy); return c
  }
  public var description: String {
    if _storage.isEmpty { return "{\n}" }
    return "{\n" + _storage.keys.sorted().map { "\t\($0) = \(_storage[$0]!.base)\n" }.joined() + "}"
  }
}

// MARK: - AttributedString
public protocol AttributedStringProtocol: CustomStringConvertible, Hashable {
  var startIndex: AttributedString.Index { get }
  var endIndex: AttributedString.Index { get }
  var runs: AttributedString.Runs { get }
  var characters: AttributedString.CharacterView { get }
  var unicodeScalars: AttributedString.UnicodeScalarView { get }
  subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == AttributedString.Index { get }
}

@dynamicMemberLookup
public struct AttributedString: AttributedStringProtocol, @unchecked Sendable {
  struct _Run: Hashable { var length: Int; var attrs: AttributeContainer }   // length in UTF-8 code units
  var _string: String
  var _runs: [_Run]

  public struct Index: Comparable, Hashable, Sendable {
    var _i: String.Index
    init(_ i: String.Index) { _i = i }
    public static func < (a: Index, b: Index) -> Bool { a._i < b._i }
  }
  public enum AttributeMergePolicy: Sendable { case keepNew, keepCurrent }

  // MARK: initializers
  public init() { _string = ""; _runs = [] }
  public init(_ string: String, attributes: AttributeContainer = .init()) {
    _string = string
    _runs = string.utf8.isEmpty ? [] : [_Run(length: string.utf8.count, attrs: attributes)]
  }
  public init(_ substring: Substring, attributes: AttributeContainer = .init()) { self.init(String(substring), attributes: attributes) }
  public init<S: Sequence>(_ elements: S, attributes: AttributeContainer = .init()) where S.Element == Character {
    self.init(String(elements), attributes: attributes)
  }
  public init(_ substring: AttributedSubstring) { self = substring._materialize() }
  public init<S: AttributedStringProtocol>(_ other: S) { self = other[other.startIndex..<other.endIndex]._materialize() }
  init(_string: String, _runs: [_Run]) { self._string = _string; self._runs = _runs; _coalesce() }

  // MARK: offsets
  func _off(_ i: Index) -> Int { _string.utf8.distance(from: _string.startIndex, to: i._i) }
  func _idx(_ off: Int) -> Index { Index(_string.utf8.index(_string.startIndex, offsetBy: off)) }
  public var startIndex: Index { Index(_string.startIndex) }
  public var endIndex: Index { Index(_string.endIndex) }

  /// (UTF-8 range, attributes) for each run intersecting `r`, clipped to it.
  func _pieces(_ r: Range<Int>) -> [(Range<Int>, AttributeContainer)] {
    var out: [(Range<Int>, AttributeContainer)] = [], pos = 0
    for run in _runs {
      let lo = max(pos, r.lowerBound), hi = min(pos + run.length, r.upperBound)
      if lo < hi { out.append((lo..<hi, run.attrs)) }
      pos += run.length
      if pos >= r.upperBound { break }
    }
    return out
  }
  mutating func _coalesce() {
    var out: [_Run] = []
    for r in _runs where r.length > 0 {
      if let last = out.last, last.attrs == r.attrs { out[out.count - 1].length += r.length } else { out.append(r) }
    }
    _runs = out
  }
  /// Replace the runs covering UTF-8 range `r` with `runs` (which must cover the new text there).
  mutating func _spliceRuns(_ r: Range<Int>, _ runs: [_Run]) {
    var before: [_Run] = [], after: [_Run] = [], pos = 0
    for run in _runs {
      let end = pos + run.length
      if pos < r.lowerBound { before.append(_Run(length: min(end, r.lowerBound) - pos, attrs: run.attrs)) }
      if end > r.upperBound { after.append(_Run(length: end - max(pos, r.upperBound), attrs: run.attrs)) }
      pos = end
    }
    _runs = before + runs + after
    _coalesce()
  }
  mutating func _editAttributes(_ r: Range<Int>, _ edit: (inout AttributeContainer) -> Void) {
    let ruled = _attrKeys.ruledTypes
    let runs = _pieces(r).map { piece -> _Run in
      var a = piece.1; edit(&a)
      if !ruled.isEmpty { AttributedString._invalidateDependents(old: piece.1, new: &a, ruled) }
      return _Run(length: piece.0.count, attrs: a)
    }
    _spliceRuns(r, runs)
    if !ruled.isEmpty { _enforceBoundaries(ruled) }
  }
  /// `.attributeChanged(X)`: keys that depend on an attribute whose value changed lose their value there.
  static func _invalidateDependents(old: AttributeContainer, new: inout AttributeContainer, _ ruled: [String: any AttributedStringKey.Type]) {
    let changed = Set(old._storage.keys).union(new._storage.keys).filter { old._storage[$0] != new._storage[$0] }
    guard !changed.isEmpty else { return }
    for (name, t) in ruled where new._storage[name] != nil && !changed.contains(name) {
      if let conds = t.invalidationConditions, conds.contains(where: { $0._attribute.map(changed.contains) ?? false }) { new._storage[name] = nil }
    }
  }
  /// UTF-8 ranges of the segments a run-boundary key is constant over (paragraphs, or text between separators)
  func _segments(_ b: AttributeRunBoundaries) -> [Range<Int>] {
    var out: [Range<Int>] = [], start = 0, pos = 0
    for ch in _string {
      pos += ch.utf8.count
      let ends = b._separator.map { ch == $0 } ?? (ch == "\n" || ch == "\r\n" || ch == "\r" || ch == "\u{2029}" || ch == "\u{85}")
      if ends { out.append(start..<pos); start = pos }
    }
    if start < pos { out.append(start..<pos) }
    return out
  }
  /// Run-boundary keys take one value per segment: the value at the segment's start.
  mutating func _enforceBoundaries(_ ruled: [String: any AttributedStringKey.Type]) {
    let bounded = ruled.compactMap { k, t in t.runBoundaries.map { (k, $0) } }
    guard !bounded.isEmpty else { return }
    let present = Set(_runs.flatMap { $0.attrs._storage.keys })
    for (name, b) in bounded where present.contains(name) {
      for seg in _segments(b) {
        let ps = _pieces(seg)
        let v = ps.first?.1._storage[name]
        if ps.allSatisfy({ $0.1._storage[name] == v }) { continue }
        _spliceRuns(seg, ps.map { p -> _Run in var a = p.1; a._storage[name] = v; return _Run(length: p.0.count, attrs: a) })
      }
    }
  }
  /// A range widened to the segments of the run-boundary keys among `names`.
  func _expandedForBoundaries(_ r: Range<Int>, names: some Sequence<String>) -> Range<Int> {
    let ruled = _attrKeys.ruledTypes
    var out = r
    for name in names {
      guard let b = ruled[name]?.runBoundaries else { continue }
      for seg in _segments(b) where seg.overlaps(out) || (out.isEmpty && seg.contains(out.lowerBound)) {
        out = min(out.lowerBound, seg.lowerBound)..<max(out.upperBound, seg.upperBound)
      }
    }
    return out
  }
  /// Replace the text in UTF-8 range `r` with `other`. `invalidating`: existing text changes (or added text joins a
  /// run), so `.textChanged` keys of the runs it touches lose their value.
  mutating func _replace(_ r: Range<Int>, with other: AttributedString, invalidating: Bool = false) {
    let ruled = _attrKeys.ruledTypes
    var spans: [(String, Range<Int>)] = []
    if invalidating && !ruled.isEmpty {
      let probe = r.isEmpty ? max(0, r.lowerBound - 1)..<r.lowerBound : r
      for (name, t) in ruled where t.invalidationConditions?.contains(.textChanged) == true {
        // the runs (maximal spans of one value) that touch the edit
        var pos = 0, spanStart = 0, spanValue: AnyHashable? = nil
        for run in _runs {
          let v = run.attrs._storage[name]
          if v != spanValue {
            if spanValue != nil, (spanStart..<pos).overlaps(probe) { spans.append((name, spanStart..<pos)) }
            spanStart = pos; spanValue = v
          }
          pos += run.length
        }
        if spanValue != nil, (spanStart..<pos).overlaps(probe) { spans.append((name, spanStart..<pos)) }
      }
    }
    let lo = _string.utf8.index(_string.startIndex, offsetBy: r.lowerBound), hi = _string.utf8.index(_string.startIndex, offsetBy: r.upperBound)
    _spliceRuns(r, other._runs)   // run arithmetic first: offsets refer to the old text
    _string.replaceSubrange(lo..<hi, with: other._string)
    if ruled.isEmpty { return }
    let delta = other._string.utf8.count - r.count
    for (name, span) in spans {
      let newSpan = span.lowerBound..<min(_string.utf8.count, span.upperBound + delta)
      if newSpan.isEmpty { continue }
      _spliceRuns(newSpan, _pieces(newSpan).map { p -> _Run in var a = p.1; a._storage[name] = nil; return _Run(length: p.0.count, attrs: a) })
    }
    _enforceBoundaries(ruled)
  }
  /// Attributes new text typed at `off` inherits (the character before it, else the one after), without the keys
  /// that are not inherited by added text.
  func _attrsForInsertion(at off: Int) -> AttributeContainer {
    let probe = off > 0 ? off - 1 : off
    var a = _pieces(probe..<(probe + 1)).first?.1 ?? AttributeContainer()
    for (name, t) in _attrKeys.ruledTypes where !t.inheritedByAddedText { a._storage[name] = nil }
    return a
  }

  // MARK: whole-string attributes
  public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? {
    get { _uniform(K.self, 0..<_string.utf8.count) }
    set { _registerAttributeKey(K.self); let k = K.name; _editAttributes(0..<_string.utf8.count) { $0._storage[k] = newValue.map { AnyHashable($0) } } }
  }
  public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? {
    get { self[K.self] }
    set { self[K.self] = newValue }
  }
  func _uniform<K: AttributedStringKey>(_ k: K.Type, _ r: Range<Int>) -> K.Value? {
    let vals = _pieces(r).map { $0.1[K.self] }
    guard let first = vals.first, vals.allSatisfy({ $0 == first }) else { return nil }
    return first
  }

  // MARK: substrings
  public subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == Index {
    get { AttributedSubstring(_base: self, _range: bounds.relative(to: characters)) }
    // `s[r].attribute = v` edits the whole string (attributes with run boundaries can reach past `r`)
    _modify {
      var sub = AttributedSubstring(_base: self, _range: bounds.relative(to: characters))
      defer { self = sub._base }
      yield &sub
    }
    set {
      let r = bounds.relative(to: characters)
      let new = newValue._materialize()
      let changed = String(_string[r.lowerBound._i..<r.upperBound._i]) != new._string
      _replace(_off(r.lowerBound)..<_off(r.upperBound), with: new, invalidating: !r.isEmpty && changed)
    }
  }

  // MARK: mutation
  public mutating func append<S: AttributedStringProtocol>(_ s: S) { let n = _string.utf8.count; _replace(n..<n, with: AttributedString(s)) }
  public mutating func insert<S: AttributedStringProtocol>(_ s: S, at index: Index) { let o = _off(index); _replace(o..<o, with: AttributedString(s)) }
  public mutating func replaceSubrange<R: RangeExpression, S: AttributedStringProtocol>(_ range: R, with s: S) where R.Bound == Index {
    let r = range.relative(to: characters)
    _replace(_off(r.lowerBound)..<_off(r.upperBound), with: AttributedString(s), invalidating: !r.isEmpty)
  }
  public mutating func removeSubrange<R: RangeExpression>(_ range: R) where R.Bound == Index {
    let r = range.relative(to: characters)
    _replace(_off(r.lowerBound)..<_off(r.upperBound), with: AttributedString(), invalidating: !r.isEmpty)
  }
  public static func + (a: AttributedString, b: AttributedString) -> AttributedString { var r = a; r.append(b); return r }
  public static func += (a: inout AttributedString, b: AttributedString) { a.append(b) }
  public static func == (a: AttributedString, b: AttributedString) -> Bool { a._string == b._string && a._runs == b._runs }
  public func hash(into h: inout Hasher) { h.combine(_string); h.combine(_runs) }

  public mutating func setAttributes(_ attributes: AttributeContainer) { _editAttributes(0..<_string.utf8.count) { $0 = attributes } }
  public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy: AttributeMergePolicy = .keepNew) {
    _editAttributes(0..<_string.utf8.count) { $0.merge(attributes, mergePolicy: mergePolicy) }
  }
  public mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) {
    _editAttributes(0..<_string.utf8.count) { a in
      if attributes._storage.allSatisfy({ a._storage[$0.key] == $0.value }) {
        for k in attributes._storage.keys { a._storage[k] = nil }
        a.merge(others)
      }
    }
  }
  public func settingAttributes(_ attributes: AttributeContainer) -> AttributedString { var s = self; s.setAttributes(attributes); return s }
  public func mergingAttributes(_ attributes: AttributeContainer, mergePolicy: AttributeMergePolicy = .keepNew) -> AttributedString {
    var s = self; s.mergeAttributes(attributes, mergePolicy: mergePolicy); return s
  }
  public func replacingAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) -> AttributedString {
    var s = self; s.replaceAttributes(attributes, with: others); return s
  }

  // MARK: description
  public var description: String { _describe(0..<_string.utf8.count) }
  func _describe(_ r: Range<Int>) -> String {
    let u = Array(_string.utf8)
    return _pieces(r).map { piece in
      String(decoding: u[piece.0], as: UTF8.self) + " " + piece.1.description
    }.joined(separator: "\n")
  }

  // MARK: index helpers
  public func index(_ i: Index, offsetByCharacters n: Int) -> Index { Index(_string.index(i._i, offsetBy: n)) }
  public func index(_ i: Index, offsetByUnicodeScalars n: Int) -> Index { Index(_string.unicodeScalars.index(i._i, offsetBy: n)) }
  public func index(afterCharacter i: Index) -> Index { Index(_string.index(after: i._i)) }
  public func index(beforeCharacter i: Index) -> Index { Index(_string.index(before: i._i)) }
}

// MARK: - AttributedSubstring
@dynamicMemberLookup
public struct AttributedSubstring: AttributedStringProtocol, @unchecked Sendable {
  public var base: AttributedString { _base }
  var _base: AttributedString
  var _range: Range<AttributedString.Index>
  init(_base: AttributedString, _range: Range<AttributedString.Index>) { self._base = _base; self._range = _range }
  public init() { _base = AttributedString(); _range = _base.startIndex..<_base.endIndex }
  var _offs: Range<Int> { _base._off(_range.lowerBound)..<_base._off(_range.upperBound) }
  func _materialize() -> AttributedString {
    let r = _offs
    return AttributedString(_string: String(_base._string[_range.lowerBound._i..<_range.upperBound._i]),
                            _runs: _base._pieces(r).map { AttributedString._Run(length: $0.0.count, attrs: $0.1) })
  }
  public var startIndex: AttributedString.Index { _range.lowerBound }
  public var endIndex: AttributedString.Index { _range.upperBound }
  public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? {
    get { _base._uniform(K.self, _offs) }
    set {
      _registerAttributeKey(K.self)
      let k = K.name
      _base._editAttributes(_base._expandedForBoundaries(_offs, names: [k])) { $0._storage[k] = newValue.map { AnyHashable($0) } }
    }
  }
  public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? {
    get { self[K.self] }
    set { self[K.self] = newValue }
  }
  public subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == AttributedString.Index {
    AttributedSubstring(_base: _base, _range: bounds.relative(to: characters))
  }
  public mutating func setAttributes(_ attributes: AttributeContainer) {
    _base._editAttributes(_base._expandedForBoundaries(_offs, names: attributes._storage.keys)) { $0 = attributes }
  }
  public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy = .keepNew) {
    _base._editAttributes(_base._expandedForBoundaries(_offs, names: attributes._storage.keys)) { $0.merge(attributes, mergePolicy: mergePolicy) }
  }
  public mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) {
    _base._editAttributes(_offs) { a in
      if attributes._storage.allSatisfy({ a._storage[$0.key] == $0.value }) {
        for k in attributes._storage.keys { a._storage[k] = nil }
        a.merge(others)
      }
    }
  }
  public var description: String { _base._describe(_offs) }
  public static func == (a: AttributedSubstring, b: AttributedSubstring) -> Bool { a._materialize() == b._materialize() }
  public func hash(into h: inout Hasher) { h.combine(_materialize()) }
}

// MARK: - shared protocol API
extension AttributedStringProtocol {
  var _whole: AttributedSubstring {
    if let s = self as? AttributedSubstring { return s }
    if let a = self as? AttributedString { return AttributedSubstring(_base: a, _range: a.startIndex..<a.endIndex) }
    return self[startIndex..<endIndex]
  }
  public var runs: AttributedString.Runs { AttributedString.Runs(_whole) }
  public var characters: AttributedString.CharacterView { AttributedString.CharacterView(_whole) }
  public var unicodeScalars: AttributedString.UnicodeScalarView { AttributedString.UnicodeScalarView(_whole) }
  public func range<T: StringProtocol>(of stringToFind: T, options: String.CompareOptions = [], locale: Locale? = nil) -> Range<AttributedString.Index>? {
    let sub = _whole
    let s = sub._base._string
    guard let r = s.range(of: String(stringToFind), options: options, range: sub._range.lowerBound._i..<sub._range.upperBound._i, locale: locale) else { return nil }
    return AttributedString.Index(r.lowerBound)..<AttributedString.Index(r.upperBound)
  }
  public func settingAttributes(_ attributes: AttributeContainer) -> AttributedString { var s = AttributedString(self); s.setAttributes(attributes); return s }
  public func mergingAttributes(_ attributes: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy = .keepNew) -> AttributedString {
    var s = AttributedString(self); s.mergeAttributes(attributes, mergePolicy: mergePolicy); return s
  }
}

// MARK: - views
extension AttributedString {
  public struct CharacterView: BidirectionalCollection, RangeReplaceableCollection, @unchecked Sendable {
    public typealias Element = Character
    public typealias Index = AttributedString.Index
    var _sub: AttributedSubstring
    init(_ s: AttributedSubstring) { _sub = s }
    public init() { _sub = AttributedSubstring() }
    var _s: String { _sub._base._string }
    public var startIndex: Index { _sub._range.lowerBound }
    public var endIndex: Index { _sub._range.upperBound }
    public func index(after i: Index) -> Index { Index(_s.index(after: i._i)) }
    public func index(before i: Index) -> Index { Index(_s.index(before: i._i)) }
    public func index(_ i: Index, offsetBy n: Int) -> Index { Index(_s.index(i._i, offsetBy: n)) }
    public func distance(from a: Index, to b: Index) -> Int { _s.distance(from: a._i, to: b._i) }
    public subscript(i: Index) -> Character { _s[i._i] }
    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C) where C.Element == Character {
      var base = _sub._base
      let lo = base._off(subrange.lowerBound), hi = base._off(subrange.upperBound)
      let start = base._off(_sub._range.lowerBound), end = base._off(_sub._range.upperBound)
      let text = String(newElements)
      base._replace(lo..<hi, with: AttributedString(text, attributes: base._attrsForInsertion(at: lo == hi ? lo : lo + 1)), invalidating: true)
      let newEnd = end + text.utf8.count - (hi - lo)
      _sub = AttributedSubstring(_base: base, _range: base._idx(start)..<base._idx(newEnd))
    }
  }
  public var characters: CharacterView {
    get { CharacterView(AttributedSubstring(_base: self, _range: startIndex..<endIndex)) }
    set { self = newValue._sub._base }
  }

  public struct UnicodeScalarView: BidirectionalCollection, @unchecked Sendable {
    public typealias Element = Unicode.Scalar
    public typealias Index = AttributedString.Index
    var _sub: AttributedSubstring
    init(_ s: AttributedSubstring) { _sub = s }
    var _u: String.UnicodeScalarView { _sub._base._string.unicodeScalars }
    public var startIndex: Index { _sub._range.lowerBound }
    public var endIndex: Index { _sub._range.upperBound }
    public func index(after i: Index) -> Index { Index(_u.index(after: i._i)) }
    public func index(before i: Index) -> Index { Index(_u.index(before: i._i)) }
    public subscript(i: Index) -> Unicode.Scalar { _u[i._i] }
  }

  // MARK: runs
  public struct Runs: BidirectionalCollection, Equatable, CustomStringConvertible, @unchecked Sendable {
    public struct Index: Comparable, Hashable, Strideable, Sendable {
      var _n: Int
      public static func < (a: Index, b: Index) -> Bool { a._n < b._n }
      public func distance(to other: Index) -> Int { other._n - _n }
      public func advanced(by n: Int) -> Index { Index(_n: _n + n) }
    }
    @dynamicMemberLookup
    public struct Run: Equatable, CustomStringConvertible, @unchecked Sendable {
      public let range: Range<AttributedString.Index>
      public let attributes: AttributeContainer
      public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? { attributes[K.self] }
      public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? { attributes[K.self] }
      public var description: String { attributes.description }
    }
    let _sub: AttributedSubstring
    let _list: [Run]
    init(_ s: AttributedSubstring) {
      _sub = s
      let b = s._base
      _list = b._pieces(s._offs).map { Run(range: b._idx($0.0.lowerBound)..<b._idx($0.0.upperBound), attributes: $0.1) }
    }
    public var startIndex: Index { Index(_n: 0) }
    public var endIndex: Index { Index(_n: _list.count) }
    public func index(after i: Index) -> Index { Index(_n: i._n + 1) }
    public func index(before i: Index) -> Index { Index(_n: i._n - 1) }
    public subscript(i: Index) -> Run { _list[i._n] }
    public subscript(position: AttributedString.Index) -> Run { _list.first { $0.range.contains(position) } ?? _list[_list.count - 1] }
    public static func == (a: Runs, b: Runs) -> Bool { a._list == b._list }
    public var description: String { _sub.description }

    public subscript<T: AttributedStringKey>(_ keyPath: KeyPath<AttributeDynamicLookup, T>) -> AttributesSlice1<T> { AttributesSlice1(_list) }
    public subscript<T: AttributedStringKey>(_ t: T.Type) -> AttributesSlice1<T> { AttributesSlice1(_list) }
    public subscript<T: AttributedStringKey, U: AttributedStringKey>(_ t: KeyPath<AttributeDynamicLookup, T>, _ u: KeyPath<AttributeDynamicLookup, U>) -> AttributesSlice2<T, U> { AttributesSlice2(_list) }

    /// Runs of equal values for one attribute: (value, range).
    public struct AttributesSlice1<T: AttributedStringKey>: BidirectionalCollection, @unchecked Sendable {
      public typealias Element = (T.Value?, Range<AttributedString.Index>)
      let _items: [Element]
      init(_ runs: [Run]) {
        var items: [Element] = []
        for r in runs {
          let v = r.attributes[T.self]
          if let last = items.last, last.0 == v { items[items.count - 1].1 = last.1.lowerBound..<r.range.upperBound } else { items.append((v, r.range)) }
        }
        _items = items
      }
      public var startIndex: Int { 0 }
      public var endIndex: Int { _items.count }
      public func index(after i: Int) -> Int { i + 1 }
      public func index(before i: Int) -> Int { i - 1 }
      public subscript(i: Int) -> Element { _items[i] }
    }
    public struct AttributesSlice2<T: AttributedStringKey, U: AttributedStringKey>: BidirectionalCollection, @unchecked Sendable {
      public typealias Element = (T.Value?, U.Value?, Range<AttributedString.Index>)
      let _items: [Element]
      init(_ runs: [Run]) {
        var items: [Element] = []
        for r in runs {
          let v = r.attributes[T.self], w = r.attributes[U.self]
          if let last = items.last, last.0 == v, last.1 == w { items[items.count - 1].2 = last.2.lowerBound..<r.range.upperBound } else { items.append((v, w, r.range)) }
        }
        _items = items
      }
      public var startIndex: Int { 0 }
      public var endIndex: Int { _items.count }
      public func index(after i: Int) -> Int { i + 1 }
      public func index(before i: Int) -> Int { i - 1 }
      public subscript(i: Int) -> Element { _items[i] }
    }
  }
}

// MARK: - NSAttributedString conversion
extension AttributedString {
  public init(_ nsStr: NSAttributedString) {
    let s = nsStr.string
    var runs: [_Run] = []
    nsStr.enumerateAttributes(in: NSRange(location: 0, length: nsStr.length), options: []) { attrs, range, _ in
      var c = AttributeContainer()
      for (k, v) in attrs {
        let name = k.rawValue
        let obj = v as AnyObject
        if let conv = _attrConverters[name], let sv = conv.fromObjC(obj) { c._storage[name] = sv }
        else if let h = v as? AnyHashable { c._storage[name] = h }
      }
      let lo = String.Index(utf16Offset: range.location, in: s), hi = String.Index(utf16Offset: range.location + range.length, in: s)
      runs.append(_Run(length: s.utf8.distance(from: lo, to: hi), attrs: c))
    }
    self.init(_string: s, _runs: runs)
  }
  public init<S: AttributeScope>(_ nsStr: NSAttributedString, including scope: KeyPath<AttributeScopes, S.Type>) throws { self.init(nsStr) }
  public init<S: AttributeScope>(_ nsStr: NSAttributedString, including scope: S.Type) throws { self.init(nsStr) }
}
extension NSAttributedString {
  static func _isimAttributes(_ c: AttributeContainer) -> [NSAttributedString.Key: Any] {
    var d: [NSAttributedString.Key: Any] = [:]
    for (k, v) in c._storage {
      if let conv = _attrConverters[k], let o = conv.toObjC(v) { d[NSAttributedString.Key(rawValue: k)] = o }
      else if let o = v.base as? NSObject { d[NSAttributedString.Key(rawValue: k)] = o }
      else { d[NSAttributedString.Key(rawValue: k)] = v.base as AnyObject }
    }
    return d
  }
  public convenience init(_ attrStr: AttributedString) {
    let m = NSMutableAttributedString(string: attrStr._string)
    let s = attrStr._string
    var pos = 0
    for run in attrStr._runs {
      let lo = s.utf8.index(s.startIndex, offsetBy: pos), hi = s.utf8.index(lo, offsetBy: run.length)
      let r = NSRange(location: lo.utf16Offset(in: s), length: s.utf16.distance(from: lo, to: hi))
      m.setAttributes(NSAttributedString._isimAttributes(run.attrs), range: r)
      pos += run.length
    }
    self.init(attributedString: m)
  }
  public convenience init<S: AttributeScope>(_ attrStr: AttributedString, including scope: KeyPath<AttributeScopes, S.Type>) throws { self.init(attrStr) }
}
extension AttributeContainer {
  public init(_ dictionary: [NSAttributedString.Key: Any]) {
    self.init()
    for (k, v) in dictionary {
      if let conv = _attrConverters[k.rawValue], let sv = conv.fromObjC(v as AnyObject) { _storage[k.rawValue] = sv }
      else if let h = v as? AnyHashable { _storage[k.rawValue] = h }
    }
  }
}
extension Dictionary where Key == NSAttributedString.Key, Value == Any {
  public init(_ container: AttributeContainer) { self = NSAttributedString._isimAttributes(container) }
}

// MARK: - localized
extension AttributedString {
  /// Looks the key up like String(localized:) and interprets inline Markdown in the result.
  public init(localized key: String.LocalizationValue, table: String? = nil, bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) {
    let s = String(localized: key, table: table, bundle: bundle, locale: locale, comment: comment)
    self = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
  }
}
