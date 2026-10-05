#pragma once
#include <CoreGraphics/CGBase.h>
__BEGIN_DECLS
struct CGPoint { CGFloat x; CGFloat y; };
typedef struct CGPoint CGPoint;
struct CGSize { CGFloat width; CGFloat height; };
typedef struct CGSize CGSize;
struct CGVector { CGFloat dx; CGFloat dy; };
typedef struct CGVector CGVector;
struct CGRect { CGPoint origin; CGSize size; };
typedef struct CGRect CGRect;
typedef CF_ENUM(uint32_t, CGRectEdge) { CGRectMinXEdge, CGRectMinYEdge, CGRectMaxXEdge, CGRectMaxYEdge };

CG_EXTERN const CGPoint CGPointZero;
CG_EXTERN const CGSize CGSizeZero;
CG_EXTERN const CGRect CGRectZero;
CG_EXTERN const CGRect CGRectNull;
CG_EXTERN const CGRect CGRectInfinite;

CG_INLINE CGPoint CGPointMake(CGFloat x, CGFloat y) { CGPoint p = { x, y }; return p; }
CG_INLINE CGSize CGSizeMake(CGFloat w, CGFloat h) { CGSize s = { w, h }; return s; }
CG_INLINE CGVector CGVectorMake(CGFloat dx, CGFloat dy) { CGVector v = { dx, dy }; return v; }
CG_INLINE CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat w, CGFloat h) { CGRect r = { { x, y }, { w, h } }; return r; }

CG_EXTERN CGFloat CGRectGetMinX(CGRect r);
CG_EXTERN CGFloat CGRectGetMidX(CGRect r);
CG_EXTERN CGFloat CGRectGetMaxX(CGRect r);
CG_EXTERN CGFloat CGRectGetMinY(CGRect r);
CG_EXTERN CGFloat CGRectGetMidY(CGRect r);
CG_EXTERN CGFloat CGRectGetMaxY(CGRect r);
CG_EXTERN CGFloat CGRectGetWidth(CGRect r);
CG_EXTERN CGFloat CGRectGetHeight(CGRect r);
CG_EXTERN bool CGPointEqualToPoint(CGPoint a, CGPoint b);
CG_EXTERN bool CGSizeEqualToSize(CGSize a, CGSize b);
CG_EXTERN bool CGRectEqualToRect(CGRect a, CGRect b);
CG_EXTERN CGRect CGRectStandardize(CGRect r);
CG_EXTERN bool CGRectIsEmpty(CGRect r);
CG_EXTERN bool CGRectIsNull(CGRect r);
CG_EXTERN CGRect CGRectInset(CGRect r, CGFloat dx, CGFloat dy);
CG_EXTERN CGRect CGRectOffset(CGRect r, CGFloat dx, CGFloat dy);
CG_EXTERN CGRect CGRectIntegral(CGRect r);
CG_EXTERN CGRect CGRectUnion(CGRect a, CGRect b);
CG_EXTERN CGRect CGRectIntersection(CGRect a, CGRect b);
CG_EXTERN bool CGRectIntersectsRect(CGRect a, CGRect b);
CG_EXTERN bool CGRectContainsPoint(CGRect r, CGPoint p);
CG_EXTERN bool CGRectContainsRect(CGRect a, CGRect b);
CG_EXTERN void CGRectDivide(CGRect r, CGRect *slice, CGRect *remainder, CGFloat amount, CGRectEdge edge);
__END_DECLS
