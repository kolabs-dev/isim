#pragma once
#import <SoundAnalysis/SNDefines.h>
#import <SoundAnalysis/SNRequest.h>
#import <SoundAnalysis/SNResult.h>
#import <AVFAudio/AVFAudio.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* analyzes audio as the app delivers it; observers are called on the analyzer's own queue */
API_AVAILABLE(ios(13.0))
@interface SNAudioStreamAnalyzer : NSObject
- (instancetype)initWithFormat:(AVAudioFormat *)format NS_DESIGNATED_INITIALIZER;
- (BOOL)addRequest:(id<SNRequest>)request withObserver:(id<SNResultsObserving>)observer error:(NSError **)error;
- (void)removeRequest:(id<SNRequest>)request;
- (void)removeAllRequests;
- (void)analyzeAudioBuffer:(AVAudioBuffer *)audioBuffer atAudioFramePosition:(AVAudioFramePosition)audioFramePosition;
- (void)completeAnalysis;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
/* analyzes an audio file */
API_AVAILABLE(ios(13.0))
@interface SNAudioFileAnalyzer : NSObject
- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (BOOL)addRequest:(id<SNRequest>)request withObserver:(id<SNResultsObserving>)observer error:(NSError **)error;
- (void)removeRequest:(id<SNRequest>)request;
- (void)removeAllRequests;
- (void)analyze;
- (void)analyzeWithCompletionHandler:(void (^)(BOOL didReachEndOfFile))completionHandler;
- (void)cancelAnalysis;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
