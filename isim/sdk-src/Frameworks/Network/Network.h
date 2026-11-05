#pragma once
/* isim Network for C and Objective-C: endpoints, parameters, connections, listeners, Bonjour browsing and the path
   monitor, over the Network Swift overlay's NWConnection, NWListener, NWBrowser and NWPathMonitor (Network.framework
   re-exports libswiftNetwork.dylib): TCP, UDP and TLS on the host's sockets and OpenSSL, Bonjour over isim's local
   registry and multicast DNS. The objects are Objective-C objects (ARC retains them; nw_retain / nw_release in C).
   Swift uses the overlay; these declarations are hidden from Swift. Not available from C yet: the sec_protocol_options
   functions (TLS uses the host's CA store and checks the host name; nw_tls_copy_sec_protocol_options hands out the
   object), protocol stacks, privacy contexts and ethernet channels (types only). */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS
typedef NSObject *nw_path_monitor_t, *nw_path_t, *nw_interface_t;
typedef NSObject *nw_endpoint_t, *nw_parameters_t, *nw_protocol_options_t, *nw_connection_t, *nw_content_context_t,
    *nw_error_t, *nw_listener_t, *nw_advertise_descriptor_t, *nw_browser_t, *nw_browse_descriptor_t, *nw_browse_result_t;
typedef enum { nw_path_status_invalid = 0, nw_path_status_satisfied = 1, nw_path_status_unsatisfied = 2, nw_path_status_satisfiable = 3 } nw_path_status_t;
typedef enum { nw_interface_type_other = 0, nw_interface_type_wifi = 1, nw_interface_type_cellular = 2, nw_interface_type_wired = 3,
               nw_interface_type_loopback = 4 } nw_interface_type_t;
typedef void (^nw_path_monitor_update_handler_t)(nw_path_t path);
typedef void (^nw_path_monitor_cancel_handler_t)(void);
typedef bool (^nw_path_enumerate_interfaces_block_t)(nw_interface_t interface);
nw_path_monitor_t nw_path_monitor_create(void) NS_RETURNS_RETAINED;
nw_path_monitor_t nw_path_monitor_create_with_type(nw_interface_type_t required_interface_type) NS_RETURNS_RETAINED;
void nw_path_monitor_set_queue(nw_path_monitor_t monitor, dispatch_queue_t queue);
void nw_path_monitor_set_update_handler(nw_path_monitor_t monitor, nw_path_monitor_update_handler_t update_handler);
void nw_path_monitor_set_cancel_handler(nw_path_monitor_t monitor, nw_path_monitor_cancel_handler_t cancel_handler);
void nw_path_monitor_start(nw_path_monitor_t monitor);
void nw_path_monitor_cancel(nw_path_monitor_t monitor);
nw_path_status_t nw_path_get_status(nw_path_t path);
bool nw_path_is_expensive(nw_path_t path);
bool nw_path_is_constrained(nw_path_t path);
bool nw_path_has_ipv4(nw_path_t path);
bool nw_path_has_ipv6(nw_path_t path);
bool nw_path_has_dns(nw_path_t path);
bool nw_path_uses_interface_type(nw_path_t path, nw_interface_type_t interface_type);
void nw_path_enumerate_interfaces(nw_path_t path, nw_path_enumerate_interfaces_block_t enumerate_block);
nw_interface_type_t nw_interface_get_type(nw_interface_t interface);
nw_endpoint_t _Nullable nw_path_copy_effective_local_endpoint(nw_path_t path) NS_RETURNS_RETAINED;
nw_endpoint_t _Nullable nw_path_copy_effective_remote_endpoint(nw_path_t path) NS_RETURNS_RETAINED;
const char *nw_interface_get_name(nw_interface_t interface);
uint32_t nw_interface_get_index(nw_interface_t interface);

void *nw_retain(void *obj);
void nw_release(void *obj);

/* endpoints */
typedef enum { nw_endpoint_type_invalid = 0, nw_endpoint_type_address = 1, nw_endpoint_type_host = 2,
               nw_endpoint_type_bonjour_service = 3, nw_endpoint_type_url = 4 } nw_endpoint_type_t;
nw_endpoint_t nw_endpoint_create_host(const char *hostname, const char *port) NS_RETURNS_RETAINED;
nw_endpoint_t nw_endpoint_create_address(const struct sockaddr *address) NS_RETURNS_RETAINED;
nw_endpoint_t nw_endpoint_create_bonjour_service(const char *name, const char *type, const char *domain) NS_RETURNS_RETAINED;
nw_endpoint_t nw_endpoint_create_url(const char *url) NS_RETURNS_RETAINED;
nw_endpoint_type_t nw_endpoint_get_type(nw_endpoint_t endpoint);
const char * _Nullable nw_endpoint_get_hostname(nw_endpoint_t endpoint);
uint16_t nw_endpoint_get_port(nw_endpoint_t endpoint);
char *nw_endpoint_copy_port_string(nw_endpoint_t endpoint);
char *nw_endpoint_copy_address_string(nw_endpoint_t endpoint);
const struct sockaddr * _Nullable nw_endpoint_get_address(nw_endpoint_t endpoint);
const char * _Nullable nw_endpoint_get_bonjour_service_name(nw_endpoint_t endpoint);
const char * _Nullable nw_endpoint_get_bonjour_service_type(nw_endpoint_t endpoint);
const char * _Nullable nw_endpoint_get_bonjour_service_domain(nw_endpoint_t endpoint);
const char * _Nullable nw_endpoint_get_url(nw_endpoint_t endpoint);

/* errors */
typedef enum { nw_error_domain_invalid = 0, nw_error_domain_posix = 1, nw_error_domain_dns = 2, nw_error_domain_tls = 3,
               nw_error_domain_wifi_aware = 4 } nw_error_domain_t;
extern const CFStringRef kNWErrorDomainPOSIX, kNWErrorDomainDNS, kNWErrorDomainTLS;
nw_error_domain_t nw_error_get_error_domain(nw_error_t error);
int nw_error_get_error_code(nw_error_t error);
CFErrorRef nw_error_copy_cf_error(nw_error_t error) CF_RETURNS_RETAINED;

/* parameters and protocol options */
typedef void (^nw_parameters_configure_protocol_block_t)(nw_protocol_options_t options);
extern const nw_parameters_configure_protocol_block_t _nw_parameters_configure_protocol_default_configuration;
extern const nw_parameters_configure_protocol_block_t _nw_parameters_configure_protocol_disable;
#define NW_PARAMETERS_DEFAULT_CONFIGURATION (_nw_parameters_configure_protocol_default_configuration)
#define NW_PARAMETERS_DISABLE_PROTOCOL (_nw_parameters_configure_protocol_disable)
nw_parameters_t nw_parameters_create(void) NS_RETURNS_RETAINED;
nw_parameters_t nw_parameters_create_secure_tcp(nw_parameters_configure_protocol_block_t configure_tls,
                                                nw_parameters_configure_protocol_block_t configure_tcp) NS_RETURNS_RETAINED;
nw_parameters_t nw_parameters_create_secure_udp(nw_parameters_configure_protocol_block_t configure_dtls,
                                                nw_parameters_configure_protocol_block_t configure_udp) NS_RETURNS_RETAINED;
nw_parameters_t nw_parameters_copy(nw_parameters_t parameters) NS_RETURNS_RETAINED;
void nw_parameters_set_local_endpoint(nw_parameters_t parameters, nw_endpoint_t _Nullable local_endpoint);
nw_endpoint_t _Nullable nw_parameters_copy_local_endpoint(nw_parameters_t parameters) NS_RETURNS_RETAINED;
void nw_parameters_set_reuse_local_address(nw_parameters_t parameters, bool reuse_local_address);
bool nw_parameters_get_reuse_local_address(nw_parameters_t parameters);
void nw_parameters_set_include_peer_to_peer(nw_parameters_t parameters, bool include_peer_to_peer);
bool nw_parameters_get_include_peer_to_peer(nw_parameters_t parameters);
void nw_parameters_set_local_only(nw_parameters_t parameters, bool local_only);
bool nw_parameters_get_local_only(nw_parameters_t parameters);
void nw_parameters_set_fast_open_enabled(nw_parameters_t parameters, bool fast_open_enabled);
bool nw_parameters_get_fast_open_enabled(nw_parameters_t parameters);
void nw_parameters_set_required_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type);
nw_interface_type_t nw_parameters_get_required_interface_type(nw_parameters_t parameters);
void nw_parameters_set_prohibit_expensive(nw_parameters_t parameters, bool prohibit_expensive);
bool nw_parameters_get_prohibit_expensive(nw_parameters_t parameters);
void nw_parameters_set_prohibit_constrained(nw_parameters_t parameters, bool prohibit_constrained);
bool nw_parameters_get_prohibit_constrained(nw_parameters_t parameters);
bool nw_protocol_options_is_tcp(nw_protocol_options_t options);
bool nw_protocol_options_is_udp(nw_protocol_options_t options);
bool nw_protocol_options_is_tls(nw_protocol_options_t options);
nw_protocol_options_t nw_tcp_create_options(void) NS_RETURNS_RETAINED;
nw_protocol_options_t nw_udp_create_options(void) NS_RETURNS_RETAINED;
nw_protocol_options_t nw_tls_create_options(void) NS_RETURNS_RETAINED;
void nw_tcp_options_set_no_delay(nw_protocol_options_t options, bool no_delay);
void nw_tcp_options_set_no_push(nw_protocol_options_t options, bool no_push);
void nw_tcp_options_set_enable_keepalive(nw_protocol_options_t options, bool enable_keepalive);
void nw_tcp_options_set_keepalive_count(nw_protocol_options_t options, uint32_t keepalive_count);
void nw_tcp_options_set_keepalive_idle_time(nw_protocol_options_t options, uint32_t keepalive_idle_time);
void nw_tcp_options_set_keepalive_interval(nw_protocol_options_t options, uint32_t keepalive_interval);
void nw_tcp_options_set_connection_timeout(nw_protocol_options_t options, uint32_t connection_timeout);
void nw_tcp_options_set_enable_fast_open(nw_protocol_options_t options, bool enable_fast_open);
void nw_udp_options_set_prefer_no_checksum(nw_protocol_options_t options, bool prefer_no_checksum);

/* content contexts */
nw_content_context_t nw_content_context_create(const char *context_identifier) NS_RETURNS_RETAINED;
const char *nw_content_context_get_identifier(nw_content_context_t context);
bool nw_content_context_get_is_final(nw_content_context_t context);
void nw_content_context_set_is_final(nw_content_context_t context, bool is_final);
uint64_t nw_content_context_get_expiration_milliseconds(nw_content_context_t context);
void nw_content_context_set_expiration_milliseconds(nw_content_context_t context, uint64_t expiration_milliseconds);
double nw_content_context_get_relative_priority(nw_content_context_t context);
void nw_content_context_set_relative_priority(nw_content_context_t context, double relative_priority);
void nw_content_context_set_antecedent(nw_content_context_t context, nw_content_context_t _Nullable antecedent_context);
nw_content_context_t _Nullable nw_content_context_copy_antecedent(nw_content_context_t context) NS_RETURNS_RETAINED;
extern nw_content_context_t _nw_content_context_default_message, _nw_content_context_final_send, _nw_content_context_default_stream;
#define NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT (_nw_content_context_default_message)
#define NW_CONNECTION_FINAL_MESSAGE_CONTEXT (_nw_content_context_final_send)
#define NW_CONNECTION_DEFAULT_STREAM_CONTEXT (_nw_content_context_default_stream)

/* connections */
typedef enum { nw_connection_state_invalid = 0, nw_connection_state_waiting = 1, nw_connection_state_preparing = 2,
               nw_connection_state_ready = 3, nw_connection_state_failed = 4, nw_connection_state_cancelled = 5 } nw_connection_state_t;
typedef void (^nw_connection_state_changed_handler_t)(nw_connection_state_t state, nw_error_t _Nullable error);
typedef void (^nw_connection_boolean_event_handler_t)(bool value);
typedef void (^nw_connection_path_event_handler_t)(nw_path_t path);
typedef void (^nw_connection_send_completion_t)(nw_error_t _Nullable error);
typedef void (^nw_connection_receive_completion_t)(dispatch_data_t _Nullable content, nw_content_context_t _Nullable context,
                                                    bool is_complete, nw_error_t _Nullable error);
extern const nw_connection_send_completion_t _nw_connection_send_idempotent_content;
#define NW_CONNECTION_SEND_IDEMPOTENT_CONTENT (_nw_connection_send_idempotent_content)
nw_connection_t nw_connection_create(nw_endpoint_t endpoint, nw_parameters_t parameters) NS_RETURNS_RETAINED;
nw_endpoint_t nw_connection_copy_endpoint(nw_connection_t connection) NS_RETURNS_RETAINED;
nw_parameters_t nw_connection_copy_parameters(nw_connection_t connection) NS_RETURNS_RETAINED;
void nw_connection_set_queue(nw_connection_t connection, dispatch_queue_t queue);
void nw_connection_set_state_changed_handler(nw_connection_t connection, nw_connection_state_changed_handler_t _Nullable handler);
void nw_connection_set_viability_changed_handler(nw_connection_t connection, nw_connection_boolean_event_handler_t _Nullable handler);
void nw_connection_set_better_path_available_handler(nw_connection_t connection, nw_connection_boolean_event_handler_t _Nullable handler);
void nw_connection_set_path_changed_handler(nw_connection_t connection, nw_connection_path_event_handler_t _Nullable handler);
void nw_connection_start(nw_connection_t connection);
void nw_connection_restart(nw_connection_t connection);
void nw_connection_cancel(nw_connection_t connection);
void nw_connection_force_cancel(nw_connection_t connection);
void nw_connection_cancel_current_endpoint(nw_connection_t connection);
void nw_connection_receive(nw_connection_t connection, uint32_t minimum_incomplete_length, uint32_t maximum_length,
                           nw_connection_receive_completion_t completion);
void nw_connection_receive_message(nw_connection_t connection, nw_connection_receive_completion_t completion);
void nw_connection_send(nw_connection_t connection, dispatch_data_t _Nullable content, nw_content_context_t context, bool is_complete,
                        nw_connection_send_completion_t completion);
void nw_connection_batch(nw_connection_t connection, dispatch_block_t batch_block);
nw_path_t _Nullable nw_connection_copy_current_path(nw_connection_t connection) NS_RETURNS_RETAINED;
uint32_t nw_connection_get_maximum_datagram_size(nw_connection_t connection);
char *nw_connection_copy_description(nw_connection_t connection);

/* listeners and Bonjour advertising */
typedef enum { nw_listener_state_invalid = 0, nw_listener_state_waiting = 1, nw_listener_state_ready = 2,
               nw_listener_state_failed = 3, nw_listener_state_cancelled = 4 } nw_listener_state_t;
typedef void (^nw_listener_state_changed_handler_t)(nw_listener_state_t state, nw_error_t _Nullable error);
typedef void (^nw_listener_new_connection_handler_t)(nw_connection_t connection);
typedef void (^nw_listener_advertised_endpoint_changed_handler_t)(nw_endpoint_t advertised_endpoint, bool added);
#define NW_LISTENER_INFINITE_CONNECTION_LIMIT UINT32_MAX
nw_listener_t _Nullable nw_listener_create(nw_parameters_t parameters) NS_RETURNS_RETAINED;
nw_listener_t _Nullable nw_listener_create_with_port(const char *port, nw_parameters_t parameters) NS_RETURNS_RETAINED;
void nw_listener_set_queue(nw_listener_t listener, dispatch_queue_t queue);
void nw_listener_set_state_changed_handler(nw_listener_t listener, nw_listener_state_changed_handler_t _Nullable handler);
void nw_listener_set_new_connection_handler(nw_listener_t listener, nw_listener_new_connection_handler_t _Nullable handler);
void nw_listener_set_advertised_endpoint_changed_handler(nw_listener_t listener,
                                                         nw_listener_advertised_endpoint_changed_handler_t _Nullable handler);
uint32_t nw_listener_get_new_connection_limit(nw_listener_t listener);
void nw_listener_set_new_connection_limit(nw_listener_t listener, uint32_t new_connection_limit);
void nw_listener_set_advertise_descriptor(nw_listener_t listener, nw_advertise_descriptor_t _Nullable advertise_descriptor);
uint16_t nw_listener_get_port(nw_listener_t listener);
void nw_listener_start(nw_listener_t listener);
void nw_listener_cancel(nw_listener_t listener);
nw_advertise_descriptor_t _Nullable nw_advertise_descriptor_create_bonjour_service(const char * _Nullable name, const char *type,
                                                                                    const char * _Nullable domain) NS_RETURNS_RETAINED;
void nw_advertise_descriptor_set_txt_record(nw_advertise_descriptor_t advertise_descriptor, const void * _Nullable txt_record,
                                            size_t txt_length);

/* Bonjour browsing */
typedef enum { nw_browser_state_invalid = 0, nw_browser_state_ready = 1, nw_browser_state_failed = 2,
               nw_browser_state_cancelled = 3, nw_browser_state_waiting = 4 } nw_browser_state_t;
typedef uint64_t nw_browse_result_change_t;
#define nw_browse_result_change_invalid 0x00
#define nw_browse_result_change_identical 0x01
#define nw_browse_result_change_result_added 0x02
#define nw_browse_result_change_result_removed 0x04
#define nw_browse_result_change_interface_added 0x08
#define nw_browse_result_change_interface_removed 0x10
#define nw_browse_result_change_txt_record_changed 0x20
typedef void (^nw_browser_state_changed_handler_t)(nw_browser_state_t state, nw_error_t _Nullable error);
typedef void (^nw_browser_browse_results_changed_handler_t)(nw_browse_result_t old_result, nw_browse_result_t new_result,
                                                            bool batch_complete);
nw_browse_descriptor_t nw_browse_descriptor_create_bonjour_service(const char *type, const char * _Nullable domain) NS_RETURNS_RETAINED;
const char *nw_browse_descriptor_get_bonjour_service_type(nw_browse_descriptor_t descriptor);
const char * _Nullable nw_browse_descriptor_get_bonjour_service_domain(nw_browse_descriptor_t descriptor);
void nw_browse_descriptor_set_include_txt_record(nw_browse_descriptor_t descriptor, bool include_txt_record);
bool nw_browse_descriptor_get_include_txt_record(nw_browse_descriptor_t descriptor);
nw_browser_t nw_browser_create(nw_browse_descriptor_t descriptor, nw_parameters_t _Nullable parameters) NS_RETURNS_RETAINED;
nw_browse_descriptor_t nw_browser_copy_browse_descriptor(nw_browser_t browser) NS_RETURNS_RETAINED;
nw_parameters_t nw_browser_copy_parameters(nw_browser_t browser) NS_RETURNS_RETAINED;
void nw_browser_set_queue(nw_browser_t browser, dispatch_queue_t queue);
void nw_browser_set_browse_results_changed_handler(nw_browser_t browser, nw_browser_browse_results_changed_handler_t _Nullable handler);
void nw_browser_set_state_changed_handler(nw_browser_t browser, nw_browser_state_changed_handler_t _Nullable state_changed_handler);
void nw_browser_start(nw_browser_t browser);
void nw_browser_cancel(nw_browser_t browser);
nw_browse_result_change_t nw_browse_result_get_changes(nw_browse_result_t _Nullable old_result, nw_browse_result_t _Nullable new_result);
nw_endpoint_t nw_browse_result_copy_endpoint(nw_browse_result_t result) NS_RETURNS_RETAINED;
size_t nw_browse_result_get_interfaces_count(nw_browse_result_t result);
typedef bool (^nw_browse_result_enumerate_interface_t)(nw_interface_t interface);
void nw_browse_result_enumerate_interfaces(nw_browse_result_t result, nw_browse_result_enumerate_interface_t enumerator);
/* ---- issue #851: protocol definitions and metadata, IP/TCP/UDP/TLS/QUIC/WebSocket options and metadata, TXT
   records, reports, connection groups, framers, proxy configurations ---- */
typedef NSObject *nw_object_t, *nw_protocol_definition_t, *nw_protocol_metadata_t, *nw_txt_record_t, *nw_establishment_report_t,
    *nw_resolution_report_t, *nw_data_transfer_report_t, *nw_group_descriptor_t, *nw_connection_group_t, *nw_ws_request_t,
    *nw_ws_response_t, *nw_framer_t, *nw_proxy_config_t, *nw_ethernet_channel_t, *nw_privacy_context_t, *nw_protocol_stack_t,
    *nw_relay_hop_t, *nw_resolver_config_t;
typedef nw_protocol_metadata_t nw_framer_message_t;
#ifndef ISIM_SEC_PROTOCOL_OBJECTS
#define ISIM_SEC_PROTOCOL_OBJECTS
typedef NSObject *sec_protocol_options_t, *sec_protocol_metadata_t;
#endif
extern const CFStringRef kNWErrorDomainWiFiAware;

/* protocol definitions and metadata */
nw_protocol_definition_t nw_protocol_copy_ip_definition(void) NS_RETURNS_RETAINED;
nw_protocol_definition_t nw_protocol_copy_tcp_definition(void) NS_RETURNS_RETAINED;
nw_protocol_definition_t nw_protocol_copy_udp_definition(void) NS_RETURNS_RETAINED;
nw_protocol_definition_t nw_protocol_copy_tls_definition(void) NS_RETURNS_RETAINED;
nw_protocol_definition_t nw_protocol_copy_quic_definition(void) NS_RETURNS_RETAINED;
nw_protocol_definition_t nw_protocol_copy_ws_definition(void) NS_RETURNS_RETAINED;
bool nw_protocol_definition_is_equal(nw_protocol_definition_t definition1, nw_protocol_definition_t definition2);
nw_protocol_definition_t nw_protocol_metadata_copy_definition(nw_protocol_metadata_t metadata) NS_RETURNS_RETAINED;
bool nw_protocol_metadata_is_ip(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_tcp(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_udp(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_tls(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_quic(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_ws(nw_protocol_metadata_t metadata);
bool nw_protocol_metadata_is_framer_message(nw_protocol_metadata_t metadata);
bool nw_protocol_options_is_quic(nw_protocol_options_t options);
nw_protocol_metadata_t _Nullable nw_connection_copy_protocol_metadata(nw_connection_t connection, nw_protocol_definition_t definition) NS_RETURNS_RETAINED;
nw_protocol_metadata_t _Nullable nw_content_context_copy_protocol_metadata(nw_content_context_t context, nw_protocol_definition_t protocol) NS_RETURNS_RETAINED;
void nw_content_context_foreach_protocol_metadata(nw_content_context_t context,
                                                  void (^foreach_block)(nw_protocol_definition_t definition, nw_protocol_metadata_t metadata));
void nw_content_context_set_metadata_for_protocol(nw_content_context_t context, nw_protocol_metadata_t protocol_metadata);

/* IP */
typedef enum { nw_ip_version_any = 0, nw_ip_version_4 = 4, nw_ip_version_6 = 6 } nw_ip_version_t;
typedef enum { nw_ip_local_address_preference_default = 0, nw_ip_local_address_preference_temporary = 1,
               nw_ip_local_address_preference_stable = 2 } nw_ip_local_address_preference_t;
typedef enum { nw_ip_ecn_flag_non_ect = 0, nw_ip_ecn_flag_ect_0 = 2, nw_ip_ecn_flag_ect_1 = 1, nw_ip_ecn_flag_ce = 3 } nw_ip_ecn_flag_t;
typedef enum { nw_service_class_best_effort = 0, nw_service_class_background = 1, nw_service_class_interactive_video = 2,
               nw_service_class_interactive_voice = 3, nw_service_class_responsive_data = 4, nw_service_class_signaling = 5 } nw_service_class_t;
void nw_ip_options_set_version(nw_protocol_options_t options, nw_ip_version_t version);
void nw_ip_options_set_hop_limit(nw_protocol_options_t options, uint8_t hop_limit);
void nw_ip_options_set_use_minimum_mtu(nw_protocol_options_t options, bool use_minimum_mtu);
void nw_ip_options_set_disable_fragmentation(nw_protocol_options_t options, bool disable_fragmentation);
void nw_ip_options_set_calculate_receive_time(nw_protocol_options_t options, bool calculate_receive_time);
void nw_ip_options_set_local_address_preference(nw_protocol_options_t options, nw_ip_local_address_preference_t preference);
void nw_ip_options_set_disable_multicast_loopback(nw_protocol_options_t options, bool disable_multicast_loopback);
nw_protocol_metadata_t nw_ip_create_metadata(void) NS_RETURNS_RETAINED;
void nw_ip_metadata_set_ecn_flag(nw_protocol_metadata_t metadata, nw_ip_ecn_flag_t ecn_flag);
nw_ip_ecn_flag_t nw_ip_metadata_get_ecn_flag(nw_protocol_metadata_t metadata);
void nw_ip_metadata_set_service_class(nw_protocol_metadata_t metadata, nw_service_class_t service_class);
nw_service_class_t nw_ip_metadata_get_service_class(nw_protocol_metadata_t metadata);
uint64_t nw_ip_metadata_get_receive_time(nw_protocol_metadata_t metadata);

/* TCP, UDP, TLS */
typedef enum { nw_multipath_version_unspecified = -1, nw_multipath_version_0 = 0, nw_multipath_version_1 = 1 } nw_multipath_version_t;
void nw_tcp_options_set_no_options(nw_protocol_options_t options, bool no_options);
void nw_tcp_options_set_maximum_segment_size(nw_protocol_options_t options, uint32_t maximum_segment_size);
void nw_tcp_options_set_persist_timeout(nw_protocol_options_t options, uint32_t persist_timeout);
void nw_tcp_options_set_retransmit_connection_drop_time(nw_protocol_options_t options, uint32_t retransmit_connection_drop_time);
void nw_tcp_options_set_retransmit_fin_drop(nw_protocol_options_t options, bool retransmit_fin_drop);
void nw_tcp_options_set_disable_ack_stretching(nw_protocol_options_t options, bool disable_ack_stretching);
void nw_tcp_options_set_disable_ecn(nw_protocol_options_t options, bool disable_ecn);
void nw_tcp_options_set_multipath_force_version(nw_protocol_options_t options, nw_multipath_version_t multipath_force_version);
uint32_t nw_tcp_get_available_receive_buffer(nw_protocol_metadata_t metadata);
uint32_t nw_tcp_get_available_send_buffer(nw_protocol_metadata_t metadata);
int nw_tcp_set_max_pacing_rate(nw_protocol_metadata_t metadata, uint64_t max_pacing_rate);
nw_protocol_metadata_t nw_udp_create_metadata(void) NS_RETURNS_RETAINED;
sec_protocol_options_t nw_tls_copy_sec_protocol_options(nw_protocol_options_t options) NS_RETURNS_RETAINED;
sec_protocol_metadata_t nw_tls_copy_sec_protocol_metadata(nw_protocol_metadata_t metadata) NS_RETURNS_RETAINED;

/* QUIC (isim has no QUIC transport yet: connections fail with ENOTSUP) */
typedef enum { nw_quic_stream_type_unknown = 0, nw_quic_stream_type_bidirectional = 1, nw_quic_stream_type_unidirectional = 2,
               nw_quic_stream_type_datagram = 3 } nw_quic_stream_type_t;
#define NW_QUIC_CONNECTION_DEFAULT_KEEPALIVE 1
nw_protocol_options_t nw_quic_create_options(void) NS_RETURNS_RETAINED;
nw_parameters_t nw_parameters_create_quic(nw_parameters_configure_protocol_block_t configure_quic) NS_RETURNS_RETAINED;
void nw_quic_add_tls_application_protocol(nw_protocol_options_t options, const char *application_protocol);
sec_protocol_options_t nw_quic_copy_sec_protocol_options(nw_protocol_options_t options) NS_RETURNS_RETAINED;
sec_protocol_metadata_t nw_quic_copy_sec_protocol_metadata(nw_protocol_metadata_t metadata) NS_RETURNS_RETAINED;
bool nw_quic_get_stream_is_unidirectional(nw_protocol_options_t options);
void nw_quic_set_stream_is_unidirectional(nw_protocol_options_t options, bool is_unidirectional);
bool nw_quic_get_stream_is_datagram(nw_protocol_options_t options);
void nw_quic_set_stream_is_datagram(nw_protocol_options_t options, bool is_datagram);
uint32_t nw_quic_get_idle_timeout(nw_protocol_options_t options);
void nw_quic_set_idle_timeout(nw_protocol_options_t options, uint32_t idle_timeout);
uint16_t nw_quic_get_max_udp_payload_size(nw_protocol_options_t options);
void nw_quic_set_max_udp_payload_size(nw_protocol_options_t options, uint16_t max_udp_payload_size);
uint64_t nw_quic_get_initial_max_data(nw_protocol_options_t options);
void nw_quic_set_initial_max_data(nw_protocol_options_t options, uint64_t initial_max_data);
uint64_t nw_quic_get_initial_max_stream_data_bidirectional_local(nw_protocol_options_t options);
void nw_quic_set_initial_max_stream_data_bidirectional_local(nw_protocol_options_t options, uint64_t value);
uint64_t nw_quic_get_initial_max_stream_data_bidirectional_remote(nw_protocol_options_t options);
void nw_quic_set_initial_max_stream_data_bidirectional_remote(nw_protocol_options_t options, uint64_t value);
uint64_t nw_quic_get_initial_max_stream_data_unidirectional(nw_protocol_options_t options);
void nw_quic_set_initial_max_stream_data_unidirectional(nw_protocol_options_t options, uint64_t value);
uint64_t nw_quic_get_initial_max_streams_bidirectional(nw_protocol_options_t options);
void nw_quic_set_initial_max_streams_bidirectional(nw_protocol_options_t options, uint64_t value);
uint64_t nw_quic_get_initial_max_streams_unidirectional(nw_protocol_options_t options);
void nw_quic_set_initial_max_streams_unidirectional(nw_protocol_options_t options, uint64_t value);
uint16_t nw_quic_get_max_datagram_frame_size(nw_protocol_options_t options);
void nw_quic_set_max_datagram_frame_size(nw_protocol_options_t options, uint16_t max_datagram_frame_size);
uint64_t nw_quic_get_stream_id(nw_protocol_metadata_t metadata);
uint8_t nw_quic_get_stream_type(nw_protocol_metadata_t stream_metadata);
uint64_t nw_quic_get_stream_application_error(nw_protocol_metadata_t metadata);
void nw_quic_set_stream_application_error(nw_protocol_metadata_t metadata, uint64_t application_error);
uint16_t nw_quic_get_stream_usable_datagram_frame_size(nw_protocol_metadata_t metadata);
uint64_t nw_quic_get_local_max_streams_bidirectional(nw_protocol_metadata_t metadata);
void nw_quic_set_local_max_streams_bidirectional(nw_protocol_metadata_t metadata, uint64_t max_streams_bidirectional);
uint64_t nw_quic_get_local_max_streams_unidirectional(nw_protocol_metadata_t metadata);
void nw_quic_set_local_max_streams_unidirectional(nw_protocol_metadata_t metadata, uint64_t max_streams_unidirectional);
uint64_t nw_quic_get_remote_max_streams_bidirectional(nw_protocol_metadata_t metadata);
uint64_t nw_quic_get_remote_max_streams_unidirectional(nw_protocol_metadata_t metadata);
uint64_t nw_quic_get_remote_idle_timeout(nw_protocol_metadata_t metadata);
uint16_t nw_quic_get_keepalive_interval(nw_protocol_metadata_t metadata);
void nw_quic_set_keepalive_interval(nw_protocol_metadata_t metadata, uint16_t keepalive_interval);
uint64_t nw_quic_get_application_error(nw_protocol_metadata_t metadata);
const char * _Nullable nw_quic_get_application_error_reason(nw_protocol_metadata_t metadata);
void nw_quic_set_application_error(nw_protocol_metadata_t metadata, uint64_t application_error, const char * _Nullable reason);

/* WebSocket */
typedef enum { nw_ws_version_invalid = 0, nw_ws_version_13 = 1 } nw_ws_version_t;
typedef enum { nw_ws_opcode_invalid = -1, nw_ws_opcode_cont = 0, nw_ws_opcode_text = 1, nw_ws_opcode_binary = 2,
               nw_ws_opcode_close = 8, nw_ws_opcode_ping = 9, nw_ws_opcode_pong = 10 } nw_ws_opcode_t;
typedef enum { nw_ws_close_code_normal_closure = 1000, nw_ws_close_code_going_away = 1001, nw_ws_close_code_protocol_error = 1002,
               nw_ws_close_code_unsupported_data = 1003, nw_ws_close_code_no_status_received = 1005,
               nw_ws_close_code_abnormal_closure = 1006, nw_ws_close_code_invalid_frame_payload_data = 1007,
               nw_ws_close_code_policy_violation = 1008, nw_ws_close_code_message_too_big = 1009,
               nw_ws_close_code_mandatory_extension = 1010, nw_ws_close_code_internal_server_error = 1011,
               nw_ws_close_code_tls_handshake = 1015 } nw_ws_close_code_t;
typedef enum { nw_ws_response_status_invalid = 0, nw_ws_response_status_accept = 1, nw_ws_response_status_reject = 2 } nw_ws_response_status_t;
typedef void (^nw_ws_pong_handler_t)(nw_error_t _Nullable error);
typedef nw_ws_response_t _Nonnull (^nw_ws_client_request_handler_t)(nw_ws_request_t request);
typedef bool (^nw_ws_subprotocol_enumerator_t)(const char *subprotocol);
typedef bool (^nw_ws_additional_header_enumerator_t)(const char *name, const char *value);
nw_protocol_options_t nw_ws_create_options(nw_ws_version_t version) NS_RETURNS_RETAINED;
void nw_ws_options_add_additional_header(nw_protocol_options_t options, const char *name, const char *value);
void nw_ws_options_add_subprotocol(nw_protocol_options_t options, const char *subprotocol);
void nw_ws_options_set_auto_reply_ping(nw_protocol_options_t options, bool auto_reply_ping);
void nw_ws_options_set_skip_handshake(nw_protocol_options_t options, bool skip_handshake);
void nw_ws_options_set_maximum_message_size(nw_protocol_options_t options, size_t maximum_message_size);
void nw_ws_options_set_client_request_handler(nw_protocol_options_t options, dispatch_queue_t client_queue, nw_ws_client_request_handler_t handler);
nw_protocol_metadata_t nw_ws_create_metadata(nw_ws_opcode_t opcode) NS_RETURNS_RETAINED;
nw_ws_opcode_t nw_ws_metadata_get_opcode(nw_protocol_metadata_t metadata);
void nw_ws_metadata_set_close_code(nw_protocol_metadata_t metadata, nw_ws_close_code_t close_code);
nw_ws_close_code_t nw_ws_metadata_get_close_code(nw_protocol_metadata_t metadata);
void nw_ws_metadata_set_pong_handler(nw_protocol_metadata_t metadata, dispatch_queue_t client_queue, nw_ws_pong_handler_t pong_handler);
nw_ws_response_t nw_ws_metadata_copy_server_response(nw_protocol_metadata_t metadata) NS_RETURNS_RETAINED;
bool nw_ws_request_enumerate_subprotocols(nw_ws_request_t request, nw_ws_subprotocol_enumerator_t enumerator);
bool nw_ws_request_enumerate_additional_headers(nw_ws_request_t request, nw_ws_additional_header_enumerator_t enumerator);
nw_ws_response_t nw_ws_response_create(nw_ws_response_status_t status, const char * _Nullable selected_subprotocol) NS_RETURNS_RETAINED;
nw_ws_response_status_t nw_ws_response_get_status(nw_ws_response_t _Nullable response);
const char * _Nullable nw_ws_response_get_selected_subprotocol(nw_ws_response_t response);
void nw_ws_response_add_additional_header(nw_ws_response_t response, const char *name, const char *value);
bool nw_ws_response_enumerate_additional_headers(nw_ws_response_t response, nw_ws_additional_header_enumerator_t enumerator);

/* TXT records */
typedef enum { nw_txt_record_find_key_invalid = 0, nw_txt_record_find_key_not_present = 1, nw_txt_record_find_key_no_value = 2,
               nw_txt_record_find_key_empty_value = 3, nw_txt_record_find_key_non_empty_value = 4 } nw_txt_record_find_key_t;
typedef bool (^nw_txt_record_access_key_t)(const char *key, nw_txt_record_find_key_t found, const uint8_t * _Nullable value, size_t value_len);
typedef bool (^nw_txt_record_access_bytes_t)(const uint8_t *raw_txt_record, size_t len);
typedef bool (^nw_txt_record_applier_t)(const char *key, nw_txt_record_find_key_t found, const uint8_t *value, size_t value_len);
nw_txt_record_t nw_txt_record_create_with_bytes(const uint8_t *txt_bytes, size_t txt_len) NS_RETURNS_RETAINED;
nw_txt_record_t nw_txt_record_create_dictionary(void) NS_RETURNS_RETAINED;
nw_txt_record_t _Nullable nw_txt_record_copy(nw_txt_record_t _Nullable txt_record) NS_RETURNS_RETAINED;
nw_txt_record_find_key_t nw_txt_record_find_key(nw_txt_record_t txt_record, const char *key);
bool nw_txt_record_access_key(nw_txt_record_t txt_record, const char *key, nw_txt_record_access_key_t access_value);
bool nw_txt_record_set_key(nw_txt_record_t txt_record, const char *key, const uint8_t * _Nullable value, size_t value_len);
bool nw_txt_record_remove_key(nw_txt_record_t txt_record, const char *key);
size_t nw_txt_record_get_key_count(nw_txt_record_t _Nullable txt_record);
bool nw_txt_record_access_bytes(nw_txt_record_t txt_record, nw_txt_record_access_bytes_t access_bytes);
bool nw_txt_record_apply(nw_txt_record_t txt_record, nw_txt_record_applier_t applier);
bool nw_txt_record_is_equal(nw_txt_record_t _Nullable left, nw_txt_record_t _Nullable right);
bool nw_txt_record_is_dictionary(nw_txt_record_t txt_record);
nw_txt_record_t _Nullable nw_endpoint_copy_txt_record(nw_endpoint_t endpoint) NS_RETURNS_RETAINED;
const uint8_t * _Nullable nw_endpoint_get_signature(nw_endpoint_t endpoint, size_t *out_signature_length);
nw_txt_record_t _Nullable nw_advertise_descriptor_copy_txt_record_object(nw_advertise_descriptor_t advertise_descriptor) NS_RETURNS_RETAINED;
void nw_advertise_descriptor_set_txt_record_object(nw_advertise_descriptor_t advertise_descriptor, nw_txt_record_t _Nullable txt_record);
void nw_advertise_descriptor_set_no_auto_rename(nw_advertise_descriptor_t advertise_descriptor, bool no_auto_rename);
bool nw_advertise_descriptor_get_no_auto_rename(nw_advertise_descriptor_t advertise_descriptor);
nw_advertise_descriptor_t nw_advertise_descriptor_create_application_service(const char *application_service_name) NS_RETURNS_RETAINED;
const char * _Nullable nw_advertise_descriptor_get_application_service_name(nw_advertise_descriptor_t advertise_descriptor);
nw_browse_descriptor_t nw_browse_descriptor_create_application_service(const char *application_service_name) NS_RETURNS_RETAINED;
const char * _Nullable nw_browse_descriptor_get_application_service_name(nw_browse_descriptor_t descriptor);
nw_txt_record_t _Nullable nw_browse_result_copy_txt_record_object(nw_browse_result_t result) NS_RETURNS_RETAINED;

/* paths and parameters */
typedef enum { nw_path_unsatisfied_reason_not_available = 0, nw_path_unsatisfied_reason_cellular_denied = 1,
               nw_path_unsatisfied_reason_wifi_denied = 2, nw_path_unsatisfied_reason_local_network_denied = 3,
               nw_path_unsatisfied_reason_vpn_inactive = 4 } nw_path_unsatisfied_reason_t;
typedef enum __attribute__((enum_extensibility(open))) : uint8_t { nw_link_quality_unknown = 0, nw_link_quality_minimal = 10,
               nw_link_quality_moderate = 20, nw_link_quality_good = 30 } nw_link_quality_t;
typedef enum { nw_multipath_service_disabled = 0, nw_multipath_service_handover = 1, nw_multipath_service_interactive = 2,
               nw_multipath_service_aggregate = 3 } nw_multipath_service_t;
typedef enum { nw_parameters_expired_dns_behavior_default = 0, nw_parameters_expired_dns_behavior_allow = 1,
               nw_parameters_expired_dns_behavior_prohibit = 2, nw_parameters_expired_dns_behavior_persistent = 3 } nw_parameters_expired_dns_behavior_t;
typedef enum : uint8_t { nw_parameters_attribution_developer = 1, nw_parameters_attribution_user = 2 } nw_parameters_attribution_t;
typedef bool (^nw_path_enumerate_gateways_block_t)(nw_endpoint_t gateway);
nw_path_unsatisfied_reason_t nw_path_get_unsatisfied_reason(nw_path_t path);
bool nw_path_is_equal(nw_path_t path, nw_path_t other_path);
void nw_path_enumerate_gateways(nw_path_t path, nw_path_enumerate_gateways_block_t enumerate_block);
nw_link_quality_t nw_path_get_link_quality(nw_path_t path);
bool nw_path_is_ultra_constrained(nw_path_t path);
void nw_path_monitor_prohibit_interface_type(nw_path_monitor_t monitor, nw_interface_type_t interface_type);
nw_parameters_t nw_parameters_create_application_service(void) NS_RETURNS_RETAINED;
void nw_parameters_set_attribution(nw_parameters_t parameters, nw_parameters_attribution_t attribution);
nw_parameters_attribution_t nw_parameters_get_attribution(nw_parameters_t parameters);
void nw_parameters_set_requires_dnssec_validation(nw_parameters_t parameters, bool requires_dnssec_validation);
bool nw_parameters_requires_dnssec_validation(nw_parameters_t parameters);
void nw_parameters_set_allow_ultra_constrained(nw_parameters_t parameters, bool allow_ultra_constrained);
bool nw_parameters_get_allow_ultra_constrained(nw_parameters_t parameters);

/* establishment and data transfer reports */
typedef enum { nw_report_resolution_source_query = 1, nw_report_resolution_source_cache = 2,
               nw_report_resolution_source_expired_cache = 3 } nw_report_resolution_source_t;
typedef enum { nw_report_resolution_protocol_unknown = 0, nw_report_resolution_protocol_udp = 1, nw_report_resolution_protocol_tcp = 2,
               nw_report_resolution_protocol_tls = 3, nw_report_resolution_protocol_https = 4 } nw_report_resolution_protocol_t;
typedef enum { nw_data_transfer_report_state_collecting = 1, nw_data_transfer_report_state_collected = 2 } nw_data_transfer_report_state_t;
typedef enum { nw_interface_radio_type_unknown = 0, nw_interface_radio_type_wifi_b = 1, nw_interface_radio_type_wifi_a = 2,
               nw_interface_radio_type_wifi_g = 3, nw_interface_radio_type_wifi_n = 4, nw_interface_radio_type_wifi_ac = 5,
               nw_interface_radio_type_wifi_ax = 6, nw_interface_radio_type_cell_lte = 0x80, nw_interface_radio_type_cell_endc_sub6 = 0x81,
               nw_interface_radio_type_cell_endc_mmw = 0x82, nw_interface_radio_type_cell_nr_sa_sub6 = 0x83,
               nw_interface_radio_type_cell_nr_sa_mmw = 0x84, nw_interface_radio_type_cell_wcdma = 0x85,
               nw_interface_radio_type_cell_gsm = 0x86, nw_interface_radio_type_cell_cdma = 0x87,
               nw_interface_radio_type_cell_evdo = 0x88 } nw_interface_radio_type_t;
typedef void (^nw_establishment_report_access_block_t)(nw_establishment_report_t _Nullable report);
typedef bool (^nw_report_resolution_enumerator_t)(nw_report_resolution_source_t source, uint64_t milliseconds, uint32_t endpoint_count,
                                                  nw_endpoint_t successful_endpoint, nw_endpoint_t preferred_endpoint);
typedef bool (^nw_report_resolution_report_enumerator_t)(nw_resolution_report_t resolution_report);
typedef bool (^nw_report_protocol_enumerator_t)(nw_protocol_definition_t protocol, uint64_t handshake_milliseconds,
                                                uint64_t handshake_rtt_milliseconds);
typedef void (^nw_data_transfer_report_collect_block_t)(nw_data_transfer_report_t report);
#define NW_ALL_PATHS UINT32_MAX
void nw_connection_access_establishment_report(nw_connection_t connection, dispatch_queue_t queue, nw_establishment_report_access_block_t access_block);
uint64_t nw_establishment_report_get_duration_milliseconds(nw_establishment_report_t report);
uint64_t nw_establishment_report_get_attempt_started_after_milliseconds(nw_establishment_report_t report);
uint32_t nw_establishment_report_get_previous_attempt_count(nw_establishment_report_t report);
bool nw_establishment_report_get_used_proxy(nw_establishment_report_t report);
bool nw_establishment_report_get_proxy_configured(nw_establishment_report_t report);
nw_endpoint_t _Nullable nw_establishment_report_copy_proxy_endpoint(nw_establishment_report_t report) NS_RETURNS_RETAINED;
void nw_establishment_report_enumerate_resolutions(nw_establishment_report_t report, nw_report_resolution_enumerator_t enumerate_block);
void nw_establishment_report_enumerate_resolution_reports(nw_establishment_report_t report, nw_report_resolution_report_enumerator_t enumerate_block);
void nw_establishment_report_enumerate_protocols(nw_establishment_report_t report, nw_report_protocol_enumerator_t enumerate_block);
nw_report_resolution_source_t nw_resolution_report_get_source(nw_resolution_report_t resolution_report);
uint64_t nw_resolution_report_get_milliseconds(nw_resolution_report_t resolution_report);
uint32_t nw_resolution_report_get_endpoint_count(nw_resolution_report_t resolution_report);
nw_endpoint_t nw_resolution_report_copy_successful_endpoint(nw_resolution_report_t resolution_report) NS_RETURNS_RETAINED;
nw_endpoint_t nw_resolution_report_copy_preferred_endpoint(nw_resolution_report_t resolution_report) NS_RETURNS_RETAINED;
nw_report_resolution_protocol_t nw_resolution_report_get_protocol(nw_resolution_report_t resolution_report);
nw_data_transfer_report_t nw_connection_create_new_data_transfer_report(nw_connection_t connection) NS_RETURNS_RETAINED;
void nw_data_transfer_report_collect(nw_data_transfer_report_t report, dispatch_queue_t queue, nw_data_transfer_report_collect_block_t collect_block);
nw_data_transfer_report_state_t nw_data_transfer_report_get_state(nw_data_transfer_report_t report);
uint64_t nw_data_transfer_report_get_duration_milliseconds(nw_data_transfer_report_t report);
uint32_t nw_data_transfer_report_get_path_count(nw_data_transfer_report_t report);
nw_interface_t nw_data_transfer_report_copy_path_interface(nw_data_transfer_report_t report, uint32_t path_index) NS_RETURNS_RETAINED;
nw_interface_radio_type_t nw_data_transfer_report_get_path_radio_type(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_received_ip_packet_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_sent_ip_packet_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_received_transport_byte_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_received_transport_duplicate_byte_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_received_transport_out_of_order_byte_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_sent_transport_byte_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_sent_transport_retransmitted_byte_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_transport_minimum_rtt_milliseconds(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_transport_rtt_variance(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_received_application_byte_count(nw_data_transfer_report_t report, uint32_t path_index);
uint64_t nw_data_transfer_report_get_sent_application_byte_count(nw_data_transfer_report_t report, uint32_t path_index);

/* connection groups (UDP multicast) */
typedef enum { nw_connection_group_state_invalid = 0, nw_connection_group_state_waiting = 1, nw_connection_group_state_ready = 2,
               nw_connection_group_state_failed = 3, nw_connection_group_state_cancelled = 4 } nw_connection_group_state_t;
typedef enum { nw_ethernet_channel_state_invalid = 0, nw_ethernet_channel_state_waiting = 1, nw_ethernet_channel_state_preparing = 2,
               nw_ethernet_channel_state_ready = 3, nw_ethernet_channel_state_failed = 4, nw_ethernet_channel_state_cancelled = 5 } nw_ethernet_channel_state_t;
typedef bool (^nw_group_descriptor_enumerate_endpoints_block_t)(nw_endpoint_t endpoint);
typedef void (^nw_connection_group_state_changed_handler_t)(nw_connection_group_state_t state, nw_error_t _Nullable error);
typedef void (^nw_connection_group_receive_handler_t)(dispatch_data_t _Nullable content, nw_content_context_t context, bool is_complete);
typedef void (^nw_connection_group_new_connection_handler_t)(nw_connection_t connection);
typedef void (^nw_connection_group_send_completion_t)(nw_error_t _Nullable error);
typedef void (^nw_listener_new_connection_group_handler_t)(nw_connection_group_t group);
nw_group_descriptor_t nw_group_descriptor_create_multicast(nw_endpoint_t multicast_group) NS_RETURNS_RETAINED;
nw_group_descriptor_t nw_group_descriptor_create_multiplex(nw_endpoint_t remote_endpoint) NS_RETURNS_RETAINED;
bool nw_group_descriptor_add_endpoint(nw_group_descriptor_t descriptor, nw_endpoint_t endpoint);
void nw_group_descriptor_enumerate_endpoints(nw_group_descriptor_t descriptor, nw_group_descriptor_enumerate_endpoints_block_t enumerate_block);
void nw_multicast_group_descriptor_set_specific_source(nw_group_descriptor_t multicast_descriptor, nw_endpoint_t source);
void nw_multicast_group_descriptor_set_disable_unicast_traffic(nw_group_descriptor_t multicast_descriptor, bool disable_unicast_traffic);
bool nw_multicast_group_descriptor_get_disable_unicast_traffic(nw_group_descriptor_t multicast_descriptor);
nw_connection_group_t nw_connection_group_create(nw_group_descriptor_t group_descriptor, nw_parameters_t parameters) NS_RETURNS_RETAINED;
nw_group_descriptor_t nw_connection_group_copy_descriptor(nw_connection_group_t group) NS_RETURNS_RETAINED;
nw_parameters_t nw_connection_group_copy_parameters(nw_connection_group_t group) NS_RETURNS_RETAINED;
void nw_connection_group_set_queue(nw_connection_group_t group, dispatch_queue_t queue);
void nw_connection_group_set_state_changed_handler(nw_connection_group_t group, nw_connection_group_state_changed_handler_t _Nullable state_changed_handler);
void nw_connection_group_set_receive_handler(nw_connection_group_t group, uint32_t maximum_message_size, bool reject_oversized_messages,
                                             nw_connection_group_receive_handler_t _Nullable receive_handler);
void nw_connection_group_set_new_connection_handler(nw_connection_group_t group, nw_connection_group_new_connection_handler_t _Nullable new_connection_handler);
void nw_connection_group_start(nw_connection_group_t group);
void nw_connection_group_cancel(nw_connection_group_t group);
void nw_connection_group_send_message(nw_connection_group_t group, dispatch_data_t _Nullable content, nw_endpoint_t _Nullable endpoint,
                                      nw_content_context_t context, nw_connection_group_send_completion_t completion);
void nw_connection_group_reply(nw_connection_group_t group, nw_content_context_t inbound_message, nw_content_context_t outbound_message,
                               dispatch_data_t _Nullable content);
nw_endpoint_t _Nullable nw_connection_group_copy_remote_endpoint_for_message(nw_connection_group_t group, nw_content_context_t context) NS_RETURNS_RETAINED;
nw_endpoint_t _Nullable nw_connection_group_copy_local_endpoint_for_message(nw_connection_group_t group, nw_content_context_t context) NS_RETURNS_RETAINED;
nw_path_t _Nullable nw_connection_group_copy_path_for_message(nw_connection_group_t group, nw_content_context_t context) NS_RETURNS_RETAINED;
nw_protocol_metadata_t _Nullable nw_connection_group_copy_protocol_metadata(nw_connection_group_t group, nw_protocol_definition_t definition) NS_RETURNS_RETAINED;
nw_protocol_metadata_t _Nullable nw_connection_group_copy_protocol_metadata_for_message(nw_connection_group_t group, nw_content_context_t context,
                                                                                        nw_protocol_definition_t definition) NS_RETURNS_RETAINED;
nw_connection_t _Nullable nw_connection_group_extract_connection(nw_connection_group_t group, nw_endpoint_t _Nullable endpoint,
                                                                 nw_protocol_options_t _Nullable protocol_options) NS_RETURNS_RETAINED;
nw_connection_t _Nullable nw_connection_group_extract_connection_for_message(nw_connection_group_t group, nw_content_context_t context) NS_RETURNS_RETAINED;
bool nw_connection_group_reinsert_extracted_connection(nw_connection_group_t group, nw_connection_t connection);
void nw_listener_set_new_connection_group_handler(nw_listener_t listener, nw_listener_new_connection_group_handler_t _Nullable handler);
nw_listener_t _Nullable nw_listener_create_with_connection(nw_connection_t connection, nw_parameters_t parameters) NS_RETURNS_RETAINED;

/* framers: an app's own message protocol */
typedef enum { nw_framer_start_result_ready = 1, nw_framer_start_result_will_mark_ready = 2 } nw_framer_start_result_t;
#define NW_FRAMER_CREATE_FLAGS_DEFAULT 0x00
#define NW_FRAMER_WAKEUP_TIME_FOREVER UINT64_MAX
typedef nw_framer_start_result_t (^nw_framer_start_handler_t)(nw_framer_t framer);
typedef size_t (^nw_framer_input_handler_t)(nw_framer_t framer);
typedef void (^nw_framer_output_handler_t)(nw_framer_t framer, nw_framer_message_t message, size_t message_length, bool is_complete);
typedef void (^nw_framer_wakeup_handler_t)(nw_framer_t framer);
typedef bool (^nw_framer_stop_handler_t)(nw_framer_t framer);
typedef void (^nw_framer_cleanup_handler_t)(nw_framer_t framer);
typedef void (^nw_framer_block_t)(void);
typedef size_t (^nw_framer_parse_completion_t)(uint8_t * _Nullable buffer, size_t buffer_length, bool is_complete);
typedef void (^nw_framer_message_dispose_value_t)(void *value);
nw_protocol_definition_t nw_framer_create_definition(const char *identifier, uint32_t flags, nw_framer_start_handler_t start_handler) NS_RETURNS_RETAINED;
nw_protocol_options_t nw_framer_create_options(nw_protocol_definition_t framer_definition) NS_RETURNS_RETAINED;
nw_framer_message_t nw_framer_protocol_create_message(nw_protocol_definition_t definition) NS_RETURNS_RETAINED;
nw_framer_message_t nw_framer_message_create(nw_framer_t framer) NS_RETURNS_RETAINED;
void nw_framer_message_set_value(nw_framer_message_t message, const char *key, void * _Nullable value, nw_framer_message_dispose_value_t _Nullable dispose_value);
bool nw_framer_message_access_value(nw_framer_message_t message, const char *key, bool (^access_value)(const void * _Nullable value));
void nw_framer_message_set_object_value(nw_framer_message_t message, const char *key, id _Nullable value);
id _Nullable nw_framer_message_copy_object_value(nw_framer_message_t message, const char *key) NS_RETURNS_RETAINED;
void nw_framer_options_set_object_value(nw_protocol_options_t options, const char *key, id _Nullable value);
id _Nullable nw_framer_options_copy_object_value(nw_protocol_options_t options, const char *key) NS_RETURNS_RETAINED;
void nw_framer_set_input_handler(nw_framer_t framer, nw_framer_input_handler_t input_handler);
void nw_framer_set_output_handler(nw_framer_t framer, nw_framer_output_handler_t output_handler);
void nw_framer_set_wakeup_handler(nw_framer_t framer, nw_framer_wakeup_handler_t wakeup_handler);
void nw_framer_set_stop_handler(nw_framer_t framer, nw_framer_stop_handler_t stop_handler);
void nw_framer_set_cleanup_handler(nw_framer_t framer, nw_framer_cleanup_handler_t cleanup_handler);
void nw_framer_mark_ready(nw_framer_t framer);
bool nw_framer_prepend_application_protocol(nw_framer_t framer, nw_protocol_options_t protocol_options);
void nw_framer_mark_failed_with_error(nw_framer_t framer, int error_code);
bool nw_framer_parse_input(nw_framer_t framer, size_t minimum_incomplete_length, size_t maximum_length, uint8_t * _Nullable temp_buffer,
                           nw_framer_parse_completion_t parse);
void nw_framer_deliver_input(nw_framer_t framer, const uint8_t *input_buffer, size_t input_length, nw_framer_message_t message, bool is_complete);
bool nw_framer_deliver_input_no_copy(nw_framer_t framer, size_t input_length, nw_framer_message_t message, bool is_complete);
void nw_framer_pass_through_input(nw_framer_t framer);
bool nw_framer_parse_output(nw_framer_t framer, size_t minimum_incomplete_length, size_t maximum_length, uint8_t * _Nullable temp_buffer,
                            nw_framer_parse_completion_t parse);
void nw_framer_write_output(nw_framer_t framer, const uint8_t *output_buffer, size_t output_length);
void nw_framer_write_output_data(nw_framer_t framer, dispatch_data_t output_data);
bool nw_framer_write_output_no_copy(nw_framer_t framer, size_t output_length);
void nw_framer_pass_through_output(nw_framer_t framer);
void nw_framer_schedule_wakeup(nw_framer_t framer, uint64_t milliseconds);
void nw_framer_async(nw_framer_t framer, nw_framer_block_t async_block);
nw_endpoint_t nw_framer_copy_remote_endpoint(nw_framer_t framer) NS_RETURNS_RETAINED;
nw_endpoint_t nw_framer_copy_local_endpoint(nw_framer_t framer) NS_RETURNS_RETAINED;
nw_parameters_t nw_framer_copy_parameters(nw_framer_t framer) NS_RETURNS_RETAINED;
nw_protocol_options_t nw_framer_copy_options(nw_framer_t framer) NS_RETURNS_RETAINED;

/* proxy configurations (kept with a privacy context: isim's connections go direct) */
typedef void (^nw_proxy_domain_enumerator_t)(const char *domain);
nw_proxy_config_t nw_proxy_config_create_socksv5(nw_endpoint_t proxy_endpoint) NS_RETURNS_RETAINED;
nw_proxy_config_t nw_proxy_config_create_http_connect(nw_endpoint_t proxy_endpoint, nw_protocol_options_t _Nullable proxy_tls_options) NS_RETURNS_RETAINED;
void nw_proxy_config_add_match_domain(nw_proxy_config_t config, const char *match_domain);
void nw_proxy_config_clear_match_domains(nw_proxy_config_t config);
void nw_proxy_config_enumerate_match_domains(nw_proxy_config_t config, nw_proxy_domain_enumerator_t enumerator);
void nw_proxy_config_add_excluded_domain(nw_proxy_config_t config, const char *excluded_domain);
void nw_proxy_config_clear_excluded_domains(nw_proxy_config_t config);
void nw_proxy_config_enumerate_excluded_domains(nw_proxy_config_t config, nw_proxy_domain_enumerator_t enumerator);
__END_DECLS
NS_ASSUME_NONNULL_END
#endif
