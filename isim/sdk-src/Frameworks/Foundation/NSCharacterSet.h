#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString;
typedef uint32_t UTF32Char;
/* isim: predicate-backed sets over UTF-16 code units (BMP); invertedSet supported */
@interface NSCharacterSet : NSObject <NSCopying>
@property (class, readonly, copy) NSCharacterSet *whitespaceCharacterSet, *whitespaceAndNewlineCharacterSet, *newlineCharacterSet,
    *decimalDigitCharacterSet, *letterCharacterSet, *lowercaseLetterCharacterSet, *uppercaseLetterCharacterSet,
    *alphanumericCharacterSet, *punctuationCharacterSet, *controlCharacterSet, *symbolCharacterSet;
+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)string;
+ (NSCharacterSet *)characterSetWithRange:(NSRange)range;
@property (readonly, copy) NSCharacterSet *invertedSet;
- (BOOL)characterIsMember:(unichar)c;
- (BOOL)longCharacterIsMember:(UTF32Char)theLongChar;
@end
@interface NSMutableCharacterSet : NSCharacterSet
- (void)addCharactersInString:(NSString *)string;
- (void)removeCharactersInString:(NSString *)string;
- (void)formUnionWithCharacterSet:(NSCharacterSet *)other;
@end
@interface NSString (NSCharacterSetAdditions)
- (NSString *)stringByTrimmingCharactersInSet:(NSCharacterSet *)set;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set;
- (NSArray<NSString *> *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)set;
@end
#if !defined(__swift__)   /* Objective-C only: Swift has its own Foundation API for these */
@interface NSCharacterSet (NSURLUtilities)
@property (class, readonly, copy) NSCharacterSet *URLUserAllowedCharacterSet;
@property (class, readonly, copy) NSCharacterSet *URLPasswordAllowedCharacterSet;
@property (class, readonly, copy) NSCharacterSet *URLHostAllowedCharacterSet;
@property (class, readonly, copy) NSCharacterSet *URLPathAllowedCharacterSet;
@property (class, readonly, copy) NSCharacterSet *URLQueryAllowedCharacterSet;
@property (class, readonly, copy) NSCharacterSet *URLFragmentAllowedCharacterSet;
@end
#endif
NS_ASSUME_NONNULL_END
