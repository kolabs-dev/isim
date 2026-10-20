// AudioToolbox's C interface (issue #286): <AudioToolbox/AudioToolbox.h> from Objective-C and plain C (plain.c),
// linked with -framework AudioToolbox: Audio Components and Audio Units (an offline render through a render callback,
// parameters, properties, listeners), AUGraph, Audio File and Extended Audio File Services (a WAV written and read
// back), Audio Converter, Audio Queues (callbacks on the audio thread and on a dispatch queue) and System Sound
// Services. Prints PASS/FAIL per check, then "audiotoolbox c test: N/M passed"; the exit code is the number of failures.
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#include <math.h>
#include <stdio.h>
#include <unistd.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (line %d)\n", #cond, __LINE__); } } while (0)
int plain_c_checks(int *checks);

/// Waits for `cond` (the main run loop keeps running, for main-queue callbacks), up to `seconds`.
#define WAIT_FOR(cond, seconds) do { NSDate *_end = [NSDate dateWithTimeIntervalSinceNow:(seconds)]; \
    while (!(cond) && [_end timeIntervalSinceNow] > 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true); } while (0)

// ---- Audio Units: a render callback (a 1 kHz sine at 48 kHz) pulled by the generic output unit ----
static int renderCalls;
static OSStatus sineRender(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *ts, UInt32 bus, UInt32 frames,
                           AudioBufferList *io) {
    renderCalls++;
    double *phase = refCon;
    for (UInt32 i = 0; i < frames; i++) {
        float v = (float)(0.5 * sin(*phase));
        for (UInt32 b = 0; b < io->mNumberBuffers; b++) ((float *)io->mBuffers[b].mData)[i] = v;
        *phase += 2 * M_PI * 1000 / 48000;
    }
    return noErr;
}
static int propertyChanges;
static AudioUnitPropertyID lastProperty;
static void propertyListener(void *refCon, AudioUnit unit, AudioUnitPropertyID prop, AudioUnitScope scope, AudioUnitElement element) {
    propertyChanges++;
    lastProperty = prop;
}
static int notifyCalls;
static OSStatus renderNotify(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *ts, UInt32 bus, UInt32 frames,
                             AudioBufferList *io) {
    if (*flags & kAudioUnitRenderAction_PostRender) notifyCalls++;
    return noErr;
}

// ---- Audio Queues ----
static volatile int queueCallbacks, queueRunningChanges;
static void queueOutput(void *userData, AudioQueueRef aq, AudioQueueBufferRef buffer) {
    queueCallbacks++;
    if (*(int *)userData) return;                              // stopping: don't refill
    memset(buffer->mAudioData, 0, buffer->mAudioDataBytesCapacity);
    buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
    AudioQueueEnqueueBuffer(aq, buffer, 0, NULL);
}
static void queueListener(void *userData, AudioQueueRef aq, AudioQueuePropertyID prop) {
    if (prop == kAudioQueueProperty_IsRunning) queueRunningChanges++;
}

// ---- System sounds ----
static volatile int soundCompletions;
static void soundDone(SystemSoundID sound, void *data) { soundCompletions++; }

int main(void) {
    @autoreleasepool {
        // ---- Audio Components ----
        AudioComponentDescription genericDesc = {kAudioUnitType_Output, kAudioUnitSubType_GenericOutput, kAudioUnitManufacturer_Apple, 0, 0};
        AudioComponentDescription remoteDesc = {kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0};
        AudioComponentDescription mixerDesc = {kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple, 0, 0};
        AudioComponent generic = AudioComponentFindNext(NULL, &genericDesc);
        AudioComponent remote = AudioComponentFindNext(NULL, &remoteDesc);
        CHECK(generic != NULL && remote != NULL && generic != remote);
        CHECK(AudioComponentFindNext(generic, &genericDesc) == NULL && AudioComponentCount(&genericDesc) == 1);
        CFStringRef name = NULL;
        CHECK(AudioComponentCopyName(remote, &name) == noErr && name != NULL && [(__bridge NSString *)name containsString:@"RemoteIO"]);
        if (name) CFRelease(name);
        AudioComponentDescription got = {0};
        CHECK(AudioComponentGetDescription(generic, &got) == noErr && got.componentSubType == kAudioUnitSubType_GenericOutput);
        UInt32 version = 0;
        CHECK(AudioComponentGetVersion(generic, &version) == noErr && version > 0);

        // ---- Audio Units: format, render callback, offline render through the generic output ----
        AudioUnit unit = NULL;
        CHECK(AudioComponentInstanceNew(generic, &unit) == noErr && unit != NULL && AudioComponentInstanceGetComponent(unit) == generic);
        AudioStreamBasicDescription fmt = {48000, kAudioFormatLinearPCM, kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
                                           4, 1, 4, 2, 32, 0};
        CHECK(AudioUnitAddPropertyListener(unit, kAudioUnitProperty_StreamFormat, propertyListener, NULL) == noErr);
        CHECK(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, sizeof fmt) == noErr);
        CHECK(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &fmt, sizeof fmt) == noErr);
        CHECK(propertyChanges >= 1 && lastProperty == kAudioUnitProperty_StreamFormat);
        AudioStreamBasicDescription back = {0};
        UInt32 size = sizeof back;
        CHECK(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &back, &size) == noErr &&
              size == sizeof back && back.mSampleRate == 48000 && back.mChannelsPerFrame == 2);
        Boolean writable = false;
        UInt32 infoSize = 0;
        CHECK(AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &infoSize, &writable) == noErr &&
              infoSize == sizeof(AudioStreamBasicDescription) && writable);
        double phase = 0;
        AURenderCallbackStruct cb = {sineRender, &phase};
        CHECK(AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb, sizeof cb) == noErr);
        CHECK(AudioUnitAddRenderNotify(unit, renderNotify, NULL) == noErr);
        CHECK(AudioUnitInitialize(unit) == noErr);
        float left[512], right[512];
        struct { UInt32 n; AudioBuffer b[2]; } list = {2, {{1, sizeof left, left}, {1, sizeof right, right}}};
        AudioTimeStamp ts = {.mSampleTime = 0, .mFlags = kAudioTimeStampSampleTimeValid};
        AudioUnitRenderActionFlags flags = 0;
        CHECK(AudioUnitRender(unit, &flags, &ts, 0, 512, (AudioBufferList *)&list) == noErr);
        CHECK(renderCalls >= 1 && notifyCalls >= 1);
        CHECK(fabsf(left[12] - (float)(0.5 * sin(12 * 2 * M_PI * 1000 / 48000))) < 1e-4 && fabsf(right[100] - left[100]) < 1e-6);
        CHECK(AudioUnitRemoveRenderNotify(unit, renderNotify, NULL) == noErr);
        CHECK(AudioUnitRemovePropertyListenerWithUserData(unit, kAudioUnitProperty_StreamFormat, propertyListener, NULL) == noErr);
        CHECK(AudioUnitUninitialize(unit) == noErr && AudioComponentInstanceDispose(unit) == noErr);

        // ---- parameters: the multichannel mixer's volume ----
        AudioUnit mixer = NULL;
        CHECK(AudioComponentInstanceNew(AudioComponentFindNext(NULL, &mixerDesc), &mixer) == noErr);
        AudioUnitParameterValue vol = 0;
        CHECK(AudioUnitSetParameter(mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 0.25f, 0) == noErr);
        CHECK(AudioUnitGetParameter(mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, &vol) == noErr && vol == 0.25f);
        CHECK(AudioUnitGetParameter(mixer, 9999, kAudioUnitScope_Output, 0, &vol) == kAudioUnitErr_InvalidParameter);
        CHECK(AudioUnitReset(mixer, kAudioUnitScope_Global, 0) == noErr && AudioComponentInstanceDispose(mixer) == noErr);

        // ---- RemoteIO: started and stopped (plays through the host mixer) ----
        AudioUnit io = NULL;
        CHECK(AudioComponentInstanceNew(remote, &io) == noErr);
        double ioPhase = 0;
        AURenderCallbackStruct ioCb = {sineRender, &ioPhase};
        AudioUnitSetProperty(io, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, sizeof fmt);
        AudioUnitSetProperty(io, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &ioCb, sizeof ioCb);
        int before = renderCalls;
        CHECK(AudioUnitInitialize(io) == noErr && AudioOutputUnitStart(io) == noErr);
        WAIT_FOR(renderCalls > before + 3, 5);
        CHECK(renderCalls > before + 3);
        CHECK(AudioOutputUnitStop(io) == noErr && AudioComponentInstanceDispose(io) == noErr);

        // ---- async instantiation (the handler runs on the main queue) ----
        __block AudioComponentInstance asyncUnit = NULL;
        __block OSStatus asyncStatus = -1;
        AudioComponentInstantiate(generic, kAudioComponentInstantiation_LoadInProcess, ^(AudioComponentInstance u, OSStatus st) {
            asyncUnit = u; asyncStatus = st;
        });
        WAIT_FOR(asyncStatus != -1, 5);
        CHECK(asyncStatus == noErr && asyncUnit != NULL);
        if (asyncUnit) AudioComponentInstanceDispose(asyncUnit);

        // ---- AUGraph ----
        AUGraph graph = NULL;
        AUNode outNode = 0, mixNode = 0;
        CHECK(NewAUGraph(&graph) == noErr && graph != NULL);
        CHECK(AUGraphAddNode(graph, &genericDesc, &outNode) == noErr && AUGraphAddNode(graph, &mixerDesc, &mixNode) == noErr);
        UInt32 nodes = 0;
        CHECK(AUGraphGetNodeCount(graph, &nodes) == noErr && nodes == 2);
        CHECK(AUGraphOpen(graph) == noErr);
        AudioUnit mixUnit = NULL;
        AudioComponentDescription nodeDesc = {0};
        CHECK(AUGraphNodeInfo(graph, mixNode, &nodeDesc, &mixUnit) == noErr && mixUnit != NULL && nodeDesc.componentType == kAudioUnitType_Mixer);
        CHECK(AUGraphConnectNodeInput(graph, mixNode, 0, outNode, 0) == noErr);
        CHECK(AUGraphInitialize(graph) == noErr);
        Boolean isOpen = false, isInit = false, isRunning = true;
        CHECK(AUGraphIsOpen(graph, &isOpen) == noErr && isOpen && AUGraphIsInitialized(graph, &isInit) == noErr && isInit);
        CHECK(AUGraphIsRunning(graph, &isRunning) == noErr && !isRunning);
        Float32 load = -1;
        CHECK(AUGraphGetCPULoad(graph, &load) == noErr && load >= 0);
        CHECK(AUGraphUninitialize(graph) == noErr && AUGraphClose(graph) == noErr && DisposeAUGraph(graph) == noErr);

        // ---- Audio File Services: a 16-bit mono WAV written and read back ----
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"atc-test.wav"];
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
        AudioStreamBasicDescription pcm16 = {44100, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, 2, 1, 2, 1, 16, 0};
        AudioFileID file = NULL;
        CHECK(AudioFileCreateWithURL(url, kAudioFileWAVEType, &pcm16, kAudioFileFlags_EraseFile, &file) == noErr && file != NULL);
        enum { kFrames = 4410 };
        static SInt16 samples[kFrames];
        for (int i = 0; i < kFrames; i++) samples[i] = (SInt16)(10000 * sin(i * 2 * M_PI * 441 / 44100));
        UInt32 packets = kFrames;
        CHECK(AudioFileWritePackets(file, false, sizeof samples, NULL, 0, &packets, samples) == noErr && packets == kFrames);
        CHECK(AudioFileClose(file) == noErr);
        CHECK([NSFileManager.defaultManager fileExistsAtPath:path]);
        file = NULL;
        CHECK(AudioFileOpenURL(url, kAudioFileReadPermission, 0, &file) == noErr && file != NULL);
        AudioStreamBasicDescription fileFmt = {0};
        size = sizeof fileFmt;
        CHECK(AudioFileGetProperty(file, kAudioFilePropertyDataFormat, &size, &fileFmt) == noErr && fileFmt.mSampleRate == 44100 &&
              fileFmt.mBitsPerChannel == 16 && fileFmt.mChannelsPerFrame == 1);
        UInt64 packetCount = 0;
        size = sizeof packetCount;
        CHECK(AudioFileGetProperty(file, kAudioFilePropertyAudioDataPacketCount, &size, &packetCount) == noErr && packetCount == kFrames);
        AudioFileTypeID type = 0;
        size = sizeof type;
        CHECK(AudioFileGetProperty(file, kAudioFilePropertyFileFormat, &size, &type) == noErr && type == kAudioFileWAVEType);
        UInt32 propSize = 0, propWritable = 1;
        CHECK(AudioFileGetPropertyInfo(file, kAudioFilePropertyDataFormat, &propSize, &propWritable) == noErr && propSize == sizeof(AudioStreamBasicDescription));
        static SInt16 readBack[100];
        UInt32 bytes = sizeof readBack, readPackets = 100;
        CHECK(AudioFileReadPacketData(file, false, &bytes, NULL, 1000, &readPackets, readBack) == noErr && readPackets == 100 &&
              memcmp(readBack, samples + 1000, sizeof readBack) == 0);
        CHECK(AudioFileClose(file) == noErr);
        CFURLRef missing = (__bridge CFURLRef)[NSURL fileURLWithPath:@"/nonexistent/atc.wav"];
        file = NULL;
        CHECK(AudioFileOpenURL(missing, kAudioFileReadPermission, 0, &file) != noErr && file == NULL);

        // ---- Extended Audio File Services: the WAV as floats ----
        ExtAudioFileRef ext = NULL;
        CHECK(ExtAudioFileOpenURL(url, &ext) == noErr && ext != NULL);
        SInt64 lengthFrames = 0;
        size = sizeof lengthFrames;
        CHECK(ExtAudioFileGetProperty(ext, kExtAudioFileProperty_FileLengthFrames, &size, &lengthFrames) == noErr && lengthFrames == kFrames);
        AudioStreamBasicDescription client = {44100, kAudioFormatLinearPCM, kAudioFormatFlagsNativeFloatPacked, 4, 1, 4, 1, 32, 0};
        CHECK(ExtAudioFileSetProperty(ext, kExtAudioFileProperty_ClientDataFormat, sizeof client, &client) == noErr);
        CHECK(ExtAudioFileSeek(ext, 2000) == noErr);
        SInt64 pos = 0;
        CHECK(ExtAudioFileTell(ext, &pos) == noErr && pos == 2000);
        static float floats[256];
        struct { UInt32 n; AudioBuffer b[1]; } flist = {1, {{1, sizeof floats, floats}}};
        UInt32 frames = 256;
        CHECK(ExtAudioFileRead(ext, &frames, (AudioBufferList *)&flist) == noErr && frames == 256);
        CHECK(fabsf(floats[10] - samples[2010] / 32768.0f) < 1e-3 && fabsf(floats[200] - samples[2200] / 32768.0f) < 1e-3);
        CHECK(ExtAudioFileDispose(ext) == noErr);

        // ---- Audio Converter: sample rate conversion through an input proc (plain C covers ConvertBuffer) ----
        failures += plain_c_checks(&checks);

        // ---- Audio Queues: an output queue whose callback refills its buffers on the audio thread ----
        AudioStreamBasicDescription qfmt = {44100, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, 4, 1, 4, 2, 16, 0};
        AudioQueueRef queue = NULL;
        int stopping = 0;
        CHECK(AudioQueueNewOutput(&qfmt, queueOutput, &stopping, NULL, NULL, 0, &queue) == noErr && queue != NULL);
        CHECK(AudioQueueAddPropertyListener(queue, kAudioQueueProperty_IsRunning, queueListener, NULL) == noErr);
        for (int i = 0; i < 3; i++) {
            AudioQueueBufferRef buf = NULL;
            CHECK(AudioQueueAllocateBuffer(queue, 4410 * 4, &buf) == noErr && buf != NULL && buf->mAudioDataBytesCapacity == 4410 * 4);
            queueOutput(&stopping, queue, buf);
        }
        queueCallbacks = 0;
        CHECK(AudioQueueSetParameter(queue, kAudioQueueParam_Volume, 0.5f) == noErr);
        AudioQueueParameterValue qvol = 0;
        CHECK(AudioQueueGetParameter(queue, kAudioQueueParam_Volume, &qvol) == noErr && qvol == 0.5f);
        CHECK(AudioQueueStart(queue, NULL) == noErr);
        WAIT_FOR(queueCallbacks >= 3, 10);
        CHECK(queueCallbacks >= 3);
        UInt32 running = 0;
        size = sizeof running;
        CHECK(AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &running, &size) == noErr && running == 1);
        AudioStreamBasicDescription qback = {0};
        size = sizeof qback;
        CHECK(AudioQueueGetProperty(queue, kAudioQueueProperty_StreamDescription, &qback, &size) == noErr && qback.mSampleRate == 44100);
        AudioTimeStamp now = {0};
        CHECK(AudioQueueGetCurrentTime(queue, NULL, &now, NULL) == noErr && now.mSampleTime > 0);
        stopping = 1;
        CHECK(AudioQueueStop(queue, true) == noErr);
        WAIT_FOR(queueRunningChanges >= 2, 5);
        CHECK(queueRunningChanges >= 2);
        CHECK(AudioQueueDispose(queue, true) == noErr);

        // ---- Audio Queues: callbacks as a block on a dispatch queue ----
        dispatch_queue_t cbQueue = dispatch_queue_create("atc.callbacks", NULL);
        __block volatile int blockCalls = 0;
        __block volatile int onQueue = 1;
        __block volatile int blockStopping = 0;
        AudioQueueRef bq = NULL;
        CHECK(AudioQueueNewOutputWithDispatchQueue(&bq, &qfmt, 0, cbQueue, ^(AudioQueueRef aq, AudioQueueBufferRef buffer) {
            blockCalls++;
            if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), "atc.callbacks") != 0) onQueue = 0;
            if (blockStopping) return;
            buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
            AudioQueueEnqueueBuffer(aq, buffer, 0, NULL);
        }) == noErr && bq != NULL);
        for (int i = 0; i < 2; i++) {
            AudioQueueBufferRef buf = NULL;
            AudioQueueAllocateBuffer(bq, 4410 * 4, &buf);
            memset(buf->mAudioData, 0, buf->mAudioDataBytesCapacity);
            buf->mAudioDataByteSize = buf->mAudioDataBytesCapacity;
            AudioQueueEnqueueBuffer(bq, buf, 0, NULL);
        }
        CHECK(AudioQueueStart(bq, NULL) == noErr);
        WAIT_FOR(blockCalls >= 3, 10);
        CHECK(blockCalls >= 3 && onQueue);
        blockStopping = 1;
        CHECK(AudioQueueStop(bq, true) == noErr && AudioQueueDispose(bq, true) == noErr);

        // ---- System Sound Services: a sound from the WAV, completions as a C proc and as a block ----
        SystemSoundID sound = 0;
        CHECK(AudioServicesCreateSystemSoundID(url, &sound) == noErr && sound != 0);
        CHECK(AudioServicesAddSystemSoundCompletion(sound, CFRunLoopGetMain(), kCFRunLoopDefaultMode, soundDone, NULL) == noErr);
        AudioServicesPlaySystemSound(sound);
        WAIT_FOR(soundCompletions >= 1, 5);
        CHECK(soundCompletions == 1);
        AudioServicesRemoveSystemSoundCompletion(sound);
        __block int blockDone = 0;
        AudioServicesPlaySystemSoundWithCompletion(sound, ^{ blockDone = 1; });
        WAIT_FOR(blockDone, 5);
        CHECK(blockDone == 1 && soundCompletions == 1);
        __block int alertDone = 0;
        AudioServicesPlayAlertSoundWithCompletion(kSystemSoundID_Vibrate, ^{ alertDone = 1; });
        WAIT_FOR(alertDone, 5);
        CHECK(alertDone == 1);
        AudioServicesPlaySystemSound(1104);                       // a built-in sound (a synthesized click)
        CHECK(AudioServicesDisposeSystemSoundID(sound) == noErr && AudioServicesDisposeSystemSoundID(sound) == kAudioServicesBadSpecifierError);

        // ---- constants: Apple's values ----
        CHECK(kAudioFileWAVEType == 'WAVE' && kAudioFilePropertyDataFormat == 'dfmt' && kExtAudioFileProperty_ClientDataFormat == 'cfmt');
        CHECK(kAudioQueueProperty_IsRunning == 'aqrn' && kAudioQueueErr_InvalidBuffer == -66687 && kAudioConverterErr_FormatNotSupported == 'fmt?');
        CHECK(kAudioUnitSubType_RemoteIO == 'rioc' && kAudioOutputUnitProperty_EnableIO == 2003 && kAUGraphErr_NodeNotFound == -10860);
        CHECK(kSystemSoundID_Vibrate == 4095 && sizeof(AudioQueueBuffer) == 56 && sizeof(AudioComponentDescription) == 20);
    }
    printf("audiotoolbox c test: %d/%d passed\n", checks - failures, checks);
    return failures;
}
