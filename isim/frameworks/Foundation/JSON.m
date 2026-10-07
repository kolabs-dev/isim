/* isim Foundation: NSJSONSerialization for Objective-C (ARC). A small recursive-descent reader and a writer. */
#import <Foundation/Foundation.h>
#import <Foundation/NSJSONSerialization.h>
#include <math.h>
#include <errno.h>
#include <stdlib.h>

static NSError *json_error(NSString *msg, NSUInteger pos) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:3840
                           userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ around character %lu.", msg, (unsigned long)pos] }];
}

/* ---- reading ---- */
typedef struct { const unsigned char *p; NSUInteger n, i; NSJSONReadingOptions opt; NSString *err; int depth; } jr;
static void ws(jr *r) { while (r->i < r->n && (r->p[r->i] == ' ' || r->p[r->i] == '\t' || r->p[r->i] == '\n' || r->p[r->i] == '\r')) r->i++; }
static id jvalue(jr *r);
static int hex4(jr *r, unsigned *out) {
    if (r->i + 4 > r->n) return 0;
    unsigned v = 0;
    for (int k = 0; k < 4; k++) {
        unsigned char c = r->p[r->i + k]; v <<= 4;
        if (c >= '0' && c <= '9') v |= c - '0'; else if (c >= 'a' && c <= 'f') v |= c - 'a' + 10; else if (c >= 'A' && c <= 'F') v |= c - 'A' + 10; else return 0;
    }
    r->i += 4; *out = v; return 1;
}
static void put_utf8(NSMutableData *d, unsigned cp) {
    unsigned char b[4]; int n;
    if (cp < 0x80) { b[0] = cp; n = 1; }
    else if (cp < 0x800) { b[0] = 0xC0 | (cp >> 6); b[1] = 0x80 | (cp & 0x3F); n = 2; }
    else if (cp < 0x10000) { b[0] = 0xE0 | (cp >> 12); b[1] = 0x80 | ((cp >> 6) & 0x3F); b[2] = 0x80 | (cp & 0x3F); n = 3; }
    else { b[0] = 0xF0 | (cp >> 18); b[1] = 0x80 | ((cp >> 12) & 0x3F); b[2] = 0x80 | ((cp >> 6) & 0x3F); b[3] = 0x80 | (cp & 0x3F); n = 4; }
    [d appendBytes:b length:n];
}
static NSString *jstring(jr *r) {
    r->i++;                                                     /* the opening quote */
    NSMutableData *d = [NSMutableData data];
    while (r->i < r->n) {
        unsigned char c = r->p[r->i++];
        if (c == '"') {
            NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            if (!s) r->err = @"Invalid UTF-8 in string";
            return (r->opt & NSJSONReadingMutableLeaves) ? [s mutableCopy] : s;
        }
        if (c < 0x20) { r->err = @"Unescaped control character"; return nil; }
        if (c != '\\') { [d appendBytes:&c length:1]; continue; }
        if (r->i >= r->n) break;
        unsigned char e = r->p[r->i++]; unsigned cp;
        switch (e) {
        case '"': case '\\': case '/': [d appendBytes:&e length:1]; break;
        case 'b': put_utf8(d, 8); break; case 'f': put_utf8(d, 12); break; case 'n': put_utf8(d, 10); break;
        case 'r': put_utf8(d, 13); break; case 't': put_utf8(d, 9); break;
        case 'u':
            if (!hex4(r, &cp)) { r->err = @"Invalid \\u escape"; return nil; }
            if (cp >= 0xD800 && cp < 0xDC00 && r->i + 6 <= r->n && r->p[r->i] == '\\' && r->p[r->i + 1] == 'u') {
                unsigned lo; NSUInteger save = r->i; r->i += 2;
                if (hex4(r, &lo) && lo >= 0xDC00 && lo < 0xE000) cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00); else r->i = save;
            }
            put_utf8(d, cp); break;
        default: r->err = @"Invalid escape sequence"; return nil;
        }
    }
    r->err = @"Unterminated string"; return nil;
}
static id jnumber(jr *r) {
    NSUInteger s = r->i; BOOL real = NO;
    if (r->i < r->n && r->p[r->i] == '-') r->i++;
    while (r->i < r->n) {
        unsigned char c = r->p[r->i];
        if (c >= '0' && c <= '9') r->i++;
        else if (c == '.' || c == 'e' || c == 'E' || c == '+' || (c == '-' && r->i > s)) { real = YES; r->i++; }
        else break;
    }
    if (r->i == s) { r->err = @"Invalid value"; return nil; }
    char buf[64]; NSUInteger l = MIN(r->i - s, (NSUInteger)63); memcpy(buf, r->p + s, l); buf[l] = 0;
    if (!real) {
        errno = 0; long long v = strtoll(buf, NULL, 10);
        if (errno != ERANGE) return @(v);
        if (buf[0] != '-') { errno = 0; unsigned long long u = strtoull(buf, NULL, 10); if (errno != ERANGE) return @(u); }
    }
    return @(strtod(buf, NULL));
}
static id jvalue(jr *r) {
    ws(r);
    if (r->i >= r->n) { r->err = @"Unexpected end of data"; return nil; }
    if (++r->depth > 512) { r->err = @"Too deeply nested"; return nil; }
    unsigned char c = r->p[r->i]; id v = nil;
    if (c == '{') {
        r->i++;
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        ws(r);
        if (r->i < r->n && r->p[r->i] == '}') r->i++;
        else for (;;) {
            ws(r);
            if (r->i >= r->n || r->p[r->i] != '"') { r->err = @"Expected a string key"; return nil; }
            NSString *k = jstring(r); if (!k) return nil;
            ws(r);
            if (r->i >= r->n || r->p[r->i] != ':') { r->err = @"Expected ':'"; return nil; }
            r->i++;
            id x = jvalue(r); if (!x) return nil;
            d[k] = x;
            ws(r);
            if (r->i < r->n && r->p[r->i] == ',') { r->i++; continue; }
            if (r->i < r->n && r->p[r->i] == '}') { r->i++; break; }
            r->err = @"Expected ',' or '}'"; return nil;
        }
        v = (r->opt & NSJSONReadingMutableContainers) ? d : [d copy];
    } else if (c == '[') {
        r->i++;
        NSMutableArray *a = [NSMutableArray array];
        ws(r);
        if (r->i < r->n && r->p[r->i] == ']') r->i++;
        else for (;;) {
            id x = jvalue(r); if (!x) return nil;
            [a addObject:x];
            ws(r);
            if (r->i < r->n && r->p[r->i] == ',') { r->i++; continue; }
            if (r->i < r->n && r->p[r->i] == ']') { r->i++; break; }
            r->err = @"Expected ',' or ']'"; return nil;
        }
        v = (r->opt & NSJSONReadingMutableContainers) ? a : [a copy];
    } else if (c == '"') v = jstring(r);
    else if (r->n - r->i >= 4 && !memcmp(r->p + r->i, "true", 4)) { r->i += 4; v = @YES; }
    else if (r->n - r->i >= 5 && !memcmp(r->p + r->i, "false", 5)) { r->i += 5; v = @NO; }
    else if (r->n - r->i >= 4 && !memcmp(r->p + r->i, "null", 4)) { r->i += 4; v = [NSNull null]; }
    else if (c == '-' || (c >= '0' && c <= '9')) v = jnumber(r);
    else r->err = @"Invalid value";
    r->depth--;
    return v;
}

/* ---- writing ---- */
static BOOL is_bool(NSNumber *n) { const char *t = n.objCType; return t && t[0] == 'c' && !t[1]; }
static BOOL jwrite(id o, NSMutableString *out, NSJSONWritingOptions opt, int indent, BOOL top) {
    BOOL pretty = (opt & NSJSONWritingPrettyPrinted) != 0;
    if ([o isKindOfClass:[NSDictionary class]] || [o isKindOfClass:[NSArray class]]) {
        BOOL dict = [o isKindOfClass:[NSDictionary class]];
        NSArray *keys = dict ? [o allKeys] : nil;
        if (dict) {
            for (id k in keys) if (![k isKindOfClass:[NSString class]]) return NO;
            if (opt & NSJSONWritingSortedKeys) keys = [keys sortedArrayUsingSelector:@selector(compare:)];
        }
        NSUInteger count = dict ? keys.count : [o count];
        [out appendString:dict ? @"{" : @"["];
        for (NSUInteger i = 0; i < count; i++) {
            if (i) [out appendString:@","];
            if (pretty) { [out appendString:@"\n"]; for (int k = 0; k <= indent; k++) [out appendString:@"  "]; }
            if (dict) {
                if (!jwrite(keys[i], out, opt, indent + 1, NO)) return NO;
                [out appendString:pretty ? @" : " : @":"];
                if (!jwrite([o objectForKey:keys[i]], out, opt, indent + 1, NO)) return NO;
            } else if (!jwrite([o objectAtIndex:i], out, opt, indent + 1, NO)) return NO;
        }
        if (pretty && count) { [out appendString:@"\n"]; for (int k = 0; k < indent; k++) [out appendString:@"  "]; }
        [out appendString:dict ? @"}" : @"]"];
        return YES;
    }
    if (top && !(opt & NSJSONWritingFragmentsAllowed)) return NO;
    if ([o isKindOfClass:[NSString class]]) {
        NSString *s = o;
        [out appendString:@"\""];
        for (NSUInteger i = 0; i < s.length; i++) {
            unichar c = [s characterAtIndex:i];
            switch (c) {
            case '"': [out appendString:@"\\\""]; break;
            case '\\': [out appendString:@"\\\\"]; break;
            case '/': [out appendString:(opt & NSJSONWritingWithoutEscapingSlashes) ? @"/" : @"\\/"]; break;
            case '\n': [out appendString:@"\\n"]; break;
            case '\r': [out appendString:@"\\r"]; break;
            case '\t': [out appendString:@"\\t"]; break;
            case '\b': [out appendString:@"\\b"]; break;
            case '\f': [out appendString:@"\\f"]; break;
            default:
                if (c < 0x20) [out appendFormat:@"\\u%04x", c];
                else [out appendString:[NSString stringWithCharacters:&c length:1]];
            }
        }
        [out appendString:@"\""];
        return YES;
    }
    if ([o isKindOfClass:[NSNumber class]]) {
        NSNumber *n = o;
        if (is_bool(n)) { [out appendString:n.boolValue ? @"true" : @"false"]; return YES; }
        const char *t = n.objCType;
        if (t && (t[0] == 'd' || t[0] == 'f')) {
            double d = n.doubleValue;
            if (!isfinite(d)) return NO;
            if (d == floor(d) && fabs(d) < 1e15) [out appendFormat:@"%lld", (long long)d];
            else [out appendFormat:@"%.17g", d];
        } else if (t && t[0] == 'Q') [out appendFormat:@"%llu", n.unsignedLongLongValue];
        else [out appendFormat:@"%lld", n.longLongValue];
        return YES;
    }
    if ([o isKindOfClass:[NSNull class]]) { [out appendString:@"null"]; return YES; }
    return NO;
}

@implementation NSJSONSerialization
+ (BOOL)isValidJSONObject:(id)obj {
    if (![obj isKindOfClass:[NSDictionary class]] && ![obj isKindOfClass:[NSArray class]]) return NO;
    NSMutableString *s = [NSMutableString string];
    return jwrite(obj, s, 0, 0, YES);
}
+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error {
    NSMutableString *s = [NSMutableString string];
    if (!obj || !jwrite(obj, s, opt, 0, YES)) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3851 userInfo:@{ NSLocalizedDescriptionKey: @"Invalid type in JSON write" }];
        return nil;
    }
    return [s dataUsingEncoding:NSUTF8StringEncoding];
}
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    if (!data) { if (error) *error = json_error(@"No data", 0); return nil; }
    jr r = { data.bytes, data.length, 0, opt, nil, 0 };
    if (r.n >= 3 && r.p[0] == 0xEF && r.p[1] == 0xBB && r.p[2] == 0xBF) r.i = 3;
    ws(&r);
    if (r.i < r.n && r.p[r.i] != '{' && r.p[r.i] != '[' && !(opt & NSJSONReadingFragmentsAllowed)) {
        if (error) *error = json_error(@"JSON text did not start with array or object and option to allow fragments not set", r.i);
        return nil;
    }
    id v = jvalue(&r);
    if (v) { ws(&r); if (r.i < r.n) { v = nil; r.err = @"Garbage at end"; } }
    if (!v && error) *error = json_error(r.err ?: @"Invalid JSON", r.i);
    return v;
}
@end
