#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSError, NSURL, NSDate, NSTimeZone, NSMutableString;

typedef uint64_t NSTextCheckingTypes;
typedef NS_OPTIONS(uint64_t, NSTextCheckingType) {
    NSTextCheckingTypeOrthography = 1ULL << 0, NSTextCheckingTypeSpelling = 1ULL << 1, NSTextCheckingTypeGrammar = 1ULL << 2,
    NSTextCheckingTypeDate = 1ULL << 3, NSTextCheckingTypeAddress = 1ULL << 4, NSTextCheckingTypeLink = 1ULL << 5,
    NSTextCheckingTypeQuote = 1ULL << 6, NSTextCheckingTypeDash = 1ULL << 7, NSTextCheckingTypeReplacement = 1ULL << 8,
    NSTextCheckingTypeCorrection = 1ULL << 9, NSTextCheckingTypeRegularExpression = 1ULL << 10,
    NSTextCheckingTypePhoneNumber = 1ULL << 11, NSTextCheckingTypeTransitInformation = 1ULL << 12
} NS_SWIFT_NAME(NSTextCheckingResult.CheckingType);
enum { NSTextCheckingAllSystemTypes = 0xffffffffULL, NSTextCheckingAllCustomTypes = 0xffffffffULL << 32, NSTextCheckingAllTypes = 0xffffffffffffffffULL };

/* isim: regular expressions use the host's PCRE2 engine, whose syntax is close to ICU's. */
typedef NS_OPTIONS(NSUInteger, NSRegularExpressionOptions) {
    NSRegularExpressionCaseInsensitive = 1 << 0, NSRegularExpressionAllowCommentsAndWhitespace = 1 << 1,
    NSRegularExpressionIgnoreMetacharacters = 1 << 2, NSRegularExpressionDotMatchesLineSeparators = 1 << 3,
    NSRegularExpressionAnchorsMatchLines = 1 << 4, NSRegularExpressionUseUnixLineSeparators = 1 << 5,
    NSRegularExpressionUseUnicodeWordBoundaries = 1 << 6
} NS_SWIFT_NAME(NSRegularExpression.Options);
typedef NS_OPTIONS(NSUInteger, NSMatchingOptions) {
    NSMatchingReportProgress = 1 << 0, NSMatchingReportCompletion = 1 << 1, NSMatchingAnchored = 1 << 2,
    NSMatchingWithTransparentBounds = 1 << 3, NSMatchingWithoutAnchoringBounds = 1 << 4
} NS_SWIFT_NAME(NSRegularExpression.MatchingOptions);
typedef NS_OPTIONS(NSUInteger, NSMatchingFlags) {
    NSMatchingProgress = 1 << 0, NSMatchingCompleted = 1 << 1, NSMatchingHitEnd = 1 << 2, NSMatchingRequiredEnd = 1 << 3,
    NSMatchingInternalError = 1 << 4
} NS_SWIFT_NAME(NSRegularExpression.MatchingFlags);

typedef NSString *NSTextCheckingKey NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT NSTextCheckingKey const NSTextCheckingNameKey, NSTextCheckingJobTitleKey, NSTextCheckingOrganizationKey,
    NSTextCheckingStreetKey, NSTextCheckingCityKey, NSTextCheckingStateKey, NSTextCheckingZIPKey, NSTextCheckingCountryKey,
    NSTextCheckingPhoneKey, NSTextCheckingAirlineKey, NSTextCheckingFlightKey;
@class NSRegularExpression;
@interface NSTextCheckingResult : NSObject <NSCopying, NSSecureCoding>
@property (readonly) NSTextCheckingType resultType;
@property (readonly) NSRange range;
@property (nullable, readonly, copy) NSRegularExpression *regularExpression;
@property (readonly) NSUInteger numberOfRanges;
- (NSRange)rangeAtIndex:(NSUInteger)idx;
- (NSRange)rangeWithName:(NSString *)name;
- (NSTextCheckingResult *)resultByAdjustingRangesWithOffset:(NSInteger)offset;
@property (nullable, readonly, copy) NSURL *URL;
@property (nullable, readonly, copy) NSString *phoneNumber;
@property (nullable, readonly, copy) NSDate *date;
@property (nullable, readonly, copy) NSTimeZone *timeZone;
@property (readonly) NSTimeInterval duration;
@property (nullable, readonly, copy) NSString *replacementString;
@property (nullable, readonly, copy) NSDictionary<NSTextCheckingKey, NSString *> *addressComponents;
@property (nullable, readonly, copy) NSDictionary<NSTextCheckingKey, NSString *> *components;
+ (NSTextCheckingResult *)regularExpressionCheckingResultWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)regularExpression;
+ (NSTextCheckingResult *)linkCheckingResultWithRange:(NSRange)range URL:(NSURL *)url;
+ (NSTextCheckingResult *)phoneNumberCheckingResultWithRange:(NSRange)range phoneNumber:(NSString *)phoneNumber;
+ (NSTextCheckingResult *)dateCheckingResultWithRange:(NSRange)range date:(NSDate *)date;
+ (NSTextCheckingResult *)replacementCheckingResultWithRange:(NSRange)range replacementString:(NSString *)replacementString;
+ (NSTextCheckingResult *)addressCheckingResultWithRange:(NSRange)range components:(NSDictionary<NSTextCheckingKey, NSString *> *)components;
+ (NSTextCheckingResult *)transitInformationCheckingResultWithRange:(NSRange)range components:(NSDictionary<NSTextCheckingKey, NSString *> *)components;
@end

@interface NSRegularExpression : NSObject <NSCopying, NSSecureCoding>
+ (nullable NSRegularExpression *)regularExpressionWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error;
- (nullable instancetype)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error NS_DESIGNATED_INITIALIZER;
@property (readonly, copy) NSString *pattern;
@property (readonly) NSRegularExpressionOptions options;
@property (readonly) NSUInteger numberOfCaptureGroups;
+ (NSString *)escapedPatternForString:(NSString *)string;

- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop))block;
- (NSArray<NSTextCheckingResult *> *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSUInteger)numberOfMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (nullable NSTextCheckingResult *)firstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSRange)rangeOfFirstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;

- (NSString *)stringByReplacingMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ;
- (NSUInteger)replaceMatchesInString:(NSMutableString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ;
- (NSString *)replacementStringForResult:(NSTextCheckingResult *)result inString:(NSString *)string offset:(NSInteger)offset template:(NSString *)templ;
+ (NSString *)escapedTemplateForString:(NSString *)string;
@end

/* isim: links (URLs, e-mail addresses, bare domains), phone numbers and dates (numeric, ISO 8601, English month names). */
@interface NSDataDetector : NSRegularExpression
+ (nullable NSDataDetector *)dataDetectorWithTypes:(NSTextCheckingTypes)checkingTypes error:(NSError **)error;
- (nullable instancetype)initWithTypes:(NSTextCheckingTypes)checkingTypes error:(NSError **)error NS_DESIGNATED_INITIALIZER;
@property (readonly) NSTextCheckingTypes checkingTypes;
@end

NS_ASSUME_NONNULL_END
