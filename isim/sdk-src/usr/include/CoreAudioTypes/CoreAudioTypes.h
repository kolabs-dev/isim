#pragma once
/* isim CoreAudioTypes (self-authored, iOS API names and C layouts): the plain audio data structures shared by
 * AudioToolbox, CoreMedia and AVFoundation. Declared in C so they can cross C function-pointer callbacks
 * (Audio Queue and Audio Converter procs) with the same memory layout as on iOS. */
#include <_isim_cdefs.h>
#include <stdint.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin

#define ISIM_CA_OPTIONS(_type, _name) enum __attribute__((flag_enum, enum_extensibility(open))) _name : _type _name; enum _name : _type

/* AudioFormatID, AudioFormatFlags and OSStatus are Swift typealiases of the AudioToolbox module (UInt32 / Int32) */

struct AudioStreamBasicDescription {
    double mSampleRate;
    uint32_t mFormatID;
    uint32_t mFormatFlags;
    uint32_t mBytesPerPacket;
    uint32_t mFramesPerPacket;
    uint32_t mBytesPerFrame;
    uint32_t mChannelsPerFrame;
    uint32_t mBitsPerChannel;
    uint32_t mReserved;
};
typedef struct AudioStreamBasicDescription AudioStreamBasicDescription;

struct AudioStreamPacketDescription {
    int64_t mStartOffset;
    uint32_t mVariableFramesInPacket;
    uint32_t mDataByteSize;
};
typedef struct AudioStreamPacketDescription AudioStreamPacketDescription;

struct AudioBuffer {
    uint32_t mNumberChannels;
    uint32_t mDataByteSize;
    void *_Nullable mData;
};
typedef struct AudioBuffer AudioBuffer;

struct AudioBufferList {
    uint32_t mNumberBuffers;
    AudioBuffer mBuffers[1];      /* variable length: mNumberBuffers entries */
};
typedef struct AudioBufferList AudioBufferList;

typedef ISIM_CA_OPTIONS(uint32_t, SMPTETimeFlags) { kSMPTETimeUnknown = 0, kSMPTETimeValid = (1U << 0), kSMPTETimeRunning = (1U << 1) };
struct SMPTETime {
    int16_t mSubframes;
    int16_t mSubframeDivisor;
    uint32_t mCounter;
    uint32_t mType;
    SMPTETimeFlags mFlags;
    int16_t mHours;
    int16_t mMinutes;
    int16_t mSeconds;
    int16_t mFrames;
};
typedef struct SMPTETime SMPTETime;

typedef ISIM_CA_OPTIONS(uint32_t, AudioTimeStampFlags) {
    kAudioTimeStampNothingValid = 0,
    kAudioTimeStampSampleTimeValid = (1U << 0),
    kAudioTimeStampHostTimeValid = (1U << 1),
    kAudioTimeStampRateScalarValid = (1U << 2),
    kAudioTimeStampWordClockTimeValid = (1U << 3),
    kAudioTimeStampSMPTETimeValid = (1U << 4),
    kAudioTimeStampSampleHostTimeValid = (kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid)
};
struct AudioTimeStamp {
    double mSampleTime;
    uint64_t mHostTime;
    double mRateScalar;
    uint64_t mWordClockTime;
    SMPTETime mSMPTETime;
    AudioTimeStampFlags mFlags;
    uint32_t mReserved;
};
typedef struct AudioTimeStamp AudioTimeStamp;

#pragma clang assume_nonnull end
__END_DECLS
