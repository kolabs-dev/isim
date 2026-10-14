#pragma once
#include <CoreVideo/CVPixelBuffer.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef struct CV_BRIDGED_TYPE(id) __CVPixelBufferPool *CVPixelBufferPoolRef;
typedef CF_OPTIONS(CVOptionFlags, CVPixelBufferPoolFlushFlags) {
    kCVPixelBufferPoolFlushExcessBuffers = 1,
};
CV_EXPORT const CFStringRef kCVPixelBufferPoolMinimumBufferCountKey;
CV_EXPORT const CFStringRef kCVPixelBufferPoolMaximumBufferAgeKey;
CV_EXPORT CFTypeID CVPixelBufferPoolGetTypeID(void);
CV_EXPORT CVPixelBufferPoolRef CVPixelBufferPoolRetain(CVPixelBufferPoolRef pixelBufferPool);
CV_EXPORT void CVPixelBufferPoolRelease(CVPixelBufferPoolRef pixelBufferPool);
CV_EXPORT CVReturn CVPixelBufferPoolCreate(CFAllocatorRef allocator, CFDictionaryRef poolAttributes, CFDictionaryRef pixelBufferAttributes,
                                           CVPixelBufferPoolRef *poolOut);
CV_EXPORT CFDictionaryRef CVPixelBufferPoolGetAttributes(CVPixelBufferPoolRef pool);
CV_EXPORT CFDictionaryRef CVPixelBufferPoolGetPixelBufferAttributes(CVPixelBufferPoolRef pool);
CV_EXPORT CVReturn CVPixelBufferPoolCreatePixelBuffer(CFAllocatorRef allocator, CVPixelBufferPoolRef pixelBufferPool,
                                                      CVPixelBufferRef *pixelBufferOut);
CV_EXPORT void CVPixelBufferPoolFlush(CVPixelBufferPoolRef pool, CVPixelBufferPoolFlushFlags options);
__END_DECLS
#endif
