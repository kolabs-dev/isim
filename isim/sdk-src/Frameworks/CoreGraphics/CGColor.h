#pragma once
#include <CoreGraphics/CGBase.h>
#include <CoreGraphics/CGColorSpace.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
typedef struct CGColor *CGColorRef;         /* isim: components in their color space + the sRGB RGBA used for drawing */
typedef struct CGPattern *CGPatternRef;
CG_EXTERN const CFStringRef kCGColorWhite CG_SWIFT_NAME(CGColor.white);
CG_EXTERN const CFStringRef kCGColorBlack CG_SWIFT_NAME(CGColor.black);
CG_EXTERN const CFStringRef kCGColorClear CG_SWIFT_NAME(CGColor.clear);
CG_EXTERN CFTypeID CGColorGetTypeID(void);
CG_EXTERN CGColorRef _Nullable CGColorCreate(CGColorSpaceRef _Nullable space, const CGFloat *_Nullable components) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.init(colorSpace:components:));
CG_EXTERN CGColorRef CGColorCreateSRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.init(srgbRed:green:blue:alpha:));
CG_EXTERN CGColorRef CGColorCreateGenericRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.init(red:green:blue:alpha:));
CG_EXTERN CGColorRef CGColorCreateGenericGray(CGFloat gray, CGFloat a) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.init(gray:alpha:));
CG_EXTERN CGColorRef CGColorCreateGenericGrayGamma2_2(CGFloat gray, CGFloat a) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.init(genericGrayGamma2_2Gray:alpha:));
CG_EXTERN CGColorRef _Nullable CGColorCreateWithPattern(CGColorSpaceRef _Nullable space, CGPatternRef _Nullable pattern, const CGFloat *_Nullable components) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.init(patternSpace:pattern:components:));
CG_EXTERN CGColorRef _Nullable CGColorGetConstantColor(CFStringRef _Nullable name) CG_SWIFT_NAME(CGColor.init(constantColor:));
CG_EXTERN CGColorRef _Nullable CGColorRetain(CGColorRef _Nullable c);
CG_EXTERN void CGColorRelease(CGColorRef _Nullable c);
CG_EXTERN const CGFloat *_Nullable CGColorGetComponents(CGColorRef _Nullable c);
CG_EXTERN CGFloat CGColorGetAlpha(CGColorRef _Nullable c) CG_SWIFT_NAME(getter:CGColor.alpha(self:));
CG_EXTERN size_t CGColorGetNumberOfComponents(CGColorRef _Nullable c) CG_SWIFT_NAME(getter:CGColor.numberOfComponents(self:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorGetColorSpace(CGColorRef _Nullable c) CG_SWIFT_NAME(getter:CGColor.colorSpace(self:));
CG_EXTERN CGPatternRef _Nullable CGColorGetPattern(CGColorRef _Nullable c) CG_SWIFT_NAME(getter:CGColor.pattern(self:));
CG_EXTERN bool CGColorEqualToColor(CGColorRef _Nullable a, CGColorRef _Nullable b);
CG_EXTERN CGColorRef _Nullable CGColorCreateCopy(CGColorRef _Nullable c) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.copy(self:));
CG_EXTERN CGColorRef _Nullable CGColorCreateCopyWithAlpha(CGColorRef _Nullable c, CGFloat alpha) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.copy(self:alpha:));
CG_EXTERN CGColorRef _Nullable CGColorCreateCopyByMatchingToColorSpace(CGColorSpaceRef _Nullable space, CGColorRenderingIntent intent, CGColorRef _Nullable color, CFDictionaryRef _Nullable options)
    CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColor.converted(to:intent:self:options:));
/* isim-private: the color as sRGB RGBA (what is drawn), whatever its color space */
CG_EXTERN void isim_cg_color_rgba(CGColorRef _Nullable c, double *_Nonnull rgba);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
