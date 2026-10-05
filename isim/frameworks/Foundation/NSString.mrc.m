/* isim Foundation: NSString family (MRC). Storage is UTF-8; indices/lengths are UTF-16 units. */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include "isim_foundation.h"

/* ---------------- UTF helpers ---------------- */
NSUInteger isim_utf16_length(const char *s, NSUInteger n) {
    NSUInteger c = 0;
    for (NSUInteger i = 0; i < n; i++) {
        unsigned char b = (unsigned char)s[i];
        if ((b & 0xC0) != 0x80) c += b >= 0xF0 ? 2 : 1;
    }
    return c;
}
NSUInteger isim_utf16_to_byte(const char *s, NSUInteger n, NSUInteger idx) {
    NSUInteger u = 0, i = 0;
    while (i < n && u < idx) {
        unsigned char b = (unsigned char)s[i];
        NSUInteger len = b < 0x80 ? 1 : b < 0xE0 ? 2 : b < 0xF0 ? 3 : 4;
        u += len == 4 ? 2 : 1;
        i += len;
    }
    return i > n ? n : i;
}
static uint32_t decode_at(const char *s, NSUInteger n, NSUInteger *i) {
    unsigned char b = (unsigned char)s[*i];
    uint32_t cp; int extra;
    if (b < 0x80) { cp = b; extra = 0; } else if (b < 0xE0) { cp = b & 0x1F; extra = 1; }
    else if (b < 0xF0) { cp = b & 0x0F; extra = 2; } else { cp = b & 0x07; extra = 3; }
    (*i)++;
    while (extra-- > 0 && *i < n) cp = (cp << 6) | ((unsigned char)s[(*i)++] & 0x3F);
    return cp;
}
static NSUInteger encode_utf8(uint32_t cp, char *out) {
    if (cp < 0x80) { out[0] = (char)cp; return 1; }
    if (cp < 0x800) { out[0] = (char)(0xC0 | cp >> 6); out[1] = (char)(0x80 | (cp & 0x3F)); return 2; }
    if (cp < 0x10000) { out[0] = (char)(0xE0 | cp >> 12); out[1] = (char)(0x80 | ((cp >> 6) & 0x3F)); out[2] = (char)(0x80 | (cp & 0x3F)); return 3; }
    out[0] = (char)(0xF0 | cp >> 18); out[1] = (char)(0x80 | ((cp >> 12) & 0x3F)); out[2] = (char)(0x80 | ((cp >> 6) & 0x3F)); out[3] = (char)(0x80 | (cp & 0x3F)); return 4;
}
static char *utf16_to_utf8(const unichar *u, NSUInteger n, NSUInteger *outLen) {
    char *out = malloc(n * 3 + 1); NSUInteger o = 0;
    for (NSUInteger i = 0; i < n; i++) {
        uint32_t cp = u[i];
        if (cp >= 0xD800 && cp < 0xDC00 && i + 1 < n && u[i + 1] >= 0xDC00 && u[i + 1] < 0xE000) { cp = 0x10000 + ((cp - 0xD800) << 10) + (u[i + 1] - 0xDC00); i++; }
        o += encode_utf8(cp, out + o);
    }
    out[o] = 0; *outLen = o;
    return out;
}

static const char *memrchr_compat(const char *b, NSUInteger n) { while (n--) if (b[n] == '.') return b + n; return NULL; }

/* ---------------- growable byte buffer ---------------- */
typedef struct { char *b; NSUInteger n, cap; } buf_t;
static void buf_add(buf_t *b, const char *s, NSUInteger n) {
    if (b->n + n + 1 > b->cap) { b->cap = (b->n + n + 1) * 2; b->b = realloc(b->b, b->cap); }
    memcpy(b->b + b->n, s, n); b->n += n; b->b[b->n] = 0;
}

/* ---------------- concrete classes ---------------- */
@interface __NSImmString : NSString { @public char *_b; NSUInteger _n; } @end
@interface __NSCFConstantString : NSString { int _flags; const void *_s; long _len; } @end

NSString *isim_string_take(char *bytes, NSUInteger len) {
    __NSImmString *s = class_createInstance([__NSImmString class], 0);
    s->_b = bytes; s->_n = len;
    return s;
}
NSString *isim_string_copy(const char *bytes, NSUInteger len) {
    char *b = malloc(len + 1); memcpy(b, bytes, len); b[len] = 0;
    return isim_string_take(b, len);
}

/* ---------------- formatting ---------------- */
NSString *isim_format(NSString *fmt, va_list ap) {
    NSUInteger fn; const char *f = [fmt _isim_bytes:&fn];
    buf_t out = {0}; buf_add(&out, "", 0);
    va_list args; va_copy(args, ap);
    for (NSUInteger i = 0; i < fn;) {
        if (f[i] != '%') { NSUInteger j = i; while (j < fn && f[j] != '%') j++; buf_add(&out, f + i, j - i); i = j; continue; }
        NSUInteger start = i++;
        char spec[64]; int sp = 0; spec[sp++] = '%';
        while (i < fn && strchr("-+ #0'", f[i])) { if (sp < 40) spec[sp++] = f[i]; i++; }
        if (i < fn && f[i] == '*') { sp += snprintf(spec + sp, 12, "%d", va_arg(args, int)); i++; }
        else while (i < fn && isdigit((unsigned char)f[i])) { if (sp < 40) spec[sp++] = f[i]; i++; }
        if (i < fn && f[i] == '$') { buf_add(&out, f + start, fn - start); break; }     /* positional args unsupported */
        if (i < fn && f[i] == '.') {
            spec[sp++] = '.'; i++;
            if (i < fn && f[i] == '*') { sp += snprintf(spec + sp, 12, "%d", va_arg(args, int)); i++; }
            else while (i < fn && isdigit((unsigned char)f[i])) { if (sp < 50) spec[sp++] = f[i]; i++; }
        }
        int lng = 0;   /* 0 int, 1 long, 2 long long, 3 long double, -1 short/char */
        while (i < fn && strchr("hlqLztj", f[i])) {
            char c = f[i++];
            if (c == 'h') lng = -1; else if (c == 'l') lng = lng == 1 ? 2 : 1; else if (c == 'q' || c == 'j') lng = 2;
            else if (c == 'L') lng = 3; else lng = 1;
        }
        if (i >= fn) break;
        char conv = f[i++];
        char tmp[512]; int n = 0;
        switch (conv) {
        case '%': buf_add(&out, "%", 1); break;
        case '@': {
            id o = va_arg(args, id);
            const char *s = o ? [[o description] UTF8String] : "(null)";
            buf_add(&out, s, strlen(s)); break; }
        case 'd': case 'i':
            if (lng == 2) { spec[sp++] = 'l'; spec[sp++] = 'l'; spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, long long)); }
            else if (lng == 1) { spec[sp++] = 'l'; spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, long)); }
            else { spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, int)); }
            buf_add(&out, tmp, n < (int)sizeof tmp ? n : (int)sizeof tmp - 1); break;
        case 'u': case 'o': case 'x': case 'X':
            if (lng == 2) { spec[sp++] = 'l'; spec[sp++] = 'l'; spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, unsigned long long)); }
            else if (lng == 1) { spec[sp++] = 'l'; spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, unsigned long)); }
            else { spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, unsigned int)); }
            buf_add(&out, tmp, n < (int)sizeof tmp ? n : (int)sizeof tmp - 1); break;
        case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
            if (lng == 3) { spec[sp++] = 'L'; spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, long double)); }
            else { spec[sp++] = conv; spec[sp] = 0; n = snprintf(tmp, sizeof tmp, spec, va_arg(args, double)); }
            buf_add(&out, tmp, n < (int)sizeof tmp ? n : (int)sizeof tmp - 1); break;
        case 'c': { char c = (char)va_arg(args, int); buf_add(&out, &c, 1); break; }
        case 'C': { char e[4]; NSUInteger k = encode_utf8((uint32_t)va_arg(args, int), e); buf_add(&out, e, k); break; }
        case 's': {
            const char *s = va_arg(args, const char *);
            spec[sp++] = 's'; spec[sp] = 0;
            if (!s) s = "(null)";
            if (sp == 2) buf_add(&out, s, strlen(s));
            else { n = snprintf(tmp, sizeof tmp, spec, s); buf_add(&out, tmp, n < (int)sizeof tmp ? n : (int)sizeof tmp - 1); }
            break; }
        case 'S': { const unichar *u = va_arg(args, const unichar *); NSUInteger k = 0; while (u && u[k]) k++;
                    NSUInteger ol; char *s = utf16_to_utf8(u, k, &ol); buf_add(&out, s, ol); free(s); break; }
        case 'p': n = snprintf(tmp, sizeof tmp, "%p", va_arg(args, void *)); buf_add(&out, tmp, n); break;
        case 'n': (void)va_arg(args, void *); break;
        default: buf_add(&out, f + start, i - start); break;
        }
    }
    va_end(args);
    return isim_string_take(out.b, out.n);
}

/* ---------------- NSString (abstract) ---------------- */
@implementation NSString
+ (instancetype)allocWithZone:(NSZone *)zone {
    if (self == [NSString class]) return class_createInstance([__NSImmString class], 0);
    return class_createInstance(self, 0);
}
- (instancetype)init { return self; }
- (const char *)_isim_bytes:(NSUInteger *)len { *len = 0; return ""; }

+ (instancetype)string { return [[[self alloc] init] autorelease]; }
+ (instancetype)stringWithString:(NSString *)s { return [[[self alloc] initWithString:s] autorelease]; }
+ (instancetype)stringWithUTF8String:(const char *)s { return [[[self alloc] initWithUTF8String:s] autorelease]; }
+ (instancetype)stringWithCString:(const char *)s encoding:(NSStringEncoding)e { return [[[self alloc] initWithUTF8String:s] autorelease]; }
+ (instancetype)stringWithFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format);
    id s = [[self alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return [s autorelease];
}
+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(id *)error {
    int fd = open([path UTF8String], O_RDONLY);
    if (fd < 0) { if (error) *error = nil; return nil; }
    buf_t b = {0}; char chunk[4096]; ssize_t r;
    buf_add(&b, "", 0);
    while ((r = read(fd, chunk, sizeof chunk)) > 0) buf_add(&b, chunk, (NSUInteger)r);
    close(fd);
    NSString *s = [[[self alloc] initWithBytes:b.b length:b.n encoding:NSUTF8StringEncoding] autorelease];
    free(b.b);
    return s;
}
- (instancetype)initWithBytes:(const void *)bytes length:(NSUInteger)len encoding:(NSStringEncoding)enc {
    [self release];
    if (enc == NSUTF16StringEncoding) { NSUInteger ol; char *u = utf16_to_utf8(bytes, len / 2, &ol); return isim_string_take(u, ol); }
    return isim_string_copy(bytes, len);
}
- (instancetype)initWithCharacters:(const unichar *)c length:(NSUInteger)n { [self release]; NSUInteger ol; char *u = utf16_to_utf8(c, n, &ol); return isim_string_take(u, ol); }
- (instancetype)initWithData:(NSData *)data encoding:(NSStringEncoding)e { [self release]; return nil; }
- (instancetype)initWithString:(NSString *)s { NSUInteger n; const char *b = [s _isim_bytes:&n]; return [self initWithBytes:b length:n encoding:NSUTF8StringEncoding]; }
- (instancetype)initWithUTF8String:(const char *)s { if (!s) { [self release]; return nil; } return [self initWithBytes:s length:strlen(s) encoding:NSUTF8StringEncoding]; }
- (instancetype)initWithFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format); id s = [self initWithFormat:format arguments:ap]; va_end(ap); return s;
}
- (instancetype)initWithFormat:(NSString *)format arguments:(va_list)ap {
    NSString *s = isim_format(format, ap);
    if ([self isKindOfClass:[NSMutableString class]]) { [(NSMutableString *)self setString:s]; [s release]; return self; }
    [self release];
    return s;
}

- (NSUInteger)length { NSUInteger n; const char *b = [self _isim_bytes:&n]; return isim_utf16_length(b, n); }
- (unichar)characterAtIndex:(NSUInteger)idx {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    NSUInteger u = 0, i = 0;
    while (i < n) {
        NSUInteger at = i; uint32_t cp = decode_at(b, n, &i); (void)at;
        if (cp >= 0x10000) {
            if (u == idx) return (unichar)(0xD800 + ((cp - 0x10000) >> 10));
            if (u + 1 == idx) return (unichar)(0xDC00 + ((cp - 0x10000) & 0x3FF));
            u += 2;
        } else { if (u == idx) return (unichar)cp; u++; }
    }
    [NSException raise:NSRangeException format:@"-[NSString characterAtIndex:]: index %lu out of bounds", (unsigned long)idx];
    return 0;
}
- (const char *)UTF8String { NSUInteger n; return [self _isim_bytes:&n]; }
- (const char *)cStringUsingEncoding:(NSStringEncoding)e { return [self UTF8String]; }
- (NSUInteger)lengthOfBytesUsingEncoding:(NSStringEncoding)e { NSUInteger n; [self _isim_bytes:&n]; return n; }
- (NSString *)description { return self; }
- (id)copyWithZone:(NSZone *)z { NSUInteger n; const char *b = [self _isim_bytes:&n]; return isim_string_copy(b, n); }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableString alloc] initWithString:self]; }

- (NSUInteger)hash {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    uint64_t h = 1469598103934665603ull;
    for (NSUInteger i = 0; i < n; i++) h = (h ^ (unsigned char)b[i]) * 1099511628211ull;
    return (NSUInteger)h;
}
- (BOOL)isEqual:(id)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[NSString class]]) return NO;
    return [self isEqualToString:o];
}
- (BOOL)isEqualToString:(NSString *)o {
    if (!o) return NO;
    NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [o _isim_bytes:&b];
    return a == b && !memcmp(x, y, a);
}
- (NSComparisonResult)compare:(NSString *)o { return [self compare:o options:0]; }
- (NSComparisonResult)caseInsensitiveCompare:(NSString *)o { return [self compare:o options:NSCaseInsensitiveSearch]; }
- (NSComparisonResult)localizedCompare:(NSString *)o { return [self compare:o options:0]; }
- (NSComparisonResult)compare:(NSString *)o options:(NSStringCompareOptions)mask {
    NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [o _isim_bytes:&b];
    if (mask & NSNumericSearch) {
        NSUInteger i = 0, j = 0;
        while (i < a && j < b) {
            if (isdigit((unsigned char)x[i]) && isdigit((unsigned char)y[j])) {
                unsigned long long p = 0, q = 0;
                while (i < a && isdigit((unsigned char)x[i])) p = p * 10 + (x[i++] - '0');
                while (j < b && isdigit((unsigned char)y[j])) q = q * 10 + (y[j++] - '0');
                if (p != q) return p < q ? NSOrderedAscending : NSOrderedDescending;
                continue;
            }
            int c1 = (unsigned char)x[i++], c2 = (unsigned char)y[j++];
            if (mask & NSCaseInsensitiveSearch) { c1 = tolower(c1); c2 = tolower(c2); }
            if (c1 != c2) return c1 < c2 ? NSOrderedAscending : NSOrderedDescending;
        }
        return i < a ? NSOrderedDescending : j < b ? NSOrderedAscending : NSOrderedSame;
    }
    NSUInteger m = a < b ? a : b;
    int r = (mask & NSCaseInsensitiveSearch) ? strncasecmp(x, y, m) : memcmp(x, y, m);
    if (r) return r < 0 ? NSOrderedAscending : NSOrderedDescending;
    return a == b ? NSOrderedSame : a < b ? NSOrderedAscending : NSOrderedDescending;
}
- (NSRange)rangeOfString:(NSString *)s { return [self rangeOfString:s options:0]; }
- (NSRange)rangeOfString:(NSString *)s options:(NSStringCompareOptions)mask {
    NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [s _isim_bytes:&b];
    if (b == 0 || b > a) return NSMakeRange(NSNotFound, 0);
    for (NSUInteger k = 0; k + b <= a; k++) {
        NSUInteger i = (mask & NSBackwardsSearch) ? a - b - k : k;
        if ((mask & NSAnchoredSearch) && k > 0) break;
        int eq = (mask & NSCaseInsensitiveSearch) ? !strncasecmp(x + i, y, b) : !memcmp(x + i, y, b);
        if (eq) return NSMakeRange(isim_utf16_length(x, i), isim_utf16_length(y, b));
    }
    return NSMakeRange(NSNotFound, 0);
}
- (BOOL)hasPrefix:(NSString *)s { NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [s _isim_bytes:&b]; return b && b <= a && !memcmp(x, y, b); }
- (BOOL)hasSuffix:(NSString *)s { NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [s _isim_bytes:&b]; return b && b <= a && !memcmp(x + a - b, y, b); }
- (BOOL)containsString:(NSString *)s { return [self rangeOfString:s].location != NSNotFound; }
- (NSString *)stringByAppendingString:(NSString *)s {
    NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [s _isim_bytes:&b];
    char *r = malloc(a + b + 1); memcpy(r, x, a); memcpy(r + a, y, b); r[a + b] = 0;
    return [isim_string_take(r, a + b) autorelease];
}
- (NSString *)stringByAppendingFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format); NSString *t = isim_format(format, ap); va_end(ap);
    NSString *r = [self stringByAppendingString:t]; [t release]; return r;
}
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)rep {
    NSUInteger a, b, c; const char *x = [self _isim_bytes:&a], *y = [target _isim_bytes:&b], *z = [rep _isim_bytes:&c];
    if (!b) return [[self copy] autorelease];
    buf_t o = {0}; buf_add(&o, "", 0);
    for (NSUInteger i = 0; i < a;) {
        if (i + b <= a && !memcmp(x + i, y, b)) { buf_add(&o, z, c); i += b; } else { buf_add(&o, x + i, 1); i++; }
    }
    return [isim_string_take(o.b, o.n) autorelease];
}
- (NSString *)substringWithRange:(NSRange)r {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    if (NSMaxRange(r) > isim_utf16_length(b, n)) [NSException raise:NSRangeException format:@"-[NSString substringWithRange:]: range {%lu, %lu} out of bounds", (unsigned long)r.location, (unsigned long)r.length];
    NSUInteger s = isim_utf16_to_byte(b, n, r.location), e = isim_utf16_to_byte(b, n, NSMaxRange(r));
    return [isim_string_copy(b + s, e - s) autorelease];
}
- (NSString *)substringFromIndex:(NSUInteger)i { return [self substringWithRange:NSMakeRange(i, [self length] - i)]; }
- (NSString *)substringToIndex:(NSUInteger)i { return [self substringWithRange:NSMakeRange(0, i)]; }
- (NSArray *)componentsSeparatedByString:(NSString *)sep {
    NSUInteger a, b; const char *x = [self _isim_bytes:&a], *y = [sep _isim_bytes:&b];
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger start = 0;
    for (NSUInteger i = 0; b && i + b <= a;) {
        if (!memcmp(x + i, y, b)) { [parts addObject:[isim_string_copy(x + start, i - start) autorelease]]; i += b; start = i; }
        else i++;
    }
    [parts addObject:[isim_string_copy(x + start, a - start) autorelease]];
    return parts;
}
static NSString *map_ascii(NSString *s, int (*fn)(int), int capitalize) {
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    char *r = malloc(n + 1); int word = 1;
    for (NSUInteger i = 0; i < n; i++) {
        unsigned char c = (unsigned char)b[i];
        if (capitalize) { r[i] = (char)(word ? toupper(c) : tolower(c)); word = c == ' ' || c == '\t' || c == '\n'; }
        else r[i] = c < 0x80 ? (char)fn(c) : (char)c;
    }
    r[n] = 0;
    return [isim_string_take(r, n) autorelease];
}
- (NSString *)lowercaseString { return map_ascii(self, tolower, 0); }
- (NSString *)uppercaseString { return map_ascii(self, toupper, 0); }
- (NSString *)capitalizedString { return map_ascii(self, NULL, 1); }
- (double)doubleValue { return strtod([self UTF8String], NULL); }
- (float)floatValue { return strtof([self UTF8String], NULL); }
- (int)intValue { return (int)strtol([self UTF8String], NULL, 10); }
- (NSInteger)integerValue { return strtol([self UTF8String], NULL, 10); }
- (long long)longLongValue { return strtoll([self UTF8String], NULL, 10); }
- (BOOL)boolValue {
    const char *s = [self UTF8String]; while (*s == ' ' || *s == '+' || *s == '-' || *s == '0') s++;
    return *s == 'Y' || *s == 'y' || *s == 'T' || *s == 't' || (*s >= '1' && *s <= '9');
}
- (NSString *)lastPathComponent {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    while (n > 1 && b[n - 1] == '/') n--;
    NSUInteger i = n; while (i > 0 && b[i - 1] != '/') i--;
    return [isim_string_copy(b + i, n - i) autorelease];
}
- (NSString *)stringByDeletingLastPathComponent {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    while (n > 1 && b[n - 1] == '/') n--;
    NSUInteger i = n; while (i > 0 && b[i - 1] != '/') i--;
    if (i == 0) return @"";
    if (i == 1) return @"/";
    return [isim_string_copy(b, i - 1) autorelease];
}
- (NSString *)pathExtension {
    NSString *last = [self lastPathComponent]; NSUInteger n; const char *b = [last _isim_bytes:&n];
    const char *dot = memrchr_compat(b, n);
    return dot ? [isim_string_copy(dot + 1, b + n - dot - 1) autorelease] : @"";
}
- (NSString *)stringByDeletingPathExtension {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    NSUInteger i = n; while (i > 0 && b[i - 1] != '.' && b[i - 1] != '/') i--;
    if (i > 1 && b[i - 1] == '.' && b[i - 2] != '/') return [isim_string_copy(b, i - 1) autorelease];
    return [[self copy] autorelease];
}
- (NSString *)stringByAppendingPathComponent:(NSString *)c {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    if (n == 0) return [[c copy] autorelease];
    return b[n - 1] == '/' ? [self stringByAppendingString:c] : [self stringByAppendingFormat:@"/%@", c];
}
- (NSString *)stringByAppendingPathExtension:(NSString *)e { return [self stringByAppendingFormat:@".%@", e]; }
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)a encoding:(NSStringEncoding)e error:(id *)err {
    int fd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return NO;
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    BOOL ok = write(fd, b, n) == (ssize_t)n;
    close(fd);
    return ok;
}
@end

@implementation __NSImmString
- (const char *)_isim_bytes:(NSUInteger *)len { *len = _n; return _b ? _b : ""; }
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
- (void)dealloc { free(_b); [super dealloc]; }
@end

/* Apple exports the constant-string class under this alias; clang's @"..." literals reference it. */
__asm__(".globl ___CFConstantStringClassReference\n.set ___CFConstantStringClassReference, _OBJC_CLASS_$___NSCFConstantString\n");

/* ---- @"..." literals: { isa, flags, bytes, length }; UTF-16 data when flags == 0x7d0 ---- */
static pthread_mutex_t const_lock = PTHREAD_MUTEX_INITIALIZER;
static struct { const void *key; char *utf8; NSUInteger n; } *const_cache; static NSUInteger const_n, const_cap;
@implementation __NSCFConstantString
- (const char *)_isim_bytes:(NSUInteger *)len {
    if (_flags != 0x7d0) { *len = (NSUInteger)_len; return _s; }
    pthread_mutex_lock(&const_lock);
    for (NSUInteger i = 0; i < const_n; i++) if (const_cache[i].key == self) { *len = const_cache[i].n; pthread_mutex_unlock(&const_lock); return const_cache[i].utf8; }
    if (const_n == const_cap) { const_cap = const_cap ? const_cap * 2 : 16; const_cache = realloc(const_cache, const_cap * sizeof *const_cache); }
    NSUInteger n; char *u = utf16_to_utf8(_s, (NSUInteger)_len, &n);
    const_cache[const_n].key = self; const_cache[const_n].utf8 = u; const_cache[const_n++].n = n;
    pthread_mutex_unlock(&const_lock);
    *len = n; return u;
}
- (NSUInteger)length { return _flags == 0x7d0 ? (NSUInteger)_len : [super length]; }
- (instancetype)retain { return self; }
- (oneway void)release {}
- (instancetype)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@implementation NSMutableString { char *_b; NSUInteger _n, _cap; }
+ (instancetype)stringWithCapacity:(NSUInteger)c { return [[[self alloc] initWithCapacity:c] autorelease]; }
- (instancetype)init { return [self initWithCapacity:16]; }
- (instancetype)initWithCapacity:(NSUInteger)c { _cap = c + 1; _b = calloc(_cap, 1); return self; }
- (instancetype)initWithBytes:(const void *)bytes length:(NSUInteger)len encoding:(NSStringEncoding)enc {
    [self initWithCapacity:len];
    if (enc == NSUTF16StringEncoding) { NSUInteger ol; char *u = utf16_to_utf8(bytes, len / 2, &ol); [self _append:u length:ol]; free(u); }
    else [self _append:bytes length:len];
    return self;
}
- (instancetype)initWithCharacters:(const unichar *)c length:(NSUInteger)n { return [self initWithBytes:c length:n * 2 encoding:NSUTF16StringEncoding]; }
- (void)dealloc { free(_b); [super dealloc]; }
- (const char *)_isim_bytes:(NSUInteger *)len { *len = _n; return _b ? _b : ""; }
- (void)_append:(const char *)s length:(NSUInteger)n {
    if (_n + n + 1 > _cap) { _cap = (_n + n + 1) * 2; _b = realloc(_b, _cap); }
    memcpy(_b + _n, s, n); _n += n; _b[_n] = 0;
}
- (void)appendString:(NSString *)s { NSUInteger n; const char *b = [s _isim_bytes:&n]; [self _append:b length:n]; }
- (void)appendFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format); NSString *t = isim_format(format, ap); va_end(ap);
    [self appendString:t]; [t release];
}
- (void)setString:(NSString *)s {
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    char *copy = malloc(n + 1); memcpy(copy, b, n);   /* s may alias self */
    _n = 0; [self _append:copy length:n]; free(copy);
}
- (void)replaceCharactersInRange:(NSRange)r withString:(NSString *)s {
    NSUInteger st = isim_utf16_to_byte(_b, _n, r.location), en = isim_utf16_to_byte(_b, _n, NSMaxRange(r));
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    char *nb = malloc(_n - (en - st) + n + 1);
    memcpy(nb, _b, st); memcpy(nb + st, b, n); memcpy(nb + st + n, _b + en, _n - en);
    _n = _n - (en - st) + n; nb[_n] = 0;
    free(_b); _b = nb; _cap = _n + 1;
}
- (void)insertString:(NSString *)s atIndex:(NSUInteger)i { [self replaceCharactersInRange:NSMakeRange(i, 0) withString:s]; }
- (void)deleteCharactersInRange:(NSRange)r { [self replaceCharactersInRange:r withString:@""]; }
- (id)copyWithZone:(NSZone *)z { return isim_string_copy(_b ? _b : "", _n); }
@end
