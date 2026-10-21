#pragma once
/* isim AVFAudio: AVAudioSourceNode (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioMixing.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef OSStatus (^AVAudioSourceNodeRenderBlock)(BOOL *isSilence, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount,
                                                 AudioBufferList *outputData);
@interface AVAudioSourceNode : AVAudioNode <AVAudioMixing>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRenderBlock:(AVAudioSourceNodeRenderBlock)block NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFormat:(AVAudioFormat *)format renderBlock:(AVAudioSourceNodeRenderBlock)block NS_DESIGNATED_INITIALIZER;
@end
NS_ASSUME_NONNULL_END
#endif
