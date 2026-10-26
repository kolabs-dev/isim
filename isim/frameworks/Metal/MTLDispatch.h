/* isim Metal: a compute dispatch, run on the worker threads (MTLDispatch.c; recorded by MTLCommand.m) */
#pragma once
#include <isim_metal_abi.h>
#include <stddef.h>

typedef struct isim_mtl_dispatch {
    const __isim_mtl_function *fn;
    void (*prepare)(const __isim_mtl_args *);       /* the library's __isim_mtl_prepare */
    __isim_mtl_args args;                           /* bindings; tgmem, barrier and sched are each worker's */
    uint32_t groups[3];                             /* threadgroups per grid */
    uint32_t group_size[3];                         /* threads per threadgroup */
    uint32_t grid[3];                               /* threads per grid (dispatchThreads: the edge groups are smaller) */
    size_t tgmem_length[ISIM_MTL_MAX_TGMEM];        /* setThreadgroupMemoryLength */
} isim_mtl_dispatch;
/* runs every threadgroup of d; returns when they are done */
void isim_mtl_run(const isim_mtl_dispatch *d);
int isim_mtl_worker_count(void);
