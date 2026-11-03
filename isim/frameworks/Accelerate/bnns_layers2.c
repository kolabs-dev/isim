// isim Accelerate BNNS (issue #808): arithmetic, broadcast matrix product, tensor contraction, loss and fused filters,
// and the multihead attention / LSTM entry points (stubs: they fail with an error).
#include "bnns_layer.h"

#define FAIL(...) do { __VA_ARGS__; return -1; } while (0)
static size_t dcount(const BNNSNDArrayDescriptor *d) { bn_dims x; return bn_dims_of(d, &x) ? 0 : x.count; }

/* ---- arithmetic ---- */
static int arity_of(BNNSArithmeticFunction f) {
    switch (f) {
    case BNNSArithmeticAdd: case BNNSArithmeticSubtract: case BNNSArithmeticMultiply: case BNNSArithmeticDivide:
    case BNNSArithmeticPow: case BNNSArithmeticMultiplyNoNaN: case BNNSArithmeticDivideNoNaN: case BNNSArithmeticMinimum:
    case BNNSArithmeticMaximum: case BNNSArithmeticFloorDivide: case BNNSArithmeticTruncDivide: case BNNSArithmeticTruncRemainder:
        return 2;
    case BNNSArithmeticMultiplyAdd: case BNNSArithmeticSelect: return 3;
    default: return f <= BNNSArithmeticErf ? 1 : 0;
    }
}
static float arith1(BNNSArithmeticFunction f, float a, float b, float c) {
    switch (f) {
    case BNNSArithmeticAdd: return a + b;
    case BNNSArithmeticSubtract: return a - b;
    case BNNSArithmeticMultiply: return a * b;
    case BNNSArithmeticDivide: return a / b;
    case BNNSArithmeticSquareRoot: return sqrtf(a);
    case BNNSArithmeticReciprocalSquareRoot: return 1 / sqrtf(a);
    case BNNSArithmeticCeil: return ceilf(a);
    case BNNSArithmeticFloor: return floorf(a);
    case BNNSArithmeticRound: return rintf(a);
    case BNNSArithmeticSin: return sinf(a);
    case BNNSArithmeticCos: return cosf(a);
    case BNNSArithmeticTan: return tanf(a);
    case BNNSArithmeticAsin: return asinf(a);
    case BNNSArithmeticAcos: return acosf(a);
    case BNNSArithmeticAtan: return atanf(a);
    case BNNSArithmeticSinh: return sinhf(a);
    case BNNSArithmeticCosh: return coshf(a);
    case BNNSArithmeticTanh: return tanhf(a);
    case BNNSArithmeticAsinh: return asinhf(a);
    case BNNSArithmeticAcosh: return acoshf(a);
    case BNNSArithmeticAtanh: return atanhf(a);
    case BNNSArithmeticPow: return powf(a, b);
    case BNNSArithmeticExp: return expf(a);
    case BNNSArithmeticExp2: return exp2f(a);
    case BNNSArithmeticLog: return logf(a);
    case BNNSArithmeticLog2: return log2f(a);
    case BNNSArithmeticMultiplyNoNaN: return b == 0 ? 0 : a * b;
    case BNNSArithmeticDivideNoNaN: return b == 0 ? 0 : a / b;
    case BNNSArithmeticMultiplyAdd: return a * b + c;
    case BNNSArithmeticMinimum: return fminf(a, b);
    case BNNSArithmeticMaximum: return fmaxf(a, b);
    case BNNSArithmeticSelect: return a != 0 ? b : c;
    case BNNSArithmeticAbs: return fabsf(a);
    case BNNSArithmeticSign: return a > 0 ? 1.0f : (a < 0 ? -1.0f : 0.0f);
    case BNNSArithmeticNegate: return -a;
    case BNNSArithmeticReciprocal: return 1 / a;
    case BNNSArithmeticSquare: return a * a;
    case BNNSArithmeticFloorDivide: return floorf(a / b);
    case BNNSArithmeticTruncDivide: return truncf(a / b);
    case BNNSArithmeticTruncRemainder: return fmodf(a, b);
    case BNNSArithmeticErf: return erff(a);
    default: return 0;
    }
}
/* partial derivatives with respect to a, b, c */
static void darith1(BNNSArithmeticFunction f, float a, float b, float c, float *da, float *db, float *dc) {
    *da = *db = *dc = 0;
    (void)c;
    switch (f) {
    case BNNSArithmeticAdd: *da = 1; *db = 1; break;
    case BNNSArithmeticSubtract: *da = 1; *db = -1; break;
    case BNNSArithmeticMultiply: *da = b; *db = a; break;
    case BNNSArithmeticMultiplyNoNaN: if (b != 0) { *da = b; *db = a; } break;
    case BNNSArithmeticDivide: *da = 1 / b; *db = -a / (b * b); break;
    case BNNSArithmeticDivideNoNaN: if (b != 0) { *da = 1 / b; *db = -a / (b * b); } break;
    case BNNSArithmeticSquareRoot: *da = 0.5f / sqrtf(a); break;
    case BNNSArithmeticReciprocalSquareRoot: *da = -0.5f / (a * sqrtf(a)); break;
    case BNNSArithmeticSin: *da = cosf(a); break;
    case BNNSArithmeticCos: *da = -sinf(a); break;
    case BNNSArithmeticTan: { float t = cosf(a); *da = 1 / (t * t); break; }
    case BNNSArithmeticAsin: *da = 1 / sqrtf(1 - a * a); break;
    case BNNSArithmeticAcos: *da = -1 / sqrtf(1 - a * a); break;
    case BNNSArithmeticAtan: *da = 1 / (1 + a * a); break;
    case BNNSArithmeticSinh: *da = coshf(a); break;
    case BNNSArithmeticCosh: *da = sinhf(a); break;
    case BNNSArithmeticTanh: { float t = tanhf(a); *da = 1 - t * t; break; }
    case BNNSArithmeticAsinh: *da = 1 / sqrtf(a * a + 1); break;
    case BNNSArithmeticAcosh: *da = 1 / sqrtf(a * a - 1); break;
    case BNNSArithmeticAtanh: *da = 1 / (1 - a * a); break;
    case BNNSArithmeticPow: *da = b * powf(a, b - 1); *db = a > 0 ? powf(a, b) * logf(a) : 0; break;
    case BNNSArithmeticExp: *da = expf(a); break;
    case BNNSArithmeticExp2: *da = exp2f(a) * (float)M_LN2; break;
    case BNNSArithmeticLog: *da = 1 / a; break;
    case BNNSArithmeticLog2: *da = 1 / (a * (float)M_LN2); break;
    case BNNSArithmeticMultiplyAdd: *da = b; *db = a; *dc = 1; break;
    case BNNSArithmeticMinimum: if (a <= b) *da = 1; else *db = 1; break;
    case BNNSArithmeticMaximum: if (a >= b) *da = 1; else *db = 1; break;
    case BNNSArithmeticSelect: if (a != 0) *db = 1; else *dc = 1; break;
    case BNNSArithmeticAbs: *da = a > 0 ? 1.0f : (a < 0 ? -1.0f : 0.0f); break;
    case BNNSArithmeticNegate: *da = -1; break;
    case BNNSArithmeticReciprocal: *da = -1 / (a * a); break;
    case BNNSArithmeticSquare: *da = 2 * a; break;
    case BNNSArithmeticTruncRemainder: *da = 1; *db = -truncf(a / b); break;
    case BNNSArithmeticErf: *da = 2 / sqrtf((float)M_PI) * expf(-a * a); break;
    default: break;
    }
}
int bn_arith_forward(bn_layer *L, const float *const *x, const bn_dims *xd, float *y, const bn_dims *yd) {
    size_t pos[BN_MAXD];
    for (size_t i = 0; i < yd->count; i++) {
        bn_unravel(yd, i, pos);
        float v[3] = {0, 0, 0};
        for (int k = 0; k < L->arity; k++) v[k] = x[k] ? x[k][bn_bcast_index(&xd[k], yd, pos)] : 0;
        y[i] = arith1(L->afn, v[0], v[1], v[2]);
    }
    bn_activation(&L->act, y, yd->count, 1, 0, NULL);
    return 0;
}
static int arith_apply(bn_filter *f, size_t batch, size_t nin, const void *const *in, const size_t *in_stride, void *out, size_t out_stride) {
    bn_layer *L = bn_layer_of(f);
    if (!L || f->kind != BK_ARITH || (int)nin < L->arity || !out) return -1;
    bn_dims xd[3], yd;
    for (int k = 0; k < L->arity; k++) if (bn_dims_of(&L->ain[k], &xd[k])) return -1;
    if (bn_dims_of(&L->aout, &yd)) return -1;
    float *y = malloc(yd.count * sizeof(float) + 1);
    int r = y ? 0 : -1;
    for (size_t b = 0; b < batch && !r; b++) {
        float *x[3] = {0};
        for (int k = 0; k < L->arity && !r; k++) {
            const void *p = in && in[k] ? in[k] : L->ain[k].data;
            size_t st = L->atype[k] == BNNSSample && in_stride ? in_stride[k] : 0;
            x[k] = p ? bn_load(&L->ain[k], (const char *)p + bn_bytes(&L->ain[k], b * st), NULL) : NULL;
            if (!x[k]) r = -1;
        }
        if (!r) r = bn_arith_forward(L, (const float *const *)x, xd, y, &yd);
        size_t ost = L->atype[0] == BNNSSample || L->arity > 1 ? out_stride : out_stride;
        if (!r) r = bn_store(&L->aout, (char *)out + bn_bytes(&L->aout, b * ost), y, 0);
        for (int k = 0; k < 3; k++) free(x[k]);
    }
    free(y);
    return r;
}
static int arith_backward(bn_filter *f, size_t batch, size_t nin, const void *const *in, const size_t *in_stride,
                          BNNSNDArrayDescriptor *const *in_delta, const size_t *in_delta_stride, const void *out, size_t out_stride,
                          const BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride) {
    bn_layer *L = bn_layer_of(f);
    if (!L || (int)nin < L->arity || !out_delta || !out_delta->data) return -1;
    bn_dims xd[3], yd;
    for (int k = 0; k < L->arity; k++) if (bn_dims_of(&L->ain[k], &xd[k])) return -1;
    bn_dims_of(&L->aout, &yd);
    size_t pos[BN_MAXD];
    /* gradients of constant / parameter inputs accumulate over the batch */
    float *acc[3] = {0};
    for (int k = 0; k < L->arity; k++) if (L->atype[k] != BNNSSample) acc[k] = calloc(xd[k].count + 1, sizeof(float));
    int r = 0;
    for (size_t b = 0; b < batch && !r; b++) {
        float *x[3] = {0}, *dx[3] = {0};
        for (int k = 0; k < L->arity; k++) {
            const void *p = in && in[k] ? in[k] : L->ain[k].data;
            size_t st = L->atype[k] == BNNSSample && in_stride ? in_stride[k] : 0;
            x[k] = p ? bn_load(&L->ain[k], (const char *)p + bn_bytes(&L->ain[k], b * st), NULL) : NULL;
            dx[k] = L->atype[k] == BNNSSample ? calloc(xd[k].count + 1, sizeof(float)) : acc[k];
            if (!x[k] || !dx[k]) r = -1;
        }
        float *g = r ? NULL : bn_load(out_delta, (const char *)out_delta->data + bn_bytes(out_delta, b * out_delta_stride), NULL);
        float *y = out && !r ? bn_load(&L->aout, (const char *)out + bn_bytes(&L->aout, b * out_stride), NULL) : NULL;
        if (!r && !g) r = -1;
        if (!r) {
            /* back through the activation: recompute z */
            if (L->act.function != BNNSActivationFunctionIdentity) {
                float *z = malloc(yd.count * sizeof(float) + 1), *yy = malloc(yd.count * sizeof(float) + 1);
                BNNSActivation keep = L->act; L->act.function = BNNSActivationFunctionIdentity;
                bn_arith_forward(L, (const float *const *)x, xd, z, &yd);
                L->act = keep;
                memcpy(yy, z, yd.count * sizeof(float));
                bn_activation(&L->act, yy, yd.count, 1, 0, NULL);
                bn_activation_backward(&L->act, z, yy, g, yd.count, 1, 0, NULL, NULL);
                free(z); free(yy);
            }
            for (size_t i = 0; i < yd.count; i++) {
                bn_unravel(&yd, i, pos);
                size_t ix[3]; float v[3] = {0, 0, 0}, d[3];
                for (int k = 0; k < L->arity; k++) { ix[k] = bn_bcast_index(&xd[k], &yd, pos); v[k] = x[k][ix[k]]; }
                darith1(L->afn, v[0], v[1], v[2], &d[0], &d[1], &d[2]);
                for (int k = 0; k < L->arity; k++) dx[k][ix[k]] += g[i] * d[k];
            }
            for (int k = 0; k < L->arity && !r; k++)
                if (L->atype[k] == BNNSSample && in_delta && in_delta[k] && in_delta[k]->data) {
                    size_t st = in_delta_stride ? in_delta_stride[k] : 0;
                    r = bn_store(in_delta[k], (char *)in_delta[k]->data + bn_bytes(in_delta[k], b * st), dx[k],
                                 in_delta[k]->flags == BNNSNDArrayFlagBackpropAccumulate);
                }
        }
        for (int k = 0; k < 3; k++) { free(x[k]); if (L->atype[k] == BNNSSample) free(dx[k]); }
        free(g); free(y);
    }
    for (int k = 0; k < L->arity; k++) {
        if (!r && acc[k] && in_delta && in_delta[k] && in_delta[k]->data)
            r = bn_store(in_delta[k], NULL, acc[k], in_delta[k]->flags == BNNSNDArrayFlagBackpropAccumulate);
        free(acc[k]);
    }
    return r;
}
BNNSFilter BNNSFilterCreateLayerArithmetic(const BNNSLayerParametersArithmetic *p, const BNNSFilterParameters *fp) {
    if (!p || !p->arithmetic_function_fields) return NULL;
    int n = arity_of(p->arithmetic_function);
    if (!n) return NULL;
    bn_filter *f = bn_layer_new(BK_ARITH, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->afn = p->arithmetic_function; L->arity = n; L->act = p->activation;
    if (n == 1) {
        const BNNSArithmeticUnary *u = p->arithmetic_function_fields;
        L->ain[0] = u->in; L->atype[0] = u->in_type; L->aout = u->out;
    } else if (n == 2) {
        const BNNSArithmeticBinary *u = p->arithmetic_function_fields;
        L->ain[0] = u->in1; L->atype[0] = u->in1_type; L->ain[1] = u->in2; L->atype[1] = u->in2_type; L->aout = u->out;
    } else {
        const BNNSArithmeticTernary *u = p->arithmetic_function_fields;
        L->ain[0] = u->in1; L->atype[0] = u->in1_type; L->ain[1] = u->in2; L->atype[1] = u->in2_type;
        L->ain[2] = u->in3; L->atype[2] = u->in3_type; L->aout = u->out;
    }
    bn_dims d, o;
    int ok = !bn_dims_of(&L->aout, &o) && !bn_activation_is_grouped(L->act.function);
    for (int k = 0; k < n && ok; k++) {
        if (bn_dims_of(&L->ain[k], &d)) ok = 0;
        for (int q = 0; q < BN_MAXD && ok; q++) if (d.n[q] != o.n[q] && d.n[q] != 1) ok = 0;
    }
    L->i = L->ain[0]; L->o = L->aout;
    if (!ok) { BNNSFilterDestroy(f); return NULL; }
    return f;
}
int BNNSArithmeticFilterApplyBatch(BNNSFilter filter, size_t batch_size, size_t number_of_inputs, const void **in,
                                   const size_t *in_stride, void *out, size_t out_stride) {
    bn_filter *f = bn_filter_of(filter);
    return f ? arith_apply(f, batch_size, number_of_inputs, in, in_stride, out, out_stride) : -1;
}
int BNNSArithmeticFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, size_t number_of_inputs, const void **in,
                                           const size_t *in_stride, BNNSNDArrayDescriptor **in_delta, const size_t *in_delta_stride,
                                           const void *out, const size_t out_stride, BNNSNDArrayDescriptor *out_delta,
                                           const size_t out_delta_stride) {
    bn_filter *f = bn_filter_of(filter);
    if (!f || f->kind != BK_ARITH) return -1;
    return arith_backward(f, batch_size, number_of_inputs, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta,
                          out_delta_stride);
}

/* ---- broadcast matrix product layer ---- */
static void dense_desc(BNNSNDArrayDescriptor *d, void *data) {
    d->data = data; d->data_type = BNNSDataTypeFloat32; d->data_scale = 1; d->data_bias = 0;
    memset(d->stride, 0, sizeof d->stride);
    if (bn_layout_first_major(d->layout)) d->layout = (BNNSDataLayout)((d->layout & ~0xffffu) | 0x8000);
}
/* first-major sizes are stored in the opposite memory order: give the dense copy the same logical dims, last-major */
BNNSFilter BNNSFilterCreateLayerBroadcastMatMul(const BNNSLayerParametersBroadcastMatMul *p, const BNNSFilterParameters *fp) {
    if (!p || (p->a_is_weights && p->b_is_weights)) return NULL;
    bn_dims d;
    if (bn_dims_of(&p->iA_desc, &d) || bn_dims_of(&p->iB_desc, &d) || bn_dims_of(&p->o_desc, &d)) return NULL;
    bn_filter *f = bn_layer_new(BK_BMM, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.bmm = *p;
    L->i = p->a_is_weights ? p->iB_desc : p->iA_desc; L->i2 = p->iB_desc; L->o = p->o_desc;
    int ok = 1;
    if (p->a_is_weights) ok = p->iA_desc.data && !bn_layer_keep(f, &L->w, &p->iA_desc, &L->owns_w);
    if (p->b_is_weights) ok = p->iB_desc.data && !bn_layer_keep(f, &L->w, &p->iB_desc, &L->owns_w);
    if (!ok) { BNNSFilterDestroy(f); return NULL; }
    return f;
}
static int bmm_compute(bn_layer *L, const float *a, const float *b, float *y) {
    BNNSNDArrayDescriptor A = L->p.bmm.iA_desc, B = L->p.bmm.iB_desc, C = L->o;
    dense_desc(&A, (void *)a); dense_desc(&B, (void *)b); dense_desc(&C, y);
    return bn_matmul(L->p.bmm.transA, L->p.bmm.transB, L->p.bmm.alpha, &A, &B, &C, 0);
}

/* ---- tensor contraction ("a_ij, b_jk -> c_ik"; '*' broadcasts leading or trailing dimensions) ---- */
static const char *skip_ws(const char *s) { while (*s == ' ' || *s == '\t') s++; return s; }
static const char *parse_operand(const char *s, char *name, char *idx, int *n, int *star) {
    s = skip_ws(s);
    if (!*s) return NULL;
    *name = *s++;
    while (*s && *s != '_') s++;
    if (*s != '_') return NULL;
    s++;
    *n = 0;
    while (*s && *s != ',' && *s != '-' && *s != ' ') {
        if (*s == '*') *star = *n == 0 ? 1 : 2;
        else { if (*n >= BN_MAXD) return NULL; idx[(*n)++] = *s; }
        s++;
    }
    idx[*n] = 0;
    return skip_ws(s);
}
int bn_contract_parse(bn_layer *L, const char *op) {
    if (!op) return -1;
    char names[3]; int star = 0, s0 = 0, s1 = 0, s2 = 0;
    const char *s = parse_operand(op, &names[0], L->cspec[0], &L->cn[0], &s0);
    if (!s) return -1;
    int two = *s == ',';
    if (two) { s = parse_operand(s + 1, &names[1], L->cspec[1], &L->cn[1], &s1); if (!s) return -1; }
    else L->cn[1] = -1;
    if (s[0] != '-' || s[1] != '>') return -1;
    s = parse_operand(s + 2, &names[2], L->cspec[2], &L->cn[2], &s2);
    if (!s || *s) return -1;
    star = s0 | s1 | s2;
    L->cstar = star;
    L->cself = two && names[0] == names[1];
    L->cweights = two ? (names[0] == 'w' ? 1 : names[1] == 'w' ? 2 : 0) : 0;
    return 0;
}
/* the letter's size from an operand's dimensions (letter k of an operand is its logical dimension k, after a leading '*') */
static int letter_dims(bn_layer *L, const bn_dims *dd[3], char letters[16], size_t sizes[16], int *nl, int nstar[3]) {
    *nl = 0;
    for (int o = 0; o < 3; o++) {
        if (L->cn[o] < 0) continue;
        nstar[o] = L->cstar ? dd[o]->rank - L->cn[o] : 0;
        if (nstar[o] < 0) return -1;
        int off = L->cstar == 1 ? nstar[o] : 0;
        for (int k = 0; k < L->cn[o]; k++) {
            char c = L->cspec[o][k]; size_t sz = dd[o]->n[off + k]; int j;
            for (j = 0; j < *nl && letters[j] != c; j++) {}
            if (j == *nl) { letters[j] = c; sizes[j] = sz; (*nl)++; }
            else if (sizes[j] == 1) sizes[j] = sz;
            else if (sz != 1 && sz != sizes[j]) return -1;
        }
    }
    return 0;
}
static int contract_run(bn_layer *L, const float *a, const float *b, const float *dy, float *y, float *da, float *db) {
    const BNNSNDArrayDescriptor *ad = &L->i, *bd = &L->i2, *od = &L->o;
    bn_dims D[3]; const bn_dims *dd[3] = {&D[0], &D[1], &D[2]};
    if (bn_dims_of(ad, &D[0]) || (L->cn[1] >= 0 && bn_dims_of(bd, &D[1])) || bn_dims_of(od, &D[2])) return -1;
    char letters[16]; size_t sizes[16]; int nl, nstar[3] = {0, 0, 0};
    if (letter_dims(L, dd, letters, sizes, &nl, nstar)) return -1;
    /* the starred dimensions: taken from the output */
    int ns = nstar[2]; size_t starsz[BN_MAXD], nstarcount = 1;
    int soff2 = L->cstar == 1 ? 0 : L->cn[2];
    for (int k = 0; k < ns; k++) { starsz[k] = D[2].n[soff2 + k]; nstarcount *= starsz[k]; }
    size_t total = nstarcount;
    for (int j = 0; j < nl; j++) total *= sizes[j];
    if (y) memset(y, 0, D[2].count * sizeof(float));
    size_t cs[3][BN_MAXD];
    for (int o = 0; o < 3; o++) { size_t s = 1; for (int k = 0; k < BN_MAXD; k++) { cs[o][k] = s; s *= D[o].n[k]; } }
    size_t lv[16], sv[BN_MAXD];
    const float *src[2] = {a, b};
    for (size_t t = 0; t < total; t++) {
        size_t r = t;
        for (int k = 0; k < ns; k++) { sv[k] = r % starsz[k]; r /= starsz[k]; }
        for (int j = 0; j < nl; j++) { lv[j] = r % sizes[j]; r /= sizes[j]; }
        size_t off[3];
        for (int o = 0; o < 3; o++) {
            off[o] = 0;
            if (L->cn[o] < 0) continue;
            int lo = L->cstar == 1 ? nstar[o] : 0, so = L->cstar == 1 ? 0 : L->cn[o];
            for (int k = 0; k < L->cn[o]; k++) {
                int j; for (j = 0; letters[j] != L->cspec[o][k]; j++) {}
                size_t p = D[o].n[lo + k] == 1 ? 0 : lv[j];
                off[o] += p * cs[o][lo + k];
            }
            for (int k = 0; k < nstar[o]; k++) {
                int sk = k + (ns - nstar[o]);   /* align starred dimensions from the end of the star block */
                size_t p = D[o].n[so + k] == 1 ? 0 : sv[sk];
                off[o] += p * cs[o][so + k];
            }
        }
        float va = src[0][off[0]], vb = L->cn[1] >= 0 ? src[1][off[1]] : 1;
        if (y) y[off[2]] += L->p.contract.alpha * va * vb;
        else {
            float g = L->p.contract.alpha * dy[off[2]];
            if (da) da[off[0]] += g * vb;
            if (db && L->cn[1] >= 0) db[off[1]] += g * va;
        }
    }
    return 0;
}
int bn_contract_forward(bn_layer *L, const float *a, const float *b, float *y) {
    float *w = NULL;
    if (L->cweights == 1) { w = bn_load(&L->w, NULL, NULL); b = a; a = w; }
    else if (L->cweights == 2) { w = bn_load(&L->w, NULL, NULL); b = w; }
    else if (L->cself || (L->cn[1] >= 0 && !b)) b = a;
    if ((L->cweights && !w)) return -1;
    int r = contract_run(L, a, b, NULL, y, NULL, NULL);
    free(w);
    return r;
}
int bn_contract_backward(bn_layer *L, const float *a, const float *b, const float *dy, float *da, float *db) {
    return contract_run(L, a, b, dy, NULL, da, db);
}
BNNSFilter BNNSFilterCreateLayerTensorContraction(const BNNSLayerParametersTensorContraction *p, const BNNSFilterParameters *fp) {
    if (!p || (p->beta != 0 && p->beta != 1)) return NULL;
    bn_filter *f = bn_layer_new(BK_CONTRACT, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.contract = *p;
    if (bn_contract_parse(L, p->operation)) { BNNSFilterDestroy(f); return NULL; }
    L->i = p->iA_desc; L->i2 = p->iB_desc; L->o = p->o_desc;
    int ok = 1;
    if (L->cweights == 1) { ok = p->iA_desc.data && !bn_layer_keep(f, &L->w, &p->iA_desc, &L->owns_w); L->i = p->iB_desc; L->i2 = p->iA_desc; }
    if (L->cweights == 2) ok = p->iB_desc.data && !bn_layer_keep(f, &L->w, &p->iB_desc, &L->owns_w);
    if (L->cweights == 1) {
        /* keep the string's operand order: the weights are operand 0 */
        BNNSNDArrayDescriptor t = L->i; L->i = L->i2; L->i2 = t;
    }
    if (!ok) { BNNSFilterDestroy(f); return NULL; }
    return f;
}

/* ---- two-input apply and the backward dispatch for these layers ---- */
int BNNSFilterApplyTwoInputBatch(BNNSFilter filter, size_t batch_size, const void *inA, size_t inA_stride, const void *inB,
                                 size_t inB_stride, void *out, size_t out_stride) {
    bn_filter *f = bn_filter_of(filter);
    bn_layer *L = bn_layer_of(f);
    if (!L || !inA || !inB || !out) return -1;
    if (f->kind == BK_ARITH) {
        const void *in[2] = {inA, inB}; size_t st[2] = {inA_stride, inB_stride};
        return arith_apply(f, batch_size, 2, in, st, out, out_stride);
    }
    if (f->kind != BK_BMM && f->kind != BK_CONTRACT) return -1;
    const BNNSNDArrayDescriptor *ad = f->kind == BK_BMM ? &L->p.bmm.iA_desc : &L->i, *bd = f->kind == BK_BMM ? &L->p.bmm.iB_desc : &L->i2;
    size_t no = dcount(&L->o);
    float *y = malloc(no * sizeof(float) + 1);
    int r = y ? 0 : -1;
    for (size_t b = 0; b < batch_size && !r; b++) {
        float *a = bn_load(ad, (const char *)inA + bn_bytes(ad, b * inA_stride), NULL);
        float *bb = bn_load(bd, (const char *)inB + bn_bytes(bd, b * inB_stride), NULL);
        if (!a || !bb) r = -1;
        else r = f->kind == BK_BMM ? bmm_compute(L, a, bb, y) : contract_run(L, a, bb, NULL, y, NULL, NULL);
        if (!r) r = bn_store(&L->o, (char *)out + bn_bytes(&L->o, b * out_stride), y, 0);
        free(a); free(bb);
    }
    free(y);
    return r;
}
int BNNSFilterApplyTwoInput(BNNSFilter filter, const void *inA, const void *inB, void *out) {
    return BNNSFilterApplyTwoInputBatch(filter, 1, inA, 0, inB, 0, out, 0);
}
/* gradients of a (possibly broadcast) matrix product through the dense contraction engine */
static int bmm_backward_one(bn_layer *L, const float *a, const float *b, const float *g, float *da, float *db) {
    /* express C = alpha op(A) op(B) as a contraction over the last two dimensions with '*' batch broadcasting */
    bn_layer T = *L;
    bn_dims dA, dB, dC;
    bn_dims_of(&L->p.bmm.iA_desc, &dA); bn_dims_of(&L->p.bmm.iB_desc, &dB); bn_dims_of(&L->o, &dC);
    if (dA.rank < 2 || dB.rank < 2 || dC.rank < 2) return -1;
    /* letters: rows i, inner k, cols j; the matrix is the last two logical dimensions (row, col) */
    strcpy(T.cspec[0], L->p.bmm.transA ? "ki" : "ik");
    strcpy(T.cspec[1], L->p.bmm.transB ? "jk" : "kj");
    strcpy(T.cspec[2], "ij");
    T.cn[0] = T.cn[1] = T.cn[2] = 2; T.cstar = 1; T.cself = 0; T.cweights = 0;
    T.p.contract.alpha = L->p.bmm.alpha;
    T.i = L->p.bmm.iA_desc; T.i2 = L->p.bmm.iB_desc;
    return contract_run(&T, a, b, g, NULL, da, db);
}
int bn_layers2_backward(bn_filter *f, size_t batch, const void *const *in, const size_t *in_stride, BNNSNDArrayDescriptor *const *in_delta,
                        const size_t *in_delta_stride, size_t nin, const void *out, size_t out_stride,
                        const BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride, BNNSNDArrayDescriptor *weights_delta) {
    bn_layer *L = bn_layer_of(f);
    if (!L || !out_delta || !out_delta->data) return -1;
    if (f->kind == BK_ARITH)
        return arith_backward(f, batch, nin, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta, out_delta_stride);
    if (f->kind != BK_BMM && f->kind != BK_CONTRACT) return -1;
    int bmm = f->kind == BK_BMM;
    const BNNSNDArrayDescriptor *ad = bmm ? &L->p.bmm.iA_desc : &L->i, *bd = bmm ? &L->p.bmm.iB_desc : &L->i2;
    int wsel = bmm ? (L->p.bmm.a_is_weights ? 1 : L->p.bmm.b_is_weights ? 2 : 0) : L->cweights;
    int self = bmm ? (!wsel && nin < 2) : (L->cself || L->cn[1] < 0);
    float *w = wsel ? bn_load(&L->w, NULL, NULL) : NULL;
    size_t na = dcount(ad), nb = dcount(bd);
    float *dwacc = wsel ? calloc((wsel == 1 ? na : nb) + 1, sizeof(float)) : NULL;
    int r = (wsel && (!w || !dwacc)) ? -1 : 0;
    for (size_t b = 0; b < batch && !r; b++) {
        const BNNSNDArrayDescriptor *xd0 = wsel == 1 ? bd : ad;
        float *x0 = bn_load(xd0, (const char *)in[0] + bn_bytes(xd0, b * in_stride[0]), NULL);
        float *x1 = (nin > 1 && in[1]) ? bn_load(bd, (const char *)in[1] + bn_bytes(bd, b * in_stride[1]), NULL) : NULL;
        float *g = bn_load(out_delta, (const char *)out_delta->data + bn_bytes(out_delta, b * out_delta_stride), NULL);
        const float *A = wsel == 1 ? w : x0, *B = wsel == 2 ? w : (wsel == 1 ? x0 : (self ? x0 : x1));
        float *da = calloc(na + 1, sizeof(float)), *db = calloc(nb + 1, sizeof(float));
        if (!x0 || !g || !A || !B || !da || !db) r = -1;
        else r = bmm ? bmm_backward_one(L, A, B, g, da, db) : bn_contract_backward(L, A, B, g, da, db);
        if (!r) {
            if (self) for (size_t i = 0; i < na; i++) da[i] += db[i];
            float *dx0 = wsel == 1 ? db : da, *dx1 = db;
            if (wsel == 1) for (size_t i = 0; i < na; i++) dwacc[i] += da[i];
            if (wsel == 2) for (size_t i = 0; i < nb; i++) dwacc[i] += db[i];
            if (in_delta && in_delta[0] && in_delta[0]->data)
                r = bn_store(in_delta[0], (char *)in_delta[0]->data + bn_bytes(in_delta[0], b * in_delta_stride[0]), dx0,
                             in_delta[0]->flags == BNNSNDArrayFlagBackpropAccumulate);
            if (!r && nin > 1 && !wsel && !self && in_delta && in_delta[1] && in_delta[1]->data)
                r = bn_store(in_delta[1], (char *)in_delta[1]->data + bn_bytes(in_delta[1], b * in_delta_stride[1]), dx1,
                             in_delta[1]->flags == BNNSNDArrayFlagBackpropAccumulate);
        }
        free(x0); free(x1); free(g); free(da); free(db);
    }
    if (!r && wsel && weights_delta && weights_delta->data)
        r = bn_store(weights_delta, NULL, dwacc, weights_delta->flags == BNNSNDArrayFlagBackpropAccumulate);
    free(w); free(dwacc);
    return r;
}
int BNNSFilterApplyBackwardTwoInputBatch(BNNSFilter filter, size_t batch_size, const void *inA, size_t inA_stride,
                                         BNNSNDArrayDescriptor *inA_delta, size_t inA_delta_stride, const void *inB, size_t inB_stride,
                                         BNNSNDArrayDescriptor *inB_delta, size_t inB_delta_stride, const void *out, size_t out_stride,
                                         const BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride,
                                         BNNSNDArrayDescriptor *weights_delta, BNNSNDArrayDescriptor *bias_delta) {
    (void)bias_delta;
    bn_filter *f = bn_filter_of(filter);
    if (!f) return -1;
    const void *in[2] = {inA, inB}; size_t st[2] = {inA_stride, inB_stride};
    BNNSNDArrayDescriptor *dl[2] = {inA_delta, inB_delta}; size_t dst[2] = {inA_delta_stride, inB_delta_stride};
    return bn_layers2_backward(f, batch_size, in, st, dl, dst, 2, out, out_stride, out_delta, out_delta_stride, weights_delta);
}

/* ---- loss ---- */
static int loss_per_sample(BNNSLossFunction fn) {
    return fn == BNNSLossFunctionSoftmaxCrossEntropy || fn == BNNSLossFunctionCosineDistance || fn == BNNSLossFunctionCategoricalCrossEntropy;
}
BNNSFilter BNNSFilterCreateLayerLoss(const void *layer_params, const BNNSFilterParameters *fp) {
    if (!layer_params) return NULL;
    const BNNSLayerParametersLossBase *base = layer_params;
    if (base->function < BNNSLossFunctionSoftmaxCrossEntropy || base->function > BNNSLossFunctionCategoricalCrossEntropy ||
        base->function == BNNSLossFunctionYolo || base->reduction > BNNSLossReductionNonZeroWeightMean)
        return NULL;   /* YOLO loss: not in isim (a stub) */
    bn_dims d;
    if (bn_dims_of(&base->i_desc, &d)) return NULL;
    bn_filter *f = bn_layer_new(BK_LOSS, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    memset(&L->p.loss, 0, sizeof L->p.loss);
    L->p.loss.function = base->function; L->p.loss.i_desc = base->i_desc; L->p.loss.o_desc = base->o_desc;
    L->p.loss.reduction = base->reduction;
    if (base->function == BNNSLossFunctionSoftmaxCrossEntropy || base->function == BNNSLossFunctionSigmoidCrossEntropy)
        L->p.loss.huber_delta = ((const BNNSLayerParametersLossSoftmaxCrossEntropy *)layer_params)->label_smooth;  /* label smoothing */
    if (base->function == BNNSLossFunctionHuber) L->p.loss.huber_delta = ((const BNNSLayerParametersLossHuber *)layer_params)->huber_delta;
    L->i = base->i_desc; L->o = base->o_desc;
    return f;
}
/* the loss terms of one sample (one per sample, or one per element) and their input gradients */
static void loss_terms(bn_layer *L, const float *x, const float *lab, size_t n, float *terms, float *grad) {
    BNNSLossFunction fn = L->p.loss.function;
    float par = L->p.loss.huber_delta;
    switch (fn) {
    case BNNSLossFunctionSoftmaxCrossEntropy: {
        float m = -INFINITY; double s = 0, t = 0;
        for (size_t i = 0; i < n; i++) if (x[i] > m) m = x[i];
        for (size_t i = 0; i < n; i++) s += exp((double)x[i] - m);
        double lsum = 0;
        for (size_t i = 0; i < n; i++) {
            double l = lab[i] * (1 - par) + par / n, lp = x[i] - m - log(s);
            t -= l * lp; lsum += l;
        }
        terms[0] = (float)t;
        if (grad) for (size_t i = 0; i < n; i++) {
            double l = lab[i] * (1 - par) + par / n;
            grad[i] = (float)(exp((double)x[i] - m - log(s)) * lsum - l);
        }
        break;
    }
    case BNNSLossFunctionCategoricalCrossEntropy: {
        double t = 0;
        for (size_t i = 0; i < n; i++) { float p = fmaxf(x[i], 1e-12f); t -= lab[i] * log(p); if (grad) grad[i] = -lab[i] / p; }
        terms[0] = (float)t;
        break;
    }
    case BNNSLossFunctionCosineDistance: {
        double xy = 0, xx = 0, yy = 0;
        for (size_t i = 0; i < n; i++) { xy += (double)x[i] * lab[i]; xx += (double)x[i] * x[i]; yy += (double)lab[i] * lab[i]; }
        double nx = sqrt(xx), ny = sqrt(yy), c = (nx && ny) ? xy / (nx * ny) : 0;
        terms[0] = (float)(1 - c);
        if (grad) for (size_t i = 0; i < n; i++) grad[i] = (nx && ny) ? (float)(-(lab[i] / (nx * ny) - c * x[i] / xx)) : 0;
        break;
    }
    default:
        for (size_t i = 0; i < n; i++) {
            float v = x[i], l = lab[i], t = 0, g = 0;
            switch (fn) {
            case BNNSLossFunctionSigmoidCrossEntropy: {
                l = l * (1 - par) + 0.5f * par;
                t = fmaxf(v, 0) - v * l + log1pf(expf(-fabsf(v)));
                g = 1 / (1 + expf(-v)) - l; break;
            }
            case BNNSLossFunctionMeanSquareError: t = (v - l) * (v - l); g = 2 * (v - l); break;
            case BNNSLossFunctionMeanAbsoluteError: t = fabsf(v - l); g = v > l ? 1.0f : (v < l ? -1.0f : 0.0f); break;
            case BNNSLossFunctionHuber: {
                float d = v - l, ad = fabsf(d), dl = par > 0 ? par : 1;
                if (ad <= dl) { t = 0.5f * d * d; g = d; } else { t = dl * (ad - 0.5f * dl); g = d > 0 ? dl : -dl; }
                break;
            }
            case BNNSLossFunctionLog: {
                const float e = 1e-7f;
                t = -(l * logf(v + e) + (1 - l) * logf(1 - v + e));
                g = -(l / (v + e)) + (1 - l) / (1 - v + e); break;
            }
            case BNNSLossFunctionHinge: t = fmaxf(0, 1 - v * l); g = 1 - v * l > 0 ? -l : 0; break;
            default: break;
            }
            terms[i] = t;
            if (grad) grad[i] = g;
        }
    }
}
static int loss_run(bn_filter *f, size_t batch, const void *in, size_t in_stride, const void *labels, size_t labels_stride,
                    const void *weights, size_t weights_size, void *out, BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride,
                    const BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride) {
    bn_layer *L = bn_layer_of(f);
    if (!L || f->kind != BK_LOSS || !in || !labels) return -1;
    size_t n = dcount(&L->i), per = loss_per_sample(L->p.loss.function) ? 1 : n, nt = batch * per;
    float *terms = malloc(nt * sizeof(float) + 1), *grads = malloc(batch * n * sizeof(float) + 1), *wts = malloc(nt * sizeof(float) + 1);
    if (!terms || !grads || !wts) FAIL(free(terms), free(grads), free(wts));
    for (size_t i = 0; i < nt; i++) {
        float w = 1;
        if (weights && weights_size == 1) w = ((const float *)weights)[0];
        else if (weights && weights_size == batch) w = ((const float *)weights)[i / per];
        else if (weights && weights_size == nt) w = ((const float *)weights)[i];
        wts[i] = w;
    }
    int r = 0;
    for (size_t b = 0; b < batch && !r; b++) {
        float *x = bn_load(&L->i, (const char *)in + bn_bytes(&L->i, b * in_stride), NULL);
        float *l = bn_load(&L->i, (const char *)labels + bn_bytes(&L->i, b * labels_stride), NULL);
        if (!x || !l) r = -1;
        else loss_terms(L, x, l, n, terms + b * per, grads + b * n);
        free(x); free(l);
    }
    /* reduction */
    double sum = 0, wsum = 0; size_t nz = 0;
    for (size_t i = 0; i < nt; i++) { sum += (double)wts[i] * terms[i]; wsum += wts[i]; nz += wts[i] != 0; }
    double scale = 1;   /* d(loss)/d(term) apart from the weight */
    switch (L->p.loss.reduction) {
    case BNNSLossReductionNone: break;
    case BNNSLossReductionSum: break;
    case BNNSLossReductionMean: scale = 1.0 / (double)nt; sum *= scale; break;
    case BNNSLossReductionWeightedMean: scale = wsum ? 1.0 / wsum : 0; sum *= scale; break;
    case BNNSLossReductionNonZeroWeightMean: scale = nz ? 1.0 / (double)nz : 0; sum *= scale; break;
    }
    BNNSNDArrayDescriptor od = {0};
    od.layout = BNNSDataLayoutVector; od.data_type = L->o.data_type ? L->o.data_type : BNNSDataTypeFloat32;
    if (!r && out) {
        if (L->p.loss.reduction == BNNSLossReductionNone) {
            od.size[0] = nt;
            for (size_t i = 0; i < nt; i++) terms[i] *= wts[i];
            r = bn_store(&od, out, terms, 0);
        } else { float s = (float)sum; od.size[0] = 1; r = bn_store(&od, out, &s, 0); }
    }
    if (!r && in_delta && in_delta->data) {
        float *g = out_delta && out_delta->data ? bn_load(out_delta, NULL, NULL) : NULL;
        for (size_t b = 0; b < batch && !r; b++) {
            float *gb = grads + b * n;
            for (size_t i = 0; i < n; i++) {
                size_t ti = b * per + (per == 1 ? 0 : i);
                float up = 1;
                if (g) up = L->p.loss.reduction == BNNSLossReductionNone ? g[ti] : g[0];
                gb[i] *= (float)(wts[ti] * scale) * up;
            }
            r = bn_store(in_delta, (char *)in_delta->data + bn_bytes(in_delta, b * in_delta_stride), gb,
                         in_delta->flags == BNNSNDArrayFlagBackpropAccumulate);
        }
        free(g);
    }
    free(terms); free(grads); free(wts);
    return r;
}
int BNNSLossFilterApplyBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, const void *labels,
                             size_t labels_stride, const void *weights, size_t weights_size, void *out,
                             BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride) {
    bn_filter *f = bn_filter_of(filter);
    return f ? loss_run(f, batch_size, in, in_stride, labels, labels_stride, weights, weights_size, out, in_delta, in_delta_stride, NULL, 0) : -1;
}
int BNNSLossFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride,
                                     BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride, const void *labels, size_t labels_stride,
                                     const void *weights, size_t weights_size, const BNNSNDArrayDescriptor *out_delta,
                                     size_t out_delta_stride) {
    bn_filter *f = bn_filter_of(filter);
    if (!f || !in_delta) return -1;
    return loss_run(f, batch_size, in, in_stride, labels, labels_stride, weights, weights_size, NULL, in_delta, in_delta_stride,
                    out_delta, out_delta_stride);
}

/* ---- fused filters: input -> filter0 -> filter1 -> output ---- */
BNNSFilter BNNSFilterCreateFusedLayer(const size_t number_of_fused_filters, const BNNSFilterType *filter_type,
                                      const void **layer_params, const BNNSFilterParameters *fp) {
    if (number_of_fused_filters != 2 || !filter_type || !layer_params) return NULL;
    bn_filter *f = bn_layer_new(BK_FUSED, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    int ok = 1;
    const BNNSNDArrayDescriptor *mid_out = NULL;
    for (size_t k = 0; k < 2 && ok; k++) {
        BNNSFilterType t = filter_type[k];
        BNNSFilter c = NULL;
        switch (t) {
        case BNNSConvolution: c = BNNSFilterCreateLayerConvolution(layer_params[k], fp); break;
        case BNNSTransposedConvolution: c = BNNSFilterCreateLayerTransposedConvolution(layer_params[k], fp); break;
        case BNNSFullyConnected: c = BNNSFilterCreateLayerFullyConnected(layer_params[k], fp); break;
        case BNNSArithmetic: c = BNNSFilterCreateLayerArithmetic(layer_params[k], fp); break;
        case BNNSBatchNorm: case BNNSInstanceNorm: case BNNSLayerNorm: case BNNSGroupNorm:
            c = BNNSFilterCreateLayerNormalization(t, layer_params[k], fp); break;
        case BNNSQuantization: {
            if (!mid_out) break;
            BNNSLayerParametersQuantization q = *(const BNNSLayerParametersQuantization *)layer_params[k];
            bn_filter *qf = bn_layer_new(BK_QUANT, fp);
            if (qf) { bn_layer *Q = qf->state; Q->p.quant = q; Q->i = *mid_out; Q->o = q.o_desc; }
            c = qf;
            break;
        }
        default: break;
        }
        bn_filter *cf = bn_filter_of(c);
        if (!cf) { ok = 0; break; }
        L->fused[k] = cf; L->ftype[k] = t; L->nfused = k + 1;
        mid_out = &bn_layer_of(cf)->o;
    }
    if (ok) { L->i = bn_layer_of(L->fused[0])->i; L->o = bn_layer_of(L->fused[1])->o; }
    if (!ok) { BNNSFilterDestroy(f); return NULL; }
    return f;
}
int bn_fused_apply(bn_filter *f, size_t batch, const void *in, size_t in_stride, void *out, size_t out_stride, int training) {
    bn_layer *L = bn_layer_of(f);
    if (!L || L->nfused != 2) return -1;
    bn_layer *A = bn_layer_of(L->fused[0]), *B = bn_layer_of(L->fused[1]);
    size_t nm = dcount(&A->o), no = dcount(&B->o);
    float **x = calloc(batch + 1, sizeof(float *)), **m = calloc(batch + 1, sizeof(float *)), **y = calloc(batch + 1, sizeof(float *));
    int r = 0;
    for (size_t b = 0; b < batch && !r; b++) {
        x[b] = bn_load(&A->i, (const char *)in + bn_bytes(&A->i, b * in_stride), NULL);
        m[b] = malloc(nm * sizeof(float) + 1); y[b] = malloc(no * sizeof(float) + 1);
        if (!x[b] || !m[b] || !y[b]) r = -1;
    }
    if (!r) r = bn_layer_forward(L->fused[0], batch, x, m, training);
    if (!r) r = bn_layer_forward(L->fused[1], batch, m, y, training);
    for (size_t b = 0; b < batch && !r; b++) r = bn_store(&L->o, (char *)out + bn_bytes(&L->o, b * out_stride), y[b], 0);
    for (size_t b = 0; b < batch; b++) { free(x[b]); free(m[b]); free(y[b]); }
    free(x); free(m); free(y);
    return r;
}
int BNNSFusedFilterApplyMultiInputBatch(BNNSFilter filter, size_t batch_size, size_t number_of_inputs, const void **in,
                                        const size_t *in_stride, void *out, size_t out_stride, bool training) {
    bn_filter *f = bn_filter_of(filter);
    bn_layer *L = bn_layer_of(f);
    if (!L || f->kind != BK_FUSED || L->nfused != 2 || L->fused[0]->kind != BK_ARITH) {
        return (f && number_of_inputs == 1 && in) ? bn_fused_apply(f, batch_size, in[0], in_stride[0], out, out_stride, training) : -1;
    }
    /* arithmetic -> normalization: the arithmetic result into the normalization */
    bn_layer *A = bn_layer_of(L->fused[0]);
    size_t nm = dcount(&A->aout);
    float *mid = malloc(batch_size * nm * sizeof(float) + 1);
    BNNSNDArrayDescriptor md = A->aout;
    dense_desc(&md, mid);
    int r = mid ? arith_apply(L->fused[0], batch_size, number_of_inputs, in, in_stride, mid, nm) : -1;
    if (!r) {
        bn_layer *N = bn_layer_of(L->fused[1]);
        BNNSNDArrayDescriptor keep = N->i;
        N->i = md; N->i.data = NULL;
        r = BNNSNormalizationFilterApplyBatch(L->fused[1], batch_size, mid, nm, out, out_stride, training);
        N->i = keep;
    }
    free(mid);
    return r;
}
int BNNSFusedFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride,
                                      BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride, const void *out, size_t out_stride,
                                      BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride, BNNSNDArrayDescriptor **delta_parameters) {
    bn_filter *f = bn_filter_of(filter);
    bn_layer *L = bn_layer_of(f);
    if (!L || f->kind != BK_FUSED || L->nfused != 2 || !out_delta || !out_delta->data) return -1;
    bn_filter *F0 = L->fused[0], *F1 = L->fused[1];
    if (F1->kind != BK_NORM) return -1;   /* the quantization configurations have no gradient */
    bn_layer *A = bn_layer_of(F0);
    size_t nm = dcount(&A->o);
    /* recompute the intermediate (the normalization's input) from the input, then back through both */
    float *mid = malloc(batch_size * nm * sizeof(float) + 1), *dmid = calloc(batch_size * nm + 1, sizeof(float));
    BNNSNDArrayDescriptor md = A->o, dmd = A->o;
    dense_desc(&md, mid); dense_desc(&dmd, dmid);
    bn_layer *N = bn_layer_of(F1);
    BNNSNDArrayDescriptor keep_ao = A->o, keep_ni = N->i;
    A->o = md; A->o.data = NULL; N->i = md; N->i.data = NULL;
    int r = (mid && dmid) ? BNNSFilterApplyBatch(F0, batch_size, in, in_stride, mid, nm) : -1;
    if (!r) {
        /* re-run the normalization in training mode on the intermediate to refresh its cache, without updating the moving
           statistics a second time (the caller's forward pass already did) */
        BNNSNDArrayDescriptor mm = N->mmean, mv = N->mvar;
        N->mmean.data = NULL; N->mvar.data = NULL;
        size_t no = dcount(&N->o);
        float *tmp = malloc(batch_size * no * sizeof(float) + 1);
        BNNSNDArrayDescriptor keep = N->o, td = N->o; dense_desc(&td, tmp);
        N->o = td; N->o.data = NULL;
        r = tmp ? BNNSNormalizationFilterApplyBatch(F1, batch_size, mid, nm, tmp, no, true) : -1;
        N->o = keep;
        N->mmean = mm; N->mvar = mv;
        free(tmp);
        BNNSNDArrayDescriptor *beta_d = delta_parameters ? delta_parameters[2] : NULL, *gamma_d = delta_parameters ? delta_parameters[3] : NULL;
        if (!r) r = BNNSNormalizationFilterApplyBackwardBatch(F1, batch_size, &dmd, nm, out, out_stride, out_delta, out_delta_stride, beta_d, gamma_d);
        if (!r) r = BNNSFilterApplyBackwardBatch(F0, batch_size, in, in_stride, in_delta, in_delta_stride, mid, nm, &dmd, nm,
                                                 delta_parameters ? delta_parameters[0] : NULL, delta_parameters ? delta_parameters[1] : NULL);
    }
    A->o = keep_ao; N->i = keep_ni;
    free(mid); free(dmid);
    return r;
}
int BNNSFusedFilterApplyBackwardMultiInputBatch(BNNSFilter filter, size_t batch_size, size_t number_of_inputs, const void **in,
                                                const size_t *in_stride, BNNSNDArrayDescriptor **in_delta, const size_t *in_delta_stride,
                                                const void *out, const size_t out_stride, BNNSNDArrayDescriptor *out_delta,
                                                size_t out_delta_stride, BNNSNDArrayDescriptor **delta_parameters) {
    if (number_of_inputs == 1 && in && in_stride && in_delta && in_delta_stride)
        return BNNSFusedFilterApplyBackwardBatch(filter, batch_size, in[0], in_stride[0], in_delta[0], in_delta_stride[0], out, out_stride,
                                                 out_delta, out_delta_stride, delta_parameters);
    return -1;   /* arithmetic -> normalization gradients: not in isim */
}

/* ---- multihead attention and LSTM: not in isim (stubs that fail) ---- */
BNNSFilter BNNSFilterCreateLayerMultiheadAttention(const BNNSLayerParametersMultiheadAttention *layer_params, const BNNSFilterParameters *fp) {
    (void)layer_params; (void)fp; return NULL;
}
int BNNSApplyMultiheadAttention(BNNSFilter F, size_t batch_size, void const *query, size_t query_stride, void const *key, size_t key_stride,
                                BNNSNDArrayDescriptor const *key_mask, size_t key_mask_stride, void const *value, size_t value_stride,
                                void *output, size_t output_stride, BNNSNDArrayDescriptor const *add_to_attention,
                                size_t *backprop_cache_size, void *backprop_cache, size_t *workspace_size, void *workspace) {
    (void)F; (void)batch_size; (void)query; (void)query_stride; (void)key; (void)key_stride; (void)key_mask; (void)key_mask_stride;
    (void)value; (void)value_stride; (void)output; (void)output_stride; (void)add_to_attention; (void)backprop_cache_size;
    (void)backprop_cache; (void)workspace_size; (void)workspace;
    return -1;
}
int BNNSApplyMultiheadAttentionBackward(BNNSFilter F, size_t batch_size, void const *query, size_t query_stride,
                                        BNNSMHAProjectionParameters *query_param_delta, void const *key, size_t key_stride,
                                        BNNSNDArrayDescriptor const *key_mask, size_t key_mask_stride, BNNSMHAProjectionParameters *key_param_delta,
                                        void const *value, size_t value_stride, BNNSMHAProjectionParameters *value_param_delta,
                                        BNNSNDArrayDescriptor const *add_to_attention, BNNSNDArrayDescriptor *key_attn_bias_delta,
                                        BNNSNDArrayDescriptor *value_attn_bias_delta, void const *output, size_t output_stride,
                                        BNNSMHAProjectionParameters *output_param_delta, size_t backprop_cache_size, void *backprop_cache,
                                        size_t *workspace_size, void *workspace) {
    (void)F; (void)batch_size; (void)query; (void)query_stride; (void)query_param_delta; (void)key; (void)key_stride; (void)key_mask;
    (void)key_mask_stride; (void)key_param_delta; (void)value; (void)value_stride; (void)value_param_delta; (void)add_to_attention;
    (void)key_attn_bias_delta; (void)value_attn_bias_delta; (void)output; (void)output_stride; (void)output_param_delta;
    (void)backprop_cache_size; (void)backprop_cache; (void)workspace_size; (void)workspace;
    return -1;
}
size_t BNNSComputeLSTMTrainingCacheCapacity(const BNNSLayerParametersLSTM *layer_params) { (void)layer_params; return 0; }
int BNNSDirectApplyLSTMBatchTrainingCaching(const BNNSLayerParametersLSTM *layer_params, const BNNSFilterParameters *fp,
                                            void *training_cache_ptr, const size_t training_cache_capacity) {
    (void)layer_params; (void)fp; (void)training_cache_ptr; (void)training_cache_capacity; return -1;
}
int BNNSDirectApplyLSTMBatchBackward(const BNNSLayerParametersLSTM *layer_params, const BNNSLayerParametersLSTM *layer_delta_params,
                                     const BNNSFilterParameters *fp, const void *training_cache_ptr, const size_t training_cache_capacity) {
    (void)layer_params; (void)layer_delta_params; (void)fp; (void)training_cache_ptr; (void)training_cache_capacity; return -1;
}
