// ReplayKit from Objective-C (ReplayKitTest.app, issue #385): the shared recorder and its properties (Apple's
// selectors), a declined recording (ISIM_REPLAYKIT_PERMISSION=deny: RPRecordingErrorUserDeclined), stopping when not
// recording, the broadcast sheet (no services on isim), the system broadcast picker, RPBroadcastConfiguration's
// secure coding and the error domain and keys.
#import <ReplayKit/ReplayKit.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

/* runs the main run loop until *flag is set (or 5 s) */
static void wait_for(volatile BOOL *flag) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!*flag && [end timeIntervalSinceNow] > 0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

int main(void) {
    @autoreleasepool {
        RPScreenRecorder *r = [RPScreenRecorder sharedRecorder];
        CHECK(r == [RPScreenRecorder sharedRecorder], "+sharedRecorder is shared");
        CHECK(r.available && !r.recording, "available, not recording");
        r.microphoneEnabled = YES; r.cameraEnabled = YES; r.cameraPosition = RPCameraPositionBack;
        CHECK(r.isMicrophoneEnabled && r.isCameraEnabled && r.cameraPosition == RPCameraPositionBack && r.cameraPreviewView == nil,
              "microphoneEnabled, cameraEnabled, cameraPosition; no camera preview before recording");
        r.microphoneEnabled = NO; r.cameraEnabled = NO;

        __block NSError *startError = nil; __block volatile BOOL started = NO;
        [r startRecordingWithHandler:^(NSError *error) { startError = error; started = YES; }];
        wait_for(&started);
        CHECK(started && [startError.domain isEqualToString:RPRecordingErrorDomain] && startError.code == RPRecordingErrorUserDeclined,
              "a declined recording: RPRecordingErrorUserDeclined (%ld)", (long)startError.code);

        __block NSError *stopError = nil; __block volatile BOOL stopped = NO;
        [r stopRecordingWithHandler:^(RPPreviewViewController *preview, NSError *error) { stopError = error; stopped = YES; }];
        wait_for(&stopped);
        CHECK(stopError.code == RPRecordingErrorAttemptToStopNonRecording, "stopping when not recording (%ld)", (long)stopError.code);
        __block volatile BOOL capStopped = NO; __block NSError *capError = nil;
        [r stopCaptureWithHandler:^(NSError *error) { capError = error; capStopped = YES; }];
        wait_for(&capStopped);
        CHECK(capError.code == RPRecordingErrorAttemptToStopNonRecording, "stopping a capture that is not running");

        __block RPBroadcastActivityViewController *sheet = nil; __block volatile BOOL loaded = NO;
        [RPBroadcastActivityViewController loadBroadcastActivityViewControllerWithPreferredExtension:@"com.example.broadcast"
            handler:^(RPBroadcastActivityViewController *vc, NSError *error) { sheet = vc; loaded = YES; }];
        wait_for(&loaded);
        CHECK(sheet != nil && sheet.delegate == nil, "the broadcast sheet loads (it lists no services)");

        RPSystemBroadcastPickerView *picker = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        picker.preferredExtension = @"com.example.broadcast"; picker.showsMicrophoneButton = NO;
        CHECK([picker.preferredExtension isEqualToString:@"com.example.broadcast"] && !picker.showsMicrophoneButton && picker.subviews.count == 1,
              "RPSystemBroadcastPickerView: preferredExtension, showsMicrophoneButton, its button");

        RPBroadcastConfiguration *config = [RPBroadcastConfiguration new];
        config.clipDuration = 7.5;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:config requiringSecureCoding:YES error:NULL];
        RPBroadcastConfiguration *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[RPBroadcastConfiguration class] fromData:data error:NULL];
        CHECK(back.clipDuration == 7.5, "RPBroadcastConfiguration secure coding (%g)", back.clipDuration);

        CHECK([RPRecordingErrorDomain isEqualToString:@"com.apple.ReplayKit.RPRecordingErrorDomain"] && RPVideoSampleOrientationKey.length > 0 &&
              RPApplicationInfoBundleIdentifierKey.length > 0 && [[RPBroadcastSampleHandler new] isKindOfClass:[RPBroadcastHandler class]],
              "the error domain, the keys, the broadcast handler classes");
        printf("replaykit: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
