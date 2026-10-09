/* isim libdispatch internals shared by Dispatch.mrc.m (queues, sources, groups) and DispatchIO.mrc.m (dispatch_data,
 * dispatch_io). Every dispatch object starts with a dobj; static objects have refs >= 1 << 29 (never freed). */
#pragma once
#include <dispatch/dispatch.h>

enum { K_QUEUE = 1, K_SOURCE, K_GROUP, K_SEMA, K_ATTR, K_DATA, K_IO };
typedef struct { int kind; int refs; void *ctx; dispatch_function_t finalizer; } dobj;

void isim_dispatch_data_dispose(dispatch_data_t data);   /* DispatchIO.mrc.m: last release */
void isim_dispatch_io_dispose(dispatch_io_t channel);
