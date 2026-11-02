/* isim Accessibility: braille translation (ARC) over the host's liblouis (libisim_host's isim_braille_*, which loads
   liblouis when first used). AXBrailleTable is one of liblouis's language tables (identifier org.liblouis.<file>);
   AXBrailleTranslator gives Unicode braille (U+2800...) and back-translates it; the result keeps, per output character,
   the input character it came from (inputIndex(forResultIndex:)). Without liblouis there are no tables. */
#import <Accessibility/Accessibility.h>
#include <isim_host.h>
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework builds for iOS 15 */

static NSString *const kPrefix = @"org.liblouis.";
#define IS_LOW(c) ((c) >= 0xDC00 && (c) <= 0xDFFF)   /* the second half of a surrogate pair */

@interface AXBrailleTable ()
@property (nonatomic, copy) NSString *file, *contraction, *direction, *system;
@property (nonatomic) NSInteger rank;
@end

/* every table, parsed once */
static NSArray<NSDictionary *> *all_tables(void) {
    static NSArray *tables;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *a = [NSMutableArray array];
        char *list = isim_braille_tables();
        if (list) {
            for (NSString *line in [@(list) componentsSeparatedByString:@"\n"]) {
                NSArray *f = [line componentsSeparatedByString:@"\t"];
                if (f.count < 9) continue;
                [a addObject:@{ @"file": f[0], @"language": f[1], @"name": f[2], @"dots": f[3], @"contraction": f[4], @"grade": f[5],
                                @"direction": f[6], @"region": f[7], @"system": f[8] }];
            }
            isim_media_free(list);
        }
        [a sortUsingComparator:^NSComparisonResult(NSDictionary *x, NSDictionary *y) { return [x[@"file"] compare:y[@"file"]]; }];
        tables = a;
    });
    return tables;
}
static NSString *locale_id(NSString *tag) { return [tag stringByReplacingOccurrencesOfString:@"-" withString:@"_"]; }

@implementation AXBrailleTable
- (instancetype)initWithIsimInfo:(NSDictionary *)d {
    if ((self = [super init])) {
        _file = d[@"file"];
        _identifier = [kPrefix stringByAppendingString:[_file stringByDeletingPathExtension]];
        _localizedName = d[@"name"];
        _providerIdentifier = @"org.liblouis";
        _localizedProviderName = @"liblouis";
        _isEightDot = [d[@"dots"] isEqualToString:@"8"];
        _language = d[@"language"];
        NSString *region = d[@"region"];
        _locales = [NSSet setWithObject:region.length ? locale_id(region) : locale_id(_language)];
        _contraction = d[@"contraction"]; _direction = d[@"direction"]; _system = d[@"system"];
    }
    return self;
}
- (instancetype)initWithIdentifier:(NSString *)identifier {
    for (NSDictionary *d in all_tables())
        if ([[kPrefix stringByAppendingString:[d[@"file"] stringByDeletingPathExtension]] isEqualToString:identifier]) return [self initWithIsimInfo:d];
    return nil;
}
+ (NSArray<AXBrailleTable *> *)_isim_all {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *d in all_tables()) [a addObject:[[AXBrailleTable alloc] initWithIsimInfo:d]];
    return a;
}
static BOOL matches(AXBrailleTable *t, NSString *localeID) {
    NSString *lang = [localeID componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_-"]].firstObject;
    return [t.language isEqualToString:lang] || [t.language hasPrefix:[lang stringByAppendingString:@"-"]];
}
+ (NSSet<AXBrailleTable *> *)tablesForLocale:(NSString *)localeID {
    NSMutableSet *s = [NSMutableSet set];
    for (AXBrailleTable *t in [self _isim_all]) if (matches(t, localeID)) [s addObject:t];
    return s;
}
/* iOS's default for a language: contracted six-dot braille that back-translates, in the locale's region if there is
   one (Unified English Braille for English) */
+ (AXBrailleTable *)defaultTableForLocale:(NSString *)localeID {
    AXBrailleTable *best = nil; NSInteger bestScore = -1;
    for (AXBrailleTable *t in [self _isim_all]) {
        if (!matches(t, localeID)) continue;
        NSInteger score = 0;
        if (!t.isEightDot) score += 8;
        if ([t.direction isEqualToString:@"both"]) score += 4;
        if ([t.locales containsObject:localeID]) score += 2;
        if ([t.system isEqualToString:@"ueb"]) score += 2;
        if ([t.contraction isEqualToString:@"full"]) score += 1;
        if (score > bestScore || (score == bestScore && [t.identifier compare:best.identifier] == NSOrderedAscending)) { best = t; bestScore = score; }
    }
    return best;
}
+ (NSSet<NSString *> *)supportedLocales {
    NSMutableSet *s = [NSMutableSet set];
    for (AXBrailleTable *t in [self _isim_all]) [s unionSet:t.locales];
    return s;
}
/* tables that are not for one language (liblouis's computer braille, NABCC) */
+ (NSSet<AXBrailleTable *> *)languageAgnosticTables {
    NSMutableSet *s = [NSMutableSet set];
    for (AXBrailleTable *t in [self _isim_all])
        if ([t.file rangeOfString:@"comp"].location != NSNotFound || [t.file rangeOfString:@"nabcc"].location != NSNotFound) [s addObject:t];
    return s;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[AXBrailleTable class]] && [[o identifier] isEqualToString:_identifier]; }
- (NSUInteger)hash { return _identifier.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<AXBrailleTable %@ (%@)>", _identifier, _localizedName]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_identifier forKey:@"identifier"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithIdentifier:[c decodeObjectOfClass:[NSString class] forKey:@"identifier"] ?: @""]; }
@end

@interface AXBrailleTranslationResult ()
@property (nonatomic, copy) NSString *input;
@property (nonatomic, copy) NSArray<NSNumber *> *positions;   /* per UTF-16 unit of the result: the UTF-16 index in the input */
@end
@implementation AXBrailleTranslationResult
- (instancetype)initWithIsimResult:(NSString *)r input:(NSString *)input scalarPositions:(const int *)pos count:(int)n {
    if ((self = [super init])) {
        _resultString = [r copy] ?: @""; _input = [input copy];
        /* code point index -> UTF-16 offset in the input; per UTF-16 unit of the result, its code point index */
        NSMutableArray<NSNumber *> *inStarts = [NSMutableArray array];
        for (NSUInteger i = 0; i < input.length; i++) {
            unichar c = [input characterAtIndex:i];
            if (IS_LOW(c) && i > 0) continue;
            [inStarts addObject:@(i)];
        }
        NSMutableArray *p = [NSMutableArray array];
        int cp = -1;
        for (NSUInteger i = 0; i < _resultString.length; i++) {
            if (!IS_LOW([_resultString characterAtIndex:i]) || i == 0) cp++;
            int in = (pos && cp < n) ? pos[cp] : -1;
            [p addObject:in >= 0 && (NSUInteger)in < inStarts.count ? inStarts[(NSUInteger)in] : @(NSNotFound)];
        }
        _positions = p;
    }
    return self;
}
- (NSUInteger)inputIndexForResultIndex:(NSUInteger)i { return i < _positions.count ? _positions[i].unsignedIntegerValue : NSNotFound; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_resultString forKey:@"result"]; [c encodeObject:_input forKey:@"input"]; [c encodeObject:_positions forKey:@"positions"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        _resultString = [c decodeObjectOfClass:[NSString class] forKey:@"result"] ?: @"";
        _input = [c decodeObjectOfClass:[NSString class] forKey:@"input"];
        _positions = [c decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil] forKey:@"positions"] ?: @[];
    }
    return self;
}
- (NSString *)description { return [NSString stringWithFormat:@"<AXBrailleTranslationResult %@>", _resultString]; }
@end

@implementation AXBrailleTranslator {
    AXBrailleTable *_table;
}
- (instancetype)initWithBrailleTable:(AXBrailleTable *)table { if ((self = [super init])) _table = table; return self; }
- (AXBrailleTranslationResult *)_isim_translate:(NSString *)text back:(BOOL)back {
    int *pos = NULL, n = 0;
    char *out = isim_braille_translate(_table.file.UTF8String, (text ?: @"").UTF8String, back, &pos, &n);
    NSString *r = out ? @(out) : @"";
    if (!out) NSLog(@"isim: braille %@ with %@ failed%@", back ? @"back-translation" : @"translation", _table.identifier ?: @"-",
                    isim_braille_available() ? @"" : @" (liblouis is not installed)");
    AXBrailleTranslationResult *res = [[AXBrailleTranslationResult alloc] initWithIsimResult:r input:text ?: @"" scalarPositions:pos count:n];
    if (out) isim_media_free(out);
    if (pos) isim_media_free(pos);
    return res;
}
- (AXBrailleTranslationResult *)translatePrintText:(NSString *)text { return [self _isim_translate:text back:NO]; }
- (AXBrailleTranslationResult *)backTranslateBraille:(NSString *)braille { return [self _isim_translate:braille back:YES]; }
@end
