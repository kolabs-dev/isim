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

/* numbers (Collections.mrc.m): NSNumber reads its value through -_isim_getNumber:, which the constant-literal
 * subclasses override (ConstantLiterals.mrc.m) */
enum { ISIM_NUM_INT, ISIM_NUM_UINT, ISIM_NUM_DBL, ISIM_NUM_BOOL };
typedef struct { int t; union { long long i; unsigned long long u; double d; }; } isim_numv;
@interface NSNumber (IsimPrimitive)
- (void)_isim_getNumber:(isim_numv *)v;
@end
NSNumber *isim_bool_number(BOOL v);   /* the kCFBooleanTrue/False singletons */

/* static objects for @[] and @{} (ConstantLiterals.mrc.m) */
extern struct isim_const_array __NSArray0__struct;
extern struct isim_const_dict __NSDictionary0__struct;

/* run loop services (NSRunLoop.m) */
void isim_schedule_perform(id target, SEL sel, id arg, NSTimeInterval delay);
void isim_cancel_performs(id target);
NSArray<NSString *> *isim_symbolicate(NSArray<NSNumber *> *addresses);   /* Runtime.m */
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
/* per-file metadata Linux cannot keep (ResourceValues.m), by absolute path */
id isim_file_meta(NSString *path, NSString *key);
void isim_file_meta_set(NSString *path, NSString *key, id value);
void isim_file_meta_move(NSString *from, NSString *to);          /* to = nil: the item was removed */
/* the iCloud state of a file in a ubiquity container (Ubiquity.m), or nil outside one:
 * container, displayName, evicted, downloading, excludedFromSync */
NSDictionary *isim_ubiquity_item_status(NSString *path);
NSDictionary *isim_global_preferences(void);

/* regular expressions (Regex.m) */
NSRange isim_regex_search(NSString *string, NSString *pattern, NSStringCompareOptions mask, NSRange range);
uint32_t isim_case_map(uint32_t c, int upper);   /* StringExtras.m */

/* property lists (PropertyList.m) */
@interface _IsimPlistUID : NSObject <NSCopying>
@property (readonly) uint64_t value;
+ (instancetype)uidWithValue:(uint64_t)value;
@end
id isim_plist_read(const void *bytes, NSUInteger len, NSPropertyListReadOptions opts, NSPropertyListFormat *format);
NSData *isim_plist_binary(id root);
NSString *isim_plist_write_xml(id root);

/* plural rules (Plurals.m): a localized format from a .stringsdict entry; isim_format expands its %#@var@ */
NSString *isim_plural_format(NSDictionary *entry, NSString *language);
NSString *isim_width_variants(NSDictionary *rule);   /* NSStringVariableWidthRuleType -> the widest text */
NSString *isim_plural_expand(NSString *fmt, double (^value)(int position), BOOL *expanded);
NSString *isim_plural_category(NSString *language, double n);
NSString *isim_plural_typed(NSString *fmt);   /* %#@var@ -> %<value type>, or nil when fmt is no known plural format */

/* keyed coding of Foundation's own classes (Archiver.m): their encodeWithCoder: / initWithCoder: use Apple's keys */
@interface NSKeyedArchiver (IsimBuiltin)
- (void)_isim_encodeBuiltin:(id)object asClass:(Class)cls;
@end
@interface NSKeyedUnarchiver (IsimBuiltin)
- (NSArray *)_isim_decodeObjectsForKey:(NSString *)key;
@end
void isim_encode_builtin(id object, NSCoder *coder, Class base);    /* raises for coders that are not keyed */
NSArray *isim_decode_objects(NSCoder *coder, NSString *key);       /* NS.objects-style reference lists */
