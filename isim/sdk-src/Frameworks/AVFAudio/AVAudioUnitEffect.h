#pragma once
/* isim AVFAudio: AVAudioUnitEffect (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioUnit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnitEffect : AVAudioUnit
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription;
@property (nonatomic) BOOL bypass;
@end
NS_ASSUME_NONNULL_END
#endif
