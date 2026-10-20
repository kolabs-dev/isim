#pragma once
/* isim AudioToolbox for C: Audio Converter Services (Apple's AudioConverter.h): linear PCM sample format, channel and
 * sample rate conversion, over isim's Swift implementation (swift/overlays/AudioToolbox/AudioServices.swift). */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef UInt32 AudioConverterPropertyID;
struct AudioConverterPrimeInfo {
    UInt32 leadingFrames;
    UInt32 trailingFrames;
};
typedef struct AudioConverterPrimeInfo AudioConverterPrimeInfo;
enum {
    kAudioConverterCurrentInputStreamDescription = 'acid',
    kAudioConverterCurrentOutputStreamDescription = 'acod',
    kAudioConverterSampleRateConverterQuality = 'srcq',
    kAudioConverterErr_FormatNotSupported = 'fmt?',
    kAudioConverterErr_OperationNotSupported = 0x6F703F3F,   /* 'op??' */
    kAudioConverterErr_PropertyNotSupported = 'prop',
    kAudioConverterErr_InvalidInputSize = 'insz',
    kAudioConverterErr_InvalidOutputSize = 'otsz',
    kAudioConverterPropertyMaximumOutputPacketSize = 'xops',
    kAudioConverterPropertyMaximumInputPacketSize = 'xips',
    kAudioConverterCompressionMagicCookie = 'kmgc',
    kAudioConverterDecompressionMagicCookie = 'dmgc',
    kAudioConverterEncodeBitRate = 'brat',
    kAudioConverterPrimeInfo = 'prim',
    kAudioConverterCodecQuality = 'cdqu',
    kAudioConverterPropertyMinimumInputBufferSize = 'mibs',
    kAudioConverterPropertyMinimumOutputBufferSize = 'mobs',
};
AT_EXPORT OSStatus AudioConverterNew(const AudioStreamBasicDescription *inSourceFormat, const AudioStreamBasicDescription *inDestinationFormat,
                                     AudioConverterRef _Nullable *_Nonnull outAudioConverter);
AT_EXPORT OSStatus AudioConverterDispose(AudioConverterRef inAudioConverter);
AT_EXPORT OSStatus AudioConverterReset(AudioConverterRef inAudioConverter);
AT_EXPORT OSStatus AudioConverterGetPropertyInfo(AudioConverterRef inAudioConverter, AudioConverterPropertyID inPropertyID,
                                                 UInt32 *_Nullable outSize, Boolean *_Nullable outWritable);
AT_EXPORT OSStatus AudioConverterGetProperty(AudioConverterRef inAudioConverter, AudioConverterPropertyID inPropertyID,
                                             UInt32 *ioPropertyDataSize, void *outPropertyData);
AT_EXPORT OSStatus AudioConverterSetProperty(AudioConverterRef inAudioConverter, AudioConverterPropertyID inPropertyID,
                                             UInt32 inPropertyDataSize, const void *inPropertyData);
AT_EXPORT OSStatus AudioConverterConvertBuffer(AudioConverterRef inAudioConverter, UInt32 inInputDataSize, const void *inInputData,
                                               UInt32 *ioOutputDataSize, void *outOutputData);
AT_EXPORT OSStatus AudioConverterFillComplexBuffer(AudioConverterRef inAudioConverter, AudioConverterComplexInputDataProc inInputDataProc,
                                                   void *_Nullable inInputDataProcUserData, UInt32 *ioOutputDataPacketSize,
                                                   AudioBufferList *outOutputData,
                                                   AudioStreamPacketDescription *_Nullable outPacketDescription);
AT_EXPORT OSStatus AudioConverterConvertComplexBuffer(AudioConverterRef inAudioConverter, UInt32 inNumberPCMFrames,
                                                      const AudioBufferList *inInputData, AudioBufferList *outOutputData);
#pragma clang assume_nonnull end
__END_DECLS
#endif
