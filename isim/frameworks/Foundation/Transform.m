// isim Foundation: string transforms (-[NSString stringByApplyingTransform:reverse:], CFStringTransform). Adapted:
// isim's own transliteration, not ICU's. A transform ID is one or more steps separated by ";" (ICU's syntax), each an
// ID isim knows: normalization (NFD, NFC, NFKD, NFKC), removing combining marks, Latin-ASCII, Any-Latin (Greek,
// Cyrillic, kana), Latin <-> Cyrillic, Greek, Hiragana, Katakana, Hiragana <-> Katakana, Fullwidth <-> Halfwidth and
// Any-Hex/XML. Others (Mandarin, Hangul, Arabic, Hebrew, Thai, Unicode names, any ICU transform ID) go to the host's
// ICU transliterator (isim_icu_transliterate); without ICU, or for an ID it does not know either, the transform fails
// (nil, or false from CFStringTransform) and the string is unchanged.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <isim_host.h>
#include <stdlib.h>
#include <string.h>

const CFStringRef kCFStringTransformStripCombiningMarks = CFSTR("NFD; [:Nonspacing Mark:] Remove; NFC");
const CFStringRef kCFStringTransformToLatin = CFSTR("Any-Latin");
const CFStringRef kCFStringTransformFullwidthHalfwidth = CFSTR("Fullwidth-Halfwidth");
const CFStringRef kCFStringTransformLatinKatakana = CFSTR("Latin-Katakana");
const CFStringRef kCFStringTransformLatinHiragana = CFSTR("Latin-Hiragana");
const CFStringRef kCFStringTransformHiraganaKatakana = CFSTR("Hiragana-Katakana");
const CFStringRef kCFStringTransformMandarinLatin = CFSTR("Mandarin-Latin");
const CFStringRef kCFStringTransformLatinHangul = CFSTR("Latin-Hangul");
const CFStringRef kCFStringTransformLatinArabic = CFSTR("Latin-Arabic");
const CFStringRef kCFStringTransformLatinHebrew = CFSTR("Latin-Hebrew");
const CFStringRef kCFStringTransformLatinThai = CFSTR("Latin-Thai");
const CFStringRef kCFStringTransformLatinCyrillic = CFSTR("Latin-Cyrillic");
const CFStringRef kCFStringTransformLatinGreek = CFSTR("Latin-Greek");
const CFStringRef kCFStringTransformToXMLHex = CFSTR("Any-Hex/XML");
const CFStringRef kCFStringTransformToUnicodeName = CFSTR("Any-Name");
const CFStringRef kCFStringTransformStripDiacritics = CFSTR("NFD; [:Diacritic:] Remove; NFC");
NSStringTransform const NSStringTransformLatinToKatakana = @"Latin-Katakana";
NSStringTransform const NSStringTransformLatinToHiragana = @"Latin-Hiragana";
NSStringTransform const NSStringTransformLatinToHangul = @"Latin-Hangul";
NSStringTransform const NSStringTransformLatinToArabic = @"Latin-Arabic";
NSStringTransform const NSStringTransformLatinToHebrew = @"Latin-Hebrew";
NSStringTransform const NSStringTransformLatinToThai = @"Latin-Thai";
NSStringTransform const NSStringTransformLatinToCyrillic = @"Latin-Cyrillic";
NSStringTransform const NSStringTransformLatinToGreek = @"Latin-Greek";
NSStringTransform const NSStringTransformToLatin = @"Any-Latin";
NSStringTransform const NSStringTransformMandarinToLatin = @"Mandarin-Latin";
NSStringTransform const NSStringTransformHiraganaToKatakana = @"Hiragana-Katakana";
NSStringTransform const NSStringTransformFullwidthToHalfwidth = @"Fullwidth-Halfwidth";
NSStringTransform const NSStringTransformToXMLHex = @"Any-Hex/XML";
NSStringTransform const NSStringTransformToUnicodeName = @"Any-Name";
NSStringTransform const NSStringTransformStripCombiningMarks = @"NFD; [:Nonspacing Mark:] Remove; NFC";
NSStringTransform const NSStringTransformStripDiacritics = @"NFD; [:Diacritic:] Remove; NFC";

/* ---------------- tables ---------------- */
/* Cyrillic -> Latin (ISO 9, ICU's Cyrillic-Latin) */
static NSDictionary<NSString *, NSString *> *cyrillic(void) {
    static NSDictionary *d;
    if (!d) {
        NSString *lower = @"а a б b в v г g д d е e ё ë ж ž з z и i й j к k л l м m н n о o п p р r с s т t у u ф f х h ц c ч č ш š щ ŝ ъ ʺ ы y ь ʹ э è ю û я â і ì ї ï є ê ґ g̀ ў ŭ";
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        NSArray *p = [lower componentsSeparatedByString:@" "];
        for (NSUInteger i = 0; i + 1 < p.count; i += 2) {
            m[p[i]] = p[i + 1];
            NSString *up = [p[i] uppercaseString], *lat = p[i + 1];
            if (![up isEqualToString:p[i]]) m[up] = [[lat substringToIndex:1].uppercaseString stringByAppendingString:[lat substringFromIndex:1]];
        }
        d = m;
    }
    return d;
}
/* Greek -> Latin (ICU's Greek-Latin, UNGEGN) */
static NSDictionary<NSString *, NSString *> *greek(void) {
    static NSDictionary *d;
    if (!d) {
        NSString *lower = @"α a β b γ g δ d ε e ζ z η ē θ th ι i κ k λ l μ m ν n ξ x ο o π p ρ r σ s ς s τ t υ y φ ph χ ch ψ ps ω ō";
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        NSArray *p = [lower componentsSeparatedByString:@" "];
        for (NSUInteger i = 0; i + 1 < p.count; i += 2) {
            m[p[i]] = p[i + 1];
            NSString *up = [p[i] uppercaseString], *lat = p[i + 1];
            if (![up isEqualToString:p[i]] && !m[up]) m[up] = [[lat substringToIndex:1].uppercaseString stringByAppendingString:[lat substringFromIndex:1]];
        }
        d = m;
    }
    return d;
}
/* hiragana -> Hepburn (ICU's Hiragana-Latin); katakana is the same shifted by 0x60 */
static NSDictionary<NSString *, NSString *> *kana(void) {
    static NSDictionary *d;
    if (!d) {
        NSString *t = @"あ a い i う u え e お o か ka き ki く ku け ke こ ko さ sa し shi す su せ se そ so た ta ち chi つ tsu て te と to "
            "な na に ni ぬ nu ね ne の no は ha ひ hi ふ fu へ he ほ ho ま ma み mi む mu め me も mo や ya ゆ yu よ yo "
            "ら ra り ri る ru れ re ろ ro わ wa ゐ wi ゑ we を wo ん n が ga ぎ gi ぐ gu げ ge ご go ざ za じ ji ず zu ぜ ze ぞ zo "
            "だ da ぢ ji づ zu で de ど do ば ba び bi ぶ bu べ be ぼ bo ぱ pa ぴ pi ぷ pu ぺ pe ぽ po ぁ a ぃ i ぅ u ぇ e ぉ o ゎ wa ゔ vu "
            "きゃ kya きゅ kyu きょ kyo しゃ sha しゅ shu しょ sho ちゃ cha ちゅ chu ちょ cho にゃ nya にゅ nyu にょ nyo ひゃ hya ひゅ hyu ひょ hyo "
            "みゃ mya みゅ myu みょ myo りゃ rya りゅ ryu りょ ryo ぎゃ gya ぎゅ gyu ぎょ gyo じゃ ja じゅ ju じょ jo びゃ bya びゅ byu びょ byo "
            "ぴゃ pya ぴゅ pyu ぴょ pyo ふぁ fa ふぃ fi ふぇ fe ふぉ fo てぃ ti でぃ di しぇ she じぇ je ちぇ che ゃ ya ゅ yu ょ yo";
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        NSArray *p = [t componentsSeparatedByString:@" "];
        for (NSUInteger i = 0; i + 1 < p.count; i += 2) m[p[i]] = p[i + 1];
        d = m;
    }
    return d;
}
static NSString *to_hiragana(NSString *s) {          /* katakana -> hiragana (ヴ and the long-vowel mark kept) */
    NSMutableString *o = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c >= 0x30A1 && c <= 0x30F6) c -= 0x60;
        [o appendFormat:@"%C", c];
    }
    return o;
}
static NSString *to_katakana(NSString *s) {
    NSMutableString *o = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c >= 0x3041 && c <= 0x3096) c += 0x60;
        [o appendFormat:@"%C", c];
    }
    return o;
}

/* ---------------- steps ---------------- */
/* combining (nonspacing) marks: the Combining Diacritical Marks blocks and the scripts' common ones */
static BOOL is_mark(unichar c) {
    static const unichar ranges[][2] = { {0x0300, 0x036F}, {0x0483, 0x0489}, {0x0591, 0x05C7}, {0x0610, 0x061A}, {0x064B, 0x065F},
                                         {0x0E31, 0x0E31}, {0x0E34, 0x0E3A}, {0x0E47, 0x0E4E}, {0x1AB0, 0x1AFF}, {0x1DC0, 0x1DFF},
                                         {0x20D0, 0x20FF}, {0x3099, 0x309A}, {0xFE20, 0xFE2F} };
    for (size_t i = 0; i < sizeof ranges / sizeof ranges[0]; i++) if (c >= ranges[i][0] && c <= ranges[i][1]) return YES;
    return NO;
}
static NSString *remove_marks(NSString *s) {
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (!is_mark(c)) [o appendFormat:@"%C", c];
    }
    return o;
}
/* each character through a table (the longest key first), NFD so that accents ride along; others unchanged */
static NSString *map_table(NSString *s, NSDictionary<NSString *, NSString *> *table, NSUInteger longest) {
    NSString *in = s.decomposedStringWithCanonicalMapping;
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < in.length;) {
        BOOL hit = NO;
        for (NSUInteger n = MIN(longest, in.length - i); n > 0 && !hit; n--) {
            NSString *v = table[[in substringWithRange:NSMakeRange(i, n)]];
            if (v) { [o appendString:v]; i += n; hit = YES; }
        }
        if (!hit) { [o appendFormat:@"%C", [in characterAtIndex:i]]; i++; }
    }
    return o.precomposedStringWithCanonicalMapping;
}
static NSDictionary *reversed(NSDictionary *table) {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    [table enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
        NSString *key = [v decomposedStringWithCanonicalMapping];
        if (!r[key] || [k length] < [r[key] length]) r[key] = k;          /* the plain letter (σ, not ς) */
    }];
    return r;
}
static NSUInteger longest_key(NSDictionary *d) { NSUInteger n = 1; for (NSString *k in d) n = MAX(n, k.length); return n; }

/* kana -> romaji: the small tsu doubles the next consonant, the long-vowel mark lengthens the vowel (a macron) */
static NSString *kana_to_latin(NSString *s) {
    NSString *h = to_hiragana(s);
    NSDictionary *t = kana();
    NSMutableString *o = [NSMutableString string];
    BOOL doubleNext = NO;
    for (NSUInteger i = 0; i < h.length;) {
        unichar c = [h characterAtIndex:i];
        if (c == 0x3063) { doubleNext = YES; i++; continue; }                     /* っ */
        if (c == 0x30FC && o.length) {                                           /* ー */
            [o appendString:@"̄"];
            i++; continue;
        }
        NSString *v = nil;
        NSUInteger n = 0;
        if (i + 1 < h.length && (v = t[[h substringWithRange:NSMakeRange(i, 2)]])) n = 2;
        else if ((v = t[[h substringWithRange:NSMakeRange(i, 1)]])) n = 1;
        if (!v) { [o appendFormat:@"%C", c]; i++; doubleNext = NO; continue; }
        if (doubleNext) { [o appendString:[v hasPrefix:@"ch"] ? @"t" : [v substringToIndex:1]]; doubleNext = NO; }
        if ([v isEqualToString:@"n"] && i + n < h.length) {                      /* ん before a vowel or y: n' */
            NSString *next = t[[h substringWithRange:NSMakeRange(i + n, 1)]];
            if (next && [@"aiueoy" rangeOfString:[next substringToIndex:1]].location != NSNotFound) v = @"n'";
        }
        [o appendString:v];
        i += n;
    }
    return o.precomposedStringWithCanonicalMapping;
}
/* romaji -> hiragana: the longest syllable first; a doubled consonant is っ; n not before a vowel (or n') is ん */
static NSString *latin_to_hiragana(NSString *s) {
    static NSDictionary *r;
    if (!r) {
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        [kana() enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            if ([k characterAtIndex:0] >= 0x3083 && [k characterAtIndex:0] <= 0x3087 && k.length == 1) return;   /* small ya/yu/yo */
            if (k.length == 1 && [k characterAtIndex:0] >= 0x3041 && [k characterAtIndex:0] <= 0x3049 && [k characterAtIndex:0] % 2 == 1) return;  /* small vowels */
            if ([k isEqualToString:@"ゎ"] || [k isEqualToString:@"ぢ"] || [k isEqualToString:@"づ"]) return;
            if (!m[v] || k.length < [m[v] length]) m[v] = k;
        }];
        m[@"si"] = @"し"; m[@"ti"] = @"ち"; m[@"tu"] = @"つ"; m[@"hu"] = @"ふ"; m[@"zi"] = @"じ"; m[@"di"] = @"ぢ"; m[@"du"] = @"づ";
        r = m;
    }
    NSString *in = remove_marks(s.decomposedStringWithCanonicalMapping).lowercaseString;
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < in.length;) {
        unichar c = [in characterAtIndex:i];
        if (c == '\'') { i++; continue; }
        if (i + 1 < in.length && c == [in characterAtIndex:i + 1] && c != 'n' && [@"bcdfghjkmpqrstvwxyz" rangeOfString:[NSString stringWithFormat:@"%C", c]].location != NSNotFound) {
            [o appendString:@"っ"]; i++; continue;
        }
        if (c == 't' && i + 2 < in.length && [[in substringWithRange:NSMakeRange(i, 3)] isEqualToString:@"tch"]) { [o appendString:@"っ"]; i++; continue; }
        BOOL hit = NO;
        for (NSUInteger n = MIN((NSUInteger)3, in.length - i); n > 0 && !hit; n--) {
            NSString *syl = [in substringWithRange:NSMakeRange(i, n)];
            if ([syl isEqualToString:@"n"]) {
                BOOL beforeVowel = i + 1 < in.length && [@"aiueoy" rangeOfString:[NSString stringWithFormat:@"%C", [in characterAtIndex:i + 1]]].location != NSNotFound;
                if (beforeVowel) continue;
                [o appendString:@"ん"]; i++; hit = YES; break;
            }
            NSString *k = r[syl];
            if (k) { [o appendString:k]; i += n; hit = YES; }
        }
        if (!hit) { [o appendFormat:@"%C", c]; i++; }
    }
    return o;
}
static NSString *any_latin(NSString *s) {
    static NSDictionary *t;
    if (!t) { NSMutableDictionary *m = [cyrillic() mutableCopy]; [m addEntriesFromDictionary:greek()]; t = m; }
    return kana_to_latin(map_table(s, t, 1));
}
static NSString *latin_ascii(NSString *s) {
    NSDictionary *t = @{ @"ß": @"ss", @"æ": @"ae", @"Æ": @"AE", @"ø": @"o", @"Ø": @"O", @"œ": @"oe", @"Œ": @"OE", @"ł": @"l", @"Ł": @"L",
                         @"đ": @"d", @"Đ": @"D", @"þ": @"th", @"Þ": @"TH", @"ð": @"d", @"Ð": @"D", @"ı": @"i", @"“": @"\"", @"”": @"\"",
                         @"„": @"\"", @"‘": @"'", @"’": @"'", @"‚": @"'", @"–": @"-", @"—": @"-", @"…": @"...", @"«": @"<<", @"»": @">>",
                         @" ": @" " };
    return map_table(remove_marks(s.decomposedStringWithCanonicalMapping), t, 1);
}
static NSString *width(NSString *s, BOOL toHalf) {
    NSMutableString *o = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (toHalf) { if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; else if (c == 0x3000) c = ' '; }
        else { if (c >= 0x21 && c <= 0x7E) c += 0xFEE0; else if (c == ' ') c = 0x3000; }
        [o appendFormat:@"%C", c];
    }
    return o;
}
/* every character as &#xHEX; (its code point; surrogate pairs joined), or back */
static NSString *xml_hex(NSString *s, BOOL decode) {
    NSMutableString *o = [NSMutableString string];
    if (!decode) {
        for (NSUInteger i = 0; i < s.length; i++) {
            uint32_t c = [s characterAtIndex:i];
            if (c >= 0xD800 && c < 0xDC00 && i + 1 < s.length) {
                unichar lo = [s characterAtIndex:i + 1];
                if (lo >= 0xDC00 && lo < 0xE000) { c = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00); i++; }
            }
            [o appendFormat:@"&#x%X;", c];
        }
        return o;
    }
    NSScanner *sc = [NSScanner scannerWithString:s];
    sc.charactersToBeSkipped = nil;
    while (!sc.isAtEnd) {
        NSString *run = nil;
        if ([sc scanUpToString:@"&#x" intoString:&run]) [o appendString:run];
        if (sc.isAtEnd) break;
        NSUInteger save = sc.scanLocation;
        unsigned v = 0;
        if ([sc scanString:@"&#x" intoString:NULL] && [sc scanHexInt:&v] && [sc scanString:@";" intoString:NULL] && v <= 0x10FFFF) {
            if (v >= 0x10000) { v -= 0x10000; [o appendFormat:@"%C%C", (unichar)(0xD800 + (v >> 10)), (unichar)(0xDC00 + (v & 0x3FF))]; }
            else [o appendFormat:@"%C", (unichar)v];
        } else { sc.scanLocation = save + 1; [o appendString:@"&"]; }
    }
    return o;
}

/* one step of a transform (reverse: its inverse); nil if isim does not know it */
static NSString *isim_apply_own_transform(NSString *s, NSString *transform, BOOL reverse);
static NSString *apply_step(NSString *s, NSString *step, BOOL reverse) {
    NSString *id_ = [step stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *lower = id_.lowercaseString;
    if ([lower isEqualToString:@"nfd"] || [lower isEqualToString:@"nfkd"]) return reverse ? s.precomposedStringWithCanonicalMapping : s.decomposedStringWithCanonicalMapping;
    if ([lower isEqualToString:@"nfc"] || [lower isEqualToString:@"nfkc"]) return reverse ? s.decomposedStringWithCanonicalMapping : s.precomposedStringWithCanonicalMapping;
    if ([lower hasSuffix:@"remove"] && [lower hasPrefix:@"["]) return reverse ? s : remove_marks(s);
    if ([lower isEqualToString:@"any-remove"]) return reverse ? s : @"";
    NSArray *ab = [id_ componentsSeparatedByString:@"-"];
    if (ab.count != 2) return nil;
    NSString *from = [ab[0] lowercaseString], *to = [ab[1] lowercaseString];
    if (reverse) { NSString *x = from; from = to; to = x; }
    if ([to isEqualToString:@"latin"] && ([from isEqualToString:@"any"])) return any_latin(s);
    if ([from isEqualToString:@"latin"] && [to isEqualToString:@"ascii"]) return latin_ascii(s);
    if ([from isEqualToString:@"cyrillic"] && [to isEqualToString:@"latin"]) return map_table(s, cyrillic(), 1);
    if ([from isEqualToString:@"latin"] && [to isEqualToString:@"cyrillic"]) { NSDictionary *r = reversed(cyrillic()); return map_table(s, r, longest_key(r)); }
    if ([from isEqualToString:@"greek"] && [to isEqualToString:@"latin"]) return map_table(s, greek(), 1);
    if ([from isEqualToString:@"latin"] && [to isEqualToString:@"greek"]) { NSDictionary *r = reversed(greek()); return map_table(s, r, longest_key(r)); }
    if (([from isEqualToString:@"hiragana"] || [from isEqualToString:@"katakana"]) && [to isEqualToString:@"latin"]) return kana_to_latin(s);
    if ([from isEqualToString:@"latin"] && [to isEqualToString:@"hiragana"]) return latin_to_hiragana(s);
    if ([from isEqualToString:@"latin"] && [to isEqualToString:@"katakana"]) return to_katakana(latin_to_hiragana(s));
    if ([from isEqualToString:@"hiragana"] && [to isEqualToString:@"katakana"]) return to_katakana(s);
    if ([from isEqualToString:@"katakana"] && [to isEqualToString:@"hiragana"]) return to_hiragana(s);
    if ([from isEqualToString:@"fullwidth"] && [to isEqualToString:@"halfwidth"]) return width(s, YES);
    if ([from isEqualToString:@"halfwidth"] && [to isEqualToString:@"fullwidth"]) return width(s, NO);
    if ([from isEqualToString:@"any"] && [to isEqualToString:@"hex/xml"]) return xml_hex(s, NO);
    if ([from isEqualToString:@"hex/xml"] && [to isEqualToString:@"any"]) return xml_hex(s, YES);
    return nil;
}
/* the host ICU's transliteration of the whole transform (Apple's "Mandarin-Latin" is ICU's "Han-Latin") */
static NSString *icu_transform(NSString *s, NSString *transform, BOOL reverse) {
    NSString *id_ = [transform stringByReplacingOccurrencesOfString:@"Mandarin-Latin" withString:@"Han-Latin"];
    const char *in = s.UTF8String;
    int cap = (int)strlen(in) * 8 + 256;
    char *out = malloc((size_t)cap);
    int n = isim_icu_transliterate(id_.UTF8String, reverse, in, out, cap);
    NSString *r = n >= 0 ? @(out) : nil;
    free(out);
    return r;
}
NSString *isim_apply_transform(NSString *s, NSString *transform, BOOL reverse) {
    if (!s || !transform) return nil;
    NSString *own = isim_apply_own_transform(s, transform, reverse);
    return own ?: icu_transform(s, transform, reverse);
}
static NSString *isim_apply_own_transform(NSString *s, NSString *transform, BOOL reverse) {
    NSArray *steps = [transform componentsSeparatedByString:@";"];
    if (reverse) steps = steps.reverseObjectEnumerator.allObjects;
    NSString *out = s;
    for (NSString *step in steps) {
        if (![step stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) continue;
        out = apply_step(out, step, reverse);
        if (!out) return nil;
    }
    return out;
}

@implementation NSString (NSStringTransform)
- (NSString *)stringByApplyingTransform:(NSStringTransform)transform reverse:(BOOL)reverse { return isim_apply_transform(self, transform, reverse); }
@end
@implementation NSMutableString (NSStringTransform)
- (BOOL)applyTransform:(NSStringTransform)transform reverse:(BOOL)reverse range:(NSRange)range updatedRange:(NSRangePointer)resultingRange {
    if (NSMaxRange(range) > self.length) return NO;
    NSString *out = isim_apply_transform([self substringWithRange:range], transform, reverse);
    if (!out) return NO;
    [self replaceCharactersInRange:range withString:out];
    if (resultingRange) *resultingRange = NSMakeRange(range.location, out.length);
    return YES;
}
@end

Boolean CFStringTransform(CFMutableStringRef string, CFRange *range, CFStringRef transform, Boolean reverse) {
    NSMutableString *s = (__bridge NSMutableString *)string;
    if (!s || !transform) return false;
    NSRange r = range ? NSMakeRange((NSUInteger)range->location, (NSUInteger)range->length) : NSMakeRange(0, s.length);
    NSRange done;
    if (![s applyTransform:(__bridge NSString *)transform reverse:reverse range:r updatedRange:&done]) return false;
    if (range) *range = CFRangeMake((CFIndex)done.location, (CFIndex)done.length);
    return true;
}
