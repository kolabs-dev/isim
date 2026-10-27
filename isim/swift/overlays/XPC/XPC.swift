// isim XPC: the Swift side of `import XPC` (XPCSession, XPCListener, XPCReceivedMessage, XPCDictionary, XPCArray,
// XPCEndpoint, XPCRichError, XPCPeerRequirement, XPCPeerHandler) over the C API (<xpc/xpc.h>, re-exported; Foundation's
// XPC.m implements it). Self-authored, iOS API names. Adapted:
//   - a service is reachable from every process of the booted device (isim's app, its extensions, other apps); nothing
//     launches a service on demand.
//   - Codable messages travel as JSON in an XPC dictionary (key "isim.codable"); XPCDictionary messages as themselves.
//   - peer requirements are accepted and always satisfied (isim does not sign code).
@_exported import XPC
import Foundation
import Dispatch
import System

// MARK: - The C API's constants (macros the importer does not see)

public var XPC_TYPE_CONNECTION: xpc_type_t { _isim_xpc_type("connection")! }
public var XPC_TYPE_ENDPOINT: xpc_type_t { _isim_xpc_type("endpoint")! }
public var XPC_TYPE_NULL: xpc_type_t { _isim_xpc_type("null")! }
public var XPC_TYPE_BOOL: xpc_type_t { _isim_xpc_type("bool")! }
public var XPC_TYPE_INT64: xpc_type_t { _isim_xpc_type("int64")! }
public var XPC_TYPE_UINT64: xpc_type_t { _isim_xpc_type("uint64")! }
public var XPC_TYPE_DOUBLE: xpc_type_t { _isim_xpc_type("double")! }
public var XPC_TYPE_DATE: xpc_type_t { _isim_xpc_type("date")! }
public var XPC_TYPE_DATA: xpc_type_t { _isim_xpc_type("data")! }
public var XPC_TYPE_STRING: xpc_type_t { _isim_xpc_type("string")! }
public var XPC_TYPE_UUID: xpc_type_t { _isim_xpc_type("uuid")! }
public var XPC_TYPE_FD: xpc_type_t { _isim_xpc_type("fd")! }
public var XPC_TYPE_SHMEM: xpc_type_t { _isim_xpc_type("shmem")! }
public var XPC_TYPE_ARRAY: xpc_type_t { _isim_xpc_type("array")! }
public var XPC_TYPE_DICTIONARY: xpc_type_t { _isim_xpc_type("dictionary")! }
public var XPC_TYPE_ERROR: xpc_type_t { _isim_xpc_type("error")! }
public var XPC_TYPE_ACTIVITY: xpc_type_t { _isim_xpc_type("activity")! }
public var XPC_TYPE_RICH_ERROR: xpc_type_t { _isim_xpc_type("rich_error")! }
public var XPC_BOOL_TRUE: xpc_object_t { _isim_xpc_constant("true")! }
public var XPC_BOOL_FALSE: xpc_object_t { _isim_xpc_constant("false")! }
public var XPC_ERROR_CONNECTION_INTERRUPTED: xpc_object_t { _isim_xpc_constant("interrupted")! }
public var XPC_ERROR_CONNECTION_INVALID: xpc_object_t { _isim_xpc_constant("invalid")! }
public var XPC_ERROR_TERMINATION_IMMINENT: xpc_object_t { _isim_xpc_constant("termination")! }
public var XPC_ERROR_PEER_CODE_SIGNING_REQUIREMENT: xpc_object_t { _isim_xpc_constant("codesigning")! }
public let XPC_ACTIVITY_CHECK_IN: xpc_object_t = _isim_xpc_constant("checkin")!
public let XPC_ARRAY_APPEND: Int = -1

// MARK: - Errors

/// An error a session or listener reports.
public struct XPCRichError: Error, CustomStringConvertible, @unchecked Sendable {
    let message: String
    let retry: Bool
    init(_ e: xpc_rich_error_t) {
        let d = xpc_rich_error_copy_description(e)
        message = d.map { String(cString: $0) } ?? "XPC error"
        free(d)
        retry = xpc_rich_error_can_retry(e)
    }
    init(message: String, canRetry: Bool) { self.message = message; retry = canRetry }
    /// Whether sending again (or activating again) may succeed.
    public var canRetry: Bool { retry }
    public var description: String { message }
}

// MARK: - Values

/// A value in a dictionary literal (`["name": "a", "count": 2]`).
public struct XPCLiteralValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
                               ExpressibleByFloatLiteral, @unchecked Sendable {
    let object: xpc_object_t
    public init(_ value: String) { object = xpc_string_create(value) }
    public init(_ value: Bool) { object = xpc_bool_create(value) }
    public init(_ value: XPCDictionary) { object = value.object }
    public init(_ value: xpc_object_t) { object = value }
    public init<T: FixedWidthInteger & SignedInteger>(_ value: T) { object = xpc_int64_create(Int64(value)) }
    public init<T: FixedWidthInteger & UnsignedInteger>(_ value: T) { object = xpc_uint64_create(UInt64(value)) }
    public init<T: BinaryFloatingPoint>(_ value: T) { object = xpc_double_create(Double(value)) }
    public init(stringLiteral value: String) { self.init(value) }
    public init(integerLiteral value: Int64) { self.init(value) }
    public init(booleanLiteral value: Bool) { self.init(value) }
    public init(floatLiteral value: Double) { self.init(value) }
}

func _xpcValue<T: FixedWidthInteger>(_ o: xpc_object_t?, _ type: T.Type) -> T? {
    guard let o else { return nil }
    let t = xpc_get_type(o)
    if t == XPC_TYPE_INT64 { return T(exactly: xpc_int64_get_value(o)) }
    if t == XPC_TYPE_UINT64 { return T(exactly: xpc_uint64_get_value(o)) }
    return nil
}
func _xpcFloat<T: BinaryFloatingPoint>(_ o: xpc_object_t?, _ type: T.Type) -> T? {
    guard let o else { return nil }
    let t = xpc_get_type(o)
    if t == XPC_TYPE_DOUBLE { return T(xpc_double_get_value(o)) }
    if t == XPC_TYPE_INT64 { return T(xpc_int64_get_value(o)) }
    if t == XPC_TYPE_UINT64 { return T(xpc_uint64_get_value(o)) }
    return nil
}
func _xpcString(_ o: xpc_object_t?) -> String? {
    guard let o, xpc_get_type(o) == XPC_TYPE_STRING, let p = xpc_string_get_string_ptr(o) else { return nil }
    return String(cString: p)
}
func _xpcUUID(_ o: xpc_object_t?) -> uuid_t? {
    guard let o, xpc_get_type(o) == XPC_TYPE_UUID, let p = xpc_uuid_get_bytes(o) else { return nil }
    return (p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13], p[14], p[15])
}
func _xpcUUIDObject(_ u: uuid_t) -> xpc_object_t {
    withUnsafeBytes(of: u) { xpc_uuid_create($0.baseAddress!.assumingMemoryBound(to: UInt8.self)) }
}
func _xpcFD(_ o: xpc_object_t?) -> FileDescriptor? {
    guard let o, xpc_get_type(o) == XPC_TYPE_FD else { return nil }
    let fd = xpc_fd_dup(o)
    return fd >= 0 ? FileDescriptor(rawValue: fd) : nil
}

// MARK: - XPCDictionary

/// An XPC dictionary: string keys, XPC values.
public struct XPCDictionary: @unchecked Sendable, ExpressibleByDictionaryLiteral, CustomStringConvertible {
    let object: xpc_object_t
    public init() { object = xpc_dictionary_create_empty() }
    public init(_ object: xpc_object_t) {
        precondition(xpc_get_type(object) == XPC_TYPE_DICTIONARY || xpc_get_type(object) == XPC_TYPE_ERROR, "XPCDictionary: not a dictionary")
        self.object = object
    }
    public init(dictionaryLiteral elements: (String, XPCLiteralValue)...) {
        object = xpc_dictionary_create_empty()
        for (k, v) in elements { xpc_dictionary_set_value(object, k, v.object) }
    }
    public var description: String {
        let d = xpc_copy_description(object)
        defer { free(d) }
        return String(cString: d)
    }

    /// Copies this dictionary's entries into `other`.
    public func copy(into other: XPCDictionary) { forEach { xpc_dictionary_set_value(other.object, $0, $1) } }
    /// Replies to this received message with `reply`'s entries.
    public func reply(_ reply: XPCDictionary) { _ = _isim_xpc_reply(object, reply.object) }
    public var isEmpty: Bool { count == 0 }
    public var count: Int { xpc_dictionary_get_count(object) }
    public var keys: [String] { var k: [String] = []; forEach { key, _ in k.append(key) }; return k }
    public var values: [xpc_object_t] { var v: [xpc_object_t] = []; forEach { _, value in v.append(value) }; return v }
    public func withUnsafeUnderlyingDictionary<ReturnType>(_ body: (xpc_object_t) throws -> ReturnType) rethrows -> ReturnType { try body(object) }
    @discardableResult
    public func removeValue(forKey key: String) -> xpc_object_t? {
        let old = xpc_dictionary_get_value(object, key)
        xpc_dictionary_set_value(object, key, nil)
        return old
    }

    public struct KeyValuePair {
        public let key: String
        public let value: xpc_object_t
    }
    public func forEach(_ body: (KeyValuePair) throws -> Void) rethrows {
        try forEach { try body(KeyValuePair(key: $0, value: $1)) }
    }
    public func forEach(_ body: (String, xpc_object_t) throws -> Void) rethrows {
        var pairs: [(String, xpc_object_t)] = []
        _ = xpc_dictionary_apply(object) { k, v in pairs.append((String(cString: k), v)); return true }
        for (k, v) in pairs { try body(k, v) }
    }
    public func map<ReturnType>(_ transform: (KeyValuePair) throws -> ReturnType) rethrows -> [ReturnType] {
        var out: [ReturnType] = []
        try forEach { (pair: KeyValuePair) in out.append(try transform(pair)) }
        return out
    }

    // values by key
    public subscript(key: String) -> xpc_object_t? {
        get { xpc_dictionary_get_value(object, key) }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue) }
    }
    public subscript(key: String) -> String? {
        get { _xpcString(xpc_dictionary_get_value(object, key)) }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue.map { xpc_string_create($0) }) }
    }
    public subscript(key: String) -> Bool? {
        get { let v = xpc_dictionary_get_value(object, key); return v.flatMap { xpc_get_type($0) == XPC_TYPE_BOOL ? xpc_bool_get_value($0) : nil } }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue.map { xpc_bool_create($0) }) }
    }
    public subscript(key: String) -> XPCDictionary? {
        get { xpc_dictionary_get_dictionary(object, key).map { XPCDictionary($0) } }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue?.object) }
    }
    public subscript(key: String) -> XPCArray? {
        get { xpc_dictionary_get_array(object, key).map { XPCArray($0) } }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue?.object) }
    }
    public subscript(key: String) -> XPCEndpoint? {
        get { let v = xpc_dictionary_get_value(object, key); return v.flatMap { xpc_get_type($0) == XPC_TYPE_ENDPOINT ? XPCEndpoint($0) : nil } }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue?.endpoint) }
    }
    public subscript(key: String) -> uuid_t? {
        get { _xpcUUID(xpc_dictionary_get_value(object, key)) }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue.map { _xpcUUIDObject($0) }) }
    }
    public subscript(key: String) -> FileDescriptor? {
        get { _xpcFD(xpc_dictionary_get_value(object, key)) }
        nonmutating set { if let fd = newValue { xpc_dictionary_set_fd(object, key, fd.rawValue) } else { xpc_dictionary_set_value(object, key, nil) } }
    }
    public subscript<T: FixedWidthInteger & SignedInteger>(key: String) -> T? {
        get { _xpcValue(xpc_dictionary_get_value(object, key), T.self) }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue.map { xpc_int64_create(Int64($0)) }) }
    }
    public subscript<T: FixedWidthInteger & UnsignedInteger>(key: String) -> T? {
        get { _xpcValue(xpc_dictionary_get_value(object, key), T.self) }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue.map { xpc_uint64_create(UInt64($0)) }) }
    }
    public subscript<T: BinaryFloatingPoint>(key: String) -> T? {
        get { _xpcFloat(xpc_dictionary_get_value(object, key), T.self) }
        nonmutating set { xpc_dictionary_set_value(object, key, newValue.map { xpc_double_create(Double($0)) }) }
    }
    public subscript(key: String, as _: XPCDictionary.Type) -> XPCDictionary? { self[key] }
    public subscript(key: String, as _: String.Type) -> String? { self[key] }
    public subscript(key: String, as _: Bool.Type) -> Bool? { self[key] }
    public subscript(key: String, as _: any OS_xpc_object.Type) -> xpc_object_t? { self[key] }
    public subscript(key: String, as type: xpc_type_t) -> xpc_object_t? {
        let v: xpc_object_t? = self[key]
        return v.flatMap { xpc_get_type($0) == type ? $0 : nil }
    }
    public subscript(key: String, as _: XPCArray.Type) -> XPCArray? { self[key] }
    public subscript(key: String, as _: XPCEndpoint.Type) -> XPCEndpoint? { self[key] }
    public subscript(key: String, as _: uuid_t.Type) -> uuid_t? { self[key] }
    public subscript(key: String, as _: FileDescriptor.Type) -> FileDescriptor? { self[key] }
    public subscript<T: FixedWidthInteger>(key: String, as _: T.Type) -> T? { _xpcValue(xpc_dictionary_get_value(object, key), T.self) }
    public subscript<T: BinaryFloatingPoint>(key: String, as _: T.Type) -> T? { _xpcFloat(xpc_dictionary_get_value(object, key), T.self) }
    public subscript(key: String, as _: Bool.Type, default value: @autoclosure () -> Bool) -> Bool { self[key, as: Bool.self] ?? value() }
    public subscript<T: FixedWidthInteger>(key: String, as _: T.Type, default value: @autoclosure () -> T) -> T { self[key, as: T.self] ?? value() }
    public subscript(key: String, as _: XPCArray.Type, default value: @autoclosure () -> XPCArray) -> XPCArray { self[key, as: XPCArray.self] ?? value() }
    public subscript(key: String, as _: FileDescriptor.Type, default value: @autoclosure () -> FileDescriptor) -> FileDescriptor {
        self[key, as: FileDescriptor.self] ?? value()
    }
    public subscript(key: String, as _: uuid_t.Type, default value: @autoclosure () -> uuid_t) -> uuid_t { self[key, as: uuid_t.self] ?? value() }
}

// MARK: - XPCArray

/// An XPC array.
public struct XPCArray: @unchecked Sendable, CustomStringConvertible {
    let object: xpc_object_t
    public init() { object = xpc_array_create_empty() }
    public init(_ object: xpc_object_t) {
        precondition(xpc_get_type(object) == XPC_TYPE_ARRAY, "XPCArray: not an array")
        self.object = object
    }
    public var description: String {
        let d = xpc_copy_description(object)
        defer { free(d) }
        return String(cString: d)
    }
    public func copy(into other: XPCArray) { forEach { _, v in xpc_array_append_value(other.object, v) } }
    public var isEmpty: Bool { count == 0 }
    public var count: Int { xpc_array_get_count(object) }
    public func withUnsafeUnderlyingArray<ReturnType>(_ body: (xpc_object_t) throws -> ReturnType) rethrows -> ReturnType { try body(object) }

    public struct IndexValuePair {
        public let index: Int
        public let value: xpc_object_t
    }
    public func forEach(_ body: (IndexValuePair) throws -> Void) rethrows {
        try forEach { try body(IndexValuePair(index: $0, value: $1)) }
    }
    public func forEach(_ body: (Int, xpc_object_t) throws -> Void) rethrows {
        for i in 0..<count { try body(i, xpc_array_get_value(object, i)) }
    }
    public func map<ReturnType>(_ transform: (IndexValuePair) throws -> ReturnType) rethrows -> [ReturnType] {
        try (0..<count).map { try transform(IndexValuePair(index: $0, value: xpc_array_get_value(object, $0))) }
    }

    func store(_ index: Int, _ value: xpc_object_t?) {
        guard let value else { return }
        xpc_array_set_value(object, index == count ? XPC_ARRAY_APPEND : index, value)
    }
    func value(at index: Int) -> xpc_object_t? { index >= 0 && index < count ? xpc_array_get_value(object, index) : nil }
    public subscript(index: Int) -> xpc_object_t? {
        get { value(at: index) }
        nonmutating set { store(index, newValue) }
    }
    public subscript(index: Int) -> String? {
        get { _xpcString(value(at: index)) }
        nonmutating set { store(index, newValue.map { xpc_string_create($0) }) }
    }
    public subscript(index: Int) -> Bool? {
        get { value(at: index).flatMap { xpc_get_type($0) == XPC_TYPE_BOOL ? xpc_bool_get_value($0) : nil } }
        nonmutating set { store(index, newValue.map { xpc_bool_create($0) }) }
    }
    public subscript(index: Int) -> XPCDictionary? {
        get { value(at: index).flatMap { xpc_get_type($0) == XPC_TYPE_DICTIONARY ? XPCDictionary($0) : nil } }
        nonmutating set { store(index, newValue?.object) }
    }
    public subscript(index: Int) -> XPCArray? {
        get { value(at: index).flatMap { xpc_get_type($0) == XPC_TYPE_ARRAY ? XPCArray($0) : nil } }
        nonmutating set { store(index, newValue?.object) }
    }
    public subscript(index: Int) -> XPCEndpoint? {
        get { value(at: index).flatMap { xpc_get_type($0) == XPC_TYPE_ENDPOINT ? XPCEndpoint($0) : nil } }
        nonmutating set { store(index, newValue?.endpoint) }
    }
    public subscript(index: Int) -> uuid_t? {
        get { _xpcUUID(value(at: index)) }
        nonmutating set { store(index, newValue.map { _xpcUUIDObject($0) }) }
    }
    public subscript(index: Int) -> FileDescriptor? {
        get { _xpcFD(value(at: index)) }
        nonmutating set { if let fd = newValue { xpc_array_set_fd(object, index == count ? XPC_ARRAY_APPEND : index, fd.rawValue) } }
    }
    public subscript<T: FixedWidthInteger & SignedInteger>(index: Int) -> T? {
        get { _xpcValue(value(at: index), T.self) }
        nonmutating set { store(index, newValue.map { xpc_int64_create(Int64($0)) }) }
    }
    public subscript<T: FixedWidthInteger & UnsignedInteger>(index: Int) -> T? {
        get { _xpcValue(value(at: index), T.self) }
        nonmutating set { store(index, newValue.map { xpc_uint64_create(UInt64($0)) }) }
    }
    public subscript<T: BinaryFloatingPoint>(index: Int) -> T? {
        get { _xpcFloat(value(at: index), T.self) }
        nonmutating set { store(index, newValue.map { xpc_double_create(Double($0)) }) }
    }
    public subscript(index: Int, as _: XPCDictionary.Type) -> XPCDictionary? { self[index] }
    public subscript(index: Int, as _: String.Type) -> String? { self[index] }
    public subscript(index: Int, as _: Bool.Type) -> Bool? { self[index] }
    public subscript(index: Int, as _: any OS_xpc_object.Type) -> xpc_object_t? { value(at: index) }
    public subscript(index: Int, as type: xpc_type_t) -> xpc_object_t? { value(at: index).flatMap { xpc_get_type($0) == type ? $0 : nil } }
    public subscript(index: Int, as _: XPCArray.Type) -> XPCArray? { self[index] }
    public subscript(index: Int, as _: XPCEndpoint.Type) -> XPCEndpoint? { self[index] }
    public subscript(index: Int, as _: uuid_t.Type) -> uuid_t? { self[index] }
    public subscript(index: Int, as _: FileDescriptor.Type) -> FileDescriptor? { self[index] }
    public subscript<T: FixedWidthInteger>(index: Int, as _: T.Type) -> T? { _xpcValue(value(at: index), T.self) }
    public subscript<T: BinaryFloatingPoint>(index: Int, as _: T.Type) -> T? { _xpcFloat(value(at: index), T.self) }
    public subscript(index: Int, as _: Bool.Type, default value: @autoclosure () -> Bool) -> Bool { self[index, as: Bool.self] ?? value() }
    public subscript<T: FixedWidthInteger>(index: Int, as _: T.Type, default value: @autoclosure () -> T) -> T { self[index, as: T.self] ?? value() }
    public subscript(index: Int, as _: XPCArray.Type, default value: @autoclosure () -> XPCArray) -> XPCArray { self[index, as: XPCArray.self] ?? value() }
    public subscript(index: Int, as _: XPCEndpoint.Type, default value: @autoclosure () -> XPCEndpoint) -> XPCEndpoint {
        self[index, as: XPCEndpoint.self] ?? value()
    }
    public subscript(index: Int, as _: FileDescriptor.Type, default value: @autoclosure () -> FileDescriptor) -> FileDescriptor {
        self[index, as: FileDescriptor.self] ?? value()
    }
    public subscript(index: Int, as _: uuid_t.Type, default value: @autoclosure () -> uuid_t) -> uuid_t { self[index, as: uuid_t.self] ?? value() }
}

// MARK: - Endpoints and requirements

/// A listener's endpoint: a session made from it reaches the listener (an anonymous one too).
public struct XPCEndpoint: @unchecked Sendable {
    let endpoint: xpc_endpoint_t
    public init(_ endpoint: xpc_endpoint_t) { self.endpoint = endpoint }
}

/// A requirement on the peer's code signature. Adapted: isim does not sign code, so every peer satisfies it.
public struct XPCPeerRequirement: Sendable, CustomStringConvertible {
    let kind: String
    public var description: String { kind }
    public init(lightweightCodeRequirements: XPCDictionary) { kind = "lightweight code requirements" }
    init(_ kind: String) { self.kind = kind }
    public static func entitlement(_ entitlement: String, matches value: String) -> XPCPeerRequirement { .init("entitlement \(entitlement) = \(value)") }
    public static func entitlement(_ entitlement: String, matches value: Int) -> XPCPeerRequirement { .init("entitlement \(entitlement) = \(value)") }
    public static func entitlement(_ entitlement: String, matches value: Bool) -> XPCPeerRequirement { .init("entitlement \(entitlement) = \(value)") }
    public static func hasEntitlement(_ entitlement: String) -> XPCPeerRequirement { .init("has entitlement \(entitlement)") }
    public static func isFromSameTeam(andMatchesSigningIdentifier identifier: String? = nil) -> XPCPeerRequirement { .init("same team \(identifier ?? "")") }
    public static func isPlatformCode(andMatchesSigningIdentifier identifier: String? = nil) -> XPCPeerRequirement { .init("platform code \(identifier ?? "")") }
}

// MARK: - Codable messages

let _codableKey = "isim.codable"
func _encodeMessage<Message: Encodable>(_ message: Message) throws -> xpc_object_t {
    if let d = message as? XPCDictionary { return d.object }
    let data = try JSONEncoder().encode(message)
    let dict = xpc_dictionary_create_empty()
    data.withUnsafeBytes { xpc_dictionary_set_data(dict, _codableKey, $0.baseAddress, $0.count) }
    return dict
}
func _encodeAny(_ message: any Encodable) throws -> xpc_object_t { try _encodeMessage(message) }
func _decodeMessage<T: Decodable>(_ object: xpc_object_t, as type: T.Type) throws -> T {
    if let d = XPCDictionary(object) as? T { return d }
    var length = 0
    guard let bytes = xpc_dictionary_get_data(object, _codableKey, &length) else {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The XPC message holds no Codable value"))
    }
    return try JSONDecoder().decode(T.self, from: Data(bytes: bytes, count: length))
}

/// A message a session received.
public struct XPCReceivedMessage: @unchecked Sendable {
    let object: xpc_object_t
    /// Whether the sender waits for the reply (sendSync).
    public var isSync: Bool { _isim_xpc_message_is_sync(object) }
    /// Whether the sender expects a reply.
    public var expectsReply: Bool { _isim_xpc_message_expects_reply(object) }
    public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T { try _decodeMessage(object, as: type) }
    /// Replies to the message (once).
    public func reply<Message: Encodable>(_ message: Message) {
        guard let o = try? _encodeMessage(message) else { return }
        _ = _isim_xpc_reply(object, o)
    }
    /// Replies later: `body` runs on `queue` and replies with `reply(_:)`; return this from the handler.
    public func handoffReply(to queue: DispatchQueue, _ body: @escaping () -> Void) -> (any Encodable)? {
        queue.async(execute: body)
        return nil
    }
    public func senderSatisfies(_ requirement: XPCPeerRequirement) -> Bool { true }
}

// MARK: - Sessions

/// A session with a service (or a listener's endpoint), or a listener's side of a session.
public final class XPCSession: @unchecked Sendable, CustomStringConvertible {
    /// How a session starts.
    public struct InitializationOptions: OptionSet, Sendable {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public static let none = InitializationOptions([])
        public static let inactive = InitializationOptions(rawValue: 1 << 0)
        public static let privileged = InitializationOptions(rawValue: 1 << 1)
    }

    let session: xpc_session_t
    /// where the handlers run (isim's C sessions deliver in order on their own queue; this hops to the caller's)
    var queue: DispatchQueue?

    init(session: xpc_session_t, queue: DispatchQueue? = nil) { self.session = session; self.queue = queue }

    convenience init(create: (inout xpc_rich_error_t?) -> xpc_session_t?, options: InitializationOptions, queue: DispatchQueue?,
                     cancellationHandler: ((XPCRichError) -> Void)?) throws {
        var err: xpc_rich_error_t?
        guard let s = create(&err) else { throw err.map { XPCRichError($0) } ?? XPCRichError(message: "Cannot create the session", canRetry: false) }
        self.init(session: s, queue: queue)
        if let cancellationHandler { setCancellationHandler(cancellationHandler) }
        if !options.contains(.inactive) { try activate() }
    }
    static func flags(_ options: InitializationOptions) -> xpc_session_create_flags_t {
        options.contains(.privileged) ? [.inactive, .privileged] : .inactive        // activated after the handlers are set
    }

    // to an XPC service
    public convenience init(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(create: { e in xpc_session_create_xpc_service(xpcService, nil, XPCSession.flags(options), &e) },
                      options: options, queue: targetQueue, cancellationHandler: cancellationHandler)
    }
    public convenience init(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingMessageHandler: @escaping (XPCReceivedMessage) -> (any Encodable)?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingMessageHandler: @escaping (XPCDictionary) -> XPCDictionary?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init<Message: Decodable>(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                                                incomingMessageHandler: @escaping (Message) -> (any Encodable)?,
                                                cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement, cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options, cancellationHandler: cancellationHandler)
    }
    public convenience init(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement, incomingMessageHandler: @escaping (XPCReceivedMessage) -> (any Encodable)?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options, incomingMessageHandler: incomingMessageHandler,
                      cancellationHandler: cancellationHandler)
    }
    public convenience init(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement, incomingMessageHandler: @escaping (XPCDictionary) -> XPCDictionary?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options, incomingMessageHandler: incomingMessageHandler,
                      cancellationHandler: cancellationHandler)
    }
    public convenience init<Message: Decodable>(xpcService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                                                requirement: XPCPeerRequirement, incomingMessageHandler: @escaping (Message) -> (any Encodable)?,
                                                cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(xpcService: xpcService, targetQueue: targetQueue, options: options, incomingMessageHandler: incomingMessageHandler,
                      cancellationHandler: cancellationHandler)
    }

    // to a named service
    public convenience init(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(create: { e in xpc_session_create_mach_service(machService, nil, XPCSession.flags(options), &e) },
                      options: options, queue: targetQueue, cancellationHandler: cancellationHandler)
    }
    public convenience init(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingMessageHandler: @escaping (XPCReceivedMessage) -> (any Encodable)?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingMessageHandler: @escaping (XPCDictionary) -> XPCDictionary?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init<Message: Decodable>(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                                                incomingMessageHandler: @escaping (Message) -> (any Encodable)?,
                                                cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement, cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options, cancellationHandler: cancellationHandler)
    }
    public convenience init(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement, incomingMessageHandler: @escaping (XPCReceivedMessage) -> (any Encodable)?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options, incomingMessageHandler: incomingMessageHandler,
                      cancellationHandler: cancellationHandler)
    }
    public convenience init(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement, incomingMessageHandler: @escaping (XPCDictionary) -> XPCDictionary?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options, incomingMessageHandler: incomingMessageHandler,
                      cancellationHandler: cancellationHandler)
    }
    public convenience init<Message: Decodable>(machService: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                                                requirement: XPCPeerRequirement, incomingMessageHandler: @escaping (Message) -> (any Encodable)?,
                                                cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(machService: machService, targetQueue: targetQueue, options: options, incomingMessageHandler: incomingMessageHandler,
                      cancellationHandler: cancellationHandler)
    }

    // to a listener's endpoint
    public convenience init(endpoint: XPCEndpoint, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(create: { e in _xpc_session_create_endpoint(endpoint.endpoint, nil, XPCSession.flags(options), &e) },
                      options: options, queue: targetQueue, cancellationHandler: cancellationHandler)
    }
    public convenience init(endpoint: XPCEndpoint, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingMessageHandler: @escaping (XPCReceivedMessage) -> (any Encodable)?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(endpoint: endpoint, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init(endpoint: XPCEndpoint, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingMessageHandler: @escaping (XPCDictionary) -> XPCDictionary?,
                            cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(endpoint: endpoint, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init<Message: Decodable>(endpoint: XPCEndpoint, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                                                incomingMessageHandler: @escaping (Message) -> (any Encodable)?,
                                                cancellationHandler: ((XPCRichError) -> Void)? = nil) throws {
        try self.init(endpoint: endpoint, targetQueue: targetQueue, options: options.union(.inactive), cancellationHandler: cancellationHandler)
        setIncomingMessageHandler(incomingMessageHandler)
        if !options.contains(.inactive) { try activate() }
    }

    public var description: String {
        let d = xpc_session_copy_description(session); defer { free(d) }
        return d.map { String(cString: $0) } ?? "<XPCSession>"
    }
    public func setTargetQueue(_ queue: DispatchQueue) { self.queue = queue }
    func run(_ body: @escaping () -> Void) { if let queue { queue.async(execute: body) } else { body() } }
    public func activate() throws {
        var err: xpc_rich_error_t?
        if !xpc_session_activate(session, &err) { throw err.map { XPCRichError($0) } ?? XPCRichError(message: "Cannot activate the session", canRetry: true) }
    }
    public func cancel(reason: String) { xpc_session_cancel(session) }
    public func setCancellationHandler(_ handler: @escaping (XPCRichError) -> Void) {
        xpc_session_set_cancel_handler(session) { [weak self] e in
            let error = XPCRichError(e)
            if let self { self.run { handler(error) } } else { handler(error) }
        }
    }
    public func setPeerRequirement(_ requirement: XPCPeerRequirement) {}

    // incoming messages
    public func setIncomingMessageHandler(_ handler: @escaping (XPCReceivedMessage) -> (any Encodable)?) {
        xpc_session_set_incoming_message_handler(session) { [weak self] message in
            let work = {
                let received = XPCReceivedMessage(object: message)
                if let reply = handler(received), received.expectsReply, let o = try? _encodeAny(reply) { _ = _isim_xpc_reply(message, o) }
            }
            if let self { self.run(work) } else { work() }
        }
    }
    public func setIncomingMessageHandler(_ handler: @escaping (XPCDictionary) -> XPCDictionary?) {
        xpc_session_set_incoming_message_handler(session) { [weak self] message in
            let work = {
                if let reply = handler(XPCDictionary(message)), _isim_xpc_message_expects_reply(message) { _ = _isim_xpc_reply(message, reply.object) }
            }
            if let self { self.run(work) } else { work() }
        }
    }
    public func setIncomingMessageHandler<Message: Decodable>(_ handler: @escaping (Message) -> (any Encodable)?) {
        xpc_session_set_incoming_message_handler(session) { [weak self] message in
            let work = {
                guard let decoded = try? _decodeMessage(message, as: Message.self) else { return }
                if let reply = handler(decoded), _isim_xpc_message_expects_reply(message), let o = try? _encodeAny(reply) { _ = _isim_xpc_reply(message, o) }
            }
            if let self { self.run(work) } else { work() }
        }
    }

    // sending
    public func send<Message: Encodable>(_ message: Message) throws {
        if let e = xpc_session_send_message(session, try _encodeMessage(message)) { throw XPCRichError(e) }
    }
    public func send(message: XPCDictionary) throws {
        if let e = xpc_session_send_message(session, message.object) { throw XPCRichError(e) }
    }
    public func send<Message: Encodable>(_ message: Message, replyHandler: @escaping (Result<XPCReceivedMessage, XPCRichError>) -> Void) throws {
        let q = queue
        xpc_session_send_message_with_reply_async(session, try _encodeMessage(message)) { reply, error in
            let result: Result<XPCReceivedMessage, XPCRichError> = reply.map { .success(XPCReceivedMessage(object: $0)) }
                ?? .failure(error.map { XPCRichError($0) } ?? XPCRichError(message: "No reply", canRetry: false))
            if let q { q.async { replyHandler(result) } } else { replyHandler(result) }
        }
    }
    public func send<Message: Encodable, Reply: Decodable>(_ message: Message, replyHandler: @escaping (Result<Reply, any Error>) -> Void) throws {
        try send(message) { (result: Result<XPCReceivedMessage, XPCRichError>) in
            switch result {
            case .success(let m): replyHandler(Result { try m.decode(as: Reply.self) })
            case .failure(let e): replyHandler(.failure(e))
            }
        }
    }
    public func send(message: XPCDictionary, replyHandler: @escaping (Result<XPCDictionary, XPCRichError>) -> Void) {
        let q = queue
        xpc_session_send_message_with_reply_async(session, message.object) { reply, error in
            let result: Result<XPCDictionary, XPCRichError> = reply.map { .success(XPCDictionary($0)) }
                ?? .failure(error.map { XPCRichError($0) } ?? XPCRichError(message: "No reply", canRetry: false))
            if let q { q.async { replyHandler(result) } } else { replyHandler(result) }
        }
    }
    public func sendSync<Message: Encodable>(_ message: Message) throws -> XPCReceivedMessage {
        var err: xpc_rich_error_t?
        guard let reply = xpc_session_send_message_with_reply_sync(session, try _encodeMessage(message), &err) else {
            throw err.map { XPCRichError($0) } ?? XPCRichError(message: "No reply", canRetry: false)
        }
        return XPCReceivedMessage(object: reply)
    }
    public func sendSync<Message: Encodable, Reply: Decodable>(_ message: Message) throws -> Reply {
        try sendSync(message).decode(as: Reply.self)
    }
    public func sendSync(message: XPCDictionary) throws -> XPCDictionary {
        var err: xpc_rich_error_t?
        guard let reply = xpc_session_send_message_with_reply_sync(session, message.object, &err) else {
            throw err.map { XPCRichError($0) } ?? XPCRichError(message: "No reply", canRetry: false)
        }
        return XPCDictionary(reply)
    }
}

// MARK: - Listeners

/// Handles one peer's messages (XPCListener.IncomingSessionRequest.accept(_:)).
public protocol XPCPeerHandler<Input, Output> {
    associatedtype Input
    associatedtype Output
    func handleIncomingRequest(_ input: Input) -> Output?
    func handleCancellation(error: XPCRichError)
}
extension XPCPeerHandler {
    public func handleCancellation(error: XPCRichError) {}
}

/// Listens for sessions to a named service, or anonymously (reached through its endpoint).
public final class XPCListener: @unchecked Sendable {
    public struct InitializationOptions: OptionSet, Sendable {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public static let none = InitializationOptions([])
        public static let inactive = InitializationOptions(rawValue: 1 << 0)
    }

    /// A peer asking for a session: accept it (with how to handle its messages) or reject it.
    public struct IncomingSessionRequest: @unchecked Sendable {
        /// What the handler decided.
        public struct Decision: Sendable {
            let accepted: Bool
            let reason: String?
        }
        let peer: xpc_session_t
        let queue: DispatchQueue?

        public func reject(reason: String) -> Decision { Decision(accepted: false, reason: reason) }

        public func accept(incomingMessageHandler: @escaping (XPCReceivedMessage) -> (any Encodable)?,
                           cancellationHandler: ((XPCRichError) -> Void)? = nil) -> Decision {
            let s = XPCSession(session: peer, queue: queue)
            s.setIncomingMessageHandler(incomingMessageHandler)
            if let cancellationHandler { s.setCancellationHandler(cancellationHandler) }
            return Decision(accepted: true, reason: nil)
        }
        public func accept(incomingMessageHandler: @escaping (XPCDictionary) -> XPCDictionary?,
                           cancellationHandler: ((XPCRichError) -> Void)? = nil) -> Decision {
            let s = XPCSession(session: peer, queue: queue)
            s.setIncomingMessageHandler(incomingMessageHandler)
            if let cancellationHandler { s.setCancellationHandler(cancellationHandler) }
            return Decision(accepted: true, reason: nil)
        }
        public func accept<Message: Decodable>(incomingMessageHandler: @escaping (Message) -> (any Encodable)?,
                                               cancellationHandler: ((XPCRichError) -> Void)? = nil) -> Decision {
            let s = XPCSession(session: peer, queue: queue)
            s.setIncomingMessageHandler(incomingMessageHandler)
            if let cancellationHandler { s.setCancellationHandler(cancellationHandler) }
            return Decision(accepted: true, reason: nil)
        }
        /// Accepts with a handler made for the session: its input is an XPCDictionary, an XPCReceivedMessage or a
        /// Decodable message; its output (if any) is the reply.
        public func accept<Handler: XPCPeerHandler>(_ makeHandler: (XPCSession) -> Handler) -> Decision {
            let s = XPCSession(session: peer, queue: queue)
            let handler = makeHandler(s)
            s.setCancellationHandler { handler.handleCancellation(error: $0) }
            xpc_session_set_incoming_message_handler(peer) { message in s.run {
                let input: Handler.Input?
                if Handler.Input.self == XPCDictionary.self { input = XPCDictionary(message) as? Handler.Input }
                else if Handler.Input.self == XPCReceivedMessage.self { input = XPCReceivedMessage(object: message) as? Handler.Input }
                else if let decodable = Handler.Input.self as? any Decodable.Type { input = (try? _decodeMessage(message, as: decodable)) as? Handler.Input }
                else { input = nil }
                guard let input, let output = handler.handleIncomingRequest(input), _isim_xpc_message_expects_reply(message) else { return }
                if let d = output as? XPCDictionary { _ = _isim_xpc_reply(message, d.object) }
                else if let e = output as? any Encodable, let o = try? _encodeAny(e) { _ = _isim_xpc_reply(message, o) }
            } }
            return Decision(accepted: true, reason: nil)
        }
    }

    let listener: xpc_listener_t

    init(service: String?, targetQueue: DispatchQueue?, options: InitializationOptions,
         incomingSessionHandler: @escaping (IncomingSessionRequest) -> IncomingSessionRequest.Decision) throws {
        var err: xpc_rich_error_t?
        let flags: xpc_listener_create_flags_t = .inactive
        guard let l = xpc_listener_create(service, nil, flags, { peer in
            // decided on the listener's own queue (the session starts once this returns); handlers hop to targetQueue
            let decision = incomingSessionHandler(IncomingSessionRequest(peer: peer, queue: targetQueue))
            if !decision.accepted { xpc_listener_reject_peer(peer, decision.reason ?? "rejected") }
        }, &err) else { throw err.map { XPCRichError($0) } ?? XPCRichError(message: "Cannot create the listener", canRetry: false) }
        listener = l
        if !options.contains(.inactive) { try activate() }
    }
    public convenience init(service: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingSessionHandler: @escaping (IncomingSessionRequest) -> IncomingSessionRequest.Decision) throws {
        try self.init(service: Optional(service), targetQueue: targetQueue, options: options, incomingSessionHandler: incomingSessionHandler)
    }
    public convenience init(service: String, targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            requirement: XPCPeerRequirement,
                            incomingSessionHandler: @escaping (IncomingSessionRequest) -> IncomingSessionRequest.Decision) throws {
        try self.init(service: Optional(service), targetQueue: targetQueue, options: options, incomingSessionHandler: incomingSessionHandler)
    }
    /// An anonymous listener: sessions reach it through its endpoint.
    public convenience init(targetQueue: DispatchQueue? = nil, options: InitializationOptions = .none,
                            incomingSessionHandler: @escaping (IncomingSessionRequest) -> IncomingSessionRequest.Decision) throws {
        try self.init(service: nil, targetQueue: targetQueue, options: options, incomingSessionHandler: incomingSessionHandler)
    }

    public func activate() throws {
        var err: xpc_rich_error_t?
        if !xpc_listener_activate(listener, &err) { throw err.map { XPCRichError($0) } ?? XPCRichError(message: "Cannot activate the listener", canRetry: false) }
    }
    public func cancel() { xpc_listener_cancel(listener) }
    public var endpoint: XPCEndpoint { XPCEndpoint(xpc_listener_copy_endpoint(listener)) }
}
