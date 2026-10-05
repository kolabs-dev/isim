#pragma once
#include <CoreGraphics/CGBase.h>
__BEGIN_DECLS
typedef struct CGColor *CGColorRef;         /* isim: an RGBA color object */
CG_EXTERN CGColorRef CGColorCreateSRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN CGColorRef CGColorRetain(CGColorRef c);
CG_EXTERN void CGColorRelease(CGColorRef c);
CG_EXTERN const CGFloat *CGColorGetComponents(CGColorRef c);
CG_EXTERN CGFloat CGColorGetAlpha(CGColorRef c);
CG_EXTERN CGColorRef CGColorCreateGenericRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN CGColorRef CGColorCreateGenericGray(CGFloat gray, CGFloat a);
CG_EXTERN size_t CGColorGetNumberOfComponents(CGColorRef c);
CG_EXTERN bool CGColorEqualToColor(CGColorRef a, CGColorRef b);
CG_EXTERN CGColorRef CGColorCreateCopyWithAlpha(CGColorRef c, CGFloat alpha);
__END_DECLS
