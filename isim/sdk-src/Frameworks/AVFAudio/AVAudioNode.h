#pragma once
/* isim AVFAudio: AVAudioNode, over the overlay's class (AVAudioEngine.swift; adapted: isim's own graph renderer). */
#import <AVFAudio/AVAudioBuffer.h>
#import <AVFAudio/AVAudioTime.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class AVAudioEngine;
typedef void (^AVAudioNodeTapBlock)(AVAudioPCMBuffer *buffer, AVAudioTime *when);
@interface AVAudioNode : NSObject
- (void)reset;
- (AVAudioFormat *)inputFormatForBus:(AVAudioNodeBus)bus;
- (AVAudioFormat *)outputFormatForBus:(AVAudioNodeBus)bus;
- (nullable NSString *)nameForInputBus:(AVAudioNodeBus)bus;
- (nullable NSString *)nameForOutputBus:(AVAudioNodeBus)bus;
- (void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)bufferSize format:(nullable AVAudioFormat *)format block:(AVAudioNodeTapBlock)tapBlock;
- (void)removeTapOnBus:(AVAudioNodeBus)bus;
@property (nonatomic, readonly, nullable) AVAudioEngine *engine;
@property (nonatomic, readonly) NSUInteger numberOfInputs;
@property (nonatomic, readonly) NSUInteger numberOfOutputs;
@property (nonatomic, readonly, nullable) AVAudioTime *lastRenderTime;
@property (nonatomic, readonly) NSTimeInterval latency;
@property (nonatomic, readonly) NSTimeInterval outputPresentationLatency;
@end
NS_ASSUME_NONNULL_END
#endif
