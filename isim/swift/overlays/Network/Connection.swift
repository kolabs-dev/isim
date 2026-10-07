// isim Network framework: endpoints, parameters and protocol options, NWConnection (TCP, UDP, TLS client),
// NWListener (TCP and UDP), Bonjour advertising/browsing (NWListener.service, NWBrowser) and NWError.
//
// Connections are BSD sockets of the host (isim's libSystem) driven on background queues; handlers run on the
// queue passed to start(queue:). TLS client connections use the host's OpenSSL (host_tls.c): the host's CA
// store and host-name check, or the app's sec_protocol_options verify block. Adapted: Bonjour is a local
// registry shared by the apps of this isim device ($ISIM_DATA/Library/isim/Bonjour), not multicast DNS — services
// are found by apps on the same simulated device only. Not provided: TLS listeners (server identities), DTLS,
// QUIC, NWProtocolWebSocket/NWProtocolFramer, multicast groups.
@_exported import Foundation
import isim_host

// MARK: - errors

/// POSIX error codes (Darwin values) as NWError reports them.
public enum POSIXErrorCode: Int32, Sendable {
    case EPERM = 1, ENOENT = 2, EINTR = 4, EIO = 5, EBADF = 9, EAGAIN = 35, ENOMEM = 12, EACCES = 13, EINVAL = 22, EPIPE = 32
    case EADDRINUSE = 48, EADDRNOTAVAIL = 49, ENETDOWN = 50, ENETUNREACH = 51, ECONNABORTED = 53, ECONNRESET = 54, ENOBUFS = 55
    case EISCONN = 56, ENOTCONN = 57, ETIMEDOUT = 60, ECONNREFUSED = 61, EHOSTUNREACH = 65, ECANCELED = 89, EMSGSIZE = 40, ENOTSUP = 45
}

public enum NWError: Error, Equatable, CustomDebugStringConvertible, Sendable {
    case posix(POSIXErrorCode)
    case dns(Int32)
    case tls(Int32)
    case wifiAware(Int32)
    public var debugDescription: String {
        switch self {
        case .posix(let c): return "POSIXErrorCode(rawValue: \(c.rawValue)): \(String(cString: strerror(_NWErrno.host(c.rawValue))))"
        case .dns(let e): return "DNSServiceErrorType(\(e))"
        case .tls(let e): return "OSStatus(\(e))"
        case .wifiAware(let e): return "WiFiAware(\(e))"
        }
    }
    public var errorCode: Int32 {
        switch self { case .posix(let c): return c.rawValue; case .dns(let e), .tls(let e), .wifiAware(let e): return e }
    }
}
enum _NWErrno {
    /// errno from the libSystem calls is already Darwin's
    static func posix(_ e: Int32) -> NWError { .posix(POSIXErrorCode(rawValue: e) ?? .EIO) }
    static func host(_ darwin: Int32) -> Int32 { darwin }
}

// MARK: - addresses & endpoints

public protocol IPAddress: CustomDebugStringConvertible {
    init?(_ rawValue: Data, _ interface: NWInterface?)
    var rawValue: Data { get }
    var interface: NWInterface? { get }
    var isLoopback: Bool { get }
    var isLinkLocal: Bool { get }
    var isMulticast: Bool { get }
}

public struct IPv4Address: IPAddress, Hashable, Sendable {
    public let rawValue: Data
    public let interface: NWInterface?
    public init?(_ rawValue: Data, _ interface: NWInterface? = nil) { guard rawValue.count == 4 else { return nil }; self.rawValue = rawValue; self.interface = interface }
    public init?(_ string: String) {
        var a = in_addr()
        guard inet_pton(AF_INET, string, &a) == 1 else { return nil }
        rawValue = withUnsafeBytes(of: &a) { Data($0) }; interface = nil
    }
    public static let any = IPv4Address(Data([0, 0, 0, 0]))!
    public static let broadcast = IPv4Address(Data([255, 255, 255, 255]))!
    public static let loopback = IPv4Address(Data([127, 0, 0, 1]))!
    public static let allHostsGroup = IPv4Address(Data([224, 0, 0, 1]))!
    public var isLoopback: Bool { rawValue.first == 127 }
    public var isLinkLocal: Bool { rawValue.prefix(2) == Data([169, 254]) }
    public var isMulticast: Bool { (rawValue.first ?? 0) >> 4 == 14 }
    public var debugDescription: String { rawValue.map(String.init).joined(separator: ".") }
}
public struct IPv6Address: IPAddress, Hashable, Sendable {
    public let rawValue: Data
    public let interface: NWInterface?
    public init?(_ rawValue: Data, _ interface: NWInterface? = nil) { guard rawValue.count == 16 else { return nil }; self.rawValue = rawValue; self.interface = interface }
    public init?(_ string: String) {
        var a = in6_addr()
        guard inet_pton(AF_INET6, string, &a) == 1 else { return nil }
        rawValue = withUnsafeBytes(of: &a) { Data($0) }; interface = nil
    }
    public static let any = IPv6Address(Data(repeating: 0, count: 16))!
    public static let loopback = IPv6Address(Data(repeating: 0, count: 15) + Data([1]))!
    public var isLoopback: Bool { self == IPv6Address.loopback }
    public var isLinkLocal: Bool { rawValue.prefix(2) == Data([0xfe, 0x80]) }
    public var isMulticast: Bool { rawValue.first == 0xff }
    public var debugDescription: String {
        var a = in6_addr(); rawValue.withUnsafeBytes { src in withUnsafeMutableBytes(of: &a) { dst in dst.copyMemory(from: src) } }
        var buf = [CChar](repeating: 0, count: 64)
        _ = inet_ntop(AF_INET6, &a, &buf, 64)
        return String(cString: buf)
    }
}

public enum NWEndpoint: Hashable, CustomDebugStringConvertible, Sendable {
    case hostPort(host: Host, port: Port)
    case service(name: String, type: String, domain: String, interface: NWInterface?)
    case unix(path: String)
    case url(URL)
    case opaque(String)

    public enum Host: Hashable, CustomDebugStringConvertible, ExpressibleByStringLiteral, Sendable {
        case name(String, NWInterface?)
        case ipv4(IPv4Address)
        case ipv6(IPv6Address)
        public init(_ string: String) {
            if let a = IPv4Address(string) { self = .ipv4(a) } else if let a = IPv6Address(string) { self = .ipv6(a) } else { self = .name(string, nil) }
        }
        public init(stringLiteral value: String) { self.init(value) }
        public var debugDescription: String {
            switch self { case .name(let n, _): return n; case .ipv4(let a): return a.debugDescription; case .ipv6(let a): return a.debugDescription }
        }
        public var interface: NWInterface? { if case .name(_, let i) = self { return i }; return nil }
    }
    public struct Port: Hashable, CustomDebugStringConvertible, ExpressibleByIntegerLiteral, RawRepresentable, Sendable {
        public let rawValue: UInt16
        public init?(rawValue: UInt16) { self.rawValue = rawValue }
        public init(integerLiteral value: UInt16) { rawValue = value }
        public init?(_ string: String) { guard let v = UInt16(string) else { return nil }; rawValue = v }
        public static let any: Port = 0
        public static let ssh: Port = 22, smtp: Port = 25, http: Port = 80, pop: Port = 110, imap: Port = 143, https: Port = 443, imaps: Port = 993, socks: Port = 1080
        public var debugDescription: String { String(rawValue) }
    }
    public var debugDescription: String {
        switch self {
        case .hostPort(let h, let p): if case .ipv6 = h { return "[\(h)]:\(p)" }; return "\(h):\(p)"
        case .service(let n, let t, let d, _): return "\(n).\(t)\(d)"
        case .unix(let p): return p
        case .url(let u): return u.absoluteString
        case .opaque(let s): return s
        }
    }
    public var interface: NWInterface? { if case .service(_, _, _, let i) = self { return i }; return nil }
}

// MARK: - protocols & parameters

public class NWProtocolDefinition: Equatable, CustomDebugStringConvertible, @unchecked Sendable {
    public let name: String
    init(_ n: String) { name = n }
    public static func == (a: NWProtocolDefinition, b: NWProtocolDefinition) -> Bool { a.name == b.name }
    public var debugDescription: String { name }
}
public class NWProtocolOptions: @unchecked Sendable { init() {} }
public class NWProtocolMetadata: @unchecked Sendable { init() {} }
public enum NWProtocolIP {
    public static let definition = NWProtocolDefinition("ip")
    public final class Options: NWProtocolOptions, @unchecked Sendable {
        public enum Version: Sendable { case any, v4, v6 }
        public var version: Version = .any
        public var hopLimit: UInt8 = 0
        public var useMinimumMTU = false
        public var disableFragmentation = false
        public var shouldCalculateReceiveTime = false
        public var localAddressPreference: Int = 0
    }
    public final class Metadata: NWProtocolMetadata, @unchecked Sendable {
        public var ecnFlag: Int = 0
        public var serviceClass: NWParameters.ServiceClass = .bestEffort
        public override init() { super.init() }
    }
}
public enum NWProtocolTCP {
    public static let definition = NWProtocolDefinition("tcp")
    public final class Options: NWProtocolOptions, @unchecked Sendable {
        public var noDelay = false
        public var noPush = false
        public var noOptions = false
        public var enableKeepalive = false
        public var keepaliveCount = 0
        public var keepaliveIdle = 0
        public var keepaliveInterval = 0
        public var maximumSegmentSize = 0
        public var connectionTimeout = 0
        public var persistTimeout = 0
        public var connectionDropTime = 0
        public var retransmitFinDrop = false
        public var disableAckStretching = false
        public var enableFastOpen = false
        public var disableECN = false
        public var multipathForceVersion: Int?
        public override init() { super.init() }
    }
    public final class Metadata: NWProtocolMetadata, @unchecked Sendable {
        public internal(set) var availableReceiveBuffer: UInt32 = 0
        public internal(set) var availableSendBuffer: UInt32 = 0
    }
}
public enum NWProtocolUDP {
    public static let definition = NWProtocolDefinition("udp")
    public final class Options: NWProtocolOptions, @unchecked Sendable {
        public var preferNoChecksum = false
        public override init() { super.init() }
    }
    public final class Metadata: NWProtocolMetadata, @unchecked Sendable { public override init() { super.init() } }
}

/// Security's TLS option/metadata objects (the parts NWProtocolTLS uses).
public final class sec_protocol_options_t: @unchecked Sendable {
    var verifyBlock: ((sec_protocol_metadata_t, sec_trust_t, @escaping sec_protocol_verify_complete_t) -> Void)?
    var verifyQueue: DispatchQueue?
    var alpn: [String] = []
    var minVersion: tls_protocol_version_t = .TLSv12
    var serverName: String?
    var peerAuthenticationRequired = true
    init() {}
}
public final class sec_protocol_metadata_t: @unchecked Sendable {
    var version = "", alpn = "", serverName: String?
    init() {}
}
public final class sec_trust_t: @unchecked Sendable { let host: String?; init(host: String?) { self.host = host } }
public typealias sec_protocol_verify_complete_t = (Bool) -> Void
public enum tls_protocol_version_t: UInt16, Sendable { case TLSv10 = 0x0301, TLSv11 = 0x0302, TLSv12 = 0x0303, TLSv13 = 0x0304, DTLSv10 = 0xfeff, DTLSv12 = 0xfefd }
public func sec_protocol_options_set_verify_block(_ options: sec_protocol_options_t, _ verifyBlock: @escaping (sec_protocol_metadata_t, sec_trust_t, @escaping sec_protocol_verify_complete_t) -> Void, _ queue: DispatchQueue) {
    options.verifyBlock = verifyBlock; options.verifyQueue = queue
}
public func sec_protocol_options_add_tls_application_protocol(_ options: sec_protocol_options_t, _ applicationProtocol: UnsafePointer<CChar>) {
    options.alpn.append(String(cString: applicationProtocol))
}
public func sec_protocol_options_set_min_tls_protocol_version(_ options: sec_protocol_options_t, _ version: tls_protocol_version_t) { options.minVersion = version }
public func sec_protocol_options_set_tls_server_name(_ options: sec_protocol_options_t, _ serverName: UnsafePointer<CChar>) { options.serverName = String(cString: serverName) }
public func sec_protocol_options_set_peer_authentication_required(_ options: sec_protocol_options_t, _ required: Bool) { options.peerAuthenticationRequired = required }
public func sec_protocol_metadata_get_negotiated_protocol(_ metadata: sec_protocol_metadata_t) -> UnsafePointer<CChar>? {
    metadata.alpn.isEmpty ? nil : UnsafePointer(strdup(metadata.alpn))
}
public func sec_protocol_metadata_get_negotiated_tls_protocol_version(_ metadata: sec_protocol_metadata_t) -> tls_protocol_version_t {
    metadata.version == "TLSv1.3" ? .TLSv13 : metadata.version == "TLSv1.2" ? .TLSv12 : metadata.version == "TLSv1.1" ? .TLSv11 : .TLSv10
}
public func sec_protocol_metadata_get_server_name(_ metadata: sec_protocol_metadata_t) -> UnsafePointer<CChar>? {
    metadata.serverName.map { UnsafePointer(strdup($0)) }
}

public enum NWProtocolTLS {
    public static let definition = NWProtocolDefinition("tls")
    public final class Options: NWProtocolOptions, @unchecked Sendable {
        public let securityProtocolOptions = sec_protocol_options_t()
        public override init() { super.init() }
    }
    public final class Metadata: NWProtocolMetadata, @unchecked Sendable {
        public let securityProtocolMetadata: sec_protocol_metadata_t
        init(_ m: sec_protocol_metadata_t) { securityProtocolMetadata = m }
    }
}

public final class NWParameters: CustomDebugStringConvertible, @unchecked Sendable {
    public enum ServiceClass: Sendable { case bestEffort, background, interactiveVideo, interactiveVoice, responsiveData, signaling }
    public enum MultipathServiceType: Sendable { case disabled, handover, interactive, aggregate }
    public enum ExpiredDNSBehavior: Sendable { case systemDefault, allow, prohibit }
    public final class ProtocolStack: @unchecked Sendable {
        public var applicationProtocols: [NWProtocolOptions] = []
        public var transportProtocol: NWProtocolOptions?
        public var internetProtocol: NWProtocolOptions? = NWProtocolIP.Options()
    }
    let tls: NWProtocolTLS.Options?
    let isUDP: Bool
    public var defaultProtocolStack = ProtocolStack()
    public var requiredInterfaceType: NWInterface.InterfaceType = .other
    public var requiredInterface: NWInterface?
    public var prohibitedInterfaceTypes: [NWInterface.InterfaceType]?
    public var prohibitedInterfaces: [NWInterface]?
    public var prohibitExpensivePaths = false
    public var prohibitConstrainedPaths = false
    public var preferNoProxies = false
    public var requiredLocalEndpoint: NWEndpoint?
    public var allowLocalEndpointReuse = false
    public var acceptLocalOnly = false
    public var includePeerToPeer = false
    public var allowFastOpen = false
    public var serviceClass: ServiceClass = .bestEffort
    public var multipathServiceType: MultipathServiceType = .disabled
    public var expiredDNSBehavior: ExpiredDNSBehavior = .systemDefault
    public var attribution: Int = 0

    public init() { tls = nil; isUDP = false; defaultProtocolStack.transportProtocol = NWProtocolTCP.Options() }
    public init(tls: NWProtocolTLS.Options?, tcp: NWProtocolTCP.Options = NWProtocolTCP.Options()) {
        self.tls = tls; isUDP = false
        defaultProtocolStack.transportProtocol = tcp
        if let tls { defaultProtocolStack.applicationProtocols = [tls] }
    }
    public init(dtls: NWProtocolTLS.Options?, udp: NWProtocolUDP.Options = NWProtocolUDP.Options()) {
        tls = dtls; isUDP = true
        defaultProtocolStack.transportProtocol = udp
    }
    public static var tcp: NWParameters { NWParameters(tls: nil) }
    public static var udp: NWParameters { NWParameters(dtls: nil) }
    public static var tls: NWParameters { NWParameters(tls: NWProtocolTLS.Options()) }
    public static var dtls: NWParameters { NWParameters(dtls: NWProtocolTLS.Options()) }
    public func copy() -> NWParameters {
        let p = isUDP ? NWParameters(dtls: tls, udp: (defaultProtocolStack.transportProtocol as? NWProtocolUDP.Options) ?? NWProtocolUDP.Options())
                      : NWParameters(tls: tls, tcp: (defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options) ?? NWProtocolTCP.Options())
        p.allowLocalEndpointReuse = allowLocalEndpointReuse; p.requiredLocalEndpoint = requiredLocalEndpoint; p.includePeerToPeer = includePeerToPeer
        p.acceptLocalOnly = acceptLocalOnly; p.serviceClass = serviceClass
        return p
    }
    var tcpOptions: NWProtocolTCP.Options? { defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options }
    public var debugDescription: String { isUDP ? (tls == nil ? "udp" : "dtls") : (tls == nil ? "tcp" : "tls") }
}

// MARK: - sockets helpers

enum _NWSock {
    /// resolves an endpoint to socket addresses (Bonjour services through the local registry)
    static func resolve(_ e: NWEndpoint, udp: Bool) -> Result<[(Data, Int32)], NWError> {
        switch e {
        case .hostPort(let host, let port):
            let name: String
            switch host { case .name(let n, _): name = n; case .ipv4(let a): name = a.debugDescription; case .ipv6(let a): name = a.debugDescription }
            var hints = addrinfo()
            hints.ai_socktype = udp ? SOCK_DGRAM : SOCK_STREAM
            hints.ai_family = AF_UNSPEC
            var res: UnsafeMutablePointer<addrinfo>?
            let rc = getaddrinfo(name, String(port.rawValue), &hints, &res)
            guard rc == 0, let first = res else { return .failure(.dns(-65554)) }   /* kDNSServiceErr_NoSuchRecord */
            var out: [(Data, Int32)] = []
            var p: UnsafeMutablePointer<addrinfo>? = first
            while let a = p {
                if let sa = a.pointee.ai_addr { out.append((Data(bytes: sa, count: Int(a.pointee.ai_addrlen)), a.pointee.ai_family)) }
                p = a.pointee.ai_next
            }
            freeaddrinfo(first)
            // IPv4 first (like happy eyeballs on a typical isim host)
            out.sort { $0.1 == AF_INET && $1.1 != AF_INET }
            return out.isEmpty ? .failure(.dns(-65554)) : .success(out)
        case .service(let name, let type, _, _):
            guard let s = _NWBonjour.lookup(name: name, type: type) else { return .failure(.dns(-65554)) }
            return resolve(.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: s.port) ?? .any), udp: udp)
        case .url(let u):
            let port = u.port.map { UInt16($0) } ?? (u.scheme == "https" ? 443 : 80)
            return resolve(.hostPort(host: NWEndpoint.Host(u.host ?? "localhost"), port: NWEndpoint.Port(rawValue: port)!), udp: udp)
        default:
            return .failure(.posix(.EINVAL))
        }
    }
    static func endpoint(_ sa: UnsafeRawPointer, _ len: Int) -> NWEndpoint {
        let fam = sa.load(fromByteOffset: 1, as: UInt8.self)
        if Int32(fam) == AF_INET6 {
            let s = sa.load(as: sockaddr_in6.self)
            var a = s.sin6_addr
            return .hostPort(host: .ipv6(IPv6Address(withUnsafeBytes(of: &a) { Data($0) })!), port: NWEndpoint.Port(rawValue: UInt16(bigEndian: s.sin6_port))!)
        }
        let s = sa.load(as: sockaddr_in.self)
        var a = s.sin_addr
        return .hostPort(host: .ipv4(IPv4Address(withUnsafeBytes(of: &a) { Data($0) })!), port: NWEndpoint.Port(rawValue: UInt16(bigEndian: s.sin_port))!)
    }
    static func peer(_ fd: Int32) -> NWEndpoint? {
        var ss = sockaddr_storage(); var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let r = withUnsafeMutablePointer(to: &ss) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getpeername(fd, $0, &len) } }
        return r == 0 ? withUnsafeBytes(of: &ss) { endpoint($0.baseAddress!, Int(len)) } : nil
    }
    static func local(_ fd: Int32) -> NWEndpoint? {
        var ss = sockaddr_storage(); var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let r = withUnsafeMutablePointer(to: &ss) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) } }
        return r == 0 ? withUnsafeBytes(of: &ss) { endpoint($0.baseAddress!, Int(len)) } : nil
    }
    static func setTimeout(_ fd: Int32, _ opt: Int32, seconds: Int) {
        var tv = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, opt, &tv, socklen_t(MemoryLayout<timeval>.size))
    }
}

// MARK: - NWConnection

public final class NWConnection: CustomDebugStringConvertible, @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case setup, waiting(NWError), preparing, ready, failed(NWError), cancelled
    }
    public enum SendCompletion: Sendable {
        case contentProcessed(@Sendable (NWError?) -> Void)
        case idempotent
    }
    public final class ContentContext: @unchecked Sendable {
        public let identifier: String
        public let isFinal: Bool
        public var expirationMilliseconds: UInt64
        public var relativePriority: Double
        public var antecedent: ContentContext?
        public var protocolMetadata: [NWProtocolMetadata]
        public init(identifier: String, expiration: UInt64 = 0, priority: Double = 0.5, isFinal: Bool = false, antecedent: ContentContext? = nil,
                    metadata: [NWProtocolMetadata]? = []) {
            self.identifier = identifier; expirationMilliseconds = expiration; relativePriority = priority; self.isFinal = isFinal
            self.antecedent = antecedent; protocolMetadata = metadata ?? []
        }
        public static let defaultMessage = ContentContext(identifier: "default_message")
        public static let finalMessage = ContentContext(identifier: "final_message", isFinal: true)
        public static let defaultStream = ContentContext(identifier: "default_stream")
        public func protocolMetadata(definition: NWProtocolDefinition) -> NWProtocolMetadata? { nil }
    }

    public let endpoint: NWEndpoint
    public let parameters: NWParameters
    public private(set) var queue: DispatchQueue?
    public var state: State { lock.lock(); defer { lock.unlock() }; return _state }
    public var stateUpdateHandler: (@Sendable (State) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _stateHandler }
        set { lock.lock(); _stateHandler = newValue; lock.unlock() }
    }
    public var viabilityUpdateHandler: (@Sendable (Bool) -> Void)?
    public var betterPathUpdateHandler: (@Sendable (Bool) -> Void)?
    public var pathUpdateHandler: (@Sendable (NWPath) -> Void)?
    public var currentPath: NWPath? {
        guard state == .ready else { return nil }
        var p = NWPath._current(required: nil, prohibited: [])
        p.localEndpoint = fd >= 0 ? _NWSock.local(fd) : nil
        p.remoteEndpoint = fd >= 0 ? _NWSock.peer(fd) : endpoint
        return p
    }
    public var maximumDatagramSize: Int { parameters.isUDP ? 65507 : 0 }
    public var debugDescription: String { "[C\(id) \(endpoint) \(parameters)]" }

    let lock = NSLock()
    var _state = State.setup
    var _stateHandler: (@Sendable (State) -> Void)?
    var fd: Int32 = -1
    var tls: OpaquePointer?
    var tlsMeta: sec_protocol_metadata_t?
    let ioQueue: DispatchQueue, readQueue: DispatchQueue
    let id: Int
    nonisolated(unsafe) static var counter = 0
    /// datagram connections from an NWListener (UDP): sends go through the listener's socket
    var udpPeer: (send: (Data) -> Int, inbox: _NWInbox)?
    var acceptedFD: Int32 = -1

    public init(to endpoint: NWEndpoint, using parameters: NWParameters) {
        NWConnection.counter += 1; id = NWConnection.counter
        self.endpoint = endpoint; self.parameters = parameters
        ioQueue = DispatchQueue(label: "isim.NWConnection.io"); readQueue = DispatchQueue(label: "isim.NWConnection.read")
    }
    public convenience init(host: NWEndpoint.Host, port: NWEndpoint.Port, using parameters: NWParameters) {
        self.init(to: .hostPort(host: host, port: port), using: parameters)
    }
    init(accepted fd: Int32, peer: NWEndpoint, parameters: NWParameters) {
        NWConnection.counter += 1; id = NWConnection.counter
        endpoint = peer; self.parameters = parameters
        ioQueue = DispatchQueue(label: "isim.NWConnection.io"); readQueue = DispatchQueue(label: "isim.NWConnection.read")
        acceptedFD = fd
    }

    func setState(_ s: State) {
        lock.lock()
        if case .cancelled = _state { lock.unlock(); return }
        if _state == s { lock.unlock(); return }
        _state = s
        let h = _stateHandler, q = queue
        lock.unlock()
        if let h { (q ?? .main).async { h(s) } }
    }

    public func start(queue: DispatchQueue) {
        lock.lock()
        guard self.queue == nil else { lock.unlock(); return }
        self.queue = queue
        lock.unlock()
        setState(.preparing)
        if udpPeer != nil { setState(.ready); return }
        if acceptedFD >= 0 { fd = acceptedFD; setState(.ready); return }
        ioQueue.async { self.connect() }
    }
    public func restart() {
        guard case .waiting = state else { return }
        setState(.preparing)
        ioQueue.async { self.connect() }
    }

    func connect() {
        let udp = parameters.isUDP
        if udp && parameters.tls != nil { setState(.failed(.posix(.ENOTSUP))); return }   /* DTLS is not provided */
        switch _NWSock.resolve(endpoint, udp: udp) {
        case .failure(let e): setState(.waiting(e)); return
        case .success(let addrs):
            var lastErr: Int32 = ECONNREFUSED
            for (sa, fam) in addrs {
                let s = socket(fam, udp ? SOCK_DGRAM : SOCK_STREAM, 0)
                guard s >= 0 else { lastErr = errno; continue }
                if !udp, let t = parameters.tcpOptions {
                    if t.noDelay { var one: Int32 = 1; setsockopt(s, IPPROTO_TCP, TCP_NODELAY, &one, 4) }
                    if t.enableKeepalive { var one: Int32 = 1; setsockopt(s, SOL_SOCKET, SO_KEEPALIVE, &one, 4) }
                    if t.connectionTimeout > 0 { _NWSock.setTimeout(s, SO_SNDTIMEO, seconds: t.connectionTimeout) }
                }
                let r = sa.withUnsafeBytes { Darwin_connect(s, $0.baseAddress!.assumingMemoryBound(to: sockaddr.self), socklen_t(sa.count)) }
                if r == 0 {
                    if !udp, let t = parameters.tcpOptions, t.connectionTimeout > 0 { _NWSock.setTimeout(s, SO_SNDTIMEO, seconds: 0) }
                    lock.lock(); let cancelled = _state == .cancelled; if !cancelled { fd = s }; lock.unlock()
                    if cancelled { close(s); return }
                    if let tlsOpts = parameters.tls { startTLS(tlsOpts.securityProtocolOptions); return }
                    setState(.ready)
                    return
                }
                lastErr = errno
                close(s)
            }
            setState(.waiting(_NWErrno.posix(lastErr == EINPROGRESS ? ETIMEDOUT : lastErr)))
        }
    }

    func startTLS(_ o: sec_protocol_options_t) {
        var host: String? = o.serverName
        if host == nil, case .hostPort(let h, _) = endpoint, case .name(let n, _) = h { host = n }
        let verifyByApp = o.verifyBlock != nil
        var err = [CChar](repeating: 0, count: 300)
        var code: Int32 = 0
        let alpn = o.alpn.joined(separator: ",")
        let t = isim_tls_connect(fd, host, verifyByApp || !o.peerAuthenticationRequired ? 0 : 1, alpn.isEmpty ? nil : alpn, Int32(o.minVersion.rawValue), &err, Int32(err.count), &code)
        guard let t else {
            print("isim: NWConnection TLS: \(String(cString: err))")
            setState(.failed(.tls(code)))
            return
        }
        tls = t
        let meta = sec_protocol_metadata_t()
        var v = [CChar](repeating: 0, count: 32), a = [CChar](repeating: 0, count: 64)
        isim_tls_info(t, &v, 32, &a, 64)
        meta.version = String(cString: v); meta.alpn = String(cString: a); meta.serverName = host
        tlsMeta = meta
        if let block = o.verifyBlock {
            let sem = DispatchSemaphore(value: 0)
            var ok = false
            (o.verifyQueue ?? .global()).async { block(meta, sec_trust_t(host: host)) { ok = $0; sem.signal() } }
            sem.wait()
            guard ok else { setState(.failed(.tls(-9807))); return }
        }
        setState(.ready)
    }

    public func metadata(definition: NWProtocolDefinition) -> NWProtocolMetadata? {
        if definition == NWProtocolTLS.definition, let m = tlsMeta { return NWProtocolTLS.Metadata(m) }
        if definition == NWProtocolTCP.definition, !parameters.isUDP { return NWProtocolTCP.Metadata() }
        return nil
    }

    // MARK: sending
    public func send(content: Data?, contentContext: ContentContext = .defaultMessage, isComplete: Bool = true, completion: SendCompletion) {
        let done: (NWError?) -> Void = { [weak self] e in
            if case .contentProcessed(let f) = completion { (self?.queue ?? .main).async { f(e) } }
        }
        ioQueue.async { [self] in
            guard state == .ready else { done(.posix(state == .cancelled ? .ECANCELED : .ENOTCONN)); return }
            if let d = content, !d.isEmpty {
                if let peer = udpPeer {
                    done(peer.send(d) < 0 ? _NWErrno.posix(errno) : nil); return
                }
                var off = 0
                let ok: Bool = d.withUnsafeBytes { raw in
                    while off < d.count {
                        let n: Int
                        if let t = tls { n = isim_tls_write(t, raw.baseAddress! + off, d.count - off) }
                        else { n = Darwin_send(fd, raw.baseAddress! + off, d.count - off) }
                        if n <= 0 { return false }
                        off += n
                        if parameters.isUDP { break }
                    }
                    return true
                }
                if !ok { done(_NWErrno.posix(errno == 0 ? EPIPE : errno)); return }
            }
            if !parameters.isUDP && isComplete && contentContext.isFinal { shutdown(fd, SHUT_WR) }
            done(nil)
        }
    }
    public func batch(_ block: () -> Void) { block() }

    // MARK: receiving
    public func receive(minimumIncompleteLength: Int, maximumLength: Int,
                        completion: @escaping @Sendable (Data?, ContentContext?, Bool, NWError?) -> Void) {
        readQueue.async { [self] in
            let r = readSome(min: max(1, minimumIncompleteLength), max: max(1, maximumLength))
            (queue ?? .main).async { completion(r.0, r.0 == nil && !r.1 ? nil : .defaultStream, r.1, r.2) }
        }
    }
    public func receiveMessage(completion: @escaping @Sendable (Data?, ContentContext?, Bool, NWError?) -> Void) {
        readQueue.async { [self] in
            if parameters.isUDP {
                let r = readSome(min: 1, max: 65536)
                (queue ?? .main).async { completion(r.0, .defaultMessage, true, r.2) }
                return
            }
            var all = Data()
            while true {
                let r = readSome(min: 1, max: 65536)
                if let d = r.0 { all.append(d) }
                if r.2 != nil { (queue ?? .main).async { completion(all.isEmpty ? nil : all, .finalMessage, true, r.2) }; return }
                if r.1 { (queue ?? .main).async { completion(all.isEmpty ? nil : all, .finalMessage, true, nil) }; return }
            }
        }
    }
    /// blocking read: (data, complete (EOF / datagram), error)
    func readSome(min: Int, max: Int) -> (Data?, Bool, NWError?) {
        while state == .preparing || state == .setup { usleep(5000) }
        guard state == .ready else { return (nil, false, .posix(state == .cancelled ? .ECANCELED : .ENOTCONN)) }
        if let peer = udpPeer {
            guard let d = peer.inbox.take() else { return (nil, false, .posix(.ECANCELED)) }
            return (d, true, nil)
        }
        var out = Data()
        var buf = [UInt8](repeating: 0, count: Swift.min(max, 65536))
        while out.count < min {
            let want = Swift.min(buf.count, max - out.count)
            let n: Int = buf.withUnsafeMutableBytes { b in
                if let t = tls { return isim_tls_read(t, b.baseAddress!, want) }
                return Darwin_recv(fd, b.baseAddress!, want)
            }
            if n > 0 {
                out.append(contentsOf: buf[0..<n])
                if parameters.isUDP { return (out, true, nil) }
                continue
            }
            if n == 0 { return (out.isEmpty ? nil : out, true, nil) }
            if state == .cancelled { return (out.isEmpty ? nil : out, false, .posix(.ECANCELED)) }
            let e = errno
            if e == EINTR || e == EAGAIN { continue }
            return (out.isEmpty ? nil : out, false, _NWErrno.posix(e == 0 ? ECONNRESET : e))
        }
        return (out, false, nil)
    }

    public func cancel() {
        lock.lock()
        if _state == .cancelled { lock.unlock(); return }
        let h = _stateHandler, q = queue
        _state = .cancelled
        let f = fd, t = tls
        lock.unlock()
        if f >= 0 { shutdown(f, SHUT_RDWR) }
        udpPeer?.inbox.close()
        ioQueue.async {
            if let t { isim_tls_close(t) }
            if f >= 0 { close(f) }
        }
        if let h { (q ?? .main).async { h(.cancelled) } }
    }
    public func forceCancel() { cancel() }
    public func cancelCurrentEndpoint() {}
    deinit { if fd >= 0 && _state != .cancelled { if let t = tls { isim_tls_close(t) }; close(fd) } }
}

/// the libSystem send/recv (named apart from NWConnection's own send/receive methods)
@inline(__always) func Darwin_send(_ fd: Int32, _ p: UnsafeRawPointer, _ n: Int) -> Int { send(fd, p, n, 0) }
@inline(__always) func Darwin_connect(_ fd: Int32, _ a: UnsafePointer<sockaddr>, _ l: socklen_t) -> Int32 { connect(fd, a, l) }
@inline(__always) func Darwin_recv(_ fd: Int32, _ p: UnsafeMutableRawPointer, _ n: Int) -> Int { recv(fd, p, n, 0) }

/// a blocking queue of datagrams (UDP listener connections)
final class _NWInbox: @unchecked Sendable {
    let cond = NSCondition()
    var items: [Data] = [], closed = false
    func put(_ d: Data) { cond.lock(); items.append(d); cond.signal(); cond.unlock() }
    func take() -> Data? {
        cond.lock(); defer { cond.unlock() }
        while items.isEmpty && !closed { cond.wait() }
        return items.isEmpty ? nil : items.removeFirst()
    }
    func close() { cond.lock(); closed = true; cond.broadcast(); cond.unlock() }
}
