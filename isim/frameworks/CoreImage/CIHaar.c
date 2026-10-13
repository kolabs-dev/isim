/* isim Core Image: a Viola-Jones Haar cascade evaluator for CIDetector's faces (and eyes / smiles). The cascades are
 * OpenCV's trained XML files (the host's opencv-data package); isim reads them and evaluates them with integral images
 * over an image pyramid, grouping detections the way OpenCV's groupRectangles does. */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { int x, y, w, h; float wt; } hrect;
typedef struct { int nrects; hrect r[3]; } hfeat;
typedef struct { int feat; float thr, left, right; } hweak;
typedef struct { int nweak; hweak *weak; float thr; } hstage;
typedef struct haar_cascade { int w, h, nstages, nfeats; hstage *stages; hfeat *feats; } haar_cascade;

static char *slurp(const char *path, long *len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = n > 0 ? malloc((size_t)n + 1) : NULL;
    if (b && fread(b, 1, (size_t)n, f) != (size_t)n) { free(b); b = NULL; }
    if (b) b[n] = 0;
    fclose(f);
    if (len) *len = n;
    return b;
}
static const char *after(const char *p, const char *tag) { const char *q = p ? strstr(p, tag) : NULL; return q ? q + strlen(tag) : NULL; }
void haar_free(haar_cascade *c) {
    if (!c) return;
    for (int i = 0; i < c->nstages; i++) free(c->stages[i].weak);
    free(c->stages); free(c->feats); free(c);
}
haar_cascade *haar_load(const char *path) {
    char *s = slurp(path, NULL);
    if (!s) return NULL;
    haar_cascade *c = calloc(1, sizeof *c);
    const char *p = strstr(s, "<cascade");
    if (!p || !strstr(p, "<featureType>HAAR")) { free(s); free(c); return NULL; }
    const char *q;
    if ((q = after(p, "<height>"))) c->h = atoi(q);
    if ((q = after(p, "<width>"))) c->w = atoi(q);
    if ((q = after(p, "<stageNum>"))) c->nstages = atoi(q);
    if (c->w <= 0 || c->h <= 0 || c->nstages <= 0 || strstr(p, "<tilted>1")) { free(s); free(c); return NULL; }
    c->stages = calloc((size_t)c->nstages, sizeof(hstage));
    const char *st = after(p, "<stages>");
    for (int i = 0; i < c->nstages && st; i++) {
        hstage *g = &c->stages[i];
        st = after(st, "<maxWeakCount>"); if (!st) break;
        g->nweak = atoi(st);
        st = after(st, "<stageThreshold>"); if (!st) break;
        g->thr = strtof(st, NULL);
        g->weak = calloc((size_t)g->nweak, sizeof(hweak));
        for (int k = 0; k < g->nweak && st; k++) {
            st = after(st, "<internalNodes>"); if (!st) break;
            char *e; strtol(st, &e, 10); strtol(e, &e, 10);
            g->weak[k].feat = (int)strtol(e, &e, 10);
            g->weak[k].thr = strtof(e, &e);
            st = after(st, "<leafValues>"); if (!st) break;
            g->weak[k].left = strtof(st, &e); g->weak[k].right = strtof(e, &e);
        }
    }
    /* features */
    const char *fs = after(p, "<features>");
    int cap = 0;
    while (fs) {
        const char *r = strstr(fs, "<rects>"); if (!r) break;
        const char *re = strstr(r, "</rects>"); if (!re) break;
        if (c->nfeats == cap) { cap = cap ? cap * 2 : 1024; c->feats = realloc(c->feats, sizeof(hfeat) * (size_t)cap); }
        hfeat *f = &c->feats[c->nfeats++]; memset(f, 0, sizeof *f);
        const char *x = r + 7;
        while (f->nrects < 3) {
            const char *u = strstr(x, "<_>"); if (!u || u > re) break;
            char *e;
            hrect *h = &f->r[f->nrects++];
            h->x = (int)strtol(u + 3, &e, 10); h->y = (int)strtol(e, &e, 10); h->w = (int)strtol(e, &e, 10); h->h = (int)strtol(e, &e, 10);
            h->wt = strtof(e, &e);
            x = e;
        }
        fs = re + 8;
    }
    free(s);
    for (int i = 0; i < c->nstages; i++) for (int k = 0; k < c->stages[i].nweak; k++)
        if (c->stages[i].weak[k].feat < 0 || c->stages[i].weak[k].feat >= c->nfeats) { haar_free(c); return NULL; }
    return c;
}
int haar_window_size(const haar_cascade *c, int *w, int *h) { *w = c->w; *h = c->h; return 1; }

/* ---- detection ---- */
typedef struct { double *sum, *sq; int w, h; } integral;   /* (w+1) x (h+1) */
static void integral_of(const float *g, int w, int h, integral *I) {
    I->w = w; I->h = h;
    I->sum = calloc((size_t)(w + 1) * (h + 1), sizeof(double)); I->sq = calloc((size_t)(w + 1) * (h + 1), sizeof(double));
    for (int y = 0; y < h; y++) {
        double rs = 0, rq = 0;
        for (int x = 0; x < w; x++) {
            double v = g[(size_t)y * w + x]; rs += v; rq += v * v;
            I->sum[(size_t)(y + 1) * (w + 1) + x + 1] = I->sum[(size_t)y * (w + 1) + x + 1] + rs;
            I->sq[(size_t)(y + 1) * (w + 1) + x + 1] = I->sq[(size_t)y * (w + 1) + x + 1] + rq;
        }
    }
}
static double rsum(const double *t, int W, int x, int y, int w, int h) {
    return t[(size_t)(y + h) * W + x + w] - t[(size_t)y * W + x + w] - t[(size_t)(y + h) * W + x] + t[(size_t)y * W + x];
}
static int eval_window(const haar_cascade *c, const integral *I, int x, int y) {
    int W = I->w + 1;
    int nw = c->w - 2, nh = c->h - 2;
    double s = rsum(I->sum, W, x + 1, y + 1, nw, nh), q = rsum(I->sq, W, x + 1, y + 1, nw, nh);
    double nf = (double)nw * nh * q - s * s;
    nf = nf > 0 ? sqrt(nf) : 1;
    for (int i = 0; i < c->nstages; i++) {
        const hstage *g = &c->stages[i];
        double acc = 0;
        for (int k = 0; k < g->nweak; k++) {
            const hweak *wk = &g->weak[k];
            const hfeat *f = &c->feats[wk->feat];
            double v = 0;
            for (int r = 0; r < f->nrects; r++) v += f->r[r].wt * rsum(I->sum, W, x + f->r[r].x, y + f->r[r].y, f->r[r].w, f->r[r].h);
            acc += v < wk->thr * nf ? wk->left : wk->right;
        }
        if (acc < g->thr) return 0;
    }
    return 1;
}
static float *resize(const float *g, int w, int h, int nw, int nh) {
    float *o = malloc(sizeof(float) * (size_t)nw * nh);
    double sx = (double)w / nw, sy = (double)h / nh;
    for (int y = 0; y < nh; y++) for (int x = 0; x < nw; x++) {
        double fx = (x + 0.5) * sx - 0.5, fy = (y + 0.5) * sy - 0.5;
        int x0 = (int)floor(fx), y0 = (int)floor(fy); double ax = fx - x0, ay = fy - y0;
        int x1 = x0 + 1, y1 = y0 + 1;
        x0 = x0 < 0 ? 0 : x0 >= w ? w - 1 : x0; x1 = x1 < 0 ? 0 : x1 >= w ? w - 1 : x1;
        y0 = y0 < 0 ? 0 : y0 >= h ? h - 1 : y0; y1 = y1 < 0 ? 0 : y1 >= h ? h - 1 : y1;
        o[(size_t)y * nw + x] = (float)((g[(size_t)y0 * w + x0] * (1 - ax) + g[(size_t)y0 * w + x1] * ax) * (1 - ay) + (g[(size_t)y1 * w + x0] * (1 - ax) + g[(size_t)y1 * w + x1] * ax) * ay);
    }
    return o;
}
static int find(int *p, int i) { while (p[i] != i) i = p[i] = p[p[i]]; return i; }
/* gray: 0...255 floats, top-down rows. Writes x, y, w, h, neighbors per detection; returns the count */
int haar_detect(const haar_cascade *c, const float *gray, int w, int h, double scaleFactor, int minNeighbors, int minSize, int *out, int maxOut) {
    int cap = 4096, n = 0;
    int *raw = malloc(sizeof(int) * 4 * (size_t)cap);
    if (scaleFactor <= 1.01) scaleFactor = 1.1;
    for (double f = 1; ; f *= scaleFactor) {
        int sw = (int)lround(w / f), sh = (int)lround(h / f);
        if (sw < c->w || sh < c->h) break;
        if (c->w * f < minSize) continue;
        float *g = f == 1 ? NULL : resize(gray, w, h, sw, sh);
        integral I; integral_of(g ? g : gray, sw, sh, &I);
        int step = f > 2 ? 1 : 2;
        for (int y = 0; y + c->h <= sh; y += step)
            for (int x = 0; x + c->w <= sw; x += step)
                if (eval_window(c, &I, x, y)) {
                    if (n == cap) { cap *= 2; raw = realloc(raw, sizeof(int) * 4 * (size_t)cap); }
                    raw[n * 4] = (int)lround(x * f); raw[n * 4 + 1] = (int)lround(y * f); raw[n * 4 + 2] = (int)lround(c->w * f); raw[n * 4 + 3] = (int)lround(c->h * f);
                    n++;
                }
        free(I.sum); free(I.sq); free(g);
    }
    /* group similar rectangles (eps 0.2), keep groups with more than minNeighbors members */
    int *parent = malloc(sizeof(int) * (size_t)(n ? n : 1));
    for (int i = 0; i < n; i++) parent[i] = i;
    for (int i = 0; i < n; i++) for (int j = i + 1; j < n; j++) {
        int *a = raw + i * 4, *b = raw + j * 4;
        double d = 0.2 * (fmin(a[2], b[2]) + fmin(a[3], b[3])) * 0.5;
        if (abs(a[0] - b[0]) <= d && abs(a[1] - b[1]) <= d && abs(a[0] + a[2] - b[0] - b[2]) <= d && abs(a[1] + a[3] - b[1] - b[3]) <= d)
            parent[find(parent, i)] = find(parent, j);
    }
    double *acc = calloc((size_t)(n ? n : 1) * 5, sizeof(double));
    for (int i = 0; i < n; i++) { int r = find(parent, i); for (int k = 0; k < 4; k++) acc[r * 5 + k] += raw[i * 4 + k]; acc[r * 5 + 4] += 1; }
    int m = 0;
    int *cand = malloc(sizeof(int) * 5 * (size_t)(n ? n : 1)), nc = 0;
    for (int i = 0; i < n; i++) if (acc[i * 5 + 4] > 0) {
        double k = acc[i * 5 + 4];
        for (int q = 0; q < 4; q++) cand[nc * 5 + q] = (int)lround(acc[i * 5 + q] / k);
        cand[nc * 5 + 4] = (int)k; nc++;
    }
    for (int i = 0; i < nc && m < maxOut; i++) {
        int *r1 = cand + i * 5, n1 = r1[4];
        if (n1 <= minNeighbors) continue;
        int inside = 0;
        for (int j = 0; j < nc && !inside; j++) {
            int *r2 = cand + j * 5, n2 = r2[4];
            if (j == i || n2 <= minNeighbors) continue;
            int dx = (int)lround(r2[2] * 0.2), dy = (int)lround(r2[3] * 0.2);
            if (r1[0] >= r2[0] - dx && r1[1] >= r2[1] - dy && r1[0] + r1[2] <= r2[0] + r2[2] + dx && r1[1] + r1[3] <= r2[1] + r2[3] + dy && (n2 > (n1 > 3 ? n1 : 3) || n1 < 3)) inside = 1;
        }
        if (inside) continue;
        memcpy(out + m * 5, r1, sizeof(int) * 5); m++;
    }
    free(raw); free(parent); free(acc); free(cand);
    for (int i = 1; i < m; i++)            /* strongest (most neighbors) first */
        for (int j = i; j > 0 && out[j * 5 + 4] > out[(j - 1) * 5 + 4]; j--)
            for (int k = 0; k < 5; k++) { int t = out[j * 5 + k]; out[j * 5 + k] = out[(j - 1) * 5 + k]; out[(j - 1) * 5 + k] = t; }
    return m;
}
