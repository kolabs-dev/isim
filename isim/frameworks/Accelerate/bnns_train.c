// isim Accelerate BNNS (issue #808): optimizers (SGD with momentum, Adam / AdamW / AMSGrad, RMSProp, with clipping), the
// random generator and k-nearest neighbors.
#include "bnns_core.h"
#include <stdint.h>

/* ---- optimizers ---- */
typedef struct {
    float lr, gscale, rscale, cmin, cmax, max_norm, use_norm;
    BNNSOptimizerRegularizationFunction reg;
    BNNSOptimizerClippingFunction clip;
} opt_common;

static float regularize(const opt_common *c, float w) {
    if (c->reg == BNNSOptimizerRegularizationL1) return c->rscale * (w > 0 ? 1.0f : (w < 0 ? -1.0f : 0.0f));
    if (c->reg == BNNSOptimizerRegularizationL2) return c->rscale * w;
    return 0;
}
/* the gradients after scaling and clipping (one dense buffer per parameter) */
static float **prepare_gradients(const opt_common *c, size_t np, const BNNSNDArrayDescriptor **grads, size_t *counts) {
    float **g = calloc(np + 1, sizeof(float *));
    if (!g) return NULL;
    double global = 0;
    for (size_t p = 0; p < np; p++) {
        bn_dims d;
        g[p] = bn_load(grads[p], NULL, &d);
        if (!g[p]) { for (size_t q = 0; q < p; q++) free(g[q]); free(g); return NULL; }
        counts[p] = d.count;
        for (size_t i = 0; i < d.count; i++) { g[p][i] *= c->gscale; global += (double)g[p][i] * g[p][i]; }
    }
    if (c->clip == BNNSOptimizerClippingByValue)
        for (size_t p = 0; p < np; p++) for (size_t i = 0; i < counts[p]; i++) g[p][i] = fminf(fmaxf(g[p][i], c->cmin), c->cmax);
    else if (c->clip == BNNSOptimizerClippingByNorm)
        for (size_t p = 0; p < np; p++) {
            double n = 0;
            for (size_t i = 0; i < counts[p]; i++) n += (double)g[p][i] * g[p][i];
            n = sqrt(n);
            if (n > c->max_norm) for (size_t i = 0; i < counts[p]; i++) g[p][i] *= (float)(c->max_norm / n);
        }
    else if (c->clip == BNNSOptimizerClippingByGlobalNorm) {
        double n = c->use_norm ? c->use_norm : sqrt(global);
        if (n > c->max_norm) for (size_t p = 0; p < np; p++) for (size_t i = 0; i < counts[p]; i++) g[p][i] *= (float)(c->max_norm / n);
    }
    return g;
}
static float *acc_load(BNNSNDArrayDescriptor *const *acc, size_t k, size_t n) {
    if (!acc || !acc[k]) return NULL;
    bn_dims d;
    float *v = bn_load(acc[k], NULL, &d);
    if (v && d.count != n) { free(v); return NULL; }
    return v;
}
int BNNSOptimizerStep(BNNSOptimizerFunction function, const void *fields, size_t np, BNNSNDArrayDescriptor **parameters,
                      const BNNSNDArrayDescriptor **gradients, BNNSNDArrayDescriptor **accumulators, const BNNSFilterParameters *fp) {
    (void)fp;
    if (!fields || !parameters || !gradients) return -1;
    opt_common c = {0};
    int clipping = function >= BNNSOptimizerFunctionSGDMomentumWithClipping;
    BNNSOptimizerFunction base = clipping ? (BNNSOptimizerFunction)(function - 6) : function;
    /* the fields: each "with clipping" structure replaces the clip flag with a clipping function */
    float momentum = 0, beta1 = 0, beta2 = 0, t = 1, eps = 0, alpha = 0; bool nesterov = false, centered = false;
    BNNSOptimizerSGDMomentumVariant variant = BNNSSGDMomentumVariant0;
    switch (function) {
    case BNNSOptimizerFunctionSGDMomentum: {
        const BNNSOptimizerSGDMomentumFields *f = fields;
        c.lr = f->learning_rate; momentum = f->momentum; c.gscale = f->gradient_scale; c.rscale = f->regularization_scale;
        if (f->clip_gradients) { c.clip = BNNSOptimizerClippingByValue; c.cmin = f->clip_gradients_min; c.cmax = f->clip_gradients_max; }
        nesterov = f->nesterov; c.reg = f->regularization_func; variant = f->sgd_momentum_variant;
        break;
    }
    case BNNSOptimizerFunctionSGDMomentumWithClipping: {
        const BNNSOptimizerSGDMomentumWithClippingFields *f = fields;
        c.lr = f->learning_rate; momentum = f->momentum; c.gscale = f->gradient_scale; c.rscale = f->regularization_scale;
        nesterov = f->nesterov; c.reg = f->regularization_func; variant = f->sgd_momentum_variant;
        c.clip = f->clipping_func; c.cmin = f->clip_gradients_min; c.cmax = f->clip_gradients_max;
        c.max_norm = f->clip_gradients_max_norm; c.use_norm = f->clip_gradients_use_norm;
        break;
    }
    case BNNSOptimizerFunctionAdam: case BNNSOptimizerFunctionAdamW: case BNNSOptimizerFunctionAdamAMSGrad: case BNNSOptimizerFunctionAdamWAMSGrad: {
        const BNNSOptimizerAdamFields *f = fields;
        c.lr = f->learning_rate; beta1 = f->beta1; beta2 = f->beta2; t = f->time_step; eps = f->epsilon;
        c.gscale = f->gradient_scale; c.rscale = f->regularization_scale; c.reg = f->regularization_func;
        if (f->clip_gradients) { c.clip = BNNSOptimizerClippingByValue; c.cmin = f->clip_gradients_min; c.cmax = f->clip_gradients_max; }
        break;
    }
    case BNNSOptimizerFunctionAdamWithClipping: case BNNSOptimizerFunctionAdamWWithClipping:
    case BNNSOptimizerFunctionAdamAMSGradWithClipping: case BNNSOptimizerFunctionAdamWAMSGradWithClipping: {
        const BNNSOptimizerAdamWithClippingFields *f = fields;
        c.lr = f->learning_rate; beta1 = f->beta1; beta2 = f->beta2; t = f->time_step; eps = f->epsilon;
        c.gscale = f->gradient_scale; c.rscale = f->regularization_scale; c.reg = f->regularization_func;
        c.clip = f->clipping_func; c.cmin = f->clip_gradients_min; c.cmax = f->clip_gradients_max;
        c.max_norm = f->clip_gradients_max_norm; c.use_norm = f->clip_gradients_use_norm;
        break;
    }
    case BNNSOptimizerFunctionRMSProp: {
        const BNNSOptimizerRMSPropFields *f = fields;
        c.lr = f->learning_rate; alpha = f->alpha; eps = f->epsilon; centered = f->centered; momentum = f->momentum;
        c.gscale = f->gradient_scale; c.rscale = f->regularization_scale; c.reg = f->regularization_func;
        if (f->clip_gradients) { c.clip = BNNSOptimizerClippingByValue; c.cmin = f->clip_gradients_min; c.cmax = f->clip_gradients_max; }
        break;
    }
    case BNNSOptimizerFunctionRMSPropWithClipping: {
        const BNNSOptimizerRMSPropWithClippingFields *f = fields;
        c.lr = f->learning_rate; alpha = f->alpha; eps = f->epsilon; centered = f->centered; momentum = f->momentum;
        c.gscale = f->gradient_scale; c.rscale = f->regularization_scale; c.reg = f->regularization_func;
        c.clip = f->clipping_func; c.cmin = f->clip_gradients_min; c.cmax = f->clip_gradients_max;
        c.max_norm = f->clip_gradients_max_norm; c.use_norm = f->clip_gradients_use_norm;
        break;
    }
    default: return -1;
    }
    size_t *counts = calloc(np + 1, sizeof(size_t));
    float **g = counts ? prepare_gradients(&c, np, gradients, counts) : NULL;
    if (!g) { free(counts); return -1; }
    int decoupled = base == BNNSOptimizerFunctionAdamW || base == BNNSOptimizerFunctionAdamWAMSGrad;
    int amsgrad = base == BNNSOptimizerFunctionAdamAMSGrad || base == BNNSOptimizerFunctionAdamWAMSGrad;
    int r = 0;
    for (size_t p = 0; p < np && !r; p++) {
        bn_dims d;
        float *w = bn_load(parameters[p], NULL, &d);
        size_t n = counts[p];
        if (!w || d.count != n) { free(w); r = -1; break; }
        float *a0 = NULL, *a1 = NULL, *a2 = NULL;
        switch (base) {
        case BNNSOptimizerFunctionSGDMomentum: {
            if (momentum != 0) { a0 = acc_load(accumulators, p, n); if (!a0) { r = -1; break; } }
            for (size_t i = 0; i < n; i++) {
                float gi = g[p][i] + regularize(&c, w[i]);
                if (momentum == 0) { w[i] -= c.lr * gi; continue; }
                float v0 = a0[i], v1;
                switch (variant) {
                case BNNSSGDMomentumVariant1:
                    v1 = momentum * v0 + gi;
                    w[i] -= (nesterov ? momentum * v1 + gi : v1) * c.lr; break;
                case BNNSSGDMomentumVariant2:
                    if (nesterov) { v1 = momentum * v0 + gi; w[i] -= c.lr * (gi + v1 * momentum); }
                    else { v1 = momentum * v0 + c.lr * gi; w[i] -= v1; }
                    break;
                default:
                    v1 = momentum * v0 - gi * c.lr;
                    w[i] += nesterov ? v1 + momentum * (v1 - v0) : v1; break;
                }
                a0[i] = v1;
            }
            if (!r && a0) r = bn_store(accumulators[p], NULL, a0, 0);
            break;
        }
        case BNNSOptimizerFunctionAdam: case BNNSOptimizerFunctionAdamW:
        case BNNSOptimizerFunctionAdamAMSGrad: case BNNSOptimizerFunctionAdamWAMSGrad: {
            a0 = acc_load(accumulators, p, n); a1 = acc_load(accumulators, np + p, n);
            if (amsgrad) a2 = acc_load(accumulators, 2 * np + p, n);
            if (!a0 || !a1 || (amsgrad && !a2)) { r = -1; break; }
            double lr_t = c.lr * sqrt(1 - pow(beta2, t)) / (1 - pow(beta1, t));
            for (size_t i = 0; i < n; i++) {
                float gi = g[p][i] + (decoupled ? 0 : regularize(&c, w[i]));
                a0[i] = beta1 * a0[i] + (1 - beta1) * gi;
                a1[i] = beta2 * a1[i] + (1 - beta2) * gi * gi;
                float v = a1[i];
                if (amsgrad) { if (a1[i] > a2[i]) a2[i] = a1[i]; v = a2[i]; }
                if (decoupled) w[i] -= c.lr * c.rscale * w[i];
                w[i] -= (float)(lr_t * a0[i] / (sqrt(v) + eps));
            }
            r = bn_store(accumulators[p], NULL, a0, 0);
            if (!r) r = bn_store(accumulators[np + p], NULL, a1, 0);
            if (!r && amsgrad) r = bn_store(accumulators[2 * np + p], NULL, a2, 0);
            break;
        }
        case BNNSOptimizerFunctionRMSProp: {
            size_t k = 0, kn = k++, kg = centered ? k++ : 0, km = momentum != 0 ? k++ : 0;
            a0 = acc_load(accumulators, kn * np + p, n);
            if (centered) a1 = acc_load(accumulators, kg * np + p, n);
            if (momentum != 0) a2 = acc_load(accumulators, km * np + p, n);
            if (!a0 || (centered && !a1) || (momentum != 0 && !a2)) { r = -1; break; }
            for (size_t i = 0; i < n; i++) {
                float gi = g[p][i] + regularize(&c, w[i]);
                a0[i] = alpha * a0[i] + (1 - alpha) * gi * gi;
                float den = a0[i];
                if (centered) { a1[i] = alpha * a1[i] + (1 - alpha) * gi; den -= a1[i] * a1[i]; }
                float step = c.lr * gi / (sqrtf(fmaxf(den, 0)) + eps);
                if (momentum != 0) { a2[i] = momentum * a2[i] - step; w[i] += a2[i]; }
                else w[i] -= step;
            }
            r = bn_store(accumulators[kn * np + p], NULL, a0, 0);
            if (!r && centered) r = bn_store(accumulators[kg * np + p], NULL, a1, 0);
            if (!r && momentum != 0) r = bn_store(accumulators[km * np + p], NULL, a2, 0);
            break;
        }
        default: r = -1; break;
        }
        if (!r) r = bn_store(parameters[p], NULL, w, 0);
        free(w); free(a0); free(a1); free(a2);
    }
    for (size_t p = 0; p < np; p++) free(g[p]);
    free(g); free(counts);
    return r;
}

/* ---- random generator (isim's own stream: xoshiro256**, not Apple's AES-CTR, so values differ from Apple's) ---- */
typedef struct { uint32_t magic; uint32_t method; uint64_t s[4]; int have_spare; float spare; } bn_rng;
#define BN_RNG_MAGIC 0x524e4721u
static uint64_t splitmix(uint64_t *x) {
    uint64_t z = (*x += 0x9e3779b97f4a7c15ull);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ull; z = (z ^ (z >> 27)) * 0x94d049bb133111ebull;
    return z ^ (z >> 31);
}
static uint64_t rotl(uint64_t x, int k) { return (x << k) | (x >> (64 - k)); }
static uint64_t rng_u64(bn_rng *g) {
    uint64_t *s = g->s, r = rotl(s[1] * 5, 7) * 9, t = s[1] << 17;
    s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3]; s[2] ^= t; s[3] = rotl(s[3], 45);
    return r;
}
static double rng_unit(bn_rng *g) { return (double)(rng_u64(g) >> 11) * (1.0 / 9007199254740992.0); }
static bn_rng *rng_of(BNNSRandomGenerator p) { bn_rng *g = p; return g && g->magic == BN_RNG_MAGIC ? g : NULL; }
BNNSRandomGenerator BNNSCreateRandomGeneratorWithSeed(BNNSRandomGeneratorMethod method, uint64_t seed, const BNNSFilterParameters *fp) {
    if (method != BNNSRandomGeneratorMethodAES_CTR) return NULL;
    bn_rng *g = bn_alloc(fp, sizeof(bn_rng));
    if (!g) return NULL;
    g->magic = BN_RNG_MAGIC; g->method = method;
    uint64_t x = seed;
    for (int k = 0; k < 4; k++) g->s[k] = splitmix(&x);
    return g;
}
BNNSRandomGenerator BNNSCreateRandomGenerator(BNNSRandomGeneratorMethod method, const BNNSFilterParameters *fp) {
    uint64_t seed;
    arc4random_buf(&seed, sizeof seed);
    return BNNSCreateRandomGeneratorWithSeed(method, seed, fp);
}
void BNNSDestroyRandomGenerator(BNNSRandomGenerator generator) {
    bn_rng *g = rng_of(generator);
    if (g) { g->magic = 0; free(g); }
}
size_t BNNSRandomGeneratorStateSize(BNNSRandomGenerator generator) { return rng_of(generator) ? sizeof(bn_rng) : 0; }
int BNNSRandomGeneratorGetState(BNNSRandomGenerator generator, size_t state_size, void *state) {
    bn_rng *g = rng_of(generator);
    if (!g || !state || state_size < sizeof(bn_rng)) return -1;
    memcpy(state, g, sizeof(bn_rng));
    return 0;
}
int BNNSRandomGeneratorSetState(BNNSRandomGenerator generator, size_t state_size, void *state) {
    bn_rng *g = rng_of(generator);
    if (!g || !state || state_size < sizeof(bn_rng) || ((bn_rng *)state)->magic != BN_RNG_MAGIC) return -1;
    memcpy(g, state, sizeof(bn_rng));
    return 0;
}
static int fill(bn_rng *g, BNNSNDArrayDescriptor *desc, int kind, double a, double b) {
    bn_dims d;
    if (!g || !desc || bn_dims_of(desc, &d)) return -1;
    int fl = bn_type_is_float(desc->data_type);
    if ((kind == 1) == fl && kind != 3) return -1;   /* uniform int needs an integer type; the float fills a float type */
    float *v = malloc(d.count * sizeof(float) + 1);
    if (!v) return -1;
    for (size_t i = 0; i < d.count; i++) {
        switch (kind) {
        case 0: v[i] = (float)(a + (b - a) * rng_unit(g)); break;
        case 1: v[i] = (float)(a + floor(rng_unit(g) * (b - a + 1))); break;
        default: {   /* normal (Box-Muller) */
            double u1 = rng_unit(g), u2 = rng_unit(g);
            if (u1 < 1e-300) u1 = 1e-300;
            v[i] = (float)(a + b * sqrt(-2 * log(u1)) * cos(2 * M_PI * u2));
        }
        }
    }
    int r = bn_store(desc, NULL, v, 0);
    free(v);
    return r;
}
int BNNSRandomFillUniformFloat(BNNSRandomGenerator generator, BNNSNDArrayDescriptor *desc, float a, float b) {
    return fill(rng_of(generator), desc, 0, a, b);
}
int BNNSRandomFillUniformInt(BNNSRandomGenerator generator, BNNSNDArrayDescriptor *desc, int64_t a, int64_t b) {
    if (b < a) return -1;
    return fill(rng_of(generator), desc, 1, (double)a, (double)b);
}
int BNNSRandomFillNormalFloat(BNNSRandomGenerator generator, BNNSNDArrayDescriptor *desc, float mean, float stddev) {
    return fill(rng_of(generator), desc, 2, mean, stddev);
}
int BNNSRandomFillCategoricalFloat(BNNSRandomGenerator generator, const BNNSNDArrayDescriptor *desc,
                                   const BNNSNDArrayDescriptor *probabilities, bool log_probabilities) {
    bn_rng *g = rng_of(generator);
    bn_dims dd, dp;
    if (!g || !desc || !probabilities || bn_dims_of(desc, &dd) || bn_dims_of(probabilities, &dp) || dd.rank != dp.rank) return -1;
    int r1 = dp.rank - 1;
    size_t K = dp.n[r1], S = dd.n[r1];
    for (int k = 0; k < r1; k++) if (dd.n[k] != dp.n[k]) return -1;
    float *p = bn_load(probabilities, NULL, NULL), *o = malloc(dd.count * sizeof(float) + 1);
    if (!p || !o) { free(p); free(o); return -1; }
    size_t batch = K ? dp.count / K : 0, cb = 1;
    for (int k = 0; k < r1; k++) cb *= dp.n[k];
    (void)cb;
    /* canonical order: dimension 0 fastest, so the innermost (last logical) dimension is the slowest */
    double *w = malloc((K + 1) * sizeof(double));
    for (size_t bi = 0; bi < batch; bi++) {
        double tot = 0, mx = -INFINITY;
        if (log_probabilities) for (size_t k = 0; k < K; k++) if (p[bi + k * batch] > mx) mx = p[bi + k * batch];
        for (size_t k = 0; k < K; k++) {
            double x = p[bi + k * batch];
            w[k] = log_probabilities ? exp(x - mx) : (x > 0 ? x : 0);
            tot += w[k];
        }
        for (size_t s = 0; s < S; s++) {
            double u = rng_unit(g) * tot, c = 0; size_t k = 0;
            for (; k + 1 < K; k++) { c += w[k]; if (u < c) break; }
            o[bi + s * batch] = (float)k;
        }
    }
    int r = bn_store(desc, NULL, o, 0);
    free(p); free(o); free(w);
    return r;
}

/* ---- k-nearest neighbors (Euclidean distance, brute force) ---- */
typedef struct { uint32_t magic; unsigned max_n, nf, k, n; BNNSDataType type; float *data; } bn_knn;
#define BN_KNN_MAGIC 0x4b4e4e21u
static bn_knn *knn_of(BNNSNearestNeighbors p) { bn_knn *k = p; return k && k->magic == BN_KNN_MAGIC ? k : NULL; }
BNNSNearestNeighbors BNNSCreateNearestNeighbors(const unsigned int max_n_samples, const unsigned int n_features,
                                                const unsigned int n_neighbors, const BNNSDataType data_type,
                                                const BNNSFilterParameters *fp) {
    if (!max_n_samples || !n_features || !n_neighbors) return NULL;
    if (data_type != BNNSDataTypeFloat32 && data_type != BNNSDataTypeFloat16) return NULL;
    bn_knn *k = bn_alloc(fp, sizeof(bn_knn));
    if (!k) return NULL;
    k->data = calloc((size_t)max_n_samples * n_features, sizeof(float));
    if (!k->data) { free(k); return NULL; }
    k->magic = BN_KNN_MAGIC; k->max_n = max_n_samples; k->nf = n_features; k->k = n_neighbors; k->type = data_type;
    return k;
}
void BNNSDestroyNearestNeighbors(BNNSNearestNeighbors knn) {
    bn_knn *k = knn_of(knn);
    if (k) { k->magic = 0; free(k->data); free(k); }
}
int BNNSNearestNeighborsLoad(BNNSNearestNeighbors knn, const unsigned int n_new_samples, const void *data_ptr) {
    bn_knn *k = knn_of(knn);
    if (!k || !data_ptr || (size_t)k->n + n_new_samples > k->max_n) return -1;
    BNNSNDArrayDescriptor d = {0};
    d.layout = BNNSDataLayoutVector; d.size[0] = (size_t)n_new_samples * k->nf; d.data_type = k->type;
    float *v = bn_load(&d, data_ptr, NULL);
    if (!v) return -1;
    memcpy(k->data + (size_t)k->n * k->nf, v, d.size[0] * sizeof(float));
    k->n += n_new_samples;
    free(v);
    return 0;
}
static void knn_one(bn_knn *k, unsigned s, int *idx, float *dist) {
    for (unsigned j = 0; j < k->k; j++) { idx[j] = -1; dist[j] = INFINITY; }
    const float *a = k->data + (size_t)s * k->nf;
    for (unsigned q = 0; q < k->n; q++) {
        if (q == s) continue;
        const float *b = k->data + (size_t)q * k->nf;
        double d2 = 0;
        for (unsigned f = 0; f < k->nf; f++) { double t = (double)a[f] - b[f]; d2 += t * t; }
        float d = (float)sqrt(d2);
        if (!(d < dist[k->k - 1])) continue;
        unsigned p = k->k - 1;
        while (p > 0 && d < dist[p - 1]) { dist[p] = dist[p - 1]; idx[p] = idx[p - 1]; p--; }
        dist[p] = d; idx[p] = (int)q;
    }
}
int BNNSNearestNeighborsGetInfo(const BNNSNearestNeighbors knn, const int sample_number, int *indices, void *distances) {
    bn_knn *k = knn_of(knn);
    if (!k || sample_number >= (int)k->n) return -1;
    unsigned first = sample_number < 0 ? 0 : (unsigned)sample_number, last = sample_number < 0 ? k->n : first + 1;
    int *ix = malloc(k->k * sizeof(int)); float *ds = malloc(k->k * sizeof(float));
    if (!ix || !ds) { free(ix); free(ds); return -1; }
    BNNSNDArrayDescriptor dd = {0};
    dd.layout = BNNSDataLayoutVector; dd.size[0] = k->k; dd.data_type = k->type;
    for (unsigned s = first; s < last; s++) {
        knn_one(k, s, ix, ds);
        size_t row = (size_t)(s - first) * k->k;
        if (indices) memcpy(indices + row, ix, k->k * sizeof(int));
        if (distances) bn_store(&dd, (char *)distances + bn_bytes(&dd, row), ds, 0);
    }
    free(ix); free(ds);
    return 0;
}
