#pragma once
/* isim AVFAudio: AVAudioUnitDelay (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioUnitEffect.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnitDelay : AVAudioUnitEffect
- (instancetype)init;
@property (nonatomic) NSTimeInterval delayTime;
@property (nonatomic) float feedback;
@property (nonatomic) float lowPassCutoff;
@property (nonatomic) float wetDryMix;
@end
NS_ASSUME_NONNULL_END
#endif
