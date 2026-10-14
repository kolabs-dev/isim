/* isim Foundation (ARC): Objective-C methods that binary SDKs built against Apple's SDK call (found with
 * ISIM_OBJC_AUDIT=1 on Google Mobile Ads): URL and path helpers, percent encoding, file-system URLs, bundle resource
 * URLs, NSValue with arbitrary bytes, dictionary initializers and description variants. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <string.h>

/* ---------------- URLs and percent encoding ---------------- */
static NSCharacterSet *chars(NSString *extra) {
    static NSString *base = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
    return [NSCharacterSet characterSetWithCharactersInString:[base stringByAppendingString:extra]];
}
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
