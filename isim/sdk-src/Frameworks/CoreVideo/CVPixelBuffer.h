#pragma once
#include <CoreVideo/CVImageBuffer.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef CVImageBufferRef CVPixelBufferRef;
enum {
    kCVPixelFormatType_24RGB = 0x00000018,
    kCVPixelFormatType_32ARGB = 0x00000020,
    kCVPixelFormatType_32BGRA = 'BGRA',
    kCVPixelFormatType_32RGBA = 'RGBA',
    kCVPixelFormatType_OneComponent8 = 'L008',
    kCVPixelFormatType_OneComponent16 = 'L016',
    kCVPixelFormatType_OneComponent16Half = 'L00h',
    kCVPixelFormatType_OneComponent32Float = 'L00f',
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange = '420v',
    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange = '420f',
    kCVPixelFormatType_DepthFloat16 = 'hdep',
    kCVPixelFormatType_DepthFloat32 = 'fdep',
    kCVPixelFormatType_DisparityFloat16 = 'hdis',
    kCVPixelFormatType_DisparityFloat32 = 'fdis',
    kCVPixelFormatType_14Bayer_GRBG = 'grb4',
    kCVPixelFormatType_14Bayer_RGGB = 'rgg4',
    kCVPixelFormatType_14Bayer_BGGR = 'bgg4',
    kCVPixelFormatType_14Bayer_GBRG = 'gbr4',
};
typedef CF_OPTIONS(CVOptionFlags, CVPixelBufferLockFlags) {
    kCVPixelBufferLock_ReadOnly = 0x00000001,
};
typedef void (*CVPixelBufferReleaseBytesCallback)(void *releaseRefCon, const void *baseAddress);
typedef void (*CVPixelBufferReleasePlanarBytesCallback)(void *releaseRefCon, const void *dataPtr, size_t dataSize,
                                                        size_t numberOfPlanes, const void *planeAddresses[]);
CV_EXPORT const CFStringRef kCVPixelBufferPixelFormatTypeKey;
CV_EXPORT const CFStringRef kCVPixelBufferWidthKey;
CV_EXPORT const CFStringRef kCVPixelBufferHeightKey;
CV_EXPORT const CFStringRef kCVPixelBufferBytesPerRowAlignmentKey;
CV_EXPORT const CFStringRef kCVPixelBufferCGImageCompatibilityKey;
CV_EXPORT const CFStringRef kCVPixelBufferCGBitmapContextCompatibilityKey;
CV_EXPORT const CFStringRef kCVPixelBufferIOSurfacePropertiesKey;
CV_EXPORT const CFStringRef kCVPixelBufferMetalCompatibilityKey;
CV_EXPORT CFTypeID CVPixelBufferGetTypeID(void);
CV_EXPORT CVPixelBufferRef CVPixelBufferRetain(CVPixelBufferRef texture);
CV_EXPORT void CVPixelBufferRelease(CVPixelBufferRef texture);
CV_EXPORT CVReturn CVPixelBufferCreate(CFAllocatorRef allocator, size_t width, size_t height, OSType pixelFormatType,
                                       CFDictionaryRef pixelBufferAttributes, CVPixelBufferRef *pixelBufferOut);
CV_EXPORT CVReturn CVPixelBufferCreateWithBytes(CFAllocatorRef allocator, size_t width, size_t height, OSType pixelFormatType,
                                                void *baseAddress, size_t bytesPerRow, CVPixelBufferReleaseBytesCallback releaseCallback,
                                                void *releaseRefCon, CFDictionaryRef pixelBufferAttributes, CVPixelBufferRef *pixelBufferOut);
CV_EXPORT CVReturn CVPixelBufferCreateWithPlanarBytes(CFAllocatorRef allocator, size_t width, size_t height, OSType pixelFormatType,
                                                      void *dataPtr, size_t dataSize, size_t numberOfPlanes, void *planeBaseAddress[],
                                                      size_t planeWidth[], size_t planeHeight[], size_t planeBytesPerRow[],
                                                      CVPixelBufferReleasePlanarBytesCallback releaseCallback, void *releaseRefCon,
                                                      CFDictionaryRef pixelBufferAttributes, CVPixelBufferRef *pixelBufferOut);
CV_EXPORT CVReturn CVPixelBufferLockBaseAddress(CVPixelBufferRef pixelBuffer, CVPixelBufferLockFlags lockFlags);
CV_EXPORT CVReturn CVPixelBufferUnlockBaseAddress(CVPixelBufferRef pixelBuffer, CVPixelBufferLockFlags unlockFlags);
CV_EXPORT size_t CVPixelBufferGetWidth(CVPixelBufferRef pixelBuffer);
CV_EXPORT size_t CVPixelBufferGetHeight(CVPixelBufferRef pixelBuffer);
CV_EXPORT OSType CVPixelBufferGetPixelFormatType(CVPixelBufferRef pixelBuffer);
CV_EXPORT void *CVPixelBufferGetBaseAddress(CVPixelBufferRef pixelBuffer);
CV_EXPORT size_t CVPixelBufferGetBytesPerRow(CVPixelBufferRef pixelBuffer);
CV_EXPORT size_t CVPixelBufferGetDataSize(CVPixelBufferRef pixelBuffer);
CV_EXPORT Boolean CVPixelBufferIsPlanar(CVPixelBufferRef pixelBuffer);
CV_EXPORT size_t CVPixelBufferGetPlaneCount(CVPixelBufferRef pixelBuffer);
CV_EXPORT size_t CVPixelBufferGetWidthOfPlane(CVPixelBufferRef pixelBuffer, size_t planeIndex);
CV_EXPORT size_t CVPixelBufferGetHeightOfPlane(CVPixelBufferRef pixelBuffer, size_t planeIndex);
CV_EXPORT void *CVPixelBufferGetBaseAddressOfPlane(CVPixelBufferRef pixelBuffer, size_t planeIndex);
CV_EXPORT size_t CVPixelBufferGetBytesPerRowOfPlane(CVPixelBufferRef pixelBuffer, size_t planeIndex);
__END_DECLS
#endif
