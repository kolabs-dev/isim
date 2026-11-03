// isim Accelerate BNNSGraph (issue #824): shape inference and the kernels of isim's graph engine (row-major float tensors).
#include "bnns_core.h"
#include "bnns_graph_engine.h"
#include <stdint.h>

static long long gcount(const gshape *s) { long long n = 1; for (int k = 0; k < s->rank; k++) n *= s->d[k]; return n; }
static void gstrides(const gshape *s, long long *st) { long long n = 1; for (int k = s->rank - 1; k >= 0; k--) { st[k] = n; n *= s->d[k]; } }
static void gunravel(const gshape *s, long long i, long long *pos) {
    for (int k = s->rank - 1; k >= 0; k--) { pos[k] = s->d[k] ? i % s->d[k] : 0; i = s->d[k] ? i / s->d[k] : 0; }
}
static int gaxis(long long a, int rank) { return (int)(a < 0 ? a + rank : a); }
static int gbroadcast(const gshape *a, const gshape *b, gshape *o) {
    int r = a->rank > b->rank ? a->rank : b->rank;
    o->rank = r;
    for (int k = 0; k < r; k++) {
        int ia = k - (r - a->rank), ib = k - (r - b->rank);
        long long da = ia >= 0 ? a->d[ia] : 1, db = ib >= 0 ? b->d[ib] : 1;
        if (da != db && da != 1 && db != 1) return -1;
        o->d[k] = da == 1 ? db : da;
    }
    return 0;
}
static long long gbidx(const gshape *s, const gshape *o, const long long *pos) {
    long long st[GMAXR], off = 0;
    gstrides(s, st);
    for (int k = 0; k < s->rank; k++) { int ko = k + (o->rank - s->rank); off += (s->d[k] == 1 ? 0 : pos[ko]) * st[k]; }
    return off;
}

/* ---- padding arithmetic shared by convolution and pooling ---- */
static void pads_for(long long kind, long long in, long long k, long long s, long long dil, const long long *custom, int transposed,
                     long long *pb, long long *pe) {
    long long eff = dil * (k - 1) + 1;
    if (kind == 1) { *pb = custom[0]; *pe = custom[1]; return; }
    if (kind == 0) { *pb = *pe = 0; return; }
    long long out = transposed ? in * s : (in + s - 1) / s;
    long long total = transposed ? (in - 1) * s + eff - out : (out - 1) * s + eff - in;
    if (total < 0) total = 0;
    if (kind == 2) { *pb = total / 2; *pe = total - total / 2; }   /* same: the extra at the end */
    else { *pe = total / 2; *pb = total - total / 2; }             /* lower: the extra at the beginning */
}

/* ---- shape inference ---- */
static int infer_node(bn_graph *g, gnode *n) {
    const gshape *a = n->nin > 0 ? &g->nodes[n->in[0]].shape : NULL, *b = n->nin > 1 ? &g->nodes[n->in[1]].shape : NULL;
    gshape o = {0};
    switch (n->op) {
    case GOP_ARG: case GOP_CONST: return 0;
    case GOP_PICK: {
        const gnode *p = &g->nodes[n->in[0]];
        n->shape = n->ia[0] == 0 ? p->shape : n->ia[0] == 1 ? p->shape2 : p->shape3;
        return 0;
    }
    case GOP_UNARY: case GOP_CAST: case GOP_SOFTMAX: case GOP_CUMSUM: case GOP_NORM: case GOP_PRELU: case GOP_ARGSORT:
    case GOP_SLICE_SET: case GOP_SCATTER: case GOP_SCATTER_AXIS: case GOP_SCATTER_ND:
        n->shape = *a; return 0;
    case GOP_BINARY: return gbroadcast(a, b, &n->shape);
    case GOP_SELECT: case GOP_FMA: {
        gshape t;
        if (gbroadcast(a, b, &t) || gbroadcast(&t, &g->nodes[n->in[2]].shape, &n->shape)) return -1;
        return 0;
    }
    case GOP_REDUCE: {
        int keep = (int)n->ia[1], cnt = (int)n->ia[2], red[GMAXR] = {0};
        for (int k = 0; k < cnt; k++) { int ax = gaxis(n->ia[3 + k], a->rank); if (ax < 0 || ax >= a->rank) return -1; red[ax] = 1; }
        if (!cnt) for (int k = 0; k < a->rank; k++) red[k] = 1;
        for (int k = 0; k < a->rank; k++) { if (red[k]) { if (keep) o.d[o.rank++] = 1; } else o.d[o.rank++] = a->d[k]; }
        n->shape = o; return 0;
    }
    case GOP_ARGREDUCE: {
        int ax = gaxis(n->ia[1], a->rank);
        if (ax < 0 || ax >= a->rank) return -1;
        for (int k = 0; k < a->rank; k++) { if (k == ax) { if (n->ia[2]) o.d[o.rank++] = 1; } else o.d[o.rank++] = a->d[k]; }
        n->shape = o; return 0;
    }
    case GOP_TOPK: {
        int ax = gaxis(n->ia[1], a->rank);
        if (ax < 0 || ax >= a->rank || n->ia[0] > a->d[ax]) return -1;
        n->shape = *a; n->shape.d[ax] = n->ia[0]; n->shape2 = n->shape;
        return 0;
    }
    case GOP_MATMUL: case GOP_LINEAR: {
        gshape A = *a, B = *b;
        if (A.rank < 1 || B.rank < 1) return -1;
        int ta = n->op == GOP_MATMUL && n->ia[0], tb = n->op == GOP_LINEAR ? 1 : (int)n->ia[1];
        if (A.rank == 1) { A.rank = 2; A.d[1] = A.d[0]; A.d[0] = 1; }
        if (B.rank == 1) { B.rank = 2; B.d[1] = 1; }
        long long m = ta ? A.d[A.rank - 1] : A.d[A.rank - 2], ka = ta ? A.d[A.rank - 2] : A.d[A.rank - 1];
        long long kb = tb ? B.d[B.rank - 1] : B.d[B.rank - 2], nn = tb ? B.d[B.rank - 2] : B.d[B.rank - 1];
        if (ka != kb) return -1;
        gshape ba = A, bb = B; ba.rank -= 2; bb.rank -= 2;
        if (gbroadcast(&ba, &bb, &o)) return -1;
        o.d[o.rank++] = m; o.d[o.rank++] = nn;
        if (a->rank == 1) { o.d[o.rank - 2] = o.d[o.rank - 1]; o.rank--; }
        n->shape = o; return 0;
    }
    case GOP_CONV: {
        int tr = (int)n->ia[0], ns = (int)n->ia[3];
        const long long *st = n->ia + 4, *dl = n->ia + 4 + ns, *cp = n->ia + 4 + 2 * ns, *op = n->ia + 4 + 4 * ns;
        if (a->rank != ns + 2 || b->rank != ns + 2) return -1;
        o.rank = a->rank; o.d[0] = a->d[0];
        long long groups = n->ia[1] > 0 ? n->ia[1] : 1;
        o.d[1] = tr ? b->d[1] * groups : b->d[0];
        for (int k = 0; k < ns; k++) {
            long long in = a->d[2 + k], kk = b->d[2 + k], pb, pe;
            pads_for(n->ia[2], in, kk, st[k], dl[k], cp + 2 * k, tr, &pb, &pe);
            long long eff = dl[k] * (kk - 1) + 1;
            o.d[2 + k] = tr ? (in - 1) * st[k] + eff - pb - pe + op[k] : (in + pb + pe - eff) / st[k] + 1;
            if (o.d[2 + k] <= 0) return -1;
        }
        n->shape = o; return 0;
    }
    case GOP_POOL: {
        int ns = (int)n->ia[3];
        const long long *kr = n->ia + 4, *st = n->ia + 4 + ns, *cp = n->ia + 4 + 2 * ns;
        if (a->rank < ns + 1) return -1;
        o = *a;
        for (int k = 0; k < ns; k++) {
            int dk = a->rank - ns + k;
            long long in = a->d[dk], pb, pe;
            pads_for(n->ia[2], in, kr[k], st[k], 1, cp + 2 * k, 0, &pb, &pe);
            long long span = in + pb + pe - kr[k];
            o.d[dk] = (n->ia[1] ? (span + st[k] - 1) / st[k] : span / st[k]) + 1;
            if (o.d[dk] <= 0) return -1;
        }
        n->shape = o; return 0;
    }
    case GOP_RESHAPE: {
        int r = (int)n->ia[0], inf = -1; long long prod = 1;
        o.rank = r;
        for (int k = 0; k < r; k++) {
            long long v = n->ia[1 + k];
            if (v == 0) v = k < a->rank ? a->d[k] : 1;
            if (v < 0) { if (inf >= 0) return -1; inf = k; v = 1; }
            o.d[k] = v; prod *= v;
        }
        if (inf >= 0) { if (!prod || gcount(a) % prod) return -1; o.d[inf] = gcount(a) / prod; }
        if (gcount(&o) != gcount(a)) return -1;
        n->shape = o; return 0;
    }
    case GOP_RESHAPE_DYN: {
        const gnode *s = &g->nodes[n->in[1]];
        if (s->op != GOP_CONST && s->op != GOP_SHAPEOF) return -1;   /* the shape must be known before running */
        if (s->op == GOP_SHAPEOF) { n->shape = g->nodes[s->in[0]].shape; return gcount(&n->shape) == gcount(a) ? 0 : -1; }
        long long c = gcount(&s->shape);
        if (c > GMAXR) return -1;
        n->ia[0] = c;
        for (int k = 0; k < c; k++) n->ia[1 + k] = (long long)s->cdata[k];
        int op = n->op; n->op = GOP_RESHAPE;
        int r = infer_node(g, n);
        n->op = op;
        return r;
    }
    case GOP_TRANSPOSE: {
        o.rank = a->rank;
        for (int k = 0; k < a->rank; k++) { int p = gaxis(n->ia[k], a->rank); if (p < 0 || p >= a->rank) return -1; o.d[k] = a->d[p]; }
        n->shape = o; return 0;
    }
    case GOP_SHAPEOF: o.rank = 1; o.d[0] = a->rank; n->shape = o; return 0;
    case GOP_SLICE: {
        int dims = n->nia / 4;
        for (int k = 0; k < a->rank; k++) {
            long long st = 0, en = a->d[k], sp = 1, sq = 0;
            if (k < dims) {
                st = n->ia[4 * k]; en = n->ia[4 * k + 1]; sp = n->ia[4 * k + 2]; sq = n->ia[4 * k + 3];
                if (st < 0) st += a->d[k];
                if (en < 0) en += a->d[k];
                if (en > a->d[k]) en = a->d[k];
                if (sq) en = st + 1;
            }
            if (st < 0 || st > a->d[k] || sp <= 0) return -1;
            long long len = en > st ? (en - st + sp - 1) / sp : 0;
            if (!sq) o.d[o.rank++] = len;
        }
        n->shape = o; return 0;
    }
    case GOP_PAD: {
        int cnt = (int)n->ia[1];
        n->shape = *a;
        for (int k = 0; k < cnt; k++) {
            int d = a->rank - cnt + k;
            if (d < 0) return -1;
            n->shape.d[d] += n->ia[2 + 2 * k] + n->ia[3 + 2 * k];
        }
        return 0;
    }
    case GOP_CONCAT: {
        int ax = gaxis(n->ia[0], a->rank);
        if (ax < 0 || ax >= a->rank) return -1;
        o = *a; o.d[ax] = 0;
        for (int k = 0; k < n->nin; k++) {
            const gshape *s = &g->nodes[n->in[k]].shape;
            if (s->rank != a->rank) return -1;
            for (int q = 0; q < a->rank; q++) if (q != ax && s->d[q] != a->d[q]) return -1;
            o.d[ax] += s->d[ax];
        }
        n->shape = o; return 0;
    }
    case GOP_GATHER: {
        int ax = gaxis(n->ia[0], a->rank), bd = (int)n->ia[1];
        if (ax < 0 || ax >= a->rank) return -1;
        for (int k = 0; k < ax; k++) o.d[o.rank++] = a->d[k];
        for (int k = bd; k < b->rank; k++) o.d[o.rank++] = b->d[k];
        for (int k = ax + 1; k < a->rank; k++) o.d[o.rank++] = a->d[k];
        if (o.rank > GMAXR) return -1;
        n->shape = o; return 0;
    }
    case GOP_GATHER_AXIS: if (b->rank != a->rank) return -1; n->shape = *b; return 0;
    case GOP_GATHER_ND: {
        int bd = (int)n->ia[0], K = (int)b->d[b->rank - 1];
        for (int k = 0; k < b->rank - 1; k++) o.d[o.rank++] = b->d[k];
        for (int k = bd + K; k < a->rank; k++) o.d[o.rank++] = a->d[k];
        if (o.rank > GMAXR) return -1;
        n->shape = o; return 0;
    }
    case GOP_RNN: case GOP_GRU: case GOP_LSTM: {
        /* x [s, b, I], h0 [b, H] */
        const gshape *h = b;
        if (a->rank != 3 || h->rank != 2) return -1;
        long long H = h->d[1], dirs = n->op == GOP_LSTM && n->ia[5] ? 2 : 1;
        if (dirs == 2) H /= 2;
        int seq = (int)(n->op == GOP_RNN ? n->ia[2] : n->op == GOP_GRU ? n->ia[4] : n->ia[4]);
        o.rank = 3; o.d[0] = seq ? a->d[0] : 1; o.d[1] = a->d[1]; o.d[2] = H * dirs;
        n->shape = o;
        n->shape2.rank = 2; n->shape2.d[0] = a->d[1]; n->shape2.d[1] = H * dirs;
        n->shape3 = n->shape2;
        return 0;
    }
    default: return -1;
    }
}
int graph_infer(bn_graph *g, const gshape *dyn) {
    for (int k = 0; k < g->n_in && dyn; k++) {
        gnode *a = &g->nodes[g->in_args[k]];
        if (dyn[k].rank) a->shape = dyn[k];
    }
    for (int i = 0; i < g->n; i++) if (infer_node(g, &g->nodes[i])) return -1;
    return 0;
}

/* ---- element functions ---- */
static float sigmf(float x) { return 1.0f / (1.0f + expf(-x)); }
static float unary(int fn, float x, float a, float b) {
    switch (fn) {
    case 0: return fabsf(x);
    case 1: return ceilf(x);
    case 2: return floorf(x);
    case 3: return rintf(x);
    case 4: return sqrtf(x);
    case 5: return 1.0f / sqrtf(x + a);
    case 6: return 1.0f / (x + a);
    case 7: return expf(x);
    case 8: return exp2f(x);
    case 9: return logf(x + a);
    case 10: return sinf(x);
    case 11: return cosf(x);
    case 12: return tanf(x);
    case 13: return asinf(x);
    case 14: return acosf(x);
    case 15: return atanf(x);
    case 16: return sinhf(x);
    case 17: return coshf(x);
    case 18: return tanhf(x);
    case 19: return asinhf(x);
    case 20: return acoshf(x);
    case 21: return atanhf(x);
    case 22: return erff(x);
    case 23: return x > 0 ? x : 0;
    case 24: return fminf(fmaxf(x, 0), 6);
    case 25: return x > 0 ? x : a * x;
    case 26: return sigmf(x);
    case 27: return x >= 0 ? fminf(b, x) : fminf(b, a * x);
    case 28: return a * tanhf(b * x);
    case 29: return fmaxf(0, fminf(1, a * x + b));
    case 30: return x / (1 + fabsf(x));
    case 31: return x > 0 ? x : a * expm1f(x);
    case 32: return x > a ? x : 0;
    case 33: return x * fminf(fmaxf(x + 3, 0), 6) / 6;
    case 34: return x * sigmf(x);
    case 35: return 0.5f * x * (1 + erff(x / sqrtf(2)));
    case 36: return 0.5f * x * (1 + tanhf(0.7978845608f * (x + 0.044715f * x * x * x)));
    case 37: return x * sigmf(1.702f * x);
    case 38: return a * log1pf(expf(x));
    case 39: return fminf(fmaxf(x, a), b);
    case 40: return fmaxf(x, a);
    case 41: return x == 0 ? 1.0f : 0.0f;
    case 42: return -x;
    default: return x;
    }
}
static float binary(int fn, float x, float y) {
    switch (fn) {
    case 0: return x + y;
    case 1: return x - y;
    case 2: return x * y;
    case 3: return x / y;
    case 4: return fmodf(x, y);
    case 5: return powf(x, y);
    case 6: return fmaxf(x, y);
    case 7: return fminf(x, y);
    case 8: return x == y;
    case 9: return x != y;
    case 10: return x < y;
    case 11: return x <= y;
    case 12: return x > y;
    case 13: return x >= y;
    case 14: return (x != 0) && (y != 0);
    case 15: return (x != 0) || (y != 0);
    case 16: return (x != 0) != (y != 0);
    default: return 0;
    }
}
static float act(int fn, float x) {   /* BNNSGraph.Builder.Activation */
    switch (fn) {
    case 0: return fmaxf(0, fminf(1, 0.2f * x + 0.5f));
    case 1: return x;
    case 2: return x > 0 ? x : 0;
    case 3: return tanhf(x);
    case 4: return sigmf(x);
    default: return tanhf(x);
    }
}
static float cast_to(BNNSDataType t, float v) {
    unsigned cls = t & 0xff0000u;
    if (t == BNNSDataTypeBoolean) return v != 0;
    if (cls == BNNSDataTypeIntBit || cls == BNNSDataTypeUIntBit) {
        float r = truncf(v);
        if (cls == BNNSDataTypeUIntBit && r < 0) r = 0;
        return r;
    }
    if (t == BNNSDataTypeFloat16) { BNNSNDArrayDescriptor d = {0}; uint16_t h; d.data_type = t; bn_write(&d, &h, 0, v); return bn_read(&d, &h, 0); }
    return v;
}

/* along one axis: (outer, len, inner) */
static void axis_split(const gshape *s, int ax, long long *outer, long long *len, long long *inner) {
    *outer = 1; *inner = 1; *len = s->d[ax];
    for (int k = 0; k < ax; k++) *outer *= s->d[k];
    for (int k = ax + 1; k < s->rank; k++) *inner *= s->d[k];
}

/* ---- matrix product ---- */
static void matmul(const float *A, const gshape *sa, int ta, const float *B, const gshape *sb, int tb, const float *bias,
                   const gshape *sbias, float *C, const gshape *sc) {
    gshape a = *sa, b = *sb, c = *sc;
    if (a.rank == 1) { a.rank = 2; a.d[1] = a.d[0]; a.d[0] = 1; }
    if (b.rank == 1) { b.rank = 2; b.d[1] = 1; }
    long long M = ta ? a.d[a.rank - 1] : a.d[a.rank - 2], K = ta ? a.d[a.rank - 2] : a.d[a.rank - 1];
    long long N = tb ? b.d[b.rank - 2] : b.d[b.rank - 1];
    if (sa->rank == 1) { c.rank++; c.d[c.rank - 1] = c.d[c.rank - 2]; c.d[c.rank - 2] = 1; }
    gshape ba = a, bb = b, bc = c; ba.rank -= 2; bb.rank -= 2; bc.rank -= 2;
    long long nb = gcount(&bc), pos[GMAXR];
    for (long long bi = 0; bi < nb; bi++) {
        gunravel(&bc, bi, pos);
        const float *ap = A + gbidx(&ba, &bc, pos) * a.d[a.rank - 1] * a.d[a.rank - 2];
        const float *bp = B + gbidx(&bb, &bc, pos) * b.d[b.rank - 1] * b.d[b.rank - 2];
        float *cp = C + bi * M * N;
        for (long long i = 0; i < M; i++)
            for (long long j = 0; j < N; j++) {
                double s = 0;
                for (long long k = 0; k < K; k++) {
                    float av = ta ? ap[k * a.d[a.rank - 1] + i] : ap[i * a.d[a.rank - 1] + k];
                    float bv = tb ? bp[j * b.d[b.rank - 1] + k] : bp[k * b.d[b.rank - 1] + j];
                    s += (double)av * bv;
                }
                if (bias) s += bias[sbias->rank ? (gcount(sbias) == N ? j : 0) : 0];
                cp[i * N + j] = (float)s;
            }
    }
}

/* ---- convolution (N-D, groups, dilation), and its transpose ---- */
static void conv(const gnode *n, const float *x, const gshape *sx, const float *w, const gshape *sw, const float *bias, float *y,
                 const gshape *sy) {
    int tr = (int)n->ia[0], ns = (int)n->ia[3];
    long long groups = n->ia[1] > 0 ? n->ia[1] : 1;
    const long long *st = n->ia + 4, *dl = n->ia + 4 + ns, *cp = n->ia + 4 + 2 * ns;
    long long pb[3] = {0}, pe[3] = {0};
    for (int k = 0; k < ns; k++) pads_for(n->ia[2], sx->d[2 + k], sw->d[2 + k], st[k], dl[k], cp + 2 * k, tr, &pb[k], &pe[k]);
    long long N = sx->d[0], Cin = sx->d[1], Cout = sy->d[1];
    long long ksz = 1, isz = 1, osz = 1;
    for (int k = 0; k < ns; k++) { ksz *= sw->d[2 + k]; isz *= sx->d[2 + k]; osz *= sy->d[2 + k]; }
    gshape ks = { ns, {0} }, is = { ns, {0} }, os = { ns, {0} };
    for (int k = 0; k < ns; k++) { ks.d[k] = sw->d[2 + k]; is.d[k] = sx->d[2 + k]; os.d[k] = sy->d[2 + k]; }
    memset(y, 0, (size_t)gcount(sy) * sizeof(float));
    long long cig = Cin / groups, cog = Cout / groups;
    long long kp[GMAXR], ip[GMAXR], opos[GMAXR];
    for (long long b = 0; b < N; b++)
        for (long long g = 0; g < groups; g++)
            for (long long oc = 0; oc < cog; oc++)
                for (long long ic = 0; ic < cig; ic++) {
                    long long cin = g * cig + ic, cout = g * cog + oc;
                    /* weights: conv [Cout, Cin/g, k...]; transposed [Cin, Cout/g, k...] */
                    const float *wk = tr ? w + (cin * cog + oc) * ksz : w + (cout * cig + ic) * ksz;
                    const float *xi = x + (b * Cin + cin) * isz;
                    float *yo = y + (b * Cout + cout) * osz;
                    for (long long kk = 0; kk < ksz; kk++) {
                        float wv = wk[kk];
                        if (wv == 0) continue;
                        gunravel(&ks, kk, kp);
                        if (!tr) {
                            for (long long o = 0; o < osz; o++) {
                                gunravel(&os, o, opos);
                                long long off = 0; int in = 1;
                                for (int d = 0; d < ns && in; d++) {
                                    long long p = opos[d] * st[d] + kp[d] * dl[d] - pb[d];
                                    if (p < 0 || p >= is.d[d]) in = 0;
                                    off = off * is.d[d] + p;
                                }
                                if (in) yo[o] += wv * xi[off];
                            }
                        } else {
                            for (long long i = 0; i < isz; i++) {
                                gunravel(&is, i, ip);
                                long long off = 0; int in = 1;
                                for (int d = 0; d < ns && in; d++) {
                                    long long p = ip[d] * st[d] + kp[d] * dl[d] - pb[d];
                                    if (p < 0 || p >= os.d[d]) in = 0;
                                    off = off * os.d[d] + p;
                                }
                                if (in) yo[off] += wv * xi[i];
                            }
                        }
                    }
                }
    if (bias)
        for (long long b = 0; b < N; b++) for (long long c = 0; c < Cout; c++) for (long long o = 0; o < osz; o++) y[(b * Cout + c) * osz + o] += bias[c];
}

static void pool(const gnode *n, const float *x, const gshape *sx, float *y, const gshape *sy) {
    int ns = (int)n->ia[3], fn = (int)n->ia[0];
    const long long *kr = n->ia + 4, *st = n->ia + 4 + ns, *cp = n->ia + 4 + 2 * ns;
    long long pb[3] = {0}, pe[3] = {0};
    for (int k = 0; k < ns; k++) pads_for(n->ia[2], sx->d[sx->rank - ns + k], kr[k], st[k], 1, cp + 2 * k, 0, &pb[k], &pe[k]);
    long long outer = 1, isz = 1, osz = 1, ksz = 1;
    for (int k = 0; k < sx->rank - ns; k++) outer *= sx->d[k];
    gshape is = { ns, {0} }, os = { ns, {0} }, ks = { ns, {0} };
    for (int k = 0; k < ns; k++) {
        is.d[k] = sx->d[sx->rank - ns + k]; os.d[k] = sy->d[sy->rank - ns + k]; ks.d[k] = kr[k];
        isz *= is.d[k]; osz *= os.d[k]; ksz *= kr[k];
    }
    long long op[GMAXR], kp[GMAXR];
    for (long long b = 0; b < outer; b++)
        for (long long o = 0; o < osz; o++) {
            gunravel(&os, o, op);
            double s = 0; float m = -INFINITY; long long cnt = 0, total = 0;
            for (long long kk = 0; kk < ksz; kk++) {
                gunravel(&ks, kk, kp);
                long long off = 0; int in = 1, padded = 1;
                for (int d = 0; d < ns; d++) {
                    long long p = op[d] * st[d] + kp[d] - pb[d];
                    if (p >= is.d[d] + pe[d]) padded = 0;   /* past the padding (ceil mode): not counted */
                    if (p < 0 || p >= is.d[d]) in = 0;
                    off = off * is.d[d] + (p < 0 ? 0 : p);
                }
                if (padded) total++;
                if (!in) continue;
                float v = x[b * isz + off];
                cnt++;
                if (v > m) m = v;
                s += fn == 3 ? (double)v * v : v;
            }
            float r;
            switch (fn) {
            case 0: r = cnt ? m : 0; break;
            case 1: r = cnt ? (float)(s / cnt) : 0; break;
            case 2: r = total ? (float)(s / total) : 0; break;
            default: r = (float)sqrt(s); break;
            }
            y[b * osz + o] = r;
        }
}

/* ---- normalizations ---- */
static void normalize_groups(float *y, const float *x, long long outer, long long len, long long inner, float eps) {
    for (long long o = 0; o < outer; o++)
        for (long long i = 0; i < inner; i++) {
            double s = 0, s2 = 0;
            for (long long k = 0; k < len; k++) { double v = x[(o * len + k) * inner + i]; s += v; s2 += v * v; }
            double mean = s / len, var = s2 / len - mean * mean;
            float is = (float)(1 / sqrt((var > 0 ? var : 0) + eps));
            for (long long k = 0; k < len; k++) { long long q = (o * len + k) * inner + i; y[q] = (x[q] - (float)mean) * is; }
        }
}
static int norm(bn_graph *g, const gnode *n, float **in, const float *x, const gshape *sx, float *y) {
    int kind = (int)n->ia[0];
    float eps = n->f[0];
    long long count = gcount(sx);
    if (kind == 0) {   /* batch: (x - mean) / sqrt(var + eps) * w + b, per channel (dimension 1) */
        long long C = sx->rank > 1 ? sx->d[1] : sx->d[0], inner = 1, outer = sx->rank > 1 ? sx->d[0] : 1;
        for (int k = 2; k < sx->rank; k++) inner *= sx->d[k];
        const float *mean = in[1], *var = in[2], *w = n->nin > 3 ? in[3] : NULL, *b = n->nin > 4 ? in[4] : NULL;
        long long cm = gcount(&g->nodes[n->in[1]].shape), cv = gcount(&g->nodes[n->in[2]].shape);
        for (long long o = 0; o < outer; o++)
            for (long long c = 0; c < C; c++)
                for (long long i = 0; i < inner; i++) {
                    long long q = (o * C + c) * inner + i;
                    float m = mean[cm == 1 ? 0 : c], v = var[cv == 1 ? 0 : c];
                    float r = (x[q] - m) / sqrtf(v + eps);
                    if (w) r *= w[gcount(&g->nodes[n->in[3]].shape) == 1 ? 0 : c];
                    if (b) r += b[gcount(&g->nodes[n->in[4]].shape) == 1 ? 0 : c];
                    y[q] = r;
                }
        return 0;
    }
    long long outer, len, inner;
    if (kind == 1) {             /* channel norm: across dimension 1 */
        if (sx->rank < 2) return -1;
        axis_split(sx, 1, &outer, &len, &inner);
    } else if (kind == 2) {      /* instance norm: over the spatial dimensions of each (n, c) */
        outer = 1; inner = 1; len = 1;
        for (int k = 0; k < sx->rank && k < 2; k++) outer *= sx->d[k];
        for (int k = 2; k < sx->rank; k++) len *= sx->d[k];
    } else if (kind == 3) {      /* layer norm: over the given axes (contiguous trailing axes) */
        int cnt = (int)n->ia[1], first = sx->rank;
        for (int k = 0; k < cnt; k++) { int ax = gaxis(n->ia[2 + k], sx->rank); if (ax < first) first = ax; }
        if (!cnt) first = sx->rank - 1;
        outer = 1; len = 1; inner = 1;
        for (int k = 0; k < first; k++) outer *= sx->d[k];
        for (int k = first; k < sx->rank; k++) len *= sx->d[k];
    } else {                     /* l2 / rms: over the last dimension */
        outer = count / sx->d[sx->rank - 1]; len = sx->d[sx->rank - 1]; inner = 1;
    }
    if (kind == 4 || kind == 5) {
        for (long long o = 0; o < outer; o++) {
            double s = 0;
            for (long long k = 0; k < len; k++) s += (double)x[o * len + k] * x[o * len + k];
            float d = kind == 4 ? (float)sqrt(s + eps) : (float)sqrt(s / len + eps);
            for (long long k = 0; k < len; k++) y[o * len + k] = x[o * len + k] / d * (kind == 5 && n->nin > 1 ? in[1][k % gcount(&g->nodes[n->in[1]].shape)] : 1);
        }
        return 0;
    }
    normalize_groups(y, x, outer, len, inner, eps);
    if (n->nin > 1) {   /* weight and bias: per channel (channel / instance norm), or shaped like the normalized axes (layer norm) */
        const float *w = in[1], *b = n->nin > 2 ? in[2] : NULL;
        long long cw = gcount(&g->nodes[n->in[1]].shape), cb = b ? gcount(&g->nodes[n->in[2]].shape) : 0;
        long long C = sx->rank > 1 ? sx->d[1] : 1, sp = 1;
        for (int k = 2; k < sx->rank; k++) sp *= sx->d[k];
        for (long long q = 0; q < count; q++) {
            long long idx = kind == 3 ? q % len : (q / sp) % C;
            y[q] = y[q] * w[cw == 1 ? 0 : idx % cw] + (b ? b[cb == 1 ? 0 : idx % cb] : 0);
        }
    }
    return 0;
}

/* ---- recurrent layers (CoreML conventions: x [s, b, I], weights [G·H, I] / [G·H, H], bias [G·H]) ---- */
static void mv_add(float *out, const float *W, const float *v, long long rows, long long cols, long long row0) {
    for (long long r = 0; r < rows; r++) {
        double s = 0;
        for (long long c = 0; c < cols; c++) s += (double)W[(row0 + r) * cols + c] * v[c];
        out[r] += (float)s;
    }
}
static void recurrent(const gnode *n, float **in, bn_graph *g, float *out, float *hn, float *cn) {
    const gshape *sx = &g->nodes[n->in[0]].shape;
    long long S = sx->d[0], B = sx->d[1], I = sx->d[2];
    int lstm = n->op == GOP_LSTM, gru = n->op == GOP_GRU, bi = lstm && n->ia[5];
    long long H = g->nodes[n->in[1]].shape.d[1] / (bi ? 2 : 1), HD = H * (bi ? 2 : 1);
    int seq = (int)(n->op == GOP_RNN ? n->ia[2] : n->ia[4]);
    int fact = (int)n->ia[1], rec = n->op == GOP_RNN ? 0 : (int)n->ia[2], cact = lstm ? (int)n->ia[3] : 0;
    int G = lstm ? 4 : gru ? 3 : 1;
    float *xi = malloc((size_t)(G * H) * sizeof(float)), *hh = malloc((size_t)(G * H) * sizeof(float));
    float *h = malloc((size_t)H * sizeof(float)), *c = malloc((size_t)H * sizeof(float)), *rh = malloc((size_t)H * sizeof(float));
    for (int dir = 0; dir < (bi ? 2 : 1); dir++) {
        int reverse = bi ? dir : (int)n->ia[0];
        int wi = lstm ? 3 + 3 * dir : 2;
        const float *wih = in[wi], *whh = in[wi + 1], *bias = in[wi + 2];
        const float *ibias = gru && n->nin > 5 ? in[5] : NULL;
        for (long long b = 0; b < B; b++) {
            for (long long k = 0; k < H; k++) {
                h[k] = in[1][b * HD + dir * H + k];
                c[k] = lstm ? in[2][b * HD + dir * H + k] : 0;
            }
            for (long long t = 0; t < S; t++) {
                long long tt = reverse ? S - 1 - t : t;
                const float *xt = in[0] + (tt * B + b) * I;
                /* input projection (+ the bias; GRU: + the input bias) and hidden projection (GRU: + the bias) */
                for (long long q = 0; q < G * H; q++) {
                    xi[q] = gru ? (ibias ? ibias[q] : 0) : (bias ? bias[q] : 0);
                    hh[q] = gru && bias ? bias[q] : 0;
                }
                mv_add(xi, wih, xt, G * H, I, 0);
                mv_add(hh, whh, h, G * H, H, 0);
                if (n->op == GOP_RNN) {
                    for (long long k = 0; k < H; k++) h[k] = act(fact, xi[k] + hh[k]);
                } else if (gru) {   /* gates z (update), r (reset), o (candidate) */
                    int after = (int)n->ia[3];
                    float *o = malloc((size_t)H * sizeof(float));
                    if (after) for (long long k = 0; k < H; k++) o[k] = act(fact, xi[2 * H + k] + act(rec, xi[H + k] + hh[H + k]) * hh[2 * H + k]);
                    else {
                        for (long long k = 0; k < H; k++) { rh[k] = act(rec, xi[H + k] + hh[H + k]) * h[k]; o[k] = xi[2 * H + k] + (bias ? bias[2 * H + k] : 0); }
                        mv_add(o, whh, rh, H, H, 2 * H);
                        for (long long k = 0; k < H; k++) o[k] = act(fact, o[k]);
                    }
                    for (long long k = 0; k < H; k++) {
                        float z = act(rec, xi[k] + hh[k]);
                        h[k] = (1 - z) * o[k] + z * h[k];
                    }
                    free(o);
                } else {            /* LSTM gates i, f, o, g */
                    for (long long k = 0; k < H; k++) {
                        float ig = act(rec, xi[k] + hh[k]), fg = act(rec, xi[H + k] + hh[H + k]);
                        float og = act(rec, xi[2 * H + k] + hh[2 * H + k]), cg = act(cact, xi[3 * H + k] + hh[3 * H + k]);
                        c[k] = fg * c[k] + ig * cg;
                        h[k] = og * act(fact, c[k]);
                    }
                }
                if (seq) for (long long k = 0; k < H; k++) out[(tt * B + b) * HD + dir * H + k] = h[k];
            }
            for (long long k = 0; k < H; k++) {
                if (!seq) out[b * HD + dir * H + k] = h[k];
                hn[b * HD + dir * H + k] = h[k];
                if (cn) cn[b * HD + dir * H + k] = c[k];
            }
        }
    }
    free(xi); free(hh); free(h); free(c); free(rh);
}

/* ---- scatter helpers ---- */
static float scatter_op(int mode, float old, float v) {
    switch (mode) {
    case 1: return old + v;
    case 2: return old - v;
    case 3: return old * v;
    case 4: return old / v;
    case 5: return fmaxf(old, v);
    case 6: return fminf(old, v);
    default: return v;
    }
}

/* ---- running a graph ---- */
static int run_node(bn_graph *g, gnode *n, float **bufs, float **bufs2, float **bufs3) {
    long long count = gcount(&n->shape);
    float *in[GMAXIN];
    for (int k = 0; k < n->nin; k++) in[k] = bufs[n->in[k]];
    const gshape *sa = n->nin > 0 ? &g->nodes[n->in[0]].shape : NULL, *sb = n->nin > 1 ? &g->nodes[n->in[1]].shape : NULL;
    long long pos[GMAXR];
    if (n->op == GOP_PICK) {
        int idx = n->in[0];
        float *src = n->ia[0] == 0 ? bufs[idx] : n->ia[0] == 1 ? bufs2[idx] : bufs3[idx];
        bufs[n - g->nodes] = malloc((size_t)(count ? count : 1) * sizeof(float));
        if (src) memcpy(bufs[n - g->nodes], src, (size_t)count * sizeof(float));
        return 0;
    }
    float *y = malloc((size_t)(count ? count : 1) * sizeof(float));
    if (!y) return -1;
    bufs[n - g->nodes] = y;
    switch (n->op) {
    case GOP_UNARY: for (long long i = 0; i < count; i++) y[i] = unary((int)n->ia[0], in[0][i], n->f[0], n->f[1]); break;
    case GOP_CAST: for (long long i = 0; i < count; i++) y[i] = cast_to(n->dtype, in[0][i]); break;
    case GOP_BINARY:
        for (long long i = 0; i < count; i++) {
            gunravel(&n->shape, i, pos);
            y[i] = binary((int)n->ia[0], in[0][gbidx(sa, &n->shape, pos)], in[1][gbidx(sb, &n->shape, pos)]);
        }
        if ((n->dtype & 0xff0000u) == BNNSDataTypeIntBit && n->ia[0] == 3) for (long long i = 0; i < count; i++) y[i] = truncf(y[i]);
        break;
    case GOP_SELECT: case GOP_FMA: {
        const gshape *sc = &g->nodes[n->in[2]].shape;
        for (long long i = 0; i < count; i++) {
            gunravel(&n->shape, i, pos);
            float a = in[0][gbidx(sa, &n->shape, pos)], b = in[1][gbidx(sb, &n->shape, pos)], c = in[2][gbidx(sc, &n->shape, pos)];
            y[i] = n->op == GOP_SELECT ? (a != 0 ? b : c) : a * b + c;
        }
        break;
    }
    case GOP_REDUCE: {
        int fn = (int)n->ia[0], cnt = (int)n->ia[2], red[GMAXR] = {0};
        for (int k = 0; k < cnt; k++) red[gaxis(n->ia[3 + k], sa->rank)] = 1;
        if (!cnt) for (int k = 0; k < sa->rank; k++) red[k] = 1;
        gshape keep = *sa; long long ks[GMAXR];
        for (int k = 0; k < sa->rank; k++) if (red[k]) keep.d[k] = 1;
        gstrides(&keep, ks);
        double *acc = calloc((size_t)(count ? count : 1), sizeof(double)), *mx = malloc((size_t)(count ? count : 1) * sizeof(double));
        long long *cnts = calloc((size_t)(count ? count : 1), sizeof(long long));
        for (long long i = 0; i < count; i++) { mx[i] = fn == 4 ? INFINITY : -INFINITY; acc[i] = fn == 2 ? 1 : 0; }
        long long total = gcount(sa);
        for (int pass = 0; pass < (fn == 9 ? 2 : 1); pass++)
            for (long long i = 0; i < total; i++) {
                gunravel(sa, i, pos);
                long long o = 0;
                for (int k = 0; k < sa->rank; k++) o += (red[k] ? 0 : pos[k]) * ks[k];
                double v = in[0][i];
                if (fn == 9 && pass == 0) { if (v > mx[o]) mx[o] = v; continue; }
                switch (fn) {
                case 0: case 3: case 8: acc[o] += v; break;
                case 1: case 7: acc[o] += v * v; break;
                case 2: acc[o] *= v; break;
                case 4: if (v < mx[o]) mx[o] = v; break;
                case 5: if (v > mx[o]) mx[o] = v; break;
                case 6: acc[o] += fabs(v); break;
                case 9: acc[o] += exp(v - mx[o]); break;
                }
                cnts[o]++;
            }
        for (long long i = 0; i < count; i++) {
            double r = acc[i];
            switch (fn) {
            case 3: r = cnts[i] ? acc[i] / cnts[i] : 0; break;
            case 4: case 5: r = mx[i]; break;
            case 7: r = sqrt(acc[i]); break;
            case 8: r = log(acc[i]); break;
            case 9: r = mx[i] + log(acc[i]); break;
            }
            y[i] = (float)r;
        }
        free(acc); free(mx); free(cnts);
        break;
    }
    case GOP_ARGREDUCE: {
        int ax = gaxis(n->ia[1], sa->rank);
        long long outer, len, inner;
        axis_split(sa, ax, &outer, &len, &inner);
        for (long long o = 0; o < outer; o++)
            for (long long i = 0; i < inner; i++) {
                long long best = 0;
                for (long long k = 1; k < len; k++) {
                    float v = in[0][(o * len + k) * inner + i], bv = in[0][(o * len + best) * inner + i];
                    if (n->ia[0] ? v > bv : v < bv) best = k;
                }
                y[o * inner + i] = (float)best;
            }
        break;
    }
    case GOP_ARGSORT: case GOP_TOPK: {
        int topk = n->op == GOP_TOPK, ax = gaxis(topk ? n->ia[1] : n->ia[0], sa->rank);
        int desc = topk ? (int)n->ia[2] : (int)n->ia[1];
        long long outer, len, inner, K = topk ? n->ia[0] : 0;
        axis_split(sa, ax, &outer, &len, &inner);
        if (!topk) K = len;
        long long *idx = malloc((size_t)(len ? len : 1) * sizeof(long long));
        float *vals = topk ? y : NULL, *ids = topk ? malloc((size_t)(count ? count : 1) * sizeof(float)) : y;
        for (long long o = 0; o < outer; o++)
            for (long long i = 0; i < inner; i++) {
                const float *src = in[0] + o * len * inner + i;
                for (long long k = 0; k < len; k++) idx[k] = k;
                for (long long a = 1; a < len; a++) {   /* stable insertion sort */
                    long long t = idx[a], b = a;
                    while (b > 0) {
                        float pv = src[idx[b - 1] * inner], tv = src[t * inner];
                        if (desc ? pv < tv : pv > tv) { idx[b] = idx[b - 1]; b--; } else break;
                    }
                    idx[b] = t;
                }
                for (long long k = 0; k < K; k++) {
                    long long q = (o * K + k) * inner + i;
                    ids[q] = (float)idx[k];
                    if (vals) vals[q] = src[idx[k] * inner];
                }
            }
        if (topk) bufs2[n - g->nodes] = ids;
        free(idx);
        break;
    }
    case GOP_CUMSUM: {
        long long outer, len, inner;
        axis_split(sa, gaxis(n->ia[0], sa->rank), &outer, &len, &inner);
        for (long long o = 0; o < outer; o++) for (long long i = 0; i < inner; i++) {
            double s = 0;
            for (long long k = 0; k < len; k++) { long long q = (o * len + k) * inner + i; s += in[0][q]; y[q] = (float)s; }
        }
        break;
    }
    case GOP_SOFTMAX: {
        long long outer, len, inner;
        axis_split(sa, gaxis(n->ia[0], sa->rank), &outer, &len, &inner);
        for (long long o = 0; o < outer; o++) for (long long i = 0; i < inner; i++) {
            float m = -INFINITY; double s = 0;
            for (long long k = 0; k < len; k++) { float v = in[0][(o * len + k) * inner + i]; if (v > m) m = v; }
            for (long long k = 0; k < len; k++) s += exp((double)in[0][(o * len + k) * inner + i] - m);
            for (long long k = 0; k < len; k++) {
                long long q = (o * len + k) * inner + i; double v = in[0][q] - m;
                y[q] = n->ia[1] ? (float)(v - log(s)) : (float)(exp(v) / s);
            }
        }
        break;
    }
    case GOP_MATMUL: case GOP_LINEAR:
        matmul(in[0], sa, n->op == GOP_MATMUL && n->ia[0], in[1], sb, n->op == GOP_LINEAR ? 1 : (int)n->ia[1],
               n->nin > 2 ? in[2] : NULL, n->nin > 2 ? &g->nodes[n->in[2]].shape : NULL, y, &n->shape);
        break;
    case GOP_CONV: conv(n, in[0], sa, in[1], sb, n->nin > 2 ? in[2] : NULL, y, &n->shape); break;
    case GOP_POOL: pool(n, in[0], sa, y, &n->shape); break;
    case GOP_NORM: if (norm(g, n, in, in[0], sa, y)) return -1; break;
    case GOP_PRELU: {
        long long C = sa->rank > 1 ? sa->d[1] : 1, inner = 1, ca = gcount(sb);
        for (int k = 2; k < sa->rank; k++) inner *= sa->d[k];
        for (long long i = 0; i < count; i++) {
            float a = in[1][ca == 1 ? 0 : ((i / inner) % C) % ca], v = in[0][i];
            y[i] = v > 0 ? v : a * v;
        }
        break;
    }
    case GOP_RESHAPE: case GOP_RESHAPE_DYN: memcpy(y, in[0], (size_t)count * sizeof(float)); break;
    case GOP_TRANSPOSE: {
        long long st[GMAXR];
        gstrides(sa, st);
        for (long long i = 0; i < count; i++) {
            gunravel(&n->shape, i, pos);
            long long off = 0;
            for (int k = 0; k < sa->rank; k++) off += pos[k] * st[gaxis(n->ia[k], sa->rank)];
            y[i] = in[0][off];
        }
        break;
    }
    case GOP_SHAPEOF: for (int k = 0; k < sa->rank; k++) y[k] = (float)sa->d[k]; break;
    case GOP_SLICE: case GOP_SLICE_SET: {
        /* the slice's geometry over the source */
        int dims = n->nia / 4;
        long long start[GMAXR], step[GMAXR], len[GMAXR], st[GMAXR];
        gshape sl = { sa->rank, {0} };
        for (int k = 0; k < sa->rank; k++) {
            long long s0 = 0, en = sa->d[k], sp = 1, sq = 0;
            if (k < dims) {
                s0 = n->ia[4 * k]; en = n->ia[4 * k + 1]; sp = n->ia[4 * k + 2]; sq = n->ia[4 * k + 3];
                if (s0 < 0) s0 += sa->d[k];
                if (en < 0) en += sa->d[k];
                if (en > sa->d[k]) en = sa->d[k];
                if (sq) en = s0 + 1;
            }
            start[k] = s0; step[k] = sp; len[k] = en > s0 ? (en - s0 + sp - 1) / sp : 0; sl.d[k] = len[k];
        }
        gstrides(sa, st);
        long long ns = gcount(&sl);
        if (n->op == GOP_SLICE_SET) memcpy(y, in[0], (size_t)count * sizeof(float));
        const gshape *sv = n->op == GOP_SLICE_SET ? sb : NULL;
        gshape svf = sl;   /* the value broadcasts against the slice with its squeezed dimensions removed */
        if (sv) { svf.rank = 0; for (int k = 0; k < sa->rank; k++) if (!(k < dims && n->ia[4 * k + 3])) svf.d[svf.rank++] = len[k]; }
        long long p2[GMAXR];
        for (long long i = 0; i < ns; i++) {
            gunravel(&sl, i, pos);
            long long off = 0;
            for (int k = 0; k < sa->rank; k++) off += (start[k] + pos[k] * step[k]) * st[k];
            if (n->op == GOP_SLICE) y[i] = in[0][off];
            else {
                int r = 0;
                for (int k = 0; k < sa->rank; k++) if (!(k < dims && n->ia[4 * k + 3])) p2[r++] = pos[k];
                y[off] = in[1][gbidx(sv, &svf, p2)];
            }
        }
        break;
    }
    case GOP_PAD: {
        int mode = (int)n->ia[0], cnt = (int)n->ia[1];
        long long st[GMAXR];
        gstrides(sa, st);
        for (long long i = 0; i < count; i++) {
            gunravel(&n->shape, i, pos);
            long long off = 0; int out = 0;
            for (int k = 0; k < sa->rank; k++) {
                int pk = k - (sa->rank - cnt);
                long long p = pos[k] - (pk >= 0 ? n->ia[2 + 2 * pk] : 0), L = sa->d[k];
                if (p < 0 || p >= L) {
                    if (mode == 0) { out = 1; break; }
                    if (mode == 1) { long long per = 2 * (L - 1); if (per <= 0) p = 0; else { p = ((p % per) + per) % per; if (p >= L) p = per - p; } }
                    else p = p < 0 ? 0 : L - 1;
                }
                off += p * st[k];
            }
            y[i] = out ? n->f[0] : in[0][off];
        }
        break;
    }
    case GOP_CONCAT: {
        int ax = gaxis(n->ia[0], sa->rank);
        long long outer, len, inner, at = 0;
        axis_split(&n->shape, ax, &outer, &len, &inner);
        for (int t = 0; t < n->nin; t++) {
            const gshape *s = &g->nodes[n->in[t]].shape;
            long long l = s->d[ax];
            for (long long o = 0; o < outer; o++)
                memcpy(y + (o * len + at) * inner, in[t] + o * l * inner, (size_t)(l * inner) * sizeof(float));
            at += l;
        }
        break;
    }
    case GOP_GATHER: {
        int ax = gaxis(n->ia[0], sa->rank), bd = (int)n->ia[1];
        long long outer, len, inner, ni = 1, nb = 1;
        axis_split(sa, ax, &outer, &len, &inner);
        for (int k = 0; k < bd; k++) nb *= sb->d[k];
        for (int k = bd; k < sb->rank; k++) ni *= sb->d[k];
        long long per_batch_outer = outer / (nb ? nb : 1);
        for (long long o = 0; o < outer; o++) {
            long long b = bd ? o / per_batch_outer : 0;
            for (long long q = 0; q < ni; q++) {
                long long k = (long long)in[1][b * ni + q];
                if (k < 0) k += len;
                if (k < 0 || k >= len) return -1;
                memcpy(y + (o * ni + q) * inner, in[0] + (o * len + k) * inner, (size_t)inner * sizeof(float));
            }
        }
        break;
    }
    case GOP_GATHER_AXIS: case GOP_SCATTER_AXIS: {
        int scatter = n->op == GOP_SCATTER_AXIS;
        const gshape *si = scatter ? &g->nodes[n->in[2]].shape : sb;
        const float *idx = scatter ? in[2] : in[1];
        int ax = gaxis(n->ia[0], sa->rank);
        long long st[GMAXR];
        gstrides(sa, st);
        if (scatter) memcpy(y, in[0], (size_t)count * sizeof(float));
        long long ni = gcount(si);
        for (long long i = 0; i < ni; i++) {
            gunravel(si, i, pos);
            long long k = (long long)idx[i];
            if (k < 0) k += sa->d[ax];
            if (k < 0 || k >= sa->d[ax]) return -1;
            long long off = 0;
            for (int d = 0; d < sa->rank; d++) off += (d == ax ? k : pos[d]) * st[d];
            if (scatter) y[off] = scatter_op((int)n->ia[1], y[off], in[1][i]);
            else y[i] = in[0][off];
        }
        break;
    }
    case GOP_GATHER_ND: case GOP_SCATTER_ND: {
        int scatter = n->op == GOP_SCATTER_ND;
        const gshape *si = scatter ? &g->nodes[n->in[2]].shape : sb;
        const float *idx = scatter ? in[2] : in[1];
        int bd = scatter ? 0 : (int)n->ia[0];
        long long K = si->d[si->rank - 1], nl = gcount(si) / (K ? K : 1), st[GMAXR], slice = 1;
        gstrides(sa, st);
        for (int k = bd + (int)K; k < sa->rank; k++) slice *= sa->d[k];
        long long nb = 1; for (int k = 0; k < bd; k++) nb *= si->d[k];
        long long per = nl / (nb ? nb : 1);
        if (scatter) memcpy(y, in[0], (size_t)count * sizeof(float));
        for (long long q = 0; q < nl; q++) {
            long long b = bd ? q / per : 0, off = 0, bb = b;
            for (int k = bd - 1; k >= 0; k--) { off += (bb % sa->d[k]) * st[k]; bb /= sa->d[k]; }
            for (long long j = 0; j < K; j++) {
                long long v = (long long)idx[q * K + j], L = sa->d[bd + j];
                if (v < 0) v += L;
                if (v < 0 || v >= L) return -1;
                off += v * st[bd + j];
            }
            for (long long s = 0; s < slice; s++) {
                if (scatter) y[off + s] = scatter_op((int)n->ia[0], y[off + s], in[1][q * slice + s]);
                else y[q * slice + s] = in[0][off + s];
            }
        }
        break;
    }
    case GOP_SCATTER: {   /* updates shaped like indices along the axis */
        int ax = gaxis(n->ia[0], sa->rank);
        long long outer, len, inner, ni = gcount(&g->nodes[n->in[2]].shape);
        axis_split(sa, ax, &outer, &len, &inner);
        memcpy(y, in[0], (size_t)count * sizeof(float));
        for (long long o = 0; o < outer; o++)
            for (long long q = 0; q < ni; q++) {
                long long k = (long long)in[2][q];
                if (k < 0) k += len;
                if (k < 0 || k >= len) return -1;
                for (long long i = 0; i < inner; i++) {
                    long long dst = (o * len + k) * inner + i;
                    y[dst] = scatter_op((int)n->ia[1], y[dst], in[1][(o * ni + q) * inner + i]);
                }
            }
        break;
    }
    case GOP_RNN: case GOP_GRU: case GOP_LSTM: {
        long long c2 = gcount(&n->shape2);
        float *hn = malloc((size_t)(c2 ? c2 : 1) * sizeof(float)), *cn = n->op == GOP_LSTM ? malloc((size_t)(c2 ? c2 : 1) * sizeof(float)) : NULL;
        recurrent(n, in, g, y, hn, cn);
        bufs2[n - g->nodes] = hn; bufs3[n - g->nodes] = cn;
        break;
    }
    default: return -1;
    }
    return 0;
}

int graph_run(bn_graph *g, float **inputs, float **outputs, const gshape *dyn) {
    if (graph_infer(g, dyn)) return -1;
    float **bufs = calloc((size_t)g->n, sizeof(float *)), **b2 = calloc((size_t)g->n, sizeof(float *)), **b3 = calloc((size_t)g->n, sizeof(float *));
    if (!bufs || !b2 || !b3) { free(bufs); free(b2); free(b3); return -1; }
    int r = 0, arg = 0;
    for (int i = 0; i < g->n && !r; i++) {
        gnode *n = &g->nodes[i];
        long long c = gcount(&n->shape);
        if (n->op == GOP_ARG) {
            bufs[i] = malloc((size_t)(c ? c : 1) * sizeof(float));
            int k;
            for (k = 0; k < g->n_in && g->in_args[k] != i; k++) {}
            (void)arg;
            if (bufs[i] && k < g->n_in && inputs[k]) memcpy(bufs[i], inputs[k], (size_t)c * sizeof(float));
            else if (bufs[i]) memset(bufs[i], 0, (size_t)c * sizeof(float));
        } else if (n->op == GOP_CONST) {
            bufs[i] = malloc((size_t)(c ? c : 1) * sizeof(float));
            if (bufs[i]) memcpy(bufs[i], n->cdata, (size_t)c * sizeof(float));
        } else r = run_node(g, n, bufs, b2, b3);
        if (!r && !bufs[i]) r = -1;
    }
    for (int k = 0; k < g->n_out && !r; k++) {
        int id = g->outs[k];
        long long c = gcount(&g->nodes[id].shape);
        outputs[k] = malloc((size_t)(c ? c : 1) * sizeof(float));
        if (!outputs[k]) { r = -1; break; }
        memcpy(outputs[k], bufs[id], (size_t)c * sizeof(float));
    }
    for (int i = 0; i < g->n; i++) { free(bufs[i]); free(b2[i]); free(b3[i]); }
    free(bufs); free(b2); free(b3);
    return r;
}
