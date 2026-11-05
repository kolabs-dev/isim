// isim Network (issue #851): the rest of the classic Swift API. Addresses (IPv4 multicast groups, IPv6 scopes and
// kinds), interface radio types, path link quality, TXT record entries and TXTRecordDecoder, endpoint copies, listener
// and browser application services, privacy contexts and proxy configurations, TLS cipher suites, and the error
// domains. Adapted: an application service is a Bonjour service of the app's own type (_<name>._isimapp._tcp), so
// other copies of the app on this isim device or the host's network find it; privacy contexts and proxy
// configurations are kept with the parameters (connections go direct, through the host's resolver).
@_exported import Foundation

// MARK: - addresses

extension IPAddress {
    /// an address from its text form ("192.0.2.1", "2001:db8::1")
    public init?(_ string: String) {
        var a4 = in_addr(), a6 = in6_addr()
        if inet_pton(AF_INET, string, &a4) == 1 { self.init(withUnsafeBytes(of: &a4) { Data($0) }, nil) }
        else if inet_pton(AF_INET6, string, &a6) == 1 { self.init(withUnsafeBytes(of: &a6) { Data($0) }, nil) }
        else { return nil }
    }
}

extension IPv4Address {
    /// all routers on the segment (224.0.0.2)
    public static let allRoutersGroup = IPv4Address(Data([224, 0, 0, 2]))!
    /// IGMPv3 reports (224.0.0.22)
    public static let allReportsGroup = IPv4Address(Data([224, 0, 0, 22]))!
    /// multicast DNS (224.0.0.251)
    public static let mdnsGroup = IPv4Address(Data([224, 0, 0, 251]))!
}

extension IPv6Address {
    /// a multicast scope (RFC 4291 §2.7)
    public enum Scope: UInt8, Sendable, Hashable {
        case nodeLocal = 1, linkLocal = 2, siteLocal = 5, organizationLocal = 8, global = 14
    }
    /// the unspecified address (::)
    public static let broadcast = IPv6Address(Data(repeating: 0, count: 16))!
    /// all nodes on this node (ff01::1)
    public static let nodeLocalNodes = IPv6Address(Data([0xff, 0x01] + [UInt8](repeating: 0, count: 13) + [1]))!
    /// all nodes on the link (ff02::1)
    public static let linkLocalNodes = IPv6Address(Data([0xff, 0x02] + [UInt8](repeating: 0, count: 13) + [1]))!
    /// all routers on the link (ff02::2)
    public static let linkLocalRouters = IPv6Address(Data([0xff, 0x02] + [UInt8](repeating: 0, count: 13) + [2]))!
    public var isAny: Bool { rawValue.allSatisfy { $0 == 0 } }
    /// ::ffff:a.b.c.d
    public var isIPv4Mapped: Bool { rawValue.prefix(10).allSatisfy { $0 == 0 } && rawValue[rawValue.startIndex + 10] == 0xff && rawValue[rawValue.startIndex + 11] == 0xff }
    /// ::a.b.c.d (not :: or ::1)
    public var isIPv4Compatabile: Bool {
        rawValue.prefix(12).allSatisfy { $0 == 0 } && !isAny && !isLoopback
    }
    /// 2002::/16
    public var is6to4: Bool { rawValue.prefix(2) == Data([0x20, 0x02]) }
    /// fc00::/7
    public var isUniqueLocal: Bool { (rawValue.first ?? 0) & 0xfe == 0xfc }
    /// the IPv4 address inside an IPv4-mapped or IPv4-compatible address
    public var asIPv4: IPv4Address? { isIPv4Mapped || isIPv4Compatabile ? IPv4Address(Data(rawValue.suffix(4))) : nil }
    /// a multicast address's scope
    public var multicastScope: Scope? { isMulticast ? Scope(rawValue: rawValue[rawValue.startIndex + 1] & 0x0f) : nil }
}

// MARK: - error domains

public let kNWErrorDomainPOSIX: CFString = "kNWErrorDomainPOSIX" as CFString
public let kNWErrorDomainDNS: CFString = "kNWErrorDomainDNS" as CFString
public let kNWErrorDomainTLS: CFString = "kNWErrorDomainTLS" as CFString
public let kNWErrorDomainWiFiAware: CFString = "kNWErrorDomainWiFiAware" as CFString

// MARK: - interfaces and paths

extension NWInterface {
    /// the radio an interface uses (iOS 15). isim's interfaces are the host's: wired, Wi-Fi or other, without a radio
    /// generation, so data transfer reports leave it out
    public enum RadioType: Sendable, Hashable {
        public enum WiFi: Sendable, Hashable { case a, b, g, n, ac, ax }
        public enum Cellular: Sendable, Hashable {
            public enum NewRadio5GVariant: Sendable, Hashable { case sub6GHz, mmWave }
            case lte, cdma, gsm, wcdma, evdo, standalone5G(NewRadio5GVariant), dualConnectivity5G(NewRadio5GVariant)
        }
        case wifi(WiFi), cell(Cellular)
    }
}

extension NWPath {
    /// how good the link is (iOS 26): isim measures none, so it is unknown on a satisfied path
    public enum LinkQuality: Sendable, Hashable { case unknown, minimal, moderate, good }
    public var linkQuality: LinkQuality { .unknown }
    /// whether the path uses an interface the user limited the most (iOS 26): never on isim
    public var isUltraConstrained: Bool { false }
}

extension NWPathMonitor {
    /// iOS 17: the iterator of `for await path in monitor`
    public typealias Iterator = AsyncIterator
}

// MARK: - endpoints

extension NWEndpoint {
    /// the same host with another port (iOS 26.4); nil for endpoints without a port
    public init?(copying endpoint: NWEndpoint, newPort: NWEndpoint.Port) {
        guard case .hostPort(let h, _) = endpoint else { return nil }
        self = .hostPort(host: h, port: newPort)
    }
    /// a Bonjour service's TXT record (iOS 16), from isim's registry or multicast DNS
    public var txtRecord: NWTXTRecord? {
        guard case .service(let name, let type, _, _) = self else { return nil }
        if let s = _NWBonjour.lookup(name: name, type: type) { return NWTXTRecord(s.txt) }
        return nil
    }
}

// MARK: - TXT records

extension NWTXTRecord {
    /// a TXT record entry: a key alone, an empty value, text, or bytes
    public enum Entry: Sendable, Hashable {
        case none, empty, string(String), data(Data)
        public init(_ data: Data?) {
            guard let data else { self = .none; return }
            if data.isEmpty { self = .empty } else if let s = String(data: data, encoding: .utf8) { self = .string(s) } else { self = .data(data) }
        }
        public var data: Data? {
            switch self {
            case .none: return nil
            case .empty: return Data()
            case .string(let s): return Data(s.utf8)
            case .data(let d): return d
            }
        }
    }
    public init(_ dictionary: [String: Data]) {
        self.init()
        for (k, v) in dictionary { _ = setEntry(.data(v), for: k) }
    }
    public init(_ entries: [String: Entry]) {
        self.init()
        for (k, v) in entries { _ = setEntry(v, for: k) }
    }
    /// keys are case-insensitive (RFC 6763 §6.4)
    func _key(_ key: String) -> String? { dictionary.keys.first { $0.caseInsensitiveCompare(key) == .orderedSame } }
    public func getEntry(for key: String) -> Entry? {
        guard let k = _key(key), let v = dictionary[k] else { return nil }
        if let d = _binary[k] { return .data(d) }
        if _bare.contains(k) { return Entry.none }
        return v.isEmpty ? .empty : .string(v)
    }
    @discardableResult public mutating func setEntry(_ entry: Entry, for key: String) -> Bool {
        guard !key.isEmpty, !key.contains("="), key.utf8.count <= 255 else { return false }
        if let old = _key(key) { dictionary.removeValue(forKey: old) }
        _binary.removeValue(forKey: key); _bare.remove(key)
        switch entry {
        case .none: dictionary[key] = ""; _bare.insert(key)
        case .empty: dictionary[key] = ""
        case .string(let s): dictionary[key] = s
        case .data(let d):
            if let s = String(data: d, encoding: .utf8) { dictionary[key] = s } else { dictionary[key] = ""; _binary[key] = d }
        }
        return true
    }
    /// iOS 26.4: every entry
    public var entries: [String: Entry] { Dictionary(uniqueKeysWithValues: dictionary.keys.map { ($0, getEntry(for: $0) ?? Entry.none) }) }
    /// iOS 26.4: every value as bytes (keys alone have none)
    public var dataDictionary: [String: Data] { entries.compactMapValues { $0.data } }
}

/// decodes a Decodable type from a TXT record (iOS 18): each property is a key, its value the entry's text
public struct TXTRecordDecoder: Sendable {
    public init() {}
    public func decode<T: Decodable>(_ type: T.Type, from txtRecord: NWTXTRecord) throws -> T {
        try T(from: _TXTDecoder(record: txtRecord, codingPath: []))
    }
}
struct _TXTDecoder: Decoder {
    let record: NWTXTRecord
    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> { KeyedDecodingContainer(_TXTKeyed<Key>(record: record, codingPath: codingPath)) }
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "a TXT record has no lists"))
    }
    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(Any.self, .init(codingPath: codingPath, debugDescription: "a TXT record is keyed"))
    }
}
struct _TXTKeyed<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let record: NWTXTRecord
    var codingPath: [any CodingKey]
    var allKeys: [Key] { record.dictionary.keys.compactMap { Key(stringValue: $0) } }
    func contains(_ key: Key) -> Bool { record.getEntry(for: key.stringValue) != nil }
    func text(_ key: Key) throws -> String {
        guard let e = record.getEntry(for: key.stringValue) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "no entry \(key.stringValue)"))
        }
        switch e {
        case .string(let s): return s
        case .none, .empty: return ""
        case .data(let d): return String(decoding: d, as: UTF8.self)
        }
    }
    func value<T: LosslessStringConvertible>(_ key: Key) throws -> T {
        let s = try text(key)
        guard let v = T(s) else { throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "\"\(s)\" is not a \(T.self)") }
        return v
    }
    func decodeNil(forKey key: Key) throws -> Bool { record.getEntry(for: key.stringValue) == nil }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        // a key alone means true (RFC 6763 §6.4)
        if case .none? = record.getEntry(for: key.stringValue) { return true }
        switch try text(key).lowercased() {
        case "1", "true", "yes", "on", "": return true
        case "0", "false", "no", "off": return false
        default: throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "not a Bool")
        }
    }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try text(key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try value(key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try value(key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try value(key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try value(key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try value(key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try value(key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try value(key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try value(key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try value(key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try value(key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try value(key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try value(key) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        if T.self == Data.self, let d = record.getEntry(for: key.stringValue)?.data { return d as! T }
        return try T(from: _TXTValueDecoder(text: try text(key), codingPath: codingPath + [key]))
    }
    func nestedContainer<N: CodingKey>(keyedBy type: N.Type, forKey key: Key) throws -> KeyedDecodingContainer<N> {
        throw DecodingError.typeMismatch([String: Any].self, .init(codingPath: codingPath + [key], debugDescription: "a TXT record is flat"))
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath + [key], debugDescription: "a TXT record has no lists"))
    }
    func superDecoder() throws -> any Decoder { _TXTDecoder(record: record, codingPath: codingPath) }
    func superDecoder(forKey key: Key) throws -> any Decoder { _TXTDecoder(record: record, codingPath: codingPath + [key]) }
}
/// one entry's text, for values decoded through their own init(from:) (enums with raw values, wrappers)
struct _TXTValueDecoder: Decoder, SingleValueDecodingContainer {
    let text: String
    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch([String: Any].self, .init(codingPath: codingPath, debugDescription: "a TXT value is text"))
    }
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "a TXT value is text"))
    }
    func singleValueContainer() throws -> any SingleValueDecodingContainer { self }
    func decodeNil() -> Bool { false }
    func value<T: LosslessStringConvertible>() throws -> T {
        guard let v = T(text) else { throw DecodingError.dataCorruptedError(in: self, debugDescription: "\"\(text)\" is not a \(T.self)") }
        return v
    }
    func decode(_ type: Bool.Type) throws -> Bool { ["1", "true", "yes", "on", ""].contains(text.lowercased()) }
    func decode(_ type: String.Type) throws -> String { text }
    func decode(_ type: Double.Type) throws -> Double { try value() }
    func decode(_ type: Float.Type) throws -> Float { try value() }
    func decode(_ type: Int.Type) throws -> Int { try value() }
    func decode(_ type: Int8.Type) throws -> Int8 { try value() }
    func decode(_ type: Int16.Type) throws -> Int16 { try value() }
    func decode(_ type: Int32.Type) throws -> Int32 { try value() }
    func decode(_ type: Int64.Type) throws -> Int64 { try value() }
    func decode(_ type: UInt.Type) throws -> UInt { try value() }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try value() }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try value() }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try value() }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try value() }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: self) }
}

// MARK: - browsers and listeners

extension NWBrowser.Result.Change {
    /// the change from one result to another: added, removed, identical or changed
    public init(between old: NWBrowser.Result?, _ new: NWBrowser.Result?) {
        switch (old, new) {
        case (nil, let n?): self = .added(n)
        case (let o?, nil): self = .removed(o)
        case (let o?, let n?):
            if o == n { self = .identical; return }
            var flags: Flags = []
            if o.metadata != n.metadata { flags.insert(.metadataChanged) }
            if Set(n.interfaces).subtracting(o.interfaces).isEmpty == false { flags.insert(.interfaceAdded) }
            if Set(o.interfaces).subtracting(n.interfaces).isEmpty == false { flags.insert(.interfaceRemoved) }
            self = .changed(old: o, new: n, flags: flags)
        case (nil, nil): self = .identical
        }
    }
}

extension NWListener {
    /// the Bonjour type isim advertises an application service under
    static func _applicationServiceType(_ name: String) -> String {
        let label = String(name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(15))
        return "_\(label.isEmpty ? "app" : label)._tcp"
    }
    /// iOS 16: a listener for devices that pick this app (isim: a Bonjour service of the app's own type)
    public convenience init(applicationService name: String, using parameters: NWParameters = .applicationService) throws {
        try self.init(service: Service(applicationService: name), using: parameters)
    }
}

extension NWParameters {
    /// iOS 16: parameters for connecting to this app on other devices (TCP with peer-to-peer allowed)
    public static var applicationService: NWParameters {
        let p = NWParameters.tcp
        p.includePeerToPeer = true
        return p
    }
    /// iOS 15: QUIC connections with these application protocols
    public static func quic(alpn: [String]) -> NWParameters { NWParameters(quic: NWProtocolQUIC.Options(alpn: alpn)) }
    /// iOS 16: QUIC datagram connections with these application protocols
    public static func quicDatagram(alpn: [String]) -> NWParameters {
        let o = NWProtocolQUIC.Options(alpn: alpn)
        o.isDatagram = true
        if o.maxDatagramFrameSize == 0 { o.maxDatagramFrameSize = 65535 }
        return NWParameters(quic: o)
    }

    /// the privacy requirements of a set of connections (iOS 14). Kept with the parameters: isim does not log
    /// connections, keeps no TLS session cache, and resolves names with the host's resolver
    public final class PrivacyContext: @unchecked Sendable {
        /// a DNS-over-TLS or DNS-over-HTTPS server
        public enum ResolverConfiguration: Sendable, Hashable {
            case https(URL, serverAddresses: [NWEndpoint])
            case tls(NWEndpoint, serverAddresses: [NWEndpoint])
        }
        public static let `default` = PrivacyContext(description: "default")
        let description: String
        var loggingDisabled = false
        var encryptedResolution: (required: Bool, fallback: ResolverConfiguration?) = (false, nil)
        /// iOS 17: proxies for the connections of this context
        public var proxyConfigurations: [ProxyConfiguration] = []
        public init(description: String) { self.description = description }
        public func disableLogging() { loggingDisabled = true }
        public func flushCache() {}
        public func requireEncryptedNameResolution(_ requireEncryption: Bool, fallbackResolver: ResolverConfiguration?) {
            encryptedResolution = (requireEncryption, fallbackResolver)
        }
    }
}

/// a proxy for a privacy context's connections (iOS 17): relays, Oblivious HTTP, HTTP CONNECT or SOCKSv5. Kept with the
/// context; isim's connections go direct
public struct ProxyConfiguration: Sendable, Hashable {
    /// one relay server; relays can be chained
    public struct RelayHop: Sendable, Hashable {
        let http3: NWEndpoint?, http2: NWEndpoint?
        let headers: [String: String]
        public init(http2RelayEndpoint: NWEndpoint, tlsOptions: NWProtocolTLS.Options = .init(), additionalHTTPHeaderFields: [String: String] = [:]) {
            http3 = nil; http2 = http2RelayEndpoint; headers = additionalHTTPHeaderFields
        }
        public init(http3RelayEndpoint: NWEndpoint, http2RelayEndpoint: NWEndpoint? = nil, tlsOptions: NWProtocolTLS.Options = .init(),
                    additionalHTTPHeaderFields: [String: String] = [:]) {
            http3 = http3RelayEndpoint; http2 = http2RelayEndpoint; headers = additionalHTTPHeaderFields
        }
    }
    enum Kind: Sendable, Hashable {
        case relays([RelayHop]), oblivious(RelayHop, path: String, keyConfig: Data), httpConnect(NWEndpoint), socks(NWEndpoint)
    }
    let kind: Kind
    var credential: [String] = []
    /// whether connections may go direct when the proxy fails (not by default)
    public var allowFailover = false
    /// the domains that use the proxy (empty: all)
    public var matchDomains: [String] = []
    /// the domains that never use it
    public var excludedDomains: [String] = []
    public init(relayHops: [RelayHop]) { kind = .relays(relayHops) }
    public init(obliviousHTTPRelay: RelayHop, relayResourcePath: String, gatewayKeyConfig: Data, matchDomains: [String]) {
        kind = .oblivious(obliviousHTTPRelay, path: relayResourcePath, keyConfig: gatewayKeyConfig); self.matchDomains = matchDomains
    }
    public init(httpCONNECTProxy: NWEndpoint, tlsOptions: NWProtocolTLS.Options? = nil) { kind = .httpConnect(httpCONNECTProxy) }
    public init(socksv5Proxy: NWEndpoint) { kind = .socks(socksv5Proxy) }
    /// a user name and password for the proxy
    public mutating func applyCredential(username: String, password: String) { credential = [username, password] }
}

// MARK: - TLS cipher suites (Security's SecProtocolTypes)

/// a TLS cipher suite (IANA values). isim's TLS is the host's OpenSSL with its own suites: the ones an app lists are kept
public enum tls_ciphersuite_t: UInt16, Sendable {
    case RSA_WITH_3DES_EDE_CBC_SHA = 0x000A
    case RSA_WITH_AES_128_CBC_SHA = 0x002F
    case RSA_WITH_AES_256_CBC_SHA = 0x0035
    case RSA_WITH_AES_128_GCM_SHA256 = 0x009C
    case RSA_WITH_AES_256_GCM_SHA384 = 0x009D
    case RSA_WITH_AES_128_CBC_SHA256 = 0x003C
    case RSA_WITH_AES_256_CBC_SHA256 = 0x003D
    case ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA = 0xC008
    case ECDHE_ECDSA_WITH_AES_128_CBC_SHA = 0xC009
    case ECDHE_ECDSA_WITH_AES_256_CBC_SHA = 0xC00A
    case ECDHE_RSA_WITH_3DES_EDE_CBC_SHA = 0xC012
    case ECDHE_RSA_WITH_AES_128_CBC_SHA = 0xC013
    case ECDHE_RSA_WITH_AES_256_CBC_SHA = 0xC014
    case ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 = 0xC023
    case ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 = 0xC024
    case ECDHE_RSA_WITH_AES_128_CBC_SHA256 = 0xC027
    case ECDHE_RSA_WITH_AES_256_CBC_SHA384 = 0xC028
    case ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 = 0xC02B
    case ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 = 0xC02C
    case ECDHE_RSA_WITH_AES_128_GCM_SHA256 = 0xC02F
    case ECDHE_RSA_WITH_AES_256_GCM_SHA384 = 0xC030
    case ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 = 0xCCA8
    case ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 = 0xCCA9
    case AES_128_GCM_SHA256 = 0x1301
    case AES_256_GCM_SHA384 = 0x1302
    case CHACHA20_POLY1305_SHA256 = 0x1303
}
/// a named set of cipher suites
public enum tls_ciphersuite_group_t: UInt16, Sendable {
    case `default` = 0, compatibility = 1, legacy = 2, ats = 3, ats_compatibility = 4
}
public func sec_protocol_options_append_tls_ciphersuite(_ options: sec_protocol_options_t, _ ciphersuite: tls_ciphersuite_t) {
    options.cipherSuites.append(ciphersuite.rawValue)
}
public func sec_protocol_options_append_tls_ciphersuite_group(_ options: sec_protocol_options_t, _ group: tls_ciphersuite_group_t) {
    options.cipherSuiteGroups.append(group.rawValue)
}
