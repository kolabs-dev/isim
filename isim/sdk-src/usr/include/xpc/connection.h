#pragma once
/* isim <xpc/connection.h> (self-authored, Apple's API): connections to a named service or an endpoint; a listener
 * connection (XPC_CONNECTION_MACH_SERVICE_LISTENER) receives its peers' connections. */
#include <xpc/base.h>

__BEGIN_DECLS
#pragma clang assume_nonnull begin

#define XPC_CONNECTION_MACH_SERVICE_LISTENER (1 << 0)
#define XPC_CONNECTION_MACH_SERVICE_PRIVILEGED (1 << 1)

XPC_EXPORT xpc_connection_t xpc_connection_create(const char *_Nullable name, dispatch_queue_t _Nullable targetq) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_connection_t xpc_connection_create_mach_service(const char *name, dispatch_queue_t _Nullable targetq, uint64_t flags) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_connection_t xpc_connection_create_from_endpoint(xpc_endpoint_t endpoint) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_endpoint_t xpc_endpoint_create(xpc_connection_t connection) XPC_RETURNS_RETAINED;
XPC_EXPORT void xpc_connection_set_target_queue(xpc_connection_t connection, dispatch_queue_t _Nullable targetq);
XPC_EXPORT void xpc_connection_set_event_handler(xpc_connection_t connection, xpc_handler_t handler);
XPC_EXPORT void xpc_connection_activate(xpc_connection_t connection);
XPC_EXPORT void xpc_connection_suspend(xpc_connection_t connection);
XPC_EXPORT void xpc_connection_resume(xpc_connection_t connection);
XPC_EXPORT void xpc_connection_cancel(xpc_connection_t connection);
XPC_EXPORT void xpc_connection_send_message(xpc_connection_t connection, xpc_object_t message);
XPC_EXPORT void xpc_connection_send_barrier(xpc_connection_t connection, dispatch_block_t barrier);
XPC_EXPORT void xpc_connection_send_message_with_reply(xpc_connection_t connection, xpc_object_t message,
                                                       dispatch_queue_t _Nullable replyq, xpc_handler_t handler);
XPC_EXPORT xpc_object_t xpc_connection_send_message_with_reply_sync(xpc_connection_t connection, xpc_object_t message) XPC_RETURNS_RETAINED;
XPC_EXPORT const char *_Nullable xpc_connection_get_name(xpc_connection_t connection);
XPC_EXPORT uid_t xpc_connection_get_euid(xpc_connection_t connection);
XPC_EXPORT gid_t xpc_connection_get_egid(xpc_connection_t connection);
XPC_EXPORT pid_t xpc_connection_get_pid(xpc_connection_t connection);
XPC_EXPORT au_asid_t xpc_connection_get_asid(xpc_connection_t connection);
XPC_EXPORT void xpc_connection_set_context(xpc_connection_t connection, void *_Nullable context);
XPC_EXPORT void *_Nullable xpc_connection_get_context(xpc_connection_t connection);
XPC_EXPORT void xpc_connection_set_finalizer_f(xpc_connection_t connection, xpc_finalizer_t _Nullable finalizer);
XPC_EXPORT char *_Nullable xpc_connection_copy_invalidation_reason(xpc_connection_t connection);
XPC_EXPORT int xpc_connection_set_peer_code_signing_requirement(xpc_connection_t connection, const char *requirement);
XPC_EXPORT int xpc_connection_set_peer_entitlement_exists_requirement(xpc_connection_t connection, const char *entitlement);
XPC_EXPORT int xpc_connection_set_peer_entitlement_matches_value_requirement(xpc_connection_t connection, const char *entitlement,
                                                                             xpc_object_t value);
XPC_EXPORT int xpc_connection_set_peer_team_identity_requirement(xpc_connection_t connection, const char *_Nullable signing_identifier);
XPC_EXPORT int xpc_connection_set_peer_platform_identity_requirement(xpc_connection_t connection, const char *_Nullable signing_identifier);
XPC_EXPORT int xpc_connection_set_peer_lightweight_code_requirement(xpc_connection_t connection, xpc_object_t lwcr);

#pragma clang assume_nonnull end
__END_DECLS
