#pragma once
/* isim CoreAudio for C: the Core Audio types (AudioStreamBasicDescription, AudioBufferList, AudioTimeStamp, …, from
 * <CoreAudioTypes/CoreAudioTypes.h>) plus the format IDs and linear PCM flags. The same values as Apple's
 * CoreAudioBaseTypes.h. Swift gets them from the CoreAudio module, which re-exports AudioToolbox. */
#include <CoreAudioTypes/CoreAudioTypes.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef int32_t OSStatus;
typedef uint32_t AudioFormatID;
typedef uint32_t AudioFormatFlags;
typedef uint32_t AudioChannelLayoutTag;
enum {
    kAudioFormatLinearPCM = 'lpcm',
    kAudioFormatMPEG4AAC = 'aac ',
    kAudioFormatAppleLossless = 'alac',
    kAudioFormatMPEGLayer3 = '.mp3',
    kAudioFormatFLAC = 'flac',
    kAudioFormatOpus = 'opus',
    kAudioFormatAppleIMA4 = 'ima4',
    kAudioFormatULaw = 'ulaw',
    kAudioFormatALaw = 'alaw',
};
enum {
    kAudioFormatFlagIsFloat = (1U << 0),
    kAudioFormatFlagIsBigEndian = (1U << 1),
    kAudioFormatFlagIsSignedInteger = (1U << 2),
    kAudioFormatFlagIsPacked = (1U << 3),
    kAudioFormatFlagIsAlignedHigh = (1U << 4),
    kAudioFormatFlagIsNonInterleaved = (1U << 5),
    kAudioFormatFlagIsNonMixable = (1U << 6),
    kAudioFormatFlagsAreAllClear = 0x80000000,
    kLinearPCMFormatFlagIsFloat = kAudioFormatFlagIsFloat,
    kLinearPCMFormatFlagIsBigEndian = kAudioFormatFlagIsBigEndian,
    kLinearPCMFormatFlagIsSignedInteger = kAudioFormatFlagIsSignedInteger,
    kLinearPCMFormatFlagIsPacked = kAudioFormatFlagIsPacked,
    kLinearPCMFormatFlagIsAlignedHigh = kAudioFormatFlagIsAlignedHigh,
    kLinearPCMFormatFlagIsNonInterleaved = kAudioFormatFlagIsNonInterleaved,
    kLinearPCMFormatFlagIsNonMixable = kAudioFormatFlagIsNonMixable,
    kAudioFormatFlagsNativeEndian = 0,
    kAudioFormatFlagsNativeFloatPacked = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
};
__END_DECLS
#endif
