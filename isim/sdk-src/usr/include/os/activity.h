#pragma once
/* isim SDK (self-authored, Apple's declarations): activity tracing. isim keeps each thread's current activity and its
 * identifiers (adapted: activities are not shown in `isim log`). */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <os/object.h>
__BEGIN_DECLS
typedef struct os_activity_s *os_activity_t;   /* a C object in isim's runtime (host_os.c), also in Objective-C */
typedef uint64_t os_activity_id_t;
typedef struct os_activity_scope_state_s { uint64_t opaque[2]; } *os_activity_scope_state_t;
typedef enum __attribute__((flag_enum)) : uint32_t {
    OS_ACTIVITY_FLAG_DEFAULT = 0,
    OS_ACTIVITY_FLAG_DETACHED = 0x1,
    OS_ACTIVITY_FLAG_IF_NONE_PRESENT = 0x2,
} os_activity_flag_t;
extern struct os_activity_s _os_activity_none, _os_activity_current;
#define OS_ACTIVITY_NONE (&_os_activity_none)
#define OS_ACTIVITY_CURRENT (&_os_activity_current)
extern void *__dso_handle;
os_activity_t _os_activity_create(void *dso, const char *description, os_activity_t parent, os_activity_flag_t flags);
#define os_activity_create(description, parent, flags) _os_activity_create(&__dso_handle, "" description, parent, flags)
void os_activity_scope_enter(os_activity_t activity, os_activity_scope_state_t state);
void os_activity_scope_leave(os_activity_scope_state_t state);
#if defined(__clang__)
static inline void _os_activity_scope_cleanup(struct os_activity_scope_state_s *s) { os_activity_scope_leave(s); }
#define os_activity_scope(activity)                                                                                 \
    struct os_activity_scope_state_s __attribute__((cleanup(_os_activity_scope_cleanup))) _os_activity_scope_state; \
    os_activity_scope_enter(activity, &_os_activity_scope_state)
#endif
#ifdef __BLOCKS__
void os_activity_apply(os_activity_t activity, void (^block)(void));
void _os_activity_initiate(void *dso, const char *description, os_activity_flag_t flags, void (^block)(void));
#define os_activity_initiate(description, flags, block) _os_activity_initiate(&__dso_handle, "" description, flags, block)
#endif
void os_activity_apply_f(os_activity_t activity, void *context, void (*function)(void *context));
void _os_activity_initiate_f(void *dso, const char *description, os_activity_flag_t flags, void *context, void (*function)(void *context));
#define os_activity_initiate_f(description, flags, context, function) \
    _os_activity_initiate_f(&__dso_handle, "" description, flags, context, function)
os_activity_id_t os_activity_get_identifier(os_activity_t activity, os_activity_id_t *parent_id);
void _os_activity_label_useraction(void *dso, const char *name);
#define os_activity_label_useraction(label) _os_activity_label_useraction(&__dso_handle, "" label)
__END_DECLS
