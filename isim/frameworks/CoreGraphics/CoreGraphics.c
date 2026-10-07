/* isim CoreGraphics: geometry, affine transforms and CGPath. Colors (CGColor.c), contexts (CGContext.c), images and
 * bitmap/PDF contexts (CGImage.c, CGBitmap.c), gradients/shadings/patterns (CGGradient.c) are in their own files. */
#include "cg_internal.h"

const CGPoint CGPointZero = { 0, 0 };
const CGSize CGSizeZero = { 0, 0 };
const CGRect CGRectZero = { { 0, 0 }, { 0, 0 } };
const CGRect CGRectNull = { { INFINITY, INFINITY }, { 0, 0 } };
const CGRect CGRectInfinite = { { -8.98846567431158e307, -8.98846567431158e307 }, { 1.7976931348623157e308, 1.7976931348623157e308 } };
const CGAffineTransform CGAffineTransformIdentity = { 1, 0, 0, 1, 0, 0 };

CGRect CGRectStandardize(CGRect r) {
    if (r.size.width < 0) { r.origin.x += r.size.width; r.size.width = -r.size.width; }
    if (r.size.height < 0) { r.origin.y += r.size.height; r.size.height = -r.size.height; }
    return r;
}
CGFloat CGRectGetMinX(CGRect r) { return CGRectStandardize(r).origin.x; }
CGFloat CGRectGetMinY(CGRect r) { return CGRectStandardize(r).origin.y; }
CGFloat CGRectGetMaxX(CGRect r) { r = CGRectStandardize(r); return r.origin.x + r.size.width; }
CGFloat CGRectGetMaxY(CGRect r) { r = CGRectStandardize(r); return r.origin.y + r.size.height; }
CGFloat CGRectGetMidX(CGRect r) { r = CGRectStandardize(r); return r.origin.x + r.size.width / 2; }
CGFloat CGRectGetMidY(CGRect r) { r = CGRectStandardize(r); return r.origin.y + r.size.height / 2; }
CGFloat CGRectGetWidth(CGRect r) { return fabs(r.size.width); }
CGFloat CGRectGetHeight(CGRect r) { return fabs(r.size.height); }
bool CGPointEqualToPoint(CGPoint a, CGPoint b) { return a.x == b.x && a.y == b.y; }
bool CGSizeEqualToSize(CGSize a, CGSize b) { return a.width == b.width && a.height == b.height; }
bool CGRectEqualToRect(CGRect a, CGRect b) { a = CGRectStandardize(a); b = CGRectStandardize(b); return CGPointEqualToPoint(a.origin, b.origin) && CGSizeEqualToSize(a.size, b.size); }
bool CGRectIsNull(CGRect r) { return isinf(r.origin.x) || isinf(r.origin.y); }
bool CGRectIsEmpty(CGRect r) { return CGRectIsNull(r) || r.size.width == 0 || r.size.height == 0; }
CGRect CGRectInset(CGRect r, CGFloat dx, CGFloat dy) {
    r = CGRectStandardize(r);
    r.origin.x += dx; r.origin.y += dy; r.size.width -= 2 * dx; r.size.height -= 2 * dy;
    if (r.size.width < 0 || r.size.height < 0) return CGRectNull;
    return r;
}
CGRect CGRectOffset(CGRect r, CGFloat dx, CGFloat dy) { r.origin.x += dx; r.origin.y += dy; return r; }
CGRect CGRectIntegral(CGRect r) {
    r = CGRectStandardize(r);
    CGFloat x0 = floor(r.origin.x), y0 = floor(r.origin.y), x1 = ceil(r.origin.x + r.size.width), y1 = ceil(r.origin.y + r.size.height);
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
CGRect CGRectUnion(CGRect a, CGRect b) {
    if (CGRectIsNull(a)) return b;
    if (CGRectIsNull(b)) return a;
    CGFloat x0 = fmin(CGRectGetMinX(a), CGRectGetMinX(b)), y0 = fmin(CGRectGetMinY(a), CGRectGetMinY(b));
    CGFloat x1 = fmax(CGRectGetMaxX(a), CGRectGetMaxX(b)), y1 = fmax(CGRectGetMaxY(a), CGRectGetMaxY(b));
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
CGRect CGRectIntersection(CGRect a, CGRect b) {
    CGFloat x0 = fmax(CGRectGetMinX(a), CGRectGetMinX(b)), y0 = fmax(CGRectGetMinY(a), CGRectGetMinY(b));
    CGFloat x1 = fmin(CGRectGetMaxX(a), CGRectGetMaxX(b)), y1 = fmin(CGRectGetMaxY(a), CGRectGetMaxY(b));
    if (x1 < x0 || y1 < y0) return CGRectNull;
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
bool CGRectIntersectsRect(CGRect a, CGRect b) { return !CGRectIsNull(CGRectIntersection(a, b)); }
bool CGRectContainsPoint(CGRect r, CGPoint p) {
    r = CGRectStandardize(r);
    return p.x >= r.origin.x && p.x < r.origin.x + r.size.width && p.y >= r.origin.y && p.y < r.origin.y + r.size.height;
}
bool CGRectContainsRect(CGRect a, CGRect b) { return CGRectEqualToRect(CGRectUnion(a, b), CGRectStandardize(a)); }
void CGRectDivide(CGRect r, CGRect *slice, CGRect *rem, CGFloat amount, CGRectEdge edge) {
    r = CGRectStandardize(r);
    CGRect s = r, m = r;
    switch (edge) {
    case CGRectMinXEdge: amount = fmin(amount, r.size.width); s.size.width = amount; m.origin.x += amount; m.size.width -= amount; break;
    case CGRectMaxXEdge: amount = fmin(amount, r.size.width); s.origin.x = CGRectGetMaxX(r) - amount; s.size.width = amount; m.size.width -= amount; break;
    case CGRectMinYEdge: amount = fmin(amount, r.size.height); s.size.height = amount; m.origin.y += amount; m.size.height -= amount; break;
    case CGRectMaxYEdge: amount = fmin(amount, r.size.height); s.origin.y = CGRectGetMaxY(r) - amount; s.size.height = amount; m.size.height -= amount; break;
    }
    if (slice) *slice = s;
    if (rem) *rem = m;
}

CGAffineTransform CGAffineTransformMake(CGFloat a, CGFloat b, CGFloat c, CGFloat d, CGFloat tx, CGFloat ty) { CGAffineTransform t = { a, b, c, d, tx, ty }; return t; }
CGAffineTransform CGAffineTransformMakeTranslation(CGFloat tx, CGFloat ty) { return CGAffineTransformMake(1, 0, 0, 1, tx, ty); }
CGAffineTransform CGAffineTransformMakeScale(CGFloat sx, CGFloat sy) { return CGAffineTransformMake(sx, 0, 0, sy, 0, 0); }
CGAffineTransform CGAffineTransformMakeRotation(CGFloat a) { return CGAffineTransformMake(cos(a), sin(a), -sin(a), cos(a), 0, 0); }
CGAffineTransform CGAffineTransformConcat(CGAffineTransform t1, CGAffineTransform t2) {
    return CGAffineTransformMake(t1.a * t2.a + t1.b * t2.c, t1.a * t2.b + t1.b * t2.d,
                                 t1.c * t2.a + t1.d * t2.c, t1.c * t2.b + t1.d * t2.d,
                                 t1.tx * t2.a + t1.ty * t2.c + t2.tx, t1.tx * t2.b + t1.ty * t2.d + t2.ty);
}
bool CGAffineTransformIsIdentity(CGAffineTransform t) { return !memcmp(&t, &CGAffineTransformIdentity, sizeof t); }
CGPoint CGPointApplyAffineTransform(CGPoint p, CGAffineTransform t) { return CGPointMake(t.a * p.x + t.c * p.y + t.tx, t.b * p.x + t.d * p.y + t.ty); }
CGSize CGSizeApplyAffineTransform(CGSize s, CGAffineTransform t) { return CGSizeMake(t.a * s.width + t.c * s.height, t.b * s.width + t.d * s.height); }
CGRect CGRectApplyAffineTransform(CGRect r, CGAffineTransform t) {
    if (CGRectIsNull(r)) return r;
    CGPoint p[4] = { r.origin, { r.origin.x + r.size.width, r.origin.y }, { r.origin.x, r.origin.y + r.size.height }, { r.origin.x + r.size.width, r.origin.y + r.size.height } };
    double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
    for (int i = 0; i < 4; i++) { CGPoint q = CGPointApplyAffineTransform(p[i], t); x0 = fmin(x0, q.x); y0 = fmin(y0, q.y); x1 = fmax(x1, q.x); y1 = fmax(y1, q.y); }
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
CGAffineTransform CGAffineTransformTranslate(CGAffineTransform t, CGFloat tx, CGFloat ty) { return CGAffineTransformConcat(CGAffineTransformMakeTranslation(tx, ty), t); }
CGAffineTransform CGAffineTransformScale(CGAffineTransform t, CGFloat sx, CGFloat sy) { return CGAffineTransformConcat(CGAffineTransformMakeScale(sx, sy), t); }
CGAffineTransform CGAffineTransformRotate(CGAffineTransform t, CGFloat a) { return CGAffineTransformConcat(CGAffineTransformMakeRotation(a), t); }
CGAffineTransform CGAffineTransformInvert(CGAffineTransform t) {
    double det = t.a * t.d - t.b * t.c;
    if (det == 0) return t;
    return CGAffineTransformMake(t.d / det, -t.b / det, -t.c / det, t.a / det, (t.c * t.ty - t.d * t.tx) / det, (t.b * t.tx - t.a * t.ty) / det);
}
bool CGAffineTransformEqualToTransform(CGAffineTransform a, CGAffineTransform b) { return !memcmp(&a, &b, sizeof a); }

/* ---- CGPath: an element list in an object of the Foundation class __NSCGPath (layout must match) ---- */
static CGMutablePathRef path_new(void) {
    static Class k; if (!k) k = objc_getClass("__NSCGPath");
    struct CGPath *p = k ? class_createInstance(k, 0) : calloc(1, sizeof *p);
    return p;
}
static CGPoint tx(const CGAffineTransform *m, CGFloat x, CGFloat y) {
    return m ? CGPointMake(m->a * x + m->c * y + m->tx, m->b * x + m->d * y + m->ty) : CGPointMake(x, y);
}
static void add_el(CGMutablePathRef p, int type, CGPoint a, CGPoint b, CGPoint c) {
    if (!p) return;
    if (p->count == p->cap) { p->cap = p->cap ? p->cap * 2 : 16; p->els = realloc(p->els, p->cap * sizeof *p->els); }
    p->els[p->count++] = (struct pel){ type, { a, b, c } };
}
CGMutablePathRef CGPathCreateMutable(void) { return path_new(); }
CGMutablePathRef CGPathCreateMutableCopy(CGPathRef src) {
    CGMutablePathRef p = path_new();
    if (src && src->count) { p->cap = p->count = src->count; p->els = malloc(p->cap * sizeof *p->els); memcpy(p->els, src->els, p->count * sizeof *p->els); }
    return p;
}
CGPathRef CGPathCreateCopy(CGPathRef src) { return CGPathCreateMutableCopy(src); }
CGPathRef CGPathRetain(CGPathRef p) { if (p) objc_retain((void *)p); return p; }
void CGPathRelease(CGPathRef p) { if (p) objc_release((void *)p); }
void CGPathMoveToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x, CGFloat y) { add_el(p, kCGPathElementMoveToPoint, tx(m, x, y), CGPointZero, CGPointZero); }
void CGPathAddLineToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x, CGFloat y) { add_el(p, kCGPathElementAddLineToPoint, tx(m, x, y), CGPointZero, CGPointZero); }
void CGPathAddQuadCurveToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat cx, CGFloat cy, CGFloat x, CGFloat y) {
    add_el(p, kCGPathElementAddQuadCurveToPoint, tx(m, cx, cy), tx(m, x, y), CGPointZero);
}
void CGPathAddCurveToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat ax, CGFloat ay, CGFloat bx, CGFloat by, CGFloat x, CGFloat y) {
    add_el(p, kCGPathElementAddCurveToPoint, tx(m, ax, ay), tx(m, bx, by), tx(m, x, y));
}
void CGPathCloseSubpath(CGMutablePathRef p) { add_el(p, kCGPathElementCloseSubpath, CGPointZero, CGPointZero, CGPointZero); }
void CGPathAddRect(CGMutablePathRef p, const CGAffineTransform *m, CGRect r) {
    r = CGRectStandardize(r);
    CGPathMoveToPoint(p, m, r.origin.x, r.origin.y);
    CGPathAddLineToPoint(p, m, r.origin.x + r.size.width, r.origin.y);
    CGPathAddLineToPoint(p, m, r.origin.x + r.size.width, r.origin.y + r.size.height);
    CGPathAddLineToPoint(p, m, r.origin.x, r.origin.y + r.size.height);
    CGPathCloseSubpath(p);
}
void CGPathAddEllipseInRect(CGMutablePathRef p, const CGAffineTransform *m, CGRect r) {
    double k = 0.5522847498, cx = CGRectGetMidX(r), cy = CGRectGetMidY(r), rx = r.size.width / 2, ry = r.size.height / 2;
    CGPathMoveToPoint(p, m, cx + rx, cy);
    CGPathAddCurveToPoint(p, m, cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
    CGPathAddCurveToPoint(p, m, cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
    CGPathAddCurveToPoint(p, m, cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
    CGPathAddCurveToPoint(p, m, cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
    CGPathCloseSubpath(p);
}
void CGPathAddRoundedRect(CGMutablePathRef p, const CGAffineTransform *m, CGRect r, CGFloat cw, CGFloat ch) {
    r = CGRectStandardize(r);
    if (cw <= 0 || ch <= 0) { CGPathAddRect(p, m, r); return; }
    cw = fmin(cw, r.size.width / 2); ch = fmin(ch, r.size.height / 2);
    double x0 = r.origin.x, y0 = r.origin.y, x1 = x0 + r.size.width, y1 = y0 + r.size.height, k = 0.5522847498;
    CGPathMoveToPoint(p, m, x0 + cw, y0);
    CGPathAddLineToPoint(p, m, x1 - cw, y0);
    CGPathAddCurveToPoint(p, m, x1 - cw + cw * k, y0, x1, y0 + ch - ch * k, x1, y0 + ch);
    CGPathAddLineToPoint(p, m, x1, y1 - ch);
    CGPathAddCurveToPoint(p, m, x1, y1 - ch + ch * k, x1 - cw + cw * k, y1, x1 - cw, y1);
    CGPathAddLineToPoint(p, m, x0 + cw, y1);
    CGPathAddCurveToPoint(p, m, x0 + cw - cw * k, y1, x0, y1 - ch + ch * k, x0, y1 - ch);
    CGPathAddLineToPoint(p, m, x0, y0 + ch);
    CGPathAddCurveToPoint(p, m, x0, y0 + ch - ch * k, x0 + cw - cw * k, y0, x0 + cw, y0);
    CGPathCloseSubpath(p);
}
/* arc as cubic segments; clockwise is in Core Graphics' sense (y-up), i.e. decreasing angle */
void CGPathAddArc(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x, CGFloat y, CGFloat r, CGFloat a0, CGFloat a1, bool clockwise) {
    double sweep = a1 - a0;
    if (clockwise) { while (sweep > 0) sweep -= 2 * M_PI; } else { while (sweep < 0) sweep += 2 * M_PI; }
    if (fabs(a1 - a0) >= 2 * M_PI) sweep = clockwise ? -2 * M_PI : 2 * M_PI;
    CGPathAddRelativeArc(p, m, x, y, r, a0, sweep);
}
void CGPathAddRelativeArc(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x, CGFloat y, CGFloat r, CGFloat a0, CGFloat delta) {
    double sx = x + r * cos(a0), sy = y + r * sin(a0);
    if (!p->count || p->els[p->count - 1].type == kCGPathElementCloseSubpath) CGPathMoveToPoint(p, m, sx, sy);
    else CGPathAddLineToPoint(p, m, sx, sy);
    int n = (int)ceil(fabs(delta) / (M_PI / 2)); if (n < 1) n = 1;
    double step = delta / n, a = a0;
    for (int i = 0; i < n; i++) {
        double b = a + step, k = 4.0 / 3 * tan(step / 4);
        CGPathAddCurveToPoint(p, m, x + r * (cos(a) - k * sin(a)), y + r * (sin(a) + k * cos(a)),
                              x + r * (cos(b) + k * sin(b)), y + r * (sin(b) - k * cos(b)), x + r * cos(b), y + r * sin(b));
        a = b;
    }
}
void CGPathAddPath(CGMutablePathRef p, const CGAffineTransform *m, CGPathRef o) {
    if (!o) return;
    for (long i = 0; i < o->count; i++) {
        struct pel e = o->els[i];
        add_el(p, e.type, tx(m, e.p[0].x, e.p[0].y), tx(m, e.p[1].x, e.p[1].y), tx(m, e.p[2].x, e.p[2].y));
    }
}
CGPathRef CGPathCreateWithRect(CGRect r, const CGAffineTransform *m) { CGMutablePathRef p = path_new(); CGPathAddRect(p, m, r); return p; }
CGPathRef CGPathCreateWithEllipseInRect(CGRect r, const CGAffineTransform *m) { CGMutablePathRef p = path_new(); CGPathAddEllipseInRect(p, m, r); return p; }
CGPathRef CGPathCreateWithRoundedRect(CGRect r, CGFloat cw, CGFloat ch, const CGAffineTransform *m) { CGMutablePathRef p = path_new(); CGPathAddRoundedRect(p, m, r, cw, ch); return p; }
bool CGPathIsEmpty(CGPathRef p) { return !p || p->count == 0; }
static int npoints(int type) { return type == kCGPathElementAddCurveToPoint ? 3 : type == kCGPathElementAddQuadCurveToPoint ? 2 : type == kCGPathElementCloseSubpath ? 0 : 1; }
CGPoint CGPathGetCurrentPoint(CGPathRef p) {
    if (!p || !p->count) return CGPointZero;
    struct pel e = p->els[p->count - 1];
    int n = npoints(e.type);
    return n ? e.p[n - 1] : CGPointZero;
}
CGRect CGPathGetBoundingBox(CGPathRef p) {
    if (!p || !p->count) return CGRectNull;
    double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
    for (long i = 0; i < p->count; i++) for (int k = 0; k < npoints(p->els[i].type); k++) {
        CGPoint q = p->els[i].p[k];
        x0 = fmin(x0, q.x); y0 = fmin(y0, q.y); x1 = fmax(x1, q.x); y1 = fmax(y1, q.y);
    }
    return x0 > x1 ? CGRectNull : CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
CGRect CGPathGetPathBoundingBox(CGPathRef p) { return CGPathGetBoundingBox(p); }
/* even-odd / nonzero test on the flattened polygon (curves sampled) */
bool CGPathContainsPoint(CGPathRef p, const CGAffineTransform *m, CGPoint pt, bool eo) {
    if (!p) return false;
    if (m) { CGAffineTransform inv = CGAffineTransformInvert(*m); pt = CGPointApplyAffineTransform(pt, inv); }
    int wind = 0, cross = 0; CGPoint start = CGPointZero, prev = CGPointZero;
    #define EDGE(A, B) do { CGPoint a_ = (A), b_ = (B); \
        if ((a_.y <= pt.y) != (b_.y <= pt.y)) { double xi = a_.x + (pt.y - a_.y) * (b_.x - a_.x) / (b_.y - a_.y); \
            if (xi > pt.x) { cross++; wind += b_.y > a_.y ? 1 : -1; } } } while (0)
    for (long i = 0; i < p->count; i++) {
        struct pel e = p->els[i];
        switch (e.type) {
        case kCGPathElementMoveToPoint: EDGE(prev, start); start = prev = e.p[0]; break;
        case kCGPathElementAddLineToPoint: EDGE(prev, e.p[0]); prev = e.p[0]; break;
        case kCGPathElementAddQuadCurveToPoint:
        case kCGPathElementAddCurveToPoint: {
            CGPoint end = e.p[npoints(e.type) - 1], last = prev;
            for (int s = 1; s <= 16; s++) {
                double t = s / 16.0, u = 1 - t; CGPoint q;
                if (e.type == kCGPathElementAddQuadCurveToPoint) q = CGPointMake(u * u * prev.x + 2 * u * t * e.p[0].x + t * t * end.x, u * u * prev.y + 2 * u * t * e.p[0].y + t * t * end.y);
                else q = CGPointMake(u * u * u * prev.x + 3 * u * u * t * e.p[0].x + 3 * u * t * t * e.p[1].x + t * t * t * end.x,
                                     u * u * u * prev.y + 3 * u * u * t * e.p[0].y + 3 * u * t * t * e.p[1].y + t * t * t * end.y);
                EDGE(last, q); last = q;
            }
            prev = end; break; }
        case kCGPathElementCloseSubpath: EDGE(prev, start); prev = start; break;
        }
    }
    EDGE(prev, start);
    #undef EDGE
    return eo ? (cross & 1) : wind != 0;
}
bool CGPathEqualToPath(CGPathRef a, CGPathRef b) {
    if (a == b) return true;
    if (!a || !b || a->count != b->count) return false;
    for (long i = 0; i < a->count; i++) {
        if (a->els[i].type != b->els[i].type) return false;
        for (int k = 0; k < npoints(a->els[i].type); k++) if (!CGPointEqualToPoint(a->els[i].p[k], b->els[i].p[k])) return false;
    }
    return true;
}
void CGPathApply(CGPathRef p, void *info, CGPathApplierFunction f) {
    if (!p || !f) return;
    for (long i = 0; i < p->count; i++) { CGPathElement e = { (CGPathElementType)p->els[i].type, p->els[i].p }; f(info, &e); }
}
