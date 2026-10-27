/* isim Foundation (ARC): automatic grammar agreement (NSMorphology, NSTermOfAddress, NSInflectionRule,
 * -[NSAttributedString attributedStringByInflectingString]). Adapted: isim's own rules, not Apple's grammar engine.
 *   - number: a run agrees with the numeral it holds ("^[3 apple](inflect: true)": "3 apples"), or with an explicit
 *     morphology. English inflects the run's last word (its head noun); Spanish, French, Italian and Portuguese
 *     inflect every word up to a preposition ("2 taza grande de café": "2 tazas grandes de café").
 *   - gender (es, it, pt: -o / -a; fr: adds -e): from an explicit morphology or the user's term of address.
 *   - plurals: regular endings and the common irregular nouns of each language; other words keep their form.
 * Self-authored. */
#import <Foundation/Foundation.h>
#import <Foundation/NSMorphology.h>

NSAttributedStringKey const NSInflectionRuleAttributeName = @"NSInflect";
NSAttributedStringKey const NSInflectionAlternativeAttributeName = @"NSInflectionAlternative";
NSAttributedStringKey const NSMorphologyAttributeName = @"NSMorphology";
NSAttributedStringKey const NSInflectionReferentConceptAttributeName = @"NSInflectionReferentConcept";
NSAttributedStringKey const NSInflectionAgreementArgumentAttributeName = @"NSInflectionAgreementArgument";
NSAttributedStringKey const NSInflectionAgreementConceptAttributeName = @"NSInflectionAgreementConcept";

/* ---------------- the rules ---------------- */
static NSArray<NSString *> *const inflected_languages(void) { return @[@"en", @"es", @"fr", @"it", @"pt"]; }

static NSString *keep_case(NSString *model, NSString *word) {     /* "Apple" -> "Apples", "APPLE" -> "APPLES" */
    if (!model.length || !word.length) return word;
    if ([model isEqualToString:model.uppercaseString] && model.length > 1) return word.uppercaseString;
    unichar c = [model characterAtIndex:0];
    if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c])
        return [[[word substringToIndex:1] uppercaseString] stringByAppendingString:[word substringFromIndex:1]];
    return word;
}
static BOOL ends(NSString *w, NSString *suffix) { return [w hasSuffix:suffix]; }
static NSString *cut(NSString *w, NSUInteger n) { return [w substringToIndex:w.length - n]; }
static BOOL vowel(unichar c) { return [@"aeiouáéíóúàèìòùâêîôûãõ" rangeOfString:[NSString stringWithCharacters:&c length:1]].location != NSNotFound; }

static NSDictionary<NSString *, NSString *> *irregular(NSString *lang) {
    static NSDictionary *all;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        all = @{
            @"en": @{ @"man": @"men", @"woman": @"women", @"child": @"children", @"person": @"people", @"mouse": @"mice", @"foot": @"feet",
                      @"tooth": @"teeth", @"goose": @"geese", @"ox": @"oxen", @"sheep": @"sheep", @"fish": @"fish", @"deer": @"deer",
                      @"series": @"series", @"species": @"species", @"knife": @"knives", @"life": @"lives", @"wife": @"wives", @"leaf": @"leaves",
                      @"half": @"halves", @"loaf": @"loaves", @"shelf": @"shelves", @"wolf": @"wolves", @"calf": @"calves", @"thief": @"thieves",
                      @"potato": @"potatoes", @"tomato": @"tomatoes", @"hero": @"heroes", @"echo": @"echoes", @"cactus": @"cacti" },
            @"fr": @{ @"œil": @"yeux", @"ciel": @"cieux", @"travail": @"travaux", @"bijou": @"bijoux", @"chou": @"choux", @"genou": @"genoux",
                      @"caillou": @"cailloux", @"hibou": @"hiboux", @"jouet": @"jouets" },
            @"es": @{ @"lunes": @"lunes", @"martes": @"martes", @"miércoles": @"miércoles", @"jueves": @"jueves", @"viernes": @"viernes", @"crisis": @"crisis" },
            @"it": @{ @"uomo": @"uomini", @"uovo": @"uova", @"dio": @"dei", @"bue": @"buoi", @"mano": @"mani", @"caffè": @"caffè", @"città": @"città", @"re": @"re" },
            @"pt": @{ @"pão": @"pães", @"mão": @"mãos", @"cão": @"cães", @"alemão": @"alemães", @"irmão": @"irmãos", @"lápis": @"lápis" },
        };
    });
    return all[lang];
}
static NSString *plural(NSString *lang, NSString *word) {
    NSString *w = word.lowercaseString;
    NSString *irr = irregular(lang)[w];
    if (irr) return keep_case(word, irr);
    for (NSString *k in irregular(lang)) if ([irregular(lang)[k] isEqualToString:w]) return word;   /* already plural */
    NSString *r = w;
    unichar last = w.length ? [w characterAtIndex:w.length - 1] : 0;
    unichar before = w.length > 1 ? [w characterAtIndex:w.length - 2] : 0;
    if ([lang isEqualToString:@"en"]) {
        if (ends(w, @"s") && !ends(w, @"ss") && !ends(w, @"us")) return word;
        if (ends(w, @"s") || ends(w, @"x") || ends(w, @"z") || ends(w, @"ch") || ends(w, @"sh")) r = [w stringByAppendingString:@"es"];
        else if (last == 'y' && !vowel(before)) r = [cut(w, 1) stringByAppendingString:@"ies"];
        else r = [w stringByAppendingString:@"s"];
    } else if ([lang isEqualToString:@"es"]) {
        if (ends(w, @"s") || ends(w, @"x")) return word;
        if (last == 'z') r = [cut(w, 1) stringByAppendingString:@"ces"];
        else if (ends(w, @"ón")) r = [cut(w, 2) stringByAppendingString:@"ones"];
        else if (ends(w, @"án")) r = [cut(w, 2) stringByAppendingString:@"anes"];
        else if (ends(w, @"és")) r = [cut(w, 2) stringByAppendingString:@"eses"];
        else if (vowel(last)) r = [w stringByAppendingString:@"s"];
        else r = [w stringByAppendingString:@"es"];
    } else if ([lang isEqualToString:@"fr"]) {
        if (ends(w, @"s") || ends(w, @"x") || ends(w, @"z")) return word;
        if (ends(w, @"eau") || ends(w, @"eu") || ends(w, @"au")) r = [w stringByAppendingString:@"x"];
        else if (ends(w, @"al")) r = [cut(w, 2) stringByAppendingString:@"aux"];
        else r = [w stringByAppendingString:@"s"];
    } else if ([lang isEqualToString:@"it"]) {
        if (ends(w, @"ca")) r = [cut(w, 2) stringByAppendingString:@"che"];
        else if (ends(w, @"ga")) r = [cut(w, 2) stringByAppendingString:@"ghe"];
        else if (ends(w, @"io")) r = [cut(w, 2) stringByAppendingString:@"i"];
        else if (last == 'o' || last == 'e') r = [cut(w, 1) stringByAppendingString:@"i"];
        else if (last == 'a') r = [cut(w, 1) stringByAppendingString:@"e"];
        else return word;                                  /* foreign words and accented endings do not change */
    } else if ([lang isEqualToString:@"pt"]) {
        if (ends(w, @"s")) return word;
        if (ends(w, @"ão")) r = [cut(w, 2) stringByAppendingString:@"ões"];
        else if (last == 'm') r = [cut(w, 1) stringByAppendingString:@"ns"];
        else if (ends(w, @"al") || ends(w, @"el") || ends(w, @"ol") || ends(w, @"ul")) r = [cut(w, 1) stringByAppendingString:@"is"];
        else if (last == 'r' || last == 'z') r = [w stringByAppendingString:@"es"];
        else r = [w stringByAppendingString:@"s"];
    }
    return keep_case(word, r);
}
static NSString *singular(NSString *lang, NSString *word) {
    NSString *w = word.lowercaseString;
    for (NSString *k in irregular(lang)) if ([irregular(lang)[k] isEqualToString:w]) return keep_case(word, k);
    NSString *r = w;
    if ([lang isEqualToString:@"en"]) {
        if (ends(w, @"ies") && w.length > 4) r = [cut(w, 3) stringByAppendingString:@"y"];
        else if (ends(w, @"ches") || ends(w, @"shes") || ends(w, @"xes") || ends(w, @"zes") || ends(w, @"sses")) r = cut(w, 2);
        else if (ends(w, @"s") && !ends(w, @"ss") && !ends(w, @"us") && w.length > 2) r = cut(w, 1);
    } else if ([lang isEqualToString:@"es"]) {
        if (ends(w, @"ces")) r = [cut(w, 3) stringByAppendingString:@"z"];
        else if (ends(w, @"ones")) r = [cut(w, 4) stringByAppendingString:@"ón"];
        else if (ends(w, @"es") && w.length > 3 && !vowel([w characterAtIndex:w.length - 3])) r = cut(w, 2);
        else if (ends(w, @"s") && w.length > 2) r = cut(w, 1);
    } else if ([lang isEqualToString:@"fr"]) {
        if (ends(w, @"aux")) r = [cut(w, 3) stringByAppendingString:@"al"];
        else if ((ends(w, @"eaux") || ends(w, @"eux")) && w.length > 3) r = cut(w, 1);
        else if (ends(w, @"s") && w.length > 2) r = cut(w, 1);
    } else if ([lang isEqualToString:@"pt"]) {
        if (ends(w, @"ões")) r = [cut(w, 3) stringByAppendingString:@"ão"];
        else if (ends(w, @"ns")) r = [cut(w, 2) stringByAppendingString:@"m"];
        else if (ends(w, @"is") && w.length > 3) r = [cut(w, 2) stringByAppendingString:@"l"];
        else if (ends(w, @"res") || ends(w, @"zes")) r = cut(w, 2);
        else if (ends(w, @"s") && w.length > 2) r = cut(w, 1);
    }                                                      /* Italian plurals are ambiguous (-i: -o or -e): unchanged */
    return keep_case(word, r);
}
/* gender agreement of adjectives and nouns that mark it with their ending */
static NSString *gendered(NSString *lang, NSString *word, NSGrammaticalGender gender) {
    NSString *w = word.lowercaseString, *r = w;
    if ([lang isEqualToString:@"es"] || [lang isEqualToString:@"it"] || [lang isEqualToString:@"pt"]) {
        if (gender == NSGrammaticalGenderFeminine) {
            if (ends(w, @"os")) r = [cut(w, 2) stringByAppendingString:@"as"];
            else if (ends(w, @"o")) r = [cut(w, 1) stringByAppendingString:@"a"];
            else if ([lang isEqualToString:@"es"] && (ends(w, @"or") || ends(w, @"ón"))) r = [w stringByAppendingString:@"a"];
            else if ([lang isEqualToString:@"it"] && ends(w, @"i")) r = [cut(w, 1) stringByAppendingString:@"e"];
        } else if (gender == NSGrammaticalGenderMasculine) {
            if (ends(w, @"as")) r = [cut(w, 2) stringByAppendingString:@"os"];
            else if (ends(w, @"a")) r = [cut(w, 1) stringByAppendingString:@"o"];
        }
    } else if ([lang isEqualToString:@"fr"]) {
        if (gender == NSGrammaticalGenderFeminine && !ends(w, @"e") && !ends(w, @"es")) {
            if (ends(w, @"s")) r = [cut(w, 1) stringByAppendingString:@"es"];
            else if (ends(w, @"if")) r = [cut(w, 1) stringByAppendingString:@"ve"];
            else if (ends(w, @"eux")) r = [cut(w, 1) stringByAppendingString:@"se"];
            else r = [w stringByAppendingString:@"e"];
        }
    }
    return keep_case(word, r);
}
static BOOL is_stop_word(NSString *lang, NSString *w) {   /* prepositions after which the phrase no longer agrees */
    static NSDictionary *stops;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stops = @{ @"es": [NSSet setWithArray:@[@"de", @"del", @"con", @"en", @"para", @"por", @"sin", @"a"]],
                   @"fr": [NSSet setWithArray:@[@"de", @"du", @"des", @"à", @"au", @"aux", @"avec", @"en", @"pour", @"sans", @"d"]],
                   @"it": [NSSet setWithArray:@[@"di", @"del", @"della", @"con", @"in", @"per", @"senza", @"a", @"da"]],
                   @"pt": [NSSet setWithArray:@[@"de", @"do", @"da", @"com", @"em", @"para", @"por", @"sem", @"a"]],
                   @"en": [NSSet setWithArray:@[@"of", @"with", @"for", @"in", @"on", @"to"]] };
    });
    return [stops[lang] containsObject:w.lowercaseString];
}
static BOOL is_article(NSString *lang, NSString *w) {
    static NSDictionary *arts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        arts = @{ @"es": @{ @"el": @"los", @"la": @"las", @"un": @"unos", @"una": @"unas" },
                  @"fr": @{ @"le": @"les", @"la": @"les", @"un": @"des", @"une": @"des" },
                  @"it": @{ @"il": @"i", @"lo": @"gli", @"la": @"le", @"un": @"dei", @"una": @"delle" },
                  @"pt": @{ @"o": @"os", @"a": @"as", @"um": @"uns", @"uma": @"umas" } };
    });
    return arts[lang][w.lowercaseString] != nil;
}
/* the number a numeral in the phrase asks for (0: no numeral) */
static NSGrammaticalNumber numeral_number(NSString *lang, NSArray<NSString *> *tokens) {
    for (NSString *t in tokens) {
        NSRange comma = [t rangeOfString:@"," options:NSBackwardsSearch];          /* "1,5": a decimal comma; "1,000": thousands */
        BOOL decimalComma = comma.location != NSNotFound && t.length - comma.location - 1 < 3;
        NSString *digits = decimalComma ? [t stringByReplacingOccurrencesOfString:@"," withString:@"."] : [t stringByReplacingOccurrencesOfString:@"," withString:@""];
        NSScanner *sc = [NSScanner scannerWithString:digits];
        double v;
        if ([sc scanDouble:&v] && sc.isAtEnd) {
            BOOL one = [lang isEqualToString:@"fr"] || [lang isEqualToString:@"pt"] ? (v >= 0 && v < 2) : v == 1;
            return one ? NSGrammaticalNumberSingular : NSGrammaticalNumberPlural;
        }
    }
    return NSGrammaticalNumberNotSet;
}
static NSString *inflect(NSString *s, NSString *lang, NSGrammaticalNumber number, NSGrammaticalGender gender) {
    if (![inflected_languages() containsObject:lang]) return s;
    /* words and what lies between them */
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSMutableArray<NSNumber *> *isWord = [NSMutableArray array];
    NSCharacterSet *letters = NSCharacterSet.letterCharacterSet, *digits = NSCharacterSet.decimalDigitCharacterSet;
    NSUInteger i = 0, n = s.length;
    while (i < n) {
        unichar c = [s characterAtIndex:i];
        BOOL wordish = [letters characterIsMember:c] || [digits characterIsMember:c];
        NSUInteger j = i;
        while (j < n) {
            unichar d = [s characterAtIndex:j];
            BOOL w = [letters characterIsMember:d] || [digits characterIsMember:d] || (wordish && (d == '.' || d == ',') && j + 1 < n && [digits characterIsMember:[s characterAtIndex:j + 1]]);
            if (w != wordish) break;
            j++;
        }
        [parts addObject:[s substringWithRange:NSMakeRange(i, j - i)]];
        [isWord addObject:@(wordish)];
        i = j;
    }
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSUInteger k = 0; k < parts.count; k++) if (isWord[k].boolValue) [words addObject:parts[k]];
    if (number == NSGrammaticalNumberNotSet) number = numeral_number(lang, words);
    BOOL wantPlural = number == NSGrammaticalNumberPlural || number == NSGrammaticalNumberPluralTwo || number == NSGrammaticalNumberPluralFew ||
                      number == NSGrammaticalNumberPluralMany || number == NSGrammaticalNumberZero;
    BOOL wantSingular = number == NSGrammaticalNumberSingular;
    BOOL english = [lang isEqualToString:@"en"];
    NSInteger lastWord = -1, stopAt = (NSInteger)parts.count;
    for (NSUInteger k = 0; k < parts.count; k++) {
        if (!isWord[k].boolValue) continue;
        if (is_stop_word(lang, parts[k])) { stopAt = (NSInteger)k; break; }
        if ([digits characterIsMember:[parts[k] characterAtIndex:0]]) continue;
        lastWord = (NSInteger)k;
    }
    for (NSInteger k = 0; k < stopAt; k++) {
        if (!isWord[k].boolValue || [digits characterIsMember:[parts[k] characterAtIndex:0]]) continue;
        if (english && k != lastWord) continue;           /* English: only the head noun changes */
        NSString *w = parts[k];
        if (!english && is_article(lang, w)) continue;
        if (gender == NSGrammaticalGenderFeminine || gender == NSGrammaticalGenderMasculine) w = gendered(lang, w, gender);
        if (wantPlural) w = plural(lang, w);
        else if (wantSingular) w = singular(lang, w);
        parts[k] = w;
    }
    return [parts componentsJoinedByString:@""];
}

/* ---------------- NSMorphology ---------------- */
@implementation NSMorphology
+ (BOOL)supportsSecureCoding { return YES; }
- (BOOL)isUnspecified {
    return !_grammaticalGender && !_partOfSpeech && !_number && !_grammaticalCase && !_determination && !_grammaticalPerson && !_pronounType && !_definiteness;
}
+ (NSMorphology *)userMorphology {
    NSMorphology *m = [NSMorphology new];
    m.grammaticalGender = NSTermOfAddress.currentUser._isimGender;
    return m;
}
- (id)copyWithZone:(NSZone *)zone {
    NSMorphology *m = [NSMorphology new];
    m->_grammaticalGender = _grammaticalGender; m->_partOfSpeech = _partOfSpeech; m->_number = _number; m->_grammaticalCase = _grammaticalCase;
    m->_determination = _determination; m->_grammaticalPerson = _grammaticalPerson; m->_pronounType = _pronounType; m->_definiteness = _definiteness;
    return m;
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSMorphology class]]) return NO;
    NSMorphology *m = o;
    return m->_grammaticalGender == _grammaticalGender && m->_partOfSpeech == _partOfSpeech && m->_number == _number && m->_grammaticalCase == _grammaticalCase &&
           m->_determination == _determination && m->_grammaticalPerson == _grammaticalPerson && m->_pronounType == _pronounType && m->_definiteness == _definiteness;
}
- (NSUInteger)hash { return (NSUInteger)(_grammaticalGender * 31 + _number * 7 + _partOfSpeech); }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:_grammaticalGender forKey:@"gender"]; [c encodeInteger:_partOfSpeech forKey:@"partOfSpeech"]; [c encodeInteger:_number forKey:@"number"];
    [c encodeInteger:_grammaticalCase forKey:@"case"]; [c encodeInteger:_determination forKey:@"determination"]; [c encodeInteger:_grammaticalPerson forKey:@"person"];
    [c encodeInteger:_pronounType forKey:@"pronounType"]; [c encodeInteger:_definiteness forKey:@"definiteness"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        _grammaticalGender = [c decodeIntegerForKey:@"gender"]; _partOfSpeech = [c decodeIntegerForKey:@"partOfSpeech"]; _number = [c decodeIntegerForKey:@"number"];
        _grammaticalCase = [c decodeIntegerForKey:@"case"]; _determination = [c decodeIntegerForKey:@"determination"]; _grammaticalPerson = [c decodeIntegerForKey:@"person"];
        _pronounType = [c decodeIntegerForKey:@"pronounType"]; _definiteness = [c decodeIntegerForKey:@"definiteness"];
    }
    return self;
}
+ (NSString *)_isim_inflectString:(NSString *)string language:(NSString *)language number:(NSInteger)number gender:(NSInteger)gender partOfSpeech:(NSInteger)partOfSpeech {
    NSString *lang = [[language componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]].firstObject lowercaseString] ?: @"en";
    return inflect(string, lang, (NSGrammaticalNumber)number, (NSGrammaticalGender)gender);
}
@end

@implementation NSMorphologyPronoun
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithPronoun:(NSString *)pronoun morphology:(NSMorphology *)morphology dependentMorphology:(NSMorphology *)dependent {
    if ((self = [super init])) { _pronoun = [pronoun copy]; _morphology = [morphology copy]; _dependentMorphology = [dependent copy]; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSMorphologyPronoun class]]) return NO;
    NSMorphologyPronoun *p = o;
    return [p.pronoun isEqual:_pronoun] && [p.morphology isEqual:_morphology] && (p.dependentMorphology == _dependentMorphology || [p.dependentMorphology isEqual:_dependentMorphology]);
}
- (NSUInteger)hash { return _pronoun.hash; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_pronoun forKey:@"pronoun"]; [c encodeObject:_morphology forKey:@"morphology"]; [c encodeObject:_dependentMorphology forKey:@"dependent"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithPronoun:[c decodeObjectOfClass:[NSString class] forKey:@"pronoun"] ?: @"" morphology:[c decodeObjectOfClass:[NSMorphology class] forKey:@"morphology"] ?: [NSMorphology new]
             dependentMorphology:[c decodeObjectOfClass:[NSMorphology class] forKey:@"dependent"]];
}
@end

/* ---------------- NSTermOfAddress ---------------- */
@implementation NSTermOfAddress {
    NSInteger _gender;
}
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)_withGender:(NSInteger)g { NSTermOfAddress *t = [self new]; t->_gender = g; return t; }
+ (instancetype)neutral { return [self _withGender:NSGrammaticalGenderNeuter]; }
+ (instancetype)feminine { return [self _withGender:NSGrammaticalGenderFeminine]; }
+ (instancetype)masculine { return [self _withGender:NSGrammaticalGenderMasculine]; }
/* the user's: Settings > General > Language & Region > Term of Address (isim: the ISIM_TERM_OF_ADDRESS variable, or
   the AppleTermOfAddress default: feminine, masculine or neutral; none by default) */
+ (NSTermOfAddress *)currentUser {
    NSString *v = NSProcessInfo.processInfo.environment[@"ISIM_TERM_OF_ADDRESS"] ?: [NSUserDefaults.standardUserDefaults stringForKey:@"AppleTermOfAddress"];
    NSTermOfAddress *t = [self new];
    t->_gender = [v isEqualToString:@"feminine"] ? NSGrammaticalGenderFeminine : [v isEqualToString:@"masculine"] ? NSGrammaticalGenderMasculine
               : [v isEqualToString:@"neutral"] ? NSGrammaticalGenderNeuter : NSGrammaticalGenderNotSet;
    return t;
}
+ (instancetype)localizedForLanguageIdentifier:(NSString *)language withPronouns:(NSArray<NSMorphologyPronoun *> *)pronouns {
    NSTermOfAddress *t = [self new];
    t->_languageIdentifier = [language copy];
    t->_pronouns = [pronouns copy];
    for (NSMorphologyPronoun *p in pronouns) if (p.morphology.grammaticalGender) { t->_gender = p.morphology.grammaticalGender; break; }
    return t;
}
- (NSInteger)_isimGender { return _gender; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSTermOfAddress class]]) return NO;
    NSTermOfAddress *t = o;
    return t->_gender == _gender && (t.languageIdentifier == _languageIdentifier || [t.languageIdentifier isEqual:_languageIdentifier]) &&
           (t.pronouns == _pronouns || [t.pronouns isEqual:_pronouns]);
}
- (NSUInteger)hash { return (NSUInteger)_gender ^ _languageIdentifier.hash; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInteger:_gender forKey:@"gender"]; [c encodeObject:_languageIdentifier forKey:@"language"]; [c encodeObject:_pronouns forKey:@"pronouns"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        _gender = [c decodeIntegerForKey:@"gender"];
        _languageIdentifier = [c decodeObjectOfClass:[NSString class] forKey:@"language"];
        _pronouns = [c decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSMorphologyPronoun class], nil] forKey:@"pronouns"];
    }
    return self;
}
@end

/* ---------------- NSInflectionRule ---------------- */
@implementation NSInflectionRule
+ (BOOL)supportsSecureCoding { return YES; }
+ (NSInflectionRule *)automaticRule {
    static NSInflectionRule *rule;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ rule = [NSInflectionRule new]; });
    return rule;
}
+ (BOOL)canInflectLanguage:(NSString *)language {
    NSString *lang = [[language componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]].firstObject lowercaseString];
    return lang && [inflected_languages() containsObject:lang];
}
+ (BOOL)canInflectPreferredLocalization { return [self canInflectLanguage:NSBundle.mainBundle.preferredLocalizations.firstObject ?: @"en"]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isEqual:(id)o { return [o isMemberOfClass:[NSInflectionRule class]] && [self isMemberOfClass:[NSInflectionRule class]]; }
- (NSUInteger)hash { return 1; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [super init]; }
@end
@implementation NSInflectionRuleExplicit
- (instancetype)initWithMorphology:(NSMorphology *)morphology { if ((self = [super init])) _morphology = [morphology copy]; return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSInflectionRuleExplicit class]] && [((NSInflectionRuleExplicit *)o).morphology isEqual:_morphology]; }
- (NSUInteger)hash { return _morphology.hash; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_morphology forKey:@"morphology"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithMorphology:[c decodeObjectOfClass:[NSMorphology class] forKey:@"morphology"] ?: [NSMorphology new]]; }
@end

/* ---------------- inflecting attributed strings ---------------- */
/* the app's preferred localization, or the device language when that is not one isim inflects ("Base") */
static NSString *isim_inflection_language(void) {
    NSString *pref = NSBundle.mainBundle.preferredLocalizations.firstObject;
    if (pref && [NSInflectionRule canInflectLanguage:pref]) return pref;
    return NSLocale.currentLocale.languageCode ?: pref ?: @"en";
}
@implementation NSAttributedString (NSInflection)
- (NSAttributedString *)attributedStringByInflectingString {
    NSMutableAttributedString *out = [self mutableCopy];
    NSString *lang = isim_inflection_language();
    NSInteger userGender = NSTermOfAddress.currentUser._isimGender;
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSMutableArray *rules = [NSMutableArray array];
    [self enumerateAttribute:NSInflectionRuleAttributeName inRange:NSMakeRange(0, self.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (!value) return;
        [ranges addObject:[NSValue valueWithRange:range]];
        [rules addObject:value];
    }];
    for (NSInteger k = (NSInteger)ranges.count - 1; k >= 0; k--) {
        NSRange r = ranges[(NSUInteger)k].rangeValue;
        id rule = rules[(NSUInteger)k];
        NSMorphology *m = [rule isKindOfClass:[NSInflectionRuleExplicit class]] ? ((NSInflectionRuleExplicit *)rule).morphology : nil;
        id attr = [self attribute:NSMorphologyAttributeName atIndex:r.location effectiveRange:NULL];
        if (!m && [attr isKindOfClass:[NSMorphology class]]) m = attr;
        NSInteger gender = m.grammaticalGender ?: (userGender == NSGrammaticalGenderNeuter ? 0 : userGender);
        NSString *text = [self.string substringWithRange:r];
        NSString *inflected = [NSMorphology _isim_inflectString:text language:lang number:m.number gender:gender partOfSpeech:m.partOfSpeech];
        NSDictionary *attrs = [self attributesAtIndex:r.location effectiveRange:NULL];
        NSMutableDictionary *kept = [attrs mutableCopy];
        [kept removeObjectForKey:NSInflectionRuleAttributeName];
        [kept removeObjectForKey:NSMorphologyAttributeName];
        [out replaceCharactersInRange:r withAttributedString:[[NSAttributedString alloc] initWithString:inflected attributes:kept]];
    }
    return [out copy];
}
@end
