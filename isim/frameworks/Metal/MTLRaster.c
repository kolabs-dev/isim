/* isim Metal: the rasterizer of render pipelines (issue #329). A draw runs in phases on the worker threads
 * (MTLDispatch.c): the vertex function for each vertex; primitive assembly, clipping (near / far planes and a guard
 * band, in clip space) and setup on the calling thread; then 64x64-pixel tiles in parallel, each drawing its primitives
 * in order: triangles with the top-left rule on a 1/256-pixel grid, perspective-correct interpolation of the vertex
 * outputs, the depth and stencil tests, the fragment function, blending and the write mask. Lines are 1 pixel wide,
 * points squares of their [[point_size]]. One sample per pixel (multisample attachments are not antialiased).
 * Adapted: Metal's rendering, on the CPU. */
#include "MTLRaster.h"
#include "MTLDispatch.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* ---- pixel formats (MTLPixelFormat numbers) ---- */
static float srgb_to_linear(float c) { return c <= 0.04045f ? c / 12.92f : powf((c + 0.055f) / 1.055f, 2.4f); }
static float linear_to_srgb(float c) { c = c < 0 ? 0 : c > 1 ? 1 : c; return c <= 0.0031308f ? c * 12.92f : 1.055f * powf(c, 1 / 2.4f) - 0.055f; }
static unsigned unorm(float v, unsigned max) { v = v != v ? 0 : v < 0 ? 0 : v > 1 ? 1 : v; return (unsigned)(v * max + 0.5f); }
static int snorm(float v, int max) { v = v != v ? 0 : v < -1 ? -1 : v > 1 ? 1 : v; return (int)roundf(v * max); }
static float snf(int v, int max) { float f = (float)v / max; return f < -1 ? -1 : f; }
static uint16_t rd16(const uint8_t *p) { uint16_t v; memcpy(&v, p, 2); return v; }
static uint32_t rd32(const uint8_t *p) { uint32_t v; memcpy(&v, p, 4); return v; }
static float rdf(const uint8_t *p) { float v; memcpy(&v, p, 4); return v; }
static void wr16(uint8_t *p, uint16_t v) { memcpy(p, &v, 2); }
static void wr32(uint8_t *p, uint32_t v) { memcpy(p, &v, 4); }
static void wrf(uint8_t *p, float v) { memcpy(p, &v, 4); }
static float hf(uint16_t h) { _Float16 x; memcpy(&x, &h, 2); return (float)x; }
static uint16_t fh(float f) { _Float16 x = (_Float16)f; uint16_t h; memcpy(&h, &x, 2); return h; }

uint32_t isim_mtl_bpp(uint32_t f) {
    switch (f) {
    case 1: case 10: case 11: case 12: case 13: case 14: case 253: return 1;
    case 20: case 22: case 23: case 24: case 25: case 30: case 31: case 32: case 33: case 34: case 40: case 41: case 42: case 43: case 250: return 2;
    case 103: case 104: case 105: case 110: case 112: case 113: case 114: case 115: case 260: case 261: case 552: case 553: return 8;
    case 123: case 124: case 125: return 16;
    default: return 4;
    }
}
static int is_int_format(uint32_t f) {
    switch (f) {
    case 13: case 14: case 23: case 24: case 33: case 34: case 53: case 54: case 63: case 64: case 73: case 74: case 91:
    case 103: case 104: case 113: case 114: case 123: case 124: return 1;
    default: return 0;
    }
}
static int is_float_format(uint32_t f) {
    switch (f) { case 25: case 55: case 65: case 92: case 93: case 105: case 115: case 125: return 1; default: return 0; }
}
void isim_mtl_unpack(uint32_t f, const uint8_t *p, float c[4]) {
    c[0] = c[1] = c[2] = 0; c[3] = 1;
    switch (f) {
    case 1: c[3] = p[0] / 255.0f; break;
    case 10: c[0] = p[0] / 255.0f; break;
    case 11: c[0] = srgb_to_linear(p[0] / 255.0f); break;
    case 12: c[0] = snf((signed char)p[0], 127); break;
    case 20: c[0] = rd16(p) / 65535.0f; break;
    case 22: c[0] = snf((int16_t)rd16(p), 32767); break;
    case 25: c[0] = hf(rd16(p)); break;
    case 30: c[0] = p[0] / 255.0f; c[1] = p[1] / 255.0f; break;
    case 31: c[0] = srgb_to_linear(p[0] / 255.0f); c[1] = srgb_to_linear(p[1] / 255.0f); break;
    case 40: { uint16_t v = rd16(p); c[0] = (v >> 11) / 31.0f; c[1] = (v >> 5 & 63) / 63.0f; c[2] = (v & 31) / 31.0f; break; }
    case 55: c[0] = rdf(p); break;
    case 60: c[0] = rd16(p) / 65535.0f; c[1] = rd16(p + 2) / 65535.0f; break;
    case 65: c[0] = hf(rd16(p)); c[1] = hf(rd16(p + 2)); break;
    case 70: for (int i = 0; i < 4; i++) c[i] = p[i] / 255.0f; break;
    case 71: for (int i = 0; i < 3; i++) c[i] = srgb_to_linear(p[i] / 255.0f); c[3] = p[3] / 255.0f; break;
    case 72: for (int i = 0; i < 4; i++) c[i] = snf((signed char)p[i], 127); break;
    case 80: c[0] = p[2] / 255.0f; c[1] = p[1] / 255.0f; c[2] = p[0] / 255.0f; c[3] = p[3] / 255.0f; break;
    case 81: c[0] = srgb_to_linear(p[2] / 255.0f); c[1] = srgb_to_linear(p[1] / 255.0f); c[2] = srgb_to_linear(p[0] / 255.0f); c[3] = p[3] / 255.0f; break;
    case 90: { uint32_t v = rd32(p); c[0] = (v & 1023) / 1023.0f; c[1] = (v >> 10 & 1023) / 1023.0f; c[2] = (v >> 20 & 1023) / 1023.0f; c[3] = (v >> 30) / 3.0f; break; }
    case 94: { uint32_t v = rd32(p); c[2] = (v & 1023) / 1023.0f; c[1] = (v >> 10 & 1023) / 1023.0f; c[0] = (v >> 20 & 1023) / 1023.0f; c[3] = (v >> 30) / 3.0f; break; }
    case 105: c[0] = rdf(p); c[1] = rdf(p + 4); break;
    case 110: for (int i = 0; i < 4; i++) c[i] = rd16(p + 2 * i) / 65535.0f; break;
    case 115: for (int i = 0; i < 4; i++) c[i] = hf(rd16(p + 2 * i)); break;
    case 125: for (int i = 0; i < 4; i++) c[i] = rdf(p + 4 * i); break;
    default:
        if (is_int_format(f)) {          /* integer formats: the values as floats */
            int n = f == 13 || f == 14 || f == 23 || f == 24 || f == 53 || f == 54 ? 1 : f == 33 || f == 34 || f == 63 || f == 64 || f == 103 || f == 104 ? 2 : 4;
            int cs = f == 13 || f == 14 || f == 33 || f == 34 || f == 73 || f == 74 ? 1 : f == 23 || f == 24 || f == 63 || f == 64 || f == 113 || f == 114 ? 2 : 4;
            int s = f == 14 || f == 24 || f == 34 || f == 54 || f == 64 || f == 74 || f == 104 || f == 114 || f == 124;
            for (int i = 0; i < n; i++) {
                const uint8_t *q = p + i * cs;
                c[i] = cs == 1 ? (s ? (float)(signed char)q[0] : (float)q[0]) : cs == 2 ? (s ? (float)(int16_t)rd16(q) : (float)rd16(q)) : (s ? (float)(int32_t)rd32(q) : (float)rd32(q));
            }
        }
        break;
    }
}
void isim_mtl_pack(uint32_t f, uint8_t *p, const float c[4]) {
    switch (f) {
    case 1: p[0] = unorm(c[3], 255); break;
    case 10: p[0] = unorm(c[0], 255); break;
    case 11: p[0] = unorm(linear_to_srgb(c[0]), 255); break;
    case 12: p[0] = (uint8_t)snorm(c[0], 127); break;
    case 20: wr16(p, unorm(c[0], 65535)); break;
    case 22: wr16(p, (uint16_t)snorm(c[0], 32767)); break;
    case 25: wr16(p, fh(c[0])); break;
    case 30: p[0] = unorm(c[0], 255); p[1] = unorm(c[1], 255); break;
    case 31: p[0] = unorm(linear_to_srgb(c[0]), 255); p[1] = unorm(linear_to_srgb(c[1]), 255); break;
    case 40: wr16(p, (uint16_t)(unorm(c[0], 31) << 11 | unorm(c[1], 63) << 5 | unorm(c[2], 31))); break;
    case 55: wrf(p, c[0]); break;
    case 60: wr16(p, unorm(c[0], 65535)); wr16(p + 2, unorm(c[1], 65535)); break;
    case 65: wr16(p, fh(c[0])); wr16(p + 2, fh(c[1])); break;
    case 70: for (int i = 0; i < 4; i++) p[i] = unorm(c[i], 255); break;
    case 71: for (int i = 0; i < 3; i++) p[i] = unorm(linear_to_srgb(c[i]), 255); p[3] = unorm(c[3], 255); break;
    case 72: for (int i = 0; i < 4; i++) p[i] = (uint8_t)snorm(c[i], 127); break;
    case 80: p[0] = unorm(c[2], 255); p[1] = unorm(c[1], 255); p[2] = unorm(c[0], 255); p[3] = unorm(c[3], 255); break;
    case 81: p[0] = unorm(linear_to_srgb(c[2]), 255); p[1] = unorm(linear_to_srgb(c[1]), 255); p[2] = unorm(linear_to_srgb(c[0]), 255); p[3] = unorm(c[3], 255); break;
    case 90: wr32(p, unorm(c[0], 1023) | unorm(c[1], 1023) << 10 | unorm(c[2], 1023) << 20 | unorm(c[3], 3) << 30); break;
    case 94: wr32(p, unorm(c[2], 1023) | unorm(c[1], 1023) << 10 | unorm(c[0], 1023) << 20 | unorm(c[3], 3) << 30); break;
    case 105: wrf(p, c[0]); wrf(p + 4, c[1]); break;
    case 110: for (int i = 0; i < 4; i++) wr16(p + 2 * i, unorm(c[i], 65535)); break;
    case 115: for (int i = 0; i < 4; i++) wr16(p + 2 * i, fh(c[i])); break;
    case 125: for (int i = 0; i < 4; i++) wrf(p + 4 * i, c[i]); break;
    default:
        if (is_int_format(f)) {
            int n = f == 13 || f == 14 || f == 23 || f == 24 || f == 53 || f == 54 ? 1 : f == 33 || f == 34 || f == 63 || f == 64 || f == 103 || f == 104 ? 2 : 4;
            int cs = f == 13 || f == 14 || f == 33 || f == 34 || f == 73 || f == 74 ? 1 : f == 23 || f == 24 || f == 63 || f == 64 || f == 113 || f == 114 ? 2 : 4;
            for (int i = 0; i < n; i++) {
                uint8_t *q = p + i * cs;
                long v = lrintf(c[i]);
                if (cs == 1) q[0] = (uint8_t)v; else if (cs == 2) wr16(q, (uint16_t)v); else wr32(q, (uint32_t)v);
            }
        }
        break;
    }
}
float isim_mtl_depth_get(uint32_t f, const uint8_t *p) {
    switch (f) { case 250: return rd16(p) / 65535.0f; case 252: case 260: return rdf(p); default: return 1; }
}
void isim_mtl_depth_set(uint32_t f, uint8_t *p, float z) {
    switch (f) { case 250: wr16(p, unorm(z, 65535)); break; case 252: case 260: wrf(p, z); break; default: break; }
}
uint8_t *isim_mtl_stencil_at(uint32_t f, uint8_t *p) {
    switch (f) { case 253: return p; case 260: case 261: return p + 4; default: return NULL; }
}
void isim_mtl_fill(const isim_mtl_target *t, const uint8_t *texel, uint32_t bpp) {
    if (!t->base) return;
    for (uint32_t y = 0; y < t->height; y++) {
        uint8_t *row = t->base + (size_t)y * t->bpr;
        for (uint32_t x = 0; x < t->width; x++) memcpy(row + (size_t)x * bpp, texel, bpp);
    }
}

/* ---- the vertices of a draw ---- */
typedef struct vpool {
    uint32_t n, cap, stage;             /* stage: the vertex outputs' size */
    float *clip;                        /* 4 per vertex */
    float *psize;
    uint8_t *out;                       /* stage bytes per vertex */
} vpool;
static uint32_t vpool_add(vpool *v) {
    if (v->n == v->cap) {
        v->cap = v->cap ? v->cap * 2 : 256;
        v->clip = realloc(v->clip, (size_t)v->cap * 4 * sizeof(float));
        v->psize = realloc(v->psize, (size_t)v->cap * sizeof(float));
        v->out = realloc(v->out, (size_t)v->cap * (v->stage ? v->stage : 1));
    }
    return v->n++;
}

typedef struct shade_job {
    const isim_mtl_draw *d;
    vpool *vp;
    const uint32_t *ids;                /* the vertex id of the draw's k-th vertex */
    uint32_t count, total;              /* pool entry i: vertex i % count of instance i / count */
} shade_job;
enum { SHADE_CHUNK = 64 };
static void shade_vertices(void *ctx, uint32_t chunk, int worker) {
    shade_job *j = ctx;
    const isim_mtl_draw *d = j->d;
    const isim_mtl_pipeline *p = d->p;
    __isim_mtl_args args = d->vargs;
    args.constant_value = d->constant_value; args.constants = p->vs_constants;
    if (p->vs_prepare) p->vs_prepare(&args);
    __isim_mtl_vertex_in vin;
    memset(&vin, 0, sizeof vin);
    vin.args = &args;
    vin.base_vertex = (uint32_t)d->base_vertex; vin.base_instance = d->base_instance;
    uint32_t end = (chunk + 1) * SHADE_CHUNK < j->total ? (chunk + 1) * SHADE_CHUNK : j->total;
    for (uint32_t idx = chunk * SHADE_CHUNK; idx < end; idx++) {
        uint32_t inst = idx / j->count, vid = j->ids[idx % j->count];
        vin.vertex_id = vid;
        vin.instance_id = inst + d->base_instance;
        for (int a = 0; a < ISIM_MTL_MAX_ATTRIBUTES; a++) {
            vin.attr_format[a] = p->attr_format[a];
            vin.attr[a] = NULL;
            if (!p->attr_format[a]) continue;
            uint32_t b = p->attr_buffer[a];
            if (b >= ISIM_MTL_MAX_BUFFERS || !d->vargs.buffers[b]) continue;
            uint32_t step = p->layout_step[b], rate = p->layout_rate[b] ? p->layout_rate[b] : 1;
            uint64_t i = step == 0 ? 0 : step == 2 ? d->base_instance + inst / rate : vid;   /* constant, per instance, per vertex */
            vin.attr[a] = (const uint8_t *)d->vargs.buffers[b] + i * p->layout_stride[b] + p->attr_offset[a];
        }
        float *clip = j->vp->clip + (size_t)idx * 4;
        j->vp->psize[idx] = 1;
        p->vs->vertex(&vin, clip, &j->vp->psize[idx], j->vp->out + (size_t)idx * (j->vp->stage ? j->vp->stage : 1));
    }
    (void)worker;
}

/* ---- primitives ---- */
enum { P_TRI, P_LINE, P_POINT };
typedef struct prim {
    uint8_t kind, front;
    uint32_t v[3];                      /* pool entries */
    uint32_t id;                        /* [[primitive_id]] */
    float sx[3], sy[3], sz[3], iw[3];   /* window coordinates, depth, 1 / w */
    int64_t X[3], Y[3], area;           /* triangles: 1/256-pixel coordinates, twice the area */
    int32_t x0, y0, x1, y1;             /* bounds, inclusive, within the scissor */
    float zoff;                         /* depth bias */
    float size;                         /* points */
} prim;

typedef struct raster {
    const isim_mtl_draw *d;
    vpool vp;
    prim *prims;
    uint32_t nprims, cap;
    int32_t sx0, sy0, sx1, sy1;         /* the scissor, clamped to the targets (inclusive) */
    uint32_t tiles_x, tiles_y;
    uint32_t *tile_start, *tile_list;   /* per tile: its primitives, in order */
    uint8_t **scratch;                  /* per worker: interpolated outputs, the fragment layout */
    uint64_t visible;
} raster;
enum { TILE = 64 };

static prim *prim_add(raster *r) {
    if (r->nprims == r->cap) { r->cap = r->cap ? r->cap * 2 : 256; r->prims = realloc(r->prims, (size_t)r->cap * sizeof(prim)); }
    prim *p = &r->prims[r->nprims++];
    memset(p, 0, sizeof *p);
    return p;
}

/* clip space -> window: x, y in pixels, z in the viewport's depth range */
static void to_window(const isim_mtl_draw *d, const float *c, float *sx, float *sy, float *sz, float *iw) {
    float w = c[3], inv = 1.0f / w;
    float nx = c[0] * inv, ny = c[1] * inv, nz = c[2] * inv;
    const double *vp = d->viewport;
    *sx = (float)(vp[0] + (nx * 0.5 + 0.5) * vp[2]);
    *sy = (float)(vp[1] + (0.5 - ny * 0.5) * vp[3]);
    float z = (float)(vp[4] + nz * (vp[5] - vp[4]));
    if (d->depth_clamp) { float lo = (float)fmin(vp[4], vp[5]), hi = (float)fmax(vp[4], vp[5]); z = z < lo ? lo : z > hi ? hi : z; }
    *sz = z; *iw = inv;
}

static void bounds(raster *r, prim *p, float minx, float miny, float maxx, float maxy) {
    int32_t x0 = (int32_t)floorf(minx), y0 = (int32_t)floorf(miny), x1 = (int32_t)ceilf(maxx), y1 = (int32_t)ceilf(maxy);
    p->x0 = x0 > r->sx0 ? x0 : r->sx0; p->y0 = y0 > r->sy0 ? y0 : r->sy0;
    p->x1 = x1 < r->sx1 ? x1 : r->sx1; p->y1 = y1 < r->sy1 ? y1 : r->sy1;
}

/* a clipped vertex: a new pool entry between a and b */
static uint32_t clip_vertex(raster *r, uint32_t a, uint32_t b, float t) {
    uint32_t n = vpool_add(&r->vp);
    float *ca = r->vp.clip + (size_t)a * 4, *cb = r->vp.clip + (size_t)b * 4, *cn = r->vp.clip + (size_t)n * 4;
    for (int i = 0; i < 4; i++) cn[i] = ca[i] + (cb[i] - ca[i]) * t;
    r->vp.psize[n] = r->vp.psize[a];
    if (r->vp.stage && r->d->p->vs->interpolate) {
        float w[3] = {1 - t, t, 0};
        uint8_t *o = r->vp.out;
        r->d->p->vs->interpolate(o + (size_t)a * r->vp.stage, o + (size_t)b * r->vp.stage, o + (size_t)b * r->vp.stage, w,
                                 o + (size_t)n * r->vp.stage);
    }
    return n;
}

/* the signed distance of a vertex to clip plane k (inside when >= 0) */
static float plane_dist(raster *r, uint32_t v, int k, float gb) {
    const float *c = r->vp.clip + (size_t)v * 4;
    switch (k) {
    case 0: return c[3] - 1e-6f;                 /* w > 0 */
    case 1: return r->d->depth_clamp ? 1 : c[2];  /* near: z >= 0 */
    case 2: return r->d->depth_clamp ? 1 : c[3] - c[2];   /* far: z <= w */
    case 3: return gb * c[3] - c[0];
    case 4: return gb * c[3] + c[0];
    case 5: return gb * c[3] - c[1];
    default: return gb * c[3] + c[1];
    }
}

static void setup_triangle(raster *r, uint32_t a, uint32_t b, uint32_t c, uint32_t id);

/* a triangle clipped against the near and far planes and the guard band, then fanned into triangles */
static void clip_triangle(raster *r, uint32_t a, uint32_t b, uint32_t c, uint32_t id, float gb) {
    uint32_t in[16] = {a, b, c}, out[16];
    int n = 3, all_in = 1;
    for (int k = 0; k < 7 && all_in; k++)
        for (int i = 0; i < 3; i++) if (plane_dist(r, in[i], k, gb) < 0) { all_in = 0; break; }
    if (all_in) { setup_triangle(r, a, b, c, id); return; }
    for (int k = 0; k < 7 && n >= 3; k++) {
        int m = 0;
        for (int i = 0; i < n && m < 15; i++) {
            uint32_t p = in[i], q = in[(i + 1) % n];
            float dp = plane_dist(r, p, k, gb), dq = plane_dist(r, q, k, gb);
            if (dp >= 0) out[m++] = p;
            if ((dp >= 0) != (dq >= 0) && m < 15) out[m++] = clip_vertex(r, p, q, dp / (dp - dq));
        }
        memcpy(in, out, sizeof(uint32_t) * m);
        n = m;
    }
    for (int i = 1; i + 1 < n; i++) setup_triangle(r, in[0], in[i], in[i + 1], id);
}

static int facing_front(const isim_mtl_draw *d, float area_ndc) {
    /* NDC (y up): a negative area is clockwise */
    return d->winding == 0 ? area_ndc < 0 : area_ndc > 0;
}

static void setup_triangle(raster *r, uint32_t a, uint32_t b, uint32_t c, uint32_t id) {
    const isim_mtl_draw *d = r->d;
    uint32_t v[3] = {a, b, c};
    float sx[3], sy[3], sz[3], iw[3];
    for (int i = 0; i < 3; i++) to_window(d, r->vp.clip + (size_t)v[i] * 4, &sx[i], &sy[i], &sz[i], &iw[i]);
    /* window y points down: the window area's sign is the opposite of NDC's (for a viewport of positive height) */
    float area_w = (sx[1] - sx[0]) * (sy[2] - sy[0]) - (sx[2] - sx[0]) * (sy[1] - sy[0]);
    float area_ndc = d->viewport[3] >= 0 ? -area_w : area_w;
    int front = facing_front(d, area_ndc);
    if ((d->cull == 1 && front) || (d->cull == 2 && !front)) return;
    if (d->fill == 1) {                  /* wireframe: the edges as lines */
        for (int i = 0; i < 3; i++) {
            prim *p = prim_add(r);
            p->kind = P_LINE; p->front = (uint8_t)front; p->id = id;
            int j = (i + 1) % 3;
            p->v[0] = v[i]; p->v[1] = v[j];
            p->sx[0] = sx[i]; p->sy[0] = sy[i]; p->sz[0] = sz[i]; p->iw[0] = iw[i];
            p->sx[1] = sx[j]; p->sy[1] = sy[j]; p->sz[1] = sz[j]; p->iw[1] = iw[j];
            bounds(r, p, fminf(sx[i], sx[j]) - 1, fminf(sy[i], sy[j]) - 1, fmaxf(sx[i], sx[j]) + 1, fmaxf(sy[i], sy[j]) + 1);
            if (p->x0 > p->x1 || p->y0 > p->y1) r->nprims--;
        }
        return;
    }
    prim *p = prim_add(r);
    p->kind = P_TRI; p->front = (uint8_t)front; p->id = id;
    for (int i = 0; i < 3; i++) {
        p->v[i] = v[i]; p->sx[i] = sx[i]; p->sy[i] = sy[i]; p->sz[i] = sz[i]; p->iw[i] = iw[i];
        p->X[i] = (int64_t)llroundf(sx[i] * 256.0f); p->Y[i] = (int64_t)llroundf(sy[i] * 256.0f);
    }
    int64_t area = (p->X[1] - p->X[0]) * (p->Y[2] - p->Y[0]) - (p->Y[1] - p->Y[0]) * (p->X[2] - p->X[0]);
    if (area == 0) { r->nprims--; return; }
    if (area < 0) {                      /* keep the interior where the edge functions are positive */
        uint32_t tv = p->v[1]; p->v[1] = p->v[2]; p->v[2] = tv;
        float t;
        t = p->sx[1]; p->sx[1] = p->sx[2]; p->sx[2] = t; t = p->sy[1]; p->sy[1] = p->sy[2]; p->sy[2] = t;
        t = p->sz[1]; p->sz[1] = p->sz[2]; p->sz[2] = t; t = p->iw[1]; p->iw[1] = p->iw[2]; p->iw[2] = t;
        int64_t ti = p->X[1]; p->X[1] = p->X[2]; p->X[2] = ti; ti = p->Y[1]; p->Y[1] = p->Y[2]; p->Y[2] = ti;
        area = -area;
    }
    p->area = area;
    if (d->depth_bias != 0 || d->depth_slope != 0) {   /* the bias plus the slope times the depth's largest gradient */
        float A = (float)area / 65536.0f;
        float dzdx = ((p->sz[1] - p->sz[0]) * (p->sy[2] - p->sy[0]) - (p->sz[2] - p->sz[0]) * (p->sy[1] - p->sy[0])) / A;
        float dzdy = ((p->sx[1] - p->sx[0]) * (p->sz[2] - p->sz[0]) - (p->sx[2] - p->sx[0]) * (p->sz[1] - p->sz[0])) / A;
        float off = d->depth_bias * (1.0f / (1 << 24)) + d->depth_slope * fmaxf(fabsf(dzdx), fabsf(dzdy));
        if (d->depth_bias_clamp > 0 && off > d->depth_bias_clamp) off = d->depth_bias_clamp;
        if (d->depth_bias_clamp < 0 && off < d->depth_bias_clamp) off = d->depth_bias_clamp;
        p->zoff = off;
    }
    bounds(r, p, fminf(sx[0], fminf(sx[1], sx[2])), fminf(sy[0], fminf(sy[1], sy[2])), fmaxf(sx[0], fmaxf(sx[1], sx[2])), fmaxf(sy[0], fmaxf(sy[1], sy[2])));
    if (p->x0 > p->x1 || p->y0 > p->y1) r->nprims--;
}

static int vertex_inside(raster *r, uint32_t v) {
    for (int k = 0; k < 3; k++) if (plane_dist(r, v, k, 0) < 0) return 0;
    return 1;
}

static void setup_line(raster *r, uint32_t a, uint32_t b, uint32_t id) {
    if (!vertex_inside(r, a) && !vertex_inside(r, b)) return;
    if (!vertex_inside(r, a) || !vertex_inside(r, b)) {   /* clip against w, near and far */
        uint32_t in = vertex_inside(r, a) ? a : b, outv = in == a ? b : a;
        float t = 1;
        for (int k = 0; k < 3; k++) {
            float di = plane_dist(r, in, k, 0), dout = plane_dist(r, outv, k, 0);
            if (dout < 0) { float tk = di / (di - dout); if (tk < t) t = tk; }
        }
        uint32_t n = clip_vertex(r, in, outv, t);
        if (in == a) b = n; else a = n;
    }
    prim *p = prim_add(r);
    p->kind = P_LINE; p->front = 1; p->id = id;
    p->v[0] = a; p->v[1] = b;
    to_window(r->d, r->vp.clip + (size_t)a * 4, &p->sx[0], &p->sy[0], &p->sz[0], &p->iw[0]);
    to_window(r->d, r->vp.clip + (size_t)b * 4, &p->sx[1], &p->sy[1], &p->sz[1], &p->iw[1]);
    bounds(r, p, fminf(p->sx[0], p->sx[1]) - 1, fminf(p->sy[0], p->sy[1]) - 1, fmaxf(p->sx[0], p->sx[1]) + 1, fmaxf(p->sy[0], p->sy[1]) + 1);
    if (p->x0 > p->x1 || p->y0 > p->y1) r->nprims--;
}

static void setup_point(raster *r, uint32_t a, uint32_t id) {
    if (!vertex_inside(r, a)) return;
    prim *p = prim_add(r);
    p->kind = P_POINT; p->front = 1; p->id = id;
    p->v[0] = a;
    to_window(r->d, r->vp.clip + (size_t)a * 4, &p->sx[0], &p->sy[0], &p->sz[0], &p->iw[0]);
    float s = r->vp.psize[a];
    p->size = s < 1 ? 1 : s;
    bounds(r, p, p->sx[0] - p->size / 2, p->sy[0] - p->size / 2, p->sx[0] + p->size / 2, p->sy[0] + p->size / 2);
    if (p->x0 > p->x1 || p->y0 > p->y1) r->nprims--;
}

/* ---- fragments ---- */
static int compare(uint8_t f, float a, float b) {   /* MTLCompareFunction: a (new) against b (stored) */
    switch (f) {
    case 0: return 0; case 1: return a < b; case 2: return a == b; case 3: return a <= b;
    case 4: return a > b; case 5: return a != b; case 6: return a >= b; default: return 1;
    }
}
static uint8_t stencil_op(uint8_t op, uint8_t s, uint8_t ref) {
    switch (op) {
    case 1: return 0; case 2: return ref; case 3: return s == 255 ? 255 : s + 1; case 4: return s == 0 ? 0 : s - 1;
    case 5: return (uint8_t)~s; case 6: return (uint8_t)(s + 1); case 7: return (uint8_t)(s - 1); default: return s;
    }
}
static float factor(uint8_t f, int ch, const float *s, const float *dst, const float *bc) {
    float sa = s[3], da = dst[3];
    switch (f) {
    case 0: return 0; case 1: return 1;
    case 2: return s[ch]; case 3: return 1 - s[ch];
    case 4: return sa; case 5: return 1 - sa;
    case 6: return dst[ch]; case 7: return 1 - dst[ch];
    case 8: return da; case 9: return 1 - da;
    case 10: return ch == 3 ? 1 : fminf(sa, 1 - da);
    case 11: return bc[ch]; case 12: return 1 - bc[ch];
    case 13: return bc[3]; case 14: return 1 - bc[3];
    default: return 1;   /* dual-source factors: not on isim */
    }
}
static float blend_op(uint8_t op, float s, float fs, float d, float fd) {
    switch (op) {
    case 1: return s * fs - d * fd; case 2: return d * fd - s * fs;
    case 3: return fminf(s, d); case 4: return fmaxf(s, d);
    default: return s * fs + d * fd;
    }
}

typedef struct frag_ctx {
    raster *r;
    __isim_mtl_fragment_in fin;
    __isim_mtl_args fargs;
    uint8_t *interp, *mapped;
} frag_ctx;

/* one fragment of primitive p at pixel (x, y), with weights w of its vertices (perspective-corrected) and depth z */
static void fragment(frag_ctx *fc, const prim *p, int x, int y, const float w[3], float z, float iw, const float *pc) {
    raster *r = fc->r;
    const isim_mtl_draw *d = r->d;
    const isim_mtl_pipeline *pl = d->p;
    uint8_t *dp = d->depth.base ? d->depth.base + (size_t)y * d->depth.bpr + (size_t)x * isim_mtl_bpp(d->depth.format) : NULL;
    uint8_t *sp = NULL;
    if (d->stencil_t.base) sp = isim_mtl_stencil_at(d->stencil_t.format, d->stencil_t.base + (size_t)y * d->stencil_t.bpr + (size_t)x * isim_mtl_bpp(d->stencil_t.format));
    const isim_mtl_stencil_face *sf = &d->stencil[p->front ? 0 : 1];
    uint8_t ref = (uint8_t)d->stencil_ref[p->front ? 0 : 1];
    /* the stencil and depth tests (before the fragment function unless it writes the depth) */
    if (sp && d->stencil_on) {
        uint8_t s = *sp;
        if (!compare(sf->func, (float)(ref & sf->read_mask), (float)(s & sf->read_mask))) {
            uint8_t ns = stencil_op(sf->fail, s, ref);
            *sp = (uint8_t)((s & ~sf->write_mask) | (ns & sf->write_mask));
            return;
        }
    }
    int late = pl->fs && pl->fs->writes_depth;    /* the depth test waits for the depth the fragment function writes */
    if (!late && dp && d->depth_func != 7 && !compare(d->depth_func, z, isim_mtl_depth_get(d->depth.format, dp))) {
        if (sp && d->stencil_on) {
            uint8_t s = *sp, ns = stencil_op(sf->zfail, s, ref);
            *sp = (uint8_t)((s & ~sf->write_mask) | (ns & sf->write_mask));
        }
        return;
    }
    __isim_mtl_fragment_in *f = &fc->fin;
    if (pl->fs) {
        if (r->vp.stage && pl->vs->interpolate) {
            const uint8_t *o = r->vp.out;
            size_t st = r->vp.stage;
            uint32_t c = p->kind == P_TRI ? p->v[2] : p->v[p->kind == P_LINE ? 1 : 0];
            pl->vs->interpolate(o + p->v[0] * st, o + p->v[p->kind == P_POINT ? 0 : 1] * st, o + c * st, w, fc->interp);
            if (pl->ncopies) {
                memset(fc->mapped, 0, pl->fs->stage_size);
                for (uint32_t i = 0; i < pl->ncopies; i++) memcpy(fc->mapped + pl->copies[i].dst, fc->interp + pl->copies[i].src, pl->copies[i].size);
                f->varyings = fc->mapped;
            } else {
                f->varyings = fc->interp;
            }
        } else {
            f->varyings = fc->interp;
        }
        f->position[0] = x + 0.5f; f->position[1] = y + 0.5f; f->position[2] = z; f->position[3] = iw;
        f->front_facing = p->front; f->primitive_id = p->id;
        if (pc) { f->point_coord[0] = pc[0]; f->point_coord[1] = pc[1]; }
        for (int i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
            const isim_mtl_target *t = &d->color[i];
            if (t->base) isim_mtl_unpack(t->format, t->base + (size_t)y * t->bpr + (size_t)x * isim_mtl_bpp(t->format), f->color_in[i]);
        }
        f->depth_written = 0;
        if (!pl->fs->fragment(f)) return;   /* discarded */
        if (f->depth_written) z = f->depth;
        if (late && dp && d->depth_func != 7 && !compare(d->depth_func, z, isim_mtl_depth_get(d->depth.format, dp))) {
            if (sp && d->stencil_on) {
                uint8_t s = *sp, ns = stencil_op(sf->zfail, s, ref);
                *sp = (uint8_t)((s & ~sf->write_mask) | (ns & sf->write_mask));
            }
            return;
        }
    }
    if (sp && d->stencil_on) {
        uint8_t s = *sp, ns = stencil_op(sf->pass, s, ref);
        *sp = (uint8_t)((s & ~sf->write_mask) | (ns & sf->write_mask));
    }
    if (dp && d->depth_write) isim_mtl_depth_set(d->depth.format, dp, z);
    if (d->visibility) r->visible++;
    if (!pl->fs) return;
    for (int i = 0; i < ISIM_MTL_MAX_COLORS; i++) {
        const isim_mtl_target *t = &d->color[i];
        const isim_mtl_blend *b = &pl->blend[i];
        if (!t->base || !(pl->fs->color_outputs & (1u << i)) || !b->write_mask) continue;
        uint8_t *px = t->base + (size_t)y * t->bpr + (size_t)x * isim_mtl_bpp(t->format);
        float s[4], dst[4], out[4];
        memcpy(s, f->color[i], sizeof s);
        if (!is_float_format(t->format) && !is_int_format(t->format))
            for (int k = 0; k < 4; k++) s[k] = s[k] != s[k] ? 0 : s[k] < 0 ? 0 : s[k] > 1 ? 1 : s[k];
        isim_mtl_unpack(t->format, px, dst);
        if (b->enabled && !is_int_format(t->format)) {
            for (int k = 0; k < 3; k++)
                out[k] = blend_op(b->op_rgb, s[k], factor(b->src_rgb, k, s, dst, d->blend_color), dst[k], factor(b->dst_rgb, k, s, dst, d->blend_color));
            out[3] = blend_op(b->op_a, s[3], factor(b->src_a, 3, s, dst, d->blend_color), dst[3], factor(b->dst_a, 3, s, dst, d->blend_color));
        } else {
            memcpy(out, s, sizeof out);
        }
        if (b->write_mask != 0xf) {          /* red 8, green 4, blue 2, alpha 1 */
            for (int k = 0; k < 4; k++) if (!(b->write_mask & (8 >> k))) out[k] = dst[k];
        }
        isim_mtl_pack(t->format, px, out);
    }
}

static void raster_triangle(frag_ctx *fc, const prim *p, int tx0, int ty0, int tx1, int ty1) {
    int x0 = p->x0 > tx0 ? p->x0 : tx0, y0 = p->y0 > ty0 ? p->y0 : ty0;
    int x1 = p->x1 < tx1 ? p->x1 : tx1, y1 = p->y1 < ty1 ? p->y1 : ty1;
    if (x0 > x1 || y0 > y1) return;
    /* edge k is opposite vertex k: from v[k+1] to v[k+2] */
    int64_t ex[3], ey[3], bias[3];
    for (int k = 0; k < 3; k++) {
        int a = (k + 1) % 3, b = (k + 2) % 3;
        ex[k] = p->X[b] - p->X[a]; ey[k] = p->Y[b] - p->Y[a];
        int top = ey[k] == 0 && ex[k] > 0, left = ey[k] < 0;
        bias[k] = top || left ? 0 : -1;
    }
    float A = (float)p->area;
    for (int y = y0; y <= y1; y++) {
        int64_t py = (int64_t)y * 256 + 128;
        int64_t px = (int64_t)x0 * 256 + 128;
        int64_t e[3];
        for (int k = 0; k < 3; k++) {
            int a = (k + 1) % 3;
            e[k] = ex[k] * (py - p->Y[a]) - ey[k] * (px - p->X[a]);
        }
        for (int x = x0; x <= x1; x++) {
            if (e[0] + bias[0] >= 0 && e[1] + bias[1] >= 0 && e[2] + bias[2] >= 0) {
                float l0 = (float)e[0] / A, l1 = (float)e[1] / A, l2 = 1 - l0 - l1;
                float z = l0 * p->sz[0] + l1 * p->sz[1] + l2 * p->sz[2] + p->zoff;
                float q0 = l0 * p->iw[0], q1 = l1 * p->iw[1], q2 = l2 * p->iw[2], qs = q0 + q1 + q2;
                float w[3] = {q0 / qs, q1 / qs, q2 / qs};
                fragment(fc, p, x, y, w, z, qs, NULL);
            }
            for (int k = 0; k < 3; k++) e[k] -= ey[k] * 256;
        }
    }
}

static void raster_line(frag_ctx *fc, const prim *p, int tx0, int ty0, int tx1, int ty1) {
    float dx = p->sx[1] - p->sx[0], dy = p->sy[1] - p->sy[0];
    int n = (int)ceilf(fmaxf(fabsf(dx), fabsf(dy)));
    if (n < 1) n = 1;
    int lastx = INT32_MIN, lasty = INT32_MIN;
    for (int i = 0; i < n; i++) {
        float t = (i + 0.5f) / n;
        int x = (int)floorf(p->sx[0] + dx * t), y = (int)floorf(p->sy[0] + dy * t);
        if (x == lastx && y == lasty) continue;
        lastx = x; lasty = y;
        if (x < tx0 || x > tx1 || y < ty0 || y > ty1 || x < p->x0 || x > p->x1 || y < p->y0 || y > p->y1) continue;
        float q0 = (1 - t) * p->iw[0], q1 = t * p->iw[1], qs = q0 + q1;
        float w[3] = {q0 / qs, q1 / qs, 0};
        fragment(fc, p, x, y, w, p->sz[0] + (p->sz[1] - p->sz[0]) * t, qs, NULL);
    }
}

static void raster_point(frag_ctx *fc, const prim *p, int tx0, int ty0, int tx1, int ty1) {
    float h = p->size / 2, left = p->sx[0] - h, top = p->sy[0] - h;
    int x0 = (int)ceilf(left - 0.5f), y0 = (int)ceilf(top - 0.5f);
    int x1 = (int)ceilf(left + p->size - 0.5f) - 1, y1 = (int)ceilf(top + p->size - 0.5f) - 1;
    x0 = x0 > tx0 ? x0 : tx0; y0 = y0 > ty0 ? y0 : ty0; x1 = x1 < tx1 ? x1 : tx1; y1 = y1 < ty1 ? y1 : ty1;
    x0 = x0 > p->x0 ? x0 : p->x0; y0 = y0 > p->y0 ? y0 : p->y0; x1 = x1 < p->x1 ? x1 : p->x1; y1 = y1 < p->y1 ? y1 : p->y1;
    float w[3] = {1, 0, 0};
    for (int y = y0; y <= y1; y++)
        for (int x = x0; x <= x1; x++) {
            float pc[2] = {(x + 0.5f - left) / p->size, (y + 0.5f - top) / p->size};
            fragment(fc, p, x, y, w, p->sz[0], p->iw[0], pc);
        }
}

static void shade_tile(void *ctx, uint32_t tile, int worker) {
    raster *r = ctx;
    const isim_mtl_draw *d = r->d;
    uint32_t first = r->tile_start[tile], last = r->tile_start[tile + 1];
    if (first == last) return;
    frag_ctx fc;
    memset(&fc, 0, sizeof fc);
    fc.r = r;
    fc.fargs = d->fargs;
    fc.fargs.constant_value = d->constant_value; fc.fargs.constants = d->p->fs_constants;
    if (d->p->fs && d->p->fs_prepare) d->p->fs_prepare(&fc.fargs);
    fc.fin.args = &fc.fargs;
    fc.interp = r->scratch[worker];
    fc.mapped = r->scratch[worker] + (r->vp.stage + 15) / 16 * 16;
    int tx0 = (int)(tile % r->tiles_x) * TILE + r->sx0, ty0 = (int)(tile / r->tiles_x) * TILE + r->sy0;
    int tx1 = tx0 + TILE - 1, ty1 = ty0 + TILE - 1;
    if (tx1 > r->sx1) tx1 = r->sx1;
    if (ty1 > r->sy1) ty1 = r->sy1;
    if (d->visibility) r->visible = 0;   /* counted per tile; the tiles then run one after another */
    for (uint32_t i = first; i < last; i++) {
        const prim *p = &r->prims[r->tile_list[i]];
        if (p->kind == P_TRI) raster_triangle(&fc, p, tx0, ty0, tx1, ty1);
        else if (p->kind == P_LINE) raster_line(&fc, p, tx0, ty0, tx1, ty1);
        else raster_point(&fc, p, tx0, ty0, tx1, ty1);
    }
}

/* a vertex id of the draw's k-th vertex (index buffer, base vertex) */
static uint32_t vertex_id(const isim_mtl_draw *d, uint32_t k) {
    if (!d->index_size) return d->start + k;
    uint32_t i = d->index_size == 2 ? rd16(d->indices + 2 * k) : rd32(d->indices + 4 * k);
    return (uint32_t)((int64_t)i + d->base_vertex);
}

/* ---- a draw ---- */
void isim_mtl_draw_run(const isim_mtl_draw *d) {
    const isim_mtl_pipeline *pl = d->p;
    if (!pl || !pl->vs || !pl->vs->vertex || !d->count || !d->instances) return;
    raster r;
    memset(&r, 0, sizeof r);
    r.d = d;
    r.vp.stage = pl->vs->stage_size;
    /* the scissor within the targets */
    r.sx0 = d->scissor[0] > 0 ? d->scissor[0] : 0; r.sy0 = d->scissor[1] > 0 ? d->scissor[1] : 0;
    r.sx1 = d->scissor[0] + d->scissor[2] - 1; r.sy1 = d->scissor[1] + d->scissor[3] - 1;
    if (r.sx1 > (int32_t)d->width - 1) r.sx1 = (int32_t)d->width - 1;
    if (r.sy1 > (int32_t)d->height - 1) r.sy1 = (int32_t)d->height - 1;
    /* the guard band: x and y within +-gb * w keep window coordinates within +-2^21 pixels */
    double vmax = fmax(fabs(d->viewport[2]), fabs(d->viewport[3]));
    float gb = (float)((1 << 21) / (vmax > 1 ? vmax : 1));
    if (gb < 1) gb = 1;

    uint32_t *ids = malloc(sizeof(uint32_t) * d->count);
    for (uint32_t k = 0; k < d->count; k++) ids[k] = vertex_id(d, k);
    /* the vertex function, for each of the draw's vertices of each instance */
    uint32_t total = d->count * d->instances;
    for (uint32_t k = 0; k < total; k++) vpool_add(&r.vp);
    shade_job j = {d, &r.vp, ids, d->count, total};
    isim_mtl_parallel((total + SHADE_CHUNK - 1) / SHADE_CHUNK, shade_vertices, &j);
    uint32_t prim_id = 0;
    for (uint32_t inst = 0; inst < d->instances && pl->rasterize; inst++) {
        uint32_t first = inst * d->count;
        /* primitives */
        uint32_t n = d->count;
        switch (d->prim) {
        case 0: for (uint32_t k = 0; k < n; k++) setup_point(&r, first + k, prim_id++); break;
        case 1: for (uint32_t k = 0; k + 1 < n; k += 2) setup_line(&r, first + k, first + k + 1, prim_id++); break;
        case 2: for (uint32_t k = 0; k + 1 < n; k++) setup_line(&r, first + k, first + k + 1, prim_id++); break;
        case 3: for (uint32_t k = 0; k + 2 < n; k += 3) clip_triangle(&r, first + k, first + k + 1, first + k + 2, prim_id++, gb); break;
        default:
            for (uint32_t k = 0; k + 2 < n; k++) {   /* strips alternate their winding */
                if (k & 1) clip_triangle(&r, first + k + 1, first + k, first + k + 2, prim_id++, gb);
                else clip_triangle(&r, first + k, first + k + 1, first + k + 2, prim_id++, gb);
            }
            break;
        }
    }
    free(ids);
    if (r.nprims && r.sx0 <= r.sx1 && r.sy0 <= r.sy1) {
        /* bins: each tile lists the primitives that touch it, in order */
        r.tiles_x = (uint32_t)(r.sx1 - r.sx0) / TILE + 1; r.tiles_y = (uint32_t)(r.sy1 - r.sy0) / TILE + 1;
        uint32_t ntiles = r.tiles_x * r.tiles_y;
        r.tile_start = calloc(ntiles + 1, sizeof(uint32_t));
        uint64_t total = 0;
        for (uint32_t i = 0; i < r.nprims; i++) {
            const prim *p = &r.prims[i];
            for (int ty = (p->y0 - r.sy0) / TILE; ty <= (p->y1 - r.sy0) / TILE; ty++)
                for (int tx = (p->x0 - r.sx0) / TILE; tx <= (p->x1 - r.sx0) / TILE; tx++) { r.tile_start[ty * r.tiles_x + tx + 1]++; total++; }
        }
        for (uint32_t t = 0; t < ntiles; t++) r.tile_start[t + 1] += r.tile_start[t];
        r.tile_list = malloc(sizeof(uint32_t) * (total ? total : 1));
        uint32_t *fill = calloc(ntiles, sizeof(uint32_t));
        for (uint32_t i = 0; i < r.nprims; i++) {
            const prim *p = &r.prims[i];
            for (int ty = (p->y0 - r.sy0) / TILE; ty <= (p->y1 - r.sy0) / TILE; ty++)
                for (int tx = (p->x0 - r.sx0) / TILE; tx <= (p->x1 - r.sx0) / TILE; tx++) {
                    uint32_t t = (uint32_t)(ty * (int)r.tiles_x + tx);
                    r.tile_list[r.tile_start[t] + fill[t]++] = i;
                }
        }
        free(fill);
        int nw = isim_mtl_worker_count();
        size_t scratch = (r.vp.stage + 15) / 16 * 16 + (pl->fs ? pl->fs->stage_size : 0) + 64;
        r.scratch = calloc((size_t)nw, sizeof(uint8_t *));
        for (int i = 0; i < nw; i++) r.scratch[i] = calloc(1, scratch);
        if (d->visibility) {
            /* counting needs every tile's count: shade the tiles one after another */
            uint64_t sum = 0;
            for (uint32_t t = 0; t < ntiles; t++) { shade_tile(&r, t, 0); sum += r.visible; }
            if (d->visibility_count) *d->visibility += sum; else if (sum) *d->visibility = 1;
        } else {
            isim_mtl_parallel(ntiles, shade_tile, &r);
        }
        for (int i = 0; i < nw; i++) free(r.scratch[i]);
        free(r.scratch);
        free(r.tile_start);
        free(r.tile_list);
    }
    free(r.prims);
    free(r.vp.clip); free(r.vp.psize); free(r.vp.out);
}
