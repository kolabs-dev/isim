// isim Network for C and Objective-C (sdk-src/Frameworks/Network): endpoints, parameters and protocol options, errors,
// content contexts, connections, listeners with Bonjour advertising, and Bonjour browsing (nw_endpoint_*,
// nw_parameters_*, nw_connection_*, nw_listener_*, nw_browser_*...), forwarding to NWConnection, NWListener and
// NWBrowser. As on Apple platforms, the objects are Objective-C objects (OS objects that ARC retains and releases;
// nw_retain / nw_release in C). The Swift objects run on the main queue; the C caller's handlers run on the queue it
// set (nw_*_set_queue), in order. The globals behind Apple's macros (NW_PARAMETERS_DEFAULT_CONFIGURATION...): capi.c.
// The C entry points take blocks and convert them to Swift closures; Swift callers (CAPISwift.swift) use the
// internal _nw_* functions with closures directly.
import Foundation
import Darwin

// MARK: - objects

final class _NWCEndpoint: NSObject {
    let endpoint: NWEndpoint
    init(_ e: NWEndpoint) { endpoint = e }
    /// C strings handed out by the getters, freed with the endpoint
    private var strings: [String: UnsafeMutablePointer<CChar>] = [:]
    private var sockaddrStorage: UnsafeMutableRawPointer?
    func cString(_ key: String, _ value: String?) -> UnsafePointer<CChar>? {
        guard let value else { return nil }
        if let s = strings[key] { return UnsafePointer(s) }
        let s = strdup(value)!
        strings[key] = s
        return UnsafePointer(s)
    }
    func sockaddr() -> UnsafeRawPointer? {
        if let s = sockaddrStorage { return UnsafeRawPointer(s) }
        guard case .hostPort(let host, let port) = endpoint else { return nil }
        switch host {
        case .ipv4(let a):
            var sa = sockaddr_in()
            sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); sa.sin_family = sa_family_t(AF_INET); sa.sin_port = port.rawValue.bigEndian
            a.rawValue.withUnsafeBytes { src in withUnsafeMutableBytes(of: &sa.sin_addr) { $0.copyMemory(from: src) } }
            let p = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<sockaddr_in>.size, alignment: 8)
            p.storeBytes(of: sa, as: sockaddr_in.self)
            sockaddrStorage = p
        case .ipv6(let a):
            var sa = sockaddr_in6()
            sa.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size); sa.sin6_family = sa_family_t(AF_INET6); sa.sin6_port = port.rawValue.bigEndian
            a.rawValue.withUnsafeBytes { src in withUnsafeMutableBytes(of: &sa.sin6_addr) { $0.copyMemory(from: src) } }
            let p = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<sockaddr_in6>.size, alignment: 8)
            p.storeBytes(of: sa, as: sockaddr_in6.self)
            sockaddrStorage = p
        case .name: return nil
        }
        return UnsafeRawPointer(sockaddrStorage)
    }
    deinit { strings.values.forEach { free($0) }; sockaddrStorage?.deallocate() }
}

final class _NWCParameters: NSObject {
    var parameters: NWParameters
    init(_ p: NWParameters) { parameters = p }
}
final class _NWCProtocolOptions: NSObject {
    let options: NWProtocolOptions
    var disabled = false                         // set by Swift's _nw_parameters_configure_protocol_disable
    init(_ o: NWProtocolOptions) { options = o }
}
final class _NWCError: NSObject {
    let error: NWError
    init(_ e: NWError) { error = e }
}
final class _NWCContext: NSObject {
    var identifier: String
    var isFinal: Bool
    var expiration: UInt64 = 0
    var priority: Double = 0.5
    var antecedent: _NWCContext?
    /// the shared contexts of Apple's macros map to NWConnection.ContentContext's
    let shared: NWConnection.ContentContext?
    var cIdentifier: UnsafeMutablePointer<CChar>?
    init(identifier: String, isFinal: Bool = false, shared: NWConnection.ContentContext? = nil) {
        self.identifier = identifier; self.isFinal = isFinal; self.shared = shared
    }
    convenience init(_ c: NWConnection.ContentContext) {
        self.init(identifier: c.identifier, isFinal: c.isFinal)
        expiration = c.expirationMilliseconds; priority = c.relativePriority
    }
    var context: NWConnection.ContentContext {
        if let shared, shared.isFinal == isFinal { return shared }
        return NWConnection.ContentContext(identifier: identifier, expiration: expiration, priority: priority, isFinal: isFinal,
                                           antecedent: antecedent?.context)
    }
    deinit { free(cIdentifier) }
}

/// the caller's queue: Swift handlers run on the main queue and hop to it (in order)
class _NWCQueued: NSObject {
    var queue: OpaquePointer? {
        didSet {
            if let queue { dispatch_retain(UnsafeMutableRawPointer(queue)) }
            if let oldValue { dispatch_release(UnsafeMutableRawPointer(oldValue)) }
        }
    }
    /// the queue a Swift caller set (Apple's Swift dispatch_queue_t is DispatchQueue)
    var swiftQueue: DispatchQueue?
    func onQueue(_ work: @escaping () -> Void) {
        if let swiftQueue { swiftQueue.async(execute: work) } else if let queue { dispatch_async(queue, work) } else { DispatchQueue.main.async(execute: work) }
    }
    deinit { if let queue { dispatch_release(UnsafeMutableRawPointer(queue)) } }
}

final class _NWCConnection: _NWCQueued {
    let connection: NWConnection
    var stateHandler: ((Int32, NSObject?) -> Void)?
    init(_ c: NWConnection) { connection = c }
}
final class _NWCListener: _NWCQueued {
    let listener: NWListener
    var stateHandler: ((Int32, NSObject?) -> Void)?
    var connectionHandler: ((NSObject) -> Void)?
    init(_ l: NWListener) { listener = l }
}
final class _NWCAdvertiseDescriptor: NSObject {
    var service: NWListener.Service
    init(_ s: NWListener.Service) { service = s }
}
final class _NWCBrowseDescriptor: NSObject {
    let type: String, domain: String?
    var includeTXT = false
    var cType: UnsafeMutablePointer<CChar>, cDomain: UnsafeMutablePointer<CChar>?
    init(type: String, domain: String?) {
        self.type = type; self.domain = domain
        cType = strdup(type); cDomain = domain.map { strdup($0) }
    }
    var descriptor: NWBrowser.Descriptor { includeTXT ? .bonjourWithTXTRecord(type: type, domain: domain) : .bonjour(type: type, domain: domain) }
    deinit { free(cType); free(cDomain) }
}
final class _NWCBrowser: _NWCQueued {
    let browser: NWBrowser
    let descriptor: _NWCBrowseDescriptor, parameters: _NWCParameters
    init(_ b: NWBrowser, _ d: _NWCBrowseDescriptor, _ p: _NWCParameters) { browser = b; descriptor = d; parameters = p }
}
final class _NWCBrowseResult: NSObject {
    private let r: NWBrowser.Result?
    init(_ r: NWBrowser.Result?) { self.r = r }
    var result: NWBrowser.Result { r! }
    var isNone: Bool { r == nil }
    /// Swift's handler takes non-optional results: an added result's old one (and a removed one's new one) is this
    nonisolated(unsafe) static let none = _NWCBrowseResult(nil)
}

private func obj<T: AnyObject>(_ p: UnsafeRawPointer, _: T.Type) -> T { Unmanaged<T>.fromOpaque(p).takeUnretainedValue() }
private func retained(_ o: NSObject) -> UnsafeMutableRawPointer { Unmanaged.passRetained(o).toOpaque() }
private func cError(_ e: NWError?) -> NSObject? { e.map { _NWCError($0) } }

@_silgen_name("_isim_nw_block_copy") func _nwBlockCopy(_ block: UnsafeRawPointer) -> UnsafeRawPointer   // capi.c
@_silgen_name("_isim_nw_block_release") func _nwBlockRelease(_ block: UnsafeRawPointer)
@_silgen_name("_isim_nw_block") func _nwBlock(_ which: Int32) -> UnsafeRawPointer
/// a handler or pointer captured by the Swift objects' @Sendable handlers (called on the caller's queue)
struct _NWCUnchecked<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

@_cdecl("_isim_nw_context")
public func _c_isim_nw_context(_ which: Int32) -> UnsafeMutableRawPointer {
    let c: NWConnection.ContentContext = which == 0 ? .defaultMessage : which == 1 ? .finalMessage : .defaultStream
    return retained(_NWCContext(identifier: c.identifier, isFinal: c.isFinal, shared: c))
}

@_cdecl("nw_retain")
public func _c_nw_retain(_ o: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer { _ = Unmanaged<AnyObject>.fromOpaque(o).retain(); return o }
@_cdecl("nw_release")
public func _c_nw_release(_ o: UnsafeMutableRawPointer) { Unmanaged<AnyObject>.fromOpaque(o).release() }

// MARK: - dispatch_data_t

private func data(_ d: OpaquePointer?) -> Data? {
    guard let d else { return nil }
    var out = Data()
    _ = dispatch_data_apply(d) { _, _, buffer, size in
        if let buffer, size > 0 { out.append(buffer.assumingMemoryBound(to: UInt8.self), count: size) }
        return true
    }
    return out
}
/// a dispatch_data_t (+1) with a copy of the bytes
private func dispatchData(_ d: Data) -> OpaquePointer? {
    d.withUnsafeBytes { dispatch_data_create($0.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!, $0.count, nil, nil) }
}

// MARK: - endpoints

/* nw_endpoint_type_t: invalid 0, address 1, host 2, bonjour_service 3, url 4 */
private func port(_ s: String) -> NWEndpoint.Port {
    if let p = NWEndpoint.Port(s) { return p }
    let services: [String: NWEndpoint.Port] = ["ssh": .ssh, "smtp": .smtp, "http": .http, "pop3": .pop, "imap": .imap, "https": .https,
                                               "imaps": .imaps, "socks": .socks]
    return services[s.lowercased()] ?? .any
}
@_cdecl("nw_endpoint_create_host")
public func _c_nw_endpoint_create_host(_ host: UnsafePointer<CChar>, _ p: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    retained(_NWCEndpoint(.hostPort(host: NWEndpoint.Host(String(cString: host)), port: port(String(cString: p)))))
}
@_cdecl("nw_endpoint_create_address")
public func _c_nw_endpoint_create_address(_ sa: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCEndpoint(_NWSock.endpoint(sa, Int(sa.load(as: UInt8.self)))))
}
@_cdecl("nw_endpoint_create_bonjour_service")
public func _c_nw_endpoint_create_bonjour_service(_ name: UnsafePointer<CChar>, _ type: UnsafePointer<CChar>, _ domain: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer {
    retained(_NWCEndpoint(.service(name: String(cString: name), type: String(cString: type), domain: domain.map { String(cString: $0) } ?? "local.", interface: nil)))
}
@_cdecl("nw_endpoint_create_url")
public func _c_nw_endpoint_create_url(_ url: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    let s = String(cString: url)
    guard let u = URL(string: s), u.host != nil else { return retained(_NWCEndpoint(.opaque(s))) }     // nw_endpoint_type_invalid
    return retained(_NWCEndpoint(.url(u)))
}
@_cdecl("nw_endpoint_get_type")
public func _c_nw_endpoint_get_type(_ e: UnsafeRawPointer) -> Int32 {
    switch obj(e, _NWCEndpoint.self).endpoint {
    case .hostPort(.name, _): return 2
    case .hostPort: return 1
    case .service: return 3
    case .url: return 4
    default: return 0
    }
}
@_cdecl("nw_endpoint_get_hostname")
public func _c_nw_endpoint_get_hostname(_ e: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(e, _NWCEndpoint.self)
    switch o.endpoint {
    case .hostPort(.name(let n, _), _): return o.cString("host", n)
    case .url(let u): return o.cString("host", u.host)
    default: return nil
    }
}
private func portOf(_ e: NWEndpoint) -> UInt16 {
    switch e {
    case .hostPort(_, let p): return p.rawValue
    case .url(let u): return UInt16(u.port ?? (u.scheme == "https" || u.scheme == "wss" ? 443 : 80))
    default: return 0
    }
}
@_cdecl("nw_endpoint_get_port")
public func _c_nw_endpoint_get_port(_ e: UnsafeRawPointer) -> UInt16 { portOf(obj(e, _NWCEndpoint.self).endpoint) }
@_cdecl("nw_endpoint_copy_port_string")
public func _c_nw_endpoint_copy_port_string(_ e: UnsafeRawPointer) -> UnsafeMutablePointer<CChar> {
    strdup(String(portOf(obj(e, _NWCEndpoint.self).endpoint)))
}
@_cdecl("nw_endpoint_copy_address_string")
public func _c_nw_endpoint_copy_address_string(_ e: UnsafeRawPointer) -> UnsafeMutablePointer<CChar> {
    if case .hostPort(let h, _) = obj(e, _NWCEndpoint.self).endpoint { return strdup(h.debugDescription) }
    return strdup("")
}
@_cdecl("nw_endpoint_get_address")
public func _c_nw_endpoint_get_address(_ e: UnsafeRawPointer) -> UnsafeRawPointer? { obj(e, _NWCEndpoint.self).sockaddr() }
@_cdecl("nw_endpoint_get_bonjour_service_name")
public func _c_nw_endpoint_get_bonjour_service_name(_ e: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(e, _NWCEndpoint.self)
    if case .service(let n, _, _, _) = o.endpoint { return o.cString("name", n) }
    return nil
}
@_cdecl("nw_endpoint_get_bonjour_service_type")
public func _c_nw_endpoint_get_bonjour_service_type(_ e: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(e, _NWCEndpoint.self)
    if case .service(_, let t, _, _) = o.endpoint { return o.cString("type", t) }
    return nil
}
@_cdecl("nw_endpoint_get_bonjour_service_domain")
public func _c_nw_endpoint_get_bonjour_service_domain(_ e: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(e, _NWCEndpoint.self)
    if case .service(_, _, let d, _) = o.endpoint { return o.cString("domain", d) }
    return nil
}
@_cdecl("nw_endpoint_get_url")
public func _c_nw_endpoint_get_url(_ e: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(e, _NWCEndpoint.self)
    if case .url(let u) = o.endpoint { return o.cString("url", u.absoluteString) }
    return nil
}
@_cdecl("nw_path_copy_effective_local_endpoint")
public func _c_nw_path_copy_effective_local_endpoint(_ p: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(p, _NWCPath.self).path.localEndpoint.map { retained(_NWCEndpoint($0)) }
}
@_cdecl("nw_path_copy_effective_remote_endpoint")
public func _c_nw_path_copy_effective_remote_endpoint(_ p: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(p, _NWCPath.self).path.remoteEndpoint.map { retained(_NWCEndpoint($0)) }
}

// MARK: - errors

/* nw_error_domain_t: invalid 0, posix 1, dns 2, tls 3, wifi_aware 4 */
@_cdecl("nw_error_get_error_domain")
public func _c_nw_error_get_error_domain(_ e: UnsafeRawPointer) -> Int32 {
    switch obj(e, _NWCError.self).error { case .posix: return 1; case .dns: return 2; case .tls: return 3; case .wifiAware: return 4 }
}
@_cdecl("nw_error_get_error_code")
public func _c_nw_error_get_error_code(_ e: UnsafeRawPointer) -> Int32 { obj(e, _NWCError.self).error.errorCode }
@_cdecl("nw_error_copy_cf_error")
public func _c_nw_error_copy_cf_error(_ e: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let error = obj(e, _NWCError.self).error
    let domain: String
    switch error { case .posix: domain = "kNWErrorDomainPOSIX"; case .dns: domain = "kNWErrorDomainDNS"; case .tls: domain = "kNWErrorDomainTLS"; default: domain = "kNWErrorDomainWiFiAware" }
    return retained(NSError(domain: domain, code: Int(error.errorCode), userInfo: [NSLocalizedDescriptionKey: error.debugDescription]))
}

// MARK: - parameters and protocol options

/// runs a configure block of nw_parameters_create_secure_*: nil when it is NW_PARAMETERS_DISABLE_PROTOCOL
private func configure<O: NWProtocolOptions>(_ block: UnsafeRawPointer, _ make: () -> O) -> O? {
    if block == _nwBlock(1) { return nil }
    let o = make()
    if block != _nwBlock(0) {
        typealias Configure = @convention(block) (NSObject) -> Void
        unsafeBitCast(block, to: Configure.self)(_NWCProtocolOptions(o))
    }
    return o
}
@_cdecl("nw_parameters_create")
public func _c_nw_parameters_create() -> UnsafeMutableRawPointer { retained(_NWCParameters(NWParameters())) }
@_cdecl("nw_parameters_create_secure_tcp")
public func _c_nw_parameters_create_secure_tcp(_ tls: UnsafeRawPointer, _ tcp: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let t = configure(tls) { NWProtocolTLS.Options() }
    let p = NWParameters(tls: t, tcp: configure(tcp) { NWProtocolTCP.Options() } ?? NWProtocolTCP.Options())
    return retained(_NWCParameters(p))
}
@_cdecl("nw_parameters_create_secure_udp")
public func _c_nw_parameters_create_secure_udp(_ dtls: UnsafeRawPointer, _ udp: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let t = configure(dtls) { NWProtocolTLS.Options() }
    let p = NWParameters(dtls: t, udp: configure(udp) { NWProtocolUDP.Options() } ?? NWProtocolUDP.Options())
    return retained(_NWCParameters(p))
}
@_cdecl("nw_parameters_copy")
public func _c_nw_parameters_copy(_ p: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let src = obj(p, _NWCParameters.self).parameters, c = src.copy()
    c.requiredInterfaceType = src.requiredInterfaceType; c.prohibitExpensivePaths = src.prohibitExpensivePaths
    c.prohibitConstrainedPaths = src.prohibitConstrainedPaths; c.allowFastOpen = src.allowFastOpen
    return retained(_NWCParameters(c))
}
private func params(_ p: UnsafeRawPointer) -> NWParameters { obj(p, _NWCParameters.self).parameters }
@_cdecl("nw_parameters_set_local_endpoint")
public func _c_nw_parameters_set_local_endpoint(_ p: UnsafeRawPointer, _ e: UnsafeRawPointer?) {
    params(p).requiredLocalEndpoint = e.map { obj($0, _NWCEndpoint.self).endpoint }
}
@_cdecl("nw_parameters_copy_local_endpoint")
public func _c_nw_parameters_copy_local_endpoint(_ p: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    params(p).requiredLocalEndpoint.map { retained(_NWCEndpoint($0)) }
}
@_cdecl("nw_parameters_set_reuse_local_address")
public func _c_nw_parameters_set_reuse_local_address(_ p: UnsafeRawPointer, _ v: Bool) { params(p).allowLocalEndpointReuse = v }
@_cdecl("nw_parameters_get_reuse_local_address")
public func _c_nw_parameters_get_reuse_local_address(_ p: UnsafeRawPointer) -> Bool { params(p).allowLocalEndpointReuse }
@_cdecl("nw_parameters_set_include_peer_to_peer")
public func _c_nw_parameters_set_include_peer_to_peer(_ p: UnsafeRawPointer, _ v: Bool) { params(p).includePeerToPeer = v }
@_cdecl("nw_parameters_get_include_peer_to_peer")
public func _c_nw_parameters_get_include_peer_to_peer(_ p: UnsafeRawPointer) -> Bool { params(p).includePeerToPeer }
@_cdecl("nw_parameters_set_local_only")
public func _c_nw_parameters_set_local_only(_ p: UnsafeRawPointer, _ v: Bool) { params(p).acceptLocalOnly = v }
@_cdecl("nw_parameters_get_local_only")
public func _c_nw_parameters_get_local_only(_ p: UnsafeRawPointer) -> Bool { params(p).acceptLocalOnly }
@_cdecl("nw_parameters_set_fast_open_enabled")
public func _c_nw_parameters_set_fast_open_enabled(_ p: UnsafeRawPointer, _ v: Bool) { params(p).allowFastOpen = v }
@_cdecl("nw_parameters_get_fast_open_enabled")
public func _c_nw_parameters_get_fast_open_enabled(_ p: UnsafeRawPointer) -> Bool { params(p).allowFastOpen }
private let interfaceTypes: [NWInterface.InterfaceType] = [.other, .wifi, .cellular, .wiredEthernet, .loopback]
@_cdecl("nw_parameters_set_required_interface_type")
public func _c_nw_parameters_set_required_interface_type(_ p: UnsafeRawPointer, _ t: Int32) {
    params(p).requiredInterfaceType = interfaceTypes.indices.contains(Int(t)) ? interfaceTypes[Int(t)] : .other
}
@_cdecl("nw_parameters_get_required_interface_type")
public func _c_nw_parameters_get_required_interface_type(_ p: UnsafeRawPointer) -> Int32 {
    Int32(interfaceTypes.firstIndex(of: params(p).requiredInterfaceType) ?? 0)
}
@_cdecl("nw_parameters_set_prohibit_expensive")
public func _c_nw_parameters_set_prohibit_expensive(_ p: UnsafeRawPointer, _ v: Bool) { params(p).prohibitExpensivePaths = v }
@_cdecl("nw_parameters_get_prohibit_expensive")
public func _c_nw_parameters_get_prohibit_expensive(_ p: UnsafeRawPointer) -> Bool { params(p).prohibitExpensivePaths }
@_cdecl("nw_parameters_set_prohibit_constrained")
public func _c_nw_parameters_set_prohibit_constrained(_ p: UnsafeRawPointer, _ v: Bool) { params(p).prohibitConstrainedPaths = v }
@_cdecl("nw_parameters_get_prohibit_constrained")
public func _c_nw_parameters_get_prohibit_constrained(_ p: UnsafeRawPointer) -> Bool { params(p).prohibitConstrainedPaths }

private func options(_ o: UnsafeRawPointer) -> NWProtocolOptions { obj(o, _NWCProtocolOptions.self).options }
@_cdecl("nw_protocol_options_is_tcp") public func _c_nw_protocol_options_is_tcp(_ o: UnsafeRawPointer) -> Bool { options(o) is NWProtocolTCP.Options }
@_cdecl("nw_protocol_options_is_udp") public func _c_nw_protocol_options_is_udp(_ o: UnsafeRawPointer) -> Bool { options(o) is NWProtocolUDP.Options }
@_cdecl("nw_protocol_options_is_tls") public func _c_nw_protocol_options_is_tls(_ o: UnsafeRawPointer) -> Bool { options(o) is NWProtocolTLS.Options }
@_cdecl("nw_tcp_create_options") public func _c_nw_tcp_create_options() -> UnsafeMutableRawPointer { retained(_NWCProtocolOptions(NWProtocolTCP.Options())) }
@_cdecl("nw_udp_create_options") public func _c_nw_udp_create_options() -> UnsafeMutableRawPointer { retained(_NWCProtocolOptions(NWProtocolUDP.Options())) }
@_cdecl("nw_tls_create_options") public func _c_nw_tls_create_options() -> UnsafeMutableRawPointer { retained(_NWCProtocolOptions(NWProtocolTLS.Options())) }
private func tcp(_ o: UnsafeRawPointer, _ set: (NWProtocolTCP.Options) -> Void) { if let t = options(o) as? NWProtocolTCP.Options { set(t) } }
@_cdecl("nw_tcp_options_set_no_delay") public func _c_nw_tcp_options_set_no_delay(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.noDelay = v } }
@_cdecl("nw_tcp_options_set_no_push") public func _c_nw_tcp_options_set_no_push(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.noPush = v } }
@_cdecl("nw_tcp_options_set_enable_keepalive") public func _c_nw_tcp_options_set_enable_keepalive(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.enableKeepalive = v } }
@_cdecl("nw_tcp_options_set_keepalive_count") public func _c_nw_tcp_options_set_keepalive_count(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.keepaliveCount = Int(v) } }
@_cdecl("nw_tcp_options_set_keepalive_idle_time") public func _c_nw_tcp_options_set_keepalive_idle_time(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.keepaliveIdle = Int(v) } }
@_cdecl("nw_tcp_options_set_keepalive_interval") public func _c_nw_tcp_options_set_keepalive_interval(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.keepaliveInterval = Int(v) } }
@_cdecl("nw_tcp_options_set_connection_timeout") public func _c_nw_tcp_options_set_connection_timeout(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.connectionTimeout = Int(v) } }
@_cdecl("nw_tcp_options_set_enable_fast_open") public func _c_nw_tcp_options_set_enable_fast_open(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.enableFastOpen = v } }
@_cdecl("nw_udp_options_set_prefer_no_checksum")
public func _c_nw_udp_options_set_prefer_no_checksum(_ o: UnsafeRawPointer, _ v: Bool) { (options(o) as? NWProtocolUDP.Options)?.preferNoChecksum = v }

// MARK: - content contexts

private func ctx(_ c: UnsafeRawPointer) -> _NWCContext { obj(c, _NWCContext.self) }
@_cdecl("nw_content_context_create")
public func _c_nw_content_context_create(_ id: UnsafePointer<CChar>) -> UnsafeMutableRawPointer { retained(_NWCContext(identifier: String(cString: id))) }
@_cdecl("nw_content_context_get_identifier")
public func _c_nw_content_context_get_identifier(_ c: UnsafeRawPointer) -> UnsafePointer<CChar> {
    let o = ctx(c)
    if o.cIdentifier == nil { o.cIdentifier = strdup(o.identifier) }
    return UnsafePointer(o.cIdentifier!)
}
@_cdecl("nw_content_context_get_is_final") public func _c_nw_content_context_get_is_final(_ c: UnsafeRawPointer) -> Bool { ctx(c).isFinal }
@_cdecl("nw_content_context_set_is_final") public func _c_nw_content_context_set_is_final(_ c: UnsafeRawPointer, _ v: Bool) { ctx(c).isFinal = v }
@_cdecl("nw_content_context_get_expiration_milliseconds")
public func _c_nw_content_context_get_expiration_milliseconds(_ c: UnsafeRawPointer) -> UInt64 { ctx(c).expiration }
@_cdecl("nw_content_context_set_expiration_milliseconds")
public func _c_nw_content_context_set_expiration_milliseconds(_ c: UnsafeRawPointer, _ v: UInt64) { ctx(c).expiration = v }
@_cdecl("nw_content_context_get_relative_priority")
public func _c_nw_content_context_get_relative_priority(_ c: UnsafeRawPointer) -> Double { ctx(c).priority }
@_cdecl("nw_content_context_set_relative_priority")
public func _c_nw_content_context_set_relative_priority(_ c: UnsafeRawPointer, _ v: Double) { ctx(c).priority = v }

@_cdecl("nw_content_context_set_antecedent")
public func _c_nw_content_context_set_antecedent(_ c: UnsafeRawPointer, _ a: UnsafeRawPointer?) { ctx(c).antecedent = a.map { ctx($0) } }
@_cdecl("nw_content_context_copy_antecedent")
public func _c_nw_content_context_copy_antecedent(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? { ctx(c).antecedent.map { retained($0) } }

// MARK: - connections

/* nw_connection_state_t: invalid 0, waiting 1, preparing 2, ready 3, failed 4, cancelled 5 */
private func connectionState(_ s: NWConnection.State) -> (Int32, NWError?)? {
    switch s {
    case .setup: return nil
    case .waiting(let e): return (1, e)
    case .preparing: return (2, nil)
    case .ready: return (3, nil)
    case .failed(let e): return (4, e)
    case .cancelled: return (5, nil)
    }
}
private func conn(_ c: UnsafeRawPointer) -> _NWCConnection { obj(c, _NWCConnection.self) }
@_cdecl("nw_connection_create")
public func _c_nw_connection_create(_ e: UnsafeRawPointer, _ p: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCConnection(NWConnection(to: obj(e, _NWCEndpoint.self).endpoint, using: params(p))))
}
@_cdecl("nw_connection_copy_endpoint")
public func _c_nw_connection_copy_endpoint(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCEndpoint(conn(c).connection.endpoint)) }
@_cdecl("nw_connection_copy_parameters")
public func _c_nw_connection_copy_parameters(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCParameters(conn(c).connection.parameters)) }
@_cdecl("nw_connection_set_queue")
public func _c_nw_connection_set_queue(_ c: UnsafeRawPointer, _ q: OpaquePointer) { conn(c).queue = q }

func _nw_connection_set_state_changed_handler(_ o: _NWCConnection, _ h: ((Int32, NSObject?) -> Void)?) {
    o.stateHandler = h
    // the handler keeps the connection alive until it is cancelled, like Apple's (a C caller may release it at once)
    guard h != nil else { o.connection.stateUpdateHandler = nil; return }
    let u = _NWCUnchecked(o)
    o.connection.stateUpdateHandler = { s in
        guard let st = connectionState(s) else { return }
        let o = u.value
        o.onQueue {
            o.stateHandler?(st.0, cError(st.1))
            if st.0 == 5 { o.stateHandler = nil; o.connection.stateUpdateHandler = nil }
        }
    }
}
@_cdecl("nw_connection_set_state_changed_handler")
public func _c_nw_connection_set_state_changed_handler(_ c: UnsafeRawPointer, _ h: (@convention(block) (Int32, NSObject?) -> Void)?) {
    _nw_connection_set_state_changed_handler(conn(c), h.map { h in { h($0, $1) } })
}
func _nw_connection_set_viability_changed_handler(_ o: _NWCConnection, _ h: ((Bool) -> Void)?) {
    let u = _NWCUnchecked(o)
    o.connection.viabilityUpdateHandler = h.map { h in let h = _NWCUnchecked(h); return { v in u.value.onQueue { h.value(v) } } }
}
@_cdecl("nw_connection_set_viability_changed_handler")
public func _c_nw_connection_set_viability_changed_handler(_ c: UnsafeRawPointer, _ h: (@convention(block) (Bool) -> Void)?) {
    _nw_connection_set_viability_changed_handler(conn(c), h.map { h in { h($0) } })
}
func _nw_connection_set_better_path_available_handler(_ o: _NWCConnection, _ h: ((Bool) -> Void)?) {
    let u = _NWCUnchecked(o)
    o.connection.betterPathUpdateHandler = h.map { h in let h = _NWCUnchecked(h); return { v in u.value.onQueue { h.value(v) } } }
}
@_cdecl("nw_connection_set_better_path_available_handler")
public func _c_nw_connection_set_better_path_available_handler(_ c: UnsafeRawPointer, _ h: (@convention(block) (Bool) -> Void)?) {
    _nw_connection_set_better_path_available_handler(conn(c), h.map { h in { h($0) } })
}
func _nw_connection_set_path_changed_handler(_ o: _NWCConnection, _ h: ((NSObject) -> Void)?) {
    let u = _NWCUnchecked(o)
    o.connection.pathUpdateHandler = h.map { h in let h = _NWCUnchecked(h); return { p in u.value.onQueue { h.value(_NWCPath(p)) } } }
}
@_cdecl("nw_connection_set_path_changed_handler")
public func _c_nw_connection_set_path_changed_handler(_ c: UnsafeRawPointer, _ h: (@convention(block) (NSObject) -> Void)?) {
    _nw_connection_set_path_changed_handler(conn(c), h.map { h in { h($0) } })
}
@_cdecl("nw_connection_start") public func _c_nw_connection_start(_ c: UnsafeRawPointer) { conn(c).connection.start(queue: .main) }
@_cdecl("nw_connection_restart") public func _c_nw_connection_restart(_ c: UnsafeRawPointer) { conn(c).connection.restart() }
@_cdecl("nw_connection_cancel") public func _c_nw_connection_cancel(_ c: UnsafeRawPointer) { conn(c).connection.cancel() }
@_cdecl("nw_connection_force_cancel") public func _c_nw_connection_force_cancel(_ c: UnsafeRawPointer) { conn(c).connection.forceCancel() }
@_cdecl("nw_connection_cancel_current_endpoint")
public func _c_nw_connection_cancel_current_endpoint(_ c: UnsafeRawPointer) { conn(c).connection.cancelCurrentEndpoint() }

private func received(_ o: _NWCConnection, _ completion: @escaping (OpaquePointer?, NSObject?, Bool, NSObject?) -> Void) -> @Sendable (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void {
    let completion = _NWCUnchecked(completion), o = _NWCUnchecked(o)
    return { d, context, complete, error in
        o.value.onQueue {
            let content = d.flatMap { $0.isEmpty ? nil : dispatchData($0) }
            completion.value(content, context.map { _NWCContext($0) }, complete, cError(error))
            if let content { dispatch_release(UnsafeMutableRawPointer(content)) }
        }
    }
}
func _nw_connection_receive(_ o: _NWCConnection, _ min: UInt32, _ max: UInt32, _ completion: @escaping (OpaquePointer?, NSObject?, Bool, NSObject?) -> Void) {
    o.connection.receive(minimumIncompleteLength: Int(min), maximumLength: Int(max), completion: received(o, completion))
}
@_cdecl("nw_connection_receive")
public func _c_nw_connection_receive(_ c: UnsafeRawPointer, _ min: UInt32, _ max: UInt32, _ completion: @escaping @convention(block) (OpaquePointer?, NSObject?, Bool, NSObject?) -> Void) {
    _nw_connection_receive(conn(c), min, max) { completion($0, $1, $2, $3) }
}
func _nw_connection_receive_message(_ o: _NWCConnection, _ completion: @escaping (OpaquePointer?, NSObject?, Bool, NSObject?) -> Void) {
    o.connection.receiveMessage(completion: received(o, completion))
}
@_cdecl("nw_connection_receive_message")
public func _c_nw_connection_receive_message(_ c: UnsafeRawPointer, _ completion: @escaping @convention(block) (OpaquePointer?, NSObject?, Bool, NSObject?) -> Void) {
    _nw_connection_receive_message(conn(c)) { completion($0, $1, $2, $3) }
}
/// completion nil: idempotent content (NW_CONNECTION_SEND_IDEMPOTENT_CONTENT)
func _nw_connection_send(_ o: _NWCConnection, _ content: OpaquePointer?, _ context: _NWCContext, _ complete: Bool, _ completion: ((NSObject?) -> Void)?) {
    let sendCompletion: NWConnection.SendCompletion
    if let completion {
        let c = _NWCUnchecked(completion), u = _NWCUnchecked(o)
        sendCompletion = .contentProcessed { e in u.value.onQueue { c.value(cError(e)) } }
    } else {
        sendCompletion = .idempotent
    }
    o.connection.send(content: data(content), contentContext: context.context, isComplete: complete, completion: sendCompletion)
}
@_cdecl("nw_connection_send")
public func _c_nw_connection_send(_ c: UnsafeRawPointer, _ content: OpaquePointer?, _ context: UnsafeRawPointer, _ complete: Bool, _ completion: UnsafeRawPointer) {
    var done: ((NSObject?) -> Void)?
    if completion != _nwBlock(2) {
        typealias Done = @convention(block) (NSObject?) -> Void
        let block = _NWCUnchecked(_nwBlockCopy(completion))
        done = { e in unsafeBitCast(block.value, to: Done.self)(e); _nwBlockRelease(block.value) }
    }
    _nw_connection_send(conn(c), content, ctx(context), complete, done)
}
@_cdecl("nw_connection_batch")
public func _c_nw_connection_batch(_ c: UnsafeRawPointer, _ block: @convention(block) () -> Void) { conn(c).connection.batch { block() } }
@_cdecl("nw_connection_copy_current_path")
public func _c_nw_connection_copy_current_path(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    conn(c).connection.currentPath.map { retained(_NWCPath($0)) }
}
@_cdecl("nw_connection_get_maximum_datagram_size")
public func _c_nw_connection_get_maximum_datagram_size(_ c: UnsafeRawPointer) -> UInt32 { UInt32(conn(c).connection.maximumDatagramSize) }
@_cdecl("nw_connection_copy_description")
public func _c_nw_connection_copy_description(_ c: UnsafeRawPointer) -> UnsafeMutablePointer<CChar> { strdup(conn(c).connection.debugDescription) }

// MARK: - listeners

/* nw_listener_state_t: invalid 0, waiting 1, ready 2, failed 3, cancelled 4 */
private func listener(_ l: UnsafeRawPointer) -> _NWCListener { obj(l, _NWCListener.self) }
@_cdecl("nw_listener_create_with_port")
public func _c_nw_listener_create_with_port(_ port: UnsafePointer<CChar>, _ p: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    guard let l = try? NWListener(using: params(p), on: NWEndpoint.Port(String(cString: port)) ?? .any) else { return nil }
    return retained(_NWCListener(l))
}
@_cdecl("nw_listener_create")
public func _c_nw_listener_create(_ p: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    guard let l = try? NWListener(using: params(p)) else { return nil }
    return retained(_NWCListener(l))
}
@_cdecl("nw_listener_set_queue")
public func _c_nw_listener_set_queue(_ l: UnsafeRawPointer, _ q: OpaquePointer) { listener(l).queue = q }
func _nw_listener_set_state_changed_handler(_ o: _NWCListener, _ h: ((Int32, NSObject?) -> Void)?) {
    o.stateHandler = h
    guard h != nil else { o.listener.stateUpdateHandler = nil; return }
    let u = _NWCUnchecked(o)
    o.listener.stateUpdateHandler = { s in
        let o = u.value
        let st: (Int32, NWError?)
        switch s {
        case .setup: return
        case .waiting(let e): st = (1, e)
        case .ready: st = (2, nil)
        case .failed(let e): st = (3, e)
        case .cancelled: st = (4, nil)
        }
        o.onQueue {
            o.stateHandler?(st.0, cError(st.1))
            if st.0 == 4 { o.stateHandler = nil; o.connectionHandler = nil; o.listener.stateUpdateHandler = nil; o.listener.newConnectionHandler = nil }
        }
    }
}
@_cdecl("nw_listener_set_state_changed_handler")
public func _c_nw_listener_set_state_changed_handler(_ l: UnsafeRawPointer, _ h: (@convention(block) (Int32, NSObject?) -> Void)?) {
    _nw_listener_set_state_changed_handler(listener(l), h.map { h in { h($0, $1) } })
}
func _nw_listener_set_new_connection_handler(_ o: _NWCListener, _ h: ((NSObject) -> Void)?) {
    o.connectionHandler = h
    guard h != nil else { o.listener.newConnectionHandler = nil; return }
    let u = _NWCUnchecked(o)
    o.listener.newConnectionHandler = { c in
        let o = u.value, cc = _NWCConnection(c)
        o.onQueue { o.connectionHandler?(cc) }
    }
}
@_cdecl("nw_listener_set_new_connection_handler")
public func _c_nw_listener_set_new_connection_handler(_ l: UnsafeRawPointer, _ h: (@convention(block) (NSObject) -> Void)?) {
    _nw_listener_set_new_connection_handler(listener(l), h.map { h in { h($0) } })
}
func _nw_listener_set_advertised_endpoint_changed_handler(_ o: _NWCListener, _ h: ((NSObject, Bool) -> Void)?) {
    let u = _NWCUnchecked(o)
    o.listener.serviceRegistrationUpdateHandler = h.map { h in let h = _NWCUnchecked(h); return { change in
        switch change {
        case .add(let e): u.value.onQueue { h.value(_NWCEndpoint(e), true) }
        case .remove(let e): u.value.onQueue { h.value(_NWCEndpoint(e), false) }
        }
    } }
}
@_cdecl("nw_listener_set_advertised_endpoint_changed_handler")
public func _c_nw_listener_set_advertised_endpoint_changed_handler(_ l: UnsafeRawPointer, _ h: (@convention(block) (NSObject, Bool) -> Void)?) {
    _nw_listener_set_advertised_endpoint_changed_handler(listener(l), h.map { h in { h($0, $1) } })
}
@_cdecl("nw_listener_get_new_connection_limit")
public func _c_nw_listener_get_new_connection_limit(_ l: UnsafeRawPointer) -> UInt32 {
    let n = listener(l).listener.newConnectionLimit
    return n >= Int(UInt32.max) ? UInt32.max : UInt32(n)
}
@_cdecl("nw_listener_set_new_connection_limit")
public func _c_nw_listener_set_new_connection_limit(_ l: UnsafeRawPointer, _ n: UInt32) {
    listener(l).listener.newConnectionLimit = n == UInt32.max ? NWListener.InfiniteConnectionLimit : Int(n)
}
@_cdecl("nw_listener_set_advertise_descriptor")
public func _c_nw_listener_set_advertise_descriptor(_ l: UnsafeRawPointer, _ d: UnsafeRawPointer?) {
    listener(l).listener.service = d.map { obj($0, _NWCAdvertiseDescriptor.self).service }
}
@_cdecl("nw_listener_get_port")
public func _c_nw_listener_get_port(_ l: UnsafeRawPointer) -> UInt16 { listener(l).listener.port?.rawValue ?? 0 }
@_cdecl("nw_listener_start") public func _c_nw_listener_start(_ l: UnsafeRawPointer) { listener(l).listener.start(queue: .main) }
@_cdecl("nw_listener_cancel") public func _c_nw_listener_cancel(_ l: UnsafeRawPointer) { listener(l).listener.cancel() }
@_cdecl("nw_advertise_descriptor_create_bonjour_service")
public func _c_nw_advertise_descriptor_create_bonjour_service(_ name: UnsafePointer<CChar>?, _ type: UnsafePointer<CChar>, _ domain: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    retained(_NWCAdvertiseDescriptor(NWListener.Service(name: name.map { String(cString: $0) }, type: String(cString: type),
                                                         domain: domain.map { String(cString: $0) })))
}
@_cdecl("nw_advertise_descriptor_set_txt_record")
public func _c_nw_advertise_descriptor_set_txt_record(_ d: UnsafeRawPointer, _ txt: UnsafeRawPointer?, _ n: Int) {
    obj(d, _NWCAdvertiseDescriptor.self).service.txtRecordObject = txt.map { NWTXTRecord(Data(bytes: $0, count: n)) }
}

// MARK: - browsing

/* nw_browser_state_t: invalid 0, ready 1, failed 2, cancelled 3, waiting 4 */
private func browser(_ b: UnsafeRawPointer) -> _NWCBrowser { obj(b, _NWCBrowser.self) }
private func browseDescriptor(_ d: UnsafeRawPointer) -> _NWCBrowseDescriptor { obj(d, _NWCBrowseDescriptor.self) }
@_cdecl("nw_browse_descriptor_create_bonjour_service")
public func _c_nw_browse_descriptor_create_bonjour_service(_ type: UnsafePointer<CChar>, _ domain: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer {
    retained(_NWCBrowseDescriptor(type: String(cString: type), domain: domain.map { String(cString: $0) }))
}
@_cdecl("nw_browse_descriptor_get_bonjour_service_type")
public func _c_nw_browse_descriptor_get_bonjour_service_type(_ d: UnsafeRawPointer) -> UnsafePointer<CChar> { UnsafePointer(browseDescriptor(d).cType) }
@_cdecl("nw_browse_descriptor_get_bonjour_service_domain")
public func _c_nw_browse_descriptor_get_bonjour_service_domain(_ d: UnsafeRawPointer) -> UnsafePointer<CChar>? { browseDescriptor(d).cDomain.map { UnsafePointer($0) } }
@_cdecl("nw_browse_descriptor_set_include_txt_record")
public func _c_nw_browse_descriptor_set_include_txt_record(_ d: UnsafeRawPointer, _ v: Bool) { browseDescriptor(d).includeTXT = v }
@_cdecl("nw_browse_descriptor_get_include_txt_record")
public func _c_nw_browse_descriptor_get_include_txt_record(_ d: UnsafeRawPointer) -> Bool { browseDescriptor(d).includeTXT }
@_cdecl("nw_browser_create")
public func _c_nw_browser_create(_ d: UnsafeRawPointer, _ p: UnsafeRawPointer?) -> UnsafeMutableRawPointer {
    let parameters = p.map { obj($0, _NWCParameters.self) } ?? _NWCParameters(NWParameters())
    return retained(_NWCBrowser(NWBrowser(for: browseDescriptor(d).descriptor, using: parameters.parameters), browseDescriptor(d), parameters))
}
@_cdecl("nw_browser_copy_browse_descriptor")
public func _c_nw_browser_copy_browse_descriptor(_ b: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(browser(b).descriptor) }
@_cdecl("nw_browser_copy_parameters")
public func _c_nw_browser_copy_parameters(_ b: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(browser(b).parameters) }
@_cdecl("nw_browser_set_queue")
public func _c_nw_browser_set_queue(_ b: UnsafeRawPointer, _ q: OpaquePointer) { browser(b).queue = q }
func _nw_browser_set_browse_results_changed_handler(_ o: _NWCBrowser, _ h: ((NSObject?, NSObject?, Bool) -> Void)?) {
    let u = _NWCUnchecked(o)
    o.browser.browseResultsChangedHandler = h.map { h in let h = _NWCUnchecked(h); return { _, changes in
        // one call per change (old result, new result), the last one with batch_complete
        var calls: [(NWBrowser.Result?, NWBrowser.Result?)] = []
        for change in changes {
            switch change {
            case .added(let r): calls.append((nil, r))
            case .removed(let r): calls.append((r, nil))
            case .changed(let old, let new, _): calls.append((old, new))
            case .identical: break
            }
        }
        guard !calls.isEmpty else { return }
        u.value.onQueue {
            for (i, (old, new)) in calls.enumerated() { h.value(old.map { _NWCBrowseResult($0) }, new.map { _NWCBrowseResult($0) }, i == calls.count - 1) }
        }
    } }
}
@_cdecl("nw_browser_set_browse_results_changed_handler")
public func _c_nw_browser_set_browse_results_changed_handler(_ b: UnsafeRawPointer, _ h: (@convention(block) (NSObject?, NSObject?, Bool) -> Void)?) {
    _nw_browser_set_browse_results_changed_handler(browser(b), h.map { h in { h($0, $1, $2) } })
}
func _nw_browser_set_state_changed_handler(_ o: _NWCBrowser, _ h: ((Int32, NSObject?) -> Void)?) {
    let u = _NWCUnchecked(o)
    o.browser.stateUpdateHandler = h.map { h in let h = _NWCUnchecked(h); return { s in
        let o = u.value
        let st: (Int32, NWError?)
        switch s {
        case .setup: return
        case .ready: st = (1, nil)
        case .failed(let e): st = (2, e)
        case .cancelled: st = (3, nil)
        case .waiting(let e): st = (4, e)
        }
        o.onQueue {
            h.value(st.0, cError(st.1))
            if st.0 == 3 { o.browser.stateUpdateHandler = nil; o.browser.browseResultsChangedHandler = nil }
        }
    } }
}
@_cdecl("nw_browser_set_state_changed_handler")
public func _c_nw_browser_set_state_changed_handler(_ b: UnsafeRawPointer, _ h: (@convention(block) (Int32, NSObject?) -> Void)?) {
    _nw_browser_set_state_changed_handler(browser(b), h.map { h in { h($0, $1) } })
}
@_cdecl("nw_browser_start") public func _c_nw_browser_start(_ b: UnsafeRawPointer) { browser(b).browser.start(queue: .main) }
@_cdecl("nw_browser_cancel") public func _c_nw_browser_cancel(_ b: UnsafeRawPointer) { browser(b).browser.cancel() }

/* nw_browse_result_change_t: identical 0x01, result_added 0x02, result_removed 0x04, interface_added 0x08,
   interface_removed 0x10, txt_record_changed 0x20 */
@_cdecl("nw_browse_result_get_changes")
public func _c_nw_browse_result_get_changes(_ old: UnsafeRawPointer?, _ new: UnsafeRawPointer?) -> UInt64 {
    switch (old.map { obj($0, _NWCBrowseResult.self).result }, new.map { obj($0, _NWCBrowseResult.self).result }) {
    case (nil, nil): return 0
    case (nil, _): return 0x02
    case (_, nil): return 0x04
    case (let o?, let n?):
        if o == n { return 0x01 }
        var c: UInt64 = 0
        if o.metadata != n.metadata { c |= 0x20 }
        if !Set(n.interfaces).subtracting(o.interfaces).isEmpty { c |= 0x08 }
        if !Set(o.interfaces).subtracting(n.interfaces).isEmpty { c |= 0x10 }
        return c
    }
}
@_cdecl("nw_browse_result_copy_endpoint")
public func _c_nw_browse_result_copy_endpoint(_ r: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCEndpoint(obj(r, _NWCBrowseResult.self).result.endpoint)) }
@_cdecl("nw_browse_result_enumerate_interfaces")
public func _c_nw_browse_result_enumerate_interfaces(_ r: UnsafeRawPointer, _ block: @convention(block) (NSObject) -> Bool) {
    for i in obj(r, _NWCBrowseResult.self).result.interfaces { if !block(_NWCInterface(i)) { break } }
}
@_cdecl("nw_browse_result_get_interfaces_count")
public func _c_nw_browse_result_get_interfaces_count(_ r: UnsafeRawPointer) -> Int { obj(r, _NWCBrowseResult.self).result.interfaces.count }
