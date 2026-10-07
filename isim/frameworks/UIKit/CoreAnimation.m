/* isim Core Animation: CATransform3D, CALayer (model + presentation layers, layer tree, implicit animations,
 * key paths), the layer renderer and the UIView hooks (3D transforms, masks, shadows, CA animations on a view's
 * own layer). Animations and transactions: CAAnimations.m; layer classes: CALayerKinds.m.
 *
 * Rendering: every frame each layer's presentation copy (model + running animations) is drawn with cairo.
 * Layer-to-parent matrix = T(-anchor - bounds.origin) . transform . T(position) (row vectors, as Core Animation),
 * times the parent's sublayerTransform about its anchor. Affine results are drawn directly; a perspective
 * result renders the layer offscreen and warps the image onto its projected quad (host isim_image_draw_quad). */
#import "CAPrivate.h"
#pragma clang diagnostic ignored "-Watomic-property-with-user-defined-accessor"
#include <objc/runtime.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* ================= CATransform3D ================= */
const CATransform3D CATransform3DIdentity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };
bool CATransform3DIsIdentity(CATransform3D t) { return !memcmp(&t, &CATransform3DIdentity, sizeof t); }
bool CATransform3DEqualToTransform(CATransform3D a, CATransform3D b) {
    const CGFloat *x = &a.m11, *y = &b.m11;
    for (int i = 0; i < 16; i++) if (x[i] != y[i]) return false;
    return true;
}
CATransform3D ca_translate(double x, double y, double z) { CATransform3D t = CATransform3DIdentity; t.m41 = x; t.m42 = y; t.m43 = z; return t; }
CATransform3D CATransform3DMakeTranslation(CGFloat tx, CGFloat ty, CGFloat tz) { return ca_translate(tx, ty, tz); }
CATransform3D CATransform3DMakeScale(CGFloat sx, CGFloat sy, CGFloat sz) { CATransform3D t = CATransform3DIdentity; t.m11 = sx; t.m22 = sy; t.m33 = sz; return t; }
CATransform3D CATransform3DMakeRotation(CGFloat a, CGFloat x, CGFloat y, CGFloat z) {
    double len = sqrt(x * x + y * y + z * z);
    if (len < 1e-12) return CATransform3DIdentity;
    x /= len; y /= len; z /= len;
    double c = cos(a), s = sin(a), t = 1 - c;
    CATransform3D r = CATransform3DIdentity;
    /* Core Animation's (row-vector) rotation: p' = p * R */
    r.m11 = t * x * x + c;     r.m12 = t * x * y + z * s; r.m13 = t * x * z - y * s;
    r.m21 = t * x * y - z * s; r.m22 = t * y * y + c;     r.m23 = t * y * z + x * s;
    r.m31 = t * x * z + y * s; r.m32 = t * y * z - x * s; r.m33 = t * z * z + c;
    return r;
}
CATransform3D ca_mul(CATransform3D a, CATransform3D b) {
    CATransform3D r; const CGFloat *A = &a.m11, *B = &b.m11; CGFloat *R = &r.m11;
    for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) {
        double s = 0; for (int k = 0; k < 4; k++) s += A[i * 4 + k] * B[k * 4 + j];
        R[i * 4 + j] = s;
    }
    return r;
}
CATransform3D CATransform3DConcat(CATransform3D a, CATransform3D b) { return ca_mul(a, b); }
CATransform3D CATransform3DTranslate(CATransform3D t, CGFloat tx, CGFloat ty, CGFloat tz) { return ca_mul(ca_translate(tx, ty, tz), t); }
CATransform3D CATransform3DScale(CATransform3D t, CGFloat sx, CGFloat sy, CGFloat sz) { return ca_mul(CATransform3DMakeScale(sx, sy, sz), t); }
CATransform3D CATransform3DRotate(CATransform3D t, CGFloat a, CGFloat x, CGFloat y, CGFloat z) { return ca_mul(CATransform3DMakeRotation(a, x, y, z), t); }
CATransform3D CATransform3DInvert(CATransform3D t) {
    /* Gauss-Jordan; a singular matrix is returned unchanged (as Core Animation does) */
    double m[4][8];
    const CGFloat *T = &t.m11;
    for (int i = 0; i < 4; i++) for (int j = 0; j < 8; j++) m[i][j] = j < 4 ? T[i * 4 + j] : (j - 4 == i);
    for (int c = 0; c < 4; c++) {
        int piv = c; for (int r = c + 1; r < 4; r++) if (fabs(m[r][c]) > fabs(m[piv][c])) piv = r;
        if (fabs(m[piv][c]) < 1e-12) return t;
        if (piv != c) for (int j = 0; j < 8; j++) { double x = m[c][j]; m[c][j] = m[piv][j]; m[piv][j] = x; }
        double d = m[c][c]; for (int j = 0; j < 8; j++) m[c][j] /= d;
        for (int r = 0; r < 4; r++) if (r != c) { double f = m[r][c]; if (f != 0) for (int j = 0; j < 8; j++) m[r][j] -= f * m[c][j]; }
    }
    CATransform3D o; CGFloat *O = &o.m11;
    for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) O[i * 4 + j] = m[i][j + 4];
    return o;
}
CATransform3D CATransform3DMakeAffineTransform(CGAffineTransform m) {
    CATransform3D t = CATransform3DIdentity;
    t.m11 = m.a; t.m12 = m.b; t.m21 = m.c; t.m22 = m.d; t.m41 = m.tx; t.m42 = m.ty;
    return t;
}
bool CATransform3DIsAffine(CATransform3D t) {
    return t.m13 == 0 && t.m14 == 0 && t.m23 == 0 && t.m24 == 0 && t.m31 == 0 && t.m32 == 0 && t.m33 == 1 && t.m34 == 0 && t.m43 == 0 && t.m44 == 1;
}
CGAffineTransform CATransform3DGetAffineTransform(CATransform3D t) { return (CGAffineTransform){ t.m11, t.m12, t.m21, t.m22, t.m41, t.m42 }; }
BOOL ca_is_affine2d(CATransform3D t) { return fabs(t.m14) < 1e-12 && fabs(t.m24) < 1e-12 && fabs(t.m44 - 1) < 1e-12; }
CGPoint ca_project(CATransform3D t, double x, double y, double *w) {
    double X = x * t.m11 + y * t.m21 + t.m41, Y = x * t.m12 + y * t.m22 + t.m42, W = x * t.m14 + y * t.m24 + t.m44;
    if (w) *w = W;
    return fabs(W) < 1e-12 ? CGPointMake(X, Y) : CGPointMake(X / W, Y / W);
}
CFTimeInterval CACurrentMediaTime(void) { return isim_time(); }

/* ================= NSValue: transforms and vectors ================= */
@interface __IsimGeometryValue : NSValue { @public int _k; CATransform3D _t; CGAffineTransform _a; CGVector _v; }
@end
@implementation __IsimGeometryValue
- (const char *)objCType {
    return _k == 0 ? "{CATransform3D=dddddddddddddddd}" : _k == 1 ? "{CGAffineTransform=dddddd}" : "{CGVector=dd}";
}
- (CATransform3D)CATransform3DValue { return _k == 0 ? _t : _k == 1 ? CATransform3DMakeAffineTransform(_a) : CATransform3DIdentity; }
- (CGAffineTransform)CGAffineTransformValue { return _k == 1 ? _a : _k == 0 ? CATransform3DGetAffineTransform(_t) : CGAffineTransformIdentity; }
- (CGVector)CGVectorValue { return _k == 2 ? _v : (CGVector){ 0, 0 }; }
- (BOOL)isEqualToValue:(NSValue *)o {
    if (![o isKindOfClass:[__IsimGeometryValue class]]) return NO;
    __IsimGeometryValue *g = (__IsimGeometryValue *)o;
    return g->_k == _k && (_k == 0 ? CATransform3DEqualToTransform(_t, g->_t) : _k == 1 ? CGAffineTransformEqualToTransform(_a, g->_a) : (_v.dx == g->_v.dx && _v.dy == g->_v.dy));
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSValue class]] && [self isEqualToValue:o]; }
- (NSUInteger)hash { return (NSUInteger)(_t.m11 * 31 + _t.m41 * 7 + _a.a * 3 + _a.tx + _v.dx * 13) ^ (NSUInteger)_k; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description {
    if (_k == 1) return [NSString stringWithFormat:@"CGAffineTransform: {{%g, %g, %g, %g}, {%g, %g}}", _a.a, _a.b, _a.c, _a.d, _a.tx, _a.ty];
    if (_k == 2) return [NSString stringWithFormat:@"CGVector: {%g, %g}", _v.dx, _v.dy];
    return [NSString stringWithFormat:@"CATransform3D: {%g %g %g %g; %g %g %g %g; %g %g %g %g; %g %g %g %g}", _t.m11, _t.m12, _t.m13, _t.m14,
            _t.m21, _t.m22, _t.m23, _t.m24, _t.m31, _t.m32, _t.m33, _t.m34, _t.m41, _t.m42, _t.m43, _t.m44];
}
@end
@implementation NSValue (CATransform3DAdditions)
+ (NSValue *)valueWithCATransform3D:(CATransform3D)t { __IsimGeometryValue *v = [__IsimGeometryValue new]; v->_k = 0; v->_t = t; return v; }
- (CATransform3D)CATransform3DValue { return CATransform3DIdentity; }
@end
@implementation NSValue (IsimUIGeometryAdditions)
+ (NSValue *)valueWithCGAffineTransform:(CGAffineTransform)a { __IsimGeometryValue *v = [__IsimGeometryValue new]; v->_k = 1; v->_a = a; return v; }
+ (NSValue *)valueWithCGVector:(CGVector)d { __IsimGeometryValue *v = [__IsimGeometryValue new]; v->_k = 2; v->_v = d; return v; }
- (CGAffineTransform)CGAffineTransformValue { return CGAffineTransformIdentity; }
- (CGVector)CGVectorValue { return (CGVector){ 0, 0 }; }
@end
@implementation NSNull (CAActionAdditions)
- (void)runActionForKey:(NSString *)event object:(id)o arguments:(NSDictionary *)d {}
@end

/* ================= values ================= */
void ca_rgba(CGColorRef c, double out[4]) {
    if (!c) { out[0] = out[1] = out[2] = out[3] = 0; return; }
    isim_cg_color_rgba(c, out);          /* sRGB RGBA whatever the color's space (gray colors have 2 components) */
}
CGColorRef ca_color(const double rgba[4]) {
    CGColorRef c = CGColorCreateSRGB(fmin(1, fmax(0, rgba[0])), fmin(1, fmax(0, rgba[1])), fmin(1, fmax(0, rgba[2])), fmin(1, fmax(0, rgba[3])));
    CFAutorelease(c);
    return c;
}
static BOOL is_cgcolor(id o) { static Class k; if (!k) k = objc_getClass("__NSCGColor"); return k && [o isKindOfClass:k]; }
static BOOL color_rgba(id o, double out[4]) {
    if (is_cgcolor(o)) { ca_rgba((__bridge CGColorRef)o, out); return YES; }
    if ([o isKindOfClass:[UIColor class]]) { isim_ui_rgba(o, out); return YES; }
    return NO;
}
static BOOL value_struct(id o, const char *prefix) { return [o isKindOfClass:[NSValue class]] && !strncmp([(NSValue *)o objCType], prefix, strlen(prefix)); }
BOOL ca_val_from_id(id o, int kind, ca_val *out) {
    memset(out, 0, sizeof *out);
    out->kind = kind;
    if (!o || o == (id)[NSNull null]) return NO;
    switch (kind) {
    case CAV_NUM:
        if (![o isKindOfClass:[NSNumber class]]) return NO;
        out->n = 1; out->v[0] = [o doubleValue]; return YES;
    case CAV_POINT:
        if (value_struct(o, "{CGPoint")) { CGPoint p = [o CGPointValue]; out->n = 2; out->v[0] = p.x; out->v[1] = p.y; return YES; }
        if (value_struct(o, "{CGSize")) { CGSize s = [o CGSizeValue]; out->n = 2; out->v[0] = s.width; out->v[1] = s.height; return YES; }
        return NO;
    case CAV_SIZE:
        if (value_struct(o, "{CGSize")) { CGSize s = [o CGSizeValue]; out->n = 2; out->v[0] = s.width; out->v[1] = s.height; return YES; }
        if (value_struct(o, "{CGPoint")) { CGPoint p = [o CGPointValue]; out->n = 2; out->v[0] = p.x; out->v[1] = p.y; return YES; }
        return NO;
    case CAV_RECT:
        if (!value_struct(o, "{CGRect")) return NO;
        { CGRect r = [o CGRectValue]; out->n = 4; out->v[0] = r.origin.x; out->v[1] = r.origin.y; out->v[2] = r.size.width; out->v[3] = r.size.height; }
        return YES;
    case CAV_COLOR:
        out->n = 4; return color_rgba(o, out->v);
    case CAV_T3D: {
        CATransform3D t;
        if (value_struct(o, "{CATransform3D")) t = [o CATransform3DValue];
        else if (value_struct(o, "{CGAffineTransform")) t = CATransform3DMakeAffineTransform([o CGAffineTransformValue]);
        else return NO;
        out->n = 16; memcpy(out->v, &t, sizeof t); return YES;
    }
    case CAV_NUMS:
        if (![o isKindOfClass:[NSArray class]]) return NO;
        for (id x in (NSArray *)o) { if (out->n >= CAV_MAX) break; out->v[out->n++] = [x isKindOfClass:[NSNumber class]] ? [x doubleValue] : 0; }
        return YES;
    case CAV_COLORS:
        if (![o isKindOfClass:[NSArray class]]) return NO;
        for (id x in (NSArray *)o) { if (out->n + 4 > CAV_MAX) break; if (!color_rgba(x, &out->v[out->n])) memset(&out->v[out->n], 0, 4 * sizeof(double)); out->n += 4; }
        return YES;
    default:
        out->kind = CAV_OBJ; out->obj = o; return YES;
    }
}
id ca_val_to_id(const ca_val *v) {
    switch (v->kind) {
    case CAV_NUM: return @(v->v[0]);
    case CAV_POINT: return [NSValue valueWithCGPoint:CGPointMake(v->v[0], v->v[1])];
    case CAV_SIZE: return [NSValue valueWithCGSize:CGSizeMake(v->v[0], v->v[1])];
    case CAV_RECT: return [NSValue valueWithCGRect:CGRectMake(v->v[0], v->v[1], v->v[2], v->v[3])];
    case CAV_COLOR: return (__bridge id)ca_color(v->v);
    case CAV_T3D: { CATransform3D t; memcpy(&t, v->v, sizeof t); return [NSValue valueWithCATransform3D:t]; }
    case CAV_NUMS: { NSMutableArray *a = [NSMutableArray array]; for (int i = 0; i < v->n; i++) [a addObject:@(v->v[i])]; return a; }
    case CAV_COLORS: { NSMutableArray *a = [NSMutableArray array]; for (int i = 0; i + 3 < v->n; i += 4) [a addObject:(__bridge id)ca_color(&v->v[i])]; return a; }
    case CAV_OBJ: return v->obj;
    default: return nil;
    }
}

/* paths with the same structure morph point by point */
typedef struct { int n, cap; int *types; CGPoint *pts; int npts; } path_pts;
static void collect_path(void *info, const CGPathElement *e) {
    path_pts *pp = info;
    static const int count[] = { 1, 1, 2, 3, 0 };
    int c = e->type <= 4 ? count[e->type] : 0;
    if (pp->n == pp->cap) { pp->cap = pp->cap ? pp->cap * 2 : 32; pp->types = realloc(pp->types, pp->cap * sizeof(int)); pp->pts = realloc(pp->pts, pp->cap * 3 * sizeof(CGPoint)); }
    pp->types[pp->n] = e->type;
    for (int i = 0; i < 3; i++) pp->pts[pp->n * 3 + i] = i < c ? e->points[i] : CGPointZero;
    pp->n++;
}
static BOOL is_cgpath(id o) { static Class k; if (!k) k = objc_getClass("__NSCGPath"); return k && [o isKindOfClass:k]; }
static id morph_paths(id a, id b, double t) {
    path_pts pa = { 0 }, pb = { 0 };
    CGPathApply((__bridge CGPathRef)a, &pa, collect_path); CGPathApply((__bridge CGPathRef)b, &pb, collect_path);
    id out = nil;
    if (pa.n == pb.n && pa.n > 0 && !memcmp(pa.types, pb.types, pa.n * sizeof(int))) {
        CGMutablePathRef p = CGPathCreateMutable();
        for (int i = 0; i < pa.n; i++) {
            CGPoint q[3];
            for (int k = 0; k < 3; k++) q[k] = CGPointMake(pa.pts[i * 3 + k].x + (pb.pts[i * 3 + k].x - pa.pts[i * 3 + k].x) * t, pa.pts[i * 3 + k].y + (pb.pts[i * 3 + k].y - pa.pts[i * 3 + k].y) * t);
            switch (pa.types[i]) {
            case kCGPathElementMoveToPoint: CGPathMoveToPoint(p, NULL, q[0].x, q[0].y); break;
            case kCGPathElementAddLineToPoint: CGPathAddLineToPoint(p, NULL, q[0].x, q[0].y); break;
            case kCGPathElementAddQuadCurveToPoint: CGPathAddQuadCurveToPoint(p, NULL, q[0].x, q[0].y, q[1].x, q[1].y); break;
            case kCGPathElementAddCurveToPoint: CGPathAddCurveToPoint(p, NULL, q[0].x, q[0].y, q[1].x, q[1].y, q[2].x, q[2].y); break;
            case kCGPathElementCloseSubpath: CGPathCloseSubpath(p); break;
            }
        }
        out = CFBridgingRelease(p);
    } else out = t < 0.5 ? a : b;
    free(pa.types); free(pa.pts); free(pb.types); free(pb.pts);
    return out;
}

/* transforms interpolate through a 2D decomposition (translation, scale, rotation, skew) when both are
   2D-affine with the same perspective terms, else component by component */
typedef struct { double tx, ty, sx, sy, rot, skew; } decomp2d;
static decomp2d decompose2d(const CATransform3D *t) {
    decomp2d d; double a = t->m11, b = t->m12, c = t->m21, dd = t->m22;
    d.tx = t->m41; d.ty = t->m42;
    d.sx = sqrt(a * a + b * b);
    d.rot = atan2(b, a);
    double cs = cos(d.rot), sn = sin(d.rot);
    /* remove rotation: [a b; c d] = [sx 0; k sy] R  (row vectors) */
    double c2 = c * cs + dd * sn, d2 = -c * sn + dd * cs;
    d.sy = d2; d.skew = d.sy != 0 ? c2 / d.sy : 0;
    if (d.sx == 0) d.rot = 0;
    return d;
}
static void recompose2d(decomp2d d, CATransform3D *t) {
    double cs = cos(d.rot), sn = sin(d.rot);
    /* S(sx, sy) with skew, then rotation: rows [sx 0], [k*sy sy] times R = [cs sn; -sn cs] */
    t->m11 = d.sx * cs; t->m12 = d.sx * sn;
    t->m21 = d.skew * d.sy * cs - d.sy * sn; t->m22 = d.skew * d.sy * sn + d.sy * cs;
    t->m41 = d.tx; t->m42 = d.ty;
}
static BOOL same_3d_terms(const CATransform3D *a, const CATransform3D *b) {
    return a->m13 == b->m13 && a->m14 == b->m14 && a->m23 == b->m23 && a->m24 == b->m24 && a->m31 == b->m31 && a->m32 == b->m32
        && a->m33 == b->m33 && a->m34 == b->m34 && a->m43 == b->m43 && a->m44 == b->m44;
}
void ca_val_lerp(const ca_val *a, const ca_val *b, double t, ca_val *out) {
    if (a->kind == CAV_OBJ || b->kind == CAV_OBJ) {
        *out = *a; out->kind = CAV_OBJ;
        if (is_cgpath(a->obj) && is_cgpath(b->obj)) out->obj = morph_paths(a->obj, b->obj, t);
        else out->obj = t < 0.5 ? a->obj : b->obj;
        return;
    }
    if (a->kind == CAV_T3D && b->kind == CAV_T3D) {
        CATransform3D A, B, R; memcpy(&A, a->v, sizeof A); memcpy(&B, b->v, sizeof B);
        if (same_3d_terms(&A, &B)) {
            decomp2d da = decompose2d(&A), db = decompose2d(&B), dr;
            double dr0 = db.rot - da.rot;
            dr.tx = da.tx + (db.tx - da.tx) * t; dr.ty = da.ty + (db.ty - da.ty) * t;
            dr.sx = da.sx + (db.sx - da.sx) * t; dr.sy = da.sy + (db.sy - da.sy) * t;
            dr.rot = da.rot + dr0 * t; dr.skew = da.skew + (db.skew - da.skew) * t;
            R = A; recompose2d(dr, &R);
        } else { const CGFloat *x = &A.m11, *y = &B.m11; CGFloat *r = &R.m11; for (int i = 0; i < 16; i++) r[i] = x[i] + (y[i] - x[i]) * t; }
        *out = *a; memcpy(out->v, &R, sizeof R); return;
    }
    *out = *a;
    int n = a->n < b->n ? a->n : b->n;
    if (a->n != b->n && (a->kind == CAV_NUMS || a->kind == CAV_COLORS)) { *out = t < 0.5 ? *a : *b; return; }
    for (int i = 0; i < n; i++) out->v[i] = a->v[i] + (b->v[i] - a->v[i]) * t;
}
void ca_val_add(const ca_val *a, const ca_val *b, double k, ca_val *out) {
    if (a->kind == CAV_OBJ) { *out = *a; return; }
    if (a->kind == CAV_T3D) {      /* transforms compose: a then b, k times (integer k) */
        CATransform3D A, B; memcpy(&A, a->v, sizeof A); memcpy(&B, b->v, sizeof B);
        CATransform3D r = A; int times = (int)lround(fabs(k));
        if (k > 0) for (int i = 0; i < times; i++) r = ca_mul(B, r);
        else if (k < 0) { CATransform3D inv = CATransform3DInvert(B); for (int i = 0; i < times; i++) r = ca_mul(inv, r); }
        *out = *a; memcpy(out->v, &r, sizeof r); return;
    }
    *out = *a;
    int n = a->n < b->n ? a->n : b->n;
    for (int i = 0; i < n; i++) out->v[i] = a->v[i] + k * b->v[i];
}
double ca_val_distance(const ca_val *a, const ca_val *b) {
    double s = 0; int n = a->n < b->n ? a->n : b->n;
    for (int i = 0; i < n; i++) s += (b->v[i] - a->v[i]) * (b->v[i] - a->v[i]);
    return sqrt(s);
}

/* ================= paths ================= */
void ca_emit_path(CGPathRef path) {
    isim_path_begin();
    CGContextAddPath(isim_cg_current_context(), path);
}
/* rounded rect with only some corners rounded (maskedCorners) */
void ca_rounded_path(CGRect r, double rad, CACornerMask m) {
    isim_path_begin();
    rad = fmax(0, fmin(rad, fmin(r.size.width, r.size.height) / 2));
    if (rad <= 0 || m == 0) { isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); return; }
    if (m == 15) { isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, rad); return; }
    double x0 = r.origin.x, y0 = r.origin.y, x1 = x0 + r.size.width, y1 = y0 + r.size.height;
    double tl = m & kCALayerMinXMinYCorner ? rad : 0, tr = m & kCALayerMaxXMinYCorner ? rad : 0;
    double bl = m & kCALayerMinXMaxYCorner ? rad : 0, br = m & kCALayerMaxXMaxYCorner ? rad : 0;
    isim_path_move(x0 + tl, y0);
    isim_path_line(x1 - tr, y0); if (tr > 0) isim_path_arc(x1 - tr, y0 + tr, tr, -M_PI / 2, 0, 1);
    isim_path_line(x1, y1 - br); if (br > 0) isim_path_arc(x1 - br, y1 - br, br, 0, M_PI / 2, 1);
    isim_path_line(x0 + bl, y1); if (bl > 0) isim_path_arc(x0 + bl, y1 - bl, bl, M_PI / 2, M_PI, 1);
    isim_path_line(x0, y0 + tl); if (tl > 0) isim_path_arc(x0 + tl, y0 + tl, tl, M_PI, 1.5 * M_PI, 1);
    isim_path_close();
}

/* ================= CALayer ================= */
CALayerCornerCurve const kCACornerCurveCircular = @"circular", kCACornerCurveContinuous = @"continuous";
CALayerContentsFilter const kCAFilterNearest = @"nearest", kCAFilterLinear = @"linear", kCAFilterTrilinear = @"trilinear";
CALayerContentsGravity const kCAGravityCenter = @"center", kCAGravityTop = @"top", kCAGravityBottom = @"bottom", kCAGravityLeft = @"left",
    kCAGravityRight = @"right", kCAGravityTopLeft = @"topLeft", kCAGravityTopRight = @"topRight", kCAGravityBottomLeft = @"bottomLeft",
    kCAGravityBottomRight = @"bottomRight", kCAGravityResize = @"resize", kCAGravityResizeAspect = @"resizeAspect",
    kCAGravityResizeAspectFill = @"resizeAspectFill";
CALayerContentsFormat const kCAContentsFormatRGBA8Uint = @"RGBA8";
CAMediaTimingFillMode const kCAFillModeForwards = @"forwards", kCAFillModeBackwards = @"backwards", kCAFillModeBoth = @"both", kCAFillModeRemoved = @"removed";

/* an animation attached to a layer */
@interface __IsimCAEntry : NSObject { @public CAAnimation *anim; NSString *key; BOOL started, stopped; NSArray *txs; }
@end
@implementation __IsimCAEntry @end

static NSMutableArray<CALayer *> *animated_layers;     /* layers with attached animations (kept alive, like CA) */
NSMutableArray *ca_animated_layers(void) { return animated_layers; }
static int key_counter;

@implementation CALayer {
    CGRect _bounds; CGPoint _position;
    NSMutableArray<CALayer *> *_subs;
    __weak CALayer *_isimSuper;
    __weak UIView *_ownerView;
    NSMutableArray<__IsimCAEntry *> *_entries;
    CALayer *_model;                     /* set on presentation copies */
    NSMutableDictionary *_extra;         /* KVC values for undeclared keys */
    BOOL _needsDisplayFlag, _needsLayoutFlag, _rendered, _has3D;
    CGAffineTransform _affineAt3D;       /* a view's layer: the view transform when its 3D transform was set */
}
@synthesize transform = _transform, sublayerTransform = _sublayerTransform, anchorPoint = _anchorPoint, zPosition = _zPosition,
    cornerRadius = _cornerRadius, borderWidth = _borderWidth, borderColor = _borderColor, backgroundColor = _backgroundColor,
    shadowColor = _shadowColor, opacity = _opacity, shadowOpacity = _shadowOpacity, shadowRadius = _shadowRadius, shadowOffset = _shadowOffset,
    shadowPath = _shadowPath, masksToBounds = _masksToBounds, hidden = _hidden, contents = _contents, contentsRect = _contentsRect,
    mask = _mask, delegate = _delegate, beginTime = _beginTime, timeOffset = _timeOffset, speed = _speed, maskedCorners = _maskedCorners,
    contentsCenter = _contentsCenter, contentsScale = _contentsScale, contentsGravity = _contentsGravity;
+ (instancetype)layer { return [self new]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)init {
    if ((self = [super init])) {
        _opacity = 1; _speed = 1; _anchorPoint = CGPointMake(0.5, 0.5);
        _transform = _sublayerTransform = CATransform3DIdentity;
        _cornerCurve = kCACornerCurveCircular; _shadowOffset = CGSizeMake(0, -3); _shadowRadius = 3;
        _magnificationFilter = kCAFilterLinear; _minificationFilter = kCAFilterLinear;
        _contentsRect = CGRectMake(0, 0, 1, 1); _contentsCenter = CGRectMake(0, 0, 1, 1); _contentsGravity = kCAGravityResize;
        _contentsScale = 1; _rasterizationScale = 1; _allowsGroupOpacity = YES; _maskedCorners = 15; _edgeAntialiasingMask = 15;
        _doubleSided = YES; _fillMode = kCAFillModeRemoved; _contentsFormat = kCAContentsFormatRGBA8Uint;
        _shadowColor = CGColorCreateSRGB(0, 0, 0, 1);
    }
    return self;
}
- (instancetype)initWithLayer:(id)other {
    if (!(self = [self init])) return nil;
    CALayer *o = other;
    if (![o isKindOfClass:[CALayer class]]) return self;
    _bounds = o.bounds; _position = o.position; _anchorPoint = o->_anchorPoint; _zPosition = o->_zPosition; _anchorPointZ = o->_anchorPointZ;
    _transform = o.transform; _sublayerTransform = o->_sublayerTransform;
    _cornerRadius = o->_cornerRadius; _borderWidth = o->_borderWidth; _maskedCorners = o->_maskedCorners; _cornerCurve = o->_cornerCurve;
    self.borderColor = o->_borderColor; self.backgroundColor = o->_backgroundColor; self.shadowColor = o->_shadowColor; self.shadowPath = o->_shadowPath;
    _opacity = o->_opacity; _shadowOpacity = o->_shadowOpacity; _shadowRadius = o->_shadowRadius; _shadowOffset = o->_shadowOffset;
    _masksToBounds = o->_masksToBounds; _hidden = o->_hidden; _opaque = o->_opaque; _mask = o->_mask;
    _contents = o->_contents; _contentsRect = o->_contentsRect; _contentsCenter = o->_contentsCenter; _contentsGravity = o->_contentsGravity;
    _contentsScale = o->_contentsScale; _magnificationFilter = o->_magnificationFilter; _minificationFilter = o->_minificationFilter;
    _name = o->_name; _delegate = o->_delegate; _speed = o->_speed; _beginTime = o->_beginTime; _timeOffset = o->_timeOffset;
    _geometryFlipped = o->_geometryFlipped; _doubleSided = o->_doubleSided;
    if (o->_extra) _extra = [o->_extra mutableCopy];
    return self;
}
- (void)dealloc {
    if (_borderColor) CGColorRelease(_borderColor);
    if (_backgroundColor) CGColorRelease(_backgroundColor);
    if (_shadowColor) CGColorRelease(_shadowColor);
    if (_shadowPath) CGPathRelease(_shadowPath);
}

/* ---- view-backed layers ---- */
- (void)_isim_setOwnerView:(id)view { _ownerView = view; _delegate = view; }
- (UIView *)_isim_ownerView { return _ownerView; }
- (BOOL)_isim_isViewLayer { return _ownerView != nil; }

/* ---- implicit animations ---- */
static NSSet *implicit_keys;
static id<CAAction> implicit_action(CALayer *l, NSString *key) {
    if (l->_ownerView || l->_model || !l->_rendered || ca_tx_disabled()) return nil;
    if (!implicit_keys) implicit_keys = [NSSet setWithArray:@[ @"bounds", @"position", @"zPosition", @"anchorPoint", @"transform", @"sublayerTransform",
        @"opacity", @"backgroundColor", @"cornerRadius", @"borderWidth", @"borderColor", @"shadowOpacity", @"shadowRadius", @"shadowOffset",
        @"shadowColor", @"shadowPath", @"contentsRect", @"path", @"fillColor", @"strokeColor", @"strokeStart", @"strokeEnd", @"lineWidth",
        @"lineDashPhase", @"miterLimit", @"colors", @"locations", @"startPoint", @"endPoint", @"fontSize", @"foregroundColor",
        @"instanceDelay", @"instanceTransform", @"instanceColor", @"instanceRedOffset", @"instanceGreenOffset", @"instanceBlueOffset",
        @"instanceAlphaOffset", @"emitterPosition", @"emitterSize", @"birthRate", @"velocity", @"scale", @"spin" ]];
    if (![implicit_keys containsObject:key]) return nil;
    return [l actionForKey:key];
}
#define CA_SET(KEY, ASSIGN) do { id<CAAction> _act = implicit_action(self, KEY); ASSIGN; isim_ui_set_needs_display(); \
                                 if (_act) [_act runActionForKey:KEY object:self arguments:nil]; } while (0)
- (id<CAAction>)_isim_implicitAction:(NSString *)key { return implicit_action(self, key); }
- (id<CAAction>)actionForKey:(NSString *)event {
    id d = _delegate;
    if (d && !_ownerView && [d respondsToSelector:@selector(actionForLayer:forKey:)]) {
        id a = [d actionForLayer:self forKey:event];
        if (a) return a == [NSNull null] ? nil : a;
    }
    id a = _actions[event];
    if (a) return a == [NSNull null] ? nil : a;
    a = [[self class] defaultActionForKey:event];
    if (a) return a == [NSNull null] ? nil : a;
    if (!implicit_keys || ![implicit_keys containsObject:event]) return nil;
    CABasicAnimation *b = [CABasicAnimation animationWithKeyPath:event];
    CALayer *p = [self presentationLayer];
    b.fromValue = [p valueForKey:event];
    b.duration = ca_tx_duration();
    b.timingFunction = ca_tx_timing() ?: [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    return b;
}
+ (id<CAAction>)defaultActionForKey:(NSString *)event { return nil; }
+ (id)defaultValueForKey:(NSString *)key { return nil; }
+ (BOOL)needsDisplayForKey:(NSString *)key { return NO; }
- (BOOL)shouldArchiveValueForKey:(NSString *)key { return YES; }

/* ---- geometry ---- */
- (CGRect)bounds { UIView *v = _ownerView; return v ? v.bounds : _bounds; }
- (void)setBounds:(CGRect)b {
    UIView *v = _ownerView;
    if (v) { v.bounds = b; return; }
    BOOL resized = !CGSizeEqualToSize(b.size, _bounds.size);
    CA_SET(@"bounds", _bounds = b);
    if (resized) { _needsLayoutFlag = YES; if (_needsDisplayOnBoundsChange) _needsDisplayFlag = YES; }
}
- (CGPoint)position { UIView *v = _ownerView; return v ? v.center : _position; }
- (void)setPosition:(CGPoint)p {
    UIView *v = _ownerView;
    if (v) { v.center = p; return; }
    CA_SET(@"position", _position = p);
}
- (void)setAnchorPoint:(CGPoint)a { CA_SET(@"anchorPoint", _anchorPoint = a); }
- (void)setZPosition:(CGFloat)z { CA_SET(@"zPosition", _zPosition = z); }
- (CGRect)frame {
    UIView *v = _ownerView;
    if (v) return v.frame;
    CGRect b = _bounds;
    CGRect r = CGRectMake(_position.x - _anchorPoint.x * b.size.width, _position.y - _anchorPoint.y * b.size.height, b.size.width, b.size.height);
    if (CATransform3DIsIdentity(_transform)) return r;
    /* the bounding box of the transformed bounds, about the anchor point */
    CATransform3D m = ca_mul(ca_mul(ca_translate(-_anchorPoint.x * b.size.width, -_anchorPoint.y * b.size.height, 0), _transform), ca_translate(_position.x, _position.y, 0));
    double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
    for (int i = 0; i < 4; i++) {
        CGPoint q = ca_project(m, (i & 1) ? b.size.width : 0, (i & 2) ? b.size.height : 0, NULL);
        x0 = fmin(x0, q.x); y0 = fmin(y0, q.y); x1 = fmax(x1, q.x); y1 = fmax(y1, q.y);
    }
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
- (void)setFrame:(CGRect)f {
    UIView *v = _ownerView;
    if (v) { v.frame = f; return; }
    f = CGRectStandardize(f);
    CGRect b = _bounds; b.size = f.size;
    self.bounds = b;
    self.position = CGPointMake(f.origin.x + _anchorPoint.x * f.size.width, f.origin.y + _anchorPoint.y * f.size.height);
}
- (CATransform3D)transform {
    UIView *v = _ownerView;
    if (!v) return _transform;
    if (_has3D && CGAffineTransformEqualToTransform(v.transform, _affineAt3D)) return _transform;
    return CATransform3DMakeAffineTransform(v.transform);
}
- (void)setTransform:(CATransform3D)t {
    UIView *v = _ownerView;
    if (v) {
        if (CATransform3DIsAffine(t)) { _has3D = NO; v.transform = CATransform3DGetAffineTransform(t); }
        else { _transform = t; _has3D = YES; _affineAt3D = CATransform3DGetAffineTransform(t); v.transform = _affineAt3D; }
        isim_ui_set_needs_display();
        return;
    }
    CA_SET(@"transform", _transform = t);
}
- (BOOL)_isim_has3D { UIView *v = _ownerView; return v && _has3D && CGAffineTransformEqualToTransform(v.transform, _affineAt3D); }
- (void)setSublayerTransform:(CATransform3D)t { CA_SET(@"sublayerTransform", _sublayerTransform = t); }
- (CGAffineTransform)affineTransform { return CATransform3DGetAffineTransform(self.transform); }
- (void)setAffineTransform:(CGAffineTransform)m { self.transform = CATransform3DMakeAffineTransform(m); }
- (CGSize)preferredFrameSize { return self.bounds.size; }

/* layer -> superlayer matrix */
static CATransform3D layer_matrix(CALayer *p) {
    CGRect b = p.bounds; CGPoint pos = p.position; CGPoint a = p.anchorPoint;
    CATransform3D t = p.transform;
    CATransform3D m = ca_translate(-b.origin.x - a.x * b.size.width, -b.origin.y - a.y * b.size.height, -p.anchorPointZ);
    if (!CATransform3DIsIdentity(t)) m = ca_mul(m, t);
    m = ca_mul(m, ca_translate(pos.x, pos.y, p.zPosition + p.anchorPointZ));
    return m;
}
static CATransform3D sublayer_matrix(CALayer *p) {
    CATransform3D s = p.sublayerTransform;
    if (CATransform3DIsIdentity(s)) return CATransform3DIdentity;
    CGRect b = p.bounds; CGPoint a = p.anchorPoint;
    double cx = b.origin.x + a.x * b.size.width, cy = b.origin.y + a.y * b.size.height;
    return ca_mul(ca_mul(ca_translate(-cx, -cy, 0), s), ca_translate(cx, cy, 0));
}
- (CALayer *)superlayer {
    if (_isimSuper) return _isimSuper;
    UIView *v = _ownerView;
    return v.superview.layer;
}
/* this layer's coordinates -> the root's (window) */
static CATransform3D to_root(CALayer *l) {
    CATransform3D m = CATransform3DIdentity;
    for (CALayer *c = l; c; ) {
        CALayer *s = c.superlayer;
        m = ca_mul(m, layer_matrix(c));
        if (!s) break;
        m = ca_mul(m, sublayer_matrix(s));
        c = s;
    }
    return m;
}
- (CGPoint)convertPoint:(CGPoint)p toLayer:(CALayer *)l {
    CATransform3D m = to_root(self);
    if (l) m = ca_mul(m, CATransform3DInvert(to_root(l)));
    return ca_project(m, p.x, p.y, NULL);
}
- (CGPoint)convertPoint:(CGPoint)p fromLayer:(CALayer *)l { return l ? [l convertPoint:p toLayer:self] : ca_project(CATransform3DInvert(to_root(self)), p.x, p.y, NULL); }
- (CGRect)convertRect:(CGRect)r toLayer:(CALayer *)l {
    double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
    for (int i = 0; i < 4; i++) {
        CGPoint q = [self convertPoint:CGPointMake(r.origin.x + ((i & 1) ? r.size.width : 0), r.origin.y + ((i & 2) ? r.size.height : 0)) toLayer:l];
        x0 = fmin(x0, q.x); y0 = fmin(y0, q.y); x1 = fmax(x1, q.x); y1 = fmax(y1, q.y);
    }
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
- (CGRect)convertRect:(CGRect)r fromLayer:(CALayer *)l {
    double x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
    for (int i = 0; i < 4; i++) {
        CGPoint q = [self convertPoint:CGPointMake(r.origin.x + ((i & 1) ? r.size.width : 0), r.origin.y + ((i & 2) ? r.size.height : 0)) fromLayer:l];
        x0 = fmin(x0, q.x); y0 = fmin(y0, q.y); x1 = fmax(x1, q.x); y1 = fmax(y1, q.y);
    }
    return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
- (BOOL)containsPoint:(CGPoint)p { return CGRectContainsPoint(self.bounds, p); }
/* p is in the superlayer's coordinates */
- (CALayer *)hitTest:(CGPoint)p {
    if (_hidden) return nil;
    CATransform3D inv = CATransform3DInvert(layer_matrix(self));
    CGPoint q = ca_project(inv, p.x, p.y, NULL);
    if (_masksToBounds && ![self containsPoint:q]) return nil;
    CATransform3D sinv = CATransform3DInvert(sublayer_matrix(self));
    CGPoint qs = ca_project(sinv, q.x, q.y, NULL);
    for (CALayer *s in [_subs reverseObjectEnumerator]) { CALayer *h = [s hitTest:qs]; if (h) return h; }
    return [self containsPoint:q] ? self : nil;
}
- (CFTimeInterval)_isim_localTimeFrom:(CFTimeInterval)t {
    CALayer *s = self.superlayer;
    if (s) t = [s _isim_localTimeFrom:t];
    if (_speed == 1 && _beginTime == 0 && _timeOffset == 0) return t;
    return (t - _beginTime) * _speed + _timeOffset;
}
- (double)_isim_localTime:(double)mediaTime { return [self _isim_localTimeFrom:mediaTime - ca_time_shift]; }
- (CFTimeInterval)convertTime:(CFTimeInterval)t fromLayer:(CALayer *)l {
    /* to media time: invert l's chain (linear), then into ours */
    double media = t;
    if (l) {
        double a = [l _isim_localTimeFrom:0], b = [l _isim_localTimeFrom:1];
        double k = b - a; media = k != 0 ? (t - a) / k : 0;
    }
    return [self _isim_localTimeFrom:media];
}
- (CFTimeInterval)convertTime:(CFTimeInterval)t toLayer:(CALayer *)l {
    double a = [self _isim_localTimeFrom:0], b = [self _isim_localTimeFrom:1], k = b - a;
    double media = k != 0 ? (t - a) / k : 0;
    return l ? [l _isim_localTimeFrom:media] : media;
}
- (void)setSpeed:(float)s { _speed = s; isim_ui_set_needs_display(); }
- (void)setTimeOffset:(CFTimeInterval)t { _timeOffset = t; isim_ui_set_needs_display(); }
- (void)setBeginTime:(CFTimeInterval)t { _beginTime = t; isim_ui_set_needs_display(); }

/* ---- appearance ---- */
- (void)setBorderColor:(CGColorRef)c { CGColorRetain(c); CA_SET(@"borderColor", { if (_borderColor) CGColorRelease(_borderColor); _borderColor = c; }); }
- (void)setBackgroundColor:(CGColorRef)c { CGColorRetain(c); CA_SET(@"backgroundColor", { if (_backgroundColor) CGColorRelease(_backgroundColor); _backgroundColor = c; }); }
- (void)setShadowColor:(CGColorRef)c { CGColorRetain(c); CA_SET(@"shadowColor", { if (_shadowColor) CGColorRelease(_shadowColor); _shadowColor = c; }); }
- (void)setShadowPath:(CGPathRef)p { CGPathRetain(p); CA_SET(@"shadowPath", { if (_shadowPath) CGPathRelease(_shadowPath); _shadowPath = p; }); }
- (void)setCornerRadius:(CGFloat)r { CA_SET(@"cornerRadius", _cornerRadius = r); }
- (void)setBorderWidth:(CGFloat)w { CA_SET(@"borderWidth", _borderWidth = w); }
- (void)setOpacity:(float)o { CA_SET(@"opacity", _opacity = o); }
- (void)setShadowOpacity:(float)o { CA_SET(@"shadowOpacity", _shadowOpacity = o); }
- (void)setShadowRadius:(CGFloat)r { CA_SET(@"shadowRadius", _shadowRadius = r); }
- (void)setShadowOffset:(CGSize)o { CA_SET(@"shadowOffset", _shadowOffset = o); }
- (void)setContentsRect:(CGRect)r { CA_SET(@"contentsRect", _contentsRect = r); }
- (void)setMasksToBounds:(BOOL)m { _masksToBounds = m; isim_ui_set_needs_display(); }
- (void)setHidden:(BOOL)h { _hidden = h; isim_ui_set_needs_display(); }
- (void)setMaskedCorners:(CACornerMask)m { _maskedCorners = m; isim_ui_set_needs_display(); }
- (void)setContents:(id)c { _contents = c; isim_ui_set_needs_display(); }
- (void)setContentsGravity:(CALayerContentsGravity)g { _contentsGravity = [g copy]; isim_ui_set_needs_display(); }
- (void)setContentsScale:(CGFloat)s { _contentsScale = s > 0 ? s : 1; isim_ui_set_needs_display(); }
- (void)setContentsCenter:(CGRect)r { _contentsCenter = r; isim_ui_set_needs_display(); }
- (void)setMask:(CALayer *)m { _mask = m; isim_ui_set_needs_display(); }
- (void)setDelegate:(id<CALayerDelegate>)d { if (!_ownerView) _delegate = d; }

/* ---- tree ---- */
- (NSArray<CALayer *> *)sublayers {
    if (_model) {          /* a presentation layer's sublayers are the model's presentation layers */
        NSMutableArray *a = [NSMutableArray array];
        for (CALayer *l in _model.sublayers) [a addObject:[l presentationLayer]];
        return a.count ? a : nil;
    }
    return _subs.count ? [_subs copy] : nil;
}
- (void)setSublayers:(NSArray<CALayer *> *)subs {
    for (CALayer *l in [_subs copy]) [l removeFromSuperlayer];
    for (CALayer *l in subs) [self addSublayer:l];
}
- (void)insertSublayer:(CALayer *)l atIndex:(unsigned)idx {
    if (!l || l == self) return;
    [l removeFromSuperlayer];
    if (!_subs) _subs = [NSMutableArray array];
    [_subs insertObject:l atIndex:MIN((NSUInteger)idx, _subs.count)];
    l->_isimSuper = self;
    isim_ui_set_needs_display();
}
- (void)addSublayer:(CALayer *)l { [self insertSublayer:l atIndex:(unsigned)_subs.count]; }
- (void)insertSublayer:(CALayer *)l below:(CALayer *)sib {
    NSUInteger i = sib ? [_subs indexOfObjectIdenticalTo:sib] : NSNotFound;
    [self insertSublayer:l atIndex:i == NSNotFound ? 0 : (unsigned)i];
}
- (void)insertSublayer:(CALayer *)l above:(CALayer *)sib {
    NSUInteger i = sib ? [_subs indexOfObjectIdenticalTo:sib] : NSNotFound;
    if (i == NSNotFound) { [self addSublayer:l]; return; }
    [l removeFromSuperlayer];
    i = [_subs indexOfObjectIdenticalTo:sib];
    [self insertSublayer:l atIndex:(unsigned)(i + 1)];
}
- (void)replaceSublayer:(CALayer *)old with:(CALayer *)l {
    NSUInteger i = [_subs indexOfObjectIdenticalTo:old];
    if (i == NSNotFound) return;
    [old removeFromSuperlayer];
    [self insertSublayer:l atIndex:(unsigned)i];
}
- (void)removeFromSuperlayer {
    CALayer *s = _isimSuper;
    if (!s) return;
    [s->_subs removeObjectIdenticalTo:self];
    _isimSuper = nil;
    _rendered = NO;
    isim_ui_set_needs_display();
}

/* ---- display & layout ---- */
- (void)setNeedsDisplay { _needsDisplayFlag = YES; isim_ui_set_needs_display(); }
- (void)setNeedsDisplayInRect:(CGRect)r { [self setNeedsDisplay]; }
- (BOOL)needsDisplay { return _needsDisplayFlag; }
- (void)displayIfNeeded { if (_needsDisplayFlag) { _needsDisplayFlag = NO; [self display]; } }
- (void)display {
    id d = _delegate;
    if (d && !_ownerView && [d respondsToSelector:@selector(displayLayer:)]) [d displayLayer:self];
}
- (void)drawInContext:(CGContextRef)ctx {
    id d = _delegate;
    if (d && !_ownerView && [d respondsToSelector:@selector(drawLayer:inContext:)]) [d drawLayer:self inContext:ctx];
}
- (void)setNeedsLayout { _needsLayoutFlag = YES; isim_ui_set_needs_layout(); }
- (BOOL)needsLayout { return _needsLayoutFlag; }
- (void)layoutIfNeeded { if (_needsLayoutFlag) { _needsLayoutFlag = NO; [self layoutSublayers]; } }
- (void)layoutSublayers {
    id d = _delegate;
    if (d && !_ownerView && [d respondsToSelector:@selector(layoutSublayersOfLayer:)]) [d layoutSublayersOfLayer:self];
}
- (void)_isim_markRendered { _rendered = YES; }
/* renders the layer's content and sublayers (not its own position/transform) into ctx's current state */
- (void)renderInContext:(CGContextRef)ctx {
    CALayer *p = [self _isim_presentationAt:CACurrentMediaTime()];
    CGRect b = p.bounds;
    isim_gfx_save();
    isim_gfx_translate(-b.origin.x, -b.origin.y);
    double bg[4]; ca_rgba(p.backgroundColor, bg);
    if (bg[3] > 0) { ca_rounded_path(b, p.cornerRadius, p.maskedCorners); isim_path_fill(bg); }
    if (p.masksToBounds) { isim_gfx_save(); ca_rounded_path(b, p.cornerRadius, p.maskedCorners); isim_gfx_clip_path(); }
    ca_draw_contents(p, b);
    [p _isim_drawContentWithModel:self];
    [p _isim_renderSublayersOf:self];
    if (p.masksToBounds) isim_gfx_restore();
    isim_gfx_restore();
}

/* ---- KVC: undeclared keys are stored (layers are key-value containers); key paths into transforms ---- */
- (void)setValue:(id)v forUndefinedKey:(NSString *)k { if (!_extra) _extra = [NSMutableDictionary dictionary]; if (v) _extra[k] = v; else [_extra removeObjectForKey:k]; }
- (id)valueForUndefinedKey:(NSString *)k { return _extra[k] ?: [[self class] defaultValueForKey:k]; }
- (id)valueForKey:(NSString *)k { ca_val v; if ([self _isim_getAnim:k value:&v]) return ca_val_to_id(&v); return [super valueForKey:k]; }
- (void)setValue:(id)o forKey:(NSString *)k {
    ca_val cur, v;
    if ([self _isim_getAnim:k value:&cur] && cur.kind != CAV_OBJ && ca_val_from_id(o, cur.kind, &v)) { [self _isim_setAnim:k value:&v]; return; }
    [super setValue:o forKey:k];
}
- (id)valueForKeyPath:(NSString *)kp { ca_val v; if ([kp containsString:@"."] && [self _isim_getAnim:kp value:&v]) return ca_val_to_id(&v); return [super valueForKeyPath:kp]; }
- (void)setValue:(id)o forKeyPath:(NSString *)kp {
    ca_val cur, v;
    if ([kp containsString:@"."] && [self _isim_getAnim:kp value:&cur] && ca_val_from_id(o, cur.kind, &v)) { [self _isim_setAnim:kp value:&v]; return; }
    [super setValue:o forKeyPath:kp];
}

/* ---- animatable key paths ---- */
static void set_num(ca_val *o, double x) { o->kind = CAV_NUM; o->n = 1; o->v[0] = x; }
static void set_pair(ca_val *o, int kind, double x, double y) { o->kind = kind; o->n = 2; o->v[0] = x; o->v[1] = y; }
static void set_color(ca_val *o, CGColorRef c) { o->kind = CAV_COLOR; o->n = 4; ca_rgba(c, o->v); }
static void set_t3d(ca_val *o, CATransform3D t) { o->kind = CAV_T3D; o->n = 16; memcpy(o->v, &t, sizeof t); }
/* "transform.rotation.z" etc.: a component of the transform (2D decomposition for z/scale/translation) */
static BOOL transform_get(CATransform3D t, NSString *sub, ca_val *o) {
    decomp2d d = decompose2d(&t);
    if ([sub isEqual:@"rotation"] || [sub isEqual:@"rotation.z"]) { set_num(o, d.rot); return YES; }
    if ([sub isEqual:@"rotation.x"]) { set_num(o, atan2(t.m23, t.m22)); return YES; }
    if ([sub isEqual:@"rotation.y"]) { set_num(o, atan2(-t.m13, t.m11)); return YES; }
    if ([sub isEqual:@"scale"]) { set_num(o, (d.sx + d.sy) / 2); return YES; }
    if ([sub isEqual:@"scale.x"]) { set_num(o, d.sx); return YES; }
    if ([sub isEqual:@"scale.y"]) { set_num(o, d.sy); return YES; }
    if ([sub isEqual:@"scale.z"]) { set_num(o, t.m33); return YES; }
    if ([sub isEqual:@"translation"]) { set_pair(o, CAV_SIZE, t.m41, t.m42); return YES; }
    if ([sub isEqual:@"translation.x"]) { set_num(o, t.m41); return YES; }
    if ([sub isEqual:@"translation.y"]) { set_num(o, t.m42); return YES; }
    if ([sub isEqual:@"translation.z"]) { set_num(o, t.m43); return YES; }
    return NO;
}
static BOOL transform_set(CATransform3D *t, NSString *sub, const ca_val *v) {
    decomp2d d = decompose2d(t);
    double x = v->v[0];
    if ([sub isEqual:@"rotation"] || [sub isEqual:@"rotation.z"]) { d.rot = x; recompose2d(d, t); return YES; }
    if ([sub isEqual:@"rotation.x"] || [sub isEqual:@"rotation.y"]) {
        BOOL isX = [sub isEqual:@"rotation.x"];
        double p = t->m34;
        CATransform3D r = ca_mul(CATransform3DMakeScale(d.sx, d.sy, 1), CATransform3DMakeRotation(x, isX, !isX, 0));
        if (p != 0) { CATransform3D persp = CATransform3DIdentity; persp.m34 = p; r = ca_mul(r, persp); }
        r.m41 = d.tx; r.m42 = d.ty; r.m43 = t->m43;
        *t = r; return YES;
    }
    if ([sub isEqual:@"scale"]) { d.sx = d.sy = x; recompose2d(d, t); t->m33 = x; return YES; }
    if ([sub isEqual:@"scale.x"]) { d.sx = x; recompose2d(d, t); return YES; }
    if ([sub isEqual:@"scale.y"]) { d.sy = x; recompose2d(d, t); return YES; }
    if ([sub isEqual:@"scale.z"]) { t->m33 = x; return YES; }
    if ([sub isEqual:@"translation"]) { t->m41 = v->v[0]; t->m42 = v->v[1]; return YES; }
    if ([sub isEqual:@"translation.x"]) { t->m41 = x; return YES; }
    if ([sub isEqual:@"translation.y"]) { t->m42 = x; return YES; }
    if ([sub isEqual:@"translation.z"]) { t->m43 = x; return YES; }
    return NO;
}
- (BOOL)_isim_getAnim:(NSString *)k value:(ca_val *)o {
    memset(o, 0, sizeof *o);
    if ([k isEqual:@"position"]) { CGPoint p = self.position; set_pair(o, CAV_POINT, p.x, p.y); return YES; }
    if ([k isEqual:@"position.x"]) { set_num(o, self.position.x); return YES; }
    if ([k isEqual:@"position.y"]) { set_num(o, self.position.y); return YES; }
    if ([k isEqual:@"bounds"]) { CGRect b = self.bounds; o->kind = CAV_RECT; o->n = 4; o->v[0] = b.origin.x; o->v[1] = b.origin.y; o->v[2] = b.size.width; o->v[3] = b.size.height; return YES; }
    if ([k isEqual:@"bounds.size"]) { CGSize s = self.bounds.size; set_pair(o, CAV_SIZE, s.width, s.height); return YES; }
    if ([k isEqual:@"bounds.size.width"]) { set_num(o, self.bounds.size.width); return YES; }
    if ([k isEqual:@"bounds.size.height"]) { set_num(o, self.bounds.size.height); return YES; }
    if ([k isEqual:@"bounds.origin"]) { CGPoint p = self.bounds.origin; set_pair(o, CAV_POINT, p.x, p.y); return YES; }
    if ([k isEqual:@"bounds.origin.x"]) { set_num(o, self.bounds.origin.x); return YES; }
    if ([k isEqual:@"bounds.origin.y"]) { set_num(o, self.bounds.origin.y); return YES; }
    if ([k isEqual:@"anchorPoint"]) { set_pair(o, CAV_POINT, _anchorPoint.x, _anchorPoint.y); return YES; }
    if ([k isEqual:@"zPosition"]) { set_num(o, _zPosition); return YES; }
    if ([k isEqual:@"opacity"]) { set_num(o, _opacity); return YES; }
    if ([k isEqual:@"cornerRadius"]) { set_num(o, _cornerRadius); return YES; }
    if ([k isEqual:@"borderWidth"]) { set_num(o, _borderWidth); return YES; }
    if ([k isEqual:@"shadowOpacity"]) { set_num(o, _shadowOpacity); return YES; }
    if ([k isEqual:@"shadowRadius"]) { set_num(o, _shadowRadius); return YES; }
    if ([k isEqual:@"shadowOffset"]) { set_pair(o, CAV_SIZE, _shadowOffset.width, _shadowOffset.height); return YES; }
    if ([k isEqual:@"backgroundColor"]) { set_color(o, _backgroundColor); return YES; }
    if ([k isEqual:@"borderColor"]) { set_color(o, _borderColor); return YES; }
    if ([k isEqual:@"shadowColor"]) { set_color(o, _shadowColor); return YES; }
    if ([k isEqual:@"contentsRect"]) { o->kind = CAV_RECT; o->n = 4; o->v[0] = _contentsRect.origin.x; o->v[1] = _contentsRect.origin.y; o->v[2] = _contentsRect.size.width; o->v[3] = _contentsRect.size.height; return YES; }
    if ([k isEqual:@"transform"]) { set_t3d(o, self.transform); return YES; }
    if ([k isEqual:@"sublayerTransform"]) { set_t3d(o, _sublayerTransform); return YES; }
    if ([k hasPrefix:@"transform."]) return transform_get(self.transform, [k substringFromIndex:10], o);
    if ([k hasPrefix:@"sublayerTransform."]) return transform_get(_sublayerTransform, [k substringFromIndex:18], o);
    if ([k isEqual:@"shadowPath"]) { o->kind = CAV_OBJ; o->obj = (__bridge id)_shadowPath; return YES; }
    if ([k isEqual:@"contents"]) { o->kind = CAV_OBJ; o->obj = _contents; return YES; }
    if ([k isEqual:@"hidden"]) { set_num(o, _hidden); return YES; }
    if ([k isEqual:@"masksToBounds"]) { set_num(o, _masksToBounds); return YES; }
    id x = _extra[k];
    if ([x isKindOfClass:[NSNumber class]]) { set_num(o, [x doubleValue]); return YES; }
    return NO;
}
- (BOOL)_isim_setAnim:(NSString *)k value:(const ca_val *)v {
    const double *x = v->v;
    if ([k isEqual:@"position"]) { self.position = CGPointMake(x[0], x[1]); return YES; }
    if ([k isEqual:@"position.x"]) { self.position = CGPointMake(x[0], self.position.y); return YES; }
    if ([k isEqual:@"position.y"]) { self.position = CGPointMake(self.position.x, x[0]); return YES; }
    if ([k isEqual:@"bounds"]) { self.bounds = CGRectMake(x[0], x[1], x[2], x[3]); return YES; }
    if ([k hasPrefix:@"bounds."]) {
        CGRect b = self.bounds;
        if ([k isEqual:@"bounds.size"]) b.size = CGSizeMake(x[0], x[1]);
        else if ([k isEqual:@"bounds.size.width"]) b.size.width = x[0];
        else if ([k isEqual:@"bounds.size.height"]) b.size.height = x[0];
        else if ([k isEqual:@"bounds.origin"]) b.origin = CGPointMake(x[0], x[1]);
        else if ([k isEqual:@"bounds.origin.x"]) b.origin.x = x[0];
        else if ([k isEqual:@"bounds.origin.y"]) b.origin.y = x[0];
        else return NO;
        self.bounds = b; return YES;
    }
    if ([k isEqual:@"anchorPoint"]) { self.anchorPoint = CGPointMake(x[0], x[1]); return YES; }
    if ([k isEqual:@"zPosition"]) { self.zPosition = x[0]; return YES; }
    if ([k isEqual:@"opacity"]) { self.opacity = (float)x[0]; return YES; }
    if ([k isEqual:@"cornerRadius"]) { self.cornerRadius = x[0]; return YES; }
    if ([k isEqual:@"borderWidth"]) { self.borderWidth = x[0]; return YES; }
    if ([k isEqual:@"shadowOpacity"]) { self.shadowOpacity = (float)x[0]; return YES; }
    if ([k isEqual:@"shadowRadius"]) { self.shadowRadius = x[0]; return YES; }
    if ([k isEqual:@"shadowOffset"]) { self.shadowOffset = CGSizeMake(x[0], x[1]); return YES; }
    if ([k isEqual:@"backgroundColor"]) { self.backgroundColor = ca_color(x); return YES; }
    if ([k isEqual:@"borderColor"]) { self.borderColor = ca_color(x); return YES; }
    if ([k isEqual:@"shadowColor"]) { self.shadowColor = ca_color(x); return YES; }
    if ([k isEqual:@"contentsRect"]) { self.contentsRect = CGRectMake(x[0], x[1], x[2], x[3]); return YES; }
    if ([k isEqual:@"transform"]) { CATransform3D t; memcpy(&t, x, sizeof t); self.transform = t; return YES; }
    if ([k isEqual:@"sublayerTransform"]) { CATransform3D t; memcpy(&t, x, sizeof t); self.sublayerTransform = t; return YES; }
    if ([k hasPrefix:@"transform."]) { CATransform3D t = self.transform; if (!transform_set(&t, [k substringFromIndex:10], v)) return NO; self.transform = t; return YES; }
    if ([k hasPrefix:@"sublayerTransform."]) { CATransform3D t = _sublayerTransform; if (!transform_set(&t, [k substringFromIndex:18], v)) return NO; self.sublayerTransform = t; return YES; }
    if ([k isEqual:@"shadowPath"]) { self.shadowPath = (__bridge CGPathRef)v->obj; return YES; }
    if ([k isEqual:@"contents"]) { self.contents = v->obj; return YES; }
    if ([k isEqual:@"hidden"]) { self.hidden = x[0] != 0; return YES; }
    if ([k isEqual:@"masksToBounds"]) { self.masksToBounds = x[0] != 0; return YES; }
    if ([_extra[k] isKindOfClass:[NSNumber class]]) { _extra[k] = @(x[0]); return YES; }
    return NO;
}

/* ---- animations ---- */
- (BOOL)_isim_hasAnimations { return _entries.count > 0; }
- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    if (!anim) return;
    if ([anim isKindOfClass:[CAPropertyAnimation class]] && !((CAPropertyAnimation *)anim).keyPath && ![anim isKindOfClass:[CAAnimationGroup class]]) return;
    CAAnimation *a = [anim copy];
    if (a.beginTime == 0) a.beginTime = [self _isim_localTime:CACurrentMediaTime()];
    if (a.duration <= 0) a.duration = [a isKindOfClass:[CASpringAnimation class]] ? ((CASpringAnimation *)a).settlingDuration : 0.25;
    if ([a isKindOfClass:[CATransition class]]) {           /* the old appearance, from the last frame on screen */
        CGRect r = [self convertRect:self.bounds toLayer:nil];
        ca_transition_set_snapshot((CATransition *)a, isim_gfx_screen_snapshot(r.origin.x, r.origin.y, r.size.width, r.size.height));
        if (!key) key = kCATransition;
    }
    if (key) [self removeAnimationForKey:key];
    __IsimCAEntry *e = [__IsimCAEntry new];
    e->anim = a; e->key = key ?: [NSString stringWithFormat:@"_isim_anim_%d", ++key_counter];
    e->txs = ca_tx_current_list();
    ca_tx_register(e);
    if (!_entries) _entries = [NSMutableArray array];
    [_entries addObject:e];
    if (!animated_layers) animated_layers = [NSMutableArray array];
    if ([animated_layers indexOfObjectIdenticalTo:self] == NSNotFound) [animated_layers addObject:self];
    ca_driver_wake();
    isim_ui_set_needs_display();
}
static void entry_stop(__IsimCAEntry *e, BOOL finished) {
    if (e->stopped) return;
    e->stopped = YES;
    id<CAAnimationDelegate> d = e->anim.delegate;
    if (d && [d respondsToSelector:@selector(animationDidStop:finished:)]) [d animationDidStop:e->anim finished:finished];
    ca_tx_entry_done(e->txs); e->txs = nil;
}
- (void)removeAnimationForKey:(NSString *)key {
    for (__IsimCAEntry *e in [_entries copy]) if ([e->key isEqual:key]) { [_entries removeObjectIdenticalTo:e]; entry_stop(e, NO); }
    isim_ui_set_needs_display();
}
- (void)removeAllAnimations {
    NSArray *es = [_entries copy]; [_entries removeAllObjects];
    for (__IsimCAEntry *e in es) entry_stop(e, NO);
    isim_ui_set_needs_display();
}
- (NSArray<NSString *> *)animationKeys {
    NSMutableArray *a = [NSMutableArray array];
    for (__IsimCAEntry *e in _entries) if (![e->key hasPrefix:@"_isim_anim_"]) [a addObject:e->key];
    return a.count ? a : nil;
}
- (CAAnimation *)animationForKey:(NSString *)key { for (__IsimCAEntry *e in _entries) if ([e->key isEqual:key]) return e->anim; return nil; }
/* lifecycle: start/stop delegate callbacks, removal on completion (called once per frame) */
- (BOOL)_isim_tickAnimations:(double)now {
    double t = [self _isim_localTime:now];
    for (__IsimCAEntry *e in [_entries copy]) {
        if (!e->started && t >= e->anim.beginTime) {
            e->started = YES;
            id<CAAnimationDelegate> d = e->anim.delegate;
            if (d && [d respondsToSelector:@selector(animationDidStart:)]) [d animationDidStart:e->anim];
        }
        if (!e->stopped && t >= ca_anim_active_end(e->anim)) {
            if (e->anim.removedOnCompletion) [_entries removeObjectIdenticalTo:e];
            entry_stop(e, YES);
        }
    }
    for (__IsimCAEntry *e in _entries) if (!e->stopped) return YES;
    return NO;
}
- (void)_isim_applyAnimationsTo:(CALayer *)p at:(double)mediaTime {
    double t = [self _isim_localTime:mediaTime];
    for (__IsimCAEntry *e in [_entries copy]) { int st; ca_anim_apply(e->anim, p, t, &st); }
}
- (CALayer *)_isim_presentationAt:(double)mediaTime {
    if (!_entries.count) return self;
    Class k = [self class];
    static Class base[8]; static int nbase;
    if (!nbase) { Class b[] = { [CAShapeLayer class], [CAGradientLayer class], [CATextLayer class], [CAReplicatorLayer class], [CAEmitterLayer class],
                                [CATransformLayer class], [CAScrollLayer class], [CALayer class] }; memcpy(base, b, sizeof b); nbase = 8; }
    /* the copy is an instance of the nearest isim layer class: app subclasses keep their state on the model */
    Class pk = [CALayer class];
    for (int i = 0; i < nbase; i++) if ([k isSubclassOfClass:base[i]]) { pk = base[i]; break; }
    CALayer *p = [[pk alloc] initWithLayer:self];
    p->_model = self;
    [self _isim_applyAnimationsTo:p at:mediaTime];
    return p;
}
- (instancetype)presentationLayer {
    if (_model) return self;
    if (!_entries.count) return self;
    return (id)[self _isim_presentationAt:CACurrentMediaTime()];
}
- (instancetype)modelLayer { return _model ?: self; }

/* ---- content hooks (subclasses) ---- */
static IMP base_drawInContext;
- (void)_isim_drawContentWithModel:(CALayer *)model {
    if (!base_drawInContext) base_drawInContext = class_getMethodImplementation([CALayer class], @selector(drawInContext:));
    id d = model->_delegate;
    BOOL delegateDraws = d && !model->_ownerView && [d respondsToSelector:@selector(drawLayer:inContext:)];
    if (class_getMethodImplementation(object_getClass(model), @selector(drawInContext:)) != base_drawInContext || delegateDraws) {
        isim_gfx_save(); CGContextSaveGState(isim_cg_current_context());
        [model drawInContext:isim_cg_current_context()];
        CGContextRestoreGState(isim_cg_current_context()); isim_gfx_restore();
    }
}
- (void)_isim_renderSublayersOf:(CALayer *)model { ca_render_sublayer_list(model, self); }
- (NSArray *)_isim_subsRaw { return _subs; }
- (NSArray *)_isim_entryList { return [_entries copy]; }

/* the old private entry points: a view's layer content (drawInContext: overrides, contents, sublayers) */
- (void)_isim_renderLayerContents {
    _rendered = YES;
    if (_needsDisplayFlag) { _needsDisplayFlag = NO; [self display]; }
    if (_needsLayoutFlag) { _needsLayoutFlag = NO; [self layoutSublayers]; }
    CGRect b = self.bounds;
    if (_contents) ca_draw_contents(self, b);
    [self _isim_drawContentWithModel:self];
    [self _isim_renderSublayersOf:self];
}
- (void)_isim_renderAsSublayer { ca_render_layer(self, NULL); }
- (NSString *)description {
    CGRect f = self.frame;
    return [NSString stringWithFormat:@"<%@: %p; position = CGPoint (%g %g); bounds = CGRect (%g %g; %g %g)%@>", NSStringFromClass([self class]), self,
            self.position.x, self.position.y, self.bounds.origin.x, self.bounds.origin.y, f.size.width, f.size.height, _name ? [@"; name = " stringByAppendingString:_name] : @""];
}
@end

/* ================= rendering ================= */
double ca_time_shift;
static NSComparisonResult by_z(CALayer *a, CALayer *b) { return a.zPosition < b.zPosition ? NSOrderedAscending : a.zPosition > b.zPosition ? NSOrderedDescending : NSOrderedSame; }

void ca_render_sublayer_list(CALayer *model, CALayer *p) {
    NSArray *subs = [model _isim_subsRaw];
    if (!subs.count) return;
    BOOL anyZ = NO; for (CALayer *l in subs) if (l.zPosition != 0) { anyZ = YES; break; }
    if (anyZ) subs = [subs sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(id a, id b) { return by_z(a, b); }];
    else subs = [subs copy];
    CATransform3D sm = sublayer_matrix(p);
    BOOL hasSub = !CATransform3DIsIdentity(sm);
    for (CALayer *l in subs) ca_render_layer(l, hasSub ? &sm : NULL);
}

/* contents (CGImage / UIImage) with gravity, contentsRect and contentsScale */
void ca_draw_contents(CALayer *p, CGRect B) {
    id c = p.contents;
    if (!c) return;
    CGImageRef img = NULL; CGFloat imgScale = p.contentsScale;
    if ([c isKindOfClass:[UIImage class]]) { img = [(UIImage *)c CGImage]; imgScale = [(UIImage *)c scale]; }
    else img = (__bridge CGImageRef)c;
    CGRect px; int h = isim_cg_image_handle(img, &px);
    if (!h) return;
    CGRect cr = p.contentsRect;
    double sx = px.origin.x + cr.origin.x * px.size.width, sy = px.origin.y + cr.origin.y * px.size.height;
    double sw = cr.size.width * px.size.width, sh = cr.size.height * px.size.height;
    if (sw <= 0 || sh <= 0) return;
    double s = imgScale > 0 ? imgScale : 1, iw = sw / s, ih = sh / s;
    NSString *g = p.contentsGravity;
    CGRect d = B;
    if ([g isEqual:kCAGravityResizeAspect] || [g isEqual:kCAGravityResizeAspectFill]) {
        double k = [g isEqual:kCAGravityResizeAspect] ? fmin(B.size.width / iw, B.size.height / ih) : fmax(B.size.width / iw, B.size.height / ih);
        d.size = CGSizeMake(iw * k, ih * k);
        d.origin = CGPointMake(CGRectGetMidX(B) - d.size.width / 2, CGRectGetMidY(B) - d.size.height / 2);
    } else if (![g isEqual:kCAGravityResize]) {
        /* positioned at natural size; Core Animation's top/bottom are y-up, so on iOS "top" is the bottom edge */
        d.size = CGSizeMake(iw, ih);
        double x = CGRectGetMidX(B) - iw / 2, y = CGRectGetMidY(B) - ih / 2;
        if ([g hasSuffix:@"eft"] || [g isEqual:kCAGravityLeft]) x = B.origin.x;
        if ([g hasSuffix:@"ight"]) x = CGRectGetMaxX(B) - iw;
        if ([g hasPrefix:@"top"]) y = CGRectGetMaxY(B) - ih;
        if ([g hasPrefix:@"bottom"]) y = B.origin.y;
        d.origin = CGPointMake(x, y);
    }
    BOOL nearest = [p.magnificationFilter isEqual:kCAFilterNearest];
    isim_image_draw_part(h, sx, sy, sw, sh, d.origin.x, d.origin.y, d.size.width, d.size.height, nearest, NULL, 0, 1);
}

/* the layer's own appearance in its bounds coordinates; silhouette: no shadow (drawn for the shadow's shape) */
static void render_body(CALayer *m, CALayer *p, BOOL silhouette) {
    CGRect b = p.bounds;
    double bg[4]; ca_rgba(p.backgroundColor, bg);
    double r = p.cornerRadius; CACornerMask corners = p.maskedCorners;
    if (!silhouette && p.shadowOpacity > 0 && p.shadowColor) {
        double sc[4]; ca_rgba(p.shadowColor, sc); sc[3] *= p.shadowOpacity;
        if (sc[3] > 0) {
            isim_gfx_push_group();
            double black[4] = { 0, 0, 0, 1 };
            if (p.shadowPath) { ca_emit_path(p.shadowPath); isim_path_fill(black); }
            else render_body(m, p, YES);
            isim_gfx_pop_group_shadow(sc, p.shadowRadius, p.shadowOffset.width, p.shadowOffset.height);
        }
    }
    if (bg[3] > 0) { ca_rounded_path(b, r, corners); isim_path_fill(bg); }
    BOOL clip = p.masksToBounds;
    if (clip) { isim_gfx_save(); ca_rounded_path(b, r, corners); isim_gfx_clip_path(); }
    ca_draw_contents(p, b);
    [p _isim_drawContentWithModel:m];
    [p _isim_renderSublayersOf:m];
    if (clip) isim_gfx_restore();
    if (p.borderWidth > 0 && p.borderColor) {
        double bc[4]; ca_rgba(p.borderColor, bc);
        double w = p.borderWidth;
        ca_rounded_path(CGRectInset(b, w / 2, w / 2), fmax(0, r - w / 2), corners);
        isim_path_stroke(w, bc);
    }
}
/* CATransition: the old appearance (snapshot) slides or fades out while the new one comes in */
static CATransition *active_transition(CALayer *m, double *prog) {
    double t = -1;
    for (__IsimCAEntry *e in [m _isim_entryList]) {
        if (![e->anim isKindOfClass:[CATransition class]]) continue;
        if (t < 0) t = [m _isim_localTime:CACurrentMediaTime()];
        double pr = ca_transition_progress((CATransition *)e->anim, t);
        if (pr >= 0) { *prog = pr; return (CATransition *)e->anim; }
    }
    return nil;
}
typedef struct { double ndx, ndy, odx, ody, oldAlpha; BOOL oldBelow; int img; __unsafe_unretained CATransition *tr; } tr_state;
static BOOL transition_begin(CALayer *m, CGRect b, tr_state *st) {
    double p; CATransition *tr = active_transition(m, &p);
    memset(st, 0, sizeof *st);
    if (!tr) return NO;
    st->tr = tr; st->img = ca_transition_snapshot(tr); st->oldAlpha = 1;
    NSString *type = tr.type, *sub = tr.subtype ?: kCATransitionFromLeft;
    double w = b.size.width, h = b.size.height, dx = 0, dy = 0;
    if ([sub isEqual:kCATransitionFromRight]) dx = w; else if ([sub isEqual:kCATransitionFromLeft]) dx = -w;
    else if ([sub isEqual:kCATransitionFromTop]) dy = -h; else dy = h;
    if ([type isEqual:kCATransitionPush]) { st->ndx = dx * (1 - p); st->ndy = dy * (1 - p); st->odx = -dx * p; st->ody = -dy * p; }
    else if ([type isEqual:kCATransitionMoveIn]) { st->ndx = dx * (1 - p); st->ndy = dy * (1 - p); st->oldBelow = YES; }
    else if ([type isEqual:kCATransitionReveal]) { st->odx = -dx * p; st->ody = -dy * p; }
    else st->oldAlpha = 1 - p;                                        /* fade */
    if (st->oldBelow && st->img) { double pw, ph; isim_image_pixel_size(st->img, &pw, &ph); isim_image_draw_part(st->img, 0, 0, pw, ph, b.origin.x, b.origin.y, w, h, 0, NULL, 0, 1); }
    isim_gfx_save();
    isim_gfx_translate(st->ndx, st->ndy);
    return YES;
}
static void transition_end(CGRect b, tr_state *st) {
    isim_gfx_restore();
    if (st->oldBelow || !st->img || st->oldAlpha <= 0.001) return;
    double pw, ph; isim_image_pixel_size(st->img, &pw, &ph);
    isim_image_draw_part(st->img, 0, 0, pw, ph, b.origin.x + st->odx, b.origin.y + st->ody, b.size.width, b.size.height, 0, NULL, 0, st->oldAlpha);
}
static void render_layer_in_bounds(CALayer *m, CALayer *p) {
    double a = p.opacity;
    CALayer *mask = p.mask;
    BOOL group = a < 0.999 || mask;
    if (group) isim_gfx_push_group();
    tr_state trs; BOOL tr = transition_begin(m, p.bounds, &trs);
    render_body(m, p, NO);
    if (tr) transition_end(p.bounds, &trs);
    if (group) {
        if (mask) { isim_gfx_push_group(); ca_render_layer(mask, NULL); isim_gfx_pop_group_masked(a); }
        else isim_gfx_pop_group(a);
    }
}
static double render_scale(void) { double s = isim_ui_device()->scale; return s > 0 ? s : 2; }
void ca_render_layer(CALayer *m, const CATransform3D *parentSub) {
    if (!m) return;
    [m layoutIfNeeded];
    [m displayIfNeeded];
    [m _isim_markRendered];
    CALayer *p = [m _isim_presentationAt:CACurrentMediaTime()];
    if (p.hidden || p.opacity <= 0.001) return;
    CATransform3D mx = layer_matrix(p);
    if (parentSub) mx = ca_mul(mx, *parentSub);
    CGRect b = p.bounds;
    if (ca_is_affine2d(mx)) {
        isim_gfx_save();
        isim_gfx_concat(mx.m11, mx.m12, mx.m21, mx.m22, mx.m41, mx.m42);
        render_layer_in_bounds(m, p);
        isim_gfx_restore();
        return;
    }
    /* perspective: render flat offscreen, then warp onto the projected corners */
    if (b.size.width <= 0 || b.size.height <= 0) return;
    double w[4]; CGPoint q[4];
    double cx[4] = { 0, b.size.width, b.size.width, 0 }, cy[4] = { 0, 0, b.size.height, b.size.height };
    for (int i = 0; i < 4; i++) { q[i] = ca_project(mx, b.origin.x + cx[i], b.origin.y + cy[i], &w[i]); if (w[i] <= 1e-6) return; }
    if (!p.doubleSided) {    /* back-facing (clockwise order flipped on screen) layers are not drawn */
        double area = 0; for (int i = 0; i < 4; i++) { CGPoint a = q[i], c = q[(i + 1) % 4]; area += a.x * c.y - c.x * a.y; }
        if (area < 0) return;
    }
    double s = render_scale();
    if (!isim_gfx_offscreen_begin(b.size.width, b.size.height, s, 0)) return;
    isim_gfx_translate(-b.origin.x, -b.origin.y);
    render_layer_in_bounds(m, p);
    int img = isim_gfx_offscreen_snapshot();
    isim_gfx_offscreen_end();
    double quad[8] = { q[0].x, q[0].y, q[1].x, q[1].y, q[2].x, q[2].y, q[3].x, q[3].y };
    isim_image_draw_quad(img, quad, 1);
    isim_image_free(img);
}

/* ================= UIView hooks ================= */
__unsafe_unretained UIView *isim_ca_flat_view;
static BOOL view_ca_value(CALayer *p, NSString *k, ca_val *v) { return [p _isim_getAnim:k value:v]; }
void isim_ca_view_values(CALayer *layer, CGRect *frame, CGAffineTransform *xf, double *opacity, double *radius, double *borderW,
                         double *borderC, BOOL *borderAnim, double *bg, BOOL *bgAnim, double *shadowOp, double *shadowRad, CGSize *shadowOff,
                         CATransform3D *t3d, BOOL *has3d) {
    *has3d = [layer _isim_has3D];
    if (*has3d) *t3d = layer.transform;
    if (![layer _isim_hasAnimations]) return;
    /* a standalone copy carrying the view's in-flight values, then the layer's Core Animation animations */
    CALayer *p = [CALayer new];
    p.bounds = CGRectMake(0, 0, frame->size.width, frame->size.height);
    p.position = CGPointMake(CGRectGetMidX(*frame), CGRectGetMidY(*frame));
    p.transform = *has3d ? *t3d : CATransform3DMakeAffineTransform(*xf);
    p.opacity = (float)*opacity; p.cornerRadius = *radius; p.borderWidth = *borderW;
    p.shadowOpacity = (float)*shadowOp; p.shadowRadius = *shadowRad; p.shadowOffset = *shadowOff;
    [layer _isim_applyAnimationsTo:p at:CACurrentMediaTime()];
    ca_val v;
    CGRect b = p.bounds; CGPoint c = p.position;
    *frame = CGRectMake(c.x - b.size.width / 2, c.y - b.size.height / 2, b.size.width, b.size.height);
    CATransform3D t = p.transform;
    if (ca_is_affine2d(t) && CATransform3DIsAffine(t)) { *xf = CATransform3DGetAffineTransform(t); *has3d = NO; }
    else { *t3d = t; *has3d = YES; }
    *opacity = p.opacity; *radius = p.cornerRadius; *borderW = p.borderWidth;
    *shadowOp = p.shadowOpacity; *shadowRad = p.shadowRadius; *shadowOff = p.shadowOffset;
    for (__IsimCAEntry *e in [layer _isim_entryList]) {
        NSString *kp = [e->anim isKindOfClass:[CAPropertyAnimation class]] ? ((CAPropertyAnimation *)e->anim).keyPath : nil;
        if ([kp isEqual:@"backgroundColor"] && view_ca_value(p, kp, &v)) { memcpy(bg, v.v, 4 * sizeof(double)); *bgAnim = YES; }
        if ([kp isEqual:@"borderColor"] && view_ca_value(p, kp, &v)) { memcpy(borderC, v.v, 4 * sizeof(double)); *borderAnim = YES; }
    }
}
void isim_ca_render_view_3d(UIView *view, CGRect f, CATransform3D t) {
    CGSize sz = f.size;
    if (sz.width <= 0 || sz.height <= 0) return;
    /* about the view's center */
    CATransform3D mx = ca_mul(ca_mul(ca_translate(-sz.width / 2, -sz.height / 2, 0), t), ca_translate(CGRectGetMidX(f), CGRectGetMidY(f), 0));
    double w[4]; CGPoint q[4];
    double cx[4] = { 0, sz.width, sz.width, 0 }, cy[4] = { 0, 0, sz.height, sz.height };
    for (int i = 0; i < 4; i++) { q[i] = ca_project(mx, cx[i], cy[i], &w[i]); if (w[i] <= 1e-6) return; }
    if (!view.layer.doubleSided) {
        double area = 0; for (int i = 0; i < 4; i++) { CGPoint a = q[i], c = q[(i + 1) % 4]; area += a.x * c.y - c.x * a.y; }
        if (area < 0) return;
    }
    if (!isim_gfx_offscreen_begin(sz.width, sz.height, render_scale(), 0)) return;
    UIView *prev = isim_ca_flat_view;
    isim_ca_flat_view = view;
    [view _isim_render];
    isim_ca_flat_view = prev;
    int img = isim_gfx_offscreen_snapshot();
    isim_gfx_offscreen_end();
    double quad[8] = { q[0].x, q[0].y, q[1].x, q[1].y, q[2].x, q[2].y, q[3].x, q[3].y };
    isim_image_draw_quad(img, quad, 1);
    isim_image_free(img);
}
/* a view's drop shadow: the shadow path, else its background shape; blurred like Core Animation's */
void isim_ca_view_shadow(CALayer *layer, CGSize sz, double radius, double opacity, double blur, CGSize off) {
    double sc[4]; ca_rgba(layer.shadowColor, sc); sc[3] *= opacity;
    if (sc[3] <= 0) return;
    double black[4] = { 0, 0, 0, 1 };
    isim_gfx_push_group();
    if (layer.shadowPath) ca_emit_path(layer.shadowPath);
    else ca_rounded_path(CGRectMake(0, 0, sz.width, sz.height), radius, layer.maskedCorners);
    isim_path_fill(black);
    isim_gfx_pop_group_shadow(sc, blur, off.width, off.height);
}
static tr_state view_tr[32]; static int view_tr_depth;
BOOL isim_ca_view_transition_begin(CALayer *layer, CGSize sz) {
    if (![layer _isim_hasAnimations] || view_tr_depth >= 32) return NO;
    tr_state st;
    if (!transition_begin(layer, CGRectMake(0, 0, sz.width, sz.height), &st)) return NO;
    view_tr[view_tr_depth++] = st;
    return YES;
}
void isim_ca_view_transition_end(CALayer *layer, CGSize sz) {
    if (view_tr_depth <= 0) return;
    tr_state st = view_tr[--view_tr_depth];
    transition_end(CGRectMake(0, 0, sz.width, sz.height), &st);
}
void isim_ca_render_mask(CALayer *mask) {
    UIView *v = [mask _isim_ownerView];
    if (v) { [v _isim_render]; return; }
    ca_render_layer(mask, NULL);
}

/* ================= UIView ================= */
static char mask_view_key;
@implementation UIView (IsimCoreAnimation)
- (CATransform3D)transform3D { return self.layer.transform; }
- (void)setTransform3D:(CATransform3D)t { self.layer.transform = t; }
- (UIView *)maskView { return objc_getAssociatedObject(self, &mask_view_key); }
- (void)setMaskView:(UIView *)v {
    objc_setAssociatedObject(self, &mask_view_key, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.layer.mask = v.layer;
}
@end
