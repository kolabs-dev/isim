// os_log from Objective-C: the os_log macros (clang's __builtin_os_log_format) with privacy specifiers.
// Called from main.swift; test_security.py checks the stderr lines.
#import <Foundation/Foundation.h>
#include <os/log.h>

void isim_test_c_os_log(void) {
    os_log_t log = os_log_create("dev.isim.test", "objc");
    os_log(log, "objc %d %s %{public}s %@ %{public}@ %.2f %x", 42, "secret", "shown", @"hidden-object", @"public-object", 2.5, 255u);
    os_log_error(log, "objc error %{public}s %ld", "boom", 7L);
    os_log_debug(OS_LOG_DEFAULT, "objc default log %{private}d", 9);
    os_log_info(OS_LOG_DISABLED, "never printed");
}
