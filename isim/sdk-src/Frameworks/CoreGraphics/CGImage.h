#pragma once
#include <CoreGraphics/CGGeometry.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: a decoded image held by the host (plus a pixel crop); reference counted */
typedef struct __attribute__((objc_bridge(id))) CGImage *CGImageRef;
typedef CF_ENUM(int32_t, CGInterpolationQuality) {
    kCGInterpolationDefault = 0, kCGInterpolationNone = 1, kCGInterpolationLow = 2, kCGInterpolationMedium = 4, kCGInterpolationHigh = 3
};
CG_EXTERN size_t CGImageGetWidth(CGImageRef _Nullable image);
CG_EXTERN size_t CGImageGetHeight(CGImageRef _Nullable image);
CG_EXTERN CGImageRef _Nullable CGImageCreateWithImageInRect(CGImageRef _Nullable image, CGRect rect);
CG_EXTERN CGImageRef _Nullable CGImageRetain(CGImageRef _Nullable image);
CG_EXTERN void CGImageRelease(CGImageRef _Nullable image);
/* isim-private: the host image behind a CGImage and its pixel rectangle */
CG_EXTERN int isim_cg_image_handle(CGImageRef _Nullable image, CGRect * _Nullable pixelRect);
CG_EXTERN CGImageRef _Nullable isim_cg_image_create(int handle, CGRect pixelRect, void * _Nullable owner) __attribute__((cf_returns_retained));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
