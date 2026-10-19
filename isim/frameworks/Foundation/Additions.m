/* isim Foundation (ARC): Objective-C methods that binary SDKs built against Apple's SDK call (found with
 * ISIM_OBJC_AUDIT=1 on Google Mobile Ads): URL and path helpers, percent encoding, file-system URLs, bundle resource
 * URLs, NSValue with arbitrary bytes, dictionary initializers and description variants. */
#import <Foundation/Foundation.h>
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

@implementation NSString (IsimMore)
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
@end

@implementation NSNumber (IsimMore)
- (unsigned short)unsignedShortValue { return (unsigned short)self.unsignedIntValue; }
- (NSString *)descriptionWithLocale:(id)locale { return self.description; }
@end

@implementation NSDate (IsimMore)
- (instancetype)initWithTimeIntervalSinceNow:(NSTimeInterval)s { return [self initWithTimeIntervalSinceReferenceDate:[NSDate date].timeIntervalSinceReferenceDate + s]; }
- (instancetype)initWithTimeIntervalSince1970:(NSTimeInterval)s { return [self initWithTimeIntervalSinceReferenceDate:s - 978307200.0]; }
- (instancetype)initWithTimeInterval:(NSTimeInterval)s sinceDate:(NSDate *)d { return [self initWithTimeIntervalSinceReferenceDate:d.timeIntervalSinceReferenceDate + s]; }
+ (instancetype)dateWithTimeInterval:(NSTimeInterval)s sinceDate:(NSDate *)d { return [[self alloc] initWithTimeInterval:s sinceDate:d]; }
- (NSString *)descriptionWithLocale:(id)locale { return self.description; }
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

@implementation NSNotification (IsimMore)
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

@implementation NSTimeZone (IsimMore)
- (BOOL)isDaylightSavingTime { return [self isDaylightSavingTimeForDate:[NSDate date]]; }
- (NSString *)localizedName:(NSInteger)style locale:(NSLocale *)locale { return self.name; }
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
@implementation NSCalendar (IsimArithmetic)
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
- (NSDate *)dateByAddingComponents:(NSDateComponents *)c toDate:(NSDate *)date options:(NSUInteger)opts {
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
- (NSDate *)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate *)date options:(NSUInteger)opts {
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
- (NSDateComponents *)components:(NSCalendarUnit)units fromDate:(NSDate *)from toDate:(NSDate *)to options:(NSUInteger)opts {
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
