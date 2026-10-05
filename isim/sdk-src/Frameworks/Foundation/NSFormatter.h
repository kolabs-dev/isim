#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDate, NSNumber, NSLocale, NSTimeZone;
@interface NSFormatter : NSObject <NSCopying, NSCoding>
- (nullable NSString *)stringForObjectValue:(nullable id)obj;
@end

typedef NS_ENUM(NSUInteger, NSDateFormatterStyle) {
    NSDateFormatterNoStyle = 0, NSDateFormatterShortStyle = 1, NSDateFormatterMediumStyle = 2,
    NSDateFormatterLongStyle = 3, NSDateFormatterFullStyle = 4
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

typedef NS_ENUM(NSUInteger, NSNumberFormatterStyle) {
    NSNumberFormatterNoStyle = 0, NSNumberFormatterDecimalStyle = 1, NSNumberFormatterCurrencyStyle = 2,
    NSNumberFormatterPercentStyle = 3, NSNumberFormatterScientificStyle = 4, NSNumberFormatterSpellOutStyle = 5
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
