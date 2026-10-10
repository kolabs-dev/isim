/* Motion effects (ARC): the viewer offset (script `tilt H V`, 0 at rest, 0 with Reduce Motion) is turned into
 * relative values by each view's effects; UIView's rendering adds them to its presentation (UIView.m _isim_render). */
#import "UIKitPrivate.h"
#import <objc/runtime.h>

static UIOffset viewer_offset;
@implementation UIMotionEffect
- (instancetype)init { return [super init]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [super init]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (id)copyWithZone:(NSZone *)z { return [[self class] new]; }
- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)o { return nil; }
@end

/* a value between two of the same kind (numbers, points, sizes, offsets) */
static id lerp_value(id a, id b, double t) {
    if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]]) return @([a doubleValue] + ([b doubleValue] - [a doubleValue]) * t);
    if ([a isKindOfClass:[NSValue class]] && [b isKindOfClass:[NSValue class]]) {
        const char *ta = [a objCType];
        if (!strcmp(ta, @encode(CGPoint))) { CGPoint p = [a CGPointValue], q = [b CGPointValue]; return [NSValue valueWithCGPoint:CGPointMake(p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t)]; }
        if (!strcmp(ta, @encode(CGSize))) { CGSize p = [a CGSizeValue], q = [b CGSizeValue]; return [NSValue valueWithCGSize:CGSizeMake(p.width + (q.width - p.width) * t, p.height + (q.height - p.height) * t)]; }
        if (!strcmp(ta, @encode(UIOffset))) { UIOffset p = [a UIOffsetValue], q = [b UIOffsetValue]; return [NSValue valueWithUIOffset:UIOffsetMake(p.horizontal + (q.horizontal - p.horizontal) * t, p.vertical + (q.vertical - p.vertical) * t)]; }
    }
    return t < 0.5 ? a : b;
}
@implementation UIInterpolatingMotionEffect
- (instancetype)init { return [self initWithKeyPath:@"" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis]; }
- (instancetype)initWithKeyPath:(NSString *)k type:(UIInterpolatingMotionEffectType)t { if ((self = [super init])) { _keyPath = [k copy]; _type = t; } return self; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithKeyPath:[c decodeObjectOfClass:[NSString class] forKey:@"keyPath"] ?: @"" type:[c decodeIntegerForKey:@"type"]]; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_keyPath forKey:@"keyPath"]; [c encodeInteger:_type forKey:@"type"]; }
- (id)copyWithZone:(NSZone *)z {
    UIInterpolatingMotionEffect *e = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:_keyPath type:_type];
    e.minimumRelativeValue = _minimumRelativeValue; e.maximumRelativeValue = _maximumRelativeValue; return e;
}
- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)o {
    if (!_keyPath.length || !_minimumRelativeValue || !_maximumRelativeValue) return nil;
    double v = _type == UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis ? o.horizontal : o.vertical;
    double t = (fmin(1, fmax(-1, v)) + 1) / 2;
    return @{ _keyPath: lerp_value(_minimumRelativeValue, _maximumRelativeValue, t) };
}
@end
@implementation UIMotionEffectGroup
- (id)copyWithZone:(NSZone *)z { UIMotionEffectGroup *g = [UIMotionEffectGroup new]; g.motionEffects = _motionEffects; return g; }
- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)o {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (UIMotionEffect *e in _motionEffects) [d addEntriesFromDictionary:[e keyPathsAndRelativeValuesForViewerOffset:o] ?: @{}];
    return d;
}
@end

static char k_effects;
static NSHashTable<UIView *> *effect_views;
@implementation UIView (UIMotionEffects)
- (NSArray *)motionEffects { return [objc_getAssociatedObject(self, &k_effects) copy] ?: @[]; }
- (void)setMotionEffects:(NSArray *)a {
    objc_setAssociatedObject(self, &k_effects, a.count ? [a mutableCopy] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!effect_views) effect_views = [NSHashTable weakObjectsHashTable];
    if (a.count) [effect_views addObject:self]; else [effect_views removeObject:self];
    isim_ui_set_needs_display();
}
- (void)addMotionEffect:(UIMotionEffect *)e { if (e) [self setMotionEffects:[self.motionEffects arrayByAddingObject:e]]; }
- (void)removeMotionEffect:(UIMotionEffect *)e { NSMutableArray *a = [self.motionEffects mutableCopy]; [a removeObjectIdenticalTo:e]; [self setMotionEffects:a]; }
@end

/* the presentation offsets a view's effects give now (UIView.m _isim_render) */
BOOL isim_ui_motion_effect_values(UIView *v, CGPoint *center, CGSize *shadow, CGFloat *alpha) {
    NSArray *effects = objc_getAssociatedObject(v, &k_effects);
    if (!effects.count || UIAccessibilityIsReduceMotionEnabled()) return NO;
    if (viewer_offset.horizontal == 0 && viewer_offset.vertical == 0) return NO;
    BOOL any = NO;
    for (UIMotionEffect *e in effects) {
        NSDictionary *d = [e keyPathsAndRelativeValuesForViewerOffset:viewer_offset];
        [d enumerateKeysAndObjectsUsingBlock:^(NSString *k, id val, BOOL *stop) {
            if ([k isEqualToString:@"center.x"]) center->x += [val doubleValue];
            else if ([k isEqualToString:@"center.y"]) center->y += [val doubleValue];
            else if ([k isEqualToString:@"center"] && [val isKindOfClass:[NSValue class]]) { CGPoint p = [val CGPointValue]; center->x += p.x; center->y += p.y; }
            else if ([k isEqualToString:@"layer.shadowOffset"] && [val isKindOfClass:[NSValue class]]) { CGSize s = [val CGSizeValue]; shadow->width += s.width; shadow->height += s.height; }
            else if ([k isEqualToString:@"layer.shadowOffset.width"]) shadow->width += [val doubleValue];
            else if ([k isEqualToString:@"layer.shadowOffset.height"]) shadow->height += [val doubleValue];
            else if ([k isEqualToString:@"alpha"]) *alpha += [val doubleValue];
        }];
        any = YES;
    }
    return any;
}
/* script "tilt H V": the viewer offset (each -1..1); "tilt" alone levels the device */
void isim_ui_tilt(NSString *args) {
    double h = 0, v = 0;
    NSArray *p = [[args stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] componentsSeparatedByString:@" "];
    if (p.count >= 1) h = [p[0] doubleValue];
    if (p.count >= 2) v = [p[1] doubleValue];
    viewer_offset = UIOffsetMake(fmin(1, fmax(-1, h)), fmin(1, fmax(-1, v)));
    NSLog(@"isim: tilt %.2f %.2f", viewer_offset.horizontal, viewer_offset.vertical);
    isim_ui_set_needs_display();
}
