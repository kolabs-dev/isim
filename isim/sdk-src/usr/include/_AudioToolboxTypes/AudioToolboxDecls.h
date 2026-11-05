#pragma once
/* isim AudioToolbox: Apple's C declarations that isim had not yet (issue #856), with Apple's names, values and C
 * layouts: Audio Unit properties, parameters and their units and flags, scopes and errors, Audio Codec, Audio Format
 * and Audio File property IDs, the CAF file structures, scheduled audio slices and file regions, parameter events,
 * render events, the Audio Session constants. Seen by Swift (the AudioToolbox module re-exports it) and by C. */
#include <stddef.h>
#include <CoreAudioTypes/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMIDI/CoreMIDI.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#if defined(__OBJC__)
#import <Foundation/Foundation.h>
#endif
#ifndef ATTRIBUTE_PACKED
#define ATTRIBUTE_PACKED __attribute__((__packed__))
#endif
__BEGIN_DECLS
#pragma clang assume_nonnull begin

/* CoreAudioBaseTypes.h */
struct AudioClassDescription {
    OSType mType;
    OSType mSubType;
    OSType mManufacturer;
};
typedef struct AudioClassDescription AudioClassDescription;

/* AUComponent.h */
enum : UInt32 {
    kAudioUnitType_MIDIProcessor = 'aumi',
    kAudioUnitType_SpeechSynthesizer = 'ausp'
};
enum : UInt32 {
    kAudioUnitType_RemoteEffect = 'aurx',
    kAudioUnitType_RemoteGenerator = 'aurg',
    kAudioUnitType_RemoteInstrument = 'auri',
    kAudioUnitType_RemoteMusicEffect = 'aurm'
};
enum : UInt32 {
    kAudioUnitSubType_DeferredRenderer = 'defr',
    kAudioUnitSubType_Splitter = 'splt',
    kAudioUnitSubType_MultiSplitter = 'mspl',
    kAudioUnitSubType_Merger = 'merg',
    kAudioUnitSubType_AUiPodTimeOther = 'ipto',
    kAudioUnitSubType_RoundTripAAC = 'raac',
    kAudioUnitSubType_AUAudioMix = 'amix'};
enum : UInt32 {
    kAudioUnitSubType_TimePitch = 'tmpt'
};
enum : UInt32 {
    kAudioUnitSubType_DynamicsProcessor = 'dcmp',
    kAudioUnitSubType_SampleDelay = 'sdly',
    kAudioUnitSubType_AUSoundIsolation = 'vois'};
enum : UInt32 {
    kAudioUnitSubType_MatrixMixer = 'mxmx',
    kAudioUnitSubType_SpatialMixer = '3dem'};
enum : UInt32 {
    kAudioUnitSubType_AU3DMixerEmbedded
    = '3dem'
};
enum : UInt32 {
    kAudioUnitSubType_ScheduledSoundPlayer	= 'sspl',
    kAudioUnitSubType_AudioFilePlayer = 'afpl'
};
enum : OSStatus {
    kAudioUnitErr_UnknownFileType = -10870,
    kAudioUnitErr_FileNotSpecified = -10869,
    kAudioUnitErr_MIDIOutputBufferFull = -66753,
    kAudioComponentErr_InstanceTimedOut = -66754,
    kAudioUnitErr_RenderTimeout = -66745,
    kAudioUnitErr_ExtensionNotFound = -66744,
    kAudioUnitErr_InvalidParameterValue = -66743,
    kAudioUnitErr_InvalidFilePath = -66742,
    kAudioUnitErr_MissingKey = -66741,
    kAudioUnitErr_ComponentManagerNotSupported = -66740,
    kAudioUnitErr_MultipleVoiceProcessors = -66635
};
enum : OSStatus {
    kAudioComponentErr_DuplicateDescription = -66752,
    kAudioComponentErr_UnsupportedType = -66751,
    kAudioComponentErr_TooManyInstances = -66750,
    kAudioComponentErr_NotPermitted = -66748,
    kAudioComponentErr_InitializationTimedOut	= -66747,
    kAudioComponentErr_InvalidFormat = -66746
};
typedef UInt32 AudioUnitPropertyID;
typedef UInt32 AudioUnitScope;
typedef UInt32 AudioUnitElement;
typedef UInt32 AudioUnitParameterID;
typedef	Float32 AudioUnitParameterValue;
typedef CF_ENUM(UInt32, AUParameterEventType)
    {
    kParameterEvent_Immediate	= 1,
    kParameterEvent_Ramped = 2
};
struct AudioUnitParameterEvent
    {
    AudioUnitScope scope;
    AudioUnitElement element;
    AudioUnitParameterID	parameter;
    AUParameterEventType	eventType;
    union
    {
    struct
    {
    SInt32 startBufferOffset;
    UInt32 durationInFrames;
    AudioUnitParameterValue startValue;
    AudioUnitParameterValue endValue;
} ramp;
    struct
    {
    UInt32 bufferOffset;
    AudioUnitParameterValue value;
} immediate;
} eventValues;
};
typedef struct AudioUnitParameterEvent	AudioUnitParameterEvent;
struct AudioUnitProperty
    {
    AudioUnit mAudioUnit;
    AudioUnitPropertyID mPropertyID;
    AudioUnitScope mScope;
    AudioUnitElement mElement;
};
typedef struct AudioUnitProperty	AudioUnitProperty;
typedef void
    (*AUInputSamplesInOutputCallback)(	void * inRefCon,
    const AudioTimeStamp * inOutputTimeStamp,
    Float64 inInputSample,
    Float64 inNumberInputSamples) ;
enum {
    kAudioUnitRange = 0x0000,
    kAudioUnitInitializeSelect = 0x0001,
    kAudioUnitUninitializeSelect = 0x0002,
    kAudioUnitGetPropertyInfoSelect = 0x0003,
    kAudioUnitGetPropertySelect = 0x0004,
    kAudioUnitSetPropertySelect = 0x0005,
    kAudioUnitAddPropertyListenerSelect = 0x000A,
    kAudioUnitRemovePropertyListenerSelect	= 0x000B,
    kAudioUnitRemovePropertyListenerWithUserDataSelect = 0x0012,
    kAudioUnitAddRenderNotifySelect = 0x000F,
    kAudioUnitRemoveRenderNotifySelect = 0x0010,
    kAudioUnitGetParameterSelect = 0x0006,
    kAudioUnitSetParameterSelect = 0x0007,
    kAudioUnitScheduleParametersSelect = 0x0011,
    kAudioUnitRenderSelect = 0x000E,
    kAudioUnitResetSelect = 0x0009,
    kAudioUnitComplexRenderSelect = 0x0013,
    kAudioUnitProcessSelect = 0x0014,
    kAudioUnitProcessMultipleSelect = 0x0015
};
typedef OSStatus
    (*AudioUnitInitializeProc) (void *self);
typedef OSStatus
    (*AudioUnitUninitializeProc) (void *self);
typedef OSStatus
    (*AudioUnitGetPropertyInfoProc) (void *self, AudioUnitPropertyID prop, AudioUnitScope scope,
    AudioUnitElement elem, UInt32 * __nullable outDataSize, Boolean * __nullable outWritable);
typedef OSStatus
    (*AudioUnitGetPropertyProc) (void *self, AudioUnitPropertyID inID, AudioUnitScope inScope,
    AudioUnitElement inElement, void *outData, UInt32 *ioDataSize);
typedef OSStatus
    (*AudioUnitSetPropertyProc) (void *self, AudioUnitPropertyID inID, AudioUnitScope inScope,
    AudioUnitElement inElement, const void *inData, UInt32 inDataSize);
typedef OSStatus
    (*AudioUnitAddPropertyListenerProc) (void *self, AudioUnitPropertyID prop,
    AudioUnitPropertyListenerProc proc, void *userData);
typedef OSStatus
    (*AudioUnitRemovePropertyListenerProc) (void *self, AudioUnitPropertyID prop,
    AudioUnitPropertyListenerProc proc);
typedef OSStatus
    (*AudioUnitRemovePropertyListenerWithUserDataProc) (void *self, AudioUnitPropertyID prop,
    AudioUnitPropertyListenerProc proc, void * __nullable userData);
typedef OSStatus
    (*AudioUnitAddRenderNotifyProc) (void *self, AURenderCallback proc, void * __nullable userData);
typedef OSStatus
    (*AudioUnitRemoveRenderNotifyProc) (void *self, AURenderCallback proc, void * __nullable userData);
typedef OSStatus
    (*AudioUnitScheduleParametersProc) (void *self, const AudioUnitParameterEvent *events, UInt32 numEvents) ;
typedef OSStatus
    (*AudioUnitResetProc) (void *self, AudioUnitScope inScope, AudioUnitElement	inElement);
typedef OSStatus
    (*AudioUnitComplexRenderProc) (void *self, AudioUnitRenderActionFlags * __nullable ioActionFlags, const AudioTimeStamp *inTimeStamp,
    UInt32 inOutputBusNumber, UInt32 inNumberOfPackets, UInt32 *outNumberOfPackets,
    AudioStreamPacketDescription *outPacketDescriptions, AudioBufferList *ioData,
    void *outMetadata, UInt32 *outMetadataByteSize) ;
typedef OSStatus
    (*AudioUnitProcessProc) (void *self, AudioUnitRenderActionFlags * __nullable ioActionFlags, const AudioTimeStamp *inTimeStamp,
    UInt32 inNumberFrames, AudioBufferList *ioData) ;
typedef OSStatus
    (*AudioUnitProcessMultipleProc) (void *self, AudioUnitRenderActionFlags * __nullable ioActionFlags, const AudioTimeStamp *inTimeStamp,
    UInt32 inNumberFrames, UInt32 inNumberInputBufferLists, const AudioBufferList * __nonnull * __nonnull inInputBufferLists,
    UInt32 inNumberOutputBufferLists, AudioBufferList * __nonnull * __nonnull ioOutputBufferLists) ;
typedef OSStatus
    (*AudioUnitGetParameterProc)(	void * inComponentStorage,
    AudioUnitParameterID inID,
    AudioUnitScope inScope,
    AudioUnitElement inElement,
    AudioUnitParameterValue *	outValue) ;
typedef OSStatus
    (*AudioUnitSetParameterProc)(	void * inComponentStorage,
    AudioUnitParameterID inID,
    AudioUnitScope inScope,
    AudioUnitElement inElement,
    AudioUnitParameterValue inValue,
    UInt32 inBufferOffsetInFrames) ;
typedef OSStatus
    (*AudioUnitRenderProc)( void * inComponentStorage,
    AudioUnitRenderActionFlags * __nullable ioActionFlags,
    const AudioTimeStamp * inTimeStamp,
    UInt32 inOutputBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList * ioData) ;

/* AudioComponent.h */
typedef CF_OPTIONS(UInt32, AudioComponentFlags) {
    kAudioComponentFlag_Unsearchable = 1,
    kAudioComponentFlag_SandboxSafe = 2,
    kAudioComponentFlag_IsV3AudioUnit = 4,
    kAudioComponentFlag_RequiresAsyncInstantiation = 8,
    kAudioComponentFlag_CanLoadInProcess = 0x10
};
typedef OSStatus (*AudioComponentMethod)(void *self, ...);
struct AudioComponentPlugInInterface {
    OSStatus (*Open)(void *self, AudioComponentInstance mInstance);
    OSStatus (*Close)(void *self);
    AudioComponentMethod __nullable	(* __nonnull Lookup)(SInt16 selector);
    void * __nullable reserved;
};
typedef struct AudioComponentPlugInInterface AudioComponentPlugInInterface;
typedef AudioComponentPlugInInterface * __nullable (*AudioComponentFactoryFunction)(const AudioComponentDescription *inDesc);
typedef CF_ENUM(UInt32, AudioComponentValidationResult)
    {
    kAudioComponentValidationResult_Unknown = 0,
    kAudioComponentValidationResult_Passed,
    kAudioComponentValidationResult_Failed,
    kAudioComponentValidationResult_TimedOut,
    kAudioComponentValidationResult_UnauthorizedError_Open,
    kAudioComponentValidationResult_UnauthorizedError_Init
};

/* AudioUnitProperties.h */
enum : AudioUnitScope {
    kAudioUnitScope_Note = 5,
    kAudioUnitScope_Layer = 6,
    kAudioUnitScope_LayerItem	= 7
};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_CPULoad = 6,
    kAudioUnitProperty_SupportedNumChannels = 13,
    kAudioUnitProperty_ParameterValueStrings = 16,
    kAudioUnitProperty_AudioChannelLayout = 19,
    kAudioUnitProperty_FactoryPresets = 24,
    kAudioUnitProperty_RenderQuality = 26,
    kAudioUnitProperty_HostCallbacks = 27,
    kAudioUnitProperty_InPlaceProcessing = 29,
    kAudioUnitProperty_ElementName = 30,
    kAudioUnitProperty_SupportedChannelLayoutTags	= 32,
    kAudioUnitProperty_PresentPreset = 36,
    kAudioUnitProperty_DependentParameters = 45,
    kAudioUnitProperty_InputSamplesInOutput = 49,
    kAudioUnitProperty_FrequencyResponse = 52,
    kAudioUnitProperty_ParameterHistoryInfo = 53,
    kAudioUnitProperty_NickName = 54,
    kAudioUnitProperty_OfflineRender = 37,
    kAudioUnitProperty_ParameterIDName = 34,
    kAudioUnitProperty_ParameterStringFromValue = 33,
    kAudioUnitProperty_ParameterClumpName = 35,
    kAudioUnitProperty_ParameterValueFromString = 38,
    kAudioUnitProperty_ContextName = 25,
    kAudioUnitProperty_PresentationLatency = 40,
    kAudioUnitProperty_ClassInfoFromDocument = 50,
    kAudioUnitProperty_RequestViewController = 56,
    kAudioUnitProperty_ParametersForOverview = 57,
    kAudioUnitProperty_SupportsMPE = 58,
    kAudioUnitProperty_LastRenderSampleTime = 61,
    kAudioUnitProperty_LoadedOutOfProcess = 62,
    kAudioUnitProperty_MIDIOutputCallbackInfo = 47,
    kAudioUnitProperty_MIDIOutputCallback = 48,
    kAudioUnitProperty_MIDIOutputEventListCallback	= 63,
    kAudioUnitProperty_AudioUnitMIDIProtocol = 64,
    kAudioUnitProperty_HostMIDIProtocol = 65,
    kAudioUnitProperty_MIDIOutputBufferSizeHint = 66
};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_RemoteControlEventListener	= 100,
    kAudioUnitProperty_IsInterAppConnected = 101,
    kAudioUnitProperty_PeerURL = 102
};
struct AUChannelInfo {
    SInt16 inChannels;
    SInt16 outChannels;
};
typedef struct AUChannelInfo AUChannelInfo;
struct AudioUnitExternalBuffer {
    Byte * buffer;
    UInt32 size;
};
typedef struct AudioUnitExternalBuffer AudioUnitExternalBuffer;
struct AUPreset {
    SInt32 presetNumber;
    CFStringRef	__nullable	presetName;
};
typedef struct AUPreset AUPreset;
enum {
    kRenderQuality_Max = 127,
    kRenderQuality_High = 96,
    kRenderQuality_Medium = 64,
    kRenderQuality_Low = 32,
    kRenderQuality_Min = 0
};
enum {
    kNumberOfResponseFrequencies = 1024
};
struct AudioUnitFrequencyResponseBin {
    Float64 mFrequency;
    Float64 mMagnitude;
};
typedef struct AudioUnitFrequencyResponseBin AudioUnitFrequencyResponseBin;
typedef OSStatus (*HostCallback_GetBeatAndTempo)(void * __nullable	inHostUserData,
    Float64	* __nullable	outCurrentBeat,
    Float64	* __nullable	outCurrentTempo) ;
typedef OSStatus (*HostCallback_GetMusicalTimeLocation)(void * __nullable	inHostUserData,
    UInt32 * __nullable outDeltaSampleOffsetToNextBeat,
    Float32 * __nullable outTimeSig_Numerator,
    UInt32 * __nullable outTimeSig_Denominator,
    Float64 * __nullable outCurrentMeasureDownBeat) ;
typedef OSStatus (*HostCallback_GetTransportState)(void * __nullable	inHostUserData,
    Boolean * __nullable outIsPlaying,
    Boolean * __nullable outTransportStateChanged,
    Float64 * __nullable outCurrentSampleInTimeLine,
    Boolean * __nullable outIsCycling,
    Float64 * __nullable outCycleStartBeat,
    Float64 * __nullable outCycleEndBeat) ;
typedef OSStatus (*HostCallback_GetTransportState2)(void * __nullable	inHostUserData,
    Boolean * __nullable outIsPlaying,
    Boolean	* __nullable outIsRecording,
    Boolean * __nullable outTransportStateChanged,
    Float64 * __nullable outCurrentSampleInTimeLine,
    Boolean * __nullable outIsCycling,
    Float64 * __nullable outCycleStartBeat,
    Float64 * __nullable outCycleEndBeat) ;
struct HostCallbackInfo {
    void * __nullable hostUserData;
    HostCallback_GetBeatAndTempo __nullable beatAndTempoProc;
    HostCallback_GetMusicalTimeLocation __nullable musicalTimeLocationProc;
    HostCallback_GetTransportState __nullable transportStateProc;
    HostCallback_GetTransportState2 __nullable transportStateProc2;
};
typedef struct HostCallbackInfo HostCallbackInfo;
struct AUDependentParameter {
    AudioUnitScope mScope;
    AudioUnitParameterID	mParameterID;
};
typedef struct AUDependentParameter AUDependentParameter;
typedef OSStatus
    (*AUMIDIOutputCallback)(void * __nullable userData,
    const AudioTimeStamp * timeStamp,
    UInt32 midiOutNum,
    const struct MIDIPacketList *	pktlist) ;
struct AUMIDIOutputCallbackStruct {
    AUMIDIOutputCallback	midiOutputCallback;
    void * __nullable userData;
};
typedef struct AUMIDIOutputCallbackStruct AUMIDIOutputCallbackStruct;
struct AUInputSamplesInOutputCallbackStruct {
    AUInputSamplesInOutputCallback inputToOutputCallback;
    void * __nullable userData;
};
typedef struct AUInputSamplesInOutputCallbackStruct AUInputSamplesInOutputCallbackStruct;
struct AudioUnitParameterHistoryInfo {
    Float32 updatesPerSecond;
    Float32 historyDurationInSeconds;
};
typedef struct AudioUnitParameterHistoryInfo AudioUnitParameterHistoryInfo;
typedef int64_t AUEventSampleTime;
typedef OSStatus (^AUMIDIEventListBlock)(AUEventSampleTime	eventSampleTime,
    uint8_t cable,
    const struct MIDIEventList * eventList) ;
typedef CF_ENUM(UInt32, AudioUnitParameterUnit)
    {
    kAudioUnitParameterUnit_Generic = 0,
    kAudioUnitParameterUnit_Indexed = 1,
    kAudioUnitParameterUnit_Boolean = 2,
    kAudioUnitParameterUnit_Percent = 3,
    kAudioUnitParameterUnit_Seconds = 4,
    kAudioUnitParameterUnit_SampleFrames = 5,
    kAudioUnitParameterUnit_Phase = 6,
    kAudioUnitParameterUnit_Rate = 7,
    kAudioUnitParameterUnit_Hertz = 8,
    kAudioUnitParameterUnit_Cents = 9,
    kAudioUnitParameterUnit_RelativeSemiTones	= 10,
    kAudioUnitParameterUnit_MIDINoteNumber = 11,
    kAudioUnitParameterUnit_MIDIController = 12,
    kAudioUnitParameterUnit_Decibels = 13,
    kAudioUnitParameterUnit_LinearGain = 14,
    kAudioUnitParameterUnit_Degrees = 15,
    kAudioUnitParameterUnit_EqualPowerCrossfade = 16,
    kAudioUnitParameterUnit_MixerFaderCurve1	= 17,
    kAudioUnitParameterUnit_Pan = 18,
    kAudioUnitParameterUnit_Meters = 19,
    kAudioUnitParameterUnit_AbsoluteCents = 20,
    kAudioUnitParameterUnit_Octaves = 21,
    kAudioUnitParameterUnit_BPM = 22,
    kAudioUnitParameterUnit_Beats = 23,
    kAudioUnitParameterUnit_Milliseconds = 24,
    kAudioUnitParameterUnit_Ratio = 25,
    kAudioUnitParameterUnit_CustomUnit = 26,
    kAudioUnitParameterUnit_MIDI2Controller = 27
};
typedef CF_OPTIONS(UInt32, AudioUnitParameterOptions)
    {
    kAudioUnitParameterFlag_CFNameRelease = (1UL << 4),
    kAudioUnitParameterFlag_OmitFromPresets = (1UL << 13),
    kAudioUnitParameterFlag_PlotHistory = (1UL << 14),
    kAudioUnitParameterFlag_MeterReadOnly = (1UL << 15),
    kAudioUnitParameterFlag_DisplayMask = (7UL << 16) | (1UL << 22),
    kAudioUnitParameterFlag_DisplaySquareRoot	= (1UL << 16),
    kAudioUnitParameterFlag_DisplaySquared = (2UL << 16),
    kAudioUnitParameterFlag_DisplayCubed = (3UL << 16),
    kAudioUnitParameterFlag_DisplayCubeRoot = (4UL << 16),
    kAudioUnitParameterFlag_DisplayExponential	= (5UL << 16),
    kAudioUnitParameterFlag_HasClump = (1UL << 20),
    kAudioUnitParameterFlag_ValuesHaveStrings	= (1UL << 21),
    kAudioUnitParameterFlag_DisplayLogarithmic = (1UL << 22),
    kAudioUnitParameterFlag_IsHighResolution = (1UL << 23),
    kAudioUnitParameterFlag_NonRealTime = (1UL << 24),
    kAudioUnitParameterFlag_CanRamp = (1UL << 25),
    kAudioUnitParameterFlag_ExpertMode = (1UL << 26),
    kAudioUnitParameterFlag_HasCFNameString = (1UL << 27),
    kAudioUnitParameterFlag_IsGlobalMeta = (1UL << 28),
    kAudioUnitParameterFlag_IsElementMeta = (1UL << 29),
    kAudioUnitParameterFlag_IsReadable = (1UL << 30),
    kAudioUnitParameterFlag_IsWritable = (1UL << 31)
};
struct AudioUnitParameterInfo {
    char name[52];
    CFStringRef __nullable unitName;
    UInt32 clumpID;
    CFStringRef __nullable cfNameString;
    AudioUnitParameterUnit unit;
    AudioUnitParameterValue minValue;
    AudioUnitParameterValue maxValue;
    AudioUnitParameterValue defaultValue;
    AudioUnitParameterOptions	flags;
};
typedef struct AudioUnitParameterInfo AudioUnitParameterInfo;
enum {
    kAudioUnitClumpID_System = 0
};
enum {
    kAudioUnitParameterName_Full = -1
};
struct AudioUnitParameterNameInfo {
    AudioUnitParameterID	inID;
    SInt32 inDesiredLength;
    CFStringRef __nullable	outName;
};
typedef struct AudioUnitParameterNameInfo AudioUnitParameterNameInfo;
typedef struct AudioUnitParameterNameInfo AudioUnitParameterIDName;
struct AudioUnitParameterStringFromValue {
    AudioUnitParameterID inParamID;
    const AudioUnitParameterValue * inValue;
    CFStringRef __nullable outString;
};
typedef struct AudioUnitParameterStringFromValue AudioUnitParameterStringFromValue;
struct AudioUnitParameterValueFromString {
    AudioUnitParameterID inParamID;
    CFStringRef inString;
    AudioUnitParameterValue outValue;
};
typedef struct AudioUnitParameterValueFromString AudioUnitParameterValueFromString;
typedef CF_ENUM(UInt32, AudioUnitRemoteControlEvent) {
    kAudioUnitRemoteControlEvent_TogglePlayPause	= 1,
    kAudioUnitRemoteControlEvent_ToggleRecord = 2,
    kAudioUnitRemoteControlEvent_Rewind = 3
};
typedef void (^AudioUnitRemoteControlEventListener)(AudioUnitRemoteControlEvent event);
enum : AudioUnitPropertyID {
    kAudioUnitProperty_SampleRateConverterComplexity	= 3014
};
enum : UInt32 {
    kAudioUnitSampleRateConverterComplexity_Linear = 'line',
    kAudioUnitSampleRateConverterComplexity_Normal = 'norm',
    kAudioUnitSampleRateConverterComplexity_Mastering = 'bats'
};
enum : AudioUnitPropertyID {
    kAudioOutputUnitProperty_ChannelMap = 2002,
    kAudioOutputUnitProperty_StartTime = 2004,
    kAudioOutputUnitProperty_HasIO = 2006,
    kAudioOutputUnitProperty_StartTimestampsAtZero = 2007};
enum : AudioUnitPropertyID {
    kAudioOutputUnitProperty_MIDICallbacks = 2010,
    kAudioOutputUnitProperty_HostReceivesRemoteControlEvents
    = 2011,
    kAudioOutputUnitProperty_RemoteControlToHost	= 2012,
    kAudioOutputUnitProperty_HostTransportState = 2013,
    kAudioOutputUnitProperty_NodeComponentDescription = 2014
};
struct AudioOutputUnitMIDICallbacks {
    void * __nullable userData;
    void (*MIDIEventProc)(void * __nullable userData, UInt32 inStatus, UInt32 inData1, UInt32 inData2, UInt32 inOffsetSampleFrame);
    void (*MIDISysExProc)(void * __nullable userData, const UInt8 *inData, UInt32 inLength);
};
typedef struct AudioOutputUnitMIDICallbacks AudioOutputUnitMIDICallbacks;
struct AudioOutputUnitStartAtTimeParams {
    AudioTimeStamp mTimestamp;
    UInt32 mFlags;
};
typedef struct AudioOutputUnitStartAtTimeParams AudioOutputUnitStartAtTimeParams;
typedef CF_ENUM(UInt32, AUVoiceIOSpeechActivityEvent)
    {
    kAUVoiceIOSpeechActivityHasStarted = 0,
    kAUVoiceIOSpeechActivityHasEnded = 1
};
typedef void (^AUVoiceIOMutedSpeechActivityEventListener)(AUVoiceIOSpeechActivityEvent event);
enum : AudioUnitPropertyID {
    kAUVoiceIOProperty_MutedSpeechActivityEventListener = 2106
} ;
typedef CF_ENUM(UInt32, AUVoiceIOOtherAudioDuckingLevel) {
    kAUVoiceIOOtherAudioDuckingLevelDefault = 0,
    kAUVoiceIOOtherAudioDuckingLevelMin = 10,
    kAUVoiceIOOtherAudioDuckingLevelMid = 20,
    kAUVoiceIOOtherAudioDuckingLevelMax = 30
};
struct AUVoiceIOOtherAudioDuckingConfiguration {
    Boolean mEnableAdvancedDucking;
    AUVoiceIOOtherAudioDuckingLevel mDuckingLevel;
};
typedef struct AUVoiceIOOtherAudioDuckingConfiguration AUVoiceIOOtherAudioDuckingConfiguration;
enum : AudioUnitPropertyID {
    kAUVoiceIOProperty_OtherAudioDuckingConfiguration = 2108
} ;
enum : AudioUnitPropertyID {
    kAUVoiceIOProperty_DuckNonVoiceAudio = 2102
} ;
enum : AudioUnitPropertyID {
    kAUVoiceIOProperty_VoiceProcessingQuality = 2103
} ;
enum : AudioUnitPropertyID {
    kAUNBandEQProperty_BiquadCoefficients = 2203
};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_MatrixLevels = 3006,
    kAudioUnitProperty_MatrixDimensions = 3009,
    kAudioUnitProperty_MeterClipping = 3011,
    kAudioUnitProperty_InputAnchorTimeStamp = 3016
};
struct AudioUnitMeterClipping {
    Float32 peakValueSinceLastCall;
    Boolean sawInfinity;
    Boolean sawNotANumber;
};
typedef struct AudioUnitMeterClipping AudioUnitMeterClipping;
enum : AudioUnitPropertyID {
    kAudioUnitProperty_ReverbRoomType = 10,
    kAudioUnitProperty_UsesInternalReverb = 1005,
    kAudioUnitProperty_SpatializationAlgorithm = 3000,
    kAudioUnitProperty_SpatialMixerRenderingFlags = 3003,
    kAudioUnitProperty_SpatialMixerSourceMode = 3005,
    kAudioUnitProperty_SpatialMixerDistanceParams = 3010,
    kAudioUnitProperty_SpatialMixerAttenuationCurve = 3013,
    kAudioUnitProperty_SpatialMixerOutputType = 3100,
    kAudioUnitProperty_SpatialMixerPointSourceInHeadMode	= 3103,
    kAudioUnitProperty_SpatialMixerEnableHeadTracking = 3111,
    kAudioUnitProperty_SpatialMixerPersonalizedHRTFMode = 3113,
    kAudioUnitProperty_SpatialMixerAnyInputIsUsingPersonalizedHRTF = 3116
};
typedef CF_ENUM(UInt32, AUSpatializationAlgorithm) {
    kSpatializationAlgorithm_EqualPowerPanning = 0,
    kSpatializationAlgorithm_SphericalHead = 1,
    kSpatializationAlgorithm_HRTF = 2,
    kSpatializationAlgorithm_SoundField = 3,
    kSpatializationAlgorithm_VectorBasedPanning = 4,
    kSpatializationAlgorithm_StereoPassThrough = 5,
    kSpatializationAlgorithm_HRTFHQ = 6,
    kSpatializationAlgorithm_UseOutputType = 7
};
typedef CF_ENUM(UInt32, AUSpatialMixerSourceMode) {
    kSpatialMixerSourceMode_SpatializeIfMono	= 0,
    kSpatialMixerSourceMode_Bypass = 1,
    kSpatialMixerSourceMode_PointSource = 2,
    kSpatialMixerSourceMode_AmbienceBed = 3
};
typedef CF_ENUM(UInt32, AUReverbRoomType) {
    kReverbRoomType_SmallRoom = 0,
    kReverbRoomType_MediumRoom = 1,
    kReverbRoomType_LargeRoom = 2,
    kReverbRoomType_MediumHall = 3,
    kReverbRoomType_LargeHall = 4,
    kReverbRoomType_Plate = 5,
    kReverbRoomType_MediumChamber	= 6,
    kReverbRoomType_LargeChamber	= 7,
    kReverbRoomType_Cathedral = 8,
    kReverbRoomType_LargeRoom2 = 9,
    kReverbRoomType_MediumHall2 = 10,
    kReverbRoomType_MediumHall3 = 11,
    kReverbRoomType_LargeHall2 = 12
};
typedef CF_ENUM(UInt32, AUSpatialMixerAttenuationCurve) {
    kSpatialMixerAttenuationCurve_Power = 0,
    kSpatialMixerAttenuationCurve_Exponential = 1,
    kSpatialMixerAttenuationCurve_Inverse = 2,
    kSpatialMixerAttenuationCurve_Linear = 3
};
struct MixerDistanceParams {
    Float32 mReferenceDistance;
    Float32 mMaxDistance;
    Float32 mMaxAttenuation;
};
typedef struct MixerDistanceParams MixerDistanceParams;
typedef CF_OPTIONS(UInt32, AUSpatialMixerRenderingFlags) {
    kSpatialMixerRenderingFlags_InterAuralDelay = (1L << 0),
    kSpatialMixerRenderingFlags_DistanceAttenuation = (1L << 2),
};
typedef CF_ENUM(UInt32, AUSpatialMixerPersonalizedHRTFMode) {
    kSpatialMixerPersonalizedHRTFMode_Off = 0,
    kSpatialMixerPersonalizedHRTFMode_On = 1,
    kSpatialMixerPersonalizedHRTFMode_Auto = 2
};
typedef CF_ENUM(UInt32, AUSpatialMixerOutputType) {
    kSpatialMixerOutputType_Headphones = 1,
    kSpatialMixerOutputType_BuiltInSpeakers = 2,
    kSpatialMixerOutputType_ExternalSpeakers	= 3
};
typedef CF_ENUM(UInt32, AUSpatialMixerPointSourceInHeadMode) {
    kSpatialMixerPointSourceInHeadMode_Mono = 0,
    kSpatialMixerPointSourceInHeadMode_Bypass	= 1
};
enum : AudioUnitPropertyID {
    kAUAudioMixProperty_SpatialAudioMixMetadata = 5000,
    kAUAudioMixProperty_EnableSpatialization = 5001};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_3DMixerDistanceParams = 3010,
    kAudioUnitProperty_3DMixerAttenuationCurve = 3013,
    kAudioUnitProperty_DopplerShift = 3002,
    kAudioUnitProperty_3DMixerRenderingFlags = 3003,
    kAudioUnitProperty_3DMixerDistanceAtten = 3004,
    kAudioUnitProperty_ReverbPreset = 3012
} ;
typedef CF_OPTIONS(UInt32, AU3DMixerRenderingFlags) {
    k3DMixerRenderingFlags_InterAuralDelay = (1L << 0),
    k3DMixerRenderingFlags_DopplerShift = (1L << 1),
    k3DMixerRenderingFlags_DistanceAttenuation = (1L << 2),
    k3DMixerRenderingFlags_DistanceFilter = (1L << 3),
    k3DMixerRenderingFlags_DistanceDiffusion = (1L << 4),
    k3DMixerRenderingFlags_LinearDistanceAttenuation = (1L << 5),
    k3DMixerRenderingFlags_ConstantReverbBlend = (1L << 6)
};
typedef CF_ENUM(UInt32, AU3DMixerAttenuationCurve) {
    k3DMixerAttenuationCurve_Power = 0,
    k3DMixerAttenuationCurve_Exponential = 1,
    k3DMixerAttenuationCurve_Inverse = 2,
    k3DMixerAttenuationCurve_Linear = 3
};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_ScheduleAudioSlice = 3300,
    kAudioUnitProperty_ScheduleStartTimeStamp = 3301,
    kAudioUnitProperty_CurrentPlayTime = 3302
};
typedef CF_OPTIONS(UInt32, AUScheduledAudioSliceFlags) {
    kScheduledAudioSliceFlag_Complete = 0x01,
    kScheduledAudioSliceFlag_BeganToRender = 0x02,
    kScheduledAudioSliceFlag_BeganToRenderLate = 0x04,
    kScheduledAudioSliceFlag_Loop = 0x08,
    kScheduledAudioSliceFlag_Interrupt = 0x10,
    kScheduledAudioSliceFlag_InterruptAtLoop = 0x20
};
typedef struct ScheduledAudioSlice ScheduledAudioSlice;
typedef void (*ScheduledAudioSliceCompletionProc)(void * __nullable userData, ScheduledAudioSlice *bufferList) ;
struct ScheduledAudioSlice {
    AudioTimeStamp mTimeStamp;
    ScheduledAudioSliceCompletionProc __nullable	mCompletionProc;
    void * mCompletionProcUserData;
    AUScheduledAudioSliceFlags mFlags;
    UInt32 mReserved;
    void *	__nullable mReserved2;
    UInt32 mNumberFrames;
    AudioBufferList * mBufferList;
};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_ScheduledFileIDs = 3310,
    kAudioUnitProperty_ScheduledFileRegion = 3311,
    kAudioUnitProperty_ScheduledFilePrime = 3312,
    kAudioUnitProperty_ScheduledFileBufferSizeFrames = 3313,
    kAudioUnitProperty_ScheduledFileNumberBuffers = 3314
};
typedef struct ScheduledAudioFileRegion ScheduledAudioFileRegion;
typedef void (*ScheduledAudioFileRegionCompletionProc)(void * __nullable userData,
    ScheduledAudioFileRegion *fileRegion, OSStatus result);
struct ScheduledAudioFileRegion {
    AudioTimeStamp mTimeStamp;
    ScheduledAudioFileRegionCompletionProc __nullable	mCompletionProc;
    void * __nullable mCompletionProcUserData;
    struct OpaqueAudioFileID * mAudioFile;
    UInt32 mLoopCount;
    SInt64 mStartFrame;
    UInt32 mFramesToPlay;
};
enum : AudioUnitPropertyID {
    kAudioUnitProperty_DeferredRendererPullSize = 3320,
    kAudioUnitProperty_DeferredRendererExtraLatency	= 3321,
    kAudioUnitProperty_DeferredRendererWaitFrames = 3322
};
enum : AudioUnitPropertyID {
    kAUSamplerProperty_LoadPresetFromBank = 4100,
    kAUSamplerProperty_BankAndPreset = kAUSamplerProperty_LoadPresetFromBank
};

/* AudioUnitParameters.h */
enum : AudioUnitParameterID {
    kAUGroupParameterID_Volume = 7,
    kAUGroupParameterID_Sustain = 64,
    kAUGroupParameterID_Sostenuto = 66,
    kAUGroupParameterID_AllNotesOff = 123,
    kAUGroupParameterID_ModWheel = 1,
    kAUGroupParameterID_PitchBend = 0xE0,
    kAUGroupParameterID_AllSoundOff = 120,
    kAUGroupParameterID_ResetAllControllers = 121,
    kAUGroupParameterID_Pan = 10,
    kAUGroupParameterID_Foot = 4,
    kAUGroupParameterID_ChannelPressure = 0xD0,
    kAUGroupParameterID_KeyPressure = 0xA0,
    kAUGroupParameterID_Expression = 11,
    kAUGroupParameterID_DataEntry = 6,
    kAUGroupParameterID_Volume_LSB = kAUGroupParameterID_Volume + 32,
    kAUGroupParameterID_ModWheel_LSB = kAUGroupParameterID_ModWheel + 32,
    kAUGroupParameterID_Pan_LSB = kAUGroupParameterID_Pan + 32,
    kAUGroupParameterID_Foot_LSB = kAUGroupParameterID_Foot + 32,
    kAUGroupParameterID_Expression_LSB = kAUGroupParameterID_Expression + 32,
    kAUGroupParameterID_DataEntry_LSB = kAUGroupParameterID_DataEntry + 32,
    kAUGroupParameterID_KeyPressure_FirstKey	= 256,
    kAUGroupParameterID_KeyPressure_LastKey = 383
};
enum : AudioUnitParameterID {
    kSpatialMixerParam_Azimuth = 0,
    kSpatialMixerParam_Elevation	= 1,
    kSpatialMixerParam_Distance = 2,
    kSpatialMixerParam_Gain = 3,
    kSpatialMixerParam_PlaybackRate	= 4,
    kSpatialMixerParam_Enable = 5,
    kSpatialMixerParam_MinGain = 6,
    kSpatialMixerParam_MaxGain = 7,
    kSpatialMixerParam_ReverbBlend = 8,
    kSpatialMixerParam_GlobalReverbGain	= 9,
    kSpatialMixerParam_OcclusionAttenuation	= 10,
    kSpatialMixerParam_ObstructionAttenuation = 11,
    kSpatialMixerParam_HeadYaw = 19,
    kSpatialMixerParam_HeadPitch = 20,
    kSpatialMixerParam_HeadRoll = 21
};
enum : AudioUnitParameterID {
    kReverbParam_FilterFrequency = 14,
    kReverbParam_FilterBandwidth = 15,
    kReverbParam_FilterGain = 16,
    kReverbParam_FilterType = 17,
    kReverbParam_FilterEnable = 18
};
enum : AudioUnitParameterID {
    k3DMixerParam_Azimuth = 0,
    k3DMixerParam_Elevation = 1,
    k3DMixerParam_Distance = 2,
    k3DMixerParam_Gain = 3,
    k3DMixerParam_PlaybackRate	= 4,
    k3DMixerParam_BusEnable = 20,
    k3DMixerParam_MinGainInDecibels = 21,
    k3DMixerParam_MaxGainInDecibels = 22,
    k3DMixerParam_DryWetReverbBlend = 23,
    k3DMixerParam_GlobalReverbGainInDecibels = 24,
    k3DMixerParam_OcclusionAttenuationInDecibels = 25,
    k3DMixerParam_ObstructionAttenuationInDecibels = 26,
    k3DMixerParam_Enable = 5,
    k3DMixerParam_MinGain = 6,
    k3DMixerParam_MaxGain = 7,
    k3DMixerParam_ReverbBlend = 8,
    k3DMixerParam_GlobalReverbGain = 9,
    k3DMixerParam_OcclusionAttenuation = 10,
    k3DMixerParam_ObstructionAttenuation = 11,
    k3DMixerParam_PreAveragePower = 1000,
    k3DMixerParam_PrePeakHoldLevel = 2000,
    k3DMixerParam_PostAveragePower = 3000,
    k3DMixerParam_PostPeakHoldLevel = 4000
};
enum : AudioUnitParameterID {
    kMatrixMixerParam_Volume = 0,
    kMatrixMixerParam_Enable = 1,
    kMatrixMixerParam_PreAveragePower	= 1000,
    kMatrixMixerParam_PrePeakHoldLevel	= 2000,
    kMatrixMixerParam_PostAveragePower	= 3000,
    kMatrixMixerParam_PostPeakHoldLevel	= 4000,
    kMatrixMixerParam_PreAveragePowerLinear = 5000,
    kMatrixMixerParam_PrePeakHoldLevelLinear = 6000,
    kMatrixMixerParam_PostAveragePowerLinear = 7000,
    kMatrixMixerParam_PostPeakHoldLevelLinear = 8000
};
enum : AudioUnitParameterID {
    kHALOutputParam_Volume = 14
};
enum : AudioUnitParameterID {
    kTimePitchParam_Rate = 0,
    kTimePitchParam_Pitch = 1,
    kTimePitchParam_EffectBlend = 2
};
enum : AudioUnitParameterID {
    kNewTimePitchParam_Smoothness = 4,
    kNewTimePitchParam_EnableSpectralCoherence = 6,
    kNewTimePitchParam_EnableTransientPreservation = 7
};
enum : AudioUnitParameterID {
    kDynamicsProcessorParam_Threshold = 0,
    kDynamicsProcessorParam_HeadRoom = 1,
    kDynamicsProcessorParam_ExpansionRatio = 2,
    kDynamicsProcessorParam_ExpansionThreshold	= 3,
    kDynamicsProcessorParam_AttackTime = 4,
    kDynamicsProcessorParam_ReleaseTime = 5,
    kDynamicsProcessorParam_OverallGain = 6,
    kDynamicsProcessorParam_CompressionAmount = 1000,
    kDynamicsProcessorParam_InputAmplitude = 2000,
    kDynamicsProcessorParam_OutputAmplitude = 3000
};
enum : AudioUnitParameterID {
    kDistortionParam_Delay = 0,
    kDistortionParam_Decay = 1,
    kDistortionParam_DelayMix = 2,
    kDistortionParam_Decimation = 3,
    kDistortionParam_Rounding = 4,
    kDistortionParam_DecimationMix = 5,
    kDistortionParam_LinearTerm = 6,
    kDistortionParam_SquaredTerm = 7,
    kDistortionParam_CubicTerm = 8,
    kDistortionParam_PolynomialMix = 9,
    kDistortionParam_RingModFreq1 = 10,
    kDistortionParam_RingModFreq2 = 11,
    kDistortionParam_RingModBalance = 12,
    kDistortionParam_RingModMix = 13};
enum : AudioUnitParameterID {
    kSampleDelayParam_DelayFrames = 0
};
enum : long {
    kAUNBandEQFilterType_Parametric = 0,
    kAUNBandEQFilterType_2ndOrderButterworthLowPass = 1,
    kAUNBandEQFilterType_2ndOrderButterworthHighPass = 2,
    kAUNBandEQFilterType_ResonantLowPass = 3,
    kAUNBandEQFilterType_ResonantHighPass = 4,
    kAUNBandEQFilterType_BandPass = 5,
    kAUNBandEQFilterType_BandStop = 6,
    kAUNBandEQFilterType_LowShelf = 7,
    kAUNBandEQFilterType_HighShelf = 8,
    kAUNBandEQFilterType_ResonantLowShelf = 9,
    kAUNBandEQFilterType_ResonantHighShelf = 10,
    kNumAUNBandEQFilterTypes = 11
};
enum : AudioUnitParameterID {
    kRoundTripAACParam_Format = 0,
    kRoundTripAACParam_EncodingStrategy = 1,
    kRoundTripAACParam_RateOrQuality = 2};
enum : AudioUnitParameterID {
    kAUSoundIsolationParam_WetDryMixPercent = 0,
    kAUSoundIsolationParam_SoundToIsolate = 1};
enum : long {
    kAUSoundIsolationSoundType_HighQualityVoice = 0,
    kAUSoundIsolationSoundType_Voice = 1
};
enum : AudioUnitParameterID {
    kAUAudioMixParameter_Style = 0,
    kAUAudioMixParameter_RemixAmount = 1};
typedef CF_ENUM( UInt32, AUAudioMixRenderingStyle ) {
    kAudioMixRenderingStyle_Cinematic = 0,
    kAudioMixRenderingStyle_Studio = 1,
    kAudioMixRenderingStyle_InFrame = 2,
    kAudioMixRenderingStyle_CinematicBackgroundStem = 3,
    kAudioMixRenderingStyle_CinematicForegroundStem = 4,
    kAudioMixRenderingStyle_StudioForegroundStem = 5,
    kAudioMixRenderingStyle_InFrameForegroundStem = 6,
    kAudioMixRenderingStyle_Standard = 7,
    kAudioMixRenderingStyle_StudioBackgroundStem = 8,
    kAudioMixRenderingStyle_InFrameBackgroundStem = 9,
};
enum : AudioUnitParameterID {
    kRandomParam_BoundA = 0,
    kRandomParam_BoundB = 1,
    kRandomParam_Curve = 2
};

/* AudioOutputUnit.h */
enum {
    kAudioOutputUnitRange = 0x0200,
    kAudioOutputUnitStartSelect = 0x0201,
    kAudioOutputUnitStopSelect = 0x0202
};
typedef OSStatus	(*AudioOutputUnitStartProc) (void *self);
typedef OSStatus	(*AudioOutputUnitStopProc) (void *self);

/* AUGraph.h */
enum : UInt32 {
    kAUNodeInteraction_Connection = 1,
    kAUNodeInteraction_InputCallback	= 2
};
struct AudioUnitNodeConnection
    {
    AUNode sourceNode;
    UInt32 sourceOutputNumber;
    AUNode destNode;
    UInt32 destInputNumber;
};
typedef struct AudioUnitNodeConnection AudioUnitNodeConnection;
typedef struct AudioUnitNodeConnection AUNodeConnection;
struct AUNodeInteraction
    {
    UInt32 nodeInteractionType;
    union
    {
    AUNodeConnection connection;
    AUNodeRenderCallback	inputCallback;
} nodeInteraction;
};
typedef struct AUNodeInteraction AUNodeInteraction;

/* AudioCodec.h */
typedef AudioComponentInstance	AudioCodec;
typedef UInt32 AudioCodecPropertyID;
struct AudioCodecMagicCookieInfo
    {
    UInt32 mMagicCookieSize;
    const void* __nullable	mMagicCookie;
};
typedef struct AudioCodecMagicCookieInfo	AudioCodecMagicCookieInfo;
enum : AudioCodecPropertyID {
    kAudioCodecPropertySupportedInputFormats = 'ifm#',
    kAudioCodecPropertySupportedOutputFormats = 'ofm#',
    kAudioCodecPropertyAvailableInputSampleRates = 'aisr',
    kAudioCodecPropertyAvailableOutputSampleRates = 'aosr',
    kAudioCodecPropertyAvailableBitRateRange = 'abrt',
    kAudioCodecPropertyMinimumNumberInputPackets = 'mnip',
    kAudioCodecPropertyMinimumNumberOutputPackets = 'mnop',
    kAudioCodecPropertyAvailableNumberChannels = 'cmnc',
    kAudioCodecPropertyDoesSampleRateConversion = 'lmrc',
    kAudioCodecPropertyAvailableInputChannelLayoutTags = 'aicl',
    kAudioCodecPropertyAvailableOutputChannelLayoutTags = 'aocl',
    kAudioCodecPropertyInputFormatsForOutputFormat = 'if4o',
    kAudioCodecPropertyOutputFormatsForInputFormat = 'of4i',
    kAudioCodecPropertyFormatInfo = 'acfi'
};
enum : AudioCodecPropertyID {
    kAudioCodecPropertyInputBufferSize = 'tbuf',
    kAudioCodecPropertyPacketFrameSize = 'pakf',
    kAudioCodecPropertyHasVariablePacketByteSizes = 'vpk?',
    kAudioCodecPropertyEmploysDependentPackets = 'dpk?',
    kAudioCodecPropertyMaximumPacketByteSize = 'pakb',
    kAudioCodecPropertyPacketSizeLimitForVBR = 'pakl',
    kAudioCodecPropertyCurrentInputFormat = 'ifmt',
    kAudioCodecPropertyCurrentOutputFormat = 'ofmt',
    kAudioCodecPropertyMagicCookie = 'kuki',
    kAudioCodecPropertyUsedInputBufferSize = 'ubuf',
    kAudioCodecPropertyIsInitialized = 'init',
    kAudioCodecPropertyCurrentTargetBitRate = 'brat',
    kAudioCodecPropertyCurrentInputSampleRate = 'cisr',
    kAudioCodecPropertyCurrentOutputSampleRate = 'cosr',
    kAudioCodecPropertyQualitySetting = 'srcq',
    kAudioCodecPropertyApplicableBitRateRange = 'brta',
    kAudioCodecPropertyRecommendedBitRateRange = 'brtr',
    kAudioCodecPropertyApplicableInputSampleRates = 'isra',
    kAudioCodecPropertyApplicableOutputSampleRates = 'osra',
    kAudioCodecPropertyPaddedZeros = 'pad0',
    kAudioCodecPropertyPrimeMethod = 'prmm',
    kAudioCodecPropertyPrimeInfo = 'prim',
    kAudioCodecPropertyCurrentInputChannelLayout = 'icl ',
    kAudioCodecPropertyCurrentOutputChannelLayout = 'ocl ',
    kAudioCodecPropertySettings = 'acs ',
    kAudioCodecPropertyFormatList = 'acfl',
    kAudioCodecPropertyBitRateControlMode = 'acbf',
    kAudioCodecPropertySoundQualityForVBR = 'vbrq',
    kAudioCodecPropertyBitRateForVBR = 'vbrb',
    kAudioCodecPropertyDelayMode = 'dmod',
    kAudioCodecPropertyAdjustLocalQuality = '^qal',
    kAudioCodecPropertyDynamicRangeControlMode = 'mdrc',
    kAudioCodecPropertyAdjustCompressionProfile = '^pro',
    kAudioCodecPropertyProgramTargetLevelConstant = 'ptlc',
    kAudioCodecPropertyAdjustTargetLevelConstant = '^tlc',
    kAudioCodecPropertyProgramTargetLevel = 'pptl',
    kAudioCodecPropertyAdjustTargetLevel = '^ptl',
    kAudioCodecPropertyDynamicRangeControlConfiguration = 'cdrc',
    kAudioCodecPropertyContentSource = 'csrc',
    kAudioCodecPropertyASPFrequency = 'aspf'};
enum : UInt32 {
    kAudioCodecQuality_Max = 0x7F,
    kAudioCodecQuality_High = 0x60,
    kAudioCodecQuality_Medium	= 0x40,
    kAudioCodecQuality_Low = 0x20,
    kAudioCodecQuality_Min = 0
};
enum : UInt32 {
    kAudioCodecPrimeMethod_Pre = 0,
    kAudioCodecPrimeMethod_Normal = 1,
    kAudioCodecPrimeMethod_None = 2
};
enum : UInt32 {
    kAudioCodecBitRateControlMode_Constant = 0,
    kAudioCodecBitRateControlMode_LongTermAverage = 1,
    kAudioCodecBitRateControlMode_VariableConstrained = 2,
    kAudioCodecBitRateControlMode_Variable = 3};
enum : UInt32 {
    kAudioCodecDelayMode_Compatibility = 0,
    kAudioCodecDelayMode_Minimum = 1,
    kAudioCodecDelayMode_Optimal = 2
};
enum : UInt32 {
    kProgramTargetLevel_None = 0,
    kProgramTargetLevel_Minus31dB	= 1,
    kProgramTargetLevel_Minus23dB	= 2,
    kProgramTargetLevel_Minus20dB	= 3
};
enum : UInt32 {
    kDynamicRangeControlMode_None	= 0,
    kDynamicRangeControlMode_Light	= 1,
    kDynamicRangeControlMode_Heavy	= 2
};
enum : UInt32 {
    kDynamicRangeCompressionProfile_None = 0,
    kDynamicRangeCompressionProfile_LateNight = 1,
    kDynamicRangeCompressionProfile_NoisyEnvironment = 2,
    kDynamicRangeCompressionProfile_LimitedPlaybackRange = 3,
    kDynamicRangeCompressionProfile_GeneralCompression = 6
};
enum : UInt32 {
    kAudioCodecDynamicRangeControlConfiguration_None = 0,
    kAudioCodecDynamicRangeControlConfiguration_Music = 1,
    kAudioCodecDynamicRangeControlConfiguration_Speech = 2,
    kAudioCodecDynamicRangeControlConfiguration_Movie = 3,
    kAudioCodecDynamicRangeControlConfiguration_Capture = 4
};
enum : SInt32 {
    kAudioCodecContentSource_Unspecified = -1,
    kAudioCodecContentSource_Reserved = 0,
    kAudioCodecContentSource_AppleCapture_Traditional = 1,
    kAudioCodecContentSource_AppleCapture_Spatial = 2,
    kAudioCodecContentSource_AppleCapture_Spatial_Enhanced = 3,
    kAudioCodecContentSource_AppleMusic_Traditional = 4,
    kAudioCodecContentSource_AppleMusic_Spatial = 5,
    kAudioCodecContentSource_AppleAV_Traditional_Offline = 6,
    kAudioCodecContentSource_AppleAV_Spatial_Offline = 7,
    kAudioCodecContentSource_AppleAV_Traditional_Live = 8,
    kAudioCodecContentSource_AppleAV_Spatial_Live = 9,
    kAudioCodecContentSource_ApplePassthrough = 10,
    kAudioCodecContentSource_Capture_Traditional = 33,
    kAudioCodecContentSource_Capture_Spatial = 34,
    kAudioCodecContentSource_Capture_Spatial_Enhanced = 35,
    kAudioCodecContentSource_Music_Traditional = 36,
    kAudioCodecContentSource_Music_Spatial = 37,
    kAudioCodecContentSource_AV_Traditional_Offline = 38,
    kAudioCodecContentSource_AV_Spatial_Offline = 39,
    kAudioCodecContentSource_AV_Traditional_Live = 40,
    kAudioCodecContentSource_AV_Spatial_Live = 41,
    kAudioCodecContentSource_Passthrough = 42
};
typedef struct AudioCodecPrimeInfo
    {
    UInt32 leadingFrames;
    UInt32 trailingFrames;
} AudioCodecPrimeInfo;
typedef CF_OPTIONS(UInt32, AudioSettingsFlags) {
    kAudioSettingsFlags_ExpertParameter = (1L << 0),
    kAudioSettingsFlags_InvisibleParameter = (1L << 1),
    kAudioSettingsFlags_MetaParameter = (1L << 2),
    kAudioSettingsFlags_UserInterfaceParameter	= (1L << 3)
};
enum : UInt32 {
    kAudioCodecProduceOutputPacketFailure = 1,
    kAudioCodecProduceOutputPacketSuccess = 2,
    kAudioCodecProduceOutputPacketSuccessHasMore = 3,
    kAudioCodecProduceOutputPacketNeedsMoreInputData = 4,
    kAudioCodecProduceOutputPacketAtEOF = 5,
    kAudioCodecProduceOutputPacketSuccessConcealed = 6
};
enum : UInt32 {
    kAudioCodecGetPropertyInfoSelect = 0x0001,
    kAudioCodecGetPropertySelect = 0x0002,
    kAudioCodecSetPropertySelect = 0x0003,
    kAudioCodecInitializeSelect = 0x0004,
    kAudioCodecUninitializeSelect = 0x0005,
    kAudioCodecAppendInputDataSelect = 0x0006,
    kAudioCodecProduceOutputDataSelect = 0x0007,
    kAudioCodecResetSelect = 0x0008,
    kAudioCodecAppendInputBufferListSelect = 0x0009,
    kAudioCodecProduceOutputBufferListSelect = 0x000A
};
enum : OSStatus {
    kAudioCodecNoError = 0,
    kAudioCodecUnspecifiedError = 'what',
    kAudioCodecUnknownPropertyError = 'who?',
    kAudioCodecBadPropertySizeError = '!siz',
    kAudioCodecIllegalOperationError = 'nope',
    kAudioCodecUnsupportedFormatError = '!dat',
    kAudioCodecStateError = '!stt',
    kAudioCodecNotEnoughBufferSpaceError = '!buf',
    kAudioCodecBadDataError = 'bada'
};
typedef OSStatus
    (*AudioCodecGetPropertyInfoProc)(void *self, AudioCodecPropertyID inPropertyID, UInt32 * __nullable outSize, Boolean * __nullable outWritable);
typedef OSStatus
    (*AudioCodecGetPropertyProc)(void *self, AudioCodecPropertyID inPropertyID, UInt32 *ioPropertyDataSize,
    void *outPropertyData);
typedef OSStatus
    (*AudioCodecSetPropertyProc)(void *self, AudioCodecPropertyID inPropertyID, UInt32 inPropertyDataSize,
    const void *inPropertyData);
typedef OSStatus
    (*AudioCodecInitializeProc)(void *self, const AudioStreamBasicDescription * __nullable inInputFormat,
    const AudioStreamBasicDescription * __nullable inOutputFormat, const void * __nullable inMagicCookie,
    UInt32 inMagicCookieByteSize);
typedef OSStatus
    (*AudioCodecUninitializeProc)(void *self);
typedef OSStatus
    (*AudioCodecAppendInputDataProc)(void *self, const void *inInputData, UInt32 *ioInputDataByteSize, UInt32 *ioNumberPackets,
    const AudioStreamPacketDescription * __nullable inPacketDescription);
typedef OSStatus
    (*AudioCodecProduceOutputPacketsProc)(void *self, void *outOutputData, UInt32 *ioOutputDataByteSize, UInt32 *ioNumberPackets,
    AudioStreamPacketDescription * __nullable outPacketDescription, UInt32 *outStatus);
typedef OSStatus
    (*AudioCodecResetProc)(void *self);
typedef OSStatus
    (*AudioCodecAppendInputBufferListProc)(void *self, const AudioBufferList *ioBufferList, UInt32 *inNumberPackets,
    const AudioStreamPacketDescription * __nullable inPacketDescription, UInt32 *outBytesConsumed);
typedef OSStatus
    (*AudioCodecProduceOutputBufferListProc)(void *self, AudioBufferList *ioBufferList, UInt32 *ioNumberPackets,
    AudioStreamPacketDescription *__nullable outPacketDescription, UInt32 *outStatus);
enum : AudioCodecPropertyID {
    kAudioCodecPropertyMinimumDelayMode = 'mdel'
};
enum : AudioCodecPropertyID {
    kAudioCodecPropertyNameCFString = 'lnam',
    kAudioCodecPropertyManufacturerCFString = 'lmak',
    kAudioCodecPropertyFormatCFString = 'lfor'
};
enum : AudioCodecPropertyID {
    kAudioCodecPropertyRequiresPacketDescription = 'pakd',
    kAudioCodecPropertyAvailableBitRates = 'brt#',
    kAudioCodecExtendFrequencies = 'acef',
    kAudioCodecUseRecommendedSampleRate = 'ursr',
    kAudioCodecOutputPrecedence = 'oppr',
    kAudioCodecBitRateFormat = kAudioCodecPropertyBitRateControlMode,
    kAudioCodecDoesSampleRateConversion = kAudioCodecPropertyDoesSampleRateConversion,
    kAudioCodecInputFormatsForOutputFormat = kAudioCodecPropertyInputFormatsForOutputFormat,
    kAudioCodecOutputFormatsForInputFormat = kAudioCodecPropertyOutputFormatsForInputFormat,
    kAudioCodecPropertyInputChannelLayout = kAudioCodecPropertyCurrentInputChannelLayout,
    kAudioCodecPropertyOutputChannelLayout = kAudioCodecPropertyCurrentOutputChannelLayout,
    kAudioCodecPropertyAvailableInputChannelLayouts = kAudioCodecPropertyAvailableInputChannelLayoutTags,
    kAudioCodecPropertyAvailableOutputChannelLayouts = kAudioCodecPropertyAvailableOutputChannelLayoutTags,
    kAudioCodecPropertyZeroFramesPadded = kAudioCodecPropertyPaddedZeros
};
enum : UInt32 {
    kAudioCodecBitRateFormat_CBR =	kAudioCodecBitRateControlMode_Constant,
    kAudioCodecBitRateFormat_ABR =	kAudioCodecBitRateControlMode_LongTermAverage,
    kAudioCodecBitRateFormat_VBR =	kAudioCodecBitRateControlMode_VariableConstrained
};
enum : UInt32 {
    kAudioCodecOutputPrecedenceNone = 0,
    kAudioCodecOutputPrecedenceBitRate = 1,
    kAudioCodecOutputPrecedenceSampleRate = 2
};
typedef struct AudioCodecMagicCookieInfo MagicCookieInfo ;
enum : UInt32 {
    kHintBasic = 0,
    kHintAdvanced	= 1,
    kHintHidden = 2
};

/* AudioConverter.h */
typedef UInt32 AudioConverterPropertyID;
enum : AudioConverterPropertyID {
    kAudioConverterPropertyCalculateInputBufferSize = 'cibs',
    kAudioConverterPropertyCalculateOutputBufferSize = 'cobs',
    kAudioConverterPropertyInputCodecParameters = 'icdp',
    kAudioConverterPropertyOutputCodecParameters = 'ocdp',
    kAudioConverterSampleRateConverterComplexity = 'srca',
    kAudioConverterSampleRateConverterInitialPhase = 'srcp',
    kAudioConverterPrimeMethod = 'prmm',
    kAudioConverterChannelMap = 'chmp',
    kAudioConverterEncodeAdjustableSampleRate = 'ajsr',
    kAudioConverterInputChannelLayout = 'icl ',
    kAudioConverterOutputChannelLayout = 'ocl ',
    kAudioConverterApplicableEncodeBitRates = 'aebr',
    kAudioConverterAvailableEncodeBitRates = 'vebr',
    kAudioConverterApplicableEncodeSampleRates = 'aesr',
    kAudioConverterAvailableEncodeSampleRates = 'vesr',
    kAudioConverterAvailableEncodeChannelLayoutTags = 'aecl',
    kAudioConverterPropertySettings = 'acps',
    kAudioConverterPropertyBitDepthHint = 'acbd',
    kAudioConverterPropertyFormatList = 'flst',
    kAudioConverterPropertyPerformDownmix = 'dmix',
    kAudioConverterPropertyChannelMixMap = 'mmap'
};
enum : UInt32 {
    kAudioConverterQuality_Max = 0x7F,
    kAudioConverterQuality_High = 0x60,
    kAudioConverterQuality_Medium = 0x40,
    kAudioConverterQuality_Low = 0x20,
    kAudioConverterQuality_Min = 0
};
enum : UInt32 {
    kAudioConverterSampleRateConverterComplexity_Linear = 'line',
    kAudioConverterSampleRateConverterComplexity_Normal = 'norm',
    kAudioConverterSampleRateConverterComplexity_Mastering = 'bats',
    kAudioConverterSampleRateConverterComplexity_MinimumPhase = 'minp'
};
enum : UInt32 {
    kConverterPrimeMethod_Pre = 0,
    kConverterPrimeMethod_Normal = 1,
    kConverterPrimeMethod_None = 2
};
typedef CF_OPTIONS(UInt32, AudioConverterOptions) {
    kAudioConverterOption_Unbuffered = (1 << 16)
};
enum : OSStatus {
    kAudioConverterErr_UnspecifiedError = 'what',
    kAudioConverterErr_BadPropertySizeError = '!siz',
    kAudioConverterErr_RequiresPacketDescriptionsError = '!pkd',
    kAudioConverterErr_InputSampleRateOutOfRange = '!isr',
    kAudioConverterErr_OutputSampleRateOutOfRange = '!osr'
};
enum : OSStatus {
    kAudioConverterErr_HardwareInUse = 'hwiu',
    kAudioConverterErr_NoHardwarePermission = 'perm'
};
typedef OSStatus
    (*AudioConverterComplexInputDataProcRealtimeSafe)(
    AudioConverterRef inAudioConverter,
    UInt32 * ioNumberDataPackets,
    AudioBufferList * ioData,
    AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
    void * __nullable inUserData) ;
enum : AudioConverterPropertyID {
    kAudioConverterPropertyMaximumInputBufferSize = 'xibs',
    kAudioConverterSampleRateConverterAlgorithm = 'srci'};
enum : AudioConverterPropertyID {
    kAudioConverterPropertyCanResumeFromInterruption = 'crfi'
};
typedef OSStatus
    (*AudioConverterInputDataProc)( AudioConverterRef inAudioConverter,
    UInt32 * ioDataSize,
    void * __nonnull * __nonnull outData,
    void * __nullable inUserData);

/* AudioFile.h */
typedef UInt32 AudioFileTypeID;
enum : AudioFileTypeID {
    kAudioFileRF64Type = 'RF64',
    kAudioFileBW64Type = 'BW64',
    kAudioFileWave64Type = 'W64f',
    kAudioFileSoundDesigner2Type	= 'Sd2f',
    kAudioFileNextType = 'NeXT',
    kAudioFileMP2Type = 'MPG2',
    kAudioFileMP1Type = 'MPG1',
    kAudioFileAC3Type = 'ac-3',
    kAudioFileM4BType = 'm4bf',
    kAudioFile3GPType = '3gpp',
    kAudioFile3GP2Type = '3gp2',
    kAudioFileAMRType = 'amrf',
    kAudioFileLATMInLOASType = 'loas'
};
enum : OSStatus {
    kAudioFileInvalidChunkError = 'chk?',
    kAudioFileDoesNotAllow64BitDataSizeError = 'off?',
    kAudioFileInvalidPacketDependencyError = 'dep?',
    kAudioFilePositionError = -40,
    kAudioFileFileNotFoundError = -43
};
typedef UInt32 AudioFilePropertyID;
enum : UInt32 {
    kAudioFileLoopDirection_NoLooping = 0,
    kAudioFileLoopDirection_Forward = 1,
    kAudioFileLoopDirection_ForwardAndBackward = 2,
    kAudioFileLoopDirection_Backward = 3
};
struct AudioFile_SMPTE_Time
    {
    SInt8 mHours;
    UInt8 mMinutes;
    UInt8 mSeconds;
    UInt8 mFrames;
    UInt32 mSubFrameSampleOffset;
};
typedef struct AudioFile_SMPTE_Time AudioFile_SMPTE_Time;
enum : UInt32 {
    kAudioFileMarkerType_Generic = 0};
struct AudioFileMarker
    {
    Float64 mFramePosition;
    CFStringRef	__nullable	mName;
    SInt32 mMarkerID;
    AudioFile_SMPTE_Time	mSMPTETime;
    UInt32 mType;
    UInt16 mReserved;
    UInt16 mChannel;
};
typedef struct AudioFileMarker AudioFileMarker;
struct AudioFileMarkerList
    {
    UInt32 mSMPTE_TimeType;
    UInt32 mNumberMarkers;
    AudioFileMarker mMarkers[1];
};
typedef struct AudioFileMarkerList AudioFileMarkerList;
typedef CF_OPTIONS(UInt32, AudioFileRegionFlags) {
    kAudioFileRegionFlag_LoopEnable = 1,
    kAudioFileRegionFlag_PlayForward = 2,
    kAudioFileRegionFlag_PlayBackward = 4
};
struct AudioFileRegion
    {
    UInt32 mRegionID;
    CFStringRef mName;
    AudioFileRegionFlags	mFlags;
    UInt32 mNumberMarkers;
    AudioFileMarker mMarkers[1];
};
typedef struct AudioFileRegion AudioFileRegion;
struct AudioFileRegionList
    {
    UInt32 mSMPTE_TimeType;
    UInt32 mNumberRegions;
    AudioFileRegion mRegions[1];
};
typedef struct AudioFileRegionList AudioFileRegionList;
struct AudioPacketRangeByteCountTranslation
    {
    SInt64 mPacket;
    SInt64 mPacketCount;
    SInt64 mByteCountUpperBound;
};
typedef struct AudioPacketRangeByteCountTranslation AudioPacketRangeByteCountTranslation;
typedef OSStatus (*AudioFile_ReadProc)(
    void * inClientData,
    SInt64 inPosition,
    UInt32 requestCount,
    void * buffer,
    UInt32 *	actualCount);
typedef OSStatus (*AudioFile_WriteProc)(
    void * inClientData,
    SInt64 inPosition,
    UInt32 requestCount,
    const void *buffer,
    UInt32 * actualCount);
typedef SInt64 (*AudioFile_GetSizeProc)(
    void * inClientData);
typedef OSStatus (*AudioFile_SetSizeProc)(
    void * inClientData,
    SInt64 inSize);
enum : AudioFilePropertyID {
    kAudioFilePropertyDataOffset =	'doff',
    kAudioFilePropertyChannelLayout =	'cmap',
    kAudioFilePropertyDeferSizeUpdates =	'dszu',
    kAudioFilePropertyDataFormatName =	'fnme',
    kAudioFilePropertyMarkerList =	'mkls',
    kAudioFilePropertyRegionList =	'rgls',
    kAudioFilePropertyPacketToFrame =	'pkfr',
    kAudioFilePropertyFrameToPacket =	'frpk',
    kAudioFilePropertyRestrictsRandomAccess	=	'rrap',
    kAudioFilePropertyPacketToRollDistance	=	'pkrl',
    kAudioFilePropertyPreviousIndependentPacket	= 'pind',
    kAudioFilePropertyNextIndependentPacket	=	'nind',
    kAudioFilePropertyPacketToDependencyInfo =	'pkdp',
    kAudioFilePropertyPacketToByte =	'pkby',
    kAudioFilePropertyByteToPacket =	'bypk',
    kAudioFilePropertyChunkIDs =	'chid',
    kAudioFilePropertyInfoDictionary =	'info',
    kAudioFilePropertyPacketTableInfo =	'pnfo',
    kAudioFilePropertyFormatList =	'flst',
    kAudioFilePropertyPacketRangeByteCountUpperBound = 'prub',
    kAudioFilePropertyReserveDuration =	'rsrv',
    kAudioFilePropertyBitRate =	'brat',
    kAudioFilePropertyID3Tag =	'id3t',
    kAudioFilePropertyID3TagOffset =	'id3o',
    kAudioFilePropertySourceBitDepth =	'sbtd',
    kAudioFilePropertyAlbumArtwork =	'aart',
    kAudioFilePropertyAudioTrackCount = 'atct',
    kAudioFilePropertyUseAudioTrack =	'uatk'
};
enum : AudioFilePropertyID {
    kAudioFileGlobalInfo_ReadableTypes = 'afrf',
    kAudioFileGlobalInfo_WritableTypes = 'afwf',
    kAudioFileGlobalInfo_FileTypeName = 'ftnm',
    kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat	= 'sdid',
    kAudioFileGlobalInfo_AvailableFormatIDs = 'fmid',
    kAudioFileGlobalInfo_AllExtensions = 'alxt',
    kAudioFileGlobalInfo_AllHFSTypeCodes = 'ahfs',
    kAudioFileGlobalInfo_AllUTIs = 'auti',
    kAudioFileGlobalInfo_AllMIMETypes = 'amim',
    kAudioFileGlobalInfo_ExtensionsForType = 'fext',
    kAudioFileGlobalInfo_HFSTypeCodesForType = 'fhfs',
    kAudioFileGlobalInfo_UTIsForType = 'futi',
    kAudioFileGlobalInfo_MIMETypesForType = 'fmim',
    kAudioFileGlobalInfo_TypesForMIMEType = 'tmim',
    kAudioFileGlobalInfo_TypesForUTI = 'tuti',
    kAudioFileGlobalInfo_TypesForHFSTypeCode = 'thfs',
    kAudioFileGlobalInfo_TypesForExtension = 'text'
};
struct AudioFileTypeAndFormatID
    {
    AudioFileTypeID mFileType;
    UInt32 mFormatID;
};
typedef struct AudioFileTypeAndFormatID AudioFileTypeAndFormatID;

/* AudioFormat.h */
typedef UInt32	AudioFormatPropertyID;
typedef CF_ENUM(UInt32, AudioPanningMode) {
    kPanningMode_SoundField = 3,
    kPanningMode_VectorBasedPanning = 4
};
struct AudioPanningInfo {
    AudioPanningMode mPanningMode;
    UInt32 mCoordinateFlags;
    Float32 mCoordinates[3];
    Float32 mGainScale;
    const AudioChannelLayout *	mOutputChannelMap;
};
typedef struct AudioPanningInfo AudioPanningInfo;
typedef CF_ENUM(UInt32, AudioBalanceFadeType) {
    kAudioBalanceFadeType_MaxUnityGain = 0,
    kAudioBalanceFadeType_EqualPower = 1
};
struct AudioBalanceFade
    {
    Float32 mLeftRightBalance;
    Float32 mBackFrontFade;
    AudioBalanceFadeType mType;
    const AudioChannelLayout*	mChannelLayout;
};
typedef struct AudioBalanceFade AudioBalanceFade;
struct AudioFormatInfo
    {
    AudioStreamBasicDescription mASBD;
    const void* mMagicCookie;
    UInt32 mMagicCookieSize;
};
typedef struct AudioFormatInfo AudioFormatInfo;
struct ExtendedAudioFormatInfo
    {
    AudioStreamBasicDescription mASBD;
    const void* __nullable mMagicCookie;
    UInt32 mMagicCookieSize;
    AudioClassDescription mClassDescription;
};
typedef struct ExtendedAudioFormatInfo ExtendedAudioFormatInfo;
enum : AudioFormatPropertyID {
    kAudioFormatProperty_FormatInfo = 'fmti',
    kAudioFormatProperty_FormatName = 'fnam',
    kAudioFormatProperty_EncodeFormatIDs = 'acof',
    kAudioFormatProperty_DecodeFormatIDs = 'acif',
    kAudioFormatProperty_FormatList = 'flst',
    kAudioFormatProperty_ASBDFromESDS = 'essd',
    kAudioFormatProperty_ChannelLayoutFromESDS = 'escl',
    kAudioFormatProperty_OutputFormatList = 'ofls',
    kAudioFormatProperty_FirstPlayableFormatFromList	= 'fpfl',
    kAudioFormatProperty_FormatIsVBR = 'fvbr',
    kAudioFormatProperty_FormatIsExternallyFramed = 'fexf',
    kAudioFormatProperty_FormatEmploysDependentPackets = 'fdep',
    kAudioFormatProperty_FormatIsEncrypted = 'cryp',
    kAudioFormatProperty_Encoders = 'aven',
    kAudioFormatProperty_Decoders = 'avde',
    kAudioFormatProperty_AvailableEncodeBitRates = 'aebr',
    kAudioFormatProperty_AvailableEncodeSampleRates = 'aesr',
    kAudioFormatProperty_AvailableEncodeChannelLayoutTags = 'aecl',
    kAudioFormatProperty_AvailableEncodeNumberChannels = 'avnc',
    kAudioFormatProperty_AvailableDecodeNumberChannels = 'adnc',
    kAudioFormatProperty_ASBDFromMPEGPacket = 'admp',
    kAudioFormatProperty_BitmapForLayoutTag = 'bmtg',
    kAudioFormatProperty_MatrixMixMap = 'mmap',
    kAudioFormatProperty_ChannelMap = 'chmp',
    kAudioFormatProperty_NumberOfChannelsForLayout = 'nchm',
    kAudioFormatProperty_AreChannelLayoutsEquivalent	= 'cheq',
    kAudioFormatProperty_ChannelLayoutHash = 'chha',
    kAudioFormatProperty_ValidateChannelLayout = 'vacl',
    kAudioFormatProperty_ChannelLayoutForTag = 'cmpl',
    kAudioFormatProperty_TagForChannelLayout = 'cmpt',
    kAudioFormatProperty_ChannelLayoutName = 'lonm',
    kAudioFormatProperty_ChannelLayoutSimpleName = 'lsnm',
    kAudioFormatProperty_ChannelLayoutForBitmap = 'cmpb',
    kAudioFormatProperty_ChannelName = 'cnam',
    kAudioFormatProperty_ChannelShortName = 'csnm',
    kAudioFormatProperty_TagsForNumberOfChannels = 'tagc',
    kAudioFormatProperty_PanningMatrix = 'panm',
    kAudioFormatProperty_BalanceFade = 'balf',
    kAudioFormatProperty_ID3TagSize = 'id3s',
    kAudioFormatProperty_ID3TagToDictionary = 'id3d'
};
enum : AudioFormatPropertyID {
    kAudioFormatProperty_HardwareCodecCapabilities = 'hwcc'} ;
enum : UInt32 {
    kAudioDecoderComponentType = 'adec',
    kAudioEncoderComponentType = 'aenc'};
enum : UInt32 {
    kAppleSoftwareAudioCodecManufacturer = 'appl',
    kAppleHardwareAudioCodecManufacturer = 'aphw'
};
enum : OSStatus {
    kAudioFormatUnspecifiedError = 'what',
    kAudioFormatUnsupportedPropertyError = 'prop',
    kAudioFormatBadPropertySizeError = '!siz',
    kAudioFormatBadSpecifierSizeError = '!spc',
    kAudioFormatUnsupportedDataFormatError = 'fmt?',
    kAudioFormatUnknownFormatError = '!fmt'
};

/* AudioQueue.h */
typedef UInt32 AudioQueueParameterID;
typedef Float32 AudioQueueParameterValue;
enum : OSStatus {
    kAudioQueueErr_DisposalPending = -66685,
    kAudioQueueErr_CannotStart = -66681,
    kAudioQueueErr_InvalidDevice = -66680,
    kAudioQueueErr_BufferInQueue = -66679,
    kAudioQueueErr_InvalidQueueType = -66677,
    kAudioQueueErr_Permissions = -66676,
    kAudioQueueErr_PrimeTimedOut = -66674,
    kAudioQueueErr_CodecNotFound = -66673,
    kAudioQueueErr_InvalidCodecAccess = -66672,
    kAudioQueueErr_QueueInvalidated = -66671,
    kAudioQueueErr_TooManyTaps = -66670,
    kAudioQueueErr_RecordUnderrun = -66668,
    kAudioQueueErr_BufferEnqueuedTwice = -66666,
    kAudioQueueErr_CannotStartYet = -66665,
    kAudioQueueErr_InvalidOfflineMode = -66626};
enum : AudioQueuePropertyID {
    kAudioQueueDeviceProperty_SampleRate = 'aqsr',
    kAudioQueueDeviceProperty_NumberChannels = 'aqdc',
    kAudioQueueProperty_CurrentDevice = 'aqcd',
    kAudioQueueProperty_MagicCookie = 'aqmc',
    kAudioQueueProperty_MaximumOutputPacketSize = 'xops',
    kAudioQueueProperty_ChannelLayout = 'aqcl',
    kAudioQueueProperty_CurrentLevelMeterDB = 'aqmd',
    kAudioQueueProperty_DecodeBufferSizeFrames = 'dcbf',
    kAudioQueueProperty_ConverterError = 'qcve'};
enum : AudioQueuePropertyID {
    kAudioQueueProperty_HardwareCodecPolicy = 'aqcp'
};
enum : UInt32 {
    kAudioQueueHardwareCodecPolicy_Default = 0,
    kAudioQueueHardwareCodecPolicy_UseSoftwareOnly = 1,
    kAudioQueueHardwareCodecPolicy_UseHardwareOnly = 2,
    kAudioQueueHardwareCodecPolicy_PreferSoftware = 3,
    kAudioQueueHardwareCodecPolicy_PreferHardware = 4
};
enum : AudioQueuePropertyID {
    kAudioQueueProperty_ChannelAssignments = 'aqca'
} ;
struct AudioQueueParameterEvent {
    AudioQueueParameterID mID;
    AudioQueueParameterValue mValue;
};
typedef struct AudioQueueParameterEvent AudioQueueParameterEvent;
typedef struct AudioQueueChannelAssignment {
    CFStringRef mDeviceUID;
    UInt32 mChannelNumber;
} AudioQueueChannelAssignment;

/* AudioServices.h */
enum : OSStatus {
    kAudioServicesBadSpecifierSizeError = '!spc'};
typedef UInt32 AudioServicesPropertyID;
enum : AudioServicesPropertyID {
    kAudioServicesPropertyIsUISound = 'isui',
    kAudioServicesPropertyCompletePlaybackIfAppDies = 'ifdi'
};

/* AudioSession.h */
enum
    {
    kAudioSessionNoError = 0,
    kAudioSessionNotInitialized = '!ini',
    kAudioSessionAlreadyInitialized = 'init',
    kAudioSessionInitializationError = 'ini?',
    kAudioSessionUnsupportedPropertyError = 'pty?',
    kAudioSessionBadPropertySizeError = '!siz',
    kAudioSessionNotActiveError = '!act',
    kAudioServicesNoHardwareError = 'nohw',
    kAudioSessionNoCategorySet = '?cat',
    kAudioSessionIncompatibleCategory = '!cat',
    kAudioSessionUnspecifiedError = 'what'
};
typedef UInt32 AudioSessionPropertyID;
enum {
    kAudioSessionBeginInterruption = 1,
    kAudioSessionEndInterruption = 0
};
enum {
    kAudioSessionCategory_AmbientSound = 'ambi',
    kAudioSessionCategory_SoloAmbientSound = 'solo',
    kAudioSessionCategory_MediaPlayback = 'medi',
    kAudioSessionCategory_RecordAudio = 'reca',
    kAudioSessionCategory_PlayAndRecord = 'plar',
    kAudioSessionCategory_AudioProcessing = 'proc'
};
enum {
    kAudioSessionOverrideAudioRoute_None = 0,
    kAudioSessionOverrideAudioRoute_Speaker = 'spkr'
};
enum {
    kAudioSessionRouteChangeReason_Unknown = 0,
    kAudioSessionRouteChangeReason_NewDeviceAvailable = 1,
    kAudioSessionRouteChangeReason_OldDeviceUnavailable = 2,
    kAudioSessionRouteChangeReason_CategoryChange = 3,
    kAudioSessionRouteChangeReason_Override = 4,
    kAudioSessionRouteChangeReason_WakeFromSleep = 6,
    kAudioSessionRouteChangeReason_NoSuitableRouteForCategory = 7,
    kAudioSessionRouteChangeReason_RouteConfigurationChange = 8
};
enum {
    kAudioSessionInterruptionType_ShouldResume = 'irsm',
    kAudioSessionInterruptionType_ShouldNotResume = '!rsm'
};
typedef UInt32 AudioSessionInterruptionType;
enum {
    kAudioSessionMode_Default = 'dflt',
    kAudioSessionMode_VoiceChat = 'vcct',
    kAudioSessionMode_VideoRecording = 'vrcd',
    kAudioSessionMode_Measurement = 'msmt',
    kAudioSessionMode_GameChat = 'gmct'
};
enum {
    kAudioSessionProperty_PreferredHardwareSampleRate = 'hwsr',
    kAudioSessionProperty_PreferredHardwareIOBufferDuration = 'iobd',
    kAudioSessionProperty_AudioCategory = 'acat',
    kAudioSessionProperty_AudioRouteChange = 'roch',
    kAudioSessionProperty_CurrentHardwareSampleRate = 'chsr',
    kAudioSessionProperty_CurrentHardwareInputNumberChannels = 'chic',
    kAudioSessionProperty_CurrentHardwareOutputNumberChannels = 'choc',
    kAudioSessionProperty_CurrentHardwareOutputVolume = 'chov',
    kAudioSessionProperty_CurrentHardwareInputLatency = 'cilt',
    kAudioSessionProperty_CurrentHardwareOutputLatency = 'colt',
    kAudioSessionProperty_CurrentHardwareIOBufferDuration = 'chbd',
    kAudioSessionProperty_OtherAudioIsPlaying = 'othr',
    kAudioSessionProperty_OverrideAudioRoute = 'ovrd',
    kAudioSessionProperty_AudioInputAvailable = 'aiav',
    kAudioSessionProperty_ServerDied = 'died',
    kAudioSessionProperty_OtherMixableAudioShouldDuck = 'duck',
    kAudioSessionProperty_OverrideCategoryMixWithOthers = 'cmix',
    kAudioSessionProperty_OverrideCategoryDefaultToSpeaker = 'cspk',
    kAudioSessionProperty_OverrideCategoryEnableBluetoothInput = 'cblu',
    kAudioSessionProperty_InterruptionType = 'type',
    kAudioSessionProperty_Mode = 'mode',
    kAudioSessionProperty_InputSources = 'srcs',
    kAudioSessionProperty_OutputDestinations = 'dsts',
    kAudioSessionProperty_InputSource = 'isrc',
    kAudioSessionProperty_OutputDestination = 'odst',
    kAudioSessionProperty_InputGainAvailable = 'igav',
    kAudioSessionProperty_InputGainScalar = 'igsc',
    kAudioSessionProperty_AudioRouteDescription = 'crar'
};
typedef void (*AudioSessionInterruptionListener)(
    void * inClientData,
    UInt32 inInterruptionState);
typedef void (*AudioSessionPropertyListener)(
    void * inClientData,
    AudioSessionPropertyID	inID,
    UInt32 inDataSize,
    const void * inData);
enum {
    kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation = (1 << 0)
};
enum {
    kAudioSessionCategory_UserInterfaceSoundEffects = 'uifx',
    kAudioSessionCategory_LiveAudio = 'live'
};
enum {
    kAudioSessionProperty_AudioRoute = 'rout'};

/* AudioUnitUtilities.h */
enum : AudioUnitParameterID {
    kAUParameterListener_AnyParameter = 0xFFFFFFFF
};
typedef CF_ENUM(UInt32, AudioUnitEventType) {
    kAudioUnitEvent_ParameterValueChange = 0,
    kAudioUnitEvent_BeginParameterChangeGesture = 1,
    kAudioUnitEvent_EndParameterChangeGesture = 2,
    kAudioUnitEvent_PropertyChange = 3
};
typedef struct AUListenerBase *AUParameterListenerRef;
typedef AUParameterListenerRef AUEventListenerRef;
struct AudioUnitEvent {
    AudioUnitEventType mEventType;
    union {
    AudioUnitParameter mParameter;
    AudioUnitProperty mProperty;
} mArgument;
};
typedef struct AudioUnitEvent AudioUnitEvent;
typedef void (^AUParameterListenerBlock)( void * __nullable inObject,
    const AudioUnitParameter * inParameter,
    AudioUnitParameterValue inValue);
typedef void (^AUEventListenerBlock)( void * __nullable inObject,
    const AudioUnitEvent * inEvent,
    UInt64 inEventHostTime,
    AudioUnitParameterValue inParameterValue);
typedef void (*AUParameterListenerProc)( void * __nullable inUserData,
    void * __nullable inObject,
    const AudioUnitParameter * inParameter,
    AudioUnitParameterValue inValue);
typedef void (*AUEventListenerProc)(void * __nullable inUserData,
    void * __nullable inObject,
    const AudioUnitEvent * inEvent,
    UInt64 inEventHostTime,
    AudioUnitParameterValue inParameterValue);

/* CAFFile.h */
enum : UInt32 {
    kCAF_FileType = 'caff',
    kCAF_FileVersion_Initial	= 1
};
enum : UInt32 {
    kCAF_StreamDescriptionChunkID = 'desc',
    kCAF_AudioDataChunkID = 'data',
    kCAF_ChannelLayoutChunkID = 'chan',
    kCAF_FillerChunkID = 'free',
    kCAF_MarkerChunkID = 'mark',
    kCAF_RegionChunkID = 'regn',
    kCAF_InstrumentChunkID = 'inst',
    kCAF_MagicCookieID = 'kuki',
    kCAF_InfoStringsChunkID = 'info',
    kCAF_EditCommentsChunkID = 'edct',
    kCAF_PacketTableChunkID = 'pakt',
    kCAF_StringsChunkID = 'strg',
    kCAF_UUIDChunkID = 'uuid',
    kCAF_PeakChunkID = 'peak',
    kCAF_OverviewChunkID = 'ovvw',
    kCAF_MIDIChunkID = 'midi',
    kCAF_UMIDChunkID = 'umid',
    kCAF_FormatListID = 'ldsc',
    kCAF_iXMLChunkID = 'iXML'
};
struct CAFFileHeader
    {
    UInt32 mFileType;
    UInt16 mFileVersion;
    UInt16 mFileFlags;
} ATTRIBUTE_PACKED;
typedef struct CAFFileHeader CAFFileHeader;
struct CAFChunkHeader
    {
    UInt32 mChunkType;
    SInt64 mChunkSize;
} ATTRIBUTE_PACKED;
typedef struct CAFChunkHeader CAFChunkHeader;
struct CAF_UUID_ChunkHeader
    {
    CAFChunkHeader mHeader;
    UInt8 mUUID[16];
} ATTRIBUTE_PACKED;
typedef struct CAF_UUID_ChunkHeader CAF_UUID_ChunkHeader;
typedef CF_OPTIONS(UInt32, CAFFormatFlags)
    {
    kCAFLinearPCMFormatFlagIsFloat = (1L << 0),
    kCAFLinearPCMFormatFlagIsLittleEndian = (1L << 1)
};
struct CAFAudioDescription
    {
    Float64 mSampleRate;
    UInt32 mFormatID;
    CAFFormatFlags mFormatFlags;
    UInt32 mBytesPerPacket;
    UInt32 mFramesPerPacket;
    UInt32 mChannelsPerFrame;
    UInt32 mBitsPerChannel;
} ATTRIBUTE_PACKED;
typedef struct CAFAudioDescription CAFAudioDescription;
struct CAFAudioFormatListItem
    {
    CAFAudioDescription mFormat;
    UInt32 mChannelLayoutTag;
} ATTRIBUTE_PACKED;
struct CAFPacketTableHeader
    {
    SInt64 mNumberPackets;
    SInt64 mNumberValidFrames;
    SInt32 mPrimingFrames;
    SInt32 mRemainderFrames;
    UInt8 mPacketDescriptions[1];
} ATTRIBUTE_PACKED;
typedef struct CAFPacketTableHeader CAFPacketTableHeader;
struct CAFDataChunk
    {
    UInt32 mEditCount;
    UInt8 mData[1];
} ATTRIBUTE_PACKED;
typedef struct CAFDataChunk CAFDataChunk;
enum : UInt32 {
    kCAFMarkerType_Generic = 0,
    kCAFMarkerType_ProgramStart = 'pbeg',
    kCAFMarkerType_ProgramEnd = 'pend',
    kCAFMarkerType_TrackStart = 'tbeg',
    kCAFMarkerType_TrackEnd = 'tend',
    kCAFMarkerType_Index = 'indx',
    kCAFMarkerType_RegionStart = 'rbeg',
    kCAFMarkerType_RegionEnd = 'rend',
    kCAFMarkerType_RegionSyncPoint = 'rsyc',
    kCAFMarkerType_SelectionStart = 'sbeg',
    kCAFMarkerType_SelectionEnd = 'send',
    kCAFMarkerType_EditSourceBegin = 'cbeg',
    kCAFMarkerType_EditSourceEnd = 'cend',
    kCAFMarkerType_EditDestinationBegin = 'dbeg',
    kCAFMarkerType_EditDestinationEnd = 'dend',
    kCAFMarkerType_SustainLoopStart = 'slbg',
    kCAFMarkerType_SustainLoopEnd = 'slen',
    kCAFMarkerType_ReleaseLoopStart = 'rlbg',
    kCAFMarkerType_ReleaseLoopEnd = 'rlen',
    kCAFMarkerType_SavedPlayPosition = 'sply',
    kCAFMarkerType_Tempo = 'tmpo',
    kCAFMarkerType_TimeSignature = 'tsig',
    kCAFMarkerType_KeySignature = 'ksig'
};
enum : UInt32 {
    kCAF_SMPTE_TimeTypeNone = 0,
    kCAF_SMPTE_TimeType24 = 1,
    kCAF_SMPTE_TimeType25 = 2,
    kCAF_SMPTE_TimeType30Drop = 3,
    kCAF_SMPTE_TimeType30 = 4,
    kCAF_SMPTE_TimeType2997 = 5,
    kCAF_SMPTE_TimeType2997Drop = 6,
    kCAF_SMPTE_TimeType60 = 7,
    kCAF_SMPTE_TimeType5994 = 8,
    kCAF_SMPTE_TimeType60Drop = 9,
    kCAF_SMPTE_TimeType5994Drop = 10,
    kCAF_SMPTE_TimeType50 = 11,
    kCAF_SMPTE_TimeType2398 = 12
};
struct CAF_SMPTE_Time
    {
    SInt8 mHours;
    SInt8 mMinutes;
    SInt8 mSeconds;
    SInt8 mFrames;
    UInt32 mSubFrameSampleOffset;
} ATTRIBUTE_PACKED;
typedef struct CAF_SMPTE_Time CAF_SMPTE_Time;
struct CAFMarker
    {
    UInt32 mType;
    Float64 mFramePosition;
    UInt32 mMarkerID;
    CAF_SMPTE_Time mSMPTETime;
    UInt32 mChannel;
} ATTRIBUTE_PACKED;
typedef struct CAFMarker CAFMarker;
struct CAFMarkerChunk
    {
    UInt32 mSMPTE_TimeType;
    UInt32 mNumberMarkers;
    CAFMarker mMarkers[1];
} ATTRIBUTE_PACKED;
typedef struct CAFMarkerChunk CAFMarkerChunk;
typedef CF_OPTIONS(UInt32, CAFRegionFlags) {
    kCAFRegionFlag_LoopEnable = 1,
    kCAFRegionFlag_PlayForward = 2,
    kCAFRegionFlag_PlayBackward = 4
};
struct CAFRegion
    {
    UInt32 mRegionID;
    CAFRegionFlags mFlags;
    UInt32 mNumberMarkers;
    CAFMarker mMarkers[1];
} ATTRIBUTE_PACKED;
typedef struct CAFRegion CAFRegion;
struct CAFRegionChunk
    {
    UInt32 mSMPTE_TimeType;
    UInt32 mNumberRegions;
    CAFRegion mRegions[1];
} ATTRIBUTE_PACKED;
typedef struct CAFRegionChunk CAFRegionChunk;
struct CAFInstrumentChunk
    {
    Float32 mBaseNote;
    UInt8 mMIDILowNote;
    UInt8 mMIDIHighNote;
    UInt8 mMIDILowVelocity;
    UInt8 mMIDIHighVelocity;
    Float32 mdBGain;
    UInt32 mStartRegionID;
    UInt32 mSustainRegionID;
    UInt32 mReleaseRegionID;
    UInt32 mInstrumentID;
} ATTRIBUTE_PACKED;
typedef struct CAFInstrumentChunk CAFInstrumentChunk;
struct CAFStringID {
    UInt32 mStringID;
    SInt64 mStringStartByteOffset;
} ATTRIBUTE_PACKED;
typedef struct CAFStringID CAFStringID;
struct CAFStrings
    {
    UInt32 mNumEntries;
    CAFStringID mStringsIDs[1];
} ATTRIBUTE_PACKED;
typedef struct CAFStrings CAFStrings;
struct CAFInfoStrings
    {
    UInt32 mNumEntries;
} ATTRIBUTE_PACKED;
typedef struct CAFInfoStrings CAFInfoStrings;
struct CAFPositionPeak
    {
    Float32 mValue;
    UInt64 mFrameNumber;
} ATTRIBUTE_PACKED;
typedef struct CAFPositionPeak CAFPositionPeak;
struct CAFPeakChunk
    {
    UInt32 mEditCount;
    CAFPositionPeak mPeaks[1];
} ATTRIBUTE_PACKED;
typedef struct CAFPeakChunk CAFPeakChunk;
struct CAFOverviewSample
    {
    SInt16 mMinValue;
    SInt16 mMaxValue;
} ATTRIBUTE_PACKED;
typedef struct CAFOverviewSample CAFOverviewSample;
struct CAFOverviewChunk
    {
    UInt32 mEditCount;
    UInt32 mNumFramesPerOVWSample;
    CAFOverviewSample mData[1];
} ATTRIBUTE_PACKED;
typedef struct CAFOverviewChunk CAFOverviewChunk;
struct CAFUMIDChunk
    {
    UInt8 mBytes[64];
} ATTRIBUTE_PACKED;
typedef struct CAFUMIDChunk CAFUMIDChunk;

/* ExtendedAudioFile.h */
typedef SInt32 ExtAudioFilePacketTableInfoOverride;
enum : ExtAudioFilePacketTableInfoOverride {
    kExtAudioFilePacketTableInfoOverride_UseFileValue = -1,
    kExtAudioFilePacketTableInfoOverride_UseFileValueIfValid	= -2
};
typedef UInt32 ExtAudioFilePropertyID;
enum : ExtAudioFilePropertyID {
    kExtAudioFileProperty_FileChannelLayout = 'fclo',
    kExtAudioFileProperty_ClientChannelLayout	= 'cclo',
    kExtAudioFileProperty_CodecManufacturer = 'cman',
    kExtAudioFileProperty_AudioConverter = 'acnv',
    kExtAudioFileProperty_FileMaxPacketSize = 'fmps',
    kExtAudioFileProperty_ClientMaxPacketSize	= 'cmps',
    kExtAudioFileProperty_ConverterConfig = 'accf',
    kExtAudioFileProperty_IOBufferSizeBytes = 'iobs',
    kExtAudioFileProperty_IOBuffer = 'iobf',
    kExtAudioFileProperty_PacketTable = 'xpti'
};
enum : OSStatus {
    kExtAudioFileError_InvalidPropertySize = -66562,
    kExtAudioFileError_InvalidChannelMap = -66564,
    kExtAudioFileError_InvalidOperationOrder	= -66565,
    kExtAudioFileError_MaxPacketSizeUnknown = -66567,
    kExtAudioFileError_AsyncWriteTooLarge = -66569,
    kExtAudioFileError_AsyncWriteBufferOverflow	= -66570
};
enum : OSStatus {
    kExtAudioFileError_CodecUnavailableInputConsumed = -66559,
    kExtAudioFileError_CodecUnavailableInputNotConsumed = -66560};

/* AUAudioUnit.h */
typedef uint8_t MIDIChannelNumber;
typedef OSStatus AUAudioUnitStatus;
enum : AUEventSampleTime {
    AUEventSampleTimeImmediate = (AUEventSampleTime)0xffffffff00000000LL
};
typedef uint32_t AUAudioFrameCount;
typedef uint32_t AUAudioChannelCount;

/* AUParameters.h */
typedef uint64_t AUParameterAddress;
typedef float AUValue;

/* AUAudioUnit.h */
typedef void (^AUScheduleParameterBlock)(AUEventSampleTime eventSampleTime,
    AUAudioFrameCount rampDurationSampleFrames, AUParameterAddress parameterAddress, AUValue value)
    ;
#if defined(__OBJC__)
typedef void (^AUMIDICIProfileChangedBlock)(uint8_t cable, MIDIChannelNumber channel, MIDICIProfile *profile, BOOL enabled) ;
#endif
#if defined(__OBJC__)
typedef NSDictionary * _Nonnull (^CallHostBlock)(NSDictionary *message);
#endif

/* AUAudioUnitImplementation.h */
union AURenderEvent;
typedef CF_ENUM(uint8_t, AURenderEventType) {
    AURenderEventParameter = 1,
    AURenderEventParameterRamp	= 2,
    AURenderEventMIDI = 8,
    AURenderEventMIDISysEx = 9,
    AURenderEventMIDIEventList = 10
};
typedef struct AURenderEventHeader {
    union AURenderEvent *__nullable next;
    AUEventSampleTime eventSampleTime;
    AURenderEventType eventType;
    uint8_t reserved;
} AURenderEventHeader;
typedef struct AUParameterEvent {
    union AURenderEvent *__nullable next;
    AUEventSampleTime eventSampleTime;
    AURenderEventType eventType;
    uint8_t reserved[3];
    AUAudioFrameCount rampDurationSampleFrames;
    AUParameterAddress parameterAddress;
    AUValue value;
} AUParameterEvent;
typedef struct AUMIDIEvent {
    union AURenderEvent *__nullable next;
    AUEventSampleTime eventSampleTime;
    AURenderEventType eventType;
    uint8_t reserved;
    uint16_t length;
    uint8_t cable;
    uint8_t data[3];
} AUMIDIEvent;
typedef struct AUMIDIEventList {
    union AURenderEvent *__nullable next;
    AUEventSampleTime eventSampleTime;
    AURenderEventType eventType;
    uint8_t reserved;
    uint8_t cable;
    MIDIEventList eventList;
} AUMIDIEventList;
typedef union AURenderEvent {
    AURenderEventHeader head;
    AUParameterEvent parameter;
    AUMIDIEvent MIDI;
    AUMIDIEventList MIDIEventsList;
} AURenderEvent;

/* AUParameters.h */
typedef CF_ENUM(uint32_t, AUParameterAutomationEventType) {
    AUParameterAutomationEventTypeValue = 0,
    AUParameterAutomationEventTypeTouch = 1,
    AUParameterAutomationEventTypeRelease = 2
};
typedef struct AURecordedParameterEvent {
    uint64_t hostTime;
    AUParameterAddress address;
    AUValue value;
} AURecordedParameterEvent;
typedef struct AUParameterAutomationEvent {
    uint64_t hostTime;
    AUParameterAddress address;
    AUValue value;
    AUParameterAutomationEventType eventType;
    uint64_t reserved;
} AUParameterAutomationEvent;
#if defined(__OBJC__)
typedef void (^AUParameterAutomationObserver)(NSInteger numberEvents, const AUParameterAutomationEvent *events);
#endif
typedef void *AUParameterObserverToken;

/* string constants */
#define AUDIO_TOOLBOX_VERSION 1060
#define AUDIO_UNIT_VERSION 1070
#define AU_SUPPORT_INTERAPP_AUDIO 1
#define kAFInfoDictionary_Album "album"
#define kAFInfoDictionary_ApproximateDurationInSeconds "approximate duration in seconds"
#define kAFInfoDictionary_Artist "artist"
#define kAFInfoDictionary_ChannelLayout "channel layout"
#define kAFInfoDictionary_Comments "comments"
#define kAFInfoDictionary_Composer "composer"
#define kAFInfoDictionary_Copyright "copyright"
#define kAFInfoDictionary_EncodingApplication "encoding application"
#define kAFInfoDictionary_Genre "genre"
#define kAFInfoDictionary_ISRC "ISRC"
#define kAFInfoDictionary_KeySignature "key signature"
#define kAFInfoDictionary_Lyricist "lyricist"
#define kAFInfoDictionary_NominalBitRate "nominal bit rate"
#define kAFInfoDictionary_RecordedDate "recorded date"
#define kAFInfoDictionary_SourceBitDepth "source bit depth"
#define kAFInfoDictionary_SourceEncoder "source encoder"
#define kAFInfoDictionary_SubTitle "subtitle"
#define kAFInfoDictionary_Tempo "tempo"
#define kAFInfoDictionary_TimeSignature "time signature"
#define kAFInfoDictionary_Title "title"
#define kAFInfoDictionary_TrackNumber "track number"
#define kAFInfoDictionary_Year "year"
#define kAUPresetCPULoadKey "cpu-load"
#define kAUPresetDataKey "data"
#define kAUPresetElementNameKey "element-name"
#define kAUPresetExternalFileRefs "file-references"
#define kAUPresetManufacturerKey "manufacturer"
#define kAUPresetNameKey "name"
#define kAUPresetNumberKey "preset-number"
#define kAUPresetPartKey "part"
#define kAUPresetRenderQualityKey "render-quality"
#define kAUPresetSubtypeKey "subtype"
#define kAUPresetTypeKey "type"
#define kAUPresetVersionKey "version"
#define kAudioComponentConfigurationInfo_ValidationResult "ValidationResult"
#define kAudioComponentValidationParameter_ForceValidation "ForceValidation"
#define kAudioComponentValidationParameter_LoadOutOfProcess "LoadOutOfProcess"
#define kAudioComponentValidationParameter_TimeOut "TimeOut"
#define kAudioSession_AudioRouteChangeKey_OldRoute "OutputDeviceDidChange_OldRoute"
#define kAudioSession_AudioRouteChangeKey_Reason "OutputDeviceDidChange_Reason"
#define kAudioSettings_AvailableValues "available values"
#define kAudioSettings_CurrentValue "current value"
#define kAudioSettings_Hint "hint"
#define kAudioSettings_LimitedValues "limited values"
#define kAudioSettings_Parameters "parameters"
#define kAudioSettings_SettingKey "key"
#define kAudioSettings_SettingName "name"
#define kAudioSettings_Summary "summary"
#define kAudioSettings_TopLevelKey "name"
#define kAudioSettings_Unit "unit"
#define kAudioSettings_ValueType "value type"
#define kAudioSettings_Version "version"
#define kAudioUnitConfigurationInfo_BusCountWritable "BusCountWritable"
#define kAudioUnitConfigurationInfo_ChannelConfigurations "ChannelConfigurations"
#define kAudioUnitConfigurationInfo_HasCustomView "HasCustomView"
#define kAudioUnitConfigurationInfo_IconURL "IconURL"
#define kAudioUnitConfigurationInfo_InitialInputs "InitialInputs"
#define kAudioUnitConfigurationInfo_InitialOutputs "InitialOutputs"
#define kAudioUnitConfigurationInfo_MIDIProtocol "MIDIProtocol"
#define kAudioUnitConfigurationInfo_MigrateFromPlugin "MigrateFromPlugin"
#define kAudioUnitConfigurationInfo_SupportedChannelLayoutTags "SupportedChannelLayoutTags"
/* Apple's inline helpers (AudioUnitProperties.h, AudioFile.h) */
static inline AudioUnitParameterOptions GetAudioUnitParameterDisplayType(AudioUnitParameterOptions flags) {
    return flags & kAudioUnitParameterFlag_DisplayMask;
}
static inline AudioUnitParameterOptions SetAudioUnitParameterDisplayType(AudioUnitParameterOptions flags, AudioUnitParameterOptions displayType) {
    return (flags & ~kAudioUnitParameterFlag_DisplayMask) | displayType;
}
static inline size_t NumBytesToNumAudioFileMarkers(size_t inNumBytes) {
    return inNumBytes < offsetof(AudioFileMarkerList, mMarkers[0]) ? 0 : (inNumBytes - offsetof(AudioFileMarkerList, mMarkers[0])) / sizeof(AudioFileMarker);
}
static inline size_t NumAudioFileMarkersToNumBytes(size_t inNumMarkers) {
    return offsetof(AudioFileMarkerList, mMarkers) + inNumMarkers * sizeof(AudioFileMarker);
}
static inline AudioFileRegion *NextAudioFileRegion(const AudioFileRegion *inAFRegionPtr) {
    return (AudioFileRegion *)((char *)inAFRegionPtr + offsetof(AudioFileRegion, mMarkers) + inAFRegionPtr->mNumberMarkers * sizeof(AudioFileMarker));
}
#pragma clang assume_nonnull end
__END_DECLS
