#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSCalendar.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSDate, NSNumber, NSLocale, NSTimeZone, NSArray<ObjectType>;
/* isim: formatters use a built-in subset of CLDR data (en, pt, es, fr, de, it, ja and their main regions);
 * output follows the device region (Settings > General > Language & Region) like iOS. */
typedef NS_ENUM(NSInteger, NSFormattingContext) {
    NSFormattingContextUnknown = 0, NSFormattingContextDynamic = 1, NSFormattingContextStandalone = 2,
    NSFormattingContextListItem = 3, NSFormattingContextBeginningOfSentence = 4, NSFormattingContextMiddleOfSentence = 5
} NS_SWIFT_NAME(Formatter.Context);
typedef NS_ENUM(NSInteger, NSFormattingUnitStyle) {
    NSFormattingUnitStyleShort = 1, NSFormattingUnitStyleMedium, NSFormattingUnitStyleLong
} NS_SWIFT_NAME(Formatter.UnitStyle);

@interface NSFormatter : NSObject <NSCopying, NSCoding>
- (nullable NSString *)stringForObjectValue:(nullable id)obj;
- (nullable NSString *)editingStringForObjectValue:(id)obj;
- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj forString:(NSString *)string errorDescription:(out NSString * _Nullable * _Nullable)error;
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
@property (null_resettable, copy) NSCalendar *calendar;
@property BOOL doesRelativeDateFormatting;
@property (getter=isLenient) BOOL lenient;
@property NSFormattingContext formattingContext;
@property (nullable, copy) NSDate *defaultDate;
@property (nullable, copy) NSDate *twoDigitStartDate;
@property BOOL generatesCalendarDates;
- (NSString *)stringFromDate:(NSDate *)date;
- (nullable NSDate *)dateFromString:(NSString *)string;
- (void)setLocalizedDateFormatFromTemplate:(NSString *)dateFormatTemplate;
+ (NSString *)localizedStringFromDate:(NSDate *)date dateStyle:(NSDateFormatterStyle)dstyle timeStyle:(NSDateFormatterStyle)tstyle;
+ (nullable NSString *)dateFormatFromTemplate:(NSString *)tmplate options:(NSUInteger)opts locale:(nullable NSLocale *)locale;
@property (null_resettable, copy) NSArray<NSString *> *monthSymbols;
@property (null_resettable, copy) NSArray<NSString *> *shortMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *standaloneMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *shortStandaloneMonthSymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortStandaloneMonthSymbols;
@property (null_resettable, copy) NSArray<NSString *> *weekdaySymbols;
@property (null_resettable, copy) NSArray<NSString *> *shortWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *standaloneWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *shortStandaloneWeekdaySymbols;
@property (readonly, copy) NSArray<NSString *> *veryShortStandaloneWeekdaySymbols;
@property (null_resettable, copy) NSString *AMSymbol;
@property (null_resettable, copy) NSString *PMSymbol;
@property (readonly, copy) NSArray<NSString *> *eraSymbols;
@property (readonly, copy) NSArray<NSString *> *quarterSymbols;
@property (readonly, copy) NSArray<NSString *> *shortQuarterSymbols;
@end

typedef NS_ENUM(NSUInteger, NSNumberFormatterStyle) NS_SWIFT_NAME(NumberFormatter.Style) {
    NSNumberFormatterNoStyle NS_SWIFT_NAME(none) = 0, NSNumberFormatterDecimalStyle NS_SWIFT_NAME(decimal) = 1, NSNumberFormatterCurrencyStyle NS_SWIFT_NAME(currency) = 2,
    NSNumberFormatterPercentStyle NS_SWIFT_NAME(percent) = 3, NSNumberFormatterScientificStyle NS_SWIFT_NAME(scientific) = 4, NSNumberFormatterSpellOutStyle NS_SWIFT_NAME(spellOut) = 5,
    NSNumberFormatterOrdinalStyle NS_SWIFT_NAME(ordinal) = 6, NSNumberFormatterCurrencyISOCodeStyle NS_SWIFT_NAME(currencyISOCode) = 8,
    NSNumberFormatterCurrencyPluralStyle NS_SWIFT_NAME(currencyPlural) = 9, NSNumberFormatterCurrencyAccountingStyle NS_SWIFT_NAME(currencyAccounting) = 10
};
typedef NS_ENUM(NSUInteger, NSNumberFormatterRoundingMode) NS_SWIFT_NAME(NumberFormatter.RoundingMode) {
    NSNumberFormatterRoundCeiling NS_SWIFT_NAME(ceiling), NSNumberFormatterRoundFloor NS_SWIFT_NAME(floor), NSNumberFormatterRoundDown NS_SWIFT_NAME(down),
    NSNumberFormatterRoundUp NS_SWIFT_NAME(up), NSNumberFormatterRoundHalfEven NS_SWIFT_NAME(halfEven), NSNumberFormatterRoundHalfDown NS_SWIFT_NAME(halfDown),
    NSNumberFormatterRoundHalfUp NS_SWIFT_NAME(halfUp)
};
@interface NSNumberFormatter : NSFormatter
@property NSNumberFormatterStyle numberStyle;
@property (null_resettable, copy) NSLocale *locale;
@property NSUInteger minimumFractionDigits;
@property NSUInteger maximumFractionDigits;
@property NSUInteger minimumIntegerDigits;
@property NSUInteger maximumIntegerDigits;
@property NSUInteger minimumSignificantDigits;
@property NSUInteger maximumSignificantDigits;
@property BOOL usesSignificantDigits;
@property BOOL usesGroupingSeparator;
@property NSUInteger groupingSize;
@property NSUInteger secondaryGroupingSize;
@property NSNumberFormatterRoundingMode roundingMode;
@property (null_resettable, copy) NSNumber *roundingIncrement;
@property (nullable, copy) NSNumber *multiplier;
@property (nullable, copy) NSNumber *minimum;
@property (nullable, copy) NSNumber *maximum;
@property (getter=isLenient) BOOL lenient;
@property BOOL allowsFloats;
@property BOOL generatesDecimalNumbers;
@property (null_resettable, copy) NSString *decimalSeparator;
@property (null_resettable, copy) NSString *groupingSeparator;
@property (null_resettable, copy) NSString *currencyDecimalSeparator;
@property (null_resettable, copy) NSString *currencyGroupingSeparator;
@property (null_resettable, copy) NSString *currencySymbol;
@property (null_resettable, copy) NSString *currencyCode;
@property (null_resettable, copy) NSString *internationalCurrencySymbol;
@property (null_resettable, copy) NSString *percentSymbol;
@property (readonly, copy) NSString *perMillSymbol;
@property (null_resettable, copy) NSString *minusSign;
@property (null_resettable, copy) NSString *plusSign;
@property (null_resettable, copy) NSString *exponentSymbol;
@property (null_resettable, copy) NSString *nilSymbol;
@property (nullable, copy) NSString *zeroSymbol;
@property (null_resettable, copy) NSString *notANumberSymbol;
@property (null_resettable, copy) NSString *positiveInfinitySymbol;
@property (null_resettable, copy) NSString *negativeInfinitySymbol;
@property (readonly, copy) NSString *paddingCharacter;
@property (null_resettable, copy) NSString *positivePrefix;
@property (null_resettable, copy) NSString *positiveSuffix;
@property (null_resettable, copy) NSString *negativePrefix;
@property (null_resettable, copy) NSString *negativeSuffix;
@property (null_resettable, copy) NSString *positiveFormat;
@property (null_resettable, copy) NSString *negativeFormat;
- (nullable NSString *)stringFromNumber:(NSNumber *)number;
- (nullable NSNumber *)numberFromString:(NSString *)string;
+ (NSString *)localizedStringFromNumber:(NSNumber *)num numberStyle:(NSNumberFormatterStyle)nstyle;
/* isim-private: exact formatting of a decimal string (used by Swift's Decimal formatting) */
- (NSString *)_isim_stringFromDecimalString:(NSString *)decimal;
@end

typedef NS_OPTIONS(NSUInteger, NSISO8601DateFormatOptions) {
    NSISO8601DateFormatWithYear NS_SWIFT_NAME(withYear) = 1UL << 0, NSISO8601DateFormatWithMonth NS_SWIFT_NAME(withMonth) = 1UL << 1,
    NSISO8601DateFormatWithWeekOfYear NS_SWIFT_NAME(withWeekOfYear) = 1UL << 2, NSISO8601DateFormatWithDay NS_SWIFT_NAME(withDay) = 1UL << 4,
    NSISO8601DateFormatWithTime NS_SWIFT_NAME(withTime) = 1UL << 5, NSISO8601DateFormatWithTimeZone NS_SWIFT_NAME(withTimeZone) = 1UL << 6,
    NSISO8601DateFormatWithSpaceBetweenDateAndTime NS_SWIFT_NAME(withSpaceBetweenDateAndTime) = 1UL << 7,
    NSISO8601DateFormatWithDashSeparatorInDate NS_SWIFT_NAME(withDashSeparatorInDate) = 1UL << 8,
    NSISO8601DateFormatWithColonSeparatorInTime NS_SWIFT_NAME(withColonSeparatorInTime) = 1UL << 9,
    NSISO8601DateFormatWithColonSeparatorInTimeZone NS_SWIFT_NAME(withColonSeparatorInTimeZone) = 1UL << 10,
    NSISO8601DateFormatWithFractionalSeconds NS_SWIFT_NAME(withFractionalSeconds) = 1UL << 11,
    NSISO8601DateFormatWithFullDate NS_SWIFT_NAME(withFullDate) = (1UL << 0) | (1UL << 1) | (1UL << 4) | (1UL << 8),
    NSISO8601DateFormatWithFullTime NS_SWIFT_NAME(withFullTime) = (1UL << 5) | (1UL << 6) | (1UL << 9) | (1UL << 10),
    NSISO8601DateFormatWithInternetDateTime NS_SWIFT_NAME(withInternetDateTime) = (1UL << 0) | (1UL << 1) | (1UL << 4) | (1UL << 8) | (1UL << 5) | (1UL << 6) | (1UL << 9) | (1UL << 10)
} NS_SWIFT_NAME(ISO8601DateFormatter.Options);
@interface NSISO8601DateFormatter : NSFormatter
@property (null_resettable, copy) NSTimeZone *timeZone;
@property NSISO8601DateFormatOptions formatOptions;
- (NSString *)stringFromDate:(NSDate *)date;
- (nullable NSDate *)dateFromString:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)formatOptions;
@end

typedef NS_ENUM(NSInteger, NSRelativeDateTimeFormatterStyle) {
    NSRelativeDateTimeFormatterStyleNumeric NS_SWIFT_NAME(numeric) = 0, NSRelativeDateTimeFormatterStyleNamed NS_SWIFT_NAME(named)
} NS_SWIFT_NAME(RelativeDateTimeFormatter.DateTimeStyle);
typedef NS_ENUM(NSInteger, NSRelativeDateTimeFormatterUnitsStyle) {
    NSRelativeDateTimeFormatterUnitsStyleFull NS_SWIFT_NAME(full) = 0, NSRelativeDateTimeFormatterUnitsStyleSpellOut NS_SWIFT_NAME(spellOut),
    NSRelativeDateTimeFormatterUnitsStyleShort NS_SWIFT_NAME(short), NSRelativeDateTimeFormatterUnitsStyleAbbreviated NS_SWIFT_NAME(abbreviated)
} NS_SWIFT_NAME(RelativeDateTimeFormatter.UnitsStyle);
@interface NSRelativeDateTimeFormatter : NSFormatter
@property NSRelativeDateTimeFormatterStyle dateTimeStyle;
@property NSRelativeDateTimeFormatterUnitsStyle unitsStyle;
@property NSFormattingContext formattingContext;
@property (null_resettable, copy) NSCalendar *calendar;
@property (null_resettable, copy) NSLocale *locale;
- (NSString *)localizedStringFromDateComponents:(NSDateComponents *)dateComponents;
- (NSString *)localizedStringFromTimeInterval:(NSTimeInterval)timeInterval;
- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)referenceDate;
@end

typedef NS_ENUM(NSInteger, NSDateComponentsFormatterUnitsStyle) {
    NSDateComponentsFormatterUnitsStylePositional NS_SWIFT_NAME(positional) = 0, NSDateComponentsFormatterUnitsStyleAbbreviated NS_SWIFT_NAME(abbreviated),
    NSDateComponentsFormatterUnitsStyleShort NS_SWIFT_NAME(short), NSDateComponentsFormatterUnitsStyleFull NS_SWIFT_NAME(full),
    NSDateComponentsFormatterUnitsStyleSpellOut NS_SWIFT_NAME(spellOut), NSDateComponentsFormatterUnitsStyleBrief NS_SWIFT_NAME(brief)
} NS_SWIFT_NAME(DateComponentsFormatter.UnitsStyle);
typedef NS_OPTIONS(NSUInteger, NSDateComponentsFormatterZeroFormattingBehavior) {
    NSDateComponentsFormatterZeroFormattingBehaviorNone NS_SWIFT_NAME(none) = 0, NSDateComponentsFormatterZeroFormattingBehaviorDefault NS_SWIFT_NAME(default) = 1,
    NSDateComponentsFormatterZeroFormattingBehaviorDropLeading NS_SWIFT_NAME(dropLeading) = 2, NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle NS_SWIFT_NAME(dropMiddle) = 4,
    NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing NS_SWIFT_NAME(dropTrailing) = 8, NSDateComponentsFormatterZeroFormattingBehaviorDropAll NS_SWIFT_NAME(dropAll) = 14,
    NSDateComponentsFormatterZeroFormattingBehaviorPad NS_SWIFT_NAME(pad) = 0x10000
} NS_SWIFT_NAME(DateComponentsFormatter.ZeroFormattingBehavior);
@interface NSDateComponentsFormatter : NSFormatter
- (nullable NSString *)stringFromDateComponents:(NSDateComponents *)components;
- (nullable NSString *)stringFromDate:(NSDate *)startDate toDate:(NSDate *)endDate;
- (nullable NSString *)stringFromTimeInterval:(NSTimeInterval)ti NS_SWIFT_NAME(string(from:));
+ (nullable NSString *)localizedStringFromDateComponents:(NSDateComponents *)components unitsStyle:(NSDateComponentsFormatterUnitsStyle)unitsStyle;
@property NSDateComponentsFormatterUnitsStyle unitsStyle;
@property NSCalendarUnit allowedUnits;
@property NSDateComponentsFormatterZeroFormattingBehavior zeroFormattingBehavior;
@property (nullable, copy) NSCalendar *calendar;
@property (nullable, copy) NSDate *referenceDate;
@property BOOL allowsFractionalUnits;
@property NSInteger maximumUnitCount;
@property BOOL collapsesLargestUnit;
@property BOOL includesApproximationPhrase;
@property BOOL includesTimeRemainingPhrase;
@property NSFormattingContext formattingContext;
@end

typedef NS_ENUM(NSUInteger, NSDateIntervalFormatterStyle) {
    NSDateIntervalFormatterNoStyle NS_SWIFT_NAME(none) = 0, NSDateIntervalFormatterShortStyle NS_SWIFT_NAME(short) = 1,
    NSDateIntervalFormatterMediumStyle NS_SWIFT_NAME(medium) = 2, NSDateIntervalFormatterLongStyle NS_SWIFT_NAME(long) = 3,
    NSDateIntervalFormatterFullStyle NS_SWIFT_NAME(full) = 4
} NS_SWIFT_NAME(DateIntervalFormatter.Style);
@interface NSDateIntervalFormatter : NSFormatter
@property (null_resettable, copy) NSLocale *locale;
@property (null_resettable, copy) NSCalendar *calendar;
@property (null_resettable, copy) NSTimeZone *timeZone;
@property (null_resettable, copy) NSString *dateTemplate;
@property NSDateIntervalFormatterStyle dateStyle;
@property NSDateIntervalFormatterStyle timeStyle;
- (NSString *)stringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate;
@end

typedef NS_OPTIONS(NSUInteger, NSByteCountFormatterUnits) {
    NSByteCountFormatterUseDefault NS_SWIFT_NAME(useDefault) = 0, NSByteCountFormatterUseBytes NS_SWIFT_NAME(useBytes) = 1UL << 0,
    NSByteCountFormatterUseKB NS_SWIFT_NAME(useKB) = 1UL << 1, NSByteCountFormatterUseMB NS_SWIFT_NAME(useMB) = 1UL << 2,
    NSByteCountFormatterUseGB NS_SWIFT_NAME(useGB) = 1UL << 3, NSByteCountFormatterUseTB NS_SWIFT_NAME(useTB) = 1UL << 4,
    NSByteCountFormatterUsePB NS_SWIFT_NAME(usePB) = 1UL << 5, NSByteCountFormatterUseEB NS_SWIFT_NAME(useEB) = 1UL << 6,
    NSByteCountFormatterUseZB NS_SWIFT_NAME(useZB) = 1UL << 7, NSByteCountFormatterUseYBOrHigher NS_SWIFT_NAME(useYBOrHigher) = 0x0FFUL << 8,
    NSByteCountFormatterUseAll NS_SWIFT_NAME(useAll) = 0x0FFFFUL
} NS_SWIFT_NAME(ByteCountFormatter.Units);
typedef NS_ENUM(NSInteger, NSByteCountFormatterCountStyle) {
    NSByteCountFormatterCountStyleFile NS_SWIFT_NAME(file) = 0, NSByteCountFormatterCountStyleMemory NS_SWIFT_NAME(memory) = 1,
    NSByteCountFormatterCountStyleDecimal NS_SWIFT_NAME(decimal) = 2, NSByteCountFormatterCountStyleBinary NS_SWIFT_NAME(binary) = 3
} NS_SWIFT_NAME(ByteCountFormatter.CountStyle);
@interface NSByteCountFormatter : NSFormatter
+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(NSByteCountFormatterCountStyle)countStyle;
- (NSString *)stringFromByteCount:(long long)byteCount;
@property NSByteCountFormatterUnits allowedUnits;
@property NSByteCountFormatterCountStyle countStyle;
@property BOOL allowsNonnumericFormatting;
@property BOOL includesUnit;
@property BOOL includesCount;
@property BOOL includesActualByteCount;
@property (getter=isAdaptive) BOOL adaptive;
@property BOOL zeroPadsFractionDigits;
@property NSFormattingContext formattingContext;
/* isim-private: Swift's ByteCountFormatStyle ("kB") */
- (NSString *)_isim_string:(long long)count locale:(NSLocale *)locale lowercaseK:(BOOL)lowercaseK;
@end

@interface NSListFormatter : NSFormatter
@property (null_resettable, copy) NSLocale *locale;
@property (nullable, copy) NSFormatter *itemFormatter;
+ (NSString *)localizedStringByJoiningStrings:(NSArray<NSString *> *)strings;
/* isim-private: Swift ListFormatStyle (width: 0 standard, 1 short, 2 narrow) */
+ (NSString *)_isim_joinStrings:(NSArray<NSString *> *)strings locale:(NSLocale *)locale orList:(BOOL)orList width:(NSInteger)width;
- (nullable NSString *)stringFromItems:(NSArray *)items;
@end

@interface NSPersonNameComponents : NSObject <NSCopying, NSSecureCoding>
@property (nullable, copy) NSString *namePrefix;
@property (nullable, copy) NSString *givenName;
@property (nullable, copy) NSString *middleName;
@property (nullable, copy) NSString *familyName;
@property (nullable, copy) NSString *nameSuffix;
@property (nullable, copy) NSString *nickname;
@property (nullable, copy) NSPersonNameComponents *phoneticRepresentation;
@end
typedef NS_ENUM(NSInteger, NSPersonNameComponentsFormatterStyle) {
    NSPersonNameComponentsFormatterStyleDefault NS_SWIFT_NAME(default) = 0, NSPersonNameComponentsFormatterStyleShort NS_SWIFT_NAME(short),
    NSPersonNameComponentsFormatterStyleMedium NS_SWIFT_NAME(medium), NSPersonNameComponentsFormatterStyleLong NS_SWIFT_NAME(long),
    NSPersonNameComponentsFormatterStyleAbbreviated NS_SWIFT_NAME(abbreviated)
} NS_SWIFT_NAME(PersonNameComponentsFormatter.Style);
typedef NS_OPTIONS(NSUInteger, NSPersonNameComponentsFormatterOptions) {
    NSPersonNameComponentsFormatterPhonetic NS_SWIFT_NAME(phonetic) = 1UL << 1
} NS_SWIFT_NAME(PersonNameComponentsFormatter.Options);
@interface NSPersonNameComponentsFormatter : NSFormatter
@property NSPersonNameComponentsFormatterStyle style;
@property (getter=isPhonetic) BOOL phonetic;
@property (null_resettable, copy) NSLocale *locale;
+ (NSString *)localizedStringFromPersonNameComponents:(NSPersonNameComponents *)components style:(NSPersonNameComponentsFormatterStyle)nameFormatStyle options:(NSPersonNameComponentsFormatterOptions)nameOptions;
- (NSString *)stringFromPersonNameComponents:(NSPersonNameComponents *)components;
- (nullable NSPersonNameComponents *)personNameComponentsFromString:(NSString *)string;
@end
NS_ASSUME_NONNULL_END
