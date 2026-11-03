// AVFoundation capture and editing from Objective-C (AVFoundationObjCTest.app, issue #707). Editing: an AVAssetWriter
// with a pixel buffer adaptor writes a red-then-blue movie; an AVMutableComposition takes ranges of it (CMTimeRange
// through the categories); an AVMutableVideoComposition with an Objective-C custom compositor (it paints every frame
// green) is exported by an AVAssetExportSession, read back by an AVAssetReader (CMSampleBuffer and CVPixelBuffer C
// functions) and composed again by an AVAssetReaderVideoCompositionOutput. Capture: the simulated back camera
// through a session with video data, photo and movie file outputs and their Objective-C delegates.
#import <AVFoundation/AVFoundation.h>
#include <stdio.h>
#include <math.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; BOOL ok_ = (cond); char what_[240]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (ok_) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static void spin(NSTimeInterval seconds) { [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }
static BOOL wait_until(NSTimeInterval limit, BOOL (^cond)(void)) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:limit];
    while (!cond() && [end timeIntervalSinceNow] > 0) spin(0.02);
    return cond();
}

enum { W = 64, H = 48 };
static CVPixelBufferRef make_frame(uint8_t r, uint8_t g, uint8_t b) {
    CVPixelBufferRef pb = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, W, H, kCVPixelFormatType_32BGRA, NULL, &pb);
    CVPixelBufferLockBaseAddress(pb, 0);
    uint8_t *base = CVPixelBufferGetBaseAddress(pb);
    size_t row = CVPixelBufferGetBytesPerRow(pb);
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++) { uint8_t *p = base + y * row + x * 4; p[0] = b; p[1] = g; p[2] = r; p[3] = 255; }
    CVPixelBufferUnlockBaseAddress(pb, 0);
    return pb;
}
/* the BGRA pixel at the middle of a 32BGRA buffer, as "r,g,b" */
static void middle(CVPixelBufferRef pb, int rgb[3]) {
    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    const uint8_t *p = (const uint8_t *)CVPixelBufferGetBaseAddress(pb) + CVPixelBufferGetHeight(pb) / 2 * CVPixelBufferGetBytesPerRow(pb)
                       + CVPixelBufferGetWidth(pb) / 2 * 4;
    rgb[0] = p[2]; rgb[1] = p[1]; rgb[2] = p[0];
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
}
static BOOL is(const int c[3], int r, int g, int b) { return abs(c[0] - r) < 60 && abs(c[1] - g) < 60 && abs(c[2] - b) < 60; }

// MARK: the custom compositor

static int renderContextChanges, requests;
static CMPersistentTrackID lastSourceTrack;
@interface GreenCompositor : NSObject <AVVideoCompositing>
@end
@implementation GreenCompositor
- (NSDictionary<NSString *, id> *)sourcePixelBufferAttributes { return @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}; }
- (NSDictionary<NSString *, id> *)requiredPixelBufferAttributesForRenderContext { return @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}; }
- (void)renderContextChanged:(AVVideoCompositionRenderContext *)ctx { renderContextChanges++; }
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
    requests++;
    NSNumber *track = request.sourceTrackIDs.firstObject;
    lastSourceTrack = track.intValue;
    CVPixelBufferRef src = track ? [request sourceFrameByTrackID:track.intValue] : NULL;
    CVPixelBufferRef out = [request.renderContext newPixelBuffer];
    if (!out || !src || !CMTIME_IS_NUMERIC(request.compositionTime)) {
        if (out) CVPixelBufferRelease(out);
        [request finishWithError:[NSError errorWithDomain:@"GreenCompositor" code:1 userInfo:nil]];
        return;
    }
    CVPixelBufferLockBaseAddress(out, 0);
    uint8_t *base = CVPixelBufferGetBaseAddress(out);
    size_t row = CVPixelBufferGetBytesPerRow(out);
    for (size_t y = 0; y < CVPixelBufferGetHeight(out); y++)
        for (size_t x = 0; x < CVPixelBufferGetWidth(out); x++) { uint8_t *p = base + y * row + x * 4; p[0] = 0; p[1] = 200; p[2] = 0; p[3] = 255; }
    CVPixelBufferUnlockBaseAddress(out, 0);
    [request finishWithComposedVideoFrame:out];
    CVPixelBufferRelease(out);
}
@end

// MARK: capture delegates

@interface FrameCounter : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (atomic) int frames;
@property (atomic) int width, height;
@property (atomic) BOOL onQueue, timed;
@property (nonatomic) dispatch_queue_t queue;
@end
@implementation FrameCounter
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sb fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef img = CMSampleBufferGetImageBuffer(sb);
    if (img) { self.width = (int)CVPixelBufferGetWidth(img); self.height = (int)CVPixelBufferGetHeight(img); }
    self.timed = CMTIME_IS_VALID(CMSampleBufferGetPresentationTimeStamp(sb));
    self.onQueue = dispatch_get_specific((__bridge void *)self) != NULL;
    self.frames++;
}
@end
@interface PhotoTaker : NSObject <AVCapturePhotoCaptureDelegate>
@property NSMutableArray<NSString *> *events;
@property (nullable) AVCapturePhoto *photo;
@end
@implementation PhotoTaker
- (instancetype)init { if ((self = [super init])) _events = [NSMutableArray array]; return self; }
- (void)captureOutput:(AVCapturePhotoOutput *)o willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)s { [_events addObject:@"willBegin"]; }
- (void)captureOutput:(AVCapturePhotoOutput *)o didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    [_events addObject:error ? @"error" : @"photo"]; _photo = photo;
}
- (void)captureOutput:(AVCapturePhotoOutput *)o didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)s error:(NSError *)error {
    [_events addObject:@"finished"];
}
@end
@interface Recorder : NSObject <AVCaptureFileOutputRecordingDelegate>
@property BOOL started, finished;
@property (nullable) NSError *error;
@end
@implementation Recorder
- (void)captureOutput:(AVCaptureFileOutput *)o didStartRecordingToOutputFileAtURL:(NSURL *)url fromConnections:(NSArray<AVCaptureConnection *> *)c { _started = YES; }
- (void)captureOutput:(AVCaptureFileOutput *)o didFinishRecordingToOutputFileAtURL:(NSURL *)url fromConnections:(NSArray<AVCaptureConnection *> *)c
                error:(NSError *)error { _finished = YES; _error = error; }
@end

static NSURL *temp(NSString *name) {
    NSURL *u = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    [[NSFileManager defaultManager] removeItemAtURL:u error:nil];
    return u;
}

static void editing(void) {
    // the writer: 15 red frames, then 15 blue, at 30 fps
    NSURL *movie = temp(@"source.mov");
    NSError *err = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:movie fileType:AVFileTypeQuickTimeMovie error:&err];
    CHECK(writer && !err && [writer.outputFileType isEqual:AVFileTypeQuickTimeMovie], "AVAssetWriter assetWriterWithURL:fileType:error:");
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                   outputSettings:@{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @(W), AVVideoHeightKey: @(H)}];
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                                                                                                  sourcePixelBufferAttributes:nil];
    CHECK(adaptor.assetWriterInput == input && [input.mediaType isEqual:AVMediaTypeVideo], "the adaptor's input");
    CHECK([writer canAddInput:input], "canAddInput:");
    [writer addInput:input];
    CHECK(writer.inputs.count == 1 && [writer startWriting] && writer.status == AVAssetWriterStatusWriting, "startWriting");
    [writer startSessionAtSourceTime:kCMTimeZero];
    CVPixelBufferRef red = make_frame(220, 0, 0), blue = make_frame(0, 0, 220);
    int appended = 0;
    for (int i = 0; i < 30; i++) {
        wait_until(5, ^BOOL{ return input.readyForMoreMediaData; });
        if ([adaptor appendPixelBuffer:i < 15 ? red : blue withPresentationTime:CMTimeMake(i, 30)]) appended++;
    }
    CVPixelBufferRelease(red); CVPixelBufferRelease(blue);
    CHECK(appended == 30, "appendPixelBuffer:withPresentationTime: (%d of 30)", appended);
    [writer endSessionAtSourceTime:CMTimeMake(30, 30)];
    [input markAsFinished];
    __block BOOL written = NO;
    [writer finishWritingWithCompletionHandler:^{ written = YES; }];
    CHECK(wait_until(30, ^BOOL{ return written; }) && writer.status == AVAssetWriterStatusCompleted, "finishWritingWithCompletionHandler: (status %ld)", (long)writer.status);

    // the asset and its track
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:movie options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    CHECK(track && track.trackID > 0 && track.asset == asset, "the written movie's video track (ID %d)", track.trackID);
    CMTimeRange range = track.timeRange;
    CHECK(fabs(CMTimeGetSeconds(range.duration) - 1.0) < 0.1, "AVAssetTrack.timeRange (%.2f s)", CMTimeGetSeconds(range.duration));
    CHECK(CGAffineTransformIsIdentity(track.preferredTransform), "AVAssetTrack.preferredTransform");

    // a composition: the red half twice, then the blue half
    AVMutableComposition *comp = [AVMutableComposition composition];
    AVMutableCompositionTrack *ct = [comp addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    CHECK(ct != nil, "addMutableTrackWithMediaType:preferredTrackID:");
    CMTime half = CMTimeMake(15, 30);
    BOOL ok = [ct insertTimeRange:CMTimeRangeMake(kCMTimeZero, half) ofTrack:track atTime:kCMTimeZero error:&err];
    ok = ok && [ct insertTimeRange:CMTimeRangeMake(kCMTimeZero, half) ofTrack:track atTime:half error:&err];
    ok = ok && [ct insertTimeRange:CMTimeRangeMake(half, half) ofTrack:track atTime:CMTimeMake(30, 30) error:&err];
    CHECK(ok && !err, "insertTimeRange:ofTrack:atTime:error: three times");
    CHECK(fabs(CMTimeGetSeconds(comp.duration) - 1.5) < 0.05, "the composition lasts 1.5 s (%.2f)", CMTimeGetSeconds(comp.duration));
    CHECK(ct.segments.count == 3 && !ct.segments.firstObject.empty && ct.segments.firstObject.sourceTrackID == track.trackID,
          "segments (%lu)", (unsigned long)ct.segments.count);
    CHECK(fabs(CMTimeGetSeconds(ct.timeRange.duration) - 1.5) < 0.05, "the composition track's timeRange");
    [ct insertEmptyTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(3, 30))];
    CHECK(fabs(CMTimeGetSeconds(comp.duration) - 1.6) < 0.05, "insertEmptyTimeRange: (%.2f s)", CMTimeGetSeconds(comp.duration));
    [ct removeTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(3, 30))];
    CHECK(fabs(CMTimeGetSeconds(comp.duration) - 1.5) < 0.05, "removeTimeRange:");
    AVMutableComposition *scaled = [AVMutableComposition composition];
    ok = [scaled insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofAsset:asset atTime:kCMTimeZero error:&err];
    [scaled scaleTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) toDuration:CMTimeMake(2, 1)];
    CHECK(ok && fabs(CMTimeGetSeconds(scaled.duration) - 2.0) < 0.05, "insertTimeRange:ofAsset:atTime:error: and scaleTimeRange:toDuration: (%.2f s)",
          CMTimeGetSeconds(scaled.duration));
    ct.preferredTransform = CGAffineTransformIdentity;

    // an audio mix's parameters
    AVMutableAudioMixInputParameters *params = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:nil];
    params.trackID = 7;
    [params setVolume:0.5 atTime:kCMTimeZero];
    [params setVolumeRampFromStartVolume:0.5 toEndVolume:1 timeRange:CMTimeRangeMake(kCMTimeZero, half)];
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    mix.inputParameters = @[params];
    CHECK(mix.inputParameters.count == 1 && params.trackID == 7, "AVMutableAudioMix and its input parameters");

    // a video composition with an Objective-C compositor
    AVMutableVideoComposition *vc = [AVMutableVideoComposition videoComposition];
    vc.renderSize = CGSizeMake(W, H);
    vc.frameDuration = CMTimeMake(1, 30);
    CHECK(CMTimeCompare(vc.frameDuration, CMTimeMake(1, 30)) == 0 && CGSizeEqualToSize(vc.renderSize, CGSizeMake(W, H)), "frameDuration and renderSize");
    vc.customVideoCompositorClass = [GreenCompositor class];
    CHECK(vc.customVideoCompositorClass == [GreenCompositor class], "customVideoCompositorClass is the Objective-C class");
    AVMutableVideoCompositionInstruction *ins = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    ins.timeRange = CMTimeRangeMake(kCMTimeZero, comp.duration);
    CHECK(CMTimeRangeEqual(ins.timeRange, CMTimeRangeMake(kCMTimeZero, comp.duration)), "the instruction's timeRange");
    AVMutableVideoCompositionLayerInstruction *layer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:ct];
    [layer setOpacity:1 atTime:kCMTimeZero];
    [layer setTransform:CGAffineTransformIdentity atTime:kCMTimeZero];
    [layer setOpacityRampFromStartOpacity:1 toEndOpacity:1 timeRange:CMTimeRangeMake(kCMTimeZero, half)];
    [layer setTransformRampFromStartTransform:CGAffineTransformIdentity toEndTransform:CGAffineTransformIdentity timeRange:CMTimeRangeMake(kCMTimeZero, half)];
    [layer setCropRectangle:CGRectMake(0, 0, W, H) atTime:kCMTimeZero];
    CHECK(layer.trackID == ct.trackID, "videoCompositionLayerInstructionWithAssetTrack: (track %d)", layer.trackID);
    ins.layerInstructions = @[layer];
    vc.instructions = @[ins];
    CHECK(vc.instructions.count == 1 && [(id)vc.instructions.firstObject layerInstructions].count == 1, "instructions");

    // export through the compositor
    NSArray<NSString *> *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:comp];
    CHECK([presets containsObject:AVAssetExportPresetHighestQuality] && [[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset640x480],
          "export presets");
    AVAssetExportSession *ex = [AVAssetExportSession exportSessionWithAsset:comp presetName:AVAssetExportPresetHighestQuality];
    NSURL *exported = temp(@"exported.mov");
    ex.outputURL = exported;
    ex.outputFileType = AVFileTypeQuickTimeMovie;
    ex.videoComposition = vc;
    ex.timeRange = CMTimeRangeMake(kCMTimeZero, comp.duration);
    CHECK(CMTimeRangeEqual(ex.timeRange, CMTimeRangeMake(kCMTimeZero, comp.duration)) && [ex.supportedFileTypes containsObject:AVFileTypeQuickTimeMovie],
          "the export session's timeRange and file types");
    __block BOOL exportedDone = NO;
    [ex exportAsynchronouslyWithCompletionHandler:^{ exportedDone = YES; }];
    CHECK(wait_until(60, ^BOOL{ return exportedDone; }) && ex.status == AVAssetExportSessionStatusCompleted,
          "exportAsynchronouslyWithCompletionHandler: (status %ld, %s)", (long)ex.status, ex.error.localizedDescription.UTF8String ?: "");
    CHECK(requests > 0 && renderContextChanges > 0 && lastSourceTrack == ct.trackID, "the compositor rendered (%d requests, track %d)", requests, lastSourceTrack);
    CHECK([ex.customVideoCompositor isKindOfClass:[GreenCompositor class]], "customVideoCompositor is the Objective-C object");

    // read the export back
    AVURLAsset *out = [AVURLAsset URLAssetWithURL:exported options:nil];
    AVAssetTrack *outTrack = [out tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:out error:&err];
    AVAssetReaderTrackOutput *ro = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:outTrack
                                                                              outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
    CHECK(reader && outTrack && [reader canAddOutput:ro], "AVAssetReader and a track output");
    [reader addOutput:ro];
    reader.timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    CHECK([reader startReading] && reader.status == AVAssetReaderStatusReading, "startReading");
    int frames = 0, green = 0; double lastPTS = -1; BOOL ordered = YES;
    CMSampleBufferRef sb;
    while ((sb = [ro copyNextSampleBuffer])) {
        CVImageBufferRef img = CMSampleBufferGetImageBuffer(sb);
        double pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb));
        if (pts <= lastPTS) ordered = NO;
        lastPTS = pts;
        if (img) { int c[3]; middle(img, c); if (is(c, 0, 200, 0)) green++; }
        frames++;
        CFRelease(sb);
    }
    CHECK(frames >= 40 && green == frames && ordered, "copyNextSampleBuffer: %d frames, %d green, in order", frames, green);
    CHECK(reader.status == AVAssetReaderStatusCompleted, "the reader completed (%ld)", (long)reader.status);

    // compose again while reading
    AVAssetReader *r2 = [AVAssetReader assetReaderWithAsset:comp error:&err];
    AVAssetReaderVideoCompositionOutput *vo = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:@[ct]
                                                   videoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
    vo.videoComposition = vc;
    [r2 addOutput:vo];
    [r2 startReading];
    int composed = 0, composedGreen = 0;
    while ((sb = [vo copyNextSampleBuffer])) {
        CVImageBufferRef img = CMSampleBufferGetImageBuffer(sb);
        if (img) { int c[3]; middle(img, c); if (is(c, 0, 200, 0)) composedGreen++; }
        composed++;
        CFRelease(sb);
    }
    CHECK(composed >= 40 && composedGreen == composed, "AVAssetReaderVideoCompositionOutput: %d frames, %d green", composed, composedGreen);
    CHECK([vo.customVideoCompositor isKindOfClass:[GreenCompositor class]], "the reader output's customVideoCompositor");
}

static void capture(void) {
    __block int granted = -1;
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL ok) { granted = ok; }];
    CHECK(wait_until(10, ^BOOL{ return granted >= 0; }) && granted == 1, "requestAccessForMediaType:completionHandler:");
    CHECK([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusAuthorized, "camera access is authorized");
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionBack];
    CHECK(camera && camera.position == AVCaptureDevicePositionBack && [camera hasMediaType:AVMediaTypeVideo] && camera.localizedName.length,
          "defaultDeviceWithDeviceType:mediaType:position: (%s)", camera.localizedName.UTF8String ?: "none");
    AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                                                        mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    CHECK(discovery.devices.count >= 2, "a discovery session finds the back and front cameras (%lu)", (unsigned long)discovery.devices.count);
    CHECK(camera.formats.count > 0 && camera.activeFormat.highResolutionStillImageDimensions.width > 0, "formats and highResolutionStillImageDimensions (%dx%d)",
          camera.activeFormat.highResolutionStillImageDimensions.width, camera.activeFormat.highResolutionStillImageDimensions.height);
    NSError *err = nil;
    CHECK([camera lockForConfiguration:&err], "lockForConfiguration:");
    camera.activeVideoMinFrameDuration = CMTimeMake(1, 15);
    CHECK(CMTimeCompare(camera.activeVideoMinFrameDuration, CMTimeMake(1, 15)) == 0, "activeVideoMinFrameDuration (%lld/%d)",
          camera.activeVideoMinFrameDuration.value, camera.activeVideoMinFrameDuration.timescale);
    CHECK(CMTIME_IS_VALID(camera.exposureDuration), "exposureDuration");
    __block BOOL biased = NO;
    [camera setExposureTargetBias:0.5 completionHandler:^(CMTime sync) { biased = CMTIME_IS_VALID(sync); }];
    CHECK(wait_until(5, ^BOOL{ return biased; }) && fabsf(camera.exposureTargetBias - 0.5f) < 0.01f, "setExposureTargetBias:completionHandler:");
    [camera unlockForConfiguration];

    AVCaptureSession *session = [AVCaptureSession new];
    [session beginConfiguration];
    session.sessionPreset = AVCaptureSessionPresetHigh;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&err];
    CHECK(input && input.device == camera && [session canAddInput:input], "deviceInputWithDevice:error:");
    [session addInput:input];
    AVCaptureVideoDataOutput *video = [AVCaptureVideoDataOutput new];
    video.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    FrameCounter *counter = [FrameCounter new];
    dispatch_queue_t q = dispatch_queue_create("frames", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(q, (__bridge void *)counter, (void *)1, NULL);
    [video setSampleBufferDelegate:counter queue:q];
    CHECK(video.sampleBufferDelegate == counter && video.sampleBufferCallbackQueue == q, "setSampleBufferDelegate:queue:");
    AVCapturePhotoOutput *photos = [AVCapturePhotoOutput new];
    AVCaptureMovieFileOutput *movies = [AVCaptureMovieFileOutput new];
    CHECK([session canAddOutput:video] && [session canAddOutput:photos], "canAddOutput:");
    [session addOutput:video];
    [session addOutput:photos];
    [session addOutput:movies];
    [session commitConfiguration];
    CHECK(session.inputs.count == 1 && session.outputs.count == 3 && [video connectionWithMediaType:AVMediaTypeVideo] != nil, "the session's inputs, outputs, connections");
    AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:session];
    preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    CHECK(preview.session == session && [preview.videoGravity isEqual:AVLayerVideoGravityResizeAspectFill], "AVCaptureVideoPreviewLayer");
    [session startRunning];
    CHECK(session.running, "startRunning");

    CHECK(wait_until(10, ^BOOL{ return counter.frames >= 3; }), "captureOutput:didOutputSampleBuffer:fromConnection: (%d frames)", counter.frames);
    CHECK(counter.width > 0 && counter.height > 0 && counter.timed && counter.onQueue, "the frames: %dx%d, timed, on the delegate's queue",
          counter.width, counter.height);

    PhotoTaker *taker = [PhotoTaker new];
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeJPEG}];
    settings.maxPhotoDimensions = photos.maxPhotoDimensions;
    CHECK(settings.maxPhotoDimensions.width == photos.maxPhotoDimensions.width && settings.uniqueID > 0, "photo settings and maxPhotoDimensions (%dx%d)",
          settings.maxPhotoDimensions.width, settings.maxPhotoDimensions.height);
    [photos capturePhotoWithSettings:settings delegate:taker];
    CHECK(wait_until(20, ^BOOL{ return [taker.events containsObject:@"finished"]; }), "the photo delegate (%s)", [taker.events componentsJoinedByString:@","].UTF8String);
    AVCapturePhoto *photo = taker.photo;
    NSData *jpeg = [photo fileDataRepresentation];
    CHECK(photo && jpeg.length > 100 && ((const uint8_t *)jpeg.bytes)[0] == 0xFF && ((const uint8_t *)jpeg.bytes)[1] == 0xD8,
          "didFinishProcessingPhoto: and fileDataRepresentation (%lu bytes of JPEG)", (unsigned long)jpeg.length);
    CHECK(photo.resolvedSettings.photoDimensions.width > 0 && CMTIME_IS_VALID(photo.timestamp), "resolvedSettings.photoDimensions (%dx%d) and timestamp",
          photo.resolvedSettings.photoDimensions.width, photo.resolvedSettings.photoDimensions.height);

    Recorder *rec = [Recorder new];
    NSURL *movie = temp(@"captured.mov");
    [movies startRecordingToOutputFileURL:movie recordingDelegate:rec];
    CHECK(wait_until(10, ^BOOL{ return rec.started; }) && movies.recording, "startRecordingToOutputFileURL:recordingDelegate:");
    wait_until(10, ^BOOL{ return CMTimeGetSeconds(movies.recordedDuration) >= 1.0; });
    CHECK(CMTimeGetSeconds(movies.recordedDuration) >= 1.0, "recordedDuration (%.2f s)", CMTimeGetSeconds(movies.recordedDuration));
    [movies stopRecording];
    CHECK(wait_until(30, ^BOOL{ return rec.finished; }) && !rec.error, "didFinishRecordingToOutputFileAtURL: (finished %d, %s)", rec.finished, rec.error.localizedDescription.UTF8String ?: "no error");
    AVAssetTrack *t = [[AVURLAsset URLAssetWithURL:movie options:nil] tracksWithMediaType:AVMediaTypeVideo].firstObject;
    CHECK(t && CMTimeGetSeconds(t.timeRange.duration) > 0.5, "the recorded movie has video (%.2f s)", CMTimeGetSeconds(t.timeRange.duration));

    [session stopRunning];
    CHECK(!session.running, "stopRunning");
}

int main(int argc, char **argv) {
    @autoreleasepool {
        editing();
        capture();
        printf("AVFoundation Objective-C: %d/%d passed\n", checks - failures, checks);
        fflush(stdout);
        return failures ? 1 : 0;
    }
}
