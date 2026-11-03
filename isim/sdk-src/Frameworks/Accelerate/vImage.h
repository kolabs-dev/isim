#pragma once
/* isim vImage (part of Accelerate.framework): Apple's image-processing library, implemented by isim in C
   (frameworks/Accelerate/vimage*.c). Every format's operations share one generic implementation over float samples
   (adapted); see docs/frameworks/Accelerate.md for what is and is not there. */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef VIMAGE_PF
#define VIMAGE_PF __attribute__((visibility("default")))
#endif

typedef unsigned long vImagePixelCount;
typedef struct vImage_Buffer {
    void *data;
    vImagePixelCount height;
    vImagePixelCount width;
    size_t rowBytes;
} vImage_Buffer;

typedef struct vImage_AffineTransform { float a, b, c, d; float tx, ty; } vImage_AffineTransform;
typedef struct vImage_AffineTransform_Double { double a, b, c, d; double tx, ty; } vImage_AffineTransform_Double;
typedef CGAffineTransform vImage_CGAffineTransform;
#define VIMAGE_AFFINETRANSFORM_DOUBLE_IS_AVAILABLE 1
#define VIMAGE_CGAFFINETRANSFORM_IS_AVAILABLE 1
/* (sic: Apple's spelling) */
typedef struct vImage_PerpsectiveTransform { float a, b, c, d; float tx, ty; float vx, vy, v; } vImage_PerpsectiveTransform;
typedef enum { kvImageInterpolationNearest = 0, kvImageInterpolationLinear = 1 } vImage_WarpInterpolation;

typedef ssize_t vImage_Error;
typedef uint32_t vImage_Flags;
typedef CGSize vImage_CGSize;

typedef uint8_t Pixel_8;
typedef float Pixel_F;
typedef uint8_t Pixel_8888[4];
typedef float Pixel_FFFF[4];
typedef uint16_t Pixel_16U;
typedef int16_t Pixel_16S;
typedef uint16_t Pixel_16F;
typedef int16_t Pixel_16Q12;
typedef uint16_t Pixel_ARGB_16U[4];
typedef int16_t Pixel_ARGB_16S[4];
typedef uint16_t Pixel_ARGB_16F[4];
typedef uint8_t Pixel_88[2];
typedef float Pixel_FF[2];
typedef uint16_t Pixel_16U16U[2];
typedef int16_t Pixel_16S16S[2];
typedef uint16_t Pixel_16F16F[2];
typedef void *ResamplingFilter;
typedef void *GammaFunction;

enum {
    kvImageNoFlags = 0,
    kvImageLeaveAlphaUnchanged = 1,
    kvImageCopyInPlace = 2,
    kvImageBackgroundColorFill = 4,
    kvImageEdgeExtend = 8,
    kvImageDoNotTile = 16,
    kvImageHighQualityResampling = 32,
    kvImageTruncateKernel = 64,
    kvImageGetTempBufferSize = 128,
    kvImagePrintDiagnosticsToConsole = 256,
    kvImageNoAllocate = 512,
    kvImageHDRContent = 1024,
    kvImageDoNotClamp = 2048,
    kvImageUseFP16Accumulator = 4096,
};

enum {
    kvImageNoError = 0,
    kvImageRoiLargerThanInputBuffer = -21766,
    kvImageInvalidKernelSize = -21767,
    kvImageInvalidEdgeStyle = -21768,
    kvImageInvalidOffset_X = -21769,
    kvImageInvalidOffset_Y = -21770,
    kvImageMemoryAllocationError = -21771,
    kvImageNullPointerArgument = -21772,
    kvImageInvalidParameter = -21773,
    kvImageBufferSizeMismatch = -21774,
    kvImageUnknownFlagsBit = -21775,
    kvImageInternalError = -21776,
    kvImageInvalidRowBytes = -21777,
    kvImageInvalidImageFormat = -21778,
    kvImageColorSyncIsAbsent = -21779,
    kvImageOutOfPlaceOperationRequired = -21780,
    kvImageInvalidImageObject = -21781,
    kvImageInvalidCVImageFormat = -21782,
    kvImageUnsupportedConversion = -21783,
    kvImageCoreVideoIsAbsent = -21784,
};

/* Rotate90's rotationConstant: the number of quarter turns counterclockwise */
enum {
    kRotate0DegreesClockwise = 0, kRotate90DegreesClockwise = 3, kRotate180DegreesClockwise = 2, kRotate270DegreesClockwise = 1,
    kRotate0DegreesCounterClockwise = 0, kRotate90DegreesCounterClockwise = 1, kRotate180DegreesCounterClockwise = 2,
    kRotate270DegreesCounterClockwise = 3,
};

/* vImageCreateGammaFunction's gamma types */
enum {
    kvImageGamma_UseGammaValue = 0, kvImageGamma_UseGammaValue_half_precision = 1, kvImageGamma_5_over_9_half_precision = 2,
    kvImageGamma_9_over_5_half_precision = 3, kvImageGamma_5_over_11_half_precision = 4, kvImageGamma_11_over_5_half_precision = 5,
    kvImageGamma_sRGB_forward_half_precision = 6, kvImageGamma_sRGB_reverse_half_precision = 7,
    kvImageGamma_11_over_9_half_precision = 8, kvImageGamma_9_over_11_half_precision = 9,
    kvImageGamma_BT709_forward_half_precision = 10, kvImageGamma_BT709_reverse_half_precision = 11,
};

/* Core Graphics interoperation */
typedef struct vImage_CGImageFormat {
    uint32_t bitsPerComponent;
    uint32_t bitsPerPixel;
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    uint32_t version;
    const CGFloat *decode;
    CGColorRenderingIntent renderingIntent;
} vImage_CGImageFormat;
typedef struct __attribute__((objc_bridge(id))) vImageConverter *vImageConverterRef;
typedef unsigned long vImageBufferTypeCode;
enum {
    kvImageBufferTypeCode_EndOfList = 0,
    kvImageBufferTypeCode_ColorSpaceChannel1 = 1, kvImageBufferTypeCode_ColorSpaceChannel2 = 2,
    kvImageBufferTypeCode_ColorSpaceChannel3 = 3, kvImageBufferTypeCode_ColorSpaceChannel4 = 4,
    kvImageBufferTypeCode_ColorSpaceChannel5 = 5, kvImageBufferTypeCode_ColorSpaceChannel6 = 6,
    kvImageBufferTypeCode_ColorSpaceChannel7 = 7, kvImageBufferTypeCode_ColorSpaceChannel8 = 8,
    kvImageBufferTypeCode_ColorSpaceChannel9 = 9, kvImageBufferTypeCode_ColorSpaceChannel10 = 10,
    kvImageBufferTypeCode_ColorSpaceChannel11 = 11, kvImageBufferTypeCode_ColorSpaceChannel12 = 12,
    kvImageBufferTypeCode_ColorSpaceChannel13 = 13, kvImageBufferTypeCode_ColorSpaceChannel14 = 14,
    kvImageBufferTypeCode_ColorSpaceChannel15 = 15, kvImageBufferTypeCode_ColorSpaceChannel16 = 16,
    kvImageBufferTypeCode_Alpha = 17,
    kvImageBufferTypeCode_Chunky = 18,
    kvImageBufferTypeCode_Indexed = 19,
    kvImageBufferTypeCode_Luminance = 20,
    kvImageBufferTypeCode_Chroma = 21,
    kvImageBufferTypeCode_Cb = 22,
    kvImageBufferTypeCode_Cr = 23,
    kvImageBufferTypeCode_CGFormat = 24,
    kvImageBufferTypeCode_UniqueFormatCount = 25,
    kvImageBufferTypeCode_RGB_Red = kvImageBufferTypeCode_ColorSpaceChannel1,
    kvImageBufferTypeCode_RGB_Green = kvImageBufferTypeCode_ColorSpaceChannel2,
    kvImageBufferTypeCode_RGB_Blue = kvImageBufferTypeCode_ColorSpaceChannel3,
    kvImageBufferTypeCode_CMYK_Cyan = kvImageBufferTypeCode_ColorSpaceChannel1,
    kvImageBufferTypeCode_CMYK_Magenta = kvImageBufferTypeCode_ColorSpaceChannel2,
    kvImageBufferTypeCode_CMYK_Yellow = kvImageBufferTypeCode_ColorSpaceChannel3,
    kvImageBufferTypeCode_CMYK_Black = kvImageBufferTypeCode_ColorSpaceChannel4,
    kvImageBufferTypeCode_LAB_L = kvImageBufferTypeCode_ColorSpaceChannel1,
    kvImageBufferTypeCode_LAB_A = kvImageBufferTypeCode_ColorSpaceChannel2,
    kvImageBufferTypeCode_LAB_B = kvImageBufferTypeCode_ColorSpaceChannel3,
    kvImageBufferTypeCode_XYZ_X = kvImageBufferTypeCode_ColorSpaceChannel1,
    kvImageBufferTypeCode_XYZ_Y = kvImageBufferTypeCode_ColorSpaceChannel2,
    kvImageBufferTypeCode_XYZ_Z = kvImageBufferTypeCode_ColorSpaceChannel3,
    kvImageBufferTypeCode_Monochrome = kvImageBufferTypeCode_ColorSpaceChannel1,
};
/* dithering (the _dithered conversions take one; isim rounds instead: adapted) */
enum {
    kvImageConvert_DitherNone = 0, kvImageConvert_DitherOrdered = 1, kvImageConvert_DitherOrderedReproducible = 2,
    kvImageConvert_DitherFloydSteinberg = 3, kvImageConvert_DitherAtkinson = 4,
    kvImageConvert_OrderedGaussianBlue = 0, kvImageConvert_OrderedUniformBlue = 0x10000000,
    kvImageConvert_OrderedNoiseShapeMask = 0x70000000,
};
/* the decode array of 16Q12 (fixed point, 4096 = 1.0) vImage_CGImageFormats */
extern VIMAGE_PF const CGFloat *kvImageDecodeArray_16Q12Format;

/* Y'CbCr */
typedef struct vImage_YpCbCrToARGBMatrix { float Yp, Cr_R, Cr_G, Cb_G, Cb_B; } vImage_YpCbCrToARGBMatrix;
typedef struct vImage_ARGBToYpCbCrMatrix { float R_Yp, G_Yp, B_Yp, R_Cb, G_Cb, B_Cb_R_Cr, G_Cr, B_Cr; } vImage_ARGBToYpCbCrMatrix;
typedef struct vImage_YpCbCrPixelRange {
    int32_t Yp_bias, CbCr_bias, YpRangeMax, CbCrRangeMax, YpMax, YpMin, CbCrMax, CbCrMin;
} vImage_YpCbCrPixelRange;
typedef struct vImage_YpCbCrToARGB { uint8_t opaque[128]; } vImage_YpCbCrToARGB;
typedef struct vImage_ARGBToYpCbCr { uint8_t opaque[128]; } vImage_ARGBToYpCbCr;
typedef enum {
    kvImage422CbYpCrYp8 = 0, kvImage422YpCbYpCr8 = 1, kvImage422CbYpCrYp8_AA8 = 2, kvImage420Yp8_Cb8_Cr8 = 3,
    kvImage420Yp8_CbCr8 = 4, kvImage444AYpCbCr8 = 5, kvImage444CrYpCb8 = 6, kvImage444CbYpCrA8 = 7,
    kvImage422CbYpCrYp16 = 8, kvImage444AYpCbCr16 = 9, kvImage444CrYpCb10 = 10, kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10 = 11,
} vImageYpCbCrType;
typedef enum {
    kvImageARGB8888 = 0, kvImageARGB16U = 1, kvImageARGB16Q12 = 2,
} vImageARGBType;
extern VIMAGE_PF const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_601_4;
extern VIMAGE_PF const vImage_YpCbCrToARGBMatrix *kvImage_YpCbCrToARGBMatrix_ITU_R_709_2;
extern VIMAGE_PF const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
extern VIMAGE_PF const vImage_ARGBToYpCbCrMatrix *kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2;


/* ---- functions (Apple's signatures; those isim implements) ---- */
VIMAGE_PF vImage_Error vImageAffineWarpCG_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_CGAffineTransform *, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpCG_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_CGAffineTransform *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpCG_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_CGAffineTransform *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpCG_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_CGAffineTransform *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpCG_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_CGAffineTransform *, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpCG_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_CGAffineTransform *, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarpD_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform_Double *, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageAffineWarp_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_AffineTransform *, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_NonpremultipliedToPremultiplied_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageAlphaBlend_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBoxConvolve_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, uint32_t, uint32_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBoxConvolve_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, uint32_t, uint32_t, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_ARGB16F(const vImage_Buffer *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_ARGB16S(const vImage_Buffer *, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_ARGB16U(const vImage_Buffer *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_ARGB8888(const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_ARGBFFFF(const vImage_Buffer *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_CbCr16S(const vImage_Buffer *, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_CbCr16U(const vImage_Buffer *, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBufferFill_CbCr8(const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageBuffer_Init(vImage_Buffer *, vImagePixelCount, vImagePixelCount, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageBuffer_InitWithCGImage(vImage_Buffer *, vImage_CGImageFormat *, const CGFloat *, CGImageRef, vImage_Flags);
VIMAGE_PF vImage_Error vImageByteSwap_Planar16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF uint32_t vImageCGImageFormat_GetComponentCount(const vImage_CGImageFormat *);
VIMAGE_PF bool vImageCGImageFormat_IsEqual(const vImage_CGImageFormat *, const vImage_CGImageFormat *);
VIMAGE_PF vImage_Error vImageClipToAlpha_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageClipToAlpha_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageClipToAlpha_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageClipToAlpha_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageClipToAlpha_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageClipToAlpha_RGBAFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageClip_PlanarF(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageContrastStretch_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageContrastStretch_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageContrastStretch_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageContrastStretch_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_12UTo16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Fto16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Fto16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Q12to16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Q12to16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Q12to8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Q12toF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16SToF(const vImage_Buffer *, const vImage_Buffer *, float, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16UTo12U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16UToF(const vImage_Buffer *, const vImage_Buffer *, float, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16UToPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Uto16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_16Uto16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_420Yp8_CbCr8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_422CbYpCrYp8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_422YpCbYpCr8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_444AYpCbCr8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_444CbYpCrA8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_444CrYpCb8ToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_YpCbCrToARGB *, const uint8_t *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_8to16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB1555toARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB1555toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB1555toRGB565(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UtoARGB8888_dithered(const vImage_Buffer *, const vImage_Buffer *, int32_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UtoPlanar16U(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To420Yp8_CbCr8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To422CbYpCrYp8(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To422YpCbYpCr8(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To444AYpCbCr8(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To444CbYpCrA8(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To444CrYpCb8(const vImage_Buffer *, const vImage_Buffer *, const vImage_ARGBToYpCbCr *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888ToARGB16U(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888ToRGB16U(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const Pixel_16U *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toARGB1555(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toARGB1555_dithered(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toPlanar16Q12(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toPlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toRGB565(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toRGB565_dithered(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888toRGB888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBFFFFtoARGB8888_dithered(const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, int32_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBFFFFtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBFFFFtoPlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBFFFFtoRGBFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBToYpCbCr_GenerateConversion(const vImage_ARGBToYpCbCrMatrix *, const vImage_YpCbCrPixelRange *, vImage_ARGBToYpCbCr *, vImageARGBType, vImageYpCbCrType, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_AnyToAny(vImageConverterRef, const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRA16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRA8888toRGB565(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRA8888toRGB565_dithered(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRA8888toRGB888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRAFFFFtoRGBFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRX8888ToPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_BGRXFFFFToPlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ChunkyToPlanar8(const void **, const vImage_Buffer **, unsigned int, size_t, vImagePixelCount, vImagePixelCount, size_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_ChunkyToPlanarF(const void **, const vImage_Buffer **, unsigned int, size_t, vImagePixelCount, vImagePixelCount, size_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_FTo16S(const vImage_Buffer *, const vImage_Buffer *, float, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_FTo16U(const vImage_Buffer *, const vImage_Buffer *, float, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Fto16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Indexed1toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Indexed2toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Indexed4toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16FtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16FtoPlanarF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16Q12toARGB16F(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16Q12toARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16Q12toRGB16F(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16Q12toRGB888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16UtoARGB16U(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16UtoPlanar8_dithered(const vImage_Buffer *, const vImage_Buffer *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar1toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar2toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar4toPlanar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8To16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8ToARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8ToBGRX8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, Pixel_8, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8ToBGRXFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, Pixel_F, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8ToXRGB8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8ToXRGBFFFF(Pixel_F, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toARGB1555(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toPlanar1(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toPlanar16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toPlanar2(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toPlanar4(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toPlanarF(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toRGB565(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toRGB888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFToBGRX8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, Pixel_8, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFToBGRXFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, Pixel_F, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFToXRGB8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFToXRGBFFFF(Pixel_F, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFtoARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFtoPlanar16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFtoPlanar8_dithered(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, Pixel_F, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarFtoRGBFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarToChunky8(const vImage_Buffer **, void **, unsigned int, size_t, vImagePixelCount, vImagePixelCount, size_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_PlanarToChunkyF(const vImage_Buffer **, void **, unsigned int, size_t, vImagePixelCount, vImagePixelCount, size_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB16UToARGB8888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB16UtoARGB16U(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB16UtoBGRA16U(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB16UtoPlanar16U(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB16UtoRGB888_dithered(const vImage_Buffer *, const vImage_Buffer *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB16UtoRGBA16U(const vImage_Buffer *, const vImage_Buffer *, Pixel_16U, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toARGB1555(const vImage_Buffer *, const vImage_Buffer *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toARGB8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toBGRA8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toRGB888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toRGBA5551(const vImage_Buffer *, const vImage_Buffer *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB565toRGBA8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB888toARGB8888(const vImage_Buffer *, const vImage_Buffer *, Pixel_8, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB888toBGRA8888(const vImage_Buffer *, const vImage_Buffer *, Pixel_8, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB888toPlanar16Q12(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB888toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB888toRGB565_dithered(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGB888toRGBA8888(const vImage_Buffer *, const vImage_Buffer *, Pixel_8, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA16UtoRGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA5551toRGB565(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA5551toRGBA8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA8888toRGB565(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA8888toRGB565_dithered(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA8888toRGB888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA8888toRGBA5551(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA8888toRGBA5551_dithered(const vImage_Buffer *, const vImage_Buffer *, void *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBAFFFFtoRGBFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBFFFtoARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBFFFtoBGRAFFFF(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBFFFtoPlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBFFFtoRGB888_dithered(const vImage_Buffer *, const vImage_Buffer *, const Pixel_F *, const Pixel_F *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_RGBFFFtoRGBAFFFF(const vImage_Buffer *, const vImage_Buffer *, Pixel_F, const vImage_Buffer *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_XRGB8888ToPlanar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_XRGBFFFFToPlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvert_YpCbCrToARGB_GenerateConversion(const vImage_YpCbCrToARGBMatrix *, const vImage_YpCbCrPixelRange *, vImage_YpCbCrToARGB *, vImageYpCbCrType, vImageARGBType, vImage_Flags);
VIMAGE_PF vImageConverterRef vImageConverter_CreateWithCGImageFormat(const vImage_CGImageFormat *, const vImage_CGImageFormat *, const CGFloat *, vImage_Flags, vImage_Error *);
VIMAGE_PF const vImageBufferTypeCode * vImageConverter_GetDestinationBufferOrder(vImageConverterRef);
VIMAGE_PF unsigned long vImageConverter_GetNumberOfDestinationBuffers(vImageConverterRef);
VIMAGE_PF unsigned long vImageConverter_GetNumberOfSourceBuffers(vImageConverterRef);
VIMAGE_PF const vImageBufferTypeCode * vImageConverter_GetSourceBufferOrder(vImageConverterRef);
VIMAGE_PF vImage_Error vImageConverter_MustOperateOutOfPlace(vImageConverterRef, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveFloatKernel_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, float, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveMultiKernel_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const int16_t **, uint32_t, uint32_t, const int32_t *, const int32_t *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveMultiKernel_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float **, uint32_t, uint32_t, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveWithBias_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, float, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveWithBias_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const int16_t *, uint32_t, uint32_t, int32_t, int32_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveWithBias_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, float, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveWithBias_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, float, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveWithBias_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const int16_t *, uint32_t, uint32_t, int32_t, int32_t, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolveWithBias_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, float, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolve_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolve_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const int16_t *, uint32_t, uint32_t, int32_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolve_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolve_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolve_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const int16_t *, uint32_t, uint32_t, int32_t, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageConvolve_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, uint32_t, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageCopyBuffer(const vImage_Buffer *, const vImage_Buffer *, size_t, vImage_Flags);
VIMAGE_PF GammaFunction vImageCreateGammaFunction(float, int32_t, vImage_Flags);
VIMAGE_PF void vImageDestroyGammaFunction(GammaFunction);
VIMAGE_PF void vImageDestroyResamplingFilter(ResamplingFilter);
VIMAGE_PF vImage_Error vImageDilate_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const uint8_t *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageDilate_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const float *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageDilate_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const uint8_t *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageDilate_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const float *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageEndsInContrastStretch_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const uint32_t *, const uint32_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageEndsInContrastStretch_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, const uint32_t *, const uint32_t *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageEndsInContrastStretch_Planar8(const vImage_Buffer *, const vImage_Buffer *, uint32_t, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageEndsInContrastStretch_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, uint32_t, uint32_t, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageEqualization_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageEqualization_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageEqualization_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageEqualization_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageErode_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const uint8_t *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageErode_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const float *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageErode_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const uint8_t *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageErode_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, const float *, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageExtractChannel_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, long, vImage_Flags);
VIMAGE_PF vImage_Error vImageExtractChannel_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, long, vImage_Flags);
VIMAGE_PF vImage_Error vImageExtractChannel_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, long, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_ARGB16Q12(const vImage_Buffer *, const vImage_Buffer *, const int16_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, const uint16_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_ARGB8888ToRGB888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const float *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_ARGBFFFFToRGBFFF(const vImage_Buffer *, const vImage_Buffer *, const float *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_BGRA8888ToRGB888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_BGRAFFFFToRGBFFF(const vImage_Buffer *, const vImage_Buffer *, const float *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_RGBA16Q12(const vImage_Buffer *, const vImage_Buffer *, const int16_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_RGBA16U(const vImage_Buffer *, const vImage_Buffer *, const uint16_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_RGBA8888ToRGB888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_RGBAFFFF(const vImage_Buffer *, const vImage_Buffer *, const float *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFlatten_RGBAFFFFToRGBFFF(const vImage_Buffer *, const vImage_Buffer *, const float *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImageFloodFill_ARGB16U(const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, uint16_t *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageFloodFill_ARGB8888(const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, uint8_t *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageFloodFill_Planar16U(const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, Pixel_16U, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageFloodFill_Planar8(const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, Pixel_8, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageGamma_Planar8toPlanarF(const vImage_Buffer *, const vImage_Buffer *, GammaFunction, vImage_Flags);
VIMAGE_PF vImage_Error vImageGamma_PlanarF(const vImage_Buffer *, const vImage_Buffer *, GammaFunction, vImage_Flags);
VIMAGE_PF vImage_Error vImageGamma_PlanarFtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, GammaFunction, vImage_Flags);
VIMAGE_PF vImagePixelCount vImageGetResamplingFilterExtent(ResamplingFilter, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramCalculation_ARGB8888(const vImage_Buffer *, vImagePixelCount **, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramCalculation_ARGBFFFF(const vImage_Buffer *, vImagePixelCount **, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramCalculation_Planar8(const vImage_Buffer *, vImagePixelCount *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramCalculation_PlanarF(const vImage_Buffer *, vImagePixelCount *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramSpecification_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImagePixelCount **, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramSpecification_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImagePixelCount **, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramSpecification_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImagePixelCount *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHistogramSpecification_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, const vImagePixelCount *, uint32_t, Pixel_F, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_Planar16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_Planar16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalReflect_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_CbCr16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_CbCr16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_Planar16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShearD_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_CbCr16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_CbCr16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_CbCr8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_Planar16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_Planar16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_16S, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_Planar16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_16U, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageInterpolatedLookupTable_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const Pixel_F *, vImagePixelCount, float, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_8to64U(const vImage_Buffer *, const vImage_Buffer *, const uint64_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar16(const vImage_Buffer *, const vImage_Buffer *, const Pixel_16U *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar8toPlanar128(const vImage_Buffer *, const vImage_Buffer *, const Pixel_FFFF *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar8toPlanar16(const vImage_Buffer *, const vImage_Buffer *, const Pixel_16U *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar8toPlanar24(const vImage_Buffer *, const vImage_Buffer *, const uint32_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar8toPlanar48(const vImage_Buffer *, const vImage_Buffer *, const uint64_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar8toPlanar96(const vImage_Buffer *, const vImage_Buffer *, const Pixel_FFFF *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_Planar8toPlanarF(const vImage_Buffer *, const vImage_Buffer *, const Pixel_F *, vImage_Flags);
VIMAGE_PF vImage_Error vImageLookupTable_PlanarFtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const int16_t *, int32_t, const int16_t *, const int32_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_ARGB8888ToPlanar8(const vImage_Buffer *, const vImage_Buffer *, const int16_t *, int32_t, const int16_t *, int32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_ARGBFFFFToPlanarF(const vImage_Buffer *, const vImage_Buffer *, const float *, const float *, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_Planar16S(const vImage_Buffer **, const vImage_Buffer **, uint32_t, uint32_t, const int16_t *, int32_t, const int16_t *, const int32_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_Planar8(const vImage_Buffer **, const vImage_Buffer **, uint32_t, uint32_t, const int16_t *, int32_t, const int16_t *, const int32_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageMatrixMultiply_PlanarF(const vImage_Buffer **, const vImage_Buffer **, uint32_t, uint32_t, const float *, const float *, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageMax_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMax_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMax_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMax_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMin_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMin_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMin_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF vImage_Error vImageMin_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImagePixelCount, vImage_Flags);
VIMAGE_PF ResamplingFilter vImageNewResamplingFilter(float, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithPixel_ARGB16U(const uint16_t *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithPixel_ARGB8888(const uint8_t *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithPixel_ARGBFFFF(const float *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_ARGB8888(Pixel_8, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_ARGBFFFF(Pixel_F, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_Planar16F(Pixel_16F, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_Planar16S(Pixel_16S, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_Planar16U(Pixel_16U, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_Planar8(Pixel_8, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannelsWithScalar_PlanarF(Pixel_F, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannels_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageOverwriteChannels_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannelsWithMaskedInsert_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannelsWithMaskedInsert_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, uint8_t, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannels_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannels_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannels_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannels_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePermuteChannels_RGB888(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePerspectiveWarp_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_PerpsectiveTransform *, vImage_WarpInterpolation, uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePerspectiveWarp_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_PerpsectiveTransform *, vImage_WarpInterpolation, uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePerspectiveWarp_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_PerpsectiveTransform *, vImage_WarpInterpolation, uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePerspectiveWarp_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_PerpsectiveTransform *, vImage_WarpInterpolation, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImagePerspectiveWarp_Planar16U(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_PerpsectiveTransform *, vImage_WarpInterpolation, Pixel_16U, vImage_Flags);
VIMAGE_PF vImage_Error vImagePerspectiveWarp_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, const vImage_PerpsectiveTransform *, vImage_WarpInterpolation, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_Planar16Q12(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, Pixel_16S, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_Planar16Q12toPlanar8(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, Pixel_16S, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_Planar8(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_Planar8toPlanar16Q12(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_Planar8toPlanarF(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, float, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseGamma_PlanarFtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, float, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewisePolynomial_Planar8toPlanarF(const vImage_Buffer *, const vImage_Buffer *, const float **, const float *, uint32_t, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewisePolynomial_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const float **, const float *, uint32_t, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewisePolynomial_PlanarFtoPlanar8(const vImage_Buffer *, const vImage_Buffer *, const float **, const float *, uint32_t, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImagePiecewiseRational_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const float **, const float **, const float *, uint32_t, uint32_t, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlendDarken_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlendLighten_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlendMultiply_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlendScreen_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlendWithPermute_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlendWithPermute_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, bool, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlend_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlend_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlend_BGRA8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlend_BGRAFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlend_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedAlphaBlend_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedConstAlphaBlend_ARGB8888(const vImage_Buffer *, Pixel_8, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedConstAlphaBlend_ARGBFFFF(const vImage_Buffer *, Pixel_F, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedConstAlphaBlend_Planar8(const vImage_Buffer *, Pixel_8, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultipliedConstAlphaBlend_PlanarF(const vImage_Buffer *, Pixel_F, const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_ARGB16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_RGBA16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_RGBA16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_RGBA16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImagePremultiplyData_RGBAFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, uint8_t, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, uint8_t, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, uint8_t, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, uint8_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, uint8_t, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, uint8_t, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_Planar16F(const vImage_Buffer *, const vImage_Buffer *, uint8_t, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_Planar16U(const vImage_Buffer *, const vImage_Buffer *, uint8_t, Pixel_16U, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_Planar8(const vImage_Buffer *, const vImage_Buffer *, uint8_t, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate90_PlanarF(const vImage_Buffer *, const vImage_Buffer *, uint8_t, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, float, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, void *, float, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, void *, float, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, float, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, float, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, void *, float, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, float, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, float, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageRotate_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, float, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_CbCr16U(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_CbCr8(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_Planar16S(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_Planar16U(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageScale_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, vImage_Flags);
VIMAGE_PF vImage_Error vImageSelectChannels_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageSelectChannels_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, uint8_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageSepConvolve_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, const float *, uint32_t, float, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageSepConvolve_Planar16F(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, const float *, uint32_t, float, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageSepConvolve_Planar16U(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, const float *, uint32_t, float, Pixel_16U, vImage_Flags);
VIMAGE_PF vImage_Error vImageSepConvolve_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, const float *, uint32_t, float, Pixel_16U, vImage_Flags);
VIMAGE_PF vImage_Error vImageSepConvolve_PlanarF(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, const float *, uint32_t, const float *, uint32_t, float, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageSymmetricPiecewiseGamma_Planar16Q12(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, Pixel_16S, vImage_Flags);
VIMAGE_PF vImage_Error vImageSymmetricPiecewiseGamma_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const float *, float, const float *, float, vImage_Flags);
VIMAGE_PF vImage_Error vImageSymmetricPiecewisePolynomial_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const float **, const float *, uint32_t, uint32_t, vImage_Flags);
VIMAGE_PF vImage_Error vImageTableLookUp_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, const Pixel_8 *, const Pixel_8 *, const Pixel_8 *, vImage_Flags);
VIMAGE_PF vImage_Error vImageTableLookUp_Planar8(const vImage_Buffer *, const vImage_Buffer *, const Pixel_8 *, vImage_Flags);
VIMAGE_PF vImage_Error vImageTentConvolve_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, uint32_t, uint32_t, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageTentConvolve_Planar8(const vImage_Buffer *, const vImage_Buffer *, void *, vImagePixelCount, vImagePixelCount, uint32_t, uint32_t, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_ARGB16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_Planar8(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_PlanarF(const vImage_Buffer *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_RGBA16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_RGBA16Q12(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_RGBA16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_RGBA8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageUnpremultiplyData_RGBAFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_Planar16F(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_Planar16U(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalReflect_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_CbCr16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_CbCr16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_Planar16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShearD_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, double, double, ResamplingFilter, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_ARGB16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_ARGB16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_ARGB8888(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const float *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_CbCr16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_CbCr16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const int16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_CbCr16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint16_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_CbCr8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, const uint8_t *, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_Planar16F(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_16F, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_Planar16S(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_16S, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_Planar16U(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_16U, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_Planar8(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_8, vImage_Flags);
VIMAGE_PF vImage_Error vImageVerticalShear_PlanarF(const vImage_Buffer *, const vImage_Buffer *, vImagePixelCount, vImagePixelCount, float, float, ResamplingFilter, Pixel_F, vImage_Flags);
VIMAGE_PF vImage_CGSize vImageBuffer_GetSize(const vImage_Buffer *buf);
VIMAGE_PF CGImageRef vImageCreateCGImageFromBuffer(const vImage_Buffer *buf, const vImage_CGImageFormat *format,
                                                   void (*callback)(void *userData, void *buf_data), void *userData,
                                                   vImage_Flags flags, vImage_Error *error);
VIMAGE_PF vImage_Error vImageGetPerspectiveWarp(const float srcPoints[4][2], const float destPoints[4][2],
                                                vImage_PerpsectiveTransform *transform, vImage_Flags flags);
VIMAGE_PF size_t vImageGetResamplingFilterSize(float scale,
                                               void (*kernelFunc)(const float *xArray, float *yArray, unsigned long count, void *userData),
                                               float kernelWidth, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageNewResamplingFilterForFunctionUsingBuffer(ResamplingFilter filter, float scale,
                                                                       void (*kernelFunc)(const float *xArray, float *yArray, unsigned long count, void *userData),
                                                                       float kernelWidth, void *userData, vImage_Flags flags);
VIMAGE_PF vImageConverterRef vImageConverter_Retain(vImageConverterRef converter);
VIMAGE_PF void vImageConverter_Release(vImageConverterRef converter);

/* ---- issue #693: 10/16-bit Y'CbCr, 4:2:2 with an alpha plane ---- */
VIMAGE_PF vImage_Error vImageConvert_422CbYpCrYp16ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_422CbYpCrYp16ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const uint16_t alpha, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To422CbYpCrYp16(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UTo422CbYpCrYp16(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_444AYpCbCr16ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_444AYpCbCr16ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To444AYpCbCr16(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UTo444AYpCbCr16(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_444CrYpCb10ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_444CrYpCb10ToARGB16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const Pixel_16Q12 alpha, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To444CrYpCb10(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16Q12To444CrYpCb10(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const uint8_t alpha, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], const Pixel_16Q12 alpha, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_422CbYpCrYp8_AA8ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *srcA, const vImage_Buffer *dest, const vImage_YpCbCrToARGB *info, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888To422CbYpCrYp8_AA8(const vImage_Buffer *src, const vImage_Buffer *dest, const vImage_Buffer *destA, const vImage_ARGBToYpCbCr *info, const uint8_t permuteMap[4], vImage_Flags flags);

/* ---- issue #693: 10-bit packed RGB (one host-order 32-bit word per pixel) ---- */
typedef uint32_t Pixel_32U;
VIMAGE_PF vImage_Error vImageConvert_ARGB8888ToARGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888ToXRGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB8888ToRGBA1010102(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UToARGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UToXRGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16UToRGBA1010102(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBFFFFToARGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGBFFFFToXRGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16Q12ToARGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16Q12ToXRGB2101010(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB16Q12ToRGBA1010102(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB2101010ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB2101010ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB2101010ToARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB2101010ToARGB16F(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_ARGB2101010ToARGB16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA1010102ToARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA1010102ToARGB16U(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_RGBA1010102ToARGB16Q12(const vImage_Buffer *src, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_XRGB2101010ToARGB8888(const vImage_Buffer *src, Pixel_8 alpha, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_XRGB2101010ToARGB16U(const vImage_Buffer *src, uint16_t alpha, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_XRGB2101010ToARGBFFFF(const vImage_Buffer *src, Pixel_F alpha, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_XRGB2101010ToARGB16F(const vImage_Buffer *src, Pixel_F alpha, const vImage_Buffer *dest, int32_t RGB101010RangeMin, int32_t RGB101010RangeMax, const uint8_t permuteMap[4], vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_XRGB2101010ToARGB16Q12(const vImage_Buffer *src, Pixel_16Q12 alpha, const vImage_Buffer *dest, int32_t RGB101010BlackPoint, int32_t RGB101010WhitePoint, const uint8_t permuteMap[4], vImage_Flags flags);
/* XRGB2101010W: extended range, 384 is 0.0 and 894 is 1.0 */
VIMAGE_PF vImage_Error vImageScale_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageHorizontalShear_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, float xTranslate, float shearSlope, ResamplingFilter filter, Pixel_32U backColor, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageVerticalShear_XRGB2101010W(const vImage_Buffer *src, const vImage_Buffer *dest, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, float yTranslate, float shearSlope, ResamplingFilter filter, Pixel_32U backColor, vImage_Flags flags);

/* ---- issue #693: Planar8 to indexed, multidimensional tables, Richardson-Lucy, Planar8 -> 16U, PNG filters, colour spaces ---- */
VIMAGE_PF vImage_Error vImageConvert_Planar8toIndexed1(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, Pixel_8 colors[2], int dither, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toIndexed2(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, Pixel_8 colors[4], int dither, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageConvert_Planar8toIndexed4(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, Pixel_8 colors[16], int dither, vImage_Flags flags);
typedef struct vImage_MultidimensionalTableData *vImage_MultidimensionalTable;
typedef uint32_t vImageMDTableUsageHint;
enum { kvImageMDTableHint_16Q12 = 1, kvImageMDTableHint_Float = 2 };
typedef uint32_t vImage_InterpolationMethod;
enum { kvImageNoInterpolation = 0, kvImageFullInterpolation = 1, kvImageHalfInterpolation = 2 };
VIMAGE_PF vImage_MultidimensionalTable vImageMultidimensionalTable_Create(const uint16_t *tableData, uint32_t numSrcChannels, uint32_t numDestChannels, const uint8_t table_entries_per_dimension[], vImageMDTableUsageHint hint, vImage_Flags flags, vImage_Error *err);
VIMAGE_PF vImage_Error vImageMultidimensionalTable_Retain(vImage_MultidimensionalTable table);
VIMAGE_PF vImage_Error vImageMultidimensionalTable_Release(vImage_MultidimensionalTable table);
VIMAGE_PF vImage_Error vImageMultiDimensionalInterpolatedLookupTable_PlanarF(const vImage_Buffer srcs[], const vImage_Buffer dests[], void *tempBuffer, vImage_MultidimensionalTable table, vImage_InterpolationMethod method, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageMultiDimensionalInterpolatedLookupTable_Planar16Q12(const vImage_Buffer srcs[], const vImage_Buffer dests[], void *tempBuffer, vImage_MultidimensionalTable table, vImage_InterpolationMethod method, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageRichardsonLucyDeConvolve_Planar8(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, const int16_t *kernel2, uint32_t kernel_height, uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, int32_t divisor, int32_t divisor2, Pixel_8 backgroundColor, uint32_t iterationCount, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageRichardsonLucyDeConvolve_PlanarF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const float *kernel, const float *kernel2, uint32_t kernel_height, uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, Pixel_F backgroundColor, uint32_t iterationCount, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageRichardsonLucyDeConvolve_ARGB8888(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const int16_t *kernel, const int16_t *kernel2, uint32_t kernel_height, uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, int32_t divisor, int32_t divisor2, const Pixel_8888 backgroundColor, uint32_t iterationCount, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageRichardsonLucyDeConvolve_ARGBFFFF(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const float *kernel, const float *kernel2, uint32_t kernel_height, uint32_t kernel_width, uint32_t kernel_height2, uint32_t kernel_width2, const Pixel_FFFF backgroundColor, uint32_t iterationCount, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageSepConvolve_Planar8to16U(const vImage_Buffer *src, const vImage_Buffer *dest, void *tempBuffer, vImagePixelCount srcOffsetToROI_X, vImagePixelCount srcOffsetToROI_Y, const float *kernelX, uint32_t kernelX_width, const float *kernelY, uint32_t kernelY_width, float scale, float bias, Pixel_8 backgroundColor, vImage_Flags flags);
enum { kvImage_PNG_FILTER_VALUE_NONE = 0, kvImage_PNG_FILTER_VALUE_SUB = 1, kvImage_PNG_FILTER_VALUE_UP = 2, kvImage_PNG_FILTER_VALUE_AVG = 3, kvImage_PNG_FILTER_VALUE_PAETH = 4 };
VIMAGE_PF vImage_Error vImagePNGDecompressionFilter(const vImage_Buffer *buffer, vImagePixelCount startScanline, vImagePixelCount scanlineCount, uint32_t bitsPerPixel, uint32_t filterMethodNumber, uint32_t filterType, vImage_Flags flags);
typedef struct vImageRGBPrimaries { float red_x, green_x, blue_x, white_x, red_y, green_y, blue_y, white_y; } vImageRGBPrimaries;
typedef struct vImageWhitePoint { float white_x, white_y; } vImageWhitePoint;
/* y = c0 * (c1 * x + c2)^gamma + c3 for x >= cutoff, c4 * x + c5 below */
typedef struct vImageTransferFunction { CGFloat c0, c1, c2, c3, gamma, cutoff, c4, c5; } vImageTransferFunction;
VIMAGE_PF CGColorSpaceRef vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(const vImageRGBPrimaries *primaries, const vImageTransferFunction *tf, CGColorRenderingIntent intent, vImage_Flags flags, vImage_Error *error);
VIMAGE_PF CGColorSpaceRef vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction(const vImageWhitePoint *whitePoint, const vImageTransferFunction *tf, CGColorRenderingIntent intent, vImage_Flags flags, vImage_Error *error);

/* ---- issue #693: Core Video ---- */
typedef struct __attribute__((objc_bridge(id))) vImageCVImageFormat *vImageCVImageFormatRef;
typedef const struct __attribute__((objc_bridge(id))) vImageCVImageFormat *vImageConstCVImageFormatRef;
typedef struct vImageChannelDescription { CGFloat min, zero, full, max; } vImageChannelDescription;
typedef uint32_t vImageMatrixType;
enum { kvImageMatrixType_None = 0, kvImageMatrixType_ARGBToYpCbCrMatrix = 1 };
enum {
    kvImageCVImageFormat_NoError = 0, kvImageCVImageFormat_ConversionMatrix = -21590, kvImageCVImageFormat_ChromaSiting = -21591,
    kvImageCVImageFormat_ColorSpace = -21592, kvImageCVImageFormat_VideoChannelDescription = -21593, kvImageCVImageFormat_AlphaIsOneHint = -21594,
};
VIMAGE_PF vImageCVImageFormatRef vImageCVImageFormat_Create(uint32_t imageFormatType, const vImage_ARGBToYpCbCrMatrix *matrix, CFStringRef cvImageBufferChromaLocation, CGColorSpaceRef baseColorspace, int alphaIsOneHint);
VIMAGE_PF vImageCVImageFormatRef vImageCVImageFormat_Copy(vImageConstCVImageFormatRef format);
VIMAGE_PF vImageCVImageFormatRef vImageCVImageFormat_Retain(vImageCVImageFormatRef fmt);
VIMAGE_PF void vImageCVImageFormat_Release(vImageCVImageFormatRef fmt);
VIMAGE_PF uint32_t vImageCVImageFormat_GetFormatCode(vImageConstCVImageFormatRef format);
VIMAGE_PF uint32_t vImageCVImageFormat_GetChannelCount(vImageConstCVImageFormatRef format);
VIMAGE_PF const vImageBufferTypeCode *vImageCVImageFormat_GetChannelNames(vImageConstCVImageFormatRef format);
VIMAGE_PF const vImageChannelDescription *vImageCVImageFormat_GetChannelDescription(vImageConstCVImageFormatRef format, vImageBufferTypeCode type);
VIMAGE_PF vImage_Error vImageCVImageFormat_CopyChannelDescription(vImageCVImageFormatRef format, const vImageChannelDescription *desc, vImageBufferTypeCode type);
VIMAGE_PF CFStringRef vImageCVImageFormat_GetChromaSiting(vImageConstCVImageFormatRef format);
VIMAGE_PF vImage_Error vImageCVImageFormat_SetChromaSiting(vImageCVImageFormatRef format, CFStringRef siting);
VIMAGE_PF CGColorSpaceRef vImageCVImageFormat_GetColorSpace(vImageConstCVImageFormatRef format);
VIMAGE_PF vImage_Error vImageCVImageFormat_SetColorSpace(vImageCVImageFormatRef format, CGColorSpaceRef colorspace);
VIMAGE_PF int vImageCVImageFormat_GetAlphaHint(vImageConstCVImageFormatRef format);
VIMAGE_PF vImage_Error vImageCVImageFormat_SetAlphaHint(vImageCVImageFormatRef format, int alphaIsOne);
VIMAGE_PF const void *vImageCVImageFormat_GetConversionMatrix(vImageConstCVImageFormatRef format, vImageMatrixType *outType);
VIMAGE_PF vImage_Error vImageCVImageFormat_CopyConversionMatrix(vImageCVImageFormatRef format, const void *matrix, vImageMatrixType inType);
VIMAGE_PF void *vImageCVImageFormat_GetUserData(vImageConstCVImageFormatRef format);
VIMAGE_PF vImage_Error vImageCVImageFormat_SetUserData(vImageCVImageFormatRef format, void *userData, void (*userDataReleaseCallback)(vImageCVImageFormatRef arg, void *userData));
VIMAGE_PF vImageConverterRef vImageConverter_CreateForCGToCVImageFormat(const vImage_CGImageFormat *srcFormat, vImageCVImageFormatRef destFormat, const CGFloat *backgroundColor, vImage_Flags flags, vImage_Error *error);
VIMAGE_PF vImageConverterRef vImageConverter_CreateForCVToCGImageFormat(vImageCVImageFormatRef srcFormat, const vImage_CGImageFormat *destFormat, const CGFloat *backgroundColor, vImage_Flags flags, vImage_Error *error);
/* the functions taking a CVPixelBuffer (Swift has its own over Swift's CVPixelBuffer, in the overlay) */
#if !defined(__swift__)
#include <CoreVideo/CoreVideo.h>
VIMAGE_PF vImageCVImageFormatRef vImageCVImageFormat_CreateWithCVPixelBuffer(CVPixelBufferRef buffer);
VIMAGE_PF vImage_Error vImageBuffer_InitWithCVPixelBuffer(vImage_Buffer *buffer, vImage_CGImageFormat *desiredFormat, CVPixelBufferRef cvPixelBuffer, vImageCVImageFormatRef cvImageFormat, const CGFloat *backgroundColor, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageBuffer_CopyToCVPixelBuffer(const vImage_Buffer *buffer, const vImage_CGImageFormat *bufferFormat, CVPixelBufferRef cvPixelBuffer, vImageCVImageFormatRef cvImageFormat, const CGFloat *backgroundColor, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageBuffer_InitForCopyToCVPixelBuffer(vImage_Buffer *buffers, const vImageConverterRef converter, const CVPixelBufferRef pixelBuffer, vImage_Flags flags);
VIMAGE_PF vImage_Error vImageBuffer_InitForCopyFromCVPixelBuffer(vImage_Buffer *buffers, const vImageConverterRef converter, const CVPixelBufferRef pixelBuffer, vImage_Flags flags);
#endif

#ifdef __cplusplus
}
#endif
