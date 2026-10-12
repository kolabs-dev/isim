#pragma once
/* isim AudioToolbox C types (self-authored, iOS API names and C layouts): opaque handles, AudioQueueBuffer and the
 * C callback types of Audio Queue, Audio Converter and Audio Unit Services (AudioComponent, AudioUnit, AUGraph).
 * Re-exported by the AudioToolbox Swift module; the functions themselves are implemented in Swift (AudioServices.swift,
 * AudioUnits.swift). */
#include <CoreAudioTypes/CoreAudioTypes.h>
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

#pragma clang assume_nonnull end
__END_DECLS
