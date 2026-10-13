// isim Core Image: UIKit's Core Image additions (UIImage <-> CIImage). The CIImage is rendered (CPU) when the UIImage
// is made, like iOS does when such an image is first drawn; the UIImage keeps the CIImage.
#import "CIInternal.h"
#include <objc/runtime.h>

static char ci_key;
@implementation UIImage (CoreImage)
+ (UIImage *)imageWithCIImage:(CIImage *)ci { return [[self alloc] initWithCIImage:ci]; }
+ (UIImage *)imageWithCIImage:(CIImage *)ci scale:(CGFloat)s orientation:(UIImageOrientation)o { return [[self alloc] initWithCIImage:ci scale:s orientation:o]; }
- (instancetype)initWithCIImage:(CIImage *)ci { return [self initWithCIImage:ci scale:1 orientation:UIImageOrientationUp]; }
- (instancetype)initWithCIImage:(CIImage *)ci scale:(CGFloat)s orientation:(UIImageOrientation)o {
    static CIContext *ctx;
    static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&m); if (!ctx) ctx = [CIContext contextWithOptions:@{ kCIContextName: @"UIImage" }]; pthread_mutex_unlock(&m);
    if (!ci || ci_infinite(ci.extent) || CGRectIsEmpty(ci.extent)) {
        /* like iOS, the image exists but draws nothing (iOS fails when drawing it) */
        if (ci && ci_infinite(ci.extent)) NSLog(@"isim: UIImage(ciImage:): the CIImage has an infinite extent; crop it first");
        UIImage *img = [self init];
        if (img && ci) objc_setAssociatedObject(img, &ci_key, ci, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return img;
    }
    CGImageRef cg = [ctx createCGImage:ci fromRect:ci.extent];
    if (!cg) return [self init];
    UIImage *img = [self initWithCGImage:cg scale:s orientation:o];
    CGImageRelease(cg);
    if (img) objc_setAssociatedObject(img, &ci_key, ci, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return img;
}
- (CIImage *)CIImage { return objc_getAssociatedObject(self, &ci_key); }
@end

