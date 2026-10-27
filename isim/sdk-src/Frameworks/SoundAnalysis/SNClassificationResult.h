#pragma once
#import <SoundAnalysis/SNDefines.h>
#import <SoundAnalysis/SNResult.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* a label and the classifier's confidence (0 ... 1) */
API_AVAILABLE(ios(13.0))
@interface SNClassification : NSObject
@property (readonly, copy) NSString *identifier;
@property (readonly, assign) double confidence;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
/* the classifications of one window, the most confident first */
API_AVAILABLE(ios(13.0))
@interface SNClassificationResult : NSObject <SNResult>
@property (readonly, copy) NSArray<SNClassification *> *classifications;
/* the window, in the input's sample rate */
@property (readonly, assign) CMTimeRange timeRange;
- (nullable SNClassification *)classificationForIdentifier:(NSString *)identifier API_AVAILABLE(ios(15.0));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
