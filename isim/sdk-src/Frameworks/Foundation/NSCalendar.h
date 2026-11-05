#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
FOUNDATION_EXPORT NSNotificationName const NSCalendarDayChangedNotification;
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSLocale, NSTimeZone, NSDate;
typedef NSString *NSCalendarIdentifier NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSCalendar.Identifier);
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierGregorian;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierISO8601;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierBuddhist;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierChinese;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierCoptic;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierEthiopicAmeteMihret;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierEthiopicAmeteAlem;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierHebrew;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierIndian;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierIslamic;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierIslamicCivil;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierIslamicTabular;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierIslamicUmmAlQura;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierJapanese;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierPersian;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierRepublicOfChina;
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierBangla API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierDangi API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierGujarati API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierKannada API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierMalayalam API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierMarathi API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierOdia API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierTamil API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierTelugu API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierVietnamese API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT NSCalendarIdentifier const NSCalendarIdentifierVikram API_AVAILABLE(ios(26.0));

typedef NS_OPTIONS(NSUInteger, NSCalendarUnit) {
    NSCalendarUnitEra NS_SWIFT_NAME(era) = 1UL << 1, NSCalendarUnitYear NS_SWIFT_NAME(year) = 1UL << 2,
    NSCalendarUnitMonth NS_SWIFT_NAME(month) = 1UL << 3, NSCalendarUnitDay NS_SWIFT_NAME(day) = 1UL << 4,
    NSCalendarUnitHour NS_SWIFT_NAME(hour) = 1UL << 5, NSCalendarUnitMinute NS_SWIFT_NAME(minute) = 1UL << 6,
    NSCalendarUnitSecond NS_SWIFT_NAME(second) = 1UL << 7, NSCalendarUnitWeekday NS_SWIFT_NAME(weekday) = 1UL << 9,
    NSCalendarUnitWeekdayOrdinal NS_SWIFT_NAME(weekdayOrdinal) = 1UL << 10, NSCalendarUnitQuarter NS_SWIFT_NAME(quarter) = 1UL << 11,
    NSCalendarUnitWeekOfMonth NS_SWIFT_NAME(weekOfMonth) = 1UL << 12, NSCalendarUnitWeekOfYear NS_SWIFT_NAME(weekOfYear) = 1UL << 13,
    NSCalendarUnitYearForWeekOfYear NS_SWIFT_NAME(yearForWeekOfYear) = 1UL << 14, NSCalendarUnitNanosecond NS_SWIFT_NAME(nanosecond) = 1UL << 15,
    NSCalendarUnitCalendar NS_SWIFT_NAME(calendar) = 1UL << 20, NSCalendarUnitTimeZone NS_SWIFT_NAME(timeZone) = 1UL << 21,
    NSCalendarUnitDayOfYear NS_SWIFT_NAME(dayOfYear) API_AVAILABLE(ios(18.0)) = 1UL << 16,
    NSCalendarUnitIsLeapMonth NS_SWIFT_NAME(isLeapMonth) API_AVAILABLE(ios(26.0)) = 1UL << 30,
    NSCalendarUnitIsRepeatedDay NS_SWIFT_NAME(isRepeatedDay) API_AVAILABLE(ios(26.0)) = 1UL << 31
} NS_SWIFT_NAME(NSCalendar.Unit);

typedef NS_OPTIONS(NSUInteger, NSCalendarOptions) {
    NSCalendarWrapComponents = 1UL << 0,
    NSCalendarMatchStrictly = 1UL << 1,
    NSCalendarSearchBackwards = 1UL << 2,
    NSCalendarMatchPreviousTimePreservingSmallerUnits = 1UL << 8,
    NSCalendarMatchNextTimePreservingSmallerUnits = 1UL << 9,
    NSCalendarMatchNextTime = 1UL << 10,
    NSCalendarMatchFirst = 1UL << 12,
    NSCalendarMatchLast = 1UL << 13
} NS_SWIFT_NAME(NSCalendar.Options);
@class NSDateComponents;

/* isim: Swift's Calendar (a value type in the overlay) does the date arithmetic; NSCalendar carries the
 * identifier, time zone, locale and symbols for the Objective-C API and the formatters. */
@interface NSCalendar : NSObject <NSCopying, NSSecureCoding>
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
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
@property (readonly, copy) NSArray<NSString *> *eraSymbols;
@property (readonly, copy) NSArray<NSString *> *longEraSymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *standaloneMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *shortStandaloneMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortStandaloneMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *standaloneWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *shortStandaloneWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortStandaloneWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *quarterSymbols;
@property (readonly, copy) NSArray<NSString *> *shortQuarterSymbols;
@property (readonly, copy) NSArray<NSString *> *standaloneQuarterSymbols;
@property (readonly, copy) NSArray<NSString *> *shortStandaloneQuarterSymbols;

@end

/* isim: the arithmetic is the Gregorian calendar's in the calendar's time zone (adapted; Swift's Calendar uses ICU for the others) */
@interface NSCalendar (NSCalendarCalculations)
- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate *)date;
- (BOOL)isDate:(NSDate *)date1 inSameDayAsDate:(NSDate *)date2;
- (BOOL)isDateInToday:(NSDate *)date;
- (NSRange)rangeOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date;
- (nullable NSDate *)dateFromComponents:(NSDateComponents *)comps;
- (NSDateComponents *)components:(NSCalendarUnit)unitFlags fromDate:(NSDate *)date;
- (nullable NSDate *)dateByAddingComponents:(NSDateComponents *)comps toDate:(NSDate *)date options:(NSCalendarOptions)opts;
- (NSDateComponents *)components:(NSCalendarUnit)unitFlags fromDate:(NSDate *)startingDate toDate:(NSDate *)resultDate options:(NSCalendarOptions)opts;
- (NSDate *)startOfDayForDate:(NSDate *)date;
- (nullable NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSCalendarOptions)options;
@end
@interface NSCalendar (NSCalendarCalculationsMore)
- (NSRange)minimumRangeOfUnit:(NSCalendarUnit)unit;
- (NSRange)maximumRangeOfUnit:(NSCalendarUnit)unit;
- (NSUInteger)ordinalityOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date;
- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate * _Nullable * _Nullable)datep interval:(nullable NSTimeInterval *)tip forDate:(NSDate *)date;
- (void)getEra:(nullable NSInteger *)eraValuePointer year:(nullable NSInteger *)yearValuePointer month:(nullable NSInteger *)monthValuePointer day:(nullable NSInteger *)dayValuePointer fromDate:(NSDate *)date;
- (void)getEra:(nullable NSInteger *)eraValuePointer yearForWeekOfYear:(nullable NSInteger *)yearValuePointer weekOfYear:(nullable NSInteger *)weekValuePointer weekday:(nullable NSInteger *)weekdayValuePointer fromDate:(NSDate *)date;
- (void)getHour:(nullable NSInteger *)hourValuePointer minute:(nullable NSInteger *)minuteValuePointer second:(nullable NSInteger *)secondValuePointer nanosecond:(nullable NSInteger *)nanosecondValuePointer fromDate:(NSDate *)date;
- (nullable NSDate *)dateWithEra:(NSInteger)eraValue year:(NSInteger)yearValue month:(NSInteger)monthValue day:(NSInteger)dayValue hour:(NSInteger)hourValue minute:(NSInteger)minuteValue second:(NSInteger)secondValue nanosecond:(NSInteger)nanosecondValue;
- (nullable NSDate *)dateWithEra:(NSInteger)eraValue yearForWeekOfYear:(NSInteger)yearValue weekOfYear:(NSInteger)weekValue weekday:(NSInteger)weekdayValue hour:(NSInteger)hourValue minute:(NSInteger)minuteValue second:(NSInteger)secondValue nanosecond:(NSInteger)nanosecondValue;
- (NSDateComponents *)componentsInTimeZone:(NSTimeZone *)timezone fromDate:(NSDate *)date;
- (NSComparisonResult)compareDate:(NSDate *)date1 toDate:(NSDate *)date2 toUnitGranularity:(NSCalendarUnit)unit;
- (BOOL)isDate:(NSDate *)date1 equalToDate:(NSDate *)date2 toUnitGranularity:(NSCalendarUnit)unit;
- (BOOL)isDateInYesterday:(NSDate *)date;
- (BOOL)isDateInTomorrow:(NSDate *)date;
- (BOOL)isDateInWeekend:(NSDate *)date;
- (BOOL)rangeOfWeekendStartDate:(NSDate * _Nullable * _Nullable)datep interval:(nullable NSTimeInterval *)tip containingDate:(NSDate *)date;
- (BOOL)nextWeekendStartDate:(NSDate * _Nullable * _Nullable)datep interval:(nullable NSTimeInterval *)tip options:(NSCalendarOptions)options afterDate:(NSDate *)date;
- (NSDateComponents *)components:(NSCalendarUnit)unitFlags fromDateComponents:(NSDateComponents *)startingDateComp toDateComponents:(NSDateComponents *)resultDateComp options:(NSCalendarOptions)options;
- (void)enumerateDatesStartingAfterDate:(NSDate *)start matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSDate * _Nullable date, BOOL exactMatch, BOOL *stop))block;
- (nullable NSDate *)nextDateAfterDate:(NSDate *)date matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)options;
- (nullable NSDate *)nextDateAfterDate:(NSDate *)date matchingUnit:(NSCalendarUnit)unit value:(NSInteger)value options:(NSCalendarOptions)options;
- (nullable NSDate *)nextDateAfterDate:(NSDate *)date matchingHour:(NSInteger)hourValue minute:(NSInteger)minuteValue second:(NSInteger)secondValue options:(NSCalendarOptions)options;
- (nullable NSDate *)dateBySettingUnit:(NSCalendarUnit)unit value:(NSInteger)v ofDate:(NSDate *)date options:(NSCalendarOptions)opts;
- (nullable NSDate *)dateBySettingHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s ofDate:(NSDate *)date options:(NSCalendarOptions)opts;
- (BOOL)date:(NSDate *)date matchesComponents:(NSDateComponents *)components;
@end

/* a span of time: a start date and a duration (Swift: DateInterval) */
@interface NSDateInterval : NSObject <NSCopying, NSSecureCoding>
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly) NSTimeInterval duration;
- (instancetype)init;
- (instancetype)initWithStartDate:(NSDate *)startDate duration:(NSTimeInterval)duration NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (NSComparisonResult)compare:(NSDateInterval *)dateInterval;
- (BOOL)isEqualToDateInterval:(NSDateInterval *)dateInterval;
- (BOOL)intersectsDateInterval:(NSDateInterval *)dateInterval;
- (nullable NSDateInterval *)intersectionWithDateInterval:(NSDateInterval *)dateInterval;
- (BOOL)containsDate:(NSDate *)date;
@end

enum { NSDateComponentUndefined = NSIntegerMax };
@interface NSDateComponents : NSObject <NSCopying, NSSecureCoding>
@property (nullable, copy) NSCalendar *calendar;
@property (nullable, copy) NSTimeZone *timeZone;
@property NSInteger era, year, month, day, hour, minute, second, nanosecond, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear, yearForWeekOfYear;
@property NSInteger dayOfYear API_AVAILABLE(ios(18.0));
@property (getter=isLeapMonth) BOOL leapMonth;
@property (getter=isRepeatedDay) BOOL repeatedDay API_AVAILABLE(ios(26.0));
/* the date of these components in their calendar (nil without a calendar) */
@property (nullable, readonly, copy) NSDate *date;
@property (readonly, getter=isValidDate) BOOL validDate;
- (BOOL)isValidDateInCalendar:(NSCalendar *)calendar;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
- (NSInteger)valueForComponent:(NSCalendarUnit)unit;
- (void)setValue:(NSInteger)value forComponent:(NSCalendarUnit)unit;
@end
NS_ASSUME_NONNULL_END
