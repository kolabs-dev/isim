/* isim Foundation (ARC): property lists — XML, binary ("bplist00") and OpenStep (read) — and
 * NSPropertyListSerialization. Also used for Info.plist, user defaults and keyed archives. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "isim_foundation.h"

static NSString *const NSDebugDescriptionErrorKey_isim = @"NSDebugDescription";

/* keyed-archive object references (binary type 0x8n, XML <dict><key>CF$UID</key>...) */
@implementation _IsimPlistUID
+ (instancetype)uidWithValue:(uint64_t)v { _IsimPlistUID *u = [self new]; u->_value = v; return u; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[_IsimPlistUID class]] && ((_IsimPlistUID *)o).value == _value; }
- (NSUInteger)hash { return (NSUInteger)_value; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<CFKeyedArchiverUID %p [%p]>{value = %llu}", self, self, (unsigned long long)_value]; }
@end

static BOOL is_bool(id o) { return [o isKindOfClass:[NSNumber class]] && [(NSNumber *)o _isim_isBool]; }
static BOOL is_real(NSNumber *n) { const char *t = n.objCType; return t && (*t == 'd' || *t == 'f'); }

/* ================= XML writer ================= */
static void xml_escape(NSMutableString *out, NSString *s) {
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    NSUInteger start = 0;
    for (NSUInteger i = 0; i < n; i++) {
        const char *rep = b[i] == '&' ? "&amp;" : b[i] == '<' ? "&lt;" : b[i] == '>' ? "&gt;" : NULL;
        if (!rep) continue;
        if (i > start) [out appendString:isim_string_copy(b + start, i - start)];
        [out appendString:@(rep)]; start = i + 1;
    }
    if (n > start) [out appendString:isim_string_copy(b + start, n - start)];
}
static void indent(NSMutableString *out, int d) { for (int i = 0; i < d; i++) [out appendString:@"\t"]; }
static NSString *iso_date(NSDate *d) {
    time_t t = (time_t)floor(d.timeIntervalSince1970); struct tm tm; gmtime_r(&t, &tm);
    return [NSString stringWithFormat:@"%04d-%02d-%02dT%02d:%02d:%02dZ", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec];
}
static BOOL xml_write(NSMutableString *out, id o, int d) {
    indent(out, d);
    if ([o isKindOfClass:[NSString class]]) { [out appendString:@"<string>"]; xml_escape(out, o); [out appendString:@"</string>\n"]; }
    else if (is_bool(o)) [out appendString:[o boolValue] ? @"<true/>\n" : @"<false/>\n"];
    else if ([o isKindOfClass:[NSNumber class]]) {
        if (is_real(o)) {
            double v = [o doubleValue];
            NSString *s = isnan(v) ? @"nan" : isinf(v) ? (v > 0 ? @"+infinity" : @"-infinity") : v == floor(v) && fabs(v) < 1e15 ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.17g", v];
            [out appendFormat:@"<real>%@</real>\n", s];
        } else if ([o objCType][0] == 'Q' || [o objCType][0] == 'L') [out appendFormat:@"<integer>%llu</integer>\n", [o unsignedLongLongValue]];
        else [out appendFormat:@"<integer>%lld</integer>\n", [o longLongValue]];
    }
    else if ([o isKindOfClass:[NSDate class]]) [out appendFormat:@"<date>%@</date>\n", iso_date(o)];
    else if ([o isKindOfClass:[NSData class]]) {
        [out appendString:@"<data>\n"]; indent(out, d);
        NSString *b64 = [o base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength | NSDataBase64EncodingEndLineWithLineFeed];
        [out appendString:[b64 stringByReplacingOccurrencesOfString:@"\n" withString:[@"\n" stringByPaddingToLength:(NSUInteger)d + 1 withString:@"\t" startingAtIndex:0]]];
        [out appendString:@"\n"]; indent(out, d); [out appendString:@"</data>\n"];
    }
    else if ([o isKindOfClass:[_IsimPlistUID class]]) {
        [out appendString:@"<dict>\n"]; indent(out, d + 1); [out appendString:@"<key>CF$UID</key>\n"]; indent(out, d + 1);
        [out appendFormat:@"<integer>%llu</integer>\n", (unsigned long long)((_IsimPlistUID *)o).value]; indent(out, d); [out appendString:@"</dict>\n"];
    }
    else if ([o isKindOfClass:[NSArray class]]) {
        if (![o count]) { [out appendString:@"<array/>\n"]; return YES; }
        [out appendString:@"<array>\n"];
        for (id x in o) if (!xml_write(out, x, d + 1)) return NO;
        indent(out, d); [out appendString:@"</array>\n"];
    }
    else if ([o isKindOfClass:[NSDictionary class]]) {
        if (![o count]) { [out appendString:@"<dict/>\n"]; return YES; }
        [out appendString:@"<dict>\n"];
        NSArray *keys = [[o allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (id k in keys) {
            if (![k isKindOfClass:[NSString class]]) return NO;
            indent(out, d + 1); [out appendString:@"<key>"]; xml_escape(out, k); [out appendString:@"</key>\n"];
            if (!xml_write(out, o[k], d + 1)) return NO;
        }
        indent(out, d); [out appendString:@"</dict>\n"];
    }
    else return NO;
    return YES;
}
NSString *isim_plist_write_xml(id root) {
    NSMutableString *out = [NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n"];
    if (!xml_write(out, root, 0)) return nil;
    [out appendString:@"</plist>\n"];
    return out;
}

/* ================= XML reader ================= */
typedef struct { const char *p, *end; BOOL mutableContainers, mutableLeaves; BOOL error; } xr_t;
static void xr_ws(xr_t *x) { while (x->p < x->end && isspace((unsigned char)*x->p)) x->p++; }
static void xr_skip_meta(xr_t *x) {
    for (;;) {
        xr_ws(x);
        if (x->p + 4 <= x->end && !strncmp(x->p, "<!--", 4)) { const char *e = strstr(x->p, "-->"); x->p = e ? e + 3 : x->end; continue; }
        if (x->p + 1 < x->end && x->p[0] == '<' && (x->p[1] == '?' || x->p[1] == '!')) { while (x->p < x->end && *x->p != '>') x->p++; if (x->p < x->end) x->p++; continue; }
        return;
    }
}
static NSString *xr_text(xr_t *x, const char *close) {
    const char *e = x->p; size_t cl = strlen(close);
    while (e + cl <= x->end && strncmp(e, close, cl)) e++;
    if (e + cl > x->end) { x->error = YES; e = x->end; }
    NSMutableData *buf = [NSMutableData dataWithCapacity:(NSUInteger)(e - x->p)];
    for (const char *q = x->p; q < e;) {
        if (*q == '&') {
            const char *semi = memchr(q, ';', (size_t)(e - q));
            if (semi) {
                size_t n = (size_t)(semi - q - 1); const char *name = q + 1;
                char tmp[8] = {0}; uint32_t cp = 0;
                if (n == 3 && !strncmp(name, "amp", 3)) cp = '&'; else if (n == 2 && !strncmp(name, "lt", 2)) cp = '<'; else if (n == 2 && !strncmp(name, "gt", 2)) cp = '>';
                else if (n == 4 && !strncmp(name, "quot", 4)) cp = '"'; else if (n == 4 && !strncmp(name, "apos", 4)) cp = '\'';
                else if (n > 1 && name[0] == '#') cp = (uint32_t)(name[1] == 'x' ? strtoul(name + 2, NULL, 16) : strtoul(name + 1, NULL, 10));
                if (cp) {
                    int k = 0;
                    if (cp < 0x80) tmp[k++] = (char)cp;
                    else if (cp < 0x800) { tmp[k++] = (char)(0xC0 | cp >> 6); tmp[k++] = (char)(0x80 | (cp & 0x3F)); }
                    else if (cp < 0x10000) { tmp[k++] = (char)(0xE0 | cp >> 12); tmp[k++] = (char)(0x80 | ((cp >> 6) & 0x3F)); tmp[k++] = (char)(0x80 | (cp & 0x3F)); }
                    else { tmp[k++] = (char)(0xF0 | cp >> 18); tmp[k++] = (char)(0x80 | ((cp >> 12) & 0x3F)); tmp[k++] = (char)(0x80 | ((cp >> 6) & 0x3F)); tmp[k++] = (char)(0x80 | (cp & 0x3F)); }
                    [buf appendBytes:tmp length:(NSUInteger)k]; q = semi + 1; continue;
                }
            }
        }
        if (!strncmp(q, "<![CDATA[", 9)) {
            const char *ce = strstr(q, "]]>");
            if (ce && ce < e) { [buf appendBytes:q + 9 length:(NSUInteger)(ce - q - 9)]; q = ce + 3; continue; }
        }
        [buf appendBytes:q length:1]; q++;
    }
    x->p = e + cl;
    return [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding] ?: @"";
}
static NSDate *parse_iso_date(NSString *s) {
    int y = 0, mo = 1, d = 1, h = 0, mi = 0; double sec = 0;
    if (sscanf(s.UTF8String, "%d-%d-%dT%d:%d:%lfZ", &y, &mo, &d, &h, &mi, &sec) < 3) return nil;
    struct tm tm = { .tm_year = y - 1900, .tm_mon = mo - 1, .tm_mday = d, .tm_hour = h, .tm_min = mi };
    return [NSDate dateWithTimeIntervalSince1970:(double)timegm(&tm) + sec];
}
static id xr_value(xr_t *x) {
    xr_skip_meta(x);
    if (x->p >= x->end || *x->p != '<') { x->error = YES; return nil; }
    char tag[32] = {0}; int n = 0;
    const char *q = x->p + 1;
    while (q < x->end && *q != '>' && !isspace((unsigned char)*q) && *q != '/' && n < 31) tag[n++] = *q++;
    while (q < x->end && *q != '>') q++;
    BOOL selfClosing = q > x->p && q[-1] == '/';
    x->p = q < x->end ? q + 1 : x->end;
    if (!strcmp(tag, "plist")) { id v = selfClosing ? nil : xr_value(x); xr_skip_meta(x); if (!strncmp(x->p, "</plist>", 8)) x->p += 8; return v; }
    if (!strcmp(tag, "true")) return @YES;
    if (!strcmp(tag, "false")) return @NO;
    if (!strcmp(tag, "dict")) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        if (!selfClosing) for (;;) {
            xr_skip_meta(x);
            if (x->p >= x->end) { x->error = YES; break; }
            if (!strncmp(x->p, "</dict>", 7)) { x->p += 7; break; }
            if (strncmp(x->p, "<key>", 5)) { if (!strncmp(x->p, "<key/>", 6)) { x->p += 6; id v = xr_value(x); if (v) d[@""] = v; continue; } x->error = YES; break; }
            x->p += 5;
            NSString *k = xr_text(x, "</key>");
            id v = xr_value(x);
            if (x->error) break;
            if (v) d[k] = v;
        }
        if (d.count == 1 && [d[@"CF$UID"] isKindOfClass:[NSNumber class]]) return [_IsimPlistUID uidWithValue:[d[@"CF$UID"] unsignedLongLongValue]];
        return x->mutableContainers ? d : [d copy];
    }
    if (!strcmp(tag, "array")) {
        NSMutableArray *a = [NSMutableArray array];
        if (!selfClosing) for (;;) {
            xr_skip_meta(x);
            if (x->p >= x->end) { x->error = YES; break; }
            if (!strncmp(x->p, "</array>", 8)) { x->p += 8; break; }
            id v = xr_value(x);
            if (!v || x->error) { x->error = YES; break; }
            [a addObject:v];
        }
        return x->mutableContainers ? a : [a copy];
    }
    if (selfClosing) {
        if (!strcmp(tag, "string")) return x->mutableLeaves ? [NSMutableString string] : @"";
        if (!strcmp(tag, "data")) return x->mutableLeaves ? [NSMutableData data] : [NSData data];
        x->error = YES; return nil;
    }
    char close[40]; snprintf(close, sizeof close, "</%s>", tag);
    NSString *text = xr_text(x, close);
    if (!strcmp(tag, "string")) return x->mutableLeaves ? [text mutableCopy] : text;
    if (!strcmp(tag, "integer")) {
        NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([t hasPrefix:@"0x"] || [t hasPrefix:@"0X"]) return @((long long)strtoull(t.UTF8String + 2, NULL, 16));
        if (t.length > 18 && ![t hasPrefix:@"-"]) return @((unsigned long long)strtoull(t.UTF8String, NULL, 10));
        return @(t.longLongValue);
    }
    if (!strcmp(tag, "real")) {
        NSString *t = [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        double v = [t isEqualToString:@"nan"] ? NAN : [t hasSuffix:@"infinity"] || [t hasSuffix:@"inf"] ? ([t hasPrefix:@"-"] ? -INFINITY : INFINITY) : strtod(t.UTF8String, NULL);
        return @(v);
    }
    if (!strcmp(tag, "date")) return parse_iso_date([text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
    if (!strcmp(tag, "data")) {
        NSData *d = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters] ?: [NSData data];
        return x->mutableLeaves ? [d mutableCopy] : d;
    }
    x->error = YES;
    return nil;
}

/* ================= OpenStep (ASCII) reader ================= */
typedef struct { const char *p, *end; BOOL error; } os_t;
static void os_ws(os_t *o) {
    for (;;) {
        while (o->p < o->end && isspace((unsigned char)*o->p)) o->p++;
        if (o->p + 1 < o->end && o->p[0] == '/' && o->p[1] == '/') { while (o->p < o->end && *o->p != '\n') o->p++; continue; }
        if (o->p + 1 < o->end && o->p[0] == '/' && o->p[1] == '*') { const char *e = strstr(o->p + 2, "*/"); o->p = e ? e + 2 : o->end; continue; }
        return;
    }
}
static id os_value(os_t *o) {
    os_ws(o);
    if (o->p >= o->end) { o->error = YES; return nil; }
    char c = *o->p;
    if (c == '{') {
        o->p++; NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (;;) {
            os_ws(o); if (o->p < o->end && *o->p == '}') { o->p++; break; }
            id k = os_value(o); os_ws(o);
            if (o->error || o->p >= o->end || *o->p != '=') { o->error = YES; return nil; }
            o->p++; id v = os_value(o); os_ws(o);
            if (o->error) return nil;
            if (k && v) d[k] = v;
            if (o->p < o->end && *o->p == ';') o->p++;
        }
        return d;
    }
    if (c == '(') {
        o->p++; NSMutableArray *a = [NSMutableArray array];
        for (;;) {
            os_ws(o); if (o->p < o->end && *o->p == ')') { o->p++; break; }
            id v = os_value(o); if (o->error) return nil;
            [a addObject:v]; os_ws(o);
            if (o->p < o->end && *o->p == ',') o->p++;
        }
        return a;
    }
    if (c == '<') {
        o->p++; NSMutableData *d = [NSMutableData data]; int hi = -1;
        while (o->p < o->end && *o->p != '>') {
            char h = *o->p++;
            if (!isxdigit((unsigned char)h)) continue;
            int v = isdigit((unsigned char)h) ? h - '0' : (tolower(h) - 'a' + 10);
            if (hi < 0) hi = v; else { unsigned char b = (unsigned char)(hi << 4 | v); [d appendBytes:&b length:1]; hi = -1; }
        }
        o->p++;
        return d;
    }
    if (c == '"') {
        o->p++; NSMutableData *buf = [NSMutableData data];
        while (o->p < o->end && *o->p != '"') {
            if (*o->p == '\\' && o->p + 1 < o->end) {
                o->p++; char e = *o->p++;
                char r = e == 'n' ? '\n' : e == 't' ? '\t' : e == 'r' ? '\r' : e;
                [buf appendBytes:&r length:1];
            } else { [buf appendBytes:o->p length:1]; o->p++; }
        }
        o->p++;
        return [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];
    }
    const char *s = o->p;
    while (o->p < o->end && (isalnum((unsigned char)*o->p) || strchr("_$+/:.-", *o->p))) o->p++;
    if (o->p == s) { o->error = YES; return nil; }
    return isim_string_copy(s, (NSUInteger)(o->p - s));
}

/* ================= binary ================= */
typedef struct { const uint8_t *b; NSUInteger n; unsigned offSize, refSize; uint64_t count, top, tableOff; BOOL mutableContainers; int depth; } bp_t;
static uint64_t be_int(const uint8_t *p, unsigned n) { uint64_t v = 0; for (unsigned i = 0; i < n; i++) v = v << 8 | p[i]; return v; }
static id bp_object(bp_t *b, uint64_t index);
static BOOL bp_len(bp_t *b, const uint8_t **p, uint8_t low, uint64_t *len) {
    if (low != 0xF) { *len = low; return YES; }
    const uint8_t *q = *p;
    if (q >= b->b + b->n || (*q & 0xF0) != 0x10) return NO;
    unsigned sz = 1u << (*q & 0xF); q++;
    if (q + sz > b->b + b->n) return NO;
    *len = be_int(q, sz); *p = q + sz;
    return YES;
}
static id bp_object(bp_t *b, uint64_t index) {
    if (index >= b->count || ++b->depth > 512) return nil;
    uint64_t off = be_int(b->b + b->tableOff + index * b->offSize, b->offSize);
    if (off >= b->n) { b->depth--; return nil; }
    const uint8_t *p = b->b + off, *end = b->b + b->n;
    uint8_t marker = *p++, hi = marker >> 4, lo = marker & 0xF;
    id result = nil;
    switch (hi) {
    case 0x0: result = marker == 0x08 ? @NO : marker == 0x09 ? @YES : [NSNull null]; break;
    case 0x1: {
        unsigned sz = 1u << lo; if (p + sz > end) break;
        if (sz == 16) result = @((unsigned long long)be_int(p + 8, 8));
        else if (sz == 8) result = @((long long)be_int(p, 8));
        else result = @((long long)be_int(p, sz));
        break;
    }
    case 0x2: {
        if (lo == 2 && p + 4 <= end) { uint32_t u = (uint32_t)be_int(p, 4); float f; memcpy(&f, &u, 4); result = @((double)f); }
        else if (lo == 3 && p + 8 <= end) { uint64_t u = be_int(p, 8); double d; memcpy(&d, &u, 8); result = @(d); }
        break;
    }
    case 0x3: if (p + 8 <= end) { uint64_t u = be_int(p, 8); double d; memcpy(&d, &u, 8); result = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:d]; } break;
    case 0x4: { uint64_t len; if (!bp_len(b, &p, lo, &len) || p + len > end) break; result = [NSData dataWithBytes:p length:(NSUInteger)len]; break; }
    case 0x5: { uint64_t len; if (!bp_len(b, &p, lo, &len) || p + len > end) break; result = [[NSString alloc] initWithBytes:p length:(NSUInteger)len encoding:NSISOLatin1StringEncoding]; break; }
    case 0x6: {
        uint64_t len; if (!bp_len(b, &p, lo, &len) || p + len * 2 > end) break;
        unichar *u = malloc(sizeof(unichar) * (size_t)(len + 1));
        for (uint64_t i = 0; i < len; i++) u[i] = (unichar)be_int(p + i * 2, 2);
        result = [NSString stringWithCharacters:u length:(NSUInteger)len]; free(u);
        break;
    }
    case 0x8: if (p + lo + 1 <= end) result = [_IsimPlistUID uidWithValue:be_int(p, lo + 1u)]; break;
    case 0xA: case 0xC: {
        uint64_t len; if (!bp_len(b, &p, lo, &len) || p + len * b->refSize > end) break;
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:(NSUInteger)len];
        for (uint64_t i = 0; i < len; i++) { id v = bp_object(b, be_int(p + i * b->refSize, b->refSize)); if (!v) { b->depth--; return nil; } [a addObject:v]; }
        result = hi == 0xC ? (b->mutableContainers ? [NSMutableSet setWithArray:a] : [NSSet setWithArray:a]) : (b->mutableContainers ? a : [a copy]);
        break;
    }
    case 0xD: {
        uint64_t len; if (!bp_len(b, &p, lo, &len) || p + len * 2 * b->refSize > end) break;
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:(NSUInteger)len];
        for (uint64_t i = 0; i < len; i++) {
            id k = bp_object(b, be_int(p + i * b->refSize, b->refSize));
            id v = bp_object(b, be_int(p + (len + i) * b->refSize, b->refSize));
            if (!k || !v) { b->depth--; return nil; }
            d[k] = v;
        }
        result = b->mutableContainers ? d : [d copy];
        break;
    }
    default: break;
    }
    b->depth--;
    return result;
}
static id bp_read(const uint8_t *bytes, NSUInteger n, BOOL mutableContainers) {
    if (n < 40 || memcmp(bytes, "bplist0", 7)) return nil;
    const uint8_t *t = bytes + n - 32;
    bp_t b = { bytes, n, t[6], t[7], be_int(t + 8, 8), be_int(t + 16, 8), be_int(t + 24, 8), mutableContainers, 0 };
    if (!b.offSize || !b.refSize || b.offSize > 8 || b.refSize > 8 || b.tableOff + b.count * b.offSize > n - 32) return nil;
    return bp_object(&b, b.top);
}

/* writer: objects are flattened (strings, numbers and dates uniqued), then written with an offset table */
@interface _IsimBPWriter : NSObject {
    @public NSMutableArray *_objects; NSMutableDictionary *_unique; NSMutableData *_out; unsigned _refSize;
}
@end
@implementation _IsimBPWriter
- (instancetype)init { if ((self = [super init])) { _objects = [NSMutableArray array]; _unique = [NSMutableDictionary dictionary]; } return self; }
- (BOOL)_flatten:(id)o index:(uint64_t *)out {
    BOOL leaf = [o isKindOfClass:[NSString class]] || [o isKindOfClass:[NSNumber class]] || [o isKindOfClass:[NSDate class]] || [o isKindOfClass:[NSData class]] || [o isKindOfClass:[_IsimPlistUID class]];
    if (leaf) {
        id key = [o isKindOfClass:[NSNumber class]] ? @[is_bool(o) ? @"b" : is_real(o) ? @"r" : @"i", o] : [o isKindOfClass:[NSString class]] ? @[@"s", o] : @[NSStringFromClass([o class]), o];
        NSNumber *idx = _unique[key];
        if (idx) { *out = idx.unsignedLongLongValue; return YES; }
        *out = _objects.count; [_objects addObject:o]; _unique[key] = @(*out);
        return YES;
    }
    if ([o isKindOfClass:[NSNull class]]) { *out = _objects.count; [_objects addObject:o]; return YES; }
    uint64_t me = _objects.count;
    if ([o isKindOfClass:[NSArray class]] || [o isKindOfClass:[NSSet class]] || [o isKindOfClass:[NSOrderedSet class]]) {
        NSMutableArray *refs = [NSMutableArray array];
        [_objects addObject:@[[o isKindOfClass:[NSSet class]] ? @"set" : @"array", refs]];
        for (id x in ([o isKindOfClass:[NSOrderedSet class]] ? [o array] : o)) { uint64_t r; if (![self _flatten:x index:&r]) return NO; [refs addObject:@(r)]; }
    } else if ([o isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *krefs = [NSMutableArray array], *vrefs = [NSMutableArray array];
        [_objects addObject:@[@"dict", krefs, vrefs]];
        for (id k in o) {
            uint64_t kr, vr;
            if (![self _flatten:k index:&kr] || ![self _flatten:o[k] index:&vr]) return NO;
            [krefs addObject:@(kr)]; [vrefs addObject:@(vr)];
        }
    } else return NO;
    *out = me;
    return YES;
}
static void put_be(NSMutableData *d, uint64_t v, unsigned n) { uint8_t b[8]; for (unsigned i = 0; i < n; i++) b[i] = (uint8_t)(v >> (8 * (n - 1 - i))); [d appendBytes:b length:n]; }
static unsigned bytes_for(uint64_t v) { return v < 0x100 ? 1 : v < 0x10000 ? 2 : v < 0x100000000ULL ? 4 : 8; }
static void put_marker(NSMutableData *d, uint8_t hi, uint64_t len) {
    if (len < 15) { uint8_t m = (uint8_t)(hi << 4 | len); [d appendBytes:&m length:1]; return; }
    uint8_t m = (uint8_t)(hi << 4 | 0xF); [d appendBytes:&m length:1];
    unsigned sz = bytes_for(len); uint8_t im = (uint8_t)(0x10 | (sz == 1 ? 0 : sz == 2 ? 1 : sz == 4 ? 2 : 3));
    [d appendBytes:&im length:1]; put_be(d, len, sz);
}
- (void)_write:(id)o {
    NSMutableData *d = _out;
    if ([o isKindOfClass:[NSNull class]]) { uint8_t m = 0x00; [d appendBytes:&m length:1]; }
    else if (is_bool(o)) { uint8_t m = [o boolValue] ? 0x09 : 0x08; [d appendBytes:&m length:1]; }
    else if ([o isKindOfClass:[NSNumber class]]) {
        if (is_real(o)) { uint8_t m = 0x23; [d appendBytes:&m length:1]; double v = [o doubleValue]; uint64_t u; memcpy(&u, &v, 8); put_be(d, u, 8); }
        else {
            const char *t = [o objCType];
            unsigned long long uv = [o unsignedLongLongValue]; long long sv = [o longLongValue];
            if ((t[0] == 'Q' || t[0] == 'L') && uv > (unsigned long long)LLONG_MAX) { uint8_t m = 0x14; [d appendBytes:&m length:1]; put_be(d, 0, 8); put_be(d, uv, 8); }
            else if (sv < 0) { uint8_t m = 0x13; [d appendBytes:&m length:1]; put_be(d, (uint64_t)sv, 8); }
            else { unsigned sz = bytes_for((uint64_t)sv); uint8_t m = (uint8_t)(0x10 | (sz == 1 ? 0 : sz == 2 ? 1 : sz == 4 ? 2 : 3)); [d appendBytes:&m length:1]; put_be(d, (uint64_t)sv, sz); }
        }
    }
    else if ([o isKindOfClass:[NSDate class]]) { uint8_t m = 0x33; [d appendBytes:&m length:1]; double v = [o timeIntervalSinceReferenceDate]; uint64_t u; memcpy(&u, &v, 8); put_be(d, u, 8); }
    else if ([o isKindOfClass:[NSData class]]) { put_marker(d, 0x4, [o length]); [d appendData:o]; }
    else if ([o isKindOfClass:[_IsimPlistUID class]]) { uint64_t v = ((_IsimPlistUID *)o).value; unsigned sz = bytes_for(v); put_marker(d, 0x8, sz - 1); put_be(d, v, sz); }
    else if ([o isKindOfClass:[NSString class]]) {
        NSUInteger n; const char *b = [o _isim_bytes:&n];
        BOOL ascii = YES; for (NSUInteger i = 0; i < n; i++) if ((unsigned char)b[i] >= 0x80) { ascii = NO; break; }
        if (ascii) { put_marker(d, 0x5, n); [d appendBytes:b length:n]; }
        else {
            NSUInteger len = [o length]; unichar *u = malloc(sizeof(unichar) * (len + 1)); [o getCharacters:u range:NSMakeRange(0, len)];
            put_marker(d, 0x6, len); for (NSUInteger i = 0; i < len; i++) put_be(d, u[i], 2); free(u);
        }
    }
    else if ([o isKindOfClass:[NSArray class]]) {
        NSString *kind = o[0];
        if ([kind isEqualToString:@"dict"]) {
            NSArray *k = o[1], *v = o[2]; put_marker(d, 0xD, k.count);
            for (NSNumber *r in k) put_be(d, r.unsignedLongLongValue, _refSize);
            for (NSNumber *r in v) put_be(d, r.unsignedLongLongValue, _refSize);
        } else {
            NSArray *refs = o[1]; put_marker(d, [kind isEqualToString:@"set"] ? 0xC : 0xA, refs.count);
            for (NSNumber *r in refs) put_be(d, r.unsignedLongLongValue, _refSize);
        }
    }
}
- (NSData *)dataFor:(id)root {
    uint64_t top;
    if (![self _flatten:root index:&top]) return nil;
    _refSize = bytes_for(_objects.count);
    _out = [NSMutableData dataWithBytes:"bplist00" length:8];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:_objects.count];
    for (id o in _objects) { [offsets addObject:@(_out.length)]; [self _write:o]; }
    uint64_t tableOff = _out.length;
    unsigned offSize = bytes_for(tableOff);
    for (NSNumber *o in offsets) put_be(_out, o.unsignedLongLongValue, offSize);
    uint8_t trailer[6] = {0}; [_out appendBytes:trailer length:6];
    uint8_t sizes[2] = { (uint8_t)offSize, (uint8_t)_refSize }; [_out appendBytes:sizes length:2];
    put_be(_out, _objects.count, 8); put_be(_out, top, 8); put_be(_out, tableOff, 8);
    return _out;
}
@end

/* ================= entry points ================= */
id isim_plist_read(const void *bytes, NSUInteger len, NSPropertyListReadOptions opts, NSPropertyListFormat *format) {
    const char *s = bytes;
    if (len >= 8 && !memcmp(s, "bplist0", 7)) { if (format) *format = NSPropertyListBinaryFormat_v1_0; return bp_read(bytes, len, opts != NSPropertyListImmutable); }
    /* skip a UTF-8 BOM and leading space */
    NSUInteger i = 0;
    if (len >= 3 && !memcmp(s, "\xEF\xBB\xBF", 3)) i = 3;
    while (i < len && isspace((unsigned char)s[i])) i++;
    if (i < len && s[i] == '<' && (i + 1 < len && (s[i + 1] == '?' || s[i + 1] == '!' || s[i + 1] == 'p'))) {
        xr_t x = { s + i, s + len, opts != NSPropertyListImmutable, opts == NSPropertyListMutableContainersAndLeaves, NO };
        id v = xr_value(&x);
        if (x.error && !v) return nil;
        if (format) *format = NSPropertyListXMLFormat_v1_0;
        return v;
    }
    os_t o = { s + i, s + len, NO };
    id v = os_value(&o);
    if (o.error) return nil;
    if (format) *format = NSPropertyListOpenStepFormat;
    return v;
}
id isim_plist_parse(const char *xml, NSUInteger len) { return isim_plist_read(xml, len, NSPropertyListMutableContainers, NULL); }
NSData *isim_plist_binary(id root) { return [[_IsimBPWriter new] dataFor:root]; }

@implementation NSPropertyListSerialization
+ (BOOL)propertyList:(id)plist isValidForFormat:(NSPropertyListFormat)format {
    if (format == NSPropertyListOpenStepFormat) return NO;
    return format == NSPropertyListXMLFormat_v1_0 ? isim_plist_write_xml(plist) != nil : isim_plist_binary(plist) != nil;
}
+ (NSData *)dataWithPropertyList:(id)plist format:(NSPropertyListFormat)format options:(NSPropertyListWriteOptions)opt error:(NSError **)error {
    NSData *d = nil;
    if (format == NSPropertyListXMLFormat_v1_0) d = [isim_plist_write_xml(plist) dataUsingEncoding:NSUTF8StringEncoding];
    else if (format == NSPropertyListBinaryFormat_v1_0) d = isim_plist_binary(plist);
    if (!d && error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3851 userInfo:@{ NSDebugDescriptionErrorKey_isim: format == NSPropertyListOpenStepFormat ? @"The OpenStep format is not supported for writing" : @"Property list invalid for format" }];
    return d;
}
+ (id)propertyListWithData:(NSData *)data options:(NSPropertyListReadOptions)opt format:(NSPropertyListFormat *)format error:(NSError **)error {
    id v = data ? isim_plist_read(data.bytes, data.length, opt, format) : nil;
    if (!v && error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:@{ NSDebugDescriptionErrorKey_isim: @"The data couldn’t be read because it isn’t in the correct format." }];
    return v;
}
@end
