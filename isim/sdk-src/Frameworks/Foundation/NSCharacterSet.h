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
NS_ASSUME_NONNULL_END
