#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFLocale, toll-free bridged with NSLocale (CFLocaleRef is
 * the NSLocale; its keys are NSLocale's), implemented over Foundation's NSLocale. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFString.h>

__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin

#ifndef CF_EXTENSIBLE_STRING_ENUM
#define CF_EXTENSIBLE_STRING_ENUM __attribute__((swift_wrapper(struct)))
#endif
#ifndef CF_STRING_ENUM
#define CF_STRING_ENUM __attribute__((swift_wrapper(enum)))
#endif

#ifndef __ISIM_CFNOTIFICATIONNAME
#define __ISIM_CFNOTIFICATIONNAME
typedef CFStringRef CFNotificationName CF_EXTENSIBLE_STRING_ENUM;
#endif
typedef const struct __attribute__((objc_bridge(NSLocale))) __CFLocale *CFLocaleRef;
typedef CFStringRef CFLocaleIdentifier CF_EXTENSIBLE_STRING_ENUM;
typedef CFStringRef CFLocaleKey CF_STRING_ENUM;
typedef CFStringRef CFCalendarIdentifier CF_STRING_ENUM;

typedef CF_ENUM(CFIndex, CFLocaleLanguageDirection) {
    kCFLocaleLanguageDirectionUnknown = 0,
    kCFLocaleLanguageDirectionLeftToRight = 1,
    kCFLocaleLanguageDirectionRightToLeft = 2,
    kCFLocaleLanguageDirectionTopToBottom = 3,
    kCFLocaleLanguageDirectionBottomToTop = 4
};

CF_EXPORT CFTypeID CFLocaleGetTypeID(void);
CF_EXPORT CFLocaleRef CFLocaleGetSystem(void);
CF_EXPORT CFLocaleRef CFLocaleCopyCurrent(void);
CF_EXPORT CFLocaleRef CFLocaleCreate(CFAllocatorRef allocator, CFLocaleIdentifier localeIdentifier);
CF_EXPORT CFLocaleRef CFLocaleCreateCopy(CFAllocatorRef allocator, CFLocaleRef locale);
CF_EXPORT CFLocaleIdentifier CFLocaleGetIdentifier(CFLocaleRef locale);
CF_EXPORT CFTypeRef CFLocaleGetValue(CFLocaleRef locale, CFLocaleKey key);
CF_EXPORT CFStringRef CFLocaleCopyDisplayNameForPropertyValue(CFLocaleRef displayLocale, CFLocaleKey key, CFStringRef value);
CF_EXPORT CFArrayRef CFLocaleCopyAvailableLocaleIdentifiers(void);
CF_EXPORT CFArrayRef CFLocaleCopyISOLanguageCodes(void);
CF_EXPORT CFArrayRef CFLocaleCopyISOCountryCodes(void);
CF_EXPORT CFArrayRef CFLocaleCopyISOCurrencyCodes(void);
CF_EXPORT CFArrayRef CFLocaleCopyCommonISOCurrencyCodes(void);
CF_EXPORT CFArrayRef CFLocaleCopyPreferredLanguages(void);
CF_EXPORT CFLocaleIdentifier CFLocaleCreateCanonicalLanguageIdentifierFromString(CFAllocatorRef allocator, CFStringRef localeIdentifier);
CF_EXPORT CFLocaleIdentifier CFLocaleCreateCanonicalLocaleIdentifierFromString(CFAllocatorRef allocator, CFStringRef localeIdentifier);
CF_EXPORT CFDictionaryRef CFLocaleCreateComponentsFromLocaleIdentifier(CFAllocatorRef allocator, CFLocaleIdentifier localeID);
CF_EXPORT CFLocaleIdentifier CFLocaleCreateLocaleIdentifierFromComponents(CFAllocatorRef allocator, CFDictionaryRef dictionary);
CF_EXPORT CFLocaleLanguageDirection CFLocaleGetLanguageCharacterDirection(CFStringRef isoLangCode);
CF_EXPORT CFLocaleLanguageDirection CFLocaleGetLanguageLineDirection(CFStringRef isoLangCode);

CF_EXPORT const CFNotificationName kCFLocaleCurrentLocaleDidChangeNotification;

CF_EXPORT const CFLocaleKey kCFLocaleIdentifier;
CF_EXPORT const CFLocaleKey kCFLocaleLanguageCode;
CF_EXPORT const CFLocaleKey kCFLocaleCountryCode;
CF_EXPORT const CFLocaleKey kCFLocaleScriptCode;
CF_EXPORT const CFLocaleKey kCFLocaleVariantCode;
CF_EXPORT const CFLocaleKey kCFLocaleExemplarCharacterSet;
CF_EXPORT const CFLocaleKey kCFLocaleCalendarIdentifier;
CF_EXPORT const CFLocaleKey kCFLocaleCalendar;
CF_EXPORT const CFLocaleKey kCFLocaleCollationIdentifier;
CF_EXPORT const CFLocaleKey kCFLocaleUsesMetricSystem;
CF_EXPORT const CFLocaleKey kCFLocaleMeasurementSystem;
CF_EXPORT const CFLocaleKey kCFLocaleDecimalSeparator;
CF_EXPORT const CFLocaleKey kCFLocaleGroupingSeparator;
CF_EXPORT const CFLocaleKey kCFLocaleCurrencySymbol;
CF_EXPORT const CFLocaleKey kCFLocaleCurrencyCode;
CF_EXPORT const CFLocaleKey kCFLocaleCollatorIdentifier;
CF_EXPORT const CFLocaleKey kCFLocaleQuotationBeginDelimiterKey;
CF_EXPORT const CFLocaleKey kCFLocaleQuotationEndDelimiterKey;
CF_EXPORT const CFLocaleKey kCFLocaleAlternateQuotationBeginDelimiterKey;
CF_EXPORT const CFLocaleKey kCFLocaleAlternateQuotationEndDelimiterKey;

CF_EXPORT const CFCalendarIdentifier kCFGregorianCalendar;
CF_EXPORT const CFCalendarIdentifier kCFBuddhistCalendar;
CF_EXPORT const CFCalendarIdentifier kCFChineseCalendar;
CF_EXPORT const CFCalendarIdentifier kCFHebrewCalendar;
CF_EXPORT const CFCalendarIdentifier kCFIslamicCalendar;
CF_EXPORT const CFCalendarIdentifier kCFIslamicCivilCalendar;
CF_EXPORT const CFCalendarIdentifier kCFJapaneseCalendar;
CF_EXPORT const CFCalendarIdentifier kCFRepublicOfChinaCalendar;
CF_EXPORT const CFCalendarIdentifier kCFPersianCalendar;
CF_EXPORT const CFCalendarIdentifier kCFIndianCalendar;
CF_EXPORT const CFCalendarIdentifier kCFISO8601Calendar;

#pragma clang arc_cf_code_audited end
__END_DECLS
