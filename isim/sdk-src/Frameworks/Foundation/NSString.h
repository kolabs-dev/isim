#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSArray<ObjectType>, NSData;
typedef unsigned short unichar;
typedef NSUInteger NSStringEncoding;
enum { NSASCIIStringEncoding = 1, NSUTF8StringEncoding = 4, NSISOLatin1StringEncoding = 5, NSUTF16StringEncoding = 10 };
typedef NS_OPTIONS(NSUInteger, NSStringCompareOptions) {
    NSCaseInsensitiveSearch = 1, NSLiteralSearch = 2, NSBackwardsSearch = 4, NSAnchoredSearch = 8, NSNumericSearch = 64
};

@interface NSString : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (readonly) NSUInteger length;
- (unichar)characterAtIndex:(NSUInteger)index;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
+ (instancetype)string;
+ (instancetype)stringWithString:(NSString *)string;
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString;
+ (instancetype)stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
+ (instancetype)stringWithCString:(const char *)cString encoding:(NSStringEncoding)enc;
+ (nullable instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(id _Nullable * _Nullable)error;
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
- (NSComparisonResult)localizedCompare:(NSString *)string;
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
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(id _Nullable * _Nullable)error;
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
