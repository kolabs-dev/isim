// The AudioToolbox headers as plain C (no Objective-C): a converter from 16-bit integers to floats, and the
// component list. Called from main.m; returns the number of failed checks and counts them in *checks.
#include <AudioToolbox/AudioToolbox.h>
#include <stdio.h>
#include <string.h>

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

// Apple's declarations from the generated header (issue #856), as plain C: values and C layouts
int decl_checks(int *checks) {
    int failures = 0;
    CCHECK(kAudioUnitProperty_ScheduleAudioSlice == 3300 && kAudioUnitProperty_ScheduledFileRegion == 3311);
    CCHECK(kAudioUnitParameterUnit_Hertz == 8 && kAudioUnitParameterUnit_Decibels == 13);
    CCHECK(kAudioUnitParameterFlag_IsReadable == (1UL << 30) && kAudioUnitParameterFlag_IsWritable == (1UL << 31));
    CCHECK(kAudioFileM4AType == 'm4af' && kAudioFile3GPType == '3gpp' && kAudioFileCAFType == 'caff');
    CCHECK(kAudioComponentErr_InstanceTimedOut == -66754 && kAudioUnitErr_RenderTimeout == -66745);
    CCHECK(sizeof(AudioUnitParameterInfo) == 104 && sizeof(CAFFileHeader) == 8 && sizeof(CAFChunkHeader) == 12);
    CCHECK(sizeof(ScheduledAudioSlice) == 112 && sizeof(AudioFileMarker) == 40);
    CCHECK(AUDIO_TOOLBOX_VERSION == 1060 && strcmp(kAUPresetVersionKey, "version") == 0);
    AudioUnitParameterInfo info = {0};
    info.unit = kAudioUnitParameterUnit_Seconds;
    info.flags = kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_CanRamp;
    CCHECK(info.unit == 4 && (info.flags & kAudioUnitParameterFlag_CanRamp) != 0);
    return failures;
}

// AudioToolbox's other functions (issue #856), as plain C: an Audio Unit registered in process (called through its
// AudioComponentPlugInInterface), Audio Format, Apple's inline helpers, AUGraph interactions, system sound properties
typedef struct { AudioComponentPlugInInterface iface; Float32 gain; int opened, initialized; } GainPlugIn;
static GainPlugIn gainPlugIn;
static OSStatus gainOpen(void *self, AudioComponentInstance instance) { ((GainPlugIn *)self)->opened++; return noErr; }
static OSStatus gainClose(void *self) { ((GainPlugIn *)self)->opened--; return noErr; }
static OSStatus gainInitialize(void *self) { ((GainPlugIn *)self)->initialized = 1; return noErr; }
static OSStatus gainGetParameter(void *self, AudioUnitParameterID id, AudioUnitScope scope, AudioUnitElement element, AudioUnitParameterValue *value) {
    if (id != 0) return kAudioUnitErr_InvalidParameter;
    *value = ((GainPlugIn *)self)->gain;
    return noErr;
}
static OSStatus gainSetParameter(void *self, AudioUnitParameterID id, AudioUnitScope scope, AudioUnitElement element, AudioUnitParameterValue value,
                                 UInt32 offset) {
    if (id != 0) return kAudioUnitErr_InvalidParameter;
    ((GainPlugIn *)self)->gain = value;
    return noErr;
}
static AudioComponentMethod gainLookup(SInt16 selector) {
    switch (selector) {
    case kAudioUnitInitializeSelect: return (AudioComponentMethod)gainInitialize;
    case kAudioUnitGetParameterSelect: return (AudioComponentMethod)gainGetParameter;
    case kAudioUnitSetParameterSelect: return (AudioComponentMethod)gainSetParameter;
    default: return NULL;
    }
}
static AudioComponentPlugInInterface *gainFactory(const AudioComponentDescription *desc) {
    gainPlugIn.iface.Open = gainOpen;
    gainPlugIn.iface.Close = gainClose;
    gainPlugIn.iface.Lookup = gainLookup;
    return &gainPlugIn.iface;
}

int function_checks(int *checks) {
    int failures = 0;
    // a registered Audio Unit
    AudioComponentDescription desc = {kAudioUnitType_Effect, 'gain', 'Isim', 0, 0};
    AudioComponent comp = AudioComponentRegister(&desc, CFSTR("Isim: Gain"), 0x00010002, gainFactory);
    CCHECK(comp != NULL && AudioComponentFindNext(NULL, &desc) == comp);
    UInt32 version = 0;
    CCHECK(AudioComponentGetVersion(comp, &version) == noErr && version == 0x00010002);
    AudioComponentValidationResult result = kAudioComponentValidationResult_Unknown;
    CCHECK(AudioComponentValidate(comp, NULL, &result) == noErr && result == kAudioComponentValidationResult_Passed && gainPlugIn.opened == 0);
    AudioComponentInstance unit = NULL;
    CCHECK(AudioComponentInstanceNew(comp, &unit) == noErr && unit != NULL && gainPlugIn.opened == 1);
    CCHECK(AudioUnitInitialize(unit) == noErr && gainPlugIn.initialized == 1);
    AudioUnitParameterValue v = 0;
    CCHECK(AudioUnitSetParameter(unit, 0, kAudioUnitScope_Global, 0, 0.5f, 0) == noErr && AudioUnitGetParameter(unit, 0, kAudioUnitScope_Global, 0, &v) == noErr
           && v == 0.5f);
    CCHECK(AudioComponentInstanceCanDo(unit, kAudioUnitGetParameterSelect) && !AudioComponentInstanceCanDo(unit, kAudioUnitRenderSelect));
    AudioUnitParameter p = {unit, 0, kAudioUnitScope_Global, 0};
    CCHECK(AUParameterSet(NULL, NULL, &p, 0.75f, 0) == noErr && gainPlugIn.gain == 0.75f);
    AudioTimeStamp ts = {0};
    AudioBufferList list = {1, {{1, 0, NULL}}};
    CCHECK(AudioUnitRender(unit, NULL, &ts, 0, 0, &list) != noErr);       // the plug-in has no render selector
    CCHECK(AudioComponentInstanceGetComponent(unit) == comp);
    CCHECK(AudioComponentInstanceDispose(unit) == noErr && gainPlugIn.opened == 0);
    CFDictionaryRef config = NULL;
    CCHECK(AudioComponentCopyConfigurationInfo(comp, &config) == noErr && config != NULL
           && CFDictionaryContainsKey(config, CFSTR(kAudioUnitConfigurationInfo_HasCustomView)));
    if (config) CFRelease(config);
    // isim's own units
    AudioComponentDescription mixDesc = {kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponentInstance mixer = NULL;
    AudioComponentInstanceNew(AudioComponentFindNext(NULL, &mixDesc), &mixer);
    CCHECK(AudioComponentInstanceCanDo(mixer, kAudioUnitRenderSelect) && !AudioComponentInstanceCanDo(mixer, kAudioOutputUnitStartSelect));
    AudioUnitParameterEvent ev = {0};
    ev.scope = kAudioUnitScope_Input; ev.element = 0; ev.parameter = kMultiChannelMixerParam_Volume;
    ev.eventType = kParameterEvent_Immediate; ev.eventValues.immediate.value = 0.3f;
    CCHECK(AudioUnitScheduleParameters(mixer, &ev, 1) == noErr && AudioUnitGetParameter(mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, &v) == noErr
           && v == 0.3f);
    AudioComponentInstanceDispose(mixer);
    // codecs are components too
    AudioComponentDescription decDesc = {kAudioDecoderComponentType, kAudioFormatMPEG4AAC, 0, 0, 0};
    CCHECK(AudioComponentCount(&decDesc) == 1);
    // Audio Format
    AudioStreamBasicDescription f = {48000, kAudioFormatLinearPCM, kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, 0, 0, 0, 2, 32, 0};
    UInt32 size = sizeof(f);
    CCHECK(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &f) == noErr && f.mBytesPerFrame == 8 && f.mFramesPerPacket == 1);
    UInt32 vbr = 1;
    size = sizeof(vbr);
    CCHECK(AudioFormatGetProperty(kAudioFormatProperty_FormatIsVBR, sizeof(f), &f, &size, &vbr) == noErr && vbr == 0);
    CCHECK(AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &size) == noErr && size == 8);
    CCHECK(AudioFormatGetProperty('none', 0, NULL, &size, &vbr) == kAudioFormatUnsupportedPropertyError);
    // Apple's inline helpers
    CCHECK(NumAudioFileMarkersToNumBytes(3) == 8 + 3 * sizeof(AudioFileMarker) && NumBytesToNumAudioFileMarkers(8 + 2 * sizeof(AudioFileMarker)) == 2);
    CCHECK(SetAudioUnitParameterDisplayType(kAudioUnitParameterFlag_IsReadable, kAudioUnitParameterFlag_DisplaySquared)
           == (kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_DisplaySquared));
    struct { AudioFileRegion r; AudioFileMarker extra; } regions = {{0}};
    regions.r.mNumberMarkers = 1;
    CCHECK((char *)NextAudioFileRegion(&regions.r) == (char *)&regions.r + offsetof(AudioFileRegion, mMarkers) + sizeof(AudioFileMarker));
    // AUGraph interactions
    AUGraph graph = NULL;
    NewAUGraph(&graph);
    AudioComponentDescription outDesc = {kAudioUnitType_Output, kAudioUnitSubType_GenericOutput, kAudioUnitManufacturer_Apple, 0, 0};
    AUNode mixNode = 0, outNode = 0;
    AUGraphAddNode(graph, &mixDesc, &mixNode);
    AUGraphAddNode(graph, &outDesc, &outNode);
    AUGraphConnectNodeInput(graph, mixNode, 0, outNode, 0);
    AUNodeInteraction inter[4];
    UInt32 n = 4;
    CCHECK(AUGraphGetNodeInteractions(graph, mixNode, &n, inter) == noErr && n == 1 && inter[0].nodeInteractionType == kAUNodeInteraction_Connection
           && inter[0].nodeInteraction.connection.sourceNode == mixNode && inter[0].nodeInteraction.connection.destNode == outNode);
    DisposeAUGraph(graph);
    // system sound properties
    SystemSoundID sound = 1104;
    UInt32 dies = 0;
    size = sizeof(dies);
    CCHECK(AudioServicesGetProperty(kAudioServicesPropertyCompletePlaybackIfAppDies, sizeof(sound), &sound, &size, &dies) == noErr && dies == 0);
    CCHECK(AudioServicesGetProperty('none', sizeof(sound), &sound, &size, &dies) == kAudioServicesUnsupportedPropertyError);
    return failures;
}
