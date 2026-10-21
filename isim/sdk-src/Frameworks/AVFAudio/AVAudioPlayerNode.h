#pragma once
/* isim AVFAudio: AVAudioPlayerNode (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioFile.h>
#import <AVFAudio/AVAudioMixing.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, AVAudioPlayerNodeBufferOptions) {
    AVAudioPlayerNodeBufferLoops = 1UL << 0, AVAudioPlayerNodeBufferInterrupts = 1UL << 1, AVAudioPlayerNodeBufferInterruptsAtLoop = 1UL << 2
};
typedef NS_ENUM(NSInteger, AVAudioPlayerNodeCompletionCallbackType) {
    AVAudioPlayerNodeCompletionDataConsumed = 0, AVAudioPlayerNodeCompletionDataRendered = 1, AVAudioPlayerNodeCompletionDataPlayedBack = 2
};
typedef void (^AVAudioPlayerNodeCompletionHandler)(AVAudioPlayerNodeCompletionCallbackType callbackType);
@interface AVAudioPlayerNode : AVAudioNode <AVAudioMixing>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer completionHandler:(nullable AVAudioNodeCompletionHandler)completionHandler;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer completionCallbackType:(AVAudioPlayerNodeCompletionCallbackType)callbackType
     completionHandler:(nullable AVAudioPlayerNodeCompletionHandler)completionHandler;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer atTime:(nullable AVAudioTime *)when options:(AVAudioPlayerNodeBufferOptions)options
     completionHandler:(nullable AVAudioNodeCompletionHandler)completionHandler;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer atTime:(nullable AVAudioTime *)when options:(AVAudioPlayerNodeBufferOptions)options
completionCallbackType:(AVAudioPlayerNodeCompletionCallbackType)callbackType completionHandler:(nullable AVAudioPlayerNodeCompletionHandler)completionHandler;
- (void)scheduleFile:(AVAudioFile *)file atTime:(nullable AVAudioTime *)when completionHandler:(nullable AVAudioNodeCompletionHandler)completionHandler;
- (void)scheduleFile:(AVAudioFile *)file atTime:(nullable AVAudioTime *)when completionCallbackType:(AVAudioPlayerNodeCompletionCallbackType)callbackType
   completionHandler:(nullable AVAudioPlayerNodeCompletionHandler)completionHandler;
- (void)scheduleSegment:(AVAudioFile *)file startingFrame:(AVAudioFramePosition)startFrame frameCount:(AVAudioFrameCount)numberFrames
                 atTime:(nullable AVAudioTime *)when completionHandler:(nullable AVAudioNodeCompletionHandler)completionHandler;
- (void)scheduleSegment:(AVAudioFile *)file startingFrame:(AVAudioFramePosition)startFrame frameCount:(AVAudioFrameCount)numberFrames
                 atTime:(nullable AVAudioTime *)when completionCallbackType:(AVAudioPlayerNodeCompletionCallbackType)callbackType
      completionHandler:(nullable AVAudioPlayerNodeCompletionHandler)completionHandler;
- (void)stop;
- (void)prepareWithFrameCount:(AVAudioFrameCount)frameCount;
- (void)play;
- (void)playAtTime:(nullable AVAudioTime *)when;
- (void)pause;
- (nullable AVAudioTime *)nodeTimeForPlayerTime:(AVAudioTime *)playerTime;
- (nullable AVAudioTime *)playerTimeForNodeTime:(AVAudioTime *)nodeTime;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@end
NS_ASSUME_NONNULL_END
#endif
