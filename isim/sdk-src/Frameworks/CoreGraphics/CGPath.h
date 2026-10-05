#pragma once
#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGAffineTransform.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: paths are reference-counted objects (as on Apple platforms) */
typedef const struct __attribute__((objc_bridge(id))) CGPath *CGPathRef;
typedef struct __attribute__((objc_bridge_mutable(id))) CGPath *CGMutablePathRef;
typedef CF_ENUM(int32_t, CGPathElementType) {
    kCGPathElementMoveToPoint, kCGPathElementAddLineToPoint, kCGPathElementAddQuadCurveToPoint,
    kCGPathElementAddCurveToPoint, kCGPathElementCloseSubpath
};
typedef struct CGPathElement { CGPathElementType type; CGPoint *points; } CGPathElement;
typedef void (*CGPathApplierFunction)(void * _Nullable info, const CGPathElement *element);
CG_EXTERN CGMutablePathRef CGPathCreateMutable(void) __attribute__((swift_name("CGMutablePath.init()")));
CG_EXTERN CGPathRef _Nullable CGPathCreateCopy(CGPathRef _Nullable path);
CG_EXTERN CGMutablePathRef _Nullable CGPathCreateMutableCopy(CGPathRef _Nullable path);
CG_EXTERN CGPathRef CGPathCreateWithRect(CGRect rect, const CGAffineTransform * _Nullable transform) __attribute__((swift_name("CGPath.init(rect:transform:)")));
CG_EXTERN CGPathRef CGPathCreateWithEllipseInRect(CGRect rect, const CGAffineTransform * _Nullable transform) __attribute__((swift_name("CGPath.init(ellipseIn:transform:)")));
CG_EXTERN CGPathRef CGPathCreateWithRoundedRect(CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight, const CGAffineTransform * _Nullable transform) __attribute__((swift_name("CGPath.init(roundedRect:cornerWidth:cornerHeight:transform:)")));
CG_EXTERN CGPathRef _Nullable CGPathRetain(CGPathRef _Nullable path);
CG_EXTERN void CGPathRelease(CGPathRef _Nullable path);
CG_EXTERN void CGPathMoveToPoint(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddLineToPoint(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddQuadCurveToPoint(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddCurveToPoint(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y);
CG_EXTERN void CGPathCloseSubpath(CGMutablePathRef path);
CG_EXTERN void CGPathAddRect(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGRect rect);
CG_EXTERN void CGPathAddEllipseInRect(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGRect rect);
CG_EXTERN void CGPathAddRoundedRect(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight);
CG_EXTERN void CGPathAddArc(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat endAngle, bool clockwise);
CG_EXTERN void CGPathAddRelativeArc(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat delta);
CG_EXTERN void CGPathAddPath(CGMutablePathRef path, const CGAffineTransform * _Nullable m, CGPathRef other);
CG_EXTERN bool CGPathIsEmpty(CGPathRef path);
CG_EXTERN CGPoint CGPathGetCurrentPoint(CGPathRef path);
CG_EXTERN CGRect CGPathGetBoundingBox(CGPathRef path);
CG_EXTERN CGRect CGPathGetPathBoundingBox(CGPathRef path);
CG_EXTERN bool CGPathContainsPoint(CGPathRef path, const CGAffineTransform * _Nullable m, CGPoint point, bool eoFill);
CG_EXTERN bool CGPathEqualToPath(CGPathRef a, CGPathRef b);
CG_EXTERN void CGPathApply(CGPathRef path, void * _Nullable info, CGPathApplierFunction _Nullable function);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
