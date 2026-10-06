#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSError;
@class NSArray<ObjectType>, NSData;
typedef unsigned short unichar;
typedef NSUInteger NSStringEncoding;
enum { NSASCIIStringEncoding = 1, NSUTF8StringEncoding = 4, NSISOLatin1StringEncoding = 5, NSUTF16StringEncoding = 10 };
typedef NS_OPTIONS(NSUInteger, NSStringCompareOptions) {
    NSCaseInsensitiveSearch NS_SWIFT_NAME(caseInsensitive) = 1, NSLiteralSearch NS_SWIFT_NAME(literal) = 2,
    NSBackwardsSearch NS_SWIFT_NAME(backwards) = 4, NSAnchoredSearch NS_SWIFT_NAME(anchored) = 8, NSNumericSearch NS_SWIFT_NAME(numeric) = 64,
    NSDiacriticInsensitiveSearch NS_SWIFT_NAME(diacriticInsensitive) = 128, NSWidthInsensitiveSearch NS_SWIFT_NAME(widthInsensitive) = 256,
    NSForcedOrderingSearch NS_SWIFT_NAME(forcedOrdering) = 512, NSRegularExpressionSearch NS_SWIFT_NAME(regularExpression) = 1024
} NS_SWIFT_NAME(NSString.CompareOptions);
typedef NS_OPTIONS(NSUInteger, NSStringEnumerationOptions) {
    NSStringEnumerationByLines NS_SWIFT_NAME(byLines) = 0, NSStringEnumerationByParagraphs NS_SWIFT_NAME(byParagraphs) = 1,
    NSStringEnumerationByComposedCharacterSequences NS_SWIFT_NAME(byComposedCharacterSequences) = 2, NSStringEnumerationByWords NS_SWIFT_NAME(byWords) = 3,
    NSStringEnumerationBySentences NS_SWIFT_NAME(bySentences) = 4, NSStringEnumerationByCaretPositions NS_SWIFT_NAME(byCaretPositions) = 5,
    NSStringEnumerationByDeletionClusters NS_SWIFT_NAME(byDeletionClusters) = 6, NSStringEnumerationReverse NS_SWIFT_NAME(reverse) = 1UL << 8,
    NSStringEnumerationSubstringNotRequired NS_SWIFT_NAME(substringNotRequired) = 1UL << 9, NSStringEnumerationLocalized NS_SWIFT_NAME(localized) = 1UL << 10
} NS_SWIFT_NAME(NSString.EnumerationOptions);
@class NSLocale;

@interface NSString : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (readonly) NSUInteger length;
- (unichar)characterAtIndex:(NSUInteger)index;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
+ (instancetype)string;
+ (instancetype)stringWithString:(NSString *)string;
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString;
+ (instancetype)stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
+ (instancetype)stringWithCString:(const char *)cString encoding:(NSStringEncoding)enc;
+ (nullable instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError * _Nullable * _Nullable)error;
- (instancetype)initWithString:(NSString *)aString;
- (nullable instancetype)initWithUTF8String:(const char *)nullTerminatedCString;
- (instancetype)initWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (instancetype)initWithFormat:(NSString *)format arguments:(va_list)argList NS_FORMAT_FUNCTION(1, 0);
- (nullable instancetype)initWithBytes:(const void *)bytes length:(NSUInteger)len encoding:(NSStringEncoding)encoding;
- (nullable instancetype)initWithCharacters:(const unichar *)characters length:(NSUInteger)length;
- (nullable instancetype)initWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
@property (nullable, readonly) const char *UTF8String NS_RETURNS_INNER_POINTER;
- (nullable const char *)cStringUsingEncoding:(NSStringEncoding)encoding NS_RETURNS_INNER_POINTER;
- (NSUInteger)lengthOfBytesUsingEncoding:(NSStringEncoding)enc;
- (BOOL)isEqualToString:(NSString *)aString;
- (NSComparisonResult)compare:(NSString *)string;
- (NSComparisonResult)compare:(NSString *)string options:(NSStringCompareOptions)mask;
- (NSComparisonResult)caseInsensitiveCompare:(NSString *)string;
/* isim: locale-independent (code point) ordering */
- (NSComparisonResult)localizedCompare:(NSString *)string;
- (NSComparisonResult)localizedCaseInsensitiveCompare:(NSString *)string;
- (NSComparisonResult)localizedStandardCompare:(NSString *)string;
- (BOOL)hasPrefix:(NSString *)str;
- (BOOL)hasSuffix:(NSString *)str;
- (BOOL)containsString:(NSString *)str;
- (NSRange)rangeOfString:(NSString *)searchString;
- (NSRange)rangeOfString:(NSString *)searchString options:(NSStringCompareOptions)mask;
- (NSString *)stringByAppendingString:(NSString *)aString;
- (NSString *)stringByAppendingFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
- (NSString *)substringFromIndex:(NSUInteger)from;
- (NSString *)substringToIndex:(NSUInteger)to;
- (NSString *)substringWithRange:(NSRange)range;
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)index;
- (NSString *)stringByReplacingCharactersInRange:(NSRange)range withString:(NSString *)replacement;
- (NSArray<NSString *> *)componentsSeparatedByString:(NSString *)separator;
@property (readonly, copy) NSString *lowercaseString;
@property (readonly, copy) NSString *uppercaseString;
@property (readonly, copy) NSString *capitalizedString;
@property (readonly, copy) NSString *decomposedStringWithCanonicalMapping;
@property (readonly, copy) NSString *precomposedStringWithCanonicalMapping;
@property (readonly) double doubleValue;
@property (readonly) float floatValue;
@property (readonly) int intValue;
@property (readonly) NSInteger integerValue;
@property (readonly) long long longLongValue;
@property (readonly) BOOL boolValue;
@property (readonly, copy) NSString *lastPathComponent;
@property (readonly, copy) NSString *stringByDeletingLastPathComponent;
@property (readonly, copy) NSString *pathExtension;
@property (readonly, copy) NSString *stringByDeletingPathExtension;
- (NSString *)stringByAppendingPathComponent:(NSString *)str;
- (NSString *)stringByAppendingPathExtension:(NSString *)str;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError * _Nullable * _Nullable)error;
@end

@interface NSString (NSStringExtensionMethods)
/* search and replace with options (NSRegularExpressionSearch uses NSRegularExpression) */
- (NSRange)rangeOfString:(NSString *)searchString options:(NSStringCompareOptions)mask range:(NSRange)rangeOfReceiverToSearch;
- (NSRange)rangeOfString:(NSString *)searchString options:(NSStringCompareOptions)mask range:(NSRange)rangeOfReceiverToSearch locale:(nullable NSLocale *)locale;
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSStringCompareOptions)options range:(NSRange)searchRange;
- (BOOL)localizedCaseInsensitiveContainsString:(NSString *)str;
- (BOOL)localizedStandardContainsString:(NSString *)str;
- (NSRange)localizedStandardRangeOfString:(NSString *)str;
- (NSString *)stringByFoldingWithOptions:(NSStringCompareOptions)options locale:(nullable NSLocale *)locale;
+ (instancetype)stringWithCharacters:(const unichar *)characters length:(NSUInteger)length;
- (void)getCharacters:(unichar *)buffer range:(NSRange)range;
- (void)enumerateLinesUsingBlock:(void (NS_NOESCAPE ^)(NSString *line, BOOL *stop))block;
- (void)enumerateSubstringsInRange:(NSRange)range options:(NSStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop))block;
- (NSRange)lineRangeForRange:(NSRange)range;
- (NSRange)paragraphRangeForRange:(NSRange)range;
- (NSString *)stringByPaddingToLength:(NSUInteger)newLength withString:(NSString *)padString startingAtIndex:(NSUInteger)padIndex;
@property (readonly, copy) NSString *localizedLowercaseString;
@property (readonly, copy) NSString *localizedUppercaseString;
@property (readonly, copy) NSString *localizedCapitalizedString;
- (NSString *)lowercaseStringWithLocale:(nullable NSLocale *)locale;
- (NSString *)uppercaseStringWithLocale:(nullable NSLocale *)locale;
- (NSString *)capitalizedStringWithLocale:(nullable NSLocale *)locale;
- (NSString *)commonPrefixWithString:(NSString *)str options:(NSStringCompareOptions)mask;
@property (readonly, getter=isAbsolutePath) BOOL absolutePath;
@property (readonly, copy) NSArray<NSString *> *pathComponents;
+ (NSString *)pathWithComponents:(NSArray<NSString *> *)components;
@property (readonly, copy) NSString *stringByExpandingTildeInPath;
@property (readonly, copy) NSString *stringByStandardizingPath;
@end

@interface NSMutableString : NSString
- (void)appendString:(NSString *)aString;
- (void)appendFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)setString:(NSString *)aString;
- (void)insertString:(NSString *)aString atIndex:(NSUInteger)loc;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)aString;
+ (instancetype)stringWithCapacity:(NSUInteger)capacity;
- (instancetype)initWithCapacity:(NSUInteger)capacity;
@end

NS_ASSUME_NONNULL_END
