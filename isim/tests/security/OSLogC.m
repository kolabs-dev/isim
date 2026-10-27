// os_log from Objective-C: the os_log macros (clang's __builtin_os_log_format) with privacy specifiers.
// Called from main.swift; test_security.py checks the stderr lines.
#import <Foundation/Foundation.h>
#include <os/log.h>
#include <os/activity.h>
#include <os/proc.h>

void isim_test_c_os_log(void) {
    os_log_t log = os_log_create("dev.isim.test", "objc");
    os_log(log, "objc %d %s %{public}s %@ %{public}@ %.2f %x", 42, "secret", "shown", @"hidden-object", @"public-object", 2.5, 255u);
    os_log_error(log, "objc error %{public}s %ld", "boom", 7L);
    os_log_debug(OS_LOG_DEFAULT, "objc default log %{private}d", 9);
    os_log_info(OS_LOG_DISABLED, "never printed");
}

/* issue #353: activities (create, scope enter / leave, apply, identifiers) and os_proc_available_memory; the number of
   checks that failed */
int isim_test_c_os_activity(void) {
    int failed = 0;
    os_activity_t outer = os_activity_create("isim outer activity", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT);
    os_activity_t inner = os_activity_create("isim inner activity", outer, OS_ACTIVITY_FLAG_DEFAULT);
    os_activity_id_t parent = 0;
    os_activity_id_t innerID = os_activity_get_identifier(inner, &parent);
    if (!outer || !inner || innerID == 0 || parent != os_activity_get_identifier(outer, NULL)) failed++;
    struct os_activity_scope_state_s state;
    os_activity_scope_enter(inner, &state);
    os_log(OS_LOG_DEFAULT, "inside the inner activity");
    os_activity_scope_leave(&state);
    __block int ran = 0;
    os_activity_apply(outer, ^{ ran++; });
    os_activity_initiate("isim initiated activity", OS_ACTIVITY_FLAG_DETACHED, ^{ ran++; });
    if (ran != 2) failed++;
    size_t avail = os_proc_available_memory();
    if (avail == 0 || avail > NSProcessInfo.processInfo.physicalMemory) failed++;
    if (OS_TRACE_TYPE_DEBUG != 4 || !OS_LOG_TARGET_HAS_10_15_FEATURES) failed++;
    return failed;
}
