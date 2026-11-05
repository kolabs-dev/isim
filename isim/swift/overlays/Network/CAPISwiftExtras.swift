// isim Network (issue #851): the rest of the C API as Swift sees it: the OS_nw_* object protocols and nw_*_t types of
// protocol definitions and metadata, TXT records, reports, connection groups, WebSocket requests and responses,
// framers and proxy configurations; their C enums as structs with constants; and the functions, over the C entry points
// (CAPIExtras.swift). As in CAPISwift.swift, queues are DispatchQueue and dispatch_data_t stays isim's C type.
import Foundation
import Darwin

// MARK: - object types

@objc public protocol OS_nw_object: NSObjectProtocol {}
@objc public protocol OS_nw_protocol_definition: NSObjectProtocol {}
@objc public protocol OS_nw_protocol_metadata: NSObjectProtocol {}
@objc public protocol OS_nw_txt_record: NSObjectProtocol {}
@objc public protocol OS_nw_establishment_report: NSObjectProtocol {}
@objc public protocol OS_nw_resolution_report: NSObjectProtocol {}
@objc public protocol OS_nw_data_transfer_report: NSObjectProtocol {}
@objc public protocol OS_nw_group_descriptor: NSObjectProtocol {}
@objc public protocol OS_nw_connection_group: NSObjectProtocol {}
@objc public protocol OS_nw_ws_request: NSObjectProtocol {}
@objc public protocol OS_nw_ws_response: NSObjectProtocol {}
@objc public protocol OS_nw_framer: NSObjectProtocol {}
@objc public protocol OS_nw_proxy_config: NSObjectProtocol {}
@objc public protocol OS_nw_ethernet_channel: NSObjectProtocol {}
@objc public protocol OS_nw_privacy_context: NSObjectProtocol {}
@objc public protocol OS_nw_protocol_stack: NSObjectProtocol {}
@objc public protocol OS_nw_relay_hop: NSObjectProtocol {}
@objc public protocol OS_nw_resolver_config: NSObjectProtocol {}
public typealias nw_object_t = any OS_nw_object
public typealias nw_protocol_definition_t = any OS_nw_protocol_definition
public typealias nw_protocol_metadata_t = any OS_nw_protocol_metadata
public typealias nw_framer_message_t = nw_protocol_metadata_t
public typealias nw_txt_record_t = any OS_nw_txt_record
public typealias nw_establishment_report_t = any OS_nw_establishment_report
public typealias nw_resolution_report_t = any OS_nw_resolution_report
public typealias nw_data_transfer_report_t = any OS_nw_data_transfer_report
public typealias nw_group_descriptor_t = any OS_nw_group_descriptor
public typealias nw_connection_group_t = any OS_nw_connection_group
public typealias nw_ws_request_t = any OS_nw_ws_request
public typealias nw_ws_response_t = any OS_nw_ws_response
public typealias nw_framer_t = any OS_nw_framer
public typealias nw_proxy_config_t = any OS_nw_proxy_config
public typealias nw_ethernet_channel_t = any OS_nw_ethernet_channel
extension _NWCDefinition: OS_nw_protocol_definition, OS_nw_object {}
extension _NWCMetadata: OS_nw_protocol_metadata, OS_nw_object {}
extension _NWCTXTRecord: OS_nw_txt_record, OS_nw_object {}
extension _NWCEstablishmentReport: OS_nw_establishment_report, OS_nw_object {}
extension _NWCResolutionReport: OS_nw_resolution_report, OS_nw_object {}
extension _NWCDataTransferReport: OS_nw_data_transfer_report, OS_nw_object {}
extension _NWCGroupDescriptor: OS_nw_group_descriptor, OS_nw_object {}
extension _NWCConnectionGroup: OS_nw_connection_group, OS_nw_object {}
extension _NWCWSRequest: OS_nw_ws_request, OS_nw_object {}
extension _NWCWSResponse: OS_nw_ws_response, OS_nw_object {}
extension _NWCFramer: OS_nw_framer, OS_nw_object {}
extension _NWCProxyConfig: OS_nw_proxy_config, OS_nw_object {}
/// Security's sec_protocol_options_t / sec_protocol_metadata_t for C (Swift has the Swift objects)
extension _NWCSecObject: OS_nw_object {}

// MARK: - handler types

public typealias nw_connection_group_state_changed_handler_t = (nw_connection_group_state_t, nw_error_t?) -> Void
public typealias nw_connection_group_receive_handler_t = (dispatch_data_t?, nw_content_context_t, Bool) -> Void
public typealias nw_connection_group_new_connection_handler_t = (nw_connection_t) -> Void
public typealias nw_connection_group_send_completion_t = (nw_error_t?) -> Void
public typealias nw_listener_new_connection_group_handler_t = (nw_connection_group_t) -> Void
public typealias nw_group_descriptor_enumerate_endpoints_block_t = (nw_endpoint_t) -> Bool
public typealias nw_establishment_report_access_block_t = (nw_establishment_report_t?) -> Void
public typealias nw_report_resolution_enumerator_t = (nw_report_resolution_source_t, UInt64, UInt32, nw_endpoint_t, nw_endpoint_t) -> Bool
public typealias nw_report_resolution_report_enumerator_t = (nw_resolution_report_t) -> Bool
public typealias nw_report_protocol_enumerator_t = (nw_protocol_definition_t, UInt64, UInt64) -> Bool
public typealias nw_data_transfer_report_collect_block_t = (nw_data_transfer_report_t) -> Void
public typealias nw_path_enumerate_gateways_block_t = (nw_endpoint_t) -> Bool
public typealias nw_proxy_domain_enumerator_t = (UnsafePointer<CChar>) -> Void
public typealias nw_txt_record_access_key_t = (UnsafePointer<CChar>, nw_txt_record_find_key_t, UnsafePointer<UInt8>?, Int) -> Bool
public typealias nw_txt_record_access_bytes_t = (UnsafePointer<UInt8>, Int) -> Bool
public typealias nw_txt_record_applier_t = (UnsafePointer<CChar>, nw_txt_record_find_key_t, UnsafePointer<UInt8>, Int) -> Bool
public typealias nw_ws_pong_handler_t = (nw_error_t?) -> Void
public typealias nw_ws_client_request_handler_t = (nw_ws_request_t) -> nw_ws_response_t
public typealias nw_ws_subprotocol_enumerator_t = (UnsafePointer<CChar>) -> Bool
public typealias nw_ws_additional_header_enumerator_t = (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool
public typealias nw_framer_start_handler_t = (nw_framer_t) -> nw_framer_start_result_t
public typealias nw_framer_input_handler_t = (nw_framer_t) -> Int
public typealias nw_framer_output_handler_t = (nw_framer_t, nw_framer_message_t, Int, Bool) -> Void
public typealias nw_framer_wakeup_handler_t = (nw_framer_t) -> Void
public typealias nw_framer_stop_handler_t = (nw_framer_t) -> Bool
public typealias nw_framer_cleanup_handler_t = (nw_framer_t) -> Void
public typealias nw_framer_block_t = () -> Void
public typealias nw_framer_parse_completion_t = (UnsafeMutablePointer<UInt8>?, Int, Bool) -> Int
public typealias nw_framer_message_dispose_value_t = (UnsafeMutableRawPointer) -> Void

// MARK: - C enums and constants

/// who a connection's traffic is for
public enum nw_parameters_attribution_t: UInt8, Sendable { case developer = 1, user = 2 }
public var NW_FRAMER_CREATE_FLAGS_DEFAULT: Int32 { 0 }
public var NW_QUIC_CONNECTION_DEFAULT_KEEPALIVE: Int32 { 1 }
public var NW_FRAMER_WAKEUP_TIME_FOREVER: UInt64 { UInt64.max }
public struct nw_connection_group_state_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_connection_group_state_invalid: nw_connection_group_state_t { .init(0) }
public var nw_connection_group_state_waiting: nw_connection_group_state_t { .init(1) }
public var nw_connection_group_state_ready: nw_connection_group_state_t { .init(2) }
public var nw_connection_group_state_failed: nw_connection_group_state_t { .init(3) }
public var nw_connection_group_state_cancelled: nw_connection_group_state_t { .init(4) }
public struct nw_data_transfer_report_state_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_data_transfer_report_state_collecting: nw_data_transfer_report_state_t { .init(1) }
public var nw_data_transfer_report_state_collected: nw_data_transfer_report_state_t { .init(2) }
public struct nw_ethernet_channel_state_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ethernet_channel_state_invalid: nw_ethernet_channel_state_t { .init(0) }
public var nw_ethernet_channel_state_waiting: nw_ethernet_channel_state_t { .init(1) }
public var nw_ethernet_channel_state_preparing: nw_ethernet_channel_state_t { .init(2) }
public var nw_ethernet_channel_state_ready: nw_ethernet_channel_state_t { .init(3) }
public var nw_ethernet_channel_state_failed: nw_ethernet_channel_state_t { .init(4) }
public var nw_ethernet_channel_state_cancelled: nw_ethernet_channel_state_t { .init(5) }
public struct nw_framer_start_result_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_framer_start_result_ready: nw_framer_start_result_t { .init(1) }
public var nw_framer_start_result_will_mark_ready: nw_framer_start_result_t { .init(2) }
public struct nw_interface_radio_type_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_interface_radio_type_unknown: nw_interface_radio_type_t { .init(0) }
public var nw_interface_radio_type_wifi_b: nw_interface_radio_type_t { .init(1) }
public var nw_interface_radio_type_wifi_a: nw_interface_radio_type_t { .init(2) }
public var nw_interface_radio_type_wifi_g: nw_interface_radio_type_t { .init(3) }
public var nw_interface_radio_type_wifi_n: nw_interface_radio_type_t { .init(4) }
public var nw_interface_radio_type_wifi_ac: nw_interface_radio_type_t { .init(5) }
public var nw_interface_radio_type_wifi_ax: nw_interface_radio_type_t { .init(6) }
public var nw_interface_radio_type_cell_lte: nw_interface_radio_type_t { .init(128) }
public var nw_interface_radio_type_cell_endc_sub6: nw_interface_radio_type_t { .init(129) }
public var nw_interface_radio_type_cell_endc_mmw: nw_interface_radio_type_t { .init(130) }
public var nw_interface_radio_type_cell_nr_sa_sub6: nw_interface_radio_type_t { .init(131) }
public var nw_interface_radio_type_cell_nr_sa_mmw: nw_interface_radio_type_t { .init(132) }
public var nw_interface_radio_type_cell_wcdma: nw_interface_radio_type_t { .init(133) }
public var nw_interface_radio_type_cell_gsm: nw_interface_radio_type_t { .init(134) }
public var nw_interface_radio_type_cell_cdma: nw_interface_radio_type_t { .init(135) }
public var nw_interface_radio_type_cell_evdo: nw_interface_radio_type_t { .init(136) }
public struct nw_ip_ecn_flag_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ip_ecn_flag_non_ect: nw_ip_ecn_flag_t { .init(0) }
public var nw_ip_ecn_flag_ect_0: nw_ip_ecn_flag_t { .init(2) }
public var nw_ip_ecn_flag_ect_1: nw_ip_ecn_flag_t { .init(1) }
public var nw_ip_ecn_flag_ce: nw_ip_ecn_flag_t { .init(3) }
public struct nw_ip_local_address_preference_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ip_local_address_preference_default: nw_ip_local_address_preference_t { .init(0) }
public var nw_ip_local_address_preference_temporary: nw_ip_local_address_preference_t { .init(1) }
public var nw_ip_local_address_preference_stable: nw_ip_local_address_preference_t { .init(2) }
public struct nw_ip_version_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ip_version_any: nw_ip_version_t { .init(0) }
public var nw_ip_version_4: nw_ip_version_t { .init(4) }
public var nw_ip_version_6: nw_ip_version_t { .init(6) }
public struct nw_link_quality_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt8
    public init(_ rawValue: UInt8) { self.rawValue = rawValue }
    public init(rawValue: UInt8) { self.rawValue = rawValue }
}
public var nw_link_quality_unknown: nw_link_quality_t { .init(0) }
public var nw_link_quality_minimal: nw_link_quality_t { .init(10) }
public var nw_link_quality_moderate: nw_link_quality_t { .init(20) }
public var nw_link_quality_good: nw_link_quality_t { .init(30) }
public struct nw_multipath_service_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_multipath_service_disabled: nw_multipath_service_t { .init(0) }
public var nw_multipath_service_handover: nw_multipath_service_t { .init(1) }
public var nw_multipath_service_interactive: nw_multipath_service_t { .init(2) }
public var nw_multipath_service_aggregate: nw_multipath_service_t { .init(3) }
public struct nw_multipath_version_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: Int32
    public init(_ rawValue: Int32) { self.rawValue = rawValue }
    public init(rawValue: Int32) { self.rawValue = rawValue }
}
public var nw_multipath_version_unspecified: nw_multipath_version_t { .init(-1) }
public var nw_multipath_version_0: nw_multipath_version_t { .init(0) }
public var nw_multipath_version_1: nw_multipath_version_t { .init(1) }
public struct nw_parameters_expired_dns_behavior_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_parameters_expired_dns_behavior_default: nw_parameters_expired_dns_behavior_t { .init(0) }
public var nw_parameters_expired_dns_behavior_allow: nw_parameters_expired_dns_behavior_t { .init(1) }
public var nw_parameters_expired_dns_behavior_prohibit: nw_parameters_expired_dns_behavior_t { .init(2) }
public var nw_parameters_expired_dns_behavior_persistent: nw_parameters_expired_dns_behavior_t { .init(3) }
public struct nw_path_unsatisfied_reason_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_path_unsatisfied_reason_not_available: nw_path_unsatisfied_reason_t { .init(0) }
public var nw_path_unsatisfied_reason_cellular_denied: nw_path_unsatisfied_reason_t { .init(1) }
public var nw_path_unsatisfied_reason_wifi_denied: nw_path_unsatisfied_reason_t { .init(2) }
public var nw_path_unsatisfied_reason_local_network_denied: nw_path_unsatisfied_reason_t { .init(3) }
public var nw_path_unsatisfied_reason_vpn_inactive: nw_path_unsatisfied_reason_t { .init(4) }
public struct nw_quic_stream_type_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_quic_stream_type_unknown: nw_quic_stream_type_t { .init(0) }
public var nw_quic_stream_type_bidirectional: nw_quic_stream_type_t { .init(1) }
public var nw_quic_stream_type_unidirectional: nw_quic_stream_type_t { .init(2) }
public var nw_quic_stream_type_datagram: nw_quic_stream_type_t { .init(3) }
public struct nw_report_resolution_protocol_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_report_resolution_protocol_unknown: nw_report_resolution_protocol_t { .init(0) }
public var nw_report_resolution_protocol_udp: nw_report_resolution_protocol_t { .init(1) }
public var nw_report_resolution_protocol_tcp: nw_report_resolution_protocol_t { .init(2) }
public var nw_report_resolution_protocol_tls: nw_report_resolution_protocol_t { .init(3) }
public var nw_report_resolution_protocol_https: nw_report_resolution_protocol_t { .init(4) }
public struct nw_report_resolution_source_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_report_resolution_source_query: nw_report_resolution_source_t { .init(1) }
public var nw_report_resolution_source_cache: nw_report_resolution_source_t { .init(2) }
public var nw_report_resolution_source_expired_cache: nw_report_resolution_source_t { .init(3) }
public struct nw_service_class_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_service_class_best_effort: nw_service_class_t { .init(0) }
public var nw_service_class_background: nw_service_class_t { .init(1) }
public var nw_service_class_interactive_video: nw_service_class_t { .init(2) }
public var nw_service_class_interactive_voice: nw_service_class_t { .init(3) }
public var nw_service_class_responsive_data: nw_service_class_t { .init(4) }
public var nw_service_class_signaling: nw_service_class_t { .init(5) }
public struct nw_txt_record_find_key_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_txt_record_find_key_invalid: nw_txt_record_find_key_t { .init(0) }
public var nw_txt_record_find_key_not_present: nw_txt_record_find_key_t { .init(1) }
public var nw_txt_record_find_key_no_value: nw_txt_record_find_key_t { .init(2) }
public var nw_txt_record_find_key_empty_value: nw_txt_record_find_key_t { .init(3) }
public var nw_txt_record_find_key_non_empty_value: nw_txt_record_find_key_t { .init(4) }
public struct nw_ws_close_code_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ws_close_code_normal_closure: nw_ws_close_code_t { .init(1000) }
public var nw_ws_close_code_going_away: nw_ws_close_code_t { .init(1001) }
public var nw_ws_close_code_protocol_error: nw_ws_close_code_t { .init(1002) }
public var nw_ws_close_code_unsupported_data: nw_ws_close_code_t { .init(1003) }
public var nw_ws_close_code_no_status_received: nw_ws_close_code_t { .init(1005) }
public var nw_ws_close_code_abnormal_closure: nw_ws_close_code_t { .init(1006) }
public var nw_ws_close_code_invalid_frame_payload_data: nw_ws_close_code_t { .init(1007) }
public var nw_ws_close_code_policy_violation: nw_ws_close_code_t { .init(1008) }
public var nw_ws_close_code_message_too_big: nw_ws_close_code_t { .init(1009) }
public var nw_ws_close_code_mandatory_extension: nw_ws_close_code_t { .init(1010) }
public var nw_ws_close_code_internal_server_error: nw_ws_close_code_t { .init(1011) }
public var nw_ws_close_code_tls_handshake: nw_ws_close_code_t { .init(1015) }
public struct nw_ws_opcode_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: Int32
    public init(_ rawValue: Int32) { self.rawValue = rawValue }
    public init(rawValue: Int32) { self.rawValue = rawValue }
}
public var nw_ws_opcode_invalid: nw_ws_opcode_t { .init(-1) }
public var nw_ws_opcode_cont: nw_ws_opcode_t { .init(0) }
public var nw_ws_opcode_text: nw_ws_opcode_t { .init(1) }
public var nw_ws_opcode_binary: nw_ws_opcode_t { .init(2) }
public var nw_ws_opcode_close: nw_ws_opcode_t { .init(8) }
public var nw_ws_opcode_ping: nw_ws_opcode_t { .init(9) }
public var nw_ws_opcode_pong: nw_ws_opcode_t { .init(10) }
public struct nw_ws_response_status_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ws_response_status_invalid: nw_ws_response_status_t { .init(0) }
public var nw_ws_response_status_accept: nw_ws_response_status_t { .init(1) }
public var nw_ws_response_status_reject: nw_ws_response_status_t { .init(2) }
public struct nw_ws_version_t: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public var nw_ws_version_invalid: nw_ws_version_t { .init(0) }
public var nw_ws_version_13: nw_ws_version_t { .init(1) }

// MARK: - functions

public func nw_advertise_descriptor_copy_txt_record_object(_ advertise_descriptor: nw_advertise_descriptor_t) -> nw_txt_record_t? { takeOptional(_c_nw_advertise_descriptor_copy_txt_record_object(raw(advertise_descriptor))) }
public func nw_advertise_descriptor_create_application_service(_ application_service_name: UnsafePointer<CChar>) -> nw_advertise_descriptor_t { take(_c_nw_advertise_descriptor_create_application_service(application_service_name)) }
public func nw_advertise_descriptor_get_application_service_name(_ advertise_descriptor: nw_advertise_descriptor_t) -> UnsafePointer<CChar>? { _c_nw_advertise_descriptor_get_application_service_name(raw(advertise_descriptor)) }
public func nw_advertise_descriptor_get_no_auto_rename(_ advertise_descriptor: nw_advertise_descriptor_t) -> Bool { _c_nw_advertise_descriptor_get_no_auto_rename(raw(advertise_descriptor)) }
public func nw_advertise_descriptor_set_no_auto_rename(_ advertise_descriptor: nw_advertise_descriptor_t, _ no_auto_rename: Bool) { _c_nw_advertise_descriptor_set_no_auto_rename(raw(advertise_descriptor), no_auto_rename) }
public func nw_advertise_descriptor_set_txt_record_object(_ advertise_descriptor: nw_advertise_descriptor_t, _ txt_record: nw_txt_record_t?) { _c_nw_advertise_descriptor_set_txt_record_object(raw(advertise_descriptor), txt_record.map { UnsafeRawPointer(raw($0)) }) }
public func nw_browse_descriptor_create_application_service(_ application_service_name: UnsafePointer<CChar>) -> nw_browse_descriptor_t { take(_c_nw_browse_descriptor_create_application_service(application_service_name)) }
public func nw_browse_descriptor_get_application_service_name(_ descriptor: nw_browse_descriptor_t) -> UnsafePointer<CChar>? { _c_nw_browse_descriptor_get_application_service_name(raw(descriptor)) }
public func nw_browse_result_copy_txt_record_object(_ result: nw_browse_result_t) -> nw_txt_record_t? { takeOptional(_c_nw_browse_result_copy_txt_record_object(raw(result))) }
public func nw_connection_copy_protocol_metadata(_ connection: nw_connection_t, _ definition: nw_protocol_definition_t) -> nw_protocol_metadata_t? { takeOptional(_c_nw_connection_copy_protocol_metadata(raw(connection), raw(definition))) }
public func nw_connection_create_new_data_transfer_report(_ connection: nw_connection_t) -> nw_data_transfer_report_t { take(_c_nw_connection_create_new_data_transfer_report(raw(connection))) }
public func nw_connection_group_cancel(_ group: nw_connection_group_t) { _c_nw_connection_group_cancel(raw(group)) }
public func nw_connection_group_copy_descriptor(_ group: nw_connection_group_t) -> nw_group_descriptor_t { take(_c_nw_connection_group_copy_descriptor(raw(group))) }
public func nw_connection_group_copy_local_endpoint_for_message(_ group: nw_connection_group_t, _ context: nw_content_context_t) -> nw_endpoint_t? { takeOptional(_c_nw_connection_group_copy_local_endpoint_for_message(raw(group), raw(context))) }
public func nw_connection_group_copy_parameters(_ group: nw_connection_group_t) -> nw_parameters_t { take(_c_nw_connection_group_copy_parameters(raw(group))) }
public func nw_connection_group_copy_path_for_message(_ group: nw_connection_group_t, _ context: nw_content_context_t) -> nw_path_t? { takeOptional(_c_nw_connection_group_copy_path_for_message(raw(group), raw(context))) }
public func nw_connection_group_copy_protocol_metadata(_ group: nw_connection_group_t, _ definition: nw_protocol_definition_t) -> nw_protocol_metadata_t? { takeOptional(_c_nw_connection_group_copy_protocol_metadata(raw(group), raw(definition))) }
public func nw_connection_group_copy_protocol_metadata_for_message(_ group: nw_connection_group_t, _ context: nw_content_context_t, _ definition: nw_protocol_definition_t) -> nw_protocol_metadata_t? { takeOptional(_c_nw_connection_group_copy_protocol_metadata_for_message(raw(group), raw(context), raw(definition))) }
public func nw_connection_group_copy_remote_endpoint_for_message(_ group: nw_connection_group_t, _ context: nw_content_context_t) -> nw_endpoint_t? { takeOptional(_c_nw_connection_group_copy_remote_endpoint_for_message(raw(group), raw(context))) }
public func nw_connection_group_create(_ group_descriptor: nw_group_descriptor_t, _ parameters: nw_parameters_t) -> nw_connection_group_t { take(_c_nw_connection_group_create(raw(group_descriptor), raw(parameters))) }
public func nw_connection_group_extract_connection(_ group: nw_connection_group_t, _ endpoint: nw_endpoint_t?, _ protocol_options: nw_protocol_options_t?) -> nw_connection_t? { takeOptional(_c_nw_connection_group_extract_connection(raw(group), endpoint.map { UnsafeRawPointer(raw($0)) }, protocol_options.map { UnsafeRawPointer(raw($0)) })) }
public func nw_connection_group_extract_connection_for_message(_ group: nw_connection_group_t, _ context: nw_content_context_t) -> nw_connection_t? { takeOptional(_c_nw_connection_group_extract_connection_for_message(raw(group), raw(context))) }
public func nw_connection_group_reinsert_extracted_connection(_ group: nw_connection_group_t, _ connection: nw_connection_t) -> Bool { _c_nw_connection_group_reinsert_extracted_connection(raw(group), raw(connection)) }
public func nw_connection_group_start(_ group: nw_connection_group_t) { _c_nw_connection_group_start(raw(group)) }
public func nw_content_context_copy_protocol_metadata(_ context: nw_content_context_t, _ protocol: nw_protocol_definition_t) -> nw_protocol_metadata_t? { takeOptional(_c_nw_content_context_copy_protocol_metadata(raw(context), raw(`protocol`))) }
public func nw_content_context_set_metadata_for_protocol(_ context: nw_content_context_t, _ protocol_metadata: nw_protocol_metadata_t) { _c_nw_content_context_set_metadata_for_protocol(raw(context), raw(protocol_metadata)) }
public func nw_data_transfer_report_copy_path_interface(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> nw_interface_t { take(_c_nw_data_transfer_report_copy_path_interface(raw(report), path_index)) }
public func nw_data_transfer_report_get_duration_milliseconds(_ report: nw_data_transfer_report_t) -> UInt64 { _c_nw_data_transfer_report_get_duration_milliseconds(raw(report)) }
public func nw_data_transfer_report_get_path_count(_ report: nw_data_transfer_report_t) -> UInt32 { _c_nw_data_transfer_report_get_path_count(raw(report)) }
public func nw_data_transfer_report_get_path_radio_type(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> nw_interface_radio_type_t { .init(_c_nw_data_transfer_report_get_path_radio_type(raw(report), path_index)) }
public func nw_data_transfer_report_get_received_application_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_received_application_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_received_ip_packet_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_received_ip_packet_count(raw(report), path_index) }
public func nw_data_transfer_report_get_received_transport_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_received_transport_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_received_transport_duplicate_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_received_transport_duplicate_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_received_transport_out_of_order_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_received_transport_out_of_order_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_sent_application_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_sent_application_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_sent_ip_packet_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_sent_ip_packet_count(raw(report), path_index) }
public func nw_data_transfer_report_get_sent_transport_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_sent_transport_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_sent_transport_retransmitted_byte_count(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_sent_transport_retransmitted_byte_count(raw(report), path_index) }
public func nw_data_transfer_report_get_state(_ report: nw_data_transfer_report_t) -> nw_data_transfer_report_state_t { .init(_c_nw_data_transfer_report_get_state(raw(report))) }
public func nw_data_transfer_report_get_transport_minimum_rtt_milliseconds(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_transport_minimum_rtt_milliseconds(raw(report), path_index) }
public func nw_data_transfer_report_get_transport_rtt_variance(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_transport_rtt_variance(raw(report), path_index) }
public func nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds(_ report: nw_data_transfer_report_t, _ path_index: UInt32) -> UInt64 { _c_nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds(raw(report), path_index) }
public func nw_endpoint_copy_txt_record(_ endpoint: nw_endpoint_t) -> nw_txt_record_t? { takeOptional(_c_nw_endpoint_copy_txt_record(raw(endpoint))) }
public func nw_endpoint_get_signature(_ endpoint: nw_endpoint_t, _ out_signature_length: UnsafeMutablePointer<Int>) -> UnsafePointer<UInt8>? { _c_nw_endpoint_get_signature(raw(endpoint), out_signature_length) }
public func nw_establishment_report_copy_proxy_endpoint(_ report: nw_establishment_report_t) -> nw_endpoint_t? { takeOptional(_c_nw_establishment_report_copy_proxy_endpoint(raw(report))) }
public func nw_establishment_report_get_attempt_started_after_milliseconds(_ report: nw_establishment_report_t) -> UInt64 { _c_nw_establishment_report_get_attempt_started_after_milliseconds(raw(report)) }
public func nw_establishment_report_get_duration_milliseconds(_ report: nw_establishment_report_t) -> UInt64 { _c_nw_establishment_report_get_duration_milliseconds(raw(report)) }
public func nw_establishment_report_get_previous_attempt_count(_ report: nw_establishment_report_t) -> UInt32 { _c_nw_establishment_report_get_previous_attempt_count(raw(report)) }
public func nw_establishment_report_get_proxy_configured(_ report: nw_establishment_report_t) -> Bool { _c_nw_establishment_report_get_proxy_configured(raw(report)) }
public func nw_establishment_report_get_used_proxy(_ report: nw_establishment_report_t) -> Bool { _c_nw_establishment_report_get_used_proxy(raw(report)) }
public func nw_framer_copy_local_endpoint(_ framer: nw_framer_t) -> nw_endpoint_t { take(_c_nw_framer_copy_local_endpoint(raw(framer))) }
public func nw_framer_copy_options(_ framer: nw_framer_t) -> nw_protocol_options_t { take(_c_nw_framer_copy_options(raw(framer))) }
public func nw_framer_copy_parameters(_ framer: nw_framer_t) -> nw_parameters_t { take(_c_nw_framer_copy_parameters(raw(framer))) }
public func nw_framer_copy_remote_endpoint(_ framer: nw_framer_t) -> nw_endpoint_t { take(_c_nw_framer_copy_remote_endpoint(raw(framer))) }
public func nw_framer_create_options(_ framer_definition: nw_protocol_definition_t) -> nw_protocol_options_t { take(_c_nw_framer_create_options(raw(framer_definition))) }
public func nw_framer_deliver_input(_ framer: nw_framer_t, _ input_buffer: UnsafePointer<UInt8>, _ input_length: Int, _ message: nw_framer_message_t, _ is_complete: Bool) { _c_nw_framer_deliver_input(raw(framer), input_buffer, input_length, raw(message), is_complete) }
public func nw_framer_deliver_input_no_copy(_ framer: nw_framer_t, _ input_length: Int, _ message: nw_framer_message_t, _ is_complete: Bool) -> Bool { _c_nw_framer_deliver_input_no_copy(raw(framer), input_length, raw(message), is_complete) }
public func nw_framer_mark_failed_with_error(_ framer: nw_framer_t, _ error_code: Int32) { _c_nw_framer_mark_failed_with_error(raw(framer), error_code) }
public func nw_framer_mark_ready(_ framer: nw_framer_t) { _c_nw_framer_mark_ready(raw(framer)) }
public func nw_framer_message_create(_ framer: nw_framer_t) -> nw_framer_message_t { take(_c_nw_framer_message_create(raw(framer))) }
public func nw_framer_message_set_value(_ message: nw_framer_message_t, _ key: UnsafePointer<CChar>, _ value: UnsafeMutableRawPointer?, _ dispose_value: nw_framer_message_dispose_value_t?) { _c_nw_framer_message_set_value(raw(message), key, value, dispose_value.map { d in { d($0) } }) }
public func nw_framer_pass_through_input(_ framer: nw_framer_t) { _c_nw_framer_pass_through_input(raw(framer)) }
public func nw_framer_pass_through_output(_ framer: nw_framer_t) { _c_nw_framer_pass_through_output(raw(framer)) }
public func nw_framer_prepend_application_protocol(_ framer: nw_framer_t, _ protocol_options: nw_protocol_options_t) -> Bool { _c_nw_framer_prepend_application_protocol(raw(framer), raw(protocol_options)) }
public func nw_framer_protocol_create_message(_ definition: nw_protocol_definition_t) -> nw_framer_message_t { take(_c_nw_framer_protocol_create_message(raw(definition))) }
public func nw_framer_schedule_wakeup(_ framer: nw_framer_t, _ milliseconds: UInt64) { _c_nw_framer_schedule_wakeup(raw(framer), milliseconds) }
public func nw_framer_write_output(_ framer: nw_framer_t, _ output_buffer: UnsafePointer<UInt8>, _ output_length: Int) { _c_nw_framer_write_output(raw(framer), output_buffer, output_length) }
public func nw_framer_write_output_data(_ framer: nw_framer_t, _ output_data: dispatch_data_t) { _c_nw_framer_write_output_data(raw(framer), output_data) }
public func nw_framer_write_output_no_copy(_ framer: nw_framer_t, _ output_length: Int) -> Bool { _c_nw_framer_write_output_no_copy(raw(framer), output_length) }
public func nw_group_descriptor_add_endpoint(_ descriptor: nw_group_descriptor_t, _ endpoint: nw_endpoint_t) -> Bool { _c_nw_group_descriptor_add_endpoint(raw(descriptor), raw(endpoint)) }
public func nw_group_descriptor_create_multicast(_ multicast_group: nw_endpoint_t) -> nw_group_descriptor_t { take(_c_nw_group_descriptor_create_multicast(raw(multicast_group))) }
public func nw_group_descriptor_create_multiplex(_ remote_endpoint: nw_endpoint_t) -> nw_group_descriptor_t { take(_c_nw_group_descriptor_create_multiplex(raw(remote_endpoint))) }
public func nw_ip_create_metadata() -> nw_protocol_metadata_t { take(_c_nw_ip_create_metadata()) }
public func nw_ip_metadata_get_ecn_flag(_ metadata: nw_protocol_metadata_t) -> nw_ip_ecn_flag_t { .init(_c_nw_ip_metadata_get_ecn_flag(raw(metadata))) }
public func nw_ip_metadata_get_receive_time(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_ip_metadata_get_receive_time(raw(metadata)) }
public func nw_ip_metadata_get_service_class(_ metadata: nw_protocol_metadata_t) -> nw_service_class_t { .init(_c_nw_ip_metadata_get_service_class(raw(metadata))) }
public func nw_ip_metadata_set_ecn_flag(_ metadata: nw_protocol_metadata_t, _ ecn_flag: nw_ip_ecn_flag_t) { _c_nw_ip_metadata_set_ecn_flag(raw(metadata), UInt32(ecn_flag.rawValue)) }
public func nw_ip_metadata_set_service_class(_ metadata: nw_protocol_metadata_t, _ service_class: nw_service_class_t) { _c_nw_ip_metadata_set_service_class(raw(metadata), UInt32(service_class.rawValue)) }
public func nw_ip_options_set_calculate_receive_time(_ options: nw_protocol_options_t, _ calculate_receive_time: Bool) { _c_nw_ip_options_set_calculate_receive_time(raw(options), calculate_receive_time) }
public func nw_ip_options_set_disable_fragmentation(_ options: nw_protocol_options_t, _ disable_fragmentation: Bool) { _c_nw_ip_options_set_disable_fragmentation(raw(options), disable_fragmentation) }
public func nw_ip_options_set_disable_multicast_loopback(_ options: nw_protocol_options_t, _ disable_multicast_loopback: Bool) { _c_nw_ip_options_set_disable_multicast_loopback(raw(options), disable_multicast_loopback) }
public func nw_ip_options_set_hop_limit(_ options: nw_protocol_options_t, _ hop_limit: UInt8) { _c_nw_ip_options_set_hop_limit(raw(options), hop_limit) }
public func nw_ip_options_set_local_address_preference(_ options: nw_protocol_options_t, _ preference: nw_ip_local_address_preference_t) { _c_nw_ip_options_set_local_address_preference(raw(options), UInt32(preference.rawValue)) }
public func nw_ip_options_set_use_minimum_mtu(_ options: nw_protocol_options_t, _ use_minimum_mtu: Bool) { _c_nw_ip_options_set_use_minimum_mtu(raw(options), use_minimum_mtu) }
public func nw_ip_options_set_version(_ options: nw_protocol_options_t, _ version: nw_ip_version_t) { _c_nw_ip_options_set_version(raw(options), UInt32(version.rawValue)) }
public func nw_listener_create_with_connection(_ connection: nw_connection_t, _ parameters: nw_parameters_t) -> nw_listener_t? { takeOptional(_c_nw_listener_create_with_connection(raw(connection), raw(parameters))) }
public func nw_multicast_group_descriptor_get_disable_unicast_traffic(_ multicast_descriptor: nw_group_descriptor_t) -> Bool { _c_nw_multicast_group_descriptor_get_disable_unicast_traffic(raw(multicast_descriptor)) }
public func nw_multicast_group_descriptor_set_disable_unicast_traffic(_ multicast_descriptor: nw_group_descriptor_t, _ disable_unicast_traffic: Bool) { _c_nw_multicast_group_descriptor_set_disable_unicast_traffic(raw(multicast_descriptor), disable_unicast_traffic) }
public func nw_multicast_group_descriptor_set_specific_source(_ multicast_descriptor: nw_group_descriptor_t, _ source: nw_endpoint_t) { _c_nw_multicast_group_descriptor_set_specific_source(raw(multicast_descriptor), raw(source)) }
public func nw_parameters_create_application_service() -> nw_parameters_t { take(_c_nw_parameters_create_application_service()) }
public func nw_parameters_get_allow_ultra_constrained(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_get_allow_ultra_constrained(raw(parameters)) }
public func nw_parameters_get_attribution(_ parameters: nw_parameters_t) -> nw_parameters_attribution_t { nw_parameters_attribution_t(rawValue: _c_nw_parameters_get_attribution(raw(parameters))) ?? .developer }
public func nw_parameters_requires_dnssec_validation(_ parameters: nw_parameters_t) -> Bool { _c_nw_parameters_requires_dnssec_validation(raw(parameters)) }
public func nw_parameters_set_allow_ultra_constrained(_ parameters: nw_parameters_t, _ allow_ultra_constrained: Bool) { _c_nw_parameters_set_allow_ultra_constrained(raw(parameters), allow_ultra_constrained) }
public func nw_parameters_set_attribution(_ parameters: nw_parameters_t, _ attribution: nw_parameters_attribution_t) { _c_nw_parameters_set_attribution(raw(parameters), attribution.rawValue) }
public func nw_parameters_set_requires_dnssec_validation(_ parameters: nw_parameters_t, _ requires_dnssec_validation: Bool) { _c_nw_parameters_set_requires_dnssec_validation(raw(parameters), requires_dnssec_validation) }
public func nw_path_get_link_quality(_ path: nw_path_t) -> nw_link_quality_t { .init(_c_nw_path_get_link_quality(raw(path))) }
public func nw_path_get_unsatisfied_reason(_ path: nw_path_t) -> nw_path_unsatisfied_reason_t { .init(_c_nw_path_get_unsatisfied_reason(raw(path))) }
public func nw_path_is_equal(_ path: nw_path_t, _ other_path: nw_path_t) -> Bool { _c_nw_path_is_equal(raw(path), raw(other_path)) }
public func nw_path_is_ultra_constrained(_ path: nw_path_t) -> Bool { _c_nw_path_is_ultra_constrained(raw(path)) }
public func nw_path_monitor_prohibit_interface_type(_ monitor: nw_path_monitor_t, _ interface_type: nw_interface_type_t) { _c_nw_path_monitor_prohibit_interface_type(raw(monitor), Int32(interface_type.rawValue)) }
public func nw_protocol_copy_ip_definition() -> nw_protocol_definition_t { take(_c_nw_protocol_copy_ip_definition()) }
public func nw_protocol_copy_quic_definition() -> nw_protocol_definition_t { take(_c_nw_protocol_copy_quic_definition()) }
public func nw_protocol_copy_tcp_definition() -> nw_protocol_definition_t { take(_c_nw_protocol_copy_tcp_definition()) }
public func nw_protocol_copy_tls_definition() -> nw_protocol_definition_t { take(_c_nw_protocol_copy_tls_definition()) }
public func nw_protocol_copy_udp_definition() -> nw_protocol_definition_t { take(_c_nw_protocol_copy_udp_definition()) }
public func nw_protocol_copy_ws_definition() -> nw_protocol_definition_t { take(_c_nw_protocol_copy_ws_definition()) }
public func nw_protocol_metadata_copy_definition(_ metadata: nw_protocol_metadata_t) -> nw_protocol_definition_t { take(_c_nw_protocol_metadata_copy_definition(raw(metadata))) }
public func nw_protocol_metadata_is_framer_message(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_framer_message(raw(metadata)) }
public func nw_protocol_metadata_is_ip(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_ip(raw(metadata)) }
public func nw_protocol_metadata_is_quic(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_quic(raw(metadata)) }
public func nw_protocol_metadata_is_tcp(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_tcp(raw(metadata)) }
public func nw_protocol_metadata_is_tls(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_tls(raw(metadata)) }
public func nw_protocol_metadata_is_udp(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_udp(raw(metadata)) }
public func nw_protocol_metadata_is_ws(_ metadata: nw_protocol_metadata_t) -> Bool { _c_nw_protocol_metadata_is_ws(raw(metadata)) }
public func nw_protocol_options_is_quic(_ options: nw_protocol_options_t) -> Bool { _c_nw_protocol_options_is_quic(raw(options)) }
public func nw_proxy_config_add_excluded_domain(_ config: nw_proxy_config_t, _ excluded_domain: UnsafePointer<CChar>) { _c_nw_proxy_config_add_excluded_domain(raw(config), excluded_domain) }
public func nw_proxy_config_add_match_domain(_ config: nw_proxy_config_t, _ match_domain: UnsafePointer<CChar>) { _c_nw_proxy_config_add_match_domain(raw(config), match_domain) }
public func nw_proxy_config_clear_excluded_domains(_ config: nw_proxy_config_t) { _c_nw_proxy_config_clear_excluded_domains(raw(config)) }
public func nw_proxy_config_clear_match_domains(_ config: nw_proxy_config_t) { _c_nw_proxy_config_clear_match_domains(raw(config)) }
public func nw_quic_add_tls_application_protocol(_ options: nw_protocol_options_t, _ application_protocol: UnsafePointer<CChar>) { _c_nw_quic_add_tls_application_protocol(raw(options), application_protocol) }
public func nw_quic_copy_sec_protocol_metadata(_ metadata: nw_protocol_metadata_t) -> sec_protocol_metadata_t { ((metadata as! _NWCMetadata).metadata as? NWProtocolQUIC.Metadata)?.securityProtocolMetadata ?? sec_protocol_metadata_t() }
public func nw_quic_copy_sec_protocol_options(_ options: nw_protocol_options_t) -> sec_protocol_options_t { ((options as! _NWCProtocolOptions).options as? NWProtocolQUIC.Options)?.securityProtocolOptions ?? sec_protocol_options_t() }
public func nw_quic_create_options() -> nw_protocol_options_t { take(_c_nw_quic_create_options()) }
public func nw_quic_get_application_error(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_application_error(raw(metadata)) }
public func nw_quic_get_application_error_reason(_ metadata: nw_protocol_metadata_t) -> UnsafePointer<CChar>? { _c_nw_quic_get_application_error_reason(raw(metadata)) }
public func nw_quic_get_idle_timeout(_ options: nw_protocol_options_t) -> UInt32 { _c_nw_quic_get_idle_timeout(raw(options)) }
public func nw_quic_get_initial_max_data(_ options: nw_protocol_options_t) -> UInt64 { _c_nw_quic_get_initial_max_data(raw(options)) }
public func nw_quic_get_initial_max_stream_data_bidirectional_local(_ options: nw_protocol_options_t) -> UInt64 { _c_nw_quic_get_initial_max_stream_data_bidirectional_local(raw(options)) }
public func nw_quic_get_initial_max_stream_data_bidirectional_remote(_ options: nw_protocol_options_t) -> UInt64 { _c_nw_quic_get_initial_max_stream_data_bidirectional_remote(raw(options)) }
public func nw_quic_get_initial_max_stream_data_unidirectional(_ options: nw_protocol_options_t) -> UInt64 { _c_nw_quic_get_initial_max_stream_data_unidirectional(raw(options)) }
public func nw_quic_get_initial_max_streams_bidirectional(_ options: nw_protocol_options_t) -> UInt64 { _c_nw_quic_get_initial_max_streams_bidirectional(raw(options)) }
public func nw_quic_get_initial_max_streams_unidirectional(_ options: nw_protocol_options_t) -> UInt64 { _c_nw_quic_get_initial_max_streams_unidirectional(raw(options)) }
public func nw_quic_get_keepalive_interval(_ metadata: nw_protocol_metadata_t) -> UInt16 { _c_nw_quic_get_keepalive_interval(raw(metadata)) }
public func nw_quic_get_local_max_streams_bidirectional(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_local_max_streams_bidirectional(raw(metadata)) }
public func nw_quic_get_local_max_streams_unidirectional(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_local_max_streams_unidirectional(raw(metadata)) }
public func nw_quic_get_max_datagram_frame_size(_ options: nw_protocol_options_t) -> UInt16 { _c_nw_quic_get_max_datagram_frame_size(raw(options)) }
public func nw_quic_get_max_udp_payload_size(_ options: nw_protocol_options_t) -> UInt16 { _c_nw_quic_get_max_udp_payload_size(raw(options)) }
public func nw_quic_get_remote_idle_timeout(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_remote_idle_timeout(raw(metadata)) }
public func nw_quic_get_remote_max_streams_bidirectional(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_remote_max_streams_bidirectional(raw(metadata)) }
public func nw_quic_get_remote_max_streams_unidirectional(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_remote_max_streams_unidirectional(raw(metadata)) }
public func nw_quic_get_stream_application_error(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_stream_application_error(raw(metadata)) }
public func nw_quic_get_stream_id(_ metadata: nw_protocol_metadata_t) -> UInt64 { _c_nw_quic_get_stream_id(raw(metadata)) }
public func nw_quic_get_stream_is_datagram(_ options: nw_protocol_options_t) -> Bool { _c_nw_quic_get_stream_is_datagram(raw(options)) }
public func nw_quic_get_stream_is_unidirectional(_ options: nw_protocol_options_t) -> Bool { _c_nw_quic_get_stream_is_unidirectional(raw(options)) }
public func nw_quic_get_stream_type(_ stream_metadata: nw_protocol_metadata_t) -> UInt8 { _c_nw_quic_get_stream_type(raw(stream_metadata)) }
public func nw_quic_get_stream_usable_datagram_frame_size(_ metadata: nw_protocol_metadata_t) -> UInt16 { _c_nw_quic_get_stream_usable_datagram_frame_size(raw(metadata)) }
public func nw_quic_set_application_error(_ metadata: nw_protocol_metadata_t, _ application_error: UInt64, _ reason: UnsafePointer<CChar>?) { _c_nw_quic_set_application_error(raw(metadata), application_error, reason) }
public func nw_quic_set_idle_timeout(_ options: nw_protocol_options_t, _ idle_timeout: UInt32) { _c_nw_quic_set_idle_timeout(raw(options), idle_timeout) }
public func nw_quic_set_initial_max_data(_ options: nw_protocol_options_t, _ initial_max_data: UInt64) { _c_nw_quic_set_initial_max_data(raw(options), initial_max_data) }
public func nw_quic_set_initial_max_stream_data_bidirectional_local(_ options: nw_protocol_options_t, _ initial_max_stream_data_bidirectional_local: UInt64) { _c_nw_quic_set_initial_max_stream_data_bidirectional_local(raw(options), initial_max_stream_data_bidirectional_local) }
public func nw_quic_set_initial_max_stream_data_bidirectional_remote(_ options: nw_protocol_options_t, _ initial_max_stream_data_bidirectional_remote: UInt64) { _c_nw_quic_set_initial_max_stream_data_bidirectional_remote(raw(options), initial_max_stream_data_bidirectional_remote) }
public func nw_quic_set_initial_max_stream_data_unidirectional(_ options: nw_protocol_options_t, _ initial_max_stream_data_unidirectional: UInt64) { _c_nw_quic_set_initial_max_stream_data_unidirectional(raw(options), initial_max_stream_data_unidirectional) }
public func nw_quic_set_initial_max_streams_bidirectional(_ options: nw_protocol_options_t, _ initial_max_streams_bidirectional: UInt64) { _c_nw_quic_set_initial_max_streams_bidirectional(raw(options), initial_max_streams_bidirectional) }
public func nw_quic_set_initial_max_streams_unidirectional(_ options: nw_protocol_options_t, _ initial_max_streams_unidirectional: UInt64) { _c_nw_quic_set_initial_max_streams_unidirectional(raw(options), initial_max_streams_unidirectional) }
public func nw_quic_set_keepalive_interval(_ metadata: nw_protocol_metadata_t, _ keepalive_interval: UInt16) { _c_nw_quic_set_keepalive_interval(raw(metadata), keepalive_interval) }
public func nw_quic_set_local_max_streams_bidirectional(_ metadata: nw_protocol_metadata_t, _ max_streams_bidirectional: UInt64) { _c_nw_quic_set_local_max_streams_bidirectional(raw(metadata), max_streams_bidirectional) }
public func nw_quic_set_local_max_streams_unidirectional(_ metadata: nw_protocol_metadata_t, _ max_streams_unidirectional: UInt64) { _c_nw_quic_set_local_max_streams_unidirectional(raw(metadata), max_streams_unidirectional) }
public func nw_quic_set_max_datagram_frame_size(_ options: nw_protocol_options_t, _ max_datagram_frame_size: UInt16) { _c_nw_quic_set_max_datagram_frame_size(raw(options), max_datagram_frame_size) }
public func nw_quic_set_max_udp_payload_size(_ options: nw_protocol_options_t, _ max_udp_payload_size: UInt16) { _c_nw_quic_set_max_udp_payload_size(raw(options), max_udp_payload_size) }
public func nw_quic_set_stream_application_error(_ metadata: nw_protocol_metadata_t, _ application_error: UInt64) { _c_nw_quic_set_stream_application_error(raw(metadata), application_error) }
public func nw_quic_set_stream_is_datagram(_ options: nw_protocol_options_t, _ is_datagram: Bool) { _c_nw_quic_set_stream_is_datagram(raw(options), is_datagram) }
public func nw_quic_set_stream_is_unidirectional(_ options: nw_protocol_options_t, _ is_unidirectional: Bool) { _c_nw_quic_set_stream_is_unidirectional(raw(options), is_unidirectional) }
public func nw_resolution_report_copy_preferred_endpoint(_ resolution_report: nw_resolution_report_t) -> nw_endpoint_t { take(_c_nw_resolution_report_copy_preferred_endpoint(raw(resolution_report))) }
public func nw_resolution_report_copy_successful_endpoint(_ resolution_report: nw_resolution_report_t) -> nw_endpoint_t { take(_c_nw_resolution_report_copy_successful_endpoint(raw(resolution_report))) }
public func nw_resolution_report_get_endpoint_count(_ resolution_report: nw_resolution_report_t) -> UInt32 { _c_nw_resolution_report_get_endpoint_count(raw(resolution_report)) }
public func nw_resolution_report_get_milliseconds(_ resolution_report: nw_resolution_report_t) -> UInt64 { _c_nw_resolution_report_get_milliseconds(raw(resolution_report)) }
public func nw_resolution_report_get_protocol(_ resolution_report: nw_resolution_report_t) -> nw_report_resolution_protocol_t { .init(_c_nw_resolution_report_get_protocol(raw(resolution_report))) }
public func nw_resolution_report_get_source(_ resolution_report: nw_resolution_report_t) -> nw_report_resolution_source_t { .init(_c_nw_resolution_report_get_source(raw(resolution_report))) }
public func nw_tcp_get_available_receive_buffer(_ metadata: nw_protocol_metadata_t) -> UInt32 { _c_nw_tcp_get_available_receive_buffer(raw(metadata)) }
public func nw_tcp_get_available_send_buffer(_ metadata: nw_protocol_metadata_t) -> UInt32 { _c_nw_tcp_get_available_send_buffer(raw(metadata)) }
public func nw_tcp_options_set_disable_ack_stretching(_ options: nw_protocol_options_t, _ disable_ack_stretching: Bool) { _c_nw_tcp_options_set_disable_ack_stretching(raw(options), disable_ack_stretching) }
public func nw_tcp_options_set_disable_ecn(_ options: nw_protocol_options_t, _ disable_ecn: Bool) { _c_nw_tcp_options_set_disable_ecn(raw(options), disable_ecn) }
public func nw_tcp_options_set_maximum_segment_size(_ options: nw_protocol_options_t, _ maximum_segment_size: UInt32) { _c_nw_tcp_options_set_maximum_segment_size(raw(options), maximum_segment_size) }
public func nw_tcp_options_set_multipath_force_version(_ options: nw_protocol_options_t, _ multipath_force_version: nw_multipath_version_t) { _c_nw_tcp_options_set_multipath_force_version(raw(options), Int32(multipath_force_version.rawValue)) }
public func nw_tcp_options_set_no_options(_ options: nw_protocol_options_t, _ no_options: Bool) { _c_nw_tcp_options_set_no_options(raw(options), no_options) }
public func nw_tcp_options_set_persist_timeout(_ options: nw_protocol_options_t, _ persist_timeout: UInt32) { _c_nw_tcp_options_set_persist_timeout(raw(options), persist_timeout) }
public func nw_tcp_options_set_retransmit_connection_drop_time(_ options: nw_protocol_options_t, _ retransmit_connection_drop_time: UInt32) { _c_nw_tcp_options_set_retransmit_connection_drop_time(raw(options), retransmit_connection_drop_time) }
public func nw_tcp_options_set_retransmit_fin_drop(_ options: nw_protocol_options_t, _ retransmit_fin_drop: Bool) { _c_nw_tcp_options_set_retransmit_fin_drop(raw(options), retransmit_fin_drop) }
public func nw_tcp_set_max_pacing_rate(_ metadata: nw_protocol_metadata_t, _ max_pacing_rate: UInt64) -> Int32 { _c_nw_tcp_set_max_pacing_rate(raw(metadata), max_pacing_rate) }
public func nw_tls_copy_sec_protocol_metadata(_ metadata: nw_protocol_metadata_t) -> sec_protocol_metadata_t { ((metadata as! _NWCMetadata).metadata as? NWProtocolTLS.Metadata)?.securityProtocolMetadata ?? sec_protocol_metadata_t() }
public func nw_tls_copy_sec_protocol_options(_ options: nw_protocol_options_t) -> sec_protocol_options_t { ((options as! _NWCProtocolOptions).options as? NWProtocolTLS.Options)?.securityProtocolOptions ?? sec_protocol_options_t() }
public func nw_txt_record_copy(_ txt_record: nw_txt_record_t?) -> nw_txt_record_t? { takeOptional(_c_nw_txt_record_copy(txt_record.map { UnsafeRawPointer(raw($0)) })) }
public func nw_txt_record_create_dictionary() -> nw_txt_record_t { take(_c_nw_txt_record_create_dictionary()) }
public func nw_txt_record_create_with_bytes(_ txt_bytes: UnsafePointer<UInt8>, _ txt_len: Int) -> nw_txt_record_t { take(_c_nw_txt_record_create_with_bytes(txt_bytes, txt_len)) }
public func nw_txt_record_find_key(_ txt_record: nw_txt_record_t, _ key: UnsafePointer<CChar>) -> nw_txt_record_find_key_t { .init(_c_nw_txt_record_find_key(raw(txt_record), key)) }
public func nw_txt_record_get_key_count(_ txt_record: nw_txt_record_t?) -> Int { _c_nw_txt_record_get_key_count(txt_record.map { UnsafeRawPointer(raw($0)) }) }
public func nw_txt_record_is_dictionary(_ txt_record: nw_txt_record_t) -> Bool { _c_nw_txt_record_is_dictionary(raw(txt_record)) }
public func nw_txt_record_is_equal(_ left: nw_txt_record_t?, _ right: nw_txt_record_t?) -> Bool { _c_nw_txt_record_is_equal(left.map { UnsafeRawPointer(raw($0)) }, right.map { UnsafeRawPointer(raw($0)) }) }
public func nw_txt_record_remove_key(_ txt_record: nw_txt_record_t, _ key: UnsafePointer<CChar>) -> Bool { _c_nw_txt_record_remove_key(raw(txt_record), key) }
public func nw_txt_record_set_key(_ txt_record: nw_txt_record_t, _ key: UnsafePointer<CChar>, _ value: UnsafePointer<UInt8>?, _ value_len: Int) -> Bool { _c_nw_txt_record_set_key(raw(txt_record), key, value, value_len) }
public func nw_udp_create_metadata() -> nw_protocol_metadata_t { take(_c_nw_udp_create_metadata()) }
public func nw_ws_create_metadata(_ opcode: nw_ws_opcode_t) -> nw_protocol_metadata_t { take(_c_nw_ws_create_metadata(Int32(opcode.rawValue))) }
public func nw_ws_create_options(_ version: nw_ws_version_t) -> nw_protocol_options_t { take(_c_nw_ws_create_options(UInt32(version.rawValue))) }
public func nw_ws_metadata_copy_server_response(_ metadata: nw_protocol_metadata_t) -> nw_ws_response_t { take(_c_nw_ws_metadata_copy_server_response(raw(metadata))) }
public func nw_ws_metadata_get_close_code(_ metadata: nw_protocol_metadata_t) -> nw_ws_close_code_t { .init(_c_nw_ws_metadata_get_close_code(raw(metadata))) }
public func nw_ws_metadata_get_opcode(_ metadata: nw_protocol_metadata_t) -> nw_ws_opcode_t { .init(_c_nw_ws_metadata_get_opcode(raw(metadata))) }
public func nw_ws_metadata_set_close_code(_ metadata: nw_protocol_metadata_t, _ close_code: nw_ws_close_code_t) { _c_nw_ws_metadata_set_close_code(raw(metadata), UInt32(close_code.rawValue)) }
public func nw_ws_options_add_additional_header(_ options: nw_protocol_options_t, _ name: UnsafePointer<CChar>, _ value: UnsafePointer<CChar>) { _c_nw_ws_options_add_additional_header(raw(options), name, value) }
public func nw_ws_options_add_subprotocol(_ options: nw_protocol_options_t, _ subprotocol: UnsafePointer<CChar>) { _c_nw_ws_options_add_subprotocol(raw(options), subprotocol) }
public func nw_ws_options_set_auto_reply_ping(_ options: nw_protocol_options_t, _ auto_reply_ping: Bool) { _c_nw_ws_options_set_auto_reply_ping(raw(options), auto_reply_ping) }
public func nw_ws_options_set_maximum_message_size(_ options: nw_protocol_options_t, _ maximum_message_size: Int) { _c_nw_ws_options_set_maximum_message_size(raw(options), maximum_message_size) }
public func nw_ws_options_set_skip_handshake(_ options: nw_protocol_options_t, _ skip_handshake: Bool) { _c_nw_ws_options_set_skip_handshake(raw(options), skip_handshake) }
public func nw_ws_response_add_additional_header(_ response: nw_ws_response_t, _ name: UnsafePointer<CChar>, _ value: UnsafePointer<CChar>) { _c_nw_ws_response_add_additional_header(raw(response), name, value) }
public func nw_ws_response_create(_ status: nw_ws_response_status_t, _ selected_subprotocol: UnsafePointer<CChar>?) -> nw_ws_response_t { take(_c_nw_ws_response_create(UInt32(status.rawValue), selected_subprotocol)) }
public func nw_ws_response_get_selected_subprotocol(_ response: nw_ws_response_t) -> UnsafePointer<CChar>? { _c_nw_ws_response_get_selected_subprotocol(raw(response)) }
public func nw_ws_response_get_status(_ response: nw_ws_response_t?) -> nw_ws_response_status_t { .init(_c_nw_ws_response_get_status(response.map { UnsafeRawPointer(raw($0)) })) }

// MARK: - functions with blocks and queues

public func nw_parameters_create_quic(_ configure_quic: @escaping nw_parameters_configure_protocol_block_t) -> nw_parameters_t {
    let o = _NWCProtocolOptions(NWProtocolQUIC.Options())
    configure_quic(o)
    return _NWCParameters(NWParameters(quic: o.options as! NWProtocolQUIC.Options))
}
public func nw_content_context_foreach_protocol_metadata(_ context: nw_content_context_t, _ foreach_block: @escaping (nw_protocol_definition_t, nw_protocol_metadata_t) -> Void) {
    _c_nw_content_context_foreach_protocol_metadata(raw(context)) { d, m in foreach_block(d as! _NWCDefinition, m as! _NWCMetadata) }
}
public func nw_connection_access_establishment_report(_ connection: nw_connection_t, _ queue: DispatchQueue, _ access_block: @escaping nw_establishment_report_access_block_t) {
    let box = _NWCUnchecked(access_block)
    (connection as! _NWCConnection).connection.requestEstablishmentReport(queue: queue) { r in box.value(r.map { _NWCEstablishmentReport($0) }) }
}
public func nw_establishment_report_enumerate_resolutions(_ report: nw_establishment_report_t, _ enumerate_block: (nw_report_resolution_source_t, UInt64, UInt32, nw_endpoint_t, nw_endpoint_t) -> Bool) {
    withoutActuallyEscaping(enumerate_block) { f in
        _c_nw_establishment_report_enumerate_resolutions(raw(report)) { s, t, n, a, b in f(.init(s), t, n, a as! _NWCEndpoint, b as! _NWCEndpoint) }
    }
}
public func nw_establishment_report_enumerate_resolution_reports(_ report: nw_establishment_report_t, _ enumerate_block: (nw_resolution_report_t) -> Bool) {
    withoutActuallyEscaping(enumerate_block) { f in _c_nw_establishment_report_enumerate_resolution_reports(raw(report)) { f($0 as! _NWCResolutionReport) } }
}
public func nw_establishment_report_enumerate_protocols(_ report: nw_establishment_report_t, _ enumerate_block: (nw_protocol_definition_t, UInt64, UInt64) -> Bool) {
    withoutActuallyEscaping(enumerate_block) { f in _c_nw_establishment_report_enumerate_protocols(raw(report)) { f($0 as! _NWCDefinition, $1, $2) } }
}
public func nw_data_transfer_report_collect(_ report: nw_data_transfer_report_t, _ queue: DispatchQueue, _ collect_block: @escaping nw_data_transfer_report_collect_block_t) {
    let o = report as! _NWCDataTransferReport, box = _NWCUnchecked(collect_block)
    o.pending.collect(queue: queue) { r in o.collected = r; box.value(o) }
}
public func nw_path_enumerate_gateways(_ path: nw_path_t, _ enumerate_block: (nw_endpoint_t) -> Bool) {
    withoutActuallyEscaping(enumerate_block) { f in _c_nw_path_enumerate_gateways(raw(path)) { f($0 as! _NWCEndpoint) } }
}
public func nw_group_descriptor_enumerate_endpoints(_ descriptor: nw_group_descriptor_t, _ enumerate_block: (nw_endpoint_t) -> Bool) {
    withoutActuallyEscaping(enumerate_block) { f in _c_nw_group_descriptor_enumerate_endpoints(raw(descriptor)) { f($0 as! _NWCEndpoint) } }
}
public func nw_connection_group_set_queue(_ group: nw_connection_group_t, _ queue: DispatchQueue) { (group as! _NWCConnectionGroup).swiftQueue = queue }
public func nw_connection_group_set_state_changed_handler(_ group: nw_connection_group_t, _ state_changed_handler: nw_connection_group_state_changed_handler_t?) {
    _c_nw_connection_group_set_state_changed_handler(raw(group), state_changed_handler.map { h in { s, e in h(.init(s), e as? _NWCError) } })
}
public func nw_connection_group_set_receive_handler(_ group: nw_connection_group_t, _ maximum_message_size: UInt32, _ reject_oversized_messages: Bool,
                                                    _ receive_handler: nw_connection_group_receive_handler_t?) {
    _c_nw_connection_group_set_receive_handler(raw(group), maximum_message_size, reject_oversized_messages,
                                               receive_handler.map { h in { d, c, complete in h(d, c as! _NWCContext, complete) } })
}
public func nw_connection_group_set_new_connection_handler(_ group: nw_connection_group_t, _ new_connection_handler: nw_connection_group_new_connection_handler_t?) {
    _c_nw_connection_group_set_new_connection_handler(raw(group), new_connection_handler.map { h in { h($0 as! _NWCConnection) } })
}
public func nw_connection_group_send_message(_ group: nw_connection_group_t, _ content: dispatch_data_t?, _ endpoint: nw_endpoint_t?,
                                             _ context: nw_content_context_t, _ completion: @escaping nw_connection_group_send_completion_t) {
    _c_nw_connection_group_send_message(raw(group), content, endpoint.map { UnsafeRawPointer(raw($0)) }, raw(context)) { completion($0 as? _NWCError) }
}
public func nw_connection_group_reply(_ group: nw_connection_group_t, _ inbound_message: nw_content_context_t, _ outbound_message: nw_content_context_t,
                                      _ content: dispatch_data_t?) {
    _c_nw_connection_group_reply(raw(group), raw(inbound_message), raw(outbound_message), content)
}
public func nw_listener_set_new_connection_group_handler(_ listener: nw_listener_t, _ handler: nw_listener_new_connection_group_handler_t?) {
    _c_nw_listener_set_new_connection_group_handler(raw(listener), handler.map { h in { h($0 as! _NWCConnectionGroup) } })
}
public func nw_txt_record_access_key(_ txt_record: nw_txt_record_t, _ key: UnsafePointer<CChar>, _ access_value: @escaping nw_txt_record_access_key_t) -> Bool {
    _c_nw_txt_record_access_key(raw(txt_record), key) { k, f, v, n in access_value(k, .init(f), v, n) }
}
public func nw_txt_record_access_bytes(_ txt_record: nw_txt_record_t, _ access_bytes: @escaping nw_txt_record_access_bytes_t) -> Bool {
    _c_nw_txt_record_access_bytes(raw(txt_record)) { access_bytes($0, $1) }
}
public func nw_txt_record_apply(_ txt_record: nw_txt_record_t, _ applier: @escaping nw_txt_record_applier_t) -> Bool {
    _c_nw_txt_record_apply(raw(txt_record)) { k, f, v, n in applier(k, .init(f), v, n) }
}
public func nw_proxy_config_enumerate_match_domains(_ config: nw_proxy_config_t, _ enumerator: (UnsafePointer<CChar>) -> Void) {
    withoutActuallyEscaping(enumerator) { f in _c_nw_proxy_config_enumerate_match_domains(raw(config)) { f($0) } }
}
public func nw_proxy_config_enumerate_excluded_domains(_ config: nw_proxy_config_t, _ enumerator: (UnsafePointer<CChar>) -> Void) {
    withoutActuallyEscaping(enumerator) { f in _c_nw_proxy_config_enumerate_excluded_domains(raw(config)) { f($0) } }
}
public func nw_ws_metadata_set_pong_handler(_ metadata: nw_protocol_metadata_t, _ client_queue: DispatchQueue, _ pong_handler: @escaping nw_ws_pong_handler_t) {
    ((metadata as! _NWCMetadata).metadata as? NWProtocolWebSocket.Metadata)?.setPongHandler(client_queue) { e in pong_handler(e.map { _NWCError($0) }) }
}
public func nw_ws_options_set_client_request_handler(_ options: nw_protocol_options_t, _ client_queue: DispatchQueue, _ handler: @escaping nw_ws_client_request_handler_t) {
    ((options as! _NWCProtocolOptions).options as? NWProtocolWebSocket.Options)?.setClientRequestHandler(client_queue) { r in
        (handler(_NWCWSRequest(r)) as! _NWCWSResponse).response
    }
}
public func nw_ws_request_enumerate_subprotocols(_ request: nw_ws_request_t, _ enumerator: (UnsafePointer<CChar>) -> Bool) -> Bool {
    withoutActuallyEscaping(enumerator) { f in _c_nw_ws_request_enumerate_subprotocols(raw(request)) { f($0) } }
}
public func nw_ws_request_enumerate_additional_headers(_ request: nw_ws_request_t, _ enumerator: (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool) -> Bool {
    withoutActuallyEscaping(enumerator) { f in _c_nw_ws_request_enumerate_additional_headers(raw(request)) { f($0, $1) } }
}
public func nw_ws_response_enumerate_additional_headers(_ response: nw_ws_response_t, _ enumerator: (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool) -> Bool {
    withoutActuallyEscaping(enumerator) { f in _c_nw_ws_response_enumerate_additional_headers(raw(response)) { f($0, $1) } }
}
public func nw_framer_create_definition(_ identifier: UnsafePointer<CChar>, _ flags: UInt32, _ start_handler: @escaping nw_framer_start_handler_t) -> nw_protocol_definition_t {
    take(_c_nw_framer_create_definition(identifier, flags) { start_handler($0 as! _NWCFramer).rawValue })
}
public func nw_framer_set_input_handler(_ framer: nw_framer_t, _ input_handler: @escaping nw_framer_input_handler_t) { (framer as! _NWCFramer).input = { input_handler($0 as! _NWCFramer) } }
public func nw_framer_set_output_handler(_ framer: nw_framer_t, _ output_handler: @escaping nw_framer_output_handler_t) {
    (framer as! _NWCFramer).output = { output_handler($0 as! _NWCFramer, $1 as! _NWCMetadata, $2, $3) }
}
public func nw_framer_set_wakeup_handler(_ framer: nw_framer_t, _ wakeup_handler: @escaping nw_framer_wakeup_handler_t) { (framer as! _NWCFramer).wakeup = { wakeup_handler($0 as! _NWCFramer) } }
public func nw_framer_set_stop_handler(_ framer: nw_framer_t, _ stop_handler: @escaping nw_framer_stop_handler_t) { (framer as! _NWCFramer).stop = { stop_handler($0 as! _NWCFramer) } }
public func nw_framer_set_cleanup_handler(_ framer: nw_framer_t, _ cleanup_handler: @escaping nw_framer_cleanup_handler_t) { (framer as! _NWCFramer).cleanup = { cleanup_handler($0 as! _NWCFramer) } }
public func nw_framer_async(_ framer: nw_framer_t, _ async_block: @escaping nw_framer_block_t) { (framer as! _NWCFramer).instance.async(execute: async_block) }
public func nw_framer_parse_input(_ framer: nw_framer_t, _ minimum_incomplete_length: Int, _ maximum_length: Int, _ temp_buffer: UnsafeMutablePointer<UInt8>?,
                                  _ parse: (UnsafeMutablePointer<UInt8>?, Int, Bool) -> Int) -> Bool {
    (framer as! _NWCFramer).instance.parseInput(minimumIncompleteLength: minimum_incomplete_length, maximumLength: maximum_length) { b, c in
        parse(b?.baseAddress?.assumingMemoryBound(to: UInt8.self), b?.count ?? 0, c)
    }
}
public func nw_framer_parse_output(_ framer: nw_framer_t, _ minimum_incomplete_length: Int, _ maximum_length: Int, _ temp_buffer: UnsafeMutablePointer<UInt8>?,
                                   _ parse: (UnsafeMutablePointer<UInt8>?, Int, Bool) -> Int) -> Bool {
    (framer as! _NWCFramer).instance.parseOutput(minimumIncompleteLength: minimum_incomplete_length, maximumLength: maximum_length) { b, c in
        parse(b?.baseAddress?.assumingMemoryBound(to: UInt8.self), b?.count ?? 0, c)
    }
}
public func nw_framer_message_access_value(_ message: nw_framer_message_t, _ key: UnsafePointer<CChar>, _ access_value: (UnsafeRawPointer?) -> Bool) -> Bool {
    withoutActuallyEscaping(access_value) { f in _c_nw_framer_message_access_value(raw(message), key) { f($0) } }
}
public func nw_framer_message_set_object_value(_ message: nw_framer_message_t, _ key: UnsafePointer<CChar>, _ value: Any?) {
    ((message as! _NWCMetadata).metadata as? NWProtocolFramer.Message)?[String(cString: key)] = value
}
public func nw_framer_message_copy_object_value(_ message: nw_framer_message_t, _ key: UnsafePointer<CChar>) -> Any? {
    ((message as! _NWCMetadata).metadata as? NWProtocolFramer.Message)?[String(cString: key)]
}
public func nw_framer_options_set_object_value(_ options: nw_protocol_options_t, _ key: UnsafePointer<CChar>, _ value: Any?) {
    ((options as! _NWCProtocolOptions).options as? NWProtocolFramer.Options)?[String(cString: key)] = value
}
public func nw_framer_options_copy_object_value(_ options: nw_protocol_options_t, _ key: UnsafePointer<CChar>) -> Any? {
    ((options as! _NWCProtocolOptions).options as? NWProtocolFramer.Options)?[String(cString: key)]
}

// MARK: - helpers

@inline(__always) private func raw(_ o: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passUnretained(o).toOpaque() }
private func take<T>(_ p: UnsafeMutableRawPointer) -> T { Unmanaged<AnyObject>.fromOpaque(p).takeRetainedValue() as! T }
private func takeOptional<T>(_ p: UnsafeMutableRawPointer?) -> T? { p.map { take($0) } }
