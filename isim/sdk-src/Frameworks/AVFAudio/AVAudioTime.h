#pragma once
/* isim AVFAudio: AVAudioTime, over the overlay's class (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioTime : NSObject
- (instancetype)initWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(double)sampleRate;
- (instancetype)initWithHostTime:(uint64_t)hostTime;
- (instancetype)initWithSampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate;
- (instancetype)initWithHostTime:(uint64_t)hostTime sampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate;
+ (instancetype)timeWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(double)sampleRate;
+ (instancetype)timeWithHostTime:(uint64_t)hostTime;
+ (instancetype)timeWithSampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate;
+ (instancetype)timeWithHostTime:(uint64_t)hostTime sampleTime:(AVAudioFramePosition)sampleTime atRate:(double)sampleRate;
+ (uint64_t)hostTimeForSeconds:(NSTimeInterval)seconds;
+ (NSTimeInterval)secondsForHostTime:(uint64_t)hostTime;
- (nullable AVAudioTime *)extrapolateTimeFromAnchor:(AVAudioTime *)anchorTime;
@property (nonatomic, readonly, getter=isHostTimeValid) BOOL hostTimeValid;
@property (nonatomic, readonly) uint64_t hostTime;
@property (nonatomic, readonly, getter=isSampleTimeValid) BOOL sampleTimeValid;
@property (nonatomic, readonly) AVAudioFramePosition sampleTime;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) AudioTimeStamp audioTimeStamp;
@end
NS_ASSUME_NONNULL_END
#endif
