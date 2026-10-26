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
#define ISIM_MTL_MAX_ATTRIBUTES 31
#define ISIM_MTL_MAX_COLORS 8

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
    uint8_t compare;                              /* MTLCompareFunction + 1 (sample_compare), 0 none */
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

enum { ISIM_MTL_FN_KERNEL = 3, ISIM_MTL_FN_VERTEX = 1, ISIM_MTL_FN_FRAGMENT = 2, ISIM_MTL_FN_VISIBLE = 5 };   /* MTLFunctionType */

/* SwiftUI's shader effects ([[stitchable]] functions, swift/overlays/SwiftUI/Shaders.swift): the layer a layerEffect
 * samples (premultiplied ARGB pixels, x0 / y0: the user-space position of pixel (0, 0)'s corner, scale: pixels per point) */
typedef struct __isim_mtl_layer {
    const uint32_t *px;
    int32_t width, height, stride;
    float x0, y0, scale;
} __isim_mtl_layer;
/* one Shader.Argument: kind 0 a value (v, count components), 1 an array (ptr, count elements), 2 an image (tex) */
typedef struct __isim_mtl_shader_arg {
    uint32_t kind, count;
    float v[4];
    const void *ptr;
    const __isim_mtl_texture *tex;
} __isim_mtl_shader_arg;
enum { ISIM_MTL_EFFECT_COLOR = 0, ISIM_MTL_EFFECT_LAYER = 1, ISIM_MTL_EFFECT_DISTORTION = 2 };
/* one pixel of a shader effect: the inputs, and the result (a color, premultiplied, or a distortion's source position) */
typedef struct __isim_mtl_stitch {
    uint32_t effect;                              /* ISIM_MTL_EFFECT_* */
    float position[2];
    float color[4];                               /* colorEffect: the pixel's color, premultiplied RGBA */
    const __isim_mtl_layer *layer;                /* layerEffect */
    const __isim_mtl_shader_arg *args;
    uint32_t nargs;
    float result[4];
} __isim_mtl_stitch;

/* render pipelines (issue #329): one vertex of a draw, as a vertex function's entry point sees it */
typedef struct __isim_mtl_vertex_in {
    const __isim_mtl_args *args;                  /* the encoder's vertex buffers, textures and samplers */
    uint32_t vertex_id, instance_id, base_vertex, base_instance;
    const uint8_t *attr[ISIM_MTL_MAX_ATTRIBUTES]; /* [[stage_in]]: this vertex's data of attribute n (the vertex descriptor) */
    uint32_t attr_format[ISIM_MTL_MAX_ATTRIBUTES];   /* MTLVertexFormat, 0 when the attribute is not set */
} __isim_mtl_vertex_in;
/* one fragment: the inputs, then what the fragment function wrote */
typedef struct __isim_mtl_fragment_in {
    const __isim_mtl_args *args;                  /* the encoder's fragment buffers, textures and samplers */
    const void *varyings;                         /* [[stage_in]]: the interpolated outputs, in the fragment function's layout */
    float position[4];                            /* [[position]]: window x, y (pixel centers), depth, 1 / w */
    float point_coord[2];                         /* [[point_coord]] of a point primitive */
    uint32_t front_facing, primitive_id;
    float color_in[ISIM_MTL_MAX_COLORS][4];       /* [[color(n)]] arguments: the attachment's current color */
    float color[ISIM_MTL_MAX_COLORS][4];          /* outputs: the colors of the attachments the function writes */
    float depth;                                  /* [[depth(...)]] output (when depth_written) */
    uint32_t depth_written;
} __isim_mtl_fragment_in;
/* a member of a vertex function's output or a fragment function's [[stage_in]] struct: the vertex outputs reach the
 * fragment inputs by key ([[user(name)]], else the member's name) */
typedef struct __isim_mtl_member {
    const char *key;
    uint32_t offset, size;
    uint32_t flags;                               /* ISIM_MTL_MEMBER_* */
} __isim_mtl_member;
enum { ISIM_MTL_MEMBER_POSITION = 1, ISIM_MTL_MEMBER_FLAT = 2, ISIM_MTL_MEMBER_POINT_SIZE = 4 };

/* a vertex or fragment function's entry points and stage struct */
typedef struct __isim_mtl_render {
    /* vertex functions: one vertex -> its clip-space position, point size and outputs (stage_size bytes) */
    void (*vertex)(const __isim_mtl_vertex_in *, float clip[4], float *point_size, void *out);
    /* vertex functions: the outputs at weights w of three vertices (perspective-corrected; flat members from a) */
    void (*interpolate)(const void *a, const void *b, const void *c, const float w[3], void *out);
    /* fragment functions: one fragment; 0 when it was discarded (discard_fragment) */
    int (*fragment)(__isim_mtl_fragment_in *);
    uint32_t stage_size;                          /* vertex: the output struct; fragment: the [[stage_in]] struct (0: none) */
    const __isim_mtl_member *members;             /* that struct's members */
    uint32_t stage_members;
    uint32_t color_outputs;                       /* fragment: a bit per [[color(n)]] it writes */
    uint32_t writes_depth;                        /* fragment: returns a [[depth(...)]] (the depth test follows it) */
} __isim_mtl_render;

/* a library's functions (the __isim_mtl_functions table), ended by a NULL name */
typedef struct __isim_mtl_function {
    const char *name;
    uint32_t type;                                /* ISIM_MTL_FN_* */
    void (*entry)(const __isim_mtl_thread *);     /* kernels: one thread */
    uint32_t uses_barrier;                        /* calls threadgroup_barrier: threads run as fibers */
    uint32_t max_threads;                         /* [[max_total_threads_per_threadgroup(n)]], 0 if none */
    const char *constants;                        /* its library's function constants: "index:type:name;..." */
    void (*stitch)(__isim_mtl_stitch *);          /* [[stitchable]] functions: one pixel of a SwiftUI shader effect */
    const struct __isim_mtl_render *render;       /* vertex and fragment functions */
} __isim_mtl_function;
