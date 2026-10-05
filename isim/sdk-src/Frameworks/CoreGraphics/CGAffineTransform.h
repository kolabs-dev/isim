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
__END_DECLS
