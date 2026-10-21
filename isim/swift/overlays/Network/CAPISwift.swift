// isim Network: the C API as Swift sees it (Apple's Network module imports nw_* into Swift too): the OS_nw_* object
// protocols and nw_*_t types, the C enums as structs with their constants, and the functions, over the same objects as
// the C entry points (CAPI.swift, CAPIConnection.swift). Adapted: Apple's Swift dispatch_queue_t is DispatchQueue, so
// the queue setters take one; dispatch_data_t stays isim's C type (isim's Dispatch has no __DispatchData class).
import Foundation
import Darwin

// MARK: - object types

@objc public protocol OS_nw_path_monitor: NSObjectProtocol {}
@objc public protocol OS_nw_path: NSObjectProtocol {}
@objc public protocol OS_nw_interface: NSObjectProtocol {}
@objc public protocol OS_nw_endpoint: NSObjectProtocol {}
@objc public protocol OS_nw_parameters: NSObjectProtocol {}
@objc public protocol OS_nw_protocol_options: NSObjectProtocol {}
@objc public protocol OS_nw_error: NSObjectProtocol {}
@objc public protocol OS_nw_content_context: NSObjectProtocol {}
@objc public protocol OS_nw_connection: NSObjectProtocol {}
@objc public protocol OS_nw_listener: NSObjectProtocol {}
@objc public protocol OS_nw_advertise_descriptor: NSObjectProtocol {}
@objc public protocol OS_nw_browser: NSObjectProtocol {}
@objc public protocol OS_nw_browse_descriptor: NSObjectProtocol {}
@objc public protocol OS_nw_browse_result: NSObjectProtocol {}
public typealias nw_path_monitor_t = any OS_nw_path_monitor
public typealias nw_path_t = any OS_nw_path
public typealias nw_interface_t = any OS_nw_interface
public typealias nw_endpoint_t = any OS_nw_endpoint
public typealias nw_parameters_t = any OS_nw_parameters
public typealias nw_protocol_options_t = any OS_nw_protocol_options
public typealias nw_error_t = any OS_nw_error
public typealias nw_content_context_t = any OS_nw_content_context
public typealias nw_connection_t = any OS_nw_connection
public typealias nw_listener_t = any OS_nw_listener
public typealias nw_advertise_descriptor_t = any OS_nw_advertise_descriptor
public typealias nw_browser_t = any OS_nw_browser
public typealias nw_browse_descriptor_t = any OS_nw_browse_descriptor
public typealias nw_browse_result_t = any OS_nw_browse_result

extension _NWCPathMonitor: OS_nw_path_monitor {}
extension _NWCPath: OS_nw_path {}
extension _NWCInterface: OS_nw_interface {}
extension _NWCEndpoint: OS_nw_endpoint {}
extension _NWCParameters: OS_nw_parameters {}
extension _NWCProtocolOptions: OS_nw_protocol_options {}
extension _NWCError: OS_nw_error {}
extension _NWCContext: OS_nw_content_context {}
extension _NWCConnection: OS_nw_connection {}
extension _NWCListener: OS_nw_listener {}
extension _NWCAdvertiseDescriptor: OS_nw_advertise_descriptor {}
extension _NWCBrowser: OS_nw_browser {}
extension _NWCBrowseDescriptor: OS_nw_browse_descriptor {}
extension _NWCBrowseResult: OS_nw_browse_result {}

// MARK: - C enums

public struct nw_path_status_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_path_status_invalid: nw_path_status_t { .init(0) }
public var nw_path_status_satisfied: nw_path_status_t { .init(1) }
public var nw_path_status_unsatisfied: nw_path_status_t { .init(2) }
public var nw_path_status_satisfiable: nw_path_status_t { .init(3) }
public struct nw_interface_type_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_interface_type_other: nw_interface_type_t { .init(0) }
public var nw_interface_type_wifi: nw_interface_type_t { .init(1) }
public var nw_interface_type_cellular: nw_interface_type_t { .init(2) }
public var nw_interface_type_wired: nw_interface_type_t { .init(3) }
public var nw_interface_type_loopback: nw_interface_type_t { .init(4) }
public struct nw_endpoint_type_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_endpoint_type_invalid: nw_endpoint_type_t { .init(0) }
public var nw_endpoint_type_address: nw_endpoint_type_t { .init(1) }
public var nw_endpoint_type_host: nw_endpoint_type_t { .init(2) }
public var nw_endpoint_type_bonjour_service: nw_endpoint_type_t { .init(3) }
public var nw_endpoint_type_url: nw_endpoint_type_t { .init(4) }
public struct nw_error_domain_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_error_domain_invalid: nw_error_domain_t { .init(0) }
public var nw_error_domain_posix: nw_error_domain_t { .init(1) }
public var nw_error_domain_dns: nw_error_domain_t { .init(2) }
public var nw_error_domain_tls: nw_error_domain_t { .init(3) }
public var nw_error_domain_wifi_aware: nw_error_domain_t { .init(4) }
public struct nw_connection_state_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_connection_state_invalid: nw_connection_state_t { .init(0) }
public var nw_connection_state_waiting: nw_connection_state_t { .init(1) }
public var nw_connection_state_preparing: nw_connection_state_t { .init(2) }
public var nw_connection_state_ready: nw_connection_state_t { .init(3) }
public var nw_connection_state_failed: nw_connection_state_t { .init(4) }
public var nw_connection_state_cancelled: nw_connection_state_t { .init(5) }
public struct nw_listener_state_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_listener_state_invalid: nw_listener_state_t { .init(0) }
public var nw_listener_state_waiting: nw_listener_state_t { .init(1) }
public var nw_listener_state_ready: nw_listener_state_t { .init(2) }
public var nw_listener_state_failed: nw_listener_state_t { .init(3) }
public var nw_listener_state_cancelled: nw_listener_state_t { .init(4) }
public struct nw_browser_state_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_browser_state_invalid: nw_browser_state_t { .init(0) }
public var nw_browser_state_ready: nw_browser_state_t { .init(1) }
public var nw_browser_state_failed: nw_browser_state_t { .init(2) }
public var nw_browser_state_cancelled: nw_browser_state_t { .init(3) }
public var nw_browser_state_waiting: nw_browser_state_t { .init(4) }
public typealias nw_browse_result_change_t = UInt64
public var nw_browse_result_change_invalid: Int { 0x00 }
public var nw_browse_result_change_identical: Int { 0x01 }
public var nw_browse_result_change_result_added: Int { 0x02 }
public var nw_browse_result_change_result_removed: Int { 0x04 }
public var nw_browse_result_change_interface_added: Int { 0x08 }
public var nw_browse_result_change_interface_removed: Int { 0x10 }
public var nw_browse_result_change_txt_record_changed: Int { 0x20 }
public var NW_LISTENER_INFINITE_CONNECTION_LIMIT: UInt32 { UInt32.max }

// MARK: - handler types

public typealias nw_path_monitor_update_handler_t = (nw_path_t) -> Void
public typealias nw_path_monitor_cancel_handler_t = () -> Void
public typealias nw_path_enumerate_interfaces_block_t = (nw_interface_t) -> Bool
public typealias nw_parameters_configure_protocol_block_t = (nw_protocol_options_t) -> Void
public typealias nw_connection_state_changed_handler_t = (nw_connection_state_t, nw_error_t?) -> Void
public typealias nw_connection_boolean_event_handler_t = (Bool) -> Void
public typealias nw_connection_path_event_handler_t = (nw_path_t) -> Void
public typealias nw_connection_send_completion_t = (nw_error_t?) -> Void
public typealias nw_connection_receive_completion_t = (dispatch_data_t?, nw_content_context_t?, Bool, nw_error_t?) -> Void
public typealias nw_listener_state_changed_handler_t = (nw_listener_state_t, nw_error_t?) -> Void
public typealias nw_listener_new_connection_handler_t = (nw_connection_t) -> Void
public typealias nw_listener_advertised_endpoint_changed_handler_t = (nw_endpoint_t, Bool) -> Void
public typealias nw_browser_state_changed_handler_t = (nw_browser_state_t, nw_error_t?) -> Void
public typealias nw_browse_result_enumerate_interface_t = (nw_interface_t) -> Bool
public typealias nw_browser_browse_results_changed_handler_t = (nw_browse_result_t, nw_browse_result_t, Bool) -> Void

// MARK: - helpers

@inline(__always) private func raw(_ o: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passUnretained(o).toOpaque() }
private func take<T>(_ p: UnsafeMutableRawPointer) -> T { Unmanaged<AnyObject>.fromOpaque(p).takeRetainedValue() as! T }
private func takeOptional<T>(_ p: UnsafeMutableRawPointer?) -> T? { p.map { take($0) } }
private func err(_ e: NSObject?) -> nw_error_t? { e as? _NWCError }

// MARK: - retain / release, path monitor

public func nw_retain(_ obj: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer { _c_nw_retain(obj) }
public func nw_release(_ obj: UnsafeMutableRawPointer) { _c_nw_release(obj) }
public func nw_path_monitor_create() -> nw_path_monitor_t { take(_c_nw_path_monitor_create()) }
public func nw_path_monitor_create_with_type(_ required_interface_type: nw_interface_type_t) -> nw_path_monitor_t {
    take(_c_nw_path_monitor_create_with_type(Int32(required_interface_type.rawValue)))
}
public func nw_path_monitor_set_queue(_ monitor: nw_path_monitor_t, _ queue: DispatchQueue) { (monitor as! _NWCPathMonitor).swiftQueue = queue }
public func nw_path_monitor_set_update_handler(_ monitor: nw_path_monitor_t, _ update_handler: @escaping nw_path_monitor_update_handler_t) {
    _nw_path_monitor_set_update_handler(monitor as! _NWCPathMonitor) { p in update_handler(p as! _NWCPath) }
}
public func nw_path_monitor_set_cancel_handler(_ monitor: nw_path_monitor_t, _ cancel_handler: @escaping nw_path_monitor_cancel_handler_t) {
    (monitor as! _NWCPathMonitor).cancelHandler = cancel_handler
}
public func nw_path_monitor_start(_ monitor: nw_path_monitor_t) { _c_nw_path_monitor_start(raw(monitor)) }
public func nw_path_monitor_cancel(_ monitor: nw_path_monitor_t) { _c_nw_path_monitor_cancel(raw(monitor)) }
public func nw_path_get_status(_ path: nw_path_t) -> nw_path_status_t { .init(UInt32(_c_nw_path_get_status(raw(path)))) }
public func nw_path_is_expensive(_ path: nw_path_t) -> Bool { _c_nw_path_is_expensive(raw(path)) }
public func nw_path_is_constrained(_ path: nw_path_t) -> Bool { _c_nw_path_is_constrained(raw(path)) }
public func nw_path_has_ipv4(_ path: nw_path_t) -> Bool { _c_nw_path_has_ipv4(raw(path)) }
public func nw_path_has_ipv6(_ path: nw_path_t) -> Bool { _c_nw_path_has_ipv6(raw(path)) }
public func nw_path_has_dns(_ path: nw_path_t) -> Bool { _c_nw_path_has_dns(raw(path)) }
public func nw_path_uses_interface_type(_ path: nw_path_t, _ interface_type: nw_interface_type_t) -> Bool {
    _c_nw_path_uses_interface_type(raw(path), Int32(interface_type.rawValue))
}
public func nw_path_enumerate_interfaces(_ path: nw_path_t, _ enumerate_block: (nw_interface_t) -> Bool) {
    for i in (path as! _NWCPath).path.availableInterfaces { if !enumerate_block(_NWCInterface(i)) { break } }
}
public func nw_path_copy_effective_local_endpoint(_ path: nw_path_t) -> nw_endpoint_t? { takeOptional(_c_nw_path_copy_effective_local_endpoint(raw(path))) }
public func nw_path_copy_effective_remote_endpoint(_ path: nw_path_t) -> nw_endpoint_t? { takeOptional(_c_nw_path_copy_effective_remote_endpoint(raw(path))) }
public func nw_interface_get_type(_ interface: nw_interface_t) -> nw_interface_type_t { .init(UInt32(_c_nw_interface_get_type(raw(interface)))) }
public func nw_interface_get_name(_ interface: nw_interface_t) -> UnsafePointer<CChar> { _c_nw_interface_get_name(raw(interface))! }
public func nw_interface_get_index(_ interface: nw_interface_t) -> UInt32 { _c_nw_interface_get_index(raw(interface)) }

// MARK: - endpoints

public func nw_endpoint_create_host(_ hostname: UnsafePointer<CChar>, _ port: UnsafePointer<CChar>) -> nw_endpoint_t {
    take(_c_nw_endpoint_create_host(hostname, port))
}
public func nw_endpoint_create_address(_ address: UnsafePointer<sockaddr>) -> nw_endpoint_t { take(_c_nw_endpoint_create_address(UnsafeRawPointer(address))) }
public func nw_endpoint_create_bonjour_service(_ name: UnsafePointer<CChar>, _ type: UnsafePointer<CChar>, _ domain: UnsafePointer<CChar>?) -> nw_endpoint_t {
    take(_c_nw_endpoint_create_bonjour_service(name, type, domain))
}
public func nw_endpoint_create_url(_ url: UnsafePointer<CChar>) -> nw_endpoint_t { take(_c_nw_endpoint_create_url(url)) }
public func nw_endpoint_get_type(_ endpoint: nw_endpoint_t) -> nw_endpoint_type_t { .init(UInt32(_c_nw_endpoint_get_type(raw(endpoint)))) }
public func nw_endpoint_get_hostname(_ endpoint: nw_endpoint_t) -> UnsafePointer<CChar>? { _c_nw_endpoint_get_hostname(raw(endpoint)) }
public func nw_endpoint_get_port(_ endpoint: nw_endpoint_t) -> UInt16 { _c_nw_endpoint_get_port(raw(endpoint)) }
public func nw_endpoint_copy_port_string(_ endpoint: nw_endpoint_t) -> UnsafeMutablePointer<CChar> { _c_nw_endpoint_copy_port_string(raw(endpoint)) }
public func nw_endpoint_copy_address_string(_ endpoint: nw_endpoint_t) -> UnsafeMutablePointer<CChar> { _c_nw_endpoint_copy_address_string(raw(endpoint)) }
public func nw_endpoint_get_address(_ endpoint: nw_endpoint_t) -> UnsafePointer<sockaddr> {
    _c_nw_endpoint_get_address(raw(endpoint))!.assumingMemoryBound(to: sockaddr.self)      // an address endpoint
}
public func nw_endpoint_get_bonjour_service_name(_ endpoint: nw_endpoint_t) -> UnsafePointer<CChar>? { _c_nw_endpoint_get_bonjour_service_name(raw(endpoint)) }
public func nw_endpoint_get_bonjour_service_type(_ endpoint: nw_endpoint_t) -> UnsafePointer<CChar>? { _c_nw_endpoint_get_bonjour_service_type(raw(endpoint)) }
public func nw_endpoint_get_bonjour_service_domain(_ endpoint: nw_endpoint_t) -> UnsafePointer<CChar>? { _c_nw_endpoint_get_bonjour_service_domain(raw(endpoint)) }
public func nw_endpoint_get_url(_ endpoint: nw_endpoint_t) -> UnsafePointer<CChar>? { _c_nw_endpoint_get_url(raw(endpoint)) }

// MARK: - errors

public func nw_error_get_error_domain(_ error: nw_error_t) -> nw_error_domain_t { .init(UInt32(_c_nw_error_get_error_domain(raw(error)))) }
public func nw_error_get_error_code(_ error: nw_error_t) -> Int32 { _c_nw_error_get_error_code(raw(error)) }
public func nw_error_copy_cf_error(_ error: nw_error_t) -> Unmanaged<CFError> { Unmanaged.fromOpaque(_c_nw_error_copy_cf_error(raw(error))) }

// MARK: - parameters and protocol options

/// the configure blocks of Apple's macros: DISABLE marks the options so nw_parameters_create_secure_* leaves the protocol out
public let _nw_parameters_configure_protocol_disable: nw_parameters_configure_protocol_block_t = { ($0 as? _NWCProtocolOptions)?.disabled = true }
public let _nw_parameters_configure_protocol_default_configuration: nw_parameters_configure_protocol_block_t = { _ in }
private func configured<O: NWProtocolOptions>(_ block: nw_parameters_configure_protocol_block_t, _ make: () -> O) -> O? {
    let o = _NWCProtocolOptions(make())
    block(o)
    return o.disabled ? nil : (o.options as! O)
}
public func nw_parameters_create() -> nw_parameters_t { take(_c_nw_parameters_create()) }
public func nw_parameters_create_secure_tcp(_ configure_tls: nw_parameters_configure_protocol_block_t,
                                            _ configure_tcp: nw_parameters_configure_protocol_block_t) -> nw_parameters_t {
    let tls = configured(configure_tls) { NWProtocolTLS.Options() }
    return _NWCParameters(NWParameters(tls: tls, tcp: configured(configure_tcp) { NWProtocolTCP.Options() } ?? NWProtocolTCP.Options()))
}
public func nw_parameters_create_secure_udp(_ configure_dtls: nw_parameters_configure_protocol_block_t,
                                            _ configure_udp: nw_parameters_configure_protocol_block_t) -> nw_parameters_t {
    let dtls = configured(configure_dtls) { NWProtocolTLS.Options() }
    return _NWCParameters(NWParameters(dtls: dtls, udp: configured(configure_udp) { NWProtocolUDP.Options() } ?? NWProtocolUDP.Options()))
}
public func nw_parameters_copy(_ parameters: nw_parameters_t) -> nw_parameters_t { take(_c_nw_parameters_copy(raw(parameters))) }
public func nw_parameters_set_local_endpoint(_ parameters: nw_parameters_t, _ local_endpoint: nw_endpoint_t?) {
    _c_nw_parameters_set_local_endpoint(raw(parameters), local_endpoint.map { UnsafeRawPointer(raw($0)) })
}
public func nw_parameters_copy_local_endpoint(_ parameters: nw_parameters_t) -> nw_endpoint_t? { takeOptional(_c_nw_parameters_copy_local_endpoint(raw(parameters))) }
public func nw_parameters_set_reuse_local_address(_ parameters: nw_parameters_t, _ reuse_local_address: Bool) { _c_nw_parameters_set_reuse_local_address(raw(parameters), reuse_local_address) }
public func nw_parameters_get_reuse_local_address(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_reuse_local_address(raw(parameters)) }
public func nw_parameters_set_include_peer_to_peer(_ parameters: nw_parameters_t, _ include_peer_to_peer: Bool) { _c_nw_parameters_set_include_peer_to_peer(raw(parameters), include_peer_to_peer) }
public func nw_parameters_get_include_peer_to_peer(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_include_peer_to_peer(raw(parameters)) }
public func nw_parameters_set_local_only(_ parameters: nw_parameters_t, _ local_only: Bool) { _c_nw_parameters_set_local_only(raw(parameters), local_only) }
public func nw_parameters_get_local_only(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_local_only(raw(parameters)) }
public func nw_parameters_set_fast_open_enabled(_ parameters: nw_parameters_t, _ fast_open_enabled: Bool) { _c_nw_parameters_set_fast_open_enabled(raw(parameters), fast_open_enabled) }
public func nw_parameters_get_fast_open_enabled(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_fast_open_enabled(raw(parameters)) }
public func nw_parameters_set_required_interface_type(_ parameters: nw_parameters_t, _ interface_type: nw_interface_type_t) {
    _c_nw_parameters_set_required_interface_type(raw(parameters), Int32(interface_type.rawValue))
}
public func nw_parameters_get_required_interface_type(_ parameters: nw_parameters_t) -> nw_interface_type_t { .init(UInt32(_c_nw_parameters_get_required_interface_type(raw(parameters)))) }
public func nw_parameters_set_prohibit_expensive(_ parameters: nw_parameters_t, _ prohibit_expensive: Bool) { _c_nw_parameters_set_prohibit_expensive(raw(parameters), prohibit_expensive) }
public func nw_parameters_get_prohibit_expensive(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_prohibit_expensive(raw(parameters)) }
public func nw_parameters_set_prohibit_constrained(_ parameters: nw_parameters_t, _ prohibit_constrained: Bool) { _c_nw_parameters_set_prohibit_constrained(raw(parameters), prohibit_constrained) }
public func nw_parameters_get_prohibit_constrained(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_prohibit_constrained(raw(parameters)) }
public func nw_protocol_options_is_tcp(_ options: nw_protocol_options_t) -> Bool { _c_nw_protocol_options_is_tcp(raw(options)) }
public func nw_protocol_options_is_udp(_ options: nw_protocol_options_t) -> Bool { _c_nw_protocol_options_is_udp(raw(options)) }
public func nw_protocol_options_is_tls(_ options: nw_protocol_options_t) -> Bool { _c_nw_protocol_options_is_tls(raw(options)) }
public func nw_tcp_create_options() -> nw_protocol_options_t { take(_c_nw_tcp_create_options()) }
public func nw_udp_create_options() -> nw_protocol_options_t { take(_c_nw_udp_create_options()) }
public func nw_tls_create_options() -> nw_protocol_options_t { take(_c_nw_tls_create_options()) }
public func nw_tcp_options_set_no_delay(_ options: nw_protocol_options_t, _ no_delay: Bool) { _c_nw_tcp_options_set_no_delay(raw(options), no_delay) }
public func nw_tcp_options_set_no_push(_ options: nw_protocol_options_t, _ no_push: Bool) { _c_nw_tcp_options_set_no_push(raw(options), no_push) }
public func nw_tcp_options_set_enable_keepalive(_ options: nw_protocol_options_t, _ enable_keepalive: Bool) { _c_nw_tcp_options_set_enable_keepalive(raw(options), enable_keepalive) }
public func nw_tcp_options_set_keepalive_count(_ options: nw_protocol_options_t, _ keepalive_count: UInt32) { _c_nw_tcp_options_set_keepalive_count(raw(options), keepalive_count) }
public func nw_tcp_options_set_keepalive_idle_time(_ options: nw_protocol_options_t, _ keepalive_idle_time: UInt32) { _c_nw_tcp_options_set_keepalive_idle_time(raw(options), keepalive_idle_time) }
public func nw_tcp_options_set_keepalive_interval(_ options: nw_protocol_options_t, _ keepalive_interval: UInt32) { _c_nw_tcp_options_set_keepalive_interval(raw(options), keepalive_interval) }
public func nw_tcp_options_set_connection_timeout(_ options: nw_protocol_options_t, _ connection_timeout: UInt32) { _c_nw_tcp_options_set_connection_timeout(raw(options), connection_timeout) }
public func nw_tcp_options_set_enable_fast_open(_ options: nw_protocol_options_t, _ enable_fast_open: Bool) { _c_nw_tcp_options_set_enable_fast_open(raw(options), enable_fast_open) }
public func nw_udp_options_set_prefer_no_checksum(_ options: nw_protocol_options_t, _ prefer_no_checksum: Bool) { _c_nw_udp_options_set_prefer_no_checksum(raw(options), prefer_no_checksum) }

// MARK: - content contexts

@_silgen_name("_isim_nw_context_global") private func _nwContextGlobal(_ which: Int32) -> UnsafeMutableRawPointer   // capi.c
public var _nw_content_context_default_message: nw_content_context_t { Unmanaged<_NWCContext>.fromOpaque(_nwContextGlobal(0)).takeUnretainedValue() }
public var _nw_content_context_final_send: nw_content_context_t { Unmanaged<_NWCContext>.fromOpaque(_nwContextGlobal(1)).takeUnretainedValue() }
public var _nw_content_context_default_stream: nw_content_context_t { Unmanaged<_NWCContext>.fromOpaque(_nwContextGlobal(2)).takeUnretainedValue() }
/// NW_CONNECTION_SEND_IDEMPOTENT_CONTENT from Swift: a completion that does nothing
public let _nw_connection_send_idempotent_content: nw_connection_send_completion_t = { _ in }
public func nw_content_context_create(_ context_identifier: UnsafePointer<CChar>) -> nw_content_context_t { take(_c_nw_content_context_create(context_identifier)) }
public func nw_content_context_get_identifier(_ context: nw_content_context_t) -> UnsafePointer<CChar> { _c_nw_content_context_get_identifier(raw(context)) }
public func nw_content_context_get_is_final(_ context: nw_content_context_t) -> Bool { _c_nw_content_context_get_is_final(raw(context)) }
public func nw_content_context_set_is_final(_ context: nw_content_context_t, _ is_final: Bool) { _c_nw_content_context_set_is_final(raw(context), is_final) }
public func nw_content_context_get_expiration_milliseconds(_ context: nw_content_context_t) -> UInt64 { _c_nw_content_context_get_expiration_milliseconds(raw(context)) }
public func nw_content_context_set_expiration_milliseconds(_ context: nw_content_context_t, _ expiration_milliseconds: UInt64) {
    _c_nw_content_context_set_expiration_milliseconds(raw(context), expiration_milliseconds)
}
public func nw_content_context_set_antecedent(_ context: nw_content_context_t, _ antecedent_context: nw_content_context_t?) {
    _c_nw_content_context_set_antecedent(raw(context), antecedent_context.map { UnsafeRawPointer(raw($0)) })
}
public func nw_content_context_copy_antecedent(_ context: nw_content_context_t) -> nw_content_context_t? { takeOptional(_c_nw_content_context_copy_antecedent(raw(context))) }
public func nw_content_context_get_relative_priority(_ context: nw_content_context_t) -> Double { _c_nw_content_context_get_relative_priority(raw(context)) }
public func nw_content_context_set_relative_priority(_ context: nw_content_context_t, _ relative_priority: Double) { _c_nw_content_context_set_relative_priority(raw(context), relative_priority) }

// MARK: - connections

public func nw_connection_create(_ endpoint: nw_endpoint_t, _ parameters: nw_parameters_t) -> nw_connection_t {
    take(_c_nw_connection_create(raw(endpoint), raw(parameters)))
}
public func nw_connection_copy_endpoint(_ connection: nw_connection_t) -> nw_endpoint_t { take(_c_nw_connection_copy_endpoint(raw(connection))) }
public func nw_connection_copy_parameters(_ connection: nw_connection_t) -> nw_parameters_t { take(_c_nw_connection_copy_parameters(raw(connection))) }
public func nw_connection_set_queue(_ connection: nw_connection_t, _ queue: DispatchQueue) { (connection as! _NWCConnection).swiftQueue = queue }
public func nw_connection_set_state_changed_handler(_ connection: nw_connection_t, _ handler: nw_connection_state_changed_handler_t?) {
    _nw_connection_set_state_changed_handler(connection as! _NWCConnection, handler.map { h in { s, e in h(.init(UInt32(s)), err(e)) } })
}
public func nw_connection_set_viability_changed_handler(_ connection: nw_connection_t, _ handler: nw_connection_boolean_event_handler_t?) {
    _nw_connection_set_viability_changed_handler(connection as! _NWCConnection, handler)
}
public func nw_connection_set_better_path_available_handler(_ connection: nw_connection_t, _ handler: nw_connection_boolean_event_handler_t?) {
    _nw_connection_set_better_path_available_handler(connection as! _NWCConnection, handler)
}
public func nw_connection_set_path_changed_handler(_ connection: nw_connection_t, _ handler: nw_connection_path_event_handler_t?) {
    _nw_connection_set_path_changed_handler(connection as! _NWCConnection, handler.map { h in { h($0 as! _NWCPath) } })
}
public func nw_connection_start(_ connection: nw_connection_t) { _c_nw_connection_start(raw(connection)) }
public func nw_connection_restart(_ connection: nw_connection_t) { _c_nw_connection_restart(raw(connection)) }
public func nw_connection_cancel(_ connection: nw_connection_t) { _c_nw_connection_cancel(raw(connection)) }
public func nw_connection_force_cancel(_ connection: nw_connection_t) { _c_nw_connection_force_cancel(raw(connection)) }
public func nw_connection_cancel_current_endpoint(_ connection: nw_connection_t) { _c_nw_connection_cancel_current_endpoint(raw(connection)) }
public func nw_connection_receive(_ connection: nw_connection_t, _ minimum_incomplete_length: UInt32, _ maximum_length: UInt32,
                                  _ completion: @escaping nw_connection_receive_completion_t) {
    _nw_connection_receive(connection as! _NWCConnection, minimum_incomplete_length, maximum_length) { d, c, complete, e in
        completion(d, c as? _NWCContext, complete, err(e))
    }
}
public func nw_connection_receive_message(_ connection: nw_connection_t, _ completion: @escaping nw_connection_receive_completion_t) {
    _nw_connection_receive_message(connection as! _NWCConnection) { d, c, complete, e in completion(d, c as? _NWCContext, complete, err(e)) }
}
public func nw_connection_send(_ connection: nw_connection_t, _ content: dispatch_data_t?, _ context: nw_content_context_t, _ is_complete: Bool,
                               _ completion: @escaping nw_connection_send_completion_t) {
    _nw_connection_send(connection as! _NWCConnection, content, context as! _NWCContext, is_complete) { e in completion(err(e)) }
}
public func nw_connection_batch(_ connection: nw_connection_t, _ batch_block: () -> Void) { (connection as! _NWCConnection).connection.batch(batch_block) }
public func nw_connection_copy_current_path(_ connection: nw_connection_t) -> nw_path_t? { takeOptional(_c_nw_connection_copy_current_path(raw(connection))) }
public func nw_connection_get_maximum_datagram_size(_ connection: nw_connection_t) -> UInt32 { _c_nw_connection_get_maximum_datagram_size(raw(connection)) }
public func nw_connection_copy_description(_ connection: nw_connection_t) -> UnsafeMutablePointer<CChar> { _c_nw_connection_copy_description(raw(connection)) }

// MARK: - listeners

public func nw_listener_create(_ parameters: nw_parameters_t) -> nw_listener_t? { takeOptional(_c_nw_listener_create(raw(parameters))) }
public func nw_listener_create_with_port(_ port: UnsafePointer<CChar>, _ parameters: nw_parameters_t) -> nw_listener_t? {
    takeOptional(_c_nw_listener_create_with_port(port, raw(parameters)))
}
public func nw_listener_set_queue(_ listener: nw_listener_t, _ queue: DispatchQueue) { (listener as! _NWCListener).swiftQueue = queue }
public func nw_listener_set_state_changed_handler(_ listener: nw_listener_t, _ handler: nw_listener_state_changed_handler_t?) {
    _nw_listener_set_state_changed_handler(listener as! _NWCListener, handler.map { h in { s, e in h(.init(UInt32(s)), err(e)) } })
}
public func nw_listener_set_new_connection_handler(_ listener: nw_listener_t, _ handler: nw_listener_new_connection_handler_t?) {
    _nw_listener_set_new_connection_handler(listener as! _NWCListener, handler.map { h in { h($0 as! _NWCConnection) } })
}
public func nw_listener_set_advertised_endpoint_changed_handler(_ listener: nw_listener_t, _ handler: nw_listener_advertised_endpoint_changed_handler_t?) {
    _nw_listener_set_advertised_endpoint_changed_handler(listener as! _NWCListener, handler.map { h in { e, added in h(e as! _NWCEndpoint, added) } })
}
public func nw_listener_get_new_connection_limit(_ listener: nw_listener_t) -> UInt32 { _c_nw_listener_get_new_connection_limit(raw(listener)) }
public func nw_listener_set_new_connection_limit(_ listener: nw_listener_t, _ new_connection_limit: UInt32) { _c_nw_listener_set_new_connection_limit(raw(listener), new_connection_limit) }
public func nw_listener_set_advertise_descriptor(_ listener: nw_listener_t, _ advertise_descriptor: nw_advertise_descriptor_t?) {
    _c_nw_listener_set_advertise_descriptor(raw(listener), advertise_descriptor.map { UnsafeRawPointer(raw($0)) })
}
public func nw_listener_get_port(_ listener: nw_listener_t) -> UInt16 { _c_nw_listener_get_port(raw(listener)) }
public func nw_listener_start(_ listener: nw_listener_t) { _c_nw_listener_start(raw(listener)) }
public func nw_listener_cancel(_ listener: nw_listener_t) { _c_nw_listener_cancel(raw(listener)) }
public func nw_advertise_descriptor_create_bonjour_service(_ name: UnsafePointer<CChar>?, _ type: UnsafePointer<CChar>, _ domain: UnsafePointer<CChar>?) -> nw_advertise_descriptor_t? {
    takeOptional(_c_nw_advertise_descriptor_create_bonjour_service(name, type, domain))
}
public func nw_advertise_descriptor_set_txt_record(_ advertise_descriptor: nw_advertise_descriptor_t, _ txt_record: UnsafeRawPointer?, _ txt_length: Int) {
    _c_nw_advertise_descriptor_set_txt_record(raw(advertise_descriptor), txt_record, txt_length)
}

// MARK: - browsing

public func nw_browse_descriptor_create_bonjour_service(_ type: UnsafePointer<CChar>, _ domain: UnsafePointer<CChar>?) -> nw_browse_descriptor_t {
    take(_c_nw_browse_descriptor_create_bonjour_service(type, domain))
}
public func nw_browse_descriptor_get_bonjour_service_type(_ descriptor: nw_browse_descriptor_t) -> UnsafePointer<CChar> { _c_nw_browse_descriptor_get_bonjour_service_type(raw(descriptor)) }
public func nw_browse_descriptor_get_bonjour_service_domain(_ descriptor: nw_browse_descriptor_t) -> UnsafePointer<CChar>? { _c_nw_browse_descriptor_get_bonjour_service_domain(raw(descriptor)) }
public func nw_browse_descriptor_set_include_txt_record(_ descriptor: nw_browse_descriptor_t, _ include_txt_record: Bool) { _c_nw_browse_descriptor_set_include_txt_record(raw(descriptor), include_txt_record) }
public func nw_browse_descriptor_get_include_txt_record(_ descriptor: nw_browse_descriptor_t) -> Bool { _c_nw_browse_descriptor_get_include_txt_record(raw(descriptor)) }
public func nw_browser_create(_ descriptor: nw_browse_descriptor_t, _ parameters: nw_parameters_t?) -> nw_browser_t {
    take(_c_nw_browser_create(raw(descriptor), parameters.map { UnsafeRawPointer(raw($0)) }))
}
public func nw_browser_copy_browse_descriptor(_ browser: nw_browser_t) -> nw_browse_descriptor_t { take(_c_nw_browser_copy_browse_descriptor(raw(browser))) }
public func nw_browser_copy_parameters(_ browser: nw_browser_t) -> nw_parameters_t { take(_c_nw_browser_copy_parameters(raw(browser))) }
public func nw_browser_set_queue(_ browser: nw_browser_t, _ queue: DispatchQueue) { (browser as! _NWCBrowser).swiftQueue = queue }
/// old_result / new_result: Apple's Swift signature has them non-optional (an added result's old one is a null object)
public func nw_browser_set_browse_results_changed_handler(_ browser: nw_browser_t, _ handler: nw_browser_browse_results_changed_handler_t?) {
    _nw_browser_set_browse_results_changed_handler(browser as! _NWCBrowser, handler.map { h in { old, new, complete in
        h((old as? _NWCBrowseResult) ?? _NWCBrowseResult.none, (new as? _NWCBrowseResult) ?? _NWCBrowseResult.none, complete)
    } })
}
public func nw_browser_set_state_changed_handler(_ browser: nw_browser_t, _ state_changed_handler: nw_browser_state_changed_handler_t?) {
    _nw_browser_set_state_changed_handler(browser as! _NWCBrowser, state_changed_handler.map { h in { s, e in h(.init(UInt32(s)), err(e)) } })
}
public func nw_browser_start(_ browser: nw_browser_t) { _c_nw_browser_start(raw(browser)) }
public func nw_browser_cancel(_ browser: nw_browser_t) { _c_nw_browser_cancel(raw(browser)) }
public func nw_browse_result_get_changes(_ old_result: nw_browse_result_t?, _ new_result: nw_browse_result_t?) -> nw_browse_result_change_t {
    func real(_ r: nw_browse_result_t?) -> UnsafeRawPointer? { (r as? _NWCBrowseResult).flatMap { $0.isNone ? nil : UnsafeRawPointer(raw($0)) } }
    return _c_nw_browse_result_get_changes(real(old_result), real(new_result))
}
public func nw_browse_result_copy_endpoint(_ result: nw_browse_result_t) -> nw_endpoint_t { take(_c_nw_browse_result_copy_endpoint(raw(result))) }
public func nw_browse_result_enumerate_interfaces(_ result: nw_browse_result_t, _ enumerator: nw_browse_result_enumerate_interface_t) {
    for i in (result as! _NWCBrowseResult).result.interfaces { if !enumerator(_NWCInterface(i)) { break } }
}
public func nw_browse_result_get_interfaces_count(_ result: nw_browse_result_t) -> Int { _c_nw_browse_result_get_interfaces_count(raw(result)) }
