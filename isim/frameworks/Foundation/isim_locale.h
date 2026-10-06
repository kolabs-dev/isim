/* isim Foundation private: built-in locale data (Locale.m) shared by the formatters (Formatters.m, Units.m).
 * A small hand-written subset of CLDR for the languages/regions isim supports; not Apple's data. */
#pragma once
#import <Foundation/Foundation.h>

typedef struct {
    const char *loc;
    const char *decimal, *group, *currencyCode, *currencySymbol;
    int hour12, metric;
    const char *dShort, *dMedium, *dLong, *dFull;   /* DateFormatter date styles */
    int minGroup;                                   /* minimum grouping digits (es/pt_PT: 2 -> "1234") */
    int indian;                                     /* 12,34,567 grouping */
    const char *currencyPattern;                    /* "¤#", "¤ #", "# ¤" (spaces are U+00A0 in output) */
    const char *percentPattern;                     /* "#%", "# %" */
    int firstWeekday;                               /* 1 Sunday, 2 Monday */
} isim_region_t;

typedef struct {
    const char *lang;
    const char *months[12], *monthsShort[12], *weekdays[7], *weekdaysShort[7], *am, *pm;
    const char *eras[2];                            /* BC, AD */
    const char *listAnd, *listOr;                   /* conjunction words; serial comma decided per region */
    const char *listSep;                            /* ", " */
    const char *dateTimeSep;                        /* between date and time in combined formats */
    /* relative/duration units, index: 0 year, 1 month, 2 week, 3 day, 4 hour, 5 minute, 6 second */
    const char *unitOne[7], *unitOther[7];          /* wide names */
    const char *unitShort[7], *unitShortOther[7];   /* "hr", "min" (short width) */
    const char *unitNarrow[7];                      /* "h", "m", "s" */
    const char *relFuture, *relPast;                /* "in %@", "%@ ago" with the counted unit */
    const char *yesterday, *today, *tomorrow, *now;
    const char *lastUnit[7], *thisUnit[7], *nextUnit[7];   /* "last week", ... (NULL: numeric) */
    int pluralZeroIsOne;                            /* fr, pt_BR: 0 and 1 take the singular */
    const char *byteUnits[6];                       /* bytes, kB, MB, GB, TB, PB */
    const char *zeroBytes;                          /* "Zero" */
    const char *const *relOther;                    /* plural unit names in relative phrases when they differ (de: "Tagen") */
} isim_lang_t;

const isim_region_t *isim_region(NSString *localeIdentifier);
const isim_lang_t *isim_lang(NSString *languageCode);
NSString *isim_locale_lang(NSLocale *locale);           /* "en" */
NSString *isim_locale_ident(NSLocale *locale);          /* "en_US" (empty -> current) */
BOOL isim_uses_12h(NSLocale *locale);
/* pattern for a date/time skeleton ("yMMMd", "jmm", "yMMMMEEEEdjmmss") in the locale */
NSString *isim_date_pattern(NSString *skeleton, NSLocale *locale);
/* DateFormatter style patterns */
NSString *isim_style_pattern(NSInteger dateStyle, NSInteger timeStyle, NSLocale *locale);
/* plural: is n "one" in the language (visible fraction digits count) */
BOOL isim_plural_one(NSString *lang, double n, int fractionDigits);
/* currency symbol for an ISO code in a locale; decimals for the currency */
NSString *isim_currency_symbol(NSString *code, NSLocale *locale);
NSString *isim_currency_name(NSString *code, BOOL plural);
int isim_currency_digits(NSString *code);
