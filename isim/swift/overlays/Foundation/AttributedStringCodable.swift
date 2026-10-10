// isim Foundation: Codable for AttributedString and AttributeContainer, attribute scopes as coding configurations,
// and the *WithConfiguration coding protocols (Apple: AttributedString+Codable, CodableWithConfiguration.swift).
// Self-authored. An attributed string encodes as its text when it has no attributes, else as alternating text
// and attribute containers (keyed by attribute name); keys outside the scope, or not Codable, are left out, as on
// iOS. The decoder also reads Apple's attribute-table form ({"runs": [...], "attributeTable": [...]}).
@_spi(Reflection) import Swift

// MARK: - codable attribute keys
public protocol EncodableAttributedStringKey: AttributedStringKey {
  static func encode(_ value: Value, to encoder: Encoder) throws
}
public protocol DecodableAttributedStringKey: AttributedStringKey {
  static func decode(from decoder: Decoder) throws -> Value
}
public typealias CodableAttributedStringKey = EncodableAttributedStringKey & DecodableAttributedStringKey
extension EncodableAttributedStringKey where Value: Encodable {
  public static func encode(_ value: Value, to encoder: Encoder) throws { try value.encode(to: encoder) }
}
extension DecodableAttributedStringKey where Value: Decodable {
  public static func decode(from decoder: Decoder) throws -> Value { try Value(from: decoder) }
}

extension AttributeScopes.FoundationAttributes.LinkAttribute: CodableAttributedStringKey {}
extension AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute: CodableAttributedStringKey {}
extension AttributeScopes.FoundationAttributes.PresentationIntentAttribute: CodableAttributedStringKey {}
extension AttributeScopes.FoundationAttributes.AlternateDescriptionAttribute: CodableAttributedStringKey {}
extension AttributeScopes.FoundationAttributes.ImageURLAttribute: CodableAttributedStringKey {}
extension AttributeScopes.FoundationAttributes.LanguageIdentifierAttribute: CodableAttributedStringKey {}
extension AttributeScopes.FoundationAttributes.MarkdownSourcePositionAttribute: CodableAttributedStringKey {}
extension InlinePresentationIntent: Codable {}

// MARK: - coding with a configuration
public protocol EncodableWithConfiguration {
  associatedtype EncodingConfiguration
  func encode(to encoder: Encoder, configuration: EncodingConfiguration) throws
}
public protocol DecodableWithConfiguration {
  associatedtype DecodingConfiguration
  init(from decoder: Decoder, configuration: DecodingConfiguration) throws
}
public typealias CodableWithConfiguration = EncodableWithConfiguration & DecodableWithConfiguration
public protocol EncodingConfigurationProviding {
  associatedtype EncodingConfiguration
  static var encodingConfiguration: EncodingConfiguration { get }
}
public protocol DecodingConfigurationProviding {
  associatedtype DecodingConfiguration
  static var decodingConfiguration: DecodingConfiguration { get }
}
/// Codes its value with the configuration of a provider: a type that provides one (EncodingConfigurationProviding /
/// DecodingConfigurationProviding), or an attribute scope (\.myApp). Adapted: Apple constrains the provider to the
/// providing protocols, which its AttributeScope refines; isim's AttributeScope does not (adding them would break
/// the scopes of apps already built), so the provider is resolved here.
@propertyWrapper
public struct CodableConfiguration<T, ConfigurationProvider>: Codable where T: CodableWithConfiguration {
  public var wrappedValue: T
  public init(wrappedValue: T) { self.wrappedValue = wrappedValue }
  public init(wrappedValue: T, from configurationProvider: ConfigurationProvider.Type) { self.wrappedValue = wrappedValue }
  public init(wrappedValue: T, from keyPath: KeyPath<AttributeScopes, ConfigurationProvider.Type>) { self.wrappedValue = wrappedValue }
  public init(from decoder: Decoder) throws { wrappedValue = try T(from: decoder, configuration: Self._decoding()) }
  public func encode(to encoder: Encoder) throws { try wrappedValue.encode(to: encoder, configuration: Self._encoding()) }
  static func _encoding() -> T.EncodingConfiguration {
    if let p = ConfigurationProvider.self as? any EncodingConfigurationProviding.Type, let c = _providedEncoding(p) as? T.EncodingConfiguration { return c }
    if ConfigurationProvider.self is any AttributeScope.Type, let c = AttributeScopeCodableConfiguration(ConfigurationProvider.self) as? T.EncodingConfiguration { return c }
    fatalError("CodableConfiguration: \(ConfigurationProvider.self) provides no \(T.EncodingConfiguration.self)")
  }
  static func _decoding() -> T.DecodingConfiguration {
    if let p = ConfigurationProvider.self as? any DecodingConfigurationProviding.Type, let c = _providedDecoding(p) as? T.DecodingConfiguration { return c }
    if ConfigurationProvider.self is any AttributeScope.Type, let c = AttributeScopeCodableConfiguration(ConfigurationProvider.self) as? T.DecodingConfiguration { return c }
    fatalError("CodableConfiguration: \(ConfigurationProvider.self) provides no \(T.DecodingConfiguration.self)")
  }
}
private func _providedEncoding<P: EncodingConfigurationProviding>(_ p: P.Type) -> Any { P.encodingConfiguration }
private func _providedDecoding<P: DecodingConfigurationProviding>(_ p: P.Type) -> Any { P.decodingConfiguration }
extension CodableConfiguration: Equatable where T: Equatable {}
extension CodableConfiguration: Hashable where T: Hashable {}
extension CodableConfiguration: Sendable where T: Sendable {}
extension KeyedEncodingContainer {
  public mutating func encode<T: EncodableWithConfiguration>(_ t: T, forKey key: Key, configuration: T.EncodingConfiguration) throws {
    try t.encode(to: superEncoder(forKey: key), configuration: configuration)
  }
  public mutating func encodeIfPresent<T: EncodableWithConfiguration>(_ t: T?, forKey key: Key, configuration: T.EncodingConfiguration) throws {
    if let t { try encode(t, forKey: key, configuration: configuration) }
  }
  public mutating func encode<T: EncodableWithConfiguration, C: EncodingConfigurationProviding>(_ t: T, forKey key: Key, configuration: C.Type) throws where T.EncodingConfiguration == C.EncodingConfiguration {
    try encode(t, forKey: key, configuration: C.encodingConfiguration)
  }
}
extension KeyedDecodingContainer {
  public func decode<T: DecodableWithConfiguration>(_ type: T.Type, forKey key: Key, configuration: T.DecodingConfiguration) throws -> T {
    try T(from: superDecoder(forKey: key), configuration: configuration)
  }
  public func decodeIfPresent<T: DecodableWithConfiguration>(_ type: T.Type, forKey key: Key, configuration: T.DecodingConfiguration) throws -> T? {
    guard contains(key), try !decodeNil(forKey: key) else { return nil }
    return try decode(type, forKey: key, configuration: configuration)
  }
  public func decode<T: DecodableWithConfiguration, C: DecodingConfigurationProviding>(_ type: T.Type, forKey key: Key, configuration: C.Type) throws -> T where T.DecodingConfiguration == C.DecodingConfiguration {
    try decode(type, forKey: key, configuration: C.decodingConfiguration)
  }
}
extension UnkeyedEncodingContainer {
  public mutating func encode<T: EncodableWithConfiguration>(_ t: T, configuration: T.EncodingConfiguration) throws {
    try t.encode(to: superEncoder(), configuration: configuration)
  }
}
extension UnkeyedDecodingContainer {
  public mutating func decode<T: DecodableWithConfiguration>(_ type: T.Type, configuration: T.DecodingConfiguration) throws -> T {
    try T(from: superDecoder(), configuration: configuration)
  }
}
extension SingleValueEncodingContainer {
  public mutating func encode<T: EncodableWithConfiguration>(_ t: T, configuration: T.EncodingConfiguration) throws {
    try encode(_ConfiguredEncodable(value: t, configuration: configuration))
  }
}
struct _ConfiguredEncodable<T: EncodableWithConfiguration>: Encodable {
  let value: T, configuration: T.EncodingConfiguration
  func encode(to encoder: Encoder) throws { try value.encode(to: encoder, configuration: configuration) }
}

// MARK: - scopes as configurations
/// The attribute keys of a scope (and of the scopes it nests), found by reflecting over its fields.
public struct AttributeScopeCodableConfiguration: Sendable {
  let _keys: [String: _AnyKey]
  struct _AnyKey: @unchecked Sendable { let type: any AttributedStringKey.Type }
  init(_ scope: Any.Type) {
    var keys: [String: _AnyKey] = [:]
    func collect(_ t: Any.Type, depth: Int) {
      _forEachField(of: t, options: [.ignoreUnknown]) { _, _, field, _ in
        if let k = field as? any AttributedStringKey.Type { if keys[k.name] == nil { keys[k.name] = _AnyKey(type: k) } }
        else if depth < 8, field is any AttributeScope.Type { collect(field, depth: depth + 1) }
        return true
      }
    }
    collect(scope, depth: 0)
    _keys = keys
  }
}
extension AttributeScope {
  public static var encodingConfiguration: AttributeScopeCodableConfiguration { AttributeScopeCodableConfiguration(Self.self) }
  public static var decodingConfiguration: AttributeScopeCodableConfiguration { AttributeScopeCodableConfiguration(Self.self) }
}

struct _AttrCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }
  init(_ s: String) { stringValue = s }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { return nil }
}
private func _encodeValue<K: EncodableAttributedStringKey>(_ k: K.Type, _ v: AnyHashable, _ encoder: Encoder) throws {
  guard let value = v.base as? K.Value else { return }
  try K.encode(value, to: encoder)
}
private func _decodeValue<K: DecodableAttributedStringKey>(_ k: K.Type, _ decoder: Decoder) throws -> AnyHashable {
  _registerAttributeKey(K.self)
  return AnyHashable(try K.decode(from: decoder))
}

extension AttributeContainer: CodableWithConfiguration {
  public func encode(to encoder: Encoder, configuration: AttributeScopeCodableConfiguration) throws {
    var c = encoder.container(keyedBy: _AttrCodingKey.self)
    for name in _storage.keys.sorted() {
      guard let k = configuration._keys[name]?.type as? any EncodableAttributedStringKey.Type, let v = _storage[name] else { continue }
      try _encodeValue(k, v, c.superEncoder(forKey: _AttrCodingKey(name)))
    }
  }
  public init(from decoder: Decoder, configuration: AttributeScopeCodableConfiguration) throws {
    self.init()
    let c = try decoder.container(keyedBy: _AttrCodingKey.self)
    for key in c.allKeys {
      guard let k = configuration._keys[key.stringValue]?.type as? any DecodableAttributedStringKey.Type else { continue }
      _storage[key.stringValue] = try _decodeValue(k, c.superDecoder(forKey: key))
    }
  }
  public func encode<S: AttributeScope>(to encoder: Encoder, configuration: S.Type) throws { try encode(to: encoder, configuration: S.encodingConfiguration) }
  public init<S: AttributeScope>(from decoder: Decoder, configuration: S.Type) throws { try self.init(from: decoder, configuration: S.decodingConfiguration) }
}

extension AttributedString: Codable, CodableWithConfiguration {
  enum _TableKeys: String, CodingKey { case runs, attributeTable }
  public func encode(to encoder: Encoder) throws { try encode(to: encoder, configuration: AttributeScopes.FoundationAttributes.encodingConfiguration) }
  public init(from decoder: Decoder) throws { try self.init(from: decoder, configuration: AttributeScopes.FoundationAttributes.decodingConfiguration) }
  public func encode(to encoder: Encoder, configuration: AttributeScopeCodableConfiguration) throws {
    if _runs.isEmpty || (_runs.count == 1 && _runs[0].attrs._storage.isEmpty) {
      var c = encoder.singleValueContainer()
      try c.encode(_string)
      return
    }
    var c = encoder.unkeyedContainer()
    let u = Array(_string.utf8)
    var pos = 0
    for run in _runs {
      try c.encode(String(decoding: u[pos..<(pos + run.length)], as: UTF8.self))
      try run.attrs.encode(to: c.superEncoder(), configuration: configuration)
      pos += run.length
    }
  }
  public init(from decoder: Decoder, configuration: AttributeScopeCodableConfiguration) throws {
    if let single = try? decoder.singleValueContainer(), let s = try? single.decode(String.self) {
      self.init(s); return
    }
    var table: [AttributeContainer] = []
    var runs: UnkeyedDecodingContainer
    if let keyed = try? decoder.container(keyedBy: _TableKeys.self), keyed.contains(.runs) {
      if keyed.contains(.attributeTable) {
        var t = try keyed.nestedUnkeyedContainer(forKey: .attributeTable)
        while !t.isAtEnd { table.append(try t.decode(AttributeContainer.self, configuration: configuration)) }
      }
      runs = try keyed.nestedUnkeyedContainer(forKey: .runs)
    } else {
      runs = try decoder.unkeyedContainer()
    }
    var text = "", out: [_Run] = []
    while !runs.isAtEnd {
      let piece = try runs.decode(String.self)
      guard !runs.isAtEnd else {
        throw DecodingError.dataCorrupted(.init(codingPath: runs.codingPath, debugDescription: "Attributed string run has no attributes"))
      }
      let attrs: AttributeContainer
      if !table.isEmpty, let index = try? runs.decode(Int.self) {
        guard table.indices.contains(index) else { throw DecodingError.dataCorrupted(.init(codingPath: runs.codingPath, debugDescription: "Attribute table index out of range")) }
        attrs = table[index]
      } else {
        attrs = try runs.decode(AttributeContainer.self, configuration: configuration)
      }
      text += piece
      out.append(_Run(length: piece.utf8.count, attrs: attrs))
    }
    self.init(_string: text, _runs: out)
  }
  public func encode<S: AttributeScope>(to encoder: Encoder, configuration: S.Type) throws { try encode(to: encoder, configuration: S.encodingConfiguration) }
  public init<S: AttributeScope>(from decoder: Decoder, configuration: S.Type) throws { try self.init(from: decoder, configuration: S.decodingConfiguration) }
}
