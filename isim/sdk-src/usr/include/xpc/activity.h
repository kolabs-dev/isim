#pragma once
/* isim <xpc/activity.h> (self-authored, Apple's API): background activities. Adapted: an activity runs in its process
 * after its delay (and again every interval when repeating), whatever the device's battery or sleep. */
#include <xpc/base.h>

__BEGIN_DECLS
#pragma clang assume_nonnull begin

typedef long xpc_activity_state_t;
enum {
    XPC_ACTIVITY_STATE_CHECK_IN = 0, XPC_ACTIVITY_STATE_WAIT = 1, XPC_ACTIVITY_STATE_RUN = 2, XPC_ACTIVITY_STATE_DEFER = 3,
    XPC_ACTIVITY_STATE_CONTINUE = 4, XPC_ACTIVITY_STATE_DONE = 5,
};
typedef void (^xpc_activity_handler_t)(xpc_activity_t activity);
XPC_EXPORT struct _xpc_dictionary_s _xpc_activity_check_in;
#if defined(__OBJC__) || defined(__swift__)
#define XPC_ACTIVITY_CHECK_IN ((__bridge xpc_object_t)(void *)&_xpc_activity_check_in)
#else
#define XPC_ACTIVITY_CHECK_IN ((xpc_object_t)(void *)&_xpc_activity_check_in)
#endif
XPC_EXPORT const char *const XPC_ACTIVITY_INTERVAL;
XPC_EXPORT const char *const XPC_ACTIVITY_REPEATING;
XPC_EXPORT const char *const XPC_ACTIVITY_DELAY;
XPC_EXPORT const char *const XPC_ACTIVITY_GRACE_PERIOD;
XPC_EXPORT const char *const XPC_ACTIVITY_PRIORITY;
XPC_EXPORT const char *const XPC_ACTIVITY_PRIORITY_MAINTENANCE;
XPC_EXPORT const char *const XPC_ACTIVITY_PRIORITY_UTILITY;
XPC_EXPORT const char *const XPC_ACTIVITY_ALLOW_BATTERY;
XPC_EXPORT const char *const XPC_ACTIVITY_REQUIRE_SCREEN_SLEEP;
XPC_EXPORT const char *const XPC_ACTIVITY_PREVENT_DEVICE_SLEEP;
XPC_EXPORT const char *const XPC_ACTIVITY_REQUIRE_BATTERY_LEVEL;
XPC_EXPORT const char *const XPC_ACTIVITY_REQUIRE_HDD_SPINNING;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_1_MIN;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_5_MIN;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_15_MIN;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_30_MIN;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_1_HOUR;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_4_HOURS;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_8_HOURS;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_1_DAY;
XPC_EXPORT const int64_t XPC_ACTIVITY_INTERVAL_7_DAYS;

XPC_EXPORT void xpc_activity_register(const char *identifier, xpc_object_t criteria, xpc_activity_handler_t handler);
XPC_EXPORT void xpc_activity_unregister(const char *identifier);
XPC_EXPORT xpc_object_t _Nullable xpc_activity_copy_criteria(xpc_activity_t activity) XPC_RETURNS_RETAINED;
XPC_EXPORT void xpc_activity_set_criteria(xpc_activity_t activity, xpc_object_t criteria);
XPC_EXPORT xpc_activity_state_t xpc_activity_get_state(xpc_activity_t activity);
XPC_EXPORT bool xpc_activity_set_state(xpc_activity_t activity, xpc_activity_state_t state);
XPC_EXPORT bool xpc_activity_should_defer(xpc_activity_t activity);

#pragma clang assume_nonnull end
__END_DECLS
