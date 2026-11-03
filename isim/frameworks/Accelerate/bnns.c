// isim Accelerate BNNS (issue #808): data types, layouts, dense load / store, activations and filter objects.
#include "bnns_core.h"
#include <stdint.h>

/* ---- data types ---- */
int bn_type_bits(BNNSDataType t) {
    switch (t) {
    case BNNSDataTypeFloat16: case BNNSDataTypeBFloat16: return 16;
    case BNNSDataTypeFloat32: return 32;
    case BNNSDataTypeBoolean: return 8;
    default: break;
    }
    unsigned cls = t & 0xff0000u, bits = t & 0xffu;
    if ((cls == BNNSDataTypeIntBit || cls == BNNSDataTypeUIntBit) && (bits == 1 || bits == 2 || bits == 3 || bits == 4 ||
        bits == 6 || bits == 8 || bits == 16 || bits == 32 || bits == 64)) {
        if (cls == BNNSDataTypeIntBit && (bits == 3 || bits == 6)) return 0;
        return (int)bits;
    }
    if (cls == BNNSDataTypeIndexedBit && (bits == 1 || bits == 2 || bits == 4 || bits == 8)) return (int)bits;
    return 0;
}
int bn_type_is_float(BNNSDataType t) {
    return t == BNNSDataTypeFloat16 || t == BNNSDataTypeFloat32 || t == BNNSDataTypeBFloat16;
}

static float half_to_float(uint16_t h) {
    uint32_t s = (uint32_t)(h & 0x8000) << 16, e = (h >> 10) & 0x1f, m = h & 0x3ff, f;
    if (e == 0) {
        if (!m) f = s;
        else { /* subnormal */
            e = 113; while (!(m & 0x400)) { m <<= 1; e--; }
            m &= 0x3ff; f = s | (e << 23) | (m << 13);
        }
    } else if (e == 31) f = s | 0x7f800000u | (m << 13);
    else f = s | ((e + 112) << 23) | (m << 13);
    float r; memcpy(&r, &f, 4); return r;
}
static uint16_t float_to_half(float x) {
    uint32_t f; memcpy(&f, &x, 4);
    uint32_t s = (f >> 16) & 0x8000; int e = (int)((f >> 23) & 0xff) - 127 + 15; uint32_t m = f & 0x7fffff;
    if (((f >> 23) & 0xff) == 0xff) return (uint16_t)(s | 0x7c00 | (m ? 0x200 : 0));
    if (e >= 31) return (uint16_t)(s | 0x7c00);
    if (e <= 0) {
        if (e < -10) return (uint16_t)s;
        m |= 0x800000; int shift = 14 - e;
        uint32_t hm = m >> shift, rem = m & ((1u << shift) - 1), half = 1u << (shift - 1);
        if (rem > half || (rem == half && (hm & 1))) hm++;
        return (uint16_t)(s | hm);
    }
    uint32_t hm = m >> 13, rem = m & 0x1fff;
    uint32_t h = s | ((uint32_t)e << 10) | hm;
    if (rem > 0x1000 || (rem == 0x1000 && (hm & 1))) h++;
    return (uint16_t)h;
}
static float bf16_to_float(uint16_t b) { uint32_t f = (uint32_t)b << 16; float r; memcpy(&r, &f, 4); return r; }
static uint16_t float_to_bf16(float x) {
    uint32_t f; memcpy(&f, &x, 4);
    if ((f & 0x7fffffff) > 0x7f800000) return (uint16_t)((f >> 16) | 0x40);
    f += 0x7fff + ((f >> 16) & 1);
    return (uint16_t)(f >> 16);
}

static unsigned read_bits(const uint8_t *p, size_t idx, int bits) {
    size_t bit = idx * (size_t)bits; unsigned v = 0;
    for (int b = 0; b < bits; b++, bit++) v |= (unsigned)((p[bit >> 3] >> (bit & 7)) & 1) << b;
    return v;
}
static void write_bits(uint8_t *p, size_t idx, int bits, unsigned v) {
    size_t bit = idx * (size_t)bits;
    for (int b = 0; b < bits; b++, bit++) {
        if ((v >> b) & 1) p[bit >> 3] |= (uint8_t)(1u << (bit & 7));
        else p[bit >> 3] &= (uint8_t)~(1u << (bit & 7));
    }
}

static long long read_int(BNNSDataType t, const void *data, size_t idx) {
    int bits = (int)(t & 0xff), sgn = (t & 0xff0000u) == BNNSDataTypeIntBit;
    switch (bits) {
    case 8: return sgn ? ((const int8_t *)data)[idx] : ((const uint8_t *)data)[idx];
    case 16: return sgn ? ((const int16_t *)data)[idx] : ((const uint16_t *)data)[idx];
    case 32: return sgn ? ((const int32_t *)data)[idx] : (long long)((const uint32_t *)data)[idx];
    case 64: return ((const int64_t *)data)[idx];
    default: {
        unsigned v = read_bits(data, idx, bits);
        if (sgn && (v >> (bits - 1))) return (long long)v - (1ll << bits);
        return v;
    }
    }
}
static void write_int(BNNSDataType t, void *data, size_t idx, long long v) {
    int bits = (int)(t & 0xff), sgn = (t & 0xff0000u) == BNNSDataTypeIntBit;
    long long lo = sgn ? -(1ll << (bits - 1)) : 0, hi = sgn ? (1ll << (bits - 1)) - 1 : (bits == 64 ? INT64_MAX : (1ll << bits) - 1);
    if (bits == 64) lo = sgn ? INT64_MIN : 0;
    if (v < lo) v = lo;
    if (v > hi) v = hi;
    switch (bits) {
    case 8: if (sgn) ((int8_t *)data)[idx] = (int8_t)v; else ((uint8_t *)data)[idx] = (uint8_t)v; break;
    case 16: if (sgn) ((int16_t *)data)[idx] = (int16_t)v; else ((uint16_t *)data)[idx] = (uint16_t)v; break;
    case 32: if (sgn) ((int32_t *)data)[idx] = (int32_t)v; else ((uint32_t *)data)[idx] = (uint32_t)v; break;
    case 64: ((int64_t *)data)[idx] = v; break;
    default: write_bits(data, idx, bits, (unsigned)(v & ((1ll << bits) - 1))); break;
    }
}
static long long float_to_ll(float f) {
    if (isnan(f)) return 0;
    if (f >= 9.2233715e18f) return INT64_MAX;
    if (f <= -9.2233715e18f) return INT64_MIN;
    return llrintf(f);
}

float bn_read(const BNNSNDArrayDescriptor *d, const void *data, size_t idx) {
    BNNSDataType t = d->data_type;
    switch (t) {
    case BNNSDataTypeFloat32: return ((const float *)data)[idx];
    case BNNSDataTypeFloat16: return half_to_float(((const uint16_t *)data)[idx]);
    case BNNSDataTypeBFloat16: return bf16_to_float(((const uint16_t *)data)[idx]);
    case BNNSDataTypeBoolean: return ((const uint8_t *)data)[idx] ? 1.0f : 0.0f;
    default: break;
    }
    if ((t & 0xff0000u) == BNNSDataTypeIndexedBit) {
        unsigned k = read_bits(data, idx, (int)(t & 0xff));
        if ((t & 0xff) == 8) k = ((const uint8_t *)data)[idx];
        if (!d->table_data) return 0;
        if (d->table_data_type == BNNSDataTypeFloat16) return half_to_float(((const uint16_t *)d->table_data)[k]);
        if (d->table_data_type == BNNSDataTypeBFloat16) return bf16_to_float(((const uint16_t *)d->table_data)[k]);
        return ((const float *)d->table_data)[k];
    }
    float scale = d->data_scale == 0 ? 1.0f : d->data_scale;
    return (float)read_int(t, data, idx) * scale + d->data_bias;
}
void bn_write(const BNNSNDArrayDescriptor *d, void *data, size_t idx, float v) {
    BNNSDataType t = d->data_type;
    switch (t) {
    case BNNSDataTypeFloat32: ((float *)data)[idx] = v; return;
    case BNNSDataTypeFloat16: ((uint16_t *)data)[idx] = float_to_half(v); return;
    case BNNSDataTypeBFloat16: ((uint16_t *)data)[idx] = float_to_bf16(v); return;
    case BNNSDataTypeBoolean: ((uint8_t *)data)[idx] = v != 0; return;
    default: break;
    }
    if ((t & 0xff0000u) == BNNSDataTypeIndexedBit) return;   /* indexed data is read-only */
    float scale = d->data_scale == 0 ? 1.0f : d->data_scale;
    write_int(t, data, idx, float_to_ll((v - d->data_bias) / scale));
}

/* ---- layouts ---- */
int bn_layout_rank(BNNSDataLayout l) {
    switch (l) {
    case BNNSDataLayoutVector: return 1;
    case BNNSDataLayoutRowMajorMatrix: case BNNSDataLayoutColumnMajorMatrix: case BNNSDataLayoutFullyConnectedSparse: return 2;
    case BNNSDataLayoutImageCHW: case BNNSDataLayoutSNE: case BNNSDataLayoutNSE: case BNNSDataLayoutMHA_DHK: return 3;
    case BNNSDataLayoutConvolutionWeightsOIHW: case BNNSDataLayoutConvolutionWeightsOIHrWr:
    case BNNSDataLayoutConvolutionWeightsIOHrWr: case BNNSDataLayoutConvolutionWeightsOIHW_Pack32: return 4;
    default: break;
    }
    unsigned r = (l >> 16) & 0xf, kind = l & 0xffff;
    if (r >= 1 && r <= 8 && (kind == 0x8000 || kind == 0x8001)) return (int)r;
    return -1;
}
int bn_layout_first_major(BNNSDataLayout l) {
    return bn_layout_rank(l) > 0 && (l & 0xffff) == 0x8001;
}
size_t BNNSDataLayoutGetRank(BNNSDataLayout layout) {
    int r = bn_layout_rank(layout);
    return r < 0 ? SIZE_MAX : (size_t)r;
}

int bn_dims_of(const BNNSNDArrayDescriptor *d, bn_dims *out) {
    int r = bn_layout_rank(d->layout);
    if (r < 0 || !bn_type_bits(d->data_type)) return -1;
    out->rank = r; out->count = 1;
    for (int k = 0; k < BN_MAXD; k++) out->n[k] = 1;
    for (int k = 0; k < r; k++) { out->n[k] = d->size[k]; out->count *= d->size[k]; }
    return 0;
}
int bn_strides(const BNNSNDArrayDescriptor *d, size_t st[BN_MAXD]) {
    int r = bn_layout_rank(d->layout), fm = bn_layout_first_major(d->layout);
    if (r < 0) return -1;
    /* memory slot j holds logical dimension j (or r-1-j for the first-major layouts) */
    size_t next = 1;
    for (int j = 0; j < r; j++) {
        int k = fm ? r - 1 - j : j;
        size_t s = d->stride[j] ? d->stride[j] : next;
        st[k] = s; next = s * d->size[k];
    }
    for (int k = r; k < BN_MAXD; k++) st[k] = 0;
    return 0;
}
size_t bn_span_bytes(const BNNSNDArrayDescriptor *d) {
    bn_dims dm; size_t st[BN_MAXD];
    if (bn_dims_of(d, &dm) || bn_strides(d, st)) return 0;
    if (!dm.count) return 0;
    size_t last = 0;
    for (int k = 0; k < dm.rank; k++) last += (dm.n[k] - 1) * st[k];
    size_t bits = (last + 1) * (size_t)bn_type_bits(d->data_type);
    return (bits + 7) / 8;
}
size_t BNNSNDArrayGetDataSize(const BNNSNDArrayDescriptor *array) {
    if (!array || !array->data) return 0;
    return bn_span_bytes(array);
}
size_t BNNSTensorGetAllocationSize(const BNNSTensor *t) {
    if (!t) return SIZE_MAX;
    int bits = bn_type_bits(t->data_type);
    if (!bits || t->rank > BN_MAXD) return SIZE_MAX;
    size_t last = 0;
    for (int k = 0; k < t->rank; k++) {   /* a BNNSTensor's stride is literal: 0 repeats, negative is unknown */
        if (t->shape[k] < 0 || t->stride[k] < 0) return SIZE_MAX;
        if (!t->shape[k]) return 0;
        last += ((size_t)t->shape[k] - 1) * (size_t)t->stride[k];
    }
    return ((last + 1) * (size_t)bits + 7) / 8;
}

void bn_unravel(const bn_dims *d, size_t i, size_t *pos) {
    for (int k = 0; k < BN_MAXD; k++) { pos[k] = d->n[k] ? i % d->n[k] : 0; i = d->n[k] ? i / d->n[k] : 0; }
}
size_t bn_bcast_index(const bn_dims *a, const bn_dims *out, const size_t *pos) {
    size_t idx = 0, mul = 1;
    (void)out;
    for (int k = 0; k < BN_MAXD; k++) { size_t p = a->n[k] == 1 ? 0 : pos[k]; idx += p * mul; mul *= a->n[k]; }
    return idx;
}

static size_t offset_of(const bn_dims *dm, const size_t *st, size_t i) {
    size_t off = 0;
    for (int k = 0; k < dm->rank; k++) { off += (i % dm->n[k]) * st[k]; i /= dm->n[k]; }
    return off;
}
float *bn_load(const BNNSNDArrayDescriptor *d, const void *data, bn_dims *dims) {
    bn_dims dm; size_t st[BN_MAXD];
    if (!d || bn_dims_of(d, &dm) || bn_strides(d, st)) return NULL;
    if (!data) data = d->data;
    if (!data && dm.count) return NULL;
    float *v = malloc((dm.count ? dm.count : 1) * sizeof(float));
    if (!v) return NULL;
    for (size_t i = 0; i < dm.count; i++) v[i] = bn_read(d, data, offset_of(&dm, st, i));
    if (dims) *dims = dm;
    return v;
}
int bn_store(const BNNSNDArrayDescriptor *d, void *data, const float *v, int accumulate) {
    bn_dims dm; size_t st[BN_MAXD];
    if (!d || bn_dims_of(d, &dm) || bn_strides(d, st)) return -1;
    if (!data) data = d->data;
    if (!data && dm.count) return -1;
    if ((d->data_type & 0xff0000u) == BNNSDataTypeIndexedBit) return -1;
    for (size_t i = 0; i < dm.count; i++) {
        size_t off = offset_of(&dm, st, i);
        bn_write(d, data, off, accumulate ? bn_read(d, data, off) + v[i] : v[i]);
    }
    return 0;
}
long long *bn_load_index(const BNNSNDArrayDescriptor *d, const void *data, bn_dims *dims) {
    bn_dims dm; size_t st[BN_MAXD];
    if (!d || bn_dims_of(d, &dm) || bn_strides(d, st)) return NULL;
    if (!data) data = d->data;
    if (!data && dm.count) return NULL;
    long long *v = malloc((dm.count ? dm.count : 1) * sizeof(long long));
    if (!v) return NULL;
    unsigned cls = d->data_type & 0xff0000u;
    for (size_t i = 0; i < dm.count; i++) {
        size_t off = offset_of(&dm, st, i);
        v[i] = (cls == BNNSDataTypeIntBit || cls == BNNSDataTypeUIntBit) ? read_int(d->data_type, data, off)
                                                                        : float_to_ll(bn_read(d, data, off));
    }
    if (dims) *dims = dm;
    return v;
}

/* ---- activations ---- */
static float sigm(float x) { return 1.0f / (1.0f + expf(-x)); }
int bn_activation_is_grouped(BNNSActivationFunction f) {
    return f == BNNSActivationFunctionSoftmax || f == BNNSActivationFunctionLogSoftmax || f == BNNSActivationFunctionGumbelMax;
}
void bn_softmax(float *v, size_t len, size_t stride, int logsoftmax) {
    float m = -INFINITY; double s = 0;
    for (size_t i = 0; i < len; i++) if (v[i * stride] > m) m = v[i * stride];
    for (size_t i = 0; i < len; i++) s += exp((double)v[i * stride] - m);
    for (size_t i = 0; i < len; i++) {
        float x = v[i * stride] - m;
        v[i * stride] = logsoftmax ? (float)(x - log(s)) : (float)(exp(x) / s);
    }
}
static uint64_t gumbel_state = 0x9e3779b97f4a7c15ull;
static float uniform01(void) {
    gumbel_state ^= gumbel_state << 13; gumbel_state ^= gumbel_state >> 7; gumbel_state ^= gumbel_state << 17;
    return ((gumbel_state >> 40) + 0.5f) / 16777216.0f;
}
static float act1(const BNNSActivation *a, float x, size_t ch, const float *prelu) {
    float al = a->alpha, be = a->beta;
    switch (a->function) {
    case BNNSActivationFunctionIdentity: return x;
    case BNNSActivationFunctionRectifiedLinear: return x > 0 ? x : 0;
    case BNNSActivationFunctionReLU6: return fminf(fmaxf(x, 0), 6);
    case BNNSActivationFunctionLeakyRectifiedLinear: return x > 0 ? x : (prelu ? prelu[0] : al) * x;
    case BNNSActivationFunctionPReLUPerChannel: return x > 0 ? x : (prelu ? prelu[ch] : al) * x;
    case BNNSActivationFunctionSigmoid: return sigm(x);
    case BNNSActivationFunctionLogSigmoid: return x >= 0 ? -log1pf(expf(-x)) : x - log1pf(expf(x));
    case BNNSActivationFunctionTanh: return tanhf(x);
    case BNNSActivationFunctionScaledTanh: return al * tanhf(x * be);
    case BNNSActivationFunctionAbs: return fabsf(x);
    case BNNSActivationFunctionLinear: return al * x;
    case BNNSActivationFunctionClamp: return fminf(fmaxf(x, al), be);
    case BNNSActivationFunctionIntegerLinearSaturate:
    case BNNSActivationFunctionIntegerLinearSaturatePerChannel: {
        long long s = a->iscale, o = a->ioffset, sh = a->ishift;
        if (a->function == BNNSActivationFunctionIntegerLinearSaturatePerChannel) {
            s = a->iscale_per_channel ? a->iscale_per_channel[ch] : 1;
            o = a->ioffset_per_channel ? a->ioffset_per_channel[ch] : 0;
            sh = a->ishift_per_channel ? a->ishift_per_channel[ch] : 0;
        }
        long long r = (s * (long long)llrintf(x) + o) >> sh;
        return (float)r;   /* saturation happens when the destination type is written */
    }
    case BNNSActivationFunctionGELUApproximation: return 0.5f * x * (1.0f + tanhf(al * (x + be * x * x * x)));
    case BNNSActivationFunctionGumbel: return -logf(-logf(al * uniform01() + be) + be);
    case BNNSActivationFunctionHardSigmoid: return fmaxf(0, fminf(1, al * x + be));
    case BNNSActivationFunctionSoftplus: return al * log1pf(expf(be * x));
    case BNNSActivationFunctionSoftsign: return x / (1 + fabsf(x));
    case BNNSActivationFunctionELU: return x < 0 ? al * expm1f(x) : x;
    case BNNSActivationFunctionSELU: return x < 0 ? 1.0507009873554805f * 1.6732632423543772f * expm1f(x) : 1.0507009873554805f * x;
    case BNNSActivationFunctionCELU: return x < 0 ? al * expm1f(x / al) : x;
    case BNNSActivationFunctionClampedLeakyRectifiedLinear: return x < 0 ? al * x : fminf(x, be);
    case BNNSActivationFunctionLinearWithBias: return al * x + be;
    case BNNSActivationFunctionHardShrink: return fabsf(x) < fabsf(al) ? 0 : x;
    case BNNSActivationFunctionSoftShrink: return fabsf(x) < fabsf(al) ? 0 : x - copysignf(fabsf(al), x);
    case BNNSActivationFunctionTanhShrink: return x - tanhf(x);
    case BNNSActivationFunctionThreshold: return x <= al ? be : x;
    case BNNSActivationFunctionGELUApproximation2: return x * fminf(fmaxf(x + 3, 0), 6) / 6.0f;
    case BNNSActivationFunctionSiLU: return x * sigm(x);
    case BNNSActivationFunctionErf: return erff(x);
    case BNNSActivationFunctionGELU: return 0.5f * x * (1 + erff(x / sqrtf(2)));
    case BNNSActivationFunctionGELUApproximationSigmoid: return x * sigm(1.702f * x);
    default: return x;
    }
}
void bn_activation(const BNNSActivation *a, float *v, size_t n, size_t inner, size_t channels, const float *prelu) {
    if (!a) return;
    if (bn_activation_is_grouped(a->function)) {
        /* over groups of `inner` consecutive values (the first dimension) */
        size_t g = inner ? inner : n;
        for (size_t o = 0; o + g <= n; o += g) {
            if (a->function == BNNSActivationFunctionGumbelMax) {
                float best = -INFINITY;
                for (size_t i = 0; i < g; i++) {
                    float y = -logf(-logf(a->alpha * uniform01() + a->beta) + a->beta) + v[o + i];
                    if (y > best) best = y;
                }
                for (size_t i = 0; i < g; i++) v[o + i] = best;
            } else bn_softmax(v + o, g, 1, a->function == BNNSActivationFunctionLogSoftmax);
        }
        return;
    }
    if (a->function == BNNSActivationFunctionIdentity) return;
    for (size_t i = 0; i < n; i++) {
        size_t ch = (inner && channels) ? (i / inner) % channels : 0;
        v[i] = act1(a, v[i], ch, prelu);
    }
}
static float dact1(const BNNSActivation *a, float x, float y, size_t ch, const float *prelu) {
    float al = a->alpha, be = a->beta;
    switch (a->function) {
    case BNNSActivationFunctionIdentity: return 1;
    case BNNSActivationFunctionRectifiedLinear: return x > 0;
    case BNNSActivationFunctionReLU6: return x > 0 && x < 6;
    case BNNSActivationFunctionLeakyRectifiedLinear: return x > 0 ? 1 : (prelu ? prelu[0] : al);
    case BNNSActivationFunctionPReLUPerChannel: return x > 0 ? 1 : (prelu ? prelu[ch] : al);
    case BNNSActivationFunctionSigmoid: return y * (1 - y);
    case BNNSActivationFunctionLogSigmoid: return 1 - sigm(x);
    case BNNSActivationFunctionTanh: return 1 - y * y;
    case BNNSActivationFunctionScaledTanh: { float t = tanhf(x * be); return al * be * (1 - t * t); }
    case BNNSActivationFunctionAbs: return x > 0 ? 1 : (x < 0 ? -1 : 0);
    case BNNSActivationFunctionLinear: return al;
    case BNNSActivationFunctionClamp: return x > al && x < be;
    case BNNSActivationFunctionGELUApproximation: {
        float u = al * (x + be * x * x * x), t = tanhf(u);
        return 0.5f * (1 + t) + 0.5f * x * (1 - t * t) * al * (1 + 3 * be * x * x);
    }
    case BNNSActivationFunctionHardSigmoid: { float z = al * x + be; return (z > 0 && z < 1) ? al : 0; }
    case BNNSActivationFunctionSoftplus: return al * be * sigm(be * x);
    case BNNSActivationFunctionSoftsign: { float d = 1 + fabsf(x); return 1 / (d * d); }
    case BNNSActivationFunctionELU: return x < 0 ? al * expf(x) : 1;
    case BNNSActivationFunctionSELU: return x < 0 ? 1.0507009873554805f * 1.6732632423543772f * expf(x) : 1.0507009873554805f;
    case BNNSActivationFunctionCELU: return x < 0 ? expf(x / al) : 1;
    case BNNSActivationFunctionClampedLeakyRectifiedLinear: return x < 0 ? al : (x < be ? 1 : 0);
    case BNNSActivationFunctionLinearWithBias: return al;
    case BNNSActivationFunctionHardShrink: case BNNSActivationFunctionSoftShrink: return fabsf(x) < fabsf(al) ? 0 : 1;
    case BNNSActivationFunctionTanhShrink: { float t = tanhf(x); return t * t; }
    case BNNSActivationFunctionThreshold: return x <= al ? 0 : 1;
    case BNNSActivationFunctionGELUApproximation2: return x < -3 ? 0 : (x > 3 ? 1 : (2 * x + 3) / 6.0f);
    case BNNSActivationFunctionSiLU: { float s = sigm(x); return s * (1 + x * (1 - s)); }
    case BNNSActivationFunctionErf: return 2 / sqrtf((float)M_PI) * expf(-x * x);
    case BNNSActivationFunctionGELU: return 0.5f * (1 + erff(x / sqrtf(2))) + x * expf(-0.5f * x * x) / sqrtf(2 * (float)M_PI);
    case BNNSActivationFunctionGELUApproximationSigmoid: { float s = sigm(1.702f * x); return s + 1.702f * x * s * (1 - s); }
    default: return 1;
    }
}
void bn_activation_backward(const BNNSActivation *a, const float *x, const float *y, float *g, size_t n,
                            size_t inner, size_t channels, const float *prelu, float *dalpha) {
    if (!a || a->function == BNNSActivationFunctionIdentity) return;
    if (a->function == BNNSActivationFunctionSoftmax || a->function == BNNSActivationFunctionLogSoftmax) {
        size_t gsz = inner ? inner : n;
        for (size_t o = 0; o + gsz <= n; o += gsz) {
            double dot = 0;
            if (a->function == BNNSActivationFunctionSoftmax) {
                for (size_t i = 0; i < gsz; i++) dot += (double)g[o + i] * y[o + i];
                for (size_t i = 0; i < gsz; i++) g[o + i] = y[o + i] * (float)(g[o + i] - dot);
            } else {
                for (size_t i = 0; i < gsz; i++) dot += g[o + i];
                for (size_t i = 0; i < gsz; i++) g[o + i] = g[o + i] - expf(y[o + i]) * (float)dot;
            }
        }
        return;
    }
    for (size_t i = 0; i < n; i++) {
        size_t ch = (inner && channels) ? (i / inner) % channels : 0;
        if (dalpha && x[i] <= 0) {
            if (a->function == BNNSActivationFunctionLeakyRectifiedLinear) dalpha[0] += g[i] * x[i];
            else if (a->function == BNNSActivationFunctionPReLUPerChannel) dalpha[ch] += g[i] * x[i];
        }
        g[i] *= dact1(a, x[i], y ? y[i] : act1(a, x[i], ch, prelu), ch, prelu);
    }
}

/* ---- allocation and filters ---- */
void *bn_alloc(const BNNSFilterParameters *fp, size_t size) {
    if (!size) size = 1;
    if (fp && fp->alloc_memory) {
        void *p = NULL;
        if (fp->alloc_memory(&p, 64, size) || !p) return NULL;
        memset(p, 0, size);
        return p;
    }
    return calloc(1, size);
}
void bn_free(const BNNSFilterParameters *fp, void *p) {
    if (!p) return;
    if (fp && fp->free_memory) fp->free_memory(p);
    else free(p);
}
bn_filter *bn_filter_new(int kind, const BNNSFilterParameters *fp, size_t state_size) {
    bn_filter *f = bn_alloc(fp, sizeof(bn_filter));
    if (!f) return NULL;
    f->magic = BN_FILTER_MAGIC; f->kind = kind;
    if (fp) f->fp = *fp;
    if (state_size) {
        f->state = calloc(1, state_size);
        if (!f->state) { bn_free(fp, f); return NULL; }
    }
    return f;
}
bn_filter *bn_filter_of(BNNSFilter f) {
    bn_filter *b = f;
    return (b && b->magic == BN_FILTER_MAGIC) ? b : NULL;
}
void BNNSFilterDestroy(BNNSFilter filter) {
    bn_filter *f = bn_filter_of(filter);
    if (!f) return;
    if (f->destroy) f->destroy(f);
    free(f->state);
    f->magic = 0;
    BNNSFilterParameters fp = f->fp;
    bn_free(&fp, f);
}
int bn_keep(BNNSNDArrayDescriptor *dst, const BNNSNDArrayDescriptor *src) {
    *dst = *src;
    if (!src->data) return 0;
    size_t n = bn_span_bytes(src);
    if (!n) { dst->data = NULL; return 0; }
    dst->data = malloc(n);
    if (!dst->data) return -1;
    memcpy(dst->data, src->data, n);
    return 0;
}
void bn_unkeep(BNNSNDArrayDescriptor *d) { free(d->data); d->data = NULL; }
