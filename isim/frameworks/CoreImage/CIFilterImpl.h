// Helpers for isim's built-in filter implementations (the CIFilters*.m files).
#pragma once
#import "CIInternal.h"

#define IMG(k) ({ id v_ = in[k]; [v_ isKindOfClass:[CIImage class]] ? (CIImage *)v_ : nil; })
#define NUM(k, d) ((float)ci_num(in[k], d))
#define PT(k, x, y) ci_point(in[k], CGPointMake(x, y))
#define BOOLV(k) (ci_num(in[k], 0) != 0)
/* registers a filter: REG(@"CIName", { ... return image; }) with the inputs dictionary as `in` */
#define REG(name, ...) ci_register_impl(name, ^CIImage *(NSDictionary *in) __VA_ARGS__)
typedef struct { float v[40]; } fbox;
static inline float mixf(float a, float b, float t) { return a + (b - a) * t; }
static inline float smoothf(float e0, float e1, float x) { float t = ci_clamp01((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); }
static inline float lumaf(const float *c) { return 0.2125f * c[0] + 0.7154f * c[1] + 0.0721f * c[2]; }
/* deterministic per-pixel noise in [0, 1) */
static inline float ci_hash01(int x, int y, int salt) {
    uint32_t h = (uint32_t)x * 73856093u ^ (uint32_t)y * 19349663u ^ (uint32_t)salt * 83492791u;
    h ^= h >> 13; h *= 0x5bd1e995u; h ^= h >> 15;
    return (h & 0xffffff) / 16777216.0f;
}
