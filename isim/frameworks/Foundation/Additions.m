/* isim Foundation (ARC): Objective-C methods that binary SDKs built against Apple's SDK call (found with
 * ISIM_OBJC_AUDIT=1 on Google Mobile Ads): URL and path helpers, percent encoding, file-system URLs, bundle resource
 * URLs, NSValue with arbitrary bytes, dictionary initializers and description variants. */
#import <Foundation/Foundation.h>
/* Foundation implements the iOS 18 / 26 calendar units it declares */
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#include "isim_locale.h"
#include <ctype.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <stdarg.h>

/* ---------------- URLs and percent encoding ---------------- */
static NSCharacterSet *chars(NSString *extra) {
    static NSString *base = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
    return [NSCharacterSet characterSetWithCharactersInString:[base stringByAppendingString:extra]];
}
/* system notifications isim does not post yet: the clock and the calendar day of the simulated device do not jump, and
   bundles are not loaded dynamically */
NSNotificationName const NSSystemClockDidChangeNotification = @"NSSystemClockDidChangeNotification",
    NSCalendarDayChangedNotification = @"NSCalendarDayChangedNotification", NSBundleDidLoadNotification = @"NSBundleDidLoadNotification";

@implementation NSCharacterSet (NSURLUtilities)
+ (NSCharacterSet *)URLUserAllowedCharacterSet { return chars(@"!$&'()*+,;="); }
+ (NSCharacterSet *)URLPasswordAllowedCharacterSet { return chars(@"!$&'()*+,;="); }
+ (NSCharacterSet *)URLHostAllowedCharacterSet { return chars(@"!$&'()*+,;=:[]"); }
+ (NSCharacterSet *)URLPathAllowedCharacterSet { return chars(@"!$&'()*+,;=:@/"); }
+ (NSCharacterSet *)URLQueryAllowedCharacterSet { return chars(@"!$&'()*+,;=:@/?"); }
+ (NSCharacterSet *)URLFragmentAllowedCharacterSet { return chars(@"!$&'()*+,;=:@/?"); }
@end

@implementation NSString (NSURLUtilities)
- (NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)allowed {
    NSData *utf8 = [self dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char *b = utf8.bytes;
    NSMutableString *out = [NSMutableString stringWithCapacity:utf8.length];
    for (NSUInteger i = 0; i < utf8.length; i++) {
        if (b[i] < 0x80 && [allowed characterIsMember:b[i]]) [out appendFormat:@"%c", b[i]];
        else [out appendFormat:@"%%%02X", b[i]];
    }
    return out;
}
/* nil when a percent sequence is malformed or the bytes are not UTF-8, like Apple's */
- (NSString *)stringByRemovingPercentEncoding {
    NSData *utf8 = [self dataUsingEncoding:NSUTF8StringEncoding];
    const char *b = utf8.bytes;
    NSMutableData *out = [NSMutableData dataWithCapacity:utf8.length];
    for (NSUInteger i = 0; i < utf8.length; i++) {
        char c = b[i];
        if (c == '%') {
            if (i + 2 >= utf8.length || !isxdigit((unsigned char)b[i + 1]) || !isxdigit((unsigned char)b[i + 2])) return nil;
            char hex[3] = { b[i + 1], b[i + 2], 0 };
            c = (char)strtol(hex, NULL, 16);
            i += 2;
        }
        [out appendBytes:&c length:1];
    }
    return [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
}
- (instancetype)initWithContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)enc error:(NSError **)error {
    NSString *s = [NSString stringWithContentsOfURL:url encoding:enc error:error];
    return s ? [self initWithString:s] : nil;
}
- (instancetype)initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error {
    NSString *s = [NSString stringWithContentsOfFile:path encoding:enc error:error];
    return s ? [self initWithString:s] : nil;
}
@end

@implementation NSMutableString (IsimReplace)
- (NSUInteger)replaceOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSStringCompareOptions)options range:(NSRange)range {
    if (NSMaxRange(range) > self.length) [NSException raise:NSRangeException format:@"-[NSMutableString replaceOccurrencesOfString:withString:options:range:]: range out of bounds"];
    NSUInteger count = 0, pos = range.location, end = NSMaxRange(range);
    while (pos <= end && target.length) {
        NSRange r = [self rangeOfString:target options:options & ~NSBackwardsSearch range:NSMakeRange(pos, end - pos)];
        if (r.location == NSNotFound) break;
        [self replaceCharactersInRange:r withString:replacement];
        end = end - r.length + replacement.length;
        pos = r.location + replacement.length;
        count++;
        if (options & NSAnchoredSearch) break;
    }
    return count;
}
@end

@implementation NSURL (IsimAdditions)
+ (instancetype)URLWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encode {
    NSURL *u = [self URLWithString:string];
    if (u || !encode) return u;
    NSMutableCharacterSet *ok = [NSMutableCharacterSet new];
    [ok formUnionWithCharacterSet:[NSCharacterSet URLQueryAllowedCharacterSet]];
    [ok addCharactersInString:@"#%[]"];
    return [self URLWithString:[string stringByAddingPercentEncodingWithAllowedCharacters:ok]];
}
- (NSURL *)URLByAppendingPathComponent:(NSString *)component isDirectory:(BOOL)isDirectory {
    NSURL *u = [self URLByAppendingPathComponent:component];
    return isDirectory && ![u.absoluteString hasSuffix:@"/"] ? [NSURL URLWithString:[u.absoluteString stringByAppendingString:@"/"]] : u;
}
- (NSURL *)URLByAppendingPathExtension:(NSString *)ext {
    if (self.isFileURL) return [NSURL fileURLWithPath:[self.path stringByAppendingPathExtension:ext]];
    NSURLComponents *c = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
    c.path = [c.path stringByAppendingPathExtension:ext];
    return c.URL;
}
@end

@implementation NSFileManager (IsimURLs)
- (NSURL *)URLForDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domain
         appropriateForURL:(NSURL *)url create:(BOOL)create error:(NSError **)error {
    NSURL *u = [self URLsForDirectory:directory inDomains:domain].firstObject;
    if (!u) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        return nil;
    }
    if (create && ![self createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:error])
        return nil;
    return u;
}
@end

@implementation NSBundle (IsimURLs)
@dynamic bundleURL, resourceURL;                 /* implemented in NSBundle (IsimMore), below */
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext {
    NSString *p = [self pathForResource:name ofType:ext];
    return p ? [NSURL fileURLWithPath:p] : nil;
}
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext subdirectory:(NSString *)subpath {
    NSString *p = [self pathForResource:name ofType:ext inDirectory:subpath forLocalization:nil];
    return p ? [NSURL fileURLWithPath:p] : nil;
}
@end

@implementation NSData (IsimURLs)
- (instancetype)initWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)options error:(NSError **)error {
    NSData *d = [NSData dataWithContentsOfURL:url options:options error:error];
    return d ? [self initWithData:d] : nil;
}
@end

/* ---------------- collections ---------------- */
@implementation NSDictionary (IsimInitializers)
- (instancetype)initWithObjects:(NSArray *)objects forKeys:(NSArray *)keys {
    if (objects.count != keys.count) [NSException raise:NSInvalidArgumentException format:@"-[NSDictionary initWithObjects:forKeys:]: count of objects (%lu) differs from count of keys (%lu)", (unsigned long)objects.count, (unsigned long)keys.count];
    NSUInteger n = objects.count;
    __unsafe_unretained id *o = (__unsafe_unretained id *)calloc(n ?: 1, sizeof(id)), *k = (__unsafe_unretained id *)calloc(n ?: 1, sizeof(id));
    for (NSUInteger i = 0; i < n; i++) { o[i] = objects[i]; k[i] = keys[i]; }
    self = [self initWithObjects:o forKeys:(id<NSCopying> __unsafe_unretained *)k count:n];
    free(o); free(k);
    return self;
}
- (instancetype)initWithDictionary:(NSDictionary *)other copyItems:(BOOL)copy {
    if (!copy) return [self initWithDictionary:other];
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:other.count], *vals = [NSMutableArray arrayWithCapacity:other.count];
    [other enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) { [keys addObject:k]; [vals addObject:[v copy]]; }];
    return [self initWithObjects:vals forKeys:keys];
}
- (NSString *)descriptionWithLocale:(id)locale { return self.description; }
- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level { return self.description; }
@end
@implementation NSArray (IsimDescription)
- (NSString *)descriptionWithLocale:(id)locale { return self.description; }
- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level { return self.description; }
@end
@implementation NSSet (IsimDescription)
- (NSString *)descriptionWithLocale:(id)locale { return self.description; }
@end

/* ---------------- NSValue with any bytes ---------------- */
@interface _ISIMBytesValue : NSValue
@end
@implementation _ISIMBytesValue { NSData *_bytes; NSString *_type; }
- (instancetype)initWithBytes:(const void *)value objCType:(const char *)type {
    NSUInteger size = 0;
    NSGetSizeAndAlignment(type, &size, NULL);
    if ((self = [super init])) { _bytes = [NSData dataWithBytes:value length:size]; _type = @(type); }
    return self;
}
- (const char *)objCType { return _type.UTF8String; }
- (void)getValue:(void *)value { memcpy(value, _bytes.bytes, _bytes.length); }
- (void)getValue:(void *)value size:(NSUInteger)size { memcpy(value, _bytes.bytes, MIN(size, _bytes.length)); }
- (void *)pointerValue { void *p = NULL; memcpy(&p, _bytes.bytes, MIN(sizeof p, _bytes.length)); return p; }
- (BOOL)isEqualToValue:(NSValue *)o {
    return [o isKindOfClass:[_ISIMBytesValue class]] && [_type isEqualToString:@(o.objCType)] && [_bytes isEqual:((_ISIMBytesValue *)o)->_bytes];
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSValue class]] && [self isEqualToValue:o]; }
- (NSUInteger)hash { return _bytes.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@>", _bytes.description]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

/* the values NSValue's own kinds hold, as bytes (CGPoint, CGSize, CGRect, NSRange, pointers) */
static BOOL builtin_bytes(NSValue *v, void *out, NSUInteger size) {
    const char *t = v.objCType;
    #define COPY(x) do { __typeof__(x) _x = (x); memcpy(out, &_x, MIN(size, sizeof _x)); return YES; } while (0)
    if (!strcmp(t, "{_NSRange=QQ}")) COPY(v.rangeValue);
    if (!strcmp(t, "{CGPoint=dd}")) COPY(v.CGPointValue);
    if (!strcmp(t, "{CGSize=dd}")) COPY(v.CGSizeValue);
    if (!strcmp(t, "{CGRect={CGPoint=dd}{CGSize=dd}}")) COPY(v.CGRectValue);
    if (!strcmp(t, "^v") || !strcmp(t, "@")) COPY(v.pointerValue);
    if ([v isKindOfClass:[NSNumber class]] && t[0] && !t[1]) {
        NSNumber *n = (NSNumber *)v;
        switch (t[0]) {
        case 'c': COPY((char)n.intValue); case 'C': COPY((unsigned char)n.unsignedIntValue); case 's': COPY((short)n.intValue);
        case 'S': COPY((unsigned short)n.unsignedIntValue); case 'i': COPY(n.intValue); case 'I': COPY(n.unsignedIntValue);
        case 'l': COPY(n.longValue); case 'L': COPY(n.unsignedLongValue); case 'q': COPY(n.longLongValue);
        case 'Q': COPY(n.unsignedLongLongValue); case 'f': COPY(n.floatValue); case 'd': COPY(n.doubleValue);
        case 'B': COPY(n.boolValue);
        }
    }
    #undef COPY
    return NO;
}
@implementation NSValue (IsimBytes)
+ (NSValue *)valueWithBytes:(const void *)value objCType:(const char *)type { return [[_ISIMBytesValue alloc] initWithBytes:value objCType:type]; }
+ (NSValue *)value:(const void *)value withObjCType:(const char *)type { return [self valueWithBytes:value objCType:type]; }
- (instancetype)initWithBytes:(const void *)value objCType:(const char *)type { return (id)[[_ISIMBytesValue alloc] initWithBytes:value objCType:type]; }
- (void)getValue:(void *)value size:(NSUInteger)size { builtin_bytes(self, value, size); }
- (void)getValue:(void *)value {
    NSUInteger size = 0;
    NSGetSizeAndAlignment(self.objCType, &size, NULL);
    builtin_bytes(self, value, size);
}
@end

/* ---------------- more of Apple's Objective-C API (found with a runtime probe of commonly used selectors) ---------------- */
@implementation NSArray (IsimMore)
- (instancetype)initWithArray:(NSArray *)array copyItems:(BOOL)copy {
    if (!copy) return [self initWithArray:array];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:array.count];
    for (id o in array) [items addObject:[o copy]];
    return [self initWithArray:items];
}
- (void)getObjects:(id __unsafe_unretained *)objects range:(NSRange)range {
    for (NSUInteger i = 0; i < range.length; i++) objects[i] = self[range.location + i];
}
+ (instancetype)arrayWithContentsOfURL:(NSURL *)url {
    NSData *d = [NSData dataWithContentsOfURL:url];
    id p = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    return [p isKindOfClass:[NSArray class]] ? [self arrayWithArray:p] : nil;
}
+ (instancetype)arrayWithContentsOfFile:(NSString *)path { return [self arrayWithContentsOfURL:[NSURL fileURLWithPath:path]]; }
@end

@implementation NSDictionary (IsimMore)
+ (instancetype)dictionaryWithContentsOfURL:(NSURL *)url {
    NSData *d = [NSData dataWithContentsOfURL:url];
    id p = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    return [p isKindOfClass:[NSDictionary class]] ? [self dictionaryWithDictionary:p] : nil;
}
+ (id)sharedKeySetForKeys:(NSArray *)keys { return [keys copy]; }
@end
@implementation NSMutableDictionary (IsimMore)
+ (instancetype)dictionaryWithSharedKeySet:(id)keyset { return [self dictionary]; }
@end

@implementation NSSet (IsimMore)
- (instancetype)initWithSet:(NSSet *)set { return [self initWithArray:set.allObjects]; }
- (instancetype)initWithSet:(NSSet *)set copyItems:(BOOL)copy {
    if (!copy) return [self initWithSet:set];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:set.count];
    for (id o in set) [items addObject:[o copy]];
    return [self initWithArray:items];
}
+ (instancetype)setWithSet:(NSSet *)set { return [[self alloc] initWithSet:set]; }
@end
@implementation NSMutableSet (IsimMore)
- (instancetype)initWithCapacity:(NSUInteger)n { return [self init]; }
@end

@implementation NSString (NSStringExtras)
- (BOOL)getCString:(char *)buffer maxLength:(NSUInteger)max encoding:(NSStringEncoding)enc {
    NSData *d = [self dataUsingEncoding:enc];
    if (!d || d.length + 1 > max) return NO;
    memcpy(buffer, d.bytes, d.length);
    buffer[d.length] = 0;
    return YES;
}
- (NSUInteger)maximumLengthOfBytesUsingEncoding:(NSStringEncoding)enc { return self.length * (enc == NSUTF8StringEncoding ? 3 : 4); }
- (BOOL)canBeConvertedToEncoding:(NSStringEncoding)enc { return [self dataUsingEncoding:enc] != nil; }
- (instancetype)initWithCString:(const char *)s encoding:(NSStringEncoding)enc { return s ? [self initWithBytes:s length:strlen(s) encoding:enc] : nil; }
- (instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)len encoding:(NSStringEncoding)enc freeWhenDone:(BOOL)freeBuffer {
    self = [self initWithBytes:bytes length:len encoding:enc];
    if (freeBuffer) free(bytes);
    return self;
}
- (instancetype)initWithFormat:(NSString *)format locale:(id)locale, ... {
    va_list ap; va_start(ap, locale);
    self = [self initWithFormat:format arguments:ap];
    va_end(ap);
    return self;
}
+ (instancetype)localizedStringWithFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format);
    NSString *s = [[self alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return s;
}
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)mask {
    NSUInteger n = self.length;
    if (mask & NSBackwardsSearch) {
        for (NSUInteger i = n; i > 0; i--) if ([set characterIsMember:[self characterAtIndex:i - 1]]) return NSMakeRange(i - 1, 1);
    } else for (NSUInteger i = 0; i < n; i++) if ([set characterIsMember:[self characterAtIndex:i]]) return NSMakeRange(i, 1);
    return NSMakeRange(NSNotFound, 0);
}
- (NSString *)stringByAddingPercentEscapesUsingEncoding:(NSStringEncoding)enc {
    NSMutableCharacterSet *ok = [NSMutableCharacterSet new];
    [ok formUnionWithCharacterSet:[NSCharacterSet URLQueryAllowedCharacterSet]];
    [ok addCharactersInString:@"#"];
    return [self stringByAddingPercentEncodingWithAllowedCharacters:ok];
}
- (NSString *)stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)enc { return self.stringByRemovingPercentEncoding; }
+ (NSStringEncoding)defaultCStringEncoding { return NSUTF8StringEncoding; }
- (instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)len encoding:(NSStringEncoding)enc deallocator:(void (^)(void *, NSUInteger))dealloc {
    self = [self initWithBytes:bytes length:len encoding:enc];
    if (dealloc) dealloc(bytes, len);
    return self;
}
- (instancetype)initWithCharactersNoCopy:(unichar *)chars length:(NSUInteger)len freeWhenDone:(BOOL)freeBuffer {
    self = [self initWithBytes:chars length:len * sizeof(unichar) encoding:NSUTF16LittleEndianStringEncoding];
    if (freeBuffer) free(chars);
    return self;
}
- (instancetype)initWithCharactersNoCopy:(unichar *)chars length:(NSUInteger)len deallocator:(void (^)(unichar *, NSUInteger))dealloc {
    self = [self initWithBytes:chars length:len * sizeof(unichar) encoding:NSUTF16LittleEndianStringEncoding];
    if (dealloc) dealloc(chars, len);
    return self;
}
/* the encoding the data decodes in: UTF-8 (or a BOM's), else Windows-1252 */
static NSStringEncoding str_detect(NSData *d, NSString **out) {
    const unsigned char *b = d.bytes;
    if (d.length >= 2 && ((b[0] == 0xFF && b[1] == 0xFE) || (b[0] == 0xFE && b[1] == 0xFF))) {
        *out = [[NSString alloc] initWithData:d encoding:NSUTF16StringEncoding]; if (*out) return NSUTF16StringEncoding;
    }
    if ((*out = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding])) return NSUTF8StringEncoding;
    if ((*out = [[NSString alloc] initWithData:d encoding:NSWindowsCP1252StringEncoding])) return NSWindowsCP1252StringEncoding;
    *out = [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
    return *out ? NSISOLatin1StringEncoding : 0;
}
- (instancetype)initWithContentsOfURL:(NSURL *)url usedEncoding:(NSStringEncoding *)enc error:(NSError **)error {
    NSData *d = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!d) return nil;
    NSString *s; NSStringEncoding e = str_detect(d, &s);
    if (!s) { if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownStringEncodingError userInfo:nil]; return nil; }
    if (enc) *enc = e;
    return [self initWithString:s];
}
- (instancetype)initWithContentsOfFile:(NSString *)path usedEncoding:(NSStringEncoding *)enc error:(NSError **)error {
    return [self initWithContentsOfURL:[NSURL fileURLWithPath:path] usedEncoding:enc error:error];
}
- (instancetype)initWithFormat:(NSString *)format locale:(id)locale arguments:(va_list)args { return [self initWithFormat:format arguments:args]; }
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)mask range:(NSRange)r {
    BOOL anchored = (mask & NSAnchoredSearch) != 0;
    if (mask & NSBackwardsSearch) {
        for (NSUInteger i = NSMaxRange(r); i > r.location; i--) {
            if ([set characterIsMember:[self characterAtIndex:i - 1]]) return NSMakeRange(i - 1, 1);
            if (anchored) break;
        }
    } else for (NSUInteger i = r.location; i < NSMaxRange(r); i++) {
        if ([set characterIsMember:[self characterAtIndex:i]]) return NSMakeRange(i, 1);
        if (anchored) break;
    }
    return NSMakeRange(NSNotFound, 0);
}
- (NSRange)rangeOfComposedCharacterSequencesForRange:(NSRange)r {
    if (r.length == 0) return [self rangeOfComposedCharacterSequenceAtIndex:r.location];
    NSRange a = [self rangeOfComposedCharacterSequenceAtIndex:r.location], b = [self rangeOfComposedCharacterSequenceAtIndex:NSMaxRange(r) - 1];
    return NSUnionRange(a, b);
}
- (void)getCharacters:(unichar *)buffer { [self getCharacters:buffer range:NSMakeRange(0, self.length)]; }
- (BOOL)getBytes:(void *)buffer maxLength:(NSUInteger)max usedLength:(NSUInteger *)used encoding:(NSStringEncoding)enc options:(NSStringEncodingConversionOptions)opts range:(NSRange)r remainingRange:(NSRangePointer)left {
    NSUInteger n = 0, i = r.location;
    char *out = buffer;
    BOOL lossy = (opts & NSStringEncodingConversionAllowLossy) != 0;
    while (i < NSMaxRange(r)) {
        NSRange c = [self rangeOfComposedCharacterSequenceAtIndex:i];
        NSData *d = [[self substringWithRange:c] dataUsingEncoding:enc allowLossyConversion:lossy];
        if (!d || n + d.length > max) break;
        if (out) memcpy(out + n, d.bytes, d.length);
        n += d.length; i = NSMaxRange(c);
    }
    if (used) *used = n;
    if (left) *left = NSMakeRange(i, NSMaxRange(r) - i);
    return i > r.location || r.length == 0;
}
- (void)getLineStart:(NSUInteger *)start end:(NSUInteger *)end contentsEnd:(NSUInteger *)contentsEnd forRange:(NSRange)r {
    NSRange line = [self lineRangeForRange:r];
    if (start) *start = line.location;
    if (end) *end = NSMaxRange(line);
    if (contentsEnd) {
        NSUInteger e = NSMaxRange(line);
        while (e > line.location && [[NSCharacterSet newlineCharacterSet] characterIsMember:[self characterAtIndex:e - 1]]) e--;
        *contentsEnd = e;
    }
}
- (void)getParagraphStart:(NSUInteger *)start end:(NSUInteger *)end contentsEnd:(NSUInteger *)contentsEnd forRange:(NSRange)r {
    NSRange p = [self paragraphRangeForRange:r];
    if (start) *start = p.location;
    if (end) *end = NSMaxRange(p);
    if (contentsEnd) {
        NSUInteger e = NSMaxRange(p);
        while (e > p.location && [[NSCharacterSet newlineCharacterSet] characterIsMember:[self characterAtIndex:e - 1]]) e--;
        *contentsEnd = e;
    }
}
- (NSArray<NSString *> *)stringsByAppendingPaths:(NSArray<NSString *> *)paths {
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *p in paths) [a addObject:[self stringByAppendingPathComponent:p]];
    return a;
}
- (NSString *)stringByAbbreviatingWithTildeInPath {
    NSString *home = NSHomeDirectory(), *path = self.stringByStandardizingPath;
    if ([path isEqualToString:home]) return @"~";
    if ([path hasPrefix:[home stringByAppendingString:@"/"]]) return [@"~" stringByAppendingString:[path substringFromIndex:home.length]];
    return self;
}
/* NFKD / NFKC: the canonical mappings after the compatibility decompositions the Unicode tables give (through ICU's transforms) */
- (NSString *)decomposedStringWithCompatibilityMapping { return [self stringByApplyingTransform:@"Any-NFKD" reverse:NO] ?: self.decomposedStringWithCanonicalMapping; }
- (NSString *)precomposedStringWithCompatibilityMapping { return [self stringByApplyingTransform:@"Any-NFKC" reverse:NO] ?: self.precomposedStringWithCanonicalMapping; }
- (NSStringEncoding)fastestEncoding { return NSUnicodeStringEncoding; }
- (NSStringEncoding)smallestEncoding {
    if ([self canBeConvertedToEncoding:NSASCIIStringEncoding]) return NSASCIIStringEncoding;
    if ([self canBeConvertedToEncoding:NSISOLatin1StringEncoding]) return NSISOLatin1StringEncoding;
    return NSUTF8StringEncoding;
}
+ (const NSStringEncoding *)availableStringEncodings {
    static const NSStringEncoding list[] = { NSASCIIStringEncoding, NSNEXTSTEPStringEncoding, NSJapaneseEUCStringEncoding, NSUTF8StringEncoding,
        NSISOLatin1StringEncoding, NSNonLossyASCIIStringEncoding, NSUnicodeStringEncoding, NSWindowsCP1252StringEncoding, NSMacOSRomanStringEncoding,
        NSUTF16BigEndianStringEncoding, NSUTF16LittleEndianStringEncoding, NSUTF32StringEncoding, NSUTF32BigEndianStringEncoding,
        NSUTF32LittleEndianStringEncoding, 0 };
    return list;
}
+ (NSString *)localizedNameOfStringEncoding:(NSStringEncoding)e {
    switch (e) {
    case NSASCIIStringEncoding: return @"Western (ASCII)";
    case NSNEXTSTEPStringEncoding: return @"Western (NextStep)";
    case NSJapaneseEUCStringEncoding: return @"Japanese (EUC)";
    case NSUTF8StringEncoding: return @"Unicode (UTF-8)";
    case NSISOLatin1StringEncoding: return @"Western (ISO Latin 1)";
    case NSNonLossyASCIIStringEncoding: return @"Non-lossy ASCII";
    case NSUnicodeStringEncoding: return @"Unicode (UTF-16)";
    case NSWindowsCP1252StringEncoding: return @"Western (Windows Latin 1)";
    case NSMacOSRomanStringEncoding: return @"Western (Mac OS Roman)";
    case NSUTF16BigEndianStringEncoding: return @"Unicode (UTF-16BE)";
    case NSUTF16LittleEndianStringEncoding: return @"Unicode (UTF-16LE)";
    case NSUTF32StringEncoding: return @"Unicode (UTF-32)";
    case NSUTF32BigEndianStringEncoding: return @"Unicode (UTF-32BE)";
    case NSUTF32LittleEndianStringEncoding: return @"Unicode (UTF-32LE)";
    default: return @"";
    }
}
- (id)propertyList {
    NSData *d = [self dataUsingEncoding:NSUTF8StringEncoding];
    return d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
}
/* "key" = "value"; pairs (a .strings file): quoted or bare tokens, backslash escapes, block and line comments */
static NSString *strings_token(NSString *s, NSUInteger *i) {
    NSUInteger n = s.length;
    for (;;) {                                                  /* whitespace and comments */
        while (*i < n && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[s characterAtIndex:*i]]) (*i)++;
        if (*i + 1 < n && [s characterAtIndex:*i] == '/' && [s characterAtIndex:*i + 1] == '*') {
            NSRange e = [s rangeOfString:@"*/" options:0 range:NSMakeRange(*i + 2, n - *i - 2)];
            *i = e.location == NSNotFound ? n : NSMaxRange(e); continue;
        }
        if (*i + 1 < n && [s characterAtIndex:*i] == '/' && [s characterAtIndex:*i + 1] == '/') {
            while (*i < n && [s characterAtIndex:*i] != '\n') (*i)++;
            continue;
        }
        break;
    }
    if (*i >= n) return nil;
    unichar c = [s characterAtIndex:*i];
    if (c == '=' || c == ';') { (*i)++; return [NSString stringWithCharacters:&c length:1]; }
    NSMutableString *out = [NSMutableString string];
    if (c == '"') {
        for ((*i)++; *i < n; (*i)++) {
            unichar d = [s characterAtIndex:*i];
            if (d == '"') { (*i)++; return out; }
            if (d == '\\' && *i + 1 < n) {
                unichar e = [s characterAtIndex:++(*i)];
                unichar r = e == 'n' ? '\n' : e == 't' ? '\t' : e == 'r' ? '\r' : e;
                [out appendFormat:@"%C", r];
            } else [out appendFormat:@"%C", d];
        }
        return out;
    }
    while (*i < n) {
        unichar d = [s characterAtIndex:*i];
        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:d] || d == '=' || d == ';') break;
        [out appendFormat:@"%C", d]; (*i)++;
    }
    return out;
}
- (NSDictionary *)propertyListFromStringsFileFormat {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    NSUInteger i = 0;
    for (;;) {
        NSString *k = strings_token(self, &i);
        if (!k) return d;
        NSString *eq = strings_token(self, &i);
        if ([eq isEqualToString:@";"]) { d[k] = k; continue; }   /* "key"; means "key" = "key"; */
        if (![eq isEqualToString:@"="]) return nil;
        NSString *v = strings_token(self, &i), *semi = strings_token(self, &i);
        if (!v || ![semi isEqualToString:@";"]) return nil;
        d[k] = v;
    }
}
- (NSUInteger)completePathIntoString:(NSString **)outName caseSensitive:(BOOL)cs matchesIntoArray:(NSArray<NSString *> **)outArray filterTypes:(NSArray<NSString *> *)types {
    NSString *path = self.stringByExpandingTildeInPath;
    NSString *dir = [path hasSuffix:@"/"] ? path : path.stringByDeletingLastPathComponent, *prefix = [path hasSuffix:@"/"] ? @"" : path.lastPathComponent;
    if (!dir.length) dir = @".";
    NSMutableArray *matches = [NSMutableArray array];
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL]) {
        BOOL ok = cs ? [f hasPrefix:prefix] : [f.lowercaseString hasPrefix:prefix.lowercaseString];
        if (ok && types.count && ![types containsObject:f.pathExtension]) ok = NO;
        if (ok) [matches addObject:[dir stringByAppendingPathComponent:f]];
    }
    [matches sortUsingSelector:@selector(compare:)];
    if (outArray) *outArray = matches;
    if (outName && matches.count) {
        NSString *common = matches[0];
        for (NSString *m in matches) common = [common commonPrefixWithString:m options:cs ? 0 : NSCaseInsensitiveSearch];
        *outName = common;
    }
    return matches.count;
}
+ (NSStringEncoding)stringEncodingForData:(NSData *)data encodingOptions:(NSDictionary *)opts convertedString:(NSString **)string usedLossyConversion:(BOOL *)lossy {
    if (lossy) *lossy = NO;
    for (NSNumber *e in opts[NSStringEncodingDetectionSuggestedEncodingsKey]) {
        NSString *s = [[NSString alloc] initWithData:data encoding:e.unsignedIntegerValue];
        if (s) { if (string) *string = s; return e.unsignedIntegerValue; }
    }
    if ([opts[NSStringEncodingDetectionUseOnlySuggestedEncodingsKey] boolValue]) return 0;
    NSString *s; NSStringEncoding e = str_detect(data, &s);
    for (NSNumber *no in opts[NSStringEncodingDetectionDisallowedEncodingsKey]) if (no.unsignedIntegerValue == e) return 0;
    if (string) *string = s;
    return e;
}
@end
NSStringEncodingDetectionOptionsKey const NSStringEncodingDetectionSuggestedEncodingsKey = @"NSStringEncodingDetectionSuggestedEncodingsKey",
    NSStringEncodingDetectionDisallowedEncodingsKey = @"NSStringEncodingDetectionDisallowedEncodingsKey",
    NSStringEncodingDetectionUseOnlySuggestedEncodingsKey = @"NSStringEncodingDetectionUseOnlySuggestedEncodingsKey",
    NSStringEncodingDetectionAllowLossyKey = @"NSStringEncodingDetectionAllowLossyKey",
    NSStringEncodingDetectionFromWindowsKey = @"NSStringEncodingDetectionFromWindowsKey",
    NSStringEncodingDetectionLossySubstitutionKey = @"NSStringEncodingDetectionLossySubstitutionKey",
    NSStringEncodingDetectionLikelyLanguageKey = @"NSStringEncodingDetectionLikelyLanguageKey";

@implementation NSNumber (IsimMore)
- (unsigned short)unsignedShortValue { return (unsigned short)self.unsignedIntValue; }
- (NSString *)descriptionWithLocale:(id)locale { return self.description; }
@end

@implementation NSDate (NSDateCreation)
- (instancetype)initWithTimeIntervalSinceNow:(NSTimeInterval)s { return [self initWithTimeIntervalSinceReferenceDate:[NSDate date].timeIntervalSinceReferenceDate + s]; }
- (instancetype)initWithTimeIntervalSince1970:(NSTimeInterval)s { return [self initWithTimeIntervalSinceReferenceDate:s - 978307200.0]; }
- (instancetype)initWithTimeInterval:(NSTimeInterval)s sinceDate:(NSDate *)d { return [self initWithTimeIntervalSinceReferenceDate:d.timeIntervalSinceReferenceDate + s]; }
+ (instancetype)dateWithTimeInterval:(NSTimeInterval)s sinceDate:(NSDate *)d { return [[self alloc] initWithTimeInterval:s sinceDate:d]; }
+ (NSDate *)now { return [self date]; }
/* the full date and time in the locale (an NSLocale), like Date.description(with:) */
- (NSString *)descriptionWithLocale:(id)locale {
    if (![locale isKindOfClass:[NSLocale class]]) return self.description;
    NSDateFormatter *f = [NSDateFormatter new];
    f.locale = locale; f.dateStyle = NSDateFormatterFullStyle; f.timeStyle = NSDateFormatterFullStyle;
    return [f stringFromDate:self];
}
@end

@implementation NSURL (IsimMore)
- (NSURL *)absoluteURL { return self; }
- (NSURL *)baseURL { return nil; }
- (NSString *)password { return [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO].password; }
- (NSString *)relativePath { return self.path; }
- (NSString *)resourceSpecifier { NSString *s = self.absoluteString; NSRange r = [s rangeOfString:@":"]; return r.location == NSNotFound ? s : [s substringFromIndex:r.location + 1]; }
- (NSArray<NSString *> *)pathComponents { return self.path.pathComponents; }
- (const char *)fileSystemRepresentation { return self.path.fileSystemRepresentation; }
- (BOOL)hasDirectoryPath { return [self.absoluteString hasSuffix:@"/"]; }
- (NSURL *)URLByDeletingLastPathComponent {
    if (self.isFileURL) return [NSURL fileURLWithPath:self.path.stringByDeletingLastPathComponent isDirectory:YES];
    NSURLComponents *c = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
    NSString *p = c.path.stringByDeletingLastPathComponent;
    c.path = [p hasSuffix:@"/"] ? p : [p stringByAppendingString:@"/"];
    return c.URL;
}
- (NSURL *)URLByDeletingPathExtension {
    if (self.isFileURL) return [NSURL fileURLWithPath:self.path.stringByDeletingPathExtension];
    NSURLComponents *c = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
    c.path = c.path.stringByDeletingPathExtension;
    return c.URL;
}
- (NSURL *)URLByStandardizingPath { return self.isFileURL ? [NSURL fileURLWithPath:self.path.stringByStandardizingPath] : self; }
/* RFC 3986 dot-segment removal on the path ("a/./b/../c" -> "a/c"); a file URL keeps a trailing slash */
static NSString *remove_dot_segments(NSString *path) {
    NSMutableArray *out = [NSMutableArray array];
    NSArray *parts = [path componentsSeparatedByString:@"/"];
    for (NSUInteger i = 0; i < parts.count; i++) {
        NSString *p = parts[i];
        BOOL last = i + 1 == parts.count;
        if ([p isEqual:@"."]) { if (last) [out addObject:@""]; continue; }
        if ([p isEqual:@".."]) {
            if (out.count > 1 || (out.count == 1 && [out[0] length])) [out removeLastObject];
            if (last) [out addObject:@""];
            continue;
        }
        [out addObject:p];
    }
    return [out componentsJoinedByString:@"/"];
}
- (NSURL *)standardizedURL {
    NSString *s = self.absoluteString;
    if (!s) return self;
    // the path: after "scheme:" and "//authority", up to "?" or "#"
    NSRange colon = [s rangeOfString:@":"];
    NSUInteger start = colon.location == NSNotFound ? 0 : NSMaxRange(colon);
    if ([s length] >= start + 2 && [[s substringWithRange:NSMakeRange(start, 2)] isEqual:@"//"]) {
        NSRange slash = [s rangeOfString:@"/" options:0 range:NSMakeRange(start + 2, s.length - start - 2)];
        start = slash.location == NSNotFound ? s.length : slash.location;
    }
    NSUInteger stop = start;
    while (stop < s.length && [s characterAtIndex:stop] != '?' && [s characterAtIndex:stop] != '#') stop++;
    NSString *path = [s substringWithRange:NSMakeRange(start, stop - start)];
    if ([path rangeOfString:@"."].location == NSNotFound) return self;
    NSString *std = [NSString stringWithFormat:@"%@%@%@", [s substringToIndex:start], remove_dot_segments(path), [s substringFromIndex:stop]];
    return [NSURL URLWithString:std] ?: self;
}
- (BOOL)checkResourceIsReachableAndReturnError:(NSError **)error {
    if (self.isFileURL && [NSFileManager.defaultManager fileExistsAtPath:self.path]) return YES;
    if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:@{ NSURLErrorKey: self }];
    return NO;
}
- (instancetype)initWithString:(NSString *)s relativeToURL:(NSURL *)base { return (id)[NSURL URLWithString:s relativeToURL:base]; }
- (instancetype)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir { return (id)[NSURL fileURLWithPath:path isDirectory:isDir]; }
+ (NSURL *)fileURLWithPathComponents:(NSArray<NSString *> *)components { return components.count ? [NSURL fileURLWithPath:[NSString pathWithComponents:components]] : nil; }
@end

@implementation NSFileManager (IsimMore)
- (NSURL *)temporaryDirectory { return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]; }
@end

@implementation NSBundle (IsimMore)
- (NSURL *)bundleURL { return [NSURL fileURLWithPath:self.bundlePath isDirectory:YES]; }
- (NSURL *)resourceURL { return self.resourcePath ? [NSURL fileURLWithPath:self.resourcePath isDirectory:YES] : nil; }
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)sub { return [self pathForResource:name ofType:ext inDirectory:sub forLocalization:nil]; }
- (NSURL *)appStoreReceiptURL { return [self.bundleURL URLByAppendingPathComponent:@"StoreKit/receipt"]; }  /* none exists, like a development build */
+ (instancetype)bundleWithURL:(NSURL *)url { return [self bundleWithPath:url.path]; }
@end

@implementation NSUserDefaults (IsimMore)
- (NSData *)dataForKey:(NSString *)key { id o = [self objectForKey:key]; return [o isKindOfClass:[NSData class]] ? o : nil; }
- (NSArray<NSString *> *)stringArrayForKey:(NSString *)key {
    id o = [self objectForKey:key];
    if (![o isKindOfClass:[NSArray class]]) return nil;
    for (id s in o) if (![s isKindOfClass:[NSString class]]) return nil;
    return o;
}
- (float)floatForKey:(NSString *)key { return (float)[self doubleForKey:key]; }
- (void)setFloat:(float)v forKey:(NSString *)key { [self setDouble:v forKey:key]; }
- (NSURL *)URLForKey:(NSString *)key {
    id o = [self objectForKey:key];
    if ([o isKindOfClass:[NSURL class]]) return o;
    if ([o isKindOfClass:[NSString class]]) return [o hasPrefix:@"/"] ? [NSURL fileURLWithPath:o] : [NSURL URLWithString:o];
    return nil;
}
- (void)setURL:(NSURL *)url forKey:(NSString *)key { [self setObject:url.absoluteString forKey:key]; }
- (void)addSuiteNamed:(NSString *)name {}
- (void)removeSuiteNamed:(NSString *)name {}
- (NSDictionary *)persistentDomainForName:(NSString *)name { return self.dictionaryRepresentation; }
- (void)removePersistentDomainForName:(NSString *)name { for (NSString *k in self.dictionaryRepresentation) [self removeObjectForKey:k]; }
- (void)setPersistentDomain:(NSDictionary *)domain forName:(NSString *)name { [domain enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s) { [self setObject:v forKey:k]; }]; }
- (NSDictionary *)volatileDomainForName:(NSString *)name { return @{}; }
+ (void)resetStandardUserDefaults {}
@end

@implementation NSNotification (NSNotificationCreation)
+ (instancetype)notificationWithName:(NSNotificationName)name object:(id)object { return [self notificationWithName:name object:object userInfo:nil]; }
- (instancetype)initWithName:(NSNotificationName)name object:(id)object userInfo:(NSDictionary *)userInfo {
    return [[self class] notificationWithName:name object:object userInfo:userInfo];
}
@end

@implementation NSTimer (IsimMore)
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)t invocation:(NSInvocation *)inv repeats:(BOOL)repeats {
    [inv retainArguments];
    return [self scheduledTimerWithTimeInterval:t repeats:repeats block:^(NSTimer *timer) { [inv invoke]; }];
}
@end

@implementation NSTimeZone (NSTimeZoneNames)
- (BOOL)isDaylightSavingTime { return [self isDaylightSavingTimeForDate:[NSDate date]]; }
/* the zone's name through the date formatter's zone patterns, at a date in (or out of) daylight saving time */
- (NSString *)localizedName:(NSTimeZoneNameStyle)style locale:(NSLocale *)locale {
    static NSString *const patterns[] = { @"zzzz", @"z", @"zzzz", @"z", @"vvvv", @"v" };
    if ((NSUInteger)style >= 6) return nil;
    NSDate *jan = [NSDate dateWithTimeIntervalSince1970:1704067200], *jul = [NSDate dateWithTimeIntervalSince1970:1719792000];   /* 2024-01-01, 2024-07-01 */
    BOOL wantDST = style == NSTimeZoneNameStyleDaylightSaving || style == NSTimeZoneNameStyleShortDaylightSaving;
    NSDate *at = [self isDaylightSavingTimeForDate:jan] == wantDST ? jan : [self isDaylightSavingTimeForDate:jul] == wantDST ? jul : jan;
    NSLocale *l = locale ?: [NSLocale currentLocale];
    if (isim_icu_on()) {                                         /* CLDR's zone names ("Pacific Standard Time") */
        NSString *s = isim_icu_date_format_string(isim_icu_locale_id(l), self.name, patterns[style], at);
        if (s.length) return s;
    }
    NSDateFormatter *f = [NSDateFormatter new];
    f.locale = l; f.timeZone = self; f.dateFormat = patterns[style];
    return [f stringFromDate:at];
}
@end

/* NSCalendar arithmetic: the Gregorian calendar in the calendar's time zone (adapted: other calendars count as Gregorian) */
static struct tm cal_tm(NSCalendar *cal, NSDate *d) {
    time_t s = (time_t)floor(d.timeIntervalSince1970 + [cal.timeZone secondsFromGMTForDate:d]);
    struct tm tm; gmtime_r(&s, &tm);
    return tm;
}
static NSDate *cal_date(NSCalendar *cal, struct tm tm, double frac) {
    time_t local = timegm(&tm);
    NSDate *guess = [NSDate dateWithTimeIntervalSince1970:(double)local];
    NSInteger off = [cal.timeZone secondsFromGMTForDate:guess];
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:(double)(local - off) + frac];
    NSInteger off2 = [cal.timeZone secondsFromGMTForDate:d];
    return off2 == off ? d : [NSDate dateWithTimeIntervalSince1970:(double)(local - off2) + frac];
}
@implementation NSCalendar (NSCalendarCalculations)
- (NSDateComponents *)components:(NSCalendarUnit)units fromDate:(NSDate *)date {
    struct tm tm = cal_tm(self, date);
    NSDateComponents *c = [NSDateComponents new];
    if (units & NSCalendarUnitEra) c.era = 1;
    if (units & NSCalendarUnitYear) c.year = tm.tm_year + 1900;
    if (units & NSCalendarUnitMonth) c.month = tm.tm_mon + 1;
    if (units & NSCalendarUnitDay) c.day = tm.tm_mday;
    if (units & NSCalendarUnitHour) c.hour = tm.tm_hour;
    if (units & NSCalendarUnitMinute) c.minute = tm.tm_min;
    if (units & NSCalendarUnitSecond) c.second = tm.tm_sec;
    if (units & NSCalendarUnitNanosecond) c.nanosecond = (NSInteger)((date.timeIntervalSince1970 - floor(date.timeIntervalSince1970)) * 1e9);
    if (units & NSCalendarUnitWeekday) c.weekday = tm.tm_wday + 1;
    if (units & NSCalendarUnitWeekdayOrdinal) c.weekdayOrdinal = (tm.tm_mday - 1) / 7 + 1;
    if (units & NSCalendarUnitQuarter) c.quarter = tm.tm_mon / 3 + 1;
    if (units & NSCalendarUnitWeekOfYear) c.weekOfYear = (tm.tm_yday + 7 - ((tm.tm_wday + 8 - (NSInteger)self.firstWeekday) % 7)) / 7 + 1;
    if (units & NSCalendarUnitWeekOfMonth) c.weekOfMonth = (tm.tm_mday - 1 + ((tm.tm_wday - (tm.tm_mday - 1) % 7 + 7 - ((NSInteger)self.firstWeekday - 1)) % 7)) / 7 + 1;
    if (units & NSCalendarUnitYearForWeekOfYear) c.yearForWeekOfYear = tm.tm_year + 1900;
    if (units & NSCalendarUnitDayOfYear) c.dayOfYear = tm.tm_yday + 1;
    if (units & NSCalendarUnitCalendar) c.calendar = self;
    if (units & NSCalendarUnitTimeZone) c.timeZone = self.timeZone;
    return c;
}
- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate *)date { return [[self components:unit fromDate:date] valueForComponent:unit]; }
- (NSDate *)dateFromComponents:(NSDateComponents *)c {
    #define V(x, d) (c.x == NSDateComponentUndefined ? (d) : c.x)
    struct tm tm = { 0 };
    tm.tm_year = (int)V(year, 1) - 1900; tm.tm_mon = (int)V(month, 1) - 1; tm.tm_mday = (int)V(day, 1);
    tm.tm_hour = (int)V(hour, 0); tm.tm_min = (int)V(minute, 0); tm.tm_sec = (int)V(second, 0);
    double frac = c.nanosecond == NSDateComponentUndefined ? 0 : c.nanosecond / 1e9;
    #undef V
    NSCalendar *cal = self;
    if (c.timeZone) { cal = [self copy]; cal.timeZone = c.timeZone; }
    return cal_date(cal, tm, frac);
}
- (NSDate *)dateByAddingComponents:(NSDateComponents *)c toDate:(NSDate *)date options:(NSCalendarOptions)opts {
    struct tm tm = cal_tm(self, date);
    double frac = date.timeIntervalSince1970 - floor(date.timeIntervalSince1970);
    #define A(x) (c.x == NSDateComponentUndefined ? 0 : (int)c.x)
    tm.tm_year += A(year); tm.tm_mon += A(month) + 3 * A(quarter);
    int day = tm.tm_mday;
    if (A(year) || A(month) || A(quarter)) {                      /* clamp to the month's length (Jan 31 + 1 month = Feb 28) */
        struct tm probe = tm; probe.tm_mday = 1; probe.tm_mon += 1; time_t t = timegm(&probe) - 86400;
        struct tm last; gmtime_r(&t, &last);
        if (day > last.tm_mday) tm.tm_mday = last.tm_mday;
    }
    tm.tm_mday += A(day) + 7 * (A(weekOfYear) + A(weekOfMonth));
    tm.tm_hour += A(hour); tm.tm_min += A(minute); tm.tm_sec += A(second);
    frac += c.nanosecond == NSDateComponentUndefined ? 0 : c.nanosecond / 1e9;
    #undef A
    return cal_date(self, tm, frac);
}
- (NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSCalendarOptions)opts {
    NSDateComponents *c = [NSDateComponents new];
    [c setValue:value forComponent:unit];
    return [self dateByAddingComponents:c toDate:date options:opts];
}
- (NSDate *)startOfDayForDate:(NSDate *)date {
    struct tm tm = cal_tm(self, date);
    tm.tm_hour = tm.tm_min = tm.tm_sec = 0;
    return cal_date(self, tm, 0);
}
- (BOOL)isDate:(NSDate *)a inSameDayAsDate:(NSDate *)b { return [[self startOfDayForDate:a] isEqualToDate:[self startOfDayForDate:b]]; }
- (BOOL)isDateInToday:(NSDate *)date { return [self isDate:date inSameDayAsDate:[NSDate date]]; }
- (NSDateComponents *)components:(NSCalendarUnit)units fromDate:(NSDate *)from toDate:(NSDate *)to options:(NSCalendarOptions)opts {
    NSDateComponents *c = [NSDateComponents new];
    NSDate *cur = from;
    static const NSCalendarUnit order[] = { NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond };
    for (size_t k = 0; k < sizeof order / sizeof *order; k++) {
        NSCalendarUnit u = order[k];
        if (!(units & u)) continue;
        NSInteger n = 0, step = [to compare:cur] == NSOrderedAscending ? -1 : 1;
        for (;;) {
            NSDate *next = [self dateByAddingUnit:u value:n + step toDate:cur options:0];
            if (step > 0 ? [next compare:to] == NSOrderedDescending : [next compare:to] == NSOrderedAscending) break;
            n += step;
            if (labs(n) > 100000000) break;
        }
        [c setValue:n forComponent:u];
        cur = [self dateByAddingUnit:u value:n toDate:cur options:0];
    }
    return c;
}
- (NSRange)rangeOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date {
    if (smaller == NSCalendarUnitDay && larger == NSCalendarUnitMonth) {
        struct tm tm = cal_tm(self, date); tm.tm_mday = 1; tm.tm_mon += 1;
        time_t t = timegm(&tm) - 86400; struct tm last; gmtime_r(&t, &last);
        return NSMakeRange(1, (NSUInteger)last.tm_mday);
    }
    if (smaller == NSCalendarUnitMonth && larger == NSCalendarUnitYear) return NSMakeRange(1, 12);
    if (smaller == NSCalendarUnitHour && larger == NSCalendarUnitDay) return NSMakeRange(0, 24);
    if ((smaller == NSCalendarUnitMinute && larger == NSCalendarUnitHour) || (smaller == NSCalendarUnitSecond && larger == NSCalendarUnitMinute)) return NSMakeRange(0, 60);
    if (smaller == NSCalendarUnitWeekday && larger == NSCalendarUnitWeekOfYear) return NSMakeRange(1, 7);
    if (smaller == NSCalendarUnitDay && larger == NSCalendarUnitYear) {
        NSInteger y = [self component:NSCalendarUnitYear fromDate:date];
        return NSMakeRange(1, (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 366 : 365);
    }
    return NSMakeRange(NSNotFound, NSNotFound);
}
@end

/* NSCalendar: the rest of the arithmetic (adapted: the Gregorian calendar in the calendar's time zone) */
static NSInteger cal_days_in_month(NSInteger y, NSInteger m) {
    static const int d[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    BOOL leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
    return m == 2 && leap ? 29 : d[(m - 1 + 12) % 12];
}
static const NSCalendarUnit CAL_FIELDS[] = { NSCalendarUnitEra, NSCalendarUnitYear, NSCalendarUnitQuarter, NSCalendarUnitMonth, NSCalendarUnitWeekOfYear,
    NSCalendarUnitWeekOfMonth, NSCalendarUnitDay, NSCalendarUnitDayOfYear, NSCalendarUnitWeekday, NSCalendarUnitWeekdayOrdinal, NSCalendarUnitYearForWeekOfYear,
    NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond, NSCalendarUnitNanosecond };
@implementation NSCalendar (NSCalendarCalculationsMore)
- (NSRange)minimumRangeOfUnit:(NSCalendarUnit)u {
    switch (u) {
    case NSCalendarUnitEra: return NSMakeRange(0, 2);
    case NSCalendarUnitYear: case NSCalendarUnitYearForWeekOfYear: return NSMakeRange(1, 140742);
    case NSCalendarUnitQuarter: return NSMakeRange(1, 4);
    case NSCalendarUnitMonth: return NSMakeRange(1, 12);
    case NSCalendarUnitDay: return NSMakeRange(1, 28);
    case NSCalendarUnitDayOfYear: return NSMakeRange(1, 365);
    case NSCalendarUnitWeekday: return NSMakeRange(1, 7);
    case NSCalendarUnitWeekdayOrdinal: return NSMakeRange(1, 4);
    case NSCalendarUnitWeekOfMonth: return NSMakeRange(1, 4);
    case NSCalendarUnitWeekOfYear: return NSMakeRange(1, 52);
    case NSCalendarUnitHour: return NSMakeRange(0, 24);
    case NSCalendarUnitMinute: case NSCalendarUnitSecond: return NSMakeRange(0, 60);
    case NSCalendarUnitNanosecond: return NSMakeRange(0, 1000000000);
    default: return NSMakeRange(NSNotFound, NSNotFound);
    }
}
- (NSRange)maximumRangeOfUnit:(NSCalendarUnit)u {
    switch (u) {
    case NSCalendarUnitYear: case NSCalendarUnitYearForWeekOfYear: return NSMakeRange(1, 144683);
    case NSCalendarUnitDay: return NSMakeRange(1, 31);
    case NSCalendarUnitDayOfYear: return NSMakeRange(1, 366);
    case NSCalendarUnitWeekdayOrdinal: return NSMakeRange(1, 5);
    case NSCalendarUnitWeekOfMonth: return NSMakeRange(1, 6);
    case NSCalendarUnitWeekOfYear: return NSMakeRange(1, 53);
    default: return [self minimumRangeOfUnit:u];
    }
}
/* the start and length of the unit holding `date` */
- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate **)datep interval:(NSTimeInterval *)tip forDate:(NSDate *)date {
    struct tm tm = cal_tm(self, date);
    NSDate *start = nil, *end = nil;
    switch (unit) {
    case NSCalendarUnitEra: start = [NSDate distantPast]; end = [NSDate distantFuture]; break;
    case NSCalendarUnitYear: case NSCalendarUnitYearForWeekOfYear:
        tm.tm_mon = 0; tm.tm_mday = 1; tm.tm_hour = tm.tm_min = tm.tm_sec = 0; start = cal_date(self, tm, 0);
        tm.tm_year += 1; end = cal_date(self, tm, 0); break;
    case NSCalendarUnitQuarter:
        tm.tm_mon -= tm.tm_mon % 3; tm.tm_mday = 1; tm.tm_hour = tm.tm_min = tm.tm_sec = 0; start = cal_date(self, tm, 0);
        tm.tm_mon += 3; end = cal_date(self, tm, 0); break;
    case NSCalendarUnitMonth:
        tm.tm_mday = 1; tm.tm_hour = tm.tm_min = tm.tm_sec = 0; start = cal_date(self, tm, 0);
        tm.tm_mon += 1; end = cal_date(self, tm, 0); break;
    case NSCalendarUnitWeekOfYear: case NSCalendarUnitWeekOfMonth: {
        int back = (tm.tm_wday + 1 - (int)self.firstWeekday + 7) % 7;
        tm.tm_mday -= back; tm.tm_hour = tm.tm_min = tm.tm_sec = 0; start = cal_date(self, tm, 0);
        tm.tm_mday += 7; end = cal_date(self, tm, 0); break;
    }
    case NSCalendarUnitDay: case NSCalendarUnitWeekday: case NSCalendarUnitWeekdayOrdinal: case NSCalendarUnitDayOfYear:
        tm.tm_hour = tm.tm_min = tm.tm_sec = 0; start = cal_date(self, tm, 0);
        tm.tm_mday += 1; end = cal_date(self, tm, 0); break;
    case NSCalendarUnitHour: { double t = floor(date.timeIntervalSince1970 / 3600) * 3600; start = [NSDate dateWithTimeIntervalSince1970:t]; end = [start dateByAddingTimeInterval:3600]; break; }
    case NSCalendarUnitMinute: { double t = floor(date.timeIntervalSince1970 / 60) * 60; start = [NSDate dateWithTimeIntervalSince1970:t]; end = [start dateByAddingTimeInterval:60]; break; }
    case NSCalendarUnitSecond: { double t = floor(date.timeIntervalSince1970); start = [NSDate dateWithTimeIntervalSince1970:t]; end = [start dateByAddingTimeInterval:1]; break; }
    case NSCalendarUnitNanosecond: start = date; end = [date dateByAddingTimeInterval:1e-9]; break;
    default: return NO;
    }
    if (datep) *datep = start;
    if (tip) *tip = [end timeIntervalSinceDate:start];
    return YES;
}
- (NSUInteger)ordinalityOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date {
    struct tm tm = cal_tm(self, date);
    if (smaller == NSCalendarUnitWeekday && (larger == NSCalendarUnitWeekOfYear || larger == NSCalendarUnitWeekOfMonth))
        return (NSUInteger)((tm.tm_wday + 1 - (int)self.firstWeekday + 7) % 7 + 1);
    if (smaller == NSCalendarUnitDay && larger == NSCalendarUnitMonth) return (NSUInteger)tm.tm_mday;
    if (smaller == NSCalendarUnitDay && larger == NSCalendarUnitYear) return (NSUInteger)tm.tm_yday + 1;
    if (smaller == NSCalendarUnitMonth && larger == NSCalendarUnitYear) return (NSUInteger)tm.tm_mon + 1;
    if (smaller == NSCalendarUnitMonth && larger == NSCalendarUnitQuarter) return (NSUInteger)tm.tm_mon % 3 + 1;
    if (smaller == NSCalendarUnitQuarter && larger == NSCalendarUnitYear) return (NSUInteger)tm.tm_mon / 3 + 1;
    if (smaller == NSCalendarUnitHour && larger == NSCalendarUnitDay) return (NSUInteger)tm.tm_hour + 1;
    if (smaller == NSCalendarUnitMinute && larger == NSCalendarUnitHour) return (NSUInteger)tm.tm_min + 1;
    if (smaller == NSCalendarUnitSecond && larger == NSCalendarUnitMinute) return (NSUInteger)tm.tm_sec + 1;
    if (smaller == NSCalendarUnitWeekOfYear && larger == NSCalendarUnitYear) return (NSUInteger)[self component:NSCalendarUnitWeekOfYear fromDate:date];
    if (smaller == NSCalendarUnitWeekOfMonth && larger == NSCalendarUnitMonth) return (NSUInteger)[self component:NSCalendarUnitWeekOfMonth fromDate:date];
    if (smaller == NSCalendarUnitYear && larger == NSCalendarUnitEra) return (NSUInteger)tm.tm_year + 1900;
    /* otherwise: how many smaller units from the start of the larger one */
    NSDate *start; NSTimeInterval len;
    if (![self rangeOfUnit:larger startDate:&start interval:&len forDate:date]) return NSNotFound;
    NSDateComponents *c = [self components:smaller fromDate:start toDate:date options:0];
    NSInteger v = [c valueForComponent:smaller];
    return v == NSDateComponentUndefined ? NSNotFound : (NSUInteger)v + 1;
}
- (void)getEra:(NSInteger *)era year:(NSInteger *)year month:(NSInteger *)month day:(NSInteger *)day fromDate:(NSDate *)date {
    NSDateComponents *c = [self components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    if (era) *era = c.era; if (year) *year = c.year; if (month) *month = c.month; if (day) *day = c.day;
}
- (void)getEra:(NSInteger *)era yearForWeekOfYear:(NSInteger *)year weekOfYear:(NSInteger *)week weekday:(NSInteger *)weekday fromDate:(NSDate *)date {
    NSDateComponents *c = [self components:NSCalendarUnitEra | NSCalendarUnitYearForWeekOfYear | NSCalendarUnitWeekOfYear | NSCalendarUnitWeekday fromDate:date];
    if (era) *era = c.era; if (year) *year = c.yearForWeekOfYear; if (week) *week = c.weekOfYear; if (weekday) *weekday = c.weekday;
}
- (void)getHour:(NSInteger *)hour minute:(NSInteger *)minute second:(NSInteger *)second nanosecond:(NSInteger *)ns fromDate:(NSDate *)date {
    NSDateComponents *c = [self components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond fromDate:date];
    if (hour) *hour = c.hour; if (minute) *minute = c.minute; if (second) *second = c.second; if (ns) *ns = c.nanosecond;
}
- (NSDate *)dateWithEra:(NSInteger)era year:(NSInteger)y month:(NSInteger)m day:(NSInteger)d hour:(NSInteger)h minute:(NSInteger)mi second:(NSInteger)s nanosecond:(NSInteger)ns {
    NSDateComponents *c = [NSDateComponents new];
    c.era = era; c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi; c.second = s; c.nanosecond = ns;
    return [self dateFromComponents:c];
}
- (NSDate *)dateWithEra:(NSInteger)era yearForWeekOfYear:(NSInteger)y weekOfYear:(NSInteger)w weekday:(NSInteger)wd hour:(NSInteger)h minute:(NSInteger)mi second:(NSInteger)s nanosecond:(NSInteger)ns {
    /* week 1 is the first week (starting on firstWeekday) with at least minimumDaysInFirstWeek days of the year */
    struct tm jan1 = { 0 }; jan1.tm_year = (int)y - 1900; jan1.tm_mday = 1;
    time_t t = timegm(&jan1); gmtime_r(&t, &jan1);
    int offset = (jan1.tm_wday + 1 - (int)self.firstWeekday + 7) % 7;
    int week1 = -offset + ((7 - offset) < (int)self.minimumDaysInFirstWeek ? 7 : 0);   /* day of year (0-based) week 1 starts on */
    struct tm tm = { 0 };
    tm.tm_year = (int)y - 1900; tm.tm_mon = 0;
    tm.tm_mday = 1 + week1 + ((int)w - 1) * 7 + ((int)wd - (int)self.firstWeekday + 7) % 7;
    tm.tm_hour = (int)h; tm.tm_min = (int)mi; tm.tm_sec = (int)s;
    return cal_date(self, tm, ns / 1e9);
}
- (NSDateComponents *)componentsInTimeZone:(NSTimeZone *)tz fromDate:(NSDate *)date {
    NSCalendar *cal = [self copy]; cal.timeZone = tz;
    NSCalendarUnit all = NSCalendarUnitCalendar | NSCalendarUnitTimeZone;
    for (size_t i = 0; i < sizeof CAL_FIELDS / sizeof *CAL_FIELDS; i++) all |= CAL_FIELDS[i];
    return [cal components:all fromDate:date];
}
- (NSComparisonResult)compareDate:(NSDate *)a toDate:(NSDate *)b toUnitGranularity:(NSCalendarUnit)unit {
    NSDate *sa, *sb;
    if (![self rangeOfUnit:unit startDate:&sa interval:NULL forDate:a] || ![self rangeOfUnit:unit startDate:&sb interval:NULL forDate:b]) return [a compare:b];
    return [sa compare:sb];
}
- (BOOL)isDate:(NSDate *)a equalToDate:(NSDate *)b toUnitGranularity:(NSCalendarUnit)unit { return [self compareDate:a toDate:b toUnitGranularity:unit] == NSOrderedSame; }
- (BOOL)isDateInYesterday:(NSDate *)date { return [self isDate:date inSameDayAsDate:[self dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:[NSDate date] options:0]]; }
- (BOOL)isDateInTomorrow:(NSDate *)date { return [self isDate:date inSameDayAsDate:[self dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[NSDate date] options:0]]; }
/* adapted: the weekend is Saturday and Sunday in every region */
- (BOOL)isDateInWeekend:(NSDate *)date { NSInteger wd = [self component:NSCalendarUnitWeekday fromDate:date]; return wd == 1 || wd == 7; }
- (BOOL)rangeOfWeekendStartDate:(NSDate **)datep interval:(NSTimeInterval *)tip containingDate:(NSDate *)date {
    if (![self isDateInWeekend:date]) return NO;
    NSDate *day = [self startOfDayForDate:date];
    if ([self component:NSCalendarUnitWeekday fromDate:date] == 1) day = [self dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:day options:0];
    if (datep) *datep = day;
    if (tip) *tip = [[self dateByAddingUnit:NSCalendarUnitDay value:2 toDate:day options:0] timeIntervalSinceDate:day];
    return YES;
}
- (BOOL)nextWeekendStartDate:(NSDate **)datep interval:(NSTimeInterval *)tip options:(NSCalendarOptions)options afterDate:(NSDate *)date {
    BOOL back = (options & NSCalendarSearchBackwards) != 0;
    NSDate *day = [self startOfDayForDate:date];
    for (int i = 0; i < 14; i++) {
        day = [self dateByAddingUnit:NSCalendarUnitDay value:back ? -1 : 1 toDate:day options:0];
        if ([self component:NSCalendarUnitWeekday fromDate:day] == 7 && (back ? [day compare:date] == NSOrderedAscending : YES))
            return [self rangeOfWeekendStartDate:datep interval:tip containingDate:day];
    }
    return NO;
}
- (NSDateComponents *)components:(NSCalendarUnit)units fromDateComponents:(NSDateComponents *)a toDateComponents:(NSDateComponents *)b options:(NSCalendarOptions)options {
    NSDate *da = [self dateFromComponents:a], *db = [self dateFromComponents:b];
    return da && db ? [self components:units fromDate:da toDate:db options:options] : [NSDateComponents new];
}
- (BOOL)date:(NSDate *)date matchesComponents:(NSDateComponents *)comps {
    NSCalendarUnit all = 0;
    for (size_t i = 0; i < sizeof CAL_FIELDS / sizeof *CAL_FIELDS; i++) all |= CAL_FIELDS[i];
    NSDateComponents *c = [self components:all fromDate:date];
    for (size_t i = 0; i < sizeof CAL_FIELDS / sizeof *CAL_FIELDS; i++) {
        NSInteger want = [comps valueForComponent:CAL_FIELDS[i]];
        if (want != NSDateComponentUndefined && want != [c valueForComponent:CAL_FIELDS[i]]) return NO;
    }
    return YES;
}
/* the next date after (or before) `date` matching the components: the days that match the day-level fields, then the
 * times on them (unset time fields smaller than a set one run through their values; the others are their lowest) */
- (NSDate *)nextDateAfterDate:(NSDate *)date matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)options {
    BOOL back = (options & NSCalendarSearchBackwards) != 0;
    NSInteger H = comps.hour, M = comps.minute, S = comps.second;
    BOOL anyTime = H != NSDateComponentUndefined || M != NSDateComponentUndefined || S != NSDateComponentUndefined;
    NSDateComponents *dayComps = [comps copy];
    dayComps.hour = dayComps.minute = dayComps.second = dayComps.nanosecond = NSDateComponentUndefined;
    NSDate *day = [self startOfDayForDate:date];
    for (int i = 0; i < 366 * 30; i++, day = [self dateByAddingUnit:NSCalendarUnitDay value:back ? -1 : 1 toDate:day options:0]) {
        if (![self date:day matchesComponents:dayComps]) continue;
        if (!anyTime) {
            if (back ? [day compare:date] == NSOrderedAscending : [day compare:date] == NSOrderedDescending) return day;
            continue;
        }
        NSInteger h0 = H != NSDateComponentUndefined ? H : 0, h1 = H != NSDateComponentUndefined ? H : (M != NSDateComponentUndefined || S != NSDateComponentUndefined ? 23 : 0);
        NSInteger m0 = M != NSDateComponentUndefined ? M : 0, m1 = M != NSDateComponentUndefined ? M : (S != NSDateComponentUndefined ? 59 : 0);
        NSInteger s0 = S != NSDateComponentUndefined ? S : 0, s1 = s0;
        for (NSInteger hh = back ? h1 : h0; back ? hh >= h0 : hh <= h1; hh += back ? -1 : 1)
            for (NSInteger mm = back ? m1 : m0; back ? mm >= m0 : mm <= m1; mm += back ? -1 : 1)
                for (NSInteger ss = back ? s1 : s0; back ? ss >= s0 : ss <= s1; ss += back ? -1 : 1) {
                    NSDate *d = [self dateBySettingHour:hh minute:mm second:ss ofDate:day options:0];
                    if (!d) continue;
                    if (back ? [d compare:date] == NSOrderedAscending : [d compare:date] == NSOrderedDescending) return d;
                }
    }
    return nil;
}
- (NSDate *)nextDateAfterDate:(NSDate *)date matchingUnit:(NSCalendarUnit)unit value:(NSInteger)value options:(NSCalendarOptions)options {
    NSDateComponents *c = [NSDateComponents new]; [c setValue:value forComponent:unit];
    return [self nextDateAfterDate:date matchingComponents:c options:options];
}
- (NSDate *)nextDateAfterDate:(NSDate *)date matchingHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s options:(NSCalendarOptions)options {
    NSDateComponents *c = [NSDateComponents new]; c.hour = h; c.minute = m; c.second = s;
    return [self nextDateAfterDate:date matchingComponents:c options:options];
}
- (void)enumerateDatesStartingAfterDate:(NSDate *)start matchingComponents:(NSDateComponents *)comps options:(NSCalendarOptions)opts usingBlock:(void (^)(NSDate *, BOOL, BOOL *))block {
    NSDate *d = start;
    BOOL stop = NO;
    for (NSUInteger n = 0; !stop && n < 1000000; n++) {
        d = [self nextDateAfterDate:d matchingComponents:comps options:opts];
        if (!d) break;
        block(d, YES, &stop);
    }
}
- (NSDate *)dateBySettingUnit:(NSCalendarUnit)unit value:(NSInteger)v ofDate:(NSDate *)date options:(NSCalendarOptions)opts {
    if ([self component:unit fromDate:date] == v) return date;
    NSCalendarUnit all = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond;
    if (unit & all) {
        NSDateComponents *c = [self components:all fromDate:date];
        [c setValue:v forComponent:unit];
        if (unit != NSCalendarUnitDay && c.day > cal_days_in_month(c.year, c.month)) c.day = cal_days_in_month(c.year, c.month);
        return [self dateFromComponents:c];
    }
    /* weekday and the other derived fields: the next date with that value, keeping the time of day */
    NSDate *n = [self nextDateAfterDate:[self startOfDayForDate:date] matchingUnit:unit value:v options:opts];
    if (!n) return nil;
    NSDateComponents *t = [self components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    return [self dateBySettingHour:t.hour minute:t.minute second:t.second ofDate:n options:opts];
}
- (NSDate *)dateBySettingHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s ofDate:(NSDate *)date options:(NSCalendarOptions)opts {
    if (h < 0 || h > 23 || m < 0 || m > 59 || s < 0 || s > 59) return nil;
    struct tm tm = cal_tm(self, date);
    tm.tm_hour = (int)h; tm.tm_min = (int)m; tm.tm_sec = (int)s;
    return cal_date(self, tm, 0);
}
@end

/* the calendars Apple added in iOS 26 */
NSCalendarIdentifier const NSCalendarIdentifierBangla = @"bangla";
NSCalendarIdentifier const NSCalendarIdentifierDangi = @"dangi";
NSCalendarIdentifier const NSCalendarIdentifierGujarati = @"gujarati";
NSCalendarIdentifier const NSCalendarIdentifierKannada = @"kannada";
NSCalendarIdentifier const NSCalendarIdentifierMalayalam = @"malayalam";
NSCalendarIdentifier const NSCalendarIdentifierMarathi = @"marathi";
NSCalendarIdentifier const NSCalendarIdentifierOdia = @"odia";
NSCalendarIdentifier const NSCalendarIdentifierTamil = @"tamil";
NSCalendarIdentifier const NSCalendarIdentifierTelugu = @"telugu";
NSCalendarIdentifier const NSCalendarIdentifierVietnamese = @"vietnamese";
NSCalendarIdentifier const NSCalendarIdentifierVikram = @"vikram";

/* NSTimeZone: data, equality, localized names, abbreviations */
static NSMutableDictionary<NSString *, NSString *> *tz_abbreviations(void) {
    static NSMutableDictionary *d;   /* (callers hold the class lock) */
    if (!d) {
        d = [@{ @"ADT": @"America/Halifax", @"AKDT": @"America/Juneau", @"AKST": @"America/Juneau", @"ART": @"America/Argentina/Buenos_Aires",
                @"AST": @"America/Halifax", @"BDT": @"Asia/Dhaka", @"BRST": @"America/Sao_Paulo", @"BRT": @"America/Sao_Paulo", @"BST": @"Europe/London",
                @"CAT": @"Africa/Harare", @"CDT": @"America/Chicago", @"CEST": @"Europe/Paris", @"CET": @"Europe/Paris", @"CLST": @"America/Santiago",
                @"CLT": @"America/Santiago", @"COT": @"America/Bogota", @"CST": @"America/Chicago", @"EAT": @"Africa/Addis_Ababa", @"EDT": @"America/New_York",
                @"EEST": @"Europe/Athens", @"EET": @"Europe/Athens", @"EST": @"America/New_York", @"GMT": @"GMT", @"GST": @"Asia/Dubai",
                @"HKT": @"Asia/Hong_Kong", @"HST": @"Pacific/Honolulu", @"ICT": @"Asia/Bangkok", @"IRST": @"Asia/Tehran", @"IST": @"Asia/Kolkata",
                @"JST": @"Asia/Tokyo", @"KST": @"Asia/Seoul", @"MDT": @"America/Denver", @"MSD": @"Europe/Moscow", @"MSK": @"Europe/Moscow",
                @"MST": @"America/Denver", @"NDT": @"America/St_Johns", @"NST": @"America/St_Johns", @"NZDT": @"Pacific/Auckland",
                @"NZST": @"Pacific/Auckland", @"PDT": @"America/Los_Angeles", @"PET": @"America/Lima", @"PHT": @"Asia/Manila", @"PKT": @"Asia/Karachi",
                @"PST": @"America/Los_Angeles", @"SGT": @"Asia/Singapore", @"TRT": @"Europe/Istanbul", @"UTC": @"UTC", @"WAT": @"Africa/Lagos",
                @"WEST": @"Europe/Lisbon", @"WET": @"Europe/Lisbon", @"WIT": @"Asia/Jakarta" } mutableCopy];
    }
    return d;
}
@implementation NSTimeZone (NSExtendedTimeZone)
+ (NSDictionary<NSString *, NSString *> *)abbreviationDictionary { @synchronized (self) { return [tz_abbreviations() copy]; } }
+ (void)setAbbreviationDictionary:(NSDictionary<NSString *, NSString *> *)dict { @synchronized (self) { [tz_abbreviations() setDictionary:dict]; } }
/* the version of the host's tz database (tzdata.zi's first line), else the one isim was built against */
+ (NSString *)timeZoneDataVersion {
    NSString *zi = [NSString stringWithContentsOfFile:@"/usr/share/zoneinfo/tzdata.zi" encoding:NSUTF8StringEncoding error:NULL];
    if ([zi hasPrefix:@"# version "]) return [[zi substringWithRange:NSMakeRange(10, MIN((NSUInteger)8, zi.length - 10))] componentsSeparatedByString:@"\n"].firstObject;
    return @"2024a";
}
- (NSData *)data {
    NSData *d = [NSData dataWithContentsOfFile:[@"/usr/share/zoneinfo/" stringByAppendingString:self.name]];
    return d ?: [NSData data];
}
+ (instancetype)timeZoneWithName:(NSString *)name data:(NSData *)data { return [self timeZoneWithName:name]; }
- (instancetype)initWithName:(NSString *)name data:(NSData *)data { return [self initWithName:name]; }
- (BOOL)isEqualToTimeZone:(NSTimeZone *)tz { return [self isEqual:tz]; }
@end

/* the nil-terminated variadic initializers */
static NSMutableArray *va_objects(id first, va_list ap) {
    NSMutableArray *a = [NSMutableArray array];
    for (id o = first; o; o = va_arg(ap, id)) [a addObject:o];
    return a;
}
@implementation NSSet (IsimVariadic)
- (instancetype)initWithObjects:(id)first, ... { va_list ap; va_start(ap, first); NSArray *a = va_objects(first, ap); va_end(ap); return [self initWithArray:a]; }
@end
@implementation NSOrderedSet (IsimVariadic)
- (instancetype)initWithObjects:(id)first, ... { va_list ap; va_start(ap, first); NSArray *a = va_objects(first, ap); va_end(ap); return [self initWithArray:a]; }
@end
@implementation NSDictionary (IsimVariadic)
- (instancetype)initWithObjectsAndKeys:(id)first, ... {
    va_list ap; va_start(ap, first); NSArray *a = va_objects(first, ap); va_end(ap);
    NSMutableArray *objs = [NSMutableArray array], *keys = [NSMutableArray array];
    for (NSUInteger i = 0; i + 1 < a.count; i += 2) { [objs addObject:a[i]]; [keys addObject:a[i + 1]]; }
    return [self initWithObjects:objs forKeys:keys];
}
@end
