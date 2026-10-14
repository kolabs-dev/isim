#pragma once
/* isim Network for C and Objective-C: the path monitor (nw_path_monitor_*, nw_path_*, nw_interface_*), from the Network
   Swift overlay's NWPathMonitor (Network.framework re-exports libswiftNetwork.dylib): the host's connectivity. The
   objects are Objective-C objects (ARC retains them). Swift uses the overlay; these declarations are hidden from Swift.
   Not available from C yet: connections, listeners, parameters and endpoints (use the Swift API or NSURLSession). */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS
typedef NSObject *nw_path_monitor_t, *nw_path_t, *nw_interface_t;
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
const char *nw_interface_get_name(nw_interface_t interface);
uint32_t nw_interface_get_index(nw_interface_t interface);
__END_DECLS
NS_ASSUME_NONNULL_END
#endif
