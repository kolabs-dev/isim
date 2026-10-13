/* isim Core Animation layer classes: CAShapeLayer (fill/stroke, dashes, strokeStart/strokeEnd trimming),
 * CAGradientLayer (axial/radial/conic through the host gradient painter), CATextLayer, CAReplicatorLayer
 * (instance transform/delay/colour offsets), CAEmitterLayer (particle simulation with sub-cells), CATransformLayer (CoreAnimation.m),
 * CAScrollLayer. Each class draws from its presentation copy and adds its animatable key paths. */
#import "CAPrivate.h"
#pragma clang diagnostic ignored "-Watomic-property-with-user-defined-accessor"
#include <math.h>
#include <stdlib.h>
#include <string.h>

static void retain_color(CGColorRef *slot, CGColorRef c) { CGColorRetain(c); if (*slot) CGColorRelease(*slot); *slot = c; }
static void kp_num(ca_val *o, double x) { memset(o, 0, sizeof *o); o->kind = CAV_NUM; o->n = 1; o->v[0] = x; }
static void kp_color(ca_val *o, CGColorRef c) { memset(o, 0, sizeof *o); o->kind = CAV_COLOR; o->n = 4; ca_rgba(c, o->v); }
static void kp_point(ca_val *o, CGPoint p) { memset(o, 0, sizeof *o); o->kind = CAV_POINT; o->n = 2; o->v[0] = p.x; o->v[1] = p.y; }

/* ================= CAShapeLayer ================= */
CAShapeLayerFillRule const kCAFillRuleNonZero = @"non-zero", kCAFillRuleEvenOdd = @"even-odd";
CAShapeLayerLineJoin const kCALineJoinMiter = @"miter", kCALineJoinRound = @"round", kCALineJoinBevel = @"bevel";
CAShapeLayerLineCap const kCALineCapButt = @"butt", kCALineCapRound = @"round", kCALineCapSquare = @"square";

/* a path flattened to polylines (one per subpath) for strokeStart/strokeEnd */
typedef struct { CGPoint *p; int n, cap; int *sub; int nsub, subcap; CGPoint last, start; BOOL *closed; } poly;
static void poly_pt(poly *pl, CGPoint p) { if (pl->n == pl->cap) { pl->cap = pl->cap ? pl->cap * 2 : 128; pl->p = realloc(pl->p, pl->cap * sizeof(CGPoint)); } pl->p[pl->n++] = p; }
static void poly_sub(poly *pl) {
    if (pl->nsub == pl->subcap) { pl->subcap = pl->subcap ? pl->subcap * 2 : 8; pl->sub = realloc(pl->sub, pl->subcap * sizeof(int)); pl->closed = realloc(pl->closed, pl->subcap * sizeof(BOOL)); }
    pl->sub[pl->nsub] = pl->n; pl->closed[pl->nsub] = NO; pl->nsub++;
}
static void poly_apply(void *info, const CGPathElement *e) {
    poly *pl = info;
    switch (e->type) {
    case kCGPathElementMoveToPoint: poly_sub(pl); poly_pt(pl, e->points[0]); pl->last = pl->start = e->points[0]; break;
    case kCGPathElementAddLineToPoint: if (!pl->nsub) { poly_sub(pl); poly_pt(pl, pl->last); } poly_pt(pl, e->points[0]); pl->last = e->points[0]; break;
    case kCGPathElementAddQuadCurveToPoint:
        if (!pl->nsub) { poly_sub(pl); poly_pt(pl, pl->last); }
        for (int i = 1; i <= 16; i++) { double t = i / 16.0, u = 1 - t;
            poly_pt(pl, CGPointMake(u * u * pl->last.x + 2 * u * t * e->points[0].x + t * t * e->points[1].x, u * u * pl->last.y + 2 * u * t * e->points[0].y + t * t * e->points[1].y)); }
        pl->last = e->points[1]; break;
    case kCGPathElementAddCurveToPoint:
        if (!pl->nsub) { poly_sub(pl); poly_pt(pl, pl->last); }
        for (int i = 1; i <= 32; i++) { double t = i / 32.0, u = 1 - t;
            poly_pt(pl, CGPointMake(u * u * u * pl->last.x + 3 * u * u * t * e->points[0].x + 3 * u * t * t * e->points[1].x + t * t * t * e->points[2].x,
                                    u * u * u * pl->last.y + 3 * u * u * t * e->points[0].y + 3 * u * t * t * e->points[1].y + t * t * t * e->points[2].y)); }
        pl->last = e->points[2]; break;
    case kCGPathElementCloseSubpath:
        if (pl->nsub) { poly_pt(pl, pl->start); pl->closed[pl->nsub - 1] = YES; }
        pl->last = pl->start; break;
    }
}
/* emits the part of the path between fractions s and e of its total length */
static void emit_trimmed(CGPathRef path, double s, double e) {
    poly pl = { 0 };
    CGPathApply(path, &pl, poly_apply);
    double total = 0;
    for (int k = 0; k < pl.nsub; k++) { int a = pl.sub[k], b = k + 1 < pl.nsub ? pl.sub[k + 1] : pl.n; for (int i = a + 1; i < b; i++) total += hypot(pl.p[i].x - pl.p[i - 1].x, pl.p[i].y - pl.p[i - 1].y); }
    isim_path_begin();
    double from = s * total, to = e * total, acc = 0;
    for (int k = 0; k < pl.nsub; k++) {
        int a = pl.sub[k], b = k + 1 < pl.nsub ? pl.sub[k + 1] : pl.n;
        BOOL drawing = NO;
        for (int i = a + 1; i < b; i++) {
            CGPoint p0 = pl.p[i - 1], p1 = pl.p[i];
            double l = hypot(p1.x - p0.x, p1.y - p0.y), l0 = acc, l1 = acc + l;
            acc = l1;
            if (l1 < from || l0 > to || l <= 0) { if (l0 > to) break; continue; }
            double t0 = fmax(0, (from - l0) / l), t1 = fmin(1, (to - l0) / l);
            CGPoint q0 = CGPointMake(p0.x + (p1.x - p0.x) * t0, p0.y + (p1.y - p0.y) * t0), q1 = CGPointMake(p0.x + (p1.x - p0.x) * t1, p0.y + (p1.y - p0.y) * t1);
            if (!drawing) { isim_path_move(q0.x, q0.y); drawing = YES; }
            isim_path_line(q1.x, q1.y);
        }
    }
    free(pl.p); free(pl.sub); free(pl.closed);
}

@implementation CAShapeLayer
- (instancetype)init {
    if ((self = [super init])) {
        _fillColor = CGColorCreateSRGB(0, 0, 0, 1);
        _fillRule = kCAFillRuleNonZero; _lineCap = kCALineCapButt; _lineJoin = kCALineJoinMiter;
        _strokeEnd = 1; _lineWidth = 1; _miterLimit = 10;
    }
    return self;
}
- (instancetype)initWithLayer:(id)layer {
    if ((self = [super initWithLayer:layer]) && [layer isKindOfClass:[CAShapeLayer class]]) {
        CAShapeLayer *o = layer;
        self.path = o.path; retain_color(&_fillColor, o.fillColor); retain_color(&_strokeColor, o.strokeColor);
        _fillRule = o.fillRule; _strokeStart = o.strokeStart; _strokeEnd = o.strokeEnd; _lineWidth = o.lineWidth; _miterLimit = o.miterLimit;
        _lineDashPhase = o.lineDashPhase; _lineCap = o.lineCap; _lineJoin = o.lineJoin; _lineDashPattern = o.lineDashPattern;
    }
    return self;
}
- (void)dealloc { if (_path) CGPathRelease(_path); if (_fillColor) CGColorRelease(_fillColor); if (_strokeColor) CGColorRelease(_strokeColor); }
#define SHAPE_SET(KEY, ASSIGN) do { id<CAAction> _act = [self _isim_implicitAction:KEY]; ASSIGN; isim_ui_set_needs_display(); if (_act) [_act runActionForKey:KEY object:self arguments:nil]; } while (0)
- (void)setPath:(CGPathRef)p { CGPathRetain(p); SHAPE_SET(@"path", { if (_path) CGPathRelease(_path); _path = p; }); }
- (void)setFillColor:(CGColorRef)c { SHAPE_SET(@"fillColor", retain_color(&_fillColor, c)); }
- (void)setStrokeColor:(CGColorRef)c { SHAPE_SET(@"strokeColor", retain_color(&_strokeColor, c)); }
- (void)setStrokeStart:(CGFloat)v { SHAPE_SET(@"strokeStart", _strokeStart = v); }
- (void)setStrokeEnd:(CGFloat)v { SHAPE_SET(@"strokeEnd", _strokeEnd = v); }
- (void)setLineWidth:(CGFloat)v { SHAPE_SET(@"lineWidth", _lineWidth = v); }
- (void)setLineDashPhase:(CGFloat)v { SHAPE_SET(@"lineDashPhase", _lineDashPhase = v); }
- (void)setMiterLimit:(CGFloat)v { SHAPE_SET(@"miterLimit", _miterLimit = v); }
- (BOOL)_isim_getAnim:(NSString *)k value:(ca_val *)o {
    if ([k isEqual:@"strokeStart"]) { kp_num(o, _strokeStart); return YES; }
    if ([k isEqual:@"strokeEnd"]) { kp_num(o, _strokeEnd); return YES; }
    if ([k isEqual:@"lineWidth"]) { kp_num(o, _lineWidth); return YES; }
    if ([k isEqual:@"lineDashPhase"]) { kp_num(o, _lineDashPhase); return YES; }
    if ([k isEqual:@"miterLimit"]) { kp_num(o, _miterLimit); return YES; }
    if ([k isEqual:@"fillColor"]) { kp_color(o, _fillColor); return YES; }
    if ([k isEqual:@"strokeColor"]) { kp_color(o, _strokeColor); return YES; }
    if ([k isEqual:@"path"]) { memset(o, 0, sizeof *o); o->kind = CAV_OBJ; o->obj = (__bridge id)_path; return YES; }
    return [super _isim_getAnim:k value:o];
}
- (BOOL)_isim_setAnim:(NSString *)k value:(const ca_val *)v {
    if ([k isEqual:@"strokeStart"]) { self.strokeStart = v->v[0]; return YES; }
    if ([k isEqual:@"strokeEnd"]) { self.strokeEnd = v->v[0]; return YES; }
    if ([k isEqual:@"lineWidth"]) { self.lineWidth = v->v[0]; return YES; }
    if ([k isEqual:@"lineDashPhase"]) { self.lineDashPhase = v->v[0]; return YES; }
    if ([k isEqual:@"miterLimit"]) { self.miterLimit = v->v[0]; return YES; }
    if ([k isEqual:@"fillColor"]) { self.fillColor = ca_color(v->v); return YES; }
    if ([k isEqual:@"strokeColor"]) { self.strokeColor = ca_color(v->v); return YES; }
    if ([k isEqual:@"path"]) { self.path = (__bridge CGPathRef)v->obj; return YES; }
    return [super _isim_setAnim:k value:v];
}
- (void)_isim_drawContentWithModel:(CALayer *)model {
    [super _isim_drawContentWithModel:model];
    if (!_path) return;
    double fc[4], sc[4]; ca_rgba(_fillColor, fc); ca_rgba(_strokeColor, sc);
    isim_gfx_save();
    if (fc[3] > 0) {
        isim_path_set_fill_rule([_fillRule isEqual:kCAFillRuleEvenOdd]);
        ca_emit_path(_path); isim_path_fill(fc);
    }
    double s = fmax(0, fmin(1, _strokeStart)), e = fmax(0, fmin(1, _strokeEnd));
    if (sc[3] > 0 && _lineWidth > 0 && e > s) {
        double dash[16]; int nd = 0;
        for (NSNumber *d in _lineDashPattern) { if (nd < 16) dash[nd++] = d.doubleValue; }
        if (nd == 1) dash[nd++] = dash[0];
        int cap = [_lineCap isEqual:kCALineCapRound] ? 1 : [_lineCap isEqual:kCALineCapSquare] ? 2 : 0;
        int join = [_lineJoin isEqual:kCALineJoinRound] ? 1 : [_lineJoin isEqual:kCALineJoinBevel] ? 2 : 0;
        isim_path_set_line_style(cap, join, _miterLimit, nd ? dash : NULL, nd, _lineDashPhase);
        if (s <= 0 && e >= 1) ca_emit_path(_path); else emit_trimmed(_path, s, e);
        isim_path_stroke(_lineWidth, sc);
    }
    isim_path_begin();
    isim_gfx_restore();
}
@end

/* ================= CAGradientLayer ================= */
CAGradientLayerType const kCAGradientLayerAxial = @"axial", kCAGradientLayerRadial = @"radial", kCAGradientLayerConic = @"conic";
@implementation CAGradientLayer
- (instancetype)init { if ((self = [super init])) { _startPoint = CGPointMake(0.5, 0); _endPoint = CGPointMake(0.5, 1); _type = kCAGradientLayerAxial; } return self; }
- (instancetype)initWithLayer:(id)layer {
    if ((self = [super initWithLayer:layer]) && [layer isKindOfClass:[CAGradientLayer class]]) {
        CAGradientLayer *o = layer; _colors = o.colors; _locations = o.locations; _startPoint = o.startPoint; _endPoint = o.endPoint; _type = o.type;
    }
    return self;
}
- (void)setColors:(NSArray *)c { SHAPE_SET(@"colors", _colors = [c copy]); }
- (void)setLocations:(NSArray<NSNumber *> *)l { SHAPE_SET(@"locations", _locations = [l copy]); }
- (void)setStartPoint:(CGPoint)p { SHAPE_SET(@"startPoint", _startPoint = p); }
- (void)setEndPoint:(CGPoint)p { SHAPE_SET(@"endPoint", _endPoint = p); }
- (void)setType:(CAGradientLayerType)t { _type = [t copy]; isim_ui_set_needs_display(); }
- (BOOL)_isim_getAnim:(NSString *)k value:(ca_val *)o {
    if ([k isEqual:@"startPoint"]) { kp_point(o, _startPoint); return YES; }
    if ([k isEqual:@"endPoint"]) { kp_point(o, _endPoint); return YES; }
    if ([k isEqual:@"colors"]) { ca_val_from_id(_colors ?: @[], CAV_COLORS, o); return YES; }
    if ([k isEqual:@"locations"]) { ca_val_from_id(_locations ?: @[], CAV_NUMS, o); return YES; }
    return [super _isim_getAnim:k value:o];
}
- (BOOL)_isim_setAnim:(NSString *)k value:(const ca_val *)v {
    if ([k isEqual:@"startPoint"]) { self.startPoint = CGPointMake(v->v[0], v->v[1]); return YES; }
    if ([k isEqual:@"endPoint"]) { self.endPoint = CGPointMake(v->v[0], v->v[1]); return YES; }
    if ([k isEqual:@"colors"]) { self.colors = ca_val_to_id(v); return YES; }
    if ([k isEqual:@"locations"]) { self.locations = ca_val_to_id(v); return YES; }
    return [super _isim_setAnim:k value:v];
}
- (void)_isim_drawContentWithModel:(CALayer *)model {
    [super _isim_drawContentWithModel:model];
    int n = (int)_colors.count;
    if (n == 0) return;
    CGRect b = self.bounds;
    double *locs = calloc((size_t)(n < 2 ? 2 : n), sizeof(double)), *rgba = calloc((size_t)(n < 2 ? 2 : n) * 4, sizeof(double));
    ca_val cv; ca_val_from_id(_colors, CAV_COLORS, &cv);
    for (int i = 0; i < n && i * 4 + 3 < CAV_MAX; i++) memcpy(&rgba[i * 4], &cv.v[i * 4], 4 * sizeof(double));
    for (int i = 0; i < n; i++) locs[i] = i < (int)_locations.count ? _locations[i].doubleValue : (n > 1 ? (double)i / (n - 1) : 0);
    if (n == 1) { memcpy(&rgba[4], rgba, 4 * sizeof(double)); locs[0] = 0; locs[1] = 1; n = 2; }
    double x0 = b.origin.x + _startPoint.x * b.size.width, y0 = b.origin.y + _startPoint.y * b.size.height;
    double x1 = b.origin.x + _endPoint.x * b.size.width, y1 = b.origin.y + _endPoint.y * b.size.height;
    isim_gfx_save();
    isim_path_begin(); isim_path_rect(b.origin.x, b.origin.y, b.size.width, b.size.height, 0);
    if ([_type isEqual:kCAGradientLayerRadial]) {
        /* an ellipse centred on startPoint whose radii reach endPoint */
        double rx = fmax(1e-6, fabs(x1 - x0)), ry = fmax(1e-6, fabs(y1 - y0));
        double geom[6] = { 0, 0, 0, 0, 0, 1 }, m[6] = { rx, 0, 0, ry, x0, y0 };
        isim_path_gradient(0, 1, geom, n, locs, rgba, 1, 0, m);
    } else if ([_type isEqual:kCAGradientLayerConic]) {
        double a0 = atan2(y1 - y0, x1 - x0);
        double geom[4] = { x0, y0, a0, a0 + 2 * M_PI };
        isim_path_gradient(0, 2, geom, n, locs, rgba, 1, 0, NULL);
    } else {
        double geom[4] = { x0, y0, x1, y1 };
        isim_path_gradient(0, 0, geom, n, locs, rgba, 1, 0, NULL);
    }
    isim_path_begin();
    isim_gfx_restore();
    free(locs); free(rgba);
}
@end

/* ================= CATextLayer ================= */
CATextLayerTruncationMode const kCATruncationNone = @"none", kCATruncationStart = @"start", kCATruncationEnd = @"end", kCATruncationMiddle = @"middle";
CATextLayerAlignmentMode const kCAAlignmentNatural = @"natural", kCAAlignmentLeft = @"left", kCAAlignmentRight = @"right",
    kCAAlignmentCenter = @"center", kCAAlignmentJustified = @"justified";
@implementation CATextLayer {
    id _drawn;                                  /* (on the model layer) the string as last drawn */
}
- (id)_isim_drawnString { return _drawn; }
- (instancetype)init {
    if ((self = [super init])) { _fontSize = 36; _foregroundColor = CGColorCreateSRGB(1, 1, 1, 1); _truncationMode = kCATruncationNone; _alignmentMode = kCAAlignmentNatural; }
    return self;
}
- (instancetype)initWithLayer:(id)layer {
    if ((self = [super initWithLayer:layer]) && [layer isKindOfClass:[CATextLayer class]]) {
        CATextLayer *o = layer; _string = o.string; self.font = o.font; _fontSize = o.fontSize; retain_color(&_foregroundColor, o.foregroundColor);
        _wrapped = o.wrapped; _truncationMode = o.truncationMode; _alignmentMode = o.alignmentMode;
    }
    return self;
}
- (void)dealloc { if (_foregroundColor) CGColorRelease(_foregroundColor); if (_font) CFRelease(_font); }
- (void)setFont:(CFTypeRef)f { if (f) CFRetain(f); if (_font) CFRelease(_font); _font = f; isim_ui_set_needs_display(); }
- (void)setString:(id)s { _string = [s copy]; isim_ui_set_needs_display(); }
- (void)setFontSize:(CGFloat)v { SHAPE_SET(@"fontSize", _fontSize = v); }
- (void)setForegroundColor:(CGColorRef)c { SHAPE_SET(@"foregroundColor", retain_color(&_foregroundColor, c)); }
- (BOOL)_isim_getAnim:(NSString *)k value:(ca_val *)o {
    if ([k isEqual:@"fontSize"]) { kp_num(o, _fontSize); return YES; }
    if ([k isEqual:@"foregroundColor"]) { kp_color(o, _foregroundColor); return YES; }
    return [super _isim_getAnim:k value:o];
}
- (BOOL)_isim_setAnim:(NSString *)k value:(const ca_val *)v {
    if ([k isEqual:@"fontSize"]) { self.fontSize = v->v[0]; return YES; }
    if ([k isEqual:@"foregroundColor"]) { self.foregroundColor = ca_color(v->v); return YES; }
    return [super _isim_setAnim:k value:v];
}
- (UIFont *)_isim_uiFont {
    id f = (__bridge id)_font;
    CGFloat size = _fontSize > 0 ? _fontSize : 36;
    if ([f isKindOfClass:[UIFont class]]) return [(UIFont *)f fontWithSize:size];
    NSString *name = [f isKindOfClass:[NSString class]] ? f : [f respondsToSelector:@selector(fontName)] ? [f fontName] : nil;
    return (name ? [UIFont fontWithName:name size:size] : nil) ?: [UIFont systemFontOfSize:size];
}
/* truncationMode: the string shortened with an ellipsis at the start, middle or end so that it fits the bounds (one
   line in their width, or wrapped, their height); kCATruncationNone draws it whole, clipped to the bounds */
static id truncated_string(id str, NSString *mode, UIFont *font, UIColor *color, CGSize box, BOOL wrapped) {
    if (!mode || [mode isEqual:kCATruncationNone]) return str;
    BOOL attr = [str isKindOfClass:[NSAttributedString class]];
    NSString *plain = attr ? [(NSAttributedString *)str string] : [str description];
    BOOL (^fits)(id) = ^BOOL(id x) {
        CGSize z = attr ? isim_ui_measure_attributed(x, font, color, wrapped ? box.width : 0, wrapped ? 0 : 1)
                        : isim_ui_measure(x, font, wrapped ? box.width : 0, wrapped ? 0 : 1);
        return wrapped ? z.height <= box.height + 0.5 : z.width <= box.width + 0.5;
    };
    if (box.width <= 0 || fits(str)) return str;
    NSUInteger n = plain.length;
    BOOL head = [mode isEqual:kCATruncationStart], middle = [mode isEqual:kCATruncationMiddle];
    /* the first `keep` characters and the last ones around the ellipsis, on composed-character boundaries */
    id (^build)(NSUInteger) = ^id(NSUInteger keep) {
        NSUInteger pre = head ? 0 : middle ? (keep + 1) / 2 : keep, suf = head ? keep : middle ? keep / 2 : 0;
        NSRange a = NSMakeRange(0, pre ? NSMaxRange([plain rangeOfComposedCharacterSequenceAtIndex:pre - 1]) : 0);
        NSUInteger from = suf ? [plain rangeOfComposedCharacterSequenceAtIndex:n - suf].location : n;
        NSRange b = NSMakeRange(from, n - from);
        if (NSMaxRange(a) > b.location) b = NSMakeRange(NSMaxRange(a), n - NSMaxRange(a));
        if (!attr) return [NSString stringWithFormat:@"%@\u2026%@", [plain substringWithRange:a], [plain substringWithRange:b]];
        NSAttributedString *as = str;
        NSMutableAttributedString *out = [[as attributedSubstringFromRange:a] mutableCopy];
        NSDictionary *at = n ? [as attributesAtIndex:MIN(a.length ? NSMaxRange(a) - 1 : b.location, n - 1) effectiveRange:NULL] : @{};
        [out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2026" attributes:at]];
        [out appendAttributedString:[as attributedSubstringFromRange:b]];
        return out;
    };
    NSUInteger lo = 0, hi = n; id best = build(0);
    while (lo <= hi) {
        NSUInteger keep = (lo + hi) / 2;
        id cand = build(keep);
        if (fits(cand)) { best = cand; lo = keep + 1; } else { if (keep == 0) break; hi = keep - 1; }
    }
    return best;
}
- (void)_isim_drawContentWithModel:(CALayer *)model {
    [super _isim_drawContentWithModel:model];
    if (!_string) return;
    CGRect b = self.bounds;
    UIFont *font = [self _isim_uiFont];
    double c[4]; ca_rgba(_foregroundColor, c);
    UIColor *color = [UIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
    NSTextAlignment al = [_alignmentMode isEqual:kCAAlignmentCenter] ? NSTextAlignmentCenter : [_alignmentMode isEqual:kCAAlignmentRight] ? NSTextAlignmentRight : NSTextAlignmentLeft;
    NSInteger lines = _wrapped ? 0 : 1;
    id str = truncated_string(_string, _truncationMode, font, color, b.size, _wrapped);
    if ([model isKindOfClass:[CATextLayer class]]) ((CATextLayer *)model)->_drawn = str;
    isim_gfx_save();
    /* the text is drawn into the layer's bounds: what does not fit is cut off */
    isim_path_begin(); isim_path_rect(b.origin.x, b.origin.y, b.size.width, b.size.height, 0); isim_gfx_clip_path();
    if ([str isKindOfClass:[NSAttributedString class]]) {
        CGSize sz = isim_ui_measure_attributed(str, font, color, b.size.width, lines);
        isim_ui_draw_attributed(str, font, color, CGRectMake(b.origin.x, b.origin.y, _wrapped ? b.size.width : fmax(b.size.width, sz.width), sz.height), al, lines, 1);
    } else {
        NSString *s = [str description];
        CGSize sz = isim_ui_measure(s, font, _wrapped ? b.size.width : 0, lines);
        isim_ui_draw_text(s, font, color, CGRectMake(b.origin.x, b.origin.y, _wrapped ? b.size.width : fmax(b.size.width, sz.width), sz.height), al, lines, 1);
    }
    isim_gfx_restore();
}
@end

/* ================= CAReplicatorLayer ================= */
@implementation CAReplicatorLayer
- (instancetype)init { if ((self = [super init])) { _instanceCount = 1; _instanceTransform = CATransform3DIdentity; } return self; }
- (instancetype)initWithLayer:(id)layer {
    if ((self = [super initWithLayer:layer]) && [layer isKindOfClass:[CAReplicatorLayer class]]) {
        CAReplicatorLayer *o = layer; _instanceCount = o.instanceCount; _instanceDelay = o.instanceDelay; _instanceTransform = o.instanceTransform;
        retain_color(&_instanceColor, o.instanceColor); _instanceRedOffset = o.instanceRedOffset; _instanceGreenOffset = o.instanceGreenOffset;
        _instanceBlueOffset = o.instanceBlueOffset; _instanceAlphaOffset = o.instanceAlphaOffset; _preservesDepth = o.preservesDepth;
    }
    return self;
}
- (void)dealloc { if (_instanceColor) CGColorRelease(_instanceColor); }
- (void)setInstanceCount:(NSInteger)n { _instanceCount = n; isim_ui_set_needs_display(); }
- (void)setInstanceDelay:(CFTimeInterval)d { SHAPE_SET(@"instanceDelay", _instanceDelay = d); }
- (void)setInstanceTransform:(CATransform3D)t { SHAPE_SET(@"instanceTransform", _instanceTransform = t); }
- (void)setInstanceColor:(CGColorRef)c { SHAPE_SET(@"instanceColor", retain_color(&_instanceColor, c)); }
- (void)setInstanceRedOffset:(float)v { SHAPE_SET(@"instanceRedOffset", _instanceRedOffset = v); }
- (void)setInstanceGreenOffset:(float)v { SHAPE_SET(@"instanceGreenOffset", _instanceGreenOffset = v); }
- (void)setInstanceBlueOffset:(float)v { SHAPE_SET(@"instanceBlueOffset", _instanceBlueOffset = v); }
- (void)setInstanceAlphaOffset:(float)v { SHAPE_SET(@"instanceAlphaOffset", _instanceAlphaOffset = v); }
- (BOOL)_isim_getAnim:(NSString *)k value:(ca_val *)o {
    if ([k isEqual:@"instanceDelay"]) { kp_num(o, _instanceDelay); return YES; }
    if ([k isEqual:@"instanceColor"]) { kp_color(o, _instanceColor); return YES; }
    if ([k isEqual:@"instanceRedOffset"]) { kp_num(o, _instanceRedOffset); return YES; }
    if ([k isEqual:@"instanceGreenOffset"]) { kp_num(o, _instanceGreenOffset); return YES; }
    if ([k isEqual:@"instanceBlueOffset"]) { kp_num(o, _instanceBlueOffset); return YES; }
    if ([k isEqual:@"instanceAlphaOffset"]) { kp_num(o, _instanceAlphaOffset); return YES; }
    if ([k isEqual:@"instanceTransform"]) { memset(o, 0, sizeof *o); o->kind = CAV_T3D; o->n = 16; memcpy(o->v, &_instanceTransform, sizeof _instanceTransform); return YES; }
    return [super _isim_getAnim:k value:o];
}
- (BOOL)_isim_setAnim:(NSString *)k value:(const ca_val *)v {
    if ([k isEqual:@"instanceDelay"]) { self.instanceDelay = v->v[0]; return YES; }
    if ([k isEqual:@"instanceColor"]) { self.instanceColor = ca_color(v->v); return YES; }
    if ([k isEqual:@"instanceRedOffset"]) { self.instanceRedOffset = (float)v->v[0]; return YES; }
    if ([k isEqual:@"instanceGreenOffset"]) { self.instanceGreenOffset = (float)v->v[0]; return YES; }
    if ([k isEqual:@"instanceBlueOffset"]) { self.instanceBlueOffset = (float)v->v[0]; return YES; }
    if ([k isEqual:@"instanceAlphaOffset"]) { self.instanceAlphaOffset = (float)v->v[0]; return YES; }
    if ([k isEqual:@"instanceTransform"]) { CATransform3D t; memcpy(&t, v->v, sizeof t); self.instanceTransform = t; return YES; }
    return [super _isim_setAnim:k value:v];
}
/* instance i: the sublayers under instanceTransform^i (about the anchor point), i * instanceDelay earlier on the
   clock, tinted by instanceColor + i * offsets */
- (void)_isim_renderSublayersOf:(CALayer *)model {
    NSInteger n = _instanceCount;
    if (n <= 0) return;
    CGRect b = self.bounds; CGPoint a = self.anchorPoint;
    double cx = b.origin.x + a.x * b.size.width, cy = b.origin.y + a.y * b.size.height;
    CATransform3D step = ca_mul(ca_mul(ca_translate(-cx, -cy, 0), _instanceTransform), ca_translate(cx, cy, 0));
    CATransform3D acc = CATransform3DIdentity;
    double base[4] = { 1, 1, 1, 1 };
    if (_instanceColor) ca_rgba(_instanceColor, base);
    double shift0 = ca_time_shift;
    for (NSInteger i = 0; i < n; i++) {
        double col[4] = { base[0] + i * _instanceRedOffset, base[1] + i * _instanceGreenOffset, base[2] + i * _instanceBlueOffset, base[3] + i * _instanceAlphaOffset };
        BOOL tint = col[0] < 0.999 || col[1] < 0.999 || col[2] < 0.999 || col[3] < 0.999;
        if (tint && col[3] <= 0) { acc = ca_mul(acc, step); continue; }
        ca_time_shift = shift0 + i * _instanceDelay;
        isim_gfx_save();
        if (ca_is_affine2d(acc)) isim_gfx_concat(acc.m11, acc.m12, acc.m21, acc.m22, acc.m41, acc.m42);
        if (tint) isim_gfx_push_group();
        if (ca_is_affine2d(acc)) ca_render_sublayer_list(model, self);
        else {    /* a perspective instance transform: pass it down as the sublayers' parent transform */
            for (CALayer *l in [model _isim_subsRaw]) ca_render_layer(l, &acc);
        }
        if (tint) isim_gfx_pop_group_tinted(col, 1);
        isim_gfx_restore();
        acc = ca_mul(acc, step);
    }
    ca_time_shift = shift0;
}
@end

/* ================= CATransformLayer / CAScrollLayer ================= */
@implementation CATransformLayer
@end
CAScrollLayerScrollMode const kCAScrollNone = @"none", kCAScrollVertically = @"vertically", kCAScrollHorizontally = @"horizontally", kCAScrollBoth = @"both";
@implementation CAScrollLayer
- (instancetype)init { if ((self = [super init])) _scrollMode = kCAScrollBoth; return self; }
- (void)scrollToPoint:(CGPoint)p {
    CGRect b = self.bounds;
    if ([_scrollMode isEqual:kCAScrollVertically]) p.x = b.origin.x;
    else if ([_scrollMode isEqual:kCAScrollHorizontally]) p.y = b.origin.y;
    else if ([_scrollMode isEqual:kCAScrollNone]) return;
    b.origin = p; self.bounds = b;
}
- (void)scrollToRect:(CGRect)r {
    CGRect b = self.bounds; CGPoint o = b.origin;
    if (CGRectGetMinX(r) < o.x) o.x = CGRectGetMinX(r); else if (CGRectGetMaxX(r) > o.x + b.size.width) o.x = CGRectGetMaxX(r) - b.size.width;
    if (CGRectGetMinY(r) < o.y) o.y = CGRectGetMinY(r); else if (CGRectGetMaxY(r) > o.y + b.size.height) o.y = CGRectGetMaxY(r) - b.size.height;
    [self scrollToPoint:o];
}
@end
static CAScrollLayer *scroll_ancestor(CALayer *l) {
    for (CALayer *s = l.superlayer; s; s = s.superlayer) if ([s isKindOfClass:[CAScrollLayer class]]) return (CAScrollLayer *)s;
    return nil;
}
@implementation CALayer (CALayerScrolling)
- (void)scrollPoint:(CGPoint)p {
    CAScrollLayer *s = scroll_ancestor(self);
    if (s) [s scrollToPoint:[self convertPoint:p toLayer:s]];
}
- (void)scrollRectToVisible:(CGRect)r {
    CAScrollLayer *s = scroll_ancestor(self);
    if (s) [s scrollToRect:[self convertRect:r toLayer:s]];
}
- (CGRect)visibleRect {
    CGRect b = self.bounds;
    CAScrollLayer *s = scroll_ancestor(self);
    if (!s) return b;
    CGRect shown = [s convertRect:s.bounds toLayer:self];
    CGRect v = CGRectIntersection(b, shown);
    return CGRectIsNull(v) ? CGRectZero : v;
}
@end

/* ================= CAEmitterLayer ================= */
CAEmitterLayerEmitterShape const kCAEmitterLayerPoint = @"point", kCAEmitterLayerLine = @"line", kCAEmitterLayerRectangle = @"rectangle",
    kCAEmitterLayerCuboid = @"cuboid", kCAEmitterLayerCircle = @"circle", kCAEmitterLayerSphere = @"sphere";
CAEmitterLayerEmitterMode const kCAEmitterLayerPoints = @"points", kCAEmitterLayerOutline = @"outline", kCAEmitterLayerSurface = @"surface", kCAEmitterLayerVolume = @"volume";
CAEmitterLayerRenderMode const kCAEmitterLayerUnordered = @"unordered", kCAEmitterLayerOldestFirst = @"oldestFirst", kCAEmitterLayerOldestLast = @"oldestLast",
    kCAEmitterLayerBackToFront = @"backToFront", kCAEmitterLayerAdditive = @"additive";

@implementation CAEmitterCell
@synthesize beginTime = _beginTime, duration = _duration, timeOffset = _timeOffset, repeatDuration = _repeatDuration, speed = _speed,
    repeatCount = _repeatCount, autoreverses = _autoreverses, fillMode = _fillMode;
+ (instancetype)emitterCell { return [self new]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)init {
    if ((self = [super init])) {
        _enabled = YES; _scale = 1; _speed = 1; _contentsRect = CGRectMake(0, 0, 1, 1); _contentsScale = 1;
        _color = CGColorCreateSRGB(1, 1, 1, 1); _minificationFilter = kCAFilterLinear; _magnificationFilter = kCAFilterLinear; _fillMode = kCAFillModeRemoved;
    }
    return self;
}
- (void)dealloc { if (_color) CGColorRelease(_color); }
- (void)setColor:(CGColorRef)c { retain_color(&_color, c); }
@end

/* a particle: position and velocity in 3D (z is projected away: isim draws the emitter's plane, orthographically),
   its cell (an index into the flattened cell tree, sub-cells after their parents) */
typedef struct { double x, y, z, vx, vy, vz, ax, ay, az, age, life, scale, scaleSpeed, angle, spin, c[4], cs[4]; int cell; } particle;
/* the cell tree flattened depth first: each cell with the index of its parent cell (-1: the layer's own cells) */
static void flatten_cells(NSArray<CAEmitterCell *> *cells, int parent, NSMutableArray *out, NSMutableArray<NSNumber *> *parents) {
    for (CAEmitterCell *c in cells) {
        int me = (int)out.count;
        [out addObject:c]; [parents addObject:@(parent)];
        if (c.emitterCells.count && out.count < 256) flatten_cells(c.emitterCells, me, out, parents);
    }
}
@implementation CAEmitterLayer {
    particle *_ps; int _np, _cap;
    double _lastStep, *_carry; int _ncarry;
    NSArray<CAEmitterCell *> *_flat; NSArray<NSNumber *> *_flatParent;
    unsigned _rng;
    BOOL _ticking;
}
- (instancetype)init {
    if ((self = [super init])) {
        _birthRate = 1; _lifetime = 1; _velocity = 1; _scale = 1; _spin = 1;
        _emitterShape = kCAEmitterLayerPoint; _emitterMode = kCAEmitterLayerVolume; _renderMode = kCAEmitterLayerUnordered;
    }
    return self;
}
- (void)dealloc { free(_ps); free(_carry); }
- (instancetype)initWithLayer:(id)layer {
    if ((self = [super initWithLayer:layer]) && [layer isKindOfClass:[CAEmitterLayer class]]) {
        CAEmitterLayer *o = layer;
        _emitterCells = o.emitterCells; _birthRate = o.birthRate; _lifetime = o.lifetime; _velocity = o.velocity; _scale = o.scale; _spin = o.spin;
        _emitterPosition = o.emitterPosition; _emitterSize = o.emitterSize; _emitterShape = o.emitterShape; _emitterMode = o.emitterMode; _renderMode = o.renderMode;
        _emitterZPosition = o.emitterZPosition; _emitterDepth = o.emitterDepth; _preservesDepth = o.preservesDepth;
    }
    return self;
}
- (void)setEmitterCells:(NSArray<CAEmitterCell *> *)c { _emitterCells = [c copy]; [self _isim_startTicking]; }
- (void)setBirthRate:(float)r { SHAPE_SET(@"birthRate", _birthRate = r); [self _isim_startTicking]; }
- (void)setEmitterPosition:(CGPoint)p { SHAPE_SET(@"emitterPosition", _emitterPosition = p); }
- (void)setEmitterSize:(CGSize)s { SHAPE_SET(@"emitterSize", _emitterSize = s); }
- (void)setVelocity:(float)v { SHAPE_SET(@"velocity", _velocity = v); }
- (void)setScale:(float)v { SHAPE_SET(@"scale", _scale = v); }
- (void)setSpin:(float)v { SHAPE_SET(@"spin", _spin = v); }
- (NSInteger)_isim_particleCount { return _np; }
- (BOOL)_isim_getAnim:(NSString *)k value:(ca_val *)o {
    if ([k isEqual:@"emitterPosition"]) { kp_point(o, _emitterPosition); return YES; }
    if ([k isEqual:@"emitterSize"]) { kp_point(o, CGPointMake(_emitterSize.width, _emitterSize.height)); o->kind = CAV_SIZE; return YES; }
    if ([k isEqual:@"birthRate"]) { kp_num(o, _birthRate); return YES; }
    if ([k isEqual:@"lifetime"]) { kp_num(o, _lifetime); return YES; }
    if ([k isEqual:@"velocity"]) { kp_num(o, _velocity); return YES; }
    if ([k isEqual:@"scale"]) { kp_num(o, _scale); return YES; }
    if ([k isEqual:@"spin"]) { kp_num(o, _spin); return YES; }
    return [super _isim_getAnim:k value:o];
}
- (BOOL)_isim_setAnim:(NSString *)k value:(const ca_val *)v {
    if ([k isEqual:@"emitterPosition"]) { self.emitterPosition = CGPointMake(v->v[0], v->v[1]); return YES; }
    if ([k isEqual:@"emitterSize"]) { self.emitterSize = CGSizeMake(v->v[0], v->v[1]); return YES; }
    if ([k isEqual:@"birthRate"]) { self.birthRate = (float)v->v[0]; return YES; }
    if ([k isEqual:@"lifetime"]) { self.lifetime = (float)v->v[0]; return YES; }
    if ([k isEqual:@"velocity"]) { self.velocity = (float)v->v[0]; return YES; }
    if ([k isEqual:@"scale"]) { self.scale = (float)v->v[0]; return YES; }
    if ([k isEqual:@"spin"]) { self.spin = (float)v->v[0]; return YES; }
    return [super _isim_setAnim:k value:v];
}
- (void)_isim_startTicking { if (!_ticking && _emitterCells.count && _birthRate > 0) { _ticking = YES; _lastStep = 0; ca_driver_add_ticker(self); } }
static double rnd(unsigned *s) { *s = *s * 1103515245u + 12345u; return ((*s >> 8) & 0xFFFFFF) / (double)0xFFFFFF; }
static double spread(unsigned *s, double range) { return range == 0 ? 0 : (rnd(s) * 2 - 1) * range; }
/* z of a newborn: emitterZPosition, spread over emitterDepth for the cuboid and sphere shapes */
- (double)_isim_spawnZ {
    BOOL deep = [_emitterShape isEqual:kCAEmitterLayerCuboid] || [_emitterShape isEqual:kCAEmitterLayerSphere];
    return _emitterZPosition + (deep ? (rnd(&_rng) - 0.5) * _emitterDepth : 0);
}
- (CGPoint)_isim_spawnPoint {
    CGPoint c = _emitterPosition; CGSize z = _emitterSize;
    if ([_emitterShape isEqual:kCAEmitterLayerLine]) return CGPointMake(c.x + (rnd(&_rng) - 0.5) * z.width, c.y);
    if ([_emitterShape isEqual:kCAEmitterLayerRectangle] || [_emitterShape isEqual:kCAEmitterLayerCuboid])
        return CGPointMake(c.x + (rnd(&_rng) - 0.5) * z.width, c.y + (rnd(&_rng) - 0.5) * z.height);
    if ([_emitterShape isEqual:kCAEmitterLayerCircle] || [_emitterShape isEqual:kCAEmitterLayerSphere]) {
        double r = z.width / 2, a = rnd(&_rng) * 2 * M_PI;
        double d = [_emitterMode isEqual:kCAEmitterLayerOutline] ? r : r * sqrt(rnd(&_rng));
        return CGPointMake(c.x + cos(a) * d, c.y + sin(a) * d);
    }
    return c;
}
/* a newborn particle of flat cell `fi`: at (x, y, z), heading `heading` + the cell's longitude (and latitude out of
   the plane), its scale and colour multiplied by `pscale` / `pc` (a parent particle's, for sub-cells) */
- (void)_isim_spawn:(int)fi at:(double)x :(double)y :(double)z heading:(double)heading scale:(double)pscale color:(const double *)pc pre:(double)pre {
    CAEmitterCell *cell = _flat[fi];
    if (_np == _cap) { _cap = _cap ? _cap * 2 : 256; _ps = realloc(_ps, _cap * sizeof(particle)); }
    particle *p = &_ps[_np++];
    memset(p, 0, sizeof *p);
    p->x = x; p->y = y; p->z = z; p->cell = fi;
    p->life = fmax(0.01, (cell.lifetime + spread(&_rng, cell.lifetimeRange)) * _lifetime);
    double v = (cell.velocity + spread(&_rng, cell.velocityRange)) * _velocity;
    double lon = heading + cell.emissionLongitude + spread(&_rng, cell.emissionRange), lat = cell.emissionLatitude;
    p->vx = v * cos(lat) * cos(lon); p->vy = v * cos(lat) * sin(lon); p->vz = v * sin(lat);
    p->ax = cell.xAcceleration; p->ay = cell.yAcceleration; p->az = cell.zAcceleration;
    p->scale = fmax(0, (cell.scale + spread(&_rng, cell.scaleRange)) * _scale * pscale); p->scaleSpeed = cell.scaleSpeed;
    p->spin = (cell.spin + spread(&_rng, cell.spinRange)) * _spin;
    double c[4]; ca_rgba(cell.color, c);
    double rg[4] = { cell.redRange, cell.greenRange, cell.blueRange, cell.alphaRange };
    for (int k = 0; k < 4; k++) p->c[k] = fmin(1, fmax(0, (c[k] + spread(&_rng, rg[k])) * (pc ? pc[k] : 1)));
    p->cs[0] = cell.redSpeed; p->cs[1] = cell.greenSpeed; p->cs[2] = cell.blueSpeed; p->cs[3] = cell.alphaSpeed;
    /* aged by a random part of the step so a burst does not move in lockstep */
    p->x += p->vx * pre; p->y += p->vy * pre; p->z += p->vz * pre; p->age = pre;
}
/* advances the simulation to `now`; YES while particles live or are being born. The layer's cells emit from the
   emitter shape; a cell's emitterCells are emitted by each of its particles, from the particle's position, at angles
   relative to its direction, inheriting its scale and colour (like Core Animation) */
- (BOOL)_isim_tick:(double)now {
    if (!_rng) _rng = _seed ? _seed : 0x1234567u;
    double dt = _lastStep > 0 ? fmin(0.1, now - _lastStep) : 0;
    _lastStep = now;
    NSMutableArray *flat = [NSMutableArray array]; NSMutableArray<NSNumber *> *parents = [NSMutableArray array];
    flatten_cells(_emitterCells, -1, flat, parents);
    _flat = flat; _flatParent = parents;
    int nflat = (int)flat.count;
    if (nflat > _ncarry) { _carry = realloc(_carry, nflat * sizeof(double)); for (int i = _ncarry; i < nflat; i++) _carry[i] = 0; _ncarry = nflat; }
    /* age and move */
    int w = 0;
    for (int i = 0; i < _np; i++) {
        particle *p = &_ps[i];
        p->age += dt;
        if (p->age >= p->life || p->cell >= nflat) continue;
        p->vx += p->ax * dt; p->vy += p->ay * dt; p->vz += p->az * dt; p->x += p->vx * dt; p->y += p->vy * dt; p->z += p->vz * dt;
        p->scale = fmax(0, p->scale + p->scaleSpeed * dt); p->angle += p->spin * dt;
        for (int k = 0; k < 4; k++) p->c[k] = fmin(1, fmax(0, p->c[k] + p->cs[k] * dt));
        _ps[w++] = *p;
    }
    _np = w;
    BOOL emitting = NO;
    /* sub-cells: every live particle of a parent cell emits (rate per particle, randomly rounded per step) */
    int alive = _np;
    for (int i = 0; i < alive && dt > 0; i++) {
        int pcell = _ps[i].cell;
        for (int fi = pcell + 1; fi < nflat; fi++) {
            if (parents[fi].intValue != pcell) continue;
            CAEmitterCell *sub = flat[fi];
            double rate = sub.birthRate * _birthRate;
            if (!sub.enabled || rate <= 0 || sub.lifetime * _lifetime <= 0) continue;
            emitting = YES;
            int born = (int)floor(rate * dt + rnd(&_rng));
            for (int b = 0; b < born && _np < 20000; b++) {
                particle par = _ps[i];                                    /* (_ps may move as it grows) */
                double heading = (par.vx != 0 || par.vy != 0) ? atan2(par.vy, par.vx) : 0;
                [self _isim_spawn:fi at:par.x :par.y :par.z heading:heading scale:par.scale color:par.c pre:rnd(&_rng) * dt];
            }
        }
    }
    /* the layer's own cells */
    for (int fi = 0; fi < nflat; fi++) {
        if (parents[fi].intValue != -1) continue;
        CAEmitterCell *cell = flat[fi];
        if (!cell.enabled) continue;
        double rate = cell.birthRate * _birthRate;
        if (rate <= 0 || cell.lifetime * _lifetime <= 0) continue;
        emitting = YES;
        _carry[fi] += rate * dt;
        int born = (int)floor(_carry[fi]); _carry[fi] -= born;
        if (born > 2000) born = 2000;
        for (int b = 0; b < born; b++) {
            CGPoint at = [self _isim_spawnPoint];
            [self _isim_spawn:fi at:at.x :at.y :[self _isim_spawnZ] heading:0 scale:1 color:NULL pre:rnd(&_rng) * dt];
        }
    }
    isim_ui_set_needs_display();
    if (!emitting && _np == 0) { _ticking = NO; return NO; }
    return YES;
}
/* (tests) live particles of the cell named `name`, at any depth of the tree */
- (NSInteger)_isim_particleCountOfCell:(NSString *)name {
    NSInteger n = 0;
    for (int i = 0; i < _np; i++) if (_ps[i].cell < (int)_flat.count && [_flat[_ps[i].cell].name isEqual:name]) n++;
    return n;
}
- (void)_isim_drawContentWithModel:(CALayer *)model {
    [super _isim_drawContentWithModel:model];
    CAEmitterLayer *m = (CAEmitterLayer *)model;     /* particles live on the model */
    if (![m isKindOfClass:[CAEmitterLayer class]] || !m->_np) return;
    NSArray *cells = m->_flat;
    BOOL additive = [_renderMode isEqual:kCAEmitterLayerAdditive];
    /* drawing order: birth order (oldest first, the default), newest first (oldestLast) or by depth (backToFront) */
    int n = m->_np, *order = malloc(sizeof(int) * (size_t)n);
    for (int i = 0; i < n; i++) order[i] = [_renderMode isEqual:kCAEmitterLayerOldestLast] ? n - 1 - i : i;
    if ([_renderMode isEqual:kCAEmitterLayerBackToFront])                 /* far (low z) first: insertion sort, stable */
        for (int i = 1; i < n; i++) { int k = order[i], j = i - 1; while (j >= 0 && m->_ps[order[j]].z > m->_ps[k].z) { order[j + 1] = order[j]; j--; } order[j + 1] = k; }
    isim_gfx_save();
    if (additive) isim_gfx_set_blend(1);
    for (int oi = 0; oi < n; oi++) {
        particle *p = &m->_ps[order[oi]];
        if (p->cell >= (int)cells.count || p->c[3] <= 0.004 || p->scale <= 0) continue;
        CAEmitterCell *cell = cells[p->cell];
        id c = cell.contents; CGImageRef img = NULL; double imgScale = cell.contentsScale > 0 ? cell.contentsScale : 1;
        if ([c isKindOfClass:[UIImage class]]) { img = [(UIImage *)c CGImage]; imgScale = [(UIImage *)c scale]; } else img = (__bridge CGImageRef)c;
        CGRect px; int h = isim_cg_image_handle(img, &px);
        if (!h) continue;
        CGRect cr = cell.contentsRect;
        double sw = px.size.width * cr.size.width, sh = px.size.height * cr.size.height;
        double w = sw / imgScale * p->scale, hh = sh / imgScale * p->scale;
        BOOL white = p->c[0] > 0.999 && p->c[1] > 0.999 && p->c[2] > 0.999;
        double tint[4] = { p->c[0], p->c[1], p->c[2], 1 };
        isim_gfx_save();
        isim_gfx_translate(p->x, p->y);
        if (p->angle != 0) isim_gfx_rotate(p->angle);
        isim_image_draw_part(h, px.origin.x + cr.origin.x * px.size.width, px.origin.y + cr.origin.y * px.size.height, sw, sh, -w / 2, -hh / 2, w, hh,
                             [cell.magnificationFilter isEqual:kCAFilterNearest], white ? NULL : tint, white ? 0 : 1, p->c[3]);
        isim_gfx_restore();
    }
    isim_gfx_restore();
    free(order);
}
@end
