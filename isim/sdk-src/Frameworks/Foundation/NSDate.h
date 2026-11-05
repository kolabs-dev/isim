#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
FOUNDATION_EXPORT NSNotificationName const NSSystemClockDidChangeNotification;
NS_ASSUME_NONNULL_BEGIN
@interface NSDate : NSObject <NSCopying, NSSecureCoding>
@property (readonly) NSTimeInterval timeIntervalSinceReferenceDate;
/* isim: current time without allocating an NSDate (used by the Swift overlay) */
+ (NSTimeInterval)timeIntervalSinceReferenceDate_isim;
+ (instancetype)date;
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)secs;
+ (instancetype)dateWithTimeIntervalSince1970:(NSTimeInterval)secs;
+ (instancetype)dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)ti;
+ (NSDate *)distantFuture;
+ (NSDate *)distantPast;
- (instancetype)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)ti NS_DESIGNATED_INITIALIZER;
@property (readonly) NSTimeInterval timeIntervalSinceNow;
@property (readonly) NSTimeInterval timeIntervalSince1970;
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)anotherDate;
- (NSDate *)dateByAddingTimeInterval:(NSTimeInterval)ti;
- (NSComparisonResult)compare:(NSDate *)other;
- (BOOL)isEqualToDate:(NSDate *)otherDate;
- (NSDate *)earlierDate:(NSDate *)anotherDate;
- (NSDate *)laterDate:(NSDate *)anotherDate;
@end
@interface NSDate (NSDateCreation)
@property (class, readonly, copy) NSDate *now API_AVAILABLE(ios(15.0));
- (instancetype)initWithTimeInterval:(NSTimeInterval)secsToBeAdded sinceDate:(NSDate *)date;
+ (instancetype)dateWithTimeInterval:(NSTimeInterval)secsToBeAdded sinceDate:(NSDate *)date;
- (instancetype)initWithTimeIntervalSinceNow:(NSTimeInterval)secs;
- (instancetype)initWithTimeIntervalSince1970:(NSTimeInterval)secs;
- (NSString *)descriptionWithLocale:(nullable id)locale;
@end
NS_ASSUME_NONNULL_END
