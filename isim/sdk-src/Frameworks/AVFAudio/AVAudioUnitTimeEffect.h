#pragma once
/* isim AVFAudio: AVAudioUnitTimeEffect, AVAudioUnitTimePitch and AVAudioUnitVarispeed (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioUnit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnitTimeEffect : AVAudioUnit
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription;
@property (nonatomic) BOOL bypass;
@end
@interface AVAudioUnitTimePitch : AVAudioUnitTimeEffect
- (instancetype)init;
@property (nonatomic) float rate;
@property (nonatomic) float pitch;
@property (nonatomic) float overlap;
@end
@interface AVAudioUnitVarispeed : AVAudioUnitTimeEffect
- (instancetype)init;
@property (nonatomic) float rate;
@end
NS_ASSUME_NONNULL_END
#endif
