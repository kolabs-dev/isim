/* UIPasteboard: items are dictionaries of type -> value ("public.utf8-plain-text", "public.url", "public.png",
 * "com.apple.uikit.color", or any type with NSData / property-list values).
 *
 * The general pasteboard is shared by the apps of an isim device: every write stores the items in
 * <device data>/pasteboard.txt (a property list: strings, URLs as strings, images as PNG data, colors as "r g b a",
 * other data as is), with the writing app and an expiration date (setItems:options:). Each app re-reads the file
 * when another app wrote it; its own writes keep the original objects. Named pasteboards live in the process.
 *
 * Paste from Other Apps (iOS 16 and later; adapted): reading another app's content (string, URL, image, color, items,
 * values, data) without a user paste asks "“App” would like to paste from “Other App”" — Don’t Allow Paste /
 * Allow Paste. The read waits for the answer in a nested main loop (iOS blocks the app while its system alert is up);
 * the answer holds until the pasteboard changes. A user paste (edit menu Paste, Cmd/Ctrl+V, UIPasteControl) never
 * asks. Setting: the app's defaults key _ISIMPrivacy.paste ("ask", "deny", "allow"; Settings > the app), or
 * ISIM_PASTE_PERMISSION=ask|deny|allow. has*, numberOfItems, types, changeCount and pattern detection never ask. */
#import "UIKitPrivate.h"
#import <UIKit/UIPasteboard.h>

UIPasteboardName const UIPasteboardNameGeneral = @"com.apple.UIKit.pboard.general";
NSString *const UIPasteboardNameFind = @"com.apple.UIKit.pboard.find";
NSNotificationName const UIPasteboardChangedNotification = @"UIPasteboardChangedNotification";
NSString *const UIPasteboardChangedTypesAddedKey = @"UIPasteboardChangedTypesAddedKey";
NSString *const UIPasteboardChangedTypesRemovedKey = @"UIPasteboardChangedTypesRemovedKey";
NSNotificationName const UIPasteboardRemovedNotification = @"UIPasteboardRemovedNotification";
NSString *const UIPasteboardTypeAutomatic = @"com.apple.uikit.pasteboard-type-automatic";
UIPasteboardOptionsKey const UIPasteboardOptionExpirationDate = @"UIPasteboardOptionExpirationDate";
UIPasteboardOptionsKey const UIPasteboardOptionLocalOnly = @"UIPasteboardOptionLocalOnly";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternProbableWebURL = @"com.apple.uikit.pasteboard-detection-pattern.probable-web-url";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternProbableWebSearch = @"com.apple.uikit.pasteboard-detection-pattern.probable-web-search";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternNumber = @"com.apple.uikit.pasteboard-detection-pattern.number";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternLink = @"com.apple.uikit.pasteboard-detection-pattern.link";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternPhoneNumber = @"com.apple.uikit.pasteboard-detection-pattern.phone-number";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternEmailAddress = @"com.apple.uikit.pasteboard-detection-pattern.email-address";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternPostalAddress = @"com.apple.uikit.pasteboard-detection-pattern.postal-address";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternCalendarEvent = @"com.apple.uikit.pasteboard-detection-pattern.calendar-event";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternShipmentTrackingNumber = @"com.apple.uikit.pasteboard-detection-pattern.shipment-tracking-number";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternFlightNumber = @"com.apple.uikit.pasteboard-detection-pattern.flight-number";
UIPasteboardDetectionPattern const UIPasteboardDetectionPatternMoneyAmount = @"com.apple.uikit.pasteboard-detection-pattern.money-amount";

static NSString *const TText = @"public.utf8-plain-text", *const TURL = @"public.url", *const TImage = @"public.png", *const TColor = @"com.apple.uikit.color";
NSArray<NSString *> *UIPasteboardTypeListString, *UIPasteboardTypeListURL, *UIPasteboardTypeListImage, *UIPasteboardTypeListColor;
__attribute__((constructor)) static void type_lists(void) {
    UIPasteboardTypeListString = @[TText, @"public.plain-text", @"public.text", @"public.utf16-plain-text"];
    UIPasteboardTypeListURL = @[TURL, @"public.file-url"];
    UIPasteboardTypeListImage = @[TImage, @"public.jpeg", @"public.tiff", @"com.compuserve.gif", @"public.image"];
    UIPasteboardTypeListColor = @[TColor];
}
extern NSString *isim_data_dir(void);

static NSString *app_id(void) { return NSBundle.mainBundle.bundleIdentifier ?: NSProcessInfo.processInfo.processName; }
static NSString *app_name(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: NSProcessInfo.processInfo.processName;
}

/* ---- user pastes ---- */
static int user_paste_depth;
void isim_ui_user_paste(void (^b)(void)) {
    user_paste_depth++;
    b();
    user_paste_depth--;
}
void isim_ui_perform_edit_action(id target, SEL s, id sender) {
    void (^call)(void) = ^{ ((void (*)(id, SEL, id))[target methodForSelector:s])(target, s, sender); };
    if ([NSStringFromSelector(s) hasPrefix:@"paste"]) isim_ui_user_paste(call);    /* paste:, pasteAndMatchStyle:, pasteAndGo:, … */
    else call();
}

@implementation UIPasteboard {
    NSMutableArray<NSDictionary *> *_items;
    NSInteger _changeCount;
    BOOL _general;
    NSString *_token, *_origin, *_originName;        /* the last write (shared file) and the app that made it */
    NSDate *_expires;
    NSInteger _answeredChange; BOOL _answeredAllow;   /* the paste prompt's answer, for one change */
}
static NSMutableDictionary<NSString *, UIPasteboard *> *named;
- (instancetype)initWithIsimName:(NSString *)n general:(BOOL)g {
    if ((self = [super init])) { _name = [n copy]; _general = g; _items = [NSMutableArray array]; _answeredChange = -1; _origin = app_id(); _originName = app_name(); }
    return self;
}
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
+ (void)removePasteboardWithName:(UIPasteboardName)n {
    UIPasteboard *p = named[n];
    if (!p) return;
    [named removeObjectForKey:n];
    [NSNotificationCenter.defaultCenter postNotificationName:UIPasteboardRemovedNotification object:p];
}
- (BOOL)isPersistent { return YES; }
- (void)setPersistent:(BOOL)p {}

/* ---- shared storage (general pasteboard) ---- */
static NSString *store_path(void) { return [isim_data_dir() stringByAppendingPathComponent:@"pasteboard.txt"]; }
/* a value as stored for other apps (nil: not shareable) */
static id stored_value(id v) {
    if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSData class]] || [v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSDate class]]) return v;
    if ([v isKindOfClass:[NSURL class]]) return [(NSURL *)v absoluteString];
    if ([v isKindOfClass:[UIImage class]]) return UIImagePNGRepresentation(v);
    if ([v isKindOfClass:[UIColor class]]) { CGFloat r = 0, g = 0, b = 0, a = 0; [(UIColor *)v getRed:&r green:&g blue:&b alpha:&a]; return [NSString stringWithFormat:@"%g %g %g %g", r, g, b, a]; }
    if ([v isKindOfClass:[NSArray class]] || [v isKindOfClass:[NSDictionary class]]) return [NSPropertyListSerialization propertyList:v isValidForFormat:NSPropertyListXMLFormat_v1_0] ? v : nil;
    return nil;
}
/* a stored value as the object the type stands for */
static id live_value(NSString *type, id v) {
    if ([UIPasteboardTypeListURL containsObject:type] && [v isKindOfClass:[NSString class]]) return [NSURL URLWithString:v];
    if ([UIPasteboardTypeListImage containsObject:type] && [v isKindOfClass:[NSData class]]) return [UIImage imageWithData:v] ?: v;
    if ([type isEqualToString:TColor] && [v isKindOfClass:[NSString class]]) {
        NSArray *c = [v componentsSeparatedByString:@" "];
        if (c.count == 4) return [UIColor colorWithRed:[c[0] doubleValue] green:[c[1] doubleValue] blue:[c[2] doubleValue] alpha:[c[3] doubleValue]];
    }
    return v;
}
- (void)_isim_load {
    if (!_general) return;
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:store_path()];
    if (![d isKindOfClass:[NSDictionary class]]) return;
    if (_token && [d[@"token"] isEqual:_token]) { [self _isim_expire]; return; }   /* our own last write (keeps the objects) */
    _token = d[@"token"]; _changeCount = [d[@"changeCount"] integerValue];
    _origin = d[@"origin"]; _originName = d[@"originName"] ?: _origin;
    _expires = [d[@"expires"] isKindOfClass:[NSDate class]] ? d[@"expires"] : nil;
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *stored in d[@"items"]) {
        if (![stored isKindOfClass:[NSDictionary class]]) continue;
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        for (NSString *type in stored) { id v = live_value(type, stored[type]); if (v) item[type] = v; }
        [items addObject:item];
    }
    _items = items;
    [self _isim_expire];
}
- (void)_isim_expire {
    if (_expires && _expires.timeIntervalSinceNow <= 0 && _items.count) { _items = [NSMutableArray array]; NSLog(@"isim: UIPasteboard: the items expired"); }
}
- (NSArray *)_isim_types:(NSArray *)items { NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSet]; for (NSDictionary *i in items) [s addObjectsFromArray:i.allKeys]; return s.array; }
- (void)_isim_changed:(NSArray *)oldItems {
    _changeCount++;
    _origin = app_id(); _originName = app_name();
    if (_general) {
        _token = NSUUID.UUID.UUIDString;
        NSMutableArray *stored = [NSMutableArray array];
        for (NSDictionary *item in _items) {
            NSMutableDictionary *s = [NSMutableDictionary dictionary];
            for (NSString *type in item) { id v = stored_value(item[type]); if (v) s[type] = v; }
            [stored addObject:s];
        }
        NSMutableDictionary *d = [@{ @"changeCount": @(_changeCount), @"token": _token, @"origin": _origin, @"originName": _originName, @"items": stored } mutableCopy];
        if (_expires) d[@"expires"] = _expires;
        [NSFileManager.defaultManager createDirectoryAtPath:isim_data_dir() withIntermediateDirectories:YES attributes:nil error:NULL];
        if (![d writeToFile:store_path() atomically:YES]) NSLog(@"isim: UIPasteboard: cannot write %@", store_path());
    }
    NSArray *before = [self _isim_types:oldItems], *after = [self _isim_types:_items];
    NSMutableArray *added = [after mutableCopy], *removed = [before mutableCopy];
    [added removeObjectsInArray:before]; [removed removeObjectsInArray:after];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (added.count) info[UIPasteboardChangedTypesAddedKey] = added;
    if (removed.count) info[UIPasteboardChangedTypesRemovedKey] = removed;
    [NSNotificationCenter.defaultCenter postNotificationName:UIPasteboardChangedNotification object:self userInfo:info];
}
- (void)_isim_replaceItems:(NSArray *)items expires:(NSDate *)expires {
    [self _isim_load];
    NSArray *old = [_items copy];
    _items = [items mutableCopy] ?: [NSMutableArray array];
    _expires = expires;
    [self _isim_changed:old];
}

/* ---- Paste from Other Apps ---- */
static NSString *paste_setting(void) {
    const char *env = getenv("ISIM_PASTE_PERMISSION");
    if (env && *env) return @(env).lowercaseString;
    NSString *s = [[NSUserDefaults.standardUserDefaults stringForKey:@"_ISIMPrivacy.paste"] lowercaseString];
    return s.length ? s : @"ask";
}
- (BOOL)_isim_mayRead {
    [self _isim_load];
    if (!_general || !_items.count || user_paste_depth || !_origin.length || [_origin isEqualToString:app_id()]) return YES;
    NSString *setting = paste_setting();
    if ([setting isEqualToString:@"allow"]) return YES;
    if ([setting isEqualToString:@"deny"]) { NSLog(@"isim: paste from “%@” denied (Paste from Other Apps: Deny)", _originName); return NO; }
    if (_answeredChange == _changeCount) return _answeredAllow;
    UIViewController *top = UIApplication.sharedApplication.keyWindow.rootViewController ?: UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
    if (!top) { NSLog(@"isim: paste from “%@” denied (no window to ask in)", _originName); return NO; }
    __block int answer = -1;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"“%@” would like to paste from “%@”", app_name(), _originName]
                                                               message:@"Do you want to allow this?" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Don’t Allow Paste" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer = 0; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Allow Paste" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer = 1; }]];
    a.view.accessibilityIdentifier = @"isim-paste-prompt";
    NSLog(@"isim: paste prompt: “%@” would like to paste from “%@”", app_name(), _originName);
    [top presentViewController:a animated:YES completion:nil];
    isim_ui_run_until(^BOOL { return answer >= 0; });
    _answeredChange = _changeCount; _answeredAllow = answer == 1;
    NSLog(@"isim: paste from “%@” %@", _originName, _answeredAllow ? @"allowed" : @"not allowed");
    return _answeredAllow;
}
/* reads: the items when this read may go ahead, else none */
- (NSArray<NSDictionary *> *)_isim_readItems { return [self _isim_mayRead] ? [_items copy] : @[]; }
- (NSArray<NSDictionary *> *)_isim_itemsForUserPaste { __block NSArray *r; isim_ui_user_paste(^{ r = [self _isim_readItems]; }); return r; }
/* checks without reading (no prompt) */
- (NSArray<NSDictionary *> *)_isim_peekItems { [self _isim_load]; return [_items copy]; }

/* ---- items ---- */
- (NSInteger)changeCount { [self _isim_load]; return _changeCount; }
- (NSArray *)items { return [self _isim_readItems]; }
- (void)setItems:(NSArray *)items { [self _isim_replaceItems:items expires:nil]; }
- (void)setItems:(NSArray *)items options:(NSDictionary *)options {
    NSDate *exp = [options[UIPasteboardOptionExpirationDate] isKindOfClass:[NSDate class]] ? options[UIPasteboardOptionExpirationDate] : nil;
    if ([options[UIPasteboardOptionLocalOnly] boolValue]) NSLog(@"isim: UIPasteboard: local only (isim has no Universal Clipboard)");
    [self _isim_replaceItems:items expires:exp];
}
- (void)addItems:(NSArray *)items { [self _isim_load]; NSArray *old = [_items copy]; [_items addObjectsFromArray:items]; [self _isim_changed:old]; }
- (NSInteger)numberOfItems { return (NSInteger)[self _isim_peekItems].count; }
static id first_of(NSDictionary *item, NSArray *types) { for (NSString *t in types) if (item[t]) return item[t]; return nil; }
static NSArray *values_of(NSArray *items, NSArray *types, Class cls) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *i in items) { id v = first_of(i, types); if (v && (!cls || [v isKindOfClass:cls])) [a addObject:v]; }
    return a;
}
- (void)_isim_setValues:(NSArray *)vals type:(NSString *)type { NSMutableArray *items = [NSMutableArray array]; for (id v in vals) [items addObject:@{ type: v }]; self.items = items; }
/* the text items (a URL-only item is not one; string falls back to the first URL) */
static NSArray<NSString *> *text_values(NSArray *items) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *i in items) {
        id v = first_of(i, UIPasteboardTypeListString);
        if ([v isKindOfClass:[NSData class]]) v = [[NSString alloc] initWithData:v encoding:NSUTF8StringEncoding];
        if ([v isKindOfClass:[NSString class]]) [a addObject:v];
    }
    return a;
}
- (NSString *)string { NSArray *items = [self _isim_readItems]; return text_values(items).firstObject ?: [values_of(items, UIPasteboardTypeListURL, [NSURL class]).firstObject absoluteString]; }
- (void)setString:(NSString *)s { [self _isim_setValues:s ? @[[s copy]] : @[] type:TText]; }
- (NSArray *)strings { NSArray *a = text_values([self _isim_readItems]); return a.count ? a : nil; }
- (void)setStrings:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TText]; }
- (NSURL *)URL { return self.URLs.firstObject; }
- (void)setURL:(NSURL *)u { [self _isim_setValues:u ? @[u] : @[] type:TURL]; }
- (NSArray *)URLs { NSArray *a = values_of([self _isim_readItems], UIPasteboardTypeListURL, [NSURL class]); return a.count ? a : nil; }
- (void)setURLs:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TURL]; }
- (UIImage *)image { return self.images.firstObject; }
- (void)setImage:(UIImage *)i { [self _isim_setValues:i ? @[i] : @[] type:TImage]; }
- (NSArray *)images { NSArray *a = values_of([self _isim_readItems], UIPasteboardTypeListImage, [UIImage class]); return a.count ? a : nil; }
- (void)setImages:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TImage]; }
- (UIColor *)color { return self.colors.firstObject; }
- (void)setColor:(UIColor *)c { [self _isim_setValues:c ? @[c] : @[] type:TColor]; }
- (NSArray *)colors { NSArray *a = values_of([self _isim_readItems], UIPasteboardTypeListColor, [UIColor class]); return a.count ? a : nil; }
- (void)setColors:(NSArray *)a { [self _isim_setValues:a ?: @[] type:TColor]; }
- (BOOL)hasStrings { NSArray *i = [self _isim_peekItems]; return values_of(i, UIPasteboardTypeListString, nil).count > 0 || values_of(i, UIPasteboardTypeListURL, nil).count > 0; }
- (BOOL)hasURLs { return values_of([self _isim_peekItems], UIPasteboardTypeListURL, nil).count > 0; }
- (BOOL)hasImages { return values_of([self _isim_peekItems], UIPasteboardTypeListImage, nil).count > 0; }
- (BOOL)hasColors { return values_of([self _isim_peekItems], UIPasteboardTypeListColor, nil).count > 0; }

/* ---- types, values and data ---- */
static NSData *data_of(id v) {
    if ([v isKindOfClass:[NSData class]]) return v;
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v dataUsingEncoding:NSUTF8StringEncoding];
    if ([v isKindOfClass:[NSURL class]]) return [[(NSURL *)v absoluteString] dataUsingEncoding:NSUTF8StringEncoding];
    if ([v isKindOfClass:[UIImage class]]) return UIImagePNGRepresentation(v);
    id s = stored_value(v);
    if ([s isKindOfClass:[NSData class]]) return s;
    if ([s isKindOfClass:[NSString class]]) return [(NSString *)s dataUsingEncoding:NSUTF8StringEncoding];
    return s ? [NSPropertyListSerialization dataWithPropertyList:s format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] : nil;
}
- (NSArray *)pasteboardTypes { return [self _isim_peekItems].firstObject.allKeys ?: @[]; }
- (BOOL)containsPasteboardTypes:(NSArray *)types { NSDictionary *i = [self _isim_peekItems].firstObject; for (NSString *t in types) if (i[t]) return YES; return NO; }
- (id)valueForPasteboardType:(NSString *)t { return [self _isim_readItems].firstObject[t]; }
- (NSData *)dataForPasteboardType:(NSString *)t { return data_of([self _isim_readItems].firstObject[t]); }
- (void)setValue:(id)v forPasteboardType:(NSString *)t { if (v) self.items = @[@{ t: v }]; }
- (void)setData:(NSData *)d forPasteboardType:(NSString *)t { if (d) self.items = @[@{ t: d }]; }
static NSArray *in_set(NSArray *items, NSIndexSet *set) {
    if (!set) return items;
    NSMutableArray *a = [NSMutableArray array];
    [set enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { if (i < items.count) [a addObject:items[i]]; }];
    return a;
}
- (NSArray *)pasteboardTypesForItemSet:(NSIndexSet *)set {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *i in in_set([self _isim_peekItems], set)) [a addObject:i.allKeys];
    return a.count ? a : nil;
}
- (BOOL)containsPasteboardTypes:(NSArray *)types inItemSet:(NSIndexSet *)set {
    for (NSDictionary *i in in_set([self _isim_peekItems], set)) for (NSString *t in types) if (i[t]) return YES;
    return NO;
}
- (NSIndexSet *)itemSetWithPasteboardTypes:(NSArray *)types {
    NSMutableIndexSet *s = [NSMutableIndexSet indexSet];
    NSArray *items = [self _isim_peekItems];
    for (NSUInteger k = 0; k < items.count; k++) for (NSString *t in types) if (items[k][t]) { [s addIndex:k]; break; }
    return s.count ? s : nil;
}
- (NSArray *)valuesForPasteboardType:(NSString *)t inItemSet:(NSIndexSet *)set {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *i in in_set([self _isim_readItems], set)) if (i[t]) [a addObject:i[t]];
    return a.count ? a : nil;
}
- (NSArray *)dataForPasteboardType:(NSString *)t inItemSet:(NSIndexSet *)set {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *i in in_set([self _isim_readItems], set)) { NSData *d = data_of(i[t]); if (d) [a addObject:d]; }
    return a.count ? a : nil;
}

/* ---- detection (adapted: simple rules over the item's text, no data detectors) ---- */
static NSString *item_text(NSDictionary *i) {
    id v = first_of(i, UIPasteboardTypeListString);
    if ([v isKindOfClass:[NSData class]]) v = [[NSString alloc] initWithData:v encoding:NSUTF8StringEncoding];
    if (![v isKindOfClass:[NSString class]]) v = [first_of(i, UIPasteboardTypeListURL) absoluteString];
    return [v isKindOfClass:[NSString class]] ? [(NSString *)v stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
}
static BOOL matches(NSString *pattern, NSString *s, BOOL whole) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
    return m && (!whole || (m.range.location == 0 && m.range.length == s.length));
}
static NSString *const kURLish = @"(https?://[^\\s]+|www\\.[^\\s]+|[a-z0-9-]+(\\.[a-z0-9-]+)*\\.(com|org|net|io|dev|app|edu|gov|co|uk|de|fr|br|pt|es|info)(/[^\\s]*)?)";
static NSDictionary<UIPasteboardDetectionPattern, id> *detect(NSDictionary *item, NSSet *patterns) {
    NSString *s = item_text(item);
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    if (!s.length) return found;
    BOOL url = matches(kURLish, s, YES);
    NSNumber *number = nil;
    NSScanner *sc = [NSScanner scannerWithString:s]; double d = 0;
    if ([sc scanDouble:&d] && sc.isAtEnd) number = @(d);
    if ([patterns containsObject:UIPasteboardDetectionPatternProbableWebURL] && url) found[UIPasteboardDetectionPatternProbableWebURL] = s;
    if ([patterns containsObject:UIPasteboardDetectionPatternProbableWebSearch] && !url && !number && s.length <= 200) found[UIPasteboardDetectionPatternProbableWebSearch] = s;
    if ([patterns containsObject:UIPasteboardDetectionPatternNumber] && number) found[UIPasteboardDetectionPatternNumber] = number;
    if ([patterns containsObject:UIPasteboardDetectionPatternLink] && matches(kURLish, s, NO)) found[UIPasteboardDetectionPatternLink] = s;
    if ([patterns containsObject:UIPasteboardDetectionPatternEmailAddress] && matches(@"[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}", s, NO)) found[UIPasteboardDetectionPatternEmailAddress] = s;
    if ([patterns containsObject:UIPasteboardDetectionPatternPhoneNumber] && matches(@"(\\+?\\d[\\d ().-]{6,}\\d)", s, NO)) found[UIPasteboardDetectionPatternPhoneNumber] = s;
    return found;
}
- (void)_isim_detect:(NSSet *)patterns set:(NSIndexSet *)set done:(void (^)(NSArray<NSDictionary *> *))done {
    NSMutableArray *per = [NSMutableArray array];
    for (NSDictionary *i in in_set([self _isim_peekItems], set)) [per addObject:detect(i, patterns)];
    dispatch_async(dispatch_get_main_queue(), ^{ done(per); });
}
- (void)detectPatternsForPatterns:(NSSet *)patterns completionHandler:(void (^)(NSSet *, NSError *))h {
    [self _isim_detect:patterns set:[NSIndexSet indexSetWithIndex:0] done:^(NSArray *per) { h([NSSet setWithArray:[per.firstObject allKeys] ?: @[]], nil); }];
}
- (void)detectPatternsForPatterns:(NSSet *)patterns inItemSet:(NSIndexSet *)set completionHandler:(void (^)(NSArray *, NSError *))h {
    [self _isim_detect:patterns set:set done:^(NSArray *per) {
        NSMutableArray *a = [NSMutableArray array];
        for (NSDictionary *d in per) [a addObject:[NSSet setWithArray:d.allKeys]];
        h(a, nil);
    }];
}
/* values: the three iOS 14 patterns (the iOS 15 ones are DataDetection matches on iOS; isim reports their patterns only) */
static NSDictionary *values_only(NSDictionary *d) {
    NSMutableDictionary *v = [NSMutableDictionary dictionary];
    for (NSString *k in @[UIPasteboardDetectionPatternProbableWebURL, UIPasteboardDetectionPatternProbableWebSearch, UIPasteboardDetectionPatternNumber]) if (d[k]) v[k] = d[k];
    return v;
}
- (void)detectValuesForPatterns:(NSSet *)patterns completionHandler:(void (^)(NSDictionary *, NSError *))h {
    [self _isim_detect:patterns set:[NSIndexSet indexSetWithIndex:0] done:^(NSArray *per) { h(values_only(per.firstObject ?: @{}), nil); }];
}
- (void)detectValuesForPatterns:(NSSet *)patterns inItemSet:(NSIndexSet *)set completionHandler:(void (^)(NSArray *, NSError *))h {
    [self _isim_detect:patterns set:set done:^(NSArray *per) {
        NSMutableArray *a = [NSMutableArray array];
        for (NSDictionary *d in per) [a addObject:values_only(d)];
        h(a, nil);
    }];
}
@end
