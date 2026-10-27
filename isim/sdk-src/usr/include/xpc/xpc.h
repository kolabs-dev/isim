#pragma once
/* isim <xpc/xpc.h> (self-authored, Apple's API): XPC objects, connections, sessions, listeners and activities.
 * Adapted: a service is a Unix socket every process of the booted device can reach (isim's app, its extensions, other
 * apps); see Foundation's XPC.m. */
#include <xpc/base.h>

__BEGIN_DECLS
#pragma clang assume_nonnull begin

XPC_DECL(xpc_connection);
XPC_DECL(xpc_endpoint);
XPC_DECL(xpc_activity);
XPC_DECL(xpc_session);
XPC_DECL(xpc_rich_error);
XPC_DECL(xpc_listener);
XPC_DECL(xpc_peer_requirement);

typedef void (^xpc_handler_t)(xpc_object_t object);
typedef void (*xpc_finalizer_t)(void *value);
typedef void (*xpc_connection_handler_t)(xpc_connection_t connection);
typedef bool (^xpc_array_applier_t)(size_t index, xpc_object_t value);
typedef bool (^xpc_dictionary_applier_t)(const char *key, xpc_object_t value);

#define _XPC_TYPE(name) XPC_EXPORT const struct _xpc_type_s _xpc_type_##name
_XPC_TYPE(connection); _XPC_TYPE(endpoint); _XPC_TYPE(null); _XPC_TYPE(bool); _XPC_TYPE(int64); _XPC_TYPE(uint64);
_XPC_TYPE(double); _XPC_TYPE(date); _XPC_TYPE(data); _XPC_TYPE(string); _XPC_TYPE(uuid); _XPC_TYPE(fd); _XPC_TYPE(shmem);
_XPC_TYPE(array); _XPC_TYPE(dictionary); _XPC_TYPE(error); _XPC_TYPE(activity); _XPC_TYPE(session); _XPC_TYPE(rich_error);
_XPC_TYPE(listener);
#define XPC_TYPE_CONNECTION (&_xpc_type_connection)
#define XPC_TYPE_ENDPOINT (&_xpc_type_endpoint)
#define XPC_TYPE_NULL (&_xpc_type_null)
#define XPC_TYPE_BOOL (&_xpc_type_bool)
#define XPC_TYPE_INT64 (&_xpc_type_int64)
#define XPC_TYPE_UINT64 (&_xpc_type_uint64)
#define XPC_TYPE_DOUBLE (&_xpc_type_double)
#define XPC_TYPE_DATE (&_xpc_type_date)
#define XPC_TYPE_DATA (&_xpc_type_data)
#define XPC_TYPE_STRING (&_xpc_type_string)
#define XPC_TYPE_UUID (&_xpc_type_uuid)
#define XPC_TYPE_FD (&_xpc_type_fd)
#define XPC_TYPE_SHMEM (&_xpc_type_shmem)
#define XPC_TYPE_ARRAY (&_xpc_type_array)
#define XPC_TYPE_DICTIONARY (&_xpc_type_dictionary)
#define XPC_TYPE_ERROR (&_xpc_type_error)
#define XPC_TYPE_ACTIVITY (&_xpc_type_activity)
#define XPC_TYPE_SESSION (&_xpc_type_session)
#define XPC_TYPE_RICH_ERROR (&_xpc_type_rich_error)
#define XPC_TYPE_LISTENER (&_xpc_type_listener)

/* objects */
XPC_EXPORT xpc_object_t xpc_retain(xpc_object_t object);
XPC_EXPORT void xpc_release(xpc_object_t object);
XPC_EXPORT xpc_type_t xpc_get_type(xpc_object_t object);
XPC_EXPORT const char *xpc_type_get_name(xpc_type_t type);
XPC_EXPORT xpc_object_t _Nullable xpc_copy(xpc_object_t object) XPC_RETURNS_RETAINED;
XPC_EXPORT bool xpc_equal(xpc_object_t object1, xpc_object_t object2);
XPC_EXPORT size_t xpc_hash(xpc_object_t object);
XPC_EXPORT char *xpc_copy_description(xpc_object_t object);
XPC_EXPORT const char *_Nullable xpc_debugger_api_misuse_info(void);

XPC_EXPORT xpc_object_t xpc_null_create(void) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t xpc_bool_create(bool value) XPC_RETURNS_RETAINED;
XPC_EXPORT bool xpc_bool_get_value(xpc_object_t xbool);
XPC_EXPORT struct _xpc_bool_s _xpc_bool_true;
XPC_EXPORT struct _xpc_bool_s _xpc_bool_false;
#if defined(__OBJC__) || defined(__swift__)
#define XPC_BOOL_TRUE ((__bridge xpc_object_t)(void *)&_xpc_bool_true)
#define XPC_BOOL_FALSE ((__bridge xpc_object_t)(void *)&_xpc_bool_false)
#else
#define XPC_BOOL_TRUE ((xpc_object_t)(void *)&_xpc_bool_true)
#define XPC_BOOL_FALSE ((xpc_object_t)(void *)&_xpc_bool_false)
#endif
XPC_EXPORT xpc_object_t xpc_int64_create(int64_t value) XPC_RETURNS_RETAINED;
XPC_EXPORT int64_t xpc_int64_get_value(xpc_object_t xint);
XPC_EXPORT xpc_object_t xpc_uint64_create(uint64_t value) XPC_RETURNS_RETAINED;
XPC_EXPORT uint64_t xpc_uint64_get_value(xpc_object_t xuint);
XPC_EXPORT xpc_object_t xpc_double_create(double value) XPC_RETURNS_RETAINED;
XPC_EXPORT double xpc_double_get_value(xpc_object_t xdouble);
XPC_EXPORT xpc_object_t xpc_date_create(int64_t interval) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t xpc_date_create_from_current(void) XPC_RETURNS_RETAINED;
XPC_EXPORT int64_t xpc_date_get_value(xpc_object_t xdate);
XPC_EXPORT xpc_object_t xpc_data_create(const void *_Nullable bytes, size_t length) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t xpc_data_create_with_dispatch_data(dispatch_data_t ddata) XPC_RETURNS_RETAINED;
XPC_EXPORT size_t xpc_data_get_length(xpc_object_t xdata);
XPC_EXPORT const void *_Nullable xpc_data_get_bytes_ptr(xpc_object_t xdata);
XPC_EXPORT size_t xpc_data_get_bytes(xpc_object_t xdata, void *buffer, size_t off, size_t length);
XPC_EXPORT xpc_object_t xpc_string_create(const char *string) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t xpc_string_create_with_format(const char *fmt, ...) XPC_RETURNS_RETAINED __attribute__((format(printf, 1, 2)));
XPC_EXPORT xpc_object_t xpc_string_create_with_format_and_arguments(const char *fmt, va_list ap) XPC_RETURNS_RETAINED;
XPC_EXPORT size_t xpc_string_get_length(xpc_object_t xstring);
XPC_EXPORT const char *_Nullable xpc_string_get_string_ptr(xpc_object_t xstring);
XPC_EXPORT xpc_object_t xpc_uuid_create(const uuid_t uuid) XPC_RETURNS_RETAINED;
XPC_EXPORT const uint8_t *_Nullable xpc_uuid_get_bytes(xpc_object_t xuuid);
XPC_EXPORT xpc_object_t _Nullable xpc_fd_create(int fd) XPC_RETURNS_RETAINED;
XPC_EXPORT int xpc_fd_dup(xpc_object_t xfd);
XPC_EXPORT xpc_object_t xpc_shmem_create(void *region, size_t length) XPC_RETURNS_RETAINED;
XPC_EXPORT size_t xpc_shmem_map(xpc_object_t xshmem, void *_Nullable *_Nonnull region);

/* arrays */
#define XPC_ARRAY_APPEND ((size_t)(-1))
XPC_EXPORT xpc_object_t xpc_array_create(const xpc_object_t _Nonnull *_Nullable objects, size_t count) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t xpc_array_create_empty(void) XPC_RETURNS_RETAINED;
XPC_EXPORT void xpc_array_set_value(xpc_object_t xarray, size_t index, xpc_object_t value);
XPC_EXPORT void xpc_array_append_value(xpc_object_t xarray, xpc_object_t value);
XPC_EXPORT size_t xpc_array_get_count(xpc_object_t xarray);
XPC_EXPORT xpc_object_t xpc_array_get_value(xpc_object_t xarray, size_t index);
XPC_EXPORT bool xpc_array_apply(xpc_object_t xarray, xpc_array_applier_t applier);
XPC_EXPORT void xpc_array_set_bool(xpc_object_t xarray, size_t index, bool value);
XPC_EXPORT void xpc_array_set_int64(xpc_object_t xarray, size_t index, int64_t value);
XPC_EXPORT void xpc_array_set_uint64(xpc_object_t xarray, size_t index, uint64_t value);
XPC_EXPORT void xpc_array_set_double(xpc_object_t xarray, size_t index, double value);
XPC_EXPORT void xpc_array_set_date(xpc_object_t xarray, size_t index, int64_t value);
XPC_EXPORT void xpc_array_set_data(xpc_object_t xarray, size_t index, const void *_Nullable bytes, size_t length);
XPC_EXPORT void xpc_array_set_string(xpc_object_t xarray, size_t index, const char *string);
XPC_EXPORT void xpc_array_set_uuid(xpc_object_t xarray, size_t index, const uuid_t _Nonnull uuid);
XPC_EXPORT void xpc_array_set_fd(xpc_object_t xarray, size_t index, int fd);
XPC_EXPORT void xpc_array_set_connection(xpc_object_t xarray, size_t index, xpc_connection_t connection);
XPC_EXPORT bool xpc_array_get_bool(xpc_object_t xarray, size_t index);
XPC_EXPORT int64_t xpc_array_get_int64(xpc_object_t xarray, size_t index);
XPC_EXPORT uint64_t xpc_array_get_uint64(xpc_object_t xarray, size_t index);
XPC_EXPORT double xpc_array_get_double(xpc_object_t xarray, size_t index);
XPC_EXPORT int64_t xpc_array_get_date(xpc_object_t xarray, size_t index);
XPC_EXPORT const void *_Nullable xpc_array_get_data(xpc_object_t xarray, size_t index, size_t *_Nullable length);
XPC_EXPORT const char *_Nullable xpc_array_get_string(xpc_object_t xarray, size_t index);
XPC_EXPORT const uint8_t *_Nullable xpc_array_get_uuid(xpc_object_t xarray, size_t index);
XPC_EXPORT int xpc_array_dup_fd(xpc_object_t xarray, size_t index);
XPC_EXPORT xpc_connection_t _Nullable xpc_array_create_connection(xpc_object_t xarray, size_t index) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t _Nullable xpc_array_get_dictionary(xpc_object_t xarray, size_t index);
XPC_EXPORT xpc_object_t _Nullable xpc_array_get_array(xpc_object_t xarray, size_t index);

/* dictionaries */
XPC_EXPORT xpc_object_t xpc_dictionary_create(const char *const _Nonnull *_Nullable keys, const xpc_object_t _Nullable *_Nullable values,
                                              size_t count) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t xpc_dictionary_create_empty(void) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t _Nullable xpc_dictionary_create_reply(xpc_object_t original) XPC_RETURNS_RETAINED;
XPC_EXPORT void xpc_dictionary_set_value(xpc_object_t xdict, const char *key, xpc_object_t _Nullable value);
XPC_EXPORT xpc_object_t _Nullable xpc_dictionary_get_value(xpc_object_t xdict, const char *key);
XPC_EXPORT size_t xpc_dictionary_get_count(xpc_object_t xdict);
XPC_EXPORT bool xpc_dictionary_apply(xpc_object_t xdict, xpc_dictionary_applier_t applier);
XPC_EXPORT xpc_connection_t _Nullable xpc_dictionary_get_remote_connection(xpc_object_t xdict);
XPC_EXPORT void xpc_dictionary_set_bool(xpc_object_t xdict, const char *key, bool value);
XPC_EXPORT void xpc_dictionary_set_int64(xpc_object_t xdict, const char *key, int64_t value);
XPC_EXPORT void xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);
XPC_EXPORT void xpc_dictionary_set_double(xpc_object_t xdict, const char *key, double value);
XPC_EXPORT void xpc_dictionary_set_date(xpc_object_t xdict, const char *key, int64_t value);
XPC_EXPORT void xpc_dictionary_set_data(xpc_object_t xdict, const char *key, const void *_Nullable bytes, size_t length);
XPC_EXPORT void xpc_dictionary_set_string(xpc_object_t xdict, const char *key, const char *string);
XPC_EXPORT void xpc_dictionary_set_uuid(xpc_object_t xdict, const char *key, const uuid_t _Nonnull uuid);
XPC_EXPORT void xpc_dictionary_set_fd(xpc_object_t xdict, const char *key, int fd);
XPC_EXPORT void xpc_dictionary_set_connection(xpc_object_t xdict, const char *key, xpc_connection_t connection);
XPC_EXPORT bool xpc_dictionary_get_bool(xpc_object_t xdict, const char *key);
XPC_EXPORT int64_t xpc_dictionary_get_int64(xpc_object_t xdict, const char *key);
XPC_EXPORT uint64_t xpc_dictionary_get_uint64(xpc_object_t xdict, const char *key);
XPC_EXPORT double xpc_dictionary_get_double(xpc_object_t xdict, const char *key);
XPC_EXPORT int64_t xpc_dictionary_get_date(xpc_object_t xdict, const char *key);
XPC_EXPORT const void *_Nullable xpc_dictionary_get_data(xpc_object_t xdict, const char *key, size_t *_Nullable length);
XPC_EXPORT const char *_Nullable xpc_dictionary_get_string(xpc_object_t xdict, const char *key);
XPC_EXPORT const uint8_t *_Nullable xpc_dictionary_get_uuid(xpc_object_t xdict, const char *key);
XPC_EXPORT int xpc_dictionary_dup_fd(xpc_object_t xdict, const char *key);
XPC_EXPORT xpc_connection_t _Nullable xpc_dictionary_create_connection(xpc_object_t xdict, const char *key) XPC_RETURNS_RETAINED;
XPC_EXPORT xpc_object_t _Nullable xpc_dictionary_get_dictionary(xpc_object_t xdict, const char *key);
XPC_EXPORT xpc_object_t _Nullable xpc_dictionary_get_array(xpc_object_t xdict, const char *key);

/* errors */
XPC_EXPORT struct _xpc_dictionary_s _xpc_error_connection_interrupted;
XPC_EXPORT struct _xpc_dictionary_s _xpc_error_connection_invalid;
XPC_EXPORT struct _xpc_dictionary_s _xpc_error_termination_imminent;
XPC_EXPORT struct _xpc_dictionary_s _xpc_error_peer_code_signing_requirement;
#if defined(__OBJC__) || defined(__swift__)
#define _XPC_ERROR(e) ((__bridge xpc_object_t)(void *)&(e))
#else
#define _XPC_ERROR(e) ((xpc_object_t)(void *)&(e))
#endif
#define XPC_ERROR_CONNECTION_INTERRUPTED _XPC_ERROR(_xpc_error_connection_interrupted)
#define XPC_ERROR_CONNECTION_INVALID _XPC_ERROR(_xpc_error_connection_invalid)
#define XPC_ERROR_TERMINATION_IMMINENT _XPC_ERROR(_xpc_error_termination_imminent)
#define XPC_ERROR_PEER_CODE_SIGNING_REQUIREMENT _XPC_ERROR(_xpc_error_peer_code_signing_requirement)
XPC_EXPORT const char *const XPC_ERROR_KEY_DESCRIPTION;
XPC_EXPORT const char *const XPC_EVENT_KEY_NAME;

/* isim: the constant objects for Swift (its XPC overlay's XPC_TYPE_*, XPC_BOOL_*, XPC_ERROR_*) */
XPC_EXPORT xpc_type_t _Nullable _isim_xpc_type(const char *name);
XPC_EXPORT xpc_object_t _Nullable _isim_xpc_constant(const char *name);
/* isim: for the Swift overlay's XPCReceivedMessage: does a received message expect a reply (sent synchronously), and
 * reply to it with the contents of a dictionary (on the connection or session it came in on) */
XPC_EXPORT bool _isim_xpc_message_expects_reply(xpc_object_t message);
XPC_EXPORT bool _isim_xpc_message_is_sync(xpc_object_t message);
XPC_EXPORT bool _isim_xpc_reply(xpc_object_t message, xpc_object_t contents);

/* event streams, services, transactions */
XPC_EXPORT void xpc_set_event_stream_handler(const char *stream, dispatch_queue_t _Nullable targetq, xpc_handler_t handler);
XPC_EXPORT void xpc_main(xpc_connection_handler_t handler) __attribute__((noreturn));
XPC_EXPORT void xpc_transaction_begin(void);
XPC_EXPORT void xpc_transaction_end(void);

#pragma clang assume_nonnull end
__END_DECLS

#include <xpc/connection.h>
#include <xpc/activity.h>
#include <xpc/rich_error.h>
#include <xpc/session.h>
#include <xpc/listener.h>
