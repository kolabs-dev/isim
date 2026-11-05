#pragma once
/* isim AudioToolbox for C: Audio File Services (Apple's AudioFile.h), over isim's Swift implementation
 * (swift/overlays/AudioToolbox/AudioServices.swift; files are read and written through the host's decoders). */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef UInt32 AudioFileTypeID;
typedef UInt32 AudioFilePropertyID;
typedef CF_ENUM(SInt8, AudioFilePermissions) {
    kAudioFileReadPermission = 0x01,
    kAudioFileWritePermission = 0x02,
    kAudioFileReadWritePermission = 0x03,
};
typedef CF_OPTIONS(UInt32, AudioFileFlags) {
    kAudioFileFlags_EraseFile = 1,
    kAudioFileFlags_DontPageAlignAudioData = 2,
};
enum {
    kAudioFileWAVEType = 'WAVE',
    kAudioFileAIFFType = 'AIFF',
    kAudioFileAIFCType = 'AIFC',
    kAudioFileCAFType = 'caff',
    kAudioFileM4AType = 'm4af',
    kAudioFileMPEG4Type = 'mp4f',
    kAudioFileMP3Type = 'MPG3',
    kAudioFileAAC_ADTSType = 'adts',
    kAudioFileFLACType = 'flac',
    kAudioFilePropertyFileFormat = 'ffmt',
    kAudioFilePropertyDataFormat = 'dfmt',
    kAudioFilePropertyAudioDataByteCount = 'bcnt',
    kAudioFilePropertyAudioDataPacketCount = 'pcnt',
    kAudioFilePropertyMaximumPacketSize = 'psze',
    kAudioFilePropertyPacketSizeUpperBound = 'pkub',
    kAudioFilePropertyEstimatedDuration = 'edur',
    kAudioFilePropertyIsOptimized = 'opti',
    kAudioFilePropertyMagicCookieData = 'mgic',
    kAudio_UnimplementedError = -4,
    kAudio_FileNotFoundError = -43,
    kAudio_ParamError = -50,
    kAudio_MemFullError = -108,
    kAudioFileUnspecifiedError = 'wht?',
    kAudioFileUnsupportedFileTypeError = 'typ?',
    kAudioFileUnsupportedDataFormatError = 'fmt?',
    kAudioFileUnsupportedPropertyError = 'pty?',
    kAudioFileBadPropertySizeError = '!siz',
    kAudioFilePermissionsError = 'prm?',
    kAudioFileNotOptimizedError = 'opti',
    kAudioFileInvalidFileError = 'dta?',
    kAudioFileEndOfFileError = -39,
    kAudioFileInvalidPacketOffsetError = -40,
    kAudioFileOperationNotSupportedError = 0x6F703F3F,   /* 'op??' */
    kAudioFileNotOpenError = -38,
};
AT_EXPORT OSStatus AudioFileOpenURL(CFURLRef inFileRef, AudioFilePermissions inPermissions, AudioFileTypeID inFileTypeHint,
                                    AudioFileID _Nullable *_Nonnull outAudioFile);
AT_EXPORT OSStatus AudioFileCreateWithURL(CFURLRef inFileRef, AudioFileTypeID inFileType, const AudioStreamBasicDescription *inFormat,
                                          AudioFileFlags inFlags, AudioFileID _Nullable *_Nonnull outAudioFile);
AT_EXPORT OSStatus AudioFileClose(AudioFileID inAudioFile);
AT_EXPORT OSStatus AudioFileOptimize(AudioFileID inAudioFile);
AT_EXPORT OSStatus AudioFileReadBytes(AudioFileID inAudioFile, Boolean inUseCache, SInt64 inStartingByte, UInt32 *ioNumBytes, void *outBuffer);
AT_EXPORT OSStatus AudioFileWriteBytes(AudioFileID inAudioFile, Boolean inUseCache, SInt64 inStartingByte, UInt32 *ioNumBytes, const void *inBuffer);
AT_EXPORT OSStatus AudioFileReadPacketData(AudioFileID inAudioFile, Boolean inUseCache, UInt32 *ioNumBytes,
                                           AudioStreamPacketDescription *_Nullable outPacketDescriptions, SInt64 inStartingPacket,
                                           UInt32 *ioNumPackets, void *_Nullable outBuffer);
AT_EXPORT OSStatus AudioFileReadPackets(AudioFileID inAudioFile, Boolean inUseCache, UInt32 *outNumBytes,
                                        AudioStreamPacketDescription *_Nullable outPacketDescriptions, SInt64 inStartingPacket,
                                        UInt32 *ioNumPackets, void *_Nullable outBuffer);
AT_EXPORT OSStatus AudioFileWritePackets(AudioFileID inAudioFile, Boolean inUseCache, UInt32 inNumBytes,
                                         const AudioStreamPacketDescription *_Nullable inPacketDescriptions, SInt64 inStartingPacket,
                                         UInt32 *ioNumPackets, const void *inBuffer);
AT_EXPORT OSStatus AudioFileGetPropertyInfo(AudioFileID inAudioFile, AudioFilePropertyID inPropertyID, UInt32 *_Nullable outDataSize,
                                            UInt32 *_Nullable isWritable);
AT_EXPORT OSStatus AudioFileGetProperty(AudioFileID inAudioFile, AudioFilePropertyID inPropertyID, UInt32 *ioDataSize, void *outPropertyData);
AT_EXPORT OSStatus AudioFileSetProperty(AudioFileID inAudioFile, AudioFilePropertyID inPropertyID, UInt32 inDataSize, const void *inPropertyData);
/* issue #856 (AudioFunctions.swift) */
AT_EXPORT OSStatus AudioFileCountUserData (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 *outNumberItems);
AT_EXPORT OSStatus AudioFileGetGlobalInfo(AudioFilePropertyID inPropertyID, UInt32 inSpecifierSize, void * _Nullable inSpecifier, UInt32 *ioDataSize, void *outPropertyData);
AT_EXPORT OSStatus AudioFileGetGlobalInfoSize(AudioFilePropertyID inPropertyID, UInt32 inSpecifierSize, void * _Nullable inSpecifier, UInt32 *outDataSize);
AT_EXPORT OSStatus AudioFileGetUserData (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt32 *ioUserDataSize, void *outUserData);
AT_EXPORT OSStatus AudioFileGetUserDataAtOffset (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, SInt64 inOffset, UInt32 *ioUserDataSize, void *outUserData);
AT_EXPORT OSStatus AudioFileGetUserDataSize (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt32 *outUserDataSize);
AT_EXPORT OSStatus AudioFileGetUserDataSize64 (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt64 *outUserDataSize);
AT_EXPORT OSStatus AudioFileInitializeWithCallbacks (void * inClientData, AudioFile_ReadProc inReadFunc, AudioFile_WriteProc inWriteFunc, AudioFile_GetSizeProc inGetSizeFunc, AudioFile_SetSizeProc inSetSizeFunc, AudioFileTypeID inFileType, const AudioStreamBasicDescription *inFormat, AudioFileFlags inFlags, AudioFileID _Nullable * _Nonnull outAudioFile);
AT_EXPORT OSStatus AudioFileOpenWithCallbacks (void * inClientData, AudioFile_ReadProc inReadFunc, AudioFile_WriteProc _Nullable inWriteFunc, AudioFile_GetSizeProc inGetSizeFunc, AudioFile_SetSizeProc _Nullable inSetSizeFunc, AudioFileTypeID inFileTypeHint, AudioFileID _Nullable * _Nonnull outAudioFile);
AT_EXPORT OSStatus AudioFileRemoveUserData (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex);
AT_EXPORT OSStatus AudioFileSetUserData (AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt32 inUserDataSize, const void *inUserData);
AT_EXPORT OSStatus AudioFileWritePacketsWithDependencies (AudioFileID inAudioFile, Boolean inUseCache, UInt32 inNumBytes, const AudioStreamPacketDescription * _Nullable inPacketDescriptions, const AudioStreamPacketDependencyDescription * inPacketDependencies, SInt64 inStartingPacket, UInt32 * ioNumPackets, const void * inBuffer);
#pragma clang assume_nonnull end
__END_DECLS
#endif
