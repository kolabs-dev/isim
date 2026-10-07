#pragma once
#include <CoreGraphics/CGBase.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGAffineTransform.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
typedef struct CGGradient *CGGradientRef;
typedef struct CGFunction *CGFunctionRef;
typedef struct CGShading *CGShadingRef;
typedef struct __attribute__((objc_bridge(id))) CGContext *CGContextRef;
typedef CF_OPTIONS(uint32_t, CGGradientDrawingOptions) { kCGGradientDrawsBeforeStartLocation = (1 << 0), kCGGradientDrawsAfterEndLocation = (1 << 1) };
/* gradients: colors are converted to sRGB; interpolation is linear in sRGB */
CG_EXTERN CFTypeID CGGradientGetTypeID(void);
CG_EXTERN CGGradientRef _Nullable CGGradientCreateWithColorComponents(CGColorSpaceRef _Nullable space, const CGFloat *_Nullable components,
    const CGFloat *_Nullable locations, size_t count) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGGradient.init(colorSpace:colorComponents:locations:count:));
CG_EXTERN CGGradientRef _Nullable CGGradientCreateWithColors(CGColorSpaceRef _Nullable space, CFArrayRef _Nullable colors,
    const CGFloat *_Nullable locations) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGGradient.init(colorsSpace:colors:locations:));
CG_EXTERN CGGradientRef _Nullable CGGradientRetain(CGGradientRef _Nullable gradient);
CG_EXTERN void CGGradientRelease(CGGradientRef _Nullable gradient);

/* functions (shadings, pattern-free gradients defined by a callback) */
typedef void (*CGFunctionEvaluateCallback)(void *_Nullable info, const CGFloat *in, CGFloat *out);
typedef void (*CGFunctionReleaseInfoCallback)(void *_Nullable info);
typedef struct CGFunctionCallbacks { unsigned int version; CGFunctionEvaluateCallback _Nullable evaluate; CGFunctionReleaseInfoCallback _Nullable releaseInfo; } CGFunctionCallbacks;
CG_EXTERN CFTypeID CGFunctionGetTypeID(void);
CG_EXTERN CGFunctionRef _Nullable CGFunctionCreate(void *_Nullable info, size_t domainDimension, const CGFloat *_Nullable domain,
    size_t rangeDimension, const CGFloat *_Nullable range, const CGFunctionCallbacks *_Nullable callbacks) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGFunction.init(info:domainDimension:domain:rangeDimension:range:callbacks:));
CG_EXTERN CGFunctionRef _Nullable CGFunctionRetain(CGFunctionRef _Nullable function);
CG_EXTERN void CGFunctionRelease(CGFunctionRef _Nullable function);

/* shadings: the function is sampled (64 steps) into a gradient */
CG_EXTERN CFTypeID CGShadingGetTypeID(void);
CG_EXTERN CGShadingRef _Nullable CGShadingCreateAxial(CGColorSpaceRef _Nullable space, CGPoint start, CGPoint end, CGFunctionRef _Nullable function,
    bool extendStart, bool extendEnd) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGShading.init(axialSpace:start:end:function:extendStart:extendEnd:));
CG_EXTERN CGShadingRef _Nullable CGShadingCreateRadial(CGColorSpaceRef _Nullable space, CGPoint start, CGFloat startRadius, CGPoint end, CGFloat endRadius,
    CGFunctionRef _Nullable function, bool extendStart, bool extendEnd) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGShading.init(radialSpace:start:startRadius:end:endRadius:function:extendStart:extendEnd:));
CG_EXTERN CGShadingRef _Nullable CGShadingRetain(CGShadingRef _Nullable shading);
CG_EXTERN void CGShadingRelease(CGShadingRef _Nullable shading);

/* patterns: the cell is drawn once into a bitmap and tiled */
typedef CF_ENUM(int32_t, CGPatternTiling) { kCGPatternTilingNoDistortion, kCGPatternTilingConstantSpacingMinimalDistortion, kCGPatternTilingConstantSpacing };
typedef void (*CGPatternDrawPatternCallback)(void *_Nullable info, CGContextRef context);
typedef void (*CGPatternReleaseInfoCallback)(void *_Nullable info);
typedef struct CGPatternCallbacks { unsigned int version; CGPatternDrawPatternCallback _Nullable drawPattern; CGPatternReleaseInfoCallback _Nullable releaseInfo; } CGPatternCallbacks;
CG_EXTERN CFTypeID CGPatternGetTypeID(void);
CG_EXTERN CGPatternRef _Nullable CGPatternCreate(void *_Nullable info, CGRect bounds, CGAffineTransform matrix, CGFloat xStep, CGFloat yStep,
    CGPatternTiling tiling, bool isColored, const CGPatternCallbacks *_Nullable callbacks) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGPattern.init(info:bounds:matrix:xStep:yStep:tiling:isColored:callbacks:));
CG_EXTERN CGPatternRef _Nullable CGPatternRetain(CGPatternRef _Nullable pattern);
CG_EXTERN void CGPatternRelease(CGPatternRef _Nullable pattern);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
