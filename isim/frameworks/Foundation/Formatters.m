/* isim Foundation (ARC): NSNumberFormatter (decimal engine with ICU-style rounding of the shortest decimal
 * representation), NSISO8601DateFormatter, NSRelativeDateTimeFormatter, NSDateComponentsFormatter,
 * NSDateIntervalFormatter, NSByteCountFormatter, NSListFormatter, NSPersonNameComponents(+Formatter), NSCalendar
 * (minimal). Locale data comes from Locale.m (isim_locale.h); formats follow the device region like iOS. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "isim_foundation.h"
#include "isim_locale.h"

NSString *isim_format_date(NSDate *date, NSString *fmt, NSLocale *locale, NSTimeZone *tz, NSDictionary *symbols);
NSString *isim_icu_date_locale(NSLocale *locale, NSString *calendarID);

/* ================= decimal digits ================= */
/* A non-negative decimal: digits d[0..n) (most significant first) and exponent e so value = 0.d1d2... * 10^e. */
typedef struct { char d[64]; int n; int e; } decnum;
static void dec_from_double(double v, decnum *out) {
    v = fabs(v);
    out->n = 0; out->e = 0;
    if (v == 0 || !isfinite(v)) return;
    char buf[64];
    for (int p = 1; p <= 17; p++) {                      /* shortest representation that round-trips */
        snprintf(buf, sizeof buf, "%.*e", p - 1, v);
        if (strtod(buf, NULL) == v) break;
    }
    char *e = strchr(buf, 'e');
    int exp10 = atoi(e + 1);
    for (char *c = buf; c < e; c++) if (isdigit((unsigned char)*c)) out->d[out->n++] = *c;
    out->e = exp10 + 1;
    while (out->n > 0 && out->d[out->n - 1] == '0') out->n--;
}
static BOOL dec_from_string(const char *s, decnum *out, BOOL *neg) {
    out->n = 0; out->e = 0; *neg = NO;
    while (*s == ' ') s++;
    if (*s == '-') { *neg = YES; s++; } else if (*s == '+') s++;
    int intDigits = 0; BOOL seenDot = NO, any = NO, lead = YES;
    for (; *s; s++) {
        if (*s == '.') { if (seenDot) return NO; seenDot = YES; continue; }
        if (*s == 'e' || *s == 'E') { out->e += atoi(s + 1); break; }
        if (!isdigit((unsigned char)*s)) return NO;
        any = YES;
        if (lead && *s == '0') { if (seenDot) out->e--; continue; }
        lead = NO;
        if (out->n < 60) out->d[out->n++] = *s;
        if (!seenDot) intDigits++;
    }
    out->e += intDigits;
    while (out->n > 0 && out->d[out->n - 1] == '0') out->n--;
    return any;
}
enum { R_CEIL, R_FLOOR, R_DOWN, R_UP, R_HALF_EVEN, R_HALF_DOWN, R_HALF_UP };
/* keep `keep` digits (may be <= 0), rounding by mode; neg affects ceiling/floor */
static void dec_round(decnum *x, int keep, int mode, BOOL neg) {
    if (x->n <= keep) return;
    if (keep < 0) { x->n = 0; return; }
    BOOL nonzeroRest = NO;
    for (int i = keep + 1; i < x->n; i++) if (x->d[i] != '0') nonzeroRest = YES;
    int first = x->d[keep] - '0';
    BOOL anyRest = first != 0 || nonzeroRest;
    BOOL up = NO;
    switch (mode) {
    case R_CEIL: up = !neg && anyRest; break;
    case R_FLOOR: up = neg && anyRest; break;
    case R_DOWN: up = NO; break;
    case R_UP: up = anyRest; break;
    case R_HALF_EVEN: up = first > 5 || (first == 5 && (nonzeroRest || (keep > 0 && ((x->d[keep - 1] - '0') & 1)))); break;
    case R_HALF_DOWN: up = first > 5 || (first == 5 && nonzeroRest); break;
    default: up = first >= 5; break;
    }
    x->n = keep;
    if (up) {
        int i = keep - 1;
        while (i >= 0 && x->d[i] == '9') { x->d[i] = '0'; i--; }
        if (i >= 0) x->d[i]++;
        else { x->d[0] = '1'; x->n = 1; x->e++; }      /* 0.999 -> 1, or rounding up from no kept digits */
    }
    while (x->n > 0 && x->d[x->n - 1] == '0') x->n--;
}
static double dec_to_double(const decnum *x) {
    char buf[96]; int k = 0; buf[k++] = '0'; buf[k++] = '.';
    for (int i = 0; i < x->n; i++) buf[k++] = x->d[i];
    snprintf(buf + k, sizeof buf - (size_t)k, "e%d", x->e);
    return x->n ? strtod(buf, NULL) : 0;
}

/* ================= number formatting spec ================= */
typedef struct {
    int minInt, maxInt, minFrac, maxFrac, minSig, maxSig; BOOL useSig;
    BOOL grouping; int groupSize, group2, minGroup;
    int rounding; double increment;
    NSString *dec, *grp;
} numspec;
/* digits of |value| as "int" and "frac" strings after rounding */
static void dec_layout(decnum x, const numspec *sp, BOOL neg, NSString **intOut, NSString **fracOut) {
    if (sp->increment > 0) {
        /* round to a multiple of the increment (prices like 0.05) */
        double v = dec_to_double(&x) / sp->increment;
        decnum q; dec_from_double(v, &q); dec_round(&q, q.e, sp->rounding, neg);
        dec_from_double(dec_to_double(&q) * sp->increment, &x);
    }
    if (sp->useSig) {
        dec_round(&x, sp->maxSig, sp->rounding, neg);
    } else {
        dec_round(&x, x.e + sp->maxFrac, sp->rounding, neg);
    }
    NSMutableString *ip = [NSMutableString string], *fp = [NSMutableString string];
    for (int i = 0; i < x.e && i < 400; i++) [ip appendFormat:@"%c", i < x.n ? x.d[i] : '0'];
    if (x.n) {
        if (x.e < 0) for (int z = x.e; z < 0 && z > -400; z++) [fp appendString:@"0"];
        for (int i = MAX(x.e, 0); i < x.n; i++) [fp appendFormat:@"%c", x.d[i]];
    }
    int minFrac = sp->minFrac;
    if (sp->useSig) {
        int shown = x.e > 0 ? MAX(x.n, x.e) : x.n;
        if (!x.n) shown = 1;
        if (shown < sp->minSig) minFrac = MAX(minFrac, (int)fp.length + (sp->minSig - shown));
        if (sp->maxFrac < minFrac && !sp->useSig) minFrac = sp->maxFrac;
    }
    while ((int)fp.length < minFrac) [fp appendString:@"0"];
    if (!ip.length) [ip setString:@"0"];
    while ((int)ip.length < sp->minInt) [ip insertString:@"0" atIndex:0];
    if ([ip isEqualToString:@"0"] && sp->minInt == 0 && fp.length) [ip setString:@""];
    if (sp->maxInt > 0 && (int)ip.length > sp->maxInt) [ip deleteCharactersInRange:NSMakeRange(0, ip.length - (NSUInteger)sp->maxInt)];
    *intOut = ip; *fracOut = fp;
}
static NSString *group_digits(NSString *ip, const numspec *sp) {
    if (!sp->grouping || (int)ip.length < sp->groupSize + sp->minGroup) return ip;
    NSMutableString *g = [NSMutableString string];
    int n = (int)ip.length, size = sp->groupSize, size2 = sp->group2 > 0 ? sp->group2 : size;
    NSMutableArray *parts = [NSMutableArray array];
    int end = n;
    int first = 1;
    while (end > 0) {
        int sz = first ? size : size2; first = 0;
        int start = MAX(0, end - sz);
        [parts insertObject:[ip substringWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start))] atIndex:0];
        end = start;
    }
    [g appendString:[parts componentsJoinedByString:sp->grp]];
    return g;
}
static NSString *format_plain(decnum x, const numspec *sp, BOOL neg) {
    NSString *ip, *fp;
    dec_layout(x, sp, neg, &ip, &fp);
    ip = group_digits(ip, sp);
    return fp.length ? [NSString stringWithFormat:@"%@%@%@", ip, sp->dec, fp] : ip;
}
static BOOL dec_is_zero_after(decnum x, const numspec *sp) {
    NSString *ip, *fp; dec_layout(x, sp, NO, &ip, &fp);
    NSString *all = [ip stringByAppendingString:fp];
    return [all stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0"]].length == 0;
}

/* ---------------- spell-out (English) and ordinals ---------------- */
static NSString *spell_en(unsigned long long n) {
    static const char *ones[] = { "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
                                  "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen" };
    static const char *tens[] = { "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety" };
    if (n < 20) return @(ones[n]);
    if (n < 100) return n % 10 ? [NSString stringWithFormat:@"%s-%s", tens[n / 10], ones[n % 10]] : @(tens[n / 10]);
    if (n < 1000) return n % 100 ? [NSString stringWithFormat:@"%s hundred %@", ones[n / 100], spell_en(n % 100)] : [NSString stringWithFormat:@"%s hundred", ones[n / 100]];
    static const char *scales[] = { "thousand", "million", "billion", "trillion", "quadrillion" };
    unsigned long long scale = 1000; int si = 0;
    while (n / scale >= 1000 && si < 4) { scale *= 1000; si++; }
    NSString *head = [NSString stringWithFormat:@"%@ %s", spell_en(n / scale), scales[si]];
    return n % scale ? [NSString stringWithFormat:@"%@ %@", head, spell_en(n % scale)] : head;
}
static NSString *spell_out(double v, NSString *lang) {
    NSString *sign = v < 0 ? @"minus " : @"";
    v = fabs(v);
    unsigned long long whole = (unsigned long long)floor(v);
    NSMutableString *s = [NSMutableString stringWithFormat:@"%@%@", sign, spell_en(whole)];
    double frac = v - (double)whole;
    if (frac > 1e-9) {
        decnum d; dec_from_double(v, &d);
        [s appendString:@" point"];
        for (int i = MAX(d.e, 0); i < d.n; i++) [s appendFormat:@" %@", spell_en((unsigned long long)(d.d[i] - '0'))];
    }
    (void)lang;
    return s;
}
static NSString *ordinal_suffix(long long n, NSString *lang) {
    if ([lang isEqualToString:@"en"]) {
        long long m100 = llabs(n) % 100, m10 = llabs(n) % 10;
        if (m100 >= 11 && m100 <= 13) return @"th";
        return m10 == 1 ? @"st" : m10 == 2 ? @"nd" : m10 == 3 ? @"rd" : @"th";
    }
    if ([lang isEqualToString:@"pt"] || [lang isEqualToString:@"it"]) return @"º";
    if ([lang isEqualToString:@"es"]) return @".º";
    if ([lang isEqualToString:@"fr"]) return n == 1 ? @"er" : @"e";
    if ([lang isEqualToString:@"de"]) return @".";
    if ([lang isEqualToString:@"ja"]) return @"";
    return @".";
}

/* ================= NSNumberFormatter ================= */
@implementation NSNumberFormatter {
    NSLocale *_locale;
    NSString *_dec, *_grp, *_cur, *_curCode, *_intlCur, *_percent, *_minus, *_plus, *_exp, *_nil, *_zero, *_nan, *_posInf, *_negInf;
    NSString *_posPrefix, *_posSuffix, *_negPrefix, *_negSuffix, *_posFormat, *_negFormat;
    BOOL _fracSet, _intSet, _groupSet, _sigSet;
    NSUInteger _minFrac, _maxFrac, _minInt, _maxInt, _minSig, _maxSig, _groupSize, _group2;
    BOOL _grouping, _useSig, _lenient, _allowsFloats, _generatesDecimal;
    NSInteger _rounding; NSNumber *_increment, *_multiplier, *_min, *_max;
    NSNumberFormatterStyle _style;
}
- (instancetype)init {
    if ((self = [super init])) {
        _locale = NSLocale.currentLocale; _maxFrac = 0; _minInt = 1; _maxInt = 42; _rounding = R_HALF_EVEN; _allowsFloats = YES;
        _minSig = 1; _maxSig = 6; _groupSize = 3;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)z {
    NSNumberFormatter *f = [NSNumberFormatter new];
    f->_locale = _locale; f->_dec = _dec; f->_grp = _grp; f->_cur = _cur; f->_curCode = _curCode; f->_intlCur = _intlCur; f->_percent = _percent;
    f->_minus = _minus; f->_plus = _plus; f->_exp = _exp; f->_nil = _nil; f->_zero = _zero; f->_nan = _nan;
    f->_posPrefix = _posPrefix; f->_posSuffix = _posSuffix; f->_negPrefix = _negPrefix; f->_negSuffix = _negSuffix;
    f->_fracSet = _fracSet; f->_intSet = _intSet; f->_groupSet = _groupSet; f->_sigSet = _sigSet;
    f->_minFrac = _minFrac; f->_maxFrac = _maxFrac; f->_minInt = _minInt; f->_maxInt = _maxInt; f->_minSig = _minSig; f->_maxSig = _maxSig;
    f->_groupSize = _groupSize; f->_group2 = _group2; f->_grouping = _grouping; f->_useSig = _useSig; f->_lenient = _lenient;
    f->_allowsFloats = _allowsFloats; f->_rounding = _rounding; f->_increment = _increment; f->_multiplier = _multiplier; f->_style = _style;
    f->_min = _min; f->_max = _max;
    return f;
}
- (const isim_region_t *)_region { return isim_region(isim_locale_ident(_locale)); }
- (NSString *)_lang { return isim_locale_lang(_locale); }
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; [self _applyStyleDefaults]; }
- (NSNumberFormatterStyle)numberStyle { return _style; }
- (void)setNumberStyle:(NSNumberFormatterStyle)st { _style = st; _fracSet = NO; _groupSet = NO; [self _applyStyleDefaults]; }
- (BOOL)_isCurrency { return _style == NSNumberFormatterCurrencyStyle || _style == NSNumberFormatterCurrencyISOCodeStyle || _style == NSNumberFormatterCurrencyPluralStyle || _style == NSNumberFormatterCurrencyAccountingStyle; }
- (void)_applyStyleDefaults {
    if (!_fracSet) {
        _minFrac = 0;
        _maxFrac = _style == NSNumberFormatterDecimalStyle ? 3 : 0;
        if ([self _isCurrency]) _minFrac = _maxFrac = (NSUInteger)isim_currency_digits(self.currencyCode);
        if (_style == NSNumberFormatterScientificStyle) _maxFrac = 16;
    }
    if (!_groupSet) _grouping = _style == NSNumberFormatterDecimalStyle || [self _isCurrency] || _style == NSNumberFormatterPercentStyle;
    if (!_intSet) _minInt = _style == NSNumberFormatterNoStyle || _style == NSNumberFormatterDecimalStyle || [self _isCurrency] || _style == NSNumberFormatterPercentStyle ? 1 : 0;
    if (_style == NSNumberFormatterPercentStyle && !_multiplier) {}
}
#define ACC(type, get, set, ivar, flag) - (type)get { return ivar; } - (void)set:(type)v { ivar = v; flag; }
ACC(NSUInteger, minimumFractionDigits, setMinimumFractionDigits, _minFrac, (_fracSet = YES, _maxFrac = MAX(_maxFrac, v)))
ACC(NSUInteger, maximumFractionDigits, setMaximumFractionDigits, _maxFrac, (_fracSet = YES, _minFrac = MIN(_minFrac, v)))
ACC(NSUInteger, minimumIntegerDigits, setMinimumIntegerDigits, _minInt, (_intSet = YES, _maxInt = MAX(_maxInt, v)))
ACC(NSUInteger, maximumIntegerDigits, setMaximumIntegerDigits, _maxInt, (_minInt = MIN(_minInt, v)))
ACC(NSUInteger, minimumSignificantDigits, setMinimumSignificantDigits, _minSig, (_useSig = YES, _maxSig = MAX(_maxSig, v)))
ACC(NSUInteger, maximumSignificantDigits, setMaximumSignificantDigits, _maxSig, (_useSig = YES, _minSig = MIN(_minSig, v)))
ACC(BOOL, usesSignificantDigits, setUsesSignificantDigits, _useSig, (void)0)
ACC(BOOL, usesGroupingSeparator, setUsesGroupingSeparator, _grouping, _groupSet = YES)
ACC(NSUInteger, groupingSize, setGroupingSize, _groupSize, (void)0)
ACC(NSUInteger, secondaryGroupingSize, setSecondaryGroupingSize, _group2, (void)0)
ACC(BOOL, isLenient, setLenient, _lenient, (void)0)
ACC(BOOL, allowsFloats, setAllowsFloats, _allowsFloats, (void)0)
ACC(BOOL, generatesDecimalNumbers, setGeneratesDecimalNumbers, _generatesDecimal, (void)0)
- (NSNumberFormatterRoundingMode)roundingMode { return (NSNumberFormatterRoundingMode)_rounding; }
- (void)setRoundingMode:(NSNumberFormatterRoundingMode)m { _rounding = (NSInteger)m; }
- (NSNumber *)roundingIncrement { return _increment ?: @0; }
- (void)setRoundingIncrement:(NSNumber *)n { _increment = n; }
- (NSNumber *)multiplier { return _multiplier ?: (_style == NSNumberFormatterPercentStyle ? @100 : nil); }
- (void)setMultiplier:(NSNumber *)n { _multiplier = n; }
- (NSNumber *)minimum { return _min; }
- (void)setMinimum:(NSNumber *)n { _min = n; }
- (NSNumber *)maximum { return _max; }
- (void)setMaximum:(NSNumber *)n { _max = n; }
#define STR(get, set, ivar, def) - (NSString *)get { return ivar ?: (def); } - (void)set:(NSString *)s { ivar = [s copy]; }
STR(decimalSeparator, setDecimalSeparator, _dec, @([self _region]->decimal))
STR(groupingSeparator, setGroupingSeparator, _grp, @([self _region]->group))
STR(currencyDecimalSeparator, setCurrencyDecimalSeparator, _dec, @([self _region]->decimal))
STR(currencyGroupingSeparator, setCurrencyGroupingSeparator, _grp, @([self _region]->group))
STR(currencyCode, setCurrencyCode, _curCode, @([self _region]->currencyCode))
STR(currencySymbol, setCurrencySymbol, _cur, isim_currency_symbol(self.currencyCode, _locale))
STR(internationalCurrencySymbol, setInternationalCurrencySymbol, _intlCur, self.currencyCode)
STR(percentSymbol, setPercentSymbol, _percent, @"%")
STR(minusSign, setMinusSign, _minus, @"-")
STR(plusSign, setPlusSign, _plus, @"+")
STR(exponentSymbol, setExponentSymbol, _exp, @"E")
STR(nilSymbol, setNilSymbol, _nil, @"")
STR(notANumberSymbol, setNotANumberSymbol, _nan, @"NaN")
STR(positiveInfinitySymbol, setPositiveInfinitySymbol, _posInf, @"∞")
STR(negativeInfinitySymbol, setNegativeInfinitySymbol, _negInf, @"-∞")
- (NSString *)zeroSymbol { return _zero; }
- (void)setZeroSymbol:(NSString *)s { _zero = [s copy]; }
- (NSString *)perMillSymbol { return @"‰"; }
- (NSString *)paddingCharacter { return @" "; }
- (NSString *)positivePrefix { return _posPrefix ?: [self _affixes:NO][0]; }
- (void)setPositivePrefix:(NSString *)s { _posPrefix = [s copy]; }
- (NSString *)positiveSuffix { return _posSuffix ?: [self _affixes:NO][1]; }
- (void)setPositiveSuffix:(NSString *)s { _posSuffix = [s copy]; }
- (NSString *)negativePrefix { return _negPrefix ?: [self _affixes:YES][0]; }
- (void)setNegativePrefix:(NSString *)s { _negPrefix = [s copy]; }
- (NSString *)negativeSuffix { return _negSuffix ?: [self _affixes:YES][1]; }
- (void)setNegativeSuffix:(NSString *)s { _negSuffix = [s copy]; }
- (NSString *)positiveFormat { return _posFormat ?: @"#,##0.###"; }
- (void)setPositiveFormat:(NSString *)f { _posFormat = [f copy]; [self _applyPattern:f]; }
- (NSString *)negativeFormat { return _negFormat ?: [@"-" stringByAppendingString:self.positiveFormat]; }
- (void)setNegativeFormat:(NSString *)f { _negFormat = [f copy]; }
/* "#,##0.00" style patterns: digits and grouping */
- (void)_applyPattern:(NSString *)f {
    NSRange dot = [f rangeOfString:@"."];
    NSString *ip = dot.location == NSNotFound ? f : [f substringToIndex:dot.location];
    NSString *fp = dot.location == NSNotFound ? @"" : [f substringFromIndex:dot.location + 1];
    NSUInteger zeros = 0, hashes = 0;
    for (NSUInteger i = 0; i < fp.length; i++) { unichar c = [fp characterAtIndex:i]; if (c == '0') zeros++; else if (c == '#') hashes++; }
    _minFrac = zeros; _maxFrac = zeros + hashes; _fracSet = YES;
    NSUInteger izeros = 0; for (NSUInteger i = 0; i < ip.length; i++) if ([ip characterAtIndex:i] == '0') izeros++;
    _minInt = izeros; _intSet = YES;
    NSRange comma = [ip rangeOfString:@"," options:NSBackwardsSearch];
    _grouping = comma.location != NSNotFound; _groupSet = YES;
    if (_grouping) _groupSize = ip.length - comma.location - 1;
}
/* [prefix, suffix] from the style and region patterns */
- (NSArray<NSString *> *)_affixes:(BOOL)negative {
    const isim_region_t *r = [self _region];
    NSString *minus = negative ? self.minusSign : @"";
    NSString *pattern = nil;
    if ([self _isCurrency]) {
        NSString *sym = _style == NSNumberFormatterCurrencyISOCodeStyle ? self.currencyCode : self.currencySymbol;
        pattern = @(r->currencyPattern);
        if (_style == NSNumberFormatterCurrencyISOCodeStyle && [pattern hasPrefix:@"¤#"]) pattern = @"¤ #";
        if (_style == NSNumberFormatterCurrencyPluralStyle) return @[minus, @""];
        if (_style == NSNumberFormatterCurrencyAccountingStyle && negative && [isim_locale_lang(_locale) isEqualToString:@"en"]) {
            NSRange h = [pattern rangeOfString:@"#"];
            return @[[@"(" stringByAppendingString:[pattern substringToIndex:h.location]].mutableCopy, [[[pattern substringFromIndex:h.location + 1] stringByAppendingString:@")"] stringByReplacingOccurrencesOfString:@"¤" withString:sym]];
        }
        NSRange h = [pattern rangeOfString:@"#"];
        NSString *pre = [[pattern substringToIndex:h.location] stringByReplacingOccurrencesOfString:@"¤" withString:sym];
        NSString *suf = [[pattern substringFromIndex:h.location + 1] stringByReplacingOccurrencesOfString:@"¤" withString:sym];
        return @[[minus stringByAppendingString:pre], suf];
    }
    if (_style == NSNumberFormatterPercentStyle) {
        pattern = @(r->percentPattern);
        NSRange h = [pattern rangeOfString:@"#"];
        return @[[minus stringByAppendingString:[pattern substringToIndex:h.location]], [[pattern substringFromIndex:h.location + 1] stringByReplacingOccurrencesOfString:@"%" withString:self.percentSymbol]];
    }
    return @[minus, @""];
}
- (numspec)_spec {
    const isim_region_t *r = [self _region];
    numspec sp = { (int)_minInt, (int)_maxInt, (int)_minFrac, (int)_maxFrac, (int)_minSig, (int)_maxSig, _useSig,
                   _grouping, (int)_groupSize, (int)_group2, r->minGroup, (int)_rounding, _increment.doubleValue,
                   [self _isCurrency] ? self.currencyDecimalSeparator : self.decimalSeparator, [self _isCurrency] ? self.currencyGroupingSeparator : self.groupingSeparator };
    if (r->indian && !_group2) sp.group2 = 2;
    if (_grp && !_dec && [_grp isEqualToString:sp.dec]) {}
    return sp;
}
- (NSString *)_formatDecimal:(decnum)x negative:(BOOL)neg value:(double)v {
    NSString *lang = [self _lang];
    switch (_style) {
    case NSNumberFormatterSpellOutStyle: {
        /* ICU's rule-based spell-out for every language; the built-in one is English */
        NSString *icu = isim_icu_on() ? isim_icu_number_style(isim_locale_ident(_locale), 5, nil, neg ? -v : v) : nil;
        return icu ?: spell_out(neg ? -v : v, lang);
    }
    case NSNumberFormatterOrdinalStyle: {
        if (!isim_lang_builtin(lang) && isim_icu_on()) {
            dec_round(&x, x.e, (int)_rounding, neg);
            NSString *icu = isim_icu_number_style(isim_locale_ident(_locale), 6, nil, (neg ? -1 : 1) * dec_to_double(&x));
            if (icu) return icu;
        }
        numspec sp = [self _spec]; sp.maxFrac = 0; sp.minFrac = 0; sp.useSig = NO; sp.grouping = YES;
        dec_round(&x, x.e, (int)_rounding, neg);
        NSString *num = format_plain(x, &sp, neg);
        long long n = (long long)llround(dec_to_double(&x));
        return [NSString stringWithFormat:@"%@%@%@", neg ? self.minusSign : @"", num, ordinal_suffix(n, lang)];
    }
    case NSNumberFormatterScientificStyle: {
        int e = x.n ? x.e - 1 : 0;
        decnum m = x; m.e = 1;
        numspec sp = [self _spec]; sp.grouping = NO; sp.minInt = 1;
        if (_useSig) { sp.useSig = YES; }
        dec_round(&m, sp.useSig ? sp.maxSig : 1 + sp.maxFrac, (int)_rounding, neg);
        if (m.e > 1) { m.e = 1; e++; }
        NSString *ms = format_plain(m, &sp, neg);
        return [NSString stringWithFormat:@"%@%@%@%d", neg ? self.minusSign : @"", ms, self.exponentSymbol, e];
    }
    default: break;
    }
    numspec sp = [self _spec];
    if (neg && dec_is_zero_after(x, &sp)) neg = NO;                /* -0.001 -> "0" (ICU drops the sign) */
    NSString *body = format_plain(x, &sp, neg);
    NSString *pre = neg ? self.negativePrefix : self.positivePrefix, *suf = neg ? self.negativeSuffix : self.positiveSuffix;
    if (_style == NSNumberFormatterCurrencyPluralStyle) {
        NSString *name = isim_currency_name(self.currencyCode, !isim_plural_one(lang, v, 0) || [body containsString:sp.dec]);
        if (isim_icu_on()) {                     /* the currency's name in the locale's language, in the number's plural form */
            NSString *ident = isim_locale_ident(_locale);
            NSString *cat = isim_icu_plural_category(ident, [body containsString:sp.dec] ? v + 0.5 * (v == floor(v)) : v, NO);
            name = isim_icu_currency_string(ident, self.currencyCode, 3, cat ?: @"other") ?: name;
        }
        return [NSString stringWithFormat:@"%@%@ %@", pre, body, name];
    }
    return [NSString stringWithFormat:@"%@%@%@", pre, body, suf];
}
- (NSString *)stringFromNumber:(NSNumber *)number {
    if (!number) return self.nilSymbol;
    double v = number.doubleValue;
    if (isnan(v)) return self.notANumberSymbol;
    if (isinf(v)) return v > 0 ? self.positiveInfinitySymbol : self.negativeInfinitySymbol;
    if (v == 0 && _zero) return _zero;
    double mul = self.multiplier ? self.multiplier.doubleValue : 1;
    decnum x;
    const char *objType = number.objCType;
    BOOL integral = objType && strchr("cislqCISLQB", objType[0]);
    if (integral && mul == 1) {
        long long iv = number.longLongValue;
        char buf[32];
        if (objType[0] == 'Q' || objType[0] == 'L') snprintf(buf, sizeof buf, "%llu", number.unsignedLongLongValue);
        else snprintf(buf, sizeof buf, "%lld", iv);
        BOOL neg; dec_from_string(buf, &x, &neg);
        return [self _formatDecimal:x negative:neg value:(double)iv];
    }
    v *= mul;
    dec_from_double(v, &x);
    return [self _formatDecimal:x negative:v < 0 || (v == 0 && signbit(v) && NO) value:v];
}
/* isim: exact formatting of a decimal string (Swift Decimal) */
- (NSString *)_isim_stringFromDecimalString:(NSString *)s {
    decnum x; BOOL neg;
    if (!dec_from_string(s.UTF8String, &x, &neg)) return self.notANumberSymbol;
    double mul = self.multiplier ? self.multiplier.doubleValue : 1;
    if (mul != 1) { int shift = (int)lround(log10(mul)); if (pow(10, shift) == mul) x.e += shift; else { double v = dec_to_double(&x) * mul; dec_from_double(v, &x); } }
    return [self _formatDecimal:x negative:neg value:(neg ? -1 : 1) * dec_to_double(&x)];
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSNumber class]] ? [self stringFromNumber:obj] : nil; }
+ (NSString *)localizedStringFromNumber:(NSNumber *)n numberStyle:(NSNumberFormatterStyle)st {
    NSNumberFormatter *f = [NSNumberFormatter new]; f.numberStyle = st; return [f stringFromNumber:n];
}
- (NSNumber *)numberFromString:(NSString *)string {
    if (!string) return nil;
    NSString *s = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL neg = NO;
    NSArray *posA = [self _affixes:NO], *negA = [self _affixes:YES];
    NSString *(^strip)(NSString *, NSString *, BOOL) = ^NSString *(NSString *str, NSString *affix, BOOL prefix) {
        NSString *a = [affix stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        a = [a stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"  "]];
        if (!a.length) return str;
        if (prefix && [str hasPrefix:a]) return [str substringFromIndex:a.length];
        if (!prefix && [str hasSuffix:a]) return [str substringToIndex:str.length - a.length];
        return nil;
    };
    NSString *t;
    if ([negA[0] length] && (t = strip(s, negA[0], YES)) && (t = strip(t, negA[1], NO))) { neg = YES; s = t; }
    else if ((t = strip(s, posA[0], YES)) && (t = strip(t, posA[1], NO))) s = t;
    else if (!_lenient && ([posA[0] length] || [posA[1] length]) && _style != NSNumberFormatterDecimalStyle) {
        /* strict formatters require the affixes; lenient ones accept bare numbers */
        if (!([self _isCurrency] || _style == NSNumberFormatterPercentStyle)) return nil;
        return nil;
    }
    if ([s hasPrefix:self.minusSign] || [s hasPrefix:@"-"]) { neg = !neg; s = [s substringFromIndex:1]; }
    else if ([s hasPrefix:@"+"]) s = [s substringFromIndex:1];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"   "]];
    NSString *dec = self.decimalSeparator, *grp = self.groupingSeparator;
    NSMutableString *clean = [NSMutableString string];
    BOOL seenDec = NO;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        NSString *ch = [s substringWithRange:NSMakeRange(i, 1)];
        if (c >= '0' && c <= '9') [clean appendString:ch];
        else if ([ch isEqualToString:dec] && !seenDec) { [clean appendString:@"."]; seenDec = YES; }
        else if ([ch isEqualToString:grp] || ((c == ' ' || c == 0xA0 || c == 0x202F) && ([grp isEqualToString:@" "] || [grp isEqualToString:@" "] || [grp isEqualToString:@" "]))) { if (seenDec) return nil; }
        else if ((c == 'e' || c == 'E') && _style == NSNumberFormatterScientificStyle) [clean appendString:@"e"];
        else if (c == '-' && [clean hasSuffix:@"e"]) [clean appendString:@"-"];
        else return nil;
    }
    if (!clean.length) return nil;
    if (seenDec && !_allowsFloats) return nil;
    double v = strtod(clean.UTF8String, NULL);
    if (neg) v = -v;
    double mul = self.multiplier ? self.multiplier.doubleValue : 1;
    if (mul != 1 && mul != 0) v /= mul;
    if (v == floor(v) && fabs(v) < 9e15 && !seenDec) return @((long long)v);
    return @(v);
}
- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error {
    NSNumber *n = [self numberFromString:string];
    if (obj) *obj = n;
    if (!n && error) *error = @"Invalid number";
    return n != nil;
}
@end

/* format a double with the number engine (used by the Swift FormatStyles via -[NSNumberFormatter _isim...]) */

/* ================= NSCalendar (minimal; Swift's Calendar is a value type in the overlay) ================= */
NSCalendarIdentifier const NSCalendarIdentifierGregorian = @"gregorian", NSCalendarIdentifierISO8601 = @"iso8601";
/* the other calendars are ICU's keyword values (computed by the host's ICU, see Swift's CalendarICU.swift) */
NSCalendarIdentifier const NSCalendarIdentifierBuddhist = @"buddhist", NSCalendarIdentifierChinese = @"chinese", NSCalendarIdentifierCoptic = @"coptic", NSCalendarIdentifierEthiopicAmeteMihret = @"ethiopic", NSCalendarIdentifierEthiopicAmeteAlem = @"ethiopic-amete-alem", NSCalendarIdentifierHebrew = @"hebrew", NSCalendarIdentifierIndian = @"indian", NSCalendarIdentifierIslamic = @"islamic", NSCalendarIdentifierIslamicCivil = @"islamic-civil", NSCalendarIdentifierIslamicTabular = @"islamic-tbla", NSCalendarIdentifierIslamicUmmAlQura = @"islamic-umalqura", NSCalendarIdentifierJapanese = @"japanese", NSCalendarIdentifierPersian = @"persian", NSCalendarIdentifierRepublicOfChina = @"roc";
@implementation NSCalendar { NSString *_ident; }
+ (NSCalendar *)currentCalendar { return [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]; }
+ (NSCalendar *)autoupdatingCurrentCalendar { return [self currentCalendar]; }
+ (NSCalendar *)calendarWithIdentifier:(NSCalendarIdentifier)ident { return [[NSCalendar alloc] initWithCalendarIdentifier:ident]; }
- (instancetype)initWithCalendarIdentifier:(NSCalendarIdentifier)ident { if ((self = [super init])) { _ident = [ident copy]; _timeZone = NSTimeZone.defaultTimeZone; _locale = NSLocale.currentLocale; _firstWeekday = (NSUInteger)isim_region(isim_locale_ident(_locale))->firstWeekday; _minimumDaysInFirstWeek = 1; } return self; }
- (NSCalendarIdentifier)calendarIdentifier { return _ident; }
- (id)copyWithZone:(NSZone *)z { NSCalendar *c = [[NSCalendar alloc] initWithCalendarIdentifier:_ident]; c.timeZone = self.timeZone; c.locale = self.locale; c.firstWeekday = self.firstWeekday; return c; }
- (NSArray<NSString *> *)monthSymbols { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.monthSymbols; }
- (NSArray<NSString *> *)shortMonthSymbols { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.shortMonthSymbols; }
- (NSArray<NSString *> *)weekdaySymbols { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.weekdaySymbols; }
- (NSArray<NSString *> *)shortWeekdaySymbols { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.shortWeekdaySymbols; }
- (NSArray<NSString *> *)veryShortWeekdaySymbols { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.veryShortWeekdaySymbols; }
- (NSString *)AMSymbol { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.AMSymbol; }
- (NSString *)PMSymbol { NSDateFormatter *f = [NSDateFormatter new]; f.locale = self.locale; return f.PMSymbol; }
@end

/* ================= NSISO8601DateFormatter ================= */
@implementation NSISO8601DateFormatter
@synthesize timeZone = _timeZone;
- (NSTimeZone *)timeZone { return _timeZone; }
- (instancetype)init {
    if ((self = [super init])) { _formatOptions = NSISO8601DateFormatWithInternetDateTime; _timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; }
    return self;
}
- (void)setTimeZone:(NSTimeZone *)tz { _timeZone = tz ?: [NSTimeZone timeZoneForSecondsFromGMT:0]; }
+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)tz formatOptions:(NSISO8601DateFormatOptions)opts {
    NSISO8601DateFormatter *f = [NSISO8601DateFormatter new]; f.timeZone = tz; f.formatOptions = opts; return [f stringFromDate:date];
}
- (NSString *)_pattern {
    NSISO8601DateFormatOptions o = _formatOptions;
    NSMutableString *p = [NSMutableString string];
    BOOL dash = o & NSISO8601DateFormatWithDashSeparatorInDate, colon = o & NSISO8601DateFormatWithColonSeparatorInTime;
    if (o & NSISO8601DateFormatWithWeekOfYear) {
        [p appendString:@"YYYY"];
        if (dash) [p appendString:@"-"];
        [p appendString:@"'W'ww"];
        if (o & NSISO8601DateFormatWithDay) { if (dash) [p appendString:@"-"]; [p appendString:@"ee"]; }
    } else {
        if (o & NSISO8601DateFormatWithYear) [p appendString:@"yyyy"];
        if (o & NSISO8601DateFormatWithMonth) { if (p.length && dash) [p appendString:@"-"]; [p appendString:@"MM"]; }
        if (o & NSISO8601DateFormatWithDay) {
            if (p.length && dash) [p appendString:@"-"];
            [p appendString:(o & NSISO8601DateFormatWithMonth) || !(o & NSISO8601DateFormatWithYear) ? @"dd" : @"DDD"];
        }
    }
    if (o & NSISO8601DateFormatWithTime) {
        if (p.length) [p appendString:(o & NSISO8601DateFormatWithSpaceBetweenDateAndTime) ? @" " : @"'T'"];
        [p appendString:colon ? @"HH:mm:ss" : @"HHmmss"];
        if (o & NSISO8601DateFormatWithFractionalSeconds) [p appendString:@".SSS"];
    }
    if (o & NSISO8601DateFormatWithTimeZone) [p appendString:(o & NSISO8601DateFormatWithColonSeparatorInTimeZone) ? @"ZZZZZ" : @"XXXX"];
    return p;
}
- (NSString *)stringFromDate:(NSDate *)date {
    if (!date) return nil;
    return isim_format_date(date, [self _pattern], [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"], _timeZone, nil);
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSDate class]] ? [self stringFromDate:obj] : nil; }
/* accepts the configured format; time zone, fractional seconds and separators are parsed leniently */
- (NSDate *)dateFromString:(NSString *)string {
    if (!string) return nil;
    const char *s = string.UTF8String;
    int y = 1970, mo = 1, d = 1, h = 0, mi = 0, sec = 0; double frac = 0; long off = 0; BOOL haveTZ = NO;
    const char *p = s;
    #define DIGITS(n, out) do { int _v = 0; for (int _i = 0; _i < (n); _i++) { if (!isdigit((unsigned char)*p)) return nil; _v = _v * 10 + (*p++ - '0'); } (out) = _v; } while (0)
    NSISO8601DateFormatOptions o = _formatOptions;
    BOOL hasDate = o & (NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithWeekOfYear);
    if (hasDate) {
        if (o & NSISO8601DateFormatWithYear) DIGITS(4, y);
        if (*p == '-') p++;
        if (o & NSISO8601DateFormatWithMonth) { DIGITS(2, mo); if (*p == '-') p++; }
        if (o & NSISO8601DateFormatWithDay) DIGITS(2, d);
    }
    if (o & NSISO8601DateFormatWithTime) {
        if (hasDate) { if (*p == 'T' || *p == 't' || *p == ' ') p++; else return nil; }
        DIGITS(2, h); if (*p == ':') p++;
        DIGITS(2, mi); if (*p == ':') p++;
        DIGITS(2, sec);
        if (*p == '.' || *p == ',') {
            p++; double scale = 0.1;
            if (!isdigit((unsigned char)*p)) return nil;
            while (isdigit((unsigned char)*p)) { frac += (*p++ - '0') * scale; scale /= 10; }
            if (!(o & NSISO8601DateFormatWithFractionalSeconds)) return nil;
        } else if (o & NSISO8601DateFormatWithFractionalSeconds) return nil;
    }
    if (o & NSISO8601DateFormatWithTimeZone) {
        if (*p == 'Z' || *p == 'z') { p++; haveTZ = YES; }
        else if (*p == '+' || *p == '-') {
            int sign = *p++ == '-' ? -1 : 1, hh, mm = 0;
            DIGITS(2, hh); if (*p == ':') p++;
            if (isdigit((unsigned char)*p)) DIGITS(2, mm);
            off = sign * (hh * 3600 + mm * 60); haveTZ = YES;
        } else return nil;
    }
    if (*p) return nil;
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 24 || mi > 59 || sec > 60) return nil;
    struct tm tm = { .tm_year = y - 1900, .tm_mon = mo - 1, .tm_mday = d, .tm_hour = h, .tm_min = mi, .tm_sec = sec };
    time_t t = timegm(&tm);
    if (!haveTZ) off = [_timeZone secondsFromGMTForDate:[NSDate dateWithTimeIntervalSince1970:t]];
    return [NSDate dateWithTimeIntervalSince1970:(double)(t - off) + frac];
    #undef DIGITS
}
- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error {
    NSDate *d = [self dateFromString:string]; if (obj) *obj = d; return d != nil;
}
@end

/* ================= unit phrases shared by relative / components formatters ================= */
/* unit index: 0 year, 1 month, 2 week, 3 day, 4 hour, 5 minute, 6 second */
static NSString *const DURATION_UNITS[7] = { @"duration-year", @"duration-month", @"duration-week", @"duration-day", @"duration-hour", @"duration-minute", @"duration-second" };
static const int REL_UNITS[7] = { 0, 2, 3, 4, 5, 6, 7 };    /* URelativeDateTimeUnit for unit 0 year .. 6 second */
static NSString *count_unit(NSString *lang, double n, int unit, int width, BOOL relative, NSLocale *locale) {
    if (!isim_lang_builtin(lang) && isim_icu_on()) {          /* ICU's unit names, with the language's plural forms */
        NSNumberFormatter *nf = [NSNumberFormatter new]; nf.locale = locale; nf.numberStyle = width == 4 ? NSNumberFormatterSpellOutStyle : NSNumberFormatterDecimalStyle;
        NSString *p = isim_icu_unit_phrase(isim_locale_ident(locale), DURATION_UNITS[unit], n, [nf stringFromNumber:@(n)], width == 0 || width == 4 ? 2 : width == 1 ? 1 : 0);
        if (p) return p;
    }
    const isim_lang_t *L = isim_lang(lang);
    BOOL one = isim_plural_one(lang, n, n == floor(n) ? 0 : 1);
    NSNumberFormatter *nf = [NSNumberFormatter new]; nf.locale = locale; nf.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *num = width == 4 ? spell_out(n, lang) : [nf stringFromNumber:@(n)];
    NSString *name;
    if (width == 0) name = one ? @(L->unitOne[unit]) : (relative && L->relOther ? @(L->relOther[unit]) : @(L->unitOther[unit]));
    else if (width == 1) name = one ? @(L->unitShort[unit]) : @(L->unitShortOther[unit]);
    else name = @(L->unitNarrow[unit]);
    BOOL en = [lang isEqualToString:@"en"];
    if (width == 0 || width == 4) return [NSString stringWithFormat:@"%@ %@", num, name];
    if (width == 1) return [NSString stringWithFormat:@"%@ %@%@", num, name, en && relative ? @"." : @""];
    return relative && en ? [NSString stringWithFormat:@"%@%@", num, name] : [NSString stringWithFormat:@"%@%@", num, name];
}

/* ================= NSRelativeDateTimeFormatter ================= */
@implementation NSRelativeDateTimeFormatter
@synthesize locale = _locale, calendar = _calendar;
- (NSLocale *)locale { return _locale; }
- (NSCalendar *)calendar { return _calendar; }
- (void)setCalendar:(NSCalendar *)c { _calendar = [c copy] ?: NSCalendar.currentCalendar; }
- (instancetype)init { if ((self = [super init])) { _locale = NSLocale.currentLocale; _calendar = NSCalendar.currentCalendar; } return self; }
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; }
- (NSString *)_phrase:(double)value unit:(int)unit {
    NSString *lang = isim_locale_lang(_locale);
    if (!isim_lang_builtin(lang) && isim_icu_on()) {          /* ICU's relative date formatting (CLDR) */
        int width = _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleShort ? 1 : _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleAbbreviated ? 2 : 0;
        NSString *p = isim_icu_relative_string(isim_locale_ident(_locale), value, REL_UNITS[unit], width, _dateTimeStyle != NSRelativeDateTimeFormatterStyleNamed);
        if (p) return p;
    }
    const isim_lang_t *L = isim_lang(lang);
    if (_dateTimeStyle == NSRelativeDateTimeFormatterStyleNamed) {
        long iv = lround(value);
        if (value == iv) {
            if (unit == 3 && iv == -1) return @(L->yesterday);
            if (unit == 3 && iv == 0) return @(L->today);
            if (unit == 3 && iv == 1) return @(L->tomorrow);
            if (iv == -1 && L->lastUnit[unit]) return @(L->lastUnit[unit]);
            if (iv == 0 && L->thisUnit[unit]) return @(L->thisUnit[unit]);
            if (iv == 1 && L->nextUnit[unit]) return @(L->nextUnit[unit]);
        }
    }
    int width = _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleFull ? 0 : _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleSpellOut ? 4 :
                _unitsStyle == NSRelativeDateTimeFormatterUnitsStyleShort ? 1 : 2;
    NSString *counted = count_unit(lang, fabs(value), unit, width, YES, _locale);
    BOOL past = value < 0 || (value == 0 && signbit(value));
    NSString *tmpl = @(past ? L->relPast : L->relFuture);
    return [tmpl stringByReplacingOccurrencesOfString:@"%@" withString:counted];
}
- (NSString *)localizedStringFromTimeInterval:(NSTimeInterval)t {
    double a = fabs(t);
    int unit; double v;
    if (a < 60) { unit = 6; v = trunc(t); }
    else if (a < 3600) { unit = 5; v = trunc(t / 60); }
    else if (a < 86400) { unit = 4; v = trunc(t / 3600); }
    else if (a < 86400 * 7) { unit = 3; v = trunc(t / 86400); }
    else if (a < 86400 * 30.436875) { unit = 2; v = trunc(t / (86400 * 7)); }
    else if (a < 86400 * 365.2425) { unit = 1; v = trunc(t / (86400 * 30.436875)); }
    else { unit = 0; v = trunc(t / (86400 * 365.2425)); }
    if (v == 0 && t < 0) v = -0.0;
    if (unit == 6 && v == 0 && _dateTimeStyle == NSRelativeDateTimeFormatterStyleNamed) return @(isim_lang(isim_locale_lang(_locale))->now);
    return [self _phrase:v unit:unit];
}
- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)ref {
    /* calendar-aware for days and larger: compare calendar dates in the time zone */
    NSTimeInterval t = [date timeIntervalSinceDate:ref];
    double a = fabs(t);
    if (a >= 86400 || (_dateTimeStyle == NSRelativeDateTimeFormatterStyleNamed && a >= 3600)) {
        NSTimeZone *tz = _calendar.timeZone ?: NSTimeZone.defaultTimeZone;
        time_t ta = (time_t)floor(date.timeIntervalSince1970) + [tz secondsFromGMTForDate:date];
        time_t tb = (time_t)floor(ref.timeIntervalSince1970) + [tz secondsFromGMTForDate:ref];
        struct tm ma, mb; gmtime_r(&ta, &ma); gmtime_r(&tb, &mb);
        long days = (long)lround((double)((ta - ta % 86400) - (tb - tb % 86400)) / 86400.0);
        long months = (ma.tm_year - mb.tm_year) * 12 + (ma.tm_mon - mb.tm_mon);
        if (t > 0 && ma.tm_mday < mb.tm_mday) months--;
        if (t < 0 && ma.tm_mday > mb.tm_mday) months++;
        long years = months / 12;
        if (labs(years) >= 1) return [self _phrase:(double)years unit:0];
        if (labs(months) >= 1) return [self _phrase:(double)months unit:1];
        if (labs(days) >= 7) return [self _phrase:(double)(days / 7) unit:2];
        if (labs(days) >= 1) return [self _phrase:(double)days unit:3];
    }
    return [self localizedStringFromTimeInterval:t];
}
- (NSString *)localizedStringFromDateComponents:(NSDateComponents *)c {
    NSInteger u = NSDateComponentUndefined;
    if (c.year != u && c.year) return [self _phrase:(double)c.year unit:0];
    if (c.month != u && c.month) return [self _phrase:(double)c.month unit:1];
    if (c.weekOfYear != u && c.weekOfYear) return [self _phrase:(double)c.weekOfYear unit:2];
    if (c.day != u && c.day) return [self _phrase:(double)c.day unit:3];
    if (c.hour != u && c.hour) return [self _phrase:(double)c.hour unit:4];
    if (c.minute != u && c.minute) return [self _phrase:(double)c.minute unit:5];
    if (c.second != u && c.second) return [self _phrase:(double)c.second unit:6];
    if (c.day != u) return [self _phrase:0 unit:3];
    return [self _phrase:0 unit:6];
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSDate class]] ? [self localizedStringForDate:obj relativeToDate:[NSDate date]] : nil; }
@end

/* ================= NSDateComponents (minimal value holder for the formatters) ================= */
@implementation NSDateComponents
- (instancetype)init {
    if ((self = [super init])) { _era = _year = _month = _day = _hour = _minute = _second = _nanosecond = _weekday = _weekdayOrdinal = _quarter = _weekOfMonth = _weekOfYear = _yearForWeekOfYear = NSDateComponentUndefined; }
    return self;
}
- (id)copyWithZone:(NSZone *)z {
    NSDateComponents *c = [NSDateComponents new];
    c.era = _era; c.year = _year; c.month = _month; c.day = _day; c.hour = _hour; c.minute = _minute; c.second = _second; c.nanosecond = _nanosecond;
    c.weekday = _weekday; c.weekdayOrdinal = _weekdayOrdinal; c.quarter = _quarter; c.weekOfMonth = _weekOfMonth; c.weekOfYear = _weekOfYear;
    c.yearForWeekOfYear = _yearForWeekOfYear; c.calendar = _calendar; c.timeZone = _timeZone;
    return c;
}
- (NSInteger)valueForComponent:(NSCalendarUnit)unit {
    switch (unit) {
    case NSCalendarUnitEra: return _era; case NSCalendarUnitYear: return _year; case NSCalendarUnitMonth: return _month;
    case NSCalendarUnitDay: return _day; case NSCalendarUnitHour: return _hour; case NSCalendarUnitMinute: return _minute;
    case NSCalendarUnitSecond: return _second; case NSCalendarUnitWeekday: return _weekday; case NSCalendarUnitWeekOfYear: return _weekOfYear;
    case NSCalendarUnitWeekOfMonth: return _weekOfMonth; case NSCalendarUnitNanosecond: return _nanosecond; case NSCalendarUnitQuarter: return _quarter;
    default: return NSDateComponentUndefined;
    }
}
- (void)setValue:(NSInteger)v forComponent:(NSCalendarUnit)unit {
    switch (unit) {
    case NSCalendarUnitEra: _era = v; break; case NSCalendarUnitYear: _year = v; break; case NSCalendarUnitMonth: _month = v; break;
    case NSCalendarUnitDay: _day = v; break; case NSCalendarUnitHour: _hour = v; break; case NSCalendarUnitMinute: _minute = v; break;
    case NSCalendarUnitSecond: _second = v; break; case NSCalendarUnitWeekday: _weekday = v; break; case NSCalendarUnitWeekOfYear: _weekOfYear = v; break;
    case NSCalendarUnitWeekOfMonth: _weekOfMonth = v; break; case NSCalendarUnitNanosecond: _nanosecond = v; break; case NSCalendarUnitQuarter: _quarter = v; break;
    default: break;
    }
}
@end

/* ================= NSDateComponentsFormatter ================= */
@implementation NSDateComponentsFormatter
- (instancetype)init {
    if ((self = [super init])) { _zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDefault; _calendar = NSCalendar.currentCalendar; }
    return self;
}
static const NSCalendarUnit UNIT_ORDER[7] = { NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitWeekOfMonth, NSCalendarUnitDay, NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond };
static const double UNIT_SECONDS[7] = { 31556952, 2629746, 604800, 86400, 3600, 60, 1 };
- (NSCalendarUnit)_units {
    NSCalendarUnit u = _allowedUnits;
    if (!u) u = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    if (u & NSCalendarUnitWeekOfYear) u |= NSCalendarUnitWeekOfMonth;
    return u;
}
/* values[i] per UNIT_ORDER; returns the formatted string */
- (NSString *)_formatValues:(double *)vals negative:(BOOL)neg {
    NSCalendarUnit units = [self _units];
    NSLocale *locale = _calendar.locale ?: NSLocale.currentLocale;
    NSString *lang = isim_locale_lang(locale);
    int idx[7], n = 0;
    for (int i = 0; i < 7; i++) if (units & UNIT_ORDER[i]) idx[n++] = i;
    if (!n) return nil;
    NSDateComponentsFormatterZeroFormattingBehavior z = _zeroFormattingBehavior;
    BOOL positional = _unitsStyle == NSDateComponentsFormatterUnitsStylePositional;
    if (z == NSDateComponentsFormatterZeroFormattingBehaviorDefault)
        z = positional ? NSDateComponentsFormatterZeroFormattingBehaviorDropLeading : NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    int first = 0, last = n - 1;
    if (z & NSDateComponentsFormatterZeroFormattingBehaviorDropLeading) while (first < last && vals[idx[first]] == 0) first++;
    if (z & NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing) while (last > first && vals[idx[last]] == 0) last--;
    if (positional) {
        /* hours:minutes:seconds; minutes and seconds always shown when allowed, padded to two digits */
        while (first > 0 && idx[first] >= 5 && first > n - 2) first--;   /* keep at least m:ss */
        if (n >= 2 && first == n - 1) first = n - 2;
        NSMutableString *out = [NSMutableString stringWithString:neg ? @"-" : @""];
        for (int k = first; k <= last; k++) {
            int i = idx[k];
            long v = lround(vals[i]);
            if (k > first) [out appendString:i >= 4 ? @":" : @" "];
            if (k == first && !(z & NSDateComponentsFormatterZeroFormattingBehaviorPad)) [out appendFormat:@"%ld", v];
            else [out appendFormat:@"%02ld", v];
        }
        return out;
    }
    int width = _unitsStyle == NSDateComponentsFormatterUnitsStyleFull ? 0 : _unitsStyle == NSDateComponentsFormatterUnitsStyleSpellOut ? 4 :
                _unitsStyle == NSDateComponentsFormatterUnitsStyleShort ? 1 : _unitsStyle == NSDateComponentsFormatterUnitsStyleBrief ? 5 : 2;
    NSMutableArray *parts = [NSMutableArray array];
    NSInteger maxCount = _maximumUnitCount > 0 ? _maximumUnitCount : 99;
    for (int k = first; k <= last && (NSInteger)parts.count < maxCount; k++) {
        int i = idx[k];
        double v = vals[i];
        if (v == 0 && (z & NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle) && k != first && k != last) continue;
        if (v == 0 && z == NSDateComponentsFormatterZeroFormattingBehaviorDropAll && !(k == last && parts.count == 0)) continue;
        int unit = i;
        NSString *p;
        if (width == 5) {                                    /* brief: "1hr 5min" */
            const isim_lang_t *L = isim_lang(lang);
            BOOL one = isim_plural_one(lang, v, 0);
            p = [NSString stringWithFormat:@"%ld%s", lround(v), one ? L->unitShort[unit] : L->unitShortOther[unit]];
        } else p = count_unit(lang, v, unit, width, NO, locale);
        [parts addObject:p];
    }
    if (!parts.count) return nil;
    NSString *sep = width == 2 || width == 5 ? @" " : @(isim_lang(lang)->listSep);
    NSString *s = [parts componentsJoinedByString:sep];
    if (!isim_lang_builtin(lang) && isim_icu_on() && parts.count > 1) {          /* the language's unit list ("1 h, 5 min") */
        s = isim_icu_list_string(isim_locale_ident(locale), parts, 2, width == 0 || width == 4 ? 0 : width == 1 ? 1 : 2) ?: s;
    }
    if (neg) s = [@"-" stringByAppendingString:s];
    if (_includesApproximationPhrase) s = [@"About " stringByAppendingString:s];
    if (_includesTimeRemainingPhrase) s = [s stringByAppendingString:@" remaining"];
    return s;
}
- (NSString *)stringFromTimeInterval:(NSTimeInterval)ti {
    if (!isfinite(ti)) return nil;
    BOOL neg = ti < 0; double rem = fabs(ti);
    NSCalendarUnit units = [self _units];
    double vals[7] = {0};
    int lastAllowed = -1;
    for (int i = 0; i < 7; i++) if (units & UNIT_ORDER[i]) lastAllowed = i;
    for (int i = 0; i < 7; i++) {
        if (!(units & UNIT_ORDER[i])) continue;
        if (i == lastAllowed) { vals[i] = _allowsFractionalUnits ? rem / UNIT_SECONDS[i] : round(rem / UNIT_SECONDS[i] - 1e-9); }
        else { vals[i] = floor(rem / UNIT_SECONDS[i] + 1e-9); rem -= vals[i] * UNIT_SECONDS[i]; }
    }
    return [self _formatValues:vals negative:neg];
}
- (NSString *)stringFromDateComponents:(NSDateComponents *)c {
    double vals[7] = {0};
    NSInteger u = NSDateComponentUndefined;
    NSInteger src[7] = { c.year, c.month, c.weekOfMonth != u ? c.weekOfMonth : c.weekOfYear, c.day, c.hour, c.minute, c.second };
    NSCalendarUnit units = [self _units];
    double carry = 0;
    for (int i = 0; i < 7; i++) {
        double v = src[i] == u ? 0 : (double)src[i];
        if (!(units & UNIT_ORDER[i])) { carry += v * UNIT_SECONDS[i]; continue; }
        v += floor(carry / UNIT_SECONDS[i]); carry = fmod(carry, UNIT_SECONDS[i]);
        vals[i] = v;
    }
    return [self _formatValues:vals negative:NO];
}
- (NSString *)stringFromDate:(NSDate *)a toDate:(NSDate *)b { return [self stringFromTimeInterval:[b timeIntervalSinceDate:a]]; }
- (NSString *)stringForObjectValue:(id)obj {
    if ([obj isKindOfClass:[NSNumber class]]) return [self stringFromTimeInterval:[obj doubleValue]];
    if ([obj isKindOfClass:[NSDateComponents class]]) return [self stringFromDateComponents:obj];
    return nil;
}
+ (NSString *)localizedStringFromDateComponents:(NSDateComponents *)c unitsStyle:(NSDateComponentsFormatterUnitsStyle)style {
    NSDateComponentsFormatter *f = [NSDateComponentsFormatter new]; f.unitsStyle = style; return [f stringFromDateComponents:c];
}
@end

/* ================= NSDateIntervalFormatter ================= */
@implementation NSDateIntervalFormatter
/* null_resettable: nil restores the default */
@synthesize locale = _locale, timeZone = _timeZone, calendar = _calendar, dateTemplate = _dateTemplate;
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = [l copy] ?: NSLocale.currentLocale; }
- (NSTimeZone *)timeZone { return _timeZone; }
- (void)setTimeZone:(NSTimeZone *)tz { _timeZone = [tz copy] ?: NSTimeZone.defaultTimeZone; }
- (NSCalendar *)calendar { return _calendar; }
- (void)setCalendar:(NSCalendar *)c { _calendar = [c copy] ?: NSCalendar.currentCalendar; }
- (NSString *)dateTemplate { return _dateTemplate ?: @""; }
- (void)setDateTemplate:(NSString *)t { _dateTemplate = [t copy]; }
- (instancetype)init {
    if ((self = [super init])) { _locale = NSLocale.currentLocale; _timeZone = NSTimeZone.defaultTimeZone; _calendar = NSCalendar.currentCalendar; _dateStyle = NSDateIntervalFormatterShortStyle; _timeStyle = NSDateIntervalFormatterShortStyle; }
    return self;
}
/* the skeleton for ICU's interval formats ("yMMMd", "jm") */
- (NSString *)_skeleton {
    if (_dateTemplate.length) return _dateTemplate;
    NSString *d = @[@"", @"yMd", @"yMMMd", @"yMMMMd", @"yMMMMEEEEd"][MIN((NSUInteger)_dateStyle, (NSUInteger)4)];
    NSString *t = @[@"", @"jm", @"jms", @"jmsz", @"jmszzzz"][MIN((NSUInteger)_timeStyle, (NSUInteger)4)];
    return [d stringByAppendingString:t];
}
- (NSString *)stringFromDate:(NSDate *)from toDate:(NSDate *)to {
    NSString *icu = isim_icu_date_locale(_locale, _calendar.calendarIdentifier);
    NSString *sk = [self _skeleton];
    if (icu && sk.length) {                                    /* a locale or calendar the built-in tables lack: ICU */
        NSString *s = isim_icu_interval_string(icu, _timeZone.name, sk, from, to);
        if (s) return s;
    }
    NSDateFormatter *df = [NSDateFormatter new]; df.locale = _locale; df.timeZone = _timeZone;
    NSDateFormatter *tf = [NSDateFormatter new]; tf.locale = _locale; tf.timeZone = _timeZone;
    NSString *datePat, *timePat;
    if (_dateTemplate.length) {
        NSString *full = isim_date_pattern(_dateTemplate, _locale);
        datePat = full; timePat = nil;
        /* split template into date and time parts for same-day collapsing */
        NSMutableString *dt = [NSMutableString string], *tt = [NSMutableString string];
        for (NSUInteger i = 0; i < _dateTemplate.length; i++) {
            unichar c = [_dateTemplate characterAtIndex:i];
            [(strchr("hHjJkKmsSaz", (char)c) ? tt : dt) appendFormat:@"%C", c];
        }
        if (dt.length && tt.length) { datePat = isim_date_pattern(dt, _locale); timePat = isim_date_pattern(tt, _locale); }
        else if (tt.length) { datePat = nil; timePat = full; }
    } else {
        datePat = _dateStyle ? isim_style_pattern((NSInteger)_dateStyle, 0, _locale) : nil;
        timePat = _timeStyle ? isim_style_pattern(0, (NSInteger)_timeStyle, _locale) : nil;
    }
    NSString *dash = @" – ";
    df.dateFormat = datePat ?: @""; tf.dateFormat = timePat ?: @"";
    NSString *d1 = datePat ? [df stringFromDate:from] : nil, *d2 = datePat ? [df stringFromDate:to] : nil;
    NSString *t1 = timePat ? [tf stringFromDate:from] : nil, *t2 = timePat ? [tf stringFromDate:to] : nil;
    NSString *sep = @(isim_lang(isim_locale_lang(_locale))->dateTimeSep);
    if (d1 && t1) {
        if ([d1 isEqualToString:d2]) {
            if ([t1 isEqualToString:t2]) return [NSString stringWithFormat:@"%@%@%@", d1, sep, t1];
            /* "3:00 – 4:00 PM" when both share the day period */
            NSString *am = tf.AMSymbol, *pm = tf.PMSymbol;
            for (NSString *ap in @[am, pm]) {
                NSString *suffix = [@" " stringByAppendingString:ap];
                if ([t1 hasSuffix:suffix] && [t2 hasSuffix:suffix]) { t1 = [t1 substringToIndex:t1.length - suffix.length]; break; }
            }
            return [NSString stringWithFormat:@"%@%@%@%@%@", d1, sep, t1, dash, t2];
        }
        return [NSString stringWithFormat:@"%@%@%@%@%@%@%@", d1, sep, t1, dash, d2, sep, t2];
    }
    if (d1) return [d1 isEqualToString:d2] ? d1 : [NSString stringWithFormat:@"%@%@%@", d1, dash, d2];
    if (t1) return [t1 isEqualToString:t2] ? t1 : [NSString stringWithFormat:@"%@%@%@", t1, dash, t2];
    return @"";
}
@end

/* ================= NSByteCountFormatter ================= */
@implementation NSByteCountFormatter
- (instancetype)init {
    if ((self = [super init])) { _allowedUnits = NSByteCountFormatterUseDefault; _countStyle = NSByteCountFormatterCountStyleFile; _includesUnit = YES; _includesCount = YES; _adaptive = YES; _allowsNonnumericFormatting = YES; }
    return self;
}
+ (NSString *)stringFromByteCount:(long long)count countStyle:(NSByteCountFormatterCountStyle)style {
    NSByteCountFormatter *f = [NSByteCountFormatter new]; f.countStyle = style; return [f stringFromByteCount:count];
}
- (NSString *)stringFromByteCount:(long long)count { return [self _isim_string:count locale:NSLocale.currentLocale lowercaseK:NO]; }
- (NSString *)_isim_string:(long long)count locale:(NSLocale *)locale lowercaseK:(BOOL)lowK {
    NSString *lang = isim_locale_lang(locale);
    const isim_lang_t *L = isim_lang(lang);
    BOOL binary = _countStyle == NSByteCountFormatterCountStyleMemory || _countStyle == NSByteCountFormatterCountStyleBinary;
    double base = binary ? 1024 : 1000;
    NSByteCountFormatterUnits allowed = _allowedUnits == NSByteCountFormatterUseDefault ? NSByteCountFormatterUseAll : _allowedUnits;
    /* the largest allowed unit the value reaches; the smallest allowed one for smaller values */
    int unit = -1, smallest = -1;
    double a = fabs((double)count);
    for (int u = 0; u <= 5; u++) {
        if (!(allowed & (1 << u))) continue;
        if (smallest < 0) smallest = u;
        if (a >= pow(base, u)) unit = u;
    }
    if (unit < 0) unit = smallest < 0 ? 0 : smallest;
    if (count == 0 && _allowsNonnumericFormatting && _includesCount && _includesUnit && !(allowed == NSByteCountFormatterUseBytes)) {
        int zu = (allowed & NSByteCountFormatterUseKB) ? 1 : unit;
        NSString *un = zu == 0 ? @(L->byteUnits[0]) : @(L->byteUnits[zu]);
        if (zu == 1 && !lowK && ([un isEqualToString:@"kB"])) un = @"KB";
        return [NSString stringWithFormat:@"%s %@", L->zeroBytes, un];
    }
    double v = (double)count / pow(base, unit);
    NSNumberFormatter *nf = [NSNumberFormatter new]; nf.locale = locale; nf.numberStyle = NSNumberFormatterDecimalStyle;
    int digits = !_adaptive ? (unit == 0 ? 0 : 2) : unit <= 1 ? 0 : unit == 2 ? 1 : 2;
    nf.maximumFractionDigits = (NSUInteger)digits;
    if (_zeroPadsFractionDigits) nf.minimumFractionDigits = (NSUInteger)digits;
    nf.roundingMode = NSNumberFormatterRoundHalfEven;
    NSString *num = [nf stringFromNumber:@(v)];
    NSString *un;
    if (unit == 0) {
        BOOL one = llabs(count) == 1;
        un = [lang isEqualToString:@"en"] ? (one ? @"byte" : @"bytes") : @(L->byteUnits[0]);
        if ([lang isEqualToString:@"fr"]) un = one || count == 0 ? @"octet" : @"octets";
    } else {
        un = @(L->byteUnits[unit]);
        if (unit == 1 && !lowK && [un isEqualToString:@"kB"]) un = @"KB";
    }
    if (!_includesUnit) return num;
    if (!_includesCount) return un;
    NSString *s = [NSString stringWithFormat:@"%@ %@", num, un];
    if (_includesActualByteCount && unit > 0) {
        NSNumberFormatter *g = [NSNumberFormatter new]; g.locale = locale; g.numberStyle = NSNumberFormatterDecimalStyle;
        s = [s stringByAppendingFormat:@" (%@ %@)", [g stringFromNumber:@(count)], [lang isEqualToString:@"en"] ? @"bytes" : @(L->byteUnits[0])];
    }
    return s;
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSNumber class]] ? [self stringFromByteCount:[obj longLongValue]] : nil; }
@end

/* ================= NSListFormatter ================= */
NSString *isim_join_list(NSArray<NSString *> *items, NSLocale *locale, BOOL orList, int width) {
    NSUInteger n = items.count;
    if (!n) return @"";
    if (n == 1) return items[0];
    NSString *lang = isim_locale_lang(locale), *ident = isim_locale_ident(locale);
    if (!isim_lang_builtin(lang) && isim_icu_on()) {           /* ICU's list patterns (CLDR) */
        NSString *s = isim_icu_list_string(ident, items, orList ? 1 : 0, width);
        if (s) return s;
    }
    const isim_lang_t *L = isim_lang(lang);
    NSString *sep = @(L->listSep);
    if ([lang isEqualToString:@"ja"]) {
        if (!orList) return [items componentsJoinedByString:@"、"];
        return [NSString stringWithFormat:@"%@、または%@", [[items subarrayWithRange:NSMakeRange(0, n - 1)] componentsJoinedByString:@"、"], items.lastObject];
    }
    NSString *conj = @(orList ? L->listOr : L->listAnd);
    if (width == 2 && !orList) {                           /* narrow: "a, b, c" */
        return [items componentsJoinedByString:sep];
    }
    if (width == 1 && !orList && [lang isEqualToString:@"en"]) conj = @"&";
    if ([lang isEqualToString:@"es"] && !orList) { NSString *last = items.lastObject.lowercaseString; if ([last hasPrefix:@"i"] || ([last hasPrefix:@"hi"] && ![last hasPrefix:@"hie"])) conj = @"e"; }
    if ([lang isEqualToString:@"es"] && orList) { NSString *last = items.lastObject.lowercaseString; if ([last hasPrefix:@"o"] || [last hasPrefix:@"ho"]) conj = @"u"; }
    if (n == 2) return [NSString stringWithFormat:@"%@ %@ %@", items[0], conj, items[1]];
    BOOL serial = [lang isEqualToString:@"en"] && ([ident isEqualToString:@"en_US"] || [ident isEqualToString:@"en"] || [ident hasPrefix:@"en_US"] || [ident isEqualToString:@"en_CA"] || [ident isEqualToString:@"en_PH"]);
    NSString *head = [[items subarrayWithRange:NSMakeRange(0, n - 1)] componentsJoinedByString:sep];
    return [NSString stringWithFormat:@"%@%@ %@ %@", head, serial ? @"," : @"", conj, items.lastObject];
}
@implementation NSListFormatter
@synthesize locale = _locale;
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = [l copy] ?: NSLocale.currentLocale; }    /* null_resettable */
- (instancetype)init { if ((self = [super init])) _locale = NSLocale.currentLocale; return self; }
+ (NSString *)localizedStringByJoiningStrings:(NSArray<NSString *> *)strings { return isim_join_list(strings, NSLocale.currentLocale, NO, 0); }
+ (NSString *)_isim_joinStrings:(NSArray<NSString *> *)strings locale:(NSLocale *)locale orList:(BOOL)orList width:(NSInteger)width {
    return isim_join_list(strings, locale, orList, (int)width);
}
- (NSString *)stringFromItems:(NSArray *)items {
    NSMutableArray *strs = [NSMutableArray array];
    for (id o in items) {
        NSString *s = _itemFormatter ? [_itemFormatter stringForObjectValue:o] : [o description];
        [strs addObject:s ?: @""];
    }
    return isim_join_list(strs, _locale, NO, 0);
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSArray class]] ? [self stringFromItems:obj] : nil; }
@end

/* ================= NSPersonNameComponents(+Formatter) ================= */
@implementation NSPersonNameComponents
- (id)copyWithZone:(NSZone *)z {
    NSPersonNameComponents *c = [NSPersonNameComponents new];
    c.namePrefix = _namePrefix; c.givenName = _givenName; c.middleName = _middleName; c.familyName = _familyName; c.nameSuffix = _nameSuffix;
    c.nickname = _nickname; c.phoneticRepresentation = _phoneticRepresentation;
    return c;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSPersonNameComponents class]]) return NO;
    NSPersonNameComponents *b = o;
    #define EQ(a, b) ((a) == (b) || [(a) isEqual:(b)])
    return EQ(_namePrefix, b.namePrefix) && EQ(_givenName, b.givenName) && EQ(_middleName, b.middleName) && EQ(_familyName, b.familyName) && EQ(_nameSuffix, b.nameSuffix) && EQ(_nickname, b.nickname);
    #undef EQ
}
- (NSUInteger)hash { return _givenName.hash ^ _familyName.hash; }
@end
@implementation NSPersonNameComponentsFormatter
@synthesize locale = _locale;
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = [l copy] ?: NSLocale.currentLocale; }    /* null_resettable */
- (instancetype)init { if ((self = [super init])) { _style = NSPersonNameComponentsFormatterStyleDefault; _locale = NSLocale.currentLocale; } return self; }
+ (NSString *)localizedStringFromPersonNameComponents:(NSPersonNameComponents *)c style:(NSPersonNameComponentsFormatterStyle)style options:(NSPersonNameComponentsFormatterOptions)opts {
    NSPersonNameComponentsFormatter *f = [NSPersonNameComponentsFormatter new]; f.style = style; return [f stringFromPersonNameComponents:c];
}
static BOOL is_cjk(NSString *s) { for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (c >= 0x3040 && c <= 0x9FFF) return YES; } return NO; }
- (NSString *)stringFromPersonNameComponents:(NSPersonNameComponents *)c {
    NSPersonNameComponents *n = _phonetic && c.phoneticRepresentation ? c.phoneticRepresentation : c;
    BOOL familyFirst = is_cjk([NSString stringWithFormat:@"%@%@", n.givenName ?: @"", n.familyName ?: @""]);
    NSMutableArray *parts = [NSMutableArray array];
    void (^add)(NSString *) = ^(NSString *s) { if (s.length) [parts addObject:s]; };
    switch (_style) {
    case NSPersonNameComponentsFormatterStyleShort: add(n.nickname.length ? n.nickname : n.givenName ?: n.familyName); break;
    case NSPersonNameComponentsFormatterStyleAbbreviated: {
        NSString *g = n.givenName.length ? [n.givenName substringToIndex:1] : @"", *f = n.familyName.length ? [n.familyName substringToIndex:1] : @"";
        return familyFirst ? [f stringByAppendingString:g] : [g stringByAppendingString:f];
    }
    case NSPersonNameComponentsFormatterStyleLong:
        add(n.namePrefix);
        if (familyFirst) { add(n.familyName); add(n.givenName); } else { add(n.givenName); add(n.middleName); add(n.familyName); }
        add(n.nameSuffix);
        break;
    default:
        if (familyFirst) { add(n.familyName); add(n.givenName); } else { add(n.givenName); add(n.familyName); }
        break;
    }
    return [parts componentsJoinedByString:familyFirst ? @"" : @" "];
}
- (NSPersonNameComponents *)personNameComponentsFromString:(NSString *)string {
    NSArray *words = [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
    NSMutableArray *w = [NSMutableArray array]; for (NSString *s in words) if (s.length) [w addObject:s];
    if (!w.count) return nil;
    NSPersonNameComponents *c = [NSPersonNameComponents new];
    NSSet *prefixes = [NSSet setWithArray:@[@"Mr.", @"Mrs.", @"Ms.", @"Dr.", @"Prof.", @"Sr.", @"Sra."]];
    if (w.count > 1 && [prefixes containsObject:w[0]]) { c.namePrefix = w[0]; [w removeObjectAtIndex:0]; }
    c.givenName = w[0];
    if (w.count >= 2) c.familyName = w.lastObject;
    if (w.count >= 3) c.middleName = [[w subarrayWithRange:NSMakeRange(1, w.count - 2)] componentsJoinedByString:@" "];
    return c;
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSPersonNameComponents class]] ? [self stringFromPersonNameComponents:obj] : nil; }
@end
