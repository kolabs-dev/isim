/* isim CoreVideo for C: the dictionary keys and attachment values, the same strings as the Swift overlay's constants */
#include <CoreVideo/CoreVideo.h>

const CFStringRef kCVPixelBufferPixelFormatTypeKey = CFSTR("PixelFormatType");
const CFStringRef kCVPixelBufferWidthKey = CFSTR("Width");
const CFStringRef kCVPixelBufferHeightKey = CFSTR("Height");
const CFStringRef kCVPixelBufferBytesPerRowAlignmentKey = CFSTR("BytesPerRowAlignment");
const CFStringRef kCVPixelBufferCGImageCompatibilityKey = CFSTR("CGImageCompatibility");
const CFStringRef kCVPixelBufferCGBitmapContextCompatibilityKey = CFSTR("CGBitmapContextCompatibility");
const CFStringRef kCVPixelBufferIOSurfacePropertiesKey = CFSTR("IOSurfaceProperties");
const CFStringRef kCVPixelBufferMetalCompatibilityKey = CFSTR("MetalCompatibility");
const CFStringRef kCVPixelBufferPoolMinimumBufferCountKey = CFSTR("MinimumBufferCount");
const CFStringRef kCVPixelBufferPoolMaximumBufferAgeKey = CFSTR("MaximumBufferAge");
const CFStringRef kCVBufferPropagatedAttachmentsKey = CFSTR("PropagatedAttachments");
const CFStringRef kCVBufferNonPropagatedAttachmentsKey = CFSTR("NonPropagatedAttachments");
const CFStringRef kCVBufferMovieTimeKey = CFSTR("QTMovieTime");
const CFStringRef kCVImageBufferCGColorSpaceKey = CFSTR("CGColorSpace");
const CFStringRef kCVImageBufferColorPrimariesKey = CFSTR("ColorPrimaries");
const CFStringRef kCVImageBufferTransferFunctionKey = CFSTR("TransferFunction");
const CFStringRef kCVImageBufferYCbCrMatrixKey = CFSTR("YCbCrMatrix");
const CFStringRef kCVImageBufferPixelAspectRatioKey = CFSTR("CVPixelAspectRatio");
const CFStringRef kCVImageBufferFieldCountKey = CFSTR("CVFieldCount");
const CFStringRef kCVImageBufferChromaLocationTopFieldKey = CFSTR("CVImageBufferChromaLocationTopField");
const CFStringRef kCVImageBufferColorPrimaries_ITU_R_709_2 = CFSTR("ITU_R_709_2");
const CFStringRef kCVImageBufferColorPrimaries_P3_D65 = CFSTR("P3_D65");
const CFStringRef kCVImageBufferTransferFunction_ITU_R_709_2 = CFSTR("ITU_R_709_2");
const CFStringRef kCVImageBufferYCbCrMatrix_ITU_R_709_2 = CFSTR("ITU_R_709_2");
const CFStringRef kCVImageBufferYCbCrMatrix_ITU_R_601_4 = CFSTR("ITU_R_601_4");
