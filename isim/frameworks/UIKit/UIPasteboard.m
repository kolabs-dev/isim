/* UIPasteboard: items are dictionaries of type -> value ("public.utf8-plain-text", "public.url", "public.png",
 * "com.apple.uikit.color"). The general pasteboard's text and URL items are kept in <device data>/pasteboard.txt
 * (escaped, one item per line) so copy and paste works between the apps of an isim device; images and colors
 * stay in the copying process. Named pasteboards live in the process. */
#import "UIKitPrivate.h"
#import <UIKit/UIPasteboard.h>

UIPasteboardName const UIPasteboardNameGeneral = @"com.apple.UIKit.pboard.general";
NSNotificationName const UIPasteboardChangedNotification = @"UIPasteboardChangedNotification";
static NSString *const TText = @"public.utf8-plain-text", *const TURL = @"public.url", *const TImage = @"public.png", *const TColor = @"com.apple.uikit.color";
extern NSString *isim_data_dir(void);

@implementation UIPasteboard {
    NSMutableArray<NSDictionary *> *_items;
    NSInteger _changeCount;
    BOOL _general;
}
static NSMutableDictionary<NSString *, UIPasteboard *> *named;
- (instancetype)initWithIsimName:(NSString *)n general:(BOOL)g { if ((self = [super init])) { _name = [n copy]; _general = g; _items = [NSMutableArray array]; } return self; }
+ (UIPasteboard *)generalPasteboard {
    static UIPasteboard *g;
    if (!g) g = [[UIPasteboard alloc] initWithIsimName:UIPasteboardNameGeneral general:YES];
    return g;
}
+ (UIPasteboard *)pasteboardWithName:(UIPasteboardName)n create:(BOOL)create {
    if ([n isEqualToString:UIPasteboardNameGeneral]) return self.generalPasteboard;
    if (!named) named = [NSMutableDictionary dictionary];
    if (!named[n] && create) named[n] = [[UIPasteboard alloc] initWithIsimName:n general:NO];
    return named[n];
}
+ (UIPasteboard *)pasteboardWithUniqueName { return [self pasteboardWithName:[NSString stringWithFormat:@"isim-%08X%08X", arc4random(), arc4random()] create:YES]; }
+ (void)removePasteboardWithName:(UIPasteboardName)n { [named removeObjectForKey:n]; }

/* ---- shared storage (general pasteboard) ---- */
static NSString *store_path(void) { return [isim_data_dir() stringByAppendingPathComponent:@"pasteboard.txt"]; }
static NSString *esc(NSString *s) { return [[[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"]; }
static NSString *unesc(NSString *s) {
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '\\' && i + 1 < s.length) { unichar d = [s characterAtIndex:++i]; [o appendString:d == 'n' ? @"\n" : d == 't' ? @"\t" : [s substringWithRange:NSMakeRange(i, 1)]]; }
        else [o appendString:[s substringWithRange:NSMakeRange(i, 1)]];
    }
    return o;
}
- (void)_isim_load {
    if (!_general) return;
    NSString *s = [NSString stringWithContentsOfFile:store_path() encoding:NSUTF8StringEncoding error:NULL];
    if (!s.length) return;
    NSArray *lines = [s componentsSeparatedByString:@"\n"];
    NSInteger count = [lines.firstObject integerValue];
    if (count == _changeCount) return;                              /* our own last write (keeps in-process images) */
    _changeCount = count;
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 1; i < lines.count; i++) {
        NSArray *p = [lines[i] componentsSeparatedByString:@"\t"];
        if (p.count < 2) continue;
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        for (NSUInteger k = 0; k + 1 < p.count; k += 2) {
            NSString *type = p[k], *v = unesc(p[k + 1]);
            if ([type isEqualToString:TURL]) { NSURL *u = [NSURL URLWithString:v]; if (u) item[type] = u; }
            else item[type] = v;
        }
        if (item.count) [items addObject:item];
    }
    _items = items;
}
- (void)_isim_changed {
    _changeCount++;
    if (_general) {
        NSMutableString *s = [NSMutableString stringWithFormat:@"%ld", (long)_changeCount];
        for (NSDictionary *item in _items) {
            NSMutableArray *fields = [NSMutableArray array];
            for (NSString *type in item) {
                id v = item[type];
                if ([v isKindOfClass:[NSString class]]) [fields addObjectsFromArray:@[type, esc(v)]];
                else if ([v isKindOfClass:[NSURL class]]) [fields addObjectsFromArray:@[type, esc([(NSURL *)v absoluteString])]];
            }
            [s appendFormat:@"\n%@", fields.count ? [fields componentsJoinedByString:@"\t"] : @"-\t-"];
        }
        [s writeToFile:store_path() atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:UIPasteboardChangedNotification object:self];
}

/* ---- items ---- */
- (NSInteger)changeCount { [self _isim_load]; return _changeCount; }
- (NSArray *)items { [self _isim_load]; return [_items copy]; }
- (void)setItems:(NSArray *)items { [self _isim_load]; _items = [items mutableCopy] ?: [NSMutableArray array]; [self _isim_changed]; }
- (void)addItems:(NSArray *)items { [self _isim_load]; [_items addObjectsFromArray:items]; [self _isim_changed]; }
- (NSInteger)numberOfItems { return (NSInteger)self.items.count; }
- (NSArray *)_isim_values:(NSString *)type { NSMutableArray *a = [NSMutableArray array]; for (NSDictionary *i in self.items) if (i[type]) [a addObject:i[type]]; return a; }
- (void)_isim_setValues:(NSArray *)vals type:(NSString *)type { NSMutableArray *items = [NSMutableArray array]; for (id v in vals) [items addObject:@{ type: v }]; self.items = items; }
- (NSString *)string { return [self _isim_values:TText].firstObject ?: [[self _isim_values:TURL].firstObject absoluteString]; }
- (void)setString:(NSString *)s { [self _isim_setValues:s ? @[[s copy]] : @[] type:TText]; }
- (NSArray *)strings { NSArray *a = [self _isim_values:TText]; return a.count ? a : nil; }
- (void)setStrings:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TText]; }
- (NSURL *)URL { return [self _isim_values:TURL].firstObject; }
- (void)setURL:(NSURL *)u { [self _isim_setValues:u ? @[u] : @[] type:TURL]; }
- (NSArray *)URLs { NSArray *a = [self _isim_values:TURL]; return a.count ? a : nil; }
- (void)setURLs:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TURL]; }
- (UIImage *)image { return [self _isim_values:TImage].firstObject; }
- (void)setImage:(UIImage *)i { [self _isim_setValues:i ? @[i] : @[] type:TImage]; }
- (NSArray *)images { NSArray *a = [self _isim_values:TImage]; return a.count ? a : nil; }
- (void)setImages:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TImage]; }
- (UIColor *)color { return [self _isim_values:TColor].firstObject; }
- (void)setColor:(UIColor *)c { [self _isim_setValues:c ? @[c] : @[] type:TColor]; }
- (NSArray *)colors { NSArray *a = [self _isim_values:TColor]; return a.count ? a : nil; }
- (void)setColors:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TColor]; }
- (BOOL)hasStrings { return [self _isim_values:TText].count > 0 || [self _isim_values:TURL].count > 0; }
- (BOOL)hasURLs { return [self _isim_values:TURL].count > 0; }
- (BOOL)hasImages { return [self _isim_values:TImage].count > 0; }
- (BOOL)hasColors { return [self _isim_values:TColor].count > 0; }
- (id)valueForPasteboardType:(NSString *)t { return self.items.firstObject[t]; }
- (void)setValue:(id)v forPasteboardType:(NSString *)t { if (v) self.items = @[@{ t: v }]; }
- (NSArray *)pasteboardTypes { return self.items.firstObject.allKeys ?: @[]; }
- (BOOL)containsPasteboardTypes:(NSArray *)types { for (NSDictionary *i in self.items) for (NSString *t in types) if (i[t]) return YES; return NO; }
@end
