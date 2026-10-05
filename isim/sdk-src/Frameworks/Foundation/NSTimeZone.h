#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDate, NSArray<ObjectType>;
@interface NSTimeZone : NSObject <NSCopying, NSSecureCoding>
@property (class, readonly, copy) NSTimeZone *systemTimeZone;
@property (class, readonly, copy) NSTimeZone *localTimeZone;
@property (class, copy) NSTimeZone *defaultTimeZone;
@property (class, readonly, copy) NSArray<NSString *> *knownTimeZoneNames;
+ (nullable instancetype)timeZoneWithName:(NSString *)tzName;
+ (nullable instancetype)timeZoneWithAbbreviation:(NSString *)abbreviation;
+ (instancetype)timeZoneForSecondsFromGMT:(NSInteger)seconds;
- (nullable instancetype)initWithName:(NSString *)tzName;
@property (readonly, copy) NSString *name;
@property (nullable, readonly, copy) NSString *abbreviation;
@property (readonly) NSInteger secondsFromGMT;
- (NSInteger)secondsFromGMTForDate:(NSDate *)aDate;
- (nullable NSString *)abbreviationForDate:(NSDate *)aDate;
- (BOOL)isDaylightSavingTimeForDate:(NSDate *)aDate;
@end
NS_ASSUME_NONNULL_END
