#pragma once
/* isim Network for C and Objective-C: endpoints, parameters, connections, listeners, Bonjour browsing and the path
   monitor, over the Network Swift overlay's NWConnection, NWListener, NWBrowser and NWPathMonitor (Network.framework
   re-exports libswiftNetwork.dylib): TCP, UDP and TLS on the host's sockets and OpenSSL, Bonjour over isim's local
   registry and multicast DNS. The objects are Objective-C objects (ARC retains them; nw_retain / nw_release in C).
   Swift uses the overlay; these declarations are hidden from Swift. Not available from C yet: sec_protocol_options
   (TLS uses the host's CA store and checks the host name), protocol stacks and metadata, framers, WebSocket options,
   connection groups and ethernet channels. */
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
__END_DECLS
NS_ASSUME_NONNULL_END
#endif
