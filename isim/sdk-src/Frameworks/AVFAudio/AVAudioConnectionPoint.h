#pragma once
/* isim AVFAudio: AVAudioConnectionPoint (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class AVAudioNode;
@interface AVAudioConnectionPoint : NSObject
- (instancetype)initWithNode:(AVAudioNode *)node bus:(AVAudioNodeBus)bus NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, weak) AVAudioNode *node;
@property (nonatomic, readonly) AVAudioNodeBus bus;
@end
NS_ASSUME_NONNULL_END
#endif
