// Sound Analysis from Objective-C (SoundAnalysisTest.app, issue #368): SNClassifySoundRequest (the built-in
// classifier's labels, window duration and its constraint, the overlap), SNAudioFileAnalyzer and SNAudioStreamAnalyzer
// with an observer (results in order, time ranges in the input's sample rate, completion), SNClassificationResult and
// SNClassification, the errors. SOUND_FILE: a WAV the test wrote (a second of near silence, then a 440 Hz tone);
// SOUND_EXPECT_MODEL=0: no classifier on the host, initWithClassifierIdentifier fails. Checks print PASS / FAIL.
#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#import <SoundAnalysis/SoundAnalysis.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

@interface Observer : NSObject <SNResultsObserving>
@property (nonatomic, strong) NSMutableArray<SNClassificationResult *> *results;
@property (nonatomic) BOOL completed;
@property (nonatomic, strong) NSError *error;
@end
@implementation Observer
- (instancetype)init { if ((self = [super init])) _results = [NSMutableArray array]; return self; }
- (void)request:(id<SNRequest>)request didProduceResult:(id<SNResult>)result {
    @synchronized (self) { [_results addObject:(SNClassificationResult *)result]; }
}
- (void)request:(id<SNRequest>)request didFailWithError:(NSError *)error { _error = error; }
- (void)requestDidComplete:(id<SNRequest>)request { _completed = YES; }
@end

int main(void) {
    @autoreleasepool {
        const char *expect = getenv("SOUND_EXPECT_MODEL");
        NSError *error = nil;
        SNClassifySoundRequest *request = [[SNClassifySoundRequest alloc] initWithClassifierIdentifier:SNClassifierIdentifierVersion1 error:&error];
        CHECK([SNErrorDomain isEqualToString:@"com.apple.SoundAnalysis"], "SNErrorDomain");
        if (expect && expect[0] == '0') {
            CHECK(!request && [error.domain isEqualToString:SNErrorDomain] && error.code == SNErrorCodeOperationFailed,
                  "no classifier on the host: SNErrorCodeOperationFailed (%s %ld)", error.domain.UTF8String, (long)error.code);
            CHECK([error.localizedDescription containsString:@"ISIM_SOUND_MODEL"], "the error says why: %s", error.localizedDescription.UTF8String);
            printf("SoundAnalysisTest: %d/%d passed\n", checks - failures, checks);
            return failures ? 1 : 0;
        }
        CHECK(request != nil, "initWithClassifierIdentifier:SNClassifierIdentifierVersion1 (%s)", error.localizedDescription.UTF8String);
        if (!request) { printf("SoundAnalysisTest: %d/%d passed\n", checks - failures, checks); return 1; }
        CHECK([request.knownClassifications isEqualToArray:(@[ @"silence", @"music", @"speech" ])], "knownClassifications: the model's labels as identifiers (%s)",
              [request.knownClassifications componentsJoinedByString:@","].UTF8String);
        CHECK(fabs(CMTimeGetSeconds(request.windowDuration) - 0.975) < 1e-6 && request.overlapFactor == 0.5, "default window 0.975 s, overlap 0.5");
        SNTimeDurationConstraint *c = request.windowDurationConstraint;
        CHECK(c.type == SNTimeDurationConstraintTypeRange && fabs(CMTimeGetSeconds(c.durationRange.start) - 0.975) < 1e-6 &&
              fabs(CMTimeGetSeconds(c.durationRange.start) + CMTimeGetSeconds(c.durationRange.duration) - 15) < 1e-6, "windowDurationConstraint: 0.975 s ... 15 s");
        request.windowDuration = CMTimeMakeWithSeconds(1.0, 1000);
        request.overlapFactor = 0;
        CHECK(fabs(CMTimeGetSeconds(request.windowDuration) - 1.0) < 1e-6, "setWindowDuration:");

        /* a file: 1 s of near silence, then a tone; 1 s windows without overlap */
        NSURL *url = [NSURL fileURLWithPath:@(getenv("SOUND_FILE") ?: "")];
        SNAudioFileAnalyzer *files = [[SNAudioFileAnalyzer alloc] initWithURL:url error:&error];
        CHECK(files != nil, "SNAudioFileAnalyzer initWithURL (%s)", error.localizedDescription.UTF8String);
        Observer *o = [Observer new];
        CHECK([files addRequest:request withObserver:o error:&error], "addRequest:withObserver:error:");
        [files analyze];
        CHECK(o.completed && !o.error, "requestDidComplete, no failure");
        CHECK(o.results.count == 3, "three 1 s windows in 3 s (%lu)", (unsigned long)o.results.count);
        if (o.results.count == 3) {
            SNClassificationResult *first = o.results[0], *last = o.results[2];
            CHECK([first.classifications.firstObject.identifier isEqualToString:@"silence"] && first.classifications.firstObject.confidence > 0.9,
                  "the first window is silence (%s %.2f)", first.classifications.firstObject.identifier.UTF8String, first.classifications.firstObject.confidence);
            CHECK([last.classifications.firstObject.identifier isEqualToString:@"music"] && last.classifications.firstObject.confidence > 0.9,
                  "the last window is the tone: music (%s %.2f)", last.classifications.firstObject.identifier.UTF8String, last.classifications.firstObject.confidence);
            CHECK(first.classifications.count == 3 && first.classifications[0].confidence >= first.classifications[1].confidence &&
                  first.classifications[1].confidence >= first.classifications[2].confidence, "classifications: all labels, the most confident first");
            CHECK([[last classificationForIdentifier:@"speech"].identifier isEqualToString:@"speech"] && [last classificationForIdentifier:@"dog"] == nil,
                  "classificationForIdentifier:");
            CMTimeRange r = last.timeRange;
            CHECK(r.start.timescale == 44100 && r.start.value == 88200 && r.duration.value == 44100, "timeRange in the file's sample rate (%lld/%d +%lld)",
                  r.start.value, r.start.timescale, r.duration.value);
        }

        /* a stream: the file's samples in 1000-frame buffers */
        AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:file.processingFormat frameCapacity:1000];
        SNAudioStreamAnalyzer *stream = [[SNAudioStreamAnalyzer alloc] initWithFormat:file.processingFormat];
        Observer *s = [Observer new];
        SNClassifySoundRequest *half = [[SNClassifySoundRequest alloc] initWithClassifierIdentifier:SNClassifierIdentifierVersion1 error:&error];
        CHECK([stream addRequest:half withObserver:s error:&error], "stream addRequest");
        AVAudioFramePosition pos = 0;
        while ([file readIntoBuffer:buffer error:&error] && buffer.frameLength > 0) {
            [stream analyzeAudioBuffer:buffer atAudioFramePosition:pos];
            pos += buffer.frameLength;
        }
        [stream completeAnalysis];
        /* 0.975 s windows every 0.4875 s over 3 s: starts 0, 0.4875, ..., 1.95 */
        CHECK(s.completed && s.results.count == 5, "stream: five half-overlapping windows, completed (%lu)", (unsigned long)s.results.count);
        CHECK(s.results.count && [s.results.lastObject.classifications.firstObject.identifier isEqualToString:@"music"], "the stream's last window is music");

        /* errors */
        SNClassifySoundRequest *bad = [[SNClassifySoundRequest alloc] initWithClassifierIdentifier:SNClassifierIdentifierVersion1 error:NULL];
        bad.windowDuration = CMTimeMakeWithSeconds(0.1, 1000);
        error = nil;
        CHECK(![stream addRequest:bad withObserver:s error:&error] && error.code == SNErrorCodeInvalidFormat, "a 0.1 s window: SNErrorCodeInvalidFormat");
        error = nil;
        CHECK(![[SNClassifySoundRequest alloc] initWithClassifierIdentifier:@"Version9" error:&error] && error.code == SNErrorCodeInvalidModel,
              "an unknown classifier: SNErrorCodeInvalidModel");
        error = nil;
        NSURL *notAudio = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"not-audio.wav"]];
        [@"not audio" writeToURL:notAudio atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        CHECK(![[SNAudioFileAnalyzer alloc] initWithURL:notAudio error:&error] && error.code == SNErrorCodeInvalidFile, "a file that is not audio: SNErrorCodeInvalidFile");

        SNTimeDurationConstraint *e = [[SNTimeDurationConstraint alloc] initWithEnumeratedDurations:@[ [NSValue valueWithBytes:&(CMTime){ 1, 1, 1, 0 } objCType:@encode(CMTime)] ]];
        CHECK(e.type == SNTimeDurationConstraintTypeEnumerated && e.enumeratedDurations.count == 1, "SNTimeDurationConstraint initWithEnumeratedDurations:");

        printf("SoundAnalysisTest: %d/%d passed\n", checks - failures, checks);
        return failures ? 1 : 0;
    }
}
