// isim ImageIO: CGAnimateImageAtURLWithBlock / CGAnimateImageDataWithBlock. The frames of a GIF or animated WebP image
// (any other image is one frame) are decoded through a CGImageSource and handed to the block on the main queue, each
// after the delay of the one before (its DelayTime, or kCGImageAnimationDelayTime), for the file's loop count (0 is
// forever) or kCGImageAnimationLoopCount, until the block sets *stop.
#import "ImageIOPrivate.h"
#include <dispatch/dispatch.h>

#define S(k) ((__bridge NSString *)(k))

@interface _ISIMImageAnimation : NSObject {
@public CGImageSourceRef _src; CGImageSourceAnimationBlock _block; size_t _count, _index; long _loops, _played; double _delay;
}
@end
@implementation _ISIMImageAnimation
- (void)dealloc { if (_src) CFRelease(_src); }
/* the delay after frame i */
- (double)delayAfter:(size_t)i {
    if (_delay > 0) return _delay;
    NSDictionary *p = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(_src, i, NULL));
    NSNumber *d = p[S(kCGImagePropertyGIFDictionary)][S(kCGImagePropertyGIFDelayTime)] ?: p[S(kCGImagePropertyWebPDictionary)][S(kCGImagePropertyWebPDelayTime)];
    return d.doubleValue > 0 ? d.doubleValue : 0.1;
}
- (void)step {
    CGImageRef im = CGImageSourceCreateImageAtIndex(_src, _index, NULL);
    if (!im) return;
    bool stop = false;
    _block(_index, im, &stop);
    CGImageRelease(im);
    if (stop || _count == 1) return;
    double delay = [self delayAfter:_index];
    if (++_index == _count) {                        /* the end of a loop */
        _index = 0;
        if (_loops > 0 && ++_played >= _loops) return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self step]; });
}
@end

static OSStatus animate(NSData *data, NSDictionary *options, CGImageSourceAnimationBlock block) {
    if (!data || !block) return kCGImageAnimationStatus_ParameterError;
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!src) return kCGImageAnimationStatus_CorruptInputImage;
    size_t count = CGImageSourceGetCount(src);
    if (!count) {
        CGImageSourceStatus st = CGImageSourceGetStatus(src);
        CFRelease(src);
        return st == kCGImageStatusUnknownType ? kCGImageAnimationStatus_UnsupportedFormat : kCGImageAnimationStatus_CorruptInputImage;
    }
    size_t start = [options[S(kCGImageAnimationStartIndex)] unsignedLongValue];
    if (start >= count) { CFRelease(src); return kCGImageAnimationStatus_ParameterError; }
    _ISIMImageAnimation *a = [_ISIMImageAnimation new];
    a->_src = src; a->_block = [block copy]; a->_count = count; a->_index = start;
    a->_delay = [options[S(kCGImageAnimationDelayTime)] doubleValue];
    NSDictionary *file = CFBridgingRelease(CGImageSourceCopyProperties(src, NULL));
    NSNumber *loops = options[S(kCGImageAnimationLoopCount)] ?: file[S(kCGImagePropertyGIFDictionary)][S(kCGImagePropertyGIFLoopCount)]
                                                               ?: file[S(kCGImagePropertyWebPDictionary)][S(kCGImagePropertyWebPLoopCount)];
    a->_loops = loops ? loops.longValue : 1;
    dispatch_async(dispatch_get_main_queue(), ^{ [a step]; });
    return noErr;
}
OSStatus CGAnimateImageDataWithBlock(CFDataRef data, CFDictionaryRef options, CGImageSourceAnimationBlock block) {
    return animate((__bridge NSData *)data, (__bridge NSDictionary *)options, block);
}
OSStatus CGAnimateImageAtURLWithBlock(CFURLRef url, CFDictionaryRef options, CGImageSourceAnimationBlock block) {
    if (!url || !block) return kCGImageAnimationStatus_ParameterError;
    NSData *d = [NSData dataWithContentsOfURL:(__bridge NSURL *)url];
    if (!d) return kCGImageAnimationStatus_CorruptInputImage;
    return animate(d, (__bridge NSDictionary *)options, block);
}
