// The AudioToolbox headers as plain C (no Objective-C): a converter from 16-bit integers to floats, and the
// component list. Called from main.m; returns the number of failed checks and counts them in *checks.
#include <AudioToolbox/AudioToolbox.h>
#include <stdio.h>

static Float32 ramp[480];
static int inputCalls;
static OSStatus feed(AudioConverterRef conv, UInt32 *ioPackets, AudioBufferList *io, AudioStreamPacketDescription **descs, void *user) {
    UInt32 *offset = user;
    UInt32 left = 480 - *offset;
    if (*ioPackets > left) *ioPackets = left;
    inputCalls++;
    io->mBuffers[0].mData = ramp + *offset;
    io->mBuffers[0].mDataByteSize = *ioPackets * sizeof(Float32);
    io->mBuffers[0].mNumberChannels = 1;
    *offset += *ioPackets;
    return noErr;
}

int plain_c_checks(int *checks) {
    int failures = 0;
#define CCHECK(cond) do { (*checks)++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (line %d)\n", #cond, __LINE__); } } while (0)
    AudioStreamBasicDescription in = {48000, kAudioFormatLinearPCM, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, 2, 1, 2, 1, 16, 0};
    AudioStreamBasicDescription out = {48000, kAudioFormatLinearPCM, kAudioFormatFlagsNativeFloatPacked, 4, 1, 4, 1, 32, 0};
    AudioConverterRef conv = NULL;
    CCHECK(AudioConverterNew(&in, &out, &conv) == noErr && conv != NULL);
    SInt16 src[4] = {0, 16384, -16384, 32767};
    Float32 dst[4] = {0};
    UInt32 size = sizeof dst;
    CCHECK(AudioConverterConvertBuffer(conv, sizeof src, src, &size, dst) == noErr && size == sizeof dst);
    CCHECK(dst[0] == 0 && dst[1] > 0.49f && dst[1] < 0.51f && dst[2] < -0.49f && dst[2] > -0.51f && dst[3] > 0.99f);
    CCHECK(AudioConverterDispose(conv) == noErr);
    // 48 kHz to 24 kHz through an input proc: half as many frames, the ramp's values kept
    AudioStreamBasicDescription half = out;
    half.mSampleRate = 24000;
    CCHECK(AudioConverterNew(&out, &half, &conv) == noErr);
    for (int i = 0; i < 480; i++) ramp[i] = i / 480.0f;
    static Float32 res[300];
    UInt32 offset = 0, packets = 300;
    AudioBufferList list = {1, {{1, sizeof res, res}}};
    CCHECK(AudioConverterFillComplexBuffer(conv, feed, &offset, &packets, &list, NULL) == noErr && inputCalls >= 1);
    CCHECK(packets >= 235 && packets <= 240 && res[100] > 0.40f && res[100] < 0.43f);
    AudioStreamBasicDescription cur = {0};
    size = sizeof cur;
    CCHECK(AudioConverterGetProperty(conv, kAudioConverterCurrentOutputStreamDescription, &size, &cur) == noErr && cur.mSampleRate == 24000);
    CCHECK(AudioConverterReset(conv) == noErr && AudioConverterDispose(conv) == noErr);
    AudioComponentDescription any = {0, 0, kAudioUnitManufacturer_Apple, 0, 0};
    UInt32 n = 0;
    for (AudioComponent c = AudioComponentFindNext(NULL, &any); c; c = AudioComponentFindNext(c, &any)) n++;
    CCHECK(n == AudioComponentCount(&any) && n >= 10);
    Boolean b = true;
    OSStatus s = noErr;
    CCHECK(b && s == 0 && sizeof(Float64) == 8 && sizeof(SInt64) == 8);
    return failures;
}
