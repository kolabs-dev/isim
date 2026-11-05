#pragma once
/* isim AudioToolbox for C: Audio Codec (Apple's AudioCodec.h): the AAC and MP3 decoders and the AAC encoder (AudioFunctions.swift), over isim's Swift implementation (swift/overlays/AudioToolbox/AudioFunctions.swift). */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
#include <stdio.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
AT_EXPORT OSStatus AudioCodecAppendInputBufferList(AudioCodec inCodec, const AudioBufferList * inBufferList, UInt32* ioNumberPackets, const AudioStreamPacketDescription* _Nullable inPacketDescription, UInt32* outBytesConsumed);
AT_EXPORT OSStatus AudioCodecAppendInputData(AudioCodec inCodec, const void* inInputData, UInt32* ioInputDataByteSize, UInt32* ioNumberPackets, const AudioStreamPacketDescription* _Nullable inPacketDescription);
AT_EXPORT OSStatus AudioCodecGetProperty(AudioCodec inCodec, AudioCodecPropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData);
AT_EXPORT OSStatus AudioCodecGetPropertyInfo(AudioCodec inCodec, AudioCodecPropertyID inPropertyID, UInt32* _Nullable outSize, Boolean* _Nullable outWritable);
AT_EXPORT OSStatus AudioCodecInitialize(AudioCodec inCodec, const AudioStreamBasicDescription* _Nullable inInputFormat, const AudioStreamBasicDescription* _Nullable inOutputFormat, const void* _Nullable inMagicCookie, UInt32 inMagicCookieByteSize);
AT_EXPORT OSStatus AudioCodecProduceOutputBufferList(AudioCodec inCodec, AudioBufferList * ioBufferList, UInt32* ioNumberPackets, AudioStreamPacketDescription* _Nullable outPacketDescription, UInt32* outStatus);
AT_EXPORT OSStatus AudioCodecProduceOutputPackets(AudioCodec inCodec, void* outOutputData, UInt32* ioOutputDataByteSize, UInt32* ioNumberPackets, AudioStreamPacketDescription* _Nullable outPacketDescription, UInt32* outStatus);
AT_EXPORT OSStatus AudioCodecReset(AudioCodec inCodec);
AT_EXPORT OSStatus AudioCodecSetProperty(AudioCodec inCodec, AudioCodecPropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);
AT_EXPORT OSStatus AudioCodecUninitialize(AudioCodec inCodec);
#pragma clang assume_nonnull end
__END_DECLS
#endif
