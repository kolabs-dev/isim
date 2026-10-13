/* Hover styles and shapes (UIHoverStyle.h). Shapes resolve against a rect (a view's bounds): rect (with corners),
 * capsule, circle, fixed rect, path, provider, and insets of them. A view's hoverStyle turns into the pointer effect
 * of UIHover.m on iPad (the only device with a pointer). */
#import "UIKitPrivate.h"
#import <UIKit/UIHoverStyle.h>
#import <objc/runtime.h>

@interface UIShapeResolutionContext ()
- (instancetype)_initWithContent:(UIResolvedShape *)content;
@end
@interface UIResolvedShape ()
- (instancetype)_initWithShape:(UIShape *)shape rect:(CGRect)rect path:(UIBezierPath *)path;
@end

@implementation UIShapeResolutionContext
- (instancetype)_initWithContent:(UIResolvedShape *)c { if ((self = [super init])) _contentShape = c; return self; }
@end

@implementation UIResolvedShape
- (instancetype)_initWithShape:(UIShape *)shape rect:(CGRect)rect path:(UIBezierPath *)path {
    if ((self = [super init])) { _shape = shape; _boundingRect = rect; _path = [path copy] ?: [UIBezierPath bezierPathWithRect:rect]; }
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (UIResolvedShape *)shapeByApplyingInset:(CGFloat)i { return [self shapeByApplyingInsets:UIEdgeInsetsMake(i, i, i, i)]; }
- (UIResolvedShape *)shapeByApplyingInsets:(UIEdgeInsets)e {
    UIShape *s = [_shape shapeByApplyingInsets:e];
    return [s _isimResolvedInRect:[self _isimContentRect]];
}
- (CGRect)_isimContentRect { return objc_getAssociatedObject(self, @selector(_isimContentRect)) ? [objc_getAssociatedObject(self, @selector(_isimContentRect)) CGRectValue] : _boundingRect; }
@end

typedef NS_ENUM(NSInteger, IsimShapeKind) { IsimShapeRect, IsimShapeCapsule, IsimShapeCircle, IsimShapeFixed, IsimShapePath, IsimShapeProvider };
@implementation UIShape {
    IsimShapeKind _kind;
    CGFloat _radius; UICornerCurve _curve; UIRectCorner _corners;
    CGRect _rect;
    UIBezierPath *_path;
    id<UIShapeProvider> _provider;
    UIEdgeInsets _insets;
}
+ (instancetype)_kind:(IsimShapeKind)k { UIShape *s = [[self alloc] _isimInit]; s->_kind = k; s->_corners = UIRectCornerAllCorners; return s; }
- (instancetype)_isimInit { return [super init]; }
+ (UIShape *)rectShape { return [self _kind:IsimShapeRect]; }
+ (UIShape *)capsuleShape { return [self _kind:IsimShapeCapsule]; }
+ (UIShape *)circleShape { return [self _kind:IsimShapeCircle]; }
+ (instancetype)rectShapeWithCornerRadius:(CGFloat)r { return [self rectShapeWithCornerRadius:r cornerCurve:UICornerCurveAutomatic maskedCorners:UIRectCornerAllCorners]; }
+ (instancetype)rectShapeWithCornerRadius:(CGFloat)r cornerCurve:(UICornerCurve)c { return [self rectShapeWithCornerRadius:r cornerCurve:c maskedCorners:UIRectCornerAllCorners]; }
+ (instancetype)rectShapeWithCornerRadius:(CGFloat)r cornerCurve:(UICornerCurve)c maskedCorners:(UIRectCorner)m {
    UIShape *s = [self _kind:IsimShapeRect]; s->_radius = r; s->_curve = c; s->_corners = m; return s;
}
+ (instancetype)fixedRectShapeWithRect:(CGRect)rect { return [self fixedRectShapeWithRect:rect cornerRadius:0 cornerCurve:UICornerCurveAutomatic maskedCorners:UIRectCornerAllCorners]; }
+ (instancetype)fixedRectShapeWithRect:(CGRect)rect cornerRadius:(CGFloat)r { return [self fixedRectShapeWithRect:rect cornerRadius:r cornerCurve:UICornerCurveAutomatic maskedCorners:UIRectCornerAllCorners]; }
+ (instancetype)fixedRectShapeWithRect:(CGRect)rect cornerRadius:(CGFloat)r cornerCurve:(UICornerCurve)c maskedCorners:(UIRectCorner)m {
    UIShape *s = [self _kind:IsimShapeFixed]; s->_rect = rect; s->_radius = r; s->_curve = c; s->_corners = m; return s;
}
+ (instancetype)shapeWithBezierPath:(UIBezierPath *)p { UIShape *s = [self _kind:IsimShapePath]; s->_path = [p copy]; return s; }
+ (instancetype)shapeWithProvider:(id<UIShapeProvider>)p { UIShape *s = [self _kind:IsimShapeProvider]; s->_provider = p; return s; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (UIShape *)_copy {
    UIShape *s = [[UIShape alloc] _isimInit];
    s->_kind = _kind; s->_radius = _radius; s->_curve = _curve; s->_corners = _corners; s->_rect = _rect; s->_path = _path; s->_provider = _provider; s->_insets = _insets;
    return s;
}
- (UIShape *)shapeByApplyingInset:(CGFloat)i { return [self shapeByApplyingInsets:UIEdgeInsetsMake(i, i, i, i)]; }
- (UIShape *)shapeByApplyingInsets:(UIEdgeInsets)e {
    UIShape *s = [self _copy];
    s->_insets = UIEdgeInsetsMake(_insets.top + e.top, _insets.left + e.left, _insets.bottom + e.bottom, _insets.right + e.right);
    return s;
}
- (BOOL)isEqual:(UIShape *)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[UIShape class]]) return NO;
    return o->_kind == _kind && o->_radius == _radius && o->_curve == _curve && o->_corners == _corners && CGRectEqualToRect(o->_rect, _rect)
        && (o->_path == _path || [o->_path isEqual:_path]) && o->_provider == _provider && UIEdgeInsetsEqualToEdgeInsets(o->_insets, _insets);
}
- (NSUInteger)hash { return (NSUInteger)_kind * 31 + (NSUInteger)_radius; }
- (UIResolvedShape *)resolvedShapeInContext:(UIShapeResolutionContext *)context { return [self _isimResolvedInRect:context.contentShape.boundingRect]; }
- (UIResolvedShape *)_isimResolvedInRect:(CGRect)content {
    CGRect r = UIEdgeInsetsInsetRect(_kind == IsimShapeFixed ? _rect : content, _insets);
    UIBezierPath *p;
    switch (_kind) {
    case IsimShapeRect: case IsimShapeFixed:
        p = _radius > 0 ? [UIBezierPath bezierPathWithRoundedRect:r byRoundingCorners:_corners cornerRadii:CGSizeMake(_radius, _radius)] : [UIBezierPath bezierPathWithRect:r];
        break;
    case IsimShapeCapsule: p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:MIN(r.size.width, r.size.height) / 2]; break;
    case IsimShapeCircle: {
        CGFloat d = MIN(r.size.width, r.size.height);
        r = CGRectMake(CGRectGetMidX(r) - d / 2, CGRectGetMidY(r) - d / 2, d, d);
        p = [UIBezierPath bezierPathWithOvalInRect:r];
        break;
    }
    case IsimShapePath: p = _path; r = _path.bounds; break;
    case IsimShapeProvider: {
        UIResolvedShape *base = [UIShape.rectShape _isimResolvedInRect:content];
        UIResolvedShape *x = [_provider resolvedShapeInContext:[[UIShapeResolutionContext alloc] _initWithContent:base]];
        p = x.path; r = x.boundingRect;
        if (!UIEdgeInsetsEqualToEdgeInsets(_insets, UIEdgeInsetsZero)) { r = UIEdgeInsetsInsetRect(r, _insets); p = [UIBezierPath bezierPathWithRect:r]; }
        break;
    }
    }
    UIResolvedShape *res = [[UIResolvedShape alloc] _initWithShape:self rect:r path:p];
    objc_setAssociatedObject(res, @selector(_isimContentRect), [NSValue valueWithCGRect:content], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return res;
}
/* the corner radius a rect-like shape draws with in a rect (the pointer platter) */
- (CGFloat)_isimCornerRadiusIn:(CGRect)r {
    if (_kind == IsimShapeCapsule) return MIN(r.size.width, r.size.height) / 2;
    if (_kind == IsimShapeCircle) return MIN(r.size.width, r.size.height) / 2;
    return _radius;
}
@end

#define EFFECT(cls) \
@implementation cls \
+ (instancetype)effect { return [self new]; } \
- (id)copyWithZone:(NSZone *)z { return self; } \
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[cls class]]; } \
- (NSUInteger)hash { return (NSUInteger)(__bridge void *)[cls class]; } \
@end
EFFECT(UIHoverAutomaticEffect)
EFFECT(UIHoverHighlightEffect)
EFFECT(UIHoverLiftEffect)

@implementation UIHoverStyle
+ (instancetype)styleWithEffect:(id<UIHoverEffect>)effect shape:(UIShape *)shape {
    UIHoverStyle *s = [[self alloc] _isimInit]; s.effect = effect ?: [UIHoverAutomaticEffect effect]; s.shape = shape; s.enabled = YES; return s;
}
+ (instancetype)styleWithShape:(UIShape *)shape { return [self styleWithEffect:[UIHoverAutomaticEffect effect] shape:shape]; }
+ (instancetype)automaticStyle { return [self styleWithEffect:[UIHoverAutomaticEffect effect] shape:nil]; }
- (instancetype)_isimInit { return [super init]; }
- (id)copyWithZone:(NSZone *)z { UIHoverStyle *s = [UIHoverStyle styleWithEffect:_effect shape:_shape]; s.enabled = _enabled; return s; }
@end

static char kHoverStyle;
@implementation UIView (UIHoverStyle)
- (UIHoverStyle *)hoverStyle { return objc_getAssociatedObject(self, &kHoverStyle); }
- (void)setHoverStyle:(UIHoverStyle *)s { objc_setAssociatedObject(self, &kHoverStyle, [s copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

/* the pointer style a view's hover style asks for (nil: none, or disabled) */
UIPointerStyle *isim_ui_hover_pointer_style(UIView *v) {
    UIHoverStyle *h = v.hoverStyle;
    if (!h.enabled) return nil;
    UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:v];
    UIPointerEffect *e = [h.effect isKindOfClass:[UIHoverLiftEffect class]] ? [UIPointerLiftEffect effectWithPreview:preview]
                                                                             : [UIPointerHighlightEffect effectWithPreview:preview];
    UIPointerShape *shape = nil;
    if (h.shape) {
        UIResolvedShape *r = [h.shape _isimResolvedInRect:v.bounds];
        /* the pointer shape is in the view's own coordinates (UIHover.m converts it to the window) */
        shape = [UIPointerShape shapeWithRoundedRect:r.boundingRect cornerRadius:[h.shape _isimCornerRadiusIn:r.boundingRect]];
    }
    return [UIPointerStyle styleWithEffect:e shape:shape];
}
