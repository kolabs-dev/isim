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
typedef enum __attribute__((enum_extensibility(open))) SMPTETimeType : uint32_t SMPTETimeType;
enum SMPTETimeType : uint32_t {
    kSMPTETimeType24 = 0, kSMPTETimeType25 = 1, kSMPTETimeType30Drop = 2, kSMPTETimeType30 = 3, kSMPTETimeType2997 = 4,
    kSMPTETimeType2997Drop = 5, kSMPTETimeType60 = 6, kSMPTETimeType5994 = 7, kSMPTETimeType60Drop = 8, kSMPTETimeType5994Drop = 9,
    kSMPTETimeType50 = 10, kSMPTETimeType2398 = 11,
};
struct SMPTETime {
    int16_t mSubframes;
    int16_t mSubframeDivisor;
    uint32_t mCounter;
    SMPTETimeType mType;
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

/* channel layouts (CoreAudioBaseTypes.h): a layout is a tag, a bitmap or a list of channel descriptions */
typedef uint32_t AudioChannelLabel;
typedef ISIM_CA_OPTIONS(uint32_t, AudioChannelBitmap) {
    kAudioChannelBit_Left = (1U << 0),
    kAudioChannelBit_Right = (1U << 1),
    kAudioChannelBit_Center = (1U << 2),
    kAudioChannelBit_LFEScreen = (1U << 3),
    kAudioChannelBit_LeftSurround = (1U << 4),
    kAudioChannelBit_RightSurround = (1U << 5),
    kAudioChannelBit_LeftCenter = (1U << 6),
    kAudioChannelBit_RightCenter = (1U << 7),
    kAudioChannelBit_CenterSurround = (1U << 8),
    kAudioChannelBit_LeftSurroundDirect = (1U << 9),
    kAudioChannelBit_RightSurroundDirect = (1U << 10),
    kAudioChannelBit_TopCenterSurround = (1U << 11),
    kAudioChannelBit_VerticalHeightLeft = (1U << 12),
    kAudioChannelBit_VerticalHeightCenter = (1U << 13),
    kAudioChannelBit_VerticalHeightRight = (1U << 14),
    kAudioChannelBit_TopBackLeft = (1U << 15),
    kAudioChannelBit_TopBackCenter = (1U << 16),
    kAudioChannelBit_TopBackRight = (1U << 17)
};
typedef ISIM_CA_OPTIONS(uint32_t, AudioChannelFlags) {
    kAudioChannelFlags_AllOff = 0,
    kAudioChannelFlags_RectangularCoordinates = (1U << 0),
    kAudioChannelFlags_SphericalCoordinates = (1U << 1),
    kAudioChannelFlags_Meters = (1U << 2)
};
struct AudioChannelDescription {
    AudioChannelLabel mChannelLabel;
    AudioChannelFlags mChannelFlags;
    float mCoordinates[3];
};
typedef struct AudioChannelDescription AudioChannelDescription;
struct AudioChannelLayout {
    uint32_t mChannelLayoutTag;               /* AudioChannelLayoutTag */
    AudioChannelBitmap mChannelBitmap;
    uint32_t mNumberChannelDescriptions;
    AudioChannelDescription mChannelDescriptions[1];   /* variable length: mNumberChannelDescriptions entries */
};
typedef struct AudioChannelLayout AudioChannelLayout;

#pragma clang assume_nonnull end
__END_DECLS
