#pragma once
/* isim AudioToolbox C types (self-authored, iOS API names and C layouts): opaque handles, AudioQueueBuffer and the
 * C callback types of Audio Queue, Audio Converter and Audio Unit Services (AudioComponent, AudioUnit, AUGraph).
 * Re-exported by the AudioToolbox Swift module; the functions themselves are implemented in Swift (AudioServices.swift,
 * AudioUnits.swift). */
#include <CoreAudioTypes/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin

typedef struct OpaqueAudioFileID *AudioFileID;
typedef struct OpaqueExtAudioFile *ExtAudioFileRef;
typedef struct OpaqueAudioConverter *AudioConverterRef;
typedef struct OpaqueAudioQueue *AudioQueueRef;
typedef struct OpaqueAudioQueueTimeline *AudioQueueTimelineRef;
typedef uint32_t AudioQueuePropertyID;

struct AudioQueueBuffer {
    const uint32_t mAudioDataBytesCapacity;
    void *const mAudioData;
    uint32_t mAudioDataByteSize;
    void *_Nullable mUserData;
    const uint32_t mPacketDescriptionCapacity;
    AudioStreamPacketDescription *const _Nullable mPacketDescriptions;
    uint32_t mPacketDescriptionCount;
};
typedef struct AudioQueueBuffer AudioQueueBuffer;
typedef AudioQueueBuffer *AudioQueueBufferRef;

typedef void (*AudioQueueOutputCallback)(void *_Nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
typedef void (*AudioQueueInputCallback)(void *_Nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer,
                                        const AudioTimeStamp *inStartTime, uint32_t inNumberPacketDescriptions,
                                        const AudioStreamPacketDescription *_Nullable inPacketDescs);
typedef void (*AudioQueuePropertyListenerProc)(void *_Nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);
typedef int32_t /* OSStatus */ (*AudioConverterComplexInputDataProc)(AudioConverterRef inAudioConverter, uint32_t *ioNumberDataPackets,
                                                       AudioBufferList *ioData, AudioStreamPacketDescription *_Nullable *_Nullable outDataPacketDescription,
                                                       void *_Nullable inUserData);

struct AudioQueueLevelMeterState {
    float mAveragePower;
    float mPeakPower;
};
typedef struct AudioQueueLevelMeterState AudioQueueLevelMeterState;

/* Audio Queue processing taps */
typedef struct OpaqueAudioQueueProcessingTap *AudioQueueProcessingTapRef;
typedef ISIM_CA_OPTIONS(uint32_t, AudioQueueProcessingTapFlags) {
    kAudioQueueProcessingTap_PreEffects = (1U << 0),
    kAudioQueueProcessingTap_PostEffects = (1U << 1),
    kAudioQueueProcessingTap_Siphon = (1U << 2),
    kAudioQueueProcessingTap_StartOfStream = (1U << 8),
    kAudioQueueProcessingTap_EndOfStream = (1U << 9)
};
typedef void (*AudioQueueProcessingTapCallback)(void *inClientData, AudioQueueProcessingTapRef inAQTap, uint32_t inNumberFrames,
                                                AudioTimeStamp *ioTimeStamp, AudioQueueProcessingTapFlags *ioFlags,
                                                uint32_t *outNumberFrames, AudioBufferList *ioData);

/* Audio Components and Audio Units */
struct AudioComponentDescription {
    uint32_t componentType;
    uint32_t componentSubType;
    uint32_t componentManufacturer;
    uint32_t componentFlags;
    uint32_t componentFlagsMask;
};
typedef struct AudioComponentDescription AudioComponentDescription;
typedef struct OpaqueAudioComponent *AudioComponent;
typedef struct ComponentInstanceRecord *AudioComponentInstance;
typedef AudioComponentInstance AudioUnit;

typedef ISIM_CA_OPTIONS(uint32_t, AudioUnitRenderActionFlags) {
    kAudioUnitRenderAction_PreRender = (1U << 2),
    kAudioUnitRenderAction_PostRender = (1U << 3),
    kAudioUnitRenderAction_OutputIsSilence = (1U << 4),
    kAudioOfflineUnitRenderAction_Preflight = (1U << 5),
    kAudioOfflineUnitRenderAction_Render = (1U << 6),
    kAudioOfflineUnitRenderAction_Complete = (1U << 7),
    kAudioUnitRenderAction_PostRenderError = (1U << 8),
    kAudioUnitRenderAction_DoNotCheckRenderArgs = (1U << 9)
};
typedef int32_t /* OSStatus */ (*AURenderCallback)(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                                   const AudioTimeStamp *inTimeStamp, uint32_t inBusNumber, uint32_t inNumberFrames,
                                                   AudioBufferList *_Nullable ioData);
typedef void (*AudioUnitPropertyListenerProc)(void *_Nullable inRefCon, AudioUnit inUnit, uint32_t inID, uint32_t inScope, uint32_t inElement);
struct AURenderCallbackStruct {
    AURenderCallback _Nullable inputProc;
    void *_Nullable inputProcRefCon;
};
typedef struct AURenderCallbackStruct AURenderCallbackStruct;
struct AudioUnitConnection {
    AudioUnit _Nullable sourceAudioUnit;
    uint32_t sourceOutputNumber;
    uint32_t destInputNumber;
};
typedef struct AudioUnitConnection AudioUnitConnection;
struct AudioUnitParameter {
    AudioUnit mAudioUnit;
    uint32_t mParameterID;
    uint32_t mScope;
    uint32_t mElement;
};
typedef struct AudioUnitParameter AudioUnitParameter;

/* AUGraph */
typedef struct OpaqueAUGraph *AUGraph;
typedef int32_t AUNode;
struct AUNodeRenderCallback {
    AUNode destNode;
    uint32_t destInputNumber;
    AURenderCallbackStruct cback;
};
typedef struct AUNodeRenderCallback AUNodeRenderCallback;


/* Music devices (MusicDevice.h): the Sampler and MIDISynth units */
typedef uint32_t MusicDeviceInstrumentID;
typedef uint32_t MusicDeviceGroupID;
typedef uint32_t NoteInstanceID;
typedef AudioComponentInstance MusicDeviceComponent;
struct MusicDeviceStdNoteParams {
    uint32_t argCount;
    float mPitch;
    float mVelocity;
};
typedef struct MusicDeviceStdNoteParams MusicDeviceStdNoteParams;
struct NoteParamsControlValue {
    uint32_t mID;
    float mValue;
};
typedef struct NoteParamsControlValue NoteParamsControlValue;
struct MusicDeviceNoteParams {
    uint32_t argCount;
    float mPitch;
    float mVelocity;
    NoteParamsControlValue mControls[1];
};
typedef struct MusicDeviceNoteParams MusicDeviceNoteParams;
static const uint32_t kMusicNoteEvent_UseGroupInstrument = 0xFFFFFFFF;
static const uint32_t kMusicNoteEvent_Unused = 0xFFFFFFFF;
struct MIDIEventList;
typedef int32_t /* OSStatus */ (*MusicDeviceMIDIEventProc)(void *self, uint32_t inStatus, uint32_t inData1, uint32_t inData2, uint32_t inOffsetSampleFrame);
typedef int32_t /* OSStatus */ (*MusicDeviceSysExProc)(void *self, const uint8_t *inData, uint32_t inLength);
typedef int32_t /* OSStatus */ (*MusicDeviceStartNoteProc)(void *self, MusicDeviceInstrumentID inInstrument, MusicDeviceGroupID inGroupID,
                                             NoteInstanceID *outNoteInstanceID, uint32_t inOffsetSampleFrame, const MusicDeviceNoteParams *inParams);
typedef int32_t /* OSStatus */ (*MusicDeviceStopNoteProc)(void *self, MusicDeviceGroupID inGroupID, NoteInstanceID inNoteInstanceID, uint32_t inOffsetSampleFrame);
/* AUSampler instruments (AudioUnitProperties.h) */
struct AUSamplerInstrumentData {
    CFURLRef fileURL;
    uint8_t instrumentType;
    uint8_t bankMSB;
    uint8_t bankLSB;
    uint8_t presetID;
};
typedef struct AUSamplerInstrumentData AUSamplerInstrumentData;
struct AUSamplerBankPresetData {
    CFURLRef bankURL;
    uint8_t bankMSB;
    uint8_t bankLSB;
    uint8_t presetID;
    uint8_t reserved;
};
typedef struct AUSamplerBankPresetData AUSamplerBankPresetData;

/* Music Sequences and Music Players (MusicPlayer.h) */
#define ISIM_AT_ENUM(_type, _name) enum __attribute__((enum_extensibility(open))) _name : _type _name; enum _name : _type
typedef struct OpaqueMusicPlayer *MusicPlayer;
typedef struct OpaqueMusicSequence *MusicSequence;
typedef struct OpaqueMusicTrack *MusicTrack;
typedef struct OpaqueMusicEventIterator *MusicEventIterator;
typedef double MusicTimeStamp;
#define kMusicTimeStamp_EndOfTrack 1000000000.0
typedef uint32_t MusicEventType;
static const uint32_t kMusicEventType_NULL = 0;
static const uint32_t kMusicEventType_ExtendedNote = 1;
static const uint32_t kMusicEventType_ExtendedTempo = 3;
static const uint32_t kMusicEventType_User = 4;
static const uint32_t kMusicEventType_Meta = 5;
static const uint32_t kMusicEventType_MIDINoteMessage = 6;
static const uint32_t kMusicEventType_MIDIChannelMessage = 7;
static const uint32_t kMusicEventType_MIDIRawData = 8;
static const uint32_t kMusicEventType_Parameter = 9;
static const uint32_t kMusicEventType_AUPreset = 10;
enum { kMusicEventType_ExtendedControl = 2 };
typedef ISIM_CA_OPTIONS(uint32_t, MusicSequenceLoadFlags) {
    kMusicSequenceLoadSMF_PreserveTracks = 0,
    kMusicSequenceLoadSMF_ChannelsToTracks = (1U << 0),
};
typedef ISIM_AT_ENUM(uint32_t, MusicSequenceType) {
    kMusicSequenceType_Beats = 0x62656174,      /* 'beat' */
    kMusicSequenceType_Seconds = 0x73656373,    /* 'secs' */
    kMusicSequenceType_Samples = 0x73616D70,    /* 'samp' */
};
typedef ISIM_AT_ENUM(uint32_t, MusicSequenceFileTypeID) {
    kMusicSequenceFile_AnyType = 0,
    kMusicSequenceFile_MIDIType = 0x6D696469,   /* 'midi' */
    kMusicSequenceFile_iMelodyType = 0x696D656C, /* 'imel' */
};
typedef ISIM_CA_OPTIONS(uint32_t, MusicSequenceFileFlags) {
    kMusicSequenceFileFlags_Default = 0,
    kMusicSequenceFileFlags_EraseFile = 1,
};
struct MIDINoteMessage {
    uint8_t channel;
    uint8_t note;
    uint8_t velocity;
    uint8_t releaseVelocity;
    float duration;
};
typedef struct MIDINoteMessage MIDINoteMessage;
struct MIDIChannelMessage {
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    uint8_t reserved;
};
typedef struct MIDIChannelMessage MIDIChannelMessage;
struct MIDIRawData {
    uint32_t length;
    uint8_t data[1];
};
typedef struct MIDIRawData MIDIRawData;
struct MIDIMetaEvent {
    uint8_t metaEventType;
    uint8_t unused1;
    uint8_t unused2;
    uint8_t unused3;
    uint32_t dataLength;
    uint8_t data[1];
};
typedef struct MIDIMetaEvent MIDIMetaEvent;
struct MusicEventUserData {
    uint32_t length;
    uint8_t data[1];
};
typedef struct MusicEventUserData MusicEventUserData;
struct ExtendedNoteOnEvent {
    MusicDeviceInstrumentID instrumentID;
    MusicDeviceGroupID groupID;
    float duration;
    MusicDeviceNoteParams extendedParams;
};
typedef struct ExtendedNoteOnEvent ExtendedNoteOnEvent;
struct ParameterEvent {
    uint32_t parameterID;
    uint32_t scope;
    uint32_t element;
    float value;
};
typedef struct ParameterEvent ParameterEvent;
struct ExtendedTempoEvent {
    double bpm;
};
typedef struct ExtendedTempoEvent ExtendedTempoEvent;
struct AUPresetEvent {
    uint32_t scope;
    uint32_t element;
    CFPropertyListRef preset;
};
typedef struct AUPresetEvent AUPresetEvent;
struct CABarBeatTime {
    int32_t bar;
    uint16_t beat;
    uint16_t subbeat;
    uint16_t subbeatDivisor;
    uint16_t reserved;
};
typedef struct CABarBeatTime CABarBeatTime;
struct MusicTrackLoopInfo {
    MusicTimeStamp loopDuration;
    int32_t numberOfLoops;
};
typedef struct MusicTrackLoopInfo MusicTrackLoopInfo;
typedef void (*MusicSequenceUserCallback)(void *_Nullable inClientData, MusicSequence inSequence, MusicTrack inTrack, MusicTimeStamp inEventTime,
                                          const MusicEventUserData *inEventData, MusicTimeStamp inStartSliceBeat, MusicTimeStamp inEndSliceBeat);


/* Audio File packet translations (AudioFile.h), shared with Audio File Streams */
struct AudioFramePacketTranslation {
    int64_t mFrame;
    int64_t mPacket;
    uint32_t mFrameOffsetInPacket;
};
typedef struct AudioFramePacketTranslation AudioFramePacketTranslation;
typedef ISIM_CA_OPTIONS(uint32_t, AudioBytePacketTranslationFlags) {
    kBytePacketTranslationFlag_IsEstimate = 1,
};
struct AudioBytePacketTranslation {
    int64_t mByte;
    int64_t mPacket;
    uint32_t mByteOffsetInPacket;
    AudioBytePacketTranslationFlags mFlags;
};
typedef struct AudioBytePacketTranslation AudioBytePacketTranslation;
struct AudioFilePacketTableInfo {
    int64_t mNumberValidFrames;
    int32_t mPrimingFrames;
    int32_t mRemainderFrames;
};
typedef struct AudioFilePacketTableInfo AudioFilePacketTableInfo;
struct AudioPacketRollDistanceTranslation {
    int64_t mPacket;
    int64_t mRollDistance;
};
typedef struct AudioPacketRollDistanceTranslation AudioPacketRollDistanceTranslation;
struct AudioIndependentPacketTranslation {
    int64_t mPacket;
    int64_t mIndependentlyDecodablePacket;
};
typedef struct AudioIndependentPacketTranslation AudioIndependentPacketTranslation;
struct AudioPacketDependencyInfoTranslation {
    int64_t mPacket;
    uint32_t mIsIndependentlyDecodable;
    uint32_t mNumberPrerollPackets;
};
typedef struct AudioPacketDependencyInfoTranslation AudioPacketDependencyInfoTranslation;

struct AudioFormatListItem {
    AudioStreamBasicDescription mASBD;
    uint32_t mChannelLayoutTag;
};
typedef struct AudioFormatListItem AudioFormatListItem;

/* Audio File Streams (AudioFileStream.h) */
typedef struct OpaqueAudioFileStreamID *AudioFileStreamID;
typedef uint32_t AudioFileStreamPropertyID;
typedef ISIM_CA_OPTIONS(uint32_t, AudioFileStreamPropertyFlags) {
    kAudioFileStreamPropertyFlag_PropertyIsCached = 1,
    kAudioFileStreamPropertyFlag_CacheProperty = 2,
};
typedef ISIM_CA_OPTIONS(uint32_t, AudioFileStreamParseFlags) {
    kAudioFileStreamParseFlag_Discontinuity = 1,
};
typedef ISIM_CA_OPTIONS(uint32_t, AudioFileStreamSeekFlags) {
    kAudioFileStreamSeekFlag_OffsetIsEstimated = 1,
};
typedef void (*AudioFileStream_PropertyListenerProc)(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID,
                                                     AudioFileStreamPropertyFlags *ioFlags);
typedef void (*AudioFileStream_PacketsProc)(void *inClientData, uint32_t inNumberBytes, uint32_t inNumberPackets, const void *inInputData,
                                            AudioStreamPacketDescription *_Nullable inPacketDescriptions);

/* Core Audio Clock (CAClock.h) */
typedef struct OpaqueCAClock *CAClockRef;
typedef double CAClockSamples;
typedef double CAClockBeats;
typedef double CAClockTempo;
typedef double CAClockSeconds;
typedef ISIM_AT_ENUM(uint32_t, CAClockPropertyID) {
    kCAClockProperty_InternalTimebase = 0x696E7462,      /* 'intb' */
    kCAClockProperty_TimebaseSource = 0x69746273,        /* 'itbs' */
    kCAClockProperty_SyncMode = 0x73796E6D,              /* 'synm' */
    kCAClockProperty_SyncSource = 0x73796E73,            /* 'syns' */
    kCAClockProperty_SMPTEFormat = 0x736D7066,           /* 'smpf' */
    kCAClockProperty_SMPTEOffset = 0x736D706F,           /* 'smpo' */
    kCAClockProperty_MIDIClockDestinations = 0x6D626364, /* 'mbcd' */
    kCAClockProperty_MTCDestinations = 0x6D746364,       /* 'mtcd' */
    kCAClockProperty_MTCFreewheelTime = 0x6D746677,      /* 'mtfw' */
    kCAClockProperty_TempoMap = 0x746D706F,              /* 'tmpo' */
    kCAClockProperty_MeterTrack = 0x6D657472,            /* 'metr' */
    kCAClockProperty_Name = 0x6E616D65,                  /* 'name' */
    kCAClockProperty_SendMIDISPP = 0x6D737070,           /* 'mspp' */
};
typedef ISIM_AT_ENUM(uint32_t, CAClockTimebase) {
    kCAClockTimebase_HostTime = 0x686F7374,              /* 'host' */
    kCAClockTimebase_AudioDevice = 0x61756469,           /* 'audi' */
    kCAClockTimebase_AudioOutputUnit = 0x61756F75,       /* 'auou' */
};
typedef ISIM_AT_ENUM(uint32_t, CAClockSyncMode) {
    kCAClockSyncMode_Internal = 0x696E7472,              /* 'intr' */
    kCAClockSyncMode_MIDIClockTransport = 0x6D636C6B,    /* 'mclk' */
    kCAClockSyncMode_MTCTransport = 0x6D6D7463,          /* 'mmtc' */
};
typedef uint32_t CAClockSMPTEFormat;
typedef ISIM_AT_ENUM(uint32_t, CAClockMessage) {
    kCAClockMessage_StartTimeSet = 0x7374696D,           /* 'stim' */
    kCAClockMessage_Started = 0x7374726E,                /* 'strt' */
    kCAClockMessage_Stopped = 0x73746F70,                /* 'stop' */
    kCAClockMessage_Armed = 0x61726D64,                  /* 'armd' */
    kCAClockMessage_Disarmed = 0x6461726D,               /* 'darm' */
    kCAClockMessage_PropertyChanged = 0x70636867,        /* 'pchg' */
    kCAClockMessage_WrongSMPTEFormat = 0x3F736D70,       /* '?smp' */
};
typedef ISIM_AT_ENUM(uint32_t, CAClockTimeFormat) {
    kCAClockTimeFormat_HostTime = 0x686F7374,            /* 'host' */
    kCAClockTimeFormat_Samples = 0x73616D70,             /* 'samp' */
    kCAClockTimeFormat_Beats = 0x62656174,               /* 'beat' */
    kCAClockTimeFormat_Seconds = 0x73656373,             /* 'secs' */
    kCAClockTimeFormat_SMPTESeconds = 0x736D7073,        /* 'smps' */
    kCAClockTimeFormat_SMPTETime = 0x736D7074,           /* 'smpt' */
    kCAClockTimeFormat_AbsoluteSeconds = 0x61736563,     /* 'asec' */
};
struct CAClockTime {
    CAClockTimeFormat format;
    uint32_t reserved;
    union {
        uint64_t hostTime;
        CAClockSamples samples;
        CAClockBeats beats;
        CAClockSeconds seconds;
        SMPTETime smpte;
    } time;
};
typedef struct CAClockTime CAClockTime;
typedef void (*CAClockListenerProc)(void *userData, CAClockMessage message, const void *param);

#pragma clang assume_nonnull end
__END_DECLS
