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

/* the 8-bit encodings' upper halves (0x80-0xFF) as Unicode: Windows-1252 (its five unassigned bytes map to the C1
 * controls, as on iOS) and Mac Roman (0xDB is the euro sign, 0xF0 the Apple logo, as in Apple's table) */
static const uint16_t cp1252_high[32] = {
    0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
    0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
};
static const uint16_t mac_roman_high[128] = {
    0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1, 0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
    0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF, 0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
    0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211, 0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
    0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB, 0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA, 0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1, 0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
    0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC, 0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
};
/* the Unicode scalar of byte b in an 8-bit encoding, or -1 (not an 8-bit encoding isim decodes, or not in it) */
int32_t isim_8bit_decode(NSStringEncoding enc, unsigned char b) {
    if (b < 0x80) return enc == NSASCIIStringEncoding || enc == NSISOLatin1StringEncoding || enc == NSWindowsCP1252StringEncoding ||
                         enc == NSMacOSRomanStringEncoding || enc == NSNonLossyASCIIStringEncoding ? b : -1;
    if (enc == NSISOLatin1StringEncoding) return b;
    if (enc == NSWindowsCP1252StringEncoding) return b < 0xA0 ? cp1252_high[b - 0x80] : b;
    if (enc == NSMacOSRomanStringEncoding) return mac_roman_high[b - 0x80];
    return -1;
}
/* the byte for Unicode scalar cp in an 8-bit encoding, or -1 */
int isim_8bit_encode(NSStringEncoding enc, uint32_t cp) {
    if (cp < 0x80) return isim_8bit_decode(enc, (unsigned char)cp) >= 0 ? (int)cp : -1;
    if (enc == NSASCIIStringEncoding || enc == NSNonLossyASCIIStringEncoding) return -1;
    for (int b = 0x80; b < 0x100; b++) { int32_t u = isim_8bit_decode(enc, (unsigned char)b); if (u < 0) return -1; if ((uint32_t)u == cp) return b; }
    return -1;
}
/* the length of the valid UTF-8 sequence at s[i] (no overlongs, surrogates or scalars past U+10FFFF), or 0 */
static NSUInteger utf8_valid_at(const unsigned char *s, NSUInteger n, NSUInteger i) {
    unsigned char b = s[i];
    if (b < 0x80) return 1;
    NSUInteger len = b >= 0xC2 && b < 0xE0 ? 2 : b >= 0xE0 && b < 0xF0 ? 3 : b >= 0xF0 && b < 0xF5 ? 4 : 0;
    if (!len || i + len > n) return 0;
    for (NSUInteger k = 1; k < len; k++) if ((s[i + k] & 0xC0) != 0x80) return 0;
    if (b == 0xE0 && s[i + 1] < 0xA0) return 0;          /* overlong */
    if (b == 0xED && s[i + 1] >= 0xA0) return 0;         /* a surrogate */
    if (b == 0xF0 && s[i + 1] < 0x90) return 0;          /* overlong */
    if (b == 0xF4 && s[i + 1] >= 0x90) return 0;         /* past U+10FFFF */
    return len;
}
/* bytes in enc as UTF-8 (malloc'd, NUL-terminated), or NULL where iOS gives nil: invalid UTF-8 or UTF-16/32, bytes outside
 * ASCII for NSASCIIStringEncoding. Encodings isim does not convert (the CJK ones, NEXTSTEP, Symbol, ISO Latin 2, the
 * other Windows code pages) are taken as UTF-8, as before. */
static char *decode_to_utf8(const void *bytes, NSUInteger len, NSStringEncoding enc, NSUInteger *outLen) {
    const unsigned char *s = bytes;
    if (enc == NSASCIIStringEncoding || enc == NSISOLatin1StringEncoding || enc == NSWindowsCP1252StringEncoding ||
        enc == NSMacOSRomanStringEncoding) {
        char *out = malloc(len * 3 + 1); NSUInteger o = 0;
        for (NSUInteger i = 0; i < len; i++) {
            int32_t cp = isim_8bit_decode(enc, s[i]);
            if (cp < 0) { free(out); return NULL; }
            o += encode_utf8((uint32_t)cp, out + o);
        }
        out[o] = 0; *outLen = o;
        return out;
    }
    if (enc == NSUTF16StringEncoding || enc == NSUTF16BigEndianStringEncoding || enc == NSUTF16LittleEndianStringEncoding) {
        if (len % 2) return NULL;
        NSUInteger n = len / 2, start = 0;
        int be = enc == NSUTF16BigEndianStringEncoding;
        if (enc == NSUTF16StringEncoding && n && ((s[0] == 0xFF && s[1] == 0xFE) || (s[0] == 0xFE && s[1] == 0xFF))) { be = s[0] == 0xFE; start = 1; }
        unichar *u = malloc((n + 1) * sizeof(unichar));
        for (NSUInteger i = start; i < n; i++) u[i - start] = be ? (unichar)(s[2 * i] << 8 | s[2 * i + 1]) : (unichar)(s[2 * i] | s[2 * i + 1] << 8);
        char *out = utf16_to_utf8(u, n - start, outLen);
        free(u);
        return out;
    }
    if (enc == NSUTF32StringEncoding || enc == NSUTF32BigEndianStringEncoding || enc == NSUTF32LittleEndianStringEncoding) {
        if (len % 4) return NULL;
        NSUInteger n = len / 4, start = 0;
        int be = enc == NSUTF32BigEndianStringEncoding;
        if (enc == NSUTF32StringEncoding && n) {
            if (s[0] == 0xFF && s[1] == 0xFE && !s[2] && !s[3]) start = 1;
            else if (!s[0] && !s[1] && s[2] == 0xFE && s[3] == 0xFF) { be = 1; start = 1; }
        }
        char *out = malloc(n * 4 + 1); NSUInteger o = 0;
        for (NSUInteger i = start; i < n; i++) {
            const unsigned char *q = s + 4 * i;
            uint32_t cp = be ? (uint32_t)q[0] << 24 | q[1] << 16 | q[2] << 8 | q[3] : (uint32_t)q[3] << 24 | q[2] << 16 | q[1] << 8 | q[0];
            if (cp > 0x10FFFF || (cp >= 0xD800 && cp < 0xE000)) { free(out); return NULL; }
            o += encode_utf8(cp, out + o);
        }
        out[o] = 0; *outLen = o;
        return out;
    }
    if (enc == NSUTF8StringEncoding)
        for (NSUInteger i = 0; i < len; ) { NSUInteger k = utf8_valid_at(s, len, i); if (!k) return NULL; i += k; }
    char *out = malloc(len + 1);
    memcpy(out, bytes, len); out[len] = 0; *outLen = len;
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
    bytes = realloc(bytes, len + 1); bytes[len] = 0;   /* storage is always NUL-terminated (UTF8String) */
    s->_b = bytes; s->_n = len;
    return s;
}
NSString *isim_string_copy(const char *bytes, NSUInteger len) {
    char *b = malloc(len + 1); memcpy(b, bytes, len); b[len] = 0;
    return isim_string_take(b, len);
}

/* ---------------- formatting ----------------
 * Two passes, so positional arguments ("%2$@ %1$d", common in localized strings) work: the first pass
 * records each argument's type by position, the arguments are read from the va_list in order, and the
 * second pass formats them. */
enum { FA_NONE, FA_INT, FA_LONG, FA_LLONG, FA_UINT, FA_ULONG, FA_ULLONG, FA_DOUBLE, FA_LDOUBLE, FA_ID, FA_PTR, FA_CSTR, FA_USTR };
typedef union { long long ll; unsigned long long ull; double d; long double ld; void *p; } farg_t;
typedef struct { NSUInteger start, end; int pos, starw, starp, flagsN; char flags[8]; int width, prec; int lng; char conv; } fspec_t;

/* parses the conversion at f[i] (after '%'); returns NO at the end of the format */
static BOOL parse_spec(const char *f, NSUInteger fn, NSUInteger *ip, fspec_t *sp, int *seq) {
    NSUInteger i = *ip;
    memset(sp, 0, sizeof *sp); sp->width = -1; sp->prec = -1; sp->starw = sp->starp = -1; sp->pos = -1;
    sp->start = i - 1;
    /* position: digits followed by '$' */
    NSUInteger j = i; int num = 0;
    while (j < fn && isdigit((unsigned char)f[j])) num = num * 10 + (f[j++] - '0');
    if (j < fn && f[j] == '$' && j > i) { sp->pos = num - 1; i = j + 1; }
    while (i < fn && strchr("-+ #0'", f[i])) { if (sp->flagsN < 7) sp->flags[sp->flagsN++] = f[i]; i++; }
    if (i < fn && f[i] == '*') {
        i++; int n2 = 0; NSUInteger k = i;
        while (k < fn && isdigit((unsigned char)f[k])) n2 = n2 * 10 + (f[k++] - '0');
        if (k < fn && f[k] == '$' && k > i) { sp->starw = n2 - 1; i = k + 1; } else sp->starw = (*seq)++;
    } else if (i < fn && isdigit((unsigned char)f[i])) { sp->width = 0; while (i < fn && isdigit((unsigned char)f[i])) sp->width = sp->width * 10 + (f[i++] - '0'); }
    if (i < fn && f[i] == '.') {
        i++; sp->prec = 0;
        if (i < fn && f[i] == '*') {
            i++; int n2 = 0; NSUInteger k = i;
            while (k < fn && isdigit((unsigned char)f[k])) n2 = n2 * 10 + (f[k++] - '0');
            if (k < fn && f[k] == '$' && k > i) { sp->starp = n2 - 1; i = k + 1; } else sp->starp = (*seq)++;
        } else while (i < fn && isdigit((unsigned char)f[i])) sp->prec = sp->prec * 10 + (f[i++] - '0');
    }
    while (i < fn && strchr("hlqLztj", f[i])) {
        char c = f[i++];
        if (c == 'h') sp->lng = -1; else if (c == 'l') sp->lng = sp->lng == 1 ? 2 : 1; else if (c == 'q' || c == 'j') sp->lng = 2;
        else if (c == 'L') sp->lng = 3; else sp->lng = 1;
    }
    if (i >= fn) { *ip = i; return NO; }
    sp->conv = f[i++];
    sp->end = i;
    if (sp->conv != '%' && sp->pos < 0) sp->pos = (*seq)++;
    *ip = i;
    return YES;
}
static int arg_type(const fspec_t *s) {
    switch (s->conv) {
    case 'd': case 'i': return s->lng == 2 ? FA_LLONG : s->lng == 1 ? FA_LONG : FA_INT;
    case 'u': case 'o': case 'x': case 'X': return s->lng == 2 ? FA_ULLONG : s->lng == 1 ? FA_ULONG : FA_UINT;
    case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A': return s->lng == 3 ? FA_LDOUBLE : FA_DOUBLE;
    case '@': return FA_ID;
    case 'c': case 'C': return FA_INT;
    case 's': return FA_CSTR;
    case 'S': return FA_USTR;
    case 'p': case 'n': return FA_PTR;
    default: return FA_NONE;
    }
}
NSString *isim_format(NSString *fmt, va_list ap) {
    NSUInteger fn; const char *f = [fmt _isim_bytes:&fn];
    enum { MAXA = 64 };
    int types[MAXA] = {0}; int nargs = 0, seq = 0;
    /* plural formats: argument types of %#@var@ come from the .stringsdict entry (NSStringFormatValueTypeKey) */
    NSString *typed = strstr(f, "#@") ? isim_plural_typed(fmt) : nil;
    NSUInteger tfn = fn; const char *tf = typed ? [typed _isim_bytes:&tfn] : f;
    /* pass 1: argument types */
    for (NSUInteger i = 0; i < tfn;) {
        if (tf[i] != '%') { i++; continue; }
        i++;
        fspec_t sp;
        if (!parse_spec(tf, tfn, &i, &sp, &seq)) break;
        if (sp.conv == '%') continue;
        if (sp.starw >= 0 && sp.starw < MAXA) { types[sp.starw] = FA_INT; if (sp.starw + 1 > nargs) nargs = sp.starw + 1; }
        if (sp.starp >= 0 && sp.starp < MAXA) { types[sp.starp] = FA_INT; if (sp.starp + 1 > nargs) nargs = sp.starp + 1; }
        if (sp.pos >= 0 && sp.pos < MAXA) { int t = arg_type(&sp); if (t) types[sp.pos] = t; if (sp.pos + 1 > nargs) nargs = sp.pos + 1; }
    }
    /* read the arguments in order */
    farg_t vals[MAXA]; memset(vals, 0, sizeof vals);
    va_list args; va_copy(args, ap);
    for (int k = 0; k < nargs; k++) {
        switch (types[k]) {
        case FA_INT: vals[k].ll = va_arg(args, int); break;
        case FA_UINT: vals[k].ull = va_arg(args, unsigned int); break;
        case FA_LONG: vals[k].ll = va_arg(args, long); break;
        case FA_ULONG: vals[k].ull = va_arg(args, unsigned long); break;
        case FA_LLONG: vals[k].ll = va_arg(args, long long); break;
        case FA_ULLONG: vals[k].ull = va_arg(args, unsigned long long); break;
        case FA_DOUBLE: vals[k].d = va_arg(args, double); break;
        case FA_LDOUBLE: vals[k].ld = va_arg(args, long double); break;
        default: vals[k].p = va_arg(args, void *); break;       /* id, pointers, strings, unknown */
        }
    }
    va_end(args);
    /* .stringsdict plural formats: substitute each %#@var@ with its rule text, then format that */
    if (typed) {
        BOOL expanded = NO;
        int *tp = types; farg_t *vp = vals; int na = nargs;   /* blocks cannot capture arrays */
        NSString *plain = isim_plural_expand(fmt, ^double(int p) {
            if (p < 0 || p >= na) return 0;
            switch (tp[p]) {
            case FA_UINT: case FA_ULONG: case FA_ULLONG: return (double)vp[p].ull;
            case FA_DOUBLE: return vp[p].d;
            case FA_LDOUBLE: return (double)vp[p].ld;
            case FA_ID: return [(id)vp[p].p respondsToSelector:@selector(doubleValue)] ? [(id)vp[p].p doubleValue] : 0;
            default: return (double)vp[p].ll;
            }
        }, &expanded);
        if (expanded) return isim_format(plain, ap);
    }
    /* pass 2: format */
    buf_t out = {0}; buf_add(&out, "", 0);
    seq = 0;
    for (NSUInteger i = 0; i < fn;) {
        if (f[i] != '%') { NSUInteger j = i; while (j < fn && f[j] != '%') j++; buf_add(&out, f + i, j - i); i = j; continue; }
        i++;
        fspec_t sp;
        if (!parse_spec(f, fn, &i, &sp, &seq)) break;
        if (sp.conv == '%') { buf_add(&out, "%", 1); continue; }
        if (sp.pos < 0 || sp.pos >= MAXA) continue;
        int width = sp.starw >= 0 && sp.starw < MAXA ? (int)vals[sp.starw].ll : sp.width;
        int prec = sp.starp >= 0 && sp.starp < MAXA ? (int)vals[sp.starp].ll : sp.prec;
        char spec[64]; int n = 0;
        spec[n++] = '%';
        for (int k = 0; k < sp.flagsN; k++) spec[n++] = sp.flags[k];
        if (width >= 0) n += snprintf(spec + n, 16, "%d", width);
        if (prec >= 0) n += snprintf(spec + n, 16, ".%d", prec);
        farg_t v = vals[sp.pos];
        char tmp[512]; int w = 0;
        switch (sp.conv) {
        case '@': {
            id o = (id)v.p;
            const char *s = o ? [[o description] UTF8String] : "(null)";
            if (width < 0 && prec < 0) buf_add(&out, s, strlen(s));
            else { spec[n++] = 's'; spec[n] = 0; w = snprintf(tmp, sizeof tmp, spec, s); buf_add(&out, tmp, w < (int)sizeof tmp ? w : (int)sizeof tmp - 1); }
            break; }
        case 'd': case 'i': spec[n++] = 'l'; spec[n++] = 'l'; spec[n++] = sp.conv; spec[n] = 0;
            w = snprintf(tmp, sizeof tmp, spec, sp.lng == -1 ? (long long)(short)v.ll : v.ll); buf_add(&out, tmp, w < (int)sizeof tmp ? w : (int)sizeof tmp - 1); break;
        case 'u': case 'o': case 'x': case 'X': spec[n++] = 'l'; spec[n++] = 'l'; spec[n++] = sp.conv; spec[n] = 0;
            w = snprintf(tmp, sizeof tmp, spec, v.ull); buf_add(&out, tmp, w < (int)sizeof tmp ? w : (int)sizeof tmp - 1); break;
        case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
            if (sp.lng == 3) { spec[n++] = 'L'; spec[n++] = sp.conv; spec[n] = 0; w = snprintf(tmp, sizeof tmp, spec, v.ld); }
            else { spec[n++] = sp.conv; spec[n] = 0; w = snprintf(tmp, sizeof tmp, spec, v.d); }
            buf_add(&out, tmp, w < (int)sizeof tmp ? w : (int)sizeof tmp - 1); break;
        case 'c': { char c = (char)v.ll; buf_add(&out, &c, 1); break; }
        case 'C': { char e[4]; NSUInteger k = encode_utf8((uint32_t)v.ll, e); buf_add(&out, e, k); break; }
        case 's': {
            const char *s = v.p ? (const char *)v.p : "(null)";
            if (width < 0 && prec < 0) buf_add(&out, s, strlen(s));
            else { spec[n++] = 's'; spec[n] = 0; w = snprintf(tmp, sizeof tmp, spec, s); buf_add(&out, tmp, w < (int)sizeof tmp ? w : (int)sizeof tmp - 1); }
            break; }
        case 'S': { const unichar *u = v.p; NSUInteger k = 0; while (u && u[k]) k++;
                    NSUInteger ol; char *s = utf16_to_utf8(u, k, &ol); buf_add(&out, s, ol); free(s); break; }
        case 'p': w = snprintf(tmp, sizeof tmp, "%p", v.p); buf_add(&out, tmp, w); break;
        case 'n': break;
        default: buf_add(&out, f + sp.start, sp.end - sp.start); break;
        }
    }
    return isim_string_take(out.b, out.n);
}

/* ---------------- NSString (abstract) ---------------- */
@implementation NSString
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSString class]); }    /* NS.string */
- (instancetype)initWithCoder:(NSCoder *)c {
    NSString *s = [c decodeObjectOfClass:[NSString class] forKey:@"NS.string"];
    if (!s) {                                                    /* NS.bytes (UTF-8), as some archives store it */
        NSUInteger n = 0; const uint8_t *b = [c decodeBytesForKey:@"NS.bytes" returnedLength:&n];
        s = b ? [[[NSString alloc] initWithBytes:b length:n encoding:NSUTF8StringEncoding] autorelease] : @"";
    }
    return [self initWithString:s ?: @""];
}
+ (instancetype)allocWithZone:(NSZone *)zone {
    if (self == [NSString class]) return class_createInstance([__NSImmString class], 0);
    return class_createInstance(self, 0);
}
- (instancetype)init { return self; }
/* A subclass isim does not implement (a Swift string bridged to Objective-C, an app's own NSString subclass): its UTF-8
 * from the primitives every subclass implements, -length and -characterAtIndex: (autoreleased). Without them: empty. */
- (const char *)_isim_bytes:(NSUInteger *)len {
    Class base = [NSString class], cls = object_getClass(self);
    if (class_getMethodImplementation(cls, @selector(length)) == class_getMethodImplementation(base, @selector(length)) ||
        class_getMethodImplementation(cls, @selector(characterAtIndex:)) == class_getMethodImplementation(base, @selector(characterAtIndex:))) {
        *len = 0; return "";
    }
    NSUInteger n = [self length];
    NSMutableData *d = [NSMutableData dataWithLength:n * 3 + 1];
    unsigned char *o = [d mutableBytes]; NSUInteger k = 0;
    for (NSUInteger i = 0; i < n; i++) {
        uint32_t c = [self characterAtIndex:i];
        if (c >= 0xD800 && c < 0xDC00 && i + 1 < n) {
            unichar lo = [self characterAtIndex:i + 1];
            if (lo >= 0xDC00 && lo < 0xE000) { c = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00); i++; }
        }
        if (c < 0x80) o[k++] = (unsigned char)c;
        else if (c < 0x800) { o[k++] = 0xC0 | (c >> 6); o[k++] = 0x80 | (c & 0x3F); }
        else if (c < 0x10000) { o[k++] = 0xE0 | (c >> 12); o[k++] = 0x80 | ((c >> 6) & 0x3F); o[k++] = 0x80 | (c & 0x3F); }
        else { o[k++] = 0xF0 | (c >> 18); o[k++] = 0x80 | ((c >> 12) & 0x3F); o[k++] = 0x80 | ((c >> 6) & 0x3F); o[k++] = 0x80 | (c & 0x3F); }
    }
    o[k] = 0;
    *len = k;
    return (const char *)o;
}
/* The Swift stdlib bridges small ASCII strings (String._bridgeToObjectiveCImpl, used e.g. for error domains when a
 * Swift Error crosses into Objective-C) by sending this to __StringStorage, whose superclass is connected to NSString.
 * Apple's Foundation answers with a tagged pointer; isim returns an ordinary immutable string (+1, "new" family). */
+ (id)newTaggedNSStringWithASCIIBytes_:(const unsigned char *)bytes length_:(NSInteger)len {
    return [[NSString alloc] initWithBytes:bytes length:(NSUInteger)len encoding:NSUTF8StringEncoding];
}

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
+ (instancetype)stringWithContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)enc error:(id *)error {
    if ([url isFileURL]) return [self stringWithContentsOfFile:[url path] encoding:enc error:error];
    NSData *d = [NSData dataWithContentsOfURL:url];
    return d ? [[[self alloc] initWithData:d encoding:enc] autorelease] : nil;
}
+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(id *)error {
    int fd = open([path UTF8String], O_RDONLY);
    if (fd < 0) { if (error) *error = nil; return nil; }
    buf_t b = {0}; char chunk[4096]; ssize_t r;
    buf_add(&b, "", 0);
    while ((r = read(fd, chunk, sizeof chunk)) > 0) buf_add(&b, chunk, (NSUInteger)r);
    close(fd);
    NSString *s = [[[self alloc] initWithBytes:b.b length:b.n encoding:enc] autorelease];
    free(b.b);
    return s;
}
- (instancetype)initWithBytes:(const void *)bytes length:(NSUInteger)len encoding:(NSStringEncoding)enc {
    [self release];
    NSUInteger ol; char *u = decode_to_utf8(bytes, len, enc, &ol);
    return u ? isim_string_take(u, ol) : nil;
}
- (instancetype)initWithCharacters:(const unichar *)c length:(NSUInteger)n { [self release]; NSUInteger ol; char *u = utf16_to_utf8(c, n, &ol); return isim_string_take(u, ol); }
- (instancetype)initWithData:(NSData *)data encoding:(NSStringEncoding)e { return data ? [self initWithBytes:[data bytes] length:[data length] encoding:e] : ([self release], nil); }
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
/* the current locale's collation (StringExtras.m); Finder-like ordering for localizedStandardCompare: */
- (NSComparisonResult)localizedCompare:(NSString *)o { return [self compare:o options:0 range:NSMakeRange(0, [self length]) locale:[NSLocale currentLocale]]; }
- (NSComparisonResult)localizedCaseInsensitiveCompare:(NSString *)o { return [self compare:o options:NSCaseInsensitiveSearch range:NSMakeRange(0, [self length]) locale:[NSLocale currentLocale]]; }
- (NSComparisonResult)localizedStandardCompare:(NSString *)o {
    return [self compare:o options:NSCaseInsensitiveSearch | NSNumericSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch range:NSMakeRange(0, [self length]) locale:[NSLocale currentLocale]];
}
- (NSComparisonResult)caseInsensitiveCompare:(NSString *)o { return [self compare:o options:NSCaseInsensitiveSearch]; }
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
    if (mask & NSRegularExpressionSearch) return isim_regex_search(self, s, mask, NSMakeRange(0, [self length]));
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
/* user-perceived character (approximation of extended grapheme clusters): surrogate pairs,
 * combining marks, variation selectors, emoji modifiers, ZWJ sequences, regional-indicator pairs */
static uint32_t scalar_at(NSString *s, NSUInteger i, NSUInteger len, NSUInteger *units) {
    unichar c = [s characterAtIndex:i];
    if (c >= 0xD800 && c < 0xDC00 && i + 1 < len) {
        unichar d = [s characterAtIndex:i + 1];
        if (d >= 0xDC00 && d < 0xE000) { *units = 2; return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); }
    }
    *units = 1; return c;
}
static BOOL is_extender(uint32_t u) {
    return (u >= 0x300 && u <= 0x36F) || (u >= 0x1AB0 && u <= 0x1AFF) || (u >= 0x1DC0 && u <= 0x1DFF) || (u >= 0x20D0 && u <= 0x20FF) ||
           (u >= 0xFE00 && u <= 0xFE0F) || (u >= 0xFE20 && u <= 0xFE2F) || (u >= 0x1F3FB && u <= 0x1F3FF) || (u >= 0xE0020 && u <= 0xE007F) || u == 0x200D;
}
static BOOL is_ri(uint32_t u) { return u >= 0x1F1E6 && u <= 0x1F1FF; }
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)idx {
    NSUInteger len = [self length];
    if (idx >= len) [NSException raise:NSRangeException format:@"-[NSString rangeOfComposedCharacterSequenceAtIndex:]: index %lu out of bounds", (unsigned long)idx];
    /* walk clusters from the start until one contains idx */
    NSUInteger start = 0;
    while (start < len) {
        NSUInteger u, end = start;
        uint32_t first = scalar_at(self, end, len, &u); end += u;
        BOOL joined = NO; int ri = is_ri(first);
        while (end < len) {
            NSUInteger v; uint32_t next = scalar_at(self, end, len, &v);
            if (is_extender(next)) { joined = next == 0x200D; end += v; continue; }
            if (joined) { joined = NO; end += v; continue; }
            if (ri == 1 && is_ri(next)) { ri = 2; end += v; continue; }
            break;
        }
        if (idx < end) return NSMakeRange(start, end - start);
        start = end;
    }
    return NSMakeRange(idx, 1);
}
- (NSString *)stringByReplacingCharactersInRange:(NSRange)r withString:(NSString *)rep {
    NSUInteger len = [self length];
    if (NSMaxRange(r) > len) [NSException raise:NSRangeException format:@"-[NSString stringByReplacingCharactersInRange:withString:]: range {%lu, %lu} out of bounds", (unsigned long)r.location, (unsigned long)r.length];
    NSString *a = [self substringToIndex:r.location], *b = [self substringFromIndex:NSMaxRange(r)];
    return [[a stringByAppendingString:rep ?: @""] stringByAppendingString:b];
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
static NSString *map_case(NSString *s, int mode) {   /* mode: 0 lower, 1 upper, 2 capitalize words */
    NSUInteger n; const char *b = [s _isim_bytes:&n];
    buf_t o = {0}; buf_add(&o, "", 0);
    int word = 1;
    for (NSUInteger i = 0; i < n;) {
        uint32_t cp = decode_at(b, n, &i);
        int up = mode == 1 || (mode == 2 && word);
        char tmp[8];
        if (up && cp == 0xDF) { buf_add(&o, "SS", 2); word = 0; continue; }       /* ß */
        uint32_t m = isim_case_map(cp, up);
        buf_add(&o, tmp, encode_utf8(m, tmp));
        if (mode == 2) word = !(isalnum((int)(cp < 0x80 ? cp : 'a')) || cp >= 0x80 || cp == '\'' || cp == 0x2019);
    }
    return [isim_string_take(o.b, o.n) autorelease];
}
- (NSString *)lowercaseString { return map_case(self, 0); }
- (NSString *)uppercaseString { return map_case(self, 1); }
- (NSString *)capitalizedString { return map_case(self, 2); }
/* isim: Unicode normalization not implemented yet; strings are returned unchanged (exact for ASCII/NFC input) */
/* Unicode NFD / NFC (Normalization.m) */
- (NSString *)decomposedStringWithCanonicalMapping { extern NSString *isim_nfd(NSString *); return isim_nfd(self); }
- (NSString *)precomposedStringWithCanonicalMapping { extern NSString *isim_nfc(NSString *); return isim_nfc(self); }
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
- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)a encoding:(NSStringEncoding)e error:(id *)err {
    if (![url isFileURL]) { if (err) *err = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:518 userInfo:nil]; return NO; }   /* NSFileWriteUnsupportedSchemeError */
    return [self writeToFile:[url path] atomically:a encoding:e error:err];
}
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
    NSUInteger ol; char *u = decode_to_utf8(bytes, len, enc, &ol);
    if (!u) { [self release]; return nil; }
    [self initWithCapacity:ol];
    [self _append:u length:ol];
    free(u);
    return self;
}
- (instancetype)initWithCharacters:(const unichar *)c length:(NSUInteger)n { return [self initWithBytes:c length:n * 2 encoding:NSUTF16LittleEndianStringEncoding]; }
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
