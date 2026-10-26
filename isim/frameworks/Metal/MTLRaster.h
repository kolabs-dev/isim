/* isim Metal: the rasterizer of render pipelines (issue #329; MTLRaster.c), run by the render command encoders
 * (MTLRender.m) on the worker threads (MTLDispatch.c). Plain C. */
#pragma once
#include <isim_metal_abi.h>
#include <stddef.h>

/* a render pass attachment: one level and slice (or depth plane) of a texture */
typedef struct isim_mtl_target {
    uint8_t *base;                  /* NULL: no attachment */
    uint32_t bpr, width, height, format;
} isim_mtl_target;

typedef struct isim_mtl_blend {
    uint8_t enabled, src_rgb, dst_rgb, op_rgb, src_a, dst_a, op_a, write_mask;   /* MTLBlendFactor / MTLBlendOperation / MTLColorWriteMask */
} isim_mtl_blend;

typedef struct isim_mtl_stencil_face {
    uint8_t func, fail, zfail, pass;   /* MTLCompareFunction, MTLStencilOperation */
    uint32_t read_mask, write_mask;
} isim_mtl_stencil_face;

/* a vertex output member copied to the fragment function's [[stage_in]] layout */
typedef struct isim_mtl_copy { uint32_t src, dst, size; } isim_mtl_copy;

/* what a render pipeline state fixes */
typedef struct isim_mtl_pipeline {
    const __isim_mtl_render *vs, *fs;                       /* fs NULL: no fragment function */
    void (*vs_prepare)(const __isim_mtl_args *), (*fs_prepare)(const __isim_mtl_args *);
    const void *vs_constants, *fs_constants;                /* isim_mtl_constant_value records */
    uint32_t attr_format[ISIM_MTL_MAX_ATTRIBUTES], attr_offset[ISIM_MTL_MAX_ATTRIBUTES], attr_buffer[ISIM_MTL_MAX_ATTRIBUTES];
    uint32_t layout_stride[ISIM_MTL_MAX_ATTRIBUTES], layout_step[ISIM_MTL_MAX_ATTRIBUTES], layout_rate[ISIM_MTL_MAX_ATTRIBUTES];
    uint32_t ncopies;                                       /* 0: the fragment function reads the vertex outputs as they are */
    isim_mtl_copy copies[64];
    isim_mtl_blend blend[ISIM_MTL_MAX_COLORS];
    uint32_t rasterize;                                     /* rasterizationEnabled */
} isim_mtl_pipeline;

/* one draw call: the pipeline, the encoder's state and the pass's attachments when it was recorded */
typedef struct isim_mtl_draw {
    const isim_mtl_pipeline *p;
    __isim_mtl_args vargs, fargs;
    int (*constant_value)(const void *ctx, uint32_t index, void *out, uint32_t size);
    double viewport[6];                                     /* originX, originY, width, height, znear, zfar */
    int32_t scissor[4];                                     /* x, y, width, height */
    uint8_t cull, winding, fill, depth_clamp;               /* MTLCullMode, MTLWinding, MTLTriangleFillMode, MTLDepthClipMode */
    float depth_bias, depth_slope, depth_bias_clamp, blend_color[4];
    uint8_t depth_func, depth_write, stencil_on;            /* depth_func: MTLCompareFunction (Always without a depth-stencil state) */
    isim_mtl_stencil_face stencil[2];                       /* front, back */
    uint32_t stencil_ref[2];
    uint8_t prim;                                           /* MTLPrimitiveType */
    uint8_t index_size;                                     /* 0: not indexed, 2 or 4 */
    const uint8_t *indices;                                 /* indexCount of them */
    uint32_t start, count, instances, base_instance;        /* start: vertexStart (not indexed) */
    int32_t base_vertex;
    isim_mtl_target color[ISIM_MTL_MAX_COLORS], depth, stencil_t;
    uint32_t width, height;
    uint64_t *visibility;                                   /* visibility result (MTLVisibilityResultMode): NULL off */
    uint8_t visibility_count;                               /* counting, else boolean */
} isim_mtl_draw;

/* runs a draw; returns when its pixels are written */
void isim_mtl_draw_run(const isim_mtl_draw *d);
/* pixels: a color (RGBA, linear) to and from a texel of a color format, and the depth / stencil parts */
void isim_mtl_pack(uint32_t format, uint8_t *p, const float c[4]);
void isim_mtl_unpack(uint32_t format, const uint8_t *p, float c[4]);
float isim_mtl_depth_get(uint32_t format, const uint8_t *p);
void isim_mtl_depth_set(uint32_t format, uint8_t *p, float z);
uint8_t *isim_mtl_stencil_at(uint32_t format, uint8_t *p);   /* the stencil byte of a depth-stencil or stencil texel, NULL if none */
uint32_t isim_mtl_bpp(uint32_t format);
/* fills a target with a color, depth or stencil value (load actions) */
void isim_mtl_fill(const isim_mtl_target *t, const uint8_t *texel, uint32_t bpp);
