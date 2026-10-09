/* UITextChecker over isim's built-in word lists (UITextCheckerWords.c). See UITextChecker.h. Learned words persist
 * in the app's defaults (NSUserDefaults key _ISIMLearnedWords), like the per-app learned words of iOS. */
#import "UIKitInputPrivate.h"
#import <UIKit/UITextChecker.h>

extern const char *const isim_words_en, *const isim_words_pt, *const isim_words_es, *const isim_words_fr, *const isim_words_de;

static NSString *lang_key(NSString *language) {
    NSString *l = language.lowercaseString;
    for (NSString *k in @[@"pt", @"es", @"fr", @"de"]) if ([l hasPrefix:k]) return k;
    return @"en";
}
static NSSet<NSString *> *word_set(NSString *language) {
    static NSMutableDictionary<NSString *, NSSet *> *cache;
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSString *k = lang_key(language);
    NSSet *s = cache[k];
    if (!s) {
        const char *src = [k isEqualToString:@"pt"] ? isim_words_pt : [k isEqualToString:@"es"] ? isim_words_es
                        : [k isEqualToString:@"fr"] ? isim_words_fr : [k isEqualToString:@"de"] ? isim_words_de : isim_words_en;
        NSArray *words = [@(src) componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSMutableSet *m = [NSMutableSet set];
        for (NSString *w in words) if (w.length) [m addObject:w];
        s = cache[k] = m;
    }
    return s;
}
/* sorted for prefix completions */
static NSArray<NSString *> *word_list(NSString *language) {
    static NSMutableDictionary<NSString *, NSArray *> *cache;
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSString *k = lang_key(language);
    if (!cache[k]) cache[k] = [word_set(language).allObjects sortedArrayUsingSelector:@selector(compare:)];
    return cache[k];
}
/* the host's Hunspell dictionary for the language: "word/FLAGS" lines after a count line (sorted, lower-cased) */
static NSArray<NSString *> *host_list(NSString *language) {
    static NSMutableDictionary<NSString *, NSArray *> *cache;
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSString *k = lang_key(language);
    if (cache[k]) return cache[k];
    NSDictionary *files = @{ @"en": @[@"en_US", @"en_GB", @"en"], @"pt": @[@"pt_BR", @"pt_PT", @"pt"], @"es": @[@"es_ES", @"es_MX", @"es"],
                             @"fr": @[@"fr_FR", @"fr"], @"de": @[@"de_DE", @"de"] };
    const char *env = getenv("ISIM_DICTIONARIES");
    NSString *dirs = env ? @(env) : @"/usr/share/hunspell:/usr/share/myspell:/usr/share/myspell/dicts";
    NSMutableSet *words = [NSMutableSet set];
    if (![dirs isEqualToString:@"none"])
        for (NSString *dir in [dirs componentsSeparatedByString:@":"]) {
            NSString *text = nil;
            for (NSString *f in files[k]) {
                text = [NSString stringWithContentsOfFile:[dir stringByAppendingFormat:@"/%@.dic", f] encoding:NSUTF8StringEncoding error:NULL];
                if (text) break;
            }
            if (!text) continue;
            NSUInteger n = 0;
            for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
                if (n++ == 0 || !line.length) continue;
                NSString *w = [line componentsSeparatedByString:@"/"][0];
                w = [w stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (w.length < 2 || [w rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet.invertedSet].location != NSNotFound) continue;
                [words addObject:w.lowercaseString];
            }
            break;
        }
    return cache[k] = [words.allObjects sortedArrayUsingSelector:@selector(compare:)];
}
static BOOL host_known(NSString *w, NSString *language) {
    NSArray *list = host_list(language);
    if (!list.count) return NO;
    NSUInteger i = [list indexOfObject:w inSortedRange:NSMakeRange(0, list.count) options:NSBinarySearchingFirstEqual usingComparator:^NSComparisonResult(NSString *a, NSString *b) { return [a compare:b]; }];
    return i != NSNotFound;
}
/* how often each word was typed (keyboard), for ranking completions */
static NSMutableDictionary<NSString *, NSNumber *> *usage(void) {
    static NSMutableDictionary *d;
    if (!d) d = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"_ISIMWordUsage"] mutableCopy] ?: [NSMutableDictionary dictionary];
    return d;
}
void isim_text_checker_note_word(NSString *w) {
    if (w.length < 2) return;
    NSString *f = w.lowercaseString;
    usage()[f] = @(usage()[f].integerValue + 1);
    [NSUserDefaults.standardUserDefaults setObject:usage() forKey:@"_ISIMWordUsage"];
}
static NSMutableArray<NSString *> *learned(void) {
    static NSMutableArray *a;
    if (!a) a = [[NSUserDefaults.standardUserDefaults arrayForKey:@"_ISIMLearnedWords"] mutableCopy] ?: [NSMutableArray array];
    return a;
}
static void save_learned(void) { [NSUserDefaults.standardUserDefaults setObject:learned() forKey:@"_ISIMLearnedWords"]; }

/* one edit (insert, delete, substitute, transpose) away? */
static BOOL one_edit(NSString *a, NSString *b) {
    NSUInteger la = a.length, lb = b.length;
    if (la > lb + 1 || lb > la + 1 || [a isEqualToString:b]) return NO;
    unichar x[64], y[64];
    if (la > 63 || lb > 63) return NO;
    [a getCharacters:x range:NSMakeRange(0, la)]; [b getCharacters:y range:NSMakeRange(0, lb)];
    if (la == lb) {
        NSUInteger diff = 0, first = 0;
        for (NSUInteger i = 0; i < la; i++) if (x[i] != y[i]) { if (!diff) first = i; diff++; }
        if (diff == 1) return YES;
        return diff == 2 && first + 1 < la && x[first] == y[first + 1] && x[first + 1] == y[first];      /* transposition */
    }
    const unichar *s = la < lb ? x : y, *l = la < lb ? y : x; NSUInteger ls = MIN(la, lb);
    NSUInteger i = 0, j = 0; BOOL skipped = NO;
    while (i < ls && j < ls + 1) {
        if (s[i] == l[j]) { i++; j++; continue; }
        if (skipped) return NO;
        skipped = YES; j++;
    }
    return YES;
}
static NSString *fold(NSString *w) { return [w lowercaseString]; }

@implementation UITextChecker
+ (NSArray<NSString *> *)availableLanguages { return @[@"en_US", @"pt_BR", @"es_ES", @"fr_FR", @"de_DE"]; }
+ (void)learnWord:(NSString *)w { if (w.length && ![learned() containsObject:w]) { [learned() addObject:w]; save_learned(); } }
+ (BOOL)hasLearnedWord:(NSString *)w { return [learned() containsObject:w]; }
+ (void)unlearnWord:(NSString *)w { [learned() removeObject:w]; save_learned(); }
- (void)ignoreWord:(NSString *)w { if (!w.length) return; NSMutableArray *a = [_ignoredWords mutableCopy] ?: [NSMutableArray array]; [a addObject:w]; _ignoredWords = a; }

- (BOOL)_isim_known:(NSString *)w language:(NSString *)language {
    if ([_ignoredWords containsObject:w] || [learned() containsObject:w]) return YES;
    NSSet *set = word_set(language);
    NSString *f = fold(w);
    if ([set containsObject:f] || [set containsObject:w] || host_known(f, language)) return YES;
    /* plurals and simple English inflections of listed words */
    if ([lang_key(language) isEqualToString:@"en"]) for (NSString *suf in @[@"s", @"es", @"ed", @"ing", @"'s", @"ly"])
        if ([f hasSuffix:suf] && f.length > suf.length + 1 && [set containsObject:[f substringToIndex:f.length - suf.length]]) return YES;
    return NO;
}
- (NSArray<NSString *> *)_isim_closeWords:(NSString *)w language:(NSString *)language {
    NSString *f = fold(w);
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *c in word_list(language)) if (one_edit(f, c)) [out addObject:c];
    if (!out.count) for (NSString *c in host_list(language)) if (one_edit(f, c)) { [out addObject:c]; if (out.count == 8) break; }
    /* keep the word's capitalization */
    BOOL cap = w.length && [NSCharacterSet.uppercaseLetterCharacterSet characterIsMember:[w characterAtIndex:0]];
    NSMutableArray *r = [NSMutableArray array];
    for (NSString *c in out) [r addObject:cap ? [[c substringToIndex:1].uppercaseString stringByAppendingString:[c substringFromIndex:1]] : c];
    /* transpositions first (teh -> the), then a missing letter (tst -> test), substitutions, an extra letter */
    NSInteger (^rank)(NSString *) = ^NSInteger(NSString *c) {
        NSString *x = fold(c);
        if (x.length == f.length) {
            NSUInteger diff = 0; for (NSUInteger i = 0; i < x.length; i++) if ([x characterAtIndex:i] != [f characterAtIndex:i]) diff++;
            return diff == 2 ? 0 : 2;
        }
        return x.length > f.length ? 1 : 3;
    };
    [r sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSInteger ra = rank(a), rb = rank(b);
        return ra < rb ? NSOrderedAscending : ra > rb ? NSOrderedDescending : [a compare:b];
    }];
    return r;
}
- (BOOL)_isim_isMisspelled:(NSString *)w language:(NSString *)language {
    if (w.length < 2) return NO;
    for (NSUInteger i = 0; i < w.length; i++) if (![NSCharacterSet.letterCharacterSet characterIsMember:[w characterAtIndex:i]] && [w characterAtIndex:i] != '\'') return NO;
    if ([self _isim_known:w language:language]) return NO;
    return [self _isim_closeWords:w language:language].count > 0;
}
- (NSRange)rangeOfMisspelledWordInString:(NSString *)s range:(NSRange)range startingAt:(NSInteger)start wrap:(BOOL)wrap language:(NSString *)language {
    if (!s.length || NSMaxRange(range) > s.length) return NSMakeRange(NSNotFound, 0);
    __block NSRange found = NSMakeRange(NSNotFound, 0);
    NSUInteger from = MAX(range.location, (NSUInteger)MAX(0, start));
    void (^scan)(NSRange) = ^(NSRange r) {
        if (found.location != NSNotFound || r.length == 0) return;
        [s enumerateSubstringsInRange:r options:NSStringEnumerationByWords usingBlock:^(NSString *w, NSRange wr, NSRange er, BOOL *stop) {
            if ([self _isim_isMisspelled:w language:language]) { found = wr; *stop = YES; }
        }];
    };
    if (from < NSMaxRange(range)) scan(NSMakeRange(from, NSMaxRange(range) - from));
    if (wrap && found.location == NSNotFound && from > range.location) scan(NSMakeRange(range.location, from - range.location));
    return found;
}
- (NSArray<NSString *> *)guessesForWordRange:(NSRange)range inString:(NSString *)s language:(NSString *)language {
    if (NSMaxRange(range) > s.length || !range.length) return nil;
    NSString *w = [s substringWithRange:range];
    if ([self _isim_known:w language:language]) return @[];
    return [self _isim_closeWords:w language:language];
}
- (NSArray<NSString *> *)completionsForPartialWordRange:(NSRange)range inString:(NSString *)s language:(NSString *)language {
    if (!s || NSMaxRange(range) > s.length || !range.length) return nil;
    NSString *p = fold([s substringWithRange:range]);
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *w in learned()) if ([fold(w) hasPrefix:p] && ![fold(w) isEqualToString:p]) [out addObject:w];
    NSArray *list = word_list(language);
    /* binary search for the first word >= prefix */
    NSUInteger lo = 0, hi = list.count;
    while (lo < hi) { NSUInteger mid = (lo + hi) / 2; if ([list[mid] compare:p] == NSOrderedAscending) lo = mid + 1; else hi = mid; }
    for (NSUInteger i = lo; i < list.count && out.count < 10; i++) {
        NSString *w = list[i];
        if (![w hasPrefix:p]) break;
        if (![w isEqualToString:p] && ![out containsObject:w]) [out addObject:w];
    }
    NSArray *host = host_list(language);
    if (out.count < 10 && host.count) {
        lo = 0; hi = host.count;
        while (lo < hi) { NSUInteger mid = (lo + hi) / 2; if ([host[mid] compare:p] == NSOrderedAscending) lo = mid + 1; else hi = mid; }
        for (NSUInteger i = lo; i < host.count && out.count < 10; i++) {
            NSString *w = host[i];
            if (![w hasPrefix:p]) break;
            if (![w isEqualToString:p] && ![out containsObject:w]) [out addObject:w];
        }
    }
    /* the most typed first, then shorter (more common in a small list) */
    NSDictionary *used = usage();
    [out sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSInteger ua = [used[fold(a)] integerValue], ub = [used[fold(b)] integerValue];
        if (ua != ub) return ua > ub ? NSOrderedAscending : NSOrderedDescending;
        return a.length < b.length ? NSOrderedAscending : a.length > b.length ? NSOrderedDescending : NSOrderedSame; }];
    return out;
}
@end
