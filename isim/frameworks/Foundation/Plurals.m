/* isim Foundation: .stringsdict plural rules (self-authored).
 * A lookup that hits a .stringsdict entry returns its NSStringLocalizedFormatKey ("%#@files@ in %@") and remembers
 * the entry for that format string. Formatting such a string (stringWithFormat:, localizedStringWithFormat:,
 * String(format:), String(localized:)) picks each variable's rule text by the CLDR plural category of its
 * argument, rewrites the rule's format specifiers to the argument's position and formats the result.
 * Apple marks the returned string itself; isim's strings bridge to Swift by copying, so the entry is found by the
 * format text (the last entry loaded for a given text wins).
 * Plural categories: CLDR integer rules for the common languages (zero/one/two/few/many/other); fractional
 * values use the language's rule for v>0 where it differs, else "other". */
#import "isim_foundation.h"

static NSMutableDictionary<NSString *, NSArray *> *registry;   /* format -> @[entry, language] */

NSString *isim_plural_format(NSDictionary *entry, NSString *language) {
    NSString *fmt = entry[@"NSStringLocalizedFormatKey"];
    @synchronized ([NSString class]) {
        if (!registry) registry = [NSMutableDictionary new];
        registry[fmt] = @[entry, language ?: @"en"];
    }
    return fmt;
}
static NSArray *lookup(NSString *fmt) {
    @synchronized ([NSString class]) { return registry[fmt]; }
}

static NSString *base_language(NSString *lang) {
    if (!lang.length || [lang isEqualToString:@"Base"]) lang = isim_preferred_languages().firstObject ?: @"en";
    NSRange r = [lang rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]];
    return (r.location == NSNotFound ? lang : [lang substringToIndex:r.location]).lowercaseString;
}

NSString *isim_plural_category(NSString *language, double n) {
    NSString *l = base_language(language);
    double a = n < 0 ? -n : n;
    BOOL integral = a == (double)(long long)a;
    long long i = (long long)a;
    long long m10 = i % 10, m100 = i % 100;
    #define IS(...) ([@[__VA_ARGS__] containsObject:l])
    if (IS(@"ja", @"zh", @"ko", @"th", @"vi", @"id", @"ms", @"lo", @"my", @"km", @"yue")) return @"other";
    if (IS(@"fr", @"pt") && ![language hasPrefix:@"pt-PT"] && ![language hasPrefix:@"pt_PT"])
        return i <= 1 ? @"one" : @"other";                                  /* i = 0,1 */
    if (IS(@"ru", @"uk", @"be")) {
        if (!integral) return @"other";
        if (m10 == 1 && m100 != 11) return @"one";
        if (m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) return @"few";
        return @"many";
    }
    if (IS(@"pl")) {
        if (!integral) return @"other";
        if (i == 1) return @"one";
        if (m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) return @"few";
        return @"many";
    }
    if (IS(@"cs", @"sk")) {
        if (!integral) return @"many";
        if (i == 1) return @"one";
        if (i >= 2 && i <= 4) return @"few";
        return @"other";
    }
    if (IS(@"hr", @"sr", @"bs")) {
        if (!integral) return @"other";
        if (m10 == 1 && m100 != 11) return @"one";
        if (m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) return @"few";
        return @"other";
    }
    if (IS(@"ar")) {
        if (!integral) return @"other";
        if (i == 0) return @"zero";
        if (i == 1) return @"one";
        if (i == 2) return @"two";
        if (m100 >= 3 && m100 <= 10) return @"few";
        if (m100 >= 11) return @"many";
        return @"other";
    }
    if (IS(@"he", @"iw")) {
        if (!integral) return @"other";
        if (i == 1) return @"one";
        if (i == 2) return @"two";
        return @"other";
    }
    if (IS(@"ro")) {
        if (!integral) return @"few";
        if (i == 1) return @"one";
        if (i == 0 || (m100 >= 2 && m100 <= 19)) return @"few";
        return @"other";
    }
    #undef IS
    /* en, de, nl, sv, da, nb, fi, it, es, el, hu, tr, ca, pt-PT, ...: one = 1 (integer) */
    return integral && i == 1 ? @"one" : @"other";
}

/* scans "%[n$]#@name@" at s[i] (s[i] == '%'); returns the end index or 0 */
static NSUInteger plural_ref(NSString *s, NSUInteger i, int *explicitPos, NSString **name) {
    NSUInteger n = s.length, j = i + 1; int num = 0;
    *explicitPos = -1;
    while (j < n && [s characterAtIndex:j] >= '0' && [s characterAtIndex:j] <= '9') num = num * 10 + ([s characterAtIndex:j++] - '0');
    if (j < n && j > i + 1 && [s characterAtIndex:j] == '$') { *explicitPos = num - 1; j++; } else j = i + 1;
    if (j + 1 >= n || [s characterAtIndex:j] != '#' || [s characterAtIndex:j + 1] != '@') return 0;
    NSUInteger k = j + 2;
    while (k < n && [s characterAtIndex:k] != '@') k++;
    if (k >= n) return 0;
    *name = [s substringWithRange:NSMakeRange(j + 2, k - j - 2)];
    return k + 1;
}

/* the end of an ordinary conversion starting at s[i] == '%' (flags, width, precision, length, conversion) */
static NSUInteger spec_end(NSString *s, NSUInteger i, BOOL *explicitPos) {
    NSUInteger n = s.length, j = i + 1;
    NSUInteger d = j; while (d < n && [s characterAtIndex:d] >= '0' && [s characterAtIndex:d] <= '9') d++;
    *explicitPos = d < n && d > j && [s characterAtIndex:d] == '$';
    if (*explicitPos) j = d + 1;
    while (j < n && strchr("-+ #0'123456789.*hlqLztj", [s characterAtIndex:j])) j++;
    return j < n ? j + 1 : n;
}

NSString *isim_plural_typed(NSString *fmt) {
    NSArray *reg = lookup(fmt);
    if (!reg) return nil;
    NSDictionary *entry = reg[0];
    NSMutableString *out = [NSMutableString string];
    NSUInteger n = fmt.length;
    for (NSUInteger i = 0; i < n;) {
        unichar c = [fmt characterAtIndex:i];
        if (c == '%' && i + 1 < n && [fmt characterAtIndex:i + 1] == '%') { [out appendString:@"%%"]; i += 2; continue; }
        int pos; NSString *name = nil; NSUInteger end;
        if (c == '%' && (end = plural_ref(fmt, i, &pos, &name))) {
            NSDictionary *rule = entry[name];
            NSString *type = [rule isKindOfClass:[NSDictionary class]] ? rule[@"NSStringFormatValueTypeKey"] : nil;
            if (![type isKindOfClass:[NSString class]] || !type.length) type = @"d";
            if (pos >= 0) [out appendFormat:@"%%%d$%@", pos + 1, type]; else [out appendFormat:@"%%%@", type];
            i = end; continue;
        }
        [out appendFormat:@"%C", c]; i++;
    }
    return out;
}

NSString *isim_plural_expand(NSString *fmt, double (^value)(int position), BOOL *expanded) {
    *expanded = NO;
    NSArray *reg = lookup(fmt);
    if (!reg) return fmt;
    NSDictionary *entry = reg[0]; NSString *lang = reg[1];
    NSMutableString *out = [NSMutableString string];
    NSUInteger n = fmt.length; int seq = 0;
    for (NSUInteger i = 0; i < n;) {
        unichar c = [fmt characterAtIndex:i];
        if (c != '%') { [out appendFormat:@"%C", c]; i++; continue; }
        if (i + 1 < n && [fmt characterAtIndex:i + 1] == '%') { [out appendString:@"%%"]; i += 2; continue; }
        int pos; NSString *name = nil; NSUInteger end = plural_ref(fmt, i, &pos, &name);
        if (end) {
            if (pos < 0) pos = seq++;
            NSDictionary *rule = entry[name];
            NSString *text = @"";
            if ([rule isKindOfClass:[NSDictionary class]]) {
                double v = value(pos);
                NSString *cat = isim_plural_category(lang, v);
                text = (v == 0 && rule[@"zero"]) ? rule[@"zero"] : (rule[cat] ?: rule[@"other"] ?: @"");
            }
            /* the rule's own conversions all refer to this variable's argument */
            for (NSUInteger k = 0; k < text.length;) {
                unichar t = [text characterAtIndex:k];
                if (t == '%' && k + 1 < text.length && [text characterAtIndex:k + 1] == '%') { [out appendString:@"%%"]; k += 2; continue; }
                if (t == '%') {
                    BOOL ex; NSUInteger e = spec_end(text, k, &ex);
                    NSString *spec = [text substringWithRange:NSMakeRange(k, e - k)];
                    if (!ex) spec = [NSString stringWithFormat:@"%%%d$%@", pos + 1, [spec substringFromIndex:1]];
                    [out appendString:spec]; k = e; continue;
                }
                [out appendFormat:@"%C", t]; k++;
            }
            i = end; continue;
        }
        /* an ordinary conversion: make it positional so the expanded rule texts can be mixed in */
        BOOL ex; NSUInteger e = spec_end(fmt, i, &ex);
        NSString *spec = [fmt substringWithRange:NSMakeRange(i, e - i)];
        if (!ex) spec = [NSString stringWithFormat:@"%%%d$%@", ++seq, [spec substringFromIndex:1]];
        [out appendString:spec]; i = e;
    }
    *expanded = YES;
    return out;
}

@implementation NSString (IsimPlurals)
- (NSString *)_isim_expandingPluralsWithValues:(NSArray<NSNumber *> *)values {
    BOOL expanded = NO;
    NSString *s = isim_plural_expand(self, ^double(int p) { return p >= 0 && p < (int)values.count ? values[p].doubleValue : 0; }, &expanded);
    return expanded ? s : nil;
}
@end
