/* isim Foundation (ARC): locale data from the host's ICU (isim_host's isim_icu_*, runtime/host_icu.c).
 * Apple's Foundation formats with ICU and CLDR as well. isim keeps its built-in tables (Locale.m) for the languages
 * and regions they cover, which mirror iOS's own strings (e.g. "Zero KB"), and takes every other locale from ICU:
 * region data (separators, currency, date and number patterns, week data) and language data (month and weekday
 * names, units, relative phrases, list words) are built from ICU here into the same structs the formatters use.
 * Calendars other than Gregorian, collation, spell-out, plural rules, currency and display names come straight from
 * ICU for every locale. Without ICU on the host, everything falls back to the built-in tables. */
#import <Foundation/Foundation.h>
#include <isim_host.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include "isim_locale.h"

enum { BUF = 2048 };

BOOL isim_icu_on(void) {
    static int on = -1;
    if (on < 0) on = isim_icu_version() > 0;
    return on;
}

NSString *isim_icu_locale_id(NSLocale *l) {
    NSString *i = l.localeIdentifier.length ? l.localeIdentifier : NSLocale.currentLocale.localeIdentifier;
    return i.length ? i : @"en_US";
}

static NSString *str(int n, const char *b) { return n >= 0 ? @(b) : nil; }

NSString *isim_icu_date_format_string(NSString *locale, NSString *tz, NSString *pattern, NSDate *date) {
    char b[BUF];
    return str(isim_icu_date_format(locale.UTF8String, tz.UTF8String, pattern.UTF8String, date.timeIntervalSince1970 * 1000.0, b, BUF), b);
}
NSDate *isim_icu_date_parse_string(NSString *locale, NSString *tz, NSString *pattern, NSString *text, BOOL lenient) {
    double ms;
    if (isim_icu_date_parse(locale.UTF8String, tz.UTF8String, pattern.UTF8String, text.UTF8String, lenient, &ms) != 1) return nil;
    return [NSDate dateWithTimeIntervalSince1970:ms / 1000.0];
}
NSString *isim_icu_skeleton_pattern(NSString *locale, NSString *skeleton) {
    char b[BUF];
    return str(isim_icu_date_pattern(locale.UTF8String, skeleton.UTF8String, 0, 0, b, BUF), b);
}
/* NSDateFormatterStyle (0 none, 1 short .. 4 full) -> ICU's (3 short .. 0 full, -1 none) */
static int icu_style(NSInteger s) { return s <= 0 ? -1 : (int)(4 - s); }
NSString *isim_icu_style_pattern(NSString *locale, NSInteger dateStyle, NSInteger timeStyle) {
    char b[BUF];
    return str(isim_icu_date_pattern(locale.UTF8String, NULL, icu_style(dateStyle), icu_style(timeStyle), b, BUF), b);
}
NSArray<NSString *> *isim_icu_symbols(NSString *locale, int type) {
    char b[BUF * 2];
    NSString *s = str(isim_icu_date_symbols(locale.UTF8String, type, b, sizeof b), b);
    return s.length ? [s componentsSeparatedByString:@"\n"] : nil;
}
NSString *isim_icu_number(NSString *locale, NSString *skeleton, double v) {
    char b[BUF];
    return str(isim_icu_number_skeleton(locale.UTF8String, skeleton.UTF8String, v, b, BUF), b);
}
NSString *isim_icu_number_style(NSString *locale, int style, NSString *currency, double v) {
    char b[BUF];
    return str(isim_icu_number_format(locale.UTF8String, style, currency.UTF8String, v, b, BUF), b);
}
NSString *isim_icu_relative_string(NSString *locale, double offset, int unit, int width, BOOL numeric) {
    char b[BUF];
    return str(isim_icu_relative(locale.UTF8String, offset, unit, width, numeric, b, BUF), b);
}
NSString *isim_icu_interval_string(NSString *locale, NSString *tz, NSString *skeleton, NSDate *from, NSDate *to) {
    char b[BUF];
    return str(isim_icu_interval(locale.UTF8String, tz.UTF8String, skeleton.UTF8String, from.timeIntervalSince1970 * 1000.0,
                                 to.timeIntervalSince1970 * 1000.0, b, BUF), b);
}
NSString *isim_icu_list_string(NSString *locale, NSArray<NSString *> *items, int type, int width) {
    char b[BUF * 2];
    NSMutableArray *clean = [NSMutableArray array];
    for (NSString *s in items) [clean addObject:[s stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return str(isim_icu_list(locale.UTF8String, [clean componentsJoinedByString:@"\n"].UTF8String, type, width, b, sizeof b), b);
}
NSString *isim_icu_plural_category(NSString *locale, double n, BOOL ordinal) {
    char b[32];
    return str(isim_icu_plural(locale.UTF8String, n, ordinal, b, sizeof b), b);
}
NSString *isim_icu_display(NSString *displayLocale, NSString *code, int kind) {
    char b[512];
    return code.length ? str(isim_icu_display_name(displayLocale.UTF8String, code.UTF8String, kind, b, sizeof b), b) : nil;
}
NSString *isim_icu_currency_string(NSString *locale, NSString *code, int kind, NSString *count) {
    char b[256];
    return str(isim_icu_currency(locale.UTF8String, code.UTF8String, kind, count.UTF8String, b, sizeof b), b);
}
NSString *isim_icu_case_string(NSString *locale, NSString *s, int kind) {
    if (!s.length) return s;
    size_t cap = strlen(s.UTF8String) * 3 + 16;
    char *b = malloc(cap);
    NSString *r = str(isim_icu_case(locale.UTF8String, s.UTF8String, kind, b, (int)cap), b);
    free(b);
    return r;
}

/* ICU unit identifiers for isim's unit keys (NSUnit class property names) */
NSString *isim_icu_unit_id(NSString *key) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"kilometers": @"length-kilometer", @"meters": @"length-meter", @"centimeters": @"length-centimeter",
            @"millimeters": @"length-millimeter", @"micrometers": @"length-micrometer", @"nanometers": @"length-nanometer",
            @"picometers": @"length-picometer", @"decimeters": @"length-decimeter", @"miles": @"length-mile", @"yards": @"length-yard",
            @"feet": @"length-foot", @"inches": @"length-inch", @"nauticalMiles": @"length-nautical-mile", @"lightyears": @"length-light-year",
            @"parsecs": @"length-parsec", @"astronomicalUnits": @"length-astronomical-unit", @"furlongs": @"length-furlong",
            @"fathoms": @"length-fathom", @"scandinavianMiles": @"length-mile-scandinavian",
            @"kilograms": @"mass-kilogram", @"grams": @"mass-gram", @"milligrams": @"mass-milligram", @"micrograms": @"mass-microgram",
            @"metricTons": @"mass-tonne", @"shortTons": @"mass-ton", @"pounds": @"mass-pound", @"ounces": @"mass-ounce",
            @"stones": @"mass-stone", @"carats": @"mass-carat", @"ouncesTroy": @"mass-ounce-troy",
            @"liters": @"volume-liter", @"milliliters": @"volume-milliliter", @"centiliters": @"volume-centiliter",
            @"deciliters": @"volume-deciliter", @"kiloliters": @"volume-kiloliter", @"megaliters": @"volume-megaliter",
            @"cubicMeters": @"volume-cubic-meter", @"cubicCentimeters": @"volume-cubic-centimeter", @"cubicKilometers": @"volume-cubic-kilometer",
            @"cubicInches": @"volume-cubic-inch", @"cubicFeet": @"volume-cubic-foot", @"cubicYards": @"volume-cubic-yard",
            @"cubicMiles": @"volume-cubic-mile", @"acreFeet": @"volume-acre-foot", @"gallons": @"volume-gallon",
            @"imperialGallons": @"volume-gallon-imperial", @"quarts": @"volume-quart", @"pints": @"volume-pint", @"cups": @"volume-cup",
            @"fluidOunces": @"volume-fluid-ounce", @"tablespoons": @"volume-tablespoon", @"teaspoons": @"volume-teaspoon",
            @"metricCups": @"volume-cup-metric", @"bushels": @"volume-bushel",
            @"celsius": @"temperature-celsius", @"fahrenheit": @"temperature-fahrenheit", @"kelvin": @"temperature-kelvin",
            @"kilometersPerHour": @"speed-kilometer-per-hour", @"milesPerHour": @"speed-mile-per-hour",
            @"metersPerSecond": @"speed-meter-per-second", @"knots": @"speed-knot",
            @"hours": @"duration-hour", @"minutes": @"duration-minute", @"seconds": @"duration-second",
            @"milliseconds": @"duration-millisecond", @"microseconds": @"duration-microsecond", @"nanoseconds": @"duration-nanosecond",
            @"squareMeters": @"area-square-meter", @"squareKilometers": @"area-square-kilometer", @"squareCentimeters": @"area-square-centimeter",
            @"squareMillimeters": @"area-square-millimeter", @"squareInches": @"area-square-inch", @"squareFeet": @"area-square-foot",
            @"squareYards": @"area-square-yard", @"squareMiles": @"area-square-mile", @"acres": @"area-acre", @"hectares": @"area-hectare",
            @"degrees": @"angle-degree", @"radians": @"angle-radian", @"arcMinutes": @"angle-arc-minute", @"arcSeconds": @"angle-arc-second",
            @"revolutions": @"angle-revolution",
            @"joules": @"energy-joule", @"kilojoules": @"energy-kilojoule", @"calories": @"energy-calorie",
            @"kilocalories": @"energy-kilocalorie", @"kilowattHours": @"energy-kilowatt-hour",
            @"watts": @"power-watt", @"kilowatts": @"power-kilowatt", @"megawatts": @"power-megawatt", @"gigawatts": @"power-gigawatt",
            @"milliwatts": @"power-milliwatt", @"horsepower": @"power-horsepower",
            @"hectopascals": @"pressure-hectopascal", @"kilopascals": @"pressure-kilopascal", @"megapascals": @"pressure-megapascal",
            @"bars": @"pressure-bar", @"millibars": @"pressure-millibar", @"inchesOfMercury": @"pressure-inch-ofhg",
            @"millimetersOfMercury": @"pressure-millimeter-ofhg", @"poundsForcePerSquareInch": @"pressure-pound-force-per-square-inch",
            @"hertz": @"frequency-hertz", @"kilohertz": @"frequency-kilohertz", @"megahertz": @"frequency-megahertz",
            @"gigahertz": @"frequency-gigahertz",
            @"volts": @"electric-volt", @"amperes": @"electric-ampere", @"milliamperes": @"electric-milliampere", @"ohms": @"electric-ohm",
            @"lux": @"light-lux", @"litersPer100Kilometers": @"consumption-liter-per-100-kilometer",
            @"milesPerGallon": @"consumption-mile-per-gallon", @"milesPerImperialGallon": @"consumption-mile-per-gallon-imperial",
            @"bytes": @"digital-byte", @"kilobytes": @"digital-kilobyte", @"megabytes": @"digital-megabyte", @"gigabytes": @"digital-gigabyte",
            @"terabytes": @"digital-terabyte", @"petabytes": @"digital-petabyte", @"bits": @"digital-bit", @"kilobits": @"digital-kilobit",
            @"megabits": @"digital-megabit", @"gigabits": @"digital-gigabit",
            @"gravity": @"acceleration-g-force", @"metersPerSecondSquared": @"acceleration-meter-per-square-second",
        };
    });
    return key ? map[key] : nil;
}

/* "5 kilometers" for `number` (already formatted): ICU's phrase for the value with ICU's own number replaced by it.
 * width 0 narrow, 1 short, 2 full name */
NSString *isim_icu_unit_phrase(NSString *locale, NSString *unitID, double value, NSString *number, int width) {
    if (!isim_icu_on() || !unitID) return nil;
    NSString *w = width == 2 ? @"unit-width-full-name" : width == 1 ? @"unit-width-short" : @"unit-width-narrow";
    NSString *phrase = isim_icu_number(locale, [NSString stringWithFormat:@"measure-unit/%@ %@ precision-unlimited", unitID, w], value);
    NSString *plain = isim_icu_number(locale, @"precision-unlimited", value);
    if (!phrase || !plain) return nil;
    if (!number) return phrase;
    NSRange r = [phrase rangeOfString:plain];
    if (r.location == NSNotFound) return phrase;
    return [phrase stringByReplacingCharactersInRange:r withString:number];
}

/* ---------------- region and language tables built from ICU ---------------- */
static pthread_mutex_t synth_lock = PTHREAD_MUTEX_INITIALIZER;
static const char *keep(NSString *s) { return strdup(s.UTF8String ?: ""); }   /* tables live for the process */

/* "¤#,##0.00" -> "¤#", "#,##0.00 ¤" -> "# ¤" (the number part becomes one '#') */
static NSString *affix_pattern(NSString *p) {
    if (!p.length) return nil;
    p = [p componentsSeparatedByString:@";"].firstObject;
    NSMutableString *out = [NSMutableString string];
    BOOL inNumber = NO, done = NO;
    for (NSUInteger i = 0; i < p.length; i++) {
        unichar c = [p characterAtIndex:i];
        BOOL num = c == '#' || c == '0' || c == ',' || c == '.' || c == '@';
        if (num) { if (!inNumber && !done) { [out appendString:@"#"]; inNumber = YES; } continue; }
        if (inNumber) { inNumber = NO; done = YES; }
        if (c != '\'') [out appendFormat:@"%C", c];
    }
    return out;
}

const isim_region_t *isim_icu_region(NSString *ident) {
    if (!isim_icu_on() || !ident.length) return NULL;
    static NSMutableDictionary<NSString *, NSValue *> *cache;
    pthread_mutex_lock(&synth_lock);
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSValue *v = cache[ident];
    if (v) { pthread_mutex_unlock(&synth_lock); return v.pointerValue; }
    pthread_mutex_unlock(&synth_lock);

    const char *loc = ident.UTF8String;
    char b[BUF];
    isim_region_t *r = calloc(1, sizeof *r);
    r->loc = keep(ident);
    NSString *dec = str(isim_icu_number_symbol(loc, 0, b, BUF), b), *grp = str(isim_icu_number_symbol(loc, 1, b, BUF), b);
    if (!dec) { free(r); return NULL; }
    r->decimal = keep(dec);
    r->group = keep(grp ?: @",");
    NSString *code = isim_icu_currency_string(ident, nil, 4, nil) ?: @"USD";
    r->currencyCode = keep(code);
    r->currencySymbol = keep(isim_icu_currency_string(ident, code, 0, nil) ?: code);
    NSString *j = isim_icu_skeleton_pattern(ident, @"j") ?: @"H";
    r->hour12 = [j rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"hK"]].location != NSNotFound;
    NSString *region = [NSLocale localeWithLocaleIdentifier:ident].countryCode ?: @"";
    r->metric = ![@[@"US", @"LR", @"MM"] containsObject:region];
    r->dShort = keep(isim_icu_style_pattern(ident, 1, 0) ?: @"y-MM-dd");
    r->dMedium = keep(isim_icu_style_pattern(ident, 2, 0) ?: @"y MMM d");
    r->dLong = keep(isim_icu_style_pattern(ident, 3, 0) ?: @"y MMMM d");
    r->dFull = keep(isim_icu_style_pattern(ident, 4, 0) ?: @"y MMMM d, EEEE");
    NSString *n4 = isim_icu_number_style(ident, 1, nil, 1234) ?: @"1,234";
    r->minGroup = grp.length && [n4 containsString:grp] ? 1 : 2;
    NSString *n7 = isim_icu_number_style(ident, 1, nil, 1234567) ?: @"";
    r->indian = grp.length && [n7 hasPrefix:[NSString stringWithFormat:@"12%@34%@", grp, grp]];
    r->currencyPattern = keep(affix_pattern(str(isim_icu_number_pattern(loc, 2, b, BUF), b)) ?: @"¤#");
    r->percentPattern = keep(affix_pattern(str(isim_icu_number_pattern(loc, 3, b, BUF), b)) ?: @"#%");
    int fw = 1, md = 1;
    isim_icu_week_data(loc, &fw, &md);
    r->firstWeekday = fw;

    pthread_mutex_lock(&synth_lock);
    if (cache[ident]) { pthread_mutex_unlock(&synth_lock); return [cache[ident] pointerValue]; }   /* another thread won */
    cache[ident] = [NSValue valueWithPointer:r];
    pthread_mutex_unlock(&synth_lock);
    return r;
}

/* text around `inner` in `outer` with `inner` replaced by %@ ("in 5 days" around "5 days" -> "in %@") */
static NSString *around(NSString *outer, NSString *inner) {
    if (!outer || !inner) return nil;
    NSRange r = [outer rangeOfString:inner];
    return r.location == NSNotFound ? nil : [outer stringByReplacingCharactersInRange:r withString:@"%@"];
}
static NSString *strip_number(NSString *phrase, NSString *number) {
    NSRange r = phrase && number ? [phrase rangeOfString:number] : NSMakeRange(NSNotFound, 0);
    if (r.location == NSNotFound) return phrase ?: @"";
    NSString *s = [phrase stringByReplacingCharactersInRange:r withString:@""];
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"   "]];
}

const isim_lang_t *isim_icu_lang(NSString *lang) {
    if (!isim_icu_on() || !lang.length) return NULL;
    static NSMutableDictionary<NSString *, NSValue *> *cache;
    pthread_mutex_lock(&synth_lock);
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSValue *v = cache[lang];
    if (v) { pthread_mutex_unlock(&synth_lock); return v.pointerValue; }
    pthread_mutex_unlock(&synth_lock);

    NSArray *months = isim_icu_symbols(lang, 1), *shortMonths = isim_icu_symbols(lang, 2);
    NSArray *days = isim_icu_symbols(lang, 3), *shortDays = isim_icu_symbols(lang, 4);
    NSArray *ampm = isim_icu_symbols(lang, 5), *eras = isim_icu_symbols(lang, 0);
    if (months.count < 12 || shortMonths.count < 12 || days.count != 7 || shortDays.count != 7) return NULL;
    isim_lang_t *L = calloc(1, sizeof *L);
    L->lang = keep(lang);
    for (int i = 0; i < 12; i++) { L->months[i] = keep(months[i]); L->monthsShort[i] = keep(shortMonths[i]); }
    for (int i = 0; i < 7; i++) { L->weekdays[i] = keep(days[i]); L->weekdaysShort[i] = keep(shortDays[i]); }
    L->am = keep(ampm.count > 0 ? ampm[0] : @"AM");
    L->pm = keep(ampm.count > 1 ? ampm[1] : @"PM");
    L->eras[0] = keep(eras.count > 0 ? eras[0] : @"BC");
    L->eras[1] = keep(eras.count > 1 ? eras[1] : @"AD");
    /* lists: "A, B и C" */
    NSString *two = isim_icu_list_string(lang, @[@"A", @"B"], 0, 0), *twoOr = isim_icu_list_string(lang, @[@"A", @"B"], 1, 0);
    NSString *three = isim_icu_list_string(lang, @[@"A", @"B", @"C"], 0, 0);
    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
    NSString *(^middle)(NSString *) = ^NSString *(NSString *s) {
        if (s.length < 3 || ![s hasPrefix:@"A"] || ![s hasSuffix:@"B"]) return nil;
        return [[s substringWithRange:NSMakeRange(1, s.length - 2)] stringByTrimmingCharactersInSet:ws];
    };
    L->listAnd = keep(middle(two) ?: @"&");
    L->listOr = keep(middle(twoOr) ?: @"/");
    NSString *sep = @", ";
    if ([three hasPrefix:@"A"]) { NSRange b = [three rangeOfString:@"B"]; if (b.location != NSNotFound) sep = [three substringWithRange:NSMakeRange(1, b.location - 1)]; }
    L->listSep = keep(sep);
    /* the glue between a short date and a short time */
    NSString *d = isim_icu_style_pattern(lang, 1, 0), *t = isim_icu_style_pattern(lang, 0, 1), *dt = isim_icu_style_pattern(lang, 1, 1);
    NSString *glue = @" ";
    if (d && t && dt) {
        NSRange rd = [dt rangeOfString:d], rt = [dt rangeOfString:t];
        if (rd.location != NSNotFound && rt.location != NSNotFound && NSMaxRange(rd) <= rt.location)
            glue = [dt substringWithRange:NSMakeRange(NSMaxRange(rd), rt.location - NSMaxRange(rd))];
        else if (rd.location != NSNotFound && rt.location != NSNotFound && NSMaxRange(rt) <= rd.location)
            glue = [dt substringWithRange:NSMakeRange(NSMaxRange(rt), rd.location - NSMaxRange(rt))];
    }
    L->dateTimeSep = keep(glue);
    /* units: 0 year .. 6 second */
    static NSString *const units[7] = { @"duration-year", @"duration-month", @"duration-week", @"duration-day", @"duration-hour", @"duration-minute", @"duration-second" };
    static const int relUnits[7] = { 0, 2, 3, 4, 5, 6, 7 };   /* URelativeDateTimeUnit */
    NSString *one = isim_icu_number(lang, @"precision-unlimited", 1), *five = isim_icu_number(lang, @"precision-unlimited", 5);
    for (int i = 0; i < 7; i++) {
        L->unitOne[i] = keep(strip_number(isim_icu_unit_phrase(lang, units[i], 1, nil, 2), one));
        L->unitOther[i] = keep(strip_number(isim_icu_unit_phrase(lang, units[i], 5, nil, 2), five));
        L->unitShort[i] = keep(strip_number(isim_icu_unit_phrase(lang, units[i], 1, nil, 1), one));
        L->unitShortOther[i] = keep(strip_number(isim_icu_unit_phrase(lang, units[i], 5, nil, 1), five));
        L->unitNarrow[i] = keep(strip_number(isim_icu_unit_phrase(lang, units[i], 1, nil, 0), one));
        NSString *last = isim_icu_relative_string(lang, -1, relUnits[i], 0, NO), *this = isim_icu_relative_string(lang, 0, relUnits[i], 0, NO);
        NSString *next = isim_icu_relative_string(lang, 1, relUnits[i], 0, NO);
        NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
        L->lastUnit[i] = last && [last rangeOfCharacterFromSet:digits].location == NSNotFound ? keep(last) : NULL;
        L->thisUnit[i] = this && [this rangeOfCharacterFromSet:digits].location == NSNotFound ? keep(this) : NULL;
        L->nextUnit[i] = next && [next rangeOfCharacterFromSet:digits].location == NSNotFound ? keep(next) : NULL;
    }
    NSString *fiveDays = isim_icu_unit_phrase(lang, @"duration-day", 5, nil, 2);
    L->relFuture = keep(around(isim_icu_relative_string(lang, 5, 4, 0, YES), fiveDays) ?: @"+%@");
    L->relPast = keep(around(isim_icu_relative_string(lang, -5, 4, 0, YES), fiveDays) ?: @"-%@");
    L->yesterday = keep(isim_icu_relative_string(lang, -1, 4, 0, NO) ?: @"-1");
    L->today = keep(isim_icu_relative_string(lang, 0, 4, 0, NO) ?: @"0");
    L->tomorrow = keep(isim_icu_relative_string(lang, 1, 4, 0, NO) ?: @"+1");
    L->now = keep(isim_icu_relative_string(lang, 0, 7, 0, NO) ?: @"0");
    L->pluralZeroIsOne = [isim_icu_plural_category(lang, 0, NO) isEqualToString:@"one"];
    static NSString *const bytes[6] = { @"digital-byte", @"digital-kilobyte", @"digital-megabyte", @"digital-gigabyte", @"digital-terabyte", @"digital-petabyte" };
    for (int i = 0; i < 6; i++) L->byteUnits[i] = keep(strip_number(isim_icu_unit_phrase(lang, bytes[i], 5, nil, 1), five));
    L->zeroBytes = keep(isim_icu_number(lang, @"precision-unlimited", 0) ?: @"0");
    L->relOther = NULL;

    pthread_mutex_lock(&synth_lock);
    if (cache[lang]) { pthread_mutex_unlock(&synth_lock); free(L); return [cache[lang] pointerValue]; }
    cache[lang] = [NSValue valueWithPointer:L];
    pthread_mutex_unlock(&synth_lock);
    return L;
}
