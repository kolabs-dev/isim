/* UIImagePickerController's camera and its "Move and Scale" crop screen.
 *
 * Adapted: the camera is isim's simulated camera (ISIM_CAMERA: a picture, a looped video or the host webcam; see
 * host_capture.c), the same one AVFoundation's capture session shows. Without it the camera source is unavailable,
 * like the iOS Simulator. The screen follows iOS's: live preview, shutter, switch camera, PHOTO / VIDEO when the
 * picker's mediaTypes allow both, then Retake / Use Photo (or Use Video); with showsCameraControls = NO only the
 * preview and the cameraOverlayView show and takePicture / startVideoCapture / stopVideoCapture capture directly.
 * No flash (isFlashAvailable is NO). Photos are the newest camera frame; videos are the frames recorded at 30 fps
 * and encoded to H.264 .MOV by ffmpeg (no sound). Camera access is the AVFoundation permission (_ISIMPrivacy.camera,
 * NSCameraUsageDescription, ISIM_CAMERA_PERMISSION=allow|deny). */
#import "UIKitPrivate.h"
#import "UIImagePickerCamera.h"
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

BOOL isim_ui_camera_available(void) { return isim_camera_source(NULL, 0) != 0; }

/* ---------------- camera permission (shared with AVFoundation: AVAuthorizationStatus values) ---------------- */
static NSString *app_display_name(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"App";
}
void isim_ui_camera_request_access(UIViewController *presenter, void (^done)(BOOL)) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    id stored = [ud objectForKey:@"_ISIMPrivacy.camera"];
    if (stored) { done([stored integerValue] == 3); return; }
    NSString *purpose = NSBundle.mainBundle.infoDictionary[@"NSCameraUsageDescription"];
    if (!purpose.length) {
        NSLog(@"isim UIKit: this app has attempted to access privacy-sensitive data without a usage description. The app's Info.plist must contain an NSCameraUsageDescription key with a string value explaining to the user how the app uses this data (iOS would terminate the app; isim reports the access as denied)");
        done(NO); return;
    }
    void (^answer)(BOOL) = ^(BOOL ok) {
        [ud setInteger:ok ? 3 : 2 forKey:@"_ISIMPrivacy.camera"]; [ud synchronize];
        NSLog(@"isim UIKit: camera access %@ for %@", ok ? @"allowed" : @"denied", app_display_name());
        done(ok);
    };
    const char *env = getenv("ISIM_CAMERA_PERMISSION");
    if (env && *env) { NSString *e = @(env).lowercaseString; answer(!([e isEqualToString:@"deny"] || [e isEqualToString:@"denied"] || [e isEqualToString:@"no"] || [e isEqualToString:@"0"])); return; }
    const char *osv = getenv("ISIM_OS_VERSION");
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"“%@” Would Like to Access the Camera", app_display_name()]
                                                               message:purpose preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Don’t Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer(NO); }]];
    [a addAction:[UIAlertAction actionWithTitle:(osv && atoi(osv) < 17) ? @"OK" : @"Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer(YES); }]];
    [presenter presentViewController:a animated:YES completion:nil];
}

/* ---------------- frames ---------------- */
/* a BGRA frame (premultiplied, rows packed) as a UIImage */
static UIImage *image_from_bgra(const unsigned char *px, int w, int h, BOOL mirror) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, (size_t)w * 4, cs, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(cs);
    if (!ctx) return nil;
    unsigned char *dst = CGBitmapContextGetData(ctx);
    size_t bpr = CGBitmapContextGetBytesPerRow(ctx);
    for (int y = 0; y < h; y++) {
        const unsigned char *s = px + (size_t)y * w * 4;
        unsigned char *d = dst + (size_t)y * bpr;
        if (!mirror) memcpy(d, s, (size_t)w * 4);
        else for (int x = 0; x < w; x++) memcpy(d + (size_t)x * 4, s + (size_t)(w - 1 - x) * 4, 4);
    }
    CGImageRef img = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    UIImage *u = img ? [UIImage imageWithCGImage:img] : nil;
    if (img) CGImageRelease(img);
    return u;
}

/* ---------------- the preview ---------------- */
@interface __IsimCameraPreview : UIView
@property (nonatomic) int camera;
@property (nonatomic) BOOL mirrored;
@property (nonatomic, strong, nullable) UIImage *still;      /* a captured photo, shown instead of the feed */
@end
@implementation __IsimCameraPreview
- (void)drawRect:(CGRect)rect {
    [UIColor.blackColor setFill]; UIRectFill(self.bounds);
    if (_still) {
        CGSize s = _still.size; CGRect b = self.bounds;
        CGFloat k = MIN(b.size.width / s.width, b.size.height / s.height);
        CGRect r = CGRectMake(b.origin.x + (b.size.width - s.width * k) / 2, b.origin.y + (b.size.height - s.height * k) / 2, s.width * k, s.height * k);
        [_still drawInRect:r];
        return;
    }
    if (_camera <= 0) return;
    int img = isim_camera_preview(_camera);
    if (img <= 0) return;
    double w = 0, h = 0; isim_image_pixel_size(img, &w, &h);
    if (w <= 0 || h <= 0) return;
    CGRect b = self.bounds;
    CGFloat k = MIN(b.size.width / w, b.size.height / h);        /* aspect fit, like iOS's photo-mode preview */
    CGRect r = CGRectMake((b.size.width - w * k) / 2, (b.size.height - h * k) / 2, w * k, h * k);
    isim_gfx_save();
    if (_mirrored) { isim_gfx_translate(b.size.width, 0); isim_gfx_scale(-1, 1); }
    isim_image_draw(img, r.origin.x, r.origin.y, r.size.width, r.size.height, NULL, 1);
    isim_gfx_restore();
}
@end

/* ---------------- recording ---------------- */
@interface __IsimCameraRecorder : NSObject
- (instancetype)initWithCamera:(int)camera width:(int)w height:(int)h maxSeconds:(double)max;
@property (nonatomic, readonly) double seconds;
@property (nonatomic, copy) void (^onLimit)(void);
- (void)start;
/* encodes on a background queue; calls done on the main queue with the movie URL or an error */
- (void)finishWithQuality:(UIImagePickerControllerQualityType)q done:(void (^)(NSURL *, NSError *))done;
@end
@implementation __IsimCameraRecorder {
    int _cam, _w, _h; double _max; volatile int _running; long _frames; NSString *_raw; pthread_t _thread; BOOL _started;
}
- (instancetype)initWithCamera:(int)camera width:(int)w height:(int)h maxSeconds:(double)max {
    if ((self = [super init])) { _cam = camera; _w = w; _h = h; _max = max > 0 ? max : 600; }
    return self;
}
- (double)seconds { return _frames / 30.0; }
static void *record_loop(void *arg) {
    __IsimCameraRecorder *r = (__bridge __IsimCameraRecorder *)arg;
    [r _loop];
    return NULL;
}
- (void)_loop {
    FILE *f = fopen(_raw.UTF8String, "wb");
    if (!f) return;
    size_t n = (size_t)_w * _h * 4;
    unsigned char *buf = malloc(n);
    long seq = 0;
    while (_running) {
        long s = isim_camera_frame(_cam, buf, seq, 0.2);
        if (s <= 0) continue;
        seq = s;
        fwrite(buf, 1, n, f);
        _frames++;
        if (_frames / 30.0 >= _max) {
            _running = 0;
            dispatch_async(dispatch_get_main_queue(), ^{ if (self.onLimit) self.onLimit(); });
        }
    }
    free(buf);
    fclose(f);
}
- (void)start {
    _raw = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"isim-capture-%@.bgra", NSUUID.UUID.UUIDString]];
    _running = 1; _frames = 0; _started = YES;
    pthread_create(&_thread, NULL, record_loop, (__bridge void *)self);
}
- (void)finishWithQuality:(UIImagePickerControllerQualityType)q done:(void (^)(NSURL *, NSError *))done {
    if (!_started) { done(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:4 userInfo:nil]); return; }
    _running = 0;
    pthread_join(_thread, NULL);
    _started = NO;
    NSString *raw = _raw, *out = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"capturedvideo-%@.MOV", NSUUID.UUID.UUIDString]];
    int w = _w, h = _h; long frames = _frames;
    /* iOS's quality presets: high keeps the camera size; the others scale the longer side */
    int side = q == UIImagePickerControllerQualityTypeMedium ? 480 : q == UIImagePickerControllerQualityTypeLow ? 192 :
               q == UIImagePickerControllerQualityType640x480 ? 640 : q == UIImagePickerControllerQualityTypeIFrame960x540 ? 960 : 0;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;
        if (frames == 0) err = [NSError errorWithDomain:@"AVFoundationErrorDomain" code:-11805 userInfo:@{ NSLocalizedDescriptionKey: @"Cannot Record" }];
        else {
            NSString *size = [NSString stringWithFormat:@"%dx%d", w, h];
            NSString *scale = side > 0 ? (w >= h ? [NSString stringWithFormat:@"scale=%d:-2", side] : [NSString stringWithFormat:@"scale=-2:%d", side]) : @"null";
            NSArray *args = @[@"-y", @"-f", @"rawvideo", @"-pix_fmt", @"bgra", @"-s", size, @"-r", @"30", @"-i", raw,
                              @"-vf", scale, @"-c:v", @"libx264", @"-preset", @"veryfast", @"-pix_fmt", @"yuv420p", @"-f", @"mov", out];
            const char *argv[32]; int n = 0;
            for (NSString *a in args) argv[n++] = a.UTF8String;
            char msg[1024] = "";
            int rc = isim_ffmpeg_run(argv, n, NULL, NULL, msg, sizeof msg);
            if (rc != 0) err = [NSError errorWithDomain:@"AVFoundationErrorDomain" code:-11800
                                               userInfo:@{ NSLocalizedDescriptionKey: rc == -1 ? @"Recording needs ffmpeg" : [NSString stringWithFormat:@"Recording failed: %s", msg] }];
        }
        [NSFileManager.defaultManager removeItemAtPath:raw error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{ done(err ? nil : [NSURL fileURLWithPath:out], err); });
    });
}
@end

/* ---------------- the camera screen ---------------- */
@implementation __IsimCameraController {
    __IsimCameraPreview *_preview;
    UIView *_bottom, *_denied;
    UIButton *_shutter, *_cancel, *_switch, *_retake, *_use, *_photoMode, *_videoMode;
    UILabel *_timer;
    CADisplayLink *_link;
    int _camera, _w, _h;
    BOOL _video, _authorized, _recording;
    __IsimCameraRecorder *_recorder;
    UIImage *_captured; NSURL *_movie; NSDictionary *_metadata;
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIButton *)_button:(NSString *)title ident:(NSString *)ident action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:18];
    b.accessibilityIdentifier = ident;
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _preview = [__IsimCameraPreview new];
    _preview.accessibilityIdentifier = @"camera-preview";
    _preview.mirrored = self.cameraDevice == UIImagePickerControllerCameraDeviceFront;
    [self.view addSubview:_preview];
    _video = self.captureMode == UIImagePickerControllerCameraCaptureModeVideo;
    if (self.overlay) [self.view addSubview:self.overlay];
    if (!self.showsControls) return;
    _bottom = [UIView new];
    _bottom.backgroundColor = UIColor.blackColor;
    [self.view addSubview:_bottom];
    _shutter = [UIButton buttonWithType:UIButtonTypeCustom];
    _shutter.accessibilityIdentifier = @"camera-shutter";
    _shutter.accessibilityLabel = @"Take Picture";
    _shutter.layer.cornerRadius = 33; _shutter.layer.borderWidth = 5; _shutter.layer.borderColor = UIColor.whiteColor.CGColor;
    [_shutter addTarget:self action:@selector(isimShutter) forControlEvents:UIControlEventTouchUpInside];
    [_bottom addSubview:_shutter];
    _cancel = [self _button:@"Cancel" ident:@"camera-cancel" action:@selector(isimCancel)];
    _switch = [self _button:@"⟲" ident:@"camera-switch" action:@selector(isimSwitch)];
    _switch.accessibilityLabel = @"Switch Camera";
    _switch.titleLabel.font = [UIFont systemFontOfSize:28];
    _retake = [self _button:@"Retake" ident:@"camera-retake" action:@selector(isimRetake)];
    _use = [self _button:@"Use Photo" ident:@"camera-use" action:@selector(isimUse)];
    for (UIView *v in @[_cancel, _switch, _retake, _use]) [_bottom addSubview:v];
    if (self.allowsPhoto && self.allowsVideo) {
        _photoMode = [self _button:@"PHOTO" ident:@"camera-mode-photo" action:@selector(isimPhotoMode)];
        _videoMode = [self _button:@"VIDEO" ident:@"camera-mode-video" action:@selector(isimVideoMode)];
        for (UIButton *b in @[_photoMode, _videoMode]) { b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; [_bottom addSubview:b]; }
    }
    _timer = [UILabel new];
    _timer.textColor = UIColor.whiteColor; _timer.textAlignment = NSTextAlignmentCenter;
    _timer.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
    _timer.accessibilityIdentifier = @"camera-timer";
    [self.view addSubview:_timer];
    [self _updateControls];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat barH = self.showsControls ? 150 + safe.bottom : 0;
    CGFloat top = self.showsControls ? MAX(safe.top, 20) + 44 : 0;
    _preview.frame = CGRectMake(0, top, b.size.width, b.size.height - barH - top);
    self.overlay.frame = self.showsControls ? _preview.frame : b;
    _preview.transform = self.previewTransform;
    _bottom.frame = CGRectMake(0, b.size.height - barH, b.size.width, barH);
    _timer.frame = CGRectMake(0, MAX(safe.top, 20) + 6, b.size.width, 32);
    CGFloat cy = 95;
    _shutter.frame = CGRectMake(b.size.width / 2 - 33, cy - 33, 66, 66);
    _cancel.frame = CGRectMake(16, cy - 22, 90, 44);
    _switch.frame = CGRectMake(b.size.width - 72, cy - 22, 56, 44);
    _retake.frame = CGRectMake(16, cy - 22, 90, 44);
    _use.frame = CGRectMake(b.size.width - 136, cy - 22, 120, 44);
    _photoMode.frame = CGRectMake(b.size.width / 2 - 2, 14, 70, 30);
    _videoMode.frame = CGRectMake(b.size.width / 2 - 72, 14, 70, 30);
}
- (void)_updateControls {
    BOOL review = _captured || _movie;
    _shutter.hidden = review;
    _cancel.hidden = review || _recording;
    _switch.hidden = review || _recording;
    _retake.hidden = _use.hidden = !review;
    _photoMode.hidden = _videoMode.hidden = review || _recording;
    [_use setTitle:_movie ? @"Use Video" : @"Use Photo" forState:UIControlStateNormal];
    _shutter.backgroundColor = _video ? UIColor.systemRedColor : UIColor.whiteColor;
    _shutter.layer.cornerRadius = _recording ? 12 : 33;
    [_photoMode setTitleColor:_video ? UIColor.whiteColor : UIColor.systemYellowColor forState:UIControlStateNormal];
    [_videoMode setTitleColor:_video ? UIColor.systemYellowColor : UIColor.whiteColor forState:UIControlStateNormal];
    _timer.hidden = !_video || review;
    if (!_recording && !review) _timer.text = @"00:00:00";
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_camera > 0 || _authorized) return;
    isim_ui_camera_request_access(self, ^(BOOL ok) {
        self->_authorized = ok;
        if (ok) [self _open];
        else [self _showDenied];
    });
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self _close]; }
- (void)_open {
    if (_camera > 0) return;
    _camera = isim_camera_open(1280, 30, &_w, &_h);
    if (_camera <= 0) { NSLog(@"isim UIKit: the simulated camera could not start (see ISIM_CAMERA; needs ffmpeg)"); return; }
    _preview.camera = _camera;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(isimFrame)];
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    NSLog(@"isim UIKit: camera picker preview %dx%d (%@)", _w, _h, self.cameraDevice == UIImagePickerControllerCameraDeviceFront ? @"front" : @"back");
}
- (void)_close {
    [_link invalidate]; _link = nil;
    if (_recording) { _recording = NO; [_recorder finishWithQuality:self.quality done:^(NSURL *u, NSError *e) { if (u) [NSFileManager.defaultManager removeItemAtPath:u.path error:NULL]; }]; }
    if (_camera > 0) { int c = _camera; _camera = 0; _preview.camera = 0; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_global_queue(0, 0), ^{ isim_camera_close(c); }); }
}
- (void)_showDenied {
    _denied = [UIView new];
    _denied.frame = _preview.frame;
    UILabel *l = [UILabel new];
    l.text = @"This app does not have access to your camera.\nYou can enable access in Privacy Settings.";
    l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter; l.textColor = UIColor.whiteColor;
    l.accessibilityIdentifier = @"camera-denied";
    l.frame = CGRectInset(_denied.bounds, 24, 0);
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_denied addSubview:l];
    [self.view addSubview:_denied];
    _shutter.enabled = NO; _switch.enabled = NO;
}
- (void)isimFrame {
    if (!_captured && !_movie) [_preview setNeedsDisplay];
    if (_recording) {
        int s = (int)_recorder.seconds;
        _timer.text = [NSString stringWithFormat:@"%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60];
    }
}
/* the newest frame as a photo, with isim's metadata (adapted: no EXIF from a real sensor) */
- (UIImage *)_grab {
    if (_camera <= 0 || _w <= 0) return nil;
    size_t n = (size_t)_w * _h * 4;
    unsigned char *buf = malloc(n);
    long s = isim_camera_frame(_camera, buf, 0, 1.0);
    UIImage *img = s > 0 ? image_from_bgra(buf, _w, _h, NO) : nil;
    free(buf);
    NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = @"yyyy:MM:dd HH:mm:ss";
    NSString *now = [f stringFromDate:NSDate.date];
    _metadata = @{ @"Orientation": @1, @"PixelWidth": @(_w), @"PixelHeight": @(_h),
                   @"{Exif}": @{ @"PixelXDimension": @(_w), @"PixelYDimension": @(_h), @"DateTimeOriginal": now, @"DateTimeDigitized": now,
                                 @"LensModel": self.cameraDevice == UIImagePickerControllerCameraDeviceFront ? @"isim simulated front camera" : @"isim simulated back camera" },
                   @"{TIFF}": @{ @"Make": @"isim", @"Model": @"simulated camera", @"Orientation": @1, @"DateTime": now } };
    return img;
}
- (void)takePicture {
    if (_video) { NSLog(@"isim UIKit: takePicture in video capture mode does nothing (like iOS)"); return; }
    UIImage *img = [self _grab];
    if (!img) { NSLog(@"isim UIKit: takePicture: no camera frame"); return; }
    NSLog(@"isim UIKit: camera picker took a %dx%d photo", _w, _h);
    if (!self.showsControls) { if (self.onPhoto) self.onPhoto(img, _metadata); return; }   /* custom controls: straight to the delegate */
    _captured = img; _preview.still = img; [_preview setNeedsDisplay];
    [self _updateControls];
}
- (BOOL)startVideoCapture {
    if (!_video || _recording || _camera <= 0) return NO;
    _recorder = [[__IsimCameraRecorder alloc] initWithCamera:_camera width:_w height:_h maxSeconds:self.maxDuration];
    __weak __IsimCameraController *w = self;
    _recorder.onLimit = ^{ [w stopVideoCapture]; };
    [_recorder start];
    _recording = YES;
    NSLog(@"isim UIKit: camera picker started recording");
    [self _updateControls];
    return YES;
}
- (void)stopVideoCapture {
    if (!_recording) return;
    _recording = NO;
    double secs = _recorder.seconds;
    [self _updateControls];
    [_recorder finishWithQuality:self.quality done:^(NSURL *url, NSError *err) {
        if (!url) { NSLog(@"isim UIKit: camera picker recording failed: %@", err.localizedDescription); return; }
        NSLog(@"isim UIKit: camera picker recorded %.1f s to %@", secs, url.lastPathComponent);
        if (!self.showsControls) { if (self.onMovie) self.onMovie(url); return; }
        self->_movie = url;
        [self _updateControls];
    }];
}
- (void)isimShutter {
    if (!_video) [self takePicture];
    else if (_recording) [self stopVideoCapture];
    else [self startVideoCapture];
}
- (void)isimCancel { if (self.onCancel) self.onCancel(); }
- (void)isimRetake {
    if (_movie) [NSFileManager.defaultManager removeItemAtPath:_movie.path error:NULL];
    _captured = nil; _movie = nil; _preview.still = nil;
    [self _updateControls];
}
- (void)isimUse {
    if (_movie) { if (self.onMovie) self.onMovie(_movie); }
    else if (_captured && self.onPhoto) self.onPhoto(_captured, _metadata);
}
- (void)isimSwitch {
    self.cameraDevice = self.cameraDevice == UIImagePickerControllerCameraDeviceFront ? UIImagePickerControllerCameraDeviceRear : UIImagePickerControllerCameraDeviceFront;
    NSLog(@"isim UIKit: camera picker switched to the %@ camera", self.cameraDevice == UIImagePickerControllerCameraDeviceFront ? @"front" : @"back");
}
- (void)setCameraDevice:(UIImagePickerControllerCameraDevice)d { _cameraDevice = d; _preview.mirrored = d == UIImagePickerControllerCameraDeviceFront; [_preview setNeedsDisplay]; }
- (void)setCaptureMode:(UIImagePickerControllerCameraCaptureMode)m {
    _captureMode = m; _video = m == UIImagePickerControllerCameraCaptureModeVideo;
    if (self.isViewLoaded) [self _updateControls];
}
- (void)isimPhotoMode { self.captureMode = UIImagePickerControllerCameraCaptureModePhoto; if (self.onModeChange) self.onModeChange(self.captureMode); }
- (void)isimVideoMode { self.captureMode = UIImagePickerControllerCameraCaptureModeVideo; if (self.onModeChange) self.onModeChange(self.captureMode); }
- (void)setOverlay:(UIView *)o {
    if (_overlay == o) return;
    [_overlay removeFromSuperview]; _overlay = o;
    if (o && self.isViewLoaded) { [self.view insertSubview:o aboveSubview:_preview]; [self.view setNeedsLayout]; }
}
- (void)setPreviewTransform:(CGAffineTransform)t { _previewTransform = t; _preview.transform = t; }
- (instancetype)init { if ((self = [super init])) { _previewTransform = CGAffineTransformIdentity; _showsControls = YES; } return self; }
@end

/* ---------------- Move and Scale ---------------- */
@interface __IsimCropController () <UIScrollViewDelegate>
@end
@implementation __IsimCropController { UIScrollView *_scroll; UIImageView *_imageView; UIView *_frameView; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _scroll = [UIScrollView new];
    _scroll.accessibilityIdentifier = @"crop-scroll";
    _scroll.delegate = self; _scroll.clipsToBounds = NO;
    _scroll.showsHorizontalScrollIndicator = _scroll.showsVerticalScrollIndicator = NO;
    _scroll.alwaysBounceVertical = _scroll.alwaysBounceHorizontal = YES;
    _imageView = [[UIImageView alloc] initWithImage:self.image];
    [_scroll addSubview:_imageView];
    [self.view addSubview:_scroll];
    _frameView = [UIView new];
    _frameView.userInteractionEnabled = NO;
    _frameView.layer.borderColor = UIColor.whiteColor.CGColor; _frameView.layer.borderWidth = 1;
    [self.view addSubview:_frameView];
    UILabel *title = [UILabel new];
    title.text = @"Move and Scale"; title.textColor = UIColor.whiteColor; title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.tag = 501;
    [self.view addSubview:title];
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem], *choose = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:self.cancelTitle ?: @"Cancel" forState:UIControlStateNormal];
    [choose setTitle:@"Choose" forState:UIControlStateNormal];
    for (UIButton *b in @[cancel, choose]) { [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; b.titleLabel.font = [UIFont systemFontOfSize:18]; [self.view addSubview:b]; }
    cancel.accessibilityIdentifier = @"crop-cancel"; choose.accessibilityIdentifier = @"crop-choose";
    cancel.tag = 502; choose.tag = 503;
    [cancel addTarget:self action:@selector(isimCropCancel) forControlEvents:UIControlEventTouchUpInside];
    [choose addTarget:self action:@selector(isimCropChoose) forControlEvents:UIControlEventTouchUpInside];
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)s { return _imageView; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGFloat side = b.size.width;
    CGRect box = CGRectMake(0, (b.size.height - side) / 2, side, side);
    _frameView.frame = box;
    [self.view viewWithTag:501].frame = CGRectMake(0, MAX(self.view.safeAreaInsets.top, 20) + 10, b.size.width, 30);
    CGFloat by = b.size.height - MAX(self.view.safeAreaInsets.bottom, 10) - 60;
    [self.view viewWithTag:502].frame = CGRectMake(16, by, 100, 44);
    [self.view viewWithTag:503].frame = CGRectMake(b.size.width - 116, by, 100, 44);
    if (CGRectEqualToRect(_scroll.frame, box)) return;
    /* the crop square is the scroll view: the image fills it at the minimum zoom (aspect fill), centred */
    _scroll.frame = box;
    CGSize s = self.image.size;
    if (s.width <= 0 || s.height <= 0) return;
    _imageView.transform = CGAffineTransformIdentity;
    _imageView.frame = CGRectMake(0, 0, s.width, s.height);
    _scroll.contentSize = s;
    CGFloat fill = MAX(side / s.width, side / s.height);
    _scroll.minimumZoomScale = fill; _scroll.maximumZoomScale = MAX(fill * 4, 1);
    _scroll.zoomScale = fill;
    _scroll.contentOffset = CGPointMake((s.width * fill - side) / 2, (s.height * fill - side) / 2);
}
/* the square's rect in the image's points */
- (CGRect)cropRect {
    CGFloat z = _scroll.zoomScale > 0 ? _scroll.zoomScale : 1, side = _scroll.bounds.size.width / z;
    CGRect r = CGRectMake(_scroll.contentOffset.x / z, _scroll.contentOffset.y / z, side, side);
    return CGRectIntersection(r, CGRectMake(0, 0, self.image.size.width, self.image.size.height));
}
- (void)isimCropCancel { if (self.onCancel) self.onCancel(); }
- (void)isimCropChoose {
    CGRect r = [self cropRect];
    CGFloat sc = self.image.scale;
    CGImageRef cg = CGImageCreateWithImageInRect(self.image.CGImage, CGRectMake(round(r.origin.x * sc), round(r.origin.y * sc), round(r.size.width * sc), round(r.size.height * sc)));
    UIImage *edited = cg ? [UIImage imageWithCGImage:cg scale:sc orientation:UIImageOrientationUp] : self.image;
    if (cg) CGImageRelease(cg);
    NSLog(@"isim UIKit: Move and Scale chose %@ of %@", NSStringFromCGRect(r), NSStringFromCGSize(self.image.size));
    if (self.onChoose) self.onChoose(edited, r);
}
@end
