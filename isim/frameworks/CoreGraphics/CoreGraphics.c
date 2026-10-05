/* isim CoreGraphics subset: geometry, affine transforms, CGColor, and a CGContext that
 * draws into the simulator surface through libisim_host. */
#include <CoreGraphics/CoreGraphics.h>
#include <isim_host.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

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

/* ---- CGColor: refcounted RGBA ---- */
struct CGColor { int refs; CGFloat c[4]; };
CGColorRef CGColorCreateSRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    CGColorRef col = malloc(sizeof *col); col->refs = 1; col->c[0] = r; col->c[1] = g; col->c[2] = b; col->c[3] = a; return col;
}
CGColorRef CGColorRetain(CGColorRef c) { if (c) __atomic_add_fetch(&c->refs, 1, __ATOMIC_RELAXED); return c; }
void CGColorRelease(CGColorRef c) { if (c && __atomic_sub_fetch(&c->refs, 1, __ATOMIC_ACQ_REL) == 0) free(c); }
const CGFloat *CGColorGetComponents(CGColorRef c) { return c ? c->c : NULL; }
CGFloat CGColorGetAlpha(CGColorRef c) { return c ? c->c[3] : 0; }

/* ---- CGContext: single current surface; state is fill/stroke color + line width ---- */
struct CGContext { CGFloat fill[4], stroke[4], lw; };
static struct CGContext gstack[32]; static int gdepth;
static struct CGContext *cur(void) { return &gstack[gdepth]; }
CGContextRef isim_cg_current_context(void) {           /* isim: used by UIKit's UIGraphicsGetCurrentContext */
    static int init;
    if (!init) { init = 1; gstack[0] = (struct CGContext){ { 0, 0, 0, 1 }, { 0, 0, 0, 1 }, 1 }; }
    return cur();
}
void CGContextSaveGState(CGContextRef c) { if (gdepth < 31) { gstack[gdepth + 1] = gstack[gdepth]; gdepth++; } isim_gfx_save(); }
void CGContextRestoreGState(CGContextRef c) { if (gdepth > 0) gdepth--; isim_gfx_restore(); }
void CGContextTranslateCTM(CGContextRef c, CGFloat tx, CGFloat ty) { isim_gfx_translate(tx, ty); }
void CGContextScaleCTM(CGContextRef c, CGFloat sx, CGFloat sy) { isim_gfx_scale(sx, sy); }
void CGContextSetRGBFillColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { CGFloat v[4] = { r, g, b, a }; memcpy(cur()->fill, v, sizeof v); }
void CGContextSetRGBStrokeColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { CGFloat v[4] = { r, g, b, a }; memcpy(cur()->stroke, v, sizeof v); }
void CGContextSetFillColorWithColor(CGContextRef c, CGColorRef col) { if (col) memcpy(cur()->fill, col->c, sizeof col->c); }
void CGContextSetStrokeColorWithColor(CGContextRef c, CGColorRef col) { if (col) memcpy(cur()->stroke, col->c, sizeof col->c); }
void CGContextSetLineWidth(CGContextRef c, CGFloat w) { cur()->lw = w; }
void CGContextFillRect(CGContextRef c, CGRect r) { isim_gfx_fill_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, 0, cur()->fill); }
void CGContextStrokeRect(CGContextRef c, CGRect r) { isim_path_begin(); isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); isim_path_stroke(cur()->lw, cur()->stroke); isim_path_begin(); }
void CGContextFillEllipseInRect(CGContextRef c, CGRect r) { isim_gfx_fill_ellipse(r.origin.x, r.origin.y, r.size.width, r.size.height, cur()->fill); }
void CGContextBeginPath(CGContextRef c) { isim_path_begin(); }
void CGContextMoveToPoint(CGContextRef c, CGFloat x, CGFloat y) { isim_path_move(x, y); }
void CGContextAddLineToPoint(CGContextRef c, CGFloat x, CGFloat y) { isim_path_line(x, y); }
void CGContextAddRect(CGContextRef c, CGRect r) { isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); }
/* CG uses a flipped-y "clockwise" flag; in UIKit's top-left coordinates clockwise=1 draws counter-clockwise visually */
void CGContextAddArc(CGContextRef c, CGFloat x, CGFloat y, CGFloat r, CGFloat a0, CGFloat a1, int clockwise) { isim_path_arc(x, y, r, a0, a1, !clockwise); }
void CGContextClosePath(CGContextRef c) { isim_path_close(); }
void CGContextFillPath(CGContextRef c) { isim_path_fill(cur()->fill); isim_path_begin(); }
void CGContextStrokePath(CGContextRef c) { isim_path_stroke(cur()->lw, cur()->stroke); isim_path_begin(); }
