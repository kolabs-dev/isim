// The Camera Control, capture events, depth output, synchronizer and system pressure from Objective-C
// (CaptureControlsObjCTest.app, issue #811), on an iPhone 16 Pro with the simulated dual wide camera. The test drives
// the controls with the `cameracontrol` script command and reads the log ("ControlsObjC: ...").
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

static void say(NSString *s) { NSLog(@"ControlsObjC: %@", s); }

@interface TestViewController : UIViewController <AVCaptureSessionControlsDelegate, AVCaptureDepthDataOutputDelegate, AVCaptureDataOutputSynchronizerDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *camera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *video;
@property (nonatomic, strong) AVCaptureDepthDataOutput *depth;
@property (nonatomic, strong) AVCaptureDataOutputSynchronizer *sync;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (atomic) BOOL depthSeen, syncSeen;
@end

@implementation TestViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.queue = dispatch_queue_create("capture", DISPATCH_QUEUE_SERIAL);
    self.camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualWideCamera mediaType:AVMediaTypeVideo
                                                      position:AVCaptureDevicePositionBack];
    AVCaptureSystemPressureState *p = self.camera.systemPressureState;
    say([NSString stringWithFormat:@"camera %@ depthFormats=%lu pressure %@ factors=%lu", self.camera.localizedName,
         (unsigned long)self.camera.activeFormat.supportedDepthDataFormats.count, p.level, (unsigned long)p.factors]);
    [self.camera addObserver:self forKeyPath:@"systemPressureState" options:NSKeyValueObservingOptionNew context:NULL];

    // capture events
    AVCaptureEventInteraction *events = [[AVCaptureEventInteraction alloc] initWithPrimaryEventHandler:^(AVCaptureEvent *e) {
        say([NSString stringWithFormat:@"capture event primary %@", e.phase == AVCaptureEventPhaseBegan ? @"began" : e.phase == AVCaptureEventPhaseEnded ? @"ended" : @"cancelled"]);
    } secondaryEventHandler:^(AVCaptureEvent *e) {
        say([NSString stringWithFormat:@"capture event secondary %@", e.phase == AVCaptureEventPhaseBegan ? @"began" : @"ended"]);
    }];
    say([NSString stringWithFormat:@"interaction enabled=%d", events.enabled]);
    [self.view addInteraction:events];

    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(self.queue, ^{ [self configure]; });
    }];
}
- (void)configure {
    AVCaptureSession *s = [AVCaptureSession new];
    self.session = s;
    [s beginConfiguration];
    NSError *err = nil;
    AVCaptureDeviceInput *in = [AVCaptureDeviceInput deviceInputWithDevice:self.camera error:&err];
    if (in && [s canAddInput:in]) [s addInput:in];
    self.video = [AVCaptureVideoDataOutput new];
    self.video.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    self.depth = [AVCaptureDepthDataOutput new];
    self.depth.filteringEnabled = YES;
    for (AVCaptureOutput *o in @[self.video, self.depth]) if ([s canAddOutput:o]) [s addOutput:o];
    [self.depth setDelegate:self callbackQueue:self.queue];
    say([NSString stringWithFormat:@"depth output filtering=%d discards=%d delegate=%d connection=%d", self.depth.filteringEnabled,
         self.depth.alwaysDiscardsLateDepthData, self.depth.delegate == self, [self.depth connectionWithMediaType:AVMediaTypeDepthData] != nil]);

    if (@available(iOS 18.0, *)) [self addControls:s];
    [s commitConfiguration];
    [s startRunning];
    say([NSString stringWithFormat:@"running=%d", s.running]);
}

- (void)addControls:(AVCaptureSession *)s API_AVAILABLE(ios(18.0)) {
    // the Camera Control
    say([NSString stringWithFormat:@"controls supported=%d max=%ld", s.supportsControls, (long)s.maxControlsCount]);
    AVCaptureSystemZoomSlider *zoom = [[AVCaptureSystemZoomSlider alloc] initWithDevice:self.camera action:^(CGFloat z) {
        say([NSString stringWithFormat:@"zoom slider %.2f", z]);
    }];
    AVCaptureSystemExposureBiasSlider *bias = [[AVCaptureSystemExposureBiasSlider alloc] initWithDevice:self.camera];
    AVCaptureSlider *intensity = [[AVCaptureSlider alloc] initWithLocalizedTitle:@"Intensity" symbolName:@"dial.medium" minValue:0 maxValue:10 step:1];
    intensity.prominentValues = @[@0, @5, @10];
    [intensity setActionQueue:self.queue action:^(float v) {
        say([NSString stringWithFormat:@"intensity %g on queue %d", v, dispatch_get_specific((__bridge void *)self) != NULL]);
    }];
    dispatch_queue_set_specific(self.queue, (__bridge void *)self, (void *)1, NULL);
    AVCaptureIndexPicker *style = [[AVCaptureIndexPicker alloc] initWithLocalizedTitle:@"Style" symbolName:@"camera.filters"
                                                                  localizedIndexTitles:@[@"Natural", @"Vivid", @"Mono"]];
    __weak AVCaptureIndexPicker *weakStyle = style;
    [style setActionQueue:self.queue action:^(NSInteger i) { say([NSString stringWithFormat:@"style %@", weakStyle.localizedIndexTitles[i]]); }];
    AVCaptureIndexPicker *numbered = [[AVCaptureIndexPicker alloc] initWithLocalizedTitle:@"Lens" symbolName:@"camera" numberOfIndexes:3
                                                                 localizedTitleTransform:^NSString *(NSInteger i) { return [NSString stringWithFormat:@"%ldx", (long)i + 1]; }];
    say([NSString stringWithFormat:@"picker titles %@ count=%ld slider prominent=%lu title=%@", [numbered.localizedIndexTitles componentsJoinedByString:@","],
         (long)numbered.numberOfIndexes, (unsigned long)intensity.prominentValues.count, intensity.localizedTitle]);
    for (AVCaptureControl *c in @[zoom, bias, intensity, style]) if ([s canAddControl:c]) [s addControl:c];
    [s setControlsDelegate:self queue:self.queue];
    say([NSString stringWithFormat:@"controls count=%lu delegate=%d", (unsigned long)s.controls.count, s.controlsDelegate == self]);
}

// MARK: delegates
- (void)sessionControlsDidBecomeActive:(AVCaptureSession *)session { say(@"controls active"); }
- (void)sessionControlsWillEnterFullscreenAppearance:(AVCaptureSession *)session { say(@"controls fullscreen"); }
- (void)sessionControlsWillExitFullscreenAppearance:(AVCaptureSession *)session { say(@"controls exit fullscreen"); }
- (void)sessionControlsDidBecomeInactive:(AVCaptureSession *)session { say(@"controls inactive"); }
- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output didOutputDepthData:(AVDepthData *)depthData timestamp:(CMTime)timestamp
             connection:(AVCaptureConnection *)connection {
    if (self.depthSeen) return;
    self.depthSeen = YES;
    CVPixelBufferRef map = depthData.depthDataMap;
    AVDepthData *disparity = [depthData depthDataByConvertingToDepthDataType:kCVPixelFormatType_DisparityFloat32];
    say([NSString stringWithFormat:@"depth delegate %zux%zu timestamp=%d filtered=%d converted=%d calibration=%d", CVPixelBufferGetWidth(map),
         CVPixelBufferGetHeight(map), CMTIME_IS_VALID(timestamp), depthData.depthDataFiltered,
         disparity.depthDataType == kCVPixelFormatType_DisparityFloat32, depthData.cameraCalibrationData != nil]);
    // now both outputs through a synchronizer
    self.sync = [[AVCaptureDataOutputSynchronizer alloc] initWithDataOutputs:@[self.video, self.depth]];
    [self.sync setDelegate:self queue:self.queue];
    say([NSString stringWithFormat:@"synchronizer outputs=%lu delegate=%d", (unsigned long)self.sync.dataOutputs.count, self.sync.delegate == self]);
}
- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)c {
    if (self.syncSeen) return;
    AVCaptureSynchronizedSampleBufferData *v = (id)[c synchronizedDataForCaptureOutput:self.video];
    AVCaptureSynchronizedDepthData *d = (id)c[self.depth];
    if (!v || !d) return;
    self.syncSeen = YES;
    NSUInteger n = 0;
    for (AVCaptureOutput *o in c) { (void)o; n++; }
    say([NSString stringWithFormat:@"sync video=%d depth=%zu sameTime=%d count=%lu enumerated=%lu dropped=%d", CMSampleBufferGetImageBuffer(v.sampleBuffer) != NULL,
         CVPixelBufferGetWidth(d.depthData.depthDataMap), CMTimeCompare(v.timestamp, d.timestamp) == 0, (unsigned long)c.count, (unsigned long)n,
         v.sampleBufferWasDropped || d.depthDataWasDropped]);
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    AVCaptureSystemPressureState *p = self.camera.systemPressureState;
    say([NSString stringWithFormat:@"pressure %@ factors=%lu serious=%d", p.level, (unsigned long)p.factors, [p.level isEqual:AVCaptureSystemPressureLevelSerious]]);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [TestViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
