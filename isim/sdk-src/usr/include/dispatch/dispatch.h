#pragma once
/* isim libdispatch subset (implemented in Foundation, Dispatch.mrc.m and DispatchIO.mrc.m; self-authored header).
 * Queues: main (serviced by the main run loop / dispatch_main), global concurrent (a worker
 * pool), serial (drained on the pool). Timers and other sources, semaphores, groups, queue-specific
 * data, dispatch_data and dispatch_io. Dispatch objects are plain C objects here (not Objective-C objects as on Apple). */
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <time.h>
#include <fcntl.h>
#include <sys/types.h>
#ifndef FOUNDATION_EXPORT
#define FOUNDATION_EXPORT extern __attribute__((visibility("default")))
#endif
#ifndef NS_NOESCAPE
#define NS_NOESCAPE __attribute__((noescape))
#endif
#define DISPATCH_EXPORT FOUNDATION_EXPORT
__BEGIN_DECLS
typedef struct dispatch_queue_s *dispatch_queue_t;
typedef struct dispatch_queue_s *dispatch_queue_global_t;
typedef struct dispatch_queue_s *dispatch_queue_serial_t;
typedef struct dispatch_queue_s *dispatch_queue_main_t;
typedef struct dispatch_queue_s *dispatch_queue_concurrent_t;
typedef struct dispatch_queue_attr_s *dispatch_queue_attr_t;
typedef struct dispatch_source_s *dispatch_source_t;
typedef struct dispatch_group_s *dispatch_group_t;
typedef struct dispatch_semaphore_s *dispatch_semaphore_t;
typedef const struct dispatch_source_type_s *dispatch_source_type_t;
typedef struct dispatch_data_s *dispatch_data_t;
typedef struct dispatch_io_s *dispatch_io_t;
typedef void *dispatch_object_t;
typedef uint64_t dispatch_time_t;
typedef long dispatch_once_t;
typedef unsigned int dispatch_qos_class_t;
#ifdef __BLOCKS__
typedef void (^dispatch_block_t)(void);
#endif
typedef void (*dispatch_function_t)(void *);

#define DISPATCH_TIME_NOW (0ull)
#define DISPATCH_TIME_FOREVER (~0ull)
#define DISPATCH_WALLTIME_NOW (~1ull)
#define NSEC_PER_SEC 1000000000ull
#define NSEC_PER_MSEC 1000000ull
#define NSEC_PER_USEC 1000ull
#define USEC_PER_SEC 1000000ull
#define DISPATCH_QUEUE_PRIORITY_HIGH 2
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
#define DISPATCH_QUEUE_PRIORITY_LOW (-2)
#define DISPATCH_QUEUE_PRIORITY_BACKGROUND (-32768)
#define DISPATCH_QUEUE_SERIAL NULL
FOUNDATION_EXPORT struct dispatch_queue_attr_s _dispatch_queue_attr_concurrent;
#define DISPATCH_QUEUE_CONCURRENT (&_dispatch_queue_attr_concurrent)
#define DISPATCH_TARGET_QUEUE_DEFAULT NULL

#include <sys/qos.h>

FOUNDATION_EXPORT struct dispatch_queue_s _dispatch_main_q;
#define dispatch_get_main_queue() (&_dispatch_main_q)
FOUNDATION_EXPORT dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
FOUNDATION_EXPORT dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);
FOUNDATION_EXPORT dispatch_queue_t dispatch_queue_create_with_target(const char *label, dispatch_queue_attr_t attr, dispatch_queue_t target);
FOUNDATION_EXPORT dispatch_queue_attr_t dispatch_queue_attr_make_with_qos_class(dispatch_queue_attr_t attr, dispatch_qos_class_t qos, int relative_priority);
FOUNDATION_EXPORT const char *dispatch_queue_get_label(dispatch_queue_t queue);
FOUNDATION_EXPORT void dispatch_set_target_queue(dispatch_object_t object, dispatch_queue_t queue);
FOUNDATION_EXPORT void dispatch_queue_set_specific(dispatch_queue_t queue, const void *key, void *context, dispatch_function_t destructor);
FOUNDATION_EXPORT void *dispatch_queue_get_specific(dispatch_queue_t queue, const void *key);
FOUNDATION_EXPORT void *dispatch_get_specific(const void *key);
FOUNDATION_EXPORT void dispatch_assert_queue(dispatch_queue_t queue);
FOUNDATION_EXPORT void dispatch_assert_queue_not(dispatch_queue_t queue);
FOUNDATION_EXPORT void dispatch_main(void) __attribute__((noreturn));

FOUNDATION_EXPORT void dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_sync_f(dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_barrier_async_f(dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_barrier_sync_f(dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_after_f(dispatch_time_t when, dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_apply_f(size_t iterations, dispatch_queue_t queue, void *context, void (*work)(void *, size_t));
FOUNDATION_EXPORT void dispatch_once_f(dispatch_once_t *predicate, void *context, dispatch_function_t function);
FOUNDATION_EXPORT dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta);
FOUNDATION_EXPORT dispatch_time_t dispatch_walltime(const struct timespec *when, int64_t delta);

/* objects */
FOUNDATION_EXPORT void dispatch_retain(dispatch_object_t object);
FOUNDATION_EXPORT void dispatch_release(dispatch_object_t object);
FOUNDATION_EXPORT void *dispatch_get_context(dispatch_object_t object);
FOUNDATION_EXPORT void dispatch_set_context(dispatch_object_t object, void *context);
FOUNDATION_EXPORT void dispatch_set_finalizer_f(dispatch_object_t object, dispatch_function_t finalizer);
FOUNDATION_EXPORT void dispatch_activate(dispatch_object_t object);
FOUNDATION_EXPORT void dispatch_suspend(dispatch_object_t object);
FOUNDATION_EXPORT void dispatch_resume(dispatch_object_t object);

/* sources: timers, user data (add/or/replace), read/write (fd readiness), signals, processes (exit, fork, exec),
 * vnodes (file changes), memory pressure (the Simulator's memory warning), Mach send (dead name) and receive (isim's
 * in-process ports) */
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_timer;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_data_add;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_data_or;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_data_replace;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_read;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_write;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_signal;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_proc;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_vnode;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_memorypressure;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_mach_send;
FOUNDATION_EXPORT const struct dispatch_source_type_s _dispatch_source_type_mach_recv;
#define DISPATCH_SOURCE_TYPE_TIMER (&_dispatch_source_type_timer)
#define DISPATCH_SOURCE_TYPE_DATA_ADD (&_dispatch_source_type_data_add)
#define DISPATCH_SOURCE_TYPE_DATA_OR (&_dispatch_source_type_data_or)
#define DISPATCH_SOURCE_TYPE_DATA_REPLACE (&_dispatch_source_type_data_replace)
#define DISPATCH_SOURCE_TYPE_READ (&_dispatch_source_type_read)
#define DISPATCH_SOURCE_TYPE_WRITE (&_dispatch_source_type_write)
#define DISPATCH_SOURCE_TYPE_SIGNAL (&_dispatch_source_type_signal)
#define DISPATCH_SOURCE_TYPE_PROC (&_dispatch_source_type_proc)
#define DISPATCH_SOURCE_TYPE_VNODE (&_dispatch_source_type_vnode)
#define DISPATCH_SOURCE_TYPE_MEMORYPRESSURE (&_dispatch_source_type_memorypressure)
#define DISPATCH_SOURCE_TYPE_MACH_SEND (&_dispatch_source_type_mach_send)
#define DISPATCH_SOURCE_TYPE_MACH_RECV (&_dispatch_source_type_mach_recv)
#define DISPATCH_TIMER_STRICT 0x1
#define DISPATCH_PROC_EXIT 0x80000000UL
#define DISPATCH_PROC_FORK 0x40000000UL
#define DISPATCH_PROC_EXEC 0x20000000UL
#define DISPATCH_PROC_SIGNAL 0x08000000UL
#define DISPATCH_VNODE_DELETE 0x1
#define DISPATCH_VNODE_WRITE 0x2
#define DISPATCH_VNODE_EXTEND 0x4
#define DISPATCH_VNODE_ATTRIB 0x8
#define DISPATCH_VNODE_LINK 0x10
#define DISPATCH_VNODE_RENAME 0x20
#define DISPATCH_VNODE_REVOKE 0x40
#define DISPATCH_VNODE_FUNLOCK 0x100
#define DISPATCH_MEMORYPRESSURE_NORMAL 0x01
#define DISPATCH_MEMORYPRESSURE_WARN 0x02
#define DISPATCH_MEMORYPRESSURE_CRITICAL 0x04
#define DISPATCH_MACH_SEND_DEAD 0x1
#define DISPATCH_MACH_SEND_POSSIBLE 0x2
FOUNDATION_EXPORT void dispatch_source_merge_data(dispatch_source_t source, uintptr_t value);
FOUNDATION_EXPORT uintptr_t dispatch_source_get_handle(dispatch_source_t source);
FOUNDATION_EXPORT uintptr_t dispatch_source_get_mask(dispatch_source_t source);
FOUNDATION_EXPORT void dispatch_source_set_registration_handler_f(dispatch_source_t source, dispatch_function_t handler);
FOUNDATION_EXPORT dispatch_source_t dispatch_source_create(dispatch_source_type_t type, uintptr_t handle, uintptr_t mask, dispatch_queue_t queue);
FOUNDATION_EXPORT void dispatch_source_set_timer(dispatch_source_t source, dispatch_time_t start, uint64_t interval, uint64_t leeway);
FOUNDATION_EXPORT void dispatch_source_set_event_handler_f(dispatch_source_t source, dispatch_function_t handler);
FOUNDATION_EXPORT void dispatch_source_set_cancel_handler_f(dispatch_source_t source, dispatch_function_t handler);
FOUNDATION_EXPORT void dispatch_source_cancel(dispatch_source_t source);
FOUNDATION_EXPORT long dispatch_source_testcancel(dispatch_source_t source);
FOUNDATION_EXPORT uintptr_t dispatch_source_get_data(dispatch_source_t source);

/* semaphores & groups */
FOUNDATION_EXPORT dispatch_semaphore_t dispatch_semaphore_create(long value);
FOUNDATION_EXPORT long dispatch_semaphore_wait(dispatch_semaphore_t dsema, dispatch_time_t timeout);
FOUNDATION_EXPORT long dispatch_semaphore_signal(dispatch_semaphore_t dsema);
FOUNDATION_EXPORT dispatch_group_t dispatch_group_create(void);
FOUNDATION_EXPORT void dispatch_group_enter(dispatch_group_t group);
FOUNDATION_EXPORT void dispatch_group_leave(dispatch_group_t group);
FOUNDATION_EXPORT long dispatch_group_wait(dispatch_group_t group, dispatch_time_t timeout);
FOUNDATION_EXPORT void dispatch_group_async_f(dispatch_group_t group, dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_group_notify_f(dispatch_group_t group, dispatch_queue_t queue, void *context, dispatch_function_t work);

#ifdef __BLOCKS__
FOUNDATION_EXPORT void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_sync(dispatch_queue_t queue, NS_NOESCAPE dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_barrier_sync(dispatch_queue_t queue, NS_NOESCAPE dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_apply(size_t iterations, dispatch_queue_t queue, NS_NOESCAPE void (^block)(size_t));
FOUNDATION_EXPORT void dispatch_once(dispatch_once_t *predicate, NS_NOESCAPE dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler);
FOUNDATION_EXPORT void dispatch_source_set_cancel_handler(dispatch_source_t source, dispatch_block_t handler);
FOUNDATION_EXPORT void dispatch_source_set_registration_handler(dispatch_source_t source, dispatch_block_t handler);
FOUNDATION_EXPORT void dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
#endif

/* data: immutable byte regions (dispatch_data_t), retained / released like other dispatch objects */
FOUNDATION_EXPORT struct dispatch_data_s _dispatch_data_empty;
#define dispatch_data_empty (&_dispatch_data_empty)
#ifdef __BLOCKS__
FOUNDATION_EXPORT const dispatch_block_t _dispatch_data_destructor_free;
FOUNDATION_EXPORT const dispatch_block_t _dispatch_data_destructor_munmap;
#define DISPATCH_DATA_DESTRUCTOR_DEFAULT NULL
#define DISPATCH_DATA_DESTRUCTOR_FREE (_dispatch_data_destructor_free)
#define DISPATCH_DATA_DESTRUCTOR_MUNMAP (_dispatch_data_destructor_munmap)
FOUNDATION_EXPORT dispatch_data_t dispatch_data_create(const void *buffer, size_t size, dispatch_queue_t queue, dispatch_block_t destructor);
typedef bool (^dispatch_data_applier_t)(dispatch_data_t region, size_t offset, const void *buffer, size_t size);
FOUNDATION_EXPORT bool dispatch_data_apply(dispatch_data_t data, NS_NOESCAPE dispatch_data_applier_t applier);
#endif
typedef bool (*dispatch_data_applier_function_t)(void *context, dispatch_data_t region, size_t offset, const void *buffer, size_t size);
FOUNDATION_EXPORT bool dispatch_data_apply_f(dispatch_data_t data, void *context, dispatch_data_applier_function_t applier);
FOUNDATION_EXPORT size_t dispatch_data_get_size(dispatch_data_t data);
FOUNDATION_EXPORT dispatch_data_t dispatch_data_create_map(dispatch_data_t data, const void **buffer_ptr, size_t *size_ptr);
FOUNDATION_EXPORT dispatch_data_t dispatch_data_create_concat(dispatch_data_t data1, dispatch_data_t data2);
FOUNDATION_EXPORT dispatch_data_t dispatch_data_create_subrange(dispatch_data_t data, size_t offset, size_t length);
FOUNDATION_EXPORT dispatch_data_t dispatch_data_copy_region(dispatch_data_t data, size_t location, size_t *offset_ptr);

/* I/O channels: stream or random-access reads and writes on a file descriptor, run on the channel's own queue */
typedef int dispatch_fd_t;
typedef unsigned long dispatch_io_type_t;
typedef unsigned long dispatch_io_close_flags_t;
typedef unsigned long dispatch_io_interval_flags_t;
#define DISPATCH_IO_STREAM 0
#define DISPATCH_IO_RANDOM 1
#define DISPATCH_IO_STOP 0x1
#define DISPATCH_IO_STRICT_INTERVAL 0x1
#ifdef __BLOCKS__
typedef void (^dispatch_io_handler_t)(bool done, dispatch_data_t data, int error);
FOUNDATION_EXPORT dispatch_io_t dispatch_io_create(dispatch_io_type_t type, dispatch_fd_t fd, dispatch_queue_t queue, void (^cleanup_handler)(int error));
FOUNDATION_EXPORT dispatch_io_t dispatch_io_create_with_path(dispatch_io_type_t type, const char *path, int oflag, mode_t mode,
                                                             dispatch_queue_t queue, void (^cleanup_handler)(int error));
FOUNDATION_EXPORT dispatch_io_t dispatch_io_create_with_io(dispatch_io_type_t type, dispatch_io_t io, dispatch_queue_t queue,
                                                           void (^cleanup_handler)(int error));
FOUNDATION_EXPORT void dispatch_io_read(dispatch_io_t channel, off_t offset, size_t length, dispatch_queue_t queue, dispatch_io_handler_t io_handler);
FOUNDATION_EXPORT void dispatch_io_write(dispatch_io_t channel, off_t offset, dispatch_data_t data, dispatch_queue_t queue, dispatch_io_handler_t io_handler);
FOUNDATION_EXPORT void dispatch_io_barrier(dispatch_io_t channel, dispatch_block_t barrier);
FOUNDATION_EXPORT void dispatch_read(dispatch_fd_t fd, size_t length, dispatch_queue_t queue, void (^handler)(dispatch_data_t data, int error));
FOUNDATION_EXPORT void dispatch_write(dispatch_fd_t fd, dispatch_data_t data, dispatch_queue_t queue, void (^handler)(dispatch_data_t data, int error));
#endif
typedef void (*dispatch_io_handler_function_t)(void *context, bool done, dispatch_data_t data, int error);
FOUNDATION_EXPORT dispatch_io_t dispatch_io_create_f(dispatch_io_type_t type, dispatch_fd_t fd, dispatch_queue_t queue, void *context,
                                                     void (*cleanup_handler)(void *context, int error));
FOUNDATION_EXPORT dispatch_io_t dispatch_io_create_with_path_f(dispatch_io_type_t type, const char *path, int oflag, mode_t mode,
                                                               dispatch_queue_t queue, void *context, void (*cleanup_handler)(void *context, int error));
FOUNDATION_EXPORT dispatch_io_t dispatch_io_create_with_io_f(dispatch_io_type_t type, dispatch_io_t io, dispatch_queue_t queue, void *context,
                                                             void (*cleanup_handler)(void *context, int error));
FOUNDATION_EXPORT void dispatch_io_read_f(dispatch_io_t channel, off_t offset, size_t length, dispatch_queue_t queue, void *context,
                                          dispatch_io_handler_function_t io_handler);
FOUNDATION_EXPORT void dispatch_io_write_f(dispatch_io_t channel, off_t offset, dispatch_data_t data, dispatch_queue_t queue, void *context,
                                           dispatch_io_handler_function_t io_handler);
FOUNDATION_EXPORT void dispatch_io_barrier_f(dispatch_io_t channel, void *context, dispatch_function_t barrier);
FOUNDATION_EXPORT void dispatch_read_f(dispatch_fd_t fd, size_t length, dispatch_queue_t queue, void *context,
                                       void (*handler)(void *context, dispatch_data_t data, int error));
FOUNDATION_EXPORT void dispatch_write_f(dispatch_fd_t fd, dispatch_data_t data, dispatch_queue_t queue, void *context,
                                        void (*handler)(void *context, dispatch_data_t data, int error));
FOUNDATION_EXPORT void dispatch_io_close(dispatch_io_t channel, dispatch_io_close_flags_t flags);
FOUNDATION_EXPORT dispatch_fd_t dispatch_io_get_descriptor(dispatch_io_t channel);
FOUNDATION_EXPORT void dispatch_io_set_high_water(dispatch_io_t channel, size_t high_water);
FOUNDATION_EXPORT void dispatch_io_set_low_water(dispatch_io_t channel, size_t low_water);
FOUNDATION_EXPORT void dispatch_io_set_interval(dispatch_io_t channel, uint64_t interval, dispatch_io_interval_flags_t flags);

/* isim: accessors for macro-only values, used by the Swift Dispatch overlay */
static inline dispatch_queue_t _isim_dispatch_main_queue(void) { return &_dispatch_main_q; }
static inline dispatch_queue_attr_t _isim_dispatch_concurrent_attr(void) { return DISPATCH_QUEUE_CONCURRENT; }
static inline dispatch_source_type_t _isim_dispatch_timer_type(void) { return DISPATCH_SOURCE_TYPE_TIMER; }
static inline dispatch_data_t _isim_dispatch_data_empty(void) { return dispatch_data_empty; }
static inline int _isim_dispatch_open(const char *path, int oflag, unsigned short mode) { return open(path, oflag, (int)mode); }
static inline dispatch_source_type_t _isim_dispatch_source_type(int kind) {
    switch (kind) {
    case 1: return DISPATCH_SOURCE_TYPE_DATA_ADD;
    case 2: return DISPATCH_SOURCE_TYPE_DATA_OR;
    case 3: return DISPATCH_SOURCE_TYPE_DATA_REPLACE;
    case 4: return DISPATCH_SOURCE_TYPE_READ;
    case 5: return DISPATCH_SOURCE_TYPE_WRITE;
    case 6: return DISPATCH_SOURCE_TYPE_SIGNAL;
    case 7: return DISPATCH_SOURCE_TYPE_PROC;
    case 8: return DISPATCH_SOURCE_TYPE_VNODE;
    case 9: return DISPATCH_SOURCE_TYPE_MEMORYPRESSURE;
    case 10: return DISPATCH_SOURCE_TYPE_MACH_SEND;
    case 11: return DISPATCH_SOURCE_TYPE_MACH_RECV;
    default: return DISPATCH_SOURCE_TYPE_TIMER;
    }
}
__END_DECLS
