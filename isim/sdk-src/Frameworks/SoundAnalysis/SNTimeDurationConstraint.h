#pragma once
#import <SoundAnalysis/SNDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SNTimeDurationConstraintType) {
    SNTimeDurationConstraintTypeEnumerated = 1,
    SNTimeDurationConstraintTypeRange = 2,
} API_AVAILABLE(ios(15.0));
/* the window durations a request accepts: a list of durations, or a range */
API_AVAILABLE(ios(15.0))
@interface SNTimeDurationConstraint : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithEnumeratedDurations:(NSArray<NSValue *> *)enumeratedDurations;
- (instancetype)initWithDurationRange:(CMTimeRange)durationRange;
@property (readonly, assign) SNTimeDurationConstraintType type;
/* CMTime values (NSValue valueWithCMTime:); empty for a range */
@property (readonly, strong) NSArray<NSValue *> *enumeratedDurations;
/* kCMTimeRangeInvalid-like (zero) for enumerated durations */
@property (readonly, assign) CMTimeRange durationRange;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
