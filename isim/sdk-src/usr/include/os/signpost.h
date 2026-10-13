#pragma once
/* isim SDK (self-authored): signposts. C/Objective-C: os_signpost_id_generate, os_signpost_enabled and the
 * os_signpost_event_emit / os_signpost_interval_begin / os_signpost_interval_end macros (an optional format and
 * arguments, packed like os_log). isim records them in the process's log store (OSLogStore reads them back as
 * OSLogEntrySignpost); ISIM_LOG_SIGNPOSTS=1 also prints them. In Swift, `import os.signpost` provides OSSignposter
 * and os_signpost (isim's Swift os module). */
#include <os/log.h>
__BEGIN_DECLS
typedef uint64_t os_signpost_id_t;
#define OS_SIGNPOST_ID_NULL ((os_signpost_id_t)0)
#define OS_SIGNPOST_ID_INVALID ((os_signpost_id_t)~0)
#define OS_SIGNPOST_ID_EXCLUSIVE ((os_signpost_id_t)0xEEEEB0B5B2B2EEEE)
typedef uint8_t os_signpost_type_t;
enum {
    OS_SIGNPOST_EVENT = 0x00,
    OS_SIGNPOST_INTERVAL_BEGIN = 0x01,
    OS_SIGNPOST_INTERVAL_END = 0x02,
};
os_signpost_id_t os_signpost_id_generate(os_log_t log);
os_signpost_id_t os_signpost_id_make_with_pointer(os_log_t log, const void *ptr);
bool os_signpost_enabled(os_log_t log);
void _os_signpost_emit_with_name_impl(void *dso, os_log_t log, os_signpost_type_t type, os_signpost_id_t spid,
                                      const char *name, const char *format, uint8_t *buf, uint32_t size);

#if defined(__clang__) && !defined(__swift__)
extern void *__dso_handle;
/* the format is optional: "" __VA_ARGS__ is "" alone, or the format literal with "" in front (and its arguments) */
#define _ISIM_SP_FIRST(f, ...) f
#define os_signpost_emit_with_type(log, type, spid, name, ...) __extension__({                                      \
    os_log_t _isim_sp_log = (log);                                                                                  \
    if (os_signpost_enabled(_isim_sp_log)) {                                                                        \
        __attribute__((aligned(16))) uint8_t _isim_sp_buf[__builtin_os_log_format_buffer_size("" __VA_ARGS__)];     \
        _os_signpost_emit_with_name_impl(&__dso_handle, _isim_sp_log, (type), (spid), (name), _ISIM_SP_FIRST("" __VA_ARGS__, 0), \
            (uint8_t *)__builtin_os_log_format(_isim_sp_buf, "" __VA_ARGS__), (uint32_t)sizeof(_isim_sp_buf));           \
    } })
#define os_signpost_event_emit(log, spid, name, ...) os_signpost_emit_with_type(log, OS_SIGNPOST_EVENT, spid, name, ##__VA_ARGS__)
#define os_signpost_interval_begin(log, spid, name, ...) os_signpost_emit_with_type(log, OS_SIGNPOST_INTERVAL_BEGIN, spid, name, ##__VA_ARGS__)
#define os_signpost_interval_end(log, spid, name, ...) os_signpost_emit_with_type(log, OS_SIGNPOST_INTERVAL_END, spid, name, ##__VA_ARGS__)
#define os_signpost_animation_interval_begin(log, spid, name, ...) os_signpost_interval_begin(log, spid, name, ##__VA_ARGS__)
#endif
__END_DECLS
