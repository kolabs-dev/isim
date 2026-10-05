#pragma once
/* isim: minimal libdispatch subset implemented in Foundation. Only the main queue is
 * serviced (by the UIKit run loop); global queues run work on new threads. */
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stddef.h>
#ifndef FOUNDATION_EXPORT
#define FOUNDATION_EXPORT extern __attribute__((visibility("default")))
#endif
#ifndef NS_NOESCAPE
#define NS_NOESCAPE __attribute__((noescape))
#endif
#include <stdint.h>
__BEGIN_DECLS
typedef struct dispatch_queue_s *dispatch_queue_t;
typedef uint64_t dispatch_time_t;
typedef long dispatch_once_t;
#ifdef __BLOCKS__
typedef void (^dispatch_block_t)(void);
#endif
typedef void (*dispatch_function_t)(void *);
#define DISPATCH_TIME_NOW (0ull)
#define DISPATCH_TIME_FOREVER (~0ull)
#define NSEC_PER_SEC 1000000000ull
#define NSEC_PER_MSEC 1000000ull
#define USEC_PER_SEC 1000000ull
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
#define DISPATCH_QUEUE_SERIAL NULL
FOUNDATION_EXPORT struct dispatch_queue_s _dispatch_main_q;
#define dispatch_get_main_queue() (&_dispatch_main_q)
FOUNDATION_EXPORT dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
FOUNDATION_EXPORT dispatch_queue_t dispatch_queue_create(const char *label, void *attr);
FOUNDATION_EXPORT void dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t work);
FOUNDATION_EXPORT void dispatch_once_f(dispatch_once_t *predicate, void *context, dispatch_function_t function);
#ifdef __BLOCKS__
FOUNDATION_EXPORT void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_sync(dispatch_queue_t queue, NS_NOESCAPE dispatch_block_t block);
FOUNDATION_EXPORT void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
FOUNDATION_EXPORT dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta);
FOUNDATION_EXPORT void dispatch_once(dispatch_once_t *predicate, NS_NOESCAPE dispatch_block_t block);
#endif
__END_DECLS
