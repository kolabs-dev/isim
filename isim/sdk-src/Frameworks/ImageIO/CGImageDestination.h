#pragma once
#include <ImageIO/CGImageSource.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: PNG and JPEG (one image) and GIF (any number of frames, palette of up to 255 colors or a color cube) */
typedef struct __attribute__((objc_bridge(id))) CGImageDestination *CGImageDestinationRef;
IMAGEIO_EXTERN const CFStringRef kCGImageDestinationLossyCompressionQuality;
IMAGEIO_EXTERN const CFStringRef kCGImageDestinationBackgroundColor;
IMAGEIO_EXTERN CFTypeID CGImageDestinationGetTypeID(void);
IMAGEIO_EXTERN CFArrayRef CGImageDestinationCopyTypeIdentifiers(void) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageDestinationRef _Nullable CGImageDestinationCreateWithData(CFMutableDataRef data, CFStringRef type, size_t count, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageDestinationRef _Nullable CGImageDestinationCreateWithURL(CFURLRef url, CFStringRef type, size_t count, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageDestinationRef _Nullable CGImageDestinationCreateWithDataConsumer(CGDataConsumerRef consumer, CFStringRef type, size_t count, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN void CGImageDestinationSetProperties(CGImageDestinationRef idst, CFDictionaryRef _Nullable properties);
IMAGEIO_EXTERN void CGImageDestinationAddImage(CGImageDestinationRef idst, CGImageRef image, CFDictionaryRef _Nullable properties);
IMAGEIO_EXTERN void CGImageDestinationAddImageFromSource(CGImageDestinationRef idst, CGImageSourceRef isrc, size_t index, CFDictionaryRef _Nullable properties);
IMAGEIO_EXTERN bool CGImageDestinationFinalize(CGImageDestinationRef idst);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
