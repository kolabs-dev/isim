#pragma once
#include <ImageIO/CGImageProperties.h>
#include <CoreGraphics/CoreGraphics.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
typedef struct __attribute__((objc_bridge(id))) CGImageSource *CGImageSourceRef;
typedef CF_ENUM(int32_t, CGImageSourceStatus) {
    kCGImageStatusUnexpectedEOF = -5, kCGImageStatusInvalidData = -4, kCGImageStatusUnknownType = -3,
    kCGImageStatusReadingHeader = -2, kCGImageStatusIncomplete = -1, kCGImageStatusComplete = 0
};
IMAGEIO_EXTERN const CFStringRef kCGImageSourceTypeIdentifierHint;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceShouldCache;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceShouldCacheImmediately;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceShouldAllowFloat;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceCreateThumbnailFromImageIfAbsent;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceCreateThumbnailFromImageAlways;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceThumbnailMaxPixelSize;
IMAGEIO_EXTERN const CFStringRef kCGImageSourceCreateThumbnailWithTransform;
IMAGEIO_EXTERN CFTypeID CGImageSourceGetTypeID(void);
IMAGEIO_EXTERN CFArrayRef CGImageSourceCopyTypeIdentifiers(void) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageSourceRef _Nullable CGImageSourceCreateWithData(CFDataRef data, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageSourceRef _Nullable CGImageSourceCreateWithURL(CFURLRef url, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageSourceRef _Nullable CGImageSourceCreateWithDataProvider(CGDataProviderRef provider, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageSourceRef CGImageSourceCreateIncremental(CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN void CGImageSourceUpdateData(CGImageSourceRef isrc, CFDataRef data, bool final);
IMAGEIO_EXTERN CFStringRef _Nullable CGImageSourceGetType(CGImageSourceRef isrc);
IMAGEIO_EXTERN size_t CGImageSourceGetCount(CGImageSourceRef isrc);
IMAGEIO_EXTERN CFDictionaryRef _Nullable CGImageSourceCopyProperties(CGImageSourceRef isrc, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFDictionaryRef _Nullable CGImageSourceCopyPropertiesAtIndex(CGImageSourceRef isrc, size_t index, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageRef _Nullable CGImageSourceCreateImageAtIndex(CGImageSourceRef isrc, size_t index, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageRef _Nullable CGImageSourceCreateThumbnailAtIndex(CGImageSourceRef isrc, size_t index, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageSourceStatus CGImageSourceGetStatus(CGImageSourceRef isrc);
IMAGEIO_EXTERN CGImageSourceStatus CGImageSourceGetStatusAtIndex(CGImageSourceRef isrc, size_t index);
IMAGEIO_EXTERN size_t CGImageSourceGetPrimaryImageIndex(CGImageSourceRef isrc);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
