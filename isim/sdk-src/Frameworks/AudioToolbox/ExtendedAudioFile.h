#pragma once
/* isim AudioToolbox for C: Extended Audio File Services (Apple's ExtendedAudioFile.h): files read and written as linear
 * PCM in the client format, over isim's Swift implementation (swift/overlays/AudioToolbox/AudioServices.swift). */
#include <AudioToolbox/AudioFile.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef UInt32 ExtAudioFilePropertyID;
enum {
    kExtAudioFileProperty_FileDataFormat = 'ffmt',
    kExtAudioFileProperty_ClientDataFormat = 'cfmt',
    kExtAudioFileProperty_FileLengthFrames = '#frm',
    kExtAudioFileProperty_AudioFile = 'afil',
    kExtAudioFileError_InvalidProperty = -66561,
    kExtAudioFileError_InvalidDataFormat = -66566,
    kExtAudioFileError_NonPCMClientFormat = -66563,
    kExtAudioFileError_InvalidSeek = -66568,
};
AT_EXPORT OSStatus ExtAudioFileOpenURL(CFURLRef inURL, ExtAudioFileRef _Nullable *_Nonnull outExtAudioFile);
/* isim: inChannelLayout (an AudioChannelLayout) is not read */
AT_EXPORT OSStatus ExtAudioFileCreateWithURL(CFURLRef inURL, AudioFileTypeID inFileType, const AudioStreamBasicDescription *inStreamDesc,
                                             const void *_Nullable inChannelLayout, UInt32 inFlags,
                                             ExtAudioFileRef _Nullable *_Nonnull outExtAudioFile);
AT_EXPORT OSStatus ExtAudioFileDispose(ExtAudioFileRef inExtAudioFile);
AT_EXPORT OSStatus ExtAudioFileRead(ExtAudioFileRef inExtAudioFile, UInt32 *ioNumberFrames, AudioBufferList *ioData);
AT_EXPORT OSStatus ExtAudioFileWrite(ExtAudioFileRef inExtAudioFile, UInt32 inNumberFrames, const AudioBufferList *ioData);
AT_EXPORT OSStatus ExtAudioFileWriteAsync(ExtAudioFileRef inExtAudioFile, UInt32 inNumberFrames, const AudioBufferList *_Nullable ioData);
AT_EXPORT OSStatus ExtAudioFileSeek(ExtAudioFileRef inExtAudioFile, SInt64 inFrameOffset);
AT_EXPORT OSStatus ExtAudioFileTell(ExtAudioFileRef inExtAudioFile, SInt64 *outFrameOffset);
AT_EXPORT OSStatus ExtAudioFileGetPropertyInfo(ExtAudioFileRef inExtAudioFile, ExtAudioFilePropertyID inPropertyID,
                                               UInt32 *_Nullable outSize, Boolean *_Nullable outWritable);
AT_EXPORT OSStatus ExtAudioFileGetProperty(ExtAudioFileRef inExtAudioFile, ExtAudioFilePropertyID inPropertyID, UInt32 *ioPropertyDataSize,
                                           void *outPropertyData);
AT_EXPORT OSStatus ExtAudioFileSetProperty(ExtAudioFileRef inExtAudioFile, ExtAudioFilePropertyID inPropertyID, UInt32 inPropertyDataSize,
                                           const void *inPropertyData);
#pragma clang assume_nonnull end
__END_DECLS
#endif
