#pragma once
#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGColorSpace.h>
#include <CoreGraphics/CGDataProvider.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: a decoded image held by the host (plus a pixel crop) and, for images made from bytes, their layout; reference counted */
typedef struct __attribute__((objc_bridge(id))) CGImage *CGImageRef;
typedef CF_ENUM(int32_t, CGInterpolationQuality) {
    kCGInterpolationDefault = 0, kCGInterpolationNone = 1, kCGInterpolationLow = 2, kCGInterpolationMedium = 4, kCGInterpolationHigh = 3
};
typedef CF_ENUM(uint32_t, CGImageAlphaInfo) {
    kCGImageAlphaNone, kCGImageAlphaPremultipliedLast, kCGImageAlphaPremultipliedFirst, kCGImageAlphaLast, kCGImageAlphaFirst,
    kCGImageAlphaNoneSkipLast, kCGImageAlphaNoneSkipFirst, kCGImageAlphaOnly
};
typedef CF_ENUM(uint32_t, CGImageByteOrderInfo) {
    kCGImageByteOrderMask = 0x7000, kCGImageByteOrderDefault = (0 << 12), kCGImageByteOrder16Little = (1 << 12),
    kCGImageByteOrder32Little = (2 << 12), kCGImageByteOrder16Big = (3 << 12), kCGImageByteOrder32Big = (4 << 12)
};
typedef CF_ENUM(uint32_t, CGImagePixelFormatInfo) {
    kCGImagePixelFormatMask = 0xF0000, kCGImagePixelFormatPacked = (0 << 16), kCGImagePixelFormatRGB555 = (1 << 16),
    kCGImagePixelFormatRGB565 = (2 << 16), kCGImagePixelFormatRGB101010 = (3 << 16), kCGImagePixelFormatRGBCIF10 = (4 << 16)
};
typedef CF_OPTIONS(uint32_t, CGBitmapInfo) {
    kCGBitmapAlphaInfoMask = 0x1F, kCGBitmapFloatInfoMask = 0xF00, kCGBitmapFloatComponents = (1 << 8),
    kCGBitmapByteOrderMask = kCGImageByteOrderMask, kCGBitmapByteOrderDefault = kCGImageByteOrderDefault,
    kCGBitmapByteOrder16Little = kCGImageByteOrder16Little, kCGBitmapByteOrder32Little = kCGImageByteOrder32Little,
    kCGBitmapByteOrder16Big = kCGImageByteOrder16Big, kCGBitmapByteOrder32Big = kCGImageByteOrder32Big
};
#define kCGBitmapByteOrder16Host kCGBitmapByteOrder16Little
#define kCGBitmapByteOrder32Host kCGBitmapByteOrder32Little
CG_EXTERN CFTypeID CGImageGetTypeID(void);
CG_EXTERN size_t CGImageGetWidth(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.width(self:));
CG_EXTERN size_t CGImageGetHeight(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.height(self:));
/* 8 bits per component layouts are supported (RGB(A/X) in any order, gray, gray + alpha, alpha only, masks) */
CG_EXTERN CGImageRef _Nullable CGImageCreate(size_t width, size_t height, size_t bitsPerComponent, size_t bitsPerPixel, size_t bytesPerRow,
    CGColorSpaceRef _Nullable space, CGBitmapInfo bitmapInfo, CGDataProviderRef _Nullable provider, const CGFloat *_Nullable decode,
    bool shouldInterpolate, CGColorRenderingIntent intent) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGImage.init(width:height:bitsPerComponent:bitsPerPixel:bytesPerRow:space:bitmapInfo:provider:decode:shouldInterpolate:intent:));
CG_EXTERN CGImageRef _Nullable CGImageMaskCreate(size_t width, size_t height, size_t bitsPerComponent, size_t bitsPerPixel, size_t bytesPerRow,
    CGDataProviderRef _Nullable provider, const CGFloat *_Nullable decode, bool shouldInterpolate) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGImage.init(maskWidth:height:bitsPerComponent:bitsPerPixel:bytesPerRow:provider:decode:shouldInterpolate:));
CG_EXTERN CGImageRef _Nullable CGImageCreateWithPNGDataProvider(CGDataProviderRef _Nullable source, const CGFloat *_Nullable decode, bool shouldInterpolate,
    CGColorRenderingIntent intent) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGImage.init(pngDataProviderSource:decode:shouldInterpolate:intent:));
CG_EXTERN CGImageRef _Nullable CGImageCreateWithJPEGDataProvider(CGDataProviderRef _Nullable source, const CGFloat *_Nullable decode, bool shouldInterpolate,
    CGColorRenderingIntent intent) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGImage.init(jpegDataProviderSource:decode:shouldInterpolate:intent:));
CG_EXTERN CGImageRef _Nullable CGImageCreateCopy(CGImageRef _Nullable image) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGImage.copy(self:));
CG_EXTERN CGImageRef _Nullable CGImageCreateCopyWithColorSpace(CGImageRef _Nullable image, CGColorSpaceRef _Nullable space) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGImage.copy(self:colorSpace:));
CG_EXTERN CGImageRef _Nullable CGImageCreateWithImageInRect(CGImageRef _Nullable image, CGRect rect) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGImage.cropping(self:to:));
CG_EXTERN CGImageRef _Nullable CGImageCreateWithMask(CGImageRef _Nullable image, CGImageRef _Nullable mask) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGImage.masking(self:_:));
CG_EXTERN CGImageRef _Nullable CGImageRetain(CGImageRef _Nullable image);
CG_EXTERN void CGImageRelease(CGImageRef _Nullable image);
CG_EXTERN bool CGImageIsMask(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.isMask(self:));
CG_EXTERN size_t CGImageGetBitsPerComponent(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.bitsPerComponent(self:));
CG_EXTERN size_t CGImageGetBitsPerPixel(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.bitsPerPixel(self:));
CG_EXTERN size_t CGImageGetBytesPerRow(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.bytesPerRow(self:));
CG_EXTERN CGColorSpaceRef _Nullable CGImageGetColorSpace(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.colorSpace(self:));
CG_EXTERN CGImageAlphaInfo CGImageGetAlphaInfo(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.alphaInfo(self:));
CG_EXTERN CGBitmapInfo CGImageGetBitmapInfo(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.bitmapInfo(self:));
CG_EXTERN CGImageByteOrderInfo CGImageGetByteOrderInfo(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.byteOrderInfo(self:));
CG_EXTERN CGImagePixelFormatInfo CGImageGetPixelFormatInfo(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.pixelFormatInfo(self:));
/* decoded images report 8-bit premultiplied RGBA (byte order R, G, B, A); the provider's bytes are made on demand */
CG_EXTERN CGDataProviderRef _Nullable CGImageGetDataProvider(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.dataProvider(self:));
CG_EXTERN const CGFloat *_Nullable CGImageGetDecode(CGImageRef _Nullable image);
CG_EXTERN bool CGImageGetShouldInterpolate(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.shouldInterpolate(self:));
CG_EXTERN CGColorRenderingIntent CGImageGetRenderingIntent(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.renderingIntent(self:));
CG_EXTERN CFStringRef _Nullable CGImageGetUTType(CGImageRef _Nullable image) CG_SWIFT_NAME(getter:CGImage.utType(self:));
/* isim-private: the host image behind a CGImage and its pixel rectangle */
CG_EXTERN int isim_cg_image_handle(CGImageRef _Nullable image, CGRect * _Nullable pixelRect);
CG_EXTERN CGImageRef _Nullable isim_cg_image_create(int handle, CGRect pixelRect, void * _Nullable owner) __attribute__((cf_returns_retained));
/* isim-private: a CGImage that owns (frees) a new host image handle; UTType recorded by ImageIO */
CG_EXTERN CGImageRef _Nullable isim_cg_image_with_handle(int handle) __attribute__((cf_returns_retained));
CG_EXTERN void isim_cg_image_set_uttype(CGImageRef _Nullable image, CFStringRef _Nullable type);
/* isim-private: 8-bit premultiplied RGBA pixels of the image (malloc'd, w*4 bytes per row) */
CG_EXTERN unsigned char *_Nullable isim_cg_image_rgba(CGImageRef _Nullable image, size_t *_Nonnull w, size_t *_Nonnull h);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
