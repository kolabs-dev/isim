#pragma once
#import <SoundAnalysis/SNDefines.h>
#import <SoundAnalysis/SNRequest.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(13.0))
@protocol SNResult <NSObject>
@end
API_AVAILABLE(ios(13.0))
@protocol SNResultsObserving <NSObject>
- (void)request:(id<SNRequest>)request didProduceResult:(id<SNResult>)result;
@optional
- (void)request:(id<SNRequest>)request didFailWithError:(NSError *)error;
- (void)requestDidComplete:(id<SNRequest>)request;
@end
NS_ASSUME_NONNULL_END
#endif
