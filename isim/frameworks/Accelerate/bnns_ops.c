// isim Accelerate BNNS (issue #808): the direct functions (copy, transpose, tile, compare, matrix products, reductions,
// gather / scatter, top-k, band part, shuffle, norms and clipping, crop-resize, quantizer).
#include "bnns_core.h"

#define FAIL(...) do { __VA_ARGS__; return -1; } while (0)

static int same_dims(const bn_dims *a, const bn_dims *b) {
    if (a->count != b->count) return 0;
    for (int k = 0; k < BN_MAXD; k++) if (a->n[k] != b->n[k]) return 0;
    return 1;
}
static void cstrides(const bn_dims *d, size_t *cs) {   /* canonical (dense) stride of each dimension */
    size_t s = 1;
    for (int k = 0; k < BN_MAXD; k++) { cs[k] = s; s *= d->n[k]; }
}

/* ---- copy, transpose, tile, compare ---- */
int BNNSCopy(BNNSNDArrayDescriptor *dest, const BNNSNDArrayDescriptor *src, const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims a, b;
    if (!dest || !src || bn_dims_of(src, &a) || bn_dims_of(dest, &b) || a.count != b.count) return -1;
    if (src->data_type == dest->data_type && (src->data_type & 0xff0000u) != BNNSDataTypeFloatBit &&
        src->data_type != BNNSDataTypeFloat16 && src->data_type != BNNSDataTypeBFloat16 &&
        (src->data_type & 0xff0000u) != BNNSDataTypeIndexedBit && src->data_scale == dest->data_scale &&
        src->data_bias == dest->data_bias) {
        /* integers of one type: exact, through the index path */
        long long *v = bn_load_index(src, NULL, NULL);
        if (!v) return -1;
        float *f = malloc(a.count * sizeof(float) + 1);
        int big = 0;
        for (size_t i = 0; i < a.count; i++) if (v[i] > 16777216 || v[i] < -16777216) big = 1;
        if (!big) {
            for (size_t i = 0; i < a.count; i++) f[i] = (float)v[i] * (src->data_scale ? src->data_scale : 1) + src->data_bias;
            int r = bn_store(dest, NULL, f, 0);
            free(f); free(v); return r;
        }
        free(f);
        /* wide values: write the raw integers element by element */
        size_t st[BN_MAXD];
        bn_strides(dest, st);
        int bits = bn_type_bits(dest->data_type);
        for (size_t i = 0; i < a.count; i++) {
            size_t off = 0, r = i;
            for (int k = 0; k < b.rank; k++) { off += (r % b.n[k]) * st[k]; r /= b.n[k]; }
            if (bits == 64) ((long long *)dest->data)[off] = v[i];
            else if (bits == 32) ((int *)dest->data)[off] = (int)v[i];
        }
        free(v); return 0;
    }
    float *v = bn_load(src, NULL, NULL);
    if (!v) return -1;
    int r = bn_store(dest, NULL, v, 0);
    free(v);
    return r;
}

int BNNSTranspose(BNNSNDArrayDescriptor *dest, const BNNSNDArrayDescriptor *src, size_t axis0, size_t axis1,
                  const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims a, b;
    if (!dest || !src || bn_dims_of(src, &a) || bn_dims_of(dest, &b)) return -1;
    if ((int)axis0 >= a.rank || (int)axis1 >= a.rank || a.rank != b.rank) return -1;
    for (int k = 0; k < a.rank; k++) {
        size_t want = a.n[k == (int)axis0 ? (int)axis1 : k == (int)axis1 ? (int)axis0 : k];
        if (b.n[k] != want) return -1;
    }
    float *v = bn_load(src, NULL, NULL), *o = malloc(b.count * sizeof(float) + 1);
    if (!v || !o) FAIL(free(v), free(o));
    size_t ca[BN_MAXD], pos[BN_MAXD];
    cstrides(&a, ca);
    for (size_t i = 0; i < b.count; i++) {
        bn_unravel(&b, i, pos);
        size_t t = pos[axis0]; pos[axis0] = pos[axis1]; pos[axis1] = t;
        size_t off = 0;
        for (int k = 0; k < BN_MAXD; k++) off += pos[k] * ca[k];
        o[i] = v[off];
    }
    int r = bn_store(dest, NULL, o, 0);
    free(v); free(o);
    return r;
}

int BNNSTile(const BNNSNDArrayDescriptor *input, BNNSNDArrayDescriptor *output, const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims a, b;
    if (!input || !output || bn_dims_of(input, &a) || bn_dims_of(output, &b) || a.rank != b.rank) return -1;
    for (int k = 0; k < a.rank; k++) if (!a.n[k] || b.n[k] % a.n[k]) return -1;
    float *v = bn_load(input, NULL, NULL), *o = malloc(b.count * sizeof(float) + 1);
    if (!v || !o) FAIL(free(v), free(o));
    size_t ca[BN_MAXD], pos[BN_MAXD];
    cstrides(&a, ca);
    for (size_t i = 0; i < b.count; i++) {
        bn_unravel(&b, i, pos);
        size_t off = 0;
        for (int k = 0; k < BN_MAXD; k++) off += (pos[k] % a.n[k]) * ca[k];
        o[i] = v[off];
    }
    int r = bn_store(output, NULL, o, 0);
    free(v); free(o);
    return r;
}
int BNNSTileBackward(BNNSNDArrayDescriptor *in_delta, const BNNSNDArrayDescriptor *out_delta, const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims a, b;
    if (!in_delta || !out_delta || bn_dims_of(in_delta, &a) || bn_dims_of(out_delta, &b) || a.rank != b.rank) return -1;
    for (int k = 0; k < a.rank; k++) if (!a.n[k] || b.n[k] % a.n[k]) return -1;
    float *g = bn_load(out_delta, NULL, NULL), *o = calloc(a.count + 1, sizeof(float));
    if (!g || !o) FAIL(free(g), free(o));
    size_t ca[BN_MAXD], pos[BN_MAXD];
    cstrides(&a, ca);
    for (size_t i = 0; i < b.count; i++) {
        bn_unravel(&b, i, pos);
        size_t off = 0;
        for (int k = 0; k < BN_MAXD; k++) off += (pos[k] % a.n[k]) * ca[k];
        o[off] += g[i];
    }
    int r = bn_store(in_delta, NULL, o, in_delta->flags == BNNSNDArrayFlagBackpropAccumulate);
    free(g); free(o);
    return r;
}

int BNNSCompareTensor(const BNNSNDArrayDescriptor *in0, const BNNSNDArrayDescriptor *in1, BNNSRelationalOperator op,
                      BNNSNDArrayDescriptor *out) {
    bn_dims a, b, c;
    if (!in0 || !out || bn_dims_of(in0, &a) || bn_dims_of(out, &c) || a.count != c.count) return -1;
    int unary = op == BNNSRelationalOperatorLogicalNOT;
    if (!unary && (!in1 || bn_dims_of(in1, &b) || b.count != a.count)) return -1;
    float *x = bn_load(in0, NULL, NULL), *y = unary ? NULL : bn_load(in1, NULL, NULL), *o = malloc(c.count * sizeof(float) + 1);
    if (!x || (!unary && !y) || !o) FAIL(free(x), free(y), free(o));
    for (size_t i = 0; i < c.count; i++) {
        float p = x[i], q = unary ? 0 : y[i]; int r = 0;
        switch (op) {
        case BNNSRelationalOperatorEqual: r = p == q; break;
        case BNNSRelationalOperatorLess: r = p < q; break;
        case BNNSRelationalOperatorLessEqual: r = p <= q; break;
        case BNNSRelationalOperatorGreater: r = p > q; break;
        case BNNSRelationalOperatorGreaterEqual: r = p >= q; break;
        case BNNSRelationalOperatorNotEqual: r = p != q; break;
        case BNNSRelationalOperatorLogicalAND: r = (p != 0) && (q != 0); break;
        case BNNSRelationalOperatorLogicalOR: r = (p != 0) || (q != 0); break;
        case BNNSRelationalOperatorLogicalNOT: r = p == 0; break;
        case BNNSRelationalOperatorLogicalNAND: r = !((p != 0) && (q != 0)); break;
        case BNNSRelationalOperatorLogicalNOR: r = !((p != 0) || (q != 0)); break;
        case BNNSRelationalOperatorLogicalXOR: r = (p != 0) != (q != 0); break;
        default: FAIL(free(x), free(y), free(o));
        }
        o[i] = (float)r;
    }
    int r = bn_store(out, NULL, o, 0);
    free(x); free(y); free(o);
    return r;
}

/* ---- matrix products ---- */
/* the matrix is the last two logical dimensions (rows, columns); the leading ones broadcast */
typedef struct { int rank; size_t rows, cols, batch[BN_MAXD]; size_t cs[BN_MAXD]; } mat_shape;
static int mat_shape_of(const bn_dims *d, int trans, mat_shape *m) {
    if (d->rank < 1) return -1;
    m->rank = d->rank;
    cstrides(d, m->cs);
    if (d->rank == 1) { m->rows = 1; m->cols = d->n[0]; }
    else { m->rows = d->n[d->rank - 2]; m->cols = d->n[d->rank - 1]; }
    if (trans) { size_t t = m->rows; m->rows = m->cols; m->cols = t; }
    return 0;
}
static float mat_at(const float *v, const bn_dims *d, const mat_shape *m, int trans, const size_t *opos, int orank,
                    size_t r, size_t c) {
    size_t off = 0;
    int nb = d->rank - 2;
    for (int k = 0; k < nb; k++) {           /* align batch dimensions from the right */
        int ok = orank - 2 - (nb - k);
        size_t p = (ok >= 0 && d->n[k] != 1) ? opos[ok] : 0;
        off += p * m->cs[k];
    }
    if (trans) { size_t t = r; r = c; c = t; }
    if (d->rank == 1) return v[off + c + r];
    return v[off + r * m->cs[d->rank - 2] + c * m->cs[d->rank - 1]];
}
static int matmul(bool transA, bool transB, float alpha, const BNNSNDArrayDescriptor *A, const BNNSNDArrayDescriptor *B,
                  const BNNSNDArrayDescriptor *C, float beta_acc) {
    bn_dims da, db, dc;
    if (!A || !B || !C || bn_dims_of(A, &da) || bn_dims_of(B, &db) || bn_dims_of(C, &dc)) return -1;
    mat_shape ma, mb, mc;
    if (mat_shape_of(&da, transA, &ma) || mat_shape_of(&db, transB, &mb) || mat_shape_of(&dc, 0, &mc)) return -1;
    if (ma.cols != mb.rows || mc.rows != ma.rows || mc.cols != mb.cols) return -1;
    float *a = bn_load(A, NULL, NULL), *b = bn_load(B, NULL, NULL), *c = beta_acc != 0 ? bn_load(C, NULL, NULL) : calloc(dc.count + 1, sizeof(float));
    if (!a || !b || !c) FAIL(free(a), free(b), free(c));
    size_t nbatch = dc.count / (mc.rows * mc.cols ? mc.rows * mc.cols : 1), bpos[BN_MAXD] = {0};
    int nbr = dc.rank - 2 > 0 ? dc.rank - 2 : 0;
    for (size_t bi = 0; bi < nbatch; bi++) {
        size_t t = bi;
        for (int k = 0; k < nbr; k++) { bpos[k] = t % dc.n[k]; t /= dc.n[k]; }
        size_t coff = 0;
        for (int k = 0; k < nbr; k++) coff += bpos[k] * mc.cs[k];
        for (size_t i = 0; i < mc.rows; i++)
            for (size_t j = 0; j < mc.cols; j++) {
                double s = 0;
                for (size_t k = 0; k < ma.cols; k++)
                    s += (double)mat_at(a, &da, &ma, transA, bpos, dc.rank, i, k) * mat_at(b, &db, &mb, transB, bpos, dc.rank, k, j);
                size_t ci = dc.rank == 1 ? j : coff + i * mc.cs[dc.rank - 2] + j * mc.cs[dc.rank - 1];
                c[ci] = (float)(alpha * s) + beta_acc * c[ci];
            }
    }
    int r = bn_store(C, NULL, c, 0);
    free(a); free(b); free(c);
    return r;
}
ssize_t BNNSMatMulWorkspaceSize(const bool transA, const bool transB, const float alpha, const BNNSNDArrayDescriptor *inputA,
                                const BNNSNDArrayDescriptor *inputB, const BNNSNDArrayDescriptor *output,
                                const BNNSFilterParameters *fp) {
    (void)transA; (void)transB; (void)alpha; (void)fp;
    bn_dims a, b, c;
    if (!inputA || !inputB || !output || bn_dims_of(inputA, &a) || bn_dims_of(inputB, &b) || bn_dims_of(output, &c)) return -1;
    return 0;   /* isim allocates its own scratch */
}
int BNNSMatMul(const bool transA, const bool transB, const float alpha, const BNNSNDArrayDescriptor *inputA,
               const BNNSNDArrayDescriptor *inputB, const BNNSNDArrayDescriptor *output, void *workspace,
               const BNNSFilterParameters *fp) {
    (void)workspace; (void)fp;
    return matmul(transA, transB, alpha, inputA, inputB, output, 0);
}
void BNNSDirectApplyBroadcastMatMul(const bool transA, const bool transB, const float alpha, const BNNSNDArrayDescriptor *inputA,
                                    const BNNSNDArrayDescriptor *inputB, const BNNSNDArrayDescriptor *output,
                                    const BNNSFilterParameters *fp) {
    (void)fp;
    matmul(transA, transB, alpha, inputA, inputB, output, 0);
}
int bn_matmul(bool transA, bool transB, float alpha, const BNNSNDArrayDescriptor *A, const BNNSNDArrayDescriptor *B,
              const BNNSNDArrayDescriptor *C, float beta) {
    return matmul(transA, transB, alpha, A, B, C, beta);
}

/* ---- reductions ---- */
int bn_reduce(BNNSReduceFunction fn, const float *x, const float *w, const bn_dims *di, float *y, const bn_dims *dout,
              float eps) {
    size_t ci[BN_MAXD], co[BN_MAXD], pos[BN_MAXD];
    cstrides(di, ci); cstrides(dout, co);
    for (int k = 0; k < BN_MAXD; k++) if (dout->n[k] != di->n[k] && dout->n[k] != 1) return -1;
    double *acc = calloc(dout->count + 1, sizeof(double)), *cnt = calloc(dout->count + 1, sizeof(double)),
           *mx = calloc(dout->count + 1, sizeof(double));
    long long *arg = calloc(dout->count + 1, sizeof(long long));
    if (!acc || !cnt || !mx || !arg) { free(acc); free(cnt); free(mx); free(arg); return -1; }
    for (size_t o = 0; o < dout->count; o++) {
        switch (fn) {
        case BNNSReduceFunctionMax: case BNNSReduceFunctionArgMax: case BNNSReduceFunctionLogSumExp: mx[o] = -INFINITY; break;
        case BNNSReduceFunctionMin: case BNNSReduceFunctionArgMin: mx[o] = INFINITY; break;
        case BNNSReduceFunctionProduct: case BNNSReduceFunctionLogicalAnd: acc[o] = 1; break;
        default: break;
        }
    }
    /* pass 1 (and the only pass for most) */
    for (size_t i = 0; i < di->count; i++) {
        bn_unravel(di, i, pos);
        size_t o = 0, r = 0, rm = 1;
        for (int k = 0; k < BN_MAXD; k++) {
            if (dout->n[k] == 1 && di->n[k] != 1) { r += pos[k] * rm; rm *= di->n[k]; }
            else o += pos[k] * co[k];
        }
        float v = x[i], wv = w ? w[i] : 1.0f;
        switch (fn) {
        case BNNSReduceFunctionMax: if (v > mx[o]) mx[o] = v; break;
        case BNNSReduceFunctionMin: if (v < mx[o]) mx[o] = v; break;
        case BNNSReduceFunctionArgMax: if (v > mx[o]) { mx[o] = v; arg[o] = (long long)r; } break;
        case BNNSReduceFunctionArgMin: if (v < mx[o]) { mx[o] = v; arg[o] = (long long)r; } break;
        case BNNSReduceFunctionMean: acc[o] += (double)v * wv; cnt[o] += 1; break;
        case BNNSReduceFunctionMeanNonZero:
            if (w ? wv != 0 : v != 0) { acc[o] += (double)v * wv; cnt[o] += 1; }
            break;
        case BNNSReduceFunctionSum: acc[o] += (double)v * wv; break;
        case BNNSReduceFunctionSumSquare: acc[o] += (double)v * v * wv; break;
        case BNNSReduceFunctionSumLog: acc[o] += log((double)v + eps) * wv; break;
        case BNNSReduceFunctionL1Norm: acc[o] += fabs((double)v) * wv; break;
        case BNNSReduceFunctionL2Norm: acc[o] += (double)v * v * wv; break;
        case BNNSReduceFunctionLogicalOr: if (v != 0) acc[o] = 1; break;
        case BNNSReduceFunctionLogicalAnd: if (v == 0) acc[o] = 0; break;
        case BNNSReduceFunctionLogSumExp: if (v > mx[o]) mx[o] = v; break;
        case BNNSReduceFunctionProduct: acc[o] *= (double)v * wv; break;
        case BNNSReduceFunctionLogSum: acc[o] += (double)v * wv; break;
        case BNNSReduceFunctionNone: acc[o] = v; break;
        default: free(acc); free(cnt); free(mx); free(arg); return -1;
        }
    }
    if (fn == BNNSReduceFunctionLogSumExp)
        for (size_t i = 0; i < di->count; i++) {
            bn_unravel(di, i, pos);
            size_t o = 0;
            for (int k = 0; k < BN_MAXD; k++) if (!(dout->n[k] == 1 && di->n[k] != 1)) o += pos[k] * co[k];
            acc[o] += exp((double)x[i] - mx[o]) * (w ? w[i] : 1.0f);
        }
    for (size_t o = 0; o < dout->count; o++) {
        double r;
        switch (fn) {
        case BNNSReduceFunctionMax: case BNNSReduceFunctionMin: r = mx[o]; break;
        case BNNSReduceFunctionArgMax: case BNNSReduceFunctionArgMin: r = (double)arg[o]; break;
        case BNNSReduceFunctionMean: case BNNSReduceFunctionMeanNonZero: r = cnt[o] ? acc[o] / cnt[o] : 0; break;
        case BNNSReduceFunctionL2Norm: r = sqrt(acc[o]); break;
        case BNNSReduceFunctionLogSumExp: r = mx[o] + log(acc[o]); break;
        case BNNSReduceFunctionLogSum: r = log(acc[o]); break;
        default: r = acc[o]; break;
        }
        y[o] = (float)r;
    }
    free(acc); free(cnt); free(mx); free(arg);
    return 0;
}
int BNNSDirectApplyReduction(const BNNSLayerParametersReduction *p, const BNNSFilterParameters *fp) {
    (void)fp;
    if (!p) return -1;
    bn_dims di, dout;
    float *x = bn_load(&p->i_desc, NULL, &di), *w = p->w_desc.data ? bn_load(&p->w_desc, NULL, NULL) : NULL;
    if (!x || bn_dims_of(&p->o_desc, &dout)) FAIL(free(x), free(w));
    float *y = malloc(dout.count * sizeof(float) + 1);
    if (!y || bn_reduce(p->reduce_func, x, w, &di, y, &dout, p->epsilon)) FAIL(free(x), free(w), free(y));
    int r = bn_store(&p->o_desc, NULL, y, 0);
    free(x); free(w); free(y);
    return r;
}

/* ---- gather / scatter ---- */
static int gather_scatter(int scatter, size_t axis, BNNSReduceFunction op, const BNNSNDArrayDescriptor *input,
                          const BNNSNDArrayDescriptor *indices, BNNSNDArrayDescriptor *output) {
    bn_dims di, dx, dout;
    if (!input || !indices || !output || bn_dims_of(input, &di) || bn_dims_of(output, &dout)) return -1;
    if ((int)axis >= di.rank || di.rank != dout.rank) return -1;
    if (scatter && op != BNNSReduceFunctionNone && op != BNNSReduceFunctionSum) return -1;
    long long *ix = bn_load_index(indices, NULL, &dx);
    float *x = bn_load(input, NULL, NULL), *o = scatter ? bn_load(output, NULL, NULL) : malloc(dout.count * sizeof(float) + 1);
    if (!ix || !x || !o) FAIL(free(ix), free(x), free(o));
    const bn_dims *walk = scatter ? &di : &dout, *other = scatter ? &dout : &di;
    int full = dx.count == walk->count && dx.count != walk->n[axis];
    size_t cw[BN_MAXD], co[BN_MAXD], pos[BN_MAXD];
    cstrides(walk, cw); cstrides(other, co);
    for (size_t i = 0; i < walk->count; i++) {
        bn_unravel(walk, i, pos);
        long long k = full ? ix[i] : ix[pos[axis]];
        if (k < 0) k += (long long)other->n[axis];
        if (k < 0 || k >= (long long)other->n[axis]) FAIL(free(ix), free(x), free(o));
        size_t off = 0;
        for (int d = 0; d < BN_MAXD; d++) off += (d == (int)axis ? (size_t)k : pos[d]) * co[d];
        if (scatter) o[off] = op == BNNSReduceFunctionSum ? o[off] + x[i] : x[i];
        else o[i] = x[off];
    }
    int r = bn_store(output, NULL, o, 0);
    free(ix); free(x); free(o);
    return r;
}
int BNNSGather(size_t axis, const BNNSNDArrayDescriptor *input, const BNNSNDArrayDescriptor *indices,
               BNNSNDArrayDescriptor *output, const BNNSFilterParameters *fp) {
    (void)fp; return gather_scatter(0, axis, BNNSReduceFunctionNone, input, indices, output);
}
int BNNSScatter(size_t axis, BNNSReduceFunction op, const BNNSNDArrayDescriptor *input, const BNNSNDArrayDescriptor *indices,
                BNNSNDArrayDescriptor *output, const BNNSFilterParameters *fp) {
    (void)fp; return gather_scatter(1, axis, op, input, indices, output);
}
/* ND: indices' first dimension (size[0]) holds the lookup vector; the data's leading logical dimensions are indexed */
static int gather_scatter_nd(int scatter, BNNSReduceFunction op, const BNNSNDArrayDescriptor *input,
                             const BNNSNDArrayDescriptor *indices, BNNSNDArrayDescriptor *output) {
    bn_dims di, dx, dout;
    if (!input || !indices || !output || bn_dims_of(input, &di) || bn_dims_of(output, &dout)) return -1;
    if (scatter && op != BNNSReduceFunctionNone && op != BNNSReduceFunctionSum) return -1;
    long long *ix = bn_load_index(indices, NULL, &dx);
    float *x = bn_load(input, NULL, NULL), *o = scatter ? bn_load(output, NULL, NULL) : malloc(dout.count * sizeof(float) + 1);
    if (!ix || !x || !o) FAIL(free(ix), free(x), free(o));
    const bn_dims *data = scatter ? &dout : &di;      /* the tensor that is indexed */
    size_t L = dx.n[0], nlook = L ? dx.count / L : 0;
    if ((int)L > data->rank) FAIL(free(ix), free(x), free(o));
    /* the slice: logical dimensions L..rank-1 of the indexed tensor */
    size_t slice = 1;
    for (int k = (int)L; k < data->rank; k++) slice *= data->n[k];
    size_t cd[BN_MAXD];
    cstrides(data, cd);
    for (size_t q = 0; q < nlook; q++) {
        size_t base = 0;
        for (size_t j = 0; j < L; j++) {
            long long k = ix[q * L + j];
            if (k < 0) k += (long long)data->n[j];
            if (k < 0 || k >= (long long)data->n[j]) FAIL(free(ix), free(x), free(o));
            base += (size_t)k * cd[j];
        }
        for (size_t s = 0; s < slice; s++) {
            /* slice element s: its position over dimensions L.. */
            size_t off = base, t = s;
            for (int k = (int)L; k < data->rank; k++) { off += (t % data->n[k]) * cd[k]; t /= data->n[k]; }
            size_t lin = s + q * slice;   /* the other tensor: slice dimensions first, then the lookups */
            if (scatter) o[off] = op == BNNSReduceFunctionSum ? o[off] + x[lin] : x[lin];
            else o[lin] = x[off];
        }
    }
    int r = bn_store(output, NULL, o, 0);
    free(ix); free(x); free(o);
    return r;
}
int BNNSGatherND(const BNNSNDArrayDescriptor *input, const BNNSNDArrayDescriptor *indices, BNNSNDArrayDescriptor *output,
                 const BNNSFilterParameters *fp) {
    (void)fp; return gather_scatter_nd(0, BNNSReduceFunctionNone, input, indices, output);
}
int BNNSScatterND(BNNSReduceFunction op, const BNNSNDArrayDescriptor *input, const BNNSNDArrayDescriptor *indices,
                  BNNSNDArrayDescriptor *output, const BNNSFilterParameters *fp) {
    (void)fp; return gather_scatter_nd(1, op, input, indices, output);
}

/* ---- top-k ---- */
static void topk_of(const float *v, size_t n, size_t stride, size_t K, float *bv, long long *bi) {
    for (size_t k = 0; k < K; k++) { bv[k] = -INFINITY; bi[k] = -1; }
    for (size_t i = 0; i < n; i++) {
        float x = v[i * stride];
        if (bi[K - 1] >= 0 && !(x > bv[K - 1])) continue;
        size_t p = K - 1;
        while (p > 0 && (bi[p - 1] < 0 || x > bv[p - 1])) { bv[p] = bv[p - 1]; bi[p] = bi[p - 1]; p--; }
        bv[p] = x; bi[p] = (long long)i;
    }
}
int BNNSDirectApplyTopK(size_t K, size_t axis, size_t batch_size, const BNNSNDArrayDescriptor *input, size_t input_batch_stride,
                        BNNSNDArrayDescriptor *best_values, size_t best_values_batch_stride, BNNSNDArrayDescriptor *best_indices,
                        size_t best_indices_batch_stride, const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims di, dv;
    if (!K || !input || !best_values || bn_dims_of(input, &di) || bn_dims_of(best_values, &dv) || (int)axis >= di.rank) return -1;
    if (dv.n[axis] < K || K > di.n[axis]) return -1;
    int ib = bn_type_bits(input->data_type), vb = bn_type_bits(best_values->data_type);
    int xb = best_indices ? bn_type_bits(best_indices->data_type) : 8;
    size_t cs[BN_MAXD], cv[BN_MAXD], pos[BN_MAXD];
    cstrides(&di, cs); cstrides(&dv, cv);
    float *bvv = malloc(K * sizeof(float)); long long *bii = malloc(K * sizeof(long long));
    for (size_t b = 0; b < batch_size; b++) {
        const char *in = (const char *)input->data + b * input_batch_stride * ib / 8;
        float *x = bn_load(input, in, NULL), *ov = calloc(dv.count + 1, sizeof(float)), *oi = calloc(dv.count + 1, sizeof(float));
        if (!x || !ov || !oi) { free(x); free(ov); free(oi); free(bvv); free(bii); return -1; }
        size_t outer = di.count / di.n[axis];
        for (size_t o = 0; o < outer; o++) {
            /* position with the axis dimension at 0 */
            size_t t = o, off = 0, voff = 0;
            for (int k = 0; k < BN_MAXD; k++) {
                if (k == (int)axis) { pos[k] = 0; continue; }
                pos[k] = t % di.n[k]; t /= di.n[k];
                off += pos[k] * cs[k]; voff += pos[k] * cv[k];
            }
            topk_of(x + off, di.n[axis], cs[axis], K, bvv, bii);
            for (size_t k = 0; k < K; k++) { ov[voff + k * cv[axis]] = bvv[k]; oi[voff + k * cv[axis]] = (float)bii[k]; }
        }
        bn_store(best_values, (char *)best_values->data + b * best_values_batch_stride * vb / 8, ov, 0);
        if (best_indices && best_indices->data)
            bn_store(best_indices, (char *)best_indices->data + b * best_indices_batch_stride * xb / 8, oi, 0);
        free(x); free(ov); free(oi);
    }
    free(bvv); free(bii);
    return 0;
}
int BNNSDirectApplyInTopK(size_t K, size_t axis, size_t batch_size, const BNNSNDArrayDescriptor *input, size_t input_batch_stride,
                          const BNNSNDArrayDescriptor *test_indices, size_t test_indices_batch_stride,
                          BNNSNDArrayDescriptor *output, size_t output_batch_stride, const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims di, dt;
    if (!K || !input || !test_indices || !output || bn_dims_of(input, &di) || bn_dims_of(test_indices, &dt) || (int)axis >= di.rank)
        return -1;
    int ib = bn_type_bits(input->data_type), tb = bn_type_bits(test_indices->data_type), ob = bn_type_bits(output->data_type);
    size_t cs[BN_MAXD], pos[BN_MAXD];
    cstrides(&di, cs);
    for (size_t b = 0; b < batch_size; b++) {
        float *x = bn_load(input, (const char *)input->data + b * input_batch_stride * ib / 8, NULL);
        long long *t = bn_load_index(test_indices, (const char *)test_indices->data + b * test_indices_batch_stride * tb / 8, NULL);
        float *o = calloc(dt.count + 1, sizeof(float));
        if (!x || !t || !o) { free(x); free(t); free(o); return -1; }
        size_t outer = di.count / di.n[axis];
        for (size_t q = 0; q < outer && q < dt.count; q++) {
            size_t r = q, off = 0;
            for (int k = 0; k < BN_MAXD; k++) {
                if (k == (int)axis) continue;
                pos[k] = r % di.n[k]; r /= di.n[k]; off += pos[k] * cs[k];
            }
            long long ti = t[q];
            if (ti < 0 || ti >= (long long)di.n[axis]) continue;
            float tv = x[off + (size_t)ti * cs[axis]];
            size_t greater = 0;
            for (size_t i = 0; i < di.n[axis]; i++) if (x[off + i * cs[axis]] > tv) greater++;
            o[q] = greater < K;   /* ties are all in the top K */
        }
        bn_store(output, (char *)output->data + b * output_batch_stride * ob / 8, o, 0);
        free(x); free(t); free(o);
    }
    return 0;
}

/* ---- band part and shuffle ---- */
int BNNSBandPart(const int num_lower, const int num_upper, const BNNSNDArrayDescriptor *input, BNNSNDArrayDescriptor *output,
                 const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims di, dout;
    if (!input || !output || bn_dims_of(input, &di) || bn_dims_of(output, &dout) || !same_dims(&di, &dout) || di.rank < 2) return -1;
    float *x = bn_load(input, NULL, NULL);
    if (!x) return -1;
    /* the innermost matrix: the two dimensions with the lowest strides (column = the fastest) */
    size_t st[BN_MAXD]; bn_strides(input, st);
    int c0 = 0, c1 = 1;
    for (int k = 0; k < di.rank; k++) if (st[k] < st[c0]) c0 = k;
    c1 = c0 == 0 ? 1 : 0;
    for (int k = 0; k < di.rank; k++) if (k != c0 && st[k] < st[c1]) c1 = k;
    size_t pos[BN_MAXD];
    for (size_t i = 0; i < di.count; i++) {
        bn_unravel(&di, i, pos);
        long long col = (long long)pos[c0], row = (long long)pos[c1];
        int keep = (num_lower < 0 || row - col <= num_lower) && (num_upper < 0 || col - row <= num_upper);
        if (!keep) x[i] = 0;
    }
    int r = bn_store(output, NULL, x, 0);
    free(x);
    return r;
}
int BNNSShuffle(const BNNSShuffleType type, const BNNSNDArrayDescriptor *input, BNNSNDArrayDescriptor *output,
                const BNNSFilterParameters *fp) {
    (void)fp;
    bn_dims di, dout;
    if (!input || !output || bn_dims_of(input, &di) || bn_dims_of(output, &dout) || di.rank < 3 || dout.rank != di.rank) return -1;
    /* NCHW: logical dimensions (W, H, C[, N]) */
    size_t W = di.n[0], H = di.n[1], C = di.n[2], N = di.rank > 3 ? di.n[3] : 1;
    size_t oW = dout.n[0], oH = dout.n[1], oC = dout.n[2];
    int up = type == BNNSShuffleTypePixelShuffleNCHW || type == BNNSShuffleTypeDepthToSpaceNCHW;
    if (type > BNNSShuffleTypeSpaceToDepthNCHW) return -1;
    size_t r = up ? (W ? oW / W : 0) : (oW ? W / oW : 0);
    if (!r || (up ? (oW != W * r || oH != H * r || oC * r * r != C) : (W != oW * r || H != oH * r || C * r * r != oC))) return -1;
    float *x = bn_load(input, NULL, NULL), *o = malloc(dout.count * sizeof(float) + 1);
    if (!x || !o) FAIL(free(x), free(o));
    int pixel = type == BNNSShuffleTypePixelShuffleNCHW || type == BNNSShuffleTypePixelUnshuffleNCHW;
    /* depth-to-space (DCR) puts the block index outside the channel; pixel shuffle (CRD) inside */
    size_t sC = up ? oC : C;
    for (size_t n = 0; n < N; n++)
        for (size_t c = 0; c < sC; c++)
            for (size_t y = 0; y < (up ? oH : H); y++)
                for (size_t xw = 0; xw < (up ? oW : W); xw++) {
                    size_t by = y % r, bx = xw % r, ly = y / r, lx = xw / r;
                    size_t deep = pixel ? c * r * r + by * r + bx : (by * r + bx) * sC + c;
                    if (up) o[((n * oC + c) * oH + y) * oW + xw] = x[((n * C + deep) * H + ly) * W + lx];
                    else o[((n * oC + deep) * oH + ly) * oW + lx] = x[((n * C + c) * H + y) * W + xw];
                }
    int rr = bn_store(output, NULL, o, 0);
    free(x); free(o);
    return rr;
}

/* ---- norms and clipping ---- */
static int norm_group(const bn_dims *d, uint32_t axis_flags, bn_dims *g) {
    *g = *d;
    g->count = 1;
    for (int k = 0; k < BN_MAXD; k++) {
        if (k < d->rank && (!axis_flags || (axis_flags >> k) & 1)) g->n[k] = 1;
        g->count *= g->n[k];
    }
    return 0;
}
int BNNSClipByValue(BNNSNDArrayDescriptor *dest, const BNNSNDArrayDescriptor *src, float min_val, float max_val) {
    bn_dims a;
    float *x = bn_load(src, NULL, &a);
    if (!x || !dest) FAIL(free(x));
    for (size_t i = 0; i < a.count; i++) x[i] = fminf(fmaxf(x[i], min_val), max_val);
    int r = bn_store(dest, NULL, x, 0);
    free(x);
    return r;
}
int BNNSClipByNorm(BNNSNDArrayDescriptor *dest, const BNNSNDArrayDescriptor *src, float max_norm, uint32_t axis_flags) {
    bn_dims a, g;
    float *x = bn_load(src, NULL, &a);
    if (!x || !dest) FAIL(free(x));
    norm_group(&a, axis_flags, &g);
    float *nrm = malloc(g.count * sizeof(float) + 1);
    if (!nrm || bn_reduce(BNNSReduceFunctionL2Norm, x, NULL, &a, nrm, &g, 0)) FAIL(free(x), free(nrm));
    size_t cg[BN_MAXD], pos[BN_MAXD];
    cstrides(&g, cg);
    for (size_t i = 0; i < a.count; i++) {
        bn_unravel(&a, i, pos);
        size_t o = 0;
        for (int k = 0; k < BN_MAXD; k++) o += (g.n[k] == 1 ? 0 : pos[k]) * cg[k];
        if (nrm[o] > max_norm) x[i] *= max_norm / nrm[o];
    }
    int r = bn_store(dest, NULL, x, 0);
    free(x); free(nrm);
    return r;
}
int BNNSClipByGlobalNorm(BNNSNDArrayDescriptor **dest, const BNNSNDArrayDescriptor **src, size_t count, float max_norm,
                         float use_norm) {
    if (!dest || !src) return -1;
    double g = use_norm;
    if (g == 0) {
        for (size_t t = 0; t < count; t++) {
            bn_dims a; float *x = bn_load(src[t], NULL, &a);
            if (!x) return -1;
            for (size_t i = 0; i < a.count; i++) g += (double)x[i] * x[i];
            free(x);
        }
        g = sqrt(g);
    }
    float s = g > max_norm ? (float)(max_norm / g) : 1.0f;
    for (size_t t = 0; t < count; t++) {
        bn_dims a; float *x = bn_load(src[t], NULL, &a);
        if (!x) return -1;
        for (size_t i = 0; i < a.count; i++) x[i] *= s;
        int r = bn_store(dest[t], NULL, x, 0);
        free(x);
        if (r) return r;
    }
    return 0;
}
int BNNSComputeNorm(BNNSNDArrayDescriptor *dest, const BNNSNDArrayDescriptor *src, BNNSNormType norm_type, uint32_t axis_flags) {
    if (norm_type != BNNSL2Norm) return -1;
    bn_dims a, g, dd;
    float *x = bn_load(src, NULL, &a);
    if (!x || !dest || bn_dims_of(dest, &dd)) FAIL(free(x));
    norm_group(&a, axis_flags, &g);
    if (g.count != dd.count) FAIL(free(x));
    float *nrm = malloc(g.count * sizeof(float) + 1);
    if (!nrm || bn_reduce(BNNSReduceFunctionL2Norm, x, NULL, &a, nrm, &g, 0)) FAIL(free(x), free(nrm));
    int r = bn_store(dest, NULL, nrm, 0);
    free(x); free(nrm);
    return r;
}
int BNNSComputeNormBackward(const void *in, BNNSNDArrayDescriptor *in_delta, const void *out,
                            const BNNSNDArrayDescriptor *out_delta, BNNSNormType norm_type, uint32_t axis_flags) {
    if (norm_type != BNNSL2Norm || !in_delta || !out_delta) return -1;
    bn_dims a, g;
    float *x = bn_load(in_delta, in, &a), *y = bn_load(out_delta, out, NULL), *dy = bn_load(out_delta, NULL, NULL);
    if (!x || !y || !dy) FAIL(free(x), free(y), free(dy));
    norm_group(&a, axis_flags, &g);
    size_t cg[BN_MAXD], pos[BN_MAXD];
    cstrides(&g, cg);
    for (size_t i = 0; i < a.count; i++) {
        bn_unravel(&a, i, pos);
        size_t o = 0;
        for (int k = 0; k < BN_MAXD; k++) o += (g.n[k] == 1 ? 0 : pos[k]) * cg[k];
        x[i] = y[o] != 0 ? dy[o] * x[i] / y[o] : 0;
    }
    int r = bn_store(in_delta, NULL, x, in_delta->flags == BNNSNDArrayFlagBackpropAccumulate);
    free(x); free(y); free(dy);
    return r;
}

/* ---- crop and resize ---- */
/* input: (W, H, C, N); roi: (4 or 5, R) rows [batch_index,] box; output: (cW, cH, C, R) */
static int crop_resize(int backward, const BNNSLayerParametersCropResize *p, const BNNSNDArrayDescriptor *img,
                       const BNNSNDArrayDescriptor *roi, const BNNSNDArrayDescriptor *crops) {
    bn_dims di, dr, dc;
    if (!p || !img || !roi || !crops || bn_dims_of(img, &di) || bn_dims_of(roi, &dr) || bn_dims_of(crops, &dc)) return -1;
    if (di.rank < 3 || dc.rank < 3) return -1;
    size_t W = di.n[0], H = di.n[1], C = di.n[2], N = di.rank > 3 ? di.n[3] : 1;
    size_t cw = dc.n[0], ch = dc.n[1], R = dc.rank > 3 ? dc.n[3] : 1;
    if (dc.n[2] != C || dr.count < R * 4) return -1;
    size_t per = dr.n[0] >= 4 ? dr.n[0] : 4;
    float *box = bn_load(roi, NULL, NULL), *x = backward ? calloc(di.count + 1, sizeof(float)) : bn_load(img, NULL, NULL);
    float *o = backward ? bn_load(crops, NULL, NULL) : calloc(dc.count + 1, sizeof(float));
    if (!box || !x || !o) FAIL(free(box), free(x), free(o));
    for (size_t r = 0; r < R; r++) {
        const float *b = box + r * per;
        size_t bi = per >= 5 ? (size_t)b[0] : (N > 1 ? r : 0);
        const float *q = per >= 5 ? b + 1 : b;
        float y1, x1, y2, x2;
        switch (p->box_coordinate_mode) {
        case BNNSCornersWidthFirst: x1 = q[0]; y1 = q[1]; x2 = q[2]; y2 = q[3]; break;
        case BNNSCenterSizeHeightFirst: y1 = q[0] - q[2] / 2; x1 = q[1] - q[3] / 2; y2 = q[0] + q[2] / 2; x2 = q[1] + q[3] / 2; break;
        case BNNSCenterSizeWidthFirst: x1 = q[0] - q[2] / 2; y1 = q[1] - q[3] / 2; x2 = q[0] + q[2] / 2; y2 = q[1] + q[3] / 2; break;
        default: y1 = q[0]; x1 = q[1]; y2 = q[2]; x2 = q[3]; break;
        }
        float sc = p->spatial_scale ? p->spatial_scale : 1;
        if (p->normalized_coordinates) { x1 *= (W - 1); x2 *= (W - 1); y1 *= (H - 1); y2 *= (H - 1); }
        else { x1 *= sc; x2 *= sc; y1 *= sc; y2 *= sc; }
        if (bi >= N) continue;
        for (size_t c = 0; c < C; c++)
            for (size_t yy = 0; yy < ch; yy++)
                for (size_t xx = 0; xx < cw; xx++) {
                    float fy = ch > 1 ? y1 + (y2 - y1) * yy / (ch - 1) : (y1 + y2) / 2;
                    float fx = cw > 1 ? x1 + (x2 - x1) * xx / (cw - 1) : (x1 + x2) / 2;
                    size_t oi = ((r * C + c) * ch + yy) * cw + xx;
                    if (fy < 0 || fy > H - 1 || fx < 0 || fx > W - 1) {
                        if (!backward) o[oi] = p->extrapolation_value;
                        continue;
                    }
                    const size_t base = (bi * C + c) * H * W;
                    if (p->method == BNNSInterpolationMethodNearest) {
                        size_t ix = (size_t)lrintf(fx), iy = (size_t)lrintf(fy);
                        if (backward) x[base + iy * W + ix] += o[oi]; else o[oi] = x[base + iy * W + ix];
                        continue;
                    }
                    size_t x0 = (size_t)floorf(fx), y0 = (size_t)floorf(fy);
                    size_t x1i = x0 + 1 < W ? x0 + 1 : x0, y1i = y0 + 1 < H ? y0 + 1 : y0;
                    float ax = fx - x0, ay = fy - y0;
                    float w00 = (1 - ax) * (1 - ay), w01 = ax * (1 - ay), w10 = (1 - ax) * ay, w11 = ax * ay;
                    if (backward) {
                        x[base + y0 * W + x0] += w00 * o[oi]; x[base + y0 * W + x1i] += w01 * o[oi];
                        x[base + y1i * W + x0] += w10 * o[oi]; x[base + y1i * W + x1i] += w11 * o[oi];
                    } else
                        o[oi] = w00 * x[base + y0 * W + x0] + w01 * x[base + y0 * W + x1i] +
                                w10 * x[base + y1i * W + x0] + w11 * x[base + y1i * W + x1i];
                }
    }
    int rr = backward ? bn_store(img, NULL, x, img->flags == BNNSNDArrayFlagBackpropAccumulate) : bn_store(crops, NULL, o, 0);
    free(box); free(x); free(o);
    return rr;
}
int BNNSCropResize(const BNNSLayerParametersCropResize *layer_params, const BNNSNDArrayDescriptor *input,
                   const BNNSNDArrayDescriptor *roi, BNNSNDArrayDescriptor *output, const BNNSFilterParameters *fp) {
    (void)fp; return crop_resize(0, layer_params, input, roi, output);
}
int BNNSCropResizeBackward(const BNNSLayerParametersCropResize *layer_params, BNNSNDArrayDescriptor *in_delta,
                           const BNNSNDArrayDescriptor *roi, const BNNSNDArrayDescriptor *out_delta,
                           const BNNSFilterParameters *fp) {
    (void)fp; return crop_resize(1, layer_params, in_delta, roi, out_delta);
}

/* ---- quantizer ---- */
int bn_quantize(const BNNSLayerParametersQuantization *p, const void *in, void *out) {
    bn_dims di, dout;
    float *x = bn_load(&p->i_desc, in, &di);
    if (!x || bn_dims_of(&p->o_desc, &dout) || dout.count != di.count) FAIL(free(x));
    float *s = p->scale.data ? bn_load(&p->scale, NULL, NULL) : NULL, *b = p->bias.data ? bn_load(&p->bias, NULL, NULL) : NULL;
    int axis = -1;
    for (int k = 0; k < BN_MAXD; k++) if (p->axis_mask == ((size_t)1 << k)) axis = k;
    size_t cs[BN_MAXD]; cstrides(&di, cs);
    /* the descriptors' own scale / bias don't apply: write raw values */
    BNNSNDArrayDescriptor od = p->o_desc; od.data_scale = 1; od.data_bias = 0;
    for (size_t i = 0; i < di.count; i++) {
        size_t c = (axis >= 0 && axis < di.rank) ? (i / cs[axis]) % di.n[axis] : 0;
        float sv = s ? s[c] : 1, bv = b ? b[c] : 0;
        x[i] = p->function == BNNSQuantizerFunctionQuantize ? sv * x[i] + bv : (x[i] - bv) / sv;
    }
    int r = bn_store(&od, out, x, 0);
    free(x); free(s); free(b);
    return r;
}
int BNNSDirectApplyQuantizer(const BNNSLayerParametersQuantization *p, const BNNSFilterParameters *fp, size_t batch_size,
                             size_t input_stride, size_t output_stride) {
    (void)fp;
    if (!p) return -1;
    if (p->axis_mask && p->axis_mask == ((size_t)1 << bn_layout_rank(p->i_desc.layout))) {
        /* scale / bias per batch member */
        for (size_t b = 0; b < batch_size; b++) {
            BNNSLayerParametersQuantization q = *p;
            float sv = 1, bv = 0;
            if (p->scale.data) sv = bn_read(&p->scale, p->scale.data, b);
            if (p->bias.data) bv = bn_read(&p->bias, p->bias.data, b);
            float sb[2] = {sv, bv};
            q.axis_mask = 0;
            q.scale.data = &sb[0]; q.scale.data_type = BNNSDataTypeFloat32; q.scale.layout = BNNSDataLayoutVector; q.scale.size[0] = 1;
            q.bias.data = &sb[1]; q.bias.data_type = BNNSDataTypeFloat32; q.bias.layout = BNNSDataLayoutVector; q.bias.size[0] = 1;
            if (bn_quantize(&q, (const char *)p->i_desc.data + b * input_stride * bn_type_bits(p->i_desc.data_type) / 8,
                            (char *)p->o_desc.data + b * output_stride * bn_type_bits(p->o_desc.data_type) / 8)) return -1;
        }
        return 0;
    }
    for (size_t b = 0; b < batch_size; b++)
        if (bn_quantize(p, (const char *)p->i_desc.data + b * input_stride * bn_type_bits(p->i_desc.data_type) / 8,
                        (char *)p->o_desc.data + b * output_stride * bn_type_bits(p->o_desc.data_type) / 8)) return -1;
    return 0;
}

/* ---- sparse fully connected weights: BNNS packs them its own way; isim stores them dense ---- */
static int sparsify_dense(const BNNSNDArrayDescriptor *shape, BNNSNDArrayDescriptor *out, float *dense) {
    bn_dims ds;
    if (bn_dims_of(shape, &ds)) return -1;
    BNNSNDArrayDescriptor d = *out;
    d.layout = BNNSDataLayoutRowMajorMatrix;
    d.size[0] = shape->size[0]; d.size[1] = shape->size[1];
    memset(d.stride, 0, sizeof d.stride);
    return bn_store(&d, NULL, dense, 0);
}
int BNNSNDArrayFullyConnectedSparsifySparseCOO(const BNNSNDArrayDescriptor *in_dense_shape, const BNNSNDArrayDescriptor *in_indices,
                                               const BNNSNDArrayDescriptor *in_values, BNNSNDArrayDescriptor *out,
                                               const BNNSSparsityParameters *sparsity_params, const size_t batch_size,
                                               void *workspace, const size_t workspace_size, const BNNSFilterParameters *fp) {
    (void)sparsity_params; (void)batch_size; (void)workspace; (void)workspace_size; (void)fp;
    if (!in_dense_shape || !in_indices || !in_values || !out) return -1;
    size_t cols = in_dense_shape->size[0], rows = in_dense_shape->size[1];
    bn_dims dv, dx;
    float *v = bn_load(in_values, NULL, &dv); long long *ix = bn_load_index(in_indices, NULL, &dx);
    float *dense = calloc(rows * cols + 1, sizeof(float));
    if (!v || !ix || !dense) FAIL(free(v), free(ix), free(dense));
    for (size_t k = 0; k < dv.count && 2 * k + 1 < dx.count; k++) {
        long long r = ix[2 * k], c = ix[2 * k + 1];
        if (r < 0 || c < 0 || (size_t)r >= rows || (size_t)c >= cols) FAIL(free(v), free(ix), free(dense));
        dense[(size_t)r * cols + (size_t)c] = v[k];
    }
    int res = sparsify_dense(in_dense_shape, out, dense);
    free(v); free(ix); free(dense);
    return res;
}
int BNNSNDArrayFullyConnectedSparsifySparseCSR(const BNNSNDArrayDescriptor *in_dense_shape, const BNNSNDArrayDescriptor *in_column_indices,
                                               const BNNSNDArrayDescriptor *in_row_starts, const BNNSNDArrayDescriptor *in_values,
                                               BNNSNDArrayDescriptor *out, const BNNSSparsityParameters *sparsity_params,
                                               const size_t batch_size, void *workspace, const size_t workspace_size,
                                               const BNNSFilterParameters *fp) {
    (void)sparsity_params; (void)batch_size; (void)workspace; (void)workspace_size; (void)fp;
    if (!in_dense_shape || !in_column_indices || !in_row_starts || !in_values || !out) return -1;
    size_t cols = in_dense_shape->size[0], rows = in_dense_shape->size[1];
    bn_dims dv, dc, dr;
    float *v = bn_load(in_values, NULL, &dv);
    long long *ci = bn_load_index(in_column_indices, NULL, &dc), *rs = bn_load_index(in_row_starts, NULL, &dr);
    float *dense = calloc(rows * cols + 1, sizeof(float));
    if (!v || !ci || !rs || !dense || dr.count < rows + 1) FAIL(free(v), free(ci), free(rs), free(dense));
    for (size_t r = 0; r < rows; r++)
        for (long long k = rs[r]; k < rs[r + 1]; k++) {
            if (k < 0 || (size_t)k >= dv.count || ci[k] < 0 || (size_t)ci[k] >= cols) FAIL(free(v), free(ci), free(rs), free(dense));
            dense[r * cols + (size_t)ci[k]] = v[k];
        }
    int res = sparsify_dense(in_dense_shape, out, dense);
    free(v); free(ci); free(rs); free(dense);
    return res;
}
