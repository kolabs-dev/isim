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

/* ================= snapshots ================= */
@implementation UIView (UISnapshotting)
- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)after {
    CGSize b = self.bounds.size;
    if (b.width <= 0 || b.height <= 0) return NO;
    CGRect f = self.frame;
    isim_gfx_save();
    isim_gfx_translate(rect.origin.x, rect.origin.y);
    isim_gfx_scale(rect.size.width / b.width, rect.size.height / b.height);
    isim_gfx_translate(-f.origin.x, -f.origin.y);          /* _isim_render draws at the view's frame origin */
    [self _isim_render];
    isim_gfx_restore();
    return YES;
}
- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)after {
    CGSize b = self.bounds.size;
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, b.width, b.height)];
    if (b.width <= 0 || b.height <= 0) return iv;
    UIGraphicsBeginImageContextWithOptions(b, NO, UIScreen.mainScreen.scale);
    [self drawViewHierarchyInRect:CGRectMake(0, 0, b.width, b.height) afterScreenUpdates:after];
    iv.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return iv;
}
@end
