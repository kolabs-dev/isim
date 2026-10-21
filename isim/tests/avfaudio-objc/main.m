// AVFAudio from Objective-C (AVFAudioObjCTest.app, issue #553): #import <AVFAudio/AVFAudio.h>, -framework AVFAudio.
// Formats, channel layouts and times; PCM buffers; a converter (buffer to buffer, and a resampling input block) and an
// AAC encode into a compressed buffer; a WAV file written and read back; an engine in offline manual rendering (player
// node, EQ, reverb, a source node and a 3D environment node); an AVAudioPlayer playing the file to its delegate; an
// AVAudioRecorder recording the microphone input (ISIM_AUDIO_INPUT) for a moment. Results go to the log ("AVFAudioObjC: ...").
#import <UIKit/UIKit.h>
#import <AVFAudio/AVFAudio.h>
#include <math.h>

static void say(NSString *s) { NSLog(@"AVFAudioObjC: %@", s); }

static float peak(AVAudioPCMBuffer *b) {
    float p = 0;
    for (AVAudioFrameCount i = 0; i < b.frameLength; i++) p = fmaxf(p, fabsf(b.floatChannelData[0][i]));
    return p;
}
/// a 440 Hz sine, Float32 deinterleaved
static AVAudioPCMBuffer *sine(AVAudioFormat *f, AVAudioFrameCount n) {
    AVAudioPCMBuffer *b = [[AVAudioPCMBuffer alloc] initWithPCMFormat:f frameCapacity:n];
    for (AVAudioChannelCount c = 0; c < f.channelCount; c++)
        for (AVAudioFrameCount i = 0; i < n; i++) b.floatChannelData[c][i] = 0.5f * sinf(2 * (float)M_PI * 440 * i / (float)f.sampleRate);
    b.frameLength = n;
    return b;
}

@interface TestViewController : UIViewController <AVAudioPlayerDelegate, AVAudioRecorderDelegate>
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSURL *wav;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self formats];
    [self conversion];
    [self file];
    [self engine];
    [self playFile];
}

- (void)formats {
    AVAudioFormat *std = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    AVAudioFormat *i16 = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:44100 channels:1 interleaved:YES];
    AVAudioChannelLayout *quad = [AVAudioChannelLayout layoutWithLayoutTag:kAudioChannelLayoutTag_Quadraphonic];
    AVAudioFormat *q = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channelLayout:quad];
    AVAudioFormat *fromSettings = [[AVAudioFormat alloc] initWithSettings:i16.settings];
    say([NSString stringWithFormat:@"format standard %d common %lu interleaved %d; int16 common %lu bytes %u; quad channels %u; settings equal %d rate %@",
         std.isStandard, (unsigned long)std.commonFormat, std.isInterleaved, (unsigned long)i16.commonFormat, i16.streamDescription->mBytesPerFrame,
         q.channelCount, [fromSettings isEqual:i16], i16.settings[AVSampleRateKey]]);

    AVAudioTime *t = [AVAudioTime timeWithSampleTime:48000 atRate:48000];
    AVAudioTime *anchor = [AVAudioTime timeWithHostTime:[AVAudioTime hostTimeForSeconds:10] sampleTime:0 atRate:48000];
    AVAudioTime *x = [t extrapolateTimeFromAnchor:anchor];
    say([NSString stringWithFormat:@"time sample %lld valid %d host %d extrapolated %.1f s", t.sampleTime, t.isSampleTimeValid, t.isHostTimeValid,
         [AVAudioTime secondsForHostTime:x.hostTime]]);

    AVAudioPCMBuffer *b = sine(std, 4800);
    AVAudioPCMBuffer *copy = [b copy];
    say([NSString stringWithFormat:@"buffer capacity %u length %u stride %lu buffers %u peak %.2f copy %u", b.frameCapacity, b.frameLength,
         (unsigned long)b.stride, b.audioBufferList->mNumberBuffers, peak(b), copy.frameLength]);
}

- (void)conversion {
    AVAudioFormat *f32 = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    AVAudioFormat *i16 = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:48000 channels:1 interleaved:YES];
    AVAudioConverter *c = [[AVAudioConverter alloc] initFromFormat:f32 toFormat:i16];
    AVAudioPCMBuffer *in = sine(f32, 480), *out = [[AVAudioPCMBuffer alloc] initWithPCMFormat:i16 frameCapacity:480];
    NSError *err = nil;
    c.primeMethod = AVAudioConverterPrimeMethod_Pre;
    BOOL ok = [c convertToBuffer:out fromBuffer:in error:&err];
    int16_t top = 0;
    for (AVAudioFrameCount i = 0; i < out.frameLength; i++) if (out.int16ChannelData[0][i] > top) top = out.int16ChannelData[0][i];
    say([NSString stringWithFormat:@"convert %d frames %u int16 peak %d prime %ld", ok, out.frameLength, top, (long)c.primeMethod]);

    /* resampling 48 kHz to 44.1 kHz through the input block */
    AVAudioFormat *f44 = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];
    AVAudioConverter *r = [[AVAudioConverter alloc] initFromFormat:f32 toFormat:f44];
    __block BOOL given = NO;
    AVAudioPCMBuffer *second = sine(f32, 48000), *res = [[AVAudioPCMBuffer alloc] initWithPCMFormat:f44 frameCapacity:44100];
    AVAudioConverterOutputStatus st = [r convertToBuffer:res error:&err withInputFromBlock:^AVAudioBuffer *(AVAudioPacketCount n, AVAudioConverterInputStatus *s) {
        if (given) { *s = AVAudioConverterInputStatus_EndOfStream; return nil; }
        given = YES; *s = AVAudioConverterInputStatus_HaveData; return second;
    }];
    say([NSString stringWithFormat:@"resample status %ld frames %u", (long)st, res.frameLength]);

    /* AAC: packets in a compressed buffer */
    AudioStreamBasicDescription aac = {48000, kAudioFormatMPEG4AAC, 0, 0, 1024, 0, 1, 0, 0};
    AVAudioFormat *af = [[AVAudioFormat alloc] initWithStreamDescription:&aac];
    AVAudioConverter *enc = [[AVAudioConverter alloc] initFromFormat:f32 toFormat:af];
    AVAudioCompressedBuffer *cb = [[AVAudioCompressedBuffer alloc] initWithFormat:af packetCapacity:8 maximumPacketSize:enc.maximumOutputPacketSize];
    __block BOOL fed = NO;
    AVAudioConverterOutputStatus es = [enc convertToBuffer:cb error:&err withInputFromBlock:^AVAudioBuffer *(AVAudioPacketCount n, AVAudioConverterInputStatus *s) {
        if (fed) { *s = AVAudioConverterInputStatus_NoDataNow; return nil; }
        fed = YES; *s = AVAudioConverterInputStatus_HaveData; return second;
    }];
    say([NSString stringWithFormat:@"aac status %ld packets %u bytes %@ descriptions %@ bitrates %@", (long)es, cb.packetCount,
         cb.byteLength > 0 ? @"yes" : @"no", cb.packetDescriptions ? @"yes" : @"no", enc.availableEncodeBitRates.count ? @"yes" : @"no"]);
}

- (void)file {
    self.wav = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"tone.wav"]];
    NSDictionary *settings = @{ AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @48000, AVNumberOfChannelsKey: @1,
                                AVLinearPCMBitDepthKey: @16, AVLinearPCMIsFloatKey: @NO };
    NSError *err = nil;
    AVAudioFile *w = [[AVAudioFile alloc] initForWriting:self.wav settings:settings commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&err];
    BOOL wrote = [w writeFromBuffer:sine(w.processingFormat, 24000) error:&err];
    [w close];
    AVAudioFile *r = [[AVAudioFile alloc] initForReading:self.wav error:&err];
    AVAudioPCMBuffer *b = [[AVAudioPCMBuffer alloc] initWithPCMFormat:r.processingFormat frameCapacity:(AVAudioFrameCount)r.length];
    BOOL read = [r readIntoBuffer:b error:&err];
    say([NSString stringWithFormat:@"file wrote %d read %d length %lld frames %u position %lld rate %.0f peak %.2f error %@", wrote, read, r.length,
         b.frameLength, r.framePosition, r.fileFormat.sampleRate, peak(b), err ? err.domain : @"none"]);
    AVAudioFile *missing = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:@"/nonexistent.wav"] error:&err];
    say([NSString stringWithFormat:@"missing file %@ error %@", missing ? @"opened" : @"refused", err ? @"yes" : @"no"]);
}

/// an offline graph: player -> EQ -> reverb -> main mixer, a source node, and a player in a 3D environment
- (void)engine {
    AVAudioEngine *e = [[AVAudioEngine alloc] init];
    AVAudioFormat *f = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    NSError *err = nil;
    BOOL manual = [e enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline format:f maximumFrameCount:4800 error:&err];
    AVAudioPlayerNode *p = [[AVAudioPlayerNode alloc] init];
    AVAudioUnitEQ *eq = [[AVAudioUnitEQ alloc] initWithNumberOfBands:1];
    eq.bands[0].filterType = AVAudioUnitEQFilterTypeLowPass;
    eq.bands[0].frequency = 2000;
    eq.bands[0].bypass = NO;
    AVAudioUnitReverb *rv = [[AVAudioUnitReverb alloc] init];
    [rv loadFactoryPreset:AVAudioUnitReverbPresetMediumHall];
    rv.wetDryMix = 30;
    for (AVAudioNode *n in @[p, eq, rv]) [e attachNode:n];
    [e connect:p to:eq format:f];
    [e connect:eq to:rv format:f];
    [e connect:rv to:e.mainMixerNode format:f];
    __block int sourceCalls = 0;
    AVAudioSourceNode *src = [[AVAudioSourceNode alloc] initWithFormat:f renderBlock:^OSStatus(BOOL *silence, const AudioTimeStamp *ts, AVAudioFrameCount n, AudioBufferList *out) {
        sourceCalls++;
        for (UInt32 k = 0; k < out->mNumberBuffers; k++) memset(out->mBuffers[k].mData, 0, out->mBuffers[k].mDataByteSize);
        *silence = YES;
        return noErr;
    }];
    [e attachNode:src];
    [e connect:src to:e.mainMixerNode format:f];

    AVAudioEnvironmentNode *env = [[AVAudioEnvironmentNode alloc] init];
    AVAudioPlayerNode *p3 = [[AVAudioPlayerNode alloc] init];
    AVAudioFormat *mono = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    [e attachNode:env];
    [e attachNode:p3];
    [e connect:p3 to:env format:mono];
    [e connect:env to:e.mainMixerNode format:f];
    env.listenerPosition = AVAudioMake3DPoint(0, 0, 0);
    env.listenerAngularOrientation = AVAudioMake3DAngularOrientation(90, 0, 0);
    env.distanceAttenuationParameters.distanceAttenuationModel = AVAudioEnvironmentDistanceAttenuationModelLinear;
    env.outputType = AVAudioEnvironmentOutputTypeHeadphones;
    [env.reverbParameters loadFactoryReverbPreset:AVAudioUnitReverbPresetSmallRoom];
    p3.position = AVAudioMake3DPoint(2, 0, -1);
    p3.renderingAlgorithm = AVAudio3DMixingRenderingAlgorithmHRTF;
    p3.sourceMode = AVAudio3DMixingSourceModePointSource;
    say([NSString stringWithFormat:@"environment listener %.0f,%.0f,%.0f yaw %.0f forward %.1f model %ld output %ld position %.0f,%.0f,%.0f algorithm %ld mode %ld",
         env.listenerPosition.x, env.listenerPosition.y, env.listenerPosition.z, env.listenerAngularOrientation.yaw,
         env.listenerVectorOrientation.forward.x, (long)env.distanceAttenuationParameters.distanceAttenuationModel, (long)env.outputType,
         p3.position.x, p3.position.y, p3.position.z, (long)p3.renderingAlgorithm, (long)p3.sourceMode]);

    __block NSString *done = @"no";
    [p scheduleBuffer:sine(f, 9600) atTime:nil options:0 completionCallbackType:AVAudioPlayerNodeCompletionDataConsumed
    completionHandler:^(AVAudioPlayerNodeCompletionCallbackType t) { done = [NSString stringWithFormat:@"type %ld", (long)t]; }];
    [p3 scheduleBuffer:sine(mono, 9600) completionHandler:nil];
    BOOL started = [e startAndReturnError:&err];
    [p play];
    [p3 play];
    AVAudioPCMBuffer *out = [[AVAudioPCMBuffer alloc] initWithPCMFormat:e.manualRenderingFormat frameCapacity:e.manualRenderingMaximumFrameCount];
    float loud = 0;
    AVAudioEngineManualRenderingStatus status = AVAudioEngineManualRenderingStatusError;
    for (int i = 0; i < 3; i++) {
        status = [e renderOffline:4800 toBuffer:out error:&err];
        loud = fmaxf(loud, peak(out));
    }
    say([NSString stringWithFormat:@"engine manual %d mode %ld started %d running %d status %ld frames %u time %lld audible %d source %@ nodes %lu",
         manual, (long)e.manualRenderingMode, started, e.isRunning, (long)status, out.frameLength, e.manualRenderingSampleTime, loud > 0.05,
         sourceCalls > 0 ? @"yes" : @"no", (unsigned long)e.attachedNodes.count]);
    dispatch_async(dispatch_get_main_queue(), ^{ say([NSString stringWithFormat:@"player node completion %@", done]); });

    AVAudioEngineManualRenderingBlock block = e.manualRenderingBlock;
    OSStatus code = -1;
    AVAudioEngineManualRenderingStatus bs = block(480, out.mutableAudioBufferList, &code);
    AVAudioConnectionPoint *in = [e inputConnectionPointForNode:rv inputBus:0];
    NSArray<AVAudioConnectionPoint *> *outs = [e outputConnectionPointsForNode:p outputBus:0];
    say([NSString stringWithFormat:@"block status %ld code %d; eq input %@ player outputs %lu to %@; eq type %ld", (long)bs, (int)code,
         in.node == eq ? @"eq" : @"?", (unsigned long)outs.count, outs.firstObject.node == eq ? @"eq" : @"?", (long)eq.bands[0].filterType]);
    [e stop];
    [e disableManualRenderingMode];
    e.autoShutdownEnabled = YES;
    AVAudioEngine *idle = [[AVAudioEngine alloc] init];
    NSError *notManual = nil;
    [idle renderOffline:10 toBuffer:out error:&notManual];
    say([NSString stringWithFormat:@"engine stopped running %d manual %d autoShutdown %d; not manual error %ld", e.isRunning, e.isInManualRenderingMode,
         e.isAutoShutdownEnabled, (long)notManual.code]);
}

- (void)playFile {
    NSError *err = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:self.wav error:&err];
    self.player.delegate = self;
    self.player.meteringEnabled = YES;
    self.player.volume = 0.5;
    say([NSString stringWithFormat:@"player duration %.2f channels %lu metering %d prepared %d playing %d", self.player.duration,
         (unsigned long)self.player.numberOfChannels, self.player.isMeteringEnabled, [self.player prepareToPlay], [self.player play]]);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    say([NSString stringWithFormat:@"player finished %d", flag]);
    [self record];
}

- (void)record {
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"clip.wav"]];
    NSError *err = nil;
    AVAudioFormat *f = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    self.recorder = [[AVAudioRecorder alloc] initWithURL:url format:f error:&err];
    self.recorder.delegate = self;
    self.recorder.meteringEnabled = YES;
    say([NSString stringWithFormat:@"recorder prepared %d recording %d metering %d", [self.recorder prepareToRecord],
         [self.recorder recordForDuration:0.5], self.recorder.isMeteringEnabled]);
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    AVAudioFile *f = [[AVAudioFile alloc] initForReading:recorder.url error:nil];
    AVAudioPCMBuffer *b = [[AVAudioPCMBuffer alloc] initWithPCMFormat:f.processingFormat frameCapacity:(AVAudioFrameCount)f.length];
    [f readIntoBuffer:b error:nil];
    say([NSString stringWithFormat:@"recorder finished %d seconds %.1f heard %d", flag, f.length / f.fileFormat.sampleRate, peak(b) > 0.1]);
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[TestViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
