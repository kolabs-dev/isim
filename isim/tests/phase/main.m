// PHASE from Objective-C (PHASETest.app, issue #386): the engine, sound assets from data, the object tree and
// transforms (simd values through the header), envelopes, meta parameters, spatial pipelines and mixers, sound events
// (start to finishedPlaying, errors), push streams, groups and duckers, with Apple's selectors and constants.
#import <PHASE/PHASE.h>
#include <math.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static void wait_for(volatile BOOL *flag) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!*flag && [end timeIntervalSinceNow] > 0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

int main(void) {
    @autoreleasepool {
        PHASEEngine *engine = [[PHASEEngine alloc] initWithUpdateMode:PHASEUpdateModeAutomatic];
        CHECK(engine.rootObject != nil && engine.assetRegistry != nil && engine.renderingState == PHASERenderingStateStopped, "an engine, its root object and registry");

        // a tone as data
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
        NSMutableData *data = [NSMutableData dataWithLength:4800 * sizeof(float)];
        float *s = data.mutableBytes;
        for (int i = 0; i < 4800; i++) s[i] = 0.5f * sinf(2 * (float)M_PI * 440 * i / 48000);
        NSError *error = nil;
        PHASESoundAsset *asset = [engine.assetRegistry registerSoundAssetWithData:data identifier:@"tone" format:format
                                                                normalizationMode:PHASENormalizationModeNone error:&error];
        CHECK(asset && [asset.identifier isEqualToString:@"tone"] && asset.type == PHASEAssetTypeResident, "-registerSoundAssetWithData:...");
        PHASESoundAsset *again = [engine.assetRegistry registerSoundAssetWithData:data identifier:@"tone" format:format normalizationMode:PHASENormalizationModeNone error:&error];
        CHECK(!again && [error.domain isEqualToString:PHASEAssetErrorDomain] && error.code == PHASEAssetErrorAlreadyExists, "a duplicate identifier: PHASEAssetErrorAlreadyExists");

        // objects and transforms
        PHASEListener *listener = [[PHASEListener alloc] initWithEngine:engine];
        PHASESource *source = [[PHASESource alloc] initWithEngine:engine];
        CHECK([engine.rootObject addChild:listener error:&error] && [engine.rootObject addChild:source error:&error], "-addChild:error:");
        CHECK(![engine.rootObject addChild:source error:&error] && [error.domain isEqualToString:PHASEErrorDomain] && error.code == PHASEErrorInvalidObject,
              "adding a child twice: PHASEErrorInvalidObject");
        simd_float4x4 m = {{{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {3, 0, -2, 1}}};
        source.transform = m;
        CHECK(source.transform.columns[3][0] == 3 && source.worldTransform.columns[3][2] == -2 && PHASEObject.forward[2] == -1,
              "transform and worldTransform (simd_float4x4), +forward");
        listener.automaticHeadTrackingFlags = PHASEAutomaticHeadTrackingFlagOrientation;
        CHECK(listener.automaticHeadTrackingFlags == PHASEAutomaticHeadTrackingFlagOrientation, "automaticHeadTrackingFlags");

        // envelopes and meta parameters
        PHASEEnvelopeSegment *seg = [[PHASEEnvelopeSegment alloc] initWithEndPoint:(simd_double2){10, 1} curveType:PHASECurveTypeLinear];
        PHASEEnvelope *env = [[PHASEEnvelope alloc] initWithStartPoint:(simd_double2){0, 0} segments:@[ seg ]];
        CHECK(fabs([env evaluateForValue:5] - 0.5) < 1e-9 && env.startPoint[0] == 0 && seg.endPoint[0] == 10 && env.domain.second == 10,
              "PHASEEnvelope (simd_double2 points), -evaluateForValue:");
        PHASENumberMetaParameterDefinition *gainDef = [[PHASENumberMetaParameterDefinition alloc] initWithValue:0.5 minimum:0 maximum:1 identifier:@"gain"];
        CHECK([gainDef.value doubleValue] == 0.5 && gainDef.maximum == 1, "PHASENumberMetaParameterDefinition");

        // a spatial pipeline and mixers
        PHASESpatialPipeline *pipeline = [[PHASESpatialPipeline alloc] initWithFlags:PHASESpatialPipelineFlagDirectPathTransmission | PHASESpatialPipelineFlagLateReverb];
        CHECK(pipeline.flags == (PHASESpatialPipelineFlagDirectPathTransmission | PHASESpatialPipelineFlagLateReverb) && pipeline.entries.count == 2 &&
              pipeline.entries[PHASESpatialCategoryDirectPathTransmission] != nil, "PHASESpatialPipeline: flags, entries by category");
        PHASESpatialMixerDefinition *spatial = [[PHASESpatialMixerDefinition alloc] initWithSpatialPipeline:pipeline identifier:@"spatial"];
        spatial.distanceModelParameters = [PHASEGeometricSpreadingDistanceModelParameters new];
        AVAudioChannelLayout *mono = [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_Mono];
        simd_quatf q = { { 0, 0, 0, 1 } };
        PHASEAmbientMixerDefinition *ambient = [[PHASEAmbientMixerDefinition alloc] initWithChannelLayout:mono orientation:q identifier:@"ambient"];
        CHECK(ambient.orientation.vector[3] == 1 && [ambient.identifier isEqualToString:@"ambient"], "PHASEAmbientMixerDefinition (simd_quatf)");
        PHASESamplerNodeDefinition *sampler = [[PHASESamplerNodeDefinition alloc] initWithSoundAssetIdentifier:@"tone" mixerDefinition:spatial];
        sampler.gainMetaParameterDefinition = gainDef;
        CHECK([engine.assetRegistry registerSoundEventAssetWithRootNode:sampler identifier:@"event" error:&error] != nil, "-registerSoundEventAssetWithRootNode:...");

        // sound events
        PHASESoundEvent *bad = [[PHASESoundEvent alloc] initWithEngine:engine assetIdentifier:@"event" error:&error];
        CHECK(!bad && [error.domain isEqualToString:PHASESoundEventErrorDomain] && error.code == PHASESoundEventErrorAPIMisuse, "no mixer parameters: PHASESoundEventErrorAPIMisuse");
        PHASEMixerParameters *params = [PHASEMixerParameters new];
        [params addSpatialMixerParametersWithIdentifier:@"spatial" source:source listener:listener];
        PHASESoundEvent *event = [[PHASESoundEvent alloc] initWithEngine:engine assetIdentifier:@"event" mixerParameters:params error:&error];
        CHECK(event && event.mixers[@"spatial"] && [event.metaParameters[@"gain"] isKindOfClass:[PHASENumberMetaParameter class]] && !event.indefinite,
              "a sound event: its mixers and meta parameters");
        CHECK([engine startAndReturnError:&error] && engine.renderingState == PHASERenderingStateStarted, "-startAndReturnError:");
        __block PHASESoundEventStartHandlerReason reason = PHASESoundEventStartHandlerReasonFailure; __block volatile BOOL done = NO;
        [event startWithCompletion:^(PHASESoundEventStartHandlerReason r) { reason = r; done = YES; }];
        wait_for(&done);
        CHECK(reason == PHASESoundEventStartHandlerReasonFinishedPlaying && engine.lastRenderTime != nil, "the event plays to its end");

        // a push stream
        PHASEChannelMixerDefinition *channel = [[PHASEChannelMixerDefinition alloc] initWithChannelLayout:mono];
        PHASEPushStreamNodeDefinition *push = [[PHASEPushStreamNodeDefinition alloc] initWithMixerDefinition:channel format:format identifier:@"push"];
        [engine.assetRegistry registerSoundEventAssetWithRootNode:push identifier:@"stream" error:&error];
        PHASESoundEvent *stream = [[PHASESoundEvent alloc] initWithEngine:engine assetIdentifier:@"stream" error:&error];
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:2400];
        buffer.frameLength = 2400;
        __block volatile BOOL rendered = NO;
        [stream startWithCompletion:nil];
        [stream.pushStreamNodes[@"push"] scheduleBuffer:buffer atTime:nil options:PHASEPushStreamBufferDefault
                                completionCallbackType:PHASEPushStreamCompletionDataRendered completionHandler:^(PHASEPushStreamCompletionCallbackCondition c) { rendered = YES; }];
        wait_for(&rendered);
        CHECK(rendered && stream.indefinite, "-scheduleBuffer:atTime:options:completionCallbackType:completionHandler:");
        [stream stopAndInvalidate];

        // groups and duckers
        PHASEGroup *a = [[PHASEGroup alloc] initWithIdentifier:@"a"], *b = [[PHASEGroup alloc] initWithIdentifier:@"b"];
        [a registerWithEngine:engine]; [b registerWithEngine:engine];
        [a mute];
        PHASEDucker *ducker = [[PHASEDucker alloc] initWithEngine:engine sourceGroups:[NSSet setWithObject:a] targetGroups:[NSSet setWithObject:b] gain:0.1
                                                       attackTime:0.1 releaseTime:0.1 attackCurve:PHASECurveTypeLinear releaseCurve:PHASECurveTypeLinear];
        [ducker activate];
        CHECK(a.muted && engine.groups.count == 2 && ducker.active && engine.duckers.count == 1, "groups (mute) and a ducker");
        [engine stop];
        CHECK(engine.renderingState == PHASERenderingStateStopped, "-stop");
        printf("phase: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
