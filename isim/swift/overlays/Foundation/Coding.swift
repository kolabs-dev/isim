// isim Foundation: Data <-> NSData and UUID <-> NSUUID bridging, PropertyListEncoder / PropertyListDecoder,
// Swift refinements for NSKeyedArchiver / NSKeyedUnarchiver / NSCoder, UndoManager.registerUndo(withTarget:handler:).

// MARK: - bridging
extension Data: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSData { bytes.withUnsafeBytes { NSData(bytes: $0.baseAddress, length: $0.count) } }
    public static func _forceBridgeFromObjectiveC(_ x: NSData, result: inout Data?) {
        result = x.length == 0 ? Data() : Data(bytes: x.bytes, count: x.length)
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSData, result: inout Data?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSData?) -> Data {
        var r: Data?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? Data()
    }
    public init(referencing reference: NSData) { self = Data._unconditionallyBridgeFromObjectiveC(reference) }
}
extension UUID: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSUUID { NSUUID(uuidString: uuidString)! }
    public static func _forceBridgeFromObjectiveC(_ x: NSUUID, result: inout UUID?) { result = UUID(uuidString: x.uuidString) }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSUUID, result: inout UUID?) -> Bool { result = UUID(uuidString: x.uuidString); return result != nil }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSUUID?) -> UUID { s.flatMap { UUID(uuidString: $0.uuidString) } ?? UUID() }
}

// MARK: - property list coding
/// Codable values as property-list objects (dictionary, array, string, number, bool, date, data).
final class _PlistBox { var value: Any; init(_ v: Any) { value = v } }
struct _PlistKey: CodingKey {
    var stringValue: String; var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
    init(_ s: String) { stringValue = s }
    static let `super` = _PlistKey("super")
}
final class _PlistEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var storage: _PlistBox?
    init(codingPath: [CodingKey] = [], userInfo: [CodingUserInfoKey: Any]) { self.codingPath = codingPath; self.userInfo = userInfo }
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if storage == nil || !(storage!.value is NSMutableDictionary) { storage = _PlistBox(NSMutableDictionary()) }
        return KeyedEncodingContainer(_PlistKeyed<Key>(encoder: self, dict: storage!.value as! NSMutableDictionary, codingPath: codingPath))
    }
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if storage == nil || !(storage!.value is NSMutableArray) { storage = _PlistBox(NSMutableArray()) }
        return _PlistUnkeyed(encoder: self, array: storage!.value as! NSMutableArray, codingPath: codingPath)
    }
    func singleValueContainer() -> SingleValueEncodingContainer { _PlistSingle(encoder: self, codingPath: codingPath) }
    /// a value as a plist object
    func box<T: Encodable>(_ value: T, at path: [CodingKey]) throws -> Any {
        switch value {
        case let v as Date: return v as NSDate
        case let v as Data: return v as NSData
        case let v as String: return v as NSString
        case let v as Bool: return NSNumber(value: v)
        case let v as Int: return NSNumber(value: v)
        case let v as Int8: return NSNumber(value: v)
        case let v as Int16: return NSNumber(value: v)
        case let v as Int32: return NSNumber(value: v)
        case let v as Int64: return NSNumber(value: v)
        case let v as UInt: return NSNumber(value: v)
        case let v as UInt8: return NSNumber(value: v)
        case let v as UInt16: return NSNumber(value: v)
        case let v as UInt32: return NSNumber(value: v)
        case let v as UInt64: return NSNumber(value: v)
        case let v as Double: return NSNumber(value: v)
        case let v as Float: return NSNumber(value: v)
        case let v as URL: return v.absoluteString as NSString
        case let v as Decimal: return NSNumber(value: v.doubleValue)
        default:
            let sub = _PlistEncoder(codingPath: path, userInfo: userInfo)
            try value.encode(to: sub)
            return sub.storage?.value ?? NSMutableDictionary()
        }
    }
}
struct _PlistKeyed<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _PlistEncoder; let dict: NSMutableDictionary; var codingPath: [CodingKey]
    mutating func encodeNil(forKey key: Key) throws { dict.setObject("$null" as NSString, forKey: key.stringValue as NSString) }
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws { dict.setObject(try encoder.box(value, at: codingPath + [key]), forKey: key.stringValue as NSString) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let d = NSMutableDictionary(); dict.setObject(d, forKey: key.stringValue as NSString)
        return KeyedEncodingContainer(_PlistKeyed<NestedKey>(encoder: encoder, dict: d, codingPath: codingPath + [key]))
    }
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let a = NSMutableArray(); dict.setObject(a, forKey: key.stringValue as NSString)
        return _PlistUnkeyed(encoder: encoder, array: a, codingPath: codingPath + [key])
    }
    mutating func superEncoder() -> Encoder { _PlistReferencingEncoder(parent: encoder, dict: dict, key: "super", codingPath: codingPath) }
    mutating func superEncoder(forKey key: Key) -> Encoder { _PlistReferencingEncoder(parent: encoder, dict: dict, key: key.stringValue, codingPath: codingPath + [key]) }
}
struct _PlistUnkeyed: UnkeyedEncodingContainer {
    let encoder: _PlistEncoder; let array: NSMutableArray; var codingPath: [CodingKey]
    var count: Int { array.count }
    mutating func encodeNil() throws { array.add("$null" as NSString) }
    mutating func encode<T: Encodable>(_ value: T) throws { array.add(try encoder.box(value, at: codingPath + [_PlistKey(intValue: count)])) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let d = NSMutableDictionary(); array.add(d)
        return KeyedEncodingContainer(_PlistKeyed<NestedKey>(encoder: encoder, dict: d, codingPath: codingPath + [_PlistKey(intValue: count - 1)]))
    }
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let a = NSMutableArray(); array.add(a)
        return _PlistUnkeyed(encoder: encoder, array: a, codingPath: codingPath + [_PlistKey(intValue: count - 1)])
    }
    mutating func superEncoder() -> Encoder {
        let d = NSMutableDictionary(); array.add(d)
        let e = _PlistEncoder(codingPath: codingPath, userInfo: encoder.userInfo); e.storage = _PlistBox(d); return e
    }
}
struct _PlistSingle: SingleValueEncodingContainer {
    let encoder: _PlistEncoder; var codingPath: [CodingKey]
    mutating func encodeNil() throws { encoder.storage = _PlistBox("$null" as NSString) }
    mutating func encode<T: Encodable>(_ value: T) throws { encoder.storage = _PlistBox(try encoder.box(value, at: codingPath)) }
}
final class _PlistReferencingEncoder: Encoder {
    let parent: _PlistEncoder; let dict: NSMutableDictionary; let key: String
    var codingPath: [CodingKey]; var userInfo: [CodingUserInfoKey: Any] { parent.userInfo }
    let inner: _PlistEncoder
    init(parent: _PlistEncoder, dict: NSMutableDictionary, key: String, codingPath: [CodingKey]) {
        self.parent = parent; self.dict = dict; self.key = key; self.codingPath = codingPath
        inner = _PlistEncoder(codingPath: codingPath, userInfo: parent.userInfo)
    }
    deinit { if let v = inner.storage?.value { dict.setObject(v, forKey: key as NSString) } }
    func container<K: CodingKey>(keyedBy type: K.Type) -> KeyedEncodingContainer<K> { let c = inner.container(keyedBy: type); dict.setObject(inner.storage!.value, forKey: key as NSString); return c }
    func unkeyedContainer() -> UnkeyedEncodingContainer { let c = inner.unkeyedContainer(); dict.setObject(inner.storage!.value, forKey: key as NSString); return c }
    func singleValueContainer() -> SingleValueEncodingContainer { inner.singleValueContainer() }
}

open class PropertyListEncoder {
    open var outputFormat: PropertyListSerialization.PropertyListFormat = .binary
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    public init() {}
    open func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let tree = try encodeToTopLevelContainer(value)
        do { return try PropertyListSerialization.data(fromPropertyList: tree, format: outputFormat, options: 0) }
        catch { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value as a property list.", underlyingError: error)) }
    }
    func encodeToTopLevelContainer<Value: Encodable>(_ value: Value) throws -> Any {
        let e = _PlistEncoder(userInfo: userInfo)
        let v = try e.box(value, at: [])
        return v
    }
}

final class _PlistDecoder: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    let value: Any
    init(value: Any, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) { self.value = value; self.codingPath = codingPath; self.userInfo = userInfo }
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let d = value as? NSDictionary else { throw DecodingError.typeMismatch([String: Any].self, .init(codingPath: codingPath, debugDescription: "Expected to decode Dictionary<String, Any> but found \(Swift.type(of: value)) instead.")) }
        return KeyedDecodingContainer(_PlistKeyedDecoder<Key>(decoder: self, dict: d, codingPath: codingPath))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let a = value as? NSArray else { throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "Expected to decode Array<Any> but found \(Swift.type(of: value)) instead.")) }
        return _PlistUnkeyedDecoder(decoder: self, array: a, codingPath: codingPath)
    }
    func singleValueContainer() throws -> SingleValueDecodingContainer { _PlistSingleDecoder(decoder: self, codingPath: codingPath) }
    func unbox<T: Decodable>(_ v: Any, as type: T.Type, path: [CodingKey]) throws -> T {
        func mismatch() -> DecodingError { .typeMismatch(T.self, .init(codingPath: path, debugDescription: "Expected to decode \(T.self) but found \(Swift.type(of: v)) instead.")) }
        func number() throws -> NSNumber { guard let n = v as? NSNumber else { throw mismatch() }; return n }
        switch type {
        case is Date.Type: guard let d = v as? NSDate else { throw mismatch() }; return (d as Date) as! T
        case is Data.Type: guard let d = v as? NSData else { throw mismatch() }; return (d as Data) as! T
        case is String.Type: guard let s = v as? NSString else { throw mismatch() }; return (s as String) as! T
        case is Bool.Type: return try number().boolValue as! T
        case is Int.Type: return Int(truncatingIfNeeded: try number().int64Value) as! T
        case is Int8.Type: return Int8(truncatingIfNeeded: try number().int64Value) as! T
        case is Int16.Type: return Int16(truncatingIfNeeded: try number().int64Value) as! T
        case is Int32.Type: return Int32(truncatingIfNeeded: try number().int64Value) as! T
        case is Int64.Type: return try number().int64Value as! T
        case is UInt.Type: return try number().uintValue as! T
        case is UInt8.Type: return UInt8(truncatingIfNeeded: try number().uint64Value) as! T
        case is UInt16.Type: return UInt16(truncatingIfNeeded: try number().uint64Value) as! T
        case is UInt32.Type: return UInt32(truncatingIfNeeded: try number().uint64Value) as! T
        case is UInt64.Type: return try number().uint64Value as! T
        case is Double.Type: return try number().doubleValue as! T
        case is Float.Type: return try number().floatValue as! T
        case is URL.Type: guard let s = v as? NSString, let u = URL(string: s as String) else { throw mismatch() }; return u as! T
        default: return try T(from: _PlistDecoder(value: v, codingPath: path, userInfo: userInfo))
        }
    }
}
func _isPlistNull(_ v: Any?) -> Bool { (v as? NSString).map { $0 as String == "$null" } ?? (v == nil) }
struct _PlistKeyedDecoder<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: _PlistDecoder; let dict: NSDictionary; var codingPath: [CodingKey]
    var allKeys: [Key] { dict.allKeys.compactMap { ($0 as? NSString).flatMap { Key(stringValue: $0 as String) } } }
    func contains(_ key: Key) -> Bool { dict[key.stringValue] != nil }
    func value(_ key: Key) throws -> Any {
        guard let v = dict[key.stringValue] else { throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "No value associated with key \(key.stringValue).")) }
        return v
    }
    func decodeNil(forKey key: Key) throws -> Bool { _isPlistNull(try value(key)) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let v = try value(key)
        if _isPlistNull(v), T.self != String.self { throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath + [key], debugDescription: "Expected \(T.self) value but found null instead.")) }
        return try decoder.unbox(v, as: type, path: codingPath + [key])
    }
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try _PlistDecoder(value: try value(key), codingPath: codingPath + [key], userInfo: decoder.userInfo).container(keyedBy: type)
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try _PlistDecoder(value: try value(key), codingPath: codingPath + [key], userInfo: decoder.userInfo).unkeyedContainer()
    }
    func superDecoder() throws -> Decoder { _PlistDecoder(value: dict["super"] ?? NSDictionary(), codingPath: codingPath + [_PlistKey.super], userInfo: decoder.userInfo) }
    func superDecoder(forKey key: Key) throws -> Decoder { _PlistDecoder(value: dict[key.stringValue] ?? NSDictionary(), codingPath: codingPath + [key], userInfo: decoder.userInfo) }
}
struct _PlistUnkeyedDecoder: UnkeyedDecodingContainer {
    let decoder: _PlistDecoder; let array: NSArray; var codingPath: [CodingKey]
    var currentIndex = 0
    init(decoder: _PlistDecoder, array: NSArray, codingPath: [CodingKey]) { self.decoder = decoder; self.array = array; self.codingPath = codingPath }
    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }
    mutating func next<T>(_ t: T.Type) throws -> Any {
        guard !isAtEnd else { throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath + [_PlistKey(intValue: currentIndex)], debugDescription: "Unkeyed container is at end.")) }
        defer { currentIndex += 1 }
        return array[currentIndex]
    }
    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return false }
        if _isPlistNull(array[currentIndex]) { currentIndex += 1; return true }
        return false
    }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let path = codingPath + [_PlistKey(intValue: currentIndex)]
        return try decoder.unbox(try next(T.self), as: type, path: path)
    }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let path = codingPath + [_PlistKey(intValue: currentIndex)]
        return try _PlistDecoder(value: try next([String: Any].self), codingPath: path, userInfo: decoder.userInfo).container(keyedBy: type)
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let path = codingPath + [_PlistKey(intValue: currentIndex)]
        return try _PlistDecoder(value: try next([Any].self), codingPath: path, userInfo: decoder.userInfo).unkeyedContainer()
    }
    mutating func superDecoder() throws -> Decoder { _PlistDecoder(value: try next(Any.self), codingPath: codingPath, userInfo: decoder.userInfo) }
}
struct _PlistSingleDecoder: SingleValueDecodingContainer {
    let decoder: _PlistDecoder; var codingPath: [CodingKey]
    func decodeNil() -> Bool { _isPlistNull(decoder.value) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try decoder.unbox(decoder.value, as: type, path: codingPath) }
}
open class PropertyListDecoder {
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    public init() {}
    open func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        var format = PropertyListSerialization.PropertyListFormat.binary
        return try decode(type, from: data, format: &format)
    }
    open func decode<T: Decodable>(_ type: T.Type, from data: Data, format: inout PropertyListSerialization.PropertyListFormat) throws -> T {
        let tree: Any
        do { tree = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) }
        catch { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The given data was not a valid property list.", underlyingError: error)) }
        return try _PlistDecoder(value: tree, codingPath: [], userInfo: userInfo).unbox(tree, as: type, path: [])
    }
}

// MARK: - keyed archiving from Swift
extension NSKeyedUnarchiver {
    public static func unarchivedObject<DecodedObjectType: NSObject>(ofClass cls: DecodedObjectType.Type, from data: Data) throws -> DecodedObjectType? {
        try _isimUnarchivedObject(ofClass: cls, from: data) as? DecodedObjectType
    }
    public static func unarchivedObject(ofClasses classes: [AnyClass], from data: Data) throws -> Any? {
        try _isimUnarchivedObject(ofClasses: NSSet(array: classes) as! Set<AnyHashable>, from: data)
    }
    public static func unarchivedArrayOfObjects<DecodedObjectType: NSObject>(ofClass cls: DecodedObjectType.Type, from data: Data) throws -> [DecodedObjectType]? {
        try _isimUnarchivedArrayOfObjects(ofClass: cls, from: data) as? [DecodedObjectType]
    }
    public static func unarchivedDictionary<KeyType: NSObject, ObjectType: NSObject>(ofKeyClass keyCls: KeyType.Type, objectClass valueCls: ObjectType.Type, from data: Data) throws -> [KeyType: ObjectType]? {
        try _isimUnarchivedDictionary(ofKeyClass: keyCls, objectClass: valueCls, from: data) as? [KeyType: ObjectType]
    }
}
extension NSCoder {
    public func decodeObject<DecodedObjectType: NSObject>(of cls: DecodedObjectType.Type, forKey key: String) -> DecodedObjectType? {
        _isimDecodeObject(of: cls, forKey: key) as? DecodedObjectType
    }
    public func decodeObject(of classes: [AnyClass]?, forKey key: String) -> Any? {
        _isimDecodeObject(ofClasses: classes.map { NSSet(array: $0) as! Set<AnyHashable> }, forKey: key)
    }
    public func decodeArrayOfObjects<DecodedObjectType: NSObject>(ofClass cls: DecodedObjectType.Type, forKey key: String) -> [DecodedObjectType]? {
        _isimDecodeArrayOfObjects(ofClass: cls, forKey: key) as? [DecodedObjectType]
    }
    public func decodeDictionary<KeyType: NSObject, ObjectType: NSObject>(withKeysOfClass keyCls: KeyType.Type, objectsOfClass objectCls: ObjectType.Type, forKey key: String) -> [KeyType: ObjectType]? {
        _isimDecodeDictionary(withKeysOfClass: keyCls, objectsOfClass: objectCls, forKey: key) as? [KeyType: ObjectType]
    }
    public func decodeTopLevelObject(forKey key: String) throws -> Any? {
        let o = decodeObject(forKey: key)
        if let e = error { throw e }
        return o
    }
}

// MARK: - UndoManager
extension UndoManager {
    public func registerUndo<TargetType: AnyObject>(withTarget target: TargetType, handler: @escaping (TargetType) -> Void) {
        _isimRegisterUndo(withTarget: target) { t in handler(t as! TargetType) }
    }
}
