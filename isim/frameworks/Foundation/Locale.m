/* isim Foundation (ARC): NSLocale, NSTimeZone, NSDateFormatter, NSNumberFormatter and .strings localization.
 *
 * Device settings come from the environment set by `isim run` / `isim settings`:
 *   ISIM_LANGUAGES  preferred languages, comma separated (e.g. "pt-BR,en"); default "en"
 *   ISIM_LOCALE     region locale identifier (e.g. "pt_BR"); default derived from the first language
 *   ISIM_HOUR_CYCLE "12", "24" or unset (locale default)
 *   TZ              time zone name (honoured by the host C library)
 * Locale data (month names, date patterns, separators) is a small built-in table covering common
 * locales (hand-written to match iOS); every other locale and calendar comes from the host's ICU (ICU.m),
 * and without ICU falls back to its language's table or to en_US. */
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
#include "isim_locale.h"

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
/* Per-language strings (isim_locale.h). Plural forms: [one, other]; relative/duration unit order:
 * year, month, week, day, hour, minute, second. */
static const isim_lang_t LANGS[] = {
    { "en", { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" },
      { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
      { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }, { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }, "AM", "PM",
      { "BC", "AD" }, "and", "or", ", ", ", ",
      { "year", "month", "week", "day", "hour", "minute", "second" }, { "years", "months", "weeks", "days", "hours", "minutes", "seconds" },
      { "yr", "mth", "wk", "day", "hr", "min", "sec" }, { "yrs", "mths", "wks", "days", "hr", "min", "sec" },
      { "y", "mo", "w", "d", "h", "m", "s" },
      "in %@", "%@ ago", "yesterday", "today", "tomorrow", "now",
      { "last year", "last month", "last week", NULL, NULL, NULL, NULL }, { "this year", "this month", "this week", NULL, "this hour", "this minute", "now" },
      { "next year", "next month", "next week", NULL, NULL, NULL, NULL }, 0,
      { "bytes", "kB", "MB", "GB", "TB", "PB" }, "Zero", NULL },
    { "pt", { "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro" },
      { "jan.", "fev.", "mar.", "abr.", "mai.", "jun.", "jul.", "ago.", "set.", "out.", "nov.", "dez." },
      { "domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado" }, { "dom.", "seg.", "ter.", "qua.", "qui.", "sex.", "sáb." }, "AM", "PM",
      { "a.C.", "d.C." }, "e", "ou", ", ", " ",
      { "ano", "mês", "semana", "dia", "hora", "minuto", "segundo" }, { "anos", "meses", "semanas", "dias", "horas", "minutos", "segundos" },
      { "ano", "mês", "sem.", "dia", "h", "min", "s" }, { "anos", "meses", "sem.", "dias", "h", "min", "s" },
      { "a", "m", "sem", "d", "h", "min", "s" },
      "em %@", "há %@", "ontem", "hoje", "amanhã", "agora",
      { "ano passado", "mês passado", "semana passada", NULL, NULL, NULL, NULL }, { "este ano", "este mês", "esta semana", NULL, "esta hora", "este minuto", "agora" },
      { "próximo ano", "próximo mês", "próxima semana", NULL, NULL, NULL, NULL }, 1,
      { "bytes", "kB", "MB", "GB", "TB", "PB" }, "Zero", NULL },
    { "es", { "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" },
      { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic" },
      { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }, { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }, "a. m.", "p. m.",
      { "a. C.", "d. C." }, "y", "o", ", ", ", ",
      { "año", "mes", "semana", "día", "hora", "minuto", "segundo" }, { "años", "meses", "semanas", "días", "horas", "minutos", "segundos" },
      { "a", "m", "sem.", "d", "h", "min", "s" }, { "a", "m", "sem.", "d", "h", "min", "s" },
      { "a", "m", "sem", "d", "h", "min", "s" },
      "dentro de %@", "hace %@", "ayer", "hoy", "mañana", "ahora",
      { "el año pasado", "el mes pasado", "la semana pasada", NULL, NULL, NULL, NULL }, { "este año", "este mes", "esta semana", NULL, "esta hora", "este minuto", "ahora" },
      { "el próximo año", "el próximo mes", "la próxima semana", NULL, NULL, NULL, NULL }, 0,
      { "bytes", "kB", "MB", "GB", "TB", "PB" }, "Cero", NULL },
    { "fr", { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" },
      { "janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc." },
      { "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi" }, { "dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam." }, "AM", "PM",
      { "av. J.-C.", "ap. J.-C." }, "et", "ou", ", ", " ",
      { "an", "mois", "semaine", "jour", "heure", "minute", "seconde" }, { "ans", "mois", "semaines", "jours", "heures", "minutes", "secondes" },
      { "an", "m.", "sem.", "j", "h", "min", "s" }, { "ans", "m.", "sem.", "j", "h", "min", "s" },
      { "a", "m", "sem", "j", "h", "min", "s" },
      "dans %@", "il y a %@", "hier", "aujourd’hui", "demain", "maintenant",
      { "l’année dernière", "le mois dernier", "la semaine dernière", NULL, NULL, NULL, NULL }, { "cette année", "ce mois-ci", "cette semaine", NULL, "cette heure-ci", "cette minute-ci", "maintenant" },
      { "l’année prochaine", "le mois prochain", "la semaine prochaine", NULL, NULL, NULL, NULL }, 1,
      { "octets", "ko", "Mo", "Go", "To", "Po" }, "Zéro", NULL },
    { "de", { "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember" },
      { "Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez." },
      { "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag" }, { "So.", "Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa." }, "AM", "PM",
      { "v. Chr.", "n. Chr." }, "und", "oder", ", ", ", ",
      { "Jahr", "Monat", "Woche", "Tag", "Stunde", "Minute", "Sekunde" }, { "Jahre", "Monate", "Wochen", "Tage", "Stunden", "Minuten", "Sekunden" },
      { "J", "M", "W", "T", "Std.", "Min.", "Sek." }, { "J", "M", "W", "T", "Std.", "Min.", "Sek." },
      { "J", "M", "W", "T", "Std.", "Min.", "Sek." },
      "in %@", "vor %@", "gestern", "heute", "morgen", "jetzt",
      { "letztes Jahr", "letzten Monat", "letzte Woche", NULL, NULL, NULL, NULL }, { "dieses Jahr", "diesen Monat", "diese Woche", NULL, "in dieser Stunde", "in dieser Minute", "jetzt" },
      { "nächstes Jahr", "nächsten Monat", "nächste Woche", NULL, NULL, NULL, NULL }, 0,
      { "Byte", "kB", "MB", "GB", "TB", "PB" }, "Null",
      (const char *[]){ "Jahren", "Monaten", "Wochen", "Tagen", "Stunden", "Minuten", "Sekunden" } },
    { "it", { "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre" },
      { "gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic" },
      { "domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato" }, { "dom", "lun", "mar", "mer", "gio", "ven", "sab" }, "AM", "PM",
      { "a.C.", "d.C." }, "e", "o", ", ", ", ",
      { "anno", "mese", "settimana", "giorno", "ora", "minuto", "secondo" }, { "anni", "mesi", "settimane", "giorni", "ore", "minuti", "secondi" },
      { "anno", "mese", "sett.", "g", "h", "min", "s" }, { "anni", "mesi", "sett.", "gg", "h", "min", "s" },
      { "a", "m", "sett", "g", "h", "min", "s" },
      "tra %@", "%@ fa", "ieri", "oggi", "domani", "ora",
      { "anno scorso", "mese scorso", "settimana scorsa", NULL, NULL, NULL, NULL }, { "quest’anno", "questo mese", "questa settimana", NULL, "quest’ora", "questo minuto", "ora" },
      { "anno prossimo", "mese prossimo", "settimana prossima", NULL, NULL, NULL, NULL }, 0,
      { "byte", "kB", "MB", "GB", "TB", "PB" }, "Zero", NULL },
    { "ja", { "1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月" },
      { "1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月" },
      { "日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日" }, { "日", "月", "火", "水", "木", "金", "土" }, "午前", "午後",
      { "紀元前", "西暦" }, "", "または", "、", " ",
      { "年", "か月", "週間", "日", "時間", "分", "秒" }, { "年", "か月", "週間", "日", "時間", "分", "秒" },
      { "年", "か月", "週間", "日", "時間", "分", "秒" }, { "年", "か月", "週間", "日", "時間", "分", "秒" },
      { "年", "か月", "週間", "日", "時間", "分", "秒" },
      "%@後", "%@前", "昨日", "今日", "明日", "今",
      { "昨年", "先月", "先週", NULL, NULL, NULL, NULL }, { "今年", "今月", "今週", NULL, NULL, NULL, "今" },
      { "来年", "来月", "来週", NULL, NULL, NULL, NULL }, 0,
      { "バイト", "KB", "MB", "GB", "TB", "PB" }, "0", NULL },
};
BOOL isim_lang_builtin(NSString *lang) {
    for (size_t i = 0; i < sizeof LANGS / sizeof *LANGS; i++) if ([lang isEqualToString:@(LANGS[i].lang)]) return YES;
    return NO;
}
/* the built-in table for its languages; any other language from the host's ICU (ICU.m); English without ICU */
const isim_lang_t *isim_lang(NSString *lang) {
    for (size_t i = 0; i < sizeof LANGS / sizeof *LANGS; i++) if ([lang isEqualToString:@(LANGS[i].lang)]) return &LANGS[i];
    const isim_lang_t *icu = isim_icu_lang(lang);
    return icu ?: &LANGS[0];
}

#define NB " "
#define NNB " "
/* patterns use Unicode/ICU date symbols */
static const isim_region_t REGIONS[] = {
    { "en_US", ".", ",", "USD", "$", 1, 0, "M/d/yy", "MMM d, y", "MMMM d, y", "EEEE, MMMM d, y", 1, 0, "¤#", "#%", 1 },
    { "en_GB", ".", ",", "GBP", "£", 0, 1, "dd/MM/y", "d MMM y", "d MMMM y", "EEEE d MMMM y", 1, 0, "¤#", "#%", 2 },
    { "en_CA", ".", ",", "CAD", "$", 1, 1, "y-MM-dd", "MMM d, y", "MMMM d, y", "EEEE, MMMM d, y", 1, 0, "¤#", "#%", 1 },
    { "en_AU", ".", ",", "AUD", "$", 1, 1, "d/M/yy", "d MMM y", "d MMMM y", "EEEE d MMMM y", 1, 0, "¤#", "#%", 2 },
    { "en_IN", ".", ",", "INR", "₹", 1, 1, "dd/MM/yy", "dd-MMM-y", "d MMMM y", "EEEE, d MMMM, y", 1, 1, "¤#", "#%", 1 },
    { "pt_BR", ",", ".", "BRL", "R$", 0, 1, "dd/MM/y", "d 'de' MMM 'de' y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y", 1, 0, "¤" NB "#", "#%", 1 },
    { "pt_PT", ",", NB, "EUR", "€", 0, 1, "dd/MM/yy", "dd/MM/y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y", 2, 0, "#" NB "¤", "#%", 2 },
    { "es_ES", ",", ".", "EUR", "€", 0, 1, "d/M/yy", "d MMM y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y", 2, 0, "#" NB "¤", "#" NB "%", 2 },
    { "es_MX", ".", ",", "MXN", "$", 0, 1, "dd/MM/yy", "d MMM y", "d 'de' MMMM 'de' y", "EEEE, d 'de' MMMM 'de' y", 1, 0, "¤#", "#" NB "%", 1 },
    { "fr_FR", ",", NNB, "EUR", "€", 0, 1, "dd/MM/y", "d MMM y", "d MMMM y", "EEEE d MMMM y", 1, 0, "#" NB "¤", "#" NNB "%", 2 },
    { "fr_CA", ",", NB, "CAD", "$", 0, 1, "y-MM-dd", "d MMM y", "d MMMM y", "EEEE d MMMM y", 1, 0, "#" NB "¤", "#" NB "%", 1 },
    { "de_DE", ",", ".", "EUR", "€", 0, 1, "dd.MM.yy", "dd.MM.y", "d. MMMM y", "EEEE, d. MMMM y", 1, 0, "#" NB "¤", "#" NB "%", 2 },
    { "it_IT", ",", ".", "EUR", "€", 0, 1, "dd/MM/yy", "d MMM y", "d MMMM y", "EEEE d MMMM y", 1, 0, "#" NB "¤", "#%", 2 },
    { "ja_JP", ".", ",", "JPY", "￥", 0, 1, "y/MM/dd", "y/MM/dd", "y年M月d日", "y年M月d日EEEE", 1, 0, "¤#", "#%", 1 },
    { "ar_SA", "٫", "٬", "SAR", "ر.س.‏", 1, 1, "d‏/M‏/y", "dd‏/MM‏/y", "d MMMM y", "EEEE، d MMMM y", 1, 0, "#" NB "¤", "#%", 1 },
};
/* a built-in row for its locales; any other locale from the host's ICU (ICU.m); without ICU, a row of the same
 * language or en_US */
static const isim_region_t *region_for(NSString *ident) {
    for (size_t i = 0; i < sizeof REGIONS / sizeof *REGIONS; i++) if ([ident isEqualToString:@(REGIONS[i].loc)]) return &REGIONS[i];
    const isim_region_t *icu = isim_icu_region(ident);
    if (icu) return icu;
    NSString *lang = [ident componentsSeparatedByString:@"_"].firstObject;
    for (size_t i = 0; i < sizeof REGIONS / sizeof *REGIONS; i++) if ([@(REGIONS[i].loc) hasPrefix:[lang stringByAppendingString:@"_"]]) return &REGIONS[i];
    return &REGIONS[0];
}
BOOL isim_region_builtin(NSString *ident) {
    for (size_t i = 0; i < sizeof REGIONS / sizeof *REGIONS; i++) if ([ident isEqualToString:@(REGIONS[i].loc)]) return YES;
    return NO;
}
#define builtin_region isim_region_builtin
const isim_region_t *isim_region(NSString *ident) { return region_for(ident.length ? ident : default_locale_identifier()); }
NSString *isim_locale_ident(NSLocale *l) { NSString *i = (l ?: NSLocale.currentLocale).localeIdentifier; return i.length ? i : @"en_US"; }
NSString *isim_locale_lang(NSLocale *l) { NSString *c = (l ?: NSLocale.currentLocale).languageCode; return c.length ? c : @"en"; }

BOOL isim_plural_one(NSString *lang, double n, int fractionDigits) {
    if (!isim_lang_builtin(lang) && isim_icu_on()) {                       /* CLDR plural rules from ICU */
        NSString *cat = isim_icu_plural_category(lang, fractionDigits && n == floor(n) ? n + 0.5 : n, NO);
        if (cat) return [cat isEqualToString:@"one"];
    }
    if ([lang isEqualToString:@"ja"] || [lang isEqualToString:@"zh"] || [lang isEqualToString:@"ko"]) return NO;
    if ([lang isEqualToString:@"fr"] || [lang isEqualToString:@"pt"]) return fabs(n) < 2;          /* i = 0,1 */
    return fabs(n) == 1 && fractionDigits == 0;
}

/* ---------- date patterns from skeletons (a small CLDR "availableFormats" stand-in) ---------- */
typedef struct {
    const char *loc;                                   /* "en_US", or language "pt" */
    const char *num_ymd, *num_md, *num_ym;             /* numeric month */
    const char *txt_ymd, *txt_md, *txt_ym;             /* text month (MMM is replaced by the requested width) */
    const char *wtxt_ymd, *wtxt_md;                    /* with weekday (EEE replaced by the requested width) */
    const char *wnum_ymd, *wnum_md;
    const char *wide_ymd, *wide_md, *wide_ym;          /* MMMM variants when they differ (es) */
} skel_t;
static const skel_t SKELS[] = {
    { "en_US", "M/d/y", "M/d", "M/y", "MMM d, y", "MMM d", "MMM y", "EEE, MMM d, y", "EEE, MMM d", "EEE, M/d/y", "EEE, M/d" },
    { "en_CA", "y-MM-dd", "MM-dd", "y-MM", "MMM d, y", "MMM d", "MMM y", "EEE, MMM d, y", "EEE, MMM d", "EEE, y-MM-dd", "EEE, MM-dd" },
    { "en_IN", "d/M/y", "d/M", "M/y", "d MMM y", "d MMM", "MMM y", "EEE, d MMM y", "EEE, d MMM", "EEE, d/M/y", "EEE, d/M" },
    { "en", "dd/MM/y", "dd/MM", "MM/y", "d MMM y", "d MMM", "MMM y", "EEE, d MMM y", "EEE d MMM", "EEE, dd/MM/y", "EEE dd/MM" },
    { "pt", "dd/MM/y", "dd/MM", "MM/y", "d 'de' MMM 'de' y", "d 'de' MMM", "MMM 'de' y", "EEE, d 'de' MMM 'de' y", "EEE, d 'de' MMM", "EEE, dd/MM/y", "EEE, dd/MM" },
    { "es_ES", "d/M/y", "d/M", "M/y", "d MMM y", "d MMM", "MMM y", "EEE, d MMM y", "EEE, d MMM", "EEE, d/M/y", "EEE, d/M",
      "d 'de' MMMM 'de' y", "d 'de' MMMM", "MMMM 'de' y" },
    { "es", "dd/MM/y", "dd/MM", "MM/y", "d MMM y", "d MMM", "MMM y", "EEE, d MMM y", "EEE, d MMM", "EEE, dd/MM/y", "EEE, dd/MM",
      "d 'de' MMMM 'de' y", "d 'de' MMMM", "MMMM 'de' y" },
    { "fr_CA", "y-MM-dd", "MM-dd", "y-MM", "d MMM y", "d MMM", "MMM y", "EEE d MMM y", "EEE d MMM", "EEE y-MM-dd", "EEE MM-dd" },
    { "fr", "dd/MM/y", "dd/MM", "MM/y", "d MMM y", "d MMM", "MMM y", "EEE d MMM y", "EEE d MMM", "EEE dd/MM/y", "EEE dd/MM" },
    { "de", "d.M.y", "d.M.", "M/y", "d. MMM y", "d. MMM", "MMM y", "EEE, d. MMM y", "EEE, d. MMM", "EEE, d.M.y", "EEE, d.M." },
    { "it", "d/M/y", "d/M", "M/y", "d MMM y", "d MMM", "MMM y", "EEE d MMM y", "EEE d MMM", "EEE d/M/y", "EEE d/M" },
    { "ja", "y/M/d", "M/d", "y/M", "y年M月d日", "M月d日", "y年M月", "y年M月d日(EEE)", "M月d日(EEE)", "y/M/d(EEE)", "M/d(EEE)" },
    { "ar", "d‏/M‏/y", "d‏/M", "M‏/y", "d MMM y", "d MMM", "MMM y", "EEE، d MMM y", "EEE، d MMM", "EEE، d‏/M‏/y", "EEE، d/‏M" },
};
static const skel_t *skel_for(NSString *ident) {
    NSString *lang = [ident componentsSeparatedByString:@"_"].firstObject;
    for (size_t i = 0; i < sizeof SKELS / sizeof *SKELS; i++) if ([ident isEqualToString:@(SKELS[i].loc)]) return &SKELS[i];
    for (size_t i = 0; i < sizeof SKELS / sizeof *SKELS; i++) if ([lang isEqualToString:@(SKELS[i].loc)]) return &SKELS[i];
    return &SKELS[0];
}
static NSString *repeat_char(char c, NSUInteger n) { char b[16]; n = MIN(n, (NSUInteger)15); memset(b, c, n); b[n] = 0; return @(b); }
/* replace a run of c (exactly as written in the pattern, outside quotes) by `with` */
static NSString *replace_field(NSString *pat, char c, NSString *with) {
    NSMutableString *out = [NSMutableString string];
    BOOL quoted = NO;
    NSUInteger n = pat.length;
    for (NSUInteger i = 0; i < n;) {
        unichar ch = [pat characterAtIndex:i];
        if (ch == '\'') { quoted = !quoted; [out appendString:@"'"]; i++; continue; }
        if (!quoted && ch == c) {
            NSUInteger k = i; while (k < n && [pat characterAtIndex:k] == c) k++;
            [out appendString:with]; i = k; continue;
        }
        [out appendString:[pat substringWithRange:NSMakeRange(i, 1)]]; i++;
    }
    return out;
}
NSString *isim_date_pattern(NSString *skeleton, NSLocale *locale) {
    NSString *ident = isim_locale_ident(locale);
    NSString *lang = isim_locale_lang(locale);
    int cnt[128] = {0};
    for (NSUInteger i = 0; i < skeleton.length; i++) { unichar c = [skeleton characterAtIndex:i]; if (c < 128) cnt[c]++; }
    int y = cnt['y'] + cnt['Y'] + cnt['u'], M = cnt['M'] + cnt['L'], d = cnt['d'], E = cnt['E'] + cnt['c'] + cnt['e'];
    int G = cnt['G'], Q = cnt['Q'] + cnt['q'], w = cnt['w'], D = cnt['D'];
    int h12 = cnt['h'] + cnt['K'], h24 = cnt['H'] + cnt['k'], hj = cnt['j'] + cnt['J'] + cnt['C'];
    int m = cnt['m'], s = cnt['s'], S = cnt['S'], a = cnt['a'] + cnt['b'] + cnt['B'];
    int z = cnt['z'], Z = cnt['Z'], v = cnt['v'], V = cnt['V'], O = cnt['O'], X = cnt['X'] + cnt['x'];
    const skel_t *sk = skel_for(ident);
    BOOL ja = [lang isEqualToString:@"ja"];
    /* ---- date part ---- */
    NSString *date = nil;
    if (M) {
        BOOL text = M >= 3;
        NSString *pat;
        if (text && M >= 4 && sk->wide_ymd) pat = d && y ? @(sk->wide_ymd) : d ? @(sk->wide_md) : y ? @(sk->wide_ym) : @"MMMM";
        else if (text) pat = E && d ? (y ? @(sk->wtxt_ymd) : @(sk->wtxt_md)) : d && y ? @(sk->txt_ymd) : d ? @(sk->txt_md) : y ? @(sk->txt_ym) : @"LLL";
        else pat = E && d ? (y ? @(sk->wnum_ymd) : @(sk->wnum_md)) : d && y ? @(sk->num_ymd) : d ? @(sk->num_md) : y ? @(sk->num_ym) : @"L";
        if (text && !ja) pat = replace_field(pat, 'M', repeat_char('M', (NSUInteger)M));
        if (!text && M == 2) pat = replace_field(pat, 'M', @"MM");
        if ([pat isEqualToString:@"LLL"]) pat = repeat_char('L', (NSUInteger)M);
        if (d == 2) pat = replace_field(pat, 'd', @"dd");
        if (y == 2) pat = replace_field(pat, 'y', @"yy");
        if (E && [pat rangeOfString:@"EEE"].location != NSNotFound) pat = replace_field(pat, 'E', repeat_char('E', (NSUInteger)MAX(E, 3)));
        else if (E) {
            BOOL comma = !([lang isEqualToString:@"fr"] || [lang isEqualToString:@"it"]);
            pat = [NSString stringWithFormat:@"%@%@ %@", repeat_char('E', (NSUInteger)MAX(E, 3)), comma ? @"," : @"", pat];
        }
        date = pat;
    } else if (d) {
        date = d == 2 ? @"dd" : @"d";
        if (E) date = ja ? [date stringByAppendingFormat:@"日(%@)", repeat_char('E', (NSUInteger)MAX(E, 3))] : [NSString stringWithFormat:@"%@ %@", date, repeat_char('E', (NSUInteger)MAX(E, 3))];
        else if (ja) date = [date stringByAppendingString:@"日"];
    } else if (y) {
        date = y == 2 ? @"yy" : @"y";
        if (ja) date = [date stringByAppendingString:@"年"];
        if (Q) date = [NSString stringWithFormat:@"%@ %@", repeat_char('Q', (NSUInteger)Q), date];
    } else if (E) {
        date = repeat_char('c', (NSUInteger)MAX(E, 3));
    } else if (Q) {
        date = repeat_char('Q', (NSUInteger)Q);
    }
    if (G && date) date = [date stringByAppendingFormat:@" %@", repeat_char('G', (NSUInteger)G)];
    if (w && !date) date = [@"w" copy];
    if (D && !date) date = [@"D" copy];
    /* ---- time part ---- */
    NSString *time = nil;
    BOOL use12 = h12 ? YES : h24 ? NO : isim_uses_12h(locale);
    int hours = h12 + h24 + hj;
    if (hours || m || s) {
        NSMutableString *t = [NSMutableString string];
        BOOL shortH = [lang isEqualToString:@"es"] || [lang isEqualToString:@"ja"];
        if (hours) [t appendString:use12 ? (h12 && cnt['K'] ? @"K" : (hours >= 2 && !m ? @"hh" : @"h")) : (shortH && hours < 2 ? @"H" : @"HH")];
        if (m) [t appendString:hours ? @":mm" : @"mm"];
        if (s) [t appendString:(hours || m) ? @":ss" : @"ss"];
        if (S) [t appendFormat:@".%@", repeat_char('S', (NSUInteger)S)];
        if (!hours && m && s) { [t setString:@"mm:ss"]; if (S) [t appendFormat:@".%@", repeat_char('S', (NSUInteger)S)]; }
        if (hours && !m && !s && !use12 && [lang isEqualToString:@"de"]) [t appendString:@" 'Uhr'"];
        if (hours && use12 && !cnt['J']) {
            if (ja) [t insertString:@"a" atIndex:0];
            else [t appendString:[lang isEqualToString:@"en"] ? @" a" : @" a"];
        } else if (a && !hours) [t appendString:@" a"];
        if (z) [t appendFormat:@" %@", repeat_char('z', (NSUInteger)z)];
        else if (v) [t appendFormat:@" %@", repeat_char('v', (NSUInteger)v)];
        else if (Z) [t appendFormat:@" %@", repeat_char('Z', (NSUInteger)Z)];
        else if (O) [t appendFormat:@" %@", repeat_char('O', (NSUInteger)O)];
        else if (V) [t appendFormat:@" %@", repeat_char('V', (NSUInteger)V)];
        else if (X) [t appendFormat:@" %@", repeat_char('X', (NSUInteger)X)];
        time = t;
    }
    if (date && time) {
        NSString *sep = @(isim_lang(lang)->dateTimeSep);
        if (M >= 4) {                                   /* long/full dates: "{1} 'at' {0}" */
            if ([lang isEqualToString:@"en"]) sep = @" 'at' ";
            else if ([lang isEqualToString:@"pt"]) sep = @" 'às' ";
            else if ([lang isEqualToString:@"de"]) sep = @" 'um' ";
            else if ([lang isEqualToString:@"fr"]) sep = @" 'à' ";
        }
        return [NSString stringWithFormat:@"%@%@%@", date, sep, time];
    }
    return date ?: time ?: @"";
}
NSString *isim_style_pattern(NSInteger dateStyle, NSInteger timeStyle, NSLocale *locale) {
    const isim_region_t *r = region_for(isim_locale_ident(locale));
    NSString *lang = isim_locale_lang(locale);
    NSString *d = nil, *t = nil;
    switch (dateStyle) {
    case 1: d = @(r->dShort); break;
    case 2: d = @(r->dMedium); break;
    case 3: d = @(r->dLong); break;
    case 4: d = @(r->dFull); break;
    default: break;
    }
    switch (timeStyle) {
    case 1: t = isim_date_pattern(@"jmm", locale); break;
    case 2: t = isim_date_pattern(@"jmmss", locale); break;
    case 3: t = isim_date_pattern(@"jmmssz", locale); break;
    case 4: t = isim_date_pattern(@"jmmsszzzz", locale); break;
    default: break;
    }
    if (d && t) {
        BOOL en = [lang isEqualToString:@"en"];
        NSString *sep = @(isim_lang(lang)->dateTimeSep);
        if (dateStyle >= 3) {
            if (en) sep = @" 'at' ";
            else if ([lang isEqualToString:@"pt"]) sep = @" 'às' ";
            else if ([lang isEqualToString:@"de"]) sep = @" 'um' ";
            else if ([lang isEqualToString:@"fr"]) sep = @" 'à' ";
        }
        return [NSString stringWithFormat:@"%@%@%@", d, sep, t];
    }
    return d ?: t ?: @"";
}

/* ---------- currencies ---------- */
typedef struct { const char *code, *symbol, *one, *other; int digits; } currency_t;
static const currency_t CURRENCIES[] = {
    { "USD", "US$", "US dollar", "US dollars", 2 }, { "EUR", "€", "euro", "euros", 2 }, { "GBP", "£", "British pound", "British pounds", 2 },
    { "JPY", "¥", "Japanese yen", "Japanese yen", 0 }, { "BRL", "R$", "Brazilian real", "Brazilian reals", 2 },
    { "CAD", "CA$", "Canadian dollar", "Canadian dollars", 2 }, { "AUD", "A$", "Australian dollar", "Australian dollars", 2 },
    { "INR", "₹", "Indian rupee", "Indian rupees", 2 }, { "MXN", "MX$", "Mexican peso", "Mexican pesos", 2 },
    { "CNY", "CN¥", "Chinese yuan", "Chinese yuan", 2 }, { "CHF", "CHF", "Swiss franc", "Swiss francs", 2 },
    { "KRW", "₩", "South Korean won", "South Korean won", 0 }, { "SAR", "SAR", "Saudi riyal", "Saudi riyals", 2 },
    { "SEK", "SEK", "Swedish krona", "Swedish kronor", 2 }, { "NOK", "NOK", "Norwegian krone", "Norwegian kroner", 2 },
    { "DKK", "DKK", "Danish krone", "Danish kroner", 2 }, { "PLN", "PLN", "Polish zloty", "Polish zlotys", 2 },
    { "RUB", "RUB", "Russian ruble", "Russian rubles", 2 }, { "TRY", "TRY", "Turkish lira", "Turkish lira", 2 },
    { "ARS", "ARS", "Argentine peso", "Argentine pesos", 2 }, { "CLP", "CLP", "Chilean peso", "Chilean pesos", 0 },
    { "COP", "COP", "Colombian peso", "Colombian pesos", 2 }, { "NZD", "NZ$", "New Zealand dollar", "New Zealand dollars", 2 },
    { "HKD", "HK$", "Hong Kong dollar", "Hong Kong dollars", 2 }, { "SGD", "SGD", "Singapore dollar", "Singapore dollars", 2 },
    { "BTC", "BTC", "Bitcoin", "Bitcoins", 2 },
};
static const currency_t *currency_for(NSString *code) {
    for (size_t i = 0; i < sizeof CURRENCIES / sizeof *CURRENCIES; i++) if ([code isEqualToString:@(CURRENCIES[i].code)]) return &CURRENCIES[i];
    return NULL;
}
NSString *isim_currency_symbol(NSString *code, NSLocale *locale) {
    const isim_region_t *r = region_for(isim_locale_ident(locale));
    NSString *lang = isim_locale_lang(locale);
    if (isim_icu_on() && code.length && (!builtin_region(isim_locale_ident(locale)) || !currency_for(code))) {
        NSString *s = isim_icu_currency_string(isim_locale_ident(locale), code, 0, nil);
        if (s) return s;
    }
    if (!code.length || [code isEqualToString:@(r->currencyCode)]) return @(r->currencySymbol);
    if ([code isEqualToString:@"USD"]) {
        if ([lang isEqualToString:@"de"] || [lang isEqualToString:@"it"] || [lang isEqualToString:@"ja"]) return @"$";
        if ([lang isEqualToString:@"fr"]) return @"$US";
        return @"US$";
    }
    if ([code isEqualToString:@"JPY"] && [lang isEqualToString:@"en"]) return @"¥";
    if ([code isEqualToString:@"JPY"]) return [lang isEqualToString:@"ja"] ? @"￥" : @"JPY";
    const currency_t *c = currency_for(code);
    return c ? @(c->symbol) : code;
}
NSString *isim_currency_name(NSString *code, BOOL plural) {
    const currency_t *c = currency_for(code);
    return c ? @(plural ? c->other : c->one) : code;
}
int isim_currency_digits(NSString *code) {
    const currency_t *c = currency_for(code);
    if (c) return c->digits;
    NSString *icu = isim_icu_on() ? isim_icu_currency_string(@"en", code, 5, nil) : nil;
    return icu ? icu.intValue : 2;
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

@interface NSLocale (IsimCurrent)
- (BOOL)_isim_isCurrent;
@end
BOOL isim_uses_12h(NSLocale *locale) {
    /* the user's 24-Hour Time setting applies to the current locale only (like iOS); a Locale made from an
     * identifier uses the region's default hour cycle */
    if (locale && ![locale _isim_isCurrent]) return region_for(isim_locale_ident(locale))->hour12;
    const char *hc = getenv("ISIM_HOUR_CYCLE");
    if (hc && !strcmp(hc, "24")) return NO;
    if (hc && !strcmp(hc, "12")) return YES;
    NSDictionary *g = isim_global_preferences();                             /* Settings > General > Date & Time */
    if ([g[@"AppleICUForce24HourTime"] boolValue]) return NO;
    if ([g[@"AppleICUForce12HourTime"] boolValue]) return YES;
    return region_for(isim_locale_ident(locale))->hour12;
}

/* ---------------- NSLocale ---------------- */
/* Foundation calendar identifiers <-> ICU's calendar keyword values */
static NSDictionary<NSString *, NSString *> *calendar_names(void) {
    return @{ @"gregorian": @"gregorian", @"buddhist": @"buddhist", @"chinese": @"chinese", @"coptic": @"coptic",
              @"ethiopic": @"ethiopic", @"ethiopic-amete-alem": @"ethiopic-amete-alem", @"hebrew": @"hebrew", @"iso8601": @"iso8601",
              @"indian": @"indian", @"islamic": @"islamic", @"islamic-civil": @"islamic-civil", @"japanese": @"japanese",
              @"persian": @"persian", @"roc": @"roc", @"islamic-tbla": @"islamic-tbla", @"islamic-umalqura": @"islamic-umalqura",
              @"dangi": @"dangi", @"vietnamese": @"chinese", @"bangla": @"indian", @"gujarati": @"indian", @"kannada": @"indian",
              @"malayalam": @"indian", @"marathi": @"indian", @"odia": @"indian", @"tamil": @"indian", @"telugu": @"indian" };
}
NSString *isim_icu_calendar_name(NSString *foundationID) {
    NSDictionary *m = @{ @"ethiopicAmeteMihret": @"ethiopic", @"ethiopicAmeteAlem": @"ethiopic-amete-alem", @"islamicCivil": @"islamic-civil",
                         @"republicOfChina": @"roc", @"islamicTabular": @"islamic-tbla", @"islamicUmmAlQura": @"islamic-umalqura",
                         @"vietnamese": @"chinese" };
    return m[foundationID] ?: foundationID;
}
NSString *isim_foundation_calendar_id(NSString *icuName) {
    NSDictionary *m = @{ @"ethiopic": @"ethiopic", @"ethiopic-amete-alem": @"ethiopic-amete-alem", @"islamic-civil": @"islamic-civil",
                         @"roc": @"roc", @"islamic-tbla": @"islamic-tbla", @"islamic-umalqura": @"islamic-umalqura" };
    return calendar_names()[icuName] ? (m[icuName] ?: icuName) : @"gregorian";
}

@implementation NSLocale { NSString *_ident; NSString *_lang, *_region, *_script, *_calendar; BOOL _current; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSLocale class]); }    /* NS.identifier */
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithLocaleIdentifier:[c decodeObjectOfClass:[NSString class] forKey:@"NS.identifier"] ?: @""]; }
+ (NSLocale *)currentLocale { NSLocale *l = [self localeWithLocaleIdentifier:default_locale_identifier()]; l->_current = YES; return l; }
- (BOOL)_isim_isCurrent { return _current; }
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
        NSRange at = [_ident rangeOfString:@"@"];                       /* "he_IL@calendar=hebrew" */
        NSString *base = at.location == NSNotFound ? _ident : [_ident substringToIndex:at.location];
        if (at.location != NSNotFound) {
            for (NSString *kv in [[_ident substringFromIndex:at.location + 1] componentsSeparatedByString:@";"]) {
                NSArray *p = [kv componentsSeparatedByString:@"="];
                if (p.count == 2 && [p[0] isEqualToString:@"calendar"]) _calendar = isim_foundation_calendar_id(p[1]);
            }
        }
        NSArray *parts = [base componentsSeparatedByString:@"_"];
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
- (NSString *)calendarIdentifier { return _calendar ?: @"gregorian"; }
- (const isim_region_t *)_region { return region_for(_ident.length ? _ident : default_locale_identifier()); }
- (NSString *)decimalSeparator { return @([self _region]->decimal); }
- (NSString *)groupingSeparator { return @([self _region]->group); }
- (NSString *)currencySymbol { return @([self _region]->currencySymbol); }
- (NSString *)currencyCode { return @([self _region]->currencyCode); }
- (BOOL)usesMetricSystem { return [self _region]->metric; }
- (BOOL)_isim_uses12Hour { return isim_uses_12h(self); }
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
    NSString *icu = isim_icu_display(isim_icu_locale_id(self), [code stringByReplacingOccurrencesOfString:@"-" withString:@"_"], 1);
    if (icu) return icu;
    NSArray *n = language_names()[[code componentsSeparatedByString:@"-"].firstObject];
    if (!n) return nil;
    return [_lang isEqualToString:[code componentsSeparatedByString:@"-"].firstObject] ? n[1] : n[0];
}
- (NSString *)localizedStringForCountryCode:(NSString *)code {
    return isim_icu_display(isim_icu_locale_id(self), code.uppercaseString, 2) ?: country_names()[code.uppercaseString];
}
- (NSString *)localizedStringForScriptCode:(NSString *)code { return isim_icu_display(isim_icu_locale_id(self), code, 3); }
- (NSString *)localizedStringForCurrencyCode:(NSString *)code {
    return isim_icu_display(isim_icu_locale_id(self), code.uppercaseString, 5) ?: isim_currency_name(code.uppercaseString, NO);
}
- (NSString *)localizedStringForCalendarIdentifier:(NSString *)ident { return isim_icu_display(isim_icu_locale_id(self), isim_icu_calendar_name(ident), 4); }
- (NSString *)localizedStringForLocaleIdentifier:(NSString *)ident {
    NSString *icu = isim_icu_display(isim_icu_locale_id(self), [ident stringByReplacingOccurrencesOfString:@"-" withString:@"_"], 0);
    if (icu) return icu;
    NSLocale *l = [NSLocale localeWithLocaleIdentifier:ident];
    NSString *lang = [self localizedStringForLanguageCode:l.languageCode ?: @""] ?: ident;
    NSString *country = l.countryCode ? [self localizedStringForCountryCode:l.countryCode] : nil;
    return country ? [NSString stringWithFormat:@"%@ (%@)", lang, country] : lang;
}
- (NSString *)displayNameForKey:(NSLocaleKey)key value:(id)value {
    if ([key isEqualToString:NSLocaleIdentifier]) return [self localizedStringForLocaleIdentifier:value];
    if ([key isEqualToString:NSLocaleLanguageCode]) return [self localizedStringForLanguageCode:value];
    if ([key isEqualToString:NSLocaleCountryCode]) return [self localizedStringForCountryCode:value];
    if ([key isEqualToString:NSLocaleScriptCode]) return [self localizedStringForScriptCode:value];
    if ([key isEqualToString:NSLocaleCurrencyCode]) return [self localizedStringForCurrencyCode:value];
    if ([key isEqualToString:NSLocaleCalendarIdentifier]) return [self localizedStringForCalendarIdentifier:value];
    return nil;
}
+ (NSLocaleLanguageDirection)characterDirectionForLanguage:(NSString *)code {
    NSString *l = [code componentsSeparatedByString:@"-"].firstObject;
    return [@[@"ar", @"he", @"fa", @"ur", @"yi"] containsObject:l] ? NSLocaleLanguageDirectionRightToLeft : NSLocaleLanguageDirectionLeftToRight;
}
@end

/* ---------------- NSTimeZone ---------------- */
NSNotificationName const NSSystemTimeZoneDidChangeNotification = @"NSSystemTimeZoneDidChangeNotification";
void isim_reapply_time_zone_setting(void);
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
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSTimeZone class]); }    /* NS.name */
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithName:[c decodeObjectOfClass:[NSString class] forKey:@"NS.name"] ?: @"GMT"]; }
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
+ (void)resetSystemTimeZone { isim_reapply_time_zone_setting(); }
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
- (NSString *)editingStringForObjectValue:(id)obj { return [self stringForObjectValue:obj]; }
- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error { if (obj) *obj = string; return YES; }
- (id)copyWithZone:(NSZone *)z { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
@end

typedef struct { struct tm tm; double frac; long offset; } isim_bdate;
static void broken_down(NSDate *date, NSTimeZone *tz, isim_bdate *b) {
    double t = date.timeIntervalSince1970;
    double whole = floor(t);
    b->frac = t - whole;
    b->offset = [tz secondsFromGMTForDate:date];
    time_t tt = (time_t)whole + b->offset;
    gmtime_r(&tt, &b->tm);
}
static void append_num(NSMutableString *out, long v, NSUInteger width) { [out appendFormat:@"%0*ld", (int)width, v]; }
static NSString *narrow(const char *s) {
    NSString *w = @(s); if (!w.length) return w;
    NSRange r = [w rangeOfComposedCharacterSequenceAtIndex:0];
    return [w substringWithRange:r].uppercaseString;
}
/* ISO 8601 week-of-year and its year */
static int iso_weeks_in_year(int y) {
    struct tm t = { .tm_year = y - 1900, .tm_mday = 1 }; time_t tt = timegm(&t); gmtime_r(&tt, &t);
    int jan1 = (t.tm_wday + 6) % 7;                   /* Monday = 0 */
    BOOL leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
    return jan1 == 3 || (leap && jan1 == 2) ? 53 : 52;
}
static void iso_week(const struct tm *tm, int *week, int *year) {
    int wday = (tm->tm_wday + 6) % 7, y = tm->tm_year + 1900;
    int w = (tm->tm_yday - wday + 10) / 7;
    if (w < 1) { y--; w = iso_weeks_in_year(y); }
    else if (w > iso_weeks_in_year(y)) { y++; w = 1; }
    *week = w; *year = y;
}
NSString *isim_format_date(NSDate *date, NSString *fmt, NSLocale *locale, NSTimeZone *tz, NSDictionary *symbols) {
    isim_bdate bd; broken_down(date, tz, &bd);
    struct tm *tm = &bd.tm;
    const isim_lang_t *n = isim_lang(isim_locale_lang(locale));
    NSMutableString *out = [NSMutableString string];
    NSUInteger len = fmt.length;
    NSString *am = symbols[@"AM"] ?: @(n->am), *pm = symbols[@"PM"] ?: @(n->pm);
    for (NSUInteger i = 0; i < len;) {
        unichar c = [fmt characterAtIndex:i];
        if (c == '\'') {                                           /* quoted literal; '' is a quote */
            NSUInteger j = i + 1;
            if (j < len && [fmt characterAtIndex:j] == '\'') { [out appendString:@"'"]; i += 2; continue; }
            NSMutableString *lit = [NSMutableString string];
            while (j < len) {
                unichar q = [fmt characterAtIndex:j];
                if (q == '\'') { if (j + 1 < len && [fmt characterAtIndex:j + 1] == '\'') { [lit appendString:@"'"]; j += 2; continue; } break; }
                [lit appendString:[fmt substringWithRange:NSMakeRange(j, 1)]]; j++;
            }
            [out appendString:lit];
            i = j + 1; continue;
        }
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))) { [out appendString:[fmt substringWithRange:NSMakeRange(i, 1)]]; i++; continue; }
        NSUInteger k = i; while (k < len && [fmt characterAtIndex:k] == c) k++;
        NSUInteger cnt = k - i; i = k;
        int year = tm->tm_year + 1900, hour12 = tm->tm_hour % 12 ? tm->tm_hour % 12 : 12;
        long off = bd.offset;
        switch (c) {
        case 'G': [out appendString:@(n->eras[year > 0 ? 1 : 0])]; break;
        case 'y': case 'u':
            if (cnt == 2) append_num(out, year % 100, 2); else append_num(out, year, cnt); break;
        case 'Y': { int w, wy; iso_week(tm, &w, &wy); if (cnt == 2) append_num(out, wy % 100, 2); else append_num(out, wy, cnt); break; }
        case 'Q': case 'q': {
            int q = tm->tm_mon / 3 + 1;
            if (cnt <= 2) append_num(out, q, cnt);
            else if (cnt == 3) [out appendFormat:@"Q%d", q];
            else [out appendString:@[@"1st quarter", @"2nd quarter", @"3rd quarter", @"4th quarter"][q - 1]];
            break; }
        case 'M': case 'L': {
            NSArray *ms = cnt >= 4 ? symbols[@"months"] : symbols[@"shortMonths"];
            if (cnt == 5) [out appendString:narrow(n->months[tm->tm_mon])];
            else if (cnt >= 4) [out appendString:ms ? ms[tm->tm_mon] : @(n->months[tm->tm_mon])];
            else if (cnt == 3) [out appendString:ms ? ms[tm->tm_mon] : @(n->monthsShort[tm->tm_mon])];
            else append_num(out, tm->tm_mon + 1, cnt);
            break; }
        case 'd': append_num(out, tm->tm_mday, cnt); break;
        case 'D': append_num(out, tm->tm_yday + 1, cnt); break;
        case 'F': append_num(out, (tm->tm_mday - 1) / 7 + 1, cnt); break;
        case 'w': { int w, wy; iso_week(tm, &w, &wy); append_num(out, w, cnt); break; }
        case 'W': append_num(out, (tm->tm_mday + ((tm->tm_wday - tm->tm_mday + 1) % 7 + 7) % 7 - 1) / 7 + 1, cnt); break;
        case 'E': case 'c': case 'e':
            if ((c == 'e' || c == 'c') && cnt <= 2) { append_num(out, tm->tm_wday + 1, cnt); break; }
            if (cnt == 5) [out appendString:narrow(n->weekdays[tm->tm_wday])];
            else if (cnt == 6) [out appendString:[@(n->weekdays[tm->tm_wday]) substringToIndex:MIN((NSUInteger)2, strlen(n->weekdays[tm->tm_wday]))]];
            else if (cnt == 4) [out appendString:symbols[@"weekdays"] ? symbols[@"weekdays"][tm->tm_wday] : @(n->weekdays[tm->tm_wday])];
            else [out appendString:symbols[@"shortWeekdays"] ? symbols[@"shortWeekdays"][tm->tm_wday] : @(n->weekdaysShort[tm->tm_wday])];
            break;
        case 'a': case 'b': case 'B': [out appendString:tm->tm_hour < 12 ? am : pm]; break;
        case 'h': append_num(out, hour12, cnt); break;
        case 'H': append_num(out, tm->tm_hour, cnt); break;
        case 'K': append_num(out, tm->tm_hour % 12, cnt); break;
        case 'k': append_num(out, tm->tm_hour ? tm->tm_hour : 24, cnt); break;
        case 'm': append_num(out, tm->tm_min, cnt); break;
        case 's': append_num(out, tm->tm_sec, cnt); break;
        case 'S': { double f = floor(bd.frac * pow(10, (double)cnt) + 1e-6); append_num(out, (long)f, cnt); break; }
        case 'A': append_num(out, (long)((tm->tm_hour * 3600 + tm->tm_min * 60 + tm->tm_sec) * 1000 + bd.frac * 1000), cnt); break;
        case 'z': case 'v':
            if (cnt >= 4 && c == 'z') [out appendString:[tz.name isEqualToString:@"GMT"] || [tz.name isEqualToString:@"UTC"] ? @"Coordinated Universal Time" : ([tz abbreviationForDate:date] ?: @"")];
            else {
                NSString *ab = [tz abbreviationForDate:date] ?: @"";
                if ([ab hasPrefix:@"+"] || [ab hasPrefix:@"-"] || !ab.length) ab = off ? [NSString stringWithFormat:@"GMT%c%ld%@", off < 0 ? '-' : '+', labs(off) / 3600, labs(off) % 3600 ? [NSString stringWithFormat:@":%02ld", labs(off) % 3600 / 60] : @""] : @"GMT";
                if ([ab isEqualToString:@"UTC"]) ab = @"GMT";
                [out appendString:ab];
            }
            break;
        case 'O':
            if (!off) { [out appendString:@"GMT"]; break; }
            if (cnt >= 4) [out appendFormat:@"GMT%c%02ld:%02ld", off < 0 ? '-' : '+', labs(off) / 3600, labs(off) % 3600 / 60];
            else [out appendFormat:@"GMT%c%ld%@", off < 0 ? '-' : '+', labs(off) / 3600, labs(off) % 3600 ? [NSString stringWithFormat:@":%02ld", labs(off) % 3600 / 60] : @""];
            break;
        case 'V': [out appendString:cnt >= 2 ? tz.name : @"unk"]; break;
        case 'Z': case 'x': case 'X':
            if (c == 'X' && off == 0) { [out appendString:@"Z"]; break; }
            if (c == 'Z' && cnt == 4) { if (!off) { [out appendString:@"GMT"]; break; } [out appendFormat:@"GMT%c%02ld:%02ld", off < 0 ? '-' : '+', labs(off) / 3600, labs(off) % 3600 / 60]; break; }
            if (c == 'Z' && cnt == 5 && off == 0) { [out appendString:@"Z"]; break; }
            {
                BOOL colon = (c == 'Z' && cnt == 5) || (c != 'Z' && (cnt == 3 || cnt == 5));
                if (c != 'Z' && cnt == 1 && labs(off) % 3600 == 0) [out appendFormat:@"%c%02ld", off < 0 ? '-' : '+', labs(off) / 3600];
                else [out appendFormat:@"%c%02ld%s%02ld", off < 0 ? '-' : '+', labs(off) / 3600, colon ? ":" : "", labs(off) % 3600 / 60];
            }
            break;
        default: [out appendString:repeat_char((char)c, cnt)]; break;
        }
    }
    return out;
}

/* The ICU locale for formatting dates in a locale and calendar, or nil when the built-in tables cover them
 * (a built-in region and language, Gregorian or ISO 8601). */
NSString *isim_icu_date_locale(NSLocale *locale, NSString *calendarID) {
    if (!isim_icu_on()) return nil;
    NSString *ident = isim_locale_ident(locale);
    NSString *cal = calendarID ?: locale.calendarIdentifier;
    BOOL gregorian = !cal.length || [cal isEqualToString:@"gregorian"] || [cal isEqualToString:@"iso8601"];
    NSRange at = [ident rangeOfString:@"@"];
    NSString *base = at.location == NSNotFound ? ident : [ident substringToIndex:at.location];
    if (gregorian && builtin_region(base) && isim_lang_builtin(isim_locale_lang(locale))) return nil;
    return gregorian ? base : [NSString stringWithFormat:@"%@@calendar=%@", base, isim_icu_calendar_name(cal)];
}
/* the user's 12/24-hour setting on an ICU pattern (the current locale only, as on iOS) */
static NSString *hour_cycle(NSString *pat, NSLocale *locale) {
    if (!pat.length || (locale && ![locale _isim_isCurrent])) return pat;
    BOOL want12 = isim_uses_12h(locale);
    NSMutableString *out = [NSMutableString string];
    BOOL quoted = NO, has12 = NO, has24 = NO;
    for (NSUInteger i = 0; i < pat.length; i++) {
        unichar c = [pat characterAtIndex:i];
        if (c == '\'') quoted = !quoted;
        else if (!quoted && (c == 'h' || c == 'K')) has12 = YES;
        else if (!quoted && (c == 'H' || c == 'k')) has24 = YES;
    }
    if ((want12 && !has24) || (!want12 && !has12)) return pat;
    quoted = NO;
    for (NSUInteger i = 0; i < pat.length; i++) {
        unichar c = [pat characterAtIndex:i];
        if (c == '\'') { quoted = !quoted; [out appendFormat:@"%C", c]; continue; }
        if (quoted) { [out appendFormat:@"%C", c]; continue; }
        if (!want12 && (c == 'h' || c == 'K')) { [out appendString:@"H"]; continue; }
        if (!want12 && (c == 'a' || c == 'b' || c == 'B')) {           /* drop the day period and the space before it */
            while (out.length && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[out characterAtIndex:out.length - 1]]) [out deleteCharactersInRange:NSMakeRange(out.length - 1, 1)];
            while (i + 1 < pat.length && [pat characterAtIndex:i + 1] == c) i++;
            if (i + 1 < pat.length && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[pat characterAtIndex:i + 1]] && !out.length) i++;
            continue;
        }
        if (want12 && (c == 'H' || c == 'k')) {
            [out appendString:@"h"];
            while (i + 1 < pat.length && ([pat characterAtIndex:i + 1] == 'H' || [pat characterAtIndex:i + 1] == 'k')) i++;
            continue;
        }
        [out appendFormat:@"%C", c];
    }
    if (want12) {                                                      /* the day period after the last time field */
        for (NSUInteger i = out.length; i > 0; i--) {
            unichar c = [out characterAtIndex:i - 1];
            if (c == 'h' || c == 'm' || c == 's' || c == 'S') { [out insertString:@"\u202Fa" atIndex:i]; break; }
        }
    }
    return out;
}

@implementation NSDateFormatter { NSString *_fmt; NSLocale *_locale; NSTimeZone *_tz; NSMutableDictionary *_symbols; }
@synthesize calendar = _calendar, dateStyle = _dateStyle, timeStyle = _timeStyle;
- (NSCalendar *)calendar { return _calendar ?: NSCalendar.currentCalendar; }
- (void)setCalendar:(NSCalendar *)c { _calendar = [c copy]; }        /* null_resettable: nil is the current calendar */
- (NSDateFormatterStyle)dateStyle { return _dateStyle; }
- (NSDateFormatterStyle)timeStyle { return _timeStyle; }
- (instancetype)init {
    if ((self = [super init])) { _locale = NSLocale.currentLocale; _tz = NSTimeZone.defaultTimeZone; _symbols = [NSMutableDictionary dictionary]; _lenient = NO; }
    return self;
}
- (id)copyWithZone:(NSZone *)z {
    NSDateFormatter *f = [NSDateFormatter new];
    f->_fmt = _fmt; f->_locale = _locale; f->_tz = _tz; f->_symbols = [_symbols mutableCopy];
    f.dateStyle = self.dateStyle; f.timeStyle = self.timeStyle; f.doesRelativeDateFormatting = self.doesRelativeDateFormatting; f.lenient = self.lenient;
    return f;
}
- (NSLocale *)locale { return _locale; }
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; }
- (NSTimeZone *)timeZone { return _tz; }
- (void)setTimeZone:(NSTimeZone *)tz { _tz = tz ?: NSTimeZone.defaultTimeZone; }
- (void)setDateFormat:(NSString *)f { _fmt = [f copy]; }
- (void)setDateStyle:(NSDateFormatterStyle)s { _dateStyle = s; _fmt = nil; }
- (void)setTimeStyle:(NSDateFormatterStyle)s { _timeStyle = s; _fmt = nil; }
- (NSString *)_icuLocale { return isim_icu_date_locale(_locale, _calendar.calendarIdentifier); }
- (NSString *)dateFormat {
    if (_fmt) return _fmt;
    NSString *icu = [self _icuLocale];
    NSString *p = icu ? hour_cycle(isim_icu_style_pattern(icu, (NSInteger)self.dateStyle, (NSInteger)self.timeStyle), _locale) : nil;
    return p ?: isim_style_pattern((NSInteger)self.dateStyle, (NSInteger)self.timeStyle, _locale);
}
- (void)setLocalizedDateFormatFromTemplate:(NSString *)tmpl {
    NSString *icu = [self _icuLocale];
    _fmt = (icu ? hour_cycle(isim_icu_skeleton_pattern(icu, tmpl), _locale) : nil) ?: isim_date_pattern(tmpl, _locale);
}
+ (NSString *)dateFormatFromTemplate:(NSString *)tmpl options:(NSUInteger)opts locale:(NSLocale *)locale {
    locale = locale ?: NSLocale.currentLocale;
    NSString *icu = isim_icu_date_locale(locale, nil);
    return (icu ? hour_cycle(isim_icu_skeleton_pattern(icu, tmpl), locale) : nil) ?: isim_date_pattern(tmpl, locale);
}
/* format with ICU when the built-in tables do not cover the locale or calendar (and no symbol was overridden) */
- (NSString *)_format:(NSDate *)date pattern:(NSString *)pattern {
    NSString *icu = _symbols.count ? nil : [self _icuLocale];
    NSString *s = icu ? isim_icu_date_format_string(icu, _tz.name, pattern, date) : nil;
    return s ?: isim_format_date(date, pattern, _locale, _tz, _symbols);
}
/* ICU's symbols when it formats for this locale / calendar (UDateFormatSymbolType) */
- (NSArray *)_icuSymbols:(int)type key:(NSString *)key {
    if (_symbols[key]) return _symbols[key];
    NSString *icu = [self _icuLocale];
    return icu ? isim_icu_symbols(icu, type) : nil;
}
+ (NSString *)localizedStringFromDate:(NSDate *)d dateStyle:(NSDateFormatterStyle)ds timeStyle:(NSDateFormatterStyle)ts {
    NSDateFormatter *f = [NSDateFormatter new]; f.dateStyle = ds; f.timeStyle = ts; return [f stringFromDate:d];
}
/* symbols (settable) */
- (NSArray *)_names:(const char *const *)src count:(int)n key:(NSString *)key narrow:(BOOL)nar {
    if (_symbols[key]) return _symbols[key];
    NSMutableArray *a = [NSMutableArray array];
    for (int i = 0; i < n; i++) [a addObject:nar ? narrow(src[i]) : @(src[i])];
    return a;
}
- (const isim_lang_t *)_lang { return isim_lang(isim_locale_lang(_locale)); }
- (NSArray *)monthSymbols { return [self _icuSymbols:1 key:@"months"] ?: [self _names:[self _lang]->months count:12 key:@"months" narrow:NO]; }
- (void)setMonthSymbols:(NSArray *)a { _symbols[@"months"] = [a copy]; }
- (NSArray *)shortMonthSymbols { return [self _icuSymbols:2 key:@"shortMonths"] ?: [self _names:[self _lang]->monthsShort count:12 key:@"shortMonths" narrow:NO]; }
- (void)setShortMonthSymbols:(NSArray *)a { _symbols[@"shortMonths"] = [a copy]; }
- (NSArray *)veryShortMonthSymbols { return [self _icuSymbols:8 key:@"veryShortMonths"] ?: [self _names:[self _lang]->months count:12 key:@"veryShortMonths" narrow:YES]; }
- (NSArray *)standaloneMonthSymbols { return [self _icuSymbols:10 key:@"standaloneMonths"] ?: self.monthSymbols; }
- (NSArray *)shortStandaloneMonthSymbols { return [self _icuSymbols:11 key:@"shortStandaloneMonths"] ?: self.shortMonthSymbols; }
- (NSArray *)veryShortStandaloneMonthSymbols { return [self _icuSymbols:12 key:@"veryShortStandaloneMonths"] ?: self.veryShortMonthSymbols; }
- (NSArray *)weekdaySymbols { return [self _icuSymbols:3 key:@"weekdays"] ?: [self _names:[self _lang]->weekdays count:7 key:@"weekdays" narrow:NO]; }
- (void)setWeekdaySymbols:(NSArray *)a { _symbols[@"weekdays"] = [a copy]; }
- (NSArray *)shortWeekdaySymbols { return [self _icuSymbols:4 key:@"shortWeekdays"] ?: [self _names:[self _lang]->weekdaysShort count:7 key:@"shortWeekdays" narrow:NO]; }
- (void)setShortWeekdaySymbols:(NSArray *)a { _symbols[@"shortWeekdays"] = [a copy]; }
- (NSArray *)veryShortWeekdaySymbols { return [self _icuSymbols:9 key:@"veryShortWeekdays"] ?: [self _names:[self _lang]->weekdays count:7 key:@"veryShortWeekdays" narrow:YES]; }
- (NSArray *)standaloneWeekdaySymbols { return [self _icuSymbols:13 key:@"standaloneWeekdays"] ?: self.weekdaySymbols; }
- (NSArray *)shortStandaloneWeekdaySymbols { return [self _icuSymbols:14 key:@"shortStandaloneWeekdays"] ?: self.shortWeekdaySymbols; }
- (NSArray *)veryShortStandaloneWeekdaySymbols { return [self _icuSymbols:15 key:@"veryShortStandaloneWeekdays"] ?: self.veryShortWeekdaySymbols; }
- (NSString *)AMSymbol { return _symbols[@"AM"] ?: [self _icuSymbols:5 key:@"AMPM"].firstObject ?: @([self _lang]->am); }
- (void)setAMSymbol:(NSString *)s { _symbols[@"AM"] = [s copy]; }
- (NSString *)PMSymbol { NSArray *a = [self _icuSymbols:5 key:@"AMPM"]; return _symbols[@"PM"] ?: (a.count > 1 ? a[1] : nil) ?: @([self _lang]->pm); }
- (void)setPMSymbol:(NSString *)s { _symbols[@"PM"] = [s copy]; }
- (NSArray *)eraSymbols { return [self _icuSymbols:0 key:@"eras"] ?: @[@([self _lang]->eras[0]), @([self _lang]->eras[1])]; }
- (NSArray *)longEraSymbols { return [self _icuSymbols:7 key:@"longEras"] ?: self.eraSymbols; }
/* quarters: ICU's names for the locale when the host has ICU (the built-in tables have English only) */
- (NSArray *)quarterSymbols {
    NSArray *a = [self _icuSymbols:16 key:@"quarters"] ?: (isim_icu_on() ? isim_icu_symbols(isim_locale_ident(_locale), 16) : nil);
    return a.count == 4 ? a : @[@"1st quarter", @"2nd quarter", @"3rd quarter", @"4th quarter"];
}
- (NSArray *)shortQuarterSymbols {
    NSArray *a = [self _icuSymbols:17 key:@"shortQuarters"] ?: (isim_icu_on() ? isim_icu_symbols(isim_locale_ident(_locale), 17) : nil);
    return a.count == 4 ? a : @[@"Q1", @"Q2", @"Q3", @"Q4"];
}

- (NSString *)stringFromDate:(NSDate *)date {
    if (!date) return nil;
    if (self.doesRelativeDateFormatting && !_fmt && self.dateStyle != NSDateFormatterNoStyle) {
        NSInteger offset = [self _dayOffsetFromToday:date];
        const isim_lang_t *n = [self _lang];
        NSString *word = offset == -1 ? @(n->yesterday) : offset == 0 ? @(n->today) : offset == 1 ? @(n->tomorrow) : nil;
        if (word) {
            word = [[word substringToIndex:1].uppercaseString stringByAppendingString:[word substringFromIndex:1]];
            if (self.timeStyle == NSDateFormatterNoStyle) return word;
            NSString *icu = [self _icuLocale];
            NSString *tp = (icu ? hour_cycle(isim_icu_style_pattern(icu, 0, (NSInteger)self.timeStyle), _locale) : nil) ?: isim_style_pattern(0, (NSInteger)self.timeStyle, _locale);
            NSString *t = [self _format:date pattern:tp];
            return [NSString stringWithFormat:@"%@%s%@", word, [isim_locale_lang(_locale) isEqualToString:@"en"] ? " at " : n->dateTimeSep, t];
        }
    }
    return [self _format:date pattern:self.dateFormat];
}
- (NSInteger)_dayOffsetFromToday:(NSDate *)date {
    isim_bdate a, b; broken_down(date, _tz, &a); broken_down([NSDate date], _tz, &b);
    struct tm ta = a.tm, tb = b.tm;
    ta.tm_hour = tb.tm_hour = 12; ta.tm_min = tb.tm_min = ta.tm_sec = tb.tm_sec = 0;
    return (NSInteger)lround((double)(timegm(&ta) - timegm(&tb)) / 86400.0);
}

static BOOL is_space(unichar c) { return c == ' ' || c == 0xA0 || c == 0x202F || c == 0x2009 || c == '\t'; }
/* Parses fields of the pattern: numbers, month/weekday names, AM/PM, eras, time zones; literals must match
 * (any space matches any space). Lenient formatters also skip unmatched literals. */
- (NSDate *)dateFromString:(NSString *)string {
    if (!string) return nil;
    NSString *fmt = self.dateFormat;
    NSString *icu = _symbols.count ? nil : [self _icuLocale];
    if (icu) return isim_icu_date_parse_string(icu, _tz.name, fmt, string, self.lenient);
    const isim_lang_t *n = [self _lang];
    struct tm tm = {0}; tm.tm_mday = 1; tm.tm_year = 70;
    int pm = -1; double frac = 0; BOOL haveOffset = NO; long offset = 0; int yearDigits = 0;
    NSUInteger si = 0, sl = string.length;
    for (NSUInteger i = 0; i < fmt.length;) {
        unichar c = [fmt characterAtIndex:i];
        if (c == '\'') {
            NSUInteger j = i + 1;
            NSMutableString *lit = [NSMutableString string];
            if (j < fmt.length && [fmt characterAtIndex:j] == '\'') { [lit appendString:@"'"]; j++; }
            else { while (j < fmt.length && [fmt characterAtIndex:j] != '\'') { [lit appendString:[fmt substringWithRange:NSMakeRange(j, 1)]]; j++; } j++; }
            for (NSUInteger q = 0; q < lit.length; q++, si++) if (si >= sl || [string characterAtIndex:si] != [lit characterAtIndex:q]) { if (!self.lenient) return nil; }
            i = j; continue;
        }
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))) {
            if (is_space(c)) { while (si < sl && is_space([string characterAtIndex:si])) si++; i++; continue; }
            if (si < sl && [string characterAtIndex:si] == c) si++;
            else if (!self.lenient) return nil;
            i++; continue;
        }
        NSUInteger k = i; while (k < fmt.length && [fmt characterAtIndex:k] == c) k++;
        NSUInteger cnt = k - i; i = k;
        BOOL nextIsDigitField = i < fmt.length && strchr("yMdHhmsSkK", (char)[fmt characterAtIndex:i]);
        if ((strchr("yuMLdDHhkKmsSQ", (char)c) && !((c == 'M' || c == 'L') && cnt >= 3)) || ((c == 'e' || c == 'c') && cnt <= 2)) {
            long v = 0; NSUInteger digits = 0;
            BOOL neg = NO;
            if (c == 'y' && si < sl && [string characterAtIndex:si] == '-') { neg = YES; si++; }
            NSUInteger maxDigits = c == 'S' ? cnt : (cnt >= 3 || !nextIsDigitField) ? 9 : MAX(cnt, (NSUInteger)2);
            if (c == 'y' && nextIsDigitField) maxDigits = cnt == 2 ? 2 : 4;
            while (si < sl && digits < maxDigits) {
                unichar ch = [string characterAtIndex:si];
                if (ch < '0' || ch > '9') break;
                v = v * 10 + (ch - '0'); si++; digits++;
            }
            if (!digits) return nil;
            if (neg) v = -v;
            switch (c) {
            case 'y': case 'u': yearDigits = (int)digits; tm.tm_year = (int)(cnt == 2 && digits <= 2 ? (v < 50 ? v + 2000 : v + 1900) : v) - 1900; break;
            case 'M': case 'L': if (v < 1 || v > 12) return nil; tm.tm_mon = (int)v - 1; break;
            case 'd': if (v < 1 || v > 31) return nil; tm.tm_mday = (int)v; break;
            case 'D': tm.tm_mday = (int)v; tm.tm_mon = 0; break;
            case 'H': case 'k': if (v > 24) return nil; tm.tm_hour = (int)(v == 24 ? 0 : v); break;
            case 'h': case 'K': if (v > 12) return nil; tm.tm_hour = (int)(v == 12 && c == 'h' ? 0 : v); if (pm < 0) pm = -2; break;
            case 'm': if (v > 59) return nil; tm.tm_min = (int)v; break;
            case 's': if (v > 60) return nil; tm.tm_sec = (int)v; break;
            case 'S': frac = v / pow(10, (double)digits); break;
            default: break;
            }
            continue;
        }
        NSString *rest = [string substringFromIndex:si];
        BOOL (^take)(NSString *) = ^BOOL(NSString *word) {
            if (word.length && [rest rangeOfString:word options:NSCaseInsensitiveSearch | NSAnchoredSearch range:NSMakeRange(0, rest.length)].location == 0) return YES;
            return NO;
        };
        if (c == 'M' || c == 'L') {
            int found = -1; NSUInteger flen = 0;
            for (int pass = 0; pass < 2 && found < 0; pass++)
                for (int mo = 0; mo < 12; mo++) {
                    NSString *w = pass == 0 ? self.monthSymbols[mo] : self.shortMonthSymbols[mo];
                    if (take(w) && w.length > flen) { found = mo; flen = w.length; }
                    NSString *noDot = [w stringByReplacingOccurrencesOfString:@"." withString:@""];
                    if (found < 0 && take(noDot) && noDot.length) { found = mo; flen = noDot.length; }
                }
            if (found < 0) return nil;
            tm.tm_mon = found; si += flen; continue;
        }
        if (c == 'E' || c == 'c' || c == 'e') {
            NSUInteger flen = 0;
            for (int wd = 0; wd < 7; wd++) {
                NSString *w1 = self.weekdaySymbols[wd], *w2 = self.shortWeekdaySymbols[wd];
                if (take(w1) && w1.length > flen) flen = w1.length;
                else if (take(w2) && w2.length > flen) flen = w2.length;
            }
            if (!flen) return nil;
            si += flen; continue;
        }
        if (c == 'a' || c == 'b' || c == 'B') {
            NSString *a = self.AMSymbol, *p = self.PMSymbol;
            if (take(p)) { pm = 1; si += p.length; }
            else if (take(a)) { pm = 0; si += a.length; }
            else if (take(@"PM") || take(@"pm")) { pm = 1; si += 2; }
            else if (take(@"AM") || take(@"am")) { pm = 0; si += 2; }
            else return nil;
            continue;
        }
        if (c == 'G') {
            if (take(@(n->eras[1]))) si += strlen(n->eras[1]) ? @(n->eras[1]).length : 0;
            else if (take(@(n->eras[0]))) { si += @(n->eras[0]).length; }
            continue;
        }
        if (c == 'Z' || c == 'X' || c == 'x' || c == 'z' || c == 'O' || c == 'v' || c == 'V') {
            if (take(@"Z")) { haveOffset = YES; offset = 0; si += 1; continue; }
            NSUInteger p = si;
            if (take(@"GMT") || take(@"UTC")) { p += 3; haveOffset = YES; offset = 0; }
            if (p < sl && ([string characterAtIndex:p] == '+' || [string characterAtIndex:p] == '-')) {
                int sign = [string characterAtIndex:p] == '-' ? -1 : 1; p++;
                long hh = 0, mm = 0; int dg = 0;
                while (p < sl && isdigit([string characterAtIndex:p]) && dg < 2) { hh = hh * 10 + ([string characterAtIndex:p] - '0'); p++; dg++; }
                if (p < sl && [string characterAtIndex:p] == ':') p++;
                dg = 0;
                while (p < sl && isdigit([string characterAtIndex:p]) && dg < 2) { mm = mm * 10 + ([string characterAtIndex:p] - '0'); p++; dg++; }
                haveOffset = YES; offset = sign * (hh * 3600 + mm * 60);
            } else if (p == si) {
                /* zone abbreviation or name */
                NSUInteger e = si; while (e < sl && ([[NSCharacterSet letterCharacterSet] characterIsMember:[string characterAtIndex:e]] || [string characterAtIndex:e] == '/' || [string characterAtIndex:e] == '_')) e++;
                NSString *name = [string substringWithRange:NSMakeRange(si, e - si)];
                NSTimeZone *z = [NSTimeZone timeZoneWithAbbreviation:name] ?: [NSTimeZone timeZoneWithName:name];
                if (!z) return nil;
                haveOffset = YES; offset = LONG_MIN; p = e;
                tm.tm_isdst = 0;
                si = p;
                /* resolve with that zone below */
                time_t t0 = timegm(&tm);
                offset = [z secondsFromGMTForDate:[NSDate dateWithTimeIntervalSince1970:t0]];
                continue;
            }
            si = p; continue;
        }
        return nil;   /* unsupported field */
    }
    while (si < sl && is_space([string characterAtIndex:si])) si++;
    if (si != sl) return nil;
    (void)yearDigits;
    if (pm == 1 && tm.tm_hour < 12) tm.tm_hour += 12;
    if (pm == 0 && tm.tm_hour == 12) tm.tm_hour = 0;
    time_t t = timegm(&tm);
    if (haveOffset) return [NSDate dateWithTimeIntervalSince1970:t - offset + frac];
    NSDate *guess = [NSDate dateWithTimeIntervalSince1970:t];
    long off1 = [_tz secondsFromGMTForDate:guess];
    long off2 = [_tz secondsFromGMTForDate:[NSDate dateWithTimeIntervalSince1970:t - off1]];
    return [NSDate dateWithTimeIntervalSince1970:t - off2 + frac];
}
- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error {
    NSDate *d = [self dateFromString:string];
    if (obj) *obj = d;
    if (!d && error) *error = @"The string couldn’t be parsed as a date.";
    return d != nil;
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSDate class]] ? [self stringFromDate:obj] : nil; }
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

/* Settings > General > Date & Time > Time Zone (a TZ environment variable given at launch wins).
 * Applied at launch and again whenever the settings change (live, as on iOS). */
static BOOL tz_from_environment, tz_applied;
static NSString *tz_current;
__attribute__((constructor)) static void isim_apply_time_zone_setting(void) {
    tz_from_environment = getenv("TZ") != NULL;
    isim_reapply_time_zone_setting();
}
void isim_reapply_time_zone_setting(void) {
    if (tz_from_environment) return;
    NSString *tz = isim_global_preferences()[@"TimeZone"];
    if (![tz isKindOfClass:[NSString class]] || !tz.length) tz = nil;
    if (tz_applied && (tz == tz_current || [tz isEqualToString:tz_current])) return;
    BOOL changed = tz_applied;
    tz_applied = YES; tz_current = [tz copy];
    if (tz) setenv("TZ", tz.UTF8String, 1); else unsetenv("TZ");          /* nil: "Set Automatically" (host zone) */
    tzset();
    default_tz = nil;
    if (changed) [NSNotificationCenter.defaultCenter postNotificationName:NSSystemTimeZoneDidChangeNotification object:nil];
}
