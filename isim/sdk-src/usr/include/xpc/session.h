#pragma once
/* isim <xpc/session.h> (self-authored, Apple's API): sessions to a named service (an extension's, an app's: on isim
 * every process of the booted device can reach it). */
#include <xpc/base.h>

__BEGIN_DECLS
#pragma clang assume_nonnull begin

typedef enum __attribute__((flag_enum, enum_extensibility(open))) : uint64_t {
    XPC_SESSION_CREATE_NONE __attribute__((swift_name("none"))) = 0,
    XPC_SESSION_CREATE_INACTIVE __attribute__((swift_name("inactive"))) = 1 << 0,
    XPC_SESSION_CREATE_MACH_PRIVILEGED __attribute__((swift_name("privileged"))) = 1 << 1,
} xpc_session_create_flags_t;
typedef void (^xpc_session_cancel_handler_t)(xpc_rich_error_t error);
typedef void (^xpc_session_incoming_message_handler_t)(xpc_object_t message);
typedef void (^xpc_session_reply_handler_t)(xpc_object_t _Nullable reply, xpc_rich_error_t _Nullable error);

XPC_EXPORT xpc_session_t _Nullable xpc_session_create_xpc_service(const char *name, dispatch_queue_t _Nullable target_queue,
    xpc_session_create_flags_t flags, xpc_rich_error_t _Nullable *_Nullable error_out) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_session_t _Nullable xpc_session_create_mach_service(const char *mach_service, dispatch_queue_t _Nullable target_queue,
    xpc_session_create_flags_t flags, xpc_rich_error_t _Nullable *_Nullable error_out) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_session_t _Nullable _xpc_session_create_endpoint(xpc_endpoint_t endpoint, dispatch_queue_t _Nullable target_queue,
    xpc_session_create_flags_t flags, xpc_rich_error_t _Nullable *_Nullable error_out) XPC_RETURNS_RETAINED;
XPC_EXPORT void xpc_session_set_target_queue(xpc_session_t session, dispatch_queue_t _Nullable target_queue);
XPC_EXPORT void xpc_session_set_cancel_handler(xpc_session_t session, xpc_session_cancel_handler_t cancel_handler);
XPC_EXPORT void xpc_session_set_incoming_message_handler(xpc_session_t session, xpc_session_incoming_message_handler_t handler);
XPC_EXPORT bool xpc_session_activate(xpc_session_t session, xpc_rich_error_t _Nullable *_Nullable error_out);
XPC_EXPORT void xpc_session_cancel(xpc_session_t session);
XPC_EXPORT char *_Nullable xpc_session_copy_description(xpc_session_t session);
XPC_EXPORT xpc_rich_error_t _Nullable xpc_session_send_message(xpc_session_t session, xpc_object_t message);
XPC_EXPORT xpc_object_t _Nullable xpc_session_send_message_with_reply_sync(xpc_session_t session, xpc_object_t message,
    xpc_rich_error_t _Nullable *_Nullable error_out) XPC_RETURNS_RETAINED;
XPC_EXPORT void xpc_session_send_message_with_reply_async(xpc_session_t session, xpc_object_t message, xpc_session_reply_handler_t reply_handler);
XPC_EXPORT int xpc_session_set_peer_code_signing_requirement(xpc_session_t session, const char *requirement);

#pragma clang assume_nonnull end
__END_DECLS
