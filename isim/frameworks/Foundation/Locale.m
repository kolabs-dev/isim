/* isim Foundation (ARC): NSLocale, NSTimeZone, NSDateFormatter, NSNumberFormatter and .strings localization.
 *
 * Device settings come from the environment set by `isim run` / `isim settings`:
 *   ISIM_LANGUAGES  preferred languages, comma separated (e.g. "pt-BR,en"); default "en"
 *   ISIM_LOCALE     region locale identifier (e.g. "pt_BR"); default derived from the first language
 *   ISIM_HOUR_CYCLE "12", "24" or unset (locale default)
 *   TZ              time zone name (honoured by the host C library)
 * Locale data (month names, date patterns, separators) is a small built-in table covering common
 * locales; other locales fall back to their language or to en_US. It is not CLDR. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "isim_foundation.h"

NSLocaleKey const NSLocaleIdentifier = @"locale:id", NSLocaleLanguageCode = @"kCFLocaleLanguageCodeKey",
    NSLocaleCountryCode = @"kCFLocaleCountryCodeKey", NSLocaleScriptCode = @"kCFLocaleScriptCodeKey",
    NSLocaleDecimalSeparator = @"kCFLocaleDecimalSeparatorKey", NSLocaleGroupingSeparator = @"kCFLocaleGroupingSeparatorKey",
    NSLocaleCurrencySymbol = @"kCFLocaleCurrencySymbolKey", NSLocaleCurrencyCode = @"currency",
    NSLocaleUsesMetricSystem = @"kCFLocaleUsesMetricSystemKey", NSLocaleCalendarIdentifier = @"calendar";
NSNotificationName const NSCurrentLocaleDidChangeNotification = @"kCFLocaleCurrentLocaleDidChangeNotification";

/* ---------------- settings ---------------- */
NSArray<NSString *> *isim_preferred_languages(void) {
    static NSArray *langs;
    if (!langs) {
        const char *e = getenv("ISIM_LANGUAGES");
        NSArray *pref = isim_global_preferences()[@"AppleLanguages"];          /* Settings > General > Language & Region */
        NSString *list = e && *e ? @(e) : [pref isKindOfClass:[NSArray class]] && pref.count ? [pref componentsJoinedByString:@","] : @"en";
        NSMutableArray *a = [NSMutableArray array];
        for (NSString *p in [list componentsSeparatedByString:@","]) {
            NSString *t = [p stringByReplacingOccurrencesOfString:@" " withString:@""];
            if (t.length) [a addObject:[t stringByReplacingOccurrencesOfString:@"_" withString:@"-"]];
        }
        langs = a.count ? [a copy] : @[@"en"];
    }
    return langs;
}
static NSString *default_locale_identifier(void) {
    const char *e = getenv("ISIM_LOCALE");
    if (e && *e) return [@(e) stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    NSString *pref = isim_global_preferences()[@"AppleLocale"];
    if ([pref isKindOfClass:[NSString class]] && pref.length) return [pref stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    NSString *first = isim_preferred_languages().firstObject;            /* "pt-BR" -> "pt_BR"; "en" -> "en_US" */
    if ([first containsString:@"-"]) {
        NSArray *parts = [first componentsSeparatedByString:@"-"];
        NSString *last = parts.lastObject;
        if (last.length == 2) return [NSString stringWithFormat:@"%@_%@", parts.firstObject, last.uppercaseString];
        return [parts componentsJoinedByString:@"_"];
    }
    NSDictionary *defaults = @{ @"en": @"en_US", @"pt": @"pt_PT", @"es": @"es_ES", @"fr": @"fr_FR", @"de": @"de_DE",
                                @"it": @"it_IT", @"ja": @"ja_JP", @"zh": @"zh_CN", @"ko": @"ko_KR", @"ar": @"ar_SA",
                                @"he": @"he_IL", @"ru": @"ru_RU", @"nl": @"nl_NL", @"sv": @"sv_SE", @"tr": @"tr_TR" };
    return defaults[first] ?: first;
}

/* ---------------- locale data ---------------- */
typedef struct {
    const char *lang;
    const char *months[12], *monthsShort[12], *weekdays[7], *weekdaysShort[7], *am, *pm;
} lang_names_t;
static const lang_names_t LANGS[] = {
    { "en", { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" },
      { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
      { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }, { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }, "AM", "PM" },
    { "pt", { "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro" },
      { "jan.", "fev.", "mar.", "abr.", "mai.", "jun.", "jul.", "ago.", "set.", "out.", "nov.", "dez." },
      { "domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado" }, { "dom.", "seg.", "ter.", "qua.", "qui.", "sex.", "sáb." }, "AM", "PM" },
    { "es", { "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" },
      { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic" },
      { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }, { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }, "a. m.", "p. m." },
    { "fr", { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" },
      { "janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc." },
      { "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi" }, { "dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam." }, "AM", "PM" },
    { "de", { "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember" },
      { "Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez." },
      { "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag" }, { "So.", "Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa." }, "AM", "PM" },
    { "it", { "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre" },
      { "gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic" },
      { "domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato" }, { "dom", "lun", "mar", "mer", "gio", "ven", "sab" }, "AM", "PM" },
};
static const lang_names_t *names_for(NSString *lang) {
    for (size_t i = 0; i < sizeof LANGS / sizeof *LANGS; i++) if ([lang isEqualToString:@(LANGS[i].lang)]) return &LANGS[i];
    return &LANGS[0];
}

typedef struct { const char *loc; const char *decimal, *group, *currencyCode, *currencySymbol; int hour12, metric;
                 const char *dShort, *dMedium, *dLong, *dFull; } region_t;
/* patterns use Unicode/ICU date symbols; '{w}' marks a weekday prefix */
static const region_t REGIONS[] = {
    { "en_US", ".", ",", "USD", "$", 1, 0, "M/d/yy", "MMM d, y", "MMMM d, y", "EEEE, MMMM d, y" },
    { "en_GB", ".", ",", "GBP", "£", 0, 1, "dd/MM/y", "d MMM y", "d MMMM y", "EEEE d MMMM y" },
    { "en_CA", ".", ",", "CAD", "$", 1, 1, "y-MM-dd", "MMM d, y", "MMMM d, y", "EEEE, MMMM d, y" },
    { "en_AU", ".", ",", "AUD", "$", 1, 1, "d/M/yy", "d MMM y", "d MMMM y", "EEEE d MMMM y" },
    { "en_IN", ".", ",", "INR", "₹", 1, 1, "dd/MM/yy", "dd-MMM-y", "d MMMM y", "EEEE, d MMMM, y" },
    { "pt_BR", ",", ".", "BRL", "R$", 0, 1, "dd/MM/y", "d 'de' MMM 'de' y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y" },
    { "pt_PT", ",", " ", "EUR", "€", 0, 1, "dd/MM/yy", "dd/MM/y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y" },
    { "es_ES", ",", ".", "EUR", "€", 0, 1, "d/M/yy", "d MMM y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y" },
    { "es_MX", ".", ",", "MXN", "$", 0, 1, "dd/MM/yy", "d MMM y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y" },
    { "fr_FR", ",", " ", "EUR", "€", 0, 1, "dd/MM/y", "d MMM y", "d MMMM y", "EEEE d MMMM y" },
    { "fr_CA", ",", " ", "CAD", "$", 0, 1, "y-MM-dd", "d MMM y", "d MMMM y", "EEEE d MMMM y" },
    { "de_DE", ",", ".", "EUR", "€", 0, 1, "dd.MM.yy", "dd.MM.y", "d. MMMM y", "EEEE, d. MMMM y" },
    { "it_IT", ",", ".", "EUR", "€", 0, 1, "dd/MM/yy", "d MMM y", "d MMMM y", "EEEE d MMMM y" },
    { "ja_JP", ".", ",", "JPY", "¥", 0, 1, "y/MM/dd", "y/MM/dd", "y年M月d日", "y年M月d日EEEE" },
    { "ar_SA", "٫", "٬", "SAR", "ر.س.", 1, 1, "d‏/M‏/y", "dd‏/MM‏/y", "d MMMM y", "EEEE، d MMMM y" },
};
static const region_t *region_for(NSString *ident) {
    for (size_t i = 0; i < sizeof REGIONS / sizeof *REGIONS; i++) if ([ident isEqualToString:@(REGIONS[i].loc)]) return &REGIONS[i];
    NSString *lang = [ident componentsSeparatedByString:@"_"].firstObject;
    for (size_t i = 0; i < sizeof REGIONS / sizeof *REGIONS; i++) if ([@(REGIONS[i].loc) hasPrefix:[lang stringByAppendingString:@"_"]]) return &REGIONS[i];
    return &REGIONS[0];
}

static NSDictionary *language_names(void) {
    return @{ @"en": @[@"English", @"English"], @"pt": @[@"Portuguese", @"português"], @"es": @[@"Spanish", @"español"],
              @"fr": @[@"French", @"français"], @"de": @[@"German", @"Deutsch"], @"it": @[@"Italian", @"italiano"],
              @"ja": @[@"Japanese", @"日本語"], @"zh": @[@"Chinese", @"中文"], @"ko": @[@"Korean", @"한국어"],
              @"ar": @[@"Arabic", @"العربية"], @"he": @[@"Hebrew", @"עברית"], @"ru": @[@"Russian", @"русский"],
              @"nl": @[@"Dutch", @"Nederlands"], @"sv": @[@"Swedish", @"svenska"], @"tr": @[@"Turkish", @"Türkçe"] };
}
static NSDictionary *country_names(void) {
    return @{ @"US": @"United States", @"BR": @"Brazil", @"PT": @"Portugal", @"ES": @"Spain", @"MX": @"Mexico",
              @"FR": @"France", @"CA": @"Canada", @"DE": @"Germany", @"GB": @"United Kingdom", @"IT": @"Italy",
              @"JP": @"Japan", @"CN": @"China", @"AU": @"Australia", @"IN": @"India", @"SA": @"Saudi Arabia" };
}

/* ---------------- NSLocale ---------------- */
@implementation NSLocale { NSString *_ident; NSString *_lang, *_region, *_script; }
+ (NSLocale *)currentLocale { return [self localeWithLocaleIdentifier:default_locale_identifier()]; }
+ (NSLocale *)autoupdatingCurrentLocale { return [self currentLocale]; }
+ (NSLocale *)systemLocale { return [self localeWithLocaleIdentifier:@""]; }
+ (NSArray<NSString *> *)preferredLanguages { return isim_preferred_languages(); }
+ (NSArray<NSString *> *)availableLocaleIdentifiers {
    NSMutableArray *a = [NSMutableArray array];
    for (size_t i = 0; i < sizeof REGIONS / sizeof *REGIONS; i++) [a addObject:@(REGIONS[i].loc)];
    return a;
}
+ (instancetype)localeWithLocaleIdentifier:(NSString *)ident { return [[self alloc] initWithLocaleIdentifier:ident]; }
- (instancetype)init { return [self initWithLocaleIdentifier:@""]; }
- (instancetype)initWithLocaleIdentifier:(NSString *)ident {
    if ((self = [super init])) {
        _ident = [[ident stringByReplacingOccurrencesOfString:@"-" withString:@"_"] copy];
        NSArray *parts = [_ident componentsSeparatedByString:@"_"];
        _lang = parts.count && [parts[0] length] ? parts[0] : nil;
        for (NSUInteger i = 1; i < parts.count; i++) {
            NSString *p = parts[i];
            if (p.length == 4) _script = p;
            else if (p.length == 2 || p.length == 3) _region = p.uppercaseString;
        }
    }
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSLocale class]] && [_ident isEqualToString:[o localeIdentifier]]; }
- (NSUInteger)hash { return _ident.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"%@ (current)", _ident]; }
- (NSString *)localeIdentifier { return _ident; }
- (NSString *)languageCode { return _lang; }
- (NSString *)countryCode { return _region; }
- (NSString *)regionCode { return _region; }
- (NSString *)scriptCode { return _script; }
- (NSString *)calendarIdentifier { return @"gregorian"; }
- (const region_t *)_region { return region_for(_ident.length ? _ident : @"en_US"); }
- (NSString *)decimalSeparator { return @([self _region]->decimal); }
- (NSString *)groupingSeparator { return @([self _region]->group); }
- (NSString *)currencySymbol { return @([self _region]->currencySymbol); }
- (NSString *)currencyCode { return @([self _region]->currencyCode); }
- (BOOL)usesMetricSystem { return [self _region]->metric; }
- (BOOL)_isim_uses12Hour {
    const char *hc = getenv("ISIM_HOUR_CYCLE");
    if (hc && !strcmp(hc, "24")) return NO;
    if (hc && !strcmp(hc, "12")) return YES;
    NSDictionary *g = isim_global_preferences();                             /* Settings > General > Date & Time */
    if ([g[@"AppleICUForce24HourTime"] boolValue]) return NO;
    if ([g[@"AppleICUForce12HourTime"] boolValue]) return YES;
    return [self _region]->hour12;
}
- (id)objectForKey:(NSLocaleKey)key {
    if ([key isEqualToString:NSLocaleIdentifier]) return _ident;
    if ([key isEqualToString:NSLocaleLanguageCode]) return _lang;
    if ([key isEqualToString:NSLocaleCountryCode]) return _region;
    if ([key isEqualToString:NSLocaleScriptCode]) return _script;
    if ([key isEqualToString:NSLocaleDecimalSeparator]) return self.decimalSeparator;
    if ([key isEqualToString:NSLocaleGroupingSeparator]) return self.groupingSeparator;
    if ([key isEqualToString:NSLocaleCurrencySymbol]) return self.currencySymbol;
    if ([key isEqualToString:NSLocaleCurrencyCode]) return self.currencyCode;
    if ([key isEqualToString:NSLocaleUsesMetricSystem]) return @(self.usesMetricSystem);
    if ([key isEqualToString:NSLocaleCalendarIdentifier]) return self.calendarIdentifier;
    return nil;
}
- (NSString *)localizedStringForLanguageCode:(NSString *)code {
    NSArray *n = language_names()[[code componentsSeparatedByString:@"-"].firstObject];
    if (!n) return nil;
    return [_lang isEqualToString:[code componentsSeparatedByString:@"-"].firstObject] ? n[1] : n[0];
}
- (NSString *)localizedStringForCountryCode:(NSString *)code { return country_names()[code.uppercaseString]; }
- (NSString *)localizedStringForLocaleIdentifier:(NSString *)ident {
    NSLocale *l = [NSLocale localeWithLocaleIdentifier:ident];
    NSString *lang = [self localizedStringForLanguageCode:l.languageCode ?: @""] ?: ident;
    NSString *country = l.countryCode ? [self localizedStringForCountryCode:l.countryCode] : nil;
    return country ? [NSString stringWithFormat:@"%@ (%@)", lang, country] : lang;
}
- (NSString *)displayNameForKey:(NSLocaleKey)key value:(id)value {
    if ([key isEqualToString:NSLocaleIdentifier]) return [self localizedStringForLocaleIdentifier:value];
    if ([key isEqualToString:NSLocaleLanguageCode]) return [self localizedStringForLanguageCode:value];
    if ([key isEqualToString:NSLocaleCountryCode]) return [self localizedStringForCountryCode:value];
    return nil;
}
+ (NSLocaleLanguageDirection)characterDirectionForLanguage:(NSString *)code {
    NSString *l = [code componentsSeparatedByString:@"-"].firstObject;
    return [@[@"ar", @"he", @"fa", @"ur", @"yi"] containsObject:l] ? NSLocaleLanguageDirectionRightToLeft : NSLocaleLanguageDirectionLeftToRight;
}
@end

/* ---------------- NSTimeZone ---------------- */
static NSTimeZone *default_tz;
static long tz_offset(NSString *name, time_t at, char *abbr, size_t abbrlen, int *dst) {
    /* evaluate in the requested zone by switching TZ temporarily (the host C library owns the tz database) */
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&lock);
    const char *old = getenv("TZ"); char saved[256] = {0}; if (old) snprintf(saved, sizeof saved, "%s", old);
    if (name) setenv("TZ", name.UTF8String, 1);
    tzset();
    struct tm tm; localtime_r(&at, &tm);
    if (name) { if (old) setenv("TZ", saved, 1); else unsetenv("TZ"); tzset(); }
    pthread_mutex_unlock(&lock);
    if (abbr) snprintf(abbr, abbrlen, "%s", tm.tm_zone ? tm.tm_zone : "");
    if (dst) *dst = tm.tm_isdst > 0;
    return tm.tm_gmtoff;
}
@implementation NSTimeZone { NSString *_name; NSInteger _fixed; BOOL _isFixed; }
+ (NSTimeZone *)systemTimeZone {
    const char *tz = getenv("TZ");
    if (tz && *tz) return [[NSTimeZone alloc] initWithName:@(tz[0] == ':' ? tz + 1 : tz)];
    char buf[256]; ssize_t n = readlink("/etc/localtime", buf, sizeof buf - 1);   /* host zone, e.g. .../zoneinfo/America/Sao_Paulo */
    if (n > 0) {
        buf[n] = 0;
        const char *z = strstr(buf, "zoneinfo/");
        if (z) return [[NSTimeZone alloc] initWithName:@(z + 9)];
    }
    return [NSTimeZone timeZoneForSecondsFromGMT:0];
}
+ (NSTimeZone *)localTimeZone { return [self defaultTimeZone]; }
+ (NSTimeZone *)defaultTimeZone { return default_tz ?: [self systemTimeZone]; }
+ (void)setDefaultTimeZone:(NSTimeZone *)tz { default_tz = [tz copy]; }
+ (NSArray<NSString *> *)knownTimeZoneNames {
    return @[@"America/New_York", @"America/Chicago", @"America/Denver", @"America/Los_Angeles", @"America/Sao_Paulo",
             @"America/Mexico_City", @"Europe/London", @"Europe/Lisbon", @"Europe/Madrid", @"Europe/Paris", @"Europe/Berlin",
             @"Europe/Rome", @"Asia/Tokyo", @"Asia/Shanghai", @"Asia/Kolkata", @"Asia/Riyadh", @"Australia/Sydney", @"UTC"];
}
+ (instancetype)timeZoneWithName:(NSString *)name { return [[self alloc] initWithName:name]; }
+ (instancetype)timeZoneWithAbbreviation:(NSString *)abbr {
    NSDictionary *m = @{ @"UTC": @"UTC", @"GMT": @"UTC", @"EST": @"America/New_York", @"PST": @"America/Los_Angeles",
                         @"BRT": @"America/Sao_Paulo", @"CET": @"Europe/Paris", @"JST": @"Asia/Tokyo" };
    return m[abbr] ? [self timeZoneWithName:m[abbr]] : nil;
}
+ (instancetype)timeZoneForSecondsFromGMT:(NSInteger)s {
    NSTimeZone *z = [NSTimeZone new]; z->_isFixed = YES; z->_fixed = s;
    z->_name = s == 0 ? @"GMT" : [NSString stringWithFormat:@"GMT%+03ld%02ld", (long)(s / 3600), (long)(labs(s) % 3600 / 60)];
    return z;
}
- (instancetype)initWithName:(NSString *)name {
    if ([name isEqualToString:@"UTC"] || [name isEqualToString:@"GMT"]) { self = [super init]; _name = name; _isFixed = YES; return self; }
    char path[512]; snprintf(path, sizeof path, "/usr/share/zoneinfo/%s", name.UTF8String);
    if (access(path, R_OK) != 0) return nil;
    if ((self = [super init])) _name = [name copy];
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSTimeZone class]] && [_name isEqualToString:[o name]]; }
- (NSUInteger)hash { return _name.hash; }
- (NSString *)name { return _name; }
- (NSInteger)secondsFromGMTForDate:(NSDate *)d { return _isFixed ? _fixed : tz_offset(_name, (time_t)d.timeIntervalSince1970, NULL, 0, NULL); }
- (NSInteger)secondsFromGMT { return [self secondsFromGMTForDate:[NSDate date]]; }
- (NSString *)abbreviationForDate:(NSDate *)d {
    if (_isFixed) return _fixed ? _name : @"GMT";
    char a[32]; tz_offset(_name, (time_t)d.timeIntervalSince1970, a, sizeof a, NULL); return @(a);
}
- (NSString *)abbreviation { return [self abbreviationForDate:[NSDate date]]; }
- (BOOL)isDaylightSavingTimeForDate:(NSDate *)d { int dst = 0; if (!_isFixed) tz_offset(_name, (time_t)d.timeIntervalSince1970, NULL, 0, &dst); return dst; }
- (NSString *)description { return [NSString stringWithFormat:@"%@ (%@) offset %ld", _name, self.abbreviation, (long)self.secondsFromGMT]; }
@end

/* ---------------- formatters ---------------- */
@implementation NSFormatter
- (NSString *)stringForObjectValue:(id)obj { return [obj description]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

static void broken_down(NSDate *date, NSTimeZone *tz, struct tm *tm) {
    time_t t = (time_t)floor(date.timeIntervalSince1970);
    t += [tz secondsFromGMTForDate:date];
    gmtime_r(&t, tm);
}

@implementation NSDateFormatter { NSString *_fmt; NSLocale *_locale; NSTimeZone *_tz; }
- (instancetype)init { if ((self = [super init])) { _locale = NSLocale.currentLocale; _tz = NSTimeZone.defaultTimeZone; } return self; }
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; }
- (NSTimeZone *)timeZone { return _tz; }
- (void)setTimeZone:(NSTimeZone *)tz { _tz = tz ?: NSTimeZone.defaultTimeZone; }
- (void)setDateFormat:(NSString *)f { _fmt = [f copy]; }
- (NSString *)dateFormat {
    if (_fmt) return _fmt;
    const region_t *r = region_for(_locale.localeIdentifier);
    NSString *d = nil, *t = nil;
    switch (self.dateStyle) {
    case NSDateFormatterShortStyle: d = @(r->dShort); break;
    case NSDateFormatterMediumStyle: d = @(r->dMedium); break;
    case NSDateFormatterLongStyle: d = @(r->dLong); break;
    case NSDateFormatterFullStyle: d = @(r->dFull); break;
    default: break;
    }
    BOOL h12 = [(id)_locale _isim_uses12Hour];
    switch (self.timeStyle) {
    case NSDateFormatterShortStyle: t = h12 ? @"h:mm a" : @"HH:mm"; break;
    case NSDateFormatterMediumStyle: t = h12 ? @"h:mm:ss a" : @"HH:mm:ss"; break;
    case NSDateFormatterLongStyle: case NSDateFormatterFullStyle: t = h12 ? @"h:mm:ss a z" : @"HH:mm:ss z"; break;
    default: break;
    }
    if (d && t) return [NSString stringWithFormat:@"%@%@%@", d, [_locale.languageCode isEqualToString:@"en"] ? @", " : @" ", t];
    return d ?: t ?: @"";
}
- (void)setLocalizedDateFormatFromTemplate:(NSString *)tmpl { _fmt = [NSDateFormatter dateFormatFromTemplate:tmpl options:0 locale:_locale]; }
+ (NSString *)dateFormatFromTemplate:(NSString *)tmpl options:(NSUInteger)opts locale:(NSLocale *)locale {
    /* simplified: keep the template's fields, apply the locale's hour cycle */
    BOOL h12 = [(id)(locale ?: NSLocale.currentLocale) _isim_uses12Hour];
    NSString *f = [tmpl stringByReplacingOccurrencesOfString:@"j" withString:h12 ? @"h" : @"H"];
    if (h12 && [f containsString:@"h"] && ![f containsString:@"a"]) f = [f stringByAppendingString:@" a"];
    return f;
}
+ (NSString *)localizedStringFromDate:(NSDate *)d dateStyle:(NSDateFormatterStyle)ds timeStyle:(NSDateFormatterStyle)ts {
    NSDateFormatter *f = [NSDateFormatter new]; f.dateStyle = ds; f.timeStyle = ts; return [f stringFromDate:d];
}
- (NSString *)stringFromDate:(NSDate *)date {
    if (!date) return nil;
    struct tm tm; broken_down(date, _tz, &tm);
    const lang_names_t *n = names_for(_locale.languageCode ?: @"en");
    NSString *fmt = self.dateFormat;
    NSMutableString *out = [NSMutableString string];
    NSUInteger len = fmt.length;
    for (NSUInteger i = 0; i < len;) {
        unichar c = [fmt characterAtIndex:i];
        if (c == '\'') {                                           /* quoted literal; '' is a quote */
            NSUInteger j = i + 1;
            if (j < len && [fmt characterAtIndex:j] == '\'') { [out appendString:@"'"]; i += 2; continue; }
            while (j < len && [fmt characterAtIndex:j] != '\'') j++;
            [out appendString:[fmt substringWithRange:NSMakeRange(i + 1, j - i - 1)]];
            i = j + 1; continue;
        }
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))) { [out appendString:[fmt substringWithRange:NSMakeRange(i, 1)]]; i++; continue; }
        NSUInteger k = i; while (k < len && [fmt characterAtIndex:k] == c) k++;
        NSUInteger cnt = k - i; i = k;
        int hour12 = tm.tm_hour % 12 ? tm.tm_hour % 12 : 12;
        switch (c) {
        case 'y': [out appendFormat:cnt == 2 ? @"%02d" : @"%d", cnt == 2 ? (tm.tm_year + 1900) % 100 : tm.tm_year + 1900]; break;
        case 'M': case 'L':
            if (cnt >= 4) [out appendString:@(n->months[tm.tm_mon])];
            else if (cnt == 3) [out appendString:@(n->monthsShort[tm.tm_mon])];
            else [out appendFormat:cnt == 2 ? @"%02d" : @"%d", tm.tm_mon + 1];
            break;
        case 'd': [out appendFormat:cnt == 2 ? @"%02d" : @"%d", tm.tm_mday]; break;
        case 'E': case 'c': case 'e': [out appendString:@(cnt >= 4 ? n->weekdays[tm.tm_wday] : n->weekdaysShort[tm.tm_wday])]; break;
        case 'H': [out appendFormat:cnt == 2 ? @"%02d" : @"%d", tm.tm_hour]; break;
        case 'h': [out appendFormat:cnt == 2 ? @"%02d" : @"%d", hour12]; break;
        case 'm': [out appendFormat:cnt == 2 ? @"%02d" : @"%d", tm.tm_min]; break;
        case 's': [out appendFormat:cnt == 2 ? @"%02d" : @"%d", tm.tm_sec]; break;
        case 'S': [out appendFormat:@"%0*d", (int)cnt, (int)(fmod(date.timeIntervalSince1970, 1) * pow(10, cnt))]; break;
        case 'a': [out appendString:@(tm.tm_hour < 12 ? n->am : n->pm)]; break;
        case 'z': case 'v': case 'V': [out appendString:[_tz abbreviationForDate:date] ?: @""]; break;
        case 'Z': case 'x': case 'X': {
            long off = [_tz secondsFromGMTForDate:date];
            [out appendFormat:@"%c%02ld%s%02ld", off < 0 ? '-' : '+', labs(off) / 3600, cnt >= 3 && c != 'Z' ? ":" : "", labs(off) % 3600 / 60];
            break; }
        default: break;
        }
    }
    return out;
}
- (NSDate *)dateFromString:(NSString *)string {
    /* numeric fields only (y M d H h m s a); literals must match */
    NSString *fmt = self.dateFormat;
    struct tm tm = {0}; tm.tm_mday = 1; tm.tm_year = 70;
    int pm = -1;
    NSUInteger si = 0, sl = string.length;
    for (NSUInteger i = 0; i < fmt.length;) {
        unichar c = [fmt characterAtIndex:i];
        NSUInteger k = i; while (k < fmt.length && [fmt characterAtIndex:k] == c) k++;
        NSUInteger cnt = k - i; i = k;
        if (strchr("yMdHhms", c)) {
            long v = 0; NSUInteger digits = 0;
            while (si < sl && [string characterAtIndex:si] >= '0' && [string characterAtIndex:si] <= '9' && (cnt > 2 || digits < (c == 'y' ? 4 : 2))) { v = v * 10 + ([string characterAtIndex:si] - '0'); si++; digits++; }
            if (!digits) return nil;
            switch (c) {
            case 'y': tm.tm_year = (int)(cnt == 2 && v < 100 ? v + 2000 : v) - 1900; break;
            case 'M': tm.tm_mon = (int)v - 1; break;
            case 'd': tm.tm_mday = (int)v; break;
            case 'H': case 'h': tm.tm_hour = (int)v; break;
            case 'm': tm.tm_min = (int)v; break;
            case 's': tm.tm_sec = (int)v; break;
            }
        } else if (c == 'a') {
            NSString *rest = [[string substringFromIndex:si] uppercaseString];
            if ([rest hasPrefix:@"PM"]) { pm = 1; si += 2; } else if ([rest hasPrefix:@"AM"]) { pm = 0; si += 2; } else return nil;
        } else {
            for (NSUInteger q = 0; q < cnt; q++, si++) if (si >= sl || [string characterAtIndex:si] != c) return nil;
        }
    }
    if (si != sl) return nil;
    if (pm == 1 && tm.tm_hour < 12) tm.tm_hour += 12;
    if (pm == 0 && tm.tm_hour == 12) tm.tm_hour = 0;
    time_t t = timegm(&tm);
    NSDate *guess = [NSDate dateWithTimeIntervalSince1970:t];
    return [NSDate dateWithTimeIntervalSince1970:t - [_tz secondsFromGMTForDate:guess]];
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSDate class]] ? [self stringFromDate:obj] : nil; }
@end

@implementation NSNumberFormatter { NSLocale *_locale; NSString *_dec, *_grp, *_cur, *_curCode; BOOL _fracSet; }
- (instancetype)init {
    if ((self = [super init])) { _locale = NSLocale.currentLocale; _maximumFractionDigits = 0; _minimumIntegerDigits = 1; }
    return self;
}
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; }
- (NSString *)decimalSeparator { return _dec ?: _locale.decimalSeparator; }
- (void)setDecimalSeparator:(NSString *)s { _dec = [s copy]; }
- (NSString *)groupingSeparator { return _grp ?: _locale.groupingSeparator; }
- (void)setGroupingSeparator:(NSString *)s { _grp = [s copy]; }
- (NSString *)currencySymbol { return _cur ?: _locale.currencySymbol; }
- (void)setCurrencySymbol:(NSString *)s { _cur = [s copy]; }
- (NSString *)currencyCode { return _curCode ?: _locale.currencyCode; }
- (void)setCurrencyCode:(NSString *)s { _curCode = [s copy]; }
- (void)setMaximumFractionDigits:(NSUInteger)n { _maximumFractionDigits = n; _fracSet = YES; }
- (void)setNumberStyle:(NSNumberFormatterStyle)st {
    _numberStyle = st;
    if (!_fracSet) _maximumFractionDigits = st == NSNumberFormatterDecimalStyle ? 3 : st == NSNumberFormatterCurrencyStyle ? 2 : 0;
    if (st == NSNumberFormatterCurrencyStyle) _minimumFractionDigits = 2;
    _usesGroupingSeparator = st == NSNumberFormatterDecimalStyle || st == NSNumberFormatterCurrencyStyle || st == NSNumberFormatterPercentStyle;
}
- (NSString *)stringFromNumber:(NSNumber *)number {
    if (!number) return nil;
    double v = number.doubleValue;
    if (_numberStyle == NSNumberFormatterPercentStyle) v *= 100;
    NSUInteger maxf = _maximumFractionDigits, minf = MIN(_minimumFractionDigits, maxf);
    char buf[128]; snprintf(buf, sizeof buf, "%.*f", (int)maxf, fabs(v));
    NSString *s = @(buf);
    NSString *intPart = s, *frac = @"";
    NSRange dot = [s rangeOfString:@"."];
    if (dot.location != NSNotFound) { intPart = [s substringToIndex:dot.location]; frac = [s substringFromIndex:dot.location + 1]; }
    while (frac.length > minf && [frac hasSuffix:@"0"]) frac = [frac substringToIndex:frac.length - 1];
    while (intPart.length < _minimumIntegerDigits) intPart = [@"0" stringByAppendingString:intPart];
    if (_usesGroupingSeparator && intPart.length > 3) {
        NSMutableString *g = [NSMutableString string];
        NSUInteger first = intPart.length % 3 ?: 3;
        [g appendString:[intPart substringToIndex:first]];
        for (NSUInteger i = first; i < intPart.length; i += 3) { [g appendString:self.groupingSeparator]; [g appendString:[intPart substringWithRange:NSMakeRange(i, 3)]]; }
        intPart = g;
    }
    NSString *num = frac.length ? [NSString stringWithFormat:@"%@%@%@", intPart, self.decimalSeparator, frac] : intPart;
    if (v < 0) num = [@"-" stringByAppendingString:num];
    switch (_numberStyle) {
    case NSNumberFormatterPercentStyle: return [num stringByAppendingString:[_locale.languageCode isEqualToString:@"en"] ? @"%" : @" %"];
    case NSNumberFormatterCurrencyStyle: {
        BOOL after = ![_locale.languageCode isEqualToString:@"en"] && ![_locale.languageCode isEqualToString:@"pt"] && ![_locale.languageCode isEqualToString:@"ja"];
        return after ? [NSString stringWithFormat:@"%@ %@", num, self.currencySymbol] : [NSString stringWithFormat:@"%@%@%@", self.currencySymbol, [_locale.languageCode isEqualToString:@"pt"] ? @" " : @"", num]; }
    default: return num;
    }
}
- (NSNumber *)numberFromString:(NSString *)string {
    NSString *s = [string stringByReplacingOccurrencesOfString:self.groupingSeparator withString:@""];
    s = [s stringByReplacingOccurrencesOfString:self.decimalSeparator withString:@"."];
    s = [s stringByReplacingOccurrencesOfString:self.currencySymbol withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"%" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@" " withString:@""];
    char *end; const char *c = s.UTF8String; double v = strtod(c, &end);
    if (end == c || *end) return nil;
    if (_numberStyle == NSNumberFormatterPercentStyle) v /= 100;
    return v == (double)(long long)v ? @((long long)v) : @(v);
}
+ (NSString *)localizedStringFromNumber:(NSNumber *)n numberStyle:(NSNumberFormatterStyle)st {
    NSNumberFormatter *f = [NSNumberFormatter new]; f.numberStyle = st; return [f stringFromNumber:n];
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSNumber class]] ? [self stringFromNumber:obj] : nil; }
@end

/* ---------------- .strings tables ---------------- */
static NSString *parse_quoted(const char **pp, const char *end) {
    const char *p = *pp;
    if (p >= end || *p != '"') return nil;
    p++;
    char *buf = malloc((size_t)(end - p) + 1); size_t n = 0;
    while (p < end && *p != '"') {
        if (*p == '\\' && p + 1 < end) {
            p++;
            switch (*p) {
            case 'n': buf[n++] = '\n'; break;
            case 't': buf[n++] = '\t'; break;
            case 'r': buf[n++] = '\r'; break;
            case 'U': case 'u': {           /* \UXXXX */
                unsigned cp = 0; int k = 0;
                while (k < 4 && p + 1 < end && isxdigit((unsigned char)p[1])) { p++; cp = cp * 16 + (unsigned)(isdigit((unsigned char)*p) ? *p - '0' : (tolower(*p) - 'a' + 10)); k++; }
                if (cp < 0x80) buf[n++] = (char)cp;
                else if (cp < 0x800) { buf[n++] = (char)(0xC0 | cp >> 6); buf[n++] = (char)(0x80 | (cp & 0x3F)); }
                else { buf[n++] = (char)(0xE0 | cp >> 12); buf[n++] = (char)(0x80 | ((cp >> 6) & 0x3F)); buf[n++] = (char)(0x80 | (cp & 0x3F)); }
                break; }
            default: buf[n++] = *p; break;
            }
            p++;
        } else buf[n++] = *p++;
    }
    *pp = p < end ? p + 1 : p;
    NSString *s = [[NSString alloc] initWithBytes:buf length:n encoding:NSUTF8StringEncoding];
    free(buf);
    return s;
}
static void skip_ws_comments(const char **pp, const char *end) {
    const char *p = *pp;
    for (;;) {
        while (p < end && isspace((unsigned char)*p)) p++;
        if (p + 1 < end && p[0] == '/' && p[1] == '*') { const char *e = strstr(p + 2, "*/"); p = e ? e + 2 : end; continue; }
        if (p + 1 < end && p[0] == '/' && p[1] == '/') { while (p < end && *p != '\n') p++; continue; }
        break;
    }
    *pp = p;
}
NSDictionary *isim_parse_strings_file(NSString *path) {
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (!text) return nil;
    const char *p = text.UTF8String, *end = p + strlen(p);
    if (!strncmp(p, "\xEF\xBB\xBF", 3)) p += 3;
    skip_ws_comments(&p, end);
    if (p < end && *p == '<') { id d = isim_plist_parse(p, (NSUInteger)(end - p)); return [d isKindOfClass:[NSDictionary class]] ? d : nil; }
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    while (p < end) {
        skip_ws_comments(&p, end);
        NSString *k = parse_quoted(&p, end);
        if (!k) break;
        skip_ws_comments(&p, end);
        if (p < end && *p == '=') p++;
        skip_ws_comments(&p, end);
        NSString *v = parse_quoted(&p, end);
        if (!v) break;
        d[k] = v;
        skip_ws_comments(&p, end);
        if (p < end && *p == ';') p++;
    }
    return d;
}

/* Settings > General > Date & Time > Time Zone (the TZ environment variable wins) */
__attribute__((constructor)) static void isim_apply_time_zone_setting(void) {
    if (getenv("TZ")) return;
    NSString *tz = isim_global_preferences()[@"TimeZone"];
    if ([tz isKindOfClass:[NSString class]] && tz.length) { setenv("TZ", tz.UTF8String, 1); tzset(); }
}
