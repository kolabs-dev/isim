#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSLocale, NSTimeZone, NSDate;
typedef NSString *NSCalendarIdentifier NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSCalendar.Identifier);
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierGregorian;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierISO8601;

typedef NS_OPTIONS(NSUInteger, NSCalendarUnit) {
    NSCalendarUnitEra NS_SWIFT_NAME(era) = 1UL << 1, NSCalendarUnitYear NS_SWIFT_NAME(year) = 1UL << 2,
    NSCalendarUnitMonth NS_SWIFT_NAME(month) = 1UL << 3, NSCalendarUnitDay NS_SWIFT_NAME(day) = 1UL << 4,
    NSCalendarUnitHour NS_SWIFT_NAME(hour) = 1UL << 5, NSCalendarUnitMinute NS_SWIFT_NAME(minute) = 1UL << 6,
    NSCalendarUnitSecond NS_SWIFT_NAME(second) = 1UL << 7, NSCalendarUnitWeekday NS_SWIFT_NAME(weekday) = 1UL << 9,
    NSCalendarUnitWeekdayOrdinal NS_SWIFT_NAME(weekdayOrdinal) = 1UL << 10, NSCalendarUnitQuarter NS_SWIFT_NAME(quarter) = 1UL << 11,
    NSCalendarUnitWeekOfMonth NS_SWIFT_NAME(weekOfMonth) = 1UL << 12, NSCalendarUnitWeekOfYear NS_SWIFT_NAME(weekOfYear) = 1UL << 13,
    NSCalendarUnitYearForWeekOfYear NS_SWIFT_NAME(yearForWeekOfYear) = 1UL << 14, NSCalendarUnitNanosecond NS_SWIFT_NAME(nanosecond) = 1UL << 15,
    NSCalendarUnitCalendar NS_SWIFT_NAME(calendar) = 1UL << 20, NSCalendarUnitTimeZone NS_SWIFT_NAME(timeZone) = 1UL << 21
} NS_SWIFT_NAME(NSCalendar.Unit);

/* isim: Swift's Calendar (a value type in the overlay) does the date arithmetic; NSCalendar carries the
 * identifier, time zone, locale and symbols for the Objective-C API and the formatters. */
@interface NSCalendar : NSObject <NSCopying>
@property (class, readonly, copy) NSCalendar *currentCalendar;
@property (class, readonly, strong) NSCalendar *autoupdatingCurrentCalendar;
+ (nullable NSCalendar *)calendarWithIdentifier:(NSCalendarIdentifier)calendarIdentifierConstant;
- (nullable instancetype)initWithCalendarIdentifier:(NSCalendarIdentifier)ident NS_DESIGNATED_INITIALIZER;
@property (readonly, copy) NSCalendarIdentifier calendarIdentifier;
@property (nullable, copy) NSLocale *locale;
@property (copy) NSTimeZone *timeZone;
@property NSUInteger firstWeekday;
@property NSUInteger minimumDaysInFirstWeek;
@property (readonly, copy) NSArray<NSString *> *monthSymbols;
@property (readonly, copy) NSArray<NSString *> *shortMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *weekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *shortWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortWeekdaySymbols;
@property (readonly, copy) NSString *AMSymbol;
@property (readonly, copy) NSString *PMSymbol;
@end

enum { NSDateComponentUndefined = NSIntegerMax };
@interface NSDateComponents : NSObject <NSCopying>
@property (nullable, copy) NSCalendar *calendar;
@property (nullable, copy) NSTimeZone *timeZone;
@property NSInteger era, year, month, day, hour, minute, second, nanosecond, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear, yearForWeekOfYear;
- (NSInteger)valueForComponent:(NSCalendarUnit)unit;
- (void)setValue:(NSInteger)value forComponent:(NSCalendarUnit)unit;
@end
NS_ASSUME_NONNULL_END
