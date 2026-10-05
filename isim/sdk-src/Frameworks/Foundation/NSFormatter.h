#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDate, NSNumber, NSLocale, NSTimeZone;
@interface NSFormatter : NSObject <NSCopying, NSCoding>
- (nullable NSString *)stringForObjectValue:(nullable id)obj;
@end

typedef NS_ENUM(NSUInteger, NSDateFormatterStyle) NS_SWIFT_NAME(DateFormatter.Style) {
    NSDateFormatterNoStyle NS_SWIFT_NAME(none) = 0, NSDateFormatterShortStyle NS_SWIFT_NAME(short) = 1, NSDateFormatterMediumStyle NS_SWIFT_NAME(medium) = 2,
    NSDateFormatterLongStyle NS_SWIFT_NAME(long) = 3, NSDateFormatterFullStyle NS_SWIFT_NAME(full) = 4
};
@interface NSDateFormatter : NSFormatter
@property (null_resettable, copy) NSString *dateFormat;
@property NSDateFormatterStyle dateStyle;
@property NSDateFormatterStyle timeStyle;
@property (null_resettable, copy) NSLocale *locale;
@property (null_resettable, copy) NSTimeZone *timeZone;
@property BOOL doesRelativeDateFormatting;
- (NSString *)stringFromDate:(NSDate *)date;
- (nullable NSDate *)dateFromString:(NSString *)string;
- (void)setLocalizedDateFormatFromTemplate:(NSString *)dateFormatTemplate;
+ (NSString *)localizedStringFromDate:(NSDate *)date dateStyle:(NSDateFormatterStyle)dstyle timeStyle:(NSDateFormatterStyle)tstyle;
+ (nullable NSString *)dateFormatFromTemplate:(NSString *)tmplate options:(NSUInteger)opts locale:(nullable NSLocale *)locale;
@end

typedef NS_ENUM(NSUInteger, NSNumberFormatterStyle) NS_SWIFT_NAME(NumberFormatter.Style) {
    NSNumberFormatterNoStyle NS_SWIFT_NAME(none) = 0, NSNumberFormatterDecimalStyle NS_SWIFT_NAME(decimal) = 1, NSNumberFormatterCurrencyStyle NS_SWIFT_NAME(currency) = 2,
    NSNumberFormatterPercentStyle NS_SWIFT_NAME(percent) = 3, NSNumberFormatterScientificStyle NS_SWIFT_NAME(scientific) = 4, NSNumberFormatterSpellOutStyle NS_SWIFT_NAME(spellOut) = 5
};
@interface NSNumberFormatter : NSFormatter
@property NSNumberFormatterStyle numberStyle;
@property (null_resettable, copy) NSLocale *locale;
@property NSUInteger minimumFractionDigits;
@property NSUInteger maximumFractionDigits;
@property NSUInteger minimumIntegerDigits;
@property BOOL usesGroupingSeparator;
@property (null_resettable, copy) NSString *decimalSeparator;
@property (null_resettable, copy) NSString *groupingSeparator;
@property (null_resettable, copy) NSString *currencySymbol;
@property (null_resettable, copy) NSString *currencyCode;
- (nullable NSString *)stringFromNumber:(NSNumber *)number;
- (nullable NSNumber *)numberFromString:(NSString *)string;
+ (NSString *)localizedStringFromNumber:(NSNumber *)num numberStyle:(NSNumberFormatterStyle)nstyle;
@end
NS_ASSUME_NONNULL_END
