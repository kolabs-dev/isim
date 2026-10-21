#pragma once
/* isim AVFAudio: AVAudioFormat, over the overlay's class (AVFoundation.swift). */
#import <AVFAudio/AVAudioChannelLayout.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, AVAudioCommonFormat) {
    AVAudioOtherFormat = 0, AVAudioPCMFormatFloat32 = 1, AVAudioPCMFormatFloat64 = 2, AVAudioPCMFormatInt16 = 3, AVAudioPCMFormatInt32 = 4
};
@interface AVAudioFormat : NSObject
- (nullable instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd;
- (nullable instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd channelLayout:(nullable AVAudioChannelLayout *)layout;
- (nullable instancetype)initStandardFormatWithSampleRate:(double)sampleRate channels:(AVAudioChannelCount)channels;
- (instancetype)initStandardFormatWithSampleRate:(double)sampleRate channelLayout:(AVAudioChannelLayout *)layout;
- (nullable instancetype)initWithCommonFormat:(AVAudioCommonFormat)format sampleRate:(double)sampleRate channels:(AVAudioChannelCount)channels
                                  interleaved:(BOOL)interleaved;
- (instancetype)initWithCommonFormat:(AVAudioCommonFormat)format sampleRate:(double)sampleRate interleaved:(BOOL)interleaved
                       channelLayout:(AVAudioChannelLayout *)layout;
- (nullable instancetype)initWithSettings:(NSDictionary<NSString *, id> *)settings;
@property (nonatomic, readonly, getter=isStandard) BOOL standard;
@property (nonatomic, readonly) AVAudioCommonFormat commonFormat;
@property (nonatomic, readonly) AVAudioChannelCount channelCount;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly, getter=isInterleaved) BOOL interleaved;
@property (nonatomic, readonly) const AudioStreamBasicDescription *streamDescription;
@property (nonatomic, readonly, nullable) AVAudioChannelLayout *channelLayout;
@property (nonatomic, retain, nullable) NSData *magicCookie;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *settings;
@end
NS_ASSUME_NONNULL_END
#endif
