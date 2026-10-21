#pragma once
/* isim AVFAudio: the engine's input and output nodes (AVAudioEngine.swift; the input is the host microphone). */
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioMixing.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef const AudioBufferList * _Nullable (^AVAudioIONodeInputBlock)(AVAudioFrameCount inNumberOfFrames);
@interface AVAudioIONode : AVAudioNode
@property (nonatomic, readonly) NSTimeInterval presentationLatency;
@property (nonatomic, readonly, nullable) AudioUnit audioUnit;
@property (nonatomic, readonly, getter=isVoiceProcessingEnabled) BOOL voiceProcessingEnabled;
- (BOOL)setVoiceProcessingEnabled:(BOOL)enabled error:(NSError **)outError;
@end
@interface AVAudioInputNode : AVAudioIONode <AVAudioMixing>
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)setManualRenderingInputPCMFormat:(AVAudioFormat *)format inputBlock:(AVAudioIONodeInputBlock)block;
@property (nonatomic, getter=isVoiceProcessingBypassed) BOOL voiceProcessingBypassed;
@property (nonatomic, getter=isVoiceProcessingAGCEnabled) BOOL voiceProcessingAGCEnabled;
@property (nonatomic, getter=isVoiceProcessingInputMuted) BOOL voiceProcessingInputMuted;
@end
@interface AVAudioOutputNode : AVAudioIONode
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
