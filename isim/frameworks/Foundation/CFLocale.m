// isim CoreFoundation: CFLocale (toll-free bridged: a CFLocaleRef is the NSLocale), CFDateFormatter (a CFDateFormatterRef
// is an NSDateFormatter, or an NSISO8601DateFormatter) and CFPreferences (over NSUserDefaults), over Foundation.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

/* NSUserDefaults' own (Additions.m, not in isim's header) */
@interface NSUserDefaults (IsimCFPreferences)
- (void)addSuiteNamed:(NSString *)name;
- (void)removeSuiteNamed:(NSString *)name;
- (NSDictionary *)persistentDomainForName:(NSString *)name;
@end

#define LOC(l) ((__bridge NSLocale *)(l))
#define STR(s) ((__bridge NSString *)(s))

/* ================= CFLocale ================= */
/* the keys are NSLocale's (Locale.m) where Foundation has them */
const CFLocaleKey kCFLocaleIdentifier = CFSTR("locale:id");
const CFLocaleKey kCFLocaleLanguageCode = CFSTR("kCFLocaleLanguageCodeKey");
const CFLocaleKey kCFLocaleCountryCode = CFSTR("kCFLocaleCountryCodeKey");
const CFLocaleKey kCFLocaleScriptCode = CFSTR("kCFLocaleScriptCodeKey");
const CFLocaleKey kCFLocaleVariantCode = CFSTR("kCFLocaleVariantCodeKey");
const CFLocaleKey kCFLocaleExemplarCharacterSet = CFSTR("kCFLocaleExemplarCharacterSetKey");
const CFLocaleKey kCFLocaleCalendarIdentifier = CFSTR("calendar");
const CFLocaleKey kCFLocaleCalendar = CFSTR("kCFLocaleCalendarKey");
const CFLocaleKey kCFLocaleCollationIdentifier = CFSTR("collation");
const CFLocaleKey kCFLocaleUsesMetricSystem = CFSTR("kCFLocaleUsesMetricSystemKey");
const CFLocaleKey kCFLocaleMeasurementSystem = CFSTR("kCFLocaleMeasurementSystemKey");
const CFLocaleKey kCFLocaleDecimalSeparator = CFSTR("kCFLocaleDecimalSeparatorKey");
const CFLocaleKey kCFLocaleGroupingSeparator = CFSTR("kCFLocaleGroupingSeparatorKey");
const CFLocaleKey kCFLocaleCurrencySymbol = CFSTR("kCFLocaleCurrencySymbolKey");
const CFLocaleKey kCFLocaleCurrencyCode = CFSTR("currency");
const CFLocaleKey kCFLocaleCollatorIdentifier = CFSTR("kCFLocaleCollatorIdentifierKey");
const CFLocaleKey kCFLocaleQuotationBeginDelimiterKey = CFSTR("kCFLocaleQuotationBeginDelimiterKey");
const CFLocaleKey kCFLocaleQuotationEndDelimiterKey = CFSTR("kCFLocaleQuotationEndDelimiterKey");
const CFLocaleKey kCFLocaleAlternateQuotationBeginDelimiterKey = CFSTR("kCFLocaleAlternateQuotationBeginDelimiterKey");
const CFLocaleKey kCFLocaleAlternateQuotationEndDelimiterKey = CFSTR("kCFLocaleAlternateQuotationEndDelimiterKey");
const CFNotificationName kCFLocaleCurrentLocaleDidChangeNotification = CFSTR("kCFLocaleCurrentLocaleDidChangeNotification");
const CFCalendarIdentifier kCFGregorianCalendar = CFSTR("gregorian");
const CFCalendarIdentifier kCFBuddhistCalendar = CFSTR("buddhist");
const CFCalendarIdentifier kCFChineseCalendar = CFSTR("chinese");
const CFCalendarIdentifier kCFHebrewCalendar = CFSTR("hebrew");
const CFCalendarIdentifier kCFIslamicCalendar = CFSTR("islamic");
const CFCalendarIdentifier kCFIslamicCivilCalendar = CFSTR("islamic-civil");
const CFCalendarIdentifier kCFJapaneseCalendar = CFSTR("japanese");
const CFCalendarIdentifier kCFRepublicOfChinaCalendar = CFSTR("roc");
const CFCalendarIdentifier kCFPersianCalendar = CFSTR("persian");
const CFCalendarIdentifier kCFIndianCalendar = CFSTR("indian");
const CFCalendarIdentifier kCFISO8601Calendar = CFSTR("iso8601");

CFTypeID CFLocaleGetTypeID(void) { return 41; }
CFLocaleRef CFLocaleGetSystem(void) { static NSLocale *system; if (!system) system = NSLocale.systemLocale; return (__bridge CFLocaleRef)system; }
CFLocaleRef CFLocaleCopyCurrent(void) { return (__bridge_retained CFLocaleRef)NSLocale.currentLocale; }
CFLocaleRef CFLocaleCreate(CFAllocatorRef a, CFLocaleIdentifier ident) {
    if (!ident) return NULL;
    return (__bridge_retained CFLocaleRef)[NSLocale localeWithLocaleIdentifier:STR(ident)];
}
CFLocaleRef CFLocaleCreateCopy(CFAllocatorRef a, CFLocaleRef l) { return (__bridge_retained CFLocaleRef)[LOC(l) copy]; }
CFLocaleIdentifier CFLocaleGetIdentifier(CFLocaleRef l) { return (__bridge CFStringRef)LOC(l).localeIdentifier; }

/* quotation marks of the locale's language (CLDR): begin, end, alternate begin, alternate end */
static NSArray<NSString *> *quotes(NSLocale *l) {
    NSDictionary *q = @{ @"en": @[@"“", @"”", @"‘", @"’"], @"fr": @[@"«", @"»", @"«", @"»"], @"de": @[@"„", @"“", @"‚", @"‘"],
                         @"es": @[@"«", @"»", @"“", @"”"], @"it": @[@"«", @"»", @"“", @"”"], @"pt": @[@"“", @"”", @"‘", @"’"],
                         @"ru": @[@"«", @"»", @"„", @"“"], @"ja": @[@"「", @"」", @"『", @"』"], @"zh": @[@"“", @"”", @"‘", @"’"],
                         @"nl": @[@"‘", @"’", @"“", @"”"], @"sv": @[@"”", @"”", @"’", @"’"], @"pl": @[@"„", @"”", @"«", @"»"] };
    return q[l.languageCode ?: @"en"] ?: q[@"en"];
}
/* the values a CFLocale has for its keys; the per-locale ones come from NSLocale (no keys: NULL) */
static id locale_value(NSLocale *l, NSString *key) {
    if ([key isEqualToString:STR(kCFLocaleIdentifier)] || [key isEqualToString:STR(kCFLocaleCollatorIdentifier)]) return l.localeIdentifier;
    if ([key isEqualToString:STR(kCFLocaleLanguageCode)]) return l.languageCode;
    if ([key isEqualToString:STR(kCFLocaleCountryCode)]) return l.countryCode;
    if ([key isEqualToString:STR(kCFLocaleScriptCode)]) return l.scriptCode;
    if ([key isEqualToString:STR(kCFLocaleVariantCode)]) {
        NSArray *p = [l.localeIdentifier componentsSeparatedByString:@"_"];
        return p.count > 2 ? p.lastObject : nil;
    }
    if ([key isEqualToString:STR(kCFLocaleCalendarIdentifier)]) return l.calendarIdentifier;
    if ([key isEqualToString:STR(kCFLocaleCalendar)]) {
        NSCalendar *c = [NSCalendar calendarWithIdentifier:l.calendarIdentifier];
        c.locale = l;
        return c;
    }
    if ([key isEqualToString:STR(kCFLocaleUsesMetricSystem)]) return @(l.usesMetricSystem);
    if ([key isEqualToString:STR(kCFLocaleMeasurementSystem)]) {
        return !l.usesMetricSystem ? @"U.S." : [l.countryCode isEqualToString:@"GB"] ? @"U.K." : @"Metric";
    }
    if ([key isEqualToString:STR(kCFLocaleDecimalSeparator)]) return l.decimalSeparator;
    if ([key isEqualToString:STR(kCFLocaleGroupingSeparator)]) return l.groupingSeparator;
    if ([key isEqualToString:STR(kCFLocaleCurrencySymbol)]) return l.currencySymbol;
    if ([key isEqualToString:STR(kCFLocaleCurrencyCode)]) return l.currencyCode;
    if ([key isEqualToString:STR(kCFLocaleExemplarCharacterSet)]) return NSCharacterSet.letterCharacterSet;   /* adapted: every letter */
    NSArray *q = quotes(l);
    if ([key isEqualToString:STR(kCFLocaleQuotationBeginDelimiterKey)]) return q[0];
    if ([key isEqualToString:STR(kCFLocaleQuotationEndDelimiterKey)]) return q[1];
    if ([key isEqualToString:STR(kCFLocaleAlternateQuotationBeginDelimiterKey)]) return q[2];
    if ([key isEqualToString:STR(kCFLocaleAlternateQuotationEndDelimiterKey)]) return q[3];
    return [l objectForKey:key];
}
CFTypeRef CFLocaleGetValue(CFLocaleRef l, CFLocaleKey key) {
    if (!l || !key) return NULL;
    static NSMutableDictionary *kept;                    /* Get: the values live as long as the process (like CF's cache) */
    id v = locale_value(LOC(l), STR(key));
    if (!v) return NULL;
    @synchronized (NSLocale.class) {
        if (!kept) kept = [NSMutableDictionary dictionary];
        NSString *k = [NSString stringWithFormat:@"%@|%@", LOC(l).localeIdentifier, STR(key)];
        if (!kept[k]) kept[k] = v;
        v = kept[k];
    }
    return (__bridge CFTypeRef)v;
}
CFStringRef CFLocaleCopyDisplayNameForPropertyValue(CFLocaleRef display, CFLocaleKey key, CFStringRef value) {
    if (!display || !key || !value) return NULL;
    NSLocale *l = LOC(display);
    NSString *k = STR(key), *v = STR(value), *name = nil;
    if ([k isEqualToString:STR(kCFLocaleIdentifier)]) name = [l localizedStringForLocaleIdentifier:v];
    else if ([k isEqualToString:STR(kCFLocaleLanguageCode)]) name = [l localizedStringForLanguageCode:v];
    else if ([k isEqualToString:STR(kCFLocaleCountryCode)]) name = [l localizedStringForCountryCode:v];
    else if ([k isEqualToString:STR(kCFLocaleScriptCode)]) name = [l localizedStringForScriptCode:v];
    else if ([k isEqualToString:STR(kCFLocaleCurrencyCode)]) name = [l localizedStringForCurrencyCode:v];
    else if ([k isEqualToString:STR(kCFLocaleCalendarIdentifier)]) name = [l localizedStringForCalendarIdentifier:v];
    else name = [l displayNameForKey:k value:v];
    return name ? (__bridge_retained CFStringRef)name : NULL;
}
static CFArrayRef ret_array(NSArray *a) { return (__bridge_retained CFArrayRef)(a ?: @[]); }
CFArrayRef CFLocaleCopyAvailableLocaleIdentifiers(void) { return ret_array(NSLocale.availableLocaleIdentifiers); }
/* the languages of the available locales (ISO 639) */
CFArrayRef CFLocaleCopyISOLanguageCodes(void) {
    NSMutableOrderedSet *codes = [NSMutableOrderedSet orderedSet];
    for (NSString *ident in NSLocale.availableLocaleIdentifiers) {
        NSString *lang = [ident componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_-"]].firstObject;
        if (lang.length >= 2 && lang.length <= 3) [codes addObject:lang];
    }
    return ret_array([codes.array sortedArrayUsingSelector:@selector(compare:)]);
}
CFArrayRef CFLocaleCopyISOCountryCodes(void) { return ret_array(NSLocale.ISOCountryCodes); }
CFArrayRef CFLocaleCopyISOCurrencyCodes(void) { return ret_array(NSLocale.ISOCurrencyCodes); }
CFArrayRef CFLocaleCopyCommonISOCurrencyCodes(void) { return ret_array(NSLocale.commonISOCurrencyCodes); }
CFArrayRef CFLocaleCopyPreferredLanguages(void) { return ret_array(NSLocale.preferredLanguages); }
/* canonical forms (adapted, BCP 47 style): language lowercase, script title case, region uppercase; "-" between them
   for language identifiers, "_" for locale identifiers */
static NSString *canonical(NSString *ident, NSString *separator) {
    NSArray *parts = [ident componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_-"]];
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < parts.count; i++) {
        NSString *p = parts[i];
        if (!p.length) continue;
        if (i == 0) [out addObject:p.lowercaseString];
        else if (p.length == 4) [out addObject:p.capitalizedString];
        else if (p.length == 2 || (p.length == 3 && [p rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location == 0)) [out addObject:p.uppercaseString];
        else [out addObject:p];
    }
    return [out componentsJoinedByString:separator];
}
CFLocaleIdentifier CFLocaleCreateCanonicalLanguageIdentifierFromString(CFAllocatorRef a, CFStringRef ident) {
    return ident ? (__bridge_retained CFStringRef)canonical(STR(ident), @"-") : NULL;
}
CFLocaleIdentifier CFLocaleCreateCanonicalLocaleIdentifierFromString(CFAllocatorRef a, CFStringRef ident) {
    return ident ? (__bridge_retained CFStringRef)canonical(STR(ident), @"_") : NULL;
}
/* "en_US" -> { kCFLocaleLanguageCodeKey: en, kCFLocaleCountryCodeKey: US }, with the script and the keywords (@...=...) */
CFDictionaryRef CFLocaleCreateComponentsFromLocaleIdentifier(CFAllocatorRef a, CFLocaleIdentifier ident) {
    if (!ident) return NULL;
    NSString *s = STR(ident), *keywords = nil;
    NSRange at = [s rangeOfString:@"@"];
    if (at.location != NSNotFound) { keywords = [s substringFromIndex:at.location + 1]; s = [s substringToIndex:at.location]; }
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    NSArray *parts = [canonical(s, @"_") componentsSeparatedByString:@"_"];
    NSUInteger i = 0;
    if (i < parts.count) d[STR(kCFLocaleLanguageCode)] = parts[i++];
    if (i < parts.count && [parts[i] length] == 4) d[STR(kCFLocaleScriptCode)] = parts[i++];
    if (i < parts.count) d[STR(kCFLocaleCountryCode)] = parts[i++];
    if (i < parts.count) d[STR(kCFLocaleVariantCode)] = [[parts subarrayWithRange:NSMakeRange(i, parts.count - i)] componentsJoinedByString:@"_"];
    for (NSString *kv in [keywords componentsSeparatedByString:@";"]) {
        NSArray *p = [kv componentsSeparatedByString:@"="];
        if (p.count == 2) d[p[0]] = p[1];
    }
    return (__bridge_retained CFDictionaryRef)d;
}
CFLocaleIdentifier CFLocaleCreateLocaleIdentifierFromComponents(CFAllocatorRef a, CFDictionaryRef dict) {
    NSDictionary *d = (__bridge NSDictionary *)dict;
    if (!d) return NULL;
    NSMutableArray *parts = [NSMutableArray array];
    NSArray *keys = @[STR(kCFLocaleLanguageCode), STR(kCFLocaleScriptCode), STR(kCFLocaleCountryCode), STR(kCFLocaleVariantCode)];
    for (NSString *k in keys) if ([d[k] length]) [parts addObject:d[k]];
    NSMutableString *ident = [[parts componentsJoinedByString:@"_"] mutableCopy];
    NSMutableArray *kw = [NSMutableArray array];
    for (NSString *k in [d.allKeys sortedArrayUsingSelector:@selector(compare:)])
        if (![keys containsObject:k] && [d[k] isKindOfClass:NSString.class]) [kw addObject:[NSString stringWithFormat:@"%@=%@", k, d[k]]];
    if (kw.count) [ident appendFormat:@"@%@", [kw componentsJoinedByString:@";"]];
    return (__bridge_retained CFStringRef)ident;
}
CFLocaleLanguageDirection CFLocaleGetLanguageCharacterDirection(CFStringRef lang) {
    return lang ? (CFLocaleLanguageDirection)[NSLocale characterDirectionForLanguage:STR(lang)] : kCFLocaleLanguageDirectionUnknown;
}
CFLocaleLanguageDirection CFLocaleGetLanguageLineDirection(CFStringRef lang) {
    return lang ? kCFLocaleLanguageDirectionTopToBottom : kCFLocaleLanguageDirectionUnknown;       /* lines go down in every script */
}

/* ================= CFDateFormatter ================= */
#define FMT(f) ((__bridge NSDateFormatter *)(f))
const CFDateFormatterKey kCFDateFormatterIsLenient = CFSTR("kCFDateFormatterIsLenientKey");
const CFDateFormatterKey kCFDateFormatterTimeZone = CFSTR("kCFDateFormatterTimeZoneKey");
const CFDateFormatterKey kCFDateFormatterCalendarName = CFSTR("kCFDateFormatterCalendarNameKey");
const CFDateFormatterKey kCFDateFormatterDefaultFormat = CFSTR("kCFDateFormatterDefaultFormatKey");
const CFDateFormatterKey kCFDateFormatterTwoDigitStartDate = CFSTR("kCFDateFormatterTwoDigitStartDateKey");
const CFDateFormatterKey kCFDateFormatterDefaultDate = CFSTR("kCFDateFormatterDefaultDateKey");
const CFDateFormatterKey kCFDateFormatterCalendar = CFSTR("kCFDateFormatterCalendarKey");
const CFDateFormatterKey kCFDateFormatterEraSymbols = CFSTR("kCFDateFormatterEraSymbolsKey");
const CFDateFormatterKey kCFDateFormatterMonthSymbols = CFSTR("kCFDateFormatterMonthSymbolsKey");
const CFDateFormatterKey kCFDateFormatterShortMonthSymbols = CFSTR("kCFDateFormatterShortMonthSymbolsKey");
const CFDateFormatterKey kCFDateFormatterWeekdaySymbols = CFSTR("kCFDateFormatterWeekdaySymbolsKey");
const CFDateFormatterKey kCFDateFormatterShortWeekdaySymbols = CFSTR("kCFDateFormatterShortWeekdaySymbolsKey");
const CFDateFormatterKey kCFDateFormatterAMSymbol = CFSTR("kCFDateFormatterAMSymbolKey");
const CFDateFormatterKey kCFDateFormatterPMSymbol = CFSTR("kCFDateFormatterPMSymbolKey");
const CFDateFormatterKey kCFDateFormatterDoesRelativeDateFormattingKey = CFSTR("kCFDateFormatterDoesRelativeDateFormattingKey");

CFTypeID CFDateFormatterGetTypeID(void) { return 50; }
CFDateFormatterRef CFDateFormatterCreate(CFAllocatorRef a, CFLocaleRef locale, CFDateFormatterStyle dateStyle, CFDateFormatterStyle timeStyle) {
    NSDateFormatter *f = [NSDateFormatter new];
    f.locale = locale ? LOC(locale) : NSLocale.currentLocale;
    f.dateStyle = (NSDateFormatterStyle)dateStyle;
    f.timeStyle = (NSDateFormatterStyle)timeStyle;
    return (__bridge_retained CFDateFormatterRef)f;
}
/* an NSISO8601DateFormatter (its format options are CFISO8601DateFormatOptions) */
CFDateFormatterRef CFDateFormatterCreateISO8601Formatter(CFAllocatorRef a, CFISO8601DateFormatOptions options) {
    NSISO8601DateFormatter *f = [NSISO8601DateFormatter new];
    f.formatOptions = (NSISO8601DateFormatOptions)options;
    return (__bridge_retained CFDateFormatterRef)f;
}
static BOOL is_iso(CFDateFormatterRef f) { return [(__bridge id)f isKindOfClass:NSISO8601DateFormatter.class]; }
CFStringRef CFDateFormatterCreateDateFormatFromTemplate(CFAllocatorRef a, CFStringRef tmplate, CFOptionFlags options, CFLocaleRef locale) {
    NSString *s = tmplate ? [NSDateFormatter dateFormatFromTemplate:STR(tmplate) options:options locale:locale ? LOC(locale) : NSLocale.currentLocale] : nil;
    return s ? (__bridge_retained CFStringRef)s : NULL;
}
CFLocaleRef CFDateFormatterGetLocale(CFDateFormatterRef f) { return is_iso(f) ? (__bridge CFLocaleRef)[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"] : (__bridge CFLocaleRef)FMT(f).locale; }
CFDateFormatterStyle CFDateFormatterGetDateStyle(CFDateFormatterRef f) { return is_iso(f) ? kCFDateFormatterNoStyle : (CFDateFormatterStyle)FMT(f).dateStyle; }
CFDateFormatterStyle CFDateFormatterGetTimeStyle(CFDateFormatterRef f) { return is_iso(f) ? kCFDateFormatterNoStyle : (CFDateFormatterStyle)FMT(f).timeStyle; }
CFStringRef CFDateFormatterGetFormat(CFDateFormatterRef f) { return is_iso(f) ? CFSTR("yyyy-MM-dd'T'HH:mm:ssXXXXX") : (__bridge CFStringRef)FMT(f).dateFormat; }
void CFDateFormatterSetFormat(CFDateFormatterRef f, CFStringRef format) { if (!is_iso(f) && format) FMT(f).dateFormat = STR(format); }
CFStringRef CFDateFormatterCreateStringWithDate(CFAllocatorRef a, CFDateFormatterRef f, CFDateRef date) {
    if (!f || !date) return NULL;
    return (__bridge_retained CFStringRef)[(__bridge id)f stringFromDate:(__bridge NSDate *)date];
}
CFStringRef CFDateFormatterCreateStringWithAbsoluteTime(CFAllocatorRef a, CFDateFormatterRef f, CFAbsoluteTime at) {
    if (!f) return NULL;
    return (__bridge_retained CFStringRef)[(__bridge id)f stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:at]];
}
/* the whole range (or the string) is parsed; *rangep is set to what was parsed */
static NSDate *parse(CFDateFormatterRef f, CFStringRef string, CFRange *rangep) {
    if (!f || !string) return nil;
    NSString *s = STR(string);
    if (rangep) {
        if (rangep->location < 0 || rangep->location + rangep->length > (CFIndex)s.length) return nil;
        s = [s substringWithRange:NSMakeRange((NSUInteger)rangep->location, (NSUInteger)rangep->length)];
    }
    NSDate *d = [(__bridge id)f dateFromString:s];
    if (!d && rangep) rangep->length = 0;
    return d;
}
CFDateRef CFDateFormatterCreateDateFromString(CFAllocatorRef a, CFDateFormatterRef f, CFStringRef string, CFRange *rangep) {
    NSDate *d = parse(f, string, rangep);
    return d ? (__bridge_retained CFDateRef)d : NULL;
}
bool CFDateFormatterGetAbsoluteTimeFromString(CFDateFormatterRef f, CFStringRef string, CFRange *rangep, CFAbsoluteTime *atp) {
    NSDate *d = parse(f, string, rangep);
    if (d && atp) *atp = d.timeIntervalSinceReferenceDate;
    return d != nil;
}
void CFDateFormatterSetProperty(CFDateFormatterRef ref, CFStringRef key, CFTypeRef value) {
    if (!ref || !key) return;
    id v = (__bridge id)value;
    if (is_iso(ref)) { if (CFEqual(key, kCFDateFormatterTimeZone) && v) ((__bridge NSISO8601DateFormatter *)ref).timeZone = v; return; }
    NSDateFormatter *f = FMT(ref);
    if (CFEqual(key, kCFDateFormatterIsLenient)) f.lenient = [v boolValue];
    else if (CFEqual(key, kCFDateFormatterTimeZone)) f.timeZone = v;
    else if (CFEqual(key, kCFDateFormatterCalendarName)) f.calendar = [NSCalendar calendarWithIdentifier:v];
    else if (CFEqual(key, kCFDateFormatterCalendar)) f.calendar = v;
    else if (CFEqual(key, kCFDateFormatterTwoDigitStartDate)) f.twoDigitStartDate = v;
    else if (CFEqual(key, kCFDateFormatterDefaultDate)) f.defaultDate = v;
    else if (CFEqual(key, kCFDateFormatterMonthSymbols)) f.monthSymbols = v;
    else if (CFEqual(key, kCFDateFormatterShortMonthSymbols)) f.shortMonthSymbols = v;
    else if (CFEqual(key, kCFDateFormatterWeekdaySymbols)) f.weekdaySymbols = v;
    else if (CFEqual(key, kCFDateFormatterShortWeekdaySymbols)) f.shortWeekdaySymbols = v;
    else if (CFEqual(key, kCFDateFormatterAMSymbol)) f.AMSymbol = v;
    else if (CFEqual(key, kCFDateFormatterPMSymbol)) f.PMSymbol = v;
    else if (CFEqual(key, kCFDateFormatterDoesRelativeDateFormattingKey)) f.doesRelativeDateFormatting = [v boolValue];
}
CFTypeRef CFDateFormatterCopyProperty(CFDateFormatterRef ref, CFDateFormatterKey key) {
    if (!ref || !key) return NULL;
    id v = nil;
    if (is_iso(ref)) v = CFEqual(key, kCFDateFormatterTimeZone) ? ((__bridge NSISO8601DateFormatter *)ref).timeZone : nil;
    else {
        NSDateFormatter *f = FMT(ref);
        if (CFEqual(key, kCFDateFormatterIsLenient)) v = @(f.lenient);
        else if (CFEqual(key, kCFDateFormatterTimeZone)) v = f.timeZone;
        else if (CFEqual(key, kCFDateFormatterCalendarName)) v = f.calendar.calendarIdentifier;
        else if (CFEqual(key, kCFDateFormatterCalendar)) v = f.calendar;
        else if (CFEqual(key, kCFDateFormatterDefaultFormat)) {
            NSDateFormatter *plain = [NSDateFormatter new];
            plain.locale = f.locale; plain.dateStyle = f.dateStyle; plain.timeStyle = f.timeStyle;
            v = plain.dateFormat;
        }
        else if (CFEqual(key, kCFDateFormatterTwoDigitStartDate)) v = f.twoDigitStartDate;
        else if (CFEqual(key, kCFDateFormatterDefaultDate)) v = f.defaultDate;
        else if (CFEqual(key, kCFDateFormatterEraSymbols)) v = f.eraSymbols;
        else if (CFEqual(key, kCFDateFormatterMonthSymbols)) v = f.monthSymbols;
        else if (CFEqual(key, kCFDateFormatterShortMonthSymbols)) v = f.shortMonthSymbols;
        else if (CFEqual(key, kCFDateFormatterWeekdaySymbols)) v = f.weekdaySymbols;
        else if (CFEqual(key, kCFDateFormatterShortWeekdaySymbols)) v = f.shortWeekdaySymbols;
        else if (CFEqual(key, kCFDateFormatterAMSymbol)) v = f.AMSymbol;
        else if (CFEqual(key, kCFDateFormatterPMSymbol)) v = f.PMSymbol;
        else if (CFEqual(key, kCFDateFormatterDoesRelativeDateFormattingKey)) v = @(f.doesRelativeDateFormatting);
    }
    return v ? (__bridge_retained CFTypeRef)v : NULL;
}

/* ================= CFPreferences ================= */
const CFStringRef kCFPreferencesAnyApplication = CFSTR("kCFPreferencesAnyApplication");
const CFStringRef kCFPreferencesCurrentApplication = CFSTR("kCFPreferencesCurrentApplication");
const CFStringRef kCFPreferencesAnyHost = CFSTR("kCFPreferencesAnyHost");
const CFStringRef kCFPreferencesCurrentHost = CFSTR("kCFPreferencesCurrentHost");
const CFStringRef kCFPreferencesAnyUser = CFSTR("kCFPreferencesAnyUser");
const CFStringRef kCFPreferencesCurrentUser = CFSTR("kCFPreferencesCurrentUser");

/* the app's defaults for the current application (or its own bundle identifier), the global domain for any
   application, a suite otherwise */
static NSUserDefaults *domain(CFStringRef appID) {
    NSString *a = STR(appID);
    if (!a || [a isEqualToString:STR(kCFPreferencesCurrentApplication)] || [a isEqualToString:NSBundle.mainBundle.bundleIdentifier])
        return NSUserDefaults.standardUserDefaults;
    static NSMutableDictionary<NSString *, NSUserDefaults *> *suites;
    @synchronized (NSUserDefaults.class) {
        if (!suites) suites = [NSMutableDictionary dictionary];
        NSString *name = [a isEqualToString:STR(kCFPreferencesAnyApplication)] ? @".GlobalPreferences" : a;
        return suites[name] ?: (suites[name] = [[NSUserDefaults alloc] initWithSuiteName:name]);
    }
}
static CFPropertyListRef copy_value(NSUserDefaults *d, CFStringRef key) {
    id v = key ? [d objectForKey:STR(key)] : nil;
    return v ? (__bridge_retained CFPropertyListRef)v : NULL;
}
CFPropertyListRef CFPreferencesCopyAppValue(CFStringRef key, CFStringRef appID) {
    NSUserDefaults *d = domain(appID);
    CFPropertyListRef v = copy_value(d, key);
    if (!v && d != domain(kCFPreferencesAnyApplication)) v = copy_value(domain(kCFPreferencesAnyApplication), key);   /* the search list */
    return v;
}
bool CFPreferencesGetAppBooleanValue(CFStringRef key, CFStringRef appID, bool *valid) {
    id v = (__bridge_transfer id)CFPreferencesCopyAppValue(key, appID);
    BOOL ok = [v isKindOfClass:NSNumber.class] || ([v isKindOfClass:NSString.class] &&
              [@[@"yes", @"no", @"true", @"false", @"1", @"0"] containsObject:[v lowercaseString]]);
    if (valid) *valid = ok;
    return ok ? [v boolValue] : false;
}
CFIndex CFPreferencesGetAppIntegerValue(CFStringRef key, CFStringRef appID, bool *valid) {
    id v = (__bridge_transfer id)CFPreferencesCopyAppValue(key, appID);
    BOOL ok = [v isKindOfClass:NSNumber.class] || ([v isKindOfClass:NSString.class] && [[NSScanner scannerWithString:v] scanInteger:NULL]);
    if (valid) *valid = ok;
    return ok ? (CFIndex)[v integerValue] : 0;
}
void CFPreferencesSetAppValue(CFStringRef key, CFPropertyListRef value, CFStringRef appID) {
    if (!key) return;
    NSUserDefaults *d = domain(appID);
    if (value) [d setObject:(__bridge id)value forKey:STR(key)]; else [d removeObjectForKey:STR(key)];
}
void CFPreferencesAddSuitePreferencesToApp(CFStringRef appID, CFStringRef suiteID) { if (suiteID) [domain(appID) addSuiteNamed:STR(suiteID)]; }
void CFPreferencesRemoveSuitePreferencesFromApp(CFStringRef appID, CFStringRef suiteID) { if (suiteID) [domain(appID) removeSuiteNamed:STR(suiteID)]; }
bool CFPreferencesAppSynchronize(CFStringRef appID) { return [domain(appID) synchronize]; }
CFPropertyListRef CFPreferencesCopyValue(CFStringRef key, CFStringRef appID, CFStringRef user, CFStringRef host) { return copy_value(domain(appID), key); }
CFDictionaryRef CFPreferencesCopyMultiple(CFArrayRef keys, CFStringRef appID, CFStringRef user, CFStringRef host) {
    NSUserDefaults *d = domain(appID);
    NSDictionary *all = d.dictionaryRepresentation;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *k in keys ? (__bridge NSArray *)keys : all.allKeys) { id v = [d objectForKey:k]; if (v) out[k] = v; }
    return (__bridge_retained CFDictionaryRef)out;
}
void CFPreferencesSetValue(CFStringRef key, CFPropertyListRef value, CFStringRef appID, CFStringRef user, CFStringRef host) {
    CFPreferencesSetAppValue(key, value, appID);
}
void CFPreferencesSetMultiple(CFDictionaryRef set, CFArrayRef remove, CFStringRef appID, CFStringRef user, CFStringRef host) {
    NSUserDefaults *d = domain(appID);
    [(__bridge NSDictionary *)set enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) { [d setObject:v forKey:k]; }];
    for (NSString *k in (__bridge NSArray *)remove) [d removeObjectForKey:k];
}
bool CFPreferencesSynchronize(CFStringRef appID, CFStringRef user, CFStringRef host) { return [domain(appID) synchronize]; }
/* the keys stored in the domain itself (not the registration domain or the global one) */
CFArrayRef CFPreferencesCopyKeyList(CFStringRef appID, CFStringRef user, CFStringRef host) {
    NSUserDefaults *d = domain(appID);
    NSString *name = d == NSUserDefaults.standardUserDefaults ? NSBundle.mainBundle.bundleIdentifier : STR(appID);
    if ([name isEqualToString:STR(kCFPreferencesAnyApplication)]) name = @".GlobalPreferences";
    NSArray *keys = name ? [d persistentDomainForName:name].allKeys : nil;
    return keys.count ? (__bridge_retained CFArrayRef)[keys sortedArrayUsingSelector:@selector(compare:)] : NULL;
}
bool CFPreferencesAppValueIsForced(CFStringRef key, CFStringRef appID) { return false; }      /* no managed (MDM) preferences */
