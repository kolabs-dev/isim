#pragma once
/* isim AudioToolbox for C: Audio File Stream Services (Apple's AudioFileStream.h): parsing WAV, AIFF, CAF, MP3 and ADTS AAC as bytes arrive
 * (swift/overlays/AudioToolbox/AudioFileStream.swift). */
#include <AudioToolbox/AudioFile.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
enum {
    kAudioFileStreamError_UnsupportedFileType = 0x7479703F,   /* 'typ?' */
    kAudioFileStreamError_UnsupportedDataFormat = 0x666D743F,   /* 'fmt?' */
    kAudioFileStreamError_UnsupportedProperty = 0x7074793F,   /* 'pty?' */
    kAudioFileStreamError_BadPropertySize = 0x2173697A,   /* '!siz' */
    kAudioFileStreamError_NotOptimized = 0x6F70746D,   /* 'optm' */
    kAudioFileStreamError_InvalidPacketOffset = 0x70636B3F,   /* 'pck?' */
    kAudioFileStreamError_InvalidFile = 0x6474613F,   /* 'dta?' */
    kAudioFileStreamError_ValueUnknown = 0x756E6B3F,   /* 'unk?' */
    kAudioFileStreamError_DataUnavailable = 0x6D6F7265,   /* 'more' */
    kAudioFileStreamError_IllegalOperation = 0x6E6F7065,   /* 'nope' */
    kAudioFileStreamError_UnspecifiedError = 0x7768743F,   /* 'wht?' */
    kAudioFileStreamError_DiscontinuityCantRecover = 0x64736321,   /* 'dsc!' */
    kAudioFileStreamProperty_ReadyToProducePackets = 0x72656479,   /* 'redy' */
    kAudioFileStreamProperty_FileFormat = 0x66666D74,   /* 'ffmt' */
    kAudioFileStreamProperty_DataFormat = 0x64666D74,   /* 'dfmt' */
    kAudioFileStreamProperty_FormatList = 0x666C7374,   /* 'flst' */
    kAudioFileStreamProperty_MagicCookieData = 0x6D676963,   /* 'mgic' */
    kAudioFileStreamProperty_AudioDataByteCount = 0x62636E74,   /* 'bcnt' */
    kAudioFileStreamProperty_AudioDataPacketCount = 0x70636E74,   /* 'pcnt' */
    kAudioFileStreamProperty_MaximumPacketSize = 0x70737A65,   /* 'psze' */
    kAudioFileStreamProperty_DataOffset = 0x646F6666,   /* 'doff' */
    kAudioFileStreamProperty_ChannelLayout = 0x636D6170,   /* 'cmap' */
    kAudioFileStreamProperty_PacketToFrame = 0x706B6672,   /* 'pkfr' */
    kAudioFileStreamProperty_FrameToPacket = 0x6672706B,   /* 'frpk' */
    kAudioFileStreamProperty_RestrictsRandomAccess = 0x72726170,   /* 'rrap' */
    kAudioFileStreamProperty_PacketToRollDistance = 0x706B726C,   /* 'pkrl' */
    kAudioFileStreamProperty_PreviousIndependentPacket = 0x70696E64,   /* 'pind' */
    kAudioFileStreamProperty_NextIndependentPacket = 0x6E696E64,   /* 'nind' */
    kAudioFileStreamProperty_PacketToDependencyInfo = 0x706B6470,   /* 'pkdp' */
    kAudioFileStreamProperty_PacketToByte = 0x706B6279,   /* 'pkby' */
    kAudioFileStreamProperty_ByteToPacket = 0x6279706B,   /* 'bypk' */
    kAudioFileStreamProperty_PacketTableInfo = 0x706E666F,   /* 'pnfo' */
    kAudioFileStreamProperty_PacketSizeUpperBound = 0x706B7562,   /* 'pkub' */
    kAudioFileStreamProperty_AverageBytesPerPacket = 0x61627070,   /* 'abpp' */
    kAudioFileStreamProperty_BitRate = 0x62726174,   /* 'brat' */
    kAudioFileStreamProperty_InfoDictionary = 0x696E666F,   /* 'info' */
};
AT_EXPORT OSStatus AudioFileStreamOpen(void * _Nullable inClientData, AudioFileStream_PropertyListenerProc inPropertyListenerProc, AudioFileStream_PacketsProc inPacketsProc, AudioFileTypeID inFileTypeHint, AudioFileStreamID _Nullable *_Nonnull outAudioFileStream);
AT_EXPORT OSStatus AudioFileStreamParseBytes(AudioFileStreamID inAudioFileStream, UInt32 inDataByteSize, const void * _Nullable inData, AudioFileStreamParseFlags inFlags);
AT_EXPORT OSStatus AudioFileStreamSeek(AudioFileStreamID inAudioFileStream, SInt64 inPacketOffset, SInt64 *outDataByteOffset, AudioFileStreamSeekFlags *ioFlags);
AT_EXPORT OSStatus AudioFileStreamGetPropertyInfo(AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 * _Nullable outPropertyDataSize, Boolean * _Nullable outWritable);
AT_EXPORT OSStatus AudioFileStreamGetProperty(AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioPropertyDataSize, void *outPropertyData);
AT_EXPORT OSStatus AudioFileStreamSetProperty(AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 inPropertyDataSize, const void *inPropertyData);
AT_EXPORT OSStatus AudioFileStreamClose(AudioFileStreamID inAudioFileStream);
#pragma clang assume_nonnull end
__END_DECLS
#endif
