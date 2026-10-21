#pragma once
/* isim AVFAudio: AVAudioMixerNode (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioMixing.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioMixerNode : AVAudioNode <AVAudioMixing>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@property (nonatomic) float outputVolume;
@property (nonatomic, readonly) AVAudioNodeBus nextAvailableInputBus;
@end
NS_ASSUME_NONNULL_END
#endif
