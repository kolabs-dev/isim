// isim Foundation: Unicode canonical normalization (NFD and NFC) for -decomposedStringWithCanonicalMapping and
// -precomposedStringWithCanonicalMapping: canonical decomposition, canonical ordering of combining marks and
// canonical composition (UAX #15), with the tables in isim_unicode_norm.h (tools/gen-unicode-norm.py) and Hangul
// syllables by formula. Adapted: the Basic Multilingual Plane (characters outside it pass through unchanged).
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include "isim_unicode_norm.h"

enum { SBase = 0xAC00, LBase = 0x1100, VBase = 0x1161, TBase = 0x11A7, LCount = 19, VCount = 21, TCount = 28,
       NCount = VCount * TCount, SCount = LCount * NCount };

static int cmp_first(const void *k, const void *e) { return (int)*(const uint16_t *)k - (int)((const uint16_t *)e)[0]; }
static const uint16_t *decomposition(unichar c) {
    return bsearch(&c, isim_nfd_table, sizeof isim_nfd_table / sizeof isim_nfd_table[0], sizeof isim_nfd_table[0], cmp_first);
}
static int ccc(unichar c) {
    if (c < 0x0300) return 0;
    const uint16_t *e = bsearch(&c, isim_ccc_table, sizeof isim_ccc_table / sizeof isim_ccc_table[0], sizeof isim_ccc_table[0], cmp_first);
    return e ? e[1] : 0;
}
static int cmp_pair(const void *k, const void *e) {
    const uint16_t *a = k, *b = e;
    return a[0] != b[0] ? (int)a[0] - (int)b[0] : (int)a[1] - (int)b[1];
}
static unichar compose(unichar a, unichar b) {
    if (a >= LBase && a < LBase + LCount && b >= VBase && b < VBase + VCount)          /* Hangul LV */
        return (unichar)(SBase + ((a - LBase) * VCount + (b - VBase)) * TCount);
    if (a >= SBase && a < SBase + SCount && (a - SBase) % TCount == 0 && b > TBase && b < TBase + TCount)   /* LV + T */
        return (unichar)(a + (b - TBase));
    uint16_t key[2] = { a, b };
    const uint16_t *e = bsearch(key, isim_nfc_table, sizeof isim_nfc_table / sizeof isim_nfc_table[0], sizeof isim_nfc_table[0], cmp_pair);
    return e ? e[2] : 0;
}
static void decompose_into(unichar c, unichar *out, NSUInteger *n) {
    if (c >= SBase && c < SBase + SCount) {
        unsigned s = c - SBase;
        out[(*n)++] = (unichar)(LBase + s / NCount);
        out[(*n)++] = (unichar)(VBase + (s % NCount) / TCount);
        if (s % TCount) out[(*n)++] = (unichar)(TBase + s % TCount);
        return;
    }
    const uint16_t *d = decomposition(c);
    if (!d) { out[(*n)++] = c; return; }
    decompose_into(d[1], out, n);
    if (d[2]) decompose_into(d[2], out, n);
}
/* canonical decomposition, then the combining marks of each run in canonical order (a stable sort by class) */
static unichar *nfd(NSString *s, NSUInteger *count) {
    NSUInteger len = s.length;
    unichar *in = malloc((len + 1) * sizeof(unichar)), *out = malloc((len * 4 + 4) * sizeof(unichar));
    [s getCharacters:in range:NSMakeRange(0, len)];
    NSUInteger n = 0;
    for (NSUInteger i = 0; i < len; i++) decompose_into(in[i], out, &n);
    free(in);
    for (NSUInteger i = 1; i < n; i++) {
        int c = ccc(out[i]);
        if (!c) continue;
        for (NSUInteger j = i; j > 0 && ccc(out[j - 1]) > c; j--) { unichar t = out[j]; out[j] = out[j - 1]; out[j - 1] = t; }
    }
    *count = n;
    return out;
}
NSString *isim_nfd(NSString *s) {
    NSUInteger n;
    unichar *d = nfd(s, &n);
    NSString *r = [[NSString alloc] initWithCharacters:d length:n];
    free(d);
    return r;
}
/* canonical composition: a character joins the last starter when it is next to it, or when every mark between them
   has a lower combining class (UAX #15) */
NSString *isim_nfc(NSString *s) {
    NSUInteger n;
    unichar *d = nfd(s, &n);
    NSUInteger out = 0;
    long starter = -1;
    int lastClass = 0;
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = d[i];
        int cc = ccc(c);
        if (starter >= 0) {
            BOOL adjacent = out == (NSUInteger)starter + 1;
            if (adjacent || (lastClass != 0 && lastClass < cc)) {
                unichar comp = compose(d[starter], c);
                if (comp) { d[starter] = comp; continue; }
            }
        }
        if (cc == 0) { starter = (long)out; lastClass = 0; } else lastClass = cc;
        d[out++] = c;
    }
    NSString *r = [[NSString alloc] initWithCharacters:d length:out];
    free(d);
    return r;
}
