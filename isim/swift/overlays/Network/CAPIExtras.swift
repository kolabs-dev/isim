// isim Network for C and Objective-C (issue #851): protocol definitions and metadata, IP / TCP / UDP / TLS / QUIC /
// WebSocket options and metadata, TXT records, application services, paths and parameters, establishment and data
// transfer reports, connection groups (UDP multicast), framers defined in C, and proxy configurations, over the Swift
// overlay's objects. The C framer runs as an NWProtocolFramerImplementation whose callbacks are the C blocks.
// Adapted: QUIC options and metadata are kept (isim has no QUIC transport yet), proxy configurations are kept
// (connections go direct), endpoints have no signatures, and a listener over a connection's streams is not available.
import Foundation
import Darwin

// MARK: - objects

final class _NWCDefinition: NSObject {
    let definition: NWProtocolDefinition
    init(_ d: NWProtocolDefinition) { definition = d }
}
final class _NWCMetadata: NSObject {
    let metadata: NWProtocolMetadata
    var cStrings: [String: UnsafeMutablePointer<CChar>] = [:]
    init(_ m: NWProtocolMetadata) { metadata = m }
    func cString(_ key: String, _ value: String?) -> UnsafePointer<CChar>? {
        guard let value else { return nil }
        if let s = cStrings[key] { free(s) }
        let s = strdup(value)!
        cStrings[key] = s
        return UnsafePointer(s)
    }
    deinit { cStrings.values.forEach { free($0) } }
}
final class _NWCSecObject: NSObject {
    let object: AnyObject
    init(_ o: AnyObject) { object = o }
}
final class _NWCTXTRecord: NSObject {
    var record: NWTXTRecord
    var bytes: Data?                                      /* a record made from bytes that are not key=value pairs */
    init(_ r: NWTXTRecord, bytes: Data? = nil) { record = r; self.bytes = bytes }
}
final class _NWCEstablishmentReport: NSObject {
    let report: NWConnection.EstablishmentReport
    init(_ r: NWConnection.EstablishmentReport) { report = r }
}
final class _NWCResolutionReport: NSObject {
    let resolution: NWConnection.EstablishmentReport.Resolution
    init(_ r: NWConnection.EstablishmentReport.Resolution) { resolution = r }
}
final class _NWCDataTransferReport: NSObject {
    let pending: NWConnection.PendingDataTransferReport
    var collected: NWConnection.DataTransferReport?
    init(_ p: NWConnection.PendingDataTransferReport) { pending = p }
}
final class _NWCGroupDescriptor: NSObject {
    var endpoints: [NWEndpoint]
    let multiplex: Bool
    var source: NWEndpoint?
    var disableUnicast = false
    init(_ e: [NWEndpoint], multiplex: Bool) { endpoints = e; self.multiplex = multiplex }
    func descriptor() -> NWGroupDescriptor? {
        if multiplex { return endpoints.first.map { NWMultiplexGroup(to: $0) } }
        return try? NWMulticastGroup(for: endpoints, from: source, disableUnicast: disableUnicast)
    }
}
final class _NWCConnectionGroup: _NWCQueued {
    let group: NWConnectionGroup
    let descriptor: _NWCGroupDescriptor
    init(_ g: NWConnectionGroup, _ d: _NWCGroupDescriptor) { group = g; descriptor = d }
}
final class _NWCWSRequest: NSObject {
    let request: NWProtocolWebSocket.Request
    init(_ r: NWProtocolWebSocket.Request) { request = r }
}
final class _NWCWSResponse: NSObject {
    var response: NWProtocolWebSocket.Response
    var cSubprotocol: UnsafeMutablePointer<CChar>?
    init(_ r: NWProtocolWebSocket.Response) { response = r }
    deinit { free(cSubprotocol) }
}
final class _NWCProxyConfig: NSObject {
    var config: ProxyConfiguration
    init(_ c: ProxyConfiguration) { config = c }
}
/// a C framer's handle: the instance and the C blocks
final class _NWCFramer: NSObject {
    let instance: NWProtocolFramer.Instance
    var input: ((NSObject) -> Int)?
    var output: ((NSObject, NSObject, Int, Bool) -> Void)?
    var wakeup: ((NSObject) -> Void)?
    var stop: ((NSObject) -> Bool)?
    var cleanup: ((NSObject) -> Void)?
    init(_ i: NWProtocolFramer.Instance) { instance = i }
}
/// a value a C framer stored in a message (nw_framer_message_set_value)
final class _NWCFramerValue {
    let pointer: UnsafeMutableRawPointer?
    let dispose: ((UnsafeMutableRawPointer) -> Void)?
    init(_ p: UnsafeMutableRawPointer?, _ d: ((UnsafeMutableRawPointer) -> Void)?) { pointer = p; dispose = d }
    deinit { if let pointer, let dispose { dispose(pointer) } }
}

/// the framers defined in C: their start blocks, by definition
nonisolated(unsafe) var _nwcFramerStarts: [ObjectIdentifier: (NSObject) -> UInt32] = [:]
let _nwcFramerLock = NSLock()
final class _NWCFramerImplementation: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: _NWCFramerImplementation.self)
    static var label: String { "isim.c-framer" }
    let framer: _NWCFramer
    init(framer instance: NWProtocolFramer.Instance) { framer = _NWCFramer(instance) }
    func start(framer instance: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        _nwcFramerLock.lock(); let start = _nwcFramerStarts[ObjectIdentifier(instance.options.definition)]; _nwcFramerLock.unlock()
        return start?(framer) == 2 ? .willMarkReady : .ready
    }
    func handleInput(framer instance: NWProtocolFramer.Instance) -> Int { framer.input?(framer) ?? 0 }
    func handleOutput(framer instance: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        if let o = framer.output { o(framer, _NWCMetadata(message), messageLength, isComplete) } else { try? instance.writeOutputNoCopy(length: messageLength) }
    }
    func wakeup(framer instance: NWProtocolFramer.Instance) { framer.wakeup?(framer) }
    func stop(framer instance: NWProtocolFramer.Instance) -> Bool { framer.stop?(framer) ?? true }
    func cleanup(framer instance: NWProtocolFramer.Instance) { framer.cleanup?(framer) }
}

// MARK: - helpers

private func obj<T: AnyObject>(_ p: UnsafeRawPointer, _: T.Type) -> T { Unmanaged<T>.fromOpaque(p).takeUnretainedValue() }
private func any(_ p: UnsafeRawPointer) -> AnyObject { Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() }
private func retained(_ o: NSObject) -> UnsafeMutableRawPointer { Unmanaged.passRetained(o).toOpaque() }
private func meta<T: NWProtocolMetadata>(_ p: UnsafeRawPointer, _: T.Type) -> T? { obj(p, _NWCMetadata.self).metadata as? T }
private func options<T: NWProtocolOptions>(_ p: UnsafeRawPointer, _: T.Type) -> T? { obj(p, _NWCProtocolOptions.self).options as? T }
private func bytes(_ d: OpaquePointer?) -> Data? {
    guard let d else { return nil }
    var out = Data()
    _ = dispatch_data_apply(d) { _, _, buffer, size in
        if let buffer, size > 0 { out.append(buffer.assumingMemoryBound(to: UInt8.self), count: size) }
        return true
    }
    return out
}
private func dispatchData(_ d: Data) -> OpaquePointer? {
    d.withUnsafeBytes { dispatch_data_create($0.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!, $0.count, nil, nil) }
}
private func ms(_ t: TimeInterval) -> UInt64 { UInt64(max(0, (t * 1000).rounded())) }
private func onQueue(_ q: OpaquePointer, _ work: @escaping () -> Void) { dispatch_async(q, work) }
private func endpointObject(_ e: NWEndpoint) -> _NWCEndpoint { _NWCEndpoint(e) }

// MARK: - protocol definitions and metadata

private func definition(_ d: NWProtocolDefinition) -> UnsafeMutableRawPointer { retained(_NWCDefinition(d)) }
@_cdecl("nw_protocol_copy_ip_definition") public func _c_nw_protocol_copy_ip_definition() -> UnsafeMutableRawPointer { definition(NWProtocolIP.definition) }
@_cdecl("nw_protocol_copy_tcp_definition") public func _c_nw_protocol_copy_tcp_definition() -> UnsafeMutableRawPointer { definition(NWProtocolTCP.definition) }
@_cdecl("nw_protocol_copy_udp_definition") public func _c_nw_protocol_copy_udp_definition() -> UnsafeMutableRawPointer { definition(NWProtocolUDP.definition) }
@_cdecl("nw_protocol_copy_tls_definition") public func _c_nw_protocol_copy_tls_definition() -> UnsafeMutableRawPointer { definition(NWProtocolTLS.definition) }
@_cdecl("nw_protocol_copy_quic_definition") public func _c_nw_protocol_copy_quic_definition() -> UnsafeMutableRawPointer { definition(NWProtocolQUIC.definition) }
@_cdecl("nw_protocol_copy_ws_definition") public func _c_nw_protocol_copy_ws_definition() -> UnsafeMutableRawPointer { definition(NWProtocolWebSocket.definition) }
@_cdecl("nw_protocol_definition_is_equal")
public func _c_nw_protocol_definition_is_equal(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer) -> Bool {
    obj(a, _NWCDefinition.self).definition == obj(b, _NWCDefinition.self).definition
}
@_cdecl("nw_protocol_metadata_copy_definition")
public func _c_nw_protocol_metadata_copy_definition(_ m: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let md = obj(m, _NWCMetadata.self).metadata
    return definition(md._definition ?? _metadataDefinition(md))
}
func _metadataDefinition(_ m: NWProtocolMetadata) -> NWProtocolDefinition {
    switch m {
    case is NWProtocolIP.Metadata: return NWProtocolIP.definition
    case is NWProtocolTCP.Metadata: return NWProtocolTCP.definition
    case is NWProtocolUDP.Metadata: return NWProtocolUDP.definition
    case is NWProtocolTLS.Metadata: return NWProtocolTLS.definition
    case is NWProtocolQUIC.Metadata: return NWProtocolQUIC.definition
    case is NWProtocolWebSocket.Metadata: return NWProtocolWebSocket.definition
    default: return m._definition ?? NWProtocolDefinition("unknown")
    }
}
@_cdecl("nw_protocol_metadata_is_ip") public func _c_nw_protocol_metadata_is_ip(_ m: UnsafeRawPointer) -> Bool { meta(m, NWProtocolIP.Metadata.self) != nil }
@_cdecl("nw_protocol_metadata_is_tcp") public func _c_nw_protocol_metadata_is_tcp(_ m: UnsafeRawPointer) -> Bool { meta(m, NWProtocolTCP.Metadata.self) != nil }
@_cdecl("nw_protocol_metadata_is_udp") public func _c_nw_protocol_metadata_is_udp(_ m: UnsafeRawPointer) -> Bool { meta(m, NWProtocolUDP.Metadata.self) != nil }
@_cdecl("nw_protocol_metadata_is_tls") public func _c_nw_protocol_metadata_is_tls(_ m: UnsafeRawPointer) -> Bool { meta(m, NWProtocolTLS.Metadata.self) != nil }
@_cdecl("nw_protocol_metadata_is_quic") public func _c_nw_protocol_metadata_is_quic(_ m: UnsafeRawPointer) -> Bool { meta(m, NWProtocolQUIC.Metadata.self) != nil }
@_cdecl("nw_protocol_metadata_is_ws") public func _c_nw_protocol_metadata_is_ws(_ m: UnsafeRawPointer) -> Bool { meta(m, NWProtocolWebSocket.Metadata.self) != nil }
@_cdecl("nw_protocol_metadata_is_framer_message") public func _c_nw_protocol_metadata_is_framer_message(_ m: UnsafeRawPointer) -> Bool {
    meta(m, NWProtocolFramer.Message.self) != nil
}
@_cdecl("nw_protocol_options_is_quic") public func _c_nw_protocol_options_is_quic(_ o: UnsafeRawPointer) -> Bool { options(o, NWProtocolQUIC.Options.self) != nil }
@_cdecl("nw_connection_copy_protocol_metadata")
public func _c_nw_connection_copy_protocol_metadata(_ c: UnsafeRawPointer, _ d: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(c, _NWCConnection.self).connection.metadata(definition: obj(d, _NWCDefinition.self).definition).map { retained(_NWCMetadata($0)) }
}
@_cdecl("nw_content_context_copy_protocol_metadata")
public func _c_nw_content_context_copy_protocol_metadata(_ c: UnsafeRawPointer, _ d: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    let def = obj(d, _NWCDefinition.self).definition
    return obj(c, _NWCContext.self).context.protocolMetadata.first { ($0._definition ?? _metadataDefinition($0)) == def }.map { retained(_NWCMetadata($0)) }
}
@_cdecl("nw_content_context_foreach_protocol_metadata")
public func _c_nw_content_context_foreach_protocol_metadata(_ c: UnsafeRawPointer, _ f: @convention(block) (NSObject, NSObject) -> Void) {
    for m in obj(c, _NWCContext.self).context.protocolMetadata { f(_NWCDefinition(m._definition ?? _metadataDefinition(m)), _NWCMetadata(m)) }
}
@_cdecl("nw_content_context_set_metadata_for_protocol")
public func _c_nw_content_context_set_metadata_for_protocol(_ c: UnsafeRawPointer, _ m: UnsafeRawPointer) {
    let ctx = obj(c, _NWCContext.self), md = obj(m, _NWCMetadata.self).metadata
    let def = md._definition ?? _metadataDefinition(md)
    if md._definition == nil { md._definition = def }
    ctx.metadata.removeAll { ($0._definition ?? _metadataDefinition($0)) == def }
    ctx.metadata.append(md)
}

// MARK: - IP

private func ip(_ o: UnsafeRawPointer, _ f: (NWProtocolIP.Options) -> Void) { if let i = options(o, NWProtocolIP.Options.self) { f(i) } }
@_cdecl("nw_ip_options_set_version")
public func _c_nw_ip_options_set_version(_ o: UnsafeRawPointer, _ v: UInt32) { ip(o) { $0.version = v == 4 ? .v4 : v == 6 ? .v6 : .any } }
@_cdecl("nw_ip_options_set_hop_limit") public func _c_nw_ip_options_set_hop_limit(_ o: UnsafeRawPointer, _ v: UInt8) { ip(o) { $0.hopLimit = v } }
@_cdecl("nw_ip_options_set_use_minimum_mtu") public func _c_nw_ip_options_set_use_minimum_mtu(_ o: UnsafeRawPointer, _ v: Bool) { ip(o) { $0.useMinimumMTU = v } }
@_cdecl("nw_ip_options_set_disable_fragmentation") public func _c_nw_ip_options_set_disable_fragmentation(_ o: UnsafeRawPointer, _ v: Bool) { ip(o) { $0.disableFragmentation = v } }
@_cdecl("nw_ip_options_set_calculate_receive_time") public func _c_nw_ip_options_set_calculate_receive_time(_ o: UnsafeRawPointer, _ v: Bool) { ip(o) { $0.shouldCalculateReceiveTime = v } }
@_cdecl("nw_ip_options_set_local_address_preference")
public func _c_nw_ip_options_set_local_address_preference(_ o: UnsafeRawPointer, _ v: UInt32) {
    ip(o) { $0.localAddressPreference = v == 1 ? .temporary : v == 2 ? .stable : .default }
}
@_cdecl("nw_ip_options_set_disable_multicast_loopback") public func _c_nw_ip_options_set_disable_multicast_loopback(_ o: UnsafeRawPointer, _ v: Bool) { ip(o) { $0.disableMulticastLoopback = v } }
@_cdecl("nw_ip_create_metadata") public func _c_nw_ip_create_metadata() -> UnsafeMutableRawPointer { retained(_NWCMetadata(NWProtocolIP.Metadata())) }
private let ecnValues: [NWProtocolIP.ECN] = [.nonECT, .ect1, .ect0, .ce]          /* by the C value: non_ect 0, ect_1 1, ect_0 2, ce 3 */
@_cdecl("nw_ip_metadata_set_ecn_flag")
public func _c_nw_ip_metadata_set_ecn_flag(_ m: UnsafeRawPointer, _ v: UInt32) { meta(m, NWProtocolIP.Metadata.self)?.ecn = ecnValues[Int(min(v, 3))] }
@_cdecl("nw_ip_metadata_get_ecn_flag")
public func _c_nw_ip_metadata_get_ecn_flag(_ m: UnsafeRawPointer) -> UInt32 { UInt32(ecnValues.firstIndex(of: meta(m, NWProtocolIP.Metadata.self)?.ecn ?? .nonECT) ?? 0) }
private let serviceClasses: [NWParameters.ServiceClass] = [.bestEffort, .background, .interactiveVideo, .interactiveVoice, .responsiveData, .signaling]
@_cdecl("nw_ip_metadata_set_service_class")
public func _c_nw_ip_metadata_set_service_class(_ m: UnsafeRawPointer, _ v: UInt32) { meta(m, NWProtocolIP.Metadata.self)?.serviceClass = serviceClasses[Int(min(v, 5))] }
@_cdecl("nw_ip_metadata_get_service_class")
public func _c_nw_ip_metadata_get_service_class(_ m: UnsafeRawPointer) -> UInt32 {
    UInt32(serviceClasses.firstIndex(of: meta(m, NWProtocolIP.Metadata.self)?.serviceClass ?? .bestEffort) ?? 0)
}
@_cdecl("nw_ip_metadata_get_receive_time") public func _c_nw_ip_metadata_get_receive_time(_ m: UnsafeRawPointer) -> UInt64 { meta(m, NWProtocolIP.Metadata.self)?.receiveTime ?? 0 }

// MARK: - TCP, UDP, TLS

private func tcp(_ o: UnsafeRawPointer, _ f: (NWProtocolTCP.Options) -> Void) { if let t = options(o, NWProtocolTCP.Options.self) { f(t) } }
@_cdecl("nw_tcp_options_set_no_options") public func _c_nw_tcp_options_set_no_options(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.noOptions = v } }
@_cdecl("nw_tcp_options_set_maximum_segment_size") public func _c_nw_tcp_options_set_maximum_segment_size(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.maximumSegmentSize = Int(v) } }
@_cdecl("nw_tcp_options_set_persist_timeout") public func _c_nw_tcp_options_set_persist_timeout(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.persistTimeout = Int(v) } }
@_cdecl("nw_tcp_options_set_retransmit_connection_drop_time")
public func _c_nw_tcp_options_set_retransmit_connection_drop_time(_ o: UnsafeRawPointer, _ v: UInt32) { tcp(o) { $0.connectionDropTime = Int(v) } }
@_cdecl("nw_tcp_options_set_retransmit_fin_drop") public func _c_nw_tcp_options_set_retransmit_fin_drop(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.retransmitFinDrop = v } }
@_cdecl("nw_tcp_options_set_disable_ack_stretching") public func _c_nw_tcp_options_set_disable_ack_stretching(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.disableAckStretching = v } }
@_cdecl("nw_tcp_options_set_disable_ecn") public func _c_nw_tcp_options_set_disable_ecn(_ o: UnsafeRawPointer, _ v: Bool) { tcp(o) { $0.disableECN = v } }
@_cdecl("nw_tcp_options_set_multipath_force_version")
public func _c_nw_tcp_options_set_multipath_force_version(_ o: UnsafeRawPointer, _ v: Int32) { tcp(o) { $0.multipathForceVersion = v < 0 ? nil : Int(v) } }
@_cdecl("nw_tcp_get_available_receive_buffer") public func _c_nw_tcp_get_available_receive_buffer(_ m: UnsafeRawPointer) -> UInt32 { meta(m, NWProtocolTCP.Metadata.self)?.availableReceiveBuffer ?? 0 }
@_cdecl("nw_tcp_get_available_send_buffer") public func _c_nw_tcp_get_available_send_buffer(_ m: UnsafeRawPointer) -> UInt32 { meta(m, NWProtocolTCP.Metadata.self)?.availableSendBuffer ?? 0 }
@_cdecl("nw_tcp_set_max_pacing_rate")
public func _c_nw_tcp_set_max_pacing_rate(_ m: UnsafeRawPointer, _ rate: UInt64) -> Int32 {
    guard let t = meta(m, NWProtocolTCP.Metadata.self) else { return EINVAL }
    t.setMaximumPacingRateBytesPerSecond(rate == 0 ? nil : rate)
    return 0
}
@_cdecl("nw_udp_create_metadata") public func _c_nw_udp_create_metadata() -> UnsafeMutableRawPointer { retained(_NWCMetadata(NWProtocolUDP.Metadata())) }
@_cdecl("nw_tls_copy_sec_protocol_options")
public func _c_nw_tls_copy_sec_protocol_options(_ o: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCSecObject(options(o, NWProtocolTLS.Options.self)?.securityProtocolOptions ?? sec_protocol_options_t()))
}
@_cdecl("nw_tls_copy_sec_protocol_metadata")
public func _c_nw_tls_copy_sec_protocol_metadata(_ m: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCSecObject(meta(m, NWProtocolTLS.Metadata.self)?.securityProtocolMetadata ?? sec_protocol_metadata_t()))
}

// MARK: - QUIC

private func quic(_ o: UnsafeRawPointer) -> NWProtocolQUIC.Options? { options(o, NWProtocolQUIC.Options.self) }
private func quicMeta(_ m: UnsafeRawPointer) -> NWProtocolQUIC.Metadata? { meta(m, NWProtocolQUIC.Metadata.self) }
@_cdecl("nw_quic_create_options") public func _c_nw_quic_create_options() -> UnsafeMutableRawPointer { retained(_NWCProtocolOptions(NWProtocolQUIC.Options())) }
@_cdecl("nw_parameters_create_quic")
public func _c_nw_parameters_create_quic(_ block: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let o = NWProtocolQUIC.Options()
    if block != _nwBlock(0) && block != _nwBlock(1) {
        typealias Configure = @convention(block) (NSObject) -> Void
        unsafeBitCast(block, to: Configure.self)(_NWCProtocolOptions(o))
    }
    return retained(_NWCParameters(NWParameters(quic: o)))
}
@_cdecl("nw_quic_add_tls_application_protocol")
public func _c_nw_quic_add_tls_application_protocol(_ o: UnsafeRawPointer, _ p: UnsafePointer<CChar>) { quic(o)?.alpn.append(String(cString: p)) }
@_cdecl("nw_quic_copy_sec_protocol_options")
public func _c_nw_quic_copy_sec_protocol_options(_ o: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCSecObject(quic(o)?.securityProtocolOptions ?? sec_protocol_options_t()))
}
@_cdecl("nw_quic_copy_sec_protocol_metadata")
public func _c_nw_quic_copy_sec_protocol_metadata(_ m: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCSecObject(quicMeta(m)?.securityProtocolMetadata ?? sec_protocol_metadata_t()))
}
@_cdecl("nw_quic_get_stream_is_unidirectional") public func _c_nw_quic_get_stream_is_unidirectional(_ o: UnsafeRawPointer) -> Bool { quic(o)?.direction == .unidirectional }
@_cdecl("nw_quic_set_stream_is_unidirectional")
public func _c_nw_quic_set_stream_is_unidirectional(_ o: UnsafeRawPointer, _ v: Bool) { quic(o)?.direction = v ? .unidirectional : .bidirectional }
@_cdecl("nw_quic_get_stream_is_datagram") public func _c_nw_quic_get_stream_is_datagram(_ o: UnsafeRawPointer) -> Bool { quic(o)?.isDatagram ?? false }
@_cdecl("nw_quic_set_stream_is_datagram") public func _c_nw_quic_set_stream_is_datagram(_ o: UnsafeRawPointer, _ v: Bool) { quic(o)?.isDatagram = v }
@_cdecl("nw_quic_get_idle_timeout") public func _c_nw_quic_get_idle_timeout(_ o: UnsafeRawPointer) -> UInt32 { UInt32(clamping: quic(o)?.idleTimeout ?? 0) }
@_cdecl("nw_quic_set_idle_timeout") public func _c_nw_quic_set_idle_timeout(_ o: UnsafeRawPointer, _ v: UInt32) { quic(o)?.idleTimeout = Int(v) }
@_cdecl("nw_quic_get_max_udp_payload_size") public func _c_nw_quic_get_max_udp_payload_size(_ o: UnsafeRawPointer) -> UInt16 { UInt16(clamping: quic(o)?.maxUDPPayloadSize ?? 0) }
@_cdecl("nw_quic_set_max_udp_payload_size") public func _c_nw_quic_set_max_udp_payload_size(_ o: UnsafeRawPointer, _ v: UInt16) { quic(o)?.maxUDPPayloadSize = Int(v) }
@_cdecl("nw_quic_get_initial_max_data") public func _c_nw_quic_get_initial_max_data(_ o: UnsafeRawPointer) -> UInt64 { UInt64(quic(o)?.initialMaxData ?? 0) }
@_cdecl("nw_quic_set_initial_max_data") public func _c_nw_quic_set_initial_max_data(_ o: UnsafeRawPointer, _ v: UInt64) { quic(o)?.initialMaxData = Int(clamping: v) }
@_cdecl("nw_quic_get_initial_max_stream_data_bidirectional_local")
public func _c_nw_quic_get_initial_max_stream_data_bidirectional_local(_ o: UnsafeRawPointer) -> UInt64 { UInt64(quic(o)?.initialMaxStreamDataBidirectionalLocal ?? 0) }
@_cdecl("nw_quic_set_initial_max_stream_data_bidirectional_local")
public func _c_nw_quic_set_initial_max_stream_data_bidirectional_local(_ o: UnsafeRawPointer, _ v: UInt64) { quic(o)?.initialMaxStreamDataBidirectionalLocal = Int(clamping: v) }
@_cdecl("nw_quic_get_initial_max_stream_data_bidirectional_remote")
public func _c_nw_quic_get_initial_max_stream_data_bidirectional_remote(_ o: UnsafeRawPointer) -> UInt64 { UInt64(quic(o)?.initialMaxStreamDataBidirectionalRemote ?? 0) }
@_cdecl("nw_quic_set_initial_max_stream_data_bidirectional_remote")
public func _c_nw_quic_set_initial_max_stream_data_bidirectional_remote(_ o: UnsafeRawPointer, _ v: UInt64) { quic(o)?.initialMaxStreamDataBidirectionalRemote = Int(clamping: v) }
@_cdecl("nw_quic_get_initial_max_stream_data_unidirectional")
public func _c_nw_quic_get_initial_max_stream_data_unidirectional(_ o: UnsafeRawPointer) -> UInt64 { UInt64(quic(o)?.initialMaxStreamDataUnidirectional ?? 0) }
@_cdecl("nw_quic_set_initial_max_stream_data_unidirectional")
public func _c_nw_quic_set_initial_max_stream_data_unidirectional(_ o: UnsafeRawPointer, _ v: UInt64) { quic(o)?.initialMaxStreamDataUnidirectional = Int(clamping: v) }
@_cdecl("nw_quic_get_initial_max_streams_bidirectional")
public func _c_nw_quic_get_initial_max_streams_bidirectional(_ o: UnsafeRawPointer) -> UInt64 { UInt64(quic(o)?.initialMaxStreamsBidirectional ?? 0) }
@_cdecl("nw_quic_set_initial_max_streams_bidirectional")
public func _c_nw_quic_set_initial_max_streams_bidirectional(_ o: UnsafeRawPointer, _ v: UInt64) { quic(o)?.initialMaxStreamsBidirectional = Int(clamping: v) }
@_cdecl("nw_quic_get_initial_max_streams_unidirectional")
public func _c_nw_quic_get_initial_max_streams_unidirectional(_ o: UnsafeRawPointer) -> UInt64 { UInt64(quic(o)?.initialMaxStreamsUnidirectional ?? 0) }
@_cdecl("nw_quic_set_initial_max_streams_unidirectional")
public func _c_nw_quic_set_initial_max_streams_unidirectional(_ o: UnsafeRawPointer, _ v: UInt64) { quic(o)?.initialMaxStreamsUnidirectional = Int(clamping: v) }
@_cdecl("nw_quic_get_max_datagram_frame_size") public func _c_nw_quic_get_max_datagram_frame_size(_ o: UnsafeRawPointer) -> UInt16 { UInt16(clamping: quic(o)?.maxDatagramFrameSize ?? 0) }
@_cdecl("nw_quic_set_max_datagram_frame_size") public func _c_nw_quic_set_max_datagram_frame_size(_ o: UnsafeRawPointer, _ v: UInt16) { quic(o)?.maxDatagramFrameSize = Int(v) }
@_cdecl("nw_quic_get_stream_id") public func _c_nw_quic_get_stream_id(_ m: UnsafeRawPointer) -> UInt64 { quicMeta(m)?.streamIdentifier ?? 0 }
@_cdecl("nw_quic_get_stream_type") public func _c_nw_quic_get_stream_type(_ m: UnsafeRawPointer) -> UInt8 { 0 }        /* unknown: no streams on isim yet */
@_cdecl("nw_quic_get_stream_application_error") public func _c_nw_quic_get_stream_application_error(_ m: UnsafeRawPointer) -> UInt64 { quicMeta(m)?.streamApplicationErrorCode ?? 0 }
@_cdecl("nw_quic_set_stream_application_error")
public func _c_nw_quic_set_stream_application_error(_ m: UnsafeRawPointer, _ v: UInt64) { quicMeta(m)?.streamApplicationErrorCode = v }
@_cdecl("nw_quic_get_stream_usable_datagram_frame_size")
public func _c_nw_quic_get_stream_usable_datagram_frame_size(_ m: UnsafeRawPointer) -> UInt16 { UInt16(clamping: quicMeta(m)?.usableDatagramFrameSize ?? 0) }
@_cdecl("nw_quic_get_local_max_streams_bidirectional")
public func _c_nw_quic_get_local_max_streams_bidirectional(_ m: UnsafeRawPointer) -> UInt64 { UInt64(quicMeta(m)?.localMaxStreamsBidirectional ?? 0) }
@_cdecl("nw_quic_set_local_max_streams_bidirectional")
public func _c_nw_quic_set_local_max_streams_bidirectional(_ m: UnsafeRawPointer, _ v: UInt64) { quicMeta(m)?.localMaxStreamsBidirectional = Int(clamping: v) }
@_cdecl("nw_quic_get_local_max_streams_unidirectional")
public func _c_nw_quic_get_local_max_streams_unidirectional(_ m: UnsafeRawPointer) -> UInt64 { UInt64(quicMeta(m)?.localMaxStreamsUnidirectional ?? 0) }
@_cdecl("nw_quic_set_local_max_streams_unidirectional")
public func _c_nw_quic_set_local_max_streams_unidirectional(_ m: UnsafeRawPointer, _ v: UInt64) { quicMeta(m)?.localMaxStreamsUnidirectional = Int(clamping: v) }
@_cdecl("nw_quic_get_remote_max_streams_bidirectional")
public func _c_nw_quic_get_remote_max_streams_bidirectional(_ m: UnsafeRawPointer) -> UInt64 { UInt64(quicMeta(m)?.remoteMaxStreamsBidirectional ?? 0) }
@_cdecl("nw_quic_get_remote_max_streams_unidirectional")
public func _c_nw_quic_get_remote_max_streams_unidirectional(_ m: UnsafeRawPointer) -> UInt64 { UInt64(quicMeta(m)?.remoteMaxStreamsUnidirectional ?? 0) }
@_cdecl("nw_quic_get_remote_idle_timeout") public func _c_nw_quic_get_remote_idle_timeout(_ m: UnsafeRawPointer) -> UInt64 { UInt64(quicMeta(m)?.remoteIdleTimeout ?? 0) }
@_cdecl("nw_quic_get_keepalive_interval")
public func _c_nw_quic_get_keepalive_interval(_ m: UnsafeRawPointer) -> UInt16 {
    switch quicMeta(m)?.keepAlive ?? .off { case .off: return 0; case .on: return 1; case .seconds(let s): return UInt16(clamping: s) }
}
@_cdecl("nw_quic_set_keepalive_interval")
public func _c_nw_quic_set_keepalive_interval(_ m: UnsafeRawPointer, _ v: UInt16) { quicMeta(m)?.keepAlive = v == 0 ? .off : v == 1 ? .on : .seconds(Int(v)) }
@_cdecl("nw_quic_get_application_error") public func _c_nw_quic_get_application_error(_ m: UnsafeRawPointer) -> UInt64 { quicMeta(m)?.applicationError.code ?? 0 }
@_cdecl("nw_quic_get_application_error_reason")
public func _c_nw_quic_get_application_error_reason(_ m: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    obj(m, _NWCMetadata.self).cString("reason", quicMeta(m)?.applicationError.reason)
}
@_cdecl("nw_quic_set_application_error")
public func _c_nw_quic_set_application_error(_ m: UnsafeRawPointer, _ code: UInt64, _ reason: UnsafePointer<CChar>?) {
    quicMeta(m)?.applicationError = NWProtocolQUIC.ApplicationError(code: code, reason: reason.map { String(cString: $0) })
}

// MARK: - WebSocket

private func ws(_ o: UnsafeRawPointer) -> NWProtocolWebSocket.Options? { options(o, NWProtocolWebSocket.Options.self) }
private func wsMeta(_ m: UnsafeRawPointer) -> NWProtocolWebSocket.Metadata? { meta(m, NWProtocolWebSocket.Metadata.self) }
private let opcodes: [Int32: NWProtocolWebSocket.Opcode] = [0: .cont, 1: .text, 2: .binary, 8: .close, 9: .ping, 10: .pong]
@_cdecl("nw_ws_create_options")
public func _c_nw_ws_create_options(_ version: UInt32) -> UnsafeMutableRawPointer { retained(_NWCProtocolOptions(NWProtocolWebSocket.Options(.version13))) }
@_cdecl("nw_ws_options_add_additional_header")
public func _c_nw_ws_options_add_additional_header(_ o: UnsafeRawPointer, _ n: UnsafePointer<CChar>, _ v: UnsafePointer<CChar>) {
    guard let w = ws(o) else { return }
    w.setAdditionalHeaders(w.headers + [(name: String(cString: n), value: String(cString: v))])
}
@_cdecl("nw_ws_options_add_subprotocol")
public func _c_nw_ws_options_add_subprotocol(_ o: UnsafeRawPointer, _ p: UnsafePointer<CChar>) { guard let w = ws(o) else { return }; w.setSubprotocols(w.subprotocols + [String(cString: p)]) }
@_cdecl("nw_ws_options_set_auto_reply_ping") public func _c_nw_ws_options_set_auto_reply_ping(_ o: UnsafeRawPointer, _ v: Bool) { ws(o)?.autoReplyPing = v }
@_cdecl("nw_ws_options_set_skip_handshake") public func _c_nw_ws_options_set_skip_handshake(_ o: UnsafeRawPointer, _ v: Bool) { ws(o)?.skipHandshake = v }
@_cdecl("nw_ws_options_set_maximum_message_size") public func _c_nw_ws_options_set_maximum_message_size(_ o: UnsafeRawPointer, _ v: Int) { ws(o)?.maximumMessageSize = v }
@_cdecl("nw_ws_options_set_client_request_handler")
public func _c_nw_ws_options_set_client_request_handler(_ o: UnsafeRawPointer, _ q: OpaquePointer, _ h: @escaping @convention(block) (NSObject) -> NSObject) {
    dispatch_retain(UnsafeMutableRawPointer(q))
    let queue = DispatchQueue(label: "isim.nw_ws.client_request")
    ws(o)?.setClientRequestHandler(queue) { request in
        nonisolated(unsafe) var answer: NWProtocolWebSocket.Response = .init(status: .reject, subprotocol: nil, additionalHeaders: nil)
        let done = DispatchSemaphore(value: 0)
        dispatch_async(q) { answer = (h(_NWCWSRequest(request)) as? _NWCWSResponse)?.response ?? answer; done.signal() }
        done.wait()
        return answer
    }
}
@_cdecl("nw_ws_create_metadata")
public func _c_nw_ws_create_metadata(_ op: Int32) -> UnsafeMutableRawPointer { retained(_NWCMetadata(NWProtocolWebSocket.Metadata(opcode: opcodes[op] ?? .binary))) }
@_cdecl("nw_ws_metadata_get_opcode")
public func _c_nw_ws_metadata_get_opcode(_ m: UnsafeRawPointer) -> Int32 {
    guard let o = wsMeta(m)?.opcode else { return -1 }
    return opcodes.first { $0.value == o }?.key ?? -1
}
@_cdecl("nw_ws_metadata_set_close_code")
public func _c_nw_ws_metadata_set_close_code(_ m: UnsafeRawPointer, _ code: UInt32) {
    wsMeta(m)?.closeCode = NWProtocolWebSocket.CloseCode(rawValue: UInt16(clamping: code)) ?? .protocolCode(.normalClosure)
}
@_cdecl("nw_ws_metadata_get_close_code") public func _c_nw_ws_metadata_get_close_code(_ m: UnsafeRawPointer) -> UInt32 { UInt32(wsMeta(m)?.closeCode.rawValue ?? 1000) }
@_cdecl("nw_ws_metadata_set_pong_handler")
public func _c_nw_ws_metadata_set_pong_handler(_ m: UnsafeRawPointer, _ q: OpaquePointer, _ h: @escaping @convention(block) (NSObject?) -> Void) {
    dispatch_retain(UnsafeMutableRawPointer(q))
    wsMeta(m)?.setPongHandler(.global()) { e in onQueue(q) { h(e.map { _NWCError($0) }) } }
}
@_cdecl("nw_ws_metadata_copy_server_response")
public func _c_nw_ws_metadata_copy_server_response(_ m: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCWSResponse(wsMeta(m)?.serverResponse ?? .init(status: .reject, subprotocol: nil, additionalHeaders: nil)))
}
@_cdecl("nw_ws_request_enumerate_subprotocols")
public func _c_nw_ws_request_enumerate_subprotocols(_ r: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<CChar>) -> Bool) -> Bool {
    let all = obj(r, _NWCWSRequest.self).request.subprotocols ?? []
    for p in all { if !p.withCString({ f($0) }) { return false } }
    return !all.isEmpty
}
@_cdecl("nw_ws_request_enumerate_additional_headers")
public func _c_nw_ws_request_enumerate_additional_headers(_ r: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool) -> Bool {
    let all = obj(r, _NWCWSRequest.self).request.additionalHeaders ?? []
    for h in all { if !h.name.withCString({ n in h.value.withCString { f(n, $0) } }) { return false } }
    return !all.isEmpty
}
@_cdecl("nw_ws_response_create")
public func _c_nw_ws_response_create(_ status: UInt32, _ sub: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer {
    retained(_NWCWSResponse(.init(status: status == 1 ? .accept : .reject, subprotocol: sub.map { String(cString: $0) }, additionalHeaders: nil)))
}
@_cdecl("nw_ws_response_get_status")
public func _c_nw_ws_response_get_status(_ r: UnsafeRawPointer?) -> UInt32 {
    guard let r else { return 0 }
    return obj(r, _NWCWSResponse.self).response.status == .accept ? 1 : 2
}
@_cdecl("nw_ws_response_get_selected_subprotocol")
public func _c_nw_ws_response_get_selected_subprotocol(_ r: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    let o = obj(r, _NWCWSResponse.self)
    guard let s = o.response.subprotocol else { return nil }
    if o.cSubprotocol == nil { o.cSubprotocol = strdup(s) }
    return UnsafePointer(o.cSubprotocol)
}
@_cdecl("nw_ws_response_add_additional_header")
public func _c_nw_ws_response_add_additional_header(_ r: UnsafeRawPointer, _ n: UnsafePointer<CChar>, _ v: UnsafePointer<CChar>) {
    let o = obj(r, _NWCWSResponse.self)
    o.response.additionalHeaders = (o.response.additionalHeaders ?? []) + [(name: String(cString: n), value: String(cString: v))]
}
@_cdecl("nw_ws_response_enumerate_additional_headers")
public func _c_nw_ws_response_enumerate_additional_headers(_ r: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool) -> Bool {
    let all = obj(r, _NWCWSResponse.self).response.additionalHeaders ?? []
    for h in all { if !h.name.withCString({ n in h.value.withCString { f(n, $0) } }) { return false } }
    return !all.isEmpty
}

// MARK: - TXT records

/* nw_txt_record_find_key_t: invalid 0, not_present 1, no_value 2, empty_value 3, non_empty_value 4 */
private func found(_ e: NWTXTRecord.Entry?) -> UInt32 {
    switch e { case nil: return 1; case .none?: return 2; case .empty?: return 3; default: return 4 }
}
private func txt(_ t: UnsafeRawPointer) -> _NWCTXTRecord { obj(t, _NWCTXTRecord.self) }
@_cdecl("nw_txt_record_create_with_bytes")
public func _c_nw_txt_record_create_with_bytes(_ b: UnsafePointer<UInt8>, _ n: Int) -> UnsafeMutableRawPointer {
    let d = Data(bytes: b, count: n)
    // a dictionary when every item is a non-empty key (before any "=") that is not repeated
    var i = 0, keys = Set<String>(), ok = n > 0
    while i < n && ok {
        let len = Int(b[i]); i += 1
        if len == 0 || i + len > n { ok = false; break }
        let item = UnsafeBufferPointer(start: b + i, count: len); i += len
        let k = String(decoding: item.prefix { $0 != UInt8(ascii: "=") }, as: UTF8.self).lowercased()
        if k.isEmpty || !keys.insert(k).inserted { ok = false }
    }
    return retained(_NWCTXTRecord(NWTXTRecord(d), bytes: ok ? nil : d))
}
@_cdecl("nw_txt_record_create_dictionary") public func _c_nw_txt_record_create_dictionary() -> UnsafeMutableRawPointer { retained(_NWCTXTRecord(NWTXTRecord())) }
@_cdecl("nw_txt_record_copy")
public func _c_nw_txt_record_copy(_ t: UnsafeRawPointer?) -> UnsafeMutableRawPointer? { t.map { retained(_NWCTXTRecord(txt($0).record, bytes: txt($0).bytes)) } }
@_cdecl("nw_txt_record_find_key")
public func _c_nw_txt_record_find_key(_ t: UnsafeRawPointer, _ k: UnsafePointer<CChar>) -> UInt32 {
    txt(t).bytes != nil ? 0 : found(txt(t).record.getEntry(for: String(cString: k)))
}
@_cdecl("nw_txt_record_access_key")
public func _c_nw_txt_record_access_key(_ t: UnsafeRawPointer, _ k: UnsafePointer<CChar>,
                                        _ f: @convention(block) (UnsafePointer<CChar>, UInt32, UnsafePointer<UInt8>?, Int) -> Bool) -> Bool {
    let e = txt(t).record.getEntry(for: String(cString: k))
    guard let d = e?.data, !d.isEmpty else { return f(k, txt(t).bytes != nil ? 0 : found(e), nil, 0) }
    return d.withUnsafeBytes { f(k, found(e), $0.bindMemory(to: UInt8.self).baseAddress, d.count) }
}
@_cdecl("nw_txt_record_set_key")
public func _c_nw_txt_record_set_key(_ t: UnsafeRawPointer, _ k: UnsafePointer<CChar>, _ v: UnsafePointer<UInt8>?, _ n: Int) -> Bool {
    let o = txt(t)
    guard o.bytes == nil else { return false }
    return o.record.setEntry(v == nil ? .none : n == 0 ? .empty : .data(Data(bytes: v!, count: n)), for: String(cString: k))
}
@_cdecl("nw_txt_record_remove_key")
public func _c_nw_txt_record_remove_key(_ t: UnsafeRawPointer, _ k: UnsafePointer<CChar>) -> Bool {
    let o = txt(t), key = String(cString: k)
    guard let real = o.record.dictionary.keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) else { return false }
    return o.record.removeEntry(key: real)
}
@_cdecl("nw_txt_record_get_key_count") public func _c_nw_txt_record_get_key_count(_ t: UnsafeRawPointer?) -> Int { t.map { txt($0).record.count } ?? 0 }
@_cdecl("nw_txt_record_access_bytes")
public func _c_nw_txt_record_access_bytes(_ t: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<UInt8>, Int) -> Bool) -> Bool {
    let d = txt(t).bytes ?? txt(t).record.data
    return d.withUnsafeBytes { f($0.bindMemory(to: UInt8.self).baseAddress ?? UnsafePointer(bitPattern: 1)!, d.count) }
}
@_cdecl("nw_txt_record_apply")
public func _c_nw_txt_record_apply(_ t: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<CChar>, UInt32, UnsafePointer<UInt8>, Int) -> Bool) -> Bool {
    let r = txt(t).record
    for key in r.dictionary.keys.sorted() {
        let e = r.getEntry(for: key), d = e?.data ?? Data()
        let go = key.withCString { k in d.withUnsafeBytes { f(k, found(e), $0.bindMemory(to: UInt8.self).baseAddress ?? UnsafePointer(bitPattern: 1)!, d.count) } }
        if !go { return false }
    }
    return true
}
@_cdecl("nw_txt_record_is_equal")
public func _c_nw_txt_record_is_equal(_ a: UnsafeRawPointer?, _ b: UnsafeRawPointer?) -> Bool {
    guard let a, let b else { return a == nil && b == nil }
    return txt(a).record.entries == txt(b).record.entries && txt(a).bytes == txt(b).bytes
}
@_cdecl("nw_txt_record_is_dictionary") public func _c_nw_txt_record_is_dictionary(_ t: UnsafeRawPointer) -> Bool { txt(t).bytes == nil }
@_cdecl("nw_endpoint_copy_txt_record")
public func _c_nw_endpoint_copy_txt_record(_ e: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(e, _NWCEndpoint.self).endpoint.txtRecord.map { retained(_NWCTXTRecord($0)) }
}
@_cdecl("nw_endpoint_get_signature")
public func _c_nw_endpoint_get_signature(_ e: UnsafeRawPointer, _ n: UnsafeMutablePointer<Int>) -> UnsafePointer<UInt8>? { n.pointee = 0; return nil }
@_cdecl("nw_advertise_descriptor_copy_txt_record_object")
public func _c_nw_advertise_descriptor_copy_txt_record_object(_ d: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(d, _NWCAdvertiseDescriptor.self).service.txtRecordObject.map { retained(_NWCTXTRecord($0)) }
}
@_cdecl("nw_advertise_descriptor_set_txt_record_object")
public func _c_nw_advertise_descriptor_set_txt_record_object(_ d: UnsafeRawPointer, _ t: UnsafeRawPointer?) {
    obj(d, _NWCAdvertiseDescriptor.self).service.txtRecordObject = t.map { txt($0).record }
}
@_cdecl("nw_advertise_descriptor_set_no_auto_rename")
public func _c_nw_advertise_descriptor_set_no_auto_rename(_ d: UnsafeRawPointer, _ v: Bool) { obj(d, _NWCAdvertiseDescriptor.self).service.noAutoRename = v }
@_cdecl("nw_advertise_descriptor_get_no_auto_rename")
public func _c_nw_advertise_descriptor_get_no_auto_rename(_ d: UnsafeRawPointer) -> Bool { obj(d, _NWCAdvertiseDescriptor.self).service.noAutoRename }
@_cdecl("nw_advertise_descriptor_create_application_service")
public func _c_nw_advertise_descriptor_create_application_service(_ n: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    let d = _NWCAdvertiseDescriptor(NWListener.Service(applicationService: String(cString: n)))
    d.applicationService = strdup(n)
    return retained(d)
}
@_cdecl("nw_advertise_descriptor_get_application_service_name")
public func _c_nw_advertise_descriptor_get_application_service_name(_ d: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    obj(d, _NWCAdvertiseDescriptor.self).applicationService.map { UnsafePointer($0) }
}
@_cdecl("nw_browse_descriptor_create_application_service")
public func _c_nw_browse_descriptor_create_application_service(_ n: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    let name = String(cString: n)
    let d = _NWCBrowseDescriptor(type: NWListener._applicationServiceType(name), domain: nil)
    d.applicationService = strdup(n)
    d.includeTXT = true
    return retained(d)
}
@_cdecl("nw_browse_descriptor_get_application_service_name")
public func _c_nw_browse_descriptor_get_application_service_name(_ d: UnsafeRawPointer) -> UnsafePointer<CChar>? {
    obj(d, _NWCBrowseDescriptor.self).applicationService.map { UnsafePointer($0) }
}
@_cdecl("nw_browse_result_copy_txt_record_object")
public func _c_nw_browse_result_copy_txt_record_object(_ r: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    let o = obj(r, _NWCBrowseResult.self)
    guard !o.isNone, case .bonjour(let t) = o.result.metadata else { return nil }
    return retained(_NWCTXTRecord(t))
}

// MARK: - paths and parameters

private func path(_ p: UnsafeRawPointer) -> NWPath { obj(p, _NWCPath.self).path }
@_cdecl("nw_path_get_unsatisfied_reason")
public func _c_nw_path_get_unsatisfied_reason(_ p: UnsafeRawPointer) -> UInt32 {
    switch path(p).unsatisfiedReason {
    case .notAvailable: return 0
    case .cellularDenied: return 1
    case .wifiDenied: return 2
    case .localNetworkDenied: return 3
    case .vpnInactive: return 4
    }
}
@_cdecl("nw_path_is_equal") public func _c_nw_path_is_equal(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer) -> Bool { path(a) == path(b) }
@_cdecl("nw_path_enumerate_gateways")
public func _c_nw_path_enumerate_gateways(_ p: UnsafeRawPointer, _ f: @convention(block) (NSObject) -> Bool) {
    for g in path(p).gateways { if !f(_NWCEndpoint(g)) { break } }
}
@_cdecl("nw_path_get_link_quality") public func _c_nw_path_get_link_quality(_ p: UnsafeRawPointer) -> UInt8 { 0 }   /* unknown: isim measures none */
@_cdecl("nw_path_is_ultra_constrained") public func _c_nw_path_is_ultra_constrained(_ p: UnsafeRawPointer) -> Bool { path(p).isUltraConstrained }
@_cdecl("nw_path_monitor_prohibit_interface_type")
public func _c_nw_path_monitor_prohibit_interface_type(_ m: UnsafeRawPointer, _ t: Int32) { obj(m, _NWCPathMonitor.self).prohibit(t) }
private func params(_ p: UnsafeRawPointer) -> NWParameters { obj(p, _NWCParameters.self).parameters }
@_cdecl("nw_parameters_create_application_service")
public func _c_nw_parameters_create_application_service() -> UnsafeMutableRawPointer { retained(_NWCParameters(.applicationService)) }
@_cdecl("nw_parameters_set_attribution")
public func _c_nw_parameters_set_attribution(_ p: UnsafeRawPointer, _ v: UInt8) { params(p).attribution = v == 2 ? .user : .developer }
@_cdecl("nw_parameters_get_attribution") public func _c_nw_parameters_get_attribution(_ p: UnsafeRawPointer) -> UInt8 { params(p).attribution == .user ? 2 : 1 }
@_cdecl("nw_parameters_set_requires_dnssec_validation")
public func _c_nw_parameters_set_requires_dnssec_validation(_ p: UnsafeRawPointer, _ v: Bool) { params(p).requiresDNSSECValidation = v }
@_cdecl("nw_parameters_requires_dnssec_validation")
public func _c_nw_parameters_requires_dnssec_validation(_ p: UnsafeRawPointer) -> Bool { params(p).requiresDNSSECValidation }
@_cdecl("nw_parameters_set_allow_ultra_constrained")
public func _c_nw_parameters_set_allow_ultra_constrained(_ p: UnsafeRawPointer, _ v: Bool) { params(p).allowUltraConstrainedPaths = v }
@_cdecl("nw_parameters_get_allow_ultra_constrained")
public func _c_nw_parameters_get_allow_ultra_constrained(_ p: UnsafeRawPointer) -> Bool { params(p).allowUltraConstrainedPaths }

// MARK: - establishment and data transfer reports

@_cdecl("nw_connection_access_establishment_report")
public func _c_nw_connection_access_establishment_report(_ c: UnsafeRawPointer, _ q: OpaquePointer, _ f: @escaping @convention(block) (NSObject?) -> Void) {
    dispatch_retain(UnsafeMutableRawPointer(q))
    let qb = _NWCUnchecked(q), fb = _NWCUnchecked(f)
    obj(c, _NWCConnection.self).connection.requestEstablishmentReport(queue: .global()) { r in
        let report = _NWCUnchecked(r)
        onQueue(qb.value) { fb.value(report.value.map { _NWCEstablishmentReport($0) }); dispatch_release(UnsafeMutableRawPointer(qb.value)) }
    }
}
private func est(_ r: UnsafeRawPointer) -> NWConnection.EstablishmentReport { obj(r, _NWCEstablishmentReport.self).report }
@_cdecl("nw_establishment_report_get_duration_milliseconds") public func _c_nw_establishment_report_get_duration_milliseconds(_ r: UnsafeRawPointer) -> UInt64 { ms(est(r).duration) }
@_cdecl("nw_establishment_report_get_attempt_started_after_milliseconds")
public func _c_nw_establishment_report_get_attempt_started_after_milliseconds(_ r: UnsafeRawPointer) -> UInt64 { ms(est(r).attemptStartedAfterInterval) }
@_cdecl("nw_establishment_report_get_previous_attempt_count")
public func _c_nw_establishment_report_get_previous_attempt_count(_ r: UnsafeRawPointer) -> UInt32 { UInt32(clamping: est(r).previousAttemptCount) }
@_cdecl("nw_establishment_report_get_used_proxy") public func _c_nw_establishment_report_get_used_proxy(_ r: UnsafeRawPointer) -> Bool { est(r).usedProxy }
@_cdecl("nw_establishment_report_get_proxy_configured") public func _c_nw_establishment_report_get_proxy_configured(_ r: UnsafeRawPointer) -> Bool { est(r).proxyConfigured }
@_cdecl("nw_establishment_report_copy_proxy_endpoint")
public func _c_nw_establishment_report_copy_proxy_endpoint(_ r: UnsafeRawPointer) -> UnsafeMutableRawPointer? { est(r).proxyEndpoint.map { retained(_NWCEndpoint($0)) } }
private func sourceValue(_ s: NWConnection.EstablishmentReport.Resolution.Source) -> UInt32 { s == .query ? 1 : s == .cache ? 2 : 3 }
@_cdecl("nw_establishment_report_enumerate_resolutions")
public func _c_nw_establishment_report_enumerate_resolutions(_ r: UnsafeRawPointer, _ f: @convention(block) (UInt32, UInt64, UInt32, NSObject, NSObject) -> Bool) {
    for x in est(r).resolutions {
        if !f(sourceValue(x.source), ms(x.duration), UInt32(clamping: x.endpointCount), _NWCEndpoint(x.successfulEndpoint), _NWCEndpoint(x.preferredEndpoint)) { break }
    }
}
@_cdecl("nw_establishment_report_enumerate_resolution_reports")
public func _c_nw_establishment_report_enumerate_resolution_reports(_ r: UnsafeRawPointer, _ f: @convention(block) (NSObject) -> Bool) {
    for x in est(r).resolutions { if !f(_NWCResolutionReport(x)) { break } }
}
@_cdecl("nw_establishment_report_enumerate_protocols")
public func _c_nw_establishment_report_enumerate_protocols(_ r: UnsafeRawPointer, _ f: @convention(block) (NSObject, UInt64, UInt64) -> Bool) {
    for h in est(r).handshakes { if !f(_NWCDefinition(h.definition), ms(h.handshakeDuration), ms(h.handshakeRTT)) { break } }
}
private func res(_ r: UnsafeRawPointer) -> NWConnection.EstablishmentReport.Resolution { obj(r, _NWCResolutionReport.self).resolution }
@_cdecl("nw_resolution_report_get_source") public func _c_nw_resolution_report_get_source(_ r: UnsafeRawPointer) -> UInt32 { sourceValue(res(r).source) }
@_cdecl("nw_resolution_report_get_milliseconds") public func _c_nw_resolution_report_get_milliseconds(_ r: UnsafeRawPointer) -> UInt64 { ms(res(r).duration) }
@_cdecl("nw_resolution_report_get_endpoint_count") public func _c_nw_resolution_report_get_endpoint_count(_ r: UnsafeRawPointer) -> UInt32 { UInt32(clamping: res(r).endpointCount) }
@_cdecl("nw_resolution_report_copy_successful_endpoint")
public func _c_nw_resolution_report_copy_successful_endpoint(_ r: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCEndpoint(res(r).successfulEndpoint)) }
@_cdecl("nw_resolution_report_copy_preferred_endpoint")
public func _c_nw_resolution_report_copy_preferred_endpoint(_ r: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCEndpoint(res(r).preferredEndpoint)) }
@_cdecl("nw_resolution_report_get_protocol")
public func _c_nw_resolution_report_get_protocol(_ r: UnsafeRawPointer) -> UInt32 {
    switch res(r).dnsProtocol { case .unknown: return 0; case .udp: return 1; case .tcp: return 2; case .tls: return 3; case .https: return 4 }
}
@_cdecl("nw_connection_create_new_data_transfer_report")
public func _c_nw_connection_create_new_data_transfer_report(_ c: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCDataTransferReport(obj(c, _NWCConnection.self).connection.startDataTransferReport()))
}
@_cdecl("nw_data_transfer_report_collect")
public func _c_nw_data_transfer_report_collect(_ r: UnsafeRawPointer, _ q: OpaquePointer, _ f: @escaping @convention(block) (NSObject) -> Void) {
    let o = obj(r, _NWCDataTransferReport.self)
    dispatch_retain(UnsafeMutableRawPointer(q))
    let qb = _NWCUnchecked(q), fb = _NWCUnchecked(f), ob = _NWCUnchecked(o)
    o.pending.collect(queue: .global()) { report in
        ob.value.collected = report
        onQueue(qb.value) { fb.value(ob.value); dispatch_release(UnsafeMutableRawPointer(qb.value)) }
    }
}
private func transfer(_ r: UnsafeRawPointer) -> NWConnection.DataTransferReport? { obj(r, _NWCDataTransferReport.self).collected }
/// a path's report; NW_ALL_PATHS (UINT32_MAX) is the aggregate
private func pathReport(_ r: UnsafeRawPointer, _ i: UInt32) -> NWConnection.DataTransferReport.PathReport? {
    guard let t = transfer(r) else { return nil }
    if i == UInt32.max { return t.aggregatePathReport }
    return Int(i) < t.pathReports.count ? t.pathReports[Int(i)] : nil
}
@_cdecl("nw_data_transfer_report_get_state") public func _c_nw_data_transfer_report_get_state(_ r: UnsafeRawPointer) -> UInt32 { transfer(r) == nil ? 1 : 2 }
@_cdecl("nw_data_transfer_report_get_duration_milliseconds")
public func _c_nw_data_transfer_report_get_duration_milliseconds(_ r: UnsafeRawPointer) -> UInt64 { transfer(r).map { ms($0.duration) } ?? 0 }
@_cdecl("nw_data_transfer_report_get_path_count")
public func _c_nw_data_transfer_report_get_path_count(_ r: UnsafeRawPointer) -> UInt32 { UInt32(transfer(r)?.pathReports.count ?? 0) }
@_cdecl("nw_data_transfer_report_copy_path_interface")
public func _c_nw_data_transfer_report_copy_path_interface(_ r: UnsafeRawPointer, _ i: UInt32) -> UnsafeMutableRawPointer {
    retained(_NWCInterface(pathReport(r, i)?.interface ?? NWInterface(type: .loopback, name: "lo0", index: 1)))
}
@_cdecl("nw_data_transfer_report_get_path_radio_type")
public func _c_nw_data_transfer_report_get_path_radio_type(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt32 { 0 }   /* unknown: the host's interfaces */
@_cdecl("nw_data_transfer_report_get_received_ip_packet_count")
public func _c_nw_data_transfer_report_get_received_ip_packet_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.receivedIPPacketCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_sent_ip_packet_count")
public func _c_nw_data_transfer_report_get_sent_ip_packet_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.sentIPPacketCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_received_transport_byte_count")
public func _c_nw_data_transfer_report_get_received_transport_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.receivedTransportByteCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_received_transport_duplicate_byte_count")
public func _c_nw_data_transfer_report_get_received_transport_duplicate_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.receivedTransportDuplicateByteCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_received_transport_out_of_order_byte_count")
public func _c_nw_data_transfer_report_get_received_transport_out_of_order_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.receivedTransportOutOfOrderByteCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_sent_transport_byte_count")
public func _c_nw_data_transfer_report_get_sent_transport_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.sentTransportByteCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_sent_transport_retransmitted_byte_count")
public func _c_nw_data_transfer_report_get_sent_transport_retransmitted_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.retransmittedTransportByteCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds")
public func _c_nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i).map { ms($0.transportSmoothedRTT) } ?? 0 }
@_cdecl("nw_data_transfer_report_get_transport_minimum_rtt_milliseconds")
public func _c_nw_data_transfer_report_get_transport_minimum_rtt_milliseconds(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i).map { ms($0.transportMinimumRTT) } ?? 0 }
@_cdecl("nw_data_transfer_report_get_transport_rtt_variance")
public func _c_nw_data_transfer_report_get_transport_rtt_variance(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i).map { ms($0.transportRTTVariance) } ?? 0 }
@_cdecl("nw_data_transfer_report_get_received_application_byte_count")
public func _c_nw_data_transfer_report_get_received_application_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.receivedApplicationByteCount ?? 0 }
@_cdecl("nw_data_transfer_report_get_sent_application_byte_count")
public func _c_nw_data_transfer_report_get_sent_application_byte_count(_ r: UnsafeRawPointer, _ i: UInt32) -> UInt64 { pathReport(r, i)?.sentApplicationByteCount ?? 0 }

// MARK: - connection groups

private func gd(_ d: UnsafeRawPointer) -> _NWCGroupDescriptor { obj(d, _NWCGroupDescriptor.self) }
@_cdecl("nw_group_descriptor_create_multicast")
public func _c_nw_group_descriptor_create_multicast(_ e: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCGroupDescriptor([obj(e, _NWCEndpoint.self).endpoint], multiplex: false))
}
@_cdecl("nw_group_descriptor_create_multiplex")
public func _c_nw_group_descriptor_create_multiplex(_ e: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCGroupDescriptor([obj(e, _NWCEndpoint.self).endpoint], multiplex: true))
}
@_cdecl("nw_group_descriptor_add_endpoint")
public func _c_nw_group_descriptor_add_endpoint(_ d: UnsafeRawPointer, _ e: UnsafeRawPointer) -> Bool {
    let o = gd(d), ep = obj(e, _NWCEndpoint.self).endpoint
    guard !o.multiplex, (try? NWMulticastGroup(for: [ep])) != nil else { return false }
    o.endpoints.append(ep)
    return true
}
@_cdecl("nw_group_descriptor_enumerate_endpoints")
public func _c_nw_group_descriptor_enumerate_endpoints(_ d: UnsafeRawPointer, _ f: @convention(block) (NSObject) -> Bool) {
    for e in gd(d).endpoints { if !f(_NWCEndpoint(e)) { break } }
}
@_cdecl("nw_multicast_group_descriptor_set_specific_source")
public func _c_nw_multicast_group_descriptor_set_specific_source(_ d: UnsafeRawPointer, _ e: UnsafeRawPointer) { gd(d).source = obj(e, _NWCEndpoint.self).endpoint }
@_cdecl("nw_multicast_group_descriptor_set_disable_unicast_traffic")
public func _c_nw_multicast_group_descriptor_set_disable_unicast_traffic(_ d: UnsafeRawPointer, _ v: Bool) { gd(d).disableUnicast = v }
@_cdecl("nw_multicast_group_descriptor_get_disable_unicast_traffic")
public func _c_nw_multicast_group_descriptor_get_disable_unicast_traffic(_ d: UnsafeRawPointer) -> Bool { gd(d).disableUnicast }
private func group(_ g: UnsafeRawPointer) -> _NWCConnectionGroup { obj(g, _NWCConnectionGroup.self) }
/* nw_connection_group_state_t: invalid 0, waiting 1, ready 2, failed 3, cancelled 4 */
private func groupState(_ s: NWConnectionGroup.State) -> (UInt32, NWError?)? {
    switch s {
    case .setup: return nil
    case .waiting(let e): return (1, e)
    case .ready: return (2, nil)
    case .failed(let e): return (3, e)
    case .cancelled: return (4, nil)
    }
}
@_cdecl("nw_connection_group_create")
public func _c_nw_connection_group_create(_ d: UnsafeRawPointer, _ p: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let desc = gd(d)
    let g = NWConnectionGroup(with: desc.descriptor() ?? NWMultiplexGroup(to: desc.endpoints.first ?? .hostPort(host: "0.0.0.0", port: .any)), using: params(p))
    return retained(_NWCConnectionGroup(g, desc))
}
@_cdecl("nw_connection_group_copy_descriptor")
public func _c_nw_connection_group_copy_descriptor(_ g: UnsafeRawPointer) -> UnsafeMutableRawPointer { Unmanaged.passRetained(group(g).descriptor).toOpaque() }
@_cdecl("nw_connection_group_copy_parameters")
public func _c_nw_connection_group_copy_parameters(_ g: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCParameters(group(g).group.parameters)) }
@_cdecl("nw_connection_group_set_queue") public func _c_nw_connection_group_set_queue(_ g: UnsafeRawPointer, _ q: OpaquePointer) { group(g).queue = q }
@_cdecl("nw_connection_group_set_state_changed_handler")
public func _c_nw_connection_group_set_state_changed_handler(_ g: UnsafeRawPointer, _ h: (@convention(block) (UInt32, NSObject?) -> Void)?) {
    let o = group(g)
    guard let h else { o.group.stateUpdateHandler = nil; return }
    let box = _NWCUnchecked(h)
    o.group.stateUpdateHandler = { [weak o] s in
        guard let o, let (v, e) = groupState(s) else { return }
        o.onQueue { box.value(v, e.map { _NWCError($0) }) }
    }
}
@_cdecl("nw_connection_group_set_receive_handler")
public func _c_nw_connection_group_set_receive_handler(_ g: UnsafeRawPointer, _ max: UInt32, _ reject: Bool,
                                                       _ h: (@convention(block) (OpaquePointer?, NSObject, Bool) -> Void)?) {
    let o = group(g)
    guard let h else { o.group.setReceiveHandler(maximumMessageSize: Int(max), rejectOversizedMessages: reject) { _, _, _ in }; return }
    let box = _NWCUnchecked(h)
    o.group.setReceiveHandler(maximumMessageSize: Int(max), rejectOversizedMessages: reject) { [weak o] m, d, complete in
        guard let o else { return }
        let ctx = _NWCContext(identifier: "isim.group.message", isFinal: m.isFinal)
        ctx.groupMessage = m
        let dd = d.flatMap { dispatchData($0) }
        o.onQueue { box.value(dd, ctx, complete); if let dd { dispatch_release(UnsafeMutableRawPointer(dd)) } }
    }
}
@_cdecl("nw_connection_group_set_new_connection_handler")
public func _c_nw_connection_group_set_new_connection_handler(_ g: UnsafeRawPointer, _ h: (@convention(block) (NSObject) -> Void)?) {
    let o = group(g)
    guard let h else { o.group.newConnectionHandler = nil; return }
    let box = _NWCUnchecked(h)
    o.group.newConnectionHandler = { [weak o] c in o?.onQueue { box.value(_NWCConnection(c)) } }
}
@_cdecl("nw_connection_group_start")
public func _c_nw_connection_group_start(_ g: UnsafeRawPointer) { group(g).group.start(queue: DispatchQueue(label: "isim.nw_connection_group")) }
@_cdecl("nw_connection_group_cancel") public func _c_nw_connection_group_cancel(_ g: UnsafeRawPointer) { group(g).group.cancel() }
@_cdecl("nw_connection_group_send_message")
public func _c_nw_connection_group_send_message(_ g: UnsafeRawPointer, _ d: OpaquePointer?, _ e: UnsafeRawPointer?, _ c: UnsafeRawPointer,
                                                _ done: @escaping @convention(block) (NSObject?) -> Void) {
    let o = group(g), box = _NWCUnchecked(done)
    o.group.send(content: bytes(d), to: e.map { obj($0, _NWCEndpoint.self).endpoint }) { [weak o] err in
        o?.onQueue { box.value(err.map { _NWCError($0) }) }
    }
}
@_cdecl("nw_connection_group_reply")
public func _c_nw_connection_group_reply(_ g: UnsafeRawPointer, _ inbound: UnsafeRawPointer, _ outbound: UnsafeRawPointer, _ d: OpaquePointer?) {
    guard let m = obj(inbound, _NWCContext.self).groupMessage else { return }
    group(g).group.reply(to: m, content: bytes(d))
}
@_cdecl("nw_connection_group_copy_remote_endpoint_for_message")
public func _c_nw_connection_group_copy_remote_endpoint_for_message(_ g: UnsafeRawPointer, _ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(c, _NWCContext.self).groupMessage?.remoteEndpoint.map { retained(_NWCEndpoint($0)) }
}
@_cdecl("nw_connection_group_copy_local_endpoint_for_message")
public func _c_nw_connection_group_copy_local_endpoint_for_message(_ g: UnsafeRawPointer, _ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(c, _NWCContext.self).groupMessage?.localEndpoint.map { retained(_NWCEndpoint($0)) }
}
@_cdecl("nw_connection_group_copy_path_for_message")
public func _c_nw_connection_group_copy_path_for_message(_ g: UnsafeRawPointer, _ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(c, _NWCContext.self).groupMessage?.path.map { retained(_NWCPath($0)) }
}
@_cdecl("nw_connection_group_copy_protocol_metadata")
public func _c_nw_connection_group_copy_protocol_metadata(_ g: UnsafeRawPointer, _ d: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    group(g).group.metadata(definition: obj(d, _NWCDefinition.self).definition).map { retained(_NWCMetadata($0)) }
}
@_cdecl("nw_connection_group_copy_protocol_metadata_for_message")
public func _c_nw_connection_group_copy_protocol_metadata_for_message(_ g: UnsafeRawPointer, _ c: UnsafeRawPointer, _ d: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(c, _NWCContext.self).groupMessage?.metadata(definition: obj(d, _NWCDefinition.self).definition).map { retained(_NWCMetadata($0)) }
}
@_cdecl("nw_connection_group_extract_connection")
public func _c_nw_connection_group_extract_connection(_ g: UnsafeRawPointer, _ e: UnsafeRawPointer?, _ o: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    NWConnection(from: group(g).group, to: e.map { obj($0, _NWCEndpoint.self).endpoint }).map { retained(_NWCConnection($0)) }
}
@_cdecl("nw_connection_group_extract_connection_for_message")
public func _c_nw_connection_group_extract_connection_for_message(_ g: UnsafeRawPointer, _ c: UnsafeRawPointer) -> UnsafeMutableRawPointer? {
    obj(c, _NWCContext.self).groupMessage?.extractConnection().map { retained(_NWCConnection($0)) }
}
@_cdecl("nw_connection_group_reinsert_extracted_connection")
public func _c_nw_connection_group_reinsert_extracted_connection(_ g: UnsafeRawPointer, _ c: UnsafeRawPointer) -> Bool {
    (try? group(g).group.reinsert(connection: obj(c, _NWCConnection.self).connection)) != nil
}
@_cdecl("nw_listener_set_new_connection_group_handler")
public func _c_nw_listener_set_new_connection_group_handler(_ l: UnsafeRawPointer, _ h: (@convention(block) (NSObject) -> Void)?) {
    let o = obj(l, _NWCListener.self)
    guard let h else { o.listener.newConnectionGroupHandler = nil; return }
    let box = _NWCUnchecked(h)
    o.listener.newConnectionGroupHandler = { [weak o] g in
        o?.onQueue { box.value(_NWCConnectionGroup(g, _NWCGroupDescriptor(g.descriptor.members, multiplex: true))) }
    }
}
@_cdecl("nw_listener_create_with_connection")
public func _c_nw_listener_create_with_connection(_ c: UnsafeRawPointer, _ p: UnsafeRawPointer) -> UnsafeMutableRawPointer? { nil }   /* QUIC streams: not on isim */

// MARK: - framers

private func framer(_ f: UnsafeRawPointer) -> _NWCFramer { obj(f, _NWCFramer.self) }
@_cdecl("nw_framer_create_definition")
public func _c_nw_framer_create_definition(_ identifier: UnsafePointer<CChar>, _ flags: UInt32, _ start: @escaping @convention(block) (NSObject) -> UInt32) -> UnsafeMutableRawPointer {
    let d = NWProtocolFramer.Definition(implementation: _NWCFramerImplementation.self, name: String(cString: identifier))
    _nwcFramerLock.lock(); _nwcFramerStarts[ObjectIdentifier(d)] = start; _nwcFramerLock.unlock()
    return retained(_NWCDefinition(d))
}
@_cdecl("nw_framer_create_options")
public func _c_nw_framer_create_options(_ d: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let def = obj(d, _NWCDefinition.self).definition as? NWProtocolFramer.Definition ?? _NWCFramerImplementation.definition
    return retained(_NWCProtocolOptions(NWProtocolFramer.Options(definition: def)))
}
@_cdecl("nw_framer_protocol_create_message")
public func _c_nw_framer_protocol_create_message(_ d: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    let def = obj(d, _NWCDefinition.self).definition as? NWProtocolFramer.Definition ?? _NWCFramerImplementation.definition
    return retained(_NWCMetadata(NWProtocolFramer.Message(definition: def)))
}
@_cdecl("nw_framer_message_create")
public func _c_nw_framer_message_create(_ f: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCMetadata(NWProtocolFramer.Message(instance: framer(f).instance)))
}
private func message(_ m: UnsafeRawPointer) -> NWProtocolFramer.Message? { meta(m, NWProtocolFramer.Message.self) }
@_cdecl("nw_framer_message_set_value")
public func _c_nw_framer_message_set_value(_ m: UnsafeRawPointer, _ k: UnsafePointer<CChar>, _ v: UnsafeMutableRawPointer?,
                                           _ dispose: (@convention(block) (UnsafeMutableRawPointer) -> Void)?) {
    message(m)?[String(cString: k)] = _NWCFramerValue(v, dispose.map { d in { d($0) } })
}
@_cdecl("nw_framer_message_access_value")
public func _c_nw_framer_message_access_value(_ m: UnsafeRawPointer, _ k: UnsafePointer<CChar>, _ f: @convention(block) (UnsafeRawPointer?) -> Bool) -> Bool {
    f((message(m)?[String(cString: k)] as? _NWCFramerValue)?.pointer.map { UnsafeRawPointer($0) })
}
@_cdecl("nw_framer_message_set_object_value")
public func _c_nw_framer_message_set_object_value(_ m: UnsafeRawPointer, _ k: UnsafePointer<CChar>, _ v: AnyObject?) { message(m)?[String(cString: k)] = v }
@_cdecl("nw_framer_message_copy_object_value")
public func _c_nw_framer_message_copy_object_value(_ m: UnsafeRawPointer, _ k: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    guard let v = message(m)?[String(cString: k)] as AnyObject?, !(v is _NWCFramerValue) else { return nil }
    return Unmanaged.passRetained(v).toOpaque()
}
@_cdecl("nw_framer_options_set_object_value")
public func _c_nw_framer_options_set_object_value(_ o: UnsafeRawPointer, _ k: UnsafePointer<CChar>, _ v: AnyObject?) {
    options(o, NWProtocolFramer.Options.self)?[String(cString: k)] = v
}
@_cdecl("nw_framer_options_copy_object_value")
public func _c_nw_framer_options_copy_object_value(_ o: UnsafeRawPointer, _ k: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    (options(o, NWProtocolFramer.Options.self)?[String(cString: k)] as AnyObject?).map { Unmanaged.passRetained($0).toOpaque() }
}
@_cdecl("nw_framer_set_input_handler")
public func _c_nw_framer_set_input_handler(_ f: UnsafeRawPointer, _ h: @escaping @convention(block) (NSObject) -> Int) { framer(f).input = { h($0) } }
@_cdecl("nw_framer_set_output_handler")
public func _c_nw_framer_set_output_handler(_ f: UnsafeRawPointer, _ h: @escaping @convention(block) (NSObject, NSObject, Int, Bool) -> Void) {
    framer(f).output = { h($0, $1, $2, $3) }
}
@_cdecl("nw_framer_set_wakeup_handler")
public func _c_nw_framer_set_wakeup_handler(_ f: UnsafeRawPointer, _ h: @escaping @convention(block) (NSObject) -> Void) { framer(f).wakeup = { h($0) } }
@_cdecl("nw_framer_set_stop_handler")
public func _c_nw_framer_set_stop_handler(_ f: UnsafeRawPointer, _ h: @escaping @convention(block) (NSObject) -> Bool) { framer(f).stop = { h($0) } }
@_cdecl("nw_framer_set_cleanup_handler")
public func _c_nw_framer_set_cleanup_handler(_ f: UnsafeRawPointer, _ h: @escaping @convention(block) (NSObject) -> Void) { framer(f).cleanup = { h($0) } }
@_cdecl("nw_framer_mark_ready") public func _c_nw_framer_mark_ready(_ f: UnsafeRawPointer) { framer(f).instance.markReady() }
@_cdecl("nw_framer_prepend_application_protocol")
public func _c_nw_framer_prepend_application_protocol(_ f: UnsafeRawPointer, _ o: UnsafeRawPointer) -> Bool {
    framer(f).instance.prependApplicationProtocol(options: obj(o, _NWCProtocolOptions.self).options); return true
}
@_cdecl("nw_framer_mark_failed_with_error")
public func _c_nw_framer_mark_failed_with_error(_ f: UnsafeRawPointer, _ code: Int32) {
    framer(f).instance.markFailed(error: code == 0 ? nil : .posix(POSIXErrorCode(rawValue: code) ?? .EIO))
}
@_cdecl("nw_framer_parse_input")
public func _c_nw_framer_parse_input(_ f: UnsafeRawPointer, _ min: Int, _ max: Int, _ temp: UnsafeMutablePointer<UInt8>?,
                                     _ parse: @convention(block) (UnsafeMutablePointer<UInt8>?, Int, Bool) -> Int) -> Bool {
    framer(f).instance.parseInput(minimumIncompleteLength: min, maximumLength: max) { b, complete in
        parse(b?.baseAddress?.assumingMemoryBound(to: UInt8.self), b?.count ?? 0, complete)
    }
}
@_cdecl("nw_framer_deliver_input")
public func _c_nw_framer_deliver_input(_ f: UnsafeRawPointer, _ b: UnsafePointer<UInt8>, _ n: Int, _ m: UnsafeRawPointer, _ complete: Bool) {
    guard let msg = message(m) else { return }
    framer(f).instance.deliverInput(data: Data(bytes: b, count: n), message: msg, isComplete: complete)
}
@_cdecl("nw_framer_deliver_input_no_copy")
public func _c_nw_framer_deliver_input_no_copy(_ f: UnsafeRawPointer, _ n: Int, _ m: UnsafeRawPointer, _ complete: Bool) -> Bool {
    guard let msg = message(m) else { return false }
    return framer(f).instance.deliverInputNoCopy(length: n, message: msg, isComplete: complete)
}
@_cdecl("nw_framer_pass_through_input") public func _c_nw_framer_pass_through_input(_ f: UnsafeRawPointer) { framer(f).instance.passThroughInput() }
@_cdecl("nw_framer_parse_output")
public func _c_nw_framer_parse_output(_ f: UnsafeRawPointer, _ min: Int, _ max: Int, _ temp: UnsafeMutablePointer<UInt8>?,
                                      _ parse: @convention(block) (UnsafeMutablePointer<UInt8>?, Int, Bool) -> Int) -> Bool {
    framer(f).instance.parseOutput(minimumIncompleteLength: min, maximumLength: max) { b, complete in
        parse(b?.baseAddress?.assumingMemoryBound(to: UInt8.self), b?.count ?? 0, complete)
    }
}
@_cdecl("nw_framer_write_output")
public func _c_nw_framer_write_output(_ f: UnsafeRawPointer, _ b: UnsafePointer<UInt8>, _ n: Int) { framer(f).instance.writeOutput(data: Data(bytes: b, count: n)) }
@_cdecl("nw_framer_write_output_data")
public func _c_nw_framer_write_output_data(_ f: UnsafeRawPointer, _ d: OpaquePointer) { framer(f).instance.writeOutput(data: bytes(d) ?? Data()) }
@_cdecl("nw_framer_write_output_no_copy")
public func _c_nw_framer_write_output_no_copy(_ f: UnsafeRawPointer, _ n: Int) -> Bool { (try? framer(f).instance.writeOutputNoCopy(length: n)) != nil }
@_cdecl("nw_framer_pass_through_output") public func _c_nw_framer_pass_through_output(_ f: UnsafeRawPointer) { framer(f).instance.passThroughOutput() }
@_cdecl("nw_framer_schedule_wakeup")
public func _c_nw_framer_schedule_wakeup(_ f: UnsafeRawPointer, _ ms: UInt64) {
    framer(f).instance.scheduleWakeup(wakeupTime: ms == UInt64.max ? .forever : .milliseconds(ms))
}
@_cdecl("nw_framer_async")
public func _c_nw_framer_async(_ f: UnsafeRawPointer, _ b: @escaping @convention(block) () -> Void) { framer(f).instance.async { b() } }
@_cdecl("nw_framer_copy_remote_endpoint")
public func _c_nw_framer_copy_remote_endpoint(_ f: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCEndpoint(framer(f).instance.remote ?? .hostPort(host: "0.0.0.0", port: .any)))
}
@_cdecl("nw_framer_copy_local_endpoint")
public func _c_nw_framer_copy_local_endpoint(_ f: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCEndpoint(framer(f).instance.local ?? .hostPort(host: "0.0.0.0", port: .any)))
}
@_cdecl("nw_framer_copy_parameters")
public func _c_nw_framer_copy_parameters(_ f: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCParameters(framer(f).instance.parameters)) }
@_cdecl("nw_framer_copy_options")
public func _c_nw_framer_copy_options(_ f: UnsafeRawPointer) -> UnsafeMutableRawPointer { retained(_NWCProtocolOptions(framer(f).instance.options)) }

// MARK: - proxy configurations

private func proxy(_ p: UnsafeRawPointer) -> _NWCProxyConfig { obj(p, _NWCProxyConfig.self) }
@_cdecl("nw_proxy_config_create_socksv5")
public func _c_nw_proxy_config_create_socksv5(_ e: UnsafeRawPointer) -> UnsafeMutableRawPointer {
    retained(_NWCProxyConfig(ProxyConfiguration(socksv5Proxy: obj(e, _NWCEndpoint.self).endpoint)))
}
@_cdecl("nw_proxy_config_create_http_connect")
public func _c_nw_proxy_config_create_http_connect(_ e: UnsafeRawPointer, _ tls: UnsafeRawPointer?) -> UnsafeMutableRawPointer {
    retained(_NWCProxyConfig(ProxyConfiguration(httpCONNECTProxy: obj(e, _NWCEndpoint.self).endpoint,
                                                tlsOptions: tls.flatMap { options($0, NWProtocolTLS.Options.self) })))
}
@_cdecl("nw_proxy_config_add_match_domain")
public func _c_nw_proxy_config_add_match_domain(_ p: UnsafeRawPointer, _ d: UnsafePointer<CChar>) { proxy(p).config.matchDomains.append(String(cString: d)) }
@_cdecl("nw_proxy_config_clear_match_domains") public func _c_nw_proxy_config_clear_match_domains(_ p: UnsafeRawPointer) { proxy(p).config.matchDomains = [] }
@_cdecl("nw_proxy_config_enumerate_match_domains")
public func _c_nw_proxy_config_enumerate_match_domains(_ p: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<CChar>) -> Void) {
    for d in proxy(p).config.matchDomains { d.withCString { f($0) } }
}
@_cdecl("nw_proxy_config_add_excluded_domain")
public func _c_nw_proxy_config_add_excluded_domain(_ p: UnsafeRawPointer, _ d: UnsafePointer<CChar>) { proxy(p).config.excludedDomains.append(String(cString: d)) }
@_cdecl("nw_proxy_config_clear_excluded_domains") public func _c_nw_proxy_config_clear_excluded_domains(_ p: UnsafeRawPointer) { proxy(p).config.excludedDomains = [] }
@_cdecl("nw_proxy_config_enumerate_excluded_domains")
public func _c_nw_proxy_config_enumerate_excluded_domains(_ p: UnsafeRawPointer, _ f: @convention(block) (UnsafePointer<CChar>) -> Void) {
    for d in proxy(p).config.excludedDomains { d.withCString { f($0) } }
}
