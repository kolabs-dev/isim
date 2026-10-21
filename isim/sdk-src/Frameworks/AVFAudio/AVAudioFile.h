#pragma once
/* isim AVFAudio: AVAudioFile, over the overlay's class (AVFoundation.swift; files decoded by the host's FFmpeg). */
#import <AVFAudio/AVAudioBuffer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioFile : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initForReading:(NSURL *)fileURL error:(NSError **)outError;
- (nullable instancetype)initForReading:(NSURL *)fileURL commonFormat:(AVAudioCommonFormat)format interleaved:(BOOL)interleaved
                                  error:(NSError **)outError;
- (nullable instancetype)initForWriting:(NSURL *)fileURL settings:(NSDictionary<NSString *, id> *)settings error:(NSError **)outError;
- (nullable instancetype)initForWriting:(NSURL *)fileURL settings:(NSDictionary<NSString *, id> *)settings commonFormat:(AVAudioCommonFormat)format
                            interleaved:(BOOL)interleaved error:(NSError **)outError;
- (void)close;
- (BOOL)readIntoBuffer:(AVAudioPCMBuffer *)buffer error:(NSError **)outError;
- (BOOL)readIntoBuffer:(AVAudioPCMBuffer *)buffer frameCount:(AVAudioFrameCount)frames error:(NSError **)outError;
- (BOOL)writeFromBuffer:(const AVAudioPCMBuffer *)buffer error:(NSError **)outError;
@property (nonatomic, readonly) BOOL isOpen;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) AVAudioFormat *fileFormat;
@property (nonatomic, readonly) AVAudioFormat *processingFormat;
@property (nonatomic, readonly) AVAudioFramePosition length;
@property (nonatomic) AVAudioFramePosition framePosition;
@end
NS_ASSUME_NONNULL_END
#endif
