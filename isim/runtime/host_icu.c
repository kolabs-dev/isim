/* isim host: locale data for Foundation from the host's ICU (libicuuc + libicui18n, loaded on first use).
 * Apple's Foundation is built on ICU too, so collation, calendars, date / number / relative / interval / list / unit
 * formatting and plural rules come from the same algorithms and CLDR data (the host's ICU version, not iOS's).
 * Linux distributions install ICU with libxml2 / Qt / Boost on practically every system; without it these functions
 * return -1 and Foundation falls back to its built-in tables.
 * Strings are UTF-8 in and out; dates are milliseconds since 1970 (ICU's UDate). Locale identifiers are ICU's
 * ("pt_BR", "ar@calendar=islamic-umalqura;numbers=arab"). Outputs are NUL-terminated; functions return the output's
 * length, or -1 when ICU is unavailable or the call failed. */
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint16_t UChar;
typedef int UErr;
typedef void UCollator, UDateFormat, UDTPG, UCal, UNumFmt, UNumFormatter, UNumResult, URelFmt, UItvFmt, UListFmt, UPlural;
#define FAIL(e) ((e) > 0)

static struct {
    /* common */
    int32_t *(*dummy)(void);
    UChar *(*strFromUTF8)(UChar *, int32_t, int32_t *, const char *, int32_t, UErr *);
    char *(*strToUTF8)(char *, int32_t, int32_t *, const UChar *, int32_t, UErr *);
    int32_t (*locDisplayName)(const char *, const char *, UChar *, int32_t, UErr *);
    int32_t (*locDisplayLanguage)(const char *, const char *, UChar *, int32_t, UErr *);
    int32_t (*locDisplayCountry)(const char *, const char *, UChar *, int32_t, UErr *);
    int32_t (*locDisplayScript)(const char *, const char *, UChar *, int32_t, UErr *);
    int32_t (*locDisplayKeywordValue)(const char *, const char *, const char *, UChar *, int32_t, UErr *);
    const UChar *(*currName)(const UChar *, const char *, int, int8_t *, int32_t *, UErr *);
    const UChar *(*currPluralName)(const UChar *, const char *, int8_t *, const char *, int32_t *, UErr *);
    int32_t (*currForLocale)(const char *, UChar *, int32_t, UErr *);
    int32_t (*currFractionDigits)(const UChar *, UErr *);
    int32_t (*toUpper)(UChar *, int32_t, const UChar *, int32_t, const char *, UErr *);
    int32_t (*toLower)(UChar *, int32_t, const UChar *, int32_t, const char *, UErr *);
    int32_t (*toTitle)(UChar *, int32_t, const UChar *, int32_t, void *, const char *, UErr *);
    /* i18n */
    UCollator *(*colOpen)(const char *, UErr *);
    void (*colClose)(UCollator *);
    void (*colSetAttr)(UCollator *, int, int, UErr *);
    int (*colStrcoll)(const UCollator *, const UChar *, int32_t, const UChar *, int32_t);
    UDateFormat *(*datOpen)(int, int, const char *, const UChar *, int32_t, const UChar *, int32_t, UErr *);
    void (*datClose)(UDateFormat *);
    int32_t (*datFormat)(const UDateFormat *, double, UChar *, int32_t, void *, UErr *);
    double (*datParse)(const UDateFormat *, const UChar *, int32_t, int32_t *, UErr *);
    void (*datSetLenient)(UDateFormat *, int8_t);
    int32_t (*datToPattern)(const UDateFormat *, int8_t, UChar *, int32_t, UErr *);
    int32_t (*datGetSymbols)(const UDateFormat *, int, int32_t, UChar *, int32_t, UErr *);
    int32_t (*datCountSymbols)(const UDateFormat *, int);
    UDTPG *(*dtpgOpen)(const char *, UErr *);
    void (*dtpgClose)(UDTPG *);
    int32_t (*dtpgBest)(UDTPG *, const UChar *, int32_t, UChar *, int32_t, UErr *);
    UCal *(*calOpen)(const UChar *, int32_t, const char *, int, UErr *);
    void (*calClose)(UCal *);
    void (*calSetMillis)(UCal *, double, UErr *);
    double (*calGetMillis)(const UCal *, UErr *);
    int32_t (*calGet)(const UCal *, int, UErr *);
    void (*calSet)(UCal *, int, int32_t);
    void (*calClear)(UCal *);
    void (*calAdd)(UCal *, int, int32_t, UErr *);
    void (*calRoll)(UCal *, int, int32_t, UErr *);
    int32_t (*calGetLimit)(const UCal *, int, int, UErr *);
    void (*calSetAttr)(UCal *, int, int32_t);
    int32_t (*calGetAttr)(const UCal *, int);
    int32_t (*calTZName)(const UCal *, int, const char *, UChar *, int32_t, UErr *);
    UNumFormatter *(*numfOpen)(const UChar *, int32_t, const char *, UErr *);
    void (*numfClose)(UNumFormatter *);
    UNumResult *(*numfOpenResult)(UErr *);
    void (*numfCloseResult)(UNumResult *);
    void (*numfFormatDouble)(const UNumFormatter *, double, UNumResult *, UErr *);
    int32_t (*numfResultToString)(const UNumResult *, UChar *, int32_t, UErr *);
    UNumFmt *(*numOpen)(int, const UChar *, int32_t, const char *, void *, UErr *);
    void (*numClose)(UNumFmt *);
    int32_t (*numFormatDouble)(const UNumFmt *, double, UChar *, int32_t, void *, UErr *);
    double (*numParseDouble)(const UNumFmt *, const UChar *, int32_t, int32_t *, UErr *);
    int32_t (*numToPattern)(const UNumFmt *, int8_t, UChar *, int32_t, UErr *);
    int32_t (*numGetSymbol)(const UNumFmt *, int, UChar *, int32_t, UErr *);
    void (*numSetTextAttr)(UNumFmt *, int, const UChar *, int32_t, UErr *);
    URelFmt *(*relOpen)(const char *, void *, int, int, UErr *);
    void (*relClose)(URelFmt *);
    int32_t (*relFormat)(const URelFmt *, double, int, UChar *, int32_t, UErr *);
    int32_t (*relFormatNumeric)(const URelFmt *, double, int, UChar *, int32_t, UErr *);
    UItvFmt *(*itvOpen)(const char *, const UChar *, int32_t, const UChar *, int32_t, UErr *);
    void (*itvClose)(UItvFmt *);
    int32_t (*itvFormat)(const UItvFmt *, double, double, UChar *, int32_t, void *, UErr *);
    UListFmt *(*listOpen)(const char *, int, int, UErr *);
    void (*listClose)(UListFmt *);
    int32_t (*listFormat)(const UListFmt *, const UChar *const *, const int32_t *, int32_t, UChar *, int32_t, UErr *);
    UPlural *(*plOpen)(const char *, int, UErr *);
    void (*plClose)(UPlural *);
    int32_t (*plSelect)(const UPlural *, double, UChar *, int32_t, UErr *);
} U;

static int icu_version;            /* major version of the loaded ICU; 0 = unavailable */
static pthread_once_t once = PTHREAD_ONCE_INIT;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;   /* ICU objects are not thread-safe; the caches are shared */

static void *sym(void *h, const char *name, int v) {
    char b[96];
    snprintf(b, sizeof b, "%s_%d", name, v);
    void *p = dlsym(h, b);
    return p ? p : dlsym(h, name);   /* built without symbol renaming */
}

static void load(void) {
    if (getenv("ISIM_NO_ICU")) return;    /* tests of the built-in fallback tables */
    void *uc = NULL, *i18n = NULL;
    int v;
    for (v = 99; v >= 50 && !uc; v--) {
        char b[48];
        snprintf(b, sizeof b, "libicuuc.so.%d", v);
        if ((uc = dlopen(b, RTLD_NOW | RTLD_LOCAL))) {
            snprintf(b, sizeof b, "libicui18n.so.%d", v);
            if (!(i18n = dlopen(b, RTLD_NOW | RTLD_LOCAL))) { dlclose(uc); uc = NULL; }
            else break;
        }
    }
    if (!uc || !i18n) return;
#define C(f, n) *(void **)&U.f = sym(uc, n, v)
#define I(f, n) *(void **)&U.f = sym(i18n, n, v)
    C(strFromUTF8, "u_strFromUTF8"); C(strToUTF8, "u_strToUTF8"); C(locDisplayName, "uloc_getDisplayName");
    C(locDisplayLanguage, "uloc_getDisplayLanguage"); C(locDisplayCountry, "uloc_getDisplayCountry");
    C(locDisplayScript, "uloc_getDisplayScript"); C(locDisplayKeywordValue, "uloc_getDisplayKeywordValue");
    C(currName, "ucurr_getName"); C(currPluralName, "ucurr_getPluralName"); C(currForLocale, "ucurr_forLocale");
    C(currFractionDigits, "ucurr_getDefaultFractionDigits");
    C(toUpper, "u_strToUpper"); C(toLower, "u_strToLower"); C(toTitle, "u_strToTitle");
    I(colOpen, "ucol_open"); I(colClose, "ucol_close"); I(colSetAttr, "ucol_setAttribute"); I(colStrcoll, "ucol_strcoll");
    I(datOpen, "udat_open"); I(datClose, "udat_close"); I(datFormat, "udat_format"); I(datParse, "udat_parse");
    I(datSetLenient, "udat_setLenient"); I(datToPattern, "udat_toPattern"); I(datGetSymbols, "udat_getSymbols");
    I(datCountSymbols, "udat_countSymbols");
    I(dtpgOpen, "udatpg_open"); I(dtpgClose, "udatpg_close"); I(dtpgBest, "udatpg_getBestPattern");
    I(calOpen, "ucal_open"); I(calClose, "ucal_close"); I(calSetMillis, "ucal_setMillis"); I(calGetMillis, "ucal_getMillis");
    I(calGet, "ucal_get"); I(calSet, "ucal_set"); I(calClear, "ucal_clear"); I(calAdd, "ucal_add"); I(calRoll, "ucal_roll");
    I(calGetLimit, "ucal_getLimit"); I(calSetAttr, "ucal_setAttribute"); I(calGetAttr, "ucal_getAttribute");
    I(calTZName, "ucal_getTimeZoneDisplayName");
    I(numfOpen, "unumf_openForSkeletonAndLocale"); I(numfClose, "unumf_close"); I(numfOpenResult, "unumf_openResult");
    I(numfCloseResult, "unumf_closeResult"); I(numfFormatDouble, "unumf_formatDouble"); I(numfResultToString, "unumf_resultToString");
    I(numOpen, "unum_open"); I(numClose, "unum_close"); I(numFormatDouble, "unum_formatDouble"); I(numParseDouble, "unum_parseDouble");
    I(numToPattern, "unum_toPattern"); I(numGetSymbol, "unum_getSymbol"); I(numSetTextAttr, "unum_setTextAttribute");
    I(relOpen, "ureldatefmt_open"); I(relClose, "ureldatefmt_close"); I(relFormat, "ureldatefmt_format");
    I(relFormatNumeric, "ureldatefmt_formatNumeric");
    I(itvOpen, "udtitvfmt_open"); I(itvClose, "udtitvfmt_close"); I(itvFormat, "udtitvfmt_format");
    I(listOpen, "ulistfmt_openForType"); I(listClose, "ulistfmt_close"); I(listFormat, "ulistfmt_format");
    I(plOpen, "uplrules_openForType"); I(plClose, "uplrules_close"); I(plSelect, "uplrules_select");
#undef C
#undef I
    /* the core every caller needs; the newer APIs (unumf 62, ulistfmt_openForType 67) are checked where used */
    if (U.strFromUTF8 && U.strToUTF8 && U.colOpen && U.colStrcoll && U.datOpen && U.datFormat && U.calOpen && U.calGet && U.numOpen)
        icu_version = v;
}

static int ready(void) { pthread_once(&once, load); return icu_version; }

/* ---- UTF-8 <-> UTF-16 ---- */
typedef struct { UChar *p; int32_t n; UChar small[256]; } ustr;
static int to_u(ustr *s, const char *utf8) {
    UErr e = 0;
    s->p = s->small; s->n = 0;
    if (!utf8) return 1;
    U.strFromUTF8(s->small, 256, &s->n, utf8, -1, &e);
    if (e == 15 /* U_BUFFER_OVERFLOW_ERROR */ || s->n >= 256) {
        e = 0;
        s->p = malloc(((size_t)s->n + 1) * sizeof(UChar));
        U.strFromUTF8(s->p, s->n + 1, &s->n, utf8, -1, &e);
    }
    return !FAIL(e);
}
static void u_free(ustr *s) { if (s->p != s->small) free(s->p); }
static int from_u(const UChar *u, int32_t n, char *out, int cap) {
    UErr e = 0;
    int32_t len = 0;
    if (cap <= 0) return -1;
    U.strToUTF8(out, cap, &len, u, n, &e);
    if (FAIL(e) || len >= cap) { out[0] = 0; return FAIL(e) && e != 15 ? -1 : -2 - len; }   /* -2-len: too small */
    out[len] = 0;
    return len;
}
#define UBUF 1024

/* ---- small caches of opened ICU objects (keyed by their creation arguments) ---- */
typedef struct { char key[320]; void *obj; void (*close)(void *); unsigned long used; } entry;
static entry cache[48];
static unsigned long tick;
static void *cache_get(const char *key) {
    for (int i = 0; i < 48; i++) if (cache[i].obj && !strcmp(cache[i].key, key)) { cache[i].used = ++tick; return cache[i].obj; }
    return NULL;
}
static void cache_put(const char *key, void *obj, void (*close)(void *)) {
    int victim = 0;
    for (int i = 0; i < 48; i++) {
        if (!cache[i].obj) { victim = i; break; }
        if (cache[i].used < cache[victim].used) victim = i;
    }
    if (cache[victim].obj) cache[victim].close(cache[victim].obj);
    snprintf(cache[victim].key, sizeof cache[victim].key, "%s", key);
    cache[victim].obj = obj; cache[victim].close = close; cache[victim].used = ++tick;
}

int isim_icu_version(void) { return ready(); }

/* ---- collation (NSString compare:options:range:locale:, localizedCompare:, localizedStandardCompare:) ----
 * flags: 1 case-insensitive, 2 diacritic-insensitive, 4 numeric, 8 width-insensitive. Returns -1, 0, 1, or -2. */
int isim_icu_collate(const char *locale, const uint16_t *a, int alen, const uint16_t *b, int blen, int flags) {
    if (!ready()) return -2;
    char key[320];
    snprintf(key, sizeof key, "col|%s|%d", locale ? locale : "", flags);
    pthread_mutex_lock(&lock);
    UCollator *c = cache_get(key);
    if (!c) {
        UErr e = 0;
        c = U.colOpen(locale ? locale : "", &e);
        if (FAIL(e) || !c) { pthread_mutex_unlock(&lock); return -2; }
        int strength = (flags & 2) ? 0 /* primary */ : (flags & 1) ? 1 /* secondary */ : (flags & 8) ? 2 : 2;   /* tertiary */
        U.colSetAttr(c, 5 /* UCOL_STRENGTH */, strength, &e);
        if ((flags & 2) && !(flags & 1)) U.colSetAttr(c, 3 /* UCOL_CASE_LEVEL */, 17 /* ON */, &e);
        if (flags & 4) U.colSetAttr(c, 7 /* UCOL_NUMERIC_COLLATION */, 17, &e);
        U.colSetAttr(c, 4 /* UCOL_NORMALIZATION_MODE */, 17, &e);
        cache_put(key, c, (void (*)(void *))U.colClose);
    }
    int r = U.colStrcoll(c, a, alen, b, blen);
    pthread_mutex_unlock(&lock);
    return r < 0 ? -1 : r > 0 ? 1 : 0;
}

/* ---- dates ---- */
static UDateFormat *date_fmt(const char *locale, const char *tz, const char *pattern, int dateStyle, int timeStyle) {
    char key[320];
    snprintf(key, sizeof key, "dat|%s|%s|%d|%d|%s", locale ? locale : "", tz ? tz : "", dateStyle, timeStyle, pattern ? pattern : "");
    UDateFormat *f = cache_get(key);
    if (f) return f;
    ustr z, p;
    UErr e = 0;
    to_u(&z, tz); to_u(&p, pattern);
    f = pattern ? U.datOpen(-2 /* UDAT_PATTERN */, -2, locale, tz ? z.p : NULL, tz ? z.n : 0, p.p, p.n, &e)
                : U.datOpen(timeStyle, dateStyle, locale, tz ? z.p : NULL, tz ? z.n : 0, NULL, 0, &e);
    u_free(&z); u_free(&p);
    if (FAIL(e) || !f) return NULL;
    cache_put(key, f, (void (*)(void *))U.datClose);
    return f;
}

/* format `ms` with a UTS #35 pattern (Foundation's dateFormat) */
int isim_icu_date_format(const char *locale, const char *tz, const char *pattern, double ms, char *out, int cap) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UDateFormat *f = date_fmt(locale, tz, pattern, -2, -2);
    int r = -1;
    if (f) {
        UChar buf[UBUF];
        UErr e = 0;
        int32_t n = U.datFormat(f, ms, buf, UBUF, NULL, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* parse `text` with a pattern; strict unless lenient. Returns 1 and sets *ms when the whole text parsed, else 0 */
int isim_icu_date_parse(const char *locale, const char *tz, const char *pattern, const char *text, int lenient, double *ms) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UDateFormat *f = date_fmt(locale, tz, pattern, -2, -2);
    int ok = -1;
    if (f) {
        ustr t;
        UErr e = 0;
        int32_t pos = 0;
        to_u(&t, text);
        U.datSetLenient(f, lenient ? 1 : 0);
        double d = U.datParse(f, t.p, t.n, &pos, &e);
        U.datSetLenient(f, 1);
        ok = !FAIL(e) && (lenient || pos == t.n);
        if (ok) *ms = d;
        u_free(&t);
    }
    pthread_mutex_unlock(&lock);
    return ok;
}

/* the pattern for a template (skeleton != NULL, dateFormatFromTemplate) or for date / time styles (0 full .. 3 short,
 * -1 none; NSDateFormatterStyle order is reversed by the caller) */
int isim_icu_date_pattern(const char *locale, const char *skeleton, int dateStyle, int timeStyle, char *out, int cap) {
    if (!ready()) return -1;
    UChar buf[UBUF];
    UErr e = 0;
    int32_t n = -1;
    pthread_mutex_lock(&lock);
    if (skeleton) {
        char key[320];
        snprintf(key, sizeof key, "dtpg|%s", locale ? locale : "");
        UDTPG *g = cache_get(key);
        if (!g && U.dtpgOpen && (g = U.dtpgOpen(locale, &e)) && !FAIL(e)) cache_put(key, g, (void (*)(void *))U.dtpgClose);
        if (g && !FAIL(e)) {
            ustr s;
            to_u(&s, skeleton);
            n = U.dtpgBest(g, s.p, s.n, buf, UBUF, &e);
            u_free(&s);
        }
    } else {
        UDateFormat *f = date_fmt(locale, "UTC", NULL, dateStyle, timeStyle);
        if (f) n = U.datToPattern(f, 0, buf, UBUF, &e);
    }
    pthread_mutex_unlock(&lock);
    return n < 0 || FAIL(e) ? -1 : from_u(buf, n, out, cap);
}

/* date format symbols, newline-separated (UDateFormatSymbolType: 0 eras, 1 months, 2 short months, 3 weekdays (Sunday
 * first), 4 short weekdays, 5 AM/PM, 7 era names, 8 narrow months, 9 narrow weekdays, 10..15 standalone forms,
 * 16 quarters, 17 short quarters, 18/19 standalone quarters, 20 shorter weekdays) */
int isim_icu_date_symbols(const char *locale, int type, char *out, int cap) {
    if (!ready() || !U.datGetSymbols) return -1;
    pthread_mutex_lock(&lock);
    UDateFormat *f = date_fmt(locale, "UTC", NULL, 2, 2);
    int len = -1;
    if (f) {
        int count = U.datCountSymbols(f, type);
        len = 0; out[0] = 0;
        for (int i = 0; i < count; i++) {
            UChar buf[256];
            UErr e = 0;
            int32_t n = U.datGetSymbols(f, type, i, buf, 256, &e);
            if (FAIL(e) || ((type == 3 || type == 4 || type == 9 || (type >= 13 && type <= 15) || type == 20) && i == 0)) continue;   /* weekdays are 1-based */
            if (len && len + 1 < cap) out[len++] = '\n';
            int w = from_u(buf, n, out + len, cap - len);
            if (w < 0) { len = -1; break; }
            len += w;
        }
    }
    pthread_mutex_unlock(&lock);
    return len;
}

/* ---- calendars (Calendar / NSCalendar for every identifier) ----
 * fields (ISIM_ICU_CAL_*, 16 ints): era, year (in the calendar's era), month (1-based), day, hour, minute, second,
 * millisecond, weekday (1 = Sunday), weekdayOrdinal, weekOfMonth, weekOfYear, yearForWeekOfYear, dayOfYear,
 * isLeapMonth, extendedYear. */
enum { F_ERA, F_YEAR, F_MONTH, F_DAY, F_HOUR, F_MINUTE, F_SECOND, F_MS, F_WEEKDAY, F_WDORD, F_WOM, F_WOY, F_YWOY, F_DOY, F_LEAP, F_EXTYEAR, F_N };
static const int ucal_field[F_N] = { 0, 1, 2, 5, 11, 12, 13, 14, 7, 8, 4, 3, 17, 6, 22, 19 };

static UCal *calendar(const char *calLocale, const char *tz, int firstWeekday, int minDays) {
    char key[320];
    snprintf(key, sizeof key, "cal|%s|%s|%d|%d", calLocale ? calLocale : "", tz ? tz : "", firstWeekday, minDays);
    UCal *c = cache_get(key);
    if (c) return c;
    ustr z;
    UErr e = 0;
    to_u(&z, tz ? tz : "UTC");
    c = U.calOpen(z.p, z.n, calLocale, 0 /* UCAL_TRADITIONAL: the locale's @calendar */, &e);
    u_free(&z);
    if (FAIL(e) || !c) return NULL;
    if (firstWeekday > 0) U.calSetAttr(c, 1 /* UCAL_FIRST_DAY_OF_WEEK */, firstWeekday);
    if (minDays > 0) U.calSetAttr(c, 2 /* UCAL_MINIMAL_DAYS_IN_FIRST_WEEK */, minDays);
    cache_put(key, c, (void (*)(void *))U.calClose);
    return c;
}
static void get_fields(UCal *c, int *f) {
    UErr e = 0;
    for (int i = 0; i < F_N; i++) f[i] = U.calGet(c, ucal_field[i], &e);
    f[F_MONTH] += 1;
}

/* calLocale: e.g. "en_US@calendar=hebrew". Fills fields for `ms`. Returns 0 or -1. */
int isim_icu_cal_fields(const char *calLocale, const char *tz, int firstWeekday, int minDays, double ms, int *fields) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UCal *c = calendar(calLocale, tz, firstWeekday, minDays);
    int r = -1;
    if (c) {
        UErr e = 0;
        U.calSetMillis(c, ms, &e);
        if (!FAIL(e)) { get_fields(c, fields); r = 0; }
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* the date for the fields whose bit is set in mask (bit i = field i); unset fields take their minimum, like
 * Calendar.date(from:). Lenient: day 32 rolls into the next month, as on iOS. */
int isim_icu_cal_date(const char *calLocale, const char *tz, int firstWeekday, int minDays, const int *fields, unsigned mask, double *ms) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UCal *c = calendar(calLocale, tz, firstWeekday, minDays);
    int r = -1;
    if (c) {
        UErr e = 0;
        U.calClear(c);
        for (int i = 0; i < F_N; i++) {
            if (!(mask & (1u << i))) continue;
            U.calSet(c, ucal_field[i], i == F_MONTH ? fields[i] - 1 : fields[i]);
        }
        double d = U.calGetMillis(c, &e);
        if (!FAIL(e)) { *ms = d; r = 0; }
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* add (roll = 0) or roll (roll = 1, wrapping within the larger field) `amount` of field (F_* index) */
int isim_icu_cal_add(const char *calLocale, const char *tz, int firstWeekday, int minDays, double ms, int field, int amount, int roll, double *out) {
    if (!ready() || field < 0 || field >= F_N) return -1;
    pthread_mutex_lock(&lock);
    UCal *c = calendar(calLocale, tz, firstWeekday, minDays);
    int r = -1;
    if (c) {
        UErr e = 0;
        U.calSetMillis(c, ms, &e);
        if (roll) U.calRoll(c, ucal_field[field], amount, &e); else U.calAdd(c, ucal_field[field], amount, &e);
        double d = U.calGetMillis(c, &e);
        if (!FAIL(e)) { *out = d; r = 0; }
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* a field's limit at `ms`: which 0 minimum, 1 maximum, 2 greatest minimum, 3 least maximum, 4 actual minimum,
 * 5 actual maximum (UCalendarLimitType). Months are 1-based. */
int isim_icu_cal_limit(const char *calLocale, const char *tz, int firstWeekday, int minDays, double ms, int field, int which, int *value) {
    if (!ready() || field < 0 || field >= F_N) return -1;
    pthread_mutex_lock(&lock);
    UCal *c = calendar(calLocale, tz, firstWeekday, minDays);
    int r = -1;
    if (c) {
        UErr e = 0;
        U.calSetMillis(c, ms, &e);
        int v = U.calGetLimit(c, ucal_field[field], which, &e);
        if (!FAIL(e)) { *value = field == F_MONTH ? v + 1 : v; r = 0; }
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* the locale's first weekday (1 = Sunday) and minimum days in the first week (CLDR weekData) */
int isim_icu_week_data(const char *locale, int *firstWeekday, int *minDays) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UCal *c = calendar(locale, "UTC", 0, 0);
    if (c) { *firstWeekday = U.calGetAttr(c, 1); *minDays = U.calGetAttr(c, 2); }
    pthread_mutex_unlock(&lock);
    return c ? 0 : -1;
}

/* time zone display name: type 0 standard, 1 short standard, 2 daylight, 3 short daylight; generic names are not
 * in this C API */
int isim_icu_tz_name(const char *tz, const char *locale, int type, char *out, int cap) {
    if (!ready() || !U.calTZName) return -1;
    pthread_mutex_lock(&lock);
    UCal *c = calendar(locale, tz, 0, 0);
    int r = -1;
    if (c) {
        UChar buf[256];
        UErr e = 0;
        int32_t n = U.calTZName(c, type, locale, buf, 256, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* ---- numbers ---- */
/* format with an ICU number skeleton ("currency/EUR", "percent precision-integer", "measure-unit/length-meter
 * unit-width-full-name", "compact-short", ...; ICU 62+) */
int isim_icu_number_skeleton(const char *locale, const char *skeleton, double v, char *out, int cap) {
    if (!ready() || !U.numfOpen) return -1;
    char key[320];
    snprintf(key, sizeof key, "numf|%s|%s", locale ? locale : "", skeleton);
    pthread_mutex_lock(&lock);
    UNumFormatter *f = cache_get(key);
    if (!f) {
        ustr s;
        UErr e = 0;
        to_u(&s, skeleton);
        f = U.numfOpen(s.p, s.n, locale, &e);
        u_free(&s);
        if (FAIL(e) || !f) { pthread_mutex_unlock(&lock); return -1; }
        cache_put(key, f, (void (*)(void *))U.numfClose);
    }
    int r = -1;
    UErr e = 0;
    UNumResult *res = U.numfOpenResult(&e);
    if (res) {
        U.numfFormatDouble(f, v, res, &e);
        UChar buf[UBUF];
        int32_t n = U.numfResultToString(res, buf, UBUF, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
        U.numfCloseResult(res);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

static UNumFmt *num_fmt(const char *locale, int style, const char *currency) {
    char key[320];
    snprintf(key, sizeof key, "num|%s|%d|%s", locale ? locale : "", style, currency ? currency : "");
    UNumFmt *f = cache_get(key);
    if (f) return f;
    UErr e = 0;
    f = U.numOpen(style, NULL, 0, locale, NULL, &e);
    if (FAIL(e) || !f) return NULL;
    if (currency && *currency) {
        ustr c;
        to_u(&c, currency);
        U.numSetTextAttr(f, 5 /* UNUM_CURRENCY_CODE */, c.p, c.n, &e);
        u_free(&c);
    }
    cache_put(key, f, (void (*)(void *))U.numClose);
    return f;
}

/* UNumberFormatStyle: 1 decimal, 2 currency, 3 percent, 4 scientific, 5 spell-out, 6 ordinal, 7 duration,
 * 10 currency ISO code, 11 currency plural, 12 accounting, 14 compact short, 15 compact long */
int isim_icu_number_format(const char *locale, int style, const char *currency, double v, char *out, int cap) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UNumFmt *f = num_fmt(locale, style, currency);
    int r = -1;
    if (f) {
        UChar buf[UBUF];
        UErr e = 0;
        int32_t n = U.numFormatDouble(f, v, buf, UBUF, NULL, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* parse with a style (as above); 1 when the whole text parsed */
int isim_icu_number_parse(const char *locale, int style, const char *currency, const char *text, double *v) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UNumFmt *f = num_fmt(locale, style, currency);
    int ok = -1;
    if (f) {
        ustr t;
        UErr e = 0;
        int32_t pos = 0;
        to_u(&t, text);
        double d = U.numParseDouble(f, t.p, t.n, &pos, &e);
        ok = !FAIL(e) && pos == t.n;
        if (ok) *v = d;
        u_free(&t);
    }
    pthread_mutex_unlock(&lock);
    return ok;
}

/* the style's pattern (unum_toPattern), e.g. "#,##0.00 ¤" */
int isim_icu_number_pattern(const char *locale, int style, char *out, int cap) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UNumFmt *f = num_fmt(locale, style, NULL);
    int r = -1;
    if (f) {
        UChar buf[256];
        UErr e = 0;
        int32_t n = U.numToPattern(f, 0, buf, 256, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* a number symbol (UNumberFormatSymbol: 0 decimal separator, 1 grouping separator, 3 percent, 4 zero digit,
 * 6 minus, 7 plus, 8 currency symbol, 9 international currency symbol, 10 monetary decimal separator, 11 exponent,
 * 12 per mille, 14 infinity, 15 NaN, 17 monetary grouping separator) */
int isim_icu_number_symbol(const char *locale, int symbol, char *out, int cap) {
    if (!ready()) return -1;
    pthread_mutex_lock(&lock);
    UNumFmt *f = num_fmt(locale, symbol == 8 || symbol == 9 || symbol == 10 || symbol == 17 ? 2 : 1, NULL);
    int r = -1;
    if (f) {
        UChar buf[64];
        UErr e = 0;
        int32_t n = U.numGetSymbol(f, symbol, buf, 64, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* currency data: kind 0 symbol, 1 long name, 2 narrow symbol, 3 plural name for `count` ("one", "other"),
 * 4 the locale's currency code (code ignored), 5 default fraction digits (written as text) */
int isim_icu_currency(const char *locale, const char *code, int kind, const char *count, char *out, int cap) {
    if (!ready()) return -1;
    UErr e = 0;
    if (kind == 4) {
        UChar buf[8];
        int32_t n = U.currForLocale(locale, buf, 8, &e);
        return FAIL(e) || n <= 0 ? -1 : from_u(buf, n, out, cap);
    }
    if (!code || strlen(code) != 3) return -1;
    UChar iso[4] = { (UChar)code[0], (UChar)code[1], (UChar)code[2], 0 };
    if (kind == 5) return U.currFractionDigits ? snprintf(out, (size_t)cap, "%d", U.currFractionDigits(iso, &e)) : -1;
    int8_t choice = 0;
    int32_t n = 0;
    const UChar *s = kind == 3 ? (U.currPluralName ? U.currPluralName(iso, locale, &choice, count ? count : "other", &n, &e) : NULL)
                               : U.currName(iso, locale, kind == 1 ? 1 : kind == 2 ? 2 : 0, &choice, &n, &e);
    return !s || FAIL(e) ? -1 : from_u(s, n, out, cap);
}

/* ---- relative dates, intervals, lists, plurals ---- */
/* unit: URelativeDateTimeUnit (0 year, 1 quarter, 2 month, 3 week, 4 day, 5 hour, 6 minute, 7 second, 8..14 Sunday..
 * Saturday); width 0 long, 1 short, 2 narrow; numeric: always "in 1 day" instead of "tomorrow" */
int isim_icu_relative(const char *locale, double offset, int unit, int width, int numeric, char *out, int cap) {
    if (!ready() || !U.relOpen) return -1;
    char key[320];
    snprintf(key, sizeof key, "rel|%s|%d", locale ? locale : "", width);
    pthread_mutex_lock(&lock);
    URelFmt *f = cache_get(key);
    UErr e = 0;
    if (!f) {
        f = U.relOpen(locale, NULL, width, 0x100 /* UDISPCTX_CAPITALIZATION_NONE */, &e);
        if (FAIL(e) || !f) { pthread_mutex_unlock(&lock); return -1; }
        cache_put(key, f, (void (*)(void *))U.relClose);
    }
    UChar buf[256];
    int32_t n = numeric ? U.relFormatNumeric(f, offset, unit, buf, 256, &e) : U.relFormat(f, offset, unit, buf, 256, &e);
    pthread_mutex_unlock(&lock);
    return FAIL(e) ? -1 : from_u(buf, n, out, cap);
}

/* a date interval with a skeleton ("yMMMd", "jm", ...) */
int isim_icu_interval(const char *locale, const char *tz, const char *skeleton, double from, double to, char *out, int cap) {
    if (!ready() || !U.itvOpen) return -1;
    char key[320];
    snprintf(key, sizeof key, "itv|%s|%s|%s", locale ? locale : "", tz ? tz : "", skeleton);
    pthread_mutex_lock(&lock);
    UItvFmt *f = cache_get(key);
    UErr e = 0;
    if (!f) {
        ustr s, z;
        to_u(&s, skeleton); to_u(&z, tz ? tz : "UTC");
        f = U.itvOpen(locale, s.p, s.n, z.p, z.n, &e);
        u_free(&s); u_free(&z);
        if (FAIL(e) || !f) { pthread_mutex_unlock(&lock); return -1; }
        cache_put(key, f, (void (*)(void *))U.itvClose);
    }
    UChar buf[UBUF];
    int32_t n = U.itvFormat(f, from, to, buf, UBUF, NULL, &e);
    pthread_mutex_unlock(&lock);
    return FAIL(e) ? -1 : from_u(buf, n, out, cap);
}

/* items separated by '\n'; type 0 and, 1 or, 2 units; width 0 wide, 1 short, 2 narrow (ICU 67+) */
int isim_icu_list(const char *locale, const char *items, int type, int width, char *out, int cap) {
    if (!ready() || !U.listOpen) return -1;
    enum { MAXI = 64 };
    ustr parts[MAXI];
    const UChar *ptrs[MAXI];
    int32_t lens[MAXI];
    int count = 0;
    const char *p = items;
    while (p && count < MAXI) {
        const char *nl = strchr(p, '\n');
        size_t len = nl ? (size_t)(nl - p) : strlen(p);
        char *tmp = strndup(p, len);
        to_u(&parts[count], tmp);
        free(tmp);
        ptrs[count] = parts[count].p; lens[count] = parts[count].n;
        count++;
        p = nl ? nl + 1 : NULL;
    }
    char key[320];
    snprintf(key, sizeof key, "list|%s|%d|%d", locale ? locale : "", type, width);
    pthread_mutex_lock(&lock);
    UListFmt *f = cache_get(key);
    UErr e = 0;
    int r = -1;
    if (!f && (f = U.listOpen(locale, type, width, &e)) && !FAIL(e)) cache_put(key, f, (void (*)(void *))U.listClose);
    if (f && !FAIL(e)) {
        UChar buf[UBUF * 2];
        int32_t n = U.listFormat(f, ptrs, lens, count, buf, UBUF * 2, &e);
        if (!FAIL(e)) r = from_u(buf, n, out, cap);
    }
    pthread_mutex_unlock(&lock);
    for (int i = 0; i < count; i++) u_free(&parts[i]);
    return r;
}

/* the plural category ("zero", "one", "two", "few", "many", "other") of n; ordinal rules when ordinal */
int isim_icu_plural(const char *locale, double n, int ordinal, char *out, int cap) {
    if (!ready() || !U.plOpen) return -1;
    char key[320];
    snprintf(key, sizeof key, "plural|%s|%d", locale ? locale : "", ordinal);
    pthread_mutex_lock(&lock);
    UPlural *f = cache_get(key);
    UErr e = 0;
    int r = -1;
    if (!f && (f = U.plOpen(locale, ordinal ? 1 : 0, &e)) && !FAIL(e)) cache_put(key, f, (void (*)(void *))U.plClose);
    if (f && !FAIL(e)) {
        UChar buf[16];
        int32_t len = U.plSelect(f, n, buf, 16, &e);
        if (!FAIL(e)) r = from_u(buf, len, out, cap);
    }
    pthread_mutex_unlock(&lock);
    return r;
}

/* ---- display names and case mapping ---- */
/* kind 0 locale identifier, 1 language code, 2 region code, 3 script code, 4 calendar identifier (ICU name),
 * 5 currency code (long name), named in `displayLocale` */
int isim_icu_display_name(const char *displayLocale, const char *code, int kind, char *out, int cap) {
    if (!ready()) return -1;
    if (kind == 5) return isim_icu_currency(displayLocale, code, 1, NULL, out, cap);
    UChar buf[256];
    UErr e = 0;
    int32_t n;
    char loc[96];
    switch (kind) {
    case 0: n = U.locDisplayName(code, displayLocale, buf, 256, &e); break;
    case 1: n = U.locDisplayLanguage(code, displayLocale, buf, 256, &e); break;
    case 2: snprintf(loc, sizeof loc, "und_%s", code); n = U.locDisplayCountry(loc, displayLocale, buf, 256, &e); break;
    case 3: snprintf(loc, sizeof loc, "und_%s", code); n = U.locDisplayScript(loc, displayLocale, buf, 256, &e); break;
    case 4:
        if (!U.locDisplayKeywordValue) return -1;
        snprintf(loc, sizeof loc, "und@calendar=%s", code);
        n = U.locDisplayKeywordValue(loc, "calendar", displayLocale, buf, 256, &e);
        break;
    default: return -1;
    }
    if (FAIL(e) || e == -127 /* U_USING_DEFAULT_WARNING */ || n <= 0) return -1;
    int r = from_u(buf, n, out, cap);
    return r >= 0 && !strcmp(out, code) ? -1 : r;     /* an unknown code: ICU echoes it */
}

/* kind 0 upper, 1 lower, 2 title case, with the locale's rules (Turkish dotted i, Greek final sigma, Dutch IJ) */
int isim_icu_case(const char *locale, const char *s, int kind, char *out, int cap) {
    if (!ready()) return -1;
    ustr in;
    to_u(&in, s);
    int32_t need = in.n * 3 + 16;
    UChar *buf = malloc((size_t)need * sizeof(UChar));
    UErr e = 0;
    int32_t n = kind == 0 ? U.toUpper(buf, need, in.p, in.n, locale, &e)
              : kind == 1 ? U.toLower(buf, need, in.p, in.n, locale, &e)
              : U.toTitle ? U.toTitle(buf, need, in.p, in.n, NULL, locale, &e) : -1;
    int r = n < 0 || FAIL(e) ? -1 : from_u(buf, n, out, cap);
    free(buf);
    u_free(&in);
    return r;
}
