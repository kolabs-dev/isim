/* isim Foundation (ARC): NSData / NSMutableData (bridged to Swift's Data), base64, file I/O. */
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "isim_foundation.h"

@implementation NSData {
    @public unsigned char *_bytes; NSUInteger _length, _cap; BOOL _noFree;
    void (^_dealloc)(void *, NSUInteger);
}
+ (instancetype)data { return [self new]; }
+ (instancetype)dataWithBytes:(const void *)b length:(NSUInteger)n { return [[self alloc] initWithBytes:b length:n]; }
+ (instancetype)dataWithBytesNoCopy:(void *)b length:(NSUInteger)n { return [[self alloc] initWithBytesNoCopy:b length:n freeWhenDone:YES]; }
+ (instancetype)dataWithBytesNoCopy:(void *)b length:(NSUInteger)n freeWhenDone:(BOOL)f { return [[self alloc] initWithBytesNoCopy:b length:n freeWhenDone:f]; }
+ (instancetype)dataWithData:(NSData *)d { return [[self alloc] initWithData:d]; }
+ (instancetype)dataWithContentsOfFile:(NSString *)path { return [[self alloc] initWithContentsOfFile:path]; }
+ (instancetype)dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)o error:(NSError **)e { return [[self alloc] initWithContentsOfFile:path options:o error:e]; }
+ (instancetype)dataWithContentsOfURL:(NSURL *)url { return url.isFileURL ? [self dataWithContentsOfFile:url.path] : nil; }
+ (instancetype)dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)o error:(NSError **)e {
    if (!url.isFileURL) { if (e) *e = [NSError errorWithDomain:NSCocoaErrorDomain code:256 userInfo:@{ @"NSURL": url }]; return nil; }
    return [self dataWithContentsOfFile:url.path options:o error:e];
}
- (instancetype)init { return [self initWithBytes:NULL length:0]; }
- (instancetype)initWithBytes:(const void *)b length:(NSUInteger)n {
    if ((self = [super init])) { _cap = n ? n : 1; _bytes = malloc(_cap); if (n && b) memcpy(_bytes, b, n); _length = n; }
    return self;
}
- (instancetype)initWithBytesNoCopy:(void *)b length:(NSUInteger)n { return [self initWithBytesNoCopy:b length:n freeWhenDone:YES]; }
- (instancetype)initWithBytesNoCopy:(void *)b length:(NSUInteger)n freeWhenDone:(BOOL)f {
    if ((self = [super init])) { _bytes = b; _length = n; _cap = n; _noFree = !f; }
    return self;
}
- (instancetype)initWithBytesNoCopy:(void *)b length:(NSUInteger)n deallocator:(void (^)(void *, NSUInteger))d {
    if ((self = [super init])) { _bytes = b; _length = n; _cap = n; _noFree = YES; _dealloc = [d copy]; }
    return self;
}
- (instancetype)initWithData:(NSData *)d { return [self initWithBytes:d.bytes length:d.length]; }
- (instancetype)initWithContentsOfFile:(NSString *)path { return [self initWithContentsOfFile:path options:0 error:NULL]; }
- (instancetype)initWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)o error:(NSError **)e {
    int fd = path ? open(path.UTF8String, O_RDONLY) : -1;
    if (fd < 0) { if (e) *e = [NSError errorWithDomain:NSCocoaErrorDomain code:260 userInfo:@{ @"NSFilePath": path ?: @"" }]; return nil; }
    NSMutableData *m = [NSMutableData data];
    char buf[65536]; ssize_t r;
    while ((r = read(fd, buf, sizeof buf)) > 0) [m appendBytes:buf length:(NSUInteger)r];
    close(fd);
    return [self initWithBytes:m.bytes length:m.length];
}
- (instancetype)initWithContentsOfURL:(NSURL *)url { return url.isFileURL ? [self initWithContentsOfFile:url.path] : nil; }
- (void)dealloc {
    if (_dealloc) _dealloc(_bytes, _length);
    else if (!_noFree) free(_bytes);
}
- (id)copyWithZone:(NSZone *)z { return [self class] == [NSData class] ? self : [[NSData alloc] initWithData:self]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableData alloc] initWithData:self]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeBytes:_bytes length:_length forKey:@"NS.bytes"]; }
- (instancetype)initWithCoder:(NSCoder *)c { NSUInteger n = 0; const uint8_t *b = [c decodeBytesForKey:@"NS.bytes" returnedLength:&n]; return [self initWithBytes:b length:n]; }
- (NSUInteger)length { return _length; }
- (const void *)bytes { return _bytes; }
- (void)getBytes:(void *)buf length:(NSUInteger)n { memcpy(buf, _bytes, MIN(n, _length)); }
- (void)getBytes:(void *)buf range:(NSRange)r {
    if (NSMaxRange(r) > _length) [NSException raise:NSRangeException format:@"-[NSData getBytes:range:]: range {%lu, %lu} exceeds data length %lu", (unsigned long)r.location, (unsigned long)r.length, (unsigned long)_length];
    memcpy(buf, _bytes + r.location, r.length);
}
- (NSData *)subdataWithRange:(NSRange)r {
    if (NSMaxRange(r) > _length) [NSException raise:NSRangeException format:@"-[NSData subdataWithRange:]: range {%lu, %lu} exceeds data length %lu", (unsigned long)r.location, (unsigned long)r.length, (unsigned long)_length];
    return [NSData dataWithBytes:_bytes + r.location length:r.length];
}
- (BOOL)isEqualToData:(NSData *)o { return o.length == _length && (!_length || !memcmp(_bytes, o.bytes, _length)); }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[NSData class]] && [self isEqualToData:o]); }
- (NSUInteger)hash { NSUInteger h = _length; for (NSUInteger i = 0; i < MIN(_length, (NSUInteger)80); i++) h = h * 31 + _bytes[i]; return h; }
- (NSRange)rangeOfData:(NSData *)d options:(NSDataSearchOptions)opts range:(NSRange)r {
    NSUInteger n = d.length;
    if (!n || n > r.length) return NSMakeRange(NSNotFound, 0);
    const unsigned char *p = d.bytes;
    for (NSUInteger k = 0; k + n <= r.length; k++) {
        NSUInteger i = (opts & NSDataSearchBackwards) ? NSMaxRange(r) - n - k : r.location + k;
        if ((opts & NSDataSearchAnchored) && k > 0) break;
        if (!memcmp(_bytes + i, p, n)) return NSMakeRange(i, n);
    }
    return NSMakeRange(NSNotFound, 0);
}
- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(const void *bytes, NSRange byteRange, BOOL *stop))block { BOOL stop = NO; block(_bytes, NSMakeRange(0, _length), &stop); }
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)atomic { return [self writeToFile:path options:atomic ? NSDataWritingAtomic : 0 error:NULL]; }
- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)opts error:(NSError **)e {
    NSString *target = (opts & NSDataWritingAtomic) ? [path stringByAppendingFormat:@".isim-tmp-%d", getpid()] : path;
    int flags = O_WRONLY | O_CREAT | O_TRUNC | ((opts & NSDataWritingWithoutOverwriting) ? O_EXCL : 0);
    int fd = open(target.UTF8String, flags, 0644);
    if (fd < 0) { if (e) *e = [NSError errorWithDomain:NSCocoaErrorDomain code:(opts & NSDataWritingWithoutOverwriting) ? 516 : 4 userInfo:@{ @"NSFilePath": path }]; return NO; }
    NSUInteger off = 0;
    while (off < _length) { ssize_t w = write(fd, _bytes + off, _length - off); if (w <= 0) break; off += (NSUInteger)w; }
    close(fd);
    if (off != _length) { if (e) *e = [NSError errorWithDomain:NSCocoaErrorDomain code:512 userInfo:@{ @"NSFilePath": path }]; return NO; }
    if (target != path && rename(target.UTF8String, path.UTF8String) != 0) { unlink(target.UTF8String); if (e) *e = [NSError errorWithDomain:NSCocoaErrorDomain code:512 userInfo:@{ @"NSFilePath": path }]; return NO; }
    return YES;
}
- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)atomic { return url.isFileURL && [self writeToFile:url.path atomically:atomic]; }
- (BOOL)writeToURL:(NSURL *)url options:(NSDataWritingOptions)o error:(NSError **)e {
    if (!url.isFileURL) { if (e) *e = [NSError errorWithDomain:NSCocoaErrorDomain code:518 userInfo:nil]; return NO; }
    return [self writeToFile:url.path options:o error:e];
}
static const char B64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
- (NSString *)base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)opts {
    NSUInteger outLen = (_length + 2) / 3 * 4;
    NSUInteger lineLen = (opts & NSDataBase64Encoding64CharacterLineLength) ? 64 : (opts & NSDataBase64Encoding76CharacterLineLength) ? 76 : 0;
    char *out = malloc(outLen + (lineLen ? outLen / lineLen * 2 : 0) + 1); NSUInteger o = 0, col = 0;
    for (NSUInteger i = 0; i < _length; i += 3) {
        uint32_t v = (uint32_t)_bytes[i] << 16 | (i + 1 < _length ? (uint32_t)_bytes[i + 1] << 8 : 0) | (i + 2 < _length ? _bytes[i + 2] : 0);
        char q[4] = { B64[v >> 18 & 63], B64[v >> 12 & 63], i + 1 < _length ? B64[v >> 6 & 63] : '=', i + 2 < _length ? B64[v & 63] : '=' };
        for (int k = 0; k < 4; k++) {
            if (lineLen && col == lineLen) {
                if (opts & NSDataBase64EncodingEndLineWithCarriageReturn || !(opts & NSDataBase64EncodingEndLineWithLineFeed)) out[o++] = '\r';
                if (opts & NSDataBase64EncodingEndLineWithLineFeed || !(opts & NSDataBase64EncodingEndLineWithCarriageReturn)) out[o++] = '\n';
                col = 0;
            }
            out[o++] = q[k]; col++;
        }
    }
    return isim_string_take(out, o);
}
- (NSData *)base64EncodedDataWithOptions:(NSDataBase64EncodingOptions)opts { return [[self base64EncodedStringWithOptions:opts] dataUsingEncoding:NSUTF8StringEncoding]; }
static NSData *b64_decode(const char *s, NSUInteger n, BOOL ignoreUnknown) {
    NSMutableData *out = [NSMutableData dataWithCapacity:n * 3 / 4];
    uint32_t acc = 0; int bits = 0, pad = 0, chars = 0;
    for (NSUInteger i = 0; i < n; i++) {
        char c = s[i]; int v;
        if (c >= 'A' && c <= 'Z') v = c - 'A'; else if (c >= 'a' && c <= 'z') v = c - 'a' + 26; else if (c >= '0' && c <= '9') v = c - '0' + 52;
        else if (c == '+' || c == '-') v = 62; else if (c == '/' || c == '_') v = 63;
        else if (c == '=') { pad++; chars++; continue; }
        else if (ignoreUnknown || c == '\r' || c == '\n' || c == ' ' || c == '\t') continue;
        else return nil;
        if (pad) return nil;
        acc = acc << 6 | (uint32_t)v; bits += 6; chars++;
        if (bits >= 8) { bits -= 8; unsigned char b = (unsigned char)(acc >> bits); [out appendBytes:&b length:1]; }
    }
    if (chars % 4 != 0 && !ignoreUnknown) return nil;
    return out;
}
- (instancetype)initWithBase64EncodedString:(NSString *)s options:(NSDataBase64DecodingOptions)opts {
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    NSData *d = b64_decode(b, n, (opts & NSDataBase64DecodingIgnoreUnknownCharacters) != 0);
    return d ? [self initWithData:d] : nil;
}
- (instancetype)initWithBase64EncodedData:(NSData *)data options:(NSDataBase64DecodingOptions)opts {
    NSData *d = b64_decode(data.bytes, data.length, (opts & NSDataBase64DecodingIgnoreUnknownCharacters) != 0);
    return d ? [self initWithData:d] : nil;
}
- (NSString *)description {
    NSMutableString *s = [NSMutableString stringWithFormat:@"{length = %lu, bytes = 0x", (unsigned long)_length];
    NSUInteger show = _length <= 24 ? _length : 8;
    for (NSUInteger i = 0; i < show; i++) [s appendFormat:@"%02x", _bytes[i]];
    if (show < _length) { [s appendString:@" ... "]; for (NSUInteger i = _length - 4; i < _length; i++) [s appendFormat:@"%02x", _bytes[i]]; }
    [s appendString:@"}"];
    return s;
}
- (NSString *)debugDescription { return self.description; }
@end

@implementation NSMutableData
+ (instancetype)dataWithCapacity:(NSUInteger)n { return [[self alloc] initWithCapacity:n]; }
+ (instancetype)dataWithLength:(NSUInteger)n { return [[self alloc] initWithLength:n]; }
- (instancetype)initWithCapacity:(NSUInteger)n { if ((self = [self initWithBytes:NULL length:0])) { _cap = MAX(n, (NSUInteger)16); _bytes = realloc(_bytes, _cap); } return self; }
- (instancetype)initWithLength:(NSUInteger)n { if ((self = [self initWithCapacity:n])) { memset(_bytes, 0, n); _length = n; } return self; }
- (id)copyWithZone:(NSZone *)z { return [[NSData alloc] initWithData:self]; }
- (void)_reserve:(NSUInteger)n {
    if (n <= _cap && !_noFree && !_dealloc) return;
    NSUInteger cap = MAX(n, _cap * 2); if (cap < 16) cap = 16;
    unsigned char *nb = malloc(cap);
    if (_length) memcpy(nb, _bytes, _length);
    if (_dealloc) { _dealloc(_bytes, _length); _dealloc = nil; } else if (!_noFree) free(_bytes);
    _bytes = nb; _cap = cap; _noFree = NO;
}
- (void *)mutableBytes { return _bytes; }
- (void)setLength:(NSUInteger)n { [self _reserve:n]; if (n > _length) memset(_bytes + _length, 0, n - _length); _length = n; }
- (void)increaseLengthBy:(NSUInteger)n { [self setLength:_length + n]; }
- (void)appendBytes:(const void *)b length:(NSUInteger)n { if (!n) return; [self _reserve:_length + n]; memcpy(_bytes + _length, b, n); _length += n; }
- (void)appendData:(NSData *)d { [self appendBytes:d.bytes length:d.length]; }
- (void)replaceBytesInRange:(NSRange)r withBytes:(const void *)b { [self replaceBytesInRange:r withBytes:b length:r.length]; }
- (void)replaceBytesInRange:(NSRange)r withBytes:(const void *)b length:(NSUInteger)n {
    if (NSMaxRange(r) > _length) [self setLength:NSMaxRange(r)];
    NSUInteger newLen = _length - r.length + n;
    [self _reserve:newLen];
    memmove(_bytes + r.location + n, _bytes + NSMaxRange(r), _length - NSMaxRange(r));
    if (n) { if (b) memcpy(_bytes + r.location, b, n); else memset(_bytes + r.location, 0, n); }
    _length = newLen;
}
- (void)resetBytesInRange:(NSRange)r { if (NSMaxRange(r) > _length) [self setLength:NSMaxRange(r)]; memset(_bytes + r.location, 0, r.length); }
- (void)setData:(NSData *)d { [self setLength:0]; [self appendData:d]; }
@end

/* NSString <-> NSData */
@implementation NSString (IsimData)
- (NSData *)dataUsingEncoding:(NSStringEncoding)enc { return [self dataUsingEncoding:enc allowLossyConversion:NO]; }
- (NSData *)dataUsingEncoding:(NSStringEncoding)enc allowLossyConversion:(BOOL)lossy {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    if (enc == NSUTF8StringEncoding || enc == 0) return [NSData dataWithBytes:b length:n];
    NSUInteger len = self.length;
    if (enc == NSUTF16StringEncoding || enc == NSUTF16LittleEndianStringEncoding || enc == NSUTF16BigEndianStringEncoding || enc == NSUnicodeStringEncoding) {
        unichar *u = malloc(sizeof(unichar) * (len + 1)); [self getCharacters:u range:NSMakeRange(0, len)];
        NSMutableData *d = [NSMutableData data];
        BOOL be = enc == NSUTF16BigEndianStringEncoding;
        if (enc == NSUTF16StringEncoding) { unsigned char bom[2] = { 0xFF, 0xFE }; [d appendBytes:bom length:2]; }
        for (NSUInteger i = 0; i < len; i++) { unsigned char c[2] = { be ? (unsigned char)(u[i] >> 8) : (unsigned char)u[i], be ? (unsigned char)u[i] : (unsigned char)(u[i] >> 8) }; [d appendBytes:c length:2]; }
        free(u);
        return d;
    }
    if (enc == NSASCIIStringEncoding || enc == NSISOLatin1StringEncoding || enc == NSNonLossyASCIIStringEncoding) {
        unichar *u = malloc(sizeof(unichar) * (len + 1)); [self getCharacters:u range:NSMakeRange(0, len)];
        NSMutableData *d = [NSMutableData dataWithCapacity:len];
        unichar limit = enc == NSISOLatin1StringEncoding ? 0xFF : 0x7F;
        for (NSUInteger i = 0; i < len; i++) {
            if (u[i] > limit) { if (!lossy) { free(u); return nil; } unsigned char q = '?'; [d appendBytes:&q length:1]; }
            else { unsigned char c = (unsigned char)u[i]; [d appendBytes:&c length:1]; }
        }
        free(u);
        return d;
    }
    return [NSData dataWithBytes:b length:n];
}
@end
