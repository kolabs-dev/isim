// isim Accelerate BNNS (issue #808): layer filters: convolution (and transposed), fully connected, pooling, activation,
// normalization, permute, dropout, padding, resize, embedding, Gram, reduction and quantization, their batch / backward
// applies, BNNSGetPointer, and the older image-stack / vector creators.
#include "bnns_layer.h"

#define FAIL(...) do { __VA_ARGS__; return -1; } while (0)

bn_layer *bn_layer_of(bn_filter *f) { return f ? f->state : NULL; }

static void layer_destroy(bn_filter *f) {
    bn_layer *L = f->state;
    if (!L) return;
    if (L->owns_w) bn_unkeep(&L->w);
    if (L->owns_b) bn_unkeep(&L->b);
    free(L->alpha);
    if (L->gamma.data) bn_unkeep(&L->gamma);
    if (L->beta.data) bn_unkeep(&L->beta);
    if (L->kind_owns_moving) { if (L->mmean.data) bn_unkeep(&L->mmean); if (L->mvar.data) bn_unkeep(&L->mvar); }
    free(L->cache_xhat); free(L->cache_istd); free(L->mask);
    for (size_t k = 0; k < L->nfused; k++) BNNSFilterDestroy(L->fused[k]);
    for (int k = 0; k < 3; k++) if (L->ain_owned[k]) bn_unkeep(&L->ain[k]);
}
bn_filter *bn_layer_new(int kind, const BNNSFilterParameters *fp) {
    bn_filter *f = bn_filter_new(kind, fp, sizeof(bn_layer));
    if (f) { f->destroy = layer_destroy; ((bn_layer *)f->state)->rng = 0x853c49e6748fea9bull; }
    return f;
}
int bn_layer_keep(bn_filter *f, BNNSNDArrayDescriptor *dst, const BNNSNDArrayDescriptor *src, int *owns) {
    *owns = 0;
    if (!src->data || (f->fp.flags & BNNSFlagsUseClientPtr)) { *dst = *src; return 0; }
    *owns = 1;
    return bn_keep(dst, src);
}
static size_t dcount(const BNNSNDArrayDescriptor *d) { bn_dims x; return bn_dims_of(d, &x) ? 0 : x.count; }
/* a descriptor for a dense float buffer from bn_load (dimension 0 fastest): same sizes, last-major, packed */
static void as_dense(BNNSNDArrayDescriptor *d, void *data) {
    d->data = data; d->data_type = BNNSDataTypeFloat32; d->data_scale = 1; d->data_bias = 0;
    memset(d->stride, 0, sizeof d->stride);
    if (bn_layout_first_major(d->layout)) d->layout = (BNNSDataLayout)((d->layout & ~0xffffu) | 0x8000);
}

/* ---- convolution ---- */
/* weights as a dense [oc][ic][ky][kx] array, from any of the convolution weight layouts */
static float *conv_weights(const BNNSNDArrayDescriptor *w, size_t *kw, size_t *kh, size_t *ic, size_t *oc) {
    bn_dims d;
    float *v = bn_load(w, NULL, &d);
    if (!v || d.rank != 4) { free(v); return NULL; }
    size_t W = d.n[0], H = d.n[1], A = d.n[2], B = d.n[3];
    int rot = w->layout == BNNSDataLayoutConvolutionWeightsOIHrWr || w->layout == BNNSDataLayoutConvolutionWeightsIOHrWr;
    int io = w->layout == BNNSDataLayoutConvolutionWeightsIOHrWr;
    size_t I = io ? B : A, O = io ? A : B;
    float *o = malloc(W * H * I * O * sizeof(float) + 1);
    if (!o) { free(v); return NULL; }
    for (size_t oo = 0; oo < O; oo++)
        for (size_t ii = 0; ii < I; ii++)
            for (size_t y = 0; y < H; y++)
                for (size_t x = 0; x < W; x++) {
                    size_t sx = rot ? W - 1 - x : x, sy = rot ? H - 1 - y : y;
                    size_t a = io ? oo : ii, b = io ? ii : oo;
                    o[((oo * I + ii) * H + y) * W + x] = v[((b * A + a) * H + sy) * W + sx];
                }
    free(v);
    *kw = W; *kh = H; *ic = I; *oc = O;
    return o;
}
static void conv_pads(const BNNSLayerParametersConvolution *c, size_t *pl, size_t *pt) {
    if (c->x_padding || c->y_padding || !(c->pad[0] | c->pad[1] | c->pad[2] | c->pad[3])) { *pl = c->x_padding; *pt = c->y_padding; }
    else { *pl = c->pad[0]; *pt = c->pad[2]; }
}
typedef struct { size_t W, H, C, oW, oH, oC, kw, kh, icg, groups, sx, sy, dx, dy, pl, pt; } conv_geo;
static int conv_geo_of(bn_layer *L, size_t kw, size_t kh, size_t icw, size_t ocw, conv_geo *g) {
    bn_dims di, dout;
    if (bn_dims_of(&L->i, &di) || bn_dims_of(&L->o, &dout)) return -1;
    const BNNSLayerParametersConvolution *c = &L->p.conv;
    g->W = di.n[0]; g->H = di.n[1]; g->C = di.rank > 2 ? di.n[2] : 1;
    g->oW = dout.n[0]; g->oH = dout.n[1]; g->oC = dout.rank > 2 ? dout.n[2] : 1;
    g->kw = kw; g->kh = kh; g->groups = c->groups > 1 ? c->groups : 1;
    g->sx = c->x_stride ? c->x_stride : 1; g->sy = c->y_stride ? c->y_stride : 1;
    g->dx = c->x_dilation_stride > 1 ? c->x_dilation_stride : 1; g->dy = c->y_dilation_stride > 1 ? c->y_dilation_stride : 1;
    conv_pads(c, &g->pl, &g->pt);
    g->icg = icw; (void)ocw;
    return 0;
}
/* y = conv(x) (+ bias); dense CHW buffers */
static void conv_core(const conv_geo *g, const float *w, const float *bias, const float *x, float *y) {
    size_t ocg = g->oC / g->groups;
    for (size_t oc = 0; oc < g->oC; oc++) {
        size_t grp = oc / ocg;
        for (size_t oy = 0; oy < g->oH; oy++)
            for (size_t ox = 0; ox < g->oW; ox++) {
                double s = bias ? bias[oc] : 0;
                for (size_t ic = 0; ic < g->icg; ic++) {
                    size_t cin = grp * g->icg + ic;
                    for (size_t ky = 0; ky < g->kh; ky++) {
                        long iy = (long)(oy * g->sy + ky * g->dy) - (long)g->pt;
                        if (iy < 0 || iy >= (long)g->H) continue;
                        for (size_t kx = 0; kx < g->kw; kx++) {
                            long ix = (long)(ox * g->sx + kx * g->dx) - (long)g->pl;
                            if (ix < 0 || ix >= (long)g->W) continue;
                            s += (double)w[((oc * g->icg + ic) * g->kh + ky) * g->kw + kx] * x[(cin * g->H + (size_t)iy) * g->W + (size_t)ix];
                        }
                    }
                }
                y[(oc * g->oH + oy) * g->oW + ox] = (float)s;
            }
    }
}
/* the adjoint: x-gradient and w-gradient from the y-gradient */
static void conv_core_back(const conv_geo *g, const float *w, const float *x, const float *dy, float *dx, float *dw, float *db) {
    size_t ocg = g->oC / g->groups;
    for (size_t oc = 0; oc < g->oC; oc++) {
        size_t grp = oc / ocg;
        for (size_t oy = 0; oy < g->oH; oy++)
            for (size_t ox = 0; ox < g->oW; ox++) {
                float d = dy[(oc * g->oH + oy) * g->oW + ox];
                if (db) db[oc] += d;
                if (d == 0) continue;
                for (size_t ic = 0; ic < g->icg; ic++) {
                    size_t cin = grp * g->icg + ic;
                    for (size_t ky = 0; ky < g->kh; ky++) {
                        long iy = (long)(oy * g->sy + ky * g->dy) - (long)g->pt;
                        if (iy < 0 || iy >= (long)g->H) continue;
                        for (size_t kx = 0; kx < g->kw; kx++) {
                            long ix = (long)(ox * g->sx + kx * g->dx) - (long)g->pl;
                            if (ix < 0 || ix >= (long)g->W) continue;
                            size_t wi = ((oc * g->icg + ic) * g->kh + ky) * g->kw + kx, xi = (cin * g->H + (size_t)iy) * g->W + (size_t)ix;
                            if (dx) dx[xi] += w[wi] * d;
                            if (dw) dw[wi] += x[xi] * d;
                        }
                    }
                }
            }
    }
}
/* store a dense [oc][ic][ky][kx] gradient into a weights descriptor of any convolution layout */
static int store_conv_weights(const BNNSNDArrayDescriptor *wd, const float *g, size_t kw, size_t kh, size_t I, size_t O, int acc) {
    int rot = wd->layout == BNNSDataLayoutConvolutionWeightsOIHrWr || wd->layout == BNNSDataLayoutConvolutionWeightsIOHrWr;
    int io = wd->layout == BNNSDataLayoutConvolutionWeightsIOHrWr;
    size_t A = io ? O : I;
    float *v = malloc(kw * kh * I * O * sizeof(float) + 1);
    if (!v) return -1;
    for (size_t oo = 0; oo < O; oo++)
        for (size_t ii = 0; ii < I; ii++)
            for (size_t y = 0; y < kh; y++)
                for (size_t x = 0; x < kw; x++) {
                    size_t sx = rot ? kw - 1 - x : x, sy = rot ? kh - 1 - y : y, a = io ? oo : ii, b = io ? ii : oo;
                    v[((b * A + a) * kh + sy) * kw + sx] = g[((oo * I + ii) * kh + y) * kw + x];
                }
    int r = bn_store(wd, NULL, v, acc);
    free(v);
    return r;
}
static int conv_forward(bn_layer *L, int transposed, const float *x, float *y, int with_act) {
    size_t kw, kh, ic, oc;
    float *w = conv_weights(&L->w, &kw, &kh, &ic, &oc), *bias = L->b.data ? bn_load(&L->b, NULL, NULL) : NULL;
    conv_geo g;
    if (!w || conv_geo_of(L, kw, kh, ic, oc, &g)) FAIL(free(w), free(bias));
    if (!transposed) conv_core(&g, w, bias, x, y);
    else {
        /* transposed: the adjoint of a convolution from the output geometry to the input geometry */
        conv_geo t = g;
        t.W = g.oW; t.H = g.oH; t.C = g.oC; t.oW = g.W; t.oH = g.H; t.oC = g.C;
        t.icg = oc / g.groups;   /* in the adjoint, "input channels per group" are the transposed layer's outputs */
        /* weights (oc_t, ic_t) = (layer output, layer input): conv_core_back expects [oC'][icg'] = [layer in][layer out/g] */
        float *wt = malloc(kw * kh * ic * oc * sizeof(float) + 1);
        size_t icg = ic, ocg = oc / g.groups;
        for (size_t o = 0; o < oc; o++) for (size_t i = 0; i < icg; i++) {
            size_t grp = o / ocg, lin = grp * icg + i, lo = o % ocg;
            for (size_t k = 0; k < kw * kh; k++) wt[((lin * ocg + lo) * kw * kh) + k] = w[((o * icg + i) * kw * kh) + k];
        }
        memset(y, 0, g.oC * g.oH * g.oW * sizeof(float));
        t.groups = g.groups;
        conv_core_back(&t, wt, NULL, x, y, NULL, NULL);
        if (bias) for (size_t c = 0; c < g.oC; c++) for (size_t p = 0; p < g.oH * g.oW; p++) y[c * g.oH * g.oW + p] += bias[c];
        free(wt);
    }
    if (with_act) bn_activation(&L->act, y, g.oC * g.oH * g.oW, g.oH * g.oW, g.oC, L->alpha);
    free(w); free(bias);
    return 0;
}

/* ---- fully connected ---- */
static float *fc_weights(bn_layer *L, size_t *nin, size_t *nout) {
    bn_dims d;
    float *v = bn_load(&L->w, NULL, &d);
    if (!v) return NULL;
    size_t ni = dcount(&L->i), no = dcount(&L->o);
    if (d.count != ni * no) { free(v); return NULL; }
    float *o = malloc(ni * no * sizeof(float) + 1);
    if (!o) { free(v); return NULL; }
    int colmajor = L->w.layout == BNNSDataLayoutColumnMajorMatrix || L->w.layout == BNNSDataLayout2DLastMajor;
    for (size_t r = 0; r < no; r++) for (size_t c = 0; c < ni; c++) o[r * ni + c] = colmajor ? v[r + no * c] : v[c + ni * r];
    free(v);
    *nin = ni; *nout = no;
    return o;
}
static int fc_forward(bn_layer *L, const float *x, float *y, int with_act) {
    size_t ni, no;
    float *w = fc_weights(L, &ni, &no), *b = L->b.data ? bn_load(&L->b, NULL, NULL) : NULL;
    if (!w) FAIL(free(b));
    for (size_t r = 0; r < no; r++) {
        double s = b ? b[r] : 0;
        for (size_t c = 0; c < ni; c++) s += (double)w[r * ni + c] * x[c];
        y[r] = (float)s;
    }
    if (with_act) bn_activation(&L->act, y, no, 1, 0, L->alpha);
    free(w); free(b);
    return 0;
}
static int store_fc_weights(bn_layer *L, const BNNSNDArrayDescriptor *wd, const float *g, size_t ni, size_t no, int acc) {
    float *v = malloc(ni * no * sizeof(float) + 1);
    if (!v) return -1;
    int colmajor = wd->layout == BNNSDataLayoutColumnMajorMatrix || wd->layout == BNNSDataLayout2DLastMajor;
    (void)L;
    for (size_t r = 0; r < no; r++) for (size_t c = 0; c < ni; c++) v[colmajor ? r + no * c : c + ni * r] = g[r * ni + c];
    int res = bn_store(wd, NULL, v, acc);
    free(v);
    return res;
}

/* ---- pooling ---- */
static void pool_geo(bn_layer *L, conv_geo *g) {
    bn_dims di, dout;
    bn_dims_of(&L->i, &di); bn_dims_of(&L->o, &dout);
    const BNNSLayerParametersPooling *p = &L->p.pool;
    g->W = di.n[0]; g->H = di.n[1]; g->C = di.rank > 2 ? di.n[2] : 1;
    g->oW = dout.n[0]; g->oH = dout.n[1]; g->oC = g->C;
    g->kw = p->k_width; g->kh = p->k_height;
    g->sx = p->x_stride ? p->x_stride : 1; g->sy = p->y_stride ? p->y_stride : 1;
    g->dx = p->x_dilation_stride > 1 ? p->x_dilation_stride : 1; g->dy = p->y_dilation_stride > 1 ? p->y_dilation_stride : 1;
    if (p->x_padding || p->y_padding || !(p->pad[0] | p->pad[1] | p->pad[2] | p->pad[3])) { g->pl = p->x_padding; g->pt = p->y_padding; }
    else { g->pl = p->pad[0]; g->pt = p->pad[2]; }
}
static int pool_forward(bn_layer *L, const float *x, float *y, long long *idx, int with_act) {
    conv_geo g; pool_geo(L, &g);
    BNNSPoolingFunction fn = L->p.pool.pooling_function;
    if (fn == BNNSPoolingFunctionUnMax) return -1;
    float *b = L->b.data ? bn_load(&L->b, NULL, NULL) : NULL;
    for (size_t c = 0; c < g.C; c++)
        for (size_t oy = 0; oy < g.oH; oy++)
            for (size_t ox = 0; ox < g.oW; ox++) {
                double s = 0; float m = -INFINITY; long long mi = -1; size_t n = 0;
                for (size_t ky = 0; ky < g.kh; ky++)
                    for (size_t kx = 0; kx < g.kw; kx++) {
                        long iy = (long)(oy * g.sy + ky * g.dy) - (long)g.pt, ix = (long)(ox * g.sx + kx * g.dx) - (long)g.pl;
                        if (iy < 0 || iy >= (long)g.H || ix < 0 || ix >= (long)g.W) continue;
                        size_t xi = (c * g.H + (size_t)iy) * g.W + (size_t)ix;
                        float v = x[xi];
                        if (v > m || mi < 0) { m = v; mi = (long long)xi; }
                        s += fn == BNNSPoolingFunctionL2Norm ? (double)v * v : v; n++;
                    }
                float r;
                switch (fn) {
                case BNNSPoolingFunctionMax: r = mi < 0 ? 0 : m; break;
                case BNNSPoolingFunctionAverageCountIncludePadding: r = (float)(s / (double)(g.kw * g.kh)); break;
                case BNNSPoolingFunctionAverageCountExcludePadding: r = n ? (float)(s / (double)n) : 0; break;
                case BNNSPoolingFunctionL2Norm: r = (float)sqrt(s); break;
                default: free(b); return -1;
                }
                size_t oi = (c * g.oH + oy) * g.oW + ox;
                y[oi] = r + (b ? b[c] : 0);
                if (idx) idx[oi] = mi;
            }
    if (with_act) bn_activation(&L->act, y, g.C * g.oH * g.oW, g.oH * g.oW, g.C, L->alpha);
    free(b);
    return 0;
}

/* ---- activation layer ---- */
/* softmax-like functions over the dimensions in axis_flags (default: dimension 0) */
static void grouped_activation(bn_layer *L, float *v, const bn_dims *d, int backward, const float *y, float *g) {
    uint32_t ax = L->axis_flags ? L->axis_flags : 1;
    bn_dims grp = *d, red = *d;
    grp.count = red.count = 1;
    for (int k = 0; k < BN_MAXD; k++) {
        int r = k < d->rank && ((ax >> k) & 1);
        grp.n[k] = r ? 1 : d->n[k]; red.n[k] = r ? d->n[k] : 1;
        grp.count *= grp.n[k]; red.count *= red.n[k];
    }
    size_t cs[BN_MAXD], s = 1, pos[BN_MAXD], rp[BN_MAXD];
    for (int k = 0; k < BN_MAXD; k++) { cs[k] = s; s *= d->n[k]; }
    float *tmp = malloc(red.count * sizeof(float) + 1), *ty = malloc(red.count * sizeof(float) + 1);
    size_t *off = malloc(red.count * sizeof(size_t) + 1);
    for (size_t o = 0; o < grp.count; o++) {
        bn_unravel(&grp, o, pos);
        for (size_t r = 0; r < red.count; r++) {
            bn_unravel(&red, r, rp);
            size_t q = 0;
            for (int k = 0; k < BN_MAXD; k++) q += (red.n[k] > 1 ? rp[k] : pos[k]) * cs[k];
            off[r] = q;
            tmp[r] = backward ? g[q] : v[q];
            if (backward) ty[r] = y[q];
        }
        if (!backward) bn_activation(&L->act, tmp, red.count, red.count, 0, NULL);
        else bn_activation_backward(&L->act, NULL, ty, tmp, red.count, red.count, 0, NULL, NULL);
        for (size_t r = 0; r < red.count; r++) (backward ? g : v)[off[r]] = tmp[r];
    }
    free(tmp); free(ty); free(off);
}
static size_t act_channels(bn_layer *L, size_t *inner) {
    bn_dims d; bn_dims_of(&L->i, &d);
    if (L->i.layout == BNNSDataLayoutImageCHW && d.rank == 3) { *inner = d.n[0] * d.n[1]; return d.n[2]; }
    *inner = 1; return 0;
}
static int act_forward(bn_layer *L, const float *x, float *y) {
    bn_dims d;
    if (bn_dims_of(&L->i, &d)) return -1;
    memcpy(y, x, d.count * sizeof(float));
    if (bn_activation_is_grouped(L->act.function) && L->act.function != BNNSActivationFunctionGumbelMax) {
        grouped_activation(L, y, &d, 0, NULL, NULL);
        return 0;
    }
    size_t inner, ch = act_channels(L, &inner);
    bn_activation(&L->act, y, d.count, inner, ch, L->alpha);
    return 0;
}

/* ---- normalization (over the whole batch) ---- */
typedef struct { size_t C, S; } norm_geo;
static norm_geo norm_geo_of(bn_layer *L) {
    bn_dims d; bn_dims_of(&L->i, &d);
    norm_geo g;
    if (L->i.layout == BNNSDataLayoutVector || d.rank == 1) { g.C = d.n[0]; g.S = 1; }
    else { g.C = d.rank > 2 ? d.n[2] : 1; g.S = d.n[0] * d.n[1]; }
    return g;
}
/* the statistics groups: returns the number of groups per batch member (or for the whole batch, for batch norm), and
   which group / channel each element of a sample belongs to */
static void norm_forward_batch(bn_layer *L, size_t batch, float **x, float **y, int training) {
    norm_geo g = norm_geo_of(L);
    size_t n = g.C * g.S;
    float *gamma = L->gamma.data ? bn_load(&L->gamma, NULL, NULL) : NULL, *beta = L->beta.data ? bn_load(&L->beta, NULL, NULL) : NULL;
    float *mm = L->mmean.data ? bn_load(&L->mmean, NULL, NULL) : NULL, *mv = L->mvar.data ? bn_load(&L->mvar, NULL, NULL) : NULL;
    float eps = L->p.norm.epsilon;
    free(L->cache_xhat); free(L->cache_istd);
    L->cache_xhat = malloc(batch * n * sizeof(float) + 1);
    L->cache_istd = malloc(batch * n * sizeof(float) + 1);   /* per element (simple and general) */
    L->cache_n = n; L->cache_batch = batch;
    BNNSFilterType t = L->norm_type;
    if (t == BNNSBatchNorm) {
        for (size_t c = 0; c < g.C; c++) {
            double s = 0, s2 = 0; size_t cnt = batch * g.S;
            for (size_t b = 0; b < batch; b++) for (size_t p = 0; p < g.S; p++) { double v = x[b][c * g.S + p]; s += v; s2 += v * v; }
            double mean = s / cnt, var = s2 / cnt - mean * mean;
            if (var < 0) var = 0;
            if (training) {
                if (mm) mm[c] = L->p.norm.momentum * mm[c] + (1 - L->p.norm.momentum) * (float)mean;
                if (mv) mv[c] = L->p.norm.momentum * mv[c] + (1 - L->p.norm.momentum) * (float)var;
            } else if (mm && mv) { mean = mm[c]; var = mv[c]; }
            float istd = (float)(1.0 / sqrt(var + eps));
            for (size_t b = 0; b < batch; b++) for (size_t p = 0; p < g.S; p++) {
                size_t i = c * g.S + p; float xh = (float)(x[b][i] - mean) * istd;
                L->cache_xhat[b * n + i] = xh; L->cache_istd[b * n + i] = istd;
                y[b][i] = (gamma ? gamma[c] : 1) * xh + (beta ? beta[c] : 0);
            }
        }
    } else {
        for (size_t b = 0; b < batch; b++) {
            /* groups of elements sharing statistics */
            size_t ngroups, gsize;
            if (t == BNNSInstanceNorm) { ngroups = g.C; gsize = g.S; }
            else if (t == BNNSGroupNorm) { size_t G = L->p.norm.num_groups ? L->p.norm.num_groups : 1; ngroups = G; gsize = n / G; }
            else { /* layer norm from normalization_axis: 0 = CHW, 1 = HW, 2 = W */
                bn_dims d; bn_dims_of(&L->i, &d);
                size_t ax = L->p.norm.normalization_axis, r = (size_t)d.rank;
                gsize = 1;
                for (size_t k = 0; k + ax < r; k++) gsize *= d.n[k];
                ngroups = n / (gsize ? gsize : 1);
            }
            for (size_t gi = 0; gi < ngroups; gi++) {
                double s = 0, s2 = 0;
                for (size_t k = 0; k < gsize; k++) { double v = x[b][gi * gsize + k]; s += v; s2 += v * v; }
                double mean = s / gsize, var = s2 / gsize - mean * mean;
                if (var < 0) var = 0;
                if (t == BNNSInstanceNorm) {
                    if (training) {
                        if (mm) mm[gi] = L->p.norm.momentum * mm[gi] + (1 - L->p.norm.momentum) * (float)mean;
                        if (mv) mv[gi] = L->p.norm.momentum * mv[gi] + (1 - L->p.norm.momentum) * (float)var;
                    } else if (mm && mv) { mean = mm[gi]; var = mv[gi]; }
                }
                float istd = (float)(1.0 / sqrt(var + eps));
                for (size_t k = 0; k < gsize; k++) {
                    size_t i = gi * gsize + k; float xh = (float)(x[b][i] - mean) * istd;
                    L->cache_xhat[b * n + i] = xh; L->cache_istd[b * n + i] = istd;
                    float ga, be;
                    if (t == BNNSLayerNorm) { ga = gamma ? gamma[k] : 1; be = beta ? beta[k] : 0; }
                    else { size_t c = i / g.S; ga = gamma ? gamma[c] : 1; be = beta ? beta[c] : 0; }
                    y[b][i] = ga * xh + be;
                }
            }
        }
    }
    for (size_t b = 0; b < batch; b++) bn_activation(&L->act, y[b], n, g.S, g.C, NULL);
    if (training) { if (mm) bn_store(&L->mmean, NULL, mm, 0); if (mv) bn_store(&L->mvar, NULL, mv, 0); }
    free(gamma); free(beta); free(mm); free(mv);
}
static int norm_backward_batch(bn_layer *L, size_t batch, float **dy, float **y, float **dx, float *dbeta, float *dgamma) {
    if (!L->cache_xhat || L->cache_batch != batch) return -1;
    norm_geo g = norm_geo_of(L);
    size_t n = L->cache_n;
    float *gamma = L->gamma.data ? bn_load(&L->gamma, NULL, NULL) : NULL, *beta = L->beta.data ? bn_load(&L->beta, NULL, NULL) : NULL;
    BNNSFilterType t = L->norm_type;
    /* parameter index of each element: per channel, or per normalized position for layer norm */
    size_t gsize_ln = 0;
    if (t == BNNSLayerNorm) {
        bn_dims d; bn_dims_of(&L->i, &d);
        gsize_ln = 1;
        for (size_t k = 0; k + L->p.norm.normalization_axis < (size_t)d.rank; k++) gsize_ln *= d.n[k];
    }
#define PIDX(i) (t == BNNSLayerNorm ? (i) % gsize_ln : (i) / g.S)
    /* activation: back through it from z = gamma * xhat + beta */
    float *z = malloc(n * sizeof(float) + 1);
    for (size_t b = 0; b < batch; b++) {
        for (size_t i = 0; i < n; i++)
            z[i] = (gamma ? gamma[PIDX(i)] : 1) * L->cache_xhat[b * n + i] + (beta ? beta[PIDX(i)] : 0);
        bn_activation_backward(&L->act, z, y[b], dy[b], n, g.S, g.C, NULL, NULL);
    }
    free(z);
    /* parameter gradients */
    float *dxh = malloc(batch * n * sizeof(float) + 1);
    for (size_t b = 0; b < batch; b++)
        for (size_t i = 0; i < n; i++) {
            size_t pi = PIDX(i);
            float d = dy[b][i], xh = L->cache_xhat[b * n + i];
            if (dbeta) dbeta[pi] += d;
            if (dgamma) dgamma[pi] += d * xh;
            dxh[b * n + i] = d * (gamma ? gamma[pi] : 1);
        }
    /* x gradients over each statistics group */
    if (dx) {
        if (t == BNNSBatchNorm) {
            for (size_t c = 0; c < g.C; c++) {
                double s = 0, sx = 0; size_t cnt = batch * g.S;
                for (size_t b = 0; b < batch; b++) for (size_t p = 0; p < g.S; p++) {
                    size_t i = b * n + c * g.S + p; s += dxh[i]; sx += dxh[i] * L->cache_xhat[i];
                }
                for (size_t b = 0; b < batch; b++) for (size_t p = 0; p < g.S; p++) {
                    size_t i = b * n + c * g.S + p;
                    dx[b][c * g.S + p] = (float)(L->cache_istd[i] / cnt * (cnt * dxh[i] - s - L->cache_xhat[i] * sx));
                }
            }
        } else {
            size_t gsize = t == BNNSInstanceNorm ? g.S : t == BNNSGroupNorm ? n / (L->p.norm.num_groups ? L->p.norm.num_groups : 1) : gsize_ln;
            for (size_t b = 0; b < batch; b++)
                for (size_t gi = 0; gi < n / gsize; gi++) {
                    double s = 0, sx = 0;
                    for (size_t k = 0; k < gsize; k++) { size_t i = b * n + gi * gsize + k; s += dxh[i]; sx += dxh[i] * L->cache_xhat[i]; }
                    for (size_t k = 0; k < gsize; k++) {
                        size_t i = b * n + gi * gsize + k;
                        dx[b][gi * gsize + k] = (float)(L->cache_istd[i] / gsize * (gsize * dxh[i] - s - L->cache_xhat[i] * sx));
                    }
                }
        }
    }
    free(dxh); free(gamma); free(beta);
#undef PIDX
    return 0;
}

/* ---- permute, dropout, padding, resize, embedding, Gram, reduction ---- */
static int permute_forward(bn_layer *L, const float *x, float *y, int backward) {
    bn_dims di, dout;
    bn_dims_of(&L->i, &di); bn_dims_of(&L->o, &dout);
    size_t ci[BN_MAXD], s = 1, pos[BN_MAXD], co[BN_MAXD];
    for (int k = 0; k < BN_MAXD; k++) { ci[k] = s; s *= di.n[k]; }
    s = 1; for (int k = 0; k < BN_MAXD; k++) { co[k] = s; s *= dout.n[k]; }
    for (size_t i = 0; i < dout.count; i++) {
        bn_unravel(&dout, i, pos);
        size_t off = 0;
        for (int k = 0; k < dout.rank; k++) off += pos[k] * ci[L->p.perm.permutation[k]];
        if (backward) y[off] = x[i]; else y[i] = x[off];
    }
    (void)co;
    return 0;
}
static uint64_t rng_next(uint64_t *s) { *s ^= *s << 13; *s ^= *s >> 7; *s ^= *s << 17; return *s; }
static int dropout_forward(bn_layer *L, size_t batch, float **x, float **y) {
    size_t n = dcount(&L->i);
    float rate = L->p.drop.rate;
    free(L->mask); L->mask = malloc(batch * n + 1); L->mask_n = batch * n;
    for (size_t b = 0; b < batch; b++)
        for (size_t i = 0; i < n; i++) {
            int keep = rate <= 0 || (float)((rng_next(&L->rng) >> 40) / 16777216.0) >= rate;
            L->mask[b * n + i] = (unsigned char)keep;
            y[b][i] = keep && rate < 1 ? x[b][i] / (1 - rate) : 0;
        }
    return 0;
}
static long pad_src(long i, long n, BNNSPaddingMode m) {
    if (i >= 0 && i < n) return i;
    if (m == BNNSPaddingModeConstant || n == 1) return -1;
    long period = m == BNNSPaddingModeReflect ? 2 * (n - 1) : 2 * n;
    long r = ((i % period) + period) % period;
    if (m == BNNSPaddingModeReflect) return r < n ? r : period - r;
    return r < n ? r : period - 1 - r;
}
static int pad_forward(bn_layer *L, const float *x, float *y, int backward) {
    bn_dims di, dout;
    bn_dims_of(&L->i, &di); bn_dims_of(&L->o, &dout);
    size_t ci[BN_MAXD], s = 1, pos[BN_MAXD];
    for (int k = 0; k < BN_MAXD; k++) { ci[k] = s; s *= di.n[k]; }
    float cval; uint32_t raw = L->p.pad.padding_value;
    memcpy(&cval, &raw, 4);
    if (L->i.data_type != BNNSDataTypeFloat32) cval = (float)(int32_t)raw;
    if (backward) memset(y, 0, di.count * sizeof(float));
    for (size_t i = 0; i < dout.count; i++) {
        bn_unravel(&dout, i, pos);
        size_t off = 0; int out = 0;
        for (int k = 0; k < dout.rank; k++) {
            long sp = pad_src((long)pos[k] - (long)L->p.pad.padding_size[k][0], (long)di.n[k], L->p.pad.padding_mode);
            if (sp < 0) { out = 1; break; }
            off += (size_t)sp * ci[k];
        }
        if (backward) { if (!out) y[off] += x[i]; }
        else y[i] = out ? cval : x[off];
    }
    return 0;
}
static int resize_forward(bn_layer *L, const float *x, float *y) {
    bn_dims di, dout;
    bn_dims_of(&L->i, &di); bn_dims_of(&L->o, &dout);
    size_t ci[BN_MAXD], s = 1, pos[BN_MAXD];
    for (int k = 0; k < BN_MAXD; k++) { ci[k] = s; s *= di.n[k]; }
    int lin = L->p.resize.method == BNNSInterpolationMethodLinear, ac = L->p.resize.align_corners;
    for (size_t i = 0; i < dout.count; i++) {
        bn_unravel(&dout, i, pos);
        /* separable: interpolate over each resized dimension (up to 2 for linear) */
        double acc = 0; size_t base = 0; int rd[BN_MAXD], nr = 0; double f[BN_MAXD];
        for (int k = 0; k < dout.rank; k++) {
            if (di.n[k] == dout.n[k]) { base += pos[k] * ci[k]; continue; }
            double src = ac && dout.n[k] > 1 ? (double)pos[k] * (di.n[k] - 1) / (dout.n[k] - 1)
                                              : ((double)pos[k] + 0.5) * di.n[k] / dout.n[k] - 0.5;
            if (!lin) { size_t sp = ac ? (size_t)llround(src) : (size_t)floor(((double)pos[k]) * di.n[k] / dout.n[k]);
                        if (sp >= di.n[k]) sp = di.n[k] - 1; base += sp * ci[k]; continue; }
            if (src < 0) src = 0;
            if (src > di.n[k] - 1) src = (double)(di.n[k] - 1);
            rd[nr] = k; f[nr] = src; nr++;
        }
        if (!lin || !nr) { y[i] = x[base]; continue; }
        for (int m = 0; m < (1 << nr); m++) {
            double wgt = 1; size_t off = base;
            for (int j = 0; j < nr; j++) {
                size_t lo = (size_t)floor(f[j]), hi = lo + 1 < di.n[rd[j]] ? lo + 1 : lo;
                double fr = f[j] - lo;
                if ((m >> j) & 1) { wgt *= fr; off += hi * ci[rd[j]]; } else { wgt *= 1 - fr; off += lo * ci[rd[j]]; }
            }
            acc += wgt * x[off];
        }
        y[i] = (float)acc;
    }
    return 0;
}
static int embed_forward(bn_layer *L, const void *in, float *y) {
    long long *ix = bn_load_index(&L->i, in, NULL);
    bn_dims dd;
    float *dict = bn_load(&L->w, NULL, &dd);
    if (!ix || !dict) FAIL(free(ix), free(dict));
    size_t E = dd.n[0], N = dd.n[1], ni = dcount(&L->i);
    for (size_t q = 0; q < ni; q++) {
        long long k = ix[q];
        float *row = y + q * E;
        if (k < 0 || (size_t)k >= N || (size_t)k == L->p.embed.padding_idx) { memset(row, 0, E * sizeof(float)); continue; }
        memcpy(row, dict + (size_t)k * E, E * sizeof(float));
        if (L->p.embed.max_norm > 0) {
            double p = L->p.embed.norm_type > 0 ? L->p.embed.norm_type : 2, s = 0;
            for (size_t e = 0; e < E; e++) s += pow(fabs(row[e]), p);
            s = pow(s, 1 / p);
            if (s > L->p.embed.max_norm) for (size_t e = 0; e < E; e++) row[e] *= (float)(L->p.embed.max_norm / s);
        }
    }
    free(ix); free(dict);
    return 0;
}
static int gram_forward(bn_layer *L, const float *x, float *y) {
    bn_dims d; bn_dims_of(&L->i, &d);
    size_t C = d.rank > 2 ? d.n[2] : d.n[d.rank - 1], S = d.count / (C ? C : 1);
    for (size_t a = 0; a < C; a++)
        for (size_t b = 0; b < C; b++) {
            double s = 0;
            for (size_t p = 0; p < S; p++) s += (double)x[a * S + p] * x[b * S + p];
            y[a + C * b] = (float)(L->p.gram.alpha * s);
        }
    return 0;
}

/* ---- per-sample dispatch ---- */
int bn_layer_forward(bn_filter *f, size_t batch, float **x, float **y, int training) {
    bn_layer *L = bn_layer_of(f);
    if (!L) return -1;
    switch (f->kind) {
    case BK_NORM: norm_forward_batch(L, batch, x, y, training); return 0;
    case BK_DROPOUT: return dropout_forward(L, batch, x, y);
    default: break;
    }
    for (size_t b = 0; b < batch; b++) {
        int r;
        switch (f->kind) {
        case BK_CONV: r = conv_forward(L, 0, x[b], y[b], 1); break;
        case BK_TCONV: r = conv_forward(L, 1, x[b], y[b], 1); break;
        case BK_FC: r = fc_forward(L, x[b], y[b], 1); break;
        case BK_POOL: r = pool_forward(L, x[b], y[b], NULL, 1); break;
        case BK_ACT: r = act_forward(L, x[b], y[b]); break;
        case BK_PERMUTE: r = permute_forward(L, x[b], y[b], 0); break;
        case BK_PAD: r = pad_forward(L, x[b], y[b], 0); break;
        case BK_RESIZE: r = resize_forward(L, x[b], y[b]); break;
        case BK_GRAM: r = gram_forward(L, x[b], y[b]); break;
        case BK_REDUCE: {
            bn_dims di, dout; bn_dims_of(&L->i, &di); bn_dims_of(&L->o, &dout);
            float *w = L->w.data ? bn_load(&L->w, NULL, NULL) : NULL;
            r = bn_reduce(L->p.reduce.reduce_func, x[b], w, &di, y[b], &dout, L->p.reduce.epsilon);
            free(w); break;
        }
        case BK_ARITH: {
            bn_dims xd[3], yd; const float *xs[3] = {x[b], NULL, NULL};
            for (int k = 0; k < L->arity; k++) bn_dims_of(&L->ain[k], &xd[k]);
            bn_dims_of(&L->aout, &yd);
            r = bn_arith_forward(L, xs, xd, y[b], &yd); break;
        }
        case BK_CONTRACT: r = bn_contract_forward(L, x[b], NULL, y[b]); break;
        case BK_BMM: {
            BNNSNDArrayDescriptor A = L->p.bmm.iA_desc, B = L->p.bmm.iB_desc, C = L->o;
            float *tw = L->w.data ? bn_load(&L->w, NULL, NULL) : NULL;
            if (L->p.bmm.a_is_weights) { as_dense(&A, tw); as_dense(&B, x[b]); }
            else if (L->p.bmm.b_is_weights) { as_dense(&A, x[b]); as_dense(&B, tw); }
            else { as_dense(&A, x[b]); as_dense(&B, x[b]); }   /* quadratic: A·A */
            as_dense(&C, y[b]);
            r = bn_matmul(L->p.bmm.transA, L->p.bmm.transB, L->p.bmm.alpha, &A, &B, &C, 0);
            free(tw); break;
        }
        case BK_QUANT: {
            BNNSLayerParametersQuantization q = L->p.quant;
            BNNSNDArrayDescriptor id = L->i, od = L->o;
            as_dense(&id, NULL); as_dense(&od, NULL);
            q.i_desc = id; q.o_desc = od;
            r = bn_quantize(&q, x[b], y[b]); break;
        }
        default: return -1;
        }
        if (r) return r;
    }
    return 0;
}

/* ---- batch apply ---- */
static int apply_batch(bn_filter *f, size_t batch, const void *in, size_t in_stride, void *out, size_t out_stride, int training,
                       long long **indices) {
    bn_layer *L = bn_layer_of(f);
    if (!L || !in || !out) return -1;
    if (f->kind == BK_FUSED) {
        extern int bn_fused_apply(bn_filter *, size_t, const void *, size_t, void *, size_t, int);
        return bn_fused_apply(f, batch, in, in_stride, out, out_stride, training);
    }
    const BNNSNDArrayDescriptor *id = f->kind == BK_ARITH ? &L->ain[0] : &L->i, *od = f->kind == BK_ARITH ? &L->aout : &L->o;
    size_t no = dcount(od);
    float **x = calloc(batch + 1, sizeof(float *)), **y = calloc(batch + 1, sizeof(float *));
    int r = 0;
    for (size_t b = 0; b < batch && !r; b++) {
        const void *p = (const char *)in + bn_bytes(id, b * in_stride);
        if (f->kind == BK_EMBED) { y[b] = malloc(no * sizeof(float) + 1); r = embed_forward(L, p, y[b]); x[b] = NULL; continue; }
        x[b] = bn_load(id, p, NULL); y[b] = malloc(no * sizeof(float) + 1);
        if (!x[b] || !y[b]) r = -1;
    }
    if (!r && f->kind == BK_POOL && indices) {
        for (size_t b = 0; b < batch && !r; b++) {
            indices[b] = malloc(no * sizeof(long long) + 1);
            r = pool_forward(L, x[b], y[b], indices[b], 1);
        }
    } else if (!r && f->kind != BK_EMBED) r = bn_layer_forward(f, batch, x, y, training);
    /* beta = 1: the matrix product and the contraction add to what the output holds */
    int acc = (f->kind == BK_BMM && L->p.bmm.beta != 0) || (f->kind == BK_CONTRACT && L->p.contract.beta != 0);
    for (size_t b = 0; b < batch && !r; b++) r = bn_store(od, (char *)out + bn_bytes(od, b * out_stride), y[b], acc);
    for (size_t b = 0; b < batch; b++) { free(x[b]); free(y[b]); }
    free(x); free(y);
    return r;
}
int BNNSFilterApplyBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, void *out, size_t out_stride) {
    bn_filter *f = bn_filter_of(filter);
    return f ? apply_batch(f, batch_size, in, in_stride, out, out_stride, 0, NULL) : -1;
}
int BNNSFilterApply(BNNSFilter filter, const void *in, void *out) { return BNNSFilterApplyBatch(filter, 1, in, 0, out, 0); }
int BNNSNormalizationFilterApplyBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, void *out,
                                      size_t out_stride, bool training) {
    bn_filter *f = bn_filter_of(filter);
    return f && f->kind == BK_NORM ? apply_batch(f, batch_size, in, in_stride, out, out_stride, training, NULL) : -1;
}
int BNNSFusedFilterApplyBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, void *out, size_t out_stride,
                              bool training) {
    bn_filter *f = bn_filter_of(filter);
    return f && f->kind == BK_FUSED ? apply_batch(f, batch_size, in, in_stride, out, out_stride, training, NULL) : -1;
}
static int pool_indices_apply(BNNSFilter filter, size_t batch, const void *in, size_t in_stride, void *out, size_t out_stride,
                              BNNSDataType itype, void *indices, size_t idx_stride) {
    bn_filter *f = bn_filter_of(filter);
    if (!f || f->kind != BK_POOL) return -1;
    if (!indices) return apply_batch(f, batch, in, in_stride, out, out_stride, 0, NULL);
    long long **ix = calloc(batch + 1, sizeof(long long *));
    int r = apply_batch(f, batch, in, in_stride, out, out_stride, 0, ix);
    size_t no = dcount(&bn_layer_of(f)->o);
    BNNSNDArrayDescriptor idesc = {0};
    idesc.layout = BNNSDataLayoutVector; idesc.size[0] = no; idesc.data_type = itype;
    for (size_t b = 0; b < batch; b++) {
        if (!r && ix[b]) {
            if (itype == (BNNSDataType)0) for (size_t i = 0; i < no; i++) ((size_t *)indices)[b * idx_stride + i] = (size_t)ix[b][i];
            else {
                float *fv = malloc(no * sizeof(float) + 1);
                for (size_t i = 0; i < no; i++) fv[i] = (float)ix[b][i];
                bn_store(&idesc, (char *)indices + bn_bytes(&idesc, b * idx_stride), fv, 0);
                free(fv);
            }
        }
        free(ix[b]);
    }
    free(ix);
    return r;
}
int BNNSPoolingFilterApplyBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, void *out, size_t out_stride,
                                size_t *indices, size_t idx_stride) {
    return pool_indices_apply(filter, batch_size, in, in_stride, out, out_stride, (BNNSDataType)0, indices, idx_stride);
}
int BNNSPoolingFilterApplyBatchEx(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, void *out, size_t out_stride,
                                  const BNNSDataType indices_data_type, void *indices, size_t idx_stride) {
    return pool_indices_apply(filter, batch_size, in, in_stride, out, out_stride, indices_data_type, indices, idx_stride);
}

/* ---- backward ---- */
static float *load_delta(const BNNSNDArrayDescriptor *d, size_t b, size_t stride) {
    return bn_load(d, (const char *)d->data + bn_bytes(d, b * stride), NULL);
}
static int store_delta(BNNSNDArrayDescriptor *d, size_t b, size_t stride, const float *v) {
    return bn_store(d, (char *)d->data + bn_bytes(d, b * stride), v, d->flags == BNNSNDArrayFlagBackpropAccumulate);
}
static int store_param_delta(BNNSNDArrayDescriptor *d, const float *v) {
    return d && d->data ? bn_store(d, NULL, v, d->flags == BNNSNDArrayFlagBackpropAccumulate) : 0;
}
int bn_layer_backward(bn_filter *f, size_t batch, const void *in, size_t in_stride, BNNSNDArrayDescriptor *in_delta,
                      size_t in_delta_stride, const void *out, size_t out_stride, const BNNSNDArrayDescriptor *out_delta,
                      size_t out_delta_stride, BNNSNDArrayDescriptor *weights_delta, BNNSNDArrayDescriptor *bias_delta) {
    bn_layer *L = bn_layer_of(f);
    if (!L || !out_delta || !out_delta->data) return -1;
    size_t ni = dcount(&L->i), no = dcount(&L->o);
    int r = 0;
    switch (f->kind) {
    case BK_ACT: case BK_FC: case BK_CONV: case BK_POOL: case BK_PERMUTE: case BK_PAD: case BK_DROPOUT: case BK_TCONV: break;
    default: return -1;
    }
    float *dw = NULL, *db = NULL, *wd = NULL; size_t nw = 0, nb = 0, kw = 0, kh = 0, ic = 0, oc = 0, fin = 0, fout = 0;
    if (f->kind == BK_FC) { wd = fc_weights(L, &fin, &fout); nw = fin * fout; nb = fout; if (!wd) return -1; }
    if (f->kind == BK_CONV || f->kind == BK_TCONV) { wd = conv_weights(&L->w, &kw, &kh, &ic, &oc); if (!wd) return -1; nw = kw * kh * ic * oc; nb = f->kind == BK_CONV ? no / (no / (oc ? oc : 1)) : 0; nb = oc; }
    if (f->kind == BK_ACT) nw = L->nalpha;
    if (f->kind == BK_POOL) { conv_geo g; pool_geo(L, &g); nb = g.C; }
    dw = calloc(nw + 1, sizeof(float)); db = calloc(nb + 1, sizeof(float));
    for (size_t b = 0; b < batch && !r; b++) {
        float *x = in ? bn_load(&L->i, (const char *)in + bn_bytes(&L->i, b * in_stride), NULL) : NULL;
        float *y = out ? bn_load(&L->o, (const char *)out + bn_bytes(&L->o, b * out_stride), NULL) : NULL;
        float *g = load_delta(out_delta, b, out_delta_stride), *dx = calloc(ni + 1, sizeof(float));
        if (!g || !dx) { r = -1; free(x); free(y); free(g); free(dx); break; }
        switch (f->kind) {
        case BK_ACT: {
            if (!x) { r = -1; break; }
            bn_dims d; bn_dims_of(&L->i, &d);
            if (!y) { y = malloc(ni * sizeof(float) + 1); act_forward(L, x, y); }
            if (bn_activation_is_grouped(L->act.function)) grouped_activation(L, NULL, &d, 1, y, g);
            else { size_t inner, ch = act_channels(L, &inner); bn_activation_backward(&L->act, x, y, g, ni, inner, ch, L->alpha, nw ? dw : NULL); }
            memcpy(dx, g, ni * sizeof(float));
            break;
        }
        case BK_FC: {
            if (!x) { r = -1; break; }
            float *z = malloc(no * sizeof(float) + 1);
            fc_forward(L, x, z, 0);
            float *yy = malloc(no * sizeof(float) + 1); memcpy(yy, z, no * sizeof(float));
            bn_activation(&L->act, yy, no, 1, 0, L->alpha);
            bn_activation_backward(&L->act, z, yy, g, no, 1, 0, L->alpha, NULL);
            for (size_t o = 0; o < no; o++) {
                db[o] += g[o];
                for (size_t c = 0; c < ni; c++) { dx[c] += wd[o * ni + c] * g[o]; dw[o * ni + c] += g[o] * x[c]; }
            }
            free(z); free(yy);
            break;
        }
        case BK_CONV: case BK_TCONV: {
            if (!x) { r = -1; break; }
            float *z = malloc(no * sizeof(float) + 1), *yy = malloc(no * sizeof(float) + 1);
            conv_forward(L, f->kind == BK_TCONV, x, z, 0);
            memcpy(yy, z, no * sizeof(float));
            conv_geo cg; conv_geo_of(L, kw, kh, ic, oc, &cg);
            bn_activation(&L->act, yy, no, cg.oH * cg.oW, cg.oC, L->alpha);
            bn_activation_backward(&L->act, z, yy, g, no, cg.oH * cg.oW, cg.oC, L->alpha, NULL);
            if (f->kind == BK_CONV) conv_core_back(&cg, wd, x, g, dx, dw, db);
            else {
                /* transposed: forward is the adjoint, so the input gradient is the convolution of dy */
                conv_geo t = cg; t.W = cg.oW; t.H = cg.oH; t.C = cg.oC; t.oW = cg.W; t.oH = cg.H; t.oC = cg.C; t.icg = oc / cg.groups;
                size_t icg = ic, ocg = oc / cg.groups;
                float *wt = malloc(nw * sizeof(float) + 1), *dwt = calloc(nw + 1, sizeof(float));
                for (size_t o = 0; o < oc; o++) for (size_t i = 0; i < icg; i++) {
                    size_t grp = o / ocg, lin = grp * icg + i, lo = o % ocg;
                    for (size_t k = 0; k < kw * kh; k++) wt[((lin * ocg + lo) * kw * kh) + k] = wd[((o * icg + i) * kw * kh) + k];
                }
                conv_core(&t, wt, NULL, g, dx);
                conv_core_back(&t, wt, g, x, NULL, dwt, NULL);
                for (size_t o = 0; o < oc; o++) for (size_t i = 0; i < icg; i++) {
                    size_t grp = o / ocg, lin = grp * icg + i, lo = o % ocg;
                    for (size_t k = 0; k < kw * kh; k++) dw[((o * icg + i) * kw * kh) + k] += dwt[((lin * ocg + lo) * kw * kh) + k];
                }
                for (size_t c = 0; c < cg.oC; c++) for (size_t p = 0; p < cg.oH * cg.oW; p++) db[c] += g[c * cg.oH * cg.oW + p];
                free(wt); free(dwt);
            }
            free(z); free(yy);
            break;
        }
        case BK_POOL: {
            if (!x) { r = -1; break; }
            conv_geo pg; pool_geo(L, &pg);
            long long *idx = malloc(no * sizeof(long long) + 1);
            float *z = malloc(no * sizeof(float) + 1), *yy = malloc(no * sizeof(float) + 1);
            BNNSActivation keep = L->act;
            pool_forward(L, x, z, idx, 0);
            memcpy(yy, z, no * sizeof(float));
            bn_activation(&L->act, yy, no, pg.oH * pg.oW, pg.C, NULL);
            bn_activation_backward(&keep, z, yy, g, no, pg.oH * pg.oW, pg.C, NULL, NULL);
            BNNSPoolingFunction fn = L->p.pool.pooling_function;
            for (size_t c = 0; c < pg.C; c++)
                for (size_t oy = 0; oy < pg.oH; oy++)
                    for (size_t ox = 0; ox < pg.oW; ox++) {
                        size_t oi = (c * pg.oH + oy) * pg.oW + ox;
                        db[c] += g[oi];
                        if (fn == BNNSPoolingFunctionMax) { if (idx[oi] >= 0) dx[idx[oi]] += g[oi]; continue; }
                        size_t n = 0;
                        for (int pass = 0; pass < 2; pass++)
                            for (size_t ky = 0; ky < pg.kh; ky++)
                                for (size_t kx = 0; kx < pg.kw; kx++) {
                                    long iy = (long)(oy * pg.sy + ky * pg.dy) - (long)pg.pt, ix = (long)(ox * pg.sx + kx * pg.dx) - (long)pg.pl;
                                    if (iy < 0 || iy >= (long)pg.H || ix < 0 || ix >= (long)pg.W) continue;
                                    size_t xi = (c * pg.H + (size_t)iy) * pg.W + (size_t)ix;
                                    if (!pass) { n++; continue; }
                                    if (fn == BNNSPoolingFunctionL2Norm) dx[xi] += z[oi] != 0 ? g[oi] * x[xi] / z[oi] : 0;
                                    else dx[xi] += g[oi] / (fn == BNNSPoolingFunctionAverageCountIncludePadding ? (float)(pg.kw * pg.kh) : (float)n);
                                }
                    }
            free(idx); free(z); free(yy);
            break;
        }
        case BK_PERMUTE: permute_forward(L, g, dx, 1); break;
        case BK_PAD: pad_forward(L, g, dx, 1); break;
        case BK_DROPOUT: {
            float rate = L->p.drop.rate;
            for (size_t i = 0; i < ni; i++) {
                int keep = !L->mask || b * ni + i >= L->mask_n || L->mask[b * ni + i];
                dx[i] = keep && rate < 1 ? g[i] / (1 - rate) : 0;
            }
            break;
        }
        }
        if (!r && in_delta && in_delta->data) r = store_delta(in_delta, b, in_delta_stride, dx);
        free(x); free(y); free(g); free(dx);
    }
    if (!r && weights_delta && nw) {
        if (f->kind == BK_FC) r = weights_delta->data ? store_fc_weights(L, weights_delta, dw, fin, fout, weights_delta->flags == BNNSNDArrayFlagBackpropAccumulate) : 0;
        else if (f->kind == BK_CONV || f->kind == BK_TCONV) r = weights_delta->data ? store_conv_weights(weights_delta, dw, kw, kh, ic, oc, weights_delta->flags == BNNSNDArrayFlagBackpropAccumulate) : 0;
        else r = store_param_delta(weights_delta, dw);
    }
    if (!r && bias_delta && nb) r = store_param_delta(bias_delta, db);
    free(dw); free(db); free(wd);
    return r;
}
int BNNSFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride, BNNSNDArrayDescriptor *in_delta,
                                 size_t in_delta_stride, const void *out, size_t out_stride, const BNNSNDArrayDescriptor *out_delta,
                                 size_t out_delta_stride, BNNSNDArrayDescriptor *weights_delta, BNNSNDArrayDescriptor *bias_delta) {
    bn_filter *f = bn_filter_of(filter);
    if (!f) return -1;
    if (f->kind == BK_ARITH || f->kind == BK_CONTRACT || f->kind == BK_BMM) {
        extern int bn_layers2_backward(bn_filter *, size_t, const void *const *, const size_t *, BNNSNDArrayDescriptor *const *,
                                       const size_t *, size_t, const void *, size_t, const BNNSNDArrayDescriptor *, size_t,
                                       BNNSNDArrayDescriptor *);
        const void *ins[1] = {in}; size_t ist[1] = {in_stride}; BNNSNDArrayDescriptor *ids[1] = {in_delta}; size_t idst[1] = {in_delta_stride};
        return bn_layers2_backward(f, batch_size, ins, ist, ids, idst, 1, out, out_stride, out_delta, out_delta_stride, weights_delta);
    }
    return bn_layer_backward(f, batch_size, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta, out_delta_stride,
                             weights_delta, bias_delta);
}
int BNNSPoolingFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride,
                                        BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride, const void *out, size_t out_stride,
                                        BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride, BNNSNDArrayDescriptor *bias_delta,
                                        const size_t *indices, size_t idx_stride) {
    (void)indices; (void)idx_stride;   /* isim recomputes the maxima from the input */
    return BNNSFilterApplyBackwardBatch(filter, batch_size, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta,
                                        out_delta_stride, NULL, bias_delta);
}
int BNNSPoolingFilterApplyBackwardBatchEx(BNNSFilter filter, size_t batch_size, const void *in, size_t in_stride,
                                          BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride, const void *out, size_t out_stride,
                                          BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride, BNNSNDArrayDescriptor *bias_delta,
                                          const BNNSDataType indices_data_type, const void *indices, size_t idx_stride) {
    (void)indices_data_type; (void)indices; (void)idx_stride;
    return BNNSFilterApplyBackwardBatch(filter, batch_size, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta,
                                        out_delta_stride, NULL, bias_delta);
}
int BNNSPermuteFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, BNNSNDArrayDescriptor *in_delta, size_t in_delta_stride,
                                        const BNNSNDArrayDescriptor *out_delta, size_t out_delta_stride) {
    bn_filter *f = bn_filter_of(filter);
    if (!f || f->kind != BK_PERMUTE) return -1;
    return bn_layer_backward(f, batch_size, NULL, 0, in_delta, in_delta_stride, NULL, 0, out_delta, out_delta_stride, NULL, NULL);
}
int BNNSNormalizationFilterApplyBackwardBatch(BNNSFilter filter, size_t batch_size, BNNSNDArrayDescriptor *in_delta,
                                              size_t in_delta_stride, const void *out, size_t out_stride, BNNSNDArrayDescriptor *out_delta,
                                              size_t out_delta_stride, BNNSNDArrayDescriptor *beta_delta, BNNSNDArrayDescriptor *gamma_delta) {
    bn_filter *f = bn_filter_of(filter);
    bn_layer *L = bn_layer_of(f);
    if (!f || f->kind != BK_NORM || !out_delta || !out_delta->data) return -1;
    size_t n = dcount(&L->i), np = L->gamma.data ? dcount(&L->gamma) : (L->beta.data ? dcount(&L->beta) : n);
    float **dy = calloc(batch_size + 1, sizeof(float *)), **y = calloc(batch_size + 1, sizeof(float *)), **dx = calloc(batch_size + 1, sizeof(float *));
    float *dbeta = calloc(np + 1, sizeof(float)), *dgamma = calloc(np + 1, sizeof(float));
    int r = 0;
    for (size_t b = 0; b < batch_size && !r; b++) {
        dy[b] = load_delta(out_delta, b, out_delta_stride);
        y[b] = out ? bn_load(&L->o, (const char *)out + bn_bytes(&L->o, b * out_stride), NULL) : calloc(n + 1, sizeof(float));
        dx[b] = calloc(n + 1, sizeof(float));
        if (!dy[b] || !y[b] || !dx[b]) r = -1;
    }
    if (!r) r = norm_backward_batch(L, batch_size, dy, y, dx, dbeta, dgamma);
    for (size_t b = 0; b < batch_size && !r; b++) if (in_delta && in_delta->data) r = store_delta(in_delta, b, in_delta_stride, dx[b]);
    if (!r) r = store_param_delta(beta_delta, dbeta);
    if (!r) r = store_param_delta(gamma_delta, dgamma);
    for (size_t b = 0; b < batch_size; b++) { free(dy[b]); free(y[b]); free(dx[b]); }
    free(dy); free(y); free(dx); free(dbeta); free(dgamma);
    return r;
}

/* ---- BNNSGetPointer ---- */
BNNSNDArrayDescriptor BNNSGetPointer(BNNSFilter filter, BNNSPointerSpecifier target) {
    BNNSNDArrayDescriptor none = {0};
    bn_filter *f = bn_filter_of(filter);
    bn_layer *L = bn_layer_of(f);
    if (!L) return none;
    if (f->kind == BK_ACT) return target == BNNSPointerSpecifierAlpha && L->alpha ? L->alpha_desc : none;
    if (f->kind == BK_NORM) return target == BNNSPointerSpecifierAlpha ? L->gamma : L->beta;
    return target == BNNSPointerSpecifierAlpha ? L->w : L->b;
}

/* ---- creation ---- */
static bn_filter *new_with(int kind, const BNNSNDArrayDescriptor *i, const BNNSNDArrayDescriptor *o, const BNNSFilterParameters *fp) {
    bn_dims d;
    if ((i && bn_dims_of(i, &d)) || (o && bn_dims_of(o, &d))) return NULL;
    bn_filter *f = bn_layer_new(kind, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    if (i) L->i = *i;
    if (o) L->o = *o;
    return f;
}
static int set_activation(bn_layer *L, const BNNSActivation *a, size_t channels) {
    L->act = *a;
    if (a->function == BNNSActivationFunctionLeakyRectifiedLinear || a->function == BNNSActivationFunctionPReLUPerChannel) {
        L->nalpha = a->function == BNNSActivationFunctionPReLUPerChannel ? (channels ? channels : 1) : 1;
        L->alpha = malloc(L->nalpha * sizeof(float));
        if (!L->alpha) return -1;
        for (size_t k = 0; k < L->nalpha; k++) L->alpha[k] = a->alpha;
        L->alpha_desc.layout = BNNSDataLayoutVector; L->alpha_desc.size[0] = L->nalpha;
        L->alpha_desc.data = L->alpha; L->alpha_desc.data_type = BNNSDataTypeFloat32;
        if (a->function == BNNSActivationFunctionLeakyRectifiedLinear) { L->act.alpha = a->alpha; }
    }
    return 0;
}
static BNNSFilter finish(bn_filter *f, int ok) {
    if (!ok) { BNNSFilterDestroy(f); return NULL; }
    return f;
}
BNNSFilter BNNSFilterCreateLayerConvolution(const BNNSLayerParametersConvolution *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_CONV, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.conv = *p;
    bn_dims o; bn_dims_of(&p->o_desc, &o);
    int ok = p->w_desc.data && bn_layout_rank(p->w_desc.layout) == 4 && p->w_desc.layout != BNNSDataLayoutConvolutionWeightsOIHW_Pack32 &&
             !bn_layer_keep(f, &L->w, &p->w_desc, &L->owns_w) && !bn_layer_keep(f, &L->b, &p->bias, &L->owns_b) &&
             !set_activation(L, &p->activation, o.rank > 2 ? o.n[2] : 1);
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerTransposedConvolution(const BNNSLayerParametersConvolution *p, const BNNSFilterParameters *fp) {
    bn_filter *f = BNNSFilterCreateLayerConvolution(p, fp);
    if (f) f->kind = BK_TCONV;
    return f;
}
BNNSFilter BNNSFilterCreateLayerFullyConnected(const BNNSLayerParametersFullyConnected *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_FC, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    int ok = p->w_desc.data && dcount(&p->w_desc) == dcount(&p->i_desc) * dcount(&p->o_desc) &&
             !bn_layer_keep(f, &L->w, &p->w_desc, &L->owns_w) && !bn_layer_keep(f, &L->b, &p->bias, &L->owns_b) &&
             !set_activation(L, &p->activation, 0);
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerPooling(const BNNSLayerParametersPooling *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_POOL, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.pool = *p;
    int ok = p->k_width && p->k_height && p->pooling_function != BNNSPoolingFunctionUnMax &&
             !bn_layer_keep(f, &L->b, &p->bias, &L->owns_b) && !set_activation(L, &p->activation, 0);
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerActivation(const BNNSLayerParametersActivation *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_ACT, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.actp = *p; L->axis_flags = p->axis_flags;
    size_t inner, ch = act_channels(L, &inner);
    int ok = dcount(&p->i_desc) == dcount(&p->o_desc) && !set_activation(L, &p->activation, ch);
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerNormalization(BNNSFilterType normType, const BNNSLayerParametersNormalization *p,
                                              const BNNSFilterParameters *fp) {
    if (!p || normType < BNNSBatchNorm || normType > BNNSGroupNorm) return NULL;
    bn_filter *f = new_with(BK_NORM, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.norm = *p; L->norm_type = normType; L->act = p->activation;
    int o1 = 0, o2 = 0;
    int ok = !bn_activation_is_grouped(p->activation.function) &&
             (!p->gamma_desc.data || !bn_keep(&L->gamma, &p->gamma_desc)) && (!p->beta_desc.data || !bn_keep(&L->beta, &p->beta_desc));
    /* the moving statistics stay the caller's: BNNS updates them in place during training */
    L->mmean = p->moving_mean_desc; L->mvar = p->moving_variance_desc;
    (void)o1; (void)o2;
    if (normType == BNNSGroupNorm && p->num_groups && norm_geo_of(L).C % p->num_groups) ok = 0;
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerPermute(const BNNSLayerParametersPermute *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_PERMUTE, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.perm = *p;
    bn_dims di, dout; bn_dims_of(&p->i_desc, &di); bn_dims_of(&p->o_desc, &dout);
    int ok = di.rank == dout.rank, seen = 0;
    for (int k = 0; k < di.rank && ok; k++) {
        size_t q = p->permutation[k];
        if ((int)q >= di.rank || (seen >> q) & 1 || dout.n[k] != di.n[q]) ok = 0;
        seen |= 1 << q;
    }
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerDropout(const BNNSLayerParametersDropout *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_DROPOUT, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.drop = *p;
    L->rng = p->seed ? 0x9e3779b97f4a7c15ull ^ p->seed : 0x853c49e6748fea9bull;
    return finish(f, p->rate >= 0 && p->rate <= 1 && dcount(&p->i_desc) == dcount(&p->o_desc));
}
BNNSFilter BNNSFilterCreateLayerPadding(const BNNSLayerParametersPadding *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_PAD, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.pad = *p;
    bn_dims di, dout; bn_dims_of(&p->i_desc, &di); bn_dims_of(&p->o_desc, &dout);
    int ok = di.rank == dout.rank && p->padding_mode <= BNNSPaddingModeSymmetric;
    for (int k = 0; k < di.rank && ok; k++) if (dout.n[k] != di.n[k] + p->padding_size[k][0] + p->padding_size[k][1]) ok = 0;
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerResize(const BNNSLayerParametersResize *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_RESIZE, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.resize = *p;
    bn_dims di, dout; bn_dims_of(&p->i_desc, &di); bn_dims_of(&p->o_desc, &dout);
    return finish(f, di.rank == dout.rank);
}
BNNSFilter BNNSFilterCreateLayerEmbedding(const BNNSLayerParametersEmbedding *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_EMBED, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.embed = *p;
    bn_dims dd;
    int ok = p->dictionary.data && !bn_dims_of(&p->dictionary, &dd) && dd.rank == 2 &&
             dcount(&p->o_desc) == dcount(&p->i_desc) * dd.n[0] && !bn_layer_keep(f, &L->w, &p->dictionary, &L->owns_w);
    return finish(f, ok);
}
BNNSFilter BNNSFilterCreateLayerGram(const BNNSLayerParametersGram *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_GRAM, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    ((bn_layer *)f->state)->p.gram = *p;
    return finish(f, 1);
}
BNNSFilter BNNSFilterCreateLayerReduction(const BNNSLayerParametersReduction *p, const BNNSFilterParameters *fp) {
    if (!p) return NULL;
    bn_filter *f = new_with(BK_REDUCE, &p->i_desc, &p->o_desc, fp);
    if (!f) return NULL;
    bn_layer *L = f->state;
    L->p.reduce = *p;
    int ok = !p->w_desc.data || !bn_layer_keep(f, &L->w, &p->w_desc, &L->owns_w);
    return finish(f, ok);
}

/* ---- the older creators: image stacks and vectors ---- */
static BNNSNDArrayDescriptor image_desc(const BNNSImageStackDescriptor *s) {
    BNNSNDArrayDescriptor d = {0};
    d.layout = BNNSDataLayoutImageCHW;
    d.size[0] = s->width; d.size[1] = s->height; d.size[2] = s->channels;
    d.stride[0] = 1; d.stride[1] = s->row_stride ? s->row_stride : s->width;
    d.stride[2] = s->image_stride ? s->image_stride : d.stride[1] * s->height;
    d.data_type = s->data_type; d.data_scale = s->data_scale; d.data_bias = s->data_bias;
    return d;
}
static BNNSNDArrayDescriptor vector_desc(const BNNSVectorDescriptor *v) {
    BNNSNDArrayDescriptor d = {0};
    d.layout = BNNSDataLayoutVector; d.size[0] = v->size;
    d.data_type = v->data_type; d.data_scale = v->data_scale; d.data_bias = v->data_bias;
    return d;
}
static BNNSNDArrayDescriptor layer_data_desc(const BNNSLayerData *ld, BNNSDataLayout layout, size_t s0, size_t s1, size_t s2, size_t s3) {
    BNNSNDArrayDescriptor d = {0};
    d.layout = layout; d.size[0] = s0; d.size[1] = s1; d.size[2] = s2; d.size[3] = s3;
    d.data = (void *)ld->data; d.data_type = ld->data_type ? ld->data_type : BNNSDataTypeFloat32;
    d.data_scale = ld->data_scale; d.data_bias = ld->data_bias;
    if ((d.data_type & 0xff0000u) == BNNSDataTypeIndexedBit) { d.table_data = (void *)ld->data_table; d.table_data_type = BNNSDataTypeFloat32; }
    return d;
}
BNNSFilter BNNSFilterCreateConvolutionLayer(const BNNSImageStackDescriptor *in_desc, const BNNSImageStackDescriptor *out_desc,
                                            const BNNSConvolutionLayerParameters *lp, const BNNSFilterParameters *fp) {
    if (!in_desc || !out_desc || !lp) return NULL;
    BNNSLayerParametersConvolution p = {0};
    p.i_desc = image_desc(in_desc); p.o_desc = image_desc(out_desc);
    p.w_desc = layer_data_desc(&lp->weights, BNNSDataLayoutConvolutionWeightsOIHW, lp->k_width, lp->k_height, lp->in_channels, lp->out_channels);
    if (lp->bias.data) p.bias = layer_data_desc(&lp->bias, BNNSDataLayoutVector, lp->out_channels, 0, 0, 0);
    p.activation = lp->activation;
    p.x_stride = lp->x_stride; p.y_stride = lp->y_stride; p.x_padding = lp->x_padding; p.y_padding = lp->y_padding;
    return BNNSFilterCreateLayerConvolution(&p, fp);
}
BNNSFilter BNNSFilterCreateFullyConnectedLayer(const BNNSVectorDescriptor *in_desc, const BNNSVectorDescriptor *out_desc,
                                               const BNNSFullyConnectedLayerParameters *lp, const BNNSFilterParameters *fp) {
    if (!in_desc || !out_desc || !lp) return NULL;
    BNNSLayerParametersFullyConnected p = {0};
    p.i_desc = vector_desc(in_desc); p.o_desc = vector_desc(out_desc);
    /* weights[i + in_size * o] */
    p.w_desc = layer_data_desc(&lp->weights, BNNSDataLayoutRowMajorMatrix, lp->in_size, lp->out_size, 0, 0);
    if (lp->bias.data) p.bias = layer_data_desc(&lp->bias, BNNSDataLayoutVector, lp->out_size, 0, 0, 0);
    p.activation = lp->activation;
    return BNNSFilterCreateLayerFullyConnected(&p, fp);
}
BNNSFilter BNNSFilterCreatePoolingLayer(const BNNSImageStackDescriptor *in_desc, const BNNSImageStackDescriptor *out_desc,
                                        const BNNSPoolingLayerParameters *lp, const BNNSFilterParameters *fp) {
    if (!in_desc || !out_desc || !lp) return NULL;
    BNNSLayerParametersPooling p = {0};
    p.i_desc = image_desc(in_desc); p.o_desc = image_desc(out_desc);
    if (lp->bias.data) p.bias = layer_data_desc(&lp->bias, BNNSDataLayoutVector, lp->out_channels, 0, 0, 0);
    p.activation = lp->activation; p.pooling_function = lp->pooling_function;
    p.k_width = lp->k_width; p.k_height = lp->k_height; p.x_stride = lp->x_stride; p.y_stride = lp->y_stride;
    p.x_padding = lp->x_padding; p.y_padding = lp->y_padding;
    return BNNSFilterCreateLayerPooling(&p, fp);
}
BNNSFilter BNNSFilterCreateVectorActivationLayer(const BNNSVectorDescriptor *in_desc, const BNNSVectorDescriptor *out_desc,
                                                 const BNNSActivation *activation, const BNNSFilterParameters *fp) {
    if (!in_desc || !out_desc || !activation) return NULL;
    BNNSLayerParametersActivation p = {0};
    p.i_desc = vector_desc(in_desc); p.o_desc = vector_desc(out_desc); p.activation = *activation;
    return BNNSFilterCreateLayerActivation(&p, fp);
}

/* ---- direct activation ---- */
int BNNSDirectApplyActivationBatch(const BNNSLayerParametersActivation *p, const BNNSFilterParameters *fp, size_t batch_size,
                                   size_t in_stride, size_t out_stride) {
    if (!p) return -1;
    BNNSFilter f = BNNSFilterCreateLayerActivation(p, fp);
    if (!f) return -1;
    int r = BNNSFilterApplyBatch(f, batch_size, p->i_desc.data, in_stride, p->o_desc.data, out_stride);
    BNNSFilterDestroy(f);
    return r;
}
