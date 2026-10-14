/* isim libdispatch internals shared by Dispatch.mrc.m (queues, sources, groups) and DispatchIO.mrc.m (dispatch_data,
 * dispatch_io). Every dispatch object starts with a dobj; static objects have refs >= 1 << 29 (never freed).
 * As on Apple platforms, dispatch objects are Objective-C objects (isa: an OS_dispatch_* class whose -retain/-release
 * are dispatch_retain/dispatch_release), so code compiled with ARC against Apple's SDK (where dispatch_queue_t is an
 * Objective-C type) can retain, release and autorelease them. */
#pragma once
#include <dispatch/dispatch.h>

enum { K_QUEUE = 1, K_SOURCE, K_GROUP, K_SEMA, K_ATTR, K_DATA, K_IO };
typedef struct { const void *isa; int kind; int refs; void *ctx; dispatch_function_t finalizer; } dobj;
extern char OBJC_CLASS_$_OS_dispatch_queue[], OBJC_CLASS_$_OS_dispatch_source[], OBJC_CLASS_$_OS_dispatch_group[],
    OBJC_CLASS_$_OS_dispatch_semaphore[], OBJC_CLASS_$_OS_dispatch_queue_attr[], OBJC_CLASS_$_OS_dispatch_data[],
    OBJC_CLASS_$_OS_dispatch_io[];
/* a dobj initializer: DOBJ(queue, K_QUEUE, 1) */
#define DOBJ(cls, kind, refs) { OBJC_CLASS_$_OS_dispatch_##cls, kind, refs, NULL, NULL }

void isim_dispatch_data_dispose(dispatch_data_t data);   /* DispatchIO.mrc.m: last release */
void isim_dispatch_io_dispose(dispatch_io_t channel);
