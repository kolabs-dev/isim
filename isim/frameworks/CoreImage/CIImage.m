// isim Core Image engine: color spaces and pixel formats, render buffers and sampling, the image node classes and
// the CIImage API. See CIInternal.h for the model (recipes rendered on the CPU into premultiplied float RGBA).
#import "CIInternal.h"
#include <objc/runtime.h>
#include <stdatomic.h>

/* ================= color spaces ================= */
const ci_space ci_space_srgb = { CI_PRIM_SRGB, CI_TRC_SRGB, 0, 1 }, ci_space_linear = { CI_PRIM_SRGB, CI_TRC_LINEAR, 0, 1 };

CGColorSpaceRef ci_cgspace_named(CFStringRef name) {
    static NSMutableDictionary *cache; static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&m);
    if (!cache) cache = [NSMutableDictionary dictionary];
    id cs = cache[(__bridge NSString *)name];
    if (!cs) { CGColorSpaceRef c = CGColorSpaceCreateWithName(name); if (c) { cs = (__bridge_transfer id)c; cache[(__bridge NSString *)name] = cs; } }
    pthread_mutex_unlock(&m);
    return (__bridge CGColorSpaceRef)cs;
}
ci_space ci_space_of(CGColorSpaceRef cs) {
    if (!cs) return ci_space_srgb;
    CFStringRef n = CGColorSpaceGetName(cs);
    NSString *s = (__bridge NSString *)n;
    ci_space r = ci_space_srgb;
    if (CGColorSpaceGetModel(cs) == kCGColorSpaceModelMonochrome) r.gray = 1;
    if (!s) return r;
    if ([s containsString:@"P3"]) r.prim = CI_PRIM_P3;
    if ([s containsString:@"2020"] || [s containsString:@"2100"]) r.prim = CI_PRIM_2020;
    if ([s containsString:@"Linear"] || [s containsString:@"linear"]) r.trc = CI_TRC_LINEAR;
    else if ([s containsString:@"709"]) r.trc = CI_TRC_709;
    else if ([s containsString:@"Gamma2_2"] || [s containsString:@"GenericGray"]) r.trc = CI_TRC_GAMMA22;
    else if ([s containsString:@"PQ"]) r.trc = CI_TRC_PQ;
    else if ([s containsString:@"HLG"]) r.trc = CI_TRC_HLG;
    if ([s containsString:@"Gray"]) r.gray = 1;
    r.extended = [s containsString:@"Extended"] || r.trc == CI_TRC_LINEAR;
    return r;
}
BOOL ci_is_null(id o) { return o && [o isKindOfClass:[NSNull class]]; }
/* Core Graphics objects answer -_isimCFTypeID (Foundation's Runtime.m) with their CG...GetTypeID value */
@interface NSObject (IsimCFTypeID)
- (unsigned long)_isimCFTypeID;
@end
BOOL ci_is_cgspace(id o) { return o && [o respondsToSelector:@selector(_isimCFTypeID)] && [o _isimCFTypeID] == CGColorSpaceGetTypeID(); }
BOOL ci_is_cgcolor(id o) { static Class k; if (!k) k = NSClassFromString(@"__NSCGColor"); return o && k && [o isKindOfClass:k]; }
int ci_space_eq(ci_space a, ci_space b) { return a.prim == b.prim && a.trc == b.trc && a.gray == b.gray; }
static float srgb_dec(float v) { return v <= 0.04045f ? v / 12.92f : powf((v + 0.055f) / 1.055f, 2.4f); }
static float srgb_enc(float v) { return v <= 0.0031308f ? v * 12.92f : 1.055f * powf(v, 1 / 2.4f) - 0.055f; }
float ci_trc_decode(int trc, float v) {
    float s = v < 0 ? -1 : 1, a = fabsf(v);
    switch (trc) {
    case CI_TRC_SRGB: return s * srgb_dec(a);
    case CI_TRC_GAMMA22: return s * powf(a, 2.2f);
    case CI_TRC_GAMMA18: return s * powf(a, 1.8f);
    case CI_TRC_709: return s * (a < 0.081f ? a / 4.5f : powf((a + 0.099f) / 1.099f, 1 / 0.45f));
    case CI_TRC_PQ: {   /* SMPTE ST 2084; 1.0 = 100 nits (SDR white) */
        const float m1 = 0.1593017578125f, m2 = 78.84375f, c1 = 0.8359375f, c2 = 18.8515625f, c3 = 18.6875f;
        float p = powf(a, 1 / m2), n = fmaxf(p - c1, 0) / (c2 - c3 * p);
        return s * powf(n, 1 / m1) * 100.0f;
    }
    case CI_TRC_HLG: {
        const float A = 0.17883277f, B = 0.28466892f, C = 0.55991073f;
        return s * (a <= 0.5f ? a * a / 3 : (expf((a - C) / A) + B) / 12) * 12 / 3.0f;
    }
    default: return v;
    }
}
float ci_trc_encode(int trc, float v) {
    float s = v < 0 ? -1 : 1, a = fabsf(v);
    switch (trc) {
    case CI_TRC_SRGB: return s * srgb_enc(a);
    case CI_TRC_GAMMA22: return s * powf(a, 1 / 2.2f);
    case CI_TRC_GAMMA18: return s * powf(a, 1 / 1.8f);
    case CI_TRC_709: return s * (a < 0.018f ? a * 4.5f : 1.099f * powf(a, 0.45f) - 0.099f);
    case CI_TRC_PQ: {
        const float m1 = 0.1593017578125f, m2 = 78.84375f, c1 = 0.8359375f, c2 = 18.8515625f, c3 = 18.6875f;
        float y = powf(a / 100.0f, m1);
        return s * powf((c1 + c2 * y) / (1 + c3 * y), m2);
    }
    case CI_TRC_HLG: {
        const float A = 0.17883277f, B = 0.28466892f, C = 0.55991073f;
        a = a * 3 / 12;
        return s * (a <= 1 / 12.0f ? sqrtf(3 * a) : A * logf(12 * a - B) + C);
    }
    default: return v;
    }
}
/* linear primaries -> linear sRGB primaries */
static const float M_TO_SRGB[3][9] = {
    { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
    { 1.2249401f, -0.2249404f, 0, -0.0420569f, 1.0420571f, 0, -0.0196376f, -0.0786361f, 1.0982735f },
    { 1.6604910f, -0.5876411f, -0.0728499f, -0.1245505f, 1.1328999f, -0.0083494f, -0.0181508f, -0.1005789f, 1.1187297f },
};
static const float M_FROM_SRGB[3][9] = {
    { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
    { 0.8224621f, 0.1775380f, 0, 0.0331941f, 0.9668058f, 0, 0.0170827f, 0.0723974f, 0.9105199f },
    { 0.6274040f, 0.3292820f, 0.0433136f, 0.0690970f, 0.9195400f, 0.0113612f, 0.0163916f, 0.0880132f, 0.8955950f },
};
static void mat3(const float *m, float *c) {
    float r = m[0] * c[0] + m[1] * c[1] + m[2] * c[2], g = m[3] * c[0] + m[4] * c[1] + m[5] * c[2], b = m[6] * c[0] + m[7] * c[1] + m[8] * c[2];
    c[0] = r; c[1] = g; c[2] = b;
}
void ci_convert_rgb(float *c, ci_space from, ci_space to) {
    if (ci_space_eq(from, to)) return;
    if (from.gray) c[1] = c[2] = c[0];
    for (int k = 0; k < 3; k++) c[k] = ci_trc_decode(from.trc, c[k]);
    if (from.prim != to.prim) { mat3(M_TO_SRGB[from.prim], c); mat3(M_FROM_SRGB[to.prim], c); }
    if (to.gray) { float l = 0.2126f * c[0] + 0.7152f * c[1] + 0.0722f * c[2]; c[0] = c[1] = c[2] = l; }
    for (int k = 0; k < 3; k++) c[k] = ci_trc_encode(to.trc, c[k]);
}
void ci_convert(float *px, size_t n, ci_space from, ci_space to) {
    if (ci_space_eq(from, to)) return;
    /* 8-bit sRGB sources hit a small set of values: a lookup table for the common sRGB <-> linear cases */
    for (size_t i = 0; i < n; i++) {
        float *p = px + i * 4, a = p[3];
        if (a <= 0) { if (!from.gray && !to.gray) continue; }
        float c[3] = { p[0], p[1], p[2] };
        if (a > 0 && a != 1) for (int k = 0; k < 3; k++) c[k] /= a;
        ci_convert_rgb(c, from, to);
        if (a != 1) for (int k = 0; k < 3; k++) c[k] *= a;
        p[0] = c[0]; p[1] = c[1]; p[2] = c[2];
    }
}
void ci_unpremul(float *p) { if (p[3] > 0 && p[3] != 1) { p[0] /= p[3]; p[1] /= p[3]; p[2] /= p[3]; } }
void ci_premul(float *p) { if (p[3] != 1) { p[0] *= p[3]; p[1] *= p[3]; p[2] *= p[3]; } }

/* ================= render context and cache ================= */
ci_rctx ci_rctx_default(void) { ci_rctx r = { 1, ci_space_linear, 0, NULL, nil }; return r; }
struct ci_cache { pthread_mutex_t m; void *d; };    /* d: NSMutableDictionary (retained), keyed by the node's key object */
ci_cache *ci_cache_new(void) {
    ci_cache *c = calloc(1, sizeof *c);
    pthread_mutexattr_t a; pthread_mutexattr_init(&a); pthread_mutexattr_settype(&a, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&c->m, &a);
    c->d = (__bridge_retained void *)[NSMutableDictionary dictionary];
    return c;
}
void ci_cache_free(ci_cache *c) { if (!c) return; CFBridgingRelease(c->d); pthread_mutex_destroy(&c->m); free(c); }
id ci_cache_get(const ci_rctx *rc, id key, id (^make)(void)) {
    if (!rc->cache) return make();
    ci_cache *c = rc->cache;
    pthread_mutex_lock(&c->m);                        /* recursive: make() may render nodes that use the cache */
    NSMutableDictionary *d = (__bridge NSMutableDictionary *)c->d;
    NSValue *k = [NSValue valueWithNonretainedObject:key];        /* identity: the key object outlives the render */
    id v = d[k];
    if (!v) { v = make() ?: [NSNull null]; d[k] = v; }
    pthread_mutex_unlock(&c->m);
    return v == [NSNull null] ? nil : v;
}
void ci_color_ws(CIColor *c, const ci_rctx *rc, float out[4]) {
    if (!c) { out[0] = out[1] = out[2] = out[3] = 0; return; }
    float v[3] = { (float)c.red, (float)c.green, (float)c.blue }, a = (float)c.alpha;
    if (rc->managed) ci_convert_rgb(v, ci_space_of(c.colorSpace), rc->ws);
    out[0] = v[0] * a; out[1] = v[1] * a; out[2] = v[2] * a; out[3] = a;
}

/* ================= buffers and sampling ================= */
BOOL ci_infinite(CGRect r) { return CGRectIsNull(r) || r.size.width > 1e8 || r.size.height > 1e8; }
CGRect ci_integral(CGRect r) { return ci_infinite(r) || CGRectIsEmpty(r) ? r : CGRectIntegral(r); }
float *ci_render_new(CIImage *im, CGRect r, const ci_rctx *rc) {
    size_t n = (size_t)r.size.width * (size_t)r.size.height * 4;
    float *b = calloc(n ? n : 4, sizeof(float));
    if (n) [im _render:r into:b ctx:rc];
    return b;
}
ci_buf ci_buf_render(CIImage *im, CGRect want, int pad, const ci_rctx *rc) {
    ci_buf b = { NULL, CGRectZero, 0, 0 };
    CGRect r = CGRectIntegral(want);
    CGRect e = im.extent;
    if (!ci_infinite(e)) r = CGRectIntersection(r, CGRectIntegral(CGRectInset(e, -pad, -pad)));
    if (CGRectIsNull(r) || CGRectIsEmpty(r)) return b;
    if (r.size.width * r.size.height > 400e6) { NSLog(@"isim: Core Image: region too large to render (%gx%g)", r.size.width, r.size.height); return b; }
    b.r = r; b.w = (int)r.size.width; b.h = (int)r.size.height;
    b.px = ci_render_new(im, r, rc);
    return b;
}
void ci_buf_free(ci_buf *b) { free(b->px); b->px = NULL; }
const float *ci_buf_at(const ci_buf *b, int x, int y) {
    if (!b->px) return NULL;
    int i = x - (int)b->r.origin.x, j = (int)(b->r.origin.y + b->r.size.height) - 1 - y;
    if (i < 0 || j < 0 || i >= b->w || j >= b->h) return NULL;
    return b->px + ((size_t)j * b->w + i) * 4;
}
static inline const float *px_at(const ci_buf *b, int i, int j) { return b->px + ((size_t)j * b->w + i) * 4; }
static float cubic_w(float x) {                 /* Catmull-Rom (B = 0, C = 0.5) */
    x = fabsf(x);
    if (x < 1) return (1.5f * x - 2.5f) * x * x + 1;
    if (x < 2) return ((-0.5f * x + 2.5f) * x - 4) * x + 2;
    return 0;
}
static void sample_impl(const ci_buf *b, double x, double y, int mode, int clamp, float out[4]) {
    out[0] = out[1] = out[2] = out[3] = 0;
    if (!b->px || !b->w || !b->h) return;
    double fx = x - b->r.origin.x - 0.5, fy = (b->r.origin.y + b->r.size.height) - y - 0.5;
    if (mode == CI_SAMPLE_NEAREST) {
        int i = (int)floor(fx + 0.5), j = (int)floor(fy + 0.5);
        if (clamp) { i = i < 0 ? 0 : i >= b->w ? b->w - 1 : i; j = j < 0 ? 0 : j >= b->h ? b->h - 1 : j; }
        else if (i < 0 || j < 0 || i >= b->w || j >= b->h) return;
        memcpy(out, px_at(b, i, j), 4 * sizeof(float));
        return;
    }
    int x0 = (int)floor(fx), y0 = (int)floor(fy);
    float ax = (float)(fx - x0), ay = (float)(fy - y0);
    if (mode == CI_SAMPLE_CUBIC) {
        for (int dy = -1; dy <= 2; dy++) {
            float wy = cubic_w(dy - ay);
            for (int dx = -1; dx <= 2; dx++) {
                int i = x0 + dx, j = y0 + dy;
                if (clamp) { i = i < 0 ? 0 : i >= b->w ? b->w - 1 : i; j = j < 0 ? 0 : j >= b->h ? b->h - 1 : j; }
                else if (i < 0 || j < 0 || i >= b->w || j >= b->h) continue;
                float w = wy * cubic_w(dx - ax); const float *p = px_at(b, i, j);
                for (int k = 0; k < 4; k++) out[k] += p[k] * w;
            }
        }
        return;
    }
    for (int dy = 0; dy < 2; dy++) for (int dx = 0; dx < 2; dx++) {
        int i = x0 + dx, j = y0 + dy;
        if (clamp) { i = i < 0 ? 0 : i >= b->w ? b->w - 1 : i; j = j < 0 ? 0 : j >= b->h ? b->h - 1 : j; }
        else if (i < 0 || j < 0 || i >= b->w || j >= b->h) continue;
        float w = (dx ? ax : 1 - ax) * (dy ? ay : 1 - ay);
        if (w == 0) continue;
        const float *p = px_at(b, i, j);
        for (int k = 0; k < 4; k++) out[k] += p[k] * w;
    }
}
void ci_sample(const ci_buf *b, double x, double y, int mode, float out[4]) { sample_impl(b, x, y, mode, 0, out); }
void ci_sample_clamped(const ci_buf *b, double x, double y, int mode, float out[4]) { sample_impl(b, x, y, mode, 1, out); }

/* Gaussian blur of a whole buffer (edges see transparent pixels); large sigmas use three box passes */
void ci_box_blur_buf(float *px, int w, int h, int rx, int ry) {
    if (w <= 0 || h <= 0) return;
    int n = w > h ? w : h;
    float *line = malloc(sizeof(float) * 4 * (size_t)(n + 1)), *acc = malloc(sizeof(float) * 4 * (size_t)(n + 1));
    if (rx > 0) for (int y = 0; y < h; y++) {
        float *row = px + (size_t)y * w * 4;
        memset(acc, 0, sizeof(float) * 4);
        for (int x = 0; x < w; x++) for (int k = 0; k < 4; k++) acc[(x + 1) * 4 + k] = acc[x * 4 + k] + row[x * 4 + k];
        float inv = 1.0f / (2 * rx + 1);
        for (int x = 0; x < w; x++) {
            int a = x - rx, b = x + rx + 1; a = a < 0 ? 0 : a; b = b > w ? w : b;
            for (int k = 0; k < 4; k++) line[x * 4 + k] = (acc[b * 4 + k] - acc[a * 4 + k]) * inv;
        }
        memcpy(row, line, sizeof(float) * 4 * w);
    }
    if (ry > 0) for (int x = 0; x < w; x++) {
        memset(acc, 0, sizeof(float) * 4);
        for (int y = 0; y < h; y++) for (int k = 0; k < 4; k++) acc[(y + 1) * 4 + k] = acc[y * 4 + k] + px[((size_t)y * w + x) * 4 + k];
        float inv = 1.0f / (2 * ry + 1);
        for (int y = 0; y < h; y++) {
            int a = y - ry, b = y + ry + 1; a = a < 0 ? 0 : a; b = b > h ? h : b;
            for (int k = 0; k < 4; k++) px[((size_t)y * w + x) * 4 + k] = (acc[b * 4 + k] - acc[a * 4 + k]) * inv;
        }
    }
    free(line); free(acc);
}
void ci_blur_buf(float *px, int w, int h, double sigma) {
    if (sigma <= 0 || w <= 0 || h <= 0) return;
    if (sigma > 24) {                               /* three box blurs approximate the Gaussian (central limit) */
        double wi = sqrt(12 * sigma * sigma / 3 + 1); int r = (int)floor((wi - 1) / 2);
        for (int i = 0; i < 3; i++) ci_box_blur_buf(px, w, h, r, r);
        return;
    }
    int pad = (int)ceil(3 * sigma), n = 2 * pad + 1;
    float *k = malloc(sizeof(float) * (size_t)n); double sum = 0;
    for (int i = 0; i < n; i++) { double d = i - pad; k[i] = (float)exp(-d * d / (2 * sigma * sigma)); sum += k[i]; }
    for (int i = 0; i < n; i++) k[i] /= (float)sum;
    int m = w > h ? w : h;
    float *t = malloc(sizeof(float) * 4 * (size_t)m);
    for (int y = 0; y < h; y++) {
        float *row = px + (size_t)y * w * 4;
        for (int x = 0; x < w; x++) {
            float a[4] = { 0 };
            int q0 = x - pad < 0 ? pad - x : 0, q1 = x + pad >= w ? pad + (w - 1 - x) : 2 * pad;
            for (int q = q0; q <= q1; q++) { const float *p = row + (x + q - pad) * 4; float kw = k[q]; a[0] += p[0] * kw; a[1] += p[1] * kw; a[2] += p[2] * kw; a[3] += p[3] * kw; }
            memcpy(t + x * 4, a, sizeof a);
        }
        memcpy(row, t, sizeof(float) * 4 * w);
    }
    for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {
            float a[4] = { 0 };
            int q0 = y - pad < 0 ? pad - y : 0, q1 = y + pad >= h ? pad + (h - 1 - y) : 2 * pad;
            for (int q = q0; q <= q1; q++) { const float *p = px + ((size_t)(y + q - pad) * w + x) * 4; float kw = k[q]; a[0] += p[0] * kw; a[1] += p[1] * kw; a[2] += p[2] * kw; a[3] += p[3] * kw; }
            memcpy(t + y * 4, a, sizeof a);
        }
        for (int y = 0; y < h; y++) memcpy(px + ((size_t)y * w + x) * 4, t + y * 4, sizeof(float) * 4);
    }
    free(t); free(k);
}

/* ================= formats ================= */
CIFormat kCIFormatARGB8 = 22, kCIFormatBGRA8 = 23, kCIFormatRGBA8 = 24, kCIFormatABGR8 = 25, kCIFormatRGBAf = 34;
CIFormat kCIFormatRGBA16 = 40, kCIFormatRGBAh = 41, kCIFormatRGBX16 = 42, kCIFormatRGBXh = 43, kCIFormatRGBXf = 44, kCIFormatRGBX8 = 45;
CIFormat kCIFormatA8 = 50, kCIFormatA16 = 51, kCIFormatAh = 52, kCIFormatAf = 53, kCIFormatR8 = 54, kCIFormatR16 = 55, kCIFormatRh = 56,
    kCIFormatRf = 57, kCIFormatRG8 = 58, kCIFormatRG16 = 59, kCIFormatRGh = 60, kCIFormatRGf = 61, kCIFormatL8 = 62, kCIFormatL16 = 63,
    kCIFormatLh = 64, kCIFormatLf = 65, kCIFormatLA8 = 66, kCIFormatLA16 = 67, kCIFormatLAh = 68, kCIFormatLAf = 69;
/* channel letters: R G B A, X padding, L luminance; component: 1 byte, 2 (16-bit int), 'h' half, 'f' float */
static BOOL fmt_desc(CIFormat f, const char **chans, char *comp) {
    struct { CIFormat *f; const char *c; char t; } tab[] = {
        { &kCIFormatARGB8, "ARGB", 1 }, { &kCIFormatBGRA8, "BGRA", 1 }, { &kCIFormatRGBA8, "RGBA", 1 }, { &kCIFormatABGR8, "ABGR", 1 },
        { &kCIFormatRGBAf, "RGBA", 'f' }, { &kCIFormatRGBA16, "RGBA", 2 }, { &kCIFormatRGBAh, "RGBA", 'h' },
        { &kCIFormatRGBX8, "RGBX", 1 }, { &kCIFormatRGBX16, "RGBX", 2 }, { &kCIFormatRGBXh, "RGBX", 'h' }, { &kCIFormatRGBXf, "RGBX", 'f' },
        { &kCIFormatA8, "A", 1 }, { &kCIFormatA16, "A", 2 }, { &kCIFormatAh, "A", 'h' }, { &kCIFormatAf, "A", 'f' },
        { &kCIFormatR8, "R", 1 }, { &kCIFormatR16, "R", 2 }, { &kCIFormatRh, "R", 'h' }, { &kCIFormatRf, "R", 'f' },
        { &kCIFormatRG8, "RG", 1 }, { &kCIFormatRG16, "RG", 2 }, { &kCIFormatRGh, "RG", 'h' }, { &kCIFormatRGf, "RG", 'f' },
        { &kCIFormatL8, "L", 1 }, { &kCIFormatL16, "L", 2 }, { &kCIFormatLh, "L", 'h' }, { &kCIFormatLf, "L", 'f' },
        { &kCIFormatLA8, "LA", 1 }, { &kCIFormatLA16, "LA", 2 }, { &kCIFormatLAh, "LA", 'h' }, { &kCIFormatLAf, "LA", 'f' },
    };
    for (size_t i = 0; i < sizeof tab / sizeof *tab; i++) if (*tab[i].f == f) { *chans = tab[i].c; *comp = tab[i].t; return YES; }
    return NO;
}
BOOL ci_fmt_of(CIFormat f, ci_fmt *o) {
    const char *c; char t;
    if (!fmt_desc(f, &c, &t)) return NO;
    memset(o, 0, sizeof *o);
    o->ch = (int)strlen(c);
    o->bytes = t == 1 ? 1 : t == 2 || t == 'h' ? 2 : 4;
    o->isfloat = t == 'h' || t == 'f'; o->half = t == 'h';
    for (int i = 0; i < o->ch; i++) {
        o->order[i] = c[i] == 'R' ? 0 : c[i] == 'G' ? 1 : c[i] == 'B' ? 2 : c[i] == 'A' ? 3 : c[i] == 'L' ? 5 : 4;
        if (c[i] == 'A') o->alpha = 1;
        if (c[i] == 'L') o->gray = 1;
    }
    o->premul = o->alpha;
    return YES;
}
uint16_t ci_f2h(float f) {
    union { float f; uint32_t u; } v = { f };
    uint32_t x = v.u, sign = (x >> 16) & 0x8000; int e = (int)((x >> 23) & 0xff) - 127 + 15; uint32_t m = x & 0x7fffff;
    if (((x >> 23) & 0xff) == 0xff) return (uint16_t)(sign | 0x7c00 | (m ? 0x200 : 0));
    if (e >= 31) return (uint16_t)(sign | 0x7c00);
    if (e <= 0) { if (e < -10) return (uint16_t)sign; m |= 0x800000; int s = 14 - e; uint32_t r = m >> s; if ((m >> (s - 1)) & 1) r++; return (uint16_t)(sign | r); }
    uint32_t r = (uint32_t)(sign | (uint32_t)e << 10 | m >> 13);
    if (m & 0x1000) r++;
    return (uint16_t)r;
}
float ci_h2f(uint16_t h) {
    uint32_t sign = (uint32_t)(h & 0x8000) << 16, e = (h >> 10) & 0x1f, m = h & 0x3ff, u;
    if (e == 0) { if (!m) u = sign; else { int s = -1; do { s++; m <<= 1; } while (!(m & 0x400)); m &= 0x3ff; u = sign | (uint32_t)(127 - 15 - s) << 23 | m << 13; } }
    else if (e == 31) u = sign | 0x7f800000 | m << 13;
    else u = sign | (e - 15 + 127) << 23 | m << 13;
    union { uint32_t u; float f; } v = { u };
    return v.f;
}
static float get_comp(const uint8_t *p, const ci_fmt *f) {
    if (f->bytes == 1) return p[0] / 255.0f;
    if (f->half) { uint16_t h; memcpy(&h, p, 2); return ci_h2f(h); }
    if (f->bytes == 2) { uint16_t v; memcpy(&v, p, 2); return v / 65535.0f; }
    float v; memcpy(&v, p, 4); return v;
}
static void put_comp(uint8_t *p, const ci_fmt *f, float v) {
    if (f->bytes == 1) { p[0] = (uint8_t)lroundf(ci_clamp01(v) * 255); return; }
    if (f->half) { uint16_t h = ci_f2h(v); memcpy(p, &h, 2); return; }
    if (f->bytes == 2) { uint16_t u = (uint16_t)lroundf(ci_clamp01(v) * 65535); memcpy(p, &u, 2); return; }
    memcpy(p, &v, 4);
}
void ci_store(const float *src, int w, int h, void *dst, ptrdiff_t rb, CIFormat fmt) {
    ci_fmt f;
    if (!ci_fmt_of(fmt, &f)) { NSLog(@"isim: Core Image: unsupported format %d", fmt); return; }
    for (int y = 0; y < h; y++) {
        uint8_t *row = (uint8_t *)dst + y * rb;
        for (int x = 0; x < w; x++) {
            const float *p = src + ((size_t)y * w + x) * 4;
            float a = p[3], c[4] = { p[0], p[1], p[2], a };
            if (!f.alpha) { if (a > 0 && a != 1) { c[0] /= a; c[1] /= a; c[2] /= a; } }
            if (!f.isfloat) {        /* integer formats hold 0...1: keep premultiplied color <= alpha */
                a = ci_clamp01(a); c[3] = a;
                if (f.alpha) for (int k = 0; k < 3; k++) c[k] = fminf(ci_clamp01(c[k]), a);
            }
            uint8_t *o = row + (size_t)x * f.ch * f.bytes;
            for (int i = 0; i < f.ch; i++) {
                int s = f.order[i];
                float v = s < 4 ? c[s] : s == 5 ? 0.2126f * c[0] + 0.7152f * c[1] + 0.0722f * c[2] : 1.0f;
                put_comp(o + i * f.bytes, &f, v);
            }
        }
    }
}
float *ci_load(const void *src, int w, int h, ptrdiff_t rb, CIFormat fmt, int premultiplied) {
    ci_fmt f;
    if (!ci_fmt_of(fmt, &f) || w <= 0 || h <= 0) return NULL;
    float *out = malloc(sizeof(float) * 4 * (size_t)w * h);
    for (int y = 0; y < h; y++) {
        const uint8_t *row = (const uint8_t *)src + y * rb;
        for (int x = 0; x < w; x++) {
            float c[4] = { 0, 0, 0, 1 };
            const uint8_t *p = row + (size_t)x * f.ch * f.bytes;
            int hasA = 0;
            for (int i = 0; i < f.ch; i++) {
                float v = get_comp(p + i * f.bytes, &f); int s = f.order[i];
                if (s < 3) c[s] = v; else if (s == 3) { c[3] = v; hasA = 1; } else if (s == 5) c[0] = c[1] = c[2] = v;
            }
            if (f.ch == 1 && f.order[0] == 3) c[0] = c[1] = c[2] = 0;          /* alpha-only: black with alpha */
            if (hasA && !premultiplied) { c[0] *= c[3]; c[1] *= c[3]; c[2] *= c[3]; }
            memcpy(out + ((size_t)y * w + x) * 4, c, sizeof c);
        }
    }
    return out;
}

/* ================= CIVector / CIColor ================= */
@implementation CIVector { CGFloat _v[16]; size_t _n; CGFloat *_big; }
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)vectorWithValues:(const CGFloat *)v count:(size_t)n { return [[self alloc] initWithValues:v count:n]; }
+ (instancetype)vectorWithX:(CGFloat)x { return [[self alloc] initWithX:x]; }
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y { return [[self alloc] initWithX:x Y:y]; }
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z { return [[self alloc] initWithX:x Y:y Z:z]; }
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w { return [[self alloc] initWithX:x Y:y Z:z W:w]; }
+ (instancetype)vectorWithCGPoint:(CGPoint)p { return [[self alloc] initWithCGPoint:p]; }
+ (instancetype)vectorWithCGRect:(CGRect)r { return [[self alloc] initWithCGRect:r]; }
+ (instancetype)vectorWithCGAffineTransform:(CGAffineTransform)t { return [[self alloc] initWithCGAffineTransform:t]; }
+ (instancetype)vectorWithString:(NSString *)s { return [[self alloc] initWithString:s]; }
- (instancetype)initWithValues:(const CGFloat *)v count:(size_t)n {
    if ((self = [super init])) {
        _n = n;
        if (n > 16) { _big = malloc(sizeof(CGFloat) * n); memcpy(_big, v, sizeof(CGFloat) * n); }
        else for (size_t i = 0; i < n; i++) _v[i] = v[i];
    }
    return self;
}
- (void)dealloc { free(_big); }
- (instancetype)initWithX:(CGFloat)x { CGFloat v[] = { x }; return [self initWithValues:v count:1]; }
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y { CGFloat v[] = { x, y }; return [self initWithValues:v count:2]; }
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z { CGFloat v[] = { x, y, z }; return [self initWithValues:v count:3]; }
- (instancetype)initWithX:(CGFloat)x Y:(CGFloat)y Z:(CGFloat)z W:(CGFloat)w { CGFloat v[] = { x, y, z, w }; return [self initWithValues:v count:4]; }
- (instancetype)initWithCGPoint:(CGPoint)p { return [self initWithX:p.x Y:p.y]; }
- (instancetype)initWithCGRect:(CGRect)r { return [self initWithX:r.origin.x Y:r.origin.y Z:r.size.width W:r.size.height]; }
- (instancetype)initWithCGAffineTransform:(CGAffineTransform)t { CGFloat v[] = { t.a, t.b, t.c, t.d, t.tx, t.ty }; return [self initWithValues:v count:6]; }
- (instancetype)initWithString:(NSString *)s {
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[] \t\n"]];
    NSMutableData *d = [NSMutableData data];
    for (NSString *p in [t componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,\t"]]) {
        if (!p.length) continue;
        CGFloat v = p.doubleValue; [d appendBytes:&v length:sizeof v];
    }
    return [self initWithValues:d.bytes count:d.length / sizeof(CGFloat)];
}
- (const CGFloat *)vals { return _big ?: _v; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:self.stringRepresentation forKey:@"CIVector"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithString:[c decodeObjectOfClass:[NSString class] forKey:@"CIVector"] ?: @"[]"]; }
- (CGFloat)valueAtIndex:(size_t)i { return i < _n ? self.vals[i] : 0; }
- (size_t)count { return _n; }
- (CGFloat)X { return [self valueAtIndex:0]; } - (CGFloat)Y { return [self valueAtIndex:1]; }
- (CGFloat)Z { return [self valueAtIndex:2]; } - (CGFloat)W { return [self valueAtIndex:3]; }
- (CGPoint)CGPointValue { return CGPointMake(self.X, self.Y); }
- (CGRect)CGRectValue { return CGRectMake(self.X, self.Y, self.Z, self.W); }
- (CGAffineTransform)CGAffineTransformValue {
    const CGFloat *v = self.vals;
    return _n >= 6 ? CGAffineTransformMake(v[0], v[1], v[2], v[3], v[4], v[5]) : CGAffineTransformIdentity;
}
- (NSString *)stringRepresentation {
    NSMutableArray *a = [NSMutableArray array];
    for (size_t i = 0; i < _n; i++) [a addObject:[NSString stringWithFormat:@"%g", self.vals[i]]];
    return [NSString stringWithFormat:@"[%@]", [a componentsJoinedByString:@" "]];
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[CIVector class]] || [o count] != _n) return NO;
    for (size_t i = 0; i < _n; i++) if ([o valueAtIndex:i] != self.vals[i]) return NO;
    return YES;
}
- (NSUInteger)hash { return _n ^ (NSUInteger)(self.X * 31 + self.Y * 17); }
- (NSString *)description { return [NSString stringWithFormat:@"<CIVector %p> %@", self, self.stringRepresentation]; }
@end

@implementation CIColor { CGFloat _c[4]; id _cs; }
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)colorWithCGColor:(CGColorRef)c { return [[self alloc] initWithCGColor:c]; }
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a { return [[self alloc] initWithRed:r green:g blue:b alpha:a]; }
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b { return [[self alloc] initWithRed:r green:g blue:b]; }
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a colorSpace:(CGColorSpaceRef)cs {
    return [[self alloc] initWithRed:r green:g blue:b alpha:a colorSpace:cs];
}
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b colorSpace:(CGColorSpaceRef)cs { return [[self alloc] initWithRed:r green:g blue:b colorSpace:cs]; }
+ (instancetype)colorWithString:(NSString *)s {
    CIVector *v = [CIVector vectorWithString:s];
    return [self colorWithRed:[v valueAtIndex:0] green:[v valueAtIndex:1] blue:[v valueAtIndex:2] alpha:v.count > 3 ? [v valueAtIndex:3] : 1];
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    if ((self = [super init])) { _c[0] = r; _c[1] = g; _c[2] = b; _c[3] = a; }
    return self;
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b { return [self initWithRed:r green:g blue:b alpha:1]; }
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a colorSpace:(CGColorSpaceRef)cs {
    if (!cs || CGColorSpaceGetModel(cs) != kCGColorSpaceModelRGB) return nil;
    if ((self = [self initWithRed:r green:g blue:b alpha:a])) _cs = (__bridge id)cs;
    return self;
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b colorSpace:(CGColorSpaceRef)cs { return [self initWithRed:r green:g blue:b alpha:1 colorSpace:cs]; }
- (instancetype)initWithCGColor:(CGColorRef)c { double v[4]; isim_cg_color_rgba(c, v); return [self initWithRed:v[0] green:v[1] blue:v[2] alpha:v[3]]; }
- (instancetype)initWithColor:(id)color { return [self initWithCGColor:[color CGColor]]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:self.stringRepresentation forKey:@"CIColor"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    CIVector *v = [CIVector vectorWithString:[c decodeObjectOfClass:[NSString class] forKey:@"CIColor"] ?: @"[0 0 0 1]"];
    return [self initWithRed:[v valueAtIndex:0] green:[v valueAtIndex:1] blue:[v valueAtIndex:2] alpha:v.count > 3 ? [v valueAtIndex:3] : 1];
}
- (size_t)numberOfComponents { return 4; }
- (const CGFloat *)components { return _c; }
- (CGFloat)red { return _c[0]; } - (CGFloat)green { return _c[1]; } - (CGFloat)blue { return _c[2]; } - (CGFloat)alpha { return _c[3]; }
- (CGColorSpaceRef)colorSpace { return _cs ? (__bridge CGColorSpaceRef)_cs : ci_cgspace_named(kCGColorSpaceSRGB); }
- (NSString *)stringRepresentation { return [NSString stringWithFormat:@"%g %g %g %g", _c[0], _c[1], _c[2], _c[3]]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[CIColor class]]) return NO;
    CIColor *c = o;
    return c.red == _c[0] && c.green == _c[1] && c.blue == _c[2] && c.alpha == _c[3] && ci_space_eq(ci_space_of(c.colorSpace), ci_space_of(self.colorSpace));
}
- (NSUInteger)hash { return (NSUInteger)(_c[0] * 255) << 24 ^ (NSUInteger)(_c[1] * 255) << 16 ^ (NSUInteger)(_c[2] * 255) << 8 ^ (NSUInteger)(_c[3] * 255); }
- (NSString *)description { return [NSString stringWithFormat:@"<CIColor %p> (%@)", self, self.stringRepresentation]; }
+ (CIColor *)blackColor { return [self colorWithRed:0 green:0 blue:0]; }
+ (CIColor *)whiteColor { return [self colorWithRed:1 green:1 blue:1]; }
+ (CIColor *)grayColor { return [self colorWithRed:0.5 green:0.5 blue:0.5]; }
+ (CIColor *)redColor { return [self colorWithRed:1 green:0 blue:0]; }
+ (CIColor *)greenColor { return [self colorWithRed:0 green:1 blue:0]; }
+ (CIColor *)blueColor { return [self colorWithRed:0 green:0 blue:1]; }
+ (CIColor *)cyanColor { return [self colorWithRed:0 green:1 blue:1]; }
+ (CIColor *)magentaColor { return [self colorWithRed:1 green:0 blue:1]; }
+ (CIColor *)yellowColor { return [self colorWithRed:1 green:1 blue:0]; }
+ (CIColor *)clearColor { return [self colorWithRed:0 green:0 blue:0 alpha:0]; }
@end

/* ================= node classes ================= */
CI_HIDDEN @interface __CIOpImage : CIImage { @public ci_render_fn _fn; }
@end
CI_HIDDEN @interface __CIBitmapImage : CIImage {
    @public float *_px; int _w, _h; ci_space _space; BOOL _raw;
    pthread_mutex_t _m; float *_conv; ci_space _convSpace;
    /* lazy sources: a CGImage (decoded on first render) or an image provider */
    id _provider, _providerInfo; CIFormat _providerFormat;
}
@end
CI_HIDDEN @interface __CITransformImage : CIImage { @public CIImage *_in; CGAffineTransform _t; BOOL _hq; }
@end
CI_HIDDEN @interface __CIProxyImage : CIImage { @public CIImage *_in; }
@end

CIImage *ci_op(CGRect extent, ci_render_fn fn) {
    __CIOpImage *o = [__CIOpImage new]; o->_fn = fn; o.isimExtent = extent; return o;
}
CIImage *ci_empty(void) { return [CIImage emptyImage]; }
CIImage *ci_map(CIImage *in, void (^fn)(float *p)) {
    return ci_op(in.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [in _render:r into:out ctx:rc];
        size_t n = (size_t)r.size.width * (size_t)r.size.height;
        for (size_t i = 0; i < n; i++) fn(out + i * 4);
    });
}
CIImage *ci_map_rgb(CIImage *in, void (^fn)(float *c)) {
    return ci_map(in, ^(float *p) {
        float a = p[3];
        if (a <= 0) return;
        float c[3] = { p[0] / a, p[1] / a, p[2] / a };
        fn(c);
        p[0] = c[0] * a; p[1] = c[1] * a; p[2] = c[2] * a;
    });
}
CIImage *ci_map_xy(CIImage *in, CGRect extent, void (^fn)(double x, double y, float *p)) {
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [in _render:r into:out ctx:rc];
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) fn(ci_px_x(r, i), ci_px_y(r, j), out + ((size_t)j * W + i) * 4);
    });
}
CIImage *ci_gen(CGRect extent, void (^fn)(double x, double y, float *out, const ci_rctx *rc)) {
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) fn(ci_px_x(r, i), ci_px_y(r, j), out + ((size_t)j * W + i) * 4, rc);
    });
}
CIImage *ci_combine(CIImage *a, CIImage *b, CGRect extent, void (^fn)(float *out, const float *pa, const float *pb)) {
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        float *fa = ci_render_new(a, r, rc), *fb = ci_render_new(b, r, rc);
        size_t n = (size_t)r.size.width * (size_t)r.size.height;
        for (size_t i = 0; i < n; i++) fn(out + i * 4, fa + i * 4, fb + i * 4);
        free(fa); free(fb);
    });
}
/* the source region a warp needs: map a grid over the output rect */
static CGRect warp_roi(CGRect r, void (^src)(double, double, double *, double *)) {
    double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
    int n = 16;
    for (int j = 0; j <= n; j++) for (int i = 0; i <= n; i++) {
        double sx, sy; src(r.origin.x + r.size.width * i / n, r.origin.y + r.size.height * j / n, &sx, &sy);
        if (!isfinite(sx) || !isfinite(sy)) continue;
        x0 = fmin(x0, sx); y0 = fmin(y0, sy); x1 = fmax(x1, sx); y1 = fmax(y1, sy);
    }
    if (x0 > x1) return CGRectNull;
    /* interior extremes (twirls, wraps) can lie between grid points: grow by a fraction */
    double gx = (x1 - x0) * 0.1 + 4, gy = (y1 - y0) * 0.1 + 4;
    return CGRectMake(x0 - gx, y0 - gy, x1 - x0 + 2 * gx, y1 - y0 + 2 * gy);
}
CIImage *ci_warp_mode(CIImage *in, CGRect extent, int clampEdges, void (^src)(double, double, double *, double *)) {
    return ci_op(extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        CGRect roi = warp_roi(r, src);
        if (CGRectIsNull(roi)) return;
        CGRect e = in.extent;
        if (!ci_infinite(e)) roi = CGRectIntersection(roi, CGRectInset(e, -2, -2));
        else if (roi.size.width * roi.size.height > 64e6) {   /* infinite input and a huge region: cap around the output */
            roi = CGRectIntersection(roi, CGRectInset(r, -4096, -4096));
        }
        if (CGRectIsNull(roi) || CGRectIsEmpty(roi)) return;
        ci_buf b = ci_buf_render(in, roi, 2, rc);
        int W = (int)r.size.width, H = (int)r.size.height, mode = in.isimSampling;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            double sx, sy; src(ci_px_x(r, i), ci_px_y(r, j), &sx, &sy);
            float *o = out + ((size_t)j * W + i) * 4;
            if (!isfinite(sx) || !isfinite(sy)) { o[0] = o[1] = o[2] = o[3] = 0; continue; }
            if (clampEdges) ci_sample_clamped(&b, sx, sy, mode, o); else ci_sample(&b, sx, sy, mode, o);
        }
        ci_buf_free(&b);
    });
}
CIImage *ci_warp(CIImage *in, CGRect extent, void (^src)(double, double, double *, double *)) { return ci_warp_mode(in, extent, 0, src); }

CIImage *ci_bitmap(float *px, int w, int h, CGRect extent, ci_space space, BOOL raw) {
    __CIBitmapImage *b = [__CIBitmapImage new];
    b->_px = px; b->_w = w; b->_h = h; b->_space = space; b->_raw = raw;
    b.isimExtent = extent;
    return b;
}
CIImage *ci_bitmap_rgba8(const unsigned char *px, int w, int h, size_t bpr, int premultiplied, ci_space space) {
    float *f = malloc(sizeof(float) * 4 * (size_t)w * h);
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        const unsigned char *p = px + (size_t)y * bpr + (size_t)x * 4; float *o = f + ((size_t)y * w + x) * 4;
        float a = p[3] / 255.0f;
        for (int k = 0; k < 3; k++) o[k] = premultiplied ? p[k] / 255.0f : p[k] / 255.0f * a;
        o[3] = a;
    }
    return ci_bitmap(f, w, h, CGRectMake(0, 0, w, h), space, NO);
}

/* ================= CIImage ================= */
CIImageOption const kCIImageColorSpace = @"kCIImageColorSpace", kCIImageToneMapHDRtoSDR = @"kCIImageToneMapHDRtoSDR",
    kCIImageExpandToHDR = @"kCIImageExpandToHDR", kCIImageNearestSampling = @"kCIImageNearestSampling",
    kCIImageCacheImmediately = @"kCIImageCacheImmediately", kCIImageProperties = @"kCIImageProperties",
    kCIImageApplyOrientationProperty = @"kCIImageApplyOrientationProperty", kCIImageAuxiliaryDepth = @"kCIImageAuxiliaryDepth",
    kCIImageAuxiliaryDisparity = @"kCIImageAuxiliaryDisparity", kCIImageAuxiliaryPortraitEffectsMatte = @"kCIImageAuxiliaryPortraitEffectsMatte",
    kCIImageAuxiliarySemanticSegmentationSkinMatte = @"kCIImageAuxiliarySemanticSegmentationSkinMatte",
    kCIImageAuxiliarySemanticSegmentationHairMatte = @"kCIImageAuxiliarySemanticSegmentationHairMatte",
    kCIImageAuxiliarySemanticSegmentationTeethMatte = @"kCIImageAuxiliarySemanticSegmentationTeethMatte",
    kCIImageAuxiliarySemanticSegmentationGlassesMatte = @"kCIImageAuxiliarySemanticSegmentationGlassesMatte",
    kCIImageAuxiliarySemanticSegmentationSkyMatte = @"kCIImageAuxiliarySemanticSegmentationSkyMatte",
    kCIImageAuxiliaryHDRGainMap = @"kCIImageAuxiliaryHDRGainMap", kCIImageContentHeadroom = @"kCIImageContentHeadroom",
    kCIImageContentAverageLightLevel = @"kCIImageContentAverageLightLevel", kCIImageApplyCleanAperture = @"kCIImageApplyCleanAperture";
CIDynamicRangeOption const kCIDynamicRangeStandard = @"standard", kCIDynamicRangeConstrainedHigh = @"constrainedHigh", kCIDynamicRangeHigh = @"high";
NSString *const kCIImageProviderTileSize = @"tile_size", *const kCIImageProviderUserInfo = @"user_info";

static CIImage *with_options(CIImage *im, NSDictionary *o);

@implementation CIImage
@synthesize isimExtent = _isimExtent;
+ (BOOL)supportsSecureCoding { return YES; }
+ (CIImage *)imageWithCGImage:(CGImageRef)image { return [[self alloc] initWithCGImage:image]; }
+ (CIImage *)imageWithCGImage:(CGImageRef)image options:(NSDictionary *)o { return [[self alloc] initWithCGImage:image options:o]; }
+ (CIImage *)imageWithCGImageSource:(CGImageSourceRef)s index:(size_t)i options:(NSDictionary *)o { return [[self alloc] initWithCGImageSource:s index:i options:o]; }
+ (CIImage *)imageWithData:(NSData *)d { return [[self alloc] initWithData:d]; }
+ (CIImage *)imageWithData:(NSData *)d options:(NSDictionary *)o { return [[self alloc] initWithData:d options:o]; }
+ (CIImage *)imageWithContentsOfURL:(NSURL *)url { return [[self alloc] initWithContentsOfURL:url]; }
+ (CIImage *)imageWithContentsOfURL:(NSURL *)url options:(NSDictionary *)o { return [[self alloc] initWithContentsOfURL:url options:o]; }
+ (CIImage *)imageWithColor:(CIColor *)c { return [[self alloc] initWithColor:c]; }
+ (CIImage *)imageWithImageProvider:(id)p size:(size_t)w :(size_t)h format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    return [[self alloc] initWithImageProvider:p size:w :h format:f colorSpace:cs options:o];
}
+ (CIImage *)emptyImage { CIImage *i = [CIImage new]; return i; }
+ (CIImage *)imageWithBitmapData:(NSData *)d bytesPerRow:(size_t)bpr size:(CGSize)s format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    return [[self alloc] initWithBitmapData:d bytesPerRow:bpr size:s format:f colorSpace:cs];
}
#define SOLID(sel, r, g, b, a) + (CIImage *)sel { return [self imageWithColor:[CIColor colorWithRed:r green:g blue:b alpha:a]]; }
SOLID(blackImage, 0, 0, 0, 1) SOLID(whiteImage, 1, 1, 1, 1) SOLID(grayImage, 0.5, 0.5, 0.5, 1) SOLID(redImage, 1, 0, 0, 1)
SOLID(greenImage, 0, 1, 0, 1) SOLID(blueImage, 0, 0, 1, 1) SOLID(cyanImage, 0, 1, 1, 1) SOLID(magentaImage, 1, 0, 1, 1)
SOLID(yellowImage, 1, 1, 0, 1) SOLID(clearImage, 0, 0, 0, 0)
- (instancetype)init { if ((self = [super init])) _isimExtent = CGRectZero; return self; }

- (instancetype)initWithCGImage:(CGImageRef)image { return [self initWithCGImage:image options:nil]; }
- (instancetype)initWithCGImage:(CGImageRef)image options:(NSDictionary *)o {
    if (!image) return (id)[CIImage emptyImage];
    size_t w = CGImageGetWidth(image), h = CGImageGetHeight(image);
    __CIBitmapImage *b = [__CIBitmapImage new];
    b->_w = (int)w; b->_h = (int)h;
    b.isimCGImage = (__bridge id)image;
    CGColorSpaceRef cs = CGImageGetColorSpace(image);
    b->_space = ci_space_of(cs);
    b.isimCGColorSpace = cs ? (__bridge id)cs : (__bridge id)ci_cgspace_named(kCGColorSpaceSRGB);
    b.isimExtent = CGRectMake(0, 0, w, h);
    b.isimOpaque = CGImageGetAlphaInfo(image) == kCGImageAlphaNone || CGImageGetAlphaInfo(image) == kCGImageAlphaNoneSkipLast ||
                   CGImageGetAlphaInfo(image) == kCGImageAlphaNoneSkipFirst;
    return (id)with_options(b, o);
}
- (instancetype)initWithCGImageSource:(CGImageSourceRef)s index:(size_t)i options:(NSDictionary *)o {
    CGImageRef im = s ? CGImageSourceCreateImageAtIndex(s, i, NULL) : NULL;
    if (!im) return (id)[CIImage emptyImage];
    NSDictionary *props = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(s, i, NULL)) ?: @{};
    NSMutableDictionary *opts = [o mutableCopy] ?: [NSMutableDictionary dictionary];
    if (!opts[kCIImageProperties]) opts[kCIImageProperties] = props;
    CIImage *r = [self initWithCGImage:im options:opts];
    CGImageRelease(im);
    return r;
}
- (instancetype)initWithData:(NSData *)d { return [self initWithData:d options:nil]; }
- (instancetype)initWithData:(NSData *)d options:(NSDictionary *)o {
    if (!d.length) return nil;
    CGImageSourceRef s = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
    if (!s || CGImageSourceGetCount(s) == 0) { if (s) CFRelease(s); return nil; }
    CIImage *r = [self initWithCGImageSource:s index:0 options:o];
    NSDictionary *aux = [CIImage _auxiliaryFrom:s options:o];
    CFRelease(s);
    if (CGRectIsEmpty(r.extent)) return nil;
    if (aux) return aux[@"image"] ?: r;
    return r;
}
- (instancetype)initWithContentsOfURL:(NSURL *)url { return [self initWithContentsOfURL:url options:nil]; }
- (instancetype)initWithContentsOfURL:(NSURL *)url options:(NSDictionary *)o {
    NSData *d = [NSData dataWithContentsOfURL:url];
    CIImage *r = d ? [self initWithData:d options:o] : nil;
    r.isimURL = url;
    return r;
}
/* auxiliary images (the options ask for one instead of the main image): isim's HEIC/JPEG files carry none unless
   written by Core Image with representation options, which isim stores as extra frames tagged in the properties */
+ (NSDictionary *)_auxiliaryFrom:(CGImageSourceRef)s options:(NSDictionary *)o {
    NSArray *keys = @[ kCIImageAuxiliaryDepth, kCIImageAuxiliaryDisparity, kCIImageAuxiliaryPortraitEffectsMatte,
                       kCIImageAuxiliarySemanticSegmentationSkinMatte, kCIImageAuxiliarySemanticSegmentationHairMatte,
                       kCIImageAuxiliarySemanticSegmentationTeethMatte, kCIImageAuxiliarySemanticSegmentationGlassesMatte,
                       kCIImageAuxiliarySemanticSegmentationSkyMatte, kCIImageAuxiliaryHDRGainMap ];
    NSString *want = nil;
    for (NSString *k in keys) if ([o[k] boolValue]) want = k;
    if (!want) return nil;
    size_t n = CGImageSourceGetCount(s);
    for (size_t i = 1; i < n; i++) {
        NSDictionary *p = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(s, i, NULL));
        NSString *tag = p[@"{isimAuxiliary}"][@"type"] ?: p[@"ImageDescription"] ?: p[@"{TIFF}"][@"ImageDescription"];
        if ([tag isEqualToString:want]) return @{ @"image": [CIImage imageWithCGImageSource:s index:i options:nil] };
    }
    return @{ @"image": [NSNull null] };   /* asked for an auxiliary image the file does not have: nil */
}
- (instancetype)initWithColor:(CIColor *)c {
    CIColor *col = c ?: [CIColor clearColor];
    CIImage *g = ci_gen(CGRectInfinite, ^(double x, double y, float *out, const ci_rctx *rc) { ci_color_ws(col, rc, out); });
    g.isimOpaque = col.alpha >= 1;
    return (id)g;
}
- (instancetype)initWithBitmapData:(NSData *)d bytesPerRow:(size_t)bpr size:(CGSize)s format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    int w = (int)s.width, h = (int)s.height;
    float *px = d ? ci_load(d.bytes, w, h, (ptrdiff_t)bpr, f, 1) : NULL;
    if (!px) return (id)[CIImage emptyImage];
    ci_fmt fm; ci_fmt_of(f, &fm);
    CIImage *b = ci_bitmap(px, w, h, CGRectMake(0, 0, w, h), ci_space_of(cs), cs == NULL && fm.isfloat);
    b.isimCGColorSpace = cs ? (__bridge id)cs : nil;
    b.isimOpaque = !fm.alpha;
    return (id)b;
}
- (instancetype)initWithImageProvider:(id)p size:(size_t)w :(size_t)h format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs options:(NSDictionary *)o {
    __CIBitmapImage *b = [__CIBitmapImage new];
    b->_w = (int)w; b->_h = (int)h; b->_provider = p; b->_providerFormat = f; b->_providerInfo = o[kCIImageProviderUserInfo];
    b->_space = ci_space_of(cs); b->_raw = cs == NULL;
    b.isimCGColorSpace = cs ? (__bridge id)cs : nil;
    b.isimExtent = CGRectMake(0, 0, w, h);
    return (id)with_options(b, o);
}
- (instancetype)initWithImage:(id)image { return [self initWithImage:image options:nil]; }
- (instancetype)initWithImage:(id)image options:(NSDictionary *)o {
    if (![image isKindOfClass:[UIImage class]]) return nil;
    UIImage *ui = image;
    if (ui.CIImage) return ui.CIImage;          /* a UIImage made from a CIImage (on isim it also has a CGImage) */
    CGImageRef cg = ui.CGImage;
    if (!cg) return nil;
    CIImage *r = [self initWithCGImage:cg options:o];
    /* like iOS: the CIImage holds the stored pixels; kCIImageApplyOrientationProperty applies the UIImage's
       orientation (UIImageOrientation -> EXIF) */
    if ([o[kCIImageApplyOrientationProperty] boolValue] && ui.imageOrientation != UIImageOrientationUp) {
        static const int exif[] = { 1, 3, 8, 6, 2, 4, 5, 7 };
        r = [r imageByApplyingOrientation:exif[ui.imageOrientation & 7]];
    }
    return r;
}
static CIImage *with_options(CIImage *im, NSDictionary *o) {
    if (!o.count) return im;
    id cs = o[kCIImageColorSpace];
    if (cs && [im isKindOfClass:[__CIBitmapImage class]]) {
        __CIBitmapImage *b = (__CIBitmapImage *)im;
        if (ci_is_null(cs)) b->_raw = YES;
        else if (ci_is_cgspace(cs)) { b->_space = ci_space_of((__bridge CGColorSpaceRef)cs); b.isimCGColorSpace = cs; }
    }
    if (o[kCIImageProperties]) im.isimProperties = o[kCIImageProperties];
    if ([o[kCIImageNearestSampling] boolValue]) im.isimSampling = CI_SAMPLE_NEAREST;
    if (o[kCIImageContentHeadroom]) im.isimHeadroom = [o[kCIImageContentHeadroom] doubleValue];
    if (o[kCIImageContentAverageLightLevel]) im.isimAverageLightLevel = [o[kCIImageContentAverageLightLevel] doubleValue];
    if ([o[kCIImageApplyOrientationProperty] boolValue]) {
        id or = im.isimProperties[(__bridge NSString *)kCGImagePropertyOrientation];
        if (or && [or intValue] > 1) im = [im imageByApplyingOrientation:[or intValue]];
    }
    return im;
}
- (CIImage *)_copyNode {
    __CIProxyImage *p = [__CIProxyImage new];
    p->_in = self;
    p.isimExtent = self.extent; p.isimProperties = self.isimProperties; p.isimURL = self.isimURL; p.isimSampling = self.isimSampling;
    p.isimOpaque = self.isimOpaque; p.isimCGColorSpace = self.isimCGColorSpace; p.isimCGImage = self.isimCGImage;
    p.isimPixelBuffer = self.isimPixelBuffer; p.isimAux = self.isimAux; p.isimHeadroom = self.isimHeadroom;
    p.isimAverageLightLevel = self.isimAverageLightLevel;
    return p;
}
- (id)copyWithZone:(NSZone *)z { return self; }
/* secure coding: the rendered pixels (RGBA float, linear sRGB) and the extent */
- (void)encodeWithCoder:(NSCoder *)c {
    CGRect e = self.extent;
    [c encodeObject:[CIVector vectorWithCGRect:e] forKey:@"extent"];
    if (!ci_infinite(e) && !CGRectIsEmpty(e)) {
        ci_rctx rc = ci_rctx_default(); rc.cache = ci_cache_new();
        float *px = ci_render_new(self, ci_integral(e), &rc);
        ci_cache_free(rc.cache);
        CGRect ie = ci_integral(e);
        [c encodeObject:[NSData dataWithBytesNoCopy:px length:sizeof(float) * 4 * (size_t)ie.size.width * ie.size.height] forKey:@"pixels"];
    }
    if (self.properties.count) [c encodeObject:self.properties forKey:@"properties"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    CGRect e = [[c decodeObjectOfClass:[CIVector class] forKey:@"extent"] CGRectValue];
    NSData *d = [c decodeObjectOfClass:[NSData class] forKey:@"pixels"];
    if (!d) return (id)[CIImage emptyImage];
    CGRect ie = ci_integral(e);
    size_t n = (size_t)ie.size.width * ie.size.height * 4;
    if (d.length < n * sizeof(float)) return (id)[CIImage emptyImage];
    float *px = malloc(n * sizeof(float)); memcpy(px, d.bytes, n * sizeof(float));
    CIImage *r = ci_bitmap(px, (int)ie.size.width, (int)ie.size.height, ie, ci_space_linear, NO);
    r.isimProperties = [c decodeObjectOfClass:[NSDictionary class] forKey:@"properties"];
    return (id)r;
}
- (CGRect)extent { return _isimExtent; }
- (CGImageRef)CGImage { return (__bridge CGImageRef)self.isimCGImage; }
- (NSDictionary *)properties { return self.isimProperties ?: @{}; }
- (CGColorSpaceRef)colorSpace { return (__bridge CGColorSpaceRef)self.isimCGColorSpace; }
- (NSURL *)url { return self.isimURL; }
- (BOOL)isOpaque { return self.isimOpaque; }
- (CGFloat)contentHeadroom { return self.isimHeadroom; }
- (float)contentAverageLightLevel { return (float)self.isimAverageLightLevel; }
- (CIFilterShape *)definition { return [CIFilterShape shapeWithRect:self.extent]; }
- (CGRect)regionOfInterestForImage:(CIImage *)image inRect:(CGRect)rect { return image == self ? rect : CGRectInfinite; }
- (NSString *)description {
    CGRect e = self.extent;
    if (ci_infinite(e)) return [NSString stringWithFormat:@"<CIImage: %p> extent [infinite]", self];
    return [NSString stringWithFormat:@"<CIImage: %p> extent [%g %g %g %g]", self, e.origin.x, e.origin.y, e.size.width, e.size.height];
}
- (NSString *)debugDescription { return self.description; }
- (void)_render:(CGRect)r into:(float *)buf ctx:(const ci_rctx *)rc {}

- (CIImage *)imageByApplyingTransform:(CGAffineTransform)t { return [self imageByApplyingTransform:t highQualityDownsample:NO]; }
- (CIImage *)imageByApplyingTransform:(CGAffineTransform)t highQualityDownsample:(BOOL)hq {
    if (CGAffineTransformIsIdentity(t)) return self;
    CIImage *src = self; CGAffineTransform m = t;
    if ([self isKindOfClass:[__CITransformImage class]]) {        /* fold consecutive transforms: one resampling */
        __CITransformImage *ti = (__CITransformImage *)self;
        src = ti->_in; m = CGAffineTransformConcat(ti->_t, t);
    }
    __CITransformImage *i = [__CITransformImage new]; i->_in = src; i->_t = m; i->_hq = hq;
    i.isimExtent = ci_infinite(src.extent) ? CGRectInfinite : CGRectApplyAffineTransform(src.extent, m);
    i.isimSampling = self.isimSampling; i.isimProperties = self.isimProperties; i.isimOpaque = self.isimOpaque;
    return i;
}
- (CGAffineTransform)imageTransformForOrientation:(int)o {
    CGRect e = self.extent; double w = e.size.width, h = e.size.height;
    /* the EXIF orientation (1...8) of the stored pixels -> transform that shows them upright (y-up space) */
    CGAffineTransform t;
    switch (o) {
    case 2: t = CGAffineTransformMake(-1, 0, 0, 1, w, 0); break;
    case 3: t = CGAffineTransformMake(-1, 0, 0, -1, w, h); break;
    case 4: t = CGAffineTransformMake(1, 0, 0, -1, 0, h); break;
    case 5: t = CGAffineTransformMake(0, -1, -1, 0, h, w); break;
    case 6: t = CGAffineTransformMake(0, -1, 1, 0, 0, w); break;
    case 7: t = CGAffineTransformMake(0, 1, 1, 0, 0, 0); break;
    case 8: t = CGAffineTransformMake(0, 1, -1, 0, h, 0); break;
    default: t = CGAffineTransformIdentity;
    }
    return CGAffineTransformConcat(CGAffineTransformMakeTranslation(-e.origin.x, -e.origin.y), t);
}
- (CGAffineTransform)imageTransformForCGOrientation:(CGImagePropertyOrientation)o { return [self imageTransformForOrientation:(int)o]; }
- (CIImage *)imageByApplyingOrientation:(int)o {
    if (o <= 1 || o > 8) return self;
    return [self imageByApplyingTransform:[self imageTransformForOrientation:o]];
}
- (CIImage *)imageByApplyingCGOrientation:(CGImagePropertyOrientation)o { return [self imageByApplyingOrientation:(int)o]; }
- (CIImage *)imageByCroppingToRect:(CGRect)rect {
    CGRect e = CGRectIntersection(self.extent, rect);
    if (CGRectIsNull(e) || CGRectIsEmpty(e)) return [CIImage emptyImage];
    if (CGRectEqualToRect(e, self.extent)) return self;
    CIImage *in = self;
    CIImage *c = ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
        CGRect ir = CGRectIntegral(e);
        CGRect sub = CGRectIntersection(r, ir);
        if (CGRectIsNull(sub) || CGRectIsEmpty(sub)) return;
        BOOL frac = !CGRectEqualToRect(ir, e);
        if (CGRectEqualToRect(sub, r) && !frac) { [in _render:r into:out ctx:rc]; return; }
        float *b = ci_render_new(in, sub, rc);
        int W = (int)r.size.width, SW = (int)sub.size.width, SH = (int)sub.size.height;
        int ox = (int)(sub.origin.x - r.origin.x), oy = (int)((r.origin.y + r.size.height) - (sub.origin.y + sub.size.height));
        for (int j = 0; j < SH; j++) {
            float *dst = out + ((size_t)(j + oy) * W + ox) * 4, *src = b + (size_t)j * SW * 4;
            if (!frac) { memcpy(dst, src, sizeof(float) * 4 * SW); continue; }
            for (int i = 0; i < SW; i++) {            /* fractional crop edges: coverage of the pixel */
                double px0 = sub.origin.x + i, py0 = sub.origin.y + SH - 1 - j;
                double cx = fmax(0, fmin(px0 + 1, CGRectGetMaxX(e)) - fmax(px0, e.origin.x));
                double cy = fmax(0, fmin(py0 + 1, CGRectGetMaxY(e)) - fmax(py0, e.origin.y));
                float cov = (float)(cx * cy);
                for (int k = 0; k < 4; k++) dst[i * 4 + k] = src[i * 4 + k] * cov;
            }
        }
        free(b);
    });
    c.isimProperties = self.isimProperties; c.isimSampling = self.isimSampling; c.isimOpaque = self.isimOpaque;
    return c;
}
- (CIImage *)imageByClampingToRect:(CGRect)rect {
    CIImage *in = self;
    CGRect e = CGRectIntegral(rect);
    if (ci_infinite(e) || CGRectIsEmpty(e)) return self;
    CIImage *c = ci_op(CGRectInfinite, ^(CGRect r, float *out, const ci_rctx *rc) {
        CGRect inner = CGRectIntersection(r, e);
        if (CGRectEqualToRect(inner, r)) { [in _render:r into:out ctx:rc]; return; }
        /* render only the part of e the output can reach (rows and columns clamp into it) */
        CGRect need = CGRectMake(fmin(fmax(r.origin.x, e.origin.x), CGRectGetMaxX(e) - 1), fmin(fmax(r.origin.y, e.origin.y), CGRectGetMaxY(e) - 1), 1, 1);
        need = CGRectUnion(need, CGRectMake(fmin(fmax(CGRectGetMaxX(r) - 1, e.origin.x), CGRectGetMaxX(e) - 1),
                                            fmin(fmax(CGRectGetMaxY(r) - 1, e.origin.y), CGRectGetMaxY(e) - 1), 1, 1));
        ci_buf b = ci_buf_render(in, need, 0, rc);
        if (!b.px) { b.r = need; b.w = (int)need.size.width; b.h = (int)need.size.height; b.px = ci_render_new(in, need, rc); }
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) {
            int y = (int)(r.origin.y + r.size.height) - 1 - j;
            int cy = y < need.origin.y ? (int)need.origin.y : y >= CGRectGetMaxY(need) ? (int)CGRectGetMaxY(need) - 1 : y;
            for (int i = 0; i < W; i++) {
                int x = (int)r.origin.x + i;
                int cx = x < need.origin.x ? (int)need.origin.x : x >= CGRectGetMaxX(need) ? (int)CGRectGetMaxX(need) - 1 : x;
                const float *p = ci_buf_at(&b, cx, cy);
                if (p) memcpy(out + ((size_t)j * W + i) * 4, p, 4 * sizeof(float));
            }
        }
        ci_buf_free(&b);
    });
    c.isimSampling = self.isimSampling; c.isimProperties = self.isimProperties; c.isimOpaque = self.isimOpaque;
    return c;
}
- (CIImage *)imageByClampingToExtent { return [self imageByClampingToRect:self.extent]; }
- (CIImage *)imageByCompositingOverImage:(CIImage *)dest {
    CIImage *fg = self;
    CGRect e = CGRectUnion(self.extent, dest.extent);
    CIImage *r = ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
        [dest _render:r into:out ctx:rc];
        float *f = ci_render_new(fg, r, rc);
        size_t n = (size_t)r.size.width * (size_t)r.size.height;
        for (size_t i = 0; i < n; i++) {
            float *d = out + i * 4, *s = f + i * 4, k = 1 - s[3];
            d[0] = s[0] + d[0] * k; d[1] = s[1] + d[1] * k; d[2] = s[2] + d[2] * k; d[3] = s[3] + d[3] * k;
        }
        free(f);
    });
    r.isimOpaque = dest.isimOpaque && CGRectContainsRect(dest.extent, self.extent);
    return r;
}
- (CIImage *)imageByApplyingFilter:(NSString *)name withInputParameters:(NSDictionary *)params {
    CIFilter *f = [CIFilter filterWithName:name];
    if (!f) { NSLog(@"isim: Core Image: no filter named %@", name); return [CIImage emptyImage]; }
    [f setValue:self forKey:kCIInputImageKey];
    for (NSString *k in params) [f setValue:params[k] forKey:k];
    return f.outputImage ?: [CIImage emptyImage];
}
- (CIImage *)imageByApplyingFilter:(NSString *)name { return [self imageByApplyingFilter:name withInputParameters:nil]; }
- (CIImage *)imageByColorMatchingColorSpaceToWorkingSpace:(CGColorSpaceRef)cs {
    ci_space from = ci_space_of(cs);
    CIImage *in = self;
    return ci_op(self.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [in _render:r into:out ctx:rc];
        if (rc->managed) ci_convert(out, (size_t)r.size.width * (size_t)r.size.height, from, rc->ws);
    });
}
- (CIImage *)imageByColorMatchingWorkingSpaceToColorSpace:(CGColorSpaceRef)cs {
    ci_space to = ci_space_of(cs);
    CIImage *in = self;
    return ci_op(self.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [in _render:r into:out ctx:rc];
        if (rc->managed) ci_convert(out, (size_t)r.size.width * (size_t)r.size.height, rc->ws, to);
    });
}
- (CIImage *)imageByApplyingGaussianBlurWithSigma:(double)sigma {
    if (sigma <= 0) return self;
    CIImage *in = self;
    int pad = (int)ceil(3 * sigma);
    CGRect e = ci_infinite(self.extent) ? CGRectInfinite : CGRectInset(self.extent, -pad, -pad);
    return ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
        CGRect src = CGRectInset(r, -pad, -pad);
        float *b = ci_render_new(in, src, rc);
        int W = (int)src.size.width, H = (int)src.size.height;
        ci_blur_buf(b, W, H, sigma);
        int RW = (int)r.size.width, RH = (int)r.size.height;
        for (int y = 0; y < RH; y++) memcpy(out + (size_t)y * RW * 4, b + ((size_t)(y + pad) * W + pad) * 4, sizeof(float) * 4 * RW);
        free(b);
    });
}
- (CIImage *)imageBySettingAlphaOneInExtent:(CGRect)e {
    CIImage *m = ci_map(self, ^(float *p) { ci_unpremul(p); p[3] = 1; });
    m = [m imageByCroppingToRect:e];
    m.isimOpaque = YES;
    return m;
}
- (CIImage *)imageByPremultiplyingAlpha { return ci_map(self, ^(float *p) { p[0] *= p[3]; p[1] *= p[3]; p[2] *= p[3]; }); }
- (CIImage *)imageByUnpremultiplyingAlpha { return ci_map(self, ^(float *p) { ci_unpremul(p); }); }
- (CIImage *)imageBySettingProperties:(NSDictionary *)props { CIImage *c = [self _copyNode]; c.isimProperties = props; return c; }
- (CIImage *)imageBySamplingLinear { CIImage *c = [self _copyNode]; c.isimSampling = CI_SAMPLE_LINEAR; return c; }
- (CIImage *)imageBySamplingNearest { CIImage *c = [self _copyNode]; c.isimSampling = CI_SAMPLE_NEAREST; return c; }
- (CIImage *)imageByInsertingIntermediate { return [self imageByInsertingIntermediate:YES]; }
/* isim renders in bands, so a tiled intermediate is an intermediate */
- (CIImage *)imageByInsertingTiledIntermediate { return [self imageByInsertingIntermediate:YES]; }
- (CIImage *)imageByConvertingWorkingSpaceToLab { return [self imageByApplyingFilter:@"CIConvertRGBtoLab" withInputParameters:@{}]; }
- (CIImage *)imageByConvertingLabToWorkingSpace { return [self imageByApplyingFilter:@"CIConvertLabToRGB" withInputParameters:@{}]; }
- (CIImage *)imageBySettingContentHeadroom:(float)headroom {
    CIImage *c = [self _copyNode]; c.isimHeadroom = headroom; return c;
}
- (CIImage *)imageBySettingContentAverageLightLevel:(float)average {
    CIImage *c = [self _copyNode]; c.isimAverageLightLevel = average; return c;
}
/* an intermediate: the input rendered once per render (whole extent) and reused by the nodes above it */
- (CIImage *)imageByInsertingIntermediate:(BOOL)cache {
    CIImage *in = self;
    CGRect e = self.extent;
    if (ci_infinite(e)) return self;
    id key = [NSObject new];
    CIImage *r = ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
        NSData *d = ci_cache_get(rc, key, ^id {
            CGRect ie = ci_integral(e);
            float *px = ci_render_new(in, ie, rc);
            return [NSData dataWithBytesNoCopy:px length:sizeof(float) * 4 * (size_t)ie.size.width * ie.size.height];
        });
        CGRect ie = ci_integral(e);
        ci_buf b = { (float *)d.bytes, ie, (int)ie.size.width, (int)ie.size.height };
        int W = (int)r.size.width, H = (int)r.size.height;
        for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
            const float *p = ci_buf_at(&b, (int)r.origin.x + i, (int)(r.origin.y + r.size.height) - 1 - j);
            if (p) memcpy(out + ((size_t)j * W + i) * 4, p, 4 * sizeof(float));
        }
    });
    r.isimProperties = self.isimProperties; r.isimOpaque = self.isimOpaque;
    return r;
}
/* gain maps (iOS 18): the HDR image is SDR * 2^(gain * log2(headroom)) with the gain map (a gray image, sRGB-encoded,
   stretched over the image) as in Apple's adaptive HDR; headroom defaults to the gain map's 4x */
- (CIImage *)imageByApplyingGainMap:(CIImage *)gainmap { return [self imageByApplyingGainMap:gainmap headroom:4]; }
- (CIImage *)imageByApplyingGainMap:(CIImage *)gm headroom:(float)headroom {
    if (!gm || CGRectIsEmpty(gm.extent)) return self;
    CGRect e = self.extent, ge = gm.extent;
    CIImage *scaled = [gm imageByApplyingTransform:CGAffineTransformMake(e.size.width / ge.size.width, 0, 0, e.size.height / ge.size.height,
                                                                         e.origin.x - ge.origin.x * e.size.width / ge.size.width,
                                                                         e.origin.y - ge.origin.y * e.size.height / ge.size.height)];
    float l2 = log2f(fmaxf(headroom, 1));
    CIImage *r = ci_combine(self, scaled, e, ^(float *out, const float *pa, const float *pb) {
        float g = pb[3] > 0 ? ci_trc_encode(CI_TRC_SRGB, ci_luma(pb) / pb[3]) : 0;
        float k = exp2f(g * l2);
        out[0] = pa[0] * k; out[1] = pa[1] * k; out[2] = pa[2] * k; out[3] = pa[3];
    });
    r.isimHeadroom = headroom;
    return r;
}
@end

@implementation __CIOpImage
- (void)_render:(CGRect)r into:(float *)buf ctx:(const ci_rctx *)rc { _fn(r, buf, rc); }
@end
@implementation __CIProxyImage
- (void)_render:(CGRect)r into:(float *)buf ctx:(const ci_rctx *)rc { [_in _render:r into:buf ctx:rc]; }
@end

@implementation __CIBitmapImage
- (instancetype)init { if ((self = [super init])) pthread_mutex_init(&_m, NULL); return self; }
- (void)dealloc { free(_px); free(_conv); pthread_mutex_destroy(&_m); }
/* the pixels in the space they are stored in (decoding a CGImage or calling the provider the first time) */
- (const float *)_source {
    if (_px) return _px;
    CGImageRef cg = (__bridge CGImageRef)self.isimCGImage;
    if (cg) {
        size_t w, h; unsigned char *px = isim_cg_image_rgba(cg, &w, &h);
        float *f = calloc((size_t)_w * _h * 4 + 4, sizeof(float));
        if (px) {
            for (size_t i = 0; i < (size_t)(w * h) && i < (size_t)_w * _h; i++) for (int k = 0; k < 4; k++) f[i * 4 + k] = px[i * 4 + k] / 255.0f;
            free(px);
        }
        _px = f;
    } else if (_provider) {
        ci_fmt fm; ci_fmt_of(_providerFormat, &fm);
        size_t bpr = (size_t)_w * fm.ch * fm.bytes;
        void *bytes = calloc(bpr * _h + 16, 1);
        [_provider provideImageData:bytes bytesPerRow:bpr origin:0 :0 size:_w :_h userInfo:_providerInfo];
        _px = ci_load(bytes, _w, _h, (ptrdiff_t)bpr, _providerFormat, 1);
        free(bytes);
        if (!_px) _px = calloc((size_t)_w * _h * 4 + 4, sizeof(float));
    } else _px = calloc(4, sizeof(float));
    return _px;
}
- (void)_render:(CGRect)r into:(float *)buf ctx:(const ci_rctx *)rc {
    pthread_mutex_lock(&_m);
    const float *src = [self _source];
    BOOL convert = rc->managed && !_raw && !ci_space_eq(_space, rc->ws);
    if (convert) {
        if (!_conv || !ci_space_eq(_convSpace, rc->ws)) {      /* the whole image converted once per working space */
            free(_conv);
            size_t n = (size_t)_w * _h;
            _conv = malloc(sizeof(float) * 4 * (n ? n : 1));
            memcpy(_conv, src, sizeof(float) * 4 * n);
            ci_convert(_conv, n, _space, rc->ws);
            _convSpace = rc->ws;
        }
        src = _conv;
    }
    pthread_mutex_unlock(&_m);
    int W = (int)r.size.width, H = (int)r.size.height;
    CGRect e = self.isimExtent;
    int ex = (int)floor(e.origin.x), ey = (int)floor(e.origin.y);
    for (int j = 0; j < H; j++) {
        int y = (int)(r.origin.y + r.size.height) - 1 - j;     /* CI y of this output row */
        int sy = ey + _h - 1 - y;                                  /* stored row (top-down) */
        if (sy < 0 || sy >= _h) continue;
        int x0 = (int)r.origin.x - ex, i0 = x0 < 0 ? -x0 : 0, i1 = W;
        if (x0 + i1 > _w) i1 = _w - x0;
        if (i1 <= i0) continue;
        memcpy(buf + ((size_t)j * W + i0) * 4, src + ((size_t)sy * _w + x0 + i0) * 4, sizeof(float) * 4 * (size_t)(i1 - i0));
    }
}
@end

@implementation __CITransformImage
- (void)_render:(CGRect)r into:(float *)buf ctx:(const ci_rctx *)rc {
    CGAffineTransform inv = CGAffineTransformInvert(_t);
    double sx = hypot(_t.a, _t.b), sy = hypot(_t.c, _t.d);       /* scale factors (output pixels per input pixel) */
    int mode = _in.isimSampling;
    BOOL axis = fabs(_t.b) < 1e-9 && fabs(_t.c) < 1e-9;
    /* pure integer translations copy */
    if (axis && _t.a == 1 && _t.d == 1 && _t.tx == floor(_t.tx) && _t.ty == floor(_t.ty)) {
        [_in _render:CGRectOffset(r, -_t.tx, -_t.ty) into:buf ctx:rc];
        return;
    }
    CGRect src = CGRectIntegral(CGRectInset(CGRectApplyAffineTransform(r, inv), -3, -3));
    if (!ci_infinite(_in.extent)) {
        src = CGRectIntersection(src, CGRectIntegral(CGRectInset(_in.extent, -2, -2)));
        if (CGRectIsNull(src) || CGRectIsEmpty(src)) return;
    }
    ci_buf b = { NULL, src, (int)src.size.width, (int)src.size.height };
    b.px = ci_render_new(_in, src, rc);
    /* downsampling (a scale below 1): pre-filter the source so each output pixel averages the pixels it covers
       (box filter of the reciprocal scale), like Core Image's high-quality downsample; plain bilinear otherwise */
    double down = fmin(sx, sy);
    if (mode != CI_SAMPLE_NEAREST && down < 0.75 && (_hq || rc->hq || down < 0.5)) {
        int rx = (int)floor(0.5 / fmax(sx, 1e-6) - 0.5), ry = (int)floor(0.5 / fmax(sy, 1e-6) - 0.5);
        if (!axis) rx = ry = (int)floor(0.5 / fmax(down, 1e-6) - 0.5);
        if (rx > 0 || ry > 0) ci_box_blur_buf(b.px, b.w, b.h, rx > 0 ? rx : 0, ry > 0 ? ry : 0);
    }
    int W = (int)r.size.width, H = (int)r.size.height;
    for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
        CGPoint p = CGPointApplyAffineTransform(CGPointMake(ci_px_x(r, i), ci_px_y(r, j)), inv);
        ci_sample(&b, p.x, p.y, mode, buf + ((size_t)j * W + i) * 4);
    }
    free(b.px);
}
@end

/* ================= auto adjustment ================= */
NSString *const kCIImageAutoAdjustEnhance = @"kCIImageAutoAdjustEnhance", *const kCIImageAutoAdjustRedEye = @"kCIImageAutoAdjustRedEye",
    *const kCIImageAutoAdjustFeatures = @"kCIImageAutoAdjustFeatures", *const kCIImageAutoAdjustCrop = @"kCIImageAutoAdjustCrop",
    *const kCIImageAutoAdjustLevel = @"kCIImageAutoAdjustLevel";
CI_HIDDEN double ci_dominant_tilt(CIImage *im);       /* CIFiltersGeometry.m */
@implementation CIImage (AutoAdjustment)
- (NSArray<CIFilter *> *)autoAdjustmentFilters { return [self autoAdjustmentFiltersWithOptions:nil]; }
- (NSArray<CIFilter *> *)autoAdjustmentFiltersWithOptions:(NSDictionary *)o {
    NSMutableArray *out = [NSMutableArray array];
    CGRect e = self.extent;
    if (ci_infinite(e) || CGRectIsEmpty(e)) return out;
    BOOL enhance = o[kCIImageAutoAdjustEnhance] ? [o[kCIImageAutoAdjustEnhance] boolValue] : YES;
    BOOL level = [o[kCIImageAutoAdjustLevel] boolValue], crop = [o[kCIImageAutoAdjustCrop] boolValue];
    if (enhance) {
        /* statistics of a downscaled copy: luminance percentiles and mean saturation */
        double s = fmin(1, 256.0 / fmax(e.size.width, e.size.height));
        CIImage *small = [[self imageByApplyingTransform:CGAffineTransformMakeScale(s, s) highQualityDownsample:YES]
                          imageByCroppingToRect:CGRectIntegral(CGRectApplyAffineTransform(e, CGAffineTransformMakeScale(s, s)))];
        CGRect se = ci_integral(small.extent);
        ci_rctx rc = ci_rctx_default(); rc.cache = ci_cache_new();
        float *px = ci_render_new(small, se, &rc);
        ci_cache_free(rc.cache);
        size_t n = (size_t)se.size.width * se.size.height;
        int hist[256] = { 0 }; double sat = 0; size_t cnt = 0;
        for (size_t i = 0; i < n; i++) {
            float *p = px + i * 4; if (p[3] <= 0) continue;
            float c[3] = { p[0] / p[3], p[1] / p[3], p[2] / p[3] };
            for (int k = 0; k < 3; k++) c[k] = ci_trc_encode(CI_TRC_SRGB, ci_clamp01(c[k]));
            float l = 0.2126f * c[0] + 0.7152f * c[1] + 0.0722f * c[2];
            hist[(int)lroundf(ci_clamp01(l) * 255)]++;
            float mx = fmaxf(c[0], fmaxf(c[1], c[2])), mn = fminf(c[0], fminf(c[1], c[2]));
            sat += mx > 0 ? (mx - mn) / mx : 0; cnt++;
        }
        free(px);
        if (cnt) {
            double lo = 0, hi = 1, mid = 0.5; size_t acc = 0;
            for (int i = 0; i < 256; i++) { acc += hist[i]; if (acc >= cnt * 0.01 && lo == 0) lo = i / 255.0; if (acc >= cnt * 0.5 && mid == 0.5) mid = i / 255.0; if (acc >= cnt * 0.99) { hi = i / 255.0; break; } }
            sat /= cnt;
            if (sat < 0.35) {
                CIFilter *v = [CIFilter filterWithName:@"CIVibrance"];
                [v setValue:@(fmin(0.5, (0.35 - sat) * 2)) forKey:@"inputAmount"];
                [out addObject:v];
            }
            if (lo > 0.02 || hi < 0.98 || fabs(mid - 0.5) > 0.08) {
                CIFilter *t = [CIFilter filterWithName:@"CIToneCurve"];
                double span = fmax(hi - lo, 0.1), m = (mid - lo) / span;
                [t setValue:[CIVector vectorWithX:lo Y:0] forKey:@"inputPoint0"];
                [t setValue:[CIVector vectorWithX:lo + span * 0.25 Y:0.25 + (0.5 - m) * 0.1] forKey:@"inputPoint1"];
                [t setValue:[CIVector vectorWithX:mid Y:0.5] forKey:@"inputPoint2"];
                [t setValue:[CIVector vectorWithX:lo + span * 0.75 Y:0.75 + (0.5 - m) * 0.05] forKey:@"inputPoint3"];
                [t setValue:[CIVector vectorWithX:hi Y:1] forKey:@"inputPoint4"];
                [out addObject:t];
            }
            if (hist[255] + hist[254] > cnt * 0.05 || hist[0] + hist[1] > cnt * 0.05) {
                CIFilter *h = [CIFilter filterWithName:@"CIHighlightShadowAdjust"];
                [h setValue:@(hist[0] + hist[1] > cnt * 0.05 ? 0.3 : 0) forKey:@"inputShadowAmount"];
                [h setValue:@(hist[255] + hist[254] > cnt * 0.05 ? 0.7 : 1) forKey:@"inputHighlightAmount"];
                [out addObject:h];
            }
        }
    }
    if (level) {
        double a = ci_dominant_tilt(self);
        if (fabs(a) > 0.002 && fabs(a) < 0.35) {
            CIFilter *st = [CIFilter filterWithName:@"CIStraightenFilter"];
            [st setValue:@(-a) forKey:@"inputAngle"];
            [out addObject:st];
            if (crop) {                /* the largest axis-aligned rect inside the rotated image */
                double w = e.size.width, h = e.size.height, c = cos(fabs(a)), sn = sin(fabs(a));
                double k = fmin(w / (w * c + h * sn), h / (w * sn + h * c));
                double cw = w * k, ch = h * k;
                CIFilter *cr = [CIFilter filterWithName:@"CICrop"];
                [cr setValue:[CIVector vectorWithCGRect:CGRectMake(CGRectGetMidX(e) - cw / 2, CGRectGetMidY(e) - ch / 2, cw, ch)] forKey:@"inputRectangle"];
                [out addObject:cr];
            }
        }
    }
    return out;
}
@end
