#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSDate : NSObject <NSCopying, NSSecureCoding>
@property (readonly) NSTimeInterval timeIntervalSinceReferenceDate;
+ (instancetype)date;
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)secs;
+ (instancetype)dateWithTimeIntervalSince1970:(NSTimeInterval)secs;
+ (NSDate *)distantFuture;
+ (NSDate *)distantPast;
- (instancetype)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)ti NS_DESIGNATED_INITIALIZER;
@property (readonly) NSTimeInterval timeIntervalSinceNow;
@property (readonly) NSTimeInterval timeIntervalSince1970;
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)anotherDate;
- (NSDate *)dateByAddingTimeInterval:(NSTimeInterval)ti;
- (NSComparisonResult)compare:(NSDate *)other;
@end
NS_ASSUME_NONNULL_END
