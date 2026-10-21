#pragma once
/* isim AVFAudio: AVAudioPlayer (AVFoundation.swift; files decoded by the host's FFmpeg, played by the host mixer). */
#import <AVFAudio/AVAudioFormat.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol AVAudioPlayerDelegate;
@interface AVAudioPlayer : NSObject
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError;
- (nullable instancetype)initWithData:(NSData *)data error:(NSError **)outError;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url fileTypeHint:(nullable NSString *)utiString error:(NSError **)outError;
- (nullable instancetype)initWithData:(NSData *)data fileTypeHint:(nullable NSString *)utiString error:(NSError **)outError;
- (BOOL)prepareToPlay;
- (BOOL)play;
- (BOOL)playAtTime:(NSTimeInterval)time;
- (void)pause;
- (void)stop;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) NSUInteger numberOfChannels;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, weak, nullable) id<AVAudioPlayerDelegate> delegate;
@property (nonatomic, readonly, nullable) NSURL *url;
@property (nonatomic, readonly, nullable) NSData *data;
@property (nonatomic) float pan;
@property (nonatomic) float volume;
- (void)setVolume:(float)volume fadeDuration:(NSTimeInterval)duration;
@property (nonatomic) BOOL enableRate;
@property (nonatomic) float rate;
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, readonly) NSTimeInterval deviceCurrentTime;
@property (nonatomic) NSInteger numberOfLoops;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *settings;
@property (nonatomic, readonly) AVAudioFormat *format;
@property (nonatomic, getter=isMeteringEnabled) BOOL meteringEnabled;
- (void)updateMeters;
- (float)peakPowerForChannel:(NSUInteger)channelNumber;
- (float)averagePowerForChannel:(NSUInteger)channelNumber;
@end
@protocol AVAudioPlayerDelegate <NSObject>
@optional
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
#endif
