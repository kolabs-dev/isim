#pragma once
#include <ImageIO/CGImageSource.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: the frames of GIF and animated WebP images (any other image is one frame), handed to the block on the main
 * queue at the delays the file gives them */
typedef CF_ENUM(OSStatus, CGImageAnimationStatus) {
    kCGImageAnimationStatus_ParameterError = -22140,
    kCGImageAnimationStatus_CorruptInputImage = -22141,
    kCGImageAnimationStatus_UnsupportedFormat = -22142,
    kCGImageAnimationStatus_IncompleteInputImage = -22143,
    kCGImageAnimationStatus_AllocationFailure = -22144
};
IMAGEIO_EXTERN const CFStringRef kCGImageAnimationStartIndex;
IMAGEIO_EXTERN const CFStringRef kCGImageAnimationDelayTime;
IMAGEIO_EXTERN const CFStringRef kCGImageAnimationLoopCount;
typedef void (^CGImageSourceAnimationBlock)(size_t index, CGImageRef image, bool *stop);
IMAGEIO_EXTERN OSStatus CGAnimateImageAtURLWithBlock(CFURLRef url, CFDictionaryRef _Nullable options, CGImageSourceAnimationBlock block);
IMAGEIO_EXTERN OSStatus CGAnimateImageDataWithBlock(CFDataRef data, CFDictionaryRef _Nullable options, CGImageSourceAnimationBlock block);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
