#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFDateFormatter, implemented over Foundation's
 * NSDateFormatter (a CFDateFormatterRef is one; Apple's is not toll-free bridged). */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFDate.h>
#include <CoreFoundation/CFLocale.h>

__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin

typedef CFStringRef CFDateFormatterKey CF_STRING_ENUM;
typedef struct __CFDateFormatter *CFDateFormatterRef;

typedef CF_ENUM(CFIndex, CFDateFormatterStyle) {
    kCFDateFormatterNoStyle = 0,
    kCFDateFormatterShortStyle = 1,
    kCFDateFormatterMediumStyle = 2,
    kCFDateFormatterLongStyle = 3,
    kCFDateFormatterFullStyle = 4
};

typedef CF_OPTIONS(CFOptionFlags, CFISO8601DateFormatOptions) {
    kCFISO8601DateFormatWithYear = (1UL << 0),
    kCFISO8601DateFormatWithMonth = (1UL << 1),
    kCFISO8601DateFormatWithWeekOfYear = (1UL << 2),
    kCFISO8601DateFormatWithDay = (1UL << 4),
    kCFISO8601DateFormatWithTime = (1UL << 5),
    kCFISO8601DateFormatWithTimeZone = (1UL << 6),
    kCFISO8601DateFormatWithSpaceBetweenDateAndTime = (1UL << 7),
    kCFISO8601DateFormatWithDashSeparatorInDate = (1UL << 8),
    kCFISO8601DateFormatWithColonSeparatorInTime = (1UL << 9),
    kCFISO8601DateFormatWithColonSeparatorInTimeZone = (1UL << 10),
    kCFISO8601DateFormatWithFractionalSeconds = (1UL << 11),
    kCFISO8601DateFormatWithFullDate = kCFISO8601DateFormatWithYear | kCFISO8601DateFormatWithMonth | kCFISO8601DateFormatWithDay | kCFISO8601DateFormatWithDashSeparatorInDate,
    kCFISO8601DateFormatWithFullTime = kCFISO8601DateFormatWithTime | kCFISO8601DateFormatWithColonSeparatorInTime | kCFISO8601DateFormatWithTimeZone | kCFISO8601DateFormatWithColonSeparatorInTimeZone,
    kCFISO8601DateFormatWithInternetDateTime = kCFISO8601DateFormatWithFullDate | kCFISO8601DateFormatWithFullTime,
};

CF_EXPORT CFTypeID CFDateFormatterGetTypeID(void);
CF_EXPORT CFDateFormatterRef CFDateFormatterCreate(CFAllocatorRef allocator, CFLocaleRef locale, CFDateFormatterStyle dateStyle, CFDateFormatterStyle timeStyle);
CF_EXPORT CFDateFormatterRef CFDateFormatterCreateISO8601Formatter(CFAllocatorRef allocator, CFISO8601DateFormatOptions formatOptions);
CF_EXPORT CFStringRef CFDateFormatterCreateDateFormatFromTemplate(CFAllocatorRef allocator, CFStringRef tmplate, CFOptionFlags options, CFLocaleRef locale);
CF_EXPORT CFLocaleRef CFDateFormatterGetLocale(CFDateFormatterRef formatter);
CF_EXPORT CFDateFormatterStyle CFDateFormatterGetDateStyle(CFDateFormatterRef formatter);
CF_EXPORT CFDateFormatterStyle CFDateFormatterGetTimeStyle(CFDateFormatterRef formatter);
CF_EXPORT CFStringRef CFDateFormatterGetFormat(CFDateFormatterRef formatter);
CF_EXPORT void CFDateFormatterSetFormat(CFDateFormatterRef formatter, CFStringRef formatString);
CF_EXPORT CFStringRef CFDateFormatterCreateStringWithDate(CFAllocatorRef allocator, CFDateFormatterRef formatter, CFDateRef date);
CF_EXPORT CFStringRef CFDateFormatterCreateStringWithAbsoluteTime(CFAllocatorRef allocator, CFDateFormatterRef formatter, CFAbsoluteTime at);
CF_EXPORT CFDateRef CFDateFormatterCreateDateFromString(CFAllocatorRef allocator, CFDateFormatterRef formatter, CFStringRef string, CFRange *rangep);
CF_EXPORT bool CFDateFormatterGetAbsoluteTimeFromString(CFDateFormatterRef formatter, CFStringRef string, CFRange *rangep, CFAbsoluteTime *atp);
CF_EXPORT void CFDateFormatterSetProperty(CFDateFormatterRef formatter, CFStringRef key, CFTypeRef value);
CF_EXPORT CFTypeRef CFDateFormatterCopyProperty(CFDateFormatterRef formatter, CFDateFormatterKey key);

CF_EXPORT const CFDateFormatterKey kCFDateFormatterIsLenient;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterTimeZone;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterCalendarName;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterDefaultFormat;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterTwoDigitStartDate;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterDefaultDate;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterCalendar;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterEraSymbols;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterMonthSymbols;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterShortMonthSymbols;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterWeekdaySymbols;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterShortWeekdaySymbols;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterAMSymbol;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterPMSymbol;
CF_EXPORT const CFDateFormatterKey kCFDateFormatterDoesRelativeDateFormattingKey;

#pragma clang arc_cf_code_audited end
__END_DECLS
