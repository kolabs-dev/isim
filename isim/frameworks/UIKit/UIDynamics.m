/* isim UIKit Dynamics: UIDynamicAnimator and its behaviors on a small 2D physics step (see UIDynamicAnimator.h).
 * Each frame the animator integrates item velocities (semi-implicit Euler, 1/240 s substeps) under gravity,
 * pushes, snaps and attachments, resolves collisions of turned rectangles (or ellipses) against boundaries and each
 * other with impulses that include rotation (an off-centre hit spins an item; restitution = elasticity, Coulomb
 * friction), writes the items' centers and transforms and runs behavior actions. */
#import "CAPrivate.h"
#import <UIKit/UIDynamicAnimator.h>
#include <math.h>

const UIFloatRange UIFloatRangeZero = { 0, 0 }, UIFloatRangeInfinite = { -INFINITY, INFINITY };
BOOL UIFloatRangeIsInfinite(UIFloatRange r) { return isinf(r.minimum) && isinf(r.maximum); }

@implementation UIView (IsimDynamicItem)
- (UIDynamicItemCollisionBoundsType)collisionBoundsType { return UIDynamicItemCollisionBoundsTypeRectangle; }
@end

@implementation UIDynamicItemGroup { NSArray *_items; }
- (instancetype)initWithItems:(NSArray<id<UIDynamicItem>> *)items { if ((self = [super init])) _items = [items copy]; return self; }
- (NSArray *)items { return _items; }
- (CGRect)bounds {
    CGRect u = CGRectNull;
    for (id<UIDynamicItem> i in _items) { CGRect b = i.bounds; CGPoint c = i.center; u = CGRectUnion(u, CGRectMake(c.x - b.size.width / 2, c.y - b.size.height / 2, b.size.width, b.size.height)); }
    return CGRectIsNull(u) ? CGRectZero : CGRectMake(0, 0, u.size.width, u.size.height);
}
- (CGPoint)center {
    CGRect u = CGRectNull;
    for (id<UIDynamicItem> i in _items) { CGRect b = i.bounds; CGPoint c = i.center; u = CGRectUnion(u, CGRectMake(c.x - b.size.width / 2, c.y - b.size.height / 2, b.size.width, b.size.height)); }
    return CGRectIsNull(u) ? CGPointZero : CGPointMake(CGRectGetMidX(u), CGRectGetMidY(u));
}
- (void)setCenter:(CGPoint)c { CGPoint o = self.center; for (id<UIDynamicItem> i in _items) i.center = CGPointMake(i.center.x + c.x - o.x, i.center.y + c.y - o.y); }
- (CGAffineTransform)transform { return CGAffineTransformIdentity; }
- (void)setTransform:(CGAffineTransform)t {}
@end

/* ================= behaviors ================= */
@interface NSObject (IsimDynWake)
- (void)_isim_wake;
@end
@implementation UIDynamicBehavior { NSMutableArray *_children; @public __weak UIDynamicAnimator *_animator; }
- (NSArray *)childBehaviors { return [_children copy] ?: @[]; }
- (void)addChildBehavior:(UIDynamicBehavior *)b { if (!_children) _children = [NSMutableArray array]; if (b) [_children addObject:b]; [self _isim_changed]; }
- (void)removeChildBehavior:(UIDynamicBehavior *)b { [_children removeObjectIdenticalTo:b]; [self _isim_changed]; }
- (void)willMoveToAnimator:(UIDynamicAnimator *)a {}
- (UIDynamicAnimator *)dynamicAnimator { return _animator; }
- (void)_isim_setAnimator:(UIDynamicAnimator *)a { [self willMoveToAnimator:a]; _animator = a; for (UIDynamicBehavior *c in _children) [c _isim_setAnimator:a]; }
- (void)_isim_changed { [(id)_animator _isim_wake]; }
- (NSArray *)_isim_items { return @[]; }
@end


#define ITEMS_IMPL \
- (instancetype)init { return [self initWithItems:@[]]; } \
- (NSArray *)items { return [_itemList copy]; } \
- (NSArray *)_isim_items { return _itemList; } \
- (void)addItem:(id<UIDynamicItem>)i { if (i && [_itemList indexOfObjectIdenticalTo:i] == NSNotFound) [_itemList addObject:i]; [self _isim_changed]; } \
- (void)removeItem:(id<UIDynamicItem>)i { [_itemList removeObjectIdenticalTo:i]; [self _isim_changed]; }

@implementation UIGravityBehavior { NSMutableArray *_itemList; }
- (instancetype)initWithItems:(NSArray *)items { if ((self = [super init])) { _itemList = [items mutableCopy] ?: [NSMutableArray array]; _gravityDirection = CGVectorMake(0, 1); } return self; }
ITEMS_IMPL
- (CGFloat)magnitude { return hypot(_gravityDirection.dx, _gravityDirection.dy); }
- (void)setMagnitude:(CGFloat)m { [self setAngle:self.angle magnitude:m]; }
- (CGFloat)angle { return atan2(_gravityDirection.dy, _gravityDirection.dx); }
- (void)setAngle:(CGFloat)a { [self setAngle:a magnitude:self.magnitude]; }
- (void)setAngle:(CGFloat)a magnitude:(CGFloat)m { self.gravityDirection = CGVectorMake(cos(a) * m, sin(a) * m); }
- (void)setGravityDirection:(CGVector)d { _gravityDirection = d; [self _isim_changed]; }
@end

@interface __IsimBoundary : NSObject { @public id identifier; UIBezierPath *path; CGPoint *pts; int n; BOOL closed; }
@end
@implementation __IsimBoundary
- (void)dealloc { free(pts); }
@end
static void collect_pts(void *info, const CGPathElement *e) {
    __IsimBoundary *b = (__bridge __IsimBoundary *)info;
    int extra = e->type == kCGPathElementAddCurveToPoint ? 12 : e->type == kCGPathElementAddQuadCurveToPoint ? 8 : 1;
    b->pts = realloc(b->pts, (size_t)(b->n + extra + 1) * sizeof(CGPoint));
    CGPoint last = b->n ? b->pts[b->n - 1] : CGPointZero;
    switch (e->type) {
    case kCGPathElementMoveToPoint: case kCGPathElementAddLineToPoint: b->pts[b->n++] = e->points[0]; break;
    case kCGPathElementAddQuadCurveToPoint:
        for (int i = 1; i <= 8; i++) { double t = i / 8.0, u = 1 - t; b->pts[b->n++] = CGPointMake(u * u * last.x + 2 * u * t * e->points[0].x + t * t * e->points[1].x, u * u * last.y + 2 * u * t * e->points[0].y + t * t * e->points[1].y); }
        break;
    case kCGPathElementAddCurveToPoint:
        for (int i = 1; i <= 12; i++) { double t = i / 12.0, u = 1 - t;
            b->pts[b->n++] = CGPointMake(u * u * u * last.x + 3 * u * u * t * e->points[0].x + 3 * u * t * t * e->points[1].x + t * t * t * e->points[2].x,
                                         u * u * u * last.y + 3 * u * u * t * e->points[0].y + 3 * u * t * t * e->points[1].y + t * t * t * e->points[2].y); }
        break;
    case kCGPathElementCloseSubpath: if (b->n) { b->pts[b->n] = b->pts[0]; b->n++; } b->closed = YES; break;
    }
}

@implementation UICollisionBehavior { NSMutableArray *_itemList; NSMutableArray<__IsimBoundary *> *_bounds; @public UIEdgeInsets _insets; NSMutableSet *_contacts; }
- (instancetype)initWithItems:(NSArray *)items {
    if ((self = [super init])) { _itemList = [items mutableCopy] ?: [NSMutableArray array]; _collisionMode = UICollisionBehaviorModeEverything; _bounds = [NSMutableArray array]; _contacts = [NSMutableSet set]; }
    return self;
}
ITEMS_IMPL
- (void)setTranslatesReferenceBoundsIntoBoundaryWithInsets:(UIEdgeInsets)i { _insets = i; self.translatesReferenceBoundsIntoBoundary = YES; }
- (void)addBoundaryWithIdentifier:(id<NSCopying>)ident forPath:(UIBezierPath *)p {
    [self removeBoundaryWithIdentifier:ident];
    __IsimBoundary *b = [__IsimBoundary new]; b->identifier = [(id)ident copyWithZone:nil]; b->path = [p copy];
    CGPathApply(p.CGPath, (__bridge void *)b, collect_pts);
    [_bounds addObject:b]; [self _isim_changed];
}
- (void)addBoundaryWithIdentifier:(id<NSCopying>)ident fromPoint:(CGPoint)p1 toPoint:(CGPoint)p2 {
    UIBezierPath *p = [UIBezierPath bezierPath]; [p moveToPoint:p1]; [p addLineToPoint:p2];
    [self addBoundaryWithIdentifier:ident forPath:p];
}
- (UIBezierPath *)boundaryWithIdentifier:(id<NSCopying>)ident { for (__IsimBoundary *b in _bounds) if ([b->identifier isEqual:ident]) return b->path; return nil; }
- (void)removeBoundaryWithIdentifier:(id<NSCopying>)ident { for (__IsimBoundary *b in [_bounds copy]) if ([b->identifier isEqual:ident]) [_bounds removeObjectIdenticalTo:b]; }
- (NSArray *)boundaryIdentifiers { NSMutableArray *a = [NSMutableArray array]; for (__IsimBoundary *b in _bounds) [a addObject:b->identifier]; return a.count ? a : nil; }
- (void)removeAllBoundaries { [_bounds removeAllObjects]; }
- (NSArray *)_isim_boundaries { return _bounds; }
@end

@implementation UISnapBehavior { @public id<UIDynamicItem> _item; }
- (instancetype)initWithItem:(id<UIDynamicItem>)item snapToPoint:(CGPoint)p { if ((self = [super init])) { _item = item; _snapPoint = p; _damping = 0.5; } return self; }
- (NSArray *)_isim_items { return _item ? @[ _item ] : @[]; }
- (void)setSnapPoint:(CGPoint)p { _snapPoint = p; [self _isim_changed]; }
@end

@implementation UIPushBehavior { NSMutableArray *_itemList; NSMapTable *_offsets; @public BOOL _fired; }
- (instancetype)initWithItems:(NSArray *)items mode:(UIPushBehaviorMode)mode {
    if ((self = [super init])) { _itemList = [items mutableCopy] ?: [NSMutableArray array]; _mode = mode; _active = YES; _offsets = [NSMapTable weakToStrongObjectsMapTable]; }
    return self;
}
- (instancetype)init { return [self initWithItems:@[] mode:UIPushBehaviorModeContinuous]; }
- (NSArray *)items { return [_itemList copy]; }
- (NSArray *)_isim_items { return _itemList; }
- (void)addItem:(id<UIDynamicItem>)i { if (i) [_itemList addObject:i]; [self _isim_changed]; }
- (void)removeItem:(id<UIDynamicItem>)i { [_itemList removeObjectIdenticalTo:i]; }
- (UIOffset)targetOffsetFromCenterForItem:(id<UIDynamicItem>)i { CGPoint p = [[_offsets objectForKey:i] CGPointValue]; return UIOffsetMake(p.x, p.y); }
- (void)setTargetOffsetFromCenter:(UIOffset)o forItem:(id<UIDynamicItem>)i { [_offsets setObject:[NSValue valueWithCGPoint:CGPointMake(o.horizontal, o.vertical)] forKey:i]; }
- (void)setActive:(BOOL)a { _active = a; if (a) _fired = NO; [self _isim_changed]; }
- (CGFloat)magnitude { return hypot(_pushDirection.dx, _pushDirection.dy); }
- (void)setMagnitude:(CGFloat)m { [self setAngle:self.angle magnitude:m]; }
- (CGFloat)angle { return atan2(_pushDirection.dy, _pushDirection.dx); }
- (void)setAngle:(CGFloat)a { [self setAngle:a magnitude:self.magnitude]; }
- (void)setAngle:(CGFloat)a magnitude:(CGFloat)m { self.pushDirection = CGVectorMake(cos(a) * m, sin(a) * m); }
- (void)setPushDirection:(CGVector)d { _pushDirection = d; _fired = NO; [self _isim_changed]; }
@end

@implementation UIAttachmentBehavior { @public id<UIDynamicItem> _a, _b; UIOffset _oa, _ob; }
- (instancetype)initWithItem:(id<UIDynamicItem>)item attachedToAnchor:(CGPoint)p { return [self initWithItem:item offsetFromCenter:UIOffsetMake(0, 0) attachedToAnchor:p]; }
- (instancetype)initWithItem:(id<UIDynamicItem>)item offsetFromCenter:(UIOffset)o attachedToAnchor:(CGPoint)p {
    if ((self = [super init])) {
        _a = item; _oa = o; _anchorPoint = p; _attachedBehaviorType = UIAttachmentBehaviorTypeAnchor; _attachmentRange = UIFloatRangeInfinite;
        CGPoint c = item.center; _length = hypot(c.x + o.horizontal - p.x, c.y + o.vertical - p.y);
    }
    return self;
}
- (instancetype)initWithItem:(id<UIDynamicItem>)i1 attachedToItem:(id<UIDynamicItem>)i2 { return [self initWithItem:i1 offsetFromCenter:UIOffsetMake(0, 0) attachedToItem:i2 offsetFromCenter:UIOffsetMake(0, 0)]; }
- (instancetype)initWithItem:(id<UIDynamicItem>)i1 offsetFromCenter:(UIOffset)o1 attachedToItem:(id<UIDynamicItem>)i2 offsetFromCenter:(UIOffset)o2 {
    if ((self = [super init])) {
        _a = i1; _b = i2; _oa = o1; _ob = o2; _attachedBehaviorType = UIAttachmentBehaviorTypeItems; _attachmentRange = UIFloatRangeInfinite;
        CGPoint c1 = i1.center, c2 = i2.center;
        _length = hypot(c1.x + o1.horizontal - c2.x - o2.horizontal, c1.y + o1.vertical - c2.y - o2.vertical);
    }
    return self;
}
- (NSArray *)items { NSMutableArray *a = [NSMutableArray array]; if (_a) [a addObject:_a]; if (_b) [a addObject:_b]; return a; }
- (NSArray *)_isim_items { return self.items; }
- (void)setAnchorPoint:(CGPoint)p { _anchorPoint = p; [self _isim_changed]; }
- (void)setLength:(CGFloat)l { _length = l; [self _isim_changed]; }
@end

@implementation UIDynamicItemBehavior { NSMutableArray *_itemList; @public NSMapTable *_addV, *_addW; }
- (instancetype)initWithItems:(NSArray *)items {
    if ((self = [super init])) {
        _itemList = [items mutableCopy] ?: [NSMutableArray array]; _density = 1; _allowsRotation = YES;
        _addV = [NSMapTable weakToStrongObjectsMapTable]; _addW = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}
ITEMS_IMPL
- (void)addLinearVelocity:(CGPoint)v forItem:(id<UIDynamicItem>)i {
    UIDynamicAnimator *an = self.dynamicAnimator;
    if (an) { [an performSelector:@selector(_isim_addVelocity:item:) withObject:[NSValue valueWithCGPoint:v] withObject:i]; return; }
    CGPoint o = [[_addV objectForKey:i] CGPointValue];
    [_addV setObject:[NSValue valueWithCGPoint:CGPointMake(o.x + v.x, o.y + v.y)] forKey:i];
}
- (CGPoint)linearVelocityForItem:(id<UIDynamicItem>)i {
    UIDynamicAnimator *an = self.dynamicAnimator;
    if (an) return [[an performSelector:@selector(_isim_velocityOf:) withObject:i] CGPointValue];
    return [[_addV objectForKey:i] CGPointValue];
}
- (void)addAngularVelocity:(CGFloat)w forItem:(id<UIDynamicItem>)i {
    UIDynamicAnimator *an = self.dynamicAnimator;
    if (an) { [an performSelector:@selector(_isim_addAngular:item:) withObject:@(w) withObject:i]; return; }
    [_addW setObject:@([[_addW objectForKey:i] doubleValue] + w) forKey:i];
}
- (CGFloat)angularVelocityForItem:(id<UIDynamicItem>)i {
    UIDynamicAnimator *an = self.dynamicAnimator;
    if (an) return [[an performSelector:@selector(_isim_angularOf:) withObject:i] doubleValue];
    return [[_addW objectForKey:i] doubleValue];
}
@end

/* ================= animator ================= */
@interface __IsimBody : NSObject { @public double vx, vy, w, angle, mass, e, friction, resistance, angRes; BOOL anchored, rotates; double rest; }
@end
@implementation __IsimBody @end

@implementation UIDynamicAnimator {
    NSMutableArray<UIDynamicBehavior *> *_behaviors;
    NSMapTable<id, __IsimBody *> *_bodies;
    double _last, _restTime, _elapsed;
    BOOL _ticking;
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
- (instancetype)init { return [self initWithReferenceView:nil]; }
#pragma clang diagnostic pop
- (instancetype)initWithReferenceView:(UIView *)view {
    if ((self = [super init])) { _referenceView = view; _behaviors = [NSMutableArray array]; _bodies = [NSMapTable strongToStrongObjectsMapTable]; }
    return self;
}
- (NSArray *)behaviors { return [_behaviors copy]; }
- (void)addBehavior:(UIDynamicBehavior *)b {
    if (!b || [_behaviors indexOfObjectIdenticalTo:b] != NSNotFound) return;
    [_behaviors addObject:b]; [b _isim_setAnimator:self];
    [self _isim_wake];
}
- (void)removeBehavior:(UIDynamicBehavior *)b { [b _isim_setAnimator:nil]; [_behaviors removeObjectIdenticalTo:b]; [self _isim_wake]; }
- (void)removeAllBehaviors { for (UIDynamicBehavior *b in [_behaviors copy]) [self removeBehavior:b]; }
- (NSArray *)itemsInRect:(CGRect)r {
    NSMutableArray *a = [NSMutableArray array];
    for (id<UIDynamicItem> i in [self _allItems]) { CGPoint c = i.center; CGSize s = i.bounds.size; if (CGRectIntersectsRect(r, CGRectMake(c.x - s.width / 2, c.y - s.height / 2, s.width, s.height))) [a addObject:i]; }
    return a;
}
- (void)updateItemUsingCurrentState:(id<UIDynamicItem>)item { [self _isim_wake]; }
- (void)_isim_wake {
    _restTime = 0;
    if (!_running && _ticking) { _running = YES; if ([_delegate respondsToSelector:@selector(dynamicAnimatorWillResume:)]) [_delegate dynamicAnimatorWillResume:self]; }
    if (!_ticking && _behaviors.count) {
        _ticking = YES; _last = 0;
        if (!_running) { _running = YES; if ([_delegate respondsToSelector:@selector(dynamicAnimatorWillResume:)]) [_delegate dynamicAnimatorWillResume:self]; }
        ca_driver_add_ticker(self);
    }
}
static void flatten(NSArray *bs, NSMutableArray *out) { for (UIDynamicBehavior *b in bs) { [out addObject:b]; flatten(b.childBehaviors, out); } }
- (NSArray *)_allBehaviors { NSMutableArray *a = [NSMutableArray array]; flatten(_behaviors, a); return a; }
- (NSArray *)_allItems {
    NSMutableArray *a = [NSMutableArray array];
    for (UIDynamicBehavior *b in [self _allBehaviors]) for (id i in [b _isim_items]) if ([a indexOfObjectIdenticalTo:i] == NSNotFound) [a addObject:i];
    return a;
}
- (__IsimBody *)_body:(id)item {
    __IsimBody *b = [_bodies objectForKey:item];
    if (!b) { b = [__IsimBody new]; b->rotates = YES; [_bodies setObject:b forKey:item]; }
    return b;
}
- (void)_isim_addVelocity:(NSValue *)v item:(id)i { __IsimBody *b = [self _body:i]; CGPoint p = v.CGPointValue; b->vx += p.x; b->vy += p.y; [self _isim_wake]; }
- (NSValue *)_isim_velocityOf:(id)i { __IsimBody *b = [_bodies objectForKey:i]; return [NSValue valueWithCGPoint:CGPointMake(b ? b->vx : 0, b ? b->vy : 0)]; }
- (void)_isim_addAngular:(NSNumber *)w item:(id)i { [self _body:i]->w += w.doubleValue; [self _isim_wake]; }
- (NSNumber *)_isim_angularOf:(id)i { return @([_bodies objectForKey:i] ? [_bodies objectForKey:i]->w : 0); }

static void report_contact(UICollisionBehavior *cb, NSMutableSet *now, id a, id b, id boundary, CGPoint at) {
    id key = boundary ? @[ @1, [NSValue valueWithNonretainedObject:a], boundary ] : @[ @0, [NSValue valueWithNonretainedObject:a], [NSValue valueWithNonretainedObject:b] ];
    [now addObject:key];
    if ([cb->_contacts containsObject:key]) return;
    id<UICollisionBehaviorDelegate> d = cb.collisionDelegate;
    if (boundary && [d respondsToSelector:@selector(collisionBehavior:beganContactForItem:withBoundaryIdentifier:atPoint:)])
        [d collisionBehavior:cb beganContactForItem:a withBoundaryIdentifier:boundary == (id)[NSNull null] ? nil : boundary atPoint:at];
    else if (!boundary && [d respondsToSelector:@selector(collisionBehavior:beganContactForItem:withItem:atPoint:)])
        [d collisionBehavior:cb beganContactForItem:a withItem:b atPoint:at];
}
/* ---- shapes and contacts ----
   An item is a rectangle (its bounds) turned by its angle, or an ellipse inscribed in it (collisionBoundsType
   .ellipse); .path uses the path's bounding rectangle (adapted). Contacts against a boundary line use the
   deepest corner (corners within half a point of it are averaged, so a box lying flat gets no torque) or the
   ellipse's support point; item pairs use the separating axis of the two rectangles. */
typedef struct { CGPoint c; double hx, hy, ang; BOOL ellipse; } Shape;
static Shape shape_of(id<UIDynamicItem> i, __IsimBody *b) {
    CGSize s = i.bounds.size;
    BOOL ell = [(id)i respondsToSelector:@selector(collisionBoundsType)] && i.collisionBoundsType == UIDynamicItemCollisionBoundsTypeEllipse;
    if ([(id)i respondsToSelector:@selector(collisionBoundsType)] && i.collisionBoundsType == UIDynamicItemCollisionBoundsTypePath &&
        [(id)i respondsToSelector:@selector(collisionBoundingPath)]) s = i.collisionBoundingPath.bounds.size;
    return (Shape){ i.center, s.width / 2, s.height / 2, b->angle, ell };
}
static void shape_corners(Shape o, CGPoint out[4]) {
    double c = cos(o.ang), s = sin(o.ang);
    double xs[4] = { -o.hx, o.hx, o.hx, -o.hx }, ys[4] = { -o.hy, -o.hy, o.hy, o.hy };
    for (int k = 0; k < 4; k++) out[k] = CGPointMake(o.c.x + xs[k] * c - ys[k] * s, o.c.y + xs[k] * s + ys[k] * c);
}
/* the shape against the half-plane through P whose normal n points into free space; for a segment (len >= 0, along
   (ux, uy) from P) only the points over the segment count */
static BOOL shape_plane_seg(Shape o, CGPoint P, double nx, double ny, double ux, double uy, double len, CGPoint *contact, double *depth);
static BOOL shape_plane(Shape o, CGPoint P, double nx, double ny, CGPoint *contact, double *depth) { return shape_plane_seg(o, P, nx, ny, 0, 0, -1, contact, depth); }
static BOOL over_segment(CGPoint x, CGPoint P, double ux, double uy, double len) {
    if (len < 0) return YES;
    double a = (x.x - P.x) * ux + (x.y - P.y) * uy;
    return a >= -0.5 && a <= len + 0.5;
}
static BOOL shape_plane_seg(Shape o, CGPoint P, double nx, double ny, double ux, double uy, double len, CGPoint *contact, double *depth) {
    if (o.ellipse) {                                           /* support point of the ellipse in -n */
        double c = cos(o.ang), s = sin(o.ang);
        double lx = -nx * c - ny * s, ly = nx * s - ny * c;    /* -n in the ellipse's frame */
        double ax = o.hx * o.hx * lx, ay = o.hy * o.hy * ly, len = sqrt(o.hx * o.hx * lx * lx + o.hy * o.hy * ly * ly);
        if (len < 1e-9) return NO;
        ax /= len; ay /= len;
        CGPoint sp = CGPointMake(o.c.x + ax * c - ay * s, o.c.y + ax * s + ay * c);
        double d = -((sp.x - P.x) * nx + (sp.y - P.y) * ny);
        if (d <= 0 || !over_segment(sp, P, ux, uy, len)) return NO;
        *contact = sp; *depth = d;
        return YES;
    }
    CGPoint k[4]; shape_corners(o, k);
    double ds[4], maxd = 0;
    for (int i = 0; i < 4; i++) { ds[i] = over_segment(k[i], P, ux, uy, len) ? -((k[i].x - P.x) * nx + (k[i].y - P.y) * ny) : -1; maxd = fmax(maxd, ds[i]); }
    if (maxd <= 0) return NO;
    double sx = 0, sy = 0; int n = 0;
    for (int i = 0; i < 4; i++) if (ds[i] >= maxd - 0.5) { sx += k[i].x; sy += k[i].y; n++; }
    *contact = CGPointMake(sx / n, sy / n); *depth = maxd;
    return YES;
}
static double inv_mass(__IsimBody *b) { return b->anchored ? 0 : 1 / fmax(b->mass, 1e-3); }
static double inv_inertia(__IsimBody *b, Shape o) {
    if (b->anchored || !b->rotates) return 0;
    double I = fmax(b->mass, 1e-3) * (4 * o.hx * o.hx + 4 * o.hy * o.hy) / 12;   /* a uniform rectangle */
    return 1 / fmax(I, 1e-6);
}
/* a contact of one body with something immovable: position correction, normal impulse (restitution) with the
   angular term, then Coulomb friction */
static void resolve_contact(id<UIDynamicItem> item, __IsimBody *b, Shape o, CGPoint at, double nx, double ny, double depth, double e) {
    if (b->anchored) return;
    CGPoint c = item.center; item.center = CGPointMake(c.x + nx * depth, c.y + ny * depth);
    double im = inv_mass(b), ii = inv_inertia(b, o);
    double rx = at.x - o.c.x, ry = at.y - o.c.y;
    double vx = b->vx - b->w * ry, vy = b->vy + b->w * rx, vn = vx * nx + vy * ny;
    if (vn >= 0) return;
    double rn = rx * ny - ry * nx, k = im + rn * rn * ii;
    double eff = -vn > 15 ? e : 0;                             /* settle instead of micro-bouncing */
    double j = -(1 + eff) * vn / k;
    b->vx += j * nx * im; b->vy += j * ny * im; b->w += rn * j * ii;
    if (b->friction > 0) {
        double tx = -ny, ty = nx;
        vx = b->vx - b->w * ry; vy = b->vy + b->w * rx;
        double vt = vx * tx + vy * ty, rt = rx * ty - ry * tx, kt = im + rt * rt * ii;
        double jt = -vt / kt, lim = b->friction * j;
        jt = fmax(-lim, fmin(lim, jt));
        b->vx += jt * tx * im; b->vy += jt * ty * im; b->w += rt * jt * ii;
    }
}
/* two rotated rectangles: separating axis (n points from q to p), the contact is the average of the corners of each
   inside the other */
static BOOL shape_pair(Shape p, Shape q, double *nx, double *ny, double *depth, CGPoint *contact) {
    double axes[4][2] = { { cos(p.ang), sin(p.ang) }, { -sin(p.ang), cos(p.ang) }, { cos(q.ang), sin(q.ang) }, { -sin(q.ang), cos(q.ang) } };
    double best = INFINITY, bx = 0, by = 0;
    for (int k = 0; k < 4; k++) {
        double ax = axes[k][0], ay = axes[k][1];
        double rp = p.hx * fabs(cos(p.ang) * ax + sin(p.ang) * ay) + p.hy * fabs(-sin(p.ang) * ax + cos(p.ang) * ay);
        double rq = q.hx * fabs(cos(q.ang) * ax + sin(q.ang) * ay) + q.hy * fabs(-sin(q.ang) * ax + cos(q.ang) * ay);
        double d = (p.c.x - q.c.x) * ax + (p.c.y - q.c.y) * ay, overlap = rp + rq - fabs(d);
        if (overlap <= 0) return NO;
        if (overlap < best) { best = overlap; bx = d >= 0 ? ax : -ax; by = d >= 0 ? ay : -ay; }
    }
    CGPoint kp[4], kq[4]; shape_corners(p, kp); shape_corners(q, kq);
    double sx = 0, sy = 0; int n = 0;
    for (int pass = 0; pass < 2; pass++) {
        Shape in = pass ? p : q; CGPoint *ks = pass ? kq : kp;
        double c = cos(in.ang), s = sin(in.ang);
        for (int k = 0; k < 4; k++) {
            double dx = ks[k].x - in.c.x, dy = ks[k].y - in.c.y, lx = dx * c + dy * s, ly = -dx * s + dy * c;
            if (fabs(lx) <= in.hx + 0.01 && fabs(ly) <= in.hy + 0.01) { sx += ks[k].x; sy += ks[k].y; n++; }
        }
    }
    *contact = n ? CGPointMake(sx / n, sy / n) : CGPointMake((p.c.x + q.c.x) / 2, (p.c.y + q.c.y) / 2);
    *nx = bx; *ny = by; *depth = best;
    return YES;
}
- (void)_step:(double)dt items:(NSArray *)items behaviors:(NSArray *)bs {
    /* forces */
    for (UIDynamicBehavior *bh in bs) {
        if ([bh isKindOfClass:[UIGravityBehavior class]]) {
            CGVector g = ((UIGravityBehavior *)bh).gravityDirection;
            for (id i in [bh _isim_items]) { __IsimBody *b = [self _body:i]; if (b->anchored) continue; b->vx += g.dx * 1000 * dt; b->vy += g.dy * 1000 * dt; }
        } else if ([bh isKindOfClass:[UIPushBehavior class]]) {
            UIPushBehavior *p = (UIPushBehavior *)bh;
            if (!p.active) continue;
            CGVector f = p.pushDirection;
            BOOL inst = p.mode == UIPushBehaviorModeInstantaneous;
            if (inst && p->_fired) continue;
            for (id i in [bh _isim_items]) {
                __IsimBody *b = [self _body:i]; if (b->anchored) continue;
                double k = 100 / fmax(b->mass, 1e-3) * (inst ? 1 : dt);
                b->vx += f.dx * k; b->vy += f.dy * k;
            }
            if (inst) { p->_fired = YES; p.active = NO; }
        } else if ([bh isKindOfClass:[UISnapBehavior class]]) {
            UISnapBehavior *s = (UISnapBehavior *)bh; id i = s->_item; if (!i) continue;
            __IsimBody *b = [self _body:i]; if (b->anchored) continue;
            CGPoint c = [i center];
            double k = 300, damp = 2 * sqrt(k) * (0.35 + fmin(1, fmax(0, s.damping)));
            b->vx += (k * (s.snapPoint.x - c.x) - damp * b->vx) * dt; b->vy += (k * (s.snapPoint.y - c.y) - damp * b->vy) * dt;
            b->w = 0; b->angle += (0 - b->angle) * fmin(1, 10 * dt);
        } else if ([bh isKindOfClass:[UIAttachmentBehavior class]]) {
            UIAttachmentBehavior *at = (UIAttachmentBehavior *)bh;
            id a = at->_a, o = at->_b; if (!a) continue;
            __IsimBody *ba = [self _body:a], *bo = o ? [self _body:o] : nil;
            CGPoint pa = [a center]; pa.x += at->_oa.horizontal; pa.y += at->_oa.vertical;
            CGPoint pb = o ? [o center] : at.anchorPoint; if (o) { pb.x += at->_ob.horizontal; pb.y += at->_ob.vertical; }
            double dx = pb.x - pa.x, dy = pb.y - pa.y, d = hypot(dx, dy);
            if (d < 1e-9) continue;
            double ux = dx / d, uy = dy / d, stretch = d - at.length;
            if (at.frequency > 0) {
                double wn = 2 * M_PI * at.frequency, k = wn * wn, c = 2 * at.damping * wn;
                double rv = ((bo ? bo->vx : 0) - ba->vx) * ux + ((bo ? bo->vy : 0) - ba->vy) * uy;
                double acc = (k * stretch + c * rv) * dt;
                if (!ba->anchored) { ba->vx += ux * acc; ba->vy += uy * acc; }
                if (bo && !bo->anchored) { bo->vx -= ux * acc; bo->vy -= uy * acc; }
            } else {      /* rigid: position correction + no relative radial velocity */
                double wa = ba->anchored ? 0 : 1, wb = bo && !bo->anchored ? 1 : 0, sum = wa + wb;
                if (sum <= 0) continue;
                CGPoint ca = [a center];
                if (wa > 0) { [a setCenter:CGPointMake(ca.x + ux * stretch * wa / sum, ca.y + uy * stretch * wa / sum)]; }
                if (wb > 0) { CGPoint cb = [o center]; [o setCenter:CGPointMake(cb.x - ux * stretch * wb / sum, cb.y - uy * stretch * wb / sum)]; }
                double rv = ((bo ? bo->vx : 0) - ba->vx) * ux + ((bo ? bo->vy : 0) - ba->vy) * uy;
                if (wa > 0) { ba->vx += ux * rv * wa / sum; ba->vy += uy * rv * wa / sum; }
                if (wb > 0) { bo->vx -= ux * rv * wb / sum; bo->vy -= uy * rv * wb / sum; }
            }
        }
    }
    /* integrate */
    for (id i in items) {
        __IsimBody *b = [self _body:i];
        if (b->anchored) { b->vx = b->vy = b->w = 0; continue; }
        if (b->resistance > 0) { double k = fmax(0, 1 - b->resistance * dt); b->vx *= k; b->vy *= k; }
        if (b->angRes > 0) b->w *= fmax(0, 1 - b->angRes * dt);
        CGPoint c = [i center]; [i setCenter:CGPointMake(c.x + b->vx * dt, c.y + b->vy * dt)];
        if (b->rotates && b->w != 0) b->angle += b->w * dt;
    }
    /* collisions */
    for (UIDynamicBehavior *bh in bs) {
        if (![bh isKindOfClass:[UICollisionBehavior class]]) continue;
        UICollisionBehavior *cb = (UICollisionBehavior *)bh;
        NSArray *its = [cb _isim_items];
        NSMutableSet *now = [NSMutableSet set];
        BOOL bounds = (cb.collisionMode & UICollisionBehaviorModeBoundaries) != 0, mutual = (cb.collisionMode & UICollisionBehaviorModeItems) != 0;
        for (id<UIDynamicItem> i in its) {
            __IsimBody *b = [self _body:i];
            if (!bounds) break;
            if (cb.translatesReferenceBoundsIntoBoundary && _referenceView) {
                CGRect R = UIEdgeInsetsInsetRect(_referenceView.bounds, cb->_insets);
                CGPoint planes[4] = { CGPointMake(CGRectGetMinX(R), 0), CGPointMake(CGRectGetMaxX(R), 0), CGPointMake(0, CGRectGetMinY(R)), CGPointMake(0, CGRectGetMaxY(R)) };
                double ns[4][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
                for (int k = 0; k < 4; k++) {
                    CGPoint at; double depth;
                    Shape o = shape_of(i, b);
                    if (!shape_plane(o, planes[k], ns[k][0], ns[k][1], &at, &depth)) continue;
                    resolve_contact(i, b, o, at, ns[k][0], ns[k][1], depth, b->e);
                    report_contact(cb, now, i, nil, [NSNull null], at);
                }
            }
            for (__IsimBoundary *bd in [cb _isim_boundaries]) {
                for (int k = 0; k + 1 < bd->n; k++) {
                    CGPoint P = bd->pts[k], Q = bd->pts[k + 1];
                    double dx = Q.x - P.x, dy = Q.y - P.y, len = hypot(dx, dy);
                    if (len < 1e-9) continue;
                    double ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
                    Shape o = shape_of(i, b);
                    if ((o.c.x - P.x) * nx + (o.c.y - P.y) * ny < 0) { nx = -nx; ny = -ny; }   /* the item's side of the line */
                    CGPoint at; double depth;
                    if (!shape_plane_seg(o, P, nx, ny, ux, uy, len, &at, &depth)) continue;   /* corners over the segment */
                    resolve_contact(i, b, o, at, nx, ny, depth, b->e);
                    report_contact(cb, now, i, nil, bd->identifier, at);
                }
            }
        }
        if (mutual) for (NSUInteger x = 0; x < its.count; x++) for (NSUInteger y = x + 1; y < its.count; y++) {
            id<UIDynamicItem> p = its[x], q = its[y];
            __IsimBody *bp = [self _body:p], *bq = [self _body:q];
            Shape sp = shape_of(p, bp), sq = shape_of(q, bq);
            double nx, ny, depth; CGPoint at;
            if (!shape_pair(sp, sq, &nx, &ny, &depth, &at)) continue;
            double ip = inv_mass(bp), iq = inv_mass(bq), sum = ip + iq;
            if (sum <= 0) continue;
            CGPoint pc = p.center, qc = q.center;
            p.center = CGPointMake(pc.x + nx * depth * ip / sum, pc.y + ny * depth * ip / sum);
            q.center = CGPointMake(qc.x - nx * depth * iq / sum, qc.y - ny * depth * iq / sum);
            double Ip = inv_inertia(bp, sp), Iq = inv_inertia(bq, sq);
            double rpx = at.x - sp.c.x, rpy = at.y - sp.c.y, rqx = at.x - sq.c.x, rqy = at.y - sq.c.y;
            double vx = (bp->vx - bp->w * rpy) - (bq->vx - bq->w * rqy), vy = (bp->vy + bp->w * rpx) - (bq->vy + bq->w * rqx);
            double vn = vx * nx + vy * ny;
            if (vn < 0) {
                double rnp = rpx * ny - rpy * nx, rnq = rqx * ny - rqy * nx;
                double e = (bp->e + bq->e) / 2, k = sum + rnp * rnp * Ip + rnq * rnq * Iq;
                double j = -(1 + (-vn > 15 ? e : 0)) * vn / k;
                bp->vx += j * ip * nx; bp->vy += j * ip * ny; bp->w += rnp * j * Ip;
                bq->vx -= j * iq * nx; bq->vy -= j * iq * ny; bq->w -= rnq * j * Iq;
            }
            report_contact(cb, now, p, q, nil, at);
        }
        /* ended contacts (reported once per frame step set) */
        for (NSArray *key in [cb->_contacts copy]) {
            if ([now containsObject:key]) continue;
            id<UICollisionBehaviorDelegate> d = cb.collisionDelegate;
            id a = [key[1] nonretainedObjectValue];
            if (![key[0] boolValue]) {
                if ([d respondsToSelector:@selector(collisionBehavior:endedContactForItem:withItem:)]) [d collisionBehavior:cb endedContactForItem:a withItem:[key[2] nonretainedObjectValue]];
            } else if ([d respondsToSelector:@selector(collisionBehavior:endedContactForItem:withBoundaryIdentifier:)])
                [d collisionBehavior:cb endedContactForItem:a withBoundaryIdentifier:key[2] == [NSNull null] ? nil : key[2]];
        }
        [cb->_contacts setSet:now];
    }
}
/* the frame tick: YES while the animator runs */
- (NSTimeInterval)elapsedTime { return _elapsed; }
- (BOOL)_isim_tick:(double)now {
    if (!_behaviors.count) { _ticking = NO; [self _pause]; return NO; }
    double dt = _last > 0 ? fmin(0.05, now - _last) : 1.0 / 60;
    _last = now;
    NSArray *bs = [self _allBehaviors], *items = [self _allItems];
    /* item properties: defaults, then UIDynamicItemBehaviors in order */
    for (id i in items) {
        __IsimBody *b = [self _body:i]; CGSize s = [i bounds].size;
        b->mass = s.width * s.height / 10000.0; b->e = 0; b->friction = 0; b->resistance = 0; b->angRes = 0; b->anchored = NO; b->rotates = YES;
    }
    for (UIDynamicBehavior *bh in bs) {
        if (![bh isKindOfClass:[UIDynamicItemBehavior class]]) continue;
        UIDynamicItemBehavior *ib = (UIDynamicItemBehavior *)bh;
        for (id i in [ib _isim_items]) {
            __IsimBody *b = [self _body:i]; CGSize s = [i bounds].size;
            b->mass = fmax(1e-3, ib.density) * s.width * s.height / 10000.0; b->e = ib.elasticity; b->friction = ib.friction;
            b->resistance = ib.resistance; b->angRes = ib.angularResistance; b->anchored = ib.anchored; b->rotates = ib.allowsRotation;
            NSValue *v = [ib->_addV objectForKey:i]; if (v) { b->vx += v.CGPointValue.x; b->vy += v.CGPointValue.y; [ib->_addV removeObjectForKey:i]; }
            NSNumber *w = [ib->_addW objectForKey:i]; if (w) { b->w += w.doubleValue; [ib->_addW removeObjectForKey:i]; }
        }
    }
    NSMutableDictionary *before = [NSMutableDictionary dictionary];
    for (id i in items) before[[NSValue valueWithNonretainedObject:i]] = [NSValue valueWithCGPoint:[i center]];
    int n = (int)ceil(dt * 240); double h = dt / n;
    for (int k = 0; k < n; k++) [self _step:h items:items behaviors:bs];
    /* rotation from angular velocity (items that rotate) */
    for (id i in items) {
        __IsimBody *b = [self _body:i];
        if (b->angle != 0 || b->w != 0) [(id<UIDynamicItem>)i setTransform:CGAffineTransformMakeRotation(b->angle)];
    }
    _elapsed += dt;
    for (UIDynamicBehavior *bh in bs) if (bh.action) bh.action();
    /* rest detection: nothing moves for 0.25 s */
    double moved = 0, speed = 0;
    for (id i in items) {
        CGPoint a = [before[[NSValue valueWithNonretainedObject:i]] CGPointValue], c = [i center];
        moved = fmax(moved, hypot(c.x - a.x, c.y - a.y));
        __IsimBody *b = [self _body:i]; if (!b->anchored) speed = fmax(speed, hypot(b->vx, b->vy) + fabs(b->w) * 10);
    }
    BOOL pendingPush = NO;
    for (UIDynamicBehavior *bh in bs) if ([bh isKindOfClass:[UIPushBehavior class]] && ((UIPushBehavior *)bh).active) pendingPush = YES;
    if (moved < 0.05 && speed < 20 && !pendingPush) _restTime += dt; else _restTime = 0;
    if (_restTime > 0.25) {
        for (id i in items) { __IsimBody *b = [self _body:i]; b->vx = b->vy = b->w = 0; }
        _ticking = NO; [self _pause];
        return NO;
    }
    if (!_running) { _running = YES; if ([_delegate respondsToSelector:@selector(dynamicAnimatorWillResume:)]) [_delegate dynamicAnimatorWillResume:self]; }
    return YES;
}
- (void)_pause {
    if (!_running) return;
    _running = NO;
    if ([_delegate respondsToSelector:@selector(dynamicAnimatorDidPause:)]) [_delegate dynamicAnimatorDidPause:self];
}
@end
