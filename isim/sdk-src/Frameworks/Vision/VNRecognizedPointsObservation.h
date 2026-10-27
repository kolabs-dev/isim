#pragma once
#import <Vision/VNObservation.h>
#import <Vision/VNGeometry.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MLMultiArray;
typedef NSString *VNRecognizedPointKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *VNRecognizedPointGroupKey NS_TYPED_EXTENSIBLE_ENUM;
VN_EXPORT VNRecognizedPointGroupKey const VNRecognizedPointGroupKeyAll API_AVAILABLE(ios(14.0));
typedef NS_ENUM(NSInteger, VNChirality) { VNChiralityUnknown = 0, VNChiralityLeft = -1, VNChiralityRight = 1 } API_AVAILABLE(ios(15.0));
API_AVAILABLE(ios(14.0))
@interface VNRecognizedPoint : VNDetectedPoint
@property (readonly, nonatomic, copy) VNRecognizedPointKey identifier;
@end
/* isim: the points come from a host model (see VNDetectHumanBodyPoseRequest.h) */
API_AVAILABLE(ios(14.0))
@interface VNRecognizedPointsObservation : VNObservation
@property (readonly, nonatomic, copy) NSArray<VNRecognizedPointKey> *availableKeys;
@property (readonly, nonatomic, copy) NSArray<VNRecognizedPointGroupKey> *availableGroupKeys;
- (nullable VNRecognizedPoint *)recognizedPointForKey:(VNRecognizedPointKey)pointKey error:(NSError **)error;
- (nullable NSDictionary<VNRecognizedPointKey, VNRecognizedPoint *> *)recognizedPointsForGroupKey:(VNRecognizedPointGroupKey)groupKey error:(NSError **)error;
- (nullable MLMultiArray *)keypointsMultiArrayAndReturnError:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
#endif
