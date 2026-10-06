#pragma once
#include <CoreGraphics/CGContext.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: 8 bits per component bitmaps (RGB with premultiplied alpha or skipped alpha in either byte order, 8-bit
 * gray, alpha only). The app's memory is the bitmap: drawing writes it, and bytes the app writes are drawn on. */
typedef void (*CGBitmapContextReleaseDataCallback)(void *_Nullable releaseInfo, void *_Nullable data);
CG_EXTERN CGContextRef _Nullable CGBitmapContextCreate(void *_Nullable data, size_t width, size_t height, size_t bitsPerComponent,
    size_t bytesPerRow, CGColorSpaceRef _Nullable space, uint32_t bitmapInfo) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGContext.init(data:width:height:bitsPerComponent:bytesPerRow:space:bitmapInfo:));
CG_EXTERN CGContextRef _Nullable CGBitmapContextCreateWithData(void *_Nullable data, size_t width, size_t height, size_t bitsPerComponent,
    size_t bytesPerRow, CGColorSpaceRef _Nullable space, uint32_t bitmapInfo, CGBitmapContextReleaseDataCallback _Nullable releaseCallback,
    void *_Nullable releaseInfo) CF_RETURNS_RETAINED
    CG_SWIFT_NAME(CGContext.init(data:width:height:bitsPerComponent:bytesPerRow:space:bitmapInfo:releaseCallback:releaseInfo:));
CG_EXTERN void *_Nullable CGBitmapContextGetData(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.data(self:));
CG_EXTERN size_t CGBitmapContextGetWidth(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.width(self:));
CG_EXTERN size_t CGBitmapContextGetHeight(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.height(self:));
CG_EXTERN size_t CGBitmapContextGetBitsPerComponent(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.bitsPerComponent(self:));
CG_EXTERN size_t CGBitmapContextGetBitsPerPixel(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.bitsPerPixel(self:));
CG_EXTERN size_t CGBitmapContextGetBytesPerRow(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.bytesPerRow(self:));
CG_EXTERN CGColorSpaceRef _Nullable CGBitmapContextGetColorSpace(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.colorSpace(self:));
CG_EXTERN CGImageAlphaInfo CGBitmapContextGetAlphaInfo(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.alphaInfo(self:));
CG_EXTERN CGBitmapInfo CGBitmapContextGetBitmapInfo(CGContextRef _Nullable context) CG_SWIFT_NAME(getter:CGContext.bitmapInfo(self:));
CG_EXTERN CGImageRef _Nullable CGBitmapContextCreateImage(CGContextRef _Nullable context) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGContext.makeImage(self:));
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
