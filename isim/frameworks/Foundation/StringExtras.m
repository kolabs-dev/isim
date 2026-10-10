/* isim Foundation (ARC): more NSString API — ranged/regex search and replace, Unicode case mapping,
 * diacritic folding, line/word/character enumeration, Scanner-free helpers. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <string.h>
#include "isim_foundation.h"
#include "isim_locale.h"
#include <isim_host.h>

/* ---------------- Unicode case mapping (Latin, Greek, Cyrillic, Armenian, fullwidth) ---------------- */
uint32_t isim_case_map(uint32_t c, int upper) {
    if (c < 0x80) return upper ? (uint32_t)toupper((int)c) : (uint32_t)tolower((int)c);
    if (upper) {
        if ((c >= 0xE0 && c <= 0xFE && c != 0xF7)) return c - 0x20;
        if (c == 0xFF) return 0x178;
        if (c == 0xB5) return 0x39C;
        if ((c >= 0x100 && c <= 0x137) || (c >= 0x14A && c <= 0x177)) return c & 1 ? c - 1 : c;
        if ((c >= 0x139 && c <= 0x148) || (c >= 0x179 && c <= 0x17E)) return c & 1 ? c : c - 1;
        if (c == 0x131) return 'I';
        if (c == 0x17F) return 'S';
        if (c >= 0x1CD && c <= 0x1DC) return c & 1 ? c : c - 1;
        if (c >= 0x1DE && c <= 0x1EF) return c & 1 ? c - 1 : c;
        if (c >= 0x1F8 && c <= 0x24F) return c & 1 ? c - 1 : c;
        if (c >= 0x3B1 && c <= 0x3C9 && c != 0x3C2) return c - 0x20;
        if (c == 0x3C2) return 0x3A3;
        if (c == 0x3AC) return 0x386;
        if (c >= 0x3AD && c <= 0x3AF) return c - 0x25;
        if (c == 0x3CC) return 0x38C;
        if (c == 0x3CD || c == 0x3CE) return c - 0x3F;
        if (c >= 0x430 && c <= 0x44F) return c - 0x20;
        if (c >= 0x450 && c <= 0x45F) return c - 0x50;
        if ((c >= 0x460 && c <= 0x481) || (c >= 0x48A && c <= 0x4BF) || (c >= 0x4D0 && c <= 0x52F)) return c & 1 ? c - 1 : c;
        if (c >= 0x561 && c <= 0x586) return c - 0x30;
        if (c >= 0x1E00 && c <= 0x1EFF) return c & 1 ? c - 1 : c;
        if (c >= 0xFF41 && c <= 0xFF5A) return c - 0x20;
    } else {
        if ((c >= 0xC0 && c <= 0xDE && c != 0xD7)) return c + 0x20;
        if (c == 0x178) return 0xFF;
        if ((c >= 0x100 && c <= 0x137) || (c >= 0x14A && c <= 0x177)) return c & 1 ? c : c + 1;
        if ((c >= 0x139 && c <= 0x148) || (c >= 0x179 && c <= 0x17E)) return c & 1 ? c + 1 : c;
        if (c == 0x130) return 'i';
        if (c >= 0x1CD && c <= 0x1DC) return c & 1 ? c + 1 : c;
        if (c >= 0x1DE && c <= 0x1EF) return c & 1 ? c : c + 1;
        if (c >= 0x1F8 && c <= 0x24F) return c & 1 ? c : c + 1;
        if (c >= 0x391 && c <= 0x3A9 && c != 0x3A2) return c + 0x20;
        if (c == 0x386) return 0x3AC;
        if (c >= 0x388 && c <= 0x38A) return c + 0x25;
        if (c == 0x38C) return 0x3CC;
        if (c == 0x38E || c == 0x38F) return c + 0x3F;
        if (c >= 0x410 && c <= 0x42F) return c + 0x20;
        if (c >= 0x400 && c <= 0x40F) return c + 0x50;
        if ((c >= 0x460 && c <= 0x481) || (c >= 0x48A && c <= 0x4BF) || (c >= 0x4D0 && c <= 0x52F)) return c & 1 ? c : c + 1;
        if (c >= 0x531 && c <= 0x556) return c + 0x30;
        if (c >= 0x1E00 && c <= 0x1EFF) return c & 1 ? c : c + 1;
        if (c >= 0xFF21 && c <= 0xFF3A) return c + 0x20;
    }
    return c;
}

/* base letter of a precomposed Latin letter (diacritic-insensitive search) */
static uint32_t strip_diacritic(uint32_t c) {
    static const char *latin1 = "AAAAAAACEEEEIIIIDNOOOOO*OUUUUYTsaaaaaaaceeeeiiiidnooooo/ouuuuyty";
    if (c >= 0xC0 && c <= 0xFF) { char b = latin1[c - 0xC0]; return b == '*' || b == '/' || b == 'T' || b == 't' || b == 's' ? c : (uint32_t)b; }
    static const char extA[] = "AaAaAaCcCcCcCcDd\0\0EeEeEeEeEeGgGgGgGgHh\0\0IiIiIiIiI\0\0\0JjKk\0LlLlLl\0\0\0\0NnNnNn\0\0\0OoOoOo\0\0RrRrRrSsSsSsSsTtTt\0\0UuUuUuUuUuUuWwYyYZzZzZz\0";
    if (c >= 0x100 && c <= 0x17F) { char b = extA[c - 0x100]; return b ? (uint32_t)(unsigned char)b : c; }
    return c;
}

typedef struct { uint32_t *cp; NSUInteger *u16; NSUInteger n; } scalars_t;   /* scalars + their UTF-16 offsets */
static scalars_t scalars_of(NSString *s, NSStringCompareOptions mask) {
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    scalars_t r = { malloc(sizeof(uint32_t) * (n + 1)), malloc(sizeof(NSUInteger) * (n + 1)), 0 };
    NSUInteger u = 0;
    for (NSUInteger i = 0; i < n;) {
        unsigned char c = (unsigned char)b[i];
        uint32_t cp; int extra;
        if (c < 0x80) { cp = c; extra = 0; } else if (c < 0xE0) { cp = c & 0x1F; extra = 1; } else if (c < 0xF0) { cp = c & 0x0F; extra = 2; } else { cp = c & 0x07; extra = 3; }
        i++;
        while (extra-- > 0 && i < n) cp = (cp << 6) | ((unsigned char)b[i++] & 0x3F);
        if ((mask & NSDiacriticInsensitiveSearch) && cp >= 0x300 && cp <= 0x36F) { u++; continue; }   /* combining marks */
        if (mask & NSDiacriticInsensitiveSearch) cp = strip_diacritic(cp);
        if (mask & NSCaseInsensitiveSearch) cp = isim_case_map(cp, 0);
        r.cp[r.n] = cp; r.u16[r.n] = u; r.n++;
        u += cp >= 0x10000 ? 2 : 1;
    }
    r.u16[r.n] = u;
    return r;
}

@implementation NSString (NSStringExtensionMethods)
- (NSRange)rangeOfString:(NSString *)str options:(NSStringCompareOptions)mask range:(NSRange)range {
    if (NSMaxRange(range) > self.length) [NSException raise:NSRangeException format:@"-[NSString rangeOfString:options:range:]: range {%lu, %lu} out of bounds", (unsigned long)range.location, (unsigned long)range.length];
    if (mask & NSRegularExpressionSearch) return isim_regex_search(self, str, mask, range);
    if (!str.length) return NSMakeRange(NSNotFound, 0);
    scalars_t h = scalars_of(self, mask), nd = scalars_of(str, mask);
    NSRange found = NSMakeRange(NSNotFound, 0);
    /* scalar window covering [range.location, NSMaxRange(range)) */
    NSUInteger lo = 0, hi = h.n;
    while (lo < h.n && h.u16[lo] < range.location) lo++;
    while (hi > lo && h.u16[hi] > NSMaxRange(range)) hi--;
    if (nd.n && nd.n <= hi - lo) {
        NSUInteger last = hi - nd.n;
        for (NSUInteger k = 0; k <= last - lo; k++) {
            NSUInteger i = (mask & NSBackwardsSearch) ? last - k : lo + k;
            if ((mask & NSAnchoredSearch) && k > 0) break;
            if (!memcmp(h.cp + i, nd.cp, nd.n * sizeof(uint32_t))) { found = NSMakeRange(h.u16[i], h.u16[i + nd.n] - h.u16[i]); break; }
        }
    }
    free(h.cp); free(h.u16); free(nd.cp); free(nd.u16);
    return found;
}
- (NSRange)rangeOfString:(NSString *)str options:(NSStringCompareOptions)mask range:(NSRange)range locale:(NSLocale *)locale {
    return [self rangeOfString:str options:mask range:range];
}
- (NSComparisonResult)compare:(NSString *)string options:(NSStringCompareOptions)mask range:(NSRange)range {
    return [self compare:string options:mask range:range locale:nil];
}
/* With a locale: the locale's collation from the host's ICU (UCA + CLDR tailorings: "é" sorts with "e", "ä" after
 * "z" in Swedish, digits numerically with NSNumericSearch), as on iOS. Without one (or without ICU): code points, with
 * case / diacritic folding. NSForcedOrderingSearch orders strings that collate equal by their code points. */
- (NSComparisonResult)compare:(NSString *)string options:(NSStringCompareOptions)mask range:(NSRange)range locale:(id)locale {
    if (NSMaxRange(range) > self.length) [NSException raise:NSRangeException format:@"-[NSString compare:options:range:locale:]: range {%lu, %lu} out of bounds", (unsigned long)range.location, (unsigned long)range.length];
    NSString *a = range.location == 0 && range.length == self.length ? self : [self substringWithRange:range];
    NSString *b = string ?: @"";
    if (locale && !(mask & NSLiteralSearch) && isim_icu_on()) {
        NSString *ident = [locale isKindOfClass:[NSLocale class]] ? [(NSLocale *)locale localeIdentifier] : NSLocale.currentLocale.localeIdentifier;
        int flags = ((mask & NSCaseInsensitiveSearch) ? 1 : 0) | ((mask & NSDiacriticInsensitiveSearch) ? 2 : 0) |
                    ((mask & NSNumericSearch) ? 4 : 0) | ((mask & NSWidthInsensitiveSearch) ? 8 : 0);
        NSUInteger na = a.length, nb = b.length;
        unichar *ua = malloc((na + 1) * sizeof(unichar)), *ub = malloc((nb + 1) * sizeof(unichar));
        [a getCharacters:ua range:NSMakeRange(0, na)];
        [b getCharacters:ub range:NSMakeRange(0, nb)];
        int r = isim_icu_collate(ident.UTF8String, ua, (int)na, ub, (int)nb, flags);
        free(ua); free(ub);
        if (r != -2) {
            if (r == 0 && (mask & NSForcedOrderingSearch)) return [a compare:b options:0];
            return r < 0 ? NSOrderedAscending : r > 0 ? NSOrderedDescending : NSOrderedSame;
        }
    }
    if (mask & NSNumericSearch) return [a compare:b options:mask & (NSCaseInsensitiveSearch | NSNumericSearch)];
    scalars_t x = scalars_of(a, mask), y = scalars_of(b, mask);
    NSComparisonResult res = NSOrderedSame;
    for (NSUInteger i = 0; i < x.n && i < y.n && res == NSOrderedSame; i++)
        if (x.cp[i] != y.cp[i]) res = x.cp[i] < y.cp[i] ? NSOrderedAscending : NSOrderedDescending;
    if (res == NSOrderedSame && x.n != y.n) res = x.n < y.n ? NSOrderedAscending : NSOrderedDescending;
    free(x.cp); free(x.u16); free(y.cp); free(y.u16);
    if (res == NSOrderedSame && (mask & NSForcedOrderingSearch) && (mask & (NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch))) return [a compare:b options:0];
    return res;
}
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)rep options:(NSStringCompareOptions)mask range:(NSRange)range {
    if (mask & NSRegularExpressionSearch) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:target options:(mask & NSCaseInsensitiveSearch) ? NSRegularExpressionCaseInsensitive : 0 error:NULL];
        return re ? [re stringByReplacingMatchesInString:self options:(mask & NSAnchoredSearch) ? NSMatchingAnchored : 0 range:range withTemplate:rep] : [self copy];
    }
    if (!mask && range.location == 0 && range.length == self.length) return [self stringByReplacingOccurrencesOfString:target withString:rep];
    NSMutableString *out = [NSMutableString string];
    NSUInteger pos = range.location, end = NSMaxRange(range);
    [out appendString:[self substringToIndex:pos]];
    while (pos <= end) {
        NSRange r = [self rangeOfString:target options:mask & ~NSBackwardsSearch range:NSMakeRange(pos, end - pos)];
        if (r.location == NSNotFound) break;
        [out appendString:[self substringWithRange:NSMakeRange(pos, r.location - pos)]];
        [out appendString:rep];
        pos = NSMaxRange(r);
        if (mask & NSAnchoredSearch) break;
    }
    [out appendString:[self substringFromIndex:pos]];
    return out;
}
- (BOOL)localizedCaseInsensitiveContainsString:(NSString *)str { return [self rangeOfString:str options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.length)].location != NSNotFound; }
- (BOOL)localizedStandardContainsString:(NSString *)str { return [self rangeOfString:str options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch range:NSMakeRange(0, self.length)].location != NSNotFound; }
- (NSRange)localizedStandardRangeOfString:(NSString *)str { return [self rangeOfString:str options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch range:NSMakeRange(0, self.length)]; }
- (NSString *)stringByFoldingWithOptions:(NSStringCompareOptions)options locale:(NSLocale *)locale {
    scalars_t s = scalars_of(self, options);
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < s.n; i++) {
        uint32_t c = s.cp[i];
        if (c >= 0x10000) { unichar u[2] = { (unichar)(0xD800 + ((c - 0x10000) >> 10)), (unichar)(0xDC00 + ((c - 0x10000) & 0x3FF)) }; [out appendString:[NSString stringWithCharacters:u length:2]]; }
        else { unichar u = (unichar)c; [out appendString:[NSString stringWithCharacters:&u length:1]]; }
    }
    free(s.cp); free(s.u16);
    return out;
}
+ (instancetype)stringWithCharacters:(const unichar *)c length:(NSUInteger)n { return [[self alloc] initWithCharacters:c length:n]; }
- (void)getCharacters:(unichar *)buffer range:(NSRange)range {
    NSUInteger n; const char *b = [self _isim_bytes:&n];
    NSUInteger i = isim_utf16_to_byte(b, n, range.location), o = 0;
    while (o < range.length && i < n) {
        unsigned char c = (unsigned char)b[i];
        uint32_t cp; int extra;
        if (c < 0x80) { cp = c; extra = 0; } else if (c < 0xE0) { cp = c & 0x1F; extra = 1; } else if (c < 0xF0) { cp = c & 0x0F; extra = 2; } else { cp = c & 0x07; extra = 3; }
        i++;
        while (extra-- > 0 && i < n) cp = (cp << 6) | ((unsigned char)b[i++] & 0x3F);
        if (cp >= 0x10000) { buffer[o++] = (unichar)(0xD800 + ((cp - 0x10000) >> 10)); if (o < range.length) buffer[o++] = (unichar)(0xDC00 + ((cp - 0x10000) & 0x3FF)); }
        else buffer[o++] = (unichar)cp;
    }
}
- (void)getCharacters:(unichar *)buffer { [self getCharacters:buffer range:NSMakeRange(0, self.length)]; }

/* ---------------- enumeration ---------------- */
- (void)enumerateLinesUsingBlock:(void (NS_NOESCAPE ^)(NSString *line, BOOL *stop))block {
    [self enumerateSubstringsInRange:NSMakeRange(0, self.length) options:NSStringEnumerationByLines
                          usingBlock:^(NSString *s, NSRange r, NSRange er, BOOL *stop) { block(s, stop); }];
}
- (void)enumerateSubstringsInRange:(NSRange)range options:(NSStringEnumerationOptions)opts
                        usingBlock:(void (NS_NOESCAPE ^)(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop))block {
    NSUInteger kind = opts & 0xFF, end = NSMaxRange(range);
    BOOL noSub = (opts & NSStringEnumerationSubstringNotRequired) != 0;
    NSMutableArray<NSValue *> *parts = [NSMutableArray array], *enclosing = [NSMutableArray array];
    NSUInteger n = self.length;
    unichar *u = malloc(sizeof(unichar) * (n + 1)); [self getCharacters:u range:NSMakeRange(0, n)];
    if (kind == NSStringEnumerationByLines || kind == NSStringEnumerationByParagraphs) {
        NSUInteger start = range.location;
        for (NSUInteger i = range.location; i <= end; i++) {
            BOOL atEnd = i == end;
            unichar c = atEnd ? 0 : u[i];
            BOOL brk = c == '\n' || c == '\r' || c == 0x2029 || (kind == NSStringEnumerationByLines && (c == 0x2028 || c == 0x85));
            if (!atEnd && !brk) continue;
            if (atEnd && start == end && start > range.location) break;
            NSUInteger termLen = atEnd ? 0 : (c == '\r' && i + 1 < end && u[i + 1] == '\n') ? 2 : 1;
            [parts addObject:[NSValue valueWithRange:NSMakeRange(start, i - start)]];
            [enclosing addObject:[NSValue valueWithRange:NSMakeRange(start, i - start + termLen)]];
            i += termLen ? termLen - 1 : 0;
            start = i + 1;
            if (atEnd) break;
        }
    } else if (kind == NSStringEnumerationByWords) {
        NSCharacterSet *wordChars = [NSCharacterSet alphanumericCharacterSet];
        NSUInteger i = range.location, prevEnd = range.location;
        while (i < end) {
            while (i < end && ![wordChars characterIsMember:u[i]] && !(u[i] >= 0xD800 && u[i] < 0xDC00)) i++;
            if (i >= end) break;
            NSUInteger s = i;
            while (i < end && ([wordChars characterIsMember:u[i]] || ((u[i] == '\'' || u[i] == 0x2019) && i + 1 < end && [wordChars characterIsMember:u[i + 1]]) || (u[i] >= 0xD800 && u[i] < 0xE000))) i++;
            [parts addObject:[NSValue valueWithRange:NSMakeRange(s, i - s)]];
            NSUInteger ee = i; while (ee < end && ![wordChars characterIsMember:u[ee]]) ee++;
            [enclosing addObject:[NSValue valueWithRange:NSMakeRange(prevEnd, ee - prevEnd)]];
            prevEnd = ee;
        }
    } else if (kind == NSStringEnumerationBySentences) {
        NSUInteger s = range.location;
        while (s < end && (u[s] == ' ' || u[s] == '\n')) s++;
        for (NSUInteger i = s; i <= end; i++) {
            BOOL stopc = i == end || u[i] == '.' || u[i] == '!' || u[i] == '?';
            if (!stopc) continue;
            NSUInteger e = i < end ? i + 1 : i;
            while (e < end && (u[e] == '.' || u[e] == '!' || u[e] == '?' || u[e] == '"' || u[e] == ')')) e++;
            if (e > s) {
                NSUInteger ee = e; while (ee < end && (u[ee] == ' ' || u[ee] == '\n' || u[ee] == '\t')) ee++;
                [parts addObject:[NSValue valueWithRange:NSMakeRange(s, e - s)]];
                [enclosing addObject:[NSValue valueWithRange:NSMakeRange(s, ee - s)]];
                s = ee; i = ee - 1;
            }
            if (i >= end) break;
        }
    } else {   /* composed character sequences */
        for (NSUInteger i = range.location; i < end;) {
            NSRange r = [self rangeOfComposedCharacterSequenceAtIndex:i];
            if (NSMaxRange(r) > end) r.length = end - r.location;
            [parts addObject:[NSValue valueWithRange:r]]; [enclosing addObject:[NSValue valueWithRange:r]];
            i = NSMaxRange(r);
        }
    }
    free(u);
    BOOL stop = NO;
    NSUInteger count = parts.count;
    for (NSUInteger k = 0; k < count && !stop; k++) {
        NSUInteger idx = (opts & NSStringEnumerationReverse) ? count - 1 - k : k;
        NSRange r = parts[idx].rangeValue;
        block(noSub ? nil : [self substringWithRange:r], r, enclosing[idx].rangeValue, &stop);
    }
}
- (NSRange)lineRangeForRange:(NSRange)range {
    NSUInteger n = self.length, s = range.location, e = NSMaxRange(range);
    while (s > 0 && [self characterAtIndex:s - 1] != '\n' && [self characterAtIndex:s - 1] != '\r') s--;
    if (e > s && e <= n && range.length && ([self characterAtIndex:e - 1] == '\n')) return NSMakeRange(s, e - s);
    while (e < n && [self characterAtIndex:e] != '\n' && [self characterAtIndex:e] != '\r') e++;
    if (e < n) e += ([self characterAtIndex:e] == '\r' && e + 1 < n && [self characterAtIndex:e + 1] == '\n') ? 2 : 1;
    return NSMakeRange(s, e - s);
}
- (NSRange)paragraphRangeForRange:(NSRange)range { return [self lineRangeForRange:range]; }
- (NSString *)stringByPaddingToLength:(NSUInteger)newLength withString:(NSString *)pad startingAtIndex:(NSUInteger)padIndex {
    NSUInteger len = self.length;
    if (len >= newLength) return [self substringToIndex:newLength];
    NSMutableString *out = [self mutableCopy];
    NSUInteger pl = pad.length;
    for (NSUInteger i = 0; len + i < newLength && pl; i++) [out appendString:[pad substringWithRange:NSMakeRange((padIndex + i) % pl, 1)]];
    return out;
}
/* with a locale: its case rules from the host's ICU (Turkish and Azeri dotted / dotless i, Lithuanian dot above,
 * Greek accents in upper case, Dutch IJ in titles); without a locale or ICU: the root rules */
- (NSString *)localizedLowercaseString { return [self lowercaseStringWithLocale:NSLocale.currentLocale]; }
- (NSString *)localizedUppercaseString { return [self uppercaseStringWithLocale:NSLocale.currentLocale]; }
- (NSString *)localizedCapitalizedString { return [self capitalizedStringWithLocale:NSLocale.currentLocale]; }
- (NSString *)lowercaseStringWithLocale:(NSLocale *)locale { return (locale && isim_icu_on() ? isim_icu_case_string(locale.localeIdentifier, self, 1) : nil) ?: self.lowercaseString; }
- (NSString *)uppercaseStringWithLocale:(NSLocale *)locale { return (locale && isim_icu_on() ? isim_icu_case_string(locale.localeIdentifier, self, 0) : nil) ?: self.uppercaseString; }
- (NSString *)capitalizedStringWithLocale:(NSLocale *)locale { return (locale && isim_icu_on() ? isim_icu_case_string(locale.localeIdentifier, self, 2) : nil) ?: self.capitalizedString; }
- (NSString *)commonPrefixWithString:(NSString *)other options:(NSStringCompareOptions)mask {
    NSUInteger i = 0, n = MIN(self.length, other.length);
    while (i < n) {
        unichar a = [self characterAtIndex:i], b = [other characterAtIndex:i];
        if (mask & NSCaseInsensitiveSearch) { a = (unichar)isim_case_map(a, 0); b = (unichar)isim_case_map(b, 0); }
        if (a != b) break;
        i++;
    }
    return [self substringToIndex:i];
}
- (BOOL)isAbsolutePath { return [self hasPrefix:@"/"] || [self hasPrefix:@"~"]; }
- (NSArray<NSString *> *)pathComponents {
    NSMutableArray *out = [NSMutableArray array];
    if ([self hasPrefix:@"/"]) [out addObject:@"/"];
    for (NSString *p in [self componentsSeparatedByString:@"/"]) if (p.length) [out addObject:p];
    if (self.length > 1 && [self hasSuffix:@"/"]) [out addObject:@"/"];
    return out;
}
+ (NSString *)pathWithComponents:(NSArray<NSString *> *)components {
    NSMutableString *s = [NSMutableString string];
    for (NSString *c in components) {
        if ([c isEqualToString:@"/"]) { if (!s.length) [s appendString:@"/"]; continue; }
        if (s.length && ![s hasSuffix:@"/"]) [s appendString:@"/"];
        [s appendString:c];
    }
    return s;
}
- (NSString *)stringByExpandingTildeInPath {
    if (![self hasPrefix:@"~"]) return [self copy];
    return [NSHomeDirectory() stringByAppendingPathComponent:[self substringFromIndex:1]];
}
- (NSString *)stringByStandardizingPath {
    NSString *p = self.stringByExpandingTildeInPath;
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *c in [p componentsSeparatedByString:@"/"]) {
        if (!c.length || [c isEqualToString:@"."]) continue;
        if ([c isEqualToString:@".."]) { if (out.count) [out removeLastObject]; continue; }
        [out addObject:c];
    }
    NSString *j = [out componentsJoinedByString:@"/"];
    return [p hasPrefix:@"/"] ? [@"/" stringByAppendingString:j] : j;
}
@end
