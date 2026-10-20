/* isim CoreGraphics: path operations (issue #273), isim's own geometry (adapted; cairo has no stroke-to-path or boolean
 * operations). Curves are flattened first, so results are polygons that fill and hit-test like Apple's.
 * - Boolean operations: every edge of both paths is split where another crosses it; an edge is kept when the result
 *   (from both paths' winding numbers at points just left and right of it, under the fill rule) is inside on one side
 *   only, oriented with the inside on its left, and the kept edges are chained into closed loops (winding rule).
 * - Stroking: the union of each segment's band, each join and each cap.
 * - Dashing: the pattern walked along the flattened path. */
#include "cg_internal.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct { double x, y; } pt;
typedef struct { pt *p; int n, cap, closed; } poly;
typedef struct { poly *v; int n, cap; } polys;
static void poly_add(poly *a, pt q) {
    if (a->n && fabs(a->p[a->n - 1].x - q.x) < 1e-12 && fabs(a->p[a->n - 1].y - q.y) < 1e-12) return;
    if (a->n == a->cap) { a->cap = a->cap ? a->cap * 2 : 16; a->p = realloc(a->p, sizeof *a->p * (size_t)a->cap); }
    a->p[a->n++] = q;
}
static poly *polys_new(polys *s) {
    if (s->n == s->cap) { s->cap = s->cap ? s->cap * 2 : 8; s->v = realloc(s->v, sizeof *s->v * (size_t)s->cap); }
    memset(&s->v[s->n], 0, sizeof *s->v);
    return &s->v[s->n++];
}
static void polys_free(polys *s) { for (int i = 0; i < s->n; i++) free(s->v[i].p); free(s->v); memset(s, 0, sizeof *s); }

/* ---------------- flattening ---------------- */
static void flat_quad(poly *a, pt p0, pt p1, pt p2, double tol, int depth) {
    double dx = p0.x - 2 * p1.x + p2.x, dy = p0.y - 2 * p1.y + p2.y;
    if (depth > 16 || dx * dx + dy * dy <= 16 * tol * tol) { poly_add(a, p2); return; }
    pt a1 = { (p0.x + p1.x) / 2, (p0.y + p1.y) / 2 }, b1 = { (p1.x + p2.x) / 2, (p1.y + p2.y) / 2 }, m = { (a1.x + b1.x) / 2, (a1.y + b1.y) / 2 };
    flat_quad(a, p0, a1, m, tol, depth + 1);
    flat_quad(a, m, b1, p2, tol, depth + 1);
}
static void flat_cubic(poly *a, pt p0, pt p1, pt p2, pt p3, double tol, int depth) {
    double ux = 3 * p1.x - 2 * p0.x - p3.x, uy = 3 * p1.y - 2 * p0.y - p3.y, vx = 3 * p2.x - 2 * p3.x - p0.x, vy = 3 * p2.y - 2 * p3.y - p0.y;
    double d = fmax(ux * ux, vx * vx) + fmax(uy * uy, vy * vy);       /* the flatness bound of the curve */
    if (depth > 16 || d <= 16 * tol * tol) { poly_add(a, p3); return; }
    pt p01 = { (p0.x + p1.x) / 2, (p0.y + p1.y) / 2 }, p12 = { (p1.x + p2.x) / 2, (p1.y + p2.y) / 2 }, p23 = { (p2.x + p3.x) / 2, (p2.y + p3.y) / 2 };
    pt a2 = { (p01.x + p12.x) / 2, (p01.y + p12.y) / 2 }, b2 = { (p12.x + p23.x) / 2, (p12.y + p23.y) / 2 }, m = { (a2.x + b2.x) / 2, (a2.y + b2.y) / 2 };
    flat_cubic(a, p0, p01, a2, m, tol, depth + 1);
    flat_cubic(a, m, b2, p23, p3, tol, depth + 1);
}
/* the subpaths of a path as polylines (closed: ended by closeSubpath) */
static void flatten(CGPathRef path, const CGAffineTransform *m, double tol, polys *out) {
    poly *cur = NULL;
    pt last = { 0, 0 }, start = { 0, 0 };
    for (long i = 0; path && i < path->count; i++) {
        const struct pel *e = &path->els[i];
        pt q[3];
        for (int k = 0; k < 3; k++) {
            CGPoint v = m ? CGPointApplyAffineTransform(e->p[k], *m) : e->p[k];
            q[k] = (pt){ v.x, v.y };
        }
        switch (e->type) {
        case kCGPathElementMoveToPoint: cur = polys_new(out); poly_add(cur, q[0]); last = start = q[0]; break;
        case kCGPathElementAddLineToPoint: if (!cur) { cur = polys_new(out); poly_add(cur, last); } poly_add(cur, q[0]); last = q[0]; break;
        case kCGPathElementAddQuadCurveToPoint: if (!cur) { cur = polys_new(out); poly_add(cur, last); } flat_quad(cur, last, q[0], q[1], tol, 0); last = q[1]; break;
        case kCGPathElementAddCurveToPoint: if (!cur) { cur = polys_new(out); poly_add(cur, last); } flat_cubic(cur, last, q[0], q[1], q[2], tol, 0); last = q[2]; break;
        case kCGPathElementCloseSubpath:
            if (cur) { cur->closed = 1; cur = NULL; }
            last = start;
            break;
        }
    }
}
static CGMutablePathRef path_of(const polys *s) {
    CGMutablePathRef p = CGPathCreateMutable();
    for (int i = 0; i < s->n; i++) {
        const poly *a = &s->v[i];
        if (a->n < 1) continue;
        CGPathMoveToPoint(p, NULL, a->p[0].x, a->p[0].y);
        for (int k = 1; k < a->n; k++) CGPathAddLineToPoint(p, NULL, a->p[k].x, a->p[k].y);
        if (a->closed) CGPathCloseSubpath(p);
    }
    return p;
}
static double tolerance_of(CGPathRef path) {
    CGRect b = CGPathGetBoundingBox(path);
    double size = fmax(b.size.width, b.size.height);
    return fmin(0.1, fmax(size * 1e-3, 1e-4));
}

/* ---------------- winding numbers ---------------- */
static int winding(const polys *s, pt q) {
    int w = 0;
    for (int i = 0; i < s->n; i++) {
        const poly *a = &s->v[i];
        for (int k = 0; k < a->n; k++) {
            pt p0 = a->p[k], p1 = a->p[(k + 1) % a->n];             /* every subpath fills as if closed */
            if (p0.y <= q.y) { if (p1.y > q.y && (p1.x - p0.x) * (q.y - p0.y) - (q.x - p0.x) * (p1.y - p0.y) > 0) w++; }
            else if (p1.y <= q.y && (p1.x - p0.x) * (q.y - p0.y) - (q.x - p0.x) * (p1.y - p0.y) < 0) w--;
        }
    }
    return w;
}
static int inside(const polys *s, pt q, int eo) { int w = winding(s, q); return eo ? (w & 1) : w != 0; }

/* ---------------- edges and their splitting ---------------- */
typedef struct { pt a, b; } seg;
typedef struct { seg *v; int n, cap; } segs;
static void seg_add(segs *s, pt a, pt b) {
    if (fabs(a.x - b.x) < 1e-12 && fabs(a.y - b.y) < 1e-12) return;
    if (s->n == s->cap) { s->cap = s->cap ? s->cap * 2 : 64; s->v = realloc(s->v, sizeof *s->v * (size_t)s->cap); }
    s->v[s->n++] = (seg){ a, b };
}
static void edges_of(const polys *p, segs *out, int closeAll) {
    for (int i = 0; i < p->n; i++) {
        const poly *a = &p->v[i];
        for (int k = 0; k + 1 < a->n; k++) seg_add(out, a->p[k], a->p[k + 1]);
        if ((closeAll || a->closed) && a->n > 2) seg_add(out, a->p[a->n - 1], a->p[0]);
    }
}
/* the parameters t along every segment of `in` where a segment of `cut` crosses or touches it; split there */
static int cmp_double(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return x < y ? -1 : x > y; }
static void split(const segs *in, const segs *cut, double eps, segs *out) {
    double *ts = NULL; int cap = 0;
    for (int i = 0; i < in->n; i++) {
        seg s = in->v[i];
        double dx = s.b.x - s.a.x, dy = s.b.y - s.a.y, len2 = dx * dx + dy * dy;
        double minx = fmin(s.a.x, s.b.x) - eps, maxx = fmax(s.a.x, s.b.x) + eps, miny = fmin(s.a.y, s.b.y) - eps, maxy = fmax(s.a.y, s.b.y) + eps;
        int nt = 0;
        for (int j = 0; j < cut->n; j++) {
            seg c = cut->v[j];
            if (fmax(c.a.x, c.b.x) < minx || fmin(c.a.x, c.b.x) > maxx || fmax(c.a.y, c.b.y) < miny || fmin(c.a.y, c.b.y) > maxy) continue;
            double ex = c.b.x - c.a.x, ey = c.b.y - c.a.y, den = dx * ey - dy * ex;
            double cand[4]; int nc = 0;
            if (fabs(den) > 1e-14 * (len2 + ex * ex + ey * ey)) {
                double t = ((c.a.x - s.a.x) * ey - (c.a.y - s.a.y) * ex) / den, u = ((c.a.x - s.a.x) * dy - (c.a.y - s.a.y) * dx) / den;
                if (u > -1e-9 && u < 1 + 1e-9) cand[nc++] = t;
            }
            /* collinear overlaps and endpoints touching: the cut's endpoints projected on s */
            for (int k = 0; k < 2; k++) {
                pt q = k ? c.b : c.a;
                double t = ((q.x - s.a.x) * dx + (q.y - s.a.y) * dy) / len2;
                double px = s.a.x + t * dx - q.x, py = s.a.y + t * dy - q.y;
                if (px * px + py * py < eps * eps) cand[nc++] = t;
            }
            for (int k = 0; k < nc; k++) if (cand[k] > 1e-9 && cand[k] < 1 - 1e-9) {
                if (nt == cap) { cap = cap ? cap * 2 : 16; ts = realloc(ts, sizeof *ts * (size_t)cap); }
                ts[nt++] = cand[k];
            }
        }
        qsort(ts, (size_t)nt, sizeof *ts, cmp_double);
        pt prev = s.a;
        for (int k = 0; k < nt; k++) {
            pt q = { s.a.x + ts[k] * dx, s.a.y + ts[k] * dy };
            if (hypot(q.x - prev.x, q.y - prev.y) < eps) continue;
            seg_add(out, prev, q);
            prev = q;
        }
        seg_add(out, prev, s.b);
    }
    free(ts);
}

/* ---------------- chaining kept edges into loops ---------------- */
static int same(pt a, pt b, double eps) { return fabs(a.x - b.x) <= eps && fabs(a.y - b.y) <= eps; }
static void chain(segs *kept, double eps, polys *out, int closed) {
    int n = kept->n;
    char *used = calloc((size_t)(n ? n : 1), 1);
    for (int i = 0; i < n; i++) {
        if (used[i]) continue;
        used[i] = 1;
        poly *a = polys_new(out);
        poly_add(a, kept->v[i].a);
        poly_add(a, kept->v[i].b);
        pt end = kept->v[i].b;
        for (int guard = 0; guard < n; guard++) {
            if (closed && same(end, a->p[0], eps)) break;
            int next = -1;
            for (int j = 0; j < n; j++) if (!used[j] && same(kept->v[j].a, end, eps)) { next = j; break; }
            if (next < 0 && !closed) {                                 /* open lines: extend backwards too */
                break;
            }
            if (next < 0) break;
            used[next] = 1;
            end = kept->v[next].b;
            poly_add(a, end);
        }
        if (closed) {
            if (a->n > 1 && same(a->p[a->n - 1], a->p[0], eps)) a->n--;
            a->closed = 1;
            /* drop collinear points */
            int m = 0;
            for (int k = 0; k < a->n; k++) {
                pt p0 = a->p[(k + a->n - 1) % a->n], p1 = a->p[k], p2 = a->p[(k + 1) % a->n];
                double cr = (p1.x - p0.x) * (p2.y - p1.y) - (p1.y - p0.y) * (p2.x - p1.x);
                double l = hypot(p1.x - p0.x, p1.y - p0.y) * hypot(p2.x - p1.x, p2.y - p1.y);
                if (fabs(cr) > 1e-9 * fmax(l, 1e-18)) a->p[m++] = p1;
            }
            a->n = m;
            if (a->n < 3) { free(a->p); out->n--; }
        }
    }
    free(used);
}

/* ---------------- boolean operations ---------------- */
enum { OP_UNION, OP_INTERSECT, OP_SUBTRACT, OP_XOR, OP_NORMALIZE };
static int combine(int op, int a, int b) {
    switch (op) {
    case OP_UNION: return a || b;
    case OP_INTERSECT: return a && b;
    case OP_SUBTRACT: return a && !b;
    case OP_XOR: return a != b;
    default: return a;
    }
}
static double scale_of(const polys *a, const polys *b) {
    double m = 1;
    const polys *both[2] = { a, b };
    for (int s = 0; s < 2; s++) if (both[s]) for (int i = 0; i < both[s]->n; i++) for (int k = 0; k < both[s]->v[i].n; k++)
        m = fmax(m, fmax(fabs(both[s]->v[i].p[k].x), fabs(both[s]->v[i].p[k].y)));
    return m;
}
static void boolean(const polys *A, const polys *B, int op, int eo, polys *out) {
    segs ea = { 0 }, eb = { 0 }, all = { 0 }, pieces = { 0 }, kept = { 0 };
    edges_of(A, &ea, 1);
    if (B) edges_of(B, &eb, 1);
    for (int i = 0; i < ea.n; i++) seg_add(&all, ea.v[i].a, ea.v[i].b);
    for (int i = 0; i < eb.n; i++) seg_add(&all, eb.v[i].a, eb.v[i].b);
    double eps = 1e-9 * scale_of(A, B), off = 1e-6 * scale_of(A, B);
    split(&all, &all, eps, &pieces);
    for (int i = 0; i < pieces.n; i++) {
        seg s = pieces.v[i];
        double dx = s.b.x - s.a.x, dy = s.b.y - s.a.y, l = hypot(dx, dy);
        if (l < eps) continue;
        /* a coincident piece already looked at */
        int dup = 0;
        for (int j = 0; j < kept.n && !dup; j++) {
            seg k = kept.v[j];
            if ((same(k.a, s.a, eps) && same(k.b, s.b, eps)) || (same(k.a, s.b, eps) && same(k.b, s.a, eps))) dup = 1;
        }
        if (dup) continue;
        pt m = { (s.a.x + s.b.x) / 2, (s.a.y + s.b.y) / 2 }, nl = { -dy / l * off, dx / l * off };
        pt L = { m.x + nl.x, m.y + nl.y }, R = { m.x - nl.x, m.y - nl.y };
        int inL = combine(op, inside(A, L, eo), B ? inside(B, L, eo) : 0), inR = combine(op, inside(A, R, eo), B ? inside(B, R, eo) : 0);
        if (inL == inR) continue;
        if (inL) seg_add(&kept, s.a, s.b); else seg_add(&kept, s.b, s.a);
    }
    chain(&kept, eps * 10, out, 1);
    free(ea.v); free(eb.v); free(all.v); free(pieces.v); free(kept.v);
}
static CGPathRef boolean_path(CGPathRef a, CGPathRef b, int op, bool eo) {
    polys pa = { 0 }, pb = { 0 }, out = { 0 };
    double tol = fmin(tolerance_of(a), b ? tolerance_of(b) : 1);
    flatten(a, NULL, tol, &pa);
    if (b) flatten(b, NULL, tol, &pb);
    boolean(&pa, b ? &pb : NULL, op, eo, &out);
    CGMutablePathRef p = path_of(&out);
    polys_free(&pa); polys_free(&pb); polys_free(&out);
    return p;
}
CGPathRef CGPathCreateCopyByNormalizing(CGPathRef path, bool eo) { return path ? boolean_path(path, NULL, OP_NORMALIZE, eo) : NULL; }
CGPathRef CGPathCreateCopyByUnioningPath(CGPathRef path, CGPathRef mask, bool eo) { return path && mask ? boolean_path(path, mask, OP_UNION, eo) : NULL; }
CGPathRef CGPathCreateCopyByIntersectingPath(CGPathRef path, CGPathRef mask, bool eo) { return path && mask ? boolean_path(path, mask, OP_INTERSECT, eo) : NULL; }
CGPathRef CGPathCreateCopyBySubtractingPath(CGPathRef path, CGPathRef mask, bool eo) { return path && mask ? boolean_path(path, mask, OP_SUBTRACT, eo) : NULL; }
CGPathRef CGPathCreateCopyBySymmetricDifferenceOfPath(CGPathRef path, CGPathRef mask, bool eo) { return path && mask ? boolean_path(path, mask, OP_XOR, eo) : NULL; }
bool CGPathIntersectsPath(CGPathRef a, CGPathRef b, bool eo) {
    CGPathRef r = a && b ? boolean_path(a, b, OP_INTERSECT, eo) : NULL;
    bool any = r && !CGPathIsEmpty(r);
    if (r) CGPathRelease(r);
    return any;
}
/* the parts of a path's lines inside (or outside) the mask's fill */
static CGPathRef line_path(CGPathRef path, CGPathRef mask, bool eo, int keepInside) {
    if (!path || !mask) return NULL;
    polys pa = { 0 }, pm = { 0 }, out = { 0 };
    double tol = fmin(tolerance_of(path), tolerance_of(mask));
    flatten(path, NULL, tol, &pa);
    flatten(mask, NULL, tol, &pm);
    segs ea = { 0 }, em = { 0 }, pieces = { 0 }, kept = { 0 };
    edges_of(&pa, &ea, 0);
    edges_of(&pm, &em, 1);
    double eps = 1e-9 * scale_of(&pa, &pm);
    split(&ea, &em, eps, &pieces);
    for (int i = 0; i < pieces.n; i++) {
        seg s = pieces.v[i];
        pt m = { (s.a.x + s.b.x) / 2, (s.a.y + s.b.y) / 2 };
        if (inside(&pm, m, eo) == keepInside) seg_add(&kept, s.a, s.b);
    }
    chain(&kept, eps * 10, &out, 0);
    CGMutablePathRef p = path_of(&out);
    free(ea.v); free(em.v); free(pieces.v); free(kept.v);
    polys_free(&pa); polys_free(&pm); polys_free(&out);
    return p;
}
CGPathRef CGPathCreateCopyOfLineByIntersectingPath(CGPathRef path, CGPathRef mask, bool eo) { return line_path(path, mask, eo, 1); }
CGPathRef CGPathCreateCopyOfLineBySubtractingPath(CGPathRef path, CGPathRef mask, bool eo) { return line_path(path, mask, eo, 0); }
static double area(const poly *a) {
    double s = 0;
    for (int k = 0; k < a->n; k++) { pt p = a->p[k], q = a->p[(k + 1) % a->n]; s += p.x * q.y - q.x * p.y; }
    return s / 2;
}
/* each outer loop (counterclockwise) with the holes (clockwise) directly inside it */
CFArrayRef CGPathCreateSeparateComponentsOfPath(CGPathRef path, bool eo) {
    if (!path) return NULL;
    polys pa = { 0 }, loops = { 0 };
    flatten(path, NULL, tolerance_of(path), &pa);
    boolean(&pa, NULL, OP_NORMALIZE, eo, &loops);
    int n = loops.n;
    int *owner = calloc((size_t)(n ? n : 1), sizeof *owner);
    for (int i = 0; i < n; i++) {
        owner[i] = -1;
        if (area(&loops.v[i]) >= 0) continue;
        double best = INFINITY;
        for (int j = 0; j < n; j++) {
            if (area(&loops.v[j]) <= 0) continue;
            polys one = { &loops.v[j], 1, 1 };
            if (winding(&one, loops.v[i].p[0]) && area(&loops.v[j]) < best) { best = area(&loops.v[j]); owner[i] = j; }
        }
    }
    CGPathRef *comps = calloc((size_t)(n ? n : 1), sizeof *comps);
    int nc = 0;
    for (int j = 0; j < n; j++) {
        if (area(&loops.v[j]) <= 0) continue;
        polys c = { 0 };
        poly *o = polys_new(&c); *o = loops.v[j]; o->p = memcpy(malloc(sizeof *o->p * (size_t)o->n), o->p, sizeof *o->p * (size_t)o->n);
        for (int i = 0; i < n; i++) if (owner[i] == j) {
            poly *h = polys_new(&c); *h = loops.v[i]; h->p = memcpy(malloc(sizeof *h->p * (size_t)h->n), h->p, sizeof *h->p * (size_t)h->n);
        }
        comps[nc++] = path_of(&c);
        polys_free(&c);
    }
    CFArrayRef a = CFArrayCreate(NULL, (const void **)comps, nc, &kCFTypeArrayCallBacks);
    for (int i = 0; i < nc; i++) CGPathRelease(comps[i]);
    free(comps); free(owner);
    polys_free(&pa); polys_free(&loops);
    return a;
}
CGPathRef CGPathCreateCopyByFlattening(CGPathRef path, CGFloat threshold) {
    if (!path) return NULL;
    polys pa = { 0 };
    flatten(path, NULL, threshold > 0 ? threshold : 0.5, &pa);
    CGMutablePathRef p = path_of(&pa);
    polys_free(&pa);
    return p;
}

/* ---------------- stroking ---------------- */
static void piece_ccw(poly *a) { if (area(a) < 0) for (int i = 0; i < a->n / 2; i++) { pt t = a->p[i]; a->p[i] = a->p[a->n - 1 - i]; a->p[a->n - 1 - i] = t; } }
static void add_circle(polys *s, pt c, double r) {
    poly *a = polys_new(s);
    int n = (int)fmax(12, fmin(96, ceil(2 * M_PI * r / fmax(r * 0.08, 0.2))));
    for (int i = 0; i < n; i++) poly_add(a, (pt){ c.x + r * cos(2 * M_PI * i / n), c.y + r * sin(2 * M_PI * i / n) });
    a->closed = 1;
}
static void add_quad(polys *s, pt a, pt b, pt c, pt d) {
    poly *q = polys_new(s);
    poly_add(q, a); poly_add(q, b); poly_add(q, c); poly_add(q, d);
    q->closed = 1;
    piece_ccw(q);
}
static void add_tri(polys *s, pt a, pt b, pt c) {
    poly *q = polys_new(s);
    poly_add(q, a); poly_add(q, b); poly_add(q, c);
    q->closed = 1;
    if (q->n < 3 || fabs(area(q)) < 1e-12) { free(q->p); s->n--; return; }
    piece_ccw(q);
}
/* `p` mapped by `m` (consumed) */
static CGPathRef transformed(CGMutablePathRef p, const CGAffineTransform *m) {
    if (!m || CGAffineTransformIsIdentity(*m)) return p;
    CGMutablePathRef t = CGPathCreateMutable();
    CGPathAddPath(t, m, p);
    CGPathRelease(p);
    return t;
}
CGPathRef CGPathCreateCopyByStrokingPath(CGPathRef path, const CGAffineTransform *m, CGFloat width, CGLineCap cap, CGLineJoin join, CGFloat miterLimit) {
    if (!path) return NULL;
    double h = fabs(width) / 2;
    polys sub = { 0 }, pieces = { 0 }, out = { 0 };
    flatten(path, NULL, fmin(tolerance_of(path), fmax(h * 0.02, 1e-3)), &sub);   /* `m` maps the outline, as on Apple's */
    if (h <= 0) { polys_free(&sub); return CGPathCreateMutable(); }
    for (int i = 0; i < sub.n; i++) {
        poly *a = &sub.v[i];
        int n = a->n, closed = a->closed && n > 2;
        if (n == 1 || (n == 2 && same(a->p[0], a->p[1], 1e-12))) {     /* a point: its caps */
            if (cap == kCGLineCapRound) add_circle(&pieces, a->p[0], h);
            else if (cap == kCGLineCapSquare) add_quad(&pieces, (pt){ a->p[0].x - h, a->p[0].y - h }, (pt){ a->p[0].x + h, a->p[0].y - h },
                                                      (pt){ a->p[0].x + h, a->p[0].y + h }, (pt){ a->p[0].x - h, a->p[0].y + h });
            continue;
        }
        int nseg = closed ? n : n - 1;
        for (int k = 0; k < nseg; k++) {                                /* each segment's band */
            pt p = a->p[k], q = a->p[(k + 1) % n];
            double dx = q.x - p.x, dy = q.y - p.y, l = hypot(dx, dy);
            if (l < 1e-12) continue;
            double nx = -dy / l * h, ny = dx / l * h;
            add_quad(&pieces, (pt){ p.x + nx, p.y + ny }, (pt){ q.x + nx, q.y + ny }, (pt){ q.x - nx, q.y - ny }, (pt){ p.x - nx, p.y - ny });
        }
        int first = closed ? 0 : 1, last = closed ? n - 1 : n - 2;
        for (int k = first; k <= last; k++) {                          /* joins */
            pt v = a->p[k], p0 = a->p[(k + n - 1) % n], p1 = a->p[(k + 1) % n];
            double d0x = v.x - p0.x, d0y = v.y - p0.y, d1x = p1.x - v.x, d1y = p1.y - v.y, l0 = hypot(d0x, d0y), l1 = hypot(d1x, d1y);
            if (l0 < 1e-12 || l1 < 1e-12) continue;
            d0x /= l0; d0y /= l0; d1x /= l1; d1y /= l1;
            double cr = d0x * d1y - d0y * d1x;
            if (fabs(cr) < 1e-9 && d0x * d1x + d0y * d1y > 0) continue;  /* straight on */
            if (join == kCGLineJoinRound) { add_circle(&pieces, v, h); continue; }
            double side = cr > 0 ? -1 : 1;                                /* the outer side of the turn */
            pt o0 = { v.x - d0y * h * side, v.y + d0x * h * side }, o1 = { v.x - d1y * h * side, v.y + d1x * h * side };
            add_tri(&pieces, v, o0, o1);
            if (join == kCGLineJoinMiter) {
                double cosA = d0x * d1x + d0y * d1y, ratio = 1 / sqrt(fmax((1 + cosA) / 2, 1e-12));   /* 1 / sin(half the angle between the lines) */
                if (ratio <= miterLimit) {
                    double bx = (o0.x + o1.x) / 2 - v.x, by = (o0.y + o1.y) / 2 - v.y, bl = hypot(bx, by);
                    if (bl > 1e-12) {
                        double ml = h * ratio;
                        pt tip = { v.x + bx / bl * ml, v.y + by / bl * ml };
                        add_tri(&pieces, v, o0, tip);
                        add_tri(&pieces, v, tip, o1);
                    }
                }
            }
        }
        if (!closed) {                                                  /* caps */
            for (int e = 0; e < 2; e++) {
                pt v = e ? a->p[n - 1] : a->p[0], w = e ? a->p[n - 2] : a->p[1];
                double dx = v.x - w.x, dy = v.y - w.y, l = hypot(dx, dy);
                if (l < 1e-12) continue;
                dx /= l; dy /= l;
                if (cap == kCGLineCapRound) add_circle(&pieces, v, h);
                else if (cap == kCGLineCapSquare)
                    add_quad(&pieces, (pt){ v.x - dy * h, v.y + dx * h }, (pt){ v.x - dy * h + dx * h, v.y + dx * h + dy * h },
                             (pt){ v.x + dy * h + dx * h, v.y - dx * h + dy * h }, (pt){ v.x + dy * h, v.y - dx * h });
            }
        }
    }
    boolean(&pieces, NULL, OP_NORMALIZE, 0, &out);
    CGMutablePathRef p = path_of(&out);
    polys_free(&sub); polys_free(&pieces); polys_free(&out);
    return transformed(p, m);
}

/* ---------------- dashing ---------------- */
CGPathRef CGPathCreateCopyByDashingPath(CGPathRef path, const CGAffineTransform *m, CGFloat phase, const CGFloat *lengths, size_t count) {
    if (!path) return NULL;
    double total = 0;
    for (size_t i = 0; i < count; i++) total += fmax(0, lengths[i]);
    if (!lengths || !count || total <= 0) {                            /* no pattern: the path itself */
        CGMutablePathRef c = CGPathCreateMutable();
        CGPathAddPath(c, m, path);
        return c;
    }
    polys sub = { 0 }, out = { 0 };
    flatten(path, NULL, tolerance_of(path), &sub);                      /* lengths are along the untransformed path */
    for (int i = 0; i < sub.n; i++) {
        poly *a = &sub.v[i];
        int nseg = a->closed && a->n > 2 ? a->n : a->n - 1;
        /* the pattern starts again on each subpath, `phase` into it */
        double ph = fmod(fmax(phase, 0), total);
        size_t di = 0;
        while (ph >= lengths[di] && ph > 0) { ph -= lengths[di]; di = (di + 1) % count; }
        double left = lengths[di] - ph;
        int on = (di % 2) == 0;
        poly *cur = NULL;
        if (on) { cur = polys_new(&out); poly_add(cur, a->p[0]); }
        for (int k = 0; k < nseg; k++) {
            pt p = a->p[k], q = a->p[(k + 1) % a->n];
            double l = hypot(q.x - p.x, q.y - p.y), t = 0;
            while (l - t > left + 1e-12) {
                t += left;
                pt x = { p.x + (q.x - p.x) * t / l, p.y + (q.y - p.y) * t / l };
                if (on) { poly_add(cur, x); cur = NULL; }
                else { cur = polys_new(&out); poly_add(cur, x); }
                on = !on;
                di = (di + 1) % count;
                left = lengths[di];
            }
            left -= l - t;
            if (on && cur) poly_add(cur, q);
        }
    }
    CGMutablePathRef p = path_of(&out);
    polys_free(&sub); polys_free(&out);
    return transformed(p, m);
}

/* ---------------- the rest ---------------- */
CGPathRef CGPathCreateCopyByTransformingPath(CGPathRef path, const CGAffineTransform *m) { return CGPathCreateMutableCopyByTransformingPath(path, m); }
CGMutablePathRef CGPathCreateMutableCopyByTransformingPath(CGPathRef path, const CGAffineTransform *m) {
    if (!path) return NULL;
    CGMutablePathRef c = CGPathCreateMutable();
    CGPathAddPath(c, m, path);
    return c;
}
bool CGPathIsRect(CGPathRef path, CGRect *rect) {
    if (!path) return false;
    long n = path->count;
    const struct pel *e = path->els;
    if (n < 4 || e[0].type != kCGPathElementMoveToPoint) return false;
    CGPoint q[5]; int k = 0;
    q[k++] = e[0].p[0];
    long i = 1;
    for (; i < n && e[i].type == kCGPathElementAddLineToPoint && k < 5; i++) q[k++] = e[i].p[0];
    if (k == 5 && q[4].x == q[0].x && q[4].y == q[0].y) k = 4;         /* a line back to the start */
    int closes = i < n && e[i].type == kCGPathElementCloseSubpath;
    if (k != 4 || (i + closes) != n) return false;
    for (int j = 0; j < 4; j++) {                                       /* every side horizontal or vertical, alternating */
        CGPoint a = q[j], b = q[(j + 1) % 4], c = q[(j + 2) % 4];
        int ha = a.y == b.y && a.x != b.x, va = a.x == b.x && a.y != b.y, hb = b.y == c.y && b.x != c.x, vb = b.x == c.x && b.y != c.y;
        if (!((ha && vb) || (va && hb))) return false;
    }
    if (rect) *rect = CGRectStandardize(CGRectMake(q[0].x, q[0].y, q[2].x - q[0].x, q[2].y - q[0].y));
    return true;
}
/* an arc of radius r tangent to the lines from the current point to (x1, y1) and from there to (x2, y2) */
void CGPathAddArcToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat r) {
    if (!p) return;
    if (!p->count) { CGPathMoveToPoint(p, m, x1, y1); return; }
    /* the current point in user space (the transform maps the arc's points) */
    CGPoint cur = CGPathGetCurrentPoint(p);
    if (m) { CGAffineTransform inv = CGAffineTransformInvert(*m); cur = CGPointApplyAffineTransform(cur, inv); }
    double ax = cur.x - x1, ay = cur.y - y1, bx = x2 - x1, by = y2 - y1, la = hypot(ax, ay), lb = hypot(bx, by);
    double cr = ax * by - ay * bx;
    if (r <= 0 || la < 1e-12 || lb < 1e-12 || fabs(cr) < 1e-12 * la * lb) { CGPathAddLineToPoint(p, m, x1, y1); return; }
    ax /= la; ay /= la; bx /= lb; by /= lb;
    double cosT = ax * bx + ay * by, half = acos(fmax(-1, fmin(1, cosT))) / 2, d = r / tan(half);
    double t0x = x1 + ax * d, t0y = y1 + ay * d, t1x = x1 + bx * d, t1y = y1 + by * d;
    double bisx = ax + bx, bisy = ay + by, bl = hypot(bisx, bisy), cd = r / sin(half);
    double cx = x1 + bisx / bl * cd, cy = y1 + bisy / bl * cd;
    double a0 = atan2(t0y - cy, t0x - cx), a1 = atan2(t1y - cy, t1x - cx);
    bool clockwise = cr > 0;                                            /* a right turn: a clockwise arc (y-up) */
    CGPathAddLineToPoint(p, m, t0x, t0y);
    CGPathAddArc(p, m, cx, cy, r, a0, a1, clockwise);
}
