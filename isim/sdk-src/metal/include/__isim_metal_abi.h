#pragma once
/* isim Metal on the CPU: the interface between Metal.framework (frameworks/Metal) and a library of kernels compiled
 * from Metal Shading Language by isim's translator (tools/mslc.py) and clang. Plain C, shared by both sides. */
#include <stdint.h>

#define ISIM_MTL_ABI 1
#define ISIM_MTL_MAX_BUFFERS 31
#define ISIM_MTL_MAX_TEXTURES 128
#define ISIM_MTL_MAX_SAMPLERS 16
#define ISIM_MTL_MAX_TGMEM 31
#define ISIM_MTL_MAX_LEVELS 16

/* a texture's storage, as kernels see it: mip level i of slice s starts at levels[i] + s * level_bpi[i] */
typedef struct __isim_mtl_texture {
    uint32_t type;                          /* MTLTextureType */
    uint32_t format;                        /* MTLPixelFormat */
    uint32_t width, height, depth;          /* level 0 */
    uint32_t array_length, mip_levels;
    uint8_t *levels[ISIM_MTL_MAX_LEVELS];
    uint32_t level_bpr[ISIM_MTL_MAX_LEVELS];   /* bytes per row */
    uint32_t level_bpi[ISIM_MTL_MAX_LEVELS];   /* bytes per image (a 2D slice or a 3D depth plane) */
} __isim_mtl_texture;

/* a sampler state (MTLSamplerDescriptor) */
typedef struct __isim_mtl_sampler {
    uint8_t min_filter, mag_filter, mip_filter;   /* 0 nearest, 1 linear; mip: 0 none, 1 nearest, 2 linear */
    uint8_t s_address, t_address, r_address;      /* MTLSamplerAddressMode */
    uint8_t normalized, border;                   /* border: MTLSamplerBorderColor */
    float lod_min, lod_max;
} __isim_mtl_sampler;

/* what a dispatch binds: the encoder's state when it was recorded */
typedef struct __isim_mtl_args {
    void *buffers[ISIM_MTL_MAX_BUFFERS];
    const __isim_mtl_texture *textures[ISIM_MTL_MAX_TEXTURES];
    const __isim_mtl_sampler *samplers[ISIM_MTL_MAX_SAMPLERS];
    void *tgmem[ISIM_MTL_MAX_TGMEM];              /* threadgroup memory of the running worker */
    uint32_t threads_per_grid[3], threadgroups_per_grid[3], threads_per_threadgroup[3];
    /* function constants (MTLFunctionConstantValues): copies the value of index i into out (size bytes), 0 if unset */
    int (*constant_value)(const void *ctx, uint32_t index, void *out, uint32_t size);
    const void *constants;
    void (*barrier)(void *sched);                 /* threadgroup_barrier: switch to the threadgroup's next thread */
    void *sched;
} __isim_mtl_args;

/* one thread of a dispatch */
typedef struct __isim_mtl_thread {
    uint32_t position_in_grid[3], position_in_threadgroup[3], threadgroup_position_in_grid[3];
    uint32_t threads_per_threadgroup[3];          /* this threadgroup's size (smaller at a non-uniform edge) */
    uint32_t index_in_threadgroup;
} __isim_mtl_thread;

enum { ISIM_MTL_FN_KERNEL = 3, ISIM_MTL_FN_VERTEX = 1, ISIM_MTL_FN_FRAGMENT = 2 };   /* MTLFunctionType */

/* a library's functions (the __isim_mtl_functions table), ended by a NULL name */
typedef struct __isim_mtl_function {
    const char *name;
    uint32_t type;                                /* ISIM_MTL_FN_* */
    void (*entry)(const __isim_mtl_thread *);     /* kernels: one thread */
    uint32_t uses_barrier;                        /* calls threadgroup_barrier: threads run as fibers */
    uint32_t max_threads;                         /* [[max_total_threads_per_threadgroup(n)]], 0 if none */
    const char *constants;                        /* its library's function constants: "index:type:name;..." */
} __isim_mtl_function;
