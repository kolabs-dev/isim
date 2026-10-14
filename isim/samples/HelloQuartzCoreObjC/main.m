// HelloQuartzCoreObjC: Core Animation and Core Video from Objective-C and C (issue #222). It imports
// <QuartzCore/QuartzCore.h> and <CoreVideo/CoreVideo.h> and links -framework QuartzCore -framework CoreVideo
// (UIKit only for the app itself). Logs "qc PASS ..." / "qc FAIL ..." per check, "qc summary N/M", then
// "qc reported" once a CADisplayLink has drawn the ring to the end. On screen: a gradient, a ring whose stroke the
// display link advances, and a pixel buffer filled from C shown as a layer's contents.
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <string.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("qc PASS  %s\n", #cond); else { failures++; printf("qc FAIL  %s  (line %d)\n", #cond, __LINE__); } fflush(stdout); } while (0)

static void test_layers(void) {
    CALayer *root = [CALayer layer];
    root.frame = CGRectMake(0, 0, 200, 100);
    CAShapeLayer *shape = [CAShapeLayer layer];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    [root addSublayer:shape];
    [root addSublayer:gradient];
    CHECK(root.sublayers.count == 2 && shape.superlayer == root);
    CHECK(root.bounds.size.width == 200 && root.position.x == 100 && root.position.y == 50);
    CHECK([shape isKindOfClass:[CALayer class]] && [gradient isKindOfClass:[CALayer class]]);
    root.transform = CATransform3DMakeScale(2, 2, 1);
    CHECK(root.transform.m11 == 2 && !CATransform3DIsIdentity(root.transform));
    CHECK(CATransform3DIsIdentity(CATransform3DIdentity));
    CHECK(CATransform3DEqualToTransform(CATransform3DConcat(CATransform3DMakeTranslation(5, 0, 0), CATransform3DIdentity),
                                        CATransform3DMakeTranslation(5, 0, 0)));
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CHECK([CATransaction disableActions]);
    root.opacity = 0.5f;
    [CATransaction commit];
    CHECK(root.opacity == 0.5f);
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @1; fade.toValue = @0; fade.duration = 0.25;
    fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [root addAnimation:fade forKey:@"fade"];
    CHECK([root animationForKey:@"fade"] != nil && [[root animationKeys] containsObject:@"fade"]);
    [root removeAllAnimations];
    CHECK([root animationForKey:@"fade"] == nil);
    [shape removeFromSuperlayer];
    CHECK(root.sublayers.count == 1 && shape.superlayer == nil);
    CHECK(CACurrentMediaTime() > 0);
}

static int released;
static void release_bytes(void *refCon, const void *base) { released += refCon == (void *)0x1234; }
static void release_planes(void *refCon, const void *data, size_t size, size_t n, const void *planes[]) { released += n == 2 && refCon == (void *)0x5678; }

static void test_pixel_buffers(void) {
    CVPixelBufferRef pb = NULL;
    CHECK(CVPixelBufferCreate(kCFAllocatorDefault, 64, 32, kCVPixelFormatType_32BGRA, NULL, &pb) == kCVReturnSuccess && pb != NULL);
    CHECK(CVPixelBufferGetWidth(pb) == 64 && CVPixelBufferGetHeight(pb) == 32);
    CHECK(CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_32BGRA && !CVPixelBufferIsPlanar(pb));
    CHECK(CVPixelBufferGetBytesPerRow(pb) >= 64 * 4);
    CHECK(CVPixelBufferLockBaseAddress(pb, 0) == kCVReturnSuccess);
    uint8_t *base = CVPixelBufferGetBaseAddress(pb);
    size_t bpr = CVPixelBufferGetBytesPerRow(pb);
    CHECK(base != NULL);
    for (size_t y = 0; y < 32; y++) memset(base + y * bpr, (int)y, 64 * 4);
    CHECK(base[31 * bpr + 4 * 63 + 3] == 31);
    CHECK(CVPixelBufferUnlockBaseAddress(pb, 0) == kCVReturnSuccess);
    CHECK(CVPixelBufferCreate(NULL, 0, 32, kCVPixelFormatType_32BGRA, NULL, &(CVPixelBufferRef){NULL}) == kCVReturnInvalidSize);

    // attachments: the value, its mode, the dictionaries per mode, propagation
    CVBufferSetAttachment(pb, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pb, CFSTR("dev.isim.note"), CFSTR("local"), kCVAttachmentMode_ShouldNotPropagate);
    CVAttachmentMode mode = 99;
    CFTypeRef v = CVBufferGetAttachment(pb, kCVImageBufferColorPrimariesKey, &mode);
    CHECK(v && CFEqual(v, CFSTR("ITU_R_709_2")) && mode == kCVAttachmentMode_ShouldPropagate);
    CHECK(CVBufferHasAttachment(pb, CFSTR("dev.isim.note")) && !CVBufferHasAttachment(pb, CFSTR("missing")));
    CFDictionaryRef prop = CVBufferCopyAttachments(pb, kCVAttachmentMode_ShouldPropagate);
    CHECK(prop && CFDictionaryGetCount(prop) == 1);
    if (prop) CFRelease(prop);
    CVPixelBufferRef copy = NULL;
    CVPixelBufferCreate(NULL, 8, 8, kCVPixelFormatType_32BGRA, NULL, &copy);
    CVBufferPropagateAttachments(pb, copy);
    CHECK(CVBufferHasAttachment(copy, kCVImageBufferColorPrimariesKey) && !CVBufferHasAttachment(copy, CFSTR("dev.isim.note")));
    CVBufferRemoveAttachment(pb, CFSTR("dev.isim.note"));
    CHECK(!CVBufferHasAttachment(pb, CFSTR("dev.isim.note")) && CVBufferGetAttachments(pb, kCVAttachmentMode_ShouldNotPropagate) == NULL);
    CVBufferRemoveAllAttachments(pb);
    CHECK(CVBufferGetAttachment(pb, kCVImageBufferColorPrimariesKey, NULL) == NULL);
    CHECK(CVPixelBufferRetain(pb) == pb);
    CVPixelBufferRelease(pb);
    CVPixelBufferRelease(pb);
    CVPixelBufferRelease(copy);

    // over the caller's memory: one plane, then NV12 (two planes)
    static uint8_t bytes[16 * 4 * 4];
    CVPixelBufferRef wrapped = NULL;
    CHECK(CVPixelBufferCreateWithBytes(NULL, 16, 4, kCVPixelFormatType_32BGRA, bytes, 64, release_bytes, (void *)0x1234, NULL, &wrapped) == kCVReturnSuccess);
    CHECK(CVPixelBufferGetBaseAddress(wrapped) == bytes && CVPixelBufferGetBytesPerRow(wrapped) == 64);
    CVPixelBufferRelease(wrapped);
    static uint8_t luma[16 * 8], chroma[16 * 4];
    void *planes[2] = {luma, chroma};
    size_t widths[2] = {16, 8}, heights[2] = {8, 4}, rows[2] = {16, 16};
    CVPixelBufferRef nv12 = NULL;
    CHECK(CVPixelBufferCreateWithPlanarBytes(NULL, 16, 8, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, NULL, 0, 2, planes, widths, heights,
                                             rows, release_planes, (void *)0x5678, NULL, &nv12) == kCVReturnSuccess);
    CHECK(CVPixelBufferIsPlanar(nv12) && CVPixelBufferGetPlaneCount(nv12) == 2);
    CHECK(CVPixelBufferGetBaseAddressOfPlane(nv12, 0) == luma && CVPixelBufferGetBaseAddressOfPlane(nv12, 1) == chroma);
    CHECK(CVPixelBufferGetWidthOfPlane(nv12, 1) == 8 && CVPixelBufferGetHeightOfPlane(nv12, 1) == 4 && CVPixelBufferGetBytesPerRowOfPlane(nv12, 1) == 16);
    CVPixelBufferRelease(nv12);
    CHECK(released == 2);
    CHECK(CVPixelBufferCreateWithPlanarBytes(NULL, 16, 8, kCVPixelFormatType_32BGRA, NULL, 0, 2, planes, widths, heights, rows, NULL, NULL,
                                             NULL, &(CVPixelBufferRef){NULL}) == kCVReturnInvalidPixelFormat);
}

static void test_pool(void) {
    NSDictionary *attrs = @{(__bridge NSString *)kCVPixelBufferWidthKey: @32, (__bridge NSString *)kCVPixelBufferHeightKey: @16,
                            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_OneComponent8)};
    NSDictionary *poolAttrs = @{(__bridge NSString *)kCVPixelBufferPoolMinimumBufferCountKey: @3};
    CVPixelBufferPoolRef pool = NULL;
    CHECK(CVPixelBufferPoolCreate(NULL, (__bridge CFDictionaryRef)poolAttrs, (__bridge CFDictionaryRef)attrs, &pool) == kCVReturnSuccess && pool);
    NSDictionary *got = (__bridge NSDictionary *)CVPixelBufferPoolGetPixelBufferAttributes(pool);
    CHECK([got[(__bridge NSString *)kCVPixelBufferWidthKey] intValue] == 32);
    CHECK([((__bridge NSDictionary *)CVPixelBufferPoolGetAttributes(pool))[@"MinimumBufferCount"] intValue] == 3);
    CVPixelBufferRef a = NULL, b = NULL;
    CHECK(CVPixelBufferPoolCreatePixelBuffer(NULL, pool, &a) == kCVReturnSuccess && CVPixelBufferPoolCreatePixelBuffer(NULL, pool, &b) == kCVReturnSuccess);
    CHECK(a != b && CVPixelBufferGetWidth(a) == 32 && CVPixelBufferGetHeight(b) == 16);
    CHECK(CVPixelBufferGetPixelFormatType(a) == kCVPixelFormatType_OneComponent8 && CVPixelBufferGetBytesPerRow(a) >= 32);
    CVPixelBufferRelease(a); CVPixelBufferRelease(b);
    CVPixelBufferPoolFlush(pool, kCVPixelBufferPoolFlushExcessBuffers);
    CHECK(CVPixelBufferPoolCreate(NULL, NULL, NULL, &(CVPixelBufferPoolRef){NULL}) == kCVReturnInvalidArgument);
    CVPixelBufferPoolRelease(pool);
}

/* a 64x64 BGRA pixel buffer filled from C (a diagonal blend), drawn as a CGImage */
static CGImageRef pixel_buffer_image(void) {
    CVPixelBufferRef pb = NULL;
    if (CVPixelBufferCreate(NULL, 64, 64, kCVPixelFormatType_32BGRA, NULL, &pb) != kCVReturnSuccess) return NULL;
    CVPixelBufferLockBaseAddress(pb, 0);
    uint8_t *base = CVPixelBufferGetBaseAddress(pb);
    size_t bpr = CVPixelBufferGetBytesPerRow(pb);
    for (int y = 0; y < 64; y++)
        for (int x = 0; x < 64; x++) {
            uint8_t *p = base + y * bpr + x * 4;
            p[0] = (uint8_t)(255 - x * 4); p[1] = (uint8_t)(y * 4); p[2] = (uint8_t)(x * 4); p[3] = 255;   // B G R A
        }
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(base, 64, 64, 8, bpr, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGImageRef img = ctx ? CGBitmapContextCreateImage(ctx) : NULL;
    if (ctx) CGContextRelease(ctx);
    CGColorSpaceRelease(cs);
    CVPixelBufferUnlockBaseAddress(pb, 0);
    CVPixelBufferRelease(pb);
    return img;
}

@interface RingController : UIViewController
@property (nonatomic, strong) CAShapeLayer *ring;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic) int ticks;
@end
@implementation RingController
- (void)viewDidLoad {
    [super viewDidLoad];
    CALayer *root = self.view.layer;
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.05 green:0.1 blue:0.3 alpha:1].CGColor, (id)[UIColor colorWithRed:0.3 green:0.1 blue:0.45 alpha:1].CGColor];
    [root addSublayer:gradient];

    CGFloat w = self.view.bounds.size.width;
    CAShapeLayer *track = [CAShapeLayer layer], *ring = [CAShapeLayer layer];
    for (CAShapeLayer *l in @[track, ring]) {
        l.frame = CGRectMake(w / 2 - 100, 160, 200, 200);
        l.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10, 10, 180, 180)].CGPath;
        l.fillColor = nil;
        l.lineWidth = 16;
        l.lineCap = kCALineCapRound;
        [root addSublayer:l];
    }
    track.strokeColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    ring.strokeColor = [UIColor colorWithRed:1 green:0.75 blue:0.2 alpha:1].CGColor;
    ring.strokeEnd = 0;
    self.ring = ring;

    CATextLayer *title = [CATextLayer layer];
    title.frame = CGRectMake(0, 90, w, 40);
    title.string = @"QuartzCore + CoreVideo";
    title.fontSize = 24;
    title.alignmentMode = kCAAlignmentCenter;
    title.foregroundColor = UIColor.whiteColor.CGColor;
    title.contentsScale = UIScreen.mainScreen.scale;
    [root addSublayer:title];

    CALayer *pixels = [CALayer layer];
    pixels.frame = CGRectMake(w / 2 - 64, 420, 128, 128);
    pixels.contents = (__bridge_transfer id)pixel_buffer_image();
    pixels.magnificationFilter = kCAFilterNearest;
    pixels.cornerRadius = 12;
    pixels.masksToBounds = YES;
    [root addSublayer:pixels];
    CHECK(pixels.contents != nil);

    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    CHECK(self.link != nil && !self.link.paused);
    [self.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)tick:(CADisplayLink *)link {
    self.ticks++;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ring.strokeEnd = MIN(1.0, self.ticks / 30.0);
    [CATransaction commit];
    if (self.ticks < 30) return;
    CHECK(self.ticks == 30);
    CHECK(link.timestamp > 0 && link.duration > 0 && link.targetTimestamp > link.timestamp);
    [link invalidate];
    CHECK(self.ring.strokeEnd == 1.0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CHECK(self.ticks == 30);                                   // invalidated: no more callbacks
        printf("qc summary %d/%d\n", checks - failures, checks);
        printf("qc reported\n");
        fflush(stdout);
    });
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    test_layers();
    test_pixel_buffers();
    test_pool();
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [RingController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
