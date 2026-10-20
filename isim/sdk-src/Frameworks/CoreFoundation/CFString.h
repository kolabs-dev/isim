#pragma once
#include <CoreFoundation/CFBase.h>
#include <stdarg.h>
__BEGIN_DECLS
typedef CF_ENUM(CFStringEncoding, CFStringBuiltInEncodings) {
    kCFStringEncodingMacRoman = 0, kCFStringEncodingWindowsLatin1 = 0x0500, kCFStringEncodingISOLatin1 = 0x0201,
    kCFStringEncodingNextStepLatin = 0x0B01, kCFStringEncodingASCII = 0x0600, kCFStringEncodingUnicode = 0x0100,
    kCFStringEncodingUTF8 = 0x08000100, kCFStringEncodingNonLossyASCII = 0x0BFF, kCFStringEncodingUTF16 = 0x0100,
    kCFStringEncodingUTF16BE = 0x10000100, kCFStringEncodingUTF16LE = 0x14000100, kCFStringEncodingUTF32 = 0x0c000100,
    kCFStringEncodingUTF32BE = 0x18000100, kCFStringEncodingUTF32LE = 0x1c000100,
};
#define kCFStringEncodingInvalidId (0xffffffffU)
CF_EXPORT const CFAllocatorRef kCFAllocatorDefault;
CF_EXPORT const CFAllocatorRef kCFAllocatorSystemDefault;
CF_EXPORT const CFAllocatorRef kCFAllocatorMalloc;
CF_EXPORT const CFAllocatorRef kCFAllocatorNull;
CF_EXPORT CFStringRef CFStringCreateWithCString(CFAllocatorRef alloc, const char *cStr, CFStringEncoding encoding) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFStringCreateWithBytes(CFAllocatorRef alloc, const UInt8 *bytes, CFIndex numBytes, CFStringEncoding encoding,
                                              Boolean isExternalRepresentation) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFStringCreateCopy(CFAllocatorRef alloc, CFStringRef theString) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableStringRef CFStringCreateMutable(CFAllocatorRef alloc, CFIndex maxLength) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableStringRef CFStringCreateMutableCopy(CFAllocatorRef alloc, CFIndex maxLength, CFStringRef theString) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFStringCreateWithFormat(CFAllocatorRef alloc, CFDictionaryRef formatOptions, CFStringRef format, ...) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFStringCreateWithFormatAndArguments(CFAllocatorRef alloc, CFDictionaryRef formatOptions, CFStringRef format,
                                                           va_list arguments) CF_RETURNS_RETAINED;
CF_EXPORT UniChar CFStringGetCharacterAtIndex(CFStringRef theString, CFIndex idx);
CF_EXPORT void CFStringGetCharacters(CFStringRef theString, CFRange range, UniChar *buffer);
CF_EXPORT Boolean CFStringGetCString(CFStringRef theString, char *buffer, CFIndex bufferSize, CFStringEncoding encoding);
CF_EXPORT const char *CFStringGetCStringPtr(CFStringRef theString, CFStringEncoding encoding);
CF_EXPORT CFIndex CFStringGetMaximumSizeForEncoding(CFIndex length, CFStringEncoding encoding);
CF_EXPORT CFComparisonResult CFStringCompare(CFStringRef theString1, CFStringRef theString2, CFOptionFlags compareOptions);
CF_EXPORT void CFStringAppend(CFMutableStringRef theString, CFStringRef appendedString);
CF_EXPORT void CFStringAppendCString(CFMutableStringRef theString, const char *cStr, CFStringEncoding encoding);
CF_EXPORT void CFStringAppendFormat(CFMutableStringRef theString, CFDictionaryRef formatOptions, CFStringRef format, ...);
CF_EXPORT void CFStringAppendFormatAndArguments(CFMutableStringRef theString, CFDictionaryRef formatOptions, CFStringRef format,
                                                va_list arguments);
CF_EXPORT unsigned long CFStringConvertEncodingToNSStringEncoding(CFStringEncoding encoding);
CF_EXPORT CFStringEncoding CFStringConvertNSStringEncodingToEncoding(unsigned long encoding);
/* transliteration (adapted: isim's own transforms, see Foundation's -applyingTransform:reverse:; transform IDs it does not
   know return false). The result is C bool here so Swift sees Bool, as with Apple's SDK (#523) */
CF_EXPORT bool CFStringTransform(CFMutableStringRef string, CFRange *range, CFStringRef transform, bool reverse);
CF_EXPORT const CFStringRef kCFStringTransformStripCombiningMarks;
CF_EXPORT const CFStringRef kCFStringTransformToLatin;
CF_EXPORT const CFStringRef kCFStringTransformFullwidthHalfwidth;
CF_EXPORT const CFStringRef kCFStringTransformLatinKatakana;
CF_EXPORT const CFStringRef kCFStringTransformLatinHiragana;
CF_EXPORT const CFStringRef kCFStringTransformHiraganaKatakana;
CF_EXPORT const CFStringRef kCFStringTransformMandarinLatin;
CF_EXPORT const CFStringRef kCFStringTransformLatinHangul;
CF_EXPORT const CFStringRef kCFStringTransformLatinArabic;
CF_EXPORT const CFStringRef kCFStringTransformLatinHebrew;
CF_EXPORT const CFStringRef kCFStringTransformLatinThai;
CF_EXPORT const CFStringRef kCFStringTransformLatinCyrillic;
CF_EXPORT const CFStringRef kCFStringTransformLatinGreek;
CF_EXPORT const CFStringRef kCFStringTransformToXMLHex;
CF_EXPORT const CFStringRef kCFStringTransformToUnicodeName;
CF_EXPORT const CFStringRef kCFStringTransformStripDiacritics;
__END_DECLS
