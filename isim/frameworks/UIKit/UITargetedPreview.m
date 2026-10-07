/* UITargetedPreview / UIPreviewParameters / UIPreviewTarget: which view a pointer effect, drag lift or drop
 * animates, and where. */
#import "UIKitInputPrivate.h"

@implementation UIPreviewParameters
- (instancetype)initWithTextLineRects:(NSArray<NSValue *> *)rects {
    if ((self = [super init])) {
        CGRect u = CGRectNull;
        for (NSValue *v in rects) u = CGRectUnion(u, v.CGRectValue);
        if (!CGRectIsNull(u)) _visiblePath = [UIBezierPath bezierPathWithRoundedRect:u cornerRadius:6];
    }
    return self;
}
- (UIColor *)backgroundColor { return _backgroundColor ?: UIColor.systemBackgroundColor; }
- (id)copyWithZone:(NSZone *)z {
    UIPreviewParameters *p = [UIPreviewParameters new];
    p.visiblePath = _visiblePath; p.shadowPath = _shadowPath; p.backgroundColor = _backgroundColor;
    return p;
}
@end

@implementation UIPreviewTarget
- (instancetype)initWithContainer:(UIView *)c center:(CGPoint)center transform:(CGAffineTransform)t {
    if ((self = [super init])) { _container = c; _center = center; _transform = t; }
    return self;
}
- (instancetype)initWithContainer:(UIView *)c center:(CGPoint)center { return [self initWithContainer:c center:center transform:CGAffineTransformIdentity]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@implementation UITargetedPreview
- (instancetype)initWithView:(UIView *)v parameters:(UIPreviewParameters *)p target:(UIPreviewTarget *)t {
    if ((self = [super init])) { _view = v; _parameters = [p copy] ?: [UIPreviewParameters new]; _target = t; }
    return self;
}
- (instancetype)initWithView:(UIView *)v parameters:(UIPreviewParameters *)p {
    UIPreviewTarget *t = v.superview ? [[UIPreviewTarget alloc] initWithContainer:v.superview center:v.center] : nil;
    return [self initWithView:v parameters:p target:t];
}
- (instancetype)initWithView:(UIView *)v { return [self initWithView:v parameters:[UIPreviewParameters new]]; }
- (CGSize)size {
    if (_parameters.visiblePath) return _parameters.visiblePath.bounds.size;
    return _view.bounds.size;
}
- (UITargetedPreview *)retargetedPreviewWithTarget:(UIPreviewTarget *)t { return [[UITargetedPreview alloc] initWithView:_view parameters:_parameters target:t]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

/* snapshots (drawViewHierarchyInRect:, snapshotViewAfterScreenUpdates:) are in UISystemIntegration.m */
