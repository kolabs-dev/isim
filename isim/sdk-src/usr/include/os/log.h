#pragma once
/* isim SDK (self-authored): unified logging. C/Objective-C: os_log_create and the os_log macros, which pack their
 * arguments with clang's __builtin_os_log_format (privacy: %{public}@, %{private}s, ...) for isim's libSystem; lines
 * go to stderr like Swift's Logger. In Swift, `import os` / `import os.log` provide Logger, OSLog, os_log and
 * OSSignposter (isim's Swift os module). */
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stdint.h>
__BEGIN_DECLS
typedef struct os_log_s *os_log_t;
typedef uint8_t os_log_type_t;
enum {
    OS_LOG_TYPE_DEFAULT = 0x00,
    OS_LOG_TYPE_INFO = 0x01,
    OS_LOG_TYPE_DEBUG = 0x02,
    OS_LOG_TYPE_ERROR = 0x10,
    OS_LOG_TYPE_FAULT = 0x11,
};
extern struct os_log_s _os_log_default;
extern struct os_log_s _os_log_disabled;
#define OS_LOG_DEFAULT (&_os_log_default)
#define OS_LOG_DISABLED (&_os_log_disabled)
os_log_t os_log_create(const char *subsystem, const char *category);
bool os_log_type_enabled(os_log_t log, os_log_type_t type);
void _os_log_impl(void *dso, os_log_t log, os_log_type_t type, const char *format, uint8_t *buf, uint32_t size);

#if defined(__clang__) && !defined(__swift__)
extern void *__dso_handle;
#define os_log_with_type(log, type, format, ...) __extension__({                                                   \
    os_log_t _isim_log = (log); os_log_type_t _isim_type = (type);                                                 \
    if (os_log_type_enabled(_isim_log, _isim_type)) {                                                               \
        __attribute__((aligned(16))) uint8_t _isim_buf[__builtin_os_log_format_buffer_size(format, ##__VA_ARGS__)];   \
        _os_log_impl(&__dso_handle, _isim_log, _isim_type, format,                                                  \
                     (uint8_t *)__builtin_os_log_format(_isim_buf, format, ##__VA_ARGS__), (uint32_t)sizeof(_isim_buf)); \
    } })
#define os_log(log, format, ...) os_log_with_type(log, OS_LOG_TYPE_DEFAULT, format, ##__VA_ARGS__)
#define os_log_info(log, format, ...) os_log_with_type(log, OS_LOG_TYPE_INFO, format, ##__VA_ARGS__)
#define os_log_debug(log, format, ...) os_log_with_type(log, OS_LOG_TYPE_DEBUG, format, ##__VA_ARGS__)
#define os_log_error(log, format, ...) os_log_with_type(log, OS_LOG_TYPE_ERROR, format, ##__VA_ARGS__)
#define os_log_fault(log, format, ...) os_log_with_type(log, OS_LOG_TYPE_FAULT, format, ##__VA_ARGS__)
#endif
__END_DECLS
