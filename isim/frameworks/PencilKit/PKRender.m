// isim PencilKit: drawing strokes. Each stroke is sampled along its path (every quarter of its width) and drawn as round
// segments whose width follows the points' sizes; translucent inks draw the whole stroke in a transparency layer so
// its own overlaps do not darken. The looks are isim's approximations of Apple's inks:
//   pen: solid, width from the points; monoline: solid, constant width; marker: wide, flat caps, half opacity;
//   pencil: 85% opacity with a grain of skipped dots; fountain pen and reed: width from the nib angle against the
//   direction of travel; watercolor: 35% opacity, softened edges; crayon: 80% opacity with a grain.
#import "pk_internal.h"

static BOOL is(PKInkType a, PKInkType b) { return [a isEqualToString:b]; }
static CGFloat ink_alpha(PKInkType t) {
    return is(t, PKInkTypeMarker) ? 0.5 : is(t, PKInkTypePencil) ? 0.85 : is(t, PKInkTypeWatercolor) ? 0.35 : is(t, PKInkTypeCrayon) ? 0.8 : 1;
}
/* samples of a stroke's path, every `step` points of length */
typedef struct { pk_point *p; NSUInteger n; } samples;
static samples sample(PKStrokePath *path, CGFloat step) {
    samples s = { NULL, 0 };
    NSUInteger cap = 64;
    s.p = malloc(sizeof(pk_point) * cap);
    if (path.count == 1) { s.p[0] = [path _isim_pointAt:0]; s.n = 1; return s; }
    PKFloatRange *all = [[PKFloatRange alloc] initWithLowerBound:0 upperBound:path.count ? path.count - 1 : 0];
    __block samples *sp = &s; __block NSUInteger *capp = &cap;
    [path enumerateInterpolatedPointsInRange:all strideByDistance:step usingBlock:^(PKStrokePoint *pt, BOOL *stop) {
        if (sp->n == *capp) { *capp *= 2; sp->p = realloc(sp->p, sizeof(pk_point) * *capp); }
        sp->p[sp->n++] = pk_point_of(pt);
    }];
    /* the last point exactly */
    if (path.count) {
        if (s.n == cap) { cap++; s.p = realloc(s.p, sizeof(pk_point) * cap); }
        s.p[s.n++] = [path _isim_pointAt:path.count - 1];
    }
    return s;
}
static CGFloat stroke_step(PKStroke *stroke) {
    CGFloat w = 0;
    PKStrokePath *path = stroke.path;
    for (NSUInteger i = 0; i < path.count; i++) w = fmax(w, path._isim_points.length ? ((const pk_point *)path._isim_points.bytes)[i].w : 0);
    return fmax(0.5, fmin(w / 4, 4));
}
/* the width a sample draws at */
static CGFloat width_at(PKInkType ink, const pk_point *p, const pk_point *prev) {
    CGFloat w = p->w > 0 ? p->w : 1;
    if (is(ink, PKInkTypeMonoline)) return w;
    if (is(ink, PKInkTypeFountainPen) || is(ink, PKInkTypeReed)) {   /* a flat nib held at the azimuth */
        double dir = prev ? atan2(p->y - prev->y, p->x - prev->x) : 0;
        return w * (0.25 + 0.75 * fabs(sin(dir - p->azimuth - M_PI_4)));
    }
    return w;
}
void pk_draw_stroke(PKStroke *stroke, CGContextRef c) {
    PKStrokePath *path = stroke.path;
    if (!path.count || !c) return;
    PKInkType ink = stroke.ink.inkType;
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![stroke.ink.color getRed:&r green:&g blue:&b alpha:&a]) { CGFloat w = 0; if ([stroke.ink.color getWhite:&w alpha:&a]) r = g = b = w; }
    samples s = sample(path, stroke_step(stroke));
    CGContextSaveGState(c);
    CGContextConcatCTM(c, stroke.transform);
    if (stroke.mask) { CGContextAddPath(c, stroke.mask.CGPath); CGContextClip(c); }
    CGFloat layerAlpha = ink_alpha(ink) * a;
    CGContextSetAlpha(c, layerAlpha);
    CGContextBeginTransparencyLayer(c, NULL);
    BOOL marker = is(ink, PKInkTypeMarker), grain = is(ink, PKInkTypePencil) || is(ink, PKInkTypeCrayon), soft = is(ink, PKInkTypeWatercolor);
    CGContextSetLineCap(c, marker ? kCGLineCapSquare : kCGLineCapRound);
    CGContextSetLineJoin(c, kCGLineJoinRound);
    if (soft) CGContextSetShadowWithColor(c, CGSizeZero, 3, [UIColor colorWithRed:r green:g blue:b alpha:1].CGColor);
    uint32_t seed = stroke.randomSeed ?: 1;
    for (NSUInteger i = 0; i < s.n; i++) {
        const pk_point *p = &s.p[i], *q = i ? &s.p[i - 1] : NULL;
        CGFloat w = width_at(ink, p, q), op = p->opacity > 0 ? fmin(p->opacity, 1) : 1;
        CGContextSetRGBStrokeColor(c, r, g, b, op);
        CGContextSetRGBFillColor(c, r, g, b, op);
        if (!q) { CGContextFillEllipseInRect(c, CGRectMake(p->x - w / 2, p->y - w / 2, w, w)); continue; }
        CGContextSetLineWidth(c, w);
        CGContextBeginPath(c);
        CGContextMoveToPoint(c, q->x, q->y);
        CGContextAddLineToPoint(c, p->x, p->y);
        CGContextStrokePath(c);
    }
    if (grain) {   /* the paper's grain: specks where the ink skipped */
        CGContextSetBlendMode(c, kCGBlendModeDestinationOut);
        CGContextSetRGBFillColor(c, 0, 0, 0, 0.6);
        for (NSUInteger i = 0; i < s.n; i++) {
            const pk_point *p = &s.p[i];
            CGFloat w = p->w > 0 ? p->w : 1;
            for (int k = 0; k < 2; k++) {
                seed = seed * 1103515245 + 12345;
                double dx = ((seed >> 8) % 1000 / 1000.0 - 0.5) * w, dy = ((seed >> 18) % 1000 / 1000.0 - 0.5) * w;
                CGContextFillRect(c, CGRectMake(p->x + dx, p->y + dy, 0.8, 0.8));
            }
        }
    }
    CGContextEndTransparencyLayer(c);
    CGContextRestoreGState(c);
    free(s.p);
}
void pk_draw_strokes(NSArray<PKStroke *> *strokes, CGContextRef c) { for (PKStroke *s in strokes) pk_draw_stroke(s, c); }

CGRect pk_stroke_bounds(PKStroke *stroke) {
    PKStrokePath *path = stroke.path;
    if (!path.count) return CGRectNull;
    samples s = sample(path, stroke_step(stroke));
    CGRect r = CGRectNull;
    for (NSUInteger i = 0; i < s.n; i++) {
        CGFloat w = s.p[i].w > 0 ? s.p[i].w : 1, h = fmax(w, s.p[i].h);
        if (is(stroke.ink.inkType, PKInkTypeWatercolor)) w += 6, h += 6;   /* its softened edge */
        r = CGRectUnion(r, CGRectMake(s.p[i].x - w / 2, s.p[i].y - h / 2, w, h));
    }
    free(s.p);
    if (stroke.mask) r = CGRectIntersection(r, stroke.mask.bounds);
    return CGRectIsNull(r) ? r : CGRectApplyAffineTransform(r, stroke.transform);
}

/* distance from p to the segment ab */
static double seg_dist(CGPoint p, CGPoint a, CGPoint b) {
    double dx = b.x - a.x, dy = b.y - a.y, l = dx * dx + dy * dy, u = l > 0 ? ((p.x - a.x) * dx + (p.y - a.y) * dy) / l : 0;
    u = fmax(0, fmin(1, u));
    return hypot(p.x - (a.x + u * dx), p.y - (a.y + u * dy));
}
NSArray<PKFloatRange *> *pk_ranges_hit(PKStroke *stroke, const CGPoint *pts, NSUInteger n, CGFloat w) {
    PKStrokePath *path = stroke.path;
    NSMutableArray *out = [NSMutableArray array];
    if (!path.count || !n) return out;
    double last = path.count - 1, step = fmin(0.05, last > 0 ? last / 4 : 1), start = -1;
    if (last == 0) step = 1;
    for (double t = 0; t <= last + 1e-9; t += step) {
        pk_point pt = [path _isim_pointAt:fmin(t, last)];
        CGPoint p = CGPointApplyAffineTransform(CGPointMake(pt.x, pt.y), stroke.transform);
        double reach = w / 2 + (pt.w > 0 ? pt.w : 1) / 2;
        BOOL hit = NO;
        for (NSUInteger i = 0; i < n && !hit; i++) hit = seg_dist(p, pts[i], pts[i + 1 < n ? i + 1 : i]) <= reach;
        if (hit && start < 0) start = fmax(0, t - step / 2);
        if (!hit && start >= 0) { [out addObject:[[PKFloatRange alloc] initWithLowerBound:start upperBound:fmin(last, t - step / 2)]]; start = -1; }
    }
    if (start >= 0) [out addObject:[[PKFloatRange alloc] initWithLowerBound:start upperBound:last]];
    return out;
}
