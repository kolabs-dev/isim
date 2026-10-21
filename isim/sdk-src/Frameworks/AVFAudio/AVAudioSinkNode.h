#pragma once
/* isim AVFAudio: AVAudioSinkNode (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef OSStatus (^AVAudioSinkNodeReceiverBlock)(const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, const AudioBufferList *inputData);
@interface AVAudioSinkNode : AVAudioNode
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithReceiverBlock:(AVAudioSinkNodeReceiverBlock)block NS_DESIGNATED_INITIALIZER;
@end
NS_ASSUME_NONNULL_END
#endif
