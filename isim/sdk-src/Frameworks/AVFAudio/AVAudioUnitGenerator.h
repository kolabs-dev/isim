#pragma once
/* isim AVFAudio: AVAudioUnitGenerator (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioUnit.h>
#import <AVFAudio/AVAudioMixing.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnitGenerator : AVAudioUnit <AVAudioMixing>
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription;
@property (nonatomic) BOOL bypass;
@end
NS_ASSUME_NONNULL_END
#endif
