/* isim Foundation private interfaces (not part of the SDK). */
#pragma once
#import <Foundation/Foundation.h>

/* strings: UTF-8 storage; NSString API is in UTF-16 code units */
@interface NSString (IsimPrimitive)
- (const char *)_isim_bytes:(NSUInteger *)len;
@end
NSString *isim_string_take(char *bytes, NSUInteger len) NS_RETURNS_RETAINED;   /* takes malloc'd buffer */
NSString *isim_string_copy(const char *bytes, NSUInteger len) NS_RETURNS_RETAINED;
NSString *isim_format(NSString *fmt, va_list ap) NS_RETURNS_RETAINED;
NSUInteger isim_utf16_length(const char *s, NSUInteger n);
NSUInteger isim_utf16_to_byte(const char *s, NSUInteger n, NSUInteger idx);

/* run loop services (NSRunLoop.m) */
void isim_schedule_perform(id target, SEL sel, id arg, NSTimeInterval delay);
void isim_cancel_performs(id target);
const char *isim_process_name(void);

/* property list parsing (NSBundle.m) */
id isim_plist_parse(const char *xml, NSUInteger len);

/* localization (Locale.m) */
NSArray<NSString *> *isim_preferred_languages(void);
NSDictionary *isim_parse_strings_file(NSString *path);
NSString *isim_plist_xml(id root);
NSString *NSTemporaryDirectory_isim(void);
@interface NSString (IsimPercent)
- (NSString *)stringByRemovingPercentEncoding_isim;
@end
@interface NSString (IsimPad)
- (NSString *)stringByPaddingToLength_isim:(NSUInteger)n;
@end

/* device data & system preferences (Runtime.m, Files.m) */
NSString *isim_data_dir(void);
NSDictionary *isim_global_preferences(void);

/* regular expressions (Regex.m) */
NSRange isim_regex_search(NSString *string, NSString *pattern, NSStringCompareOptions mask, NSRange range);
uint32_t isim_case_map(uint32_t c, int upper);   /* StringExtras.m */
