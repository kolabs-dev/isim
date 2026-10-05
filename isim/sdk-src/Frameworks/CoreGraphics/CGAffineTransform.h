#pragma once
#include <CoreGraphics/CGGeometry.h>
__BEGIN_DECLS
struct CGAffineTransform { CGFloat a, b, c, d, tx, ty; };
typedef struct CGAffineTransform CGAffineTransform;
CG_EXTERN const CGAffineTransform CGAffineTransformIdentity;
CG_EXTERN CGAffineTransform CGAffineTransformMake(CGFloat a, CGFloat b, CGFloat c, CGFloat d, CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformMakeTranslation(CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformMakeScale(CGFloat sx, CGFloat sy);
CG_EXTERN CGAffineTransform CGAffineTransformMakeRotation(CGFloat angle);
CG_EXTERN CGAffineTransform CGAffineTransformConcat(CGAffineTransform t1, CGAffineTransform t2);
CG_EXTERN bool CGAffineTransformIsIdentity(CGAffineTransform t);
CG_EXTERN CGPoint CGPointApplyAffineTransform(CGPoint p, CGAffineTransform t);
CG_EXTERN CGSize CGSizeApplyAffineTransform(CGSize s, CGAffineTransform t);
CG_EXTERN CGRect CGRectApplyAffineTransform(CGRect r, CGAffineTransform t);
CG_EXTERN CGAffineTransform CGAffineTransformTranslate(CGAffineTransform t, CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformScale(CGAffineTransform t, CGFloat sx, CGFloat sy);
CG_EXTERN CGAffineTransform CGAffineTransformRotate(CGAffineTransform t, CGFloat angle);
CG_EXTERN CGAffineTransform CGAffineTransformInvert(CGAffineTransform t);
CG_EXTERN bool CGAffineTransformEqualToTransform(CGAffineTransform a, CGAffineTransform b);
__END_DECLS
