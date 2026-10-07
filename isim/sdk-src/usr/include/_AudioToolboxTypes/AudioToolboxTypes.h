#pragma once
/* isim AudioToolbox C types (self-authored, iOS API names and C layouts): opaque handles, AudioQueueBuffer and the
 * C callback types of Audio Queue and Audio Converter Services. Re-exported by the AudioToolbox Swift module; the
 * functions themselves are implemented in Swift (AudioServices.swift). */
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

#pragma clang assume_nonnull end
__END_DECLS
