#pragma once
#include <CoreGraphics/CGBase.h>
__BEGIN_DECLS
typedef struct CGColor *CGColorRef;         /* isim: an RGBA color object */
CG_EXTERN CGColorRef CGColorCreateSRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN CGColorRef CGColorRetain(CGColorRef c);
CG_EXTERN void CGColorRelease(CGColorRef c);
CG_EXTERN const CGFloat *CGColorGetComponents(CGColorRef c);
CG_EXTERN CGFloat CGColorGetAlpha(CGColorRef c);
__END_DECLS
