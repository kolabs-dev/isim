/* NSCharacterSet (predicate-backed) and the NSString methods that use it. */
#import <Foundation/Foundation.h>
#include <wctype.h>

@interface NSCharacterSet ()
@property (nonatomic, copy) BOOL (^test)(unichar c);
@end
@implementation NSCharacterSet
+ (instancetype)_with:(BOOL (^)(unichar))t { NSCharacterSet *s = [self new]; s.test = t; return s; }
+ (NSCharacterSet *)whitespaceCharacterSet { return [self _with:^BOOL(unichar c) { return c == ' ' || c == '\t' || c == 0xA0 || (c >= 0x2000 && c <= 0x200A) || c == 0x202F || c == 0x205F || c == 0x3000 || c == 0x1680; }]; }
+ (NSCharacterSet *)newlineCharacterSet { return [self _with:^BOOL(unichar c) { return (c >= 0x0A && c <= 0x0D) || c == 0x85 || c == 0x2028 || c == 0x2029; }]; }
+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet {
    NSCharacterSet *w = self.whitespaceCharacterSet, *n = self.newlineCharacterSet;
    return [self _with:^BOOL(unichar c) { return [w characterIsMember:c] || [n characterIsMember:c]; }];
}
+ (NSCharacterSet *)decimalDigitCharacterSet { return [self _with:^BOOL(unichar c) { return iswdigit(c) || (c >= 0x660 && c <= 0x669) || (c >= 0x6F0 && c <= 0x6F9) || (c >= 0x966 && c <= 0x96F) || (c >= 0xFF10 && c <= 0xFF19); }]; }
+ (NSCharacterSet *)letterCharacterSet { return [self _with:^BOOL(unichar c) { return iswalpha(c); }]; }
+ (NSCharacterSet *)lowercaseLetterCharacterSet { return [self _with:^BOOL(unichar c) { return iswlower(c); }]; }
+ (NSCharacterSet *)uppercaseLetterCharacterSet { return [self _with:^BOOL(unichar c) { return iswupper(c); }]; }
+ (NSCharacterSet *)alphanumericCharacterSet { return [self _with:^BOOL(unichar c) { return iswalnum(c); }]; }
+ (NSCharacterSet *)punctuationCharacterSet { return [self _with:^BOOL(unichar c) { return iswpunct(c) && !strchr("$+<=>^`|~", c < 128 ? (int)c : 1); }]; }
+ (NSCharacterSet *)symbolCharacterSet { return [self _with:^BOOL(unichar c) { return c < 128 ? strchr("$+<=>^`|~", c) != NULL : iswpunct(c); }]; }
+ (NSCharacterSet *)controlCharacterSet { return [self _with:^BOOL(unichar c) { return iswcntrl(c); }]; }
+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)str {
    NSString *copy = [str copy];
    return [self _with:^BOOL(unichar c) { for (NSUInteger i = 0; i < copy.length; i++) if ([copy characterAtIndex:i] == c) return YES; return NO; }];
}
+ (NSCharacterSet *)characterSetWithRange:(NSRange)r { return [self _with:^BOOL(unichar c) { return c >= r.location && c < NSMaxRange(r); }]; }
- (NSCharacterSet *)invertedSet { BOOL (^t)(unichar) = self.test; return [NSCharacterSet _with:^BOOL(unichar c) { return !t(c); }]; }
- (BOOL)characterIsMember:(unichar)c { return self.test ? self.test(c) : NO; }
/* isim: these sets are defined over UTF-16 code units, so supplementary-plane scalars are not members */
- (BOOL)longCharacterIsMember:(UTF32Char)c { return c <= 0xFFFF ? [self characterIsMember:(unichar)c] : NO; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation NSMutableCharacterSet
- (void)addCharactersInString:(NSString *)s { NSCharacterSet *o = [NSCharacterSet characterSetWithCharactersInString:s]; [self formUnionWithCharacterSet:o]; }
- (void)removeCharactersInString:(NSString *)s {
    BOOL (^t)(unichar) = self.test; NSCharacterSet *o = [NSCharacterSet characterSetWithCharactersInString:s];
    self.test = ^BOOL(unichar c) { return (t ? t(c) : NO) && ![o characterIsMember:c]; };
}
- (void)formUnionWithCharacterSet:(NSCharacterSet *)o { BOOL (^t)(unichar) = self.test; self.test = ^BOOL(unichar c) { return (t ? t(c) : NO) || [o characterIsMember:c]; }; }
- (id)copyWithZone:(NSZone *)z { return [NSCharacterSet _with:self.test]; }
@end

@implementation NSString (NSCharacterSetAdditions)
- (NSString *)stringByTrimmingCharactersInSet:(NSCharacterSet *)set {
    NSUInteger n = self.length, a = 0, b = n;
    while (a < n && [set characterIsMember:[self characterAtIndex:a]]) a++;
    while (b > a && [set characterIsMember:[self characterAtIndex:b - 1]]) b--;
    return [self substringWithRange:NSMakeRange(a, b - a)];
}
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set {
    for (NSUInteger i = 0; i < self.length; i++) if ([set characterIsMember:[self characterAtIndex:i]]) return NSMakeRange(i, 1);
    return NSMakeRange(NSNotFound, 0);
}
- (NSArray<NSString *> *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)set {
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger start = 0, n = self.length;
    for (NSUInteger i = 0; i <= n; i++)
        if (i == n || [set characterIsMember:[self characterAtIndex:i]]) { [out addObject:[self substringWithRange:NSMakeRange(start, i - start)]]; start = i + 1; }
    return out;
}
@end
