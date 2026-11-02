// Speech from Objective-C (SpeechCTest.app, issue #700): authorization, a recognizer, a URL request with contextual
// strings through a result handler, an audio-buffer request through the task delegate (Apple's @objc protocol with
// optional methods), cancelling a task, and SFSpeechLanguageModel's error. test_speech.py runs it with the stand-in
// whisper-cli (fake-whisper-cli).
#import <Foundation/Foundation.h>
#import <Speech/Speech.h>
#include <math.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, what) do { checks++; if (cond) printf("PASS  %s\n", what); else { failures++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

/* runs the run loop until done() or the timeout */
static BOOL wait_for(BOOL (^done)(void), double seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [end timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    return done();
}

/* a 1 s 16 kHz 16-bit mono WAV of a 440 Hz tone */
static NSURL *wav_file(void) {
    int rate = 16000, n = rate;
    NSMutableData *d = [NSMutableData data];
    uint32_t u32; uint16_t u16;
    [d appendBytes:"RIFF" length:4]; u32 = 36 + n * 2; [d appendBytes:&u32 length:4]; [d appendBytes:"WAVEfmt " length:8];
    u32 = 16; [d appendBytes:&u32 length:4]; u16 = 1; [d appendBytes:&u16 length:2]; [d appendBytes:&u16 length:2];
    u32 = rate; [d appendBytes:&u32 length:4]; u32 = rate * 2; [d appendBytes:&u32 length:4]; u16 = 2; [d appendBytes:&u16 length:2];
    u16 = 16; [d appendBytes:&u16 length:2]; [d appendBytes:"data" length:4]; u32 = n * 2; [d appendBytes:&u32 length:4];
    for (int i = 0; i < n; i++) { int16_t s = (int16_t)(8000 * sin(2 * M_PI * 440 * i / rate)); [d appendBytes:&s length:2]; }
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"speech-c.wav"]];
    [d writeToURL:url atomically:YES];
    return url;
}

@interface TaskWatcher : NSObject <SFSpeechRecognitionTaskDelegate>
@property (nonatomic) int readingDone, finishedRecognition, successes, cancels;
@property (nonatomic, copy) NSString *text;
@end
@implementation TaskWatcher
- (void)speechRecognitionTaskFinishedReadingAudio:(SFSpeechRecognitionTask *)task { _readingDone++; }
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)result {
    _finishedRecognition++; _text = result.bestTranscription.formattedString;
}
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishSuccessfully:(BOOL)ok { if (ok) _successes++; }
- (void)speechRecognitionTaskWasCancelled:(SFSpeechRecognitionTask *)task { _cancels++; }
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        __block SFSpeechRecognizerAuthorizationStatus status = SFSpeechRecognizerAuthorizationStatusNotDetermined;
        __block BOOL answered = NO;
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus s) { status = s; answered = YES; }];
        CHECK(wait_for(^{ return answered; }, 10) && status == SFSpeechRecognizerAuthorizationStatusAuthorized &&
              [SFSpeechRecognizer authorizationStatus] == SFSpeechRecognizerAuthorizationStatusAuthorized, "requestAuthorization: authorized");

        SFSpeechRecognizer *r = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
        CHECK(r != nil && r.isAvailable && [r.locale.localeIdentifier hasPrefix:@"en"], "initWithLocale:, isAvailable with the host engine");
        CHECK([[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"tlh"]] == nil, "an unsupported locale gives nil");
        CHECK([SFSpeechRecognizer supportedLocales].count > 10, "supportedLocales");

        /* a file, through the result handler */
        SFSpeechURLRecognitionRequest *req = [[SFSpeechURLRecognitionRequest alloc] initWithURL:wav_file()];
        req.contextualStrings = @[@"isim", @"Objective-C"];
        req.taskHint = SFSpeechRecognitionTaskHintDictation;
        __block SFSpeechRecognitionResult *result = nil; __block NSError *error = nil; __block BOOL done = NO;
        SFSpeechRecognitionTask *t = [r recognitionTaskWithRequest:req resultHandler:^(SFSpeechRecognitionResult *res, NSError *e) {
            result = res; error = e; done = YES;
        }];
        CHECK(wait_for(^{ return done; }, 30) && !error && result.isFinal, "a URL request's final result");
        NSString *text = result.bestTranscription.formattedString;
        printf("      %s\n", text.UTF8String ?: "-");
        CHECK([text containsString:@"Hello, isim world (en)."] && [text containsString:@"isim, Objective-C"], "the transcription, with the contextual strings as the prompt");
        CHECK(result.bestTranscription.segments.count > 0 && result.transcriptions.count == 1 &&
              NSEqualRanges(result.bestTranscription.segments[0].substringRange, NSMakeRange(0, 6)), "segments and their ranges");
        CHECK(t.state == SFSpeechRecognitionTaskStateCompleted && !t.isCancelled && [req.URL.lastPathComponent isEqualToString:@"speech-c.wav"], "the task completed; the request's URL");

        /* an audio buffer, through the delegate */
        SFSpeechAudioBufferRecognitionRequest *buf = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        AVAudioFormat *fmt = buf.nativeAudioFormat;
        AVAudioPCMBuffer *pcm = [[AVAudioPCMBuffer alloc] initWithPCMFormat:fmt frameCapacity:16000];
        pcm.frameLength = 16000;
        for (int i = 0; i < 16000; i++) pcm.floatChannelData[0][i] = (float)(0.25 * sin(2 * M_PI * 440 * i / 16000.0));
        TaskWatcher *w = [TaskWatcher new];
        SFSpeechRecognitionTask *bt = [r recognitionTaskWithRequest:buf delegate:w];
        [buf appendAudioPCMBuffer:pcm];
        [buf endAudio];
        CHECK(wait_for(^{ return (BOOL)(w.successes > 0); }, 30) && w.finishedRecognition == 1 && w.readingDone == 1 &&
              [w.text containsString:@"Hello, isim world"], "an audio-buffer request through the task delegate (optional methods)");
        CHECK(fmt.sampleRate == 16000 && fmt.channelCount == 1 && bt.error == nil, "nativeAudioFormat: 16 kHz mono");

        /* cancelling */
        SFSpeechAudioBufferRecognitionRequest *never = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        TaskWatcher *cw = [TaskWatcher new];
        SFSpeechRecognitionTask *ct = [r recognitionTaskWithRequest:never delegate:cw];
        [ct cancel];
        CHECK(wait_for(^{ return (BOOL)(cw.cancels > 0); }, 10) && ct.isCancelled && ct.state == SFSpeechRecognitionTaskStateCompleted, "cancel: speechRecognitionTaskWasCancelled");

        /* a custom language model that cannot be prepared */
        __block NSError *lmError = nil; __block BOOL lmDone = NO;
        SFSpeechLanguageModelConfiguration *config = [[SFSpeechLanguageModelConfiguration alloc]
            initWithLanguageModel:[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"lm.bin"]]];
        [SFSpeechLanguageModel prepareCustomLanguageModelForUrl:[NSURL fileURLWithPath:@"/nonexistent"] configuration:config completion:^(NSError *e) {
            lmError = e; lmDone = YES;
        }];
        CHECK(wait_for(^{ return lmDone; }, 10) && [lmError.domain isEqualToString:SFSpeechErrorDomain], "SFSpeechLanguageModel: a missing asset fails in SFSpeechErrorDomain");
        CHECK(config.vocabulary == nil && [config.languageModel.lastPathComponent isEqualToString:@"lm.bin"], "SFSpeechLanguageModelConfiguration");

        printf("SpeechCTest: %d/%d passed\n", checks - failures, checks);
        return failures ? 1 : 0;
    }
}
