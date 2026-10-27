#pragma once
/* isim <xpc/listener.h> (self-authored, Apple's API): a listener for a named service, or anonymous (reached through
 * its endpoint); each incoming session is handed to the handler, which accepts it (the default) or rejects it. */
#include <xpc/base.h>

__BEGIN_DECLS
#pragma clang assume_nonnull begin

typedef enum __attribute__((flag_enum, enum_extensibility(open))) : uint64_t {
    XPC_LISTENER_CREATE_NONE __attribute__((swift_name("none"))) = 0,
    XPC_LISTENER_CREATE_INACTIVE __attribute__((swift_name("inactive"))) = 1 << 0,
} xpc_listener_create_flags_t;
typedef void (^xpc_listener_incoming_session_handler_t)(xpc_session_t peer);

XPC_EXPORT xpc_listener_t _Nullable xpc_listener_create(const char *_Nullable service, dispatch_queue_t _Nullable target_queue,
    xpc_listener_create_flags_t flags, xpc_listener_incoming_session_handler_t incoming_session_handler,
    xpc_rich_error_t _Nullable *_Nullable error_out) XPC_RETURNS_RETAINED;
XPC_EXPORT bool xpc_listener_activate(xpc_listener_t listener, xpc_rich_error_t _Nullable *_Nullable error_out);
XPC_EXPORT void xpc_listener_cancel(xpc_listener_t listener);
XPC_EXPORT void xpc_listener_reject_peer(xpc_session_t peer, const char *reason);
XPC_EXPORT xpc_endpoint_t xpc_listener_copy_endpoint(xpc_listener_t listener) XPC_RETURNS_RETAINED;
XPC_EXPORT char *_Nullable xpc_listener_copy_description(xpc_listener_t listener);
XPC_EXPORT int xpc_listener_set_peer_code_signing_requirement(xpc_listener_t listener, const char *requirement);

#pragma clang assume_nonnull end
__END_DECLS
