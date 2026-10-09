/* isim Foundation (ARC): NSDecimal arithmetic (the C API), NSDecimalNumber and NSDecimalNumberHandler.
 * Values are exact: up to 38 significant digits times 10^exponent (-128...127), worked on as decimal digit strings and
 * rounded once per operation to 38 digits in the requested rounding mode (plain: half away from zero, down / up:
 * toward -infinity / +infinity, bankers: half to even), like Apple's NSDecimal and Swift's Decimal. */
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdlib.h>
#include "isim_foundation.h"

NSExceptionName const NSDecimalNumberExactnessException = @"NSDecimalNumberExactnessException";
NSExceptionName const NSDecimalNumberOverflowException = @"NSDecimalNumberOverflowException";
NSExceptionName const NSDecimalNumberUnderflowException = @"NSDecimalNumberUnderflowException";
NSExceptionName const NSDecimalNumberDivideByZeroException = @"NSDecimalNumberDivideByZeroException";

/* ---------------- digit strings ---------------- */
#define DMAX 200            /* working digits (products and quotients are rounded down to 38) */
typedef struct { int nan, neg, exp, nd; unsigned char d[DMAX]; } dec;      /* value = (-1)^neg * d[0..nd) * 10^exp, d most significant first */

static void dec_trim(dec *x) {                     /* no leading zeros; zero is nd == 0 */
    int lead = 0;
    while (lead < x->nd && x->d[lead] == 0) lead++;
    if (lead) { memmove(x->d, x->d + lead, x->nd - lead); x->nd -= lead; }
    if (!x->nd) { x->neg = 0; x->exp = 0; }
}
static void dec_strip(dec *x) { while (x->nd && x->d[x->nd - 1] == 0) { x->nd--; x->exp++; } if (!x->nd) { x->neg = 0; x->exp = 0; } }

static void from_ns(dec *x, const NSDecimal *n) {
    memset(x, 0, sizeof *x);
    if (n->_length == 0) { x->nan = n->_isNegative; return; }
    unsigned short w[8]; int len = n->_length;
    memcpy(w, n->_mantissa, sizeof w);
    unsigned char rev[40]; int k = 0;
    for (;;) {                                     /* repeated division of the 128-bit mantissa by 10 */
        int nz = 0; unsigned rem = 0;
        for (int i = len - 1; i >= 0; i--) { unsigned cur = (rem << 16) | w[i]; w[i] = (unsigned short)(cur / 10); rem = cur % 10; if (w[i]) nz = 1; }
        rev[k++] = (unsigned char)rem;
        if (!nz) break;
    }
    for (int i = 0; i < k; i++) x->d[i] = rev[k - 1 - i];
    x->nd = k; x->neg = n->_isNegative; x->exp = n->_exponent;
    dec_trim(x);
}
/* rounds away the last `drop` digits in the mode; returns 1 when a nonzero digit was dropped */
static int dec_drop(dec *x, int drop, NSRoundingMode mode) {
    if (drop <= 0) return 0;
    if (drop > x->nd) { unsigned char z[DMAX] = {0}; int pad = drop - x->nd; if (x->nd + pad > DMAX) pad = DMAX - x->nd; memcpy(z + pad, x->d, x->nd); memcpy(x->d, z, x->nd + pad); x->nd += pad; }
    int keep = x->nd - drop;
    int first = x->d[keep], rest = 0;
    for (int i = keep + 1; i < x->nd; i++) if (x->d[i]) { rest = 1; break; }
    int inexact = first || rest, up;
    switch (mode) {
    case NSRoundDown: up = x->neg && inexact; break;
    case NSRoundUp: up = !x->neg && inexact; break;
    case NSRoundBankers: up = first > 5 || (first == 5 && (rest || (keep > 0 && (x->d[keep - 1] & 1)))); break;
    default: up = first >= 5; break;
    }
    x->nd = keep; x->exp += drop;
    if (up) {
        int i = keep - 1;
        while (i >= 0 && x->d[i] == 9) x->d[i--] = 0;
        if (i >= 0) x->d[i]++;
        else { memmove(x->d + 1, x->d, x->nd); x->d[0] = 1; x->nd++; }
    }
    if (!x->nd && !up) { x->neg = 0; x->exp = 0; }
    return inexact;
}
/* back to an NSDecimal: 38 digits, exponent -128...127 */
static NSCalculationError to_ns(dec *x, NSDecimal *out, NSRoundingMode mode) {
    NSCalculationError err = NSCalculationNoError;
    memset(out, 0, sizeof *out);
    if (x->nan) { out->_isNegative = 1; return NSCalculationNoError; }
    dec_trim(x);
    if (x->nd > 38) { if (dec_drop(x, x->nd - 38, mode)) err = NSCalculationLossOfPrecision; if (x->nd > 38) dec_drop(x, 1, mode); }
    dec_strip(x);
    while (x->exp > 127 && x->nd && x->nd < 38) { x->d[x->nd++] = 0; x->exp--; }
    if (x->exp > 127 && x->nd) { out->_isNegative = 1; return NSCalculationOverflow; }   /* NaN */
    if (x->exp < -128 && x->nd) {
        if (dec_drop(x, -128 - x->exp, mode)) err = NSCalculationLossOfPrecision;
        dec_trim(x);
        if (!x->nd) return NSCalculationUnderflow;
        dec_strip(x);
    }
    if (!x->nd) { out->_isCompact = 1; return err; }
    unsigned short w[8] = {0};
    for (int i = 0; i < x->nd; i++) {               /* w = w * 10 + digit */
        unsigned carry = x->d[i];
        for (int j = 0; j < 8; j++) { unsigned cur = w[j] * 10u + carry; w[j] = (unsigned short)cur; carry = cur >> 16; }
    }
    int len = 8; while (len > 0 && !w[len - 1]) len--;
    memcpy(out->_mantissa, w, sizeof w);
    out->_length = len; out->_exponent = x->exp; out->_isNegative = x->neg; out->_isCompact = 1;
    return err;
}
static int cmp_mag(const dec *a, const dec *b) {   /* same exponent */
    if (a->nd != b->nd) return a->nd < b->nd ? -1 : 1;
    int c = memcmp(a->d, b->d, a->nd);
    return c < 0 ? -1 : c > 0 ? 1 : 0;
}
/* gives both the smaller exponent (appending zeros), within DMAX digits */
static void align(dec *a, dec *b) {
    dec *hi = a->exp > b->exp ? a : b, *lo = hi == a ? b : a;
    while (hi->exp > lo->exp && hi->nd && hi->nd < DMAX) { hi->d[hi->nd++] = 0; hi->exp--; }
    if (!hi->nd) hi->exp = lo->exp;
    while (hi->exp > lo->exp) { if (!lo->nd) { lo->exp = hi->exp; break; } dec_drop(lo, 1, NSRoundPlain); }
}
static void add_mag(dec *r, const dec *a, const dec *b) {   /* aligned */
    int n = a->nd > b->nd ? a->nd : b->nd;
    unsigned char t[DMAX + 1]; int carry = 0;
    for (int i = 0; i < n; i++) {
        int da = i < a->nd ? a->d[a->nd - 1 - i] : 0, db = i < b->nd ? b->d[b->nd - 1 - i] : 0, s = da + db + carry;
        t[i] = s % 10; carry = s / 10;
    }
    if (carry) t[n++] = 1;
    if (n > DMAX) n = DMAX;
    r->nd = n; for (int i = 0; i < n; i++) r->d[i] = t[n - 1 - i];
}
static void sub_mag(dec *r, const dec *a, const dec *b) {   /* aligned, |a| >= |b| */
    int borrow = 0, n = a->nd; unsigned char t[DMAX];
    for (int i = 0; i < n; i++) {
        int da = a->d[a->nd - 1 - i], db = i < b->nd ? b->d[b->nd - 1 - i] : 0, s = da - db - borrow;
        borrow = s < 0; t[i] = (unsigned char)(s + (borrow ? 10 : 0));
    }
    r->nd = n; for (int i = 0; i < n; i++) r->d[i] = t[n - 1 - i];
}
static void dec_add(dec *r, dec a, dec b, int negate_b) {
    if (negate_b) b.neg = !b.neg;
    memset(r, 0, sizeof *r);
    if (a.nan || b.nan) { r->nan = 1; return; }
    if (!a.nd) { *r = b; if (!b.nd) r->neg = 0; return; }
    if (!b.nd) { *r = a; return; }
    align(&a, &b);
    r->exp = a.exp;
    if (a.neg == b.neg) { add_mag(r, &a, &b); r->neg = a.neg; }
    else if (cmp_mag(&a, &b) >= 0) { sub_mag(r, &a, &b); r->neg = a.neg; }
    else { sub_mag(r, &b, &a); r->neg = b.neg; }
    dec_trim(r);
}
static void dec_mul(dec *r, const dec *a, const dec *b) {
    memset(r, 0, sizeof *r);
    if (a->nan || b->nan) { r->nan = 1; return; }
    if (!a->nd || !b->nd) return;
    int n = a->nd + b->nd; unsigned t[2 * 40 + 2] = {0};
    for (int i = a->nd - 1; i >= 0; i--)
        for (int j = b->nd - 1; j >= 0; j--) t[i + j + 1] += a->d[i] * b->d[j];
    for (int k = n - 1; k > 0; k--) { t[k - 1] += t[k] / 10; t[k] %= 10; }
    r->nd = n; for (int k = 0; k < n; k++) r->d[k] = (unsigned char)t[k];
    r->neg = a->neg != b->neg; r->exp = a->exp + b->exp;
    dec_trim(r);
}
/* integer magnitude compare (trimmed digit strings) */
static int cmp_int(const unsigned char *a, int na, const unsigned char *b, int nb) {
    if (na != nb) return na < nb ? -1 : 1;
    int c = memcmp(a, b, na);
    return c < 0 ? -1 : c > 0 ? 1 : 0;
}
/* long division: A * 10^k / B with k chosen for at least 41 quotient digits; a nonzero remainder leaves a sticky 1
 * one place below, so the rounding to 38 digits sees the value is inexact. Returns 1 for division by zero (NaN). */
static int dec_div(dec *r, const dec *a, const dec *b) {
    memset(r, 0, sizeof *r);
    if (a->nan || b->nan) { r->nan = 1; return 0; }
    if (!b->nd) { r->nan = 1; return 1; }
    if (!a->nd) return 0;
    int k = 41 + b->nd - a->nd + 1; if (k < 0) k = 0;
    unsigned char rem[DMAX]; int nr = 0;
    unsigned char q[DMAX]; int nq = 0;
    for (int i = 0; i < a->nd + k; i++) {
        int digit = i < a->nd ? a->d[i] : 0;
        if (nr || digit) { if (nr < DMAX) rem[nr++] = (unsigned char)digit; }
        int qd = 0;
        while (cmp_int(rem, nr, b->d, b->nd) >= 0) {     /* rem -= B */
            int borrow = 0;
            for (int j = 0; j < nr; j++) {
                int dr = rem[nr - 1 - j], db = j < b->nd ? b->d[b->nd - 1 - j] : 0, s2 = dr - db - borrow;
                borrow = s2 < 0; rem[nr - 1 - j] = (unsigned char)(s2 + (borrow ? 10 : 0));
            }
            int lead = 0; while (lead < nr && !rem[lead]) lead++;
            memmove(rem, rem + lead, nr - lead); nr -= lead;
            qd++;
        }
        if (nq < DMAX - 1) q[nq++] = (unsigned char)qd;
    }
    memcpy(r->d, q, nq); r->nd = nq;
    r->exp = a->exp - b->exp - k;
    if (nr && r->nd < DMAX) { r->d[r->nd++] = 1; r->exp--; }
    r->neg = a->neg != b->neg;
    dec_trim(r);
    return 0;
}

/* ---------------- the C API ---------------- */
BOOL NSDecimalIsNotANumber(const NSDecimal *n) { return n->_length == 0 && n->_isNegative; }
void NSDecimalCopy(NSDecimal *dst, const NSDecimal *src) { *dst = *src; }
void NSDecimalCompact(NSDecimal *n) { dec x; from_ns(&x, n); to_ns(&x, n, NSRoundPlain); }
NSComparisonResult NSDecimalCompare(const NSDecimal *l, const NSDecimal *r) {
    dec a, b, d; from_ns(&a, l); from_ns(&b, r);
    if (a.nan || b.nan) return a.nan == b.nan ? NSOrderedSame : a.nan ? NSOrderedAscending : NSOrderedDescending;
    dec_add(&d, a, b, 1);
    return !d.nd ? NSOrderedSame : d.neg ? NSOrderedAscending : NSOrderedDescending;
}
void NSDecimalRound(NSDecimal *result, const NSDecimal *number, NSInteger scale, NSRoundingMode mode) {
    dec x; from_ns(&x, number);
    if (!x.nan && scale != NSDecimalNoScale && x.nd && -x.exp > scale) dec_drop(&x, (int)(-x.exp - scale), mode);
    to_ns(&x, result, mode);
}
NSCalculationError NSDecimalNormalize(NSDecimal *n1, NSDecimal *n2, NSRoundingMode mode) {
    dec a, b; from_ns(&a, n1); from_ns(&b, n2);
    if (a.nan || b.nan) return NSCalculationNoError;
    align(&a, &b);
    /* written back without stripping trailing zeros, so both keep the common exponent */
    NSDecimal *outs[2] = { n1, n2 }; dec *ds[2] = { &a, &b }; NSCalculationError err = NSCalculationNoError;
    for (int k = 0; k < 2; k++) {
        dec *x = ds[k]; NSDecimal *o = outs[k];
        if (x->nd > 38) { dec_drop(x, x->nd - 38, mode); err = NSCalculationLossOfPrecision; }
        unsigned short w[8] = {0};
        for (int i = 0; i < x->nd; i++) { unsigned carry = x->d[i]; for (int j = 0; j < 8; j++) { unsigned cur = w[j] * 10u + carry; w[j] = (unsigned short)cur; carry = cur >> 16; } }
        int len = 8; while (len > 0 && !w[len - 1]) len--;
        memset(o, 0, sizeof *o); memcpy(o->_mantissa, w, sizeof w);
        o->_length = len; o->_exponent = len ? x->exp : 0; o->_isNegative = len && x->neg; o->_isCompact = 0;
    }
    return err;
}
NSCalculationError NSDecimalAdd(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode) {
    dec a, b, x; from_ns(&a, l); from_ns(&b, r); dec_add(&x, a, b, 0); return to_ns(&x, result, mode);
}
NSCalculationError NSDecimalSubtract(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode) {
    dec a, b, x; from_ns(&a, l); from_ns(&b, r); dec_add(&x, a, b, 1); return to_ns(&x, result, mode);
}
NSCalculationError NSDecimalMultiply(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode) {
    dec a, b, x; from_ns(&a, l); from_ns(&b, r); dec_mul(&x, &a, &b); return to_ns(&x, result, mode);
}
NSCalculationError NSDecimalDivide(NSDecimal *result, const NSDecimal *l, const NSDecimal *r, NSRoundingMode mode) {
    dec a, b, x; from_ns(&a, l); from_ns(&b, r);
    if (dec_div(&x, &a, &b)) { to_ns(&x, result, mode); return NSCalculationDivideByZero; }
    return to_ns(&x, result, mode);
}
NSCalculationError NSDecimalPower(NSDecimal *result, const NSDecimal *number, NSUInteger power, NSRoundingMode mode) {
    NSDecimal acc = {0}, base = *number;
    acc._length = 1; acc._mantissa[0] = 1; acc._isCompact = 1;
    NSCalculationError err = NSCalculationNoError, e;
    while (power) {
        if (power & 1) { if ((e = NSDecimalMultiply(&acc, &acc, &base, mode)) > err) err = e; }
        power >>= 1;
        if (power && (e = NSDecimalMultiply(&base, &base, &base, mode)) > err) err = e;
    }
    *result = acc;
    return err;
}
NSCalculationError NSDecimalMultiplyByPowerOf10(NSDecimal *result, const NSDecimal *number, short power, NSRoundingMode mode) {
    dec x; from_ns(&x, number);
    if (!x.nan && x.nd) x.exp += power;
    return to_ns(&x, result, mode);
}
/* "123.45", "-0.001", "1200", "NaN"; the decimal separator from a locale or an NSLocaleDecimalSeparator dictionary */
static NSString *decimal_separator(id locale) {
    if ([locale isKindOfClass:[NSLocale class]]) return [locale objectForKey:NSLocaleDecimalSeparator] ?: @".";
    if ([locale isKindOfClass:[NSDictionary class]]) return locale[NSLocaleDecimalSeparator] ?: locale[@"NSDecimalSeparator"] ?: @".";
    return @".";
}
NSString *NSDecimalString(const NSDecimal *n, id locale) {
    dec x; from_ns(&x, n);
    if (x.nan) return @"NaN";
    if (!x.nd) return @"0";
    NSMutableString *s = [NSMutableString string];
    if (x.neg) [s appendString:@"-"];
    NSString *sep = decimal_separator(locale);
    if (x.exp >= 0) {
        for (int i = 0; i < x.nd; i++) [s appendFormat:@"%d", x.d[i]];
        for (int i = 0; i < x.exp; i++) [s appendString:@"0"];
    } else {
        int point = x.nd + x.exp;                  /* digits before the separator */
        if (point <= 0) {
            [s appendString:@"0"]; [s appendString:sep];
            for (int i = 0; i < -point; i++) [s appendString:@"0"];
            for (int i = 0; i < x.nd; i++) [s appendFormat:@"%d", x.d[i]];
        } else {
            for (int i = 0; i < x.nd; i++) { if (i == point) [s appendString:sep]; [s appendFormat:@"%d", x.d[i]]; }
        }
    }
    return s;
}
/* a leading number ("12.5", "-3e4", " 7.25 kg"); NO when there is none */
static BOOL parse_decimal(NSString *str, id locale, NSDecimal *out) {
    NSString *sep = decimal_separator(locale);
    NSUInteger n = str.length, i = 0;
    while (i < n && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[str characterAtIndex:i]]) i++;
    dec x; memset(&x, 0, sizeof x);
    if (i < n && ([str characterAtIndex:i] == '-' || [str characterAtIndex:i] == '+')) { x.neg = [str characterAtIndex:i] == '-'; i++; }
    int any = 0, frac = 0, after = 0;
    for (; i < n; i++) {
        unichar c = [str characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            any = 1;
            if (x.nd < DMAX - 1) { x.d[x.nd++] = (unsigned char)(c - '0'); if (frac) after++; }
            else if (!frac) x.exp++;
        } else if (!frac && [[str substringWithRange:NSMakeRange(i, 1)] isEqualToString:sep]) frac = 1;
        else break;
    }
    if (!any) return NO;
    x.exp -= after;
    if (i < n && ([str characterAtIndex:i] == 'e' || [str characterAtIndex:i] == 'E')) {
        NSUInteger j = i + 1; int eneg = 0, e = 0, digits = 0;
        if (j < n && ([str characterAtIndex:j] == '-' || [str characterAtIndex:j] == '+')) { eneg = [str characterAtIndex:j] == '-'; j++; }
        while (j < n && [str characterAtIndex:j] >= '0' && [str characterAtIndex:j] <= '9') { if (e < 10000) e = e * 10 + ([str characterAtIndex:j] - '0'); j++; digits++; }
        if (digits) x.exp += eneg ? -e : e;
    }
    to_ns(&x, out, NSRoundPlain);
    return YES;
}

/* ---------------- NSDecimalNumber ---------------- */
@interface NSNumber (IsimNumberValue)
- (void)_isim_getNumber:(isim_numv *)v;
@end
static id<NSDecimalNumberBehaviors> default_behavior;

@implementation NSDecimalNumber { NSDecimal _d; }
- (instancetype)initWithDecimal:(NSDecimal)dcm {
    if ((self = [super init])) { _d = dcm; NSDecimalCompact(&_d); }
    return self;
}
- (instancetype)initWithMantissa:(unsigned long long)m exponent:(short)e isNegative:(BOOL)neg {
    NSDecimal d = {0};
    for (int i = 0; i < 4; i++) d._mantissa[i] = (unsigned short)(m >> (16 * i));
    int len = 4; while (len > 0 && !d._mantissa[len - 1]) len--;
    d._length = len; d._exponent = e; d._isNegative = len && neg;
    return [self initWithDecimal:d];
}
- (instancetype)initWithString:(NSString *)s locale:(id)locale {
    NSDecimal d = {0};
    if (!s || !parse_decimal(s, locale, &d)) { d._length = 0; d._isNegative = 1; }    /* NaN */
    return [self initWithDecimal:d];
}
- (instancetype)initWithString:(NSString *)s { return [self initWithString:s locale:nil]; }
- (instancetype)init { NSDecimal z = {0}; return [self initWithDecimal:z]; }
+ (NSDecimalNumber *)decimalNumberWithMantissa:(unsigned long long)m exponent:(short)e isNegative:(BOOL)neg { return [[self alloc] initWithMantissa:m exponent:e isNegative:neg]; }
+ (NSDecimalNumber *)decimalNumberWithDecimal:(NSDecimal)d { return [[self alloc] initWithDecimal:d]; }
+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)s { return [[self alloc] initWithString:s]; }
+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)s locale:(id)l { return [[self alloc] initWithString:s locale:l]; }
+ (NSDecimalNumber *)zero { return [self decimalNumberWithMantissa:0 exponent:0 isNegative:NO]; }
+ (NSDecimalNumber *)one { return [self decimalNumberWithMantissa:1 exponent:0 isNegative:NO]; }
+ (NSDecimalNumber *)notANumber { NSDecimal d = {0}; d._isNegative = 1; return [self decimalNumberWithDecimal:d]; }
+ (NSDecimalNumber *)maximumDecimalNumber {
    NSDecimal d = {0}; for (int i = 0; i < 8; i++) d._mantissa[i] = 0xffff;
    d._length = 8; d._exponent = 127;
    /* 2^128 - 1 has 39 digits: keep 38 nines' worth as Apple does (rounded down) */
    dec x; from_ns(&x, &d); dec_drop(&x, x.nd - 38, NSRoundDown); to_ns(&x, &d, NSRoundDown);
    return [self decimalNumberWithDecimal:d];
}
+ (NSDecimalNumber *)minimumDecimalNumber {
    NSDecimal d = self.maximumDecimalNumber.decimalValue; d._isNegative = 1;
    return [self decimalNumberWithDecimal:d];
}
+ (id<NSDecimalNumberBehaviors>)defaultBehavior { return default_behavior ?: NSDecimalNumberHandler.defaultDecimalNumberHandler; }
+ (void)setDefaultBehavior:(id<NSDecimalNumberBehaviors>)b { default_behavior = b; }
- (NSDecimal)decimalValue { return _d; }
- (void)_isim_getNumber:(isim_numv *)v { v->t = ISIM_NUM_DBL; v->d = self.doubleValue; }
- (double)doubleValue { return NSDecimalIsNotANumber(&_d) ? NAN : [NSDecimalString(&_d, nil) doubleValue]; }
- (long long)longLongValue { return (long long)self.doubleValue; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)self.doubleValue; }
- (BOOL)boolValue { return _d._length != 0; }
- (const char *)objCType { return "d"; }
- (NSString *)descriptionWithLocale:(id)locale { return NSDecimalString(&_d, locale); }
- (NSString *)description { return NSDecimalString(&_d, nil); }
- (NSString *)stringValue { return self.description; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSUInteger)hash { return (NSUInteger)self.doubleValue; }
- (BOOL)isEqual:(id)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[NSNumber class]]) return NO;
    return [self compare:o] == NSOrderedSame;
}
- (NSComparisonResult)compare:(NSNumber *)o {
    NSDecimal od = [o isKindOfClass:[NSDecimalNumber class]] ? [(NSDecimalNumber *)o decimalValue] : o.decimalValue;
    return NSDecimalCompare(&_d, &od);
}
/* arithmetic through a behavior: rounding to its scale, its reaction to errors */
static NSDecimalNumber *finish(NSDecimal r, NSCalculationError err, SEL op, NSDecimalNumber *l, NSDecimalNumber *rr, id<NSDecimalNumberBehaviors> b) {
    if (!b) b = NSDecimalNumber.defaultBehavior;
    short scale = [b scale];
    if (scale != NSDecimalNoScale && !NSDecimalIsNotANumber(&r)) NSDecimalRound(&r, &r, scale, [b roundingMode]);
    if (err != NSCalculationNoError) {
        NSDecimalNumber *alt = [b exceptionDuringOperation:op error:err leftOperand:l rightOperand:rr];
        if (alt) return alt;
    }
    return [NSDecimalNumber decimalNumberWithDecimal:r];
}
- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)n withBehavior:(id<NSDecimalNumberBehaviors>)b {
    NSDecimal r, x = n.decimalValue; id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSCalculationError e = NSDecimalAdd(&r, &_d, &x, [bb roundingMode]);
    return finish(r, e, _cmd, self, n, bb);
}
- (NSDecimalNumber *)decimalNumberByAdding:(NSDecimalNumber *)n { return [self decimalNumberByAdding:n withBehavior:nil]; }
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)n withBehavior:(id<NSDecimalNumberBehaviors>)b {
    NSDecimal r, x = n.decimalValue; id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSCalculationError e = NSDecimalSubtract(&r, &_d, &x, [bb roundingMode]);
    return finish(r, e, _cmd, self, n, bb);
}
- (NSDecimalNumber *)decimalNumberBySubtracting:(NSDecimalNumber *)n { return [self decimalNumberBySubtracting:n withBehavior:nil]; }
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)n withBehavior:(id<NSDecimalNumberBehaviors>)b {
    NSDecimal r, x = n.decimalValue; id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSCalculationError e = NSDecimalMultiply(&r, &_d, &x, [bb roundingMode]);
    return finish(r, e, _cmd, self, n, bb);
}
- (NSDecimalNumber *)decimalNumberByMultiplyingBy:(NSDecimalNumber *)n { return [self decimalNumberByMultiplyingBy:n withBehavior:nil]; }
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)n withBehavior:(id<NSDecimalNumberBehaviors>)b {
    NSDecimal r, x = n.decimalValue; id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSCalculationError e = NSDecimalDivide(&r, &_d, &x, [bb roundingMode]);
    return finish(r, e, _cmd, self, n, bb);
}
- (NSDecimalNumber *)decimalNumberByDividingBy:(NSDecimalNumber *)n { return [self decimalNumberByDividingBy:n withBehavior:nil]; }
- (NSDecimalNumber *)decimalNumberByRaisingToPower:(NSUInteger)p withBehavior:(id<NSDecimalNumberBehaviors>)b {
    NSDecimal r; id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSCalculationError e = NSDecimalPower(&r, &_d, p, [bb roundingMode]);
    return finish(r, e, _cmd, self, nil, bb);
}
- (NSDecimalNumber *)decimalNumberByRaisingToPower:(NSUInteger)p { return [self decimalNumberByRaisingToPower:p withBehavior:nil]; }
- (NSDecimalNumber *)decimalNumberByMultiplyingByPowerOf10:(short)p withBehavior:(id<NSDecimalNumberBehaviors>)b {
    NSDecimal r; id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSCalculationError e = NSDecimalMultiplyByPowerOf10(&r, &_d, p, [bb roundingMode]);
    return finish(r, e, _cmd, self, nil, bb);
}
- (NSDecimalNumber *)decimalNumberByMultiplyingByPowerOf10:(short)p { return [self decimalNumberByMultiplyingByPowerOf10:p withBehavior:nil]; }
- (NSDecimalNumber *)decimalNumberByRoundingAccordingToBehavior:(id<NSDecimalNumberBehaviors>)b {
    id<NSDecimalNumberBehaviors> bb = b ?: NSDecimalNumber.defaultBehavior;
    NSDecimal r; NSDecimalRound(&r, &_d, [bb scale], [bb roundingMode]);
    return [NSDecimalNumber decimalNumberWithDecimal:r];
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:self.description forKey:@"NS.decimal"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithString:[c decodeObjectOfClass:[NSString class] forKey:@"NS.decimal"]]; }
@end

/* ---------------- NSDecimalNumberHandler ---------------- */
@implementation NSDecimalNumberHandler { NSRoundingMode _mode; short _scale; BOOL _exact, _over, _under, _div; }
+ (NSDecimalNumberHandler *)defaultDecimalNumberHandler {
    static NSDecimalNumberHandler *h; static dispatch_once_t o;
    dispatch_once(&o, ^{ h = [[NSDecimalNumberHandler alloc] initWithRoundingMode:NSRoundPlain scale:NSDecimalNoScale raiseOnExactness:NO raiseOnOverflow:YES raiseOnUnderflow:YES raiseOnDivideByZero:YES]; });
    return h;
}
- (instancetype)initWithRoundingMode:(NSRoundingMode)m scale:(short)s raiseOnExactness:(BOOL)e raiseOnOverflow:(BOOL)o raiseOnUnderflow:(BOOL)u raiseOnDivideByZero:(BOOL)d {
    if ((self = [super init])) { _mode = m; _scale = s; _exact = e; _over = o; _under = u; _div = d; }
    return self;
}
- (instancetype)init { return [self initWithRoundingMode:NSRoundPlain scale:NSDecimalNoScale raiseOnExactness:NO raiseOnOverflow:YES raiseOnUnderflow:YES raiseOnDivideByZero:YES]; }
+ (instancetype)decimalNumberHandlerWithRoundingMode:(NSRoundingMode)m scale:(short)s raiseOnExactness:(BOOL)e raiseOnOverflow:(BOOL)o raiseOnUnderflow:(BOOL)u raiseOnDivideByZero:(BOOL)d {
    return [[self alloc] initWithRoundingMode:m scale:s raiseOnExactness:e raiseOnOverflow:o raiseOnUnderflow:u raiseOnDivideByZero:d];
}
- (NSRoundingMode)roundingMode { return _mode; }
- (short)scale { return _scale; }
/* raises when asked to; otherwise NaN for overflow and division by zero, 0 for underflow, the rounded value for exactness */
- (NSDecimalNumber *)exceptionDuringOperation:(SEL)op error:(NSCalculationError)err leftOperand:(NSDecimalNumber *)l rightOperand:(NSDecimalNumber *)r {
    switch (err) {
    case NSCalculationLossOfPrecision:
        if (_exact) [NSException raise:NSDecimalNumberExactnessException format:@"NSDecimalNumber exception: loss of precision in %@", NSStringFromSelector(op)];
        return nil;
    case NSCalculationOverflow:
        if (_over) [NSException raise:NSDecimalNumberOverflowException format:@"NSDecimalNumber overflow exception in %@", NSStringFromSelector(op)];
        return NSDecimalNumber.notANumber;
    case NSCalculationUnderflow:
        if (_under) [NSException raise:NSDecimalNumberUnderflowException format:@"NSDecimalNumber underflow exception in %@", NSStringFromSelector(op)];
        return NSDecimalNumber.zero;
    case NSCalculationDivideByZero:
        if (_div) [NSException raise:NSDecimalNumberDivideByZeroException format:@"NSDecimalNumber divide by zero exception in %@", NSStringFromSelector(op)];
        return NSDecimalNumber.notANumber;
    default: return nil;
    }
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInteger:_mode forKey:@"mode"]; [c encodeInteger:_scale forKey:@"scale"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithRoundingMode:[c decodeIntegerForKey:@"mode"] scale:(short)[c decodeIntegerForKey:@"scale"] raiseOnExactness:NO raiseOnOverflow:YES raiseOnUnderflow:YES raiseOnDivideByZero:YES]; }
@end

/* ---------------- NSNumber decimalValue ---------------- */
@implementation NSNumber (NSDecimalNumberExtensions)
/* integers exactly; doubles through their shortest round-tripping digits (%.17g trimmed), as on iOS */
- (NSDecimal)decimalValue {
    NSDecimal d = {0};
    const char *t = self.objCType;
    if (t[0] == 'd' || t[0] == 'f') {
        double v = self.doubleValue;
        if (v != v) { d._isNegative = 1; return d; }
        char buf[40];
        for (int prec = 15; prec <= 17; prec++) { snprintf(buf, sizeof buf, "%.*g", prec, v); if (strtod(buf, NULL) == v) break; }
        parse_decimal(@(buf), nil, &d);
    } else if (t[0] == 'Q' || t[0] == 'L' || t[0] == 'I' || t[0] == 'S' || t[0] == 'C') {
        unsigned long long u = self.unsignedLongLongValue;
        for (int i = 0; i < 4; i++) d._mantissa[i] = (unsigned short)(u >> (16 * i));
        int len = 4; while (len > 0 && !d._mantissa[len - 1]) len--; d._length = len;
    } else {
        long long s = self.longLongValue; unsigned long long u = s < 0 ? -(unsigned long long)s : (unsigned long long)s;
        for (int i = 0; i < 4; i++) d._mantissa[i] = (unsigned short)(u >> (16 * i));
        int len = 4; while (len > 0 && !d._mantissa[len - 1]) len--; d._length = len; d._isNegative = len && s < 0;
    }
    NSDecimalCompact(&d);
    return d;
}
@end
