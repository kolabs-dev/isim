#pragma once
/* isim AVFAudio: AVAudioRecorder (AVAudioExtras.swift; records the host microphone). */
#import <AVFAudio/AVAudioFormat.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol AVAudioRecorderDelegate;
@interface AVAudioRecorder : NSObject
- (nullable instancetype)initWithURL:(NSURL *)url settings:(NSDictionary<NSString *, id> *)settings error:(NSError **)outError;
- (nullable instancetype)initWithURL:(NSURL *)url format:(AVAudioFormat *)format error:(NSError **)outError;
- (BOOL)prepareToRecord;
- (BOOL)record;
- (BOOL)recordAtTime:(NSTimeInterval)time;
- (BOOL)recordForDuration:(NSTimeInterval)duration;
- (BOOL)recordAtTime:(NSTimeInterval)time forDuration:(NSTimeInterval)duration;
- (void)pause;
- (void)stop;
- (BOOL)deleteRecording;
@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *settings;
@property (nonatomic, readonly) AVAudioFormat *format;
@property (nonatomic, weak, nullable) id<AVAudioRecorderDelegate> delegate;
@property (nonatomic, readonly) NSTimeInterval currentTime;
@property (nonatomic, readonly) NSTimeInterval deviceCurrentTime;
@property (nonatomic, getter=isMeteringEnabled) BOOL meteringEnabled;
- (void)updateMeters;
- (float)peakPowerForChannel:(NSUInteger)channelNumber;
- (float)averagePowerForChannel:(NSUInteger)channelNumber;
@end
@protocol AVAudioRecorderDelegate <NSObject>
@optional
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag;
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
#endif
