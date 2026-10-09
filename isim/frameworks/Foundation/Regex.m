/* isim Foundation (ARC): NSRegularExpression, NSTextCheckingResult, NSDataDetector.
 * Matching runs in the host's PCRE2 (runtime/host_regex.c) on the strings' UTF-8 storage; ranges are
 * converted to UTF-16 indices like the rest of NSString. PCRE2's syntax is close to ICU's (which Apple
 * uses): Unicode classes (\w \d \b are Unicode-aware), lookaround, atomic groups, possessive quantifiers,
 * named groups (?<name>...), \uhhhh / \x{hhhh} escapes, (?i) inline flags. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <string.h>
#include <time.h>
#include "isim_foundation.h"

void *isim_regex_compile(const char *pattern, unsigned long len, unsigned int options, int unix_lines, int *err, unsigned long *erroffset);
void isim_regex_free(void *code);
int isim_regex_capture_count(void *code);
int isim_regex_group_number(void *code, const char *name);
void isim_regex_error_message(int err, char *buf, unsigned long n);
int isim_regex_match(void *code, const char *subject, unsigned long len, unsigned long start, unsigned int options, long *ovector, int pairs);
#define PCRE_CASELESS 0x00000008u
#define PCRE_DOTALL 0x00000020u
#define PCRE_EXTENDED 0x00000080u
#define PCRE_MULTILINE 0x00000400u
#define PCRE_LITERAL 0x02000000u
#define PCRE_ANCHORED 0x80000000u
#define PCRE_NOTBOL 0x00000001u
#define PCRE_NOTEOL 0x00000002u
#define PCRE_NOTEMPTY_ATSTART 0x00000008u

@interface NSRegularExpression (IsimGroups)
- (NSInteger)_isim_groupNumberForName:(NSString *)name;
@end

/* byte offset <-> UTF-16 index over a UTF-8 buffer, with a forward-moving cursor for match loops */
typedef struct { const char *s; NSUInteger n, byte, u16; } u16cursor;
static NSUInteger cursor_u16(u16cursor *c, NSUInteger byte) {
    if (byte < c->byte) { c->byte = 0; c->u16 = 0; }
    c->u16 += isim_utf16_length(c->s + c->byte, byte - c->byte);
    c->byte = byte;
    return c->u16;
}

/* ================= NSTextCheckingResult ================= */
@implementation NSTextCheckingResult {
    @public NSTextCheckingType _type; NSRange *_ranges; NSUInteger _count;
    NSRegularExpression *_regex; NSURL *_url; NSString *_phone, *_replacement; NSDictionary *_components; NSDate *_date; NSTimeZone *_tz; NSTimeInterval _duration;
}
static NSTextCheckingResult *make_result(NSTextCheckingType type, const NSRange *ranges, NSUInteger count) {
    NSTextCheckingResult *r = [NSTextCheckingResult new];
    r->_type = type; r->_count = count ? count : 1;
    r->_ranges = calloc(r->_count, sizeof(NSRange));
    if (count) memcpy(r->_ranges, ranges, count * sizeof(NSRange)); else r->_ranges[0] = NSMakeRange(NSNotFound, 0);
    return r;
}
+ (NSTextCheckingResult *)regularExpressionCheckingResultWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)re {
    NSTextCheckingResult *r = make_result(NSTextCheckingTypeRegularExpression, ranges, count); r->_regex = re; return r;
}
+ (NSTextCheckingResult *)linkCheckingResultWithRange:(NSRange)range URL:(NSURL *)url { NSTextCheckingResult *r = make_result(NSTextCheckingTypeLink, &range, 1); r->_url = url; return r; }
+ (NSTextCheckingResult *)phoneNumberCheckingResultWithRange:(NSRange)range phoneNumber:(NSString *)p { NSTextCheckingResult *r = make_result(NSTextCheckingTypePhoneNumber, &range, 1); r->_phone = [p copy]; return r; }
+ (NSTextCheckingResult *)dateCheckingResultWithRange:(NSRange)range date:(NSDate *)d { NSTextCheckingResult *r = make_result(NSTextCheckingTypeDate, &range, 1); r->_date = d; return r; }
+ (NSTextCheckingResult *)replacementCheckingResultWithRange:(NSRange)range replacementString:(NSString *)s { NSTextCheckingResult *r = make_result(NSTextCheckingTypeReplacement, &range, 1); r->_replacement = [s copy]; return r; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)dealloc { free(_ranges); }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSTextCheckingType)resultType { return _type; }
- (NSRange)range { return _ranges[0]; }
- (NSUInteger)numberOfRanges { return _count; }
- (NSRange)rangeAtIndex:(NSUInteger)i {
    if (i >= _count) [NSException raise:NSRangeException format:@"-[NSTextCheckingResult rangeAtIndex:]: index %lu out of bounds", (unsigned long)i];
    return _ranges[i];
}
- (NSRange)rangeWithName:(NSString *)name {
    NSInteger g = [_regex _isim_groupNumberForName:name];
    return g >= 0 && (NSUInteger)g < _count ? _ranges[g] : NSMakeRange(NSNotFound, 0);
}
- (NSTextCheckingResult *)resultByAdjustingRangesWithOffset:(NSInteger)offset {
    NSTextCheckingResult *r = make_result(_type, _ranges, _count);
    for (NSUInteger i = 0; i < _count; i++) if (r->_ranges[i].location != NSNotFound) r->_ranges[i].location += offset;
    r->_regex = _regex; r->_url = _url; r->_phone = _phone; r->_date = _date; r->_tz = _tz; r->_duration = _duration; r->_replacement = _replacement; r->_components = _components;
    return r;
}
- (NSRegularExpression *)regularExpression { return _regex; }
- (NSURL *)URL { return _url; }
- (NSString *)phoneNumber { return _phone; }
- (NSDate *)date { return _date; }
- (NSTimeZone *)timeZone { return _tz; }
- (NSTimeInterval)duration { return _duration; }
- (NSString *)replacementString { return _replacement; }
+ (NSTextCheckingResult *)addressCheckingResultWithRange:(NSRange)range components:(NSDictionary *)c { NSTextCheckingResult *r = make_result(NSTextCheckingTypeAddress, &range, 1); r->_components = [c copy]; return r; }
+ (NSTextCheckingResult *)transitInformationCheckingResultWithRange:(NSRange)range components:(NSDictionary *)c { NSTextCheckingResult *r = make_result(NSTextCheckingTypeTransitInformation, &range, 1); r->_components = [c copy]; return r; }
- (NSDictionary *)addressComponents { return _type == NSTextCheckingTypeAddress ? _components : nil; }
- (NSDictionary *)components { return _type == NSTextCheckingTypeAddress ? nil : _components; }   /* transit information */
- (NSString *)description {
    NSString *kind = _type == NSTextCheckingTypeLink ? @"Link" : _type == NSTextCheckingTypePhoneNumber ? @"PhoneNumber" : _type == NSTextCheckingTypeDate ? @"Date" : _type == NSTextCheckingTypeAddress ? @"Address" : _type == NSTextCheckingTypeTransitInformation ? @"TransitInformation" : @"RegularExpression";
    return [NSString stringWithFormat:@"<NSTextCheckingResult: %p>{%lu, %lu}%@", self, (unsigned long)_ranges[0].location, (unsigned long)_ranges[0].length, kind];
}
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return nil; }
@end

/* ================= NSRegularExpression ================= */
@implementation NSRegularExpression { void *_code; NSString *_pattern; NSRegularExpressionOptions _options; NSUInteger _groups; }
+ (NSRegularExpression *)regularExpressionWithPattern:(NSString *)p options:(NSRegularExpressionOptions)o error:(NSError **)e {
    return [[self alloc] initWithPattern:p options:o error:e];
}
- (instancetype)init { return [self initWithPattern:@"" options:0 error:NULL]; }
- (instancetype)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error {
    if (!(self = [super init])) return nil;
    if (!pattern) { if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:2048 userInfo:@{ @"NSInvalidValue": @"(null)" }]; return nil; }
    _pattern = [pattern copy]; _options = options;
    unsigned int flags = 0;
    if (options & NSRegularExpressionCaseInsensitive) flags |= PCRE_CASELESS;
    if (options & NSRegularExpressionAllowCommentsAndWhitespace) flags |= PCRE_EXTENDED;
    if (options & NSRegularExpressionIgnoreMetacharacters) flags |= PCRE_LITERAL;
    if (options & NSRegularExpressionDotMatchesLineSeparators) flags |= PCRE_DOTALL;
    if (options & NSRegularExpressionAnchorsMatchLines) flags |= PCRE_MULTILINE;
    NSUInteger n; const char *b = [_pattern _isim_bytes:&n];
    int err = 0; unsigned long off = 0;
    _code = isim_regex_compile(b, n, flags, (options & NSRegularExpressionUseUnixLineSeparators) != 0, &err, &off);
    if (!_code) {
        if (error) {
            char msg[256]; isim_regex_error_message(err, msg, sizeof msg);
            /* NSRegularExpression reports invalid patterns as NSCocoaErrorDomain 2048 (NSFormattingError) */
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:2048
                                     userInfo:@{ @"NSInvalidValue": _pattern, @"NSDebugDescription": [NSString stringWithFormat:@"%s at offset %lu", msg, off] }];
        }
        return nil;
    }
    _groups = (NSUInteger)isim_regex_capture_count(_code);
    return self;
}
- (void)dealloc { isim_regex_free(_code); }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return nil; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSRegularExpression class]] && [_pattern isEqualToString:[o pattern]] && _options == [(NSRegularExpression *)o options]; }
- (NSUInteger)hash { return _pattern.hash ^ _options; }
- (NSString *)pattern { return _pattern; }
- (NSRegularExpressionOptions)options { return _options; }
- (NSUInteger)numberOfCaptureGroups { return _groups; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p> %@ 0x%lx", [self class], self, _pattern, (unsigned long)_options]; }
- (NSInteger)_isim_groupNumberForName:(NSString *)name { return _code && name ? isim_regex_group_number(_code, name.UTF8String) : -1; }

+ (NSString *)escapedPatternForString:(NSString *)s {
    NSMutableString *out = [NSMutableString string];
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    for (NSUInteger i = 0; i < n; i++) {
        if (strchr("\\^$.|?*+()[]{}", b[i]) && b[i]) [out appendString:@"\\"];
        [out appendString:isim_string_copy(b + i, 1)];
    }
    return out;
}
+ (NSString *)escapedTemplateForString:(NSString *)s {
    return [[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
}

static void check_range(NSString *s, NSRange r, const char *sel) {
    if (!s) [NSException raise:NSInvalidArgumentException format:@"-[NSRegularExpression %s]: nil argument", sel];
    if (NSMaxRange(r) > s.length) [NSException raise:NSRangeException format:@"-[NSRegularExpression %s]: Range {%lu, %lu} out of bounds; string length %lu", sel, (unsigned long)r.location, (unsigned long)r.length, (unsigned long)s.length];
}

- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
                      usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult *, NSMatchingFlags, BOOL *))block {
    check_range(string, range, "enumerateMatchesInString:options:range:usingBlock:");
    NSUInteger n; const char *b = [string _isim_bytes:&n];
    NSUInteger bs = isim_utf16_to_byte(b, n, range.location), be = isim_utf16_to_byte(b, n, NSMaxRange(range));
    /* default (anchoring, opaque bounds): the range is the whole subject. Transparent bounds let lookaround
     * see outside it, approximated by matching the whole string from bs and ignoring matches past be. */
    BOOL transparent = (options & NSMatchingWithTransparentBounds) != 0;
    const char *subject = transparent ? b : b + bs;
    unsigned long len = transparent ? be : be - bs, base = transparent ? 0 : bs, pos = transparent ? bs : 0;
    unsigned int mopts = (options & NSMatchingAnchored) ? PCRE_ANCHORED : 0;
    if ((options & NSMatchingWithoutAnchoringBounds) && !transparent) { if (bs > 0) mopts |= PCRE_NOTBOL; if (be < n) mopts |= PCRE_NOTEOL; }
    int pairs = (int)_groups + 1;
    long *ov = malloc(sizeof(long) * 2 * (size_t)pairs);
    NSRange *ranges = malloc(sizeof(NSRange) * (size_t)pairs);
    u16cursor cur = { b, n, 0, 0 };
    BOOL stop = NO;
    unsigned int extra = 0;
    while (!stop && pos <= len) {
        int rc = isim_regex_match(_code, subject, len, pos, mopts | extra, ov, pairs);
        if (rc < 0) break;
        if (rc == 0) {
            if (!extra) break;
            /* empty match at pos already reported: retry one character further */
            extra = 0;
            if (pos >= len) break;
            unsigned char c = (unsigned char)subject[pos];
            pos += c < 0x80 ? 1 : c < 0xE0 ? 2 : c < 0xF0 ? 3 : 4;
            if (mopts & PCRE_ANCHORED) break;
            continue;
        }
        for (int i = 0; i < pairs; i++) {
            if (ov[2 * i] < 0) { ranges[i] = NSMakeRange(NSNotFound, 0); continue; }
            NSUInteger s0 = cursor_u16(&cur, base + (NSUInteger)ov[2 * i]);
            NSUInteger s1 = cursor_u16(&cur, base + (NSUInteger)ov[2 * i + 1]);
            ranges[i] = NSMakeRange(s0, s1 - s0);
        }
        @autoreleasepool {
            NSTextCheckingResult *r = [NSTextCheckingResult regularExpressionCheckingResultWithRanges:ranges count:(NSUInteger)pairs regularExpression:self];
            block(r, 0, &stop);
        }
        if (mopts & PCRE_ANCHORED && !(ov[0] == ov[1])) { /* anchored: matches must be contiguous */ }
        if (ov[0] == ov[1]) { extra = PCRE_NOTEMPTY_ATSTART | PCRE_ANCHORED; pos = (unsigned long)ov[1]; }
        else { extra = 0; pos = (unsigned long)ov[1]; }
    }
    if (!stop && (options & NSMatchingReportCompletion)) block(nil, NSMatchingCompleted, &stop);
    free(ov); free(ranges);
}
- (NSArray<NSTextCheckingResult *> *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range {
    NSMutableArray *a = [NSMutableArray array];
    [self enumerateMatchesInString:string options:options & ~NSMatchingReportCompletion range:range usingBlock:^(NSTextCheckingResult *r, NSMatchingFlags f, BOOL *stop) { if (r) [a addObject:r]; }];
    return a;
}
- (NSUInteger)numberOfMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range {
    __block NSUInteger n = 0;
    [self enumerateMatchesInString:string options:options & ~NSMatchingReportCompletion range:range usingBlock:^(NSTextCheckingResult *r, NSMatchingFlags f, BOOL *stop) { if (r) n++; }];
    return n;
}
- (NSTextCheckingResult *)firstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range {
    __block NSTextCheckingResult *first = nil;
    [self enumerateMatchesInString:string options:options & ~NSMatchingReportCompletion range:range usingBlock:^(NSTextCheckingResult *r, NSMatchingFlags f, BOOL *stop) { if (r) { first = r; *stop = YES; } }];
    return first;
}
- (NSRange)rangeOfFirstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range {
    NSTextCheckingResult *r = [self firstMatchInString:string options:options range:range];
    return r ? r.range : NSMakeRange(NSNotFound, 0);
}

/* ICU template syntax: $n (longest valid group number), ${name}, \x escapes the next character */
- (NSString *)replacementStringForResult:(NSTextCheckingResult *)result inString:(NSString *)string offset:(NSInteger)offset template:(NSString *)templ {
    NSMutableString *out = [NSMutableString string];
    NSUInteger tn; const char *t = [templ _isim_bytes:&tn];
    NSUInteger groups = result.numberOfRanges;
    void (^group)(NSUInteger) = ^(NSUInteger g) {
        if (g >= groups) return;
        NSRange r = [result rangeAtIndex:g];
        if (r.location == NSNotFound) return;
        r.location += offset;
        [out appendString:[string substringWithRange:r]];
    };
    NSUInteger lit = 0;
    for (NSUInteger i = 0; i < tn;) {
        if (t[i] == '\\' && i + 1 < tn) {
            [out appendString:isim_string_copy(t + lit, i - lit)];
            i++; NSUInteger k = i; unsigned char c = (unsigned char)t[i];
            k += c < 0x80 ? 1 : c < 0xE0 ? 2 : c < 0xF0 ? 3 : 4;
            [out appendString:isim_string_copy(t + i, k - i)];
            i = lit = k; continue;
        }
        if (t[i] == '$' && i + 1 < tn && t[i + 1] == '{') {
            const char *close = memchr(t + i + 2, '}', tn - i - 2);
            if (close) {
                [out appendString:isim_string_copy(t + lit, i - lit)];
                NSString *name = isim_string_copy(t + i + 2, (NSUInteger)(close - t - i - 2));
                NSInteger g = [result.regularExpression _isim_groupNumberForName:name];
                if (g < 0 && name.length && isdigit((unsigned char)name.UTF8String[0])) g = name.integerValue;
                if (g >= 0) group((NSUInteger)g);
                i = lit = (NSUInteger)(close - t) + 1; continue;
            }
        }
        if (t[i] == '$' && i + 1 < tn && isdigit((unsigned char)t[i + 1])) {
            [out appendString:isim_string_copy(t + lit, i - lit)];
            NSUInteger g = (NSUInteger)(t[i + 1] - '0'), k = i + 2;
            while (k < tn && isdigit((unsigned char)t[k]) && g * 10 + (NSUInteger)(t[k] - '0') < groups) { g = g * 10 + (NSUInteger)(t[k] - '0'); k++; }
            group(g);
            i = lit = k; continue;
        }
        i++;
    }
    [out appendString:isim_string_copy(t + lit, tn - lit)];
    return out;
}
- (NSString *)stringByReplacingMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ {
    NSArray *matches = [self matchesInString:string options:options range:range];
    if (!matches.count) return [string copy];
    NSMutableString *out = [NSMutableString string];
    NSUInteger last = 0;
    for (NSTextCheckingResult *m in matches) {
        [out appendString:[string substringWithRange:NSMakeRange(last, m.range.location - last)]];
        [out appendString:[self replacementStringForResult:m inString:string offset:0 template:templ]];
        last = NSMaxRange(m.range);
    }
    [out appendString:[string substringFromIndex:last]];
    return out;
}
- (NSUInteger)replaceMatchesInString:(NSMutableString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ {
    NSArray *matches = [self matchesInString:string options:options range:range];
    NSString *copy = [string copy];
    for (NSTextCheckingResult *m in matches.reverseObjectEnumerator.allObjects)
        [string replaceCharactersInRange:m.range withString:[self replacementStringForResult:m inString:copy offset:0 template:templ]];
    return matches.count;
}
@end

/* -[NSString rangeOfString:options:range:] with NSRegularExpressionSearch */
NSRange isim_regex_search(NSString *string, NSString *pattern, NSStringCompareOptions mask, NSRange range) {
    NSRegularExpressionOptions o = (mask & NSCaseInsensitiveSearch) ? NSRegularExpressionCaseInsensitive : 0;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:o error:NULL];
    if (!re) return NSMakeRange(NSNotFound, 0);
    NSMatchingOptions mo = (mask & NSAnchoredSearch) ? NSMatchingAnchored : 0;
    if (mask & NSBackwardsSearch) {
        NSTextCheckingResult *last = [re matchesInString:string options:0 range:range].lastObject;
        return last ? last.range : NSMakeRange(NSNotFound, 0);
    }
    return [re rangeOfFirstMatchInString:string options:mo range:range];
}

/* ================= NSDataDetector ================= */
static NSString *const kLinkPattern =
    @"(?:\\b(?:https?|ftp)://[^\\s<>\"]+"
    @"|\\bmailto:[^\\s<>\"]+"
    @"|\\b[A-Za-z0-9._%+-]+@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,}\\b"
    @"|\\bwww\\.[^\\s<>\"]+"
    @"|(?<![@\\w.-])(?:[A-Za-z0-9-]+\\.)+(?:com|org|net|edu|gov|io|dev|app|co|me|info|biz|us|uk|br|pt|de|fr|es|it|nl|jp|cn|in|au|ca|mx|ru|ch|se|no|eu|tv|ai|ly|gg)\\b(?:/[^\\s<>\"]*)?)";
static NSString *const kPhonePattern =
    @"(?<![\\w+])(?:\\+\\d{1,3}[\\s.-]?)?(?:\\(\\d{1,4}\\)[\\s.-]?)?\\d{2,5}(?:[\\s.-]?\\d{2,5}){1,3}(?![\\w])";
/* street addresses (US / UK style): number, street name and kind, then optional city, state and ZIP */
static NSString *const kAddressPattern =
    @"\\b(\\d{1,5}(?:\\s+[A-Z][A-Za-z.'-]*){1,4}\\s+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Way|Court|Ct|Place|Pl|"
    @"Parkway|Pkwy|Square|Sq|Terrace|Ter|Highway|Hwy|Circle|Cir|Loop|Alley|Plaza)\\.?)"
    @"(?:,?\\s+((?:[A-Z][A-Za-z.'-]+\\s?){1,3}?)(?:,\\s*([A-Z]{2}))?(?:\\s+(\\d{5}(?:-\\d{4})?))?)?(?![\\w])";
/* flights: an airline's IATA code and a number ("UA 123", "BA2490") */
static NSDictionary<NSString *, NSString *> *airlines(void) {
    static NSDictionary *d;
    if (!d) d = @{ @"AA": @"American Airlines", @"AC": @"Air Canada", @"AF": @"Air France", @"AM": @"Aeroméxico", @"AS": @"Alaska Airlines",
                   @"AZ": @"ITA Airways", @"BA": @"British Airways", @"B6": @"JetBlue", @"CX": @"Cathay Pacific", @"DL": @"Delta Air Lines",
                   @"EK": @"Emirates", @"EY": @"Etihad Airways", @"F9": @"Frontier Airlines", @"IB": @"Iberia", @"JL": @"Japan Airlines",
                   @"KL": @"KLM", @"LA": @"LATAM", @"LH": @"Lufthansa", @"LX": @"SWISS", @"NH": @"ANA", @"NK": @"Spirit Airlines",
                   @"QF": @"Qantas", @"QR": @"Qatar Airways", @"SQ": @"Singapore Airlines", @"SK": @"SAS", @"TK": @"Turkish Airlines",
                   @"TP": @"TAP Air Portugal", @"UA": @"United Airlines", @"VS": @"Virgin Atlantic", @"WN": @"Southwest Airlines",
                   @"G3": @"GOL", @"AD": @"Azul", @"FR": @"Ryanair", @"U2": @"easyJet" };
    return d;
}
NSTextCheckingKey const NSTextCheckingNameKey = @"Name", NSTextCheckingJobTitleKey = @"JobTitle", NSTextCheckingOrganizationKey = @"Organization",
    NSTextCheckingStreetKey = @"Street", NSTextCheckingCityKey = @"City", NSTextCheckingStateKey = @"State", NSTextCheckingZIPKey = @"ZIP",
    NSTextCheckingCountryKey = @"Country", NSTextCheckingPhoneKey = @"Phone", NSTextCheckingAirlineKey = @"Airline", NSTextCheckingFlightKey = @"Flight";
static NSString *const kMonths = @"(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept?|Oct|Nov|Dec)\\.?";
@implementation NSDataDetector { NSTextCheckingTypes _types; NSRegularExpression *_link, *_phone, *_address, *_flight, *_dateISO, *_dateNum, *_dateText1, *_dateText2, *_dateRel; }
+ (NSDataDetector *)dataDetectorWithTypes:(NSTextCheckingTypes)t error:(NSError **)e { return [[self alloc] initWithTypes:t error:e]; }
- (instancetype)initWithPattern:(NSString *)p options:(NSRegularExpressionOptions)o error:(NSError **)e { return [self initWithTypes:0 error:e]; }
- (instancetype)initWithTypes:(NSTextCheckingTypes)types error:(NSError **)error {
    if (!(self = [super initWithPattern:@"" options:0 error:error])) return nil;
    NSTextCheckingTypes supported = NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber | NSTextCheckingTypeDate | NSTextCheckingTypeAddress | NSTextCheckingTypeTransitInformation;
    if (!types || (types & ~supported)) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:2048 userInfo:@{ @"NSInvalidValue": @(types) }];
        return nil;
    }
    _types = types;
    NSRegularExpressionOptions ci = NSRegularExpressionCaseInsensitive;
    _link = [NSRegularExpression regularExpressionWithPattern:kLinkPattern options:ci error:NULL];
    _phone = [NSRegularExpression regularExpressionWithPattern:kPhonePattern options:0 error:NULL];
    _address = [NSRegularExpression regularExpressionWithPattern:kAddressPattern options:0 error:NULL];
    _flight = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b(%@)\\s?(\\d{1,4})\\b",
               [airlines().allKeys componentsJoinedByString:@"|"]] options:0 error:NULL];
    _dateISO = [NSRegularExpression regularExpressionWithPattern:@"\\b(\\d{4})-(\\d{2})-(\\d{2})(?:[T ](\\d{2}):(\\d{2})(?::(\\d{2}))?)?\\b" options:0 error:NULL];
    _dateNum = [NSRegularExpression regularExpressionWithPattern:@"\\b(\\d{1,2})[/.](\\d{1,2})[/.](\\d{2,4})\\b" options:0 error:NULL];
    _dateText1 = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b%@ (\\d{1,2})(?:st|nd|rd|th)?(?:,? (\\d{4}))?\\b", kMonths] options:ci error:NULL];
    _dateText2 = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\b(\\d{1,2})(?:st|nd|rd|th)? (?:of )?%@(?:,? (\\d{4}))?\\b", kMonths] options:ci error:NULL];
    _dateRel = [NSRegularExpression regularExpressionWithPattern:@"\\b(today|tomorrow|yesterday)\\b" options:ci error:NULL];
    return self;
}
- (NSTextCheckingTypes)checkingTypes { return _types; }
- (NSString *)pattern { return @""; }
- (NSUInteger)numberOfCaptureGroups { return 0; }

static NSDate *make_date(NSInteger y, NSInteger m, NSInteger d, NSInteger hh, NSInteger mm, NSInteger ss) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return nil;
    struct tm tm = { .tm_year = (int)y - 1900, .tm_mon = (int)m - 1, .tm_mday = (int)d, .tm_hour = (int)hh, .tm_min = (int)mm, .tm_sec = (int)ss };
    time_t t = timegm(&tm);
    return [NSDate dateWithTimeIntervalSince1970:t - [NSTimeZone.defaultTimeZone secondsFromGMTForDate:[NSDate dateWithTimeIntervalSince1970:t]]];
}
static NSInteger month_index(NSString *name) {
    static NSArray *names;
    if (!names) names = @[@"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul", @"aug", @"sep", @"oct", @"nov", @"dec"];
    NSString *k = name.lowercaseString;
    for (NSUInteger i = 0; i < 12; i++) if ([k hasPrefix:names[i]]) return (NSInteger)i + 1;
    return 0;
}
static NSInteger current_year(void) { time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm); return tm.tm_year + 1900; }

- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
                      usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult *, NSMatchingFlags, BOOL *))block {
    check_range(string, range, "enumerateMatchesInString:options:range:usingBlock:");
    NSMutableArray<NSTextCheckingResult *> *found = [NSMutableArray array];
    NSString *(^sub)(NSTextCheckingResult *, NSUInteger) = ^NSString *(NSTextCheckingResult *m, NSUInteger i) {
        NSRange r = [m rangeAtIndex:i]; return r.location == NSNotFound ? nil : [string substringWithRange:r];
    };
    if (_types & NSTextCheckingTypeLink) {
        for (NSTextCheckingResult *m in [_link matchesInString:string options:0 range:range]) {
            NSRange r = m.range;
            NSString *s = [string substringWithRange:r];
            while (s.length && strchr(".,;:!?)]}'\"", [s characterAtIndex:s.length - 1]) && [s characterAtIndex:s.length - 1] < 128) { s = [s substringToIndex:s.length - 1]; r.length--; }
            if (!s.length) continue;
            NSString *url = s;
            if ([s rangeOfString:@"://"].location == NSNotFound && ![s.lowercaseString hasPrefix:@"mailto:"])
                url = [s containsString:@"@"] && [s rangeOfString:@"/"].location == NSNotFound ? [@"mailto:" stringByAppendingString:s] : [@"http://" stringByAppendingString:s];
            NSURL *u = [NSURL URLWithString:url];
            if (u) [found addObject:[NSTextCheckingResult linkCheckingResultWithRange:r URL:u]];
        }
    }
    if (_types & NSTextCheckingTypePhoneNumber) {
        for (NSTextCheckingResult *m in [_phone matchesInString:string options:0 range:range]) {
            NSString *s = [string substringWithRange:m.range];
            NSUInteger digits = 0; for (NSUInteger i = 0; i < s.length; i++) if (isdigit([s characterAtIndex:i])) digits++;
            BOOL separated = [s rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" .-()+"]].location != NSNotFound;
            if (digits < 7 || digits > 15 || (!separated && digits < 10)) continue;
            if ([_dateISO firstMatchInString:s options:NSMatchingAnchored range:NSMakeRange(0, s.length)]) continue;
            [found addObject:[NSTextCheckingResult phoneNumberCheckingResultWithRange:m.range phoneNumber:s]];
        }
    }
    if (_types & NSTextCheckingTypeAddress) {
        for (NSTextCheckingResult *m in [_address matchesInString:string options:0 range:range]) {
            NSMutableDictionary *c = [NSMutableDictionary dictionary];
            NSString *street = sub(m, 1), *city = [sub(m, 2) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet], *state = sub(m, 3), *zip = sub(m, 4);
            NSRange r = m.range;
            if (city.length && !state && !zip) {           /* a capitalised word after the street is a city only with a state or ZIP */
                city = nil; r = [m rangeAtIndex:1];
            }
            if (street) c[NSTextCheckingStreetKey] = street;
            if (city.length) c[NSTextCheckingCityKey] = city;
            if (state) c[NSTextCheckingStateKey] = state;
            if (zip) c[NSTextCheckingZIPKey] = zip;
            [found addObject:[NSTextCheckingResult addressCheckingResultWithRange:r components:c]];
        }
    }
    if (_types & NSTextCheckingTypeTransitInformation) {
        for (NSTextCheckingResult *m in [_flight matchesInString:string options:0 range:range])
            [found addObject:[NSTextCheckingResult transitInformationCheckingResultWithRange:m.range
                components:@{ NSTextCheckingAirlineKey: airlines()[sub(m, 1)], NSTextCheckingFlightKey: sub(m, 2) }]];
    }
    if (_types & NSTextCheckingTypeDate) {
        BOOL dayFirst = ![NSLocale.currentLocale.countryCode isEqualToString:@"US"];
        for (NSTextCheckingResult *m in [_dateISO matchesInString:string options:0 range:range]) {
            NSDate *d = make_date(sub(m, 1).integerValue, sub(m, 2).integerValue, sub(m, 3).integerValue, sub(m, 4).integerValue, sub(m, 5).integerValue, sub(m, 6).integerValue);
            if (d) [found addObject:[NSTextCheckingResult dateCheckingResultWithRange:m.range date:d]];
        }
        for (NSTextCheckingResult *m in [_dateNum matchesInString:string options:0 range:range]) {
            NSInteger a = sub(m, 1).integerValue, b = sub(m, 2).integerValue, y = sub(m, 3).integerValue;
            if (y < 100) y += 2000;
            NSDate *d = dayFirst ? make_date(y, b, a, 12, 0, 0) : make_date(y, a, b, 12, 0, 0);
            if (d) [found addObject:[NSTextCheckingResult dateCheckingResultWithRange:m.range date:d]];
        }
        for (NSTextCheckingResult *m in [_dateText1 matchesInString:string options:0 range:range]) {
            NSString *y = sub(m, 3);
            NSDate *d = make_date(y ? y.integerValue : current_year(), month_index(sub(m, 1)), sub(m, 2).integerValue, 12, 0, 0);
            if (d) [found addObject:[NSTextCheckingResult dateCheckingResultWithRange:m.range date:d]];
        }
        for (NSTextCheckingResult *m in [_dateText2 matchesInString:string options:0 range:range]) {
            NSString *y = sub(m, 3);
            NSDate *d = make_date(y ? y.integerValue : current_year(), month_index(sub(m, 2)), sub(m, 1).integerValue, 12, 0, 0);
            if (d) [found addObject:[NSTextCheckingResult dateCheckingResultWithRange:m.range date:d]];
        }
        for (NSTextCheckingResult *m in [_dateRel matchesInString:string options:0 range:range]) {
            NSString *w = sub(m, 1).lowercaseString;
            NSInteger days = [w isEqualToString:@"tomorrow"] ? 1 : [w isEqualToString:@"yesterday"] ? -1 : 0;
            time_t t = time(NULL) + days * 86400; struct tm tm; localtime_r(&t, &tm);
            NSDate *d = make_date(tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, 12, 0, 0);
            if (d) [found addObject:[NSTextCheckingResult dateCheckingResultWithRange:m.range date:d]];
        }
    }
    /* in text order; overlapping results keep the earliest (then longest) one */
    [found sortUsingComparator:^NSComparisonResult(NSTextCheckingResult *a, NSTextCheckingResult *b) {
        if (a.range.location != b.range.location) return a.range.location < b.range.location ? NSOrderedAscending : NSOrderedDescending;
        return a.range.length > b.range.length ? NSOrderedAscending : a.range.length < b.range.length ? NSOrderedDescending : NSOrderedSame;
    }];
    NSUInteger end = 0; BOOL stop = NO;
    for (NSTextCheckingResult *r in found) {
        if (r.range.location < end) continue;
        end = NSMaxRange(r.range);
        block(r, 0, &stop);
        if (stop) return;
    }
    if (options & NSMatchingReportCompletion) block(nil, NSMatchingCompleted, &stop);
}
@end
