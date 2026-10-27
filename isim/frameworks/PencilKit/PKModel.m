// isim PencilKit: the model. Stroke points and paths (a Catmull-Rom curve through the control points, interpolated
// by parametric value, distance or time), inks, strokes, drawings and their data (isim's own format: a binary
// property list, not the data of an Apple device), and the tools.
#import "pk_internal.h"

PKInkType const PKInkTypePen = @"com.apple.ink.pen";
PKInkType const PKInkTypePencil = @"com.apple.ink.pencil";
PKInkType const PKInkTypeMarker = @"com.apple.ink.marker";
PKInkType const PKInkTypeMonoline = @"com.apple.ink.monoline";
PKInkType const PKInkTypeFountainPen = @"com.apple.ink.fountainpen";
PKInkType const PKInkTypeWatercolor = @"com.apple.ink.watercolor";
PKInkType const PKInkTypeCrayon = @"com.apple.ink.crayon";
PKInkType const PKInkTypeReed = @"com.apple.ink.reed";
CFStringRef const PKAppleDrawingTypeIdentifier = CFSTR("com.apple.drawing");

/* ---------------- ranges ---------------- */
@implementation PKFloatRange
- (instancetype)initWithLowerBound:(CGFloat)lower upperBound:(CGFloat)upper {
    if ((self = [super init])) { _lowerBound = lower; _upperBound = upper; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKFloatRange class]] && [o lowerBound] == _lowerBound && [o upperBound] == _upperBound; }
- (NSUInteger)hash { return (NSUInteger)(_lowerBound * 1000 + _upperBound); }
- (NSString *)description { return [NSString stringWithFormat:@"<PKFloatRange %g...%g>", _lowerBound, _upperBound]; }
@end

/* ---------------- points ---------------- */
@implementation PKStrokePoint
- (instancetype)initWithLocation:(CGPoint)l timeOffset:(NSTimeInterval)t size:(CGSize)s opacity:(CGFloat)o force:(CGFloat)f azimuth:(CGFloat)az altitude:(CGFloat)al {
    return [self initWithLocation:l timeOffset:t size:s opacity:o force:f azimuth:az altitude:al secondaryScale:1 threshold:0 lateralJitter:0];
}
- (instancetype)initWithLocation:(CGPoint)l timeOffset:(NSTimeInterval)t size:(CGSize)s opacity:(CGFloat)o force:(CGFloat)f azimuth:(CGFloat)az altitude:(CGFloat)al
                  secondaryScale:(CGFloat)sc {
    return [self initWithLocation:l timeOffset:t size:s opacity:o force:f azimuth:az altitude:al secondaryScale:sc threshold:0 lateralJitter:0];
}
- (instancetype)initWithLocation:(CGPoint)l timeOffset:(NSTimeInterval)t size:(CGSize)s opacity:(CGFloat)o force:(CGFloat)f azimuth:(CGFloat)az altitude:(CGFloat)al
                  secondaryScale:(CGFloat)sc threshold:(CGFloat)th {
    return [self initWithLocation:l timeOffset:t size:s opacity:o force:f azimuth:az altitude:al secondaryScale:sc threshold:th lateralJitter:0];
}
- (instancetype)initWithLocation:(CGPoint)l timeOffset:(NSTimeInterval)t size:(CGSize)s opacity:(CGFloat)o force:(CGFloat)f azimuth:(CGFloat)az altitude:(CGFloat)al
                  secondaryScale:(CGFloat)sc threshold:(CGFloat)th lateralJitter:(CGFloat)j {
    if ((self = [super init])) {
        _location = l; _timeOffset = t; _size = s; _opacity = o; _force = f; _azimuth = az; _altitude = al;
        _secondaryScale = sc; _threshold = th; _lateralJitter = j;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[PKStrokePoint class]]) return NO;
    pk_point a = pk_point_of(self), b = pk_point_of(o);
    return !memcmp(&a, &b, sizeof a);
}
- (NSUInteger)hash { return (NSUInteger)(_location.x * 31 + _location.y * 17 + _timeOffset * 1000); }
- (NSString *)description { return [NSString stringWithFormat:@"<PKStrokePoint (%g, %g) t %g size %gx%g>", _location.x, _location.y, _timeOffset, _size.width, _size.height]; }
@end
pk_point pk_point_of(PKStrokePoint *p) {
    return (pk_point){ p.location.x, p.location.y, p.timeOffset, p.size.width, p.size.height, p.opacity, p.force, p.azimuth, p.altitude,
                       p.secondaryScale, p.threshold, p.lateralJitter };
}
PKStrokePoint *pk_point_object(pk_point p) {
    return [[PKStrokePoint alloc] initWithLocation:CGPointMake(p.x, p.y) timeOffset:p.t size:CGSizeMake(p.w, p.h) opacity:p.opacity force:p.force
                                           azimuth:p.azimuth altitude:p.altitude secondaryScale:p.secondary threshold:p.threshold lateralJitter:p.jitter];
}

@implementation PKConvertedBezierPoint {
@public NSInteger _index, _count, _segment; CGPoint _location;
}
- (NSInteger)index { return _index; }
- (NSInteger)pointCount { return _count; }
- (CGPoint)location { return _location; }
- (NSInteger)bezierSegmentIndex { return _segment; }
@end

/* ---------------- paths ---------------- */
@implementation PKStrokePath {
    NSData *_points;           /* pk_point[] */
    NSDate *_date; NSUUID *_pathID;
    double *_arc;              /* cumulative length at ARC_STEPS samples per segment, built on first use */
    CGPathRef _bezier;
}
#define ARC_STEPS 16
- (instancetype)init { return [self _isim_initWithPoints:[NSData data] creationDate:[NSDate date] pathID:[NSUUID UUID]]; }
- (instancetype)_isim_initWithPoints:(NSData *)points creationDate:(NSDate *)date pathID:(NSUUID *)pathID {
    if ((self = [super init])) { _points = [points copy]; _date = date ?: [NSDate date]; _pathID = pathID ?: [NSUUID UUID]; }
    return self;
}
static NSData *pack(NSArray<PKStrokePoint *> *points) {
    NSMutableData *d = [NSMutableData dataWithLength:points.count * sizeof(pk_point)];
    pk_point *p = d.mutableBytes;
    for (NSUInteger i = 0; i < points.count; i++) p[i] = pk_point_of(points[i]);
    return d;
}
- (instancetype)initWithControlPoints:(NSArray<PKStrokePoint *> *)points creationDate:(NSDate *)date {
    return [self _isim_initWithPoints:pack(points) creationDate:date pathID:[NSUUID UUID]];
}
- (instancetype)initWithControlPoints:(NSArray<PKStrokePoint *> *)points creationDate:(NSDate *)date strokePathID:(NSUUID *)pathID {
    return [self _isim_initWithPoints:pack(points) creationDate:date pathID:pathID];
}
typedef struct { CGPoint *pts; NSInteger *segs; NSInteger n, cap, seg; CGPoint cur, start; } flat;
static void flat_add(flat *f, CGPoint p) {
    if (f->n == f->cap) { f->cap = f->cap ? f->cap * 2 : 64; f->pts = realloc(f->pts, sizeof(CGPoint) * (size_t)f->cap); f->segs = realloc(f->segs, sizeof(NSInteger) * (size_t)f->cap); }
    f->pts[f->n] = p; f->segs[f->n] = f->seg; f->n++;
}
static void flatten(void *info, const CGPathElement *e) {
    flat *f = info;
    CGPoint p0 = f->cur;
    switch (e->type) {
    case kCGPathElementMoveToPoint: f->cur = f->start = e->points[0]; flat_add(f, f->cur); break;
    case kCGPathElementAddLineToPoint: f->seg++; f->cur = e->points[0]; flat_add(f, f->cur); break;
    case kCGPathElementAddQuadCurveToPoint: f->seg++;
        for (int k = 1; k <= 8; k++) { double t = k / 8.0, a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t;
            flat_add(f, CGPointMake(a * p0.x + b * e->points[0].x + c * e->points[1].x, a * p0.y + b * e->points[0].y + c * e->points[1].y)); }
        f->cur = e->points[1]; break;
    case kCGPathElementAddCurveToPoint: f->seg++;
        for (int k = 1; k <= 8; k++) { double t = k / 8.0, a = pow(1 - t, 3), b = 3 * (1 - t) * (1 - t) * t, c = 3 * (1 - t) * t * t, d = t * t * t;
            flat_add(f, CGPointMake(a * p0.x + b * e->points[0].x + c * e->points[1].x + d * e->points[2].x,
                                    a * p0.y + b * e->points[0].y + c * e->points[1].y + d * e->points[2].y)); }
        f->cur = e->points[2]; break;
    case kCGPathElementCloseSubpath: f->seg++; f->cur = f->start; flat_add(f, f->cur); break;
    }
}
- (instancetype)initWithBezierPath:(CGPathRef)path creationDate:(NSDate *)date pointProvider:(PKStrokePoint *(NS_NOESCAPE ^)(PKConvertedBezierPoint *))provider {
    flat f = { 0 };
    if (path) CGPathApply(path, &f, flatten);
    NSMutableArray *points = [NSMutableArray array];
    for (NSInteger i = 0; i < f.n; i++) {
        PKConvertedBezierPoint *c = [PKConvertedBezierPoint alloc];
        c->_index = i; c->_count = f.n; c->_location = f.pts[i]; c->_segment = f.segs[i];
        PKStrokePoint *p = provider ? provider(c) : nil;
        if (p) [points addObject:p];
    }
    free(f.pts); free(f.segs);
    return [self initWithControlPoints:points creationDate:date];
}
- (void)dealloc { free(_arc); if (_bezier) CGPathRelease(_bezier); }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSData *)_isim_points { return _points; }
- (NSUInteger)count { return _points.length / sizeof(pk_point); }
- (NSDate *)creationDate { return _date; }
- (NSUUID *)strokePathID { return _pathID; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKStrokePath class]] && [[o _isim_points] isEqual:_points] && [[o creationDate] isEqual:_date]; }
- (NSUInteger)hash { return _points.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<PKStrokePath %lu points>", (unsigned long)self.count]; }
static const pk_point *P(PKStrokePath *s) { return s->_points.bytes; }
- (PKStrokePoint *)pointAtIndex:(NSUInteger)i {
    if (i >= self.count) [NSException raise:NSRangeException format:@"PKStrokePath: index %lu beyond %lu points", (unsigned long)i, (unsigned long)self.count];
    return pk_point_object(P(self)[i]);
}
- (PKStrokePoint *)objectAtIndexedSubscript:(NSUInteger)i { return [self pointAtIndex:i]; }
/* the point at t: the location on the Catmull-Rom curve, the other values linear between the control points */
- (pk_point)_isim_pointAt:(CGFloat)t {
    NSInteger n = (NSInteger)self.count;
    if (n == 0) return (pk_point){ 0 };
    const pk_point *p = P(self);
    if (n == 1 || t <= 0) return p[0];
    if (t >= n - 1) return p[n - 1];
    NSInteger i = (NSInteger)floor(t);
    double u = t - i;
    const pk_point *p0 = &p[i > 0 ? i - 1 : 0], *p1 = &p[i], *p2 = &p[i + 1], *p3 = &p[i + 2 < n ? i + 2 : n - 1];
    pk_point r;
    double *a = (double *)p1, *b = (double *)p2, *o = (double *)&r;
    for (size_t k = 0; k < sizeof(pk_point) / sizeof(double); k++) o[k] = a[k] + (b[k] - a[k]) * u;
    double u2 = u * u, u3 = u2 * u;
    r.x = 0.5 * (2 * p1->x + (-p0->x + p2->x) * u + (2 * p0->x - 5 * p1->x + 4 * p2->x - p3->x) * u2 + (-p0->x + 3 * p1->x - 3 * p2->x + p3->x) * u3);
    r.y = 0.5 * (2 * p1->y + (-p0->y + p2->y) * u + (2 * p0->y - 5 * p1->y + 4 * p2->y - p3->y) * u2 + (-p0->y + 3 * p1->y - 3 * p2->y + p3->y) * u3);
    return r;
}
- (CGPoint)interpolatedLocationAt:(CGFloat)t { pk_point p = [self _isim_pointAt:t]; return CGPointMake(p.x, p.y); }
- (PKStrokePoint *)interpolatedPointAt:(CGFloat)t { return pk_point_object([self _isim_pointAt:t]); }
/* cumulative arc length: _arc[k] at t = k / ARC_STEPS */
- (const double *)arc {
    if (!_arc) {
        NSInteger n = (NSInteger)self.count, m = n > 1 ? (n - 1) * ARC_STEPS : 0;
        _arc = calloc((size_t)m + 1, sizeof(double));
        CGPoint prev = [self interpolatedLocationAt:0];
        for (NSInteger k = 1; k <= m; k++) {
            CGPoint q = [self interpolatedLocationAt:(CGFloat)k / ARC_STEPS];
            _arc[k] = _arc[k - 1] + hypot(q.x - prev.x, q.y - prev.y);
            prev = q;
        }
    }
    return _arc;
}
static double length_at(PKStrokePath *s, double t) {
    NSInteger n = (NSInteger)s.count;
    if (n < 2) return 0;
    const double *a = [s arc];
    double k = fmax(0, fmin(t, n - 1)) * ARC_STEPS;
    NSInteger i = (NSInteger)floor(k);
    if (i >= (n - 1) * ARC_STEPS) return a[(n - 1) * ARC_STEPS];
    return a[i] + (a[i + 1] - a[i]) * (k - i);
}
static double t_at_length(PKStrokePath *s, double len) {
    NSInteger n = (NSInteger)s.count, m = (n - 1) * ARC_STEPS;
    if (n < 2) return 0;
    const double *a = [s arc];
    if (len <= 0) return 0;
    if (len >= a[m]) return n - 1;
    NSInteger lo = 0, hi = m;
    while (hi - lo > 1) { NSInteger mid = (lo + hi) / 2; if (a[mid] < len) lo = mid; else hi = mid; }
    double f = a[hi] > a[lo] ? (len - a[lo]) / (a[hi] - a[lo]) : 0;
    return (lo + f) / ARC_STEPS;
}
static double time_at(PKStrokePath *s, double t) { return [s _isim_pointAt:t].t; }
static double t_at_time(PKStrokePath *s, double time) {
    NSInteger n = (NSInteger)s.count;
    if (n < 2) return 0;
    const pk_point *p = P(s);
    if (time <= p[0].t) return 0;
    for (NSInteger i = 0; i < n - 1; i++)
        if (time <= p[i + 1].t) return p[i + 1].t > p[i].t ? i + (time - p[i].t) / (p[i + 1].t - p[i].t) : i + 1;
    return n - 1;
}
- (CGFloat)parametricValue:(CGFloat)t offsetByDistance:(CGFloat)d { return t_at_length(self, length_at(self, t) + d); }
- (CGFloat)parametricValue:(CGFloat)t offsetByTime:(NSTimeInterval)dt { return t_at_time(self, time_at(self, t) + dt); }
static void clamp_range(PKStrokePath *s, PKFloatRange *r, double *lo, double *hi) {
    double last = s.count ? (double)s.count - 1 : 0;
    *lo = r ? fmax(0, fmin(r.lowerBound, last)) : 0; *hi = r ? fmax(0, fmin(r.upperBound, last)) : last;
}
- (void)enumerateInterpolatedPointsInRange:(PKFloatRange *)range strideByDistance:(CGFloat)d usingBlock:(void (NS_NOESCAPE ^)(PKStrokePoint *, BOOL *))block {
    if (!self.count || d <= 0) return;
    double lo, hi; clamp_range(self, range, &lo, &hi);
    BOOL stop = NO;
    double end = length_at(self, hi);
    for (double len = length_at(self, lo); !stop; len += d) {
        if (len > end + 1e-9) break;
        block([self interpolatedPointAt:t_at_length(self, len)], &stop);
    }
}
- (void)enumerateInterpolatedPointsInRange:(PKFloatRange *)range strideByTime:(NSTimeInterval)dt usingBlock:(void (NS_NOESCAPE ^)(PKStrokePoint *, BOOL *))block {
    if (!self.count || dt <= 0) return;
    double lo, hi; clamp_range(self, range, &lo, &hi);
    BOOL stop = NO;
    double end = time_at(self, hi);
    for (double time = time_at(self, lo); !stop && time <= end + 1e-9; time += dt) block([self interpolatedPointAt:t_at_time(self, time)], &stop);
}
- (void)enumerateInterpolatedPointsInRange:(PKFloatRange *)range strideByParametricStep:(CGFloat)step usingBlock:(void (NS_NOESCAPE ^)(PKStrokePoint *, BOOL *))block {
    if (!self.count || step <= 0) return;
    double lo, hi; clamp_range(self, range, &lo, &hi);
    BOOL stop = NO;
    for (double t = lo; !stop && t <= hi + 1e-9; t += step) block([self interpolatedPointAt:t], &stop);
}
/* the curve as cubic Béziers: each Catmull-Rom segment's control points are its neighbors' sixths */
- (CGPathRef)bezierRepresentation {
    if (_bezier) return _bezier;
    CGMutablePathRef path = CGPathCreateMutable();
    NSInteger n = (NSInteger)self.count;
    const pk_point *p = P(self);
    if (n) CGPathMoveToPoint(path, NULL, p[0].x, p[0].y);
    for (NSInteger i = 0; i + 1 < n; i++) {
        const pk_point *p0 = &p[i > 0 ? i - 1 : 0], *p1 = &p[i], *p2 = &p[i + 1], *p3 = &p[i + 2 < n ? i + 2 : n - 1];
        CGPathAddCurveToPoint(path, NULL, p1->x + (p2->x - p0->x) / 6, p1->y + (p2->y - p0->y) / 6, p2->x - (p3->x - p1->x) / 6, p2->y - (p3->y - p1->y) / 6, p2->x, p2->y);
    }
    _bezier = path;
    return _bezier;
}
- (PKStrokePath *)subpathWithRange:(PKFloatRange *)range {
    double lo, hi; clamp_range(self, range, &lo, &hi);
    NSMutableData *d = [NSMutableData data];
    pk_point a = [self _isim_pointAt:lo], b = [self _isim_pointAt:hi];
    [d appendBytes:&a length:sizeof a];
    for (NSInteger i = (NSInteger)floor(lo) + 1; i < hi && i < (NSInteger)self.count; i++) if (i > lo) [d appendBytes:&P(self)[i] length:sizeof(pk_point)];
    if (hi > lo) [d appendBytes:&b length:sizeof b];
    return [[PKStrokePath alloc] _isim_initWithPoints:d creationDate:_date pathID:[NSUUID UUID]];
}
@end

/* ---------------- inks ---------------- */
static NSDictionary<NSString *, NSArray<NSNumber *> *> *ink_table(void) {   /* default, minimum, maximum width, content version */
    static NSDictionary *t;
    if (!t) t = @{ PKInkTypePen: @[ @4, @1, @25, @1 ], PKInkTypePencil: @[ @4, @2.4, @16, @1 ], PKInkTypeMarker: @[ @15, @6, @60, @1 ],
                   PKInkTypeMonoline: @[ @3, @1, @25, @2 ], PKInkTypeFountainPen: @[ @6, @1, @20, @2 ], PKInkTypeWatercolor: @[ @20, @5, @40, @2 ],
                   PKInkTypeCrayon: @[ @10, @3, @30, @2 ], PKInkTypeReed: @[ @8, @2, @30, @4 ] };
    return t;
}
static NSArray<NSNumber *> *ink_row(PKInkType type) { return ink_table()[type] ?: ink_table()[PKInkTypePen]; }
CGFloat pk_ink_default_width(PKInkType type) { return ink_row(type)[0].doubleValue; }
CGFloat pk_ink_min_width(PKInkType type) { return ink_row(type)[1].doubleValue; }
CGFloat pk_ink_max_width(PKInkType type) { return ink_row(type)[2].doubleValue; }
PKContentVersion pk_ink_version(PKInkType type) { return (PKContentVersion)ink_row(type)[3].integerValue; }

/* colors are equal when their sRGB components are (a color read back from data is a new object) */
static BOOL colors_equal(UIColor *a, UIColor *b) {
    if (a == b || [a isEqual:b]) return YES;
    CGFloat c[2][4] = { { 0, 0, 0, 1 }, { 0, 0, 0, 1 } };
    UIColor *cs[2] = { a, b };
    for (int i = 0; i < 2; i++)
        if (![cs[i] getRed:&c[i][0] green:&c[i][1] blue:&c[i][2] alpha:&c[i][3]]) {
            if (![cs[i] getWhite:&c[i][0] alpha:&c[i][3]]) return NO;
            c[i][1] = c[i][2] = c[i][0];
        }
    for (int k = 0; k < 4; k++) if (fabs(c[0][k] - c[1][k]) > 1e-6) return NO;
    return YES;
}

@implementation PKInk
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color {
    if ((self = [super init])) { _inkType = [type copy] ?: PKInkTypePen; _color = color ?: UIColor.blackColor; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (PKContentVersion)requiredContentVersion { return pk_ink_version(_inkType); }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKInk class]] && [((PKInk *)o).inkType isEqual:_inkType] && colors_equal(((PKInk *)o).color, _color); }
- (NSUInteger)hash { return _inkType.hash ^ _color.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<PKInk %@ %@>", _inkType, _color]; }
@end

/* ---------------- strokes ---------------- */
@implementation PKStrokeRenderState
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithGrainOffset:(CGPoint)g { if ((self = [super init])) _grainOffset = g; return self; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithGrainOffset:CGPointMake([c decodeDoubleForKey:@"x"], [c decodeDoubleForKey:@"y"])]; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeDouble:_grainOffset.x forKey:@"x"]; [c encodeDouble:_grainOffset.y forKey:@"y"]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (PKContentVersion)requiredContentVersion { return PKContentVersion4; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKStrokeRenderState class]] && CGPointEqualToPoint([o grainOffset], _grainOffset); }
- (NSUInteger)hash { return (NSUInteger)(_grainOffset.x * 31 + _grainOffset.y); }
@end

@implementation PKStroke {
    CGRect _bounds; BOOL _boundsDone;
}
- (instancetype)initWithInk:(PKInk *)ink strokePath:(PKStrokePath *)path transform:(CGAffineTransform)t mask:(UIBezierPath *)mask {
    return [self initWithInk:ink strokePath:path transform:t mask:mask randomSeed:arc4random()];
}
- (instancetype)initWithInk:(PKInk *)ink strokePath:(PKStrokePath *)path transform:(CGAffineTransform)t mask:(UIBezierPath *)mask randomSeed:(uint32_t)seed {
    return [self initWithInk:ink strokePath:path transform:t mask:mask randomSeed:seed strokeID:[NSUUID UUID] renderGroupID:nil renderState:nil];
}
- (instancetype)initWithInk:(PKInk *)ink strokePath:(PKStrokePath *)path transform:(CGAffineTransform)t mask:(UIBezierPath *)mask randomSeed:(uint32_t)seed
                   strokeID:(NSUUID *)sid renderGroupID:(NSUUID *)gid renderState:(PKStrokeRenderState *)state {
    if ((self = [super init])) {
        _ink = ink ?: [[PKInk alloc] initWithInkType:PKInkTypePen color:UIColor.blackColor];
        _path = path ?: [[PKStrokePath alloc] init]; _transform = t; _mask = [mask copy]; _randomSeed = seed;
        _strokeID = sid ?: [NSUUID UUID]; _renderGroupID = gid; _renderState = state;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (CGRect)renderBounds {
    if (!_boundsDone) { _bounds = pk_stroke_bounds(self); _boundsDone = YES; }
    return _bounds;
}
- (NSArray<PKFloatRange *> *)maskedPathRanges {
    double last = _path.count ? (double)_path.count - 1 : 0;
    if (!_mask) return @[ [[PKFloatRange alloc] initWithLowerBound:0 upperBound:last] ];
    NSMutableArray *out = [NSMutableArray array];
    double start = -1, step = 0.05;
    for (double t = 0; t <= last + 1e-9; t += step) {
        BOOL in = [_mask containsPoint:[_path interpolatedLocationAt:fmin(t, last)]];
        if (in && start < 0) start = t;
        if (!in && start >= 0) { [out addObject:[[PKFloatRange alloc] initWithLowerBound:start upperBound:t - step]]; start = -1; }
    }
    if (start >= 0) [out addObject:[[PKFloatRange alloc] initWithLowerBound:start upperBound:last]];
    return out;
}
- (PKContentVersion)requiredContentVersion {
    PKContentVersion v = _ink.requiredContentVersion;
    return _renderState && _renderState.requiredContentVersion > v ? _renderState.requiredContentVersion : v;
}
- (PKStroke *)substrokeWithRange:(PKFloatRange *)range {
    return [[PKStroke alloc] initWithInk:_ink strokePath:[_path subpathWithRange:range] transform:_transform mask:_mask randomSeed:_randomSeed
                                strokeID:[NSUUID UUID] renderGroupID:_renderGroupID renderState:_renderState];
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[PKStroke class]]) return NO;
    PKStroke *s = o;
    return [s.ink isEqual:_ink] && [s.path isEqual:_path] && CGAffineTransformEqualToTransform(s.transform, _transform) && s.randomSeed == _randomSeed &&
           ((!s.mask && !_mask) || (s.mask && _mask && CGPathEqualToPath(s.mask.CGPath, _mask.CGPath))) && [s.strokeID isEqual:_strokeID];
}
- (NSUInteger)hash { return _strokeID.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<PKStroke %@ %lu points>", _ink.inkType, (unsigned long)_path.count]; }
@end

/* ---------------- drawings and their data ---------------- */
static NSString *const FORMAT = @"isim.PKDrawing";   /* isim's own format: not an Apple device's drawing data */
static void add_element(void *info, const CGPathElement *e) {
    int n = e->type == kCGPathElementAddCurveToPoint ? 3 : e->type == kCGPathElementAddQuadCurveToPoint ? 2 : e->type == kCGPathElementCloseSubpath ? 0 : 1;
    NSMutableArray *a = [NSMutableArray arrayWithObject:@(e->type)];
    for (int i = 0; i < n; i++) { [a addObject:@(e->points[i].x)]; [a addObject:@(e->points[i].y)]; }
    [(__bridge NSMutableArray *)info addObject:a];
}
static NSArray *path_elements(CGPathRef path) {
    NSMutableArray *els = [NSMutableArray array];
    CGPathApply(path, (__bridge void *)els, add_element);
    return els;
}
static UIBezierPath *path_of_elements(NSArray *els) {
    CGMutablePathRef p = CGPathCreateMutable();
    for (NSArray *a in els) {
        if (![a isKindOfClass:[NSArray class]] || !a.count) continue;
        double v[6] = { 0 };
        for (NSUInteger i = 1; i < a.count && i <= 6; i++) v[i - 1] = [a[i] doubleValue];
        switch ([a[0] intValue]) {
        case kCGPathElementMoveToPoint: CGPathMoveToPoint(p, NULL, v[0], v[1]); break;
        case kCGPathElementAddLineToPoint: CGPathAddLineToPoint(p, NULL, v[0], v[1]); break;
        case kCGPathElementAddQuadCurveToPoint: CGPathAddQuadCurveToPoint(p, NULL, v[0], v[1], v[2], v[3]); break;
        case kCGPathElementAddCurveToPoint: CGPathAddCurveToPoint(p, NULL, v[0], v[1], v[2], v[3], v[4], v[5]); break;
        case kCGPathElementCloseSubpath: CGPathCloseSubpath(p); break;
        }
    }
    UIBezierPath *b = [UIBezierPath bezierPathWithCGPath:p];
    CGPathRelease(p);
    return b;
}
static NSArray<NSNumber *> *rgba(UIColor *c) {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) { CGFloat w = 0; if ([c getWhite:&w alpha:&a]) r = g = b = w; }
    return @[ @(r), @(g), @(b), @(a) ];
}
static NSDictionary *stroke_plist(PKStroke *s) {
    CGAffineTransform t = s.transform;
    NSMutableDictionary *d = [@{ @"ink": s.ink.inkType, @"color": rgba(s.ink.color), @"transform": @[ @(t.a), @(t.b), @(t.c), @(t.d), @(t.tx), @(t.ty) ],
                                 @"seed": @(s.randomSeed), @"id": s.strokeID.UUIDString, @"points": s.path._isim_points,
                                 @"created": @(s.path.creationDate.timeIntervalSinceReferenceDate), @"pathID": s.path.strokePathID.UUIDString } mutableCopy];
    if (s.mask) d[@"mask"] = path_elements(s.mask.CGPath);
    if (s.renderGroupID) d[@"group"] = s.renderGroupID.UUIDString;
    if (s.renderState) d[@"grain"] = @[ @(s.renderState.grainOffset.x), @(s.renderState.grainOffset.y) ];
    return d;
}
static PKStroke *stroke_of_plist(NSDictionary *d) {
    if (![d isKindOfClass:[NSDictionary class]] || ![d[@"points"] isKindOfClass:[NSData class]] || [d[@"points"] length] % sizeof(pk_point)) return nil;
    NSArray *c = d[@"color"], *t = d[@"transform"], *g = d[@"grain"];
    if (c.count != 4 || t.count != 6) return nil;
    UIColor *color = [UIColor colorWithRed:[c[0] doubleValue] green:[c[1] doubleValue] blue:[c[2] doubleValue] alpha:[c[3] doubleValue]];
    PKStrokePath *path = [[PKStrokePath alloc] _isim_initWithPoints:d[@"points"] creationDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[d[@"created"] doubleValue]]
                                                              pathID:[[NSUUID alloc] initWithUUIDString:d[@"pathID"] ?: @""] ?: [NSUUID UUID]];
    CGAffineTransform tr = CGAffineTransformMake([t[0] doubleValue], [t[1] doubleValue], [t[2] doubleValue], [t[3] doubleValue], [t[4] doubleValue], [t[5] doubleValue]);
    PKStrokeRenderState *state = g.count == 2 ? [[PKStrokeRenderState alloc] initWithGrainOffset:CGPointMake([g[0] doubleValue], [g[1] doubleValue])] : nil;
    return [[PKStroke alloc] initWithInk:[[PKInk alloc] initWithInkType:d[@"ink"] ?: PKInkTypePen color:color] strokePath:path transform:tr
                                    mask:d[@"mask"] ? path_of_elements(d[@"mask"]) : nil randomSeed:(uint32_t)[d[@"seed"] unsignedIntValue]
                                strokeID:[[NSUUID alloc] initWithUUIDString:d[@"id"] ?: @""] ?: [NSUUID UUID]
                           renderGroupID:d[@"group"] ? [[NSUUID alloc] initWithUUIDString:d[@"group"]] : nil renderState:state];
}

@implementation PKDrawing {
    NSArray<PKStroke *> *_strokes; CGRect _bounds; BOOL _boundsDone;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init { if ((self = [super init])) _strokes = @[]; return self; }
- (instancetype)initWithStrokes:(NSArray<PKStroke *> *)strokes { if ((self = [self init])) _strokes = [strokes copy] ?: @[]; return self; }
- (instancetype)initWithData:(NSData *)data error:(NSError **)error {
    NSDictionary *plist = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL] : nil;
    if (![plist isKindOfClass:[NSDictionary class]] || ![plist[@"format"] isEqual:FORMAT]) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:@{
            NSLocalizedDescriptionKey: @"The data is not a drawing in isim's format (isim reads only the drawings it wrote, not an Apple device's)." }];
        return nil;
    }
    NSMutableArray *strokes = [NSMutableArray array];
    for (NSDictionary *s in plist[@"strokes"]) { PKStroke *k = stroke_of_plist(s); if (k) [strokes addObject:k]; }
    if ((self = [super init])) _strokes = strokes;
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    NSData *d = [coder decodeObjectOfClass:[NSData class] forKey:@"data"];
    return d ? [self initWithData:d error:NULL] : [self init];
}
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:self.dataRepresentation forKey:@"data"]; }
- (NSData *)dataRepresentation {
    NSMutableArray *strokes = [NSMutableArray array];
    for (PKStroke *s in _strokes) [strokes addObject:stroke_plist(s)];
    return [NSPropertyListSerialization dataWithPropertyList:@{ @"format": FORMAT, @"version": @1, @"strokes": strokes }
                                                      format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSArray<PKStroke *> *)strokes { return _strokes; }
- (CGRect)bounds {
    if (!_boundsDone) {
        CGRect r = CGRectNull;
        for (PKStroke *s in _strokes) r = CGRectUnion(r, s.renderBounds);
        _bounds = CGRectIsNull(r) ? CGRectZero : r; _boundsDone = YES;
    }
    return _bounds;
}
- (PKContentVersion)requiredContentVersion {
    PKContentVersion v = PKContentVersion1;
    for (PKStroke *s in _strokes) if (s.requiredContentVersion > v) v = s.requiredContentVersion;
    return v;
}
- (UIImage *)imageFromRect:(CGRect)rect scale:(CGFloat)scale {
    if (CGRectIsEmpty(rect) || CGRectIsNull(rect)) return [[UIImage alloc] init];
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, scale > 0 ? scale : UIScreen.mainScreen.scale);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(c, -rect.origin.x, -rect.origin.y);
    pk_draw_strokes(_strokes, c);
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return im;
}
- (PKDrawing *)drawingByApplyingTransform:(CGAffineTransform)t {
    NSMutableArray *out = [NSMutableArray array];
    for (PKStroke *s in _strokes)
        [out addObject:[[PKStroke alloc] initWithInk:s.ink strokePath:s.path transform:CGAffineTransformConcat(s.transform, t) mask:s.mask randomSeed:s.randomSeed
                                            strokeID:s.strokeID renderGroupID:s.renderGroupID renderState:s.renderState]];
    return [[PKDrawing alloc] initWithStrokes:out];
}
- (PKDrawing *)drawingByAppendingDrawing:(PKDrawing *)d { return [self drawingByAppendingStrokes:d.strokes ?: @[]]; }
- (PKDrawing *)drawingByAppendingStrokes:(NSArray<PKStroke *> *)strokes { return [[PKDrawing alloc] initWithStrokes:[_strokes arrayByAddingObjectsFromArray:strokes ?: @[]]]; }
/* each stroke without the parametric ranges the eraser path (its points, transformed into drawing coordinates, at its
 * ink's width) passes over */
- (PKDrawing *)drawingByErasingStrokePath:(PKStrokePath *)path mask:(UIBezierPath *)mask transform:(CGAffineTransform)t {
    NSMutableData *pts = [NSMutableData data];
    CGFloat width = 0;
    for (NSUInteger i = 0; i < path.count; i++) {
        PKStrokePoint *p = [path pointAtIndex:i];
        if (mask && ![mask containsPoint:p.location]) continue;
        CGPoint q = CGPointApplyAffineTransform(p.location, t);
        [pts appendBytes:&q length:sizeof q];
        width = fmax(width, p.size.width);
    }
    NSUInteger n = pts.length / sizeof(CGPoint);
    if (!n) return self;
    const CGPoint *q = pts.bytes;
    CGRect area = CGRectNull;
    for (NSUInteger i = 0; i < n; i++) area = CGRectUnion(area, CGRectMake(q[i].x, q[i].y, 0, 0));
    area = CGRectInset(area, -width / 2, -width / 2);
    NSMutableArray *out = [NSMutableArray array];
    for (PKStroke *s in _strokes) {
        if (!CGRectIntersectsRect(s.renderBounds, area)) { [out addObject:s]; continue; }
        NSArray<PKFloatRange *> *hit = pk_ranges_hit(s, pts.bytes, n, width);
        if (!hit.count) { [out addObject:s]; continue; }
        double last = s.path.count ? (double)s.path.count - 1 : 0, start = 0;
        for (PKFloatRange *h in hit) {
            if (h.lowerBound > start + 1e-6) [out addObject:[s substrokeWithRange:[[PKFloatRange alloc] initWithLowerBound:start upperBound:h.lowerBound]]];
            start = h.upperBound;
        }
        if (last > start + 1e-6) [out addObject:[s substrokeWithRange:[[PKFloatRange alloc] initWithLowerBound:start upperBound:last]]];
    }
    return [[PKDrawing alloc] initWithStrokes:out];
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKDrawing class]] && [[o strokes] isEqual:_strokes]; }
- (NSUInteger)hash { return _strokes.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<PKDrawing %lu strokes>", (unsigned long)_strokes.count]; }
@end

/* ---------------- tools ---------------- */
@interface PKTool (Isim)
- (instancetype)_isim_init __attribute__((objc_method_family(init)));
@end
@implementation PKTool
- (instancetype)_isim_init { return [super init]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation PKInkingTool
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color width:(CGFloat)width azimuth:(CGFloat)azimuth {
    if ((self = [super _isim_init])) {
        _inkType = [type copy] ?: PKInkTypePen; _color = color ?: UIColor.blackColor;
        _width = fmin(fmax(width, pk_ink_min_width(_inkType)), pk_ink_max_width(_inkType)); _azimuth = azimuth;
    }
    return self;
}
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color width:(CGFloat)width { return [self initWithInkType:type color:color width:width azimuth:0]; }
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color { return [self initWithInkType:type color:color width:pk_ink_default_width(type)]; }
- (instancetype)initWithInk:(PKInk *)ink width:(CGFloat)width { return [self initWithInkType:ink.inkType color:ink.color width:width]; }
+ (CGFloat)defaultWidthForInkType:(PKInkType)t { return pk_ink_default_width(t); }
+ (CGFloat)minimumWidthForInkType:(PKInkType)t { return pk_ink_min_width(t); }
+ (CGFloat)maximumWidthForInkType:(PKInkType)t { return pk_ink_max_width(t); }
- (PKInk *)ink { return [[PKInk alloc] initWithInkType:_inkType color:_color]; }
- (PKContentVersion)requiredContentVersion { return pk_ink_version(_inkType); }
/* the color with its lightness inverted (hue and saturation kept): what dark mode shows for a light-mode ink */
+ (CGColorRef)invertColor:(CGColorRef)color {
    UIColor *c = [UIColor colorWithCGColor:color];
    CGFloat h = 0, s = 0, b = 0, a = 1;
    if (![c getHue:&h saturation:&s brightness:&b alpha:&a]) return color;
    /* brightness/saturation (HSB) -> lightness (HSL), inverted, back */
    double l = b * (1 - s / 2), sl = l > 0 && l < 1 ? (b - l) / fmin(l, 1 - l) : 0;
    l = 1 - l;
    double bb = l + sl * fmin(l, 1 - l), sb = bb > 0 ? 2 * (1 - l / bb) : 0;
    return (CGColorRef)CFAutorelease(CGColorRetain([UIColor colorWithHue:h saturation:sb brightness:bb alpha:a].CGColor));
}
+ (UIColor *)convertColor:(UIColor *)color fromUserInterfaceStyle:(UIUserInterfaceStyle)from to:(UIUserInterfaceStyle)to {
    BOOL fromDark = from == UIUserInterfaceStyleDark, toDark = to == UIUserInterfaceStyleDark;
    if (fromDark == toDark) return color;
    return [UIColor colorWithCGColor:[self invertColor:color.CGColor]];
}
- (BOOL)isEqual:(id)o {
    return [o isKindOfClass:[PKInkingTool class]] && [((PKInkingTool *)o).inkType isEqual:_inkType] && colors_equal(((PKInkingTool *)o).color, _color) &&
           ((PKInkingTool *)o).width == _width && ((PKInkingTool *)o).azimuth == _azimuth;
}
- (NSUInteger)hash { return _inkType.hash ^ (NSUInteger)(_width * 1000); }
- (NSString *)description { return [NSString stringWithFormat:@"<PKInkingTool %@ %@ width %g>", _inkType, _color, _width]; }
@end

@implementation PKEraserTool
- (instancetype)initWithEraserType:(PKEraserType)type { return [self initWithEraserType:type width:[PKEraserTool defaultWidthForEraserType:type]]; }
- (instancetype)initWithEraserType:(PKEraserType)type width:(CGFloat)width {
    if ((self = [super _isim_init])) {
        _eraserType = type;
        _width = fmin(fmax(width, [PKEraserTool minimumWidthForEraserType:type]), [PKEraserTool maximumWidthForEraserType:type]);
    }
    return self;
}
+ (CGFloat)defaultWidthForEraserType:(PKEraserType)t { return t == PKEraserTypeVector ? 20 : 15; }
+ (CGFloat)minimumWidthForEraserType:(PKEraserType)t { return 5; }
+ (CGFloat)maximumWidthForEraserType:(PKEraserType)t { return 60; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKEraserTool class]] && ((PKEraserTool *)o).eraserType == _eraserType && ((PKEraserTool *)o).width == _width; }
- (NSUInteger)hash { return (NSUInteger)_eraserType * 1000 + (NSUInteger)_width; }
@end

@implementation PKLassoTool
- (instancetype)init { return [super _isim_init]; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[PKLassoTool class]]; }
- (NSUInteger)hash { return 7; }
@end
