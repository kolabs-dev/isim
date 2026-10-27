#pragma once
#include <CoreGraphics/CGBase.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: color spaces are descriptions; colors in them are converted to sRGB for drawing (Display P3, linear, ICC
 * matrix / TRC and Lab spaces convert exactly, values outside sRGB are clamped). ICC profiles are read by isim itself:
 * RGB profiles with primaries and tone curves convert exactly; other profiles keep their model and draw as their
 * device space would. */
typedef struct __attribute__((objc_bridge(id))) CGColorSpace *CGColorSpaceRef;
typedef CF_ENUM(int32_t, CGColorSpaceModel) {
    kCGColorSpaceModelUnknown = -1, kCGColorSpaceModelMonochrome, kCGColorSpaceModelRGB, kCGColorSpaceModelCMYK,
    kCGColorSpaceModelLab, kCGColorSpaceModelDeviceN, kCGColorSpaceModelIndexed, kCGColorSpaceModelPattern, kCGColorSpaceModelXYZ
};
typedef CF_ENUM(int32_t, CGColorRenderingIntent) {
    kCGRenderingIntentDefault CG_SWIFT_NAME(defaultIntent), kCGRenderingIntentAbsoluteColorimetric CG_SWIFT_NAME(absoluteColorimetric),
    kCGRenderingIntentRelativeColorimetric CG_SWIFT_NAME(relativeColorimetric), kCGRenderingIntentPerceptual CG_SWIFT_NAME(perceptual),
    kCGRenderingIntentSaturation CG_SWIFT_NAME(saturation)
};
CG_EXTERN const CFStringRef kCGColorSpaceSRGB CG_SWIFT_NAME(CGColorSpace.sRGB);
CG_EXTERN const CFStringRef kCGColorSpaceDisplayP3 CG_SWIFT_NAME(CGColorSpace.displayP3);
CG_EXTERN const CFStringRef kCGColorSpaceLinearSRGB CG_SWIFT_NAME(CGColorSpace.linearSRGB);
CG_EXTERN const CFStringRef kCGColorSpaceExtendedSRGB CG_SWIFT_NAME(CGColorSpace.extendedSRGB);
CG_EXTERN const CFStringRef kCGColorSpaceExtendedLinearSRGB CG_SWIFT_NAME(CGColorSpace.extendedLinearSRGB);
CG_EXTERN const CFStringRef kCGColorSpaceGenericRGBLinear CG_SWIFT_NAME(CGColorSpace.genericRGBLinear);
CG_EXTERN const CFStringRef kCGColorSpaceGenericGrayGamma2_2 CG_SWIFT_NAME(CGColorSpace.genericGrayGamma2_2);
CG_EXTERN const CFStringRef kCGColorSpaceLinearGray CG_SWIFT_NAME(CGColorSpace.linearGray);
CG_EXTERN const CFStringRef kCGColorSpaceExtendedGray CG_SWIFT_NAME(CGColorSpace.extendedGray);
CG_EXTERN const CFStringRef kCGColorSpaceGenericCMYK CG_SWIFT_NAME(CGColorSpace.genericCMYK);
CG_EXTERN const CFStringRef kCGColorSpaceITUR_709 CG_SWIFT_NAME(CGColorSpace.itur_709);
CG_EXTERN const CFStringRef kCGColorSpaceExtendedDisplayP3 CG_SWIFT_NAME(CGColorSpace.extendedDisplayP3);
CG_EXTERN const CFStringRef kCGColorSpaceLinearDisplayP3 CG_SWIFT_NAME(CGColorSpace.linearDisplayP3);
CG_EXTERN const CFStringRef kCGColorSpaceGenericLab CG_SWIFT_NAME(CGColorSpace.genericLab);
CG_EXTERN const CFStringRef kCGColorSpaceExtendedRange;
CG_EXTERN CFTypeID CGColorSpaceGetTypeID(void);
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void) CF_RETURNS_RETAINED;
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceGray(void) CF_RETURNS_RETAINED;
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateDeviceCMYK(void) CF_RETURNS_RETAINED;
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateWithName(CFStringRef _Nullable name) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpace.init(name:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreatePattern(CGColorSpaceRef _Nullable baseSpace) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpace.init(patternBaseSpace:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceRetain(CGColorSpaceRef _Nullable space);
CG_EXTERN void CGColorSpaceRelease(CGColorSpaceRef _Nullable space);
CG_EXTERN CGColorSpaceModel CGColorSpaceGetModel(CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(getter:CGColorSpace.model(self:));
CG_EXTERN size_t CGColorSpaceGetNumberOfComponents(CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(getter:CGColorSpace.numberOfComponents(self:));
CG_EXTERN CFStringRef _Nullable CGColorSpaceCopyName(CGColorSpaceRef space) CG_SWIFT_NAME(getter:CGColorSpace.name(self:));
CG_EXTERN CFStringRef _Nullable CGColorSpaceGetName(CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(CGColorSpaceGetName(_:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceGetBaseColorSpace(CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(getter:CGColorSpace.baseColorSpace(self:));
CG_EXTERN bool CGColorSpaceIsWideGamutRGB(CGColorSpaceRef space) CG_SWIFT_NAME(getter:CGColorSpace.isWideGamutRGB(self:));
CG_EXTERN bool CGColorSpaceSupportsOutput(CGColorSpaceRef space) CG_SWIFT_NAME(getter:CGColorSpace.supportsOutput(self:));
CG_EXTERN bool CGColorSpaceUsesExtendedRange(CGColorSpaceRef space) CG_SWIFT_NAME(CGColorSpaceUsesExtendedRange(_:));
/* data: a CFData or a CGDataProvider holding an ICC profile */
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateWithICCData(CFTypeRef _Nullable data) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpace.init(iccData:));
CG_EXTERN CFDataRef _Nullable CGColorSpaceCopyICCData(CGColorSpaceRef _Nullable space) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpace.copyICCData(self:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateLab(const CGFloat *_Nonnull whitePoint, const CGFloat *_Nullable blackPoint,
                                                          const CGFloat *_Nullable range) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGColorSpace.init(labWhitePoint:blackPoint:range:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateIndexed(CGColorSpaceRef _Nullable baseSpace, size_t lastIndex,
                                                              const unsigned char *_Nullable colorTable) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGColorSpace.init(indexedBaseSpace:last:colorTable:));
CG_EXTERN size_t CGColorSpaceGetColorTableCount(CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(getter:CGColorSpace.__colorTableCount(self:));
CG_EXTERN void CGColorSpaceGetColorTable(CGColorSpaceRef _Nullable space, uint8_t *_Nullable table) CG_SWIFT_NAME(CGColorSpace.__unsafeGetColorTable(self:_:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateExtended(CGColorSpaceRef space) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpaceCreateExtended(_:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateLinearized(CGColorSpaceRef space) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpaceCreateLinearized(_:));
CG_EXTERN CGColorSpaceRef _Nullable CGColorSpaceCreateExtendedLinearized(CGColorSpaceRef space) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGColorSpaceCreateExtendedLinearized(_:));
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateCopyWithStandardRange(CGColorSpaceRef s) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpaceCreateCopyWithStandardRange(_:));
CG_EXTERN CGColorSpaceRef CGColorSpaceCopyBaseColorSpace(CGColorSpaceRef space) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGColorSpaceCopyBaseColorSpace(_:));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
