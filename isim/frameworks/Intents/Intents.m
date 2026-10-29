/* isim Intents (SiriKit): the value classes, intents, responses, resolution results, authorization, donations and
 * voice shortcuts (ARC). The conversation itself (resolve / confirm / handle) is INSiriRunner.m.
 *
 * Every value class keeps its properties in a dictionary (NSObject (INValues), VALUE_CLASS), which gives them copying, equality, secure
 * coding and a property-list form (_isim_plist) used between the simulated Siri (the home screen), Intents extensions
 * and apps. */
#import <Intents/Intents.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdlib.h>

NSString *isim_data_dir(void);

/* ---------------- the property-list form ---------------- */
static id in_encode(id v);
static id in_decode(id v);
static NSSet *in_plist_classes(void);
@interface NSObject (INPlist)
- (NSDictionary *)_isim_plist;
+ (id)_isim_fromPlist:(NSDictionary *)p;
@end

/* the properties of a value object (an associated dictionary: the classes keep Apple's NSObject superclass) */
static char kValues;
@interface NSObject (INValues)
- (NSMutableDictionary *)_in_values;
- (id)_get:(NSString *)k;
- (NSInteger)_int:(NSString *)k;
- (void)_set:(id)v forKey:(NSString *)k;
@end
@implementation NSObject (INValues)
- (NSMutableDictionary *)_in_values {
    NSMutableDictionary *d = objc_getAssociatedObject(self, &kValues);
    if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(self, &kValues, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return d;
}
- (id)_get:(NSString *)k { id v = self._in_values[k]; return v == NSNull.null ? nil : v; }
- (NSInteger)_int:(NSString *)k { return [self._in_values[k] integerValue]; }
- (void)_set:(id)v forKey:(NSString *)k { if (v) self._in_values[k] = v; else [self._in_values removeObjectForKey:k]; }
@end
static NSDictionary *values_plist(id self) {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithObject:NSStringFromClass([self class]) forKey:@"$class"];
    NSDictionary *v = [self _in_values];
    for (NSString *k in v) { id e = in_encode(v[k]); if (e) p[k] = e; }
    return p;
}
static id values_from_plist(Class cls, NSDictionary *p) {
    id o = [[cls alloc] init];
    for (NSString *k in p) if (![k hasPrefix:@"$"]) { id x = in_decode(p[k]); if (x) [o _in_values][k] = x; }
    return o;
}
/* copying, equality, secure coding and the plist form of a value class */
#define VALUE_CLASS \
- (id)copyWithZone:(NSZone *)zone { id c = [[[self class] alloc] init]; [[c _in_values] setDictionary:self._in_values]; return c; } \
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[self class]] && [[o _in_values] isEqual:self._in_values]); } \
- (NSUInteger)hash { return self._in_values.count; } \
+ (BOOL)supportsSecureCoding { return YES; } \
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:[self _isim_plist] forKey:@"isim"]; } \
- (instancetype)initWithCoder:(NSCoder *)c { \
    if ((self = [self init])) { NSDictionary *p = [c decodeObjectOfClasses:in_plist_classes() forKey:@"isim"]; for (NSString *k in p) if (![k hasPrefix:@"$"]) { id x = in_decode(p[k]); if (x) self._in_values[k] = x; } } \
    return self; \
} \
- (NSDictionary *)_isim_plist { return values_plist(self); } \
+ (instancetype)_isim_fromPlist:(NSDictionary *)p { return values_from_plist(self, p); } \
- (NSString *)description { return [NSString stringWithFormat:@"<%@ %@>", NSStringFromClass([self class]), self._in_values]; }

/* what the property-list form is made of (secure decoding) */
static NSSet *in_plist_classes(void) {
    static NSSet *s;
    if (!s) s = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSDate class], [NSData class], nil];
    return s;
}
static id in_encode(id v) {
    if (!v || v == NSNull.null) return nil;
    if ([v isKindOfClass:[NSDecimalNumber class]]) return @{ @"$class": @"NSDecimalNumber", @"value": [v stringValue] };
    /* CoreLocation's places and locations (the rides and photos domains): their plist forms (CoreLocation/ObjC.swift) */
    if ([v respondsToSelector:NSSelectorFromString(@"_isim_placemarkPlist")]) return ((id (*)(id, SEL))objc_msgSend)(v, NSSelectorFromString(@"_isim_placemarkPlist"));
    if ([v respondsToSelector:NSSelectorFromString(@"_isim_locationPlist")]) return ((id (*)(id, SEL))objc_msgSend)(v, NSSelectorFromString(@"_isim_locationPlist"));
    if ([NSStringFromClass([v class]) hasPrefix:@"CL"] && [v respondsToSelector:NSSelectorFromString(@"identifier")]) {   /* a CLRegion: kept for the record */
        NSMutableDictionary *d = [@{ @"$class": @"CLRegion", @"identifier": [v valueForKey:@"identifier"] ?: @"" } mutableCopy];
        if ([v respondsToSelector:NSSelectorFromString(@"radius")]) d[@"radius"] = [v valueForKey:@"radius"];
        return d;
    }
    if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSDate class]] || [v isKindOfClass:[NSData class]]) return v;
    if ([v isKindOfClass:[NSArray class]]) { NSMutableArray *a = [NSMutableArray array]; for (id e in v) { id x = in_encode(e); if (x) [a addObject:x]; } return a; }
    if ([v isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:@"NSDictionary" forKey:@"$class"];
        for (id k in v) { id x = in_encode(v[k]); if (x && [k isKindOfClass:[NSString class]]) d[k] = x; }
        return d;
    }
    if ([v isKindOfClass:[NSUUID class]]) return @{ @"$class": @"NSUUID", @"uuid": [v UUIDString] };
    if ([v isKindOfClass:[NSURL class]]) return @{ @"$class": @"NSURL", @"url": [v absoluteString] };
    if ([v isKindOfClass:[NSPersonNameComponents class]]) {
        NSPersonNameComponents *n = v; NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:@"NSPersonNameComponents" forKey:@"$class"];
        if (n.givenName) d[@"givenName"] = n.givenName; if (n.familyName) d[@"familyName"] = n.familyName;
        if (n.middleName) d[@"middleName"] = n.middleName; if (n.nickname) d[@"nickname"] = n.nickname;
        if (n.namePrefix) d[@"namePrefix"] = n.namePrefix; if (n.nameSuffix) d[@"nameSuffix"] = n.nameSuffix;
        return d;
    }
    if ([v isKindOfClass:[NSDateComponents class]]) {
        NSDateComponents *c = v; NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject:@"NSDateComponents" forKey:@"$class"];
        NSInteger u = NSDateComponentUndefined;
        if (c.year != u) d[@"year"] = @(c.year); if (c.month != u) d[@"month"] = @(c.month); if (c.day != u) d[@"day"] = @(c.day);
        if (c.hour != u) d[@"hour"] = @(c.hour); if (c.minute != u) d[@"minute"] = @(c.minute); if (c.second != u) d[@"second"] = @(c.second);
        return d;
    }
    if ([v isKindOfClass:[NSUserActivity class]]) return @{ @"$class": @"NSUserActivity", @"activity": [v _isim_plist] };
    if ([v respondsToSelector:@selector(_isim_plist)]) return [v _isim_plist];
    return [v description];
}
static id in_decode(id v) {
    if ([v isKindOfClass:[NSArray class]]) { NSMutableArray *a = [NSMutableArray array]; for (id e in v) { id x = in_decode(e); if (x) [a addObject:x]; } return a; }
    if (![v isKindOfClass:[NSDictionary class]]) return v;
    NSString *cls = v[@"$class"];
    if ([cls isEqualToString:@"NSDictionary"]) { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSString *k in v) if (![k isEqualToString:@"$class"]) d[k] = in_decode(v[k]); return d; }
    if ([cls isEqualToString:@"NSUUID"]) return [[NSUUID alloc] initWithUUIDString:v[@"uuid"]];
    if ([cls isEqualToString:@"NSDecimalNumber"]) return [NSDecimalNumber decimalNumberWithString:v[@"value"] ?: @"0"];
    if ([cls isEqualToString:@"NSURL"]) return [NSURL URLWithString:v[@"url"]];
    if ([cls isEqualToString:@"CLPlacemark"] || [cls isEqualToString:@"CLLocation"]) {     /* nil without CoreLocation */
        Class c = NSClassFromString(cls);
        SEL named = NSSelectorFromString(@"_isim_placemarkNamed:"), withPlist = NSSelectorFromString([cls isEqualToString:@"CLPlacemark"] ? @"_isim_placemarkWithPlist:" : @"_isim_locationWithPlist:");
        if ([cls isEqualToString:@"CLPlacemark"] && !v[@"latitude"] && [v[@"name"] length] && [c respondsToSelector:named])   /* a place Siri heard: looked up */
            return ((id (*)(id, SEL, id))objc_msgSend)(c, named, v[@"name"]);
        return [c respondsToSelector:withPlist] ? ((id (*)(id, SEL, id))objc_msgSend)(c, withPlist, v) : nil;
    }
    if ([cls isEqualToString:@"NSUserActivity"]) return [NSUserActivity _isim_activityWithPlist:v[@"activity"]];
    if ([cls isEqualToString:@"NSPersonNameComponents"]) {
        NSPersonNameComponents *n = [NSPersonNameComponents new];
        n.givenName = v[@"givenName"]; n.familyName = v[@"familyName"]; n.middleName = v[@"middleName"]; n.nickname = v[@"nickname"];
        n.namePrefix = v[@"namePrefix"]; n.nameSuffix = v[@"nameSuffix"];
        return n;
    }
    if ([cls isEqualToString:@"NSDateComponents"]) {
        NSDateComponents *c = [NSDateComponents new];
        if (v[@"year"]) c.year = [v[@"year"] integerValue]; if (v[@"month"]) c.month = [v[@"month"] integerValue]; if (v[@"day"]) c.day = [v[@"day"] integerValue];
        if (v[@"hour"]) c.hour = [v[@"hour"] integerValue]; if (v[@"minute"]) c.minute = [v[@"minute"] integerValue]; if (v[@"second"]) c.second = [v[@"second"] integerValue];
        return c;
    }
    Class c = cls ? NSClassFromString(cls) : nil;
    if (c && [c respondsToSelector:@selector(_isim_fromPlist:)]) return [c _isim_fromPlist:v];
    if (!cls) { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSString *k in v) d[k] = in_decode(v[k]); return d; }
    return nil;
}
id isim_in_encode(id v) { return in_encode(v); }
id isim_in_decode(id v) { return in_decode(v); }

#define OBJ(type, name) - (type)name { return [self _get:@#name]; }
#define INT(type, name) - (type)name { return (type)[self _int:@#name]; }
#define SET(k, v) [self _set:(v) forKey:@k]
#define SETI(k, v) [self _set:@(v) forKey:@k]

/* ---------------- authorization ---------------- */
static NSString *app_display_name(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"App";
}
@interface UIAlertController (ISIMSystemAlert)
- (void)_isim_markSystemAlert;
@end
@implementation INPreferences
+ (INSiriAuthorizationStatus)siriAuthorizationStatus {
    id v = [NSUserDefaults.standardUserDefaults objectForKey:@"_ISIMPrivacy.siri"];
    return v ? (INSiriAuthorizationStatus)[v integerValue] : INSiriAuthorizationStatusNotDetermined;
}
+ (NSString *)siriLanguageCode { return [[NSLocale preferredLanguages].firstObject ?: @"en-US" copy]; }
+ (UIViewController *)_topController {
    UIWindow *key = nil;
    for (UIWindow *w in UIApplication.sharedApplication.windows) if (w.isKeyWindow) key = w;
    UIViewController *vc = (key ?: UIApplication.sharedApplication.windows.firstObject).rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}
+ (void)requestSiriAuthorization:(void (^)(INSiriAuthorizationStatus))handler {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    void (^reply)(INSiriAuthorizationStatus) = ^(INSiriAuthorizationStatus s) { dispatch_async(dispatch_get_main_queue(), ^{ if (handler) handler(s); }); };
    id stored = [ud objectForKey:@"_ISIMPrivacy.siri"];
    if (stored) { reply((INSiriAuthorizationStatus)[stored integerValue]); return; }
    NSString *purpose = NSBundle.mainBundle.infoDictionary[@"NSSiriUsageDescription"];
    if (!purpose.length) {
        NSLog(@"isim Intents: this app has attempted to access privacy-sensitive data without a usage description. The app's Info.plist must contain an NSSiriUsageDescription key with a string value explaining to the user how the app uses this data (iOS would terminate the app; isim reports the access as denied)");
        reply(INSiriAuthorizationStatusDenied); return;
    }
    void (^answer)(BOOL) = ^(BOOL ok) {
        INSiriAuthorizationStatus s = ok ? INSiriAuthorizationStatusAuthorized : INSiriAuthorizationStatusDenied;
        [ud setInteger:s forKey:@"_ISIMPrivacy.siri"]; [ud synchronize];
        NSLog(@"isim Intents: Siri %@ for %@", ok ? @"allowed" : @"denied", app_display_name());
        reply(s);
    };
    const char *env = getenv("ISIM_SIRI_PERMISSION");
    if (env && *env) { NSString *e = @(env).lowercaseString; answer(!([e isEqualToString:@"deny"] || [e isEqualToString:@"denied"] || [e isEqualToString:@"no"] || [e isEqualToString:@"0"])); return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        const char *osv = getenv("ISIM_OS_VERSION");
        UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"“%@” Would Like to Use Siri", app_display_name()]
                                                                   message:purpose preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Don’t Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer(NO); }]];
        [a addAction:[UIAlertAction actionWithTitle:(osv && atoi(osv) < 17) ? @"OK" : @"Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { answer(YES); }]];
        if ([a respondsToSelector:@selector(_isim_markSystemAlert)]) [a _isim_markSystemAlert];
        UIViewController *top = [self _topController];
        if (!top) { NSLog(@"isim Intents: no window to ask for Siri access"); answer(NO); return; }
        NSLog(@"isim Intents: asking for Siri access");
        [top presentViewController:a animated:YES completion:nil];
    });
}
@end

/* ---------------- vocabulary ---------------- */
static NSString *library_isim(NSString *file);
@implementation INVocabulary
+ (instancetype)sharedVocabulary { static INVocabulary *v; static dispatch_once_t once; dispatch_once(&once, ^{ v = [self new]; }); return v; }
- (void)_store:(NSArray *)entries ofType:(INVocabularyStringType)type {
    NSString *f = library_isim(@"Vocabulary.plist");
    NSMutableDictionary *all = [[NSDictionary dictionaryWithContentsOfFile:f][@"types"] mutableCopy] ?: [NSMutableDictionary dictionary];
    all[[NSString stringWithFormat:@"%ld", (long)type]] = entries;
    [@{ @"types": all } writeToFile:f atomically:YES];
    NSLog(@"isim Intents: %lu vocabulary string(s) of type %ld", (unsigned long)entries.count, (long)type);
}
- (void)setVocabularyStrings:(NSOrderedSet<NSString *> *)vocabulary ofType:(INVocabularyStringType)type {
    NSMutableArray *a = [NSMutableArray array];
    for (id x in vocabulary) if ([x isKindOfClass:[NSString class]]) [a addObject:@{ @"spokenPhrase": x }];
    [self _store:a ofType:type];
}
- (void)setVocabulary:(NSOrderedSet<id<INSpeakable>> *)vocabulary ofType:(INVocabularyStringType)type {
    NSMutableArray *a = [NSMutableArray array];
    for (id<INSpeakable> x in vocabulary) {
        if (![x respondsToSelector:@selector(spokenPhrase)]) continue;
        NSMutableDictionary *e = [@{ @"spokenPhrase": x.spokenPhrase ?: @"" } mutableCopy];
        if (x.vocabularyIdentifier ?: x.identifier) e[@"identifier"] = x.vocabularyIdentifier ?: x.identifier;
        if (x.pronunciationHint) e[@"pronunciationHint"] = x.pronunciationHint;
        NSMutableArray *alt = [NSMutableArray array];
        for (id<INSpeakable> m in x.alternativeSpeakableMatches) if (m.spokenPhrase) [alt addObject:m.spokenPhrase];
        if (alt.count) e[@"alternatives"] = alt;
        [a addObject:e];
    }
    [self _store:a ofType:type];
}
- (void)removeAllVocabularyStrings {
    [NSFileManager.defaultManager removeItemAtPath:library_isim(@"Vocabulary.plist") error:NULL];
    NSLog(@"isim Intents: removed the vocabulary");
}
@end

/* ---------------- shared types ---------------- */
@implementation INImage
VALUE_CLASS
+ (instancetype)imageNamed:(NSString *)name { INImage *i = [self new]; [i _set:name ?: @"" forKey:@"name"]; return i; }
+ (instancetype)systemImageNamed:(NSString *)n { INImage *i = [self new]; [i _set:n forKey:@"systemName"]; return i; }
+ (instancetype)imageWithImageData:(NSData *)d { INImage *i = [self new]; [i _set:d forKey:@"data"]; return i; }
+ (instancetype)imageWithURL:(NSURL *)u { if (!u) return nil; INImage *i = [self new]; [i _set:u.absoluteString forKey:@"url"]; return i; }
+ (instancetype)imageWithUIImage:(UIImage *)img { return [self imageWithImageData:UIImagePNGRepresentation(img) ?: [NSData data]]; }
@end

@implementation INSpeakableString
VALUE_CLASS
- (instancetype)initWithVocabularyIdentifier:(NSString *)vid spokenPhrase:(NSString *)p pronunciationHint:(NSString *)h {
    if ((self = [self init])) { SET("vocabularyIdentifier", vid); SET("identifier", vid); SET("spokenPhrase", p ?: @""); SET("pronunciationHint", h); }
    return self;
}
- (instancetype)initWithIdentifier:(NSString *)i spokenPhrase:(NSString *)p pronunciationHint:(NSString *)h { return [self initWithVocabularyIdentifier:i spokenPhrase:p pronunciationHint:h]; }
- (instancetype)initWithSpokenPhrase:(NSString *)p { if ((self = [self init])) SET("spokenPhrase", p ?: @""); return self; }
OBJ(NSString *, vocabularyIdentifier) OBJ(NSString *, identifier) OBJ(NSString *, pronunciationHint)
- (NSString *)spokenPhrase { return [self _get:@"spokenPhrase"] ?: @""; }
- (NSArray *)alternativeSpeakableMatches { return nil; }
@end

@implementation INPersonHandle
VALUE_CLASS
- (instancetype)initWithValue:(NSString *)value type:(INPersonHandleType)type { return [self initWithValue:value type:type label:nil]; }
- (instancetype)initWithValue:(NSString *)value type:(INPersonHandleType)type label:(INPersonHandleLabel)label {
    if ((self = [self init])) { SET("value", value); SETI("type", type); SET("label", label); }
    return self;
}
OBJ(NSString *, value) INT(INPersonHandleType, type) OBJ(INPersonHandleLabel, label)
@end

@implementation INPerson
VALUE_CLASS
- (instancetype)initWithPersonHandle:(INPersonHandle *)h nameComponents:(NSPersonNameComponents *)n displayName:(NSString *)d image:(INImage *)i contactIdentifier:(NSString *)c customIdentifier:(NSString *)u {
    return [self initWithPersonHandle:h nameComponents:n displayName:d image:i contactIdentifier:c customIdentifier:u aliases:nil suggestionType:INPersonSuggestionTypeNone];
}
- (instancetype)initWithPersonHandle:(INPersonHandle *)h nameComponents:(NSPersonNameComponents *)n displayName:(NSString *)d image:(INImage *)i contactIdentifier:(NSString *)c customIdentifier:(NSString *)u isMe:(BOOL)me {
    if ((self = [self initWithPersonHandle:h nameComponents:n displayName:d image:i contactIdentifier:c customIdentifier:u])) SETI("isMe", me);
    return self;
}
- (instancetype)initWithPersonHandle:(INPersonHandle *)h nameComponents:(NSPersonNameComponents *)n displayName:(NSString *)d image:(INImage *)i contactIdentifier:(NSString *)c customIdentifier:(NSString *)u aliases:(NSArray *)al suggestionType:(INPersonSuggestionType)st {
    if ((self = [self init])) {
        SET("personHandle", h); SET("nameComponents", n); SET("displayName", d); SET("image", i); SET("contactIdentifier", c); SET("customIdentifier", u);
        SET("aliases", al); SETI("suggestionType", st);
    }
    return self;
}
OBJ(INPersonHandle *, personHandle) OBJ(NSPersonNameComponents *, nameComponents) OBJ(INImage *, image) OBJ(NSString *, contactIdentifier)
OBJ(NSString *, customIdentifier) OBJ(NSArray *, aliases) INT(INPersonSuggestionType, suggestionType)
- (BOOL)isMe { return [self _int:@"isMe"] != 0; }
- (NSString *)displayName {
    NSString *d = [self _get:@"displayName"];
    if (d.length) return d;
    NSPersonNameComponents *n = self.nameComponents;
    NSString *full = [[@[n.givenName ?: @"", n.familyName ?: @""] componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    return full.length ? full : self.personHandle.value ?: @"";
}
@end

/* ---------------- custom intents: @NSManaged / @dynamic properties ---------------- */
/* a declared property of a subclass without accessors (Swift @NSManaged, Objective-C @dynamic) is kept with the
   object's values: objects as they are, scalars (enumerations, BOOL, numbers) as NSNumbers */
static id dyn_get_obj(id self, SEL _cmd) { return [self _get:NSStringFromSelector(_cmd)]; }
static long long dyn_get_int(id self, SEL _cmd) { return [[self _get:NSStringFromSelector(_cmd)] longLongValue]; }
static double dyn_get_dbl(id self, SEL _cmd) { return [[self _get:NSStringFromSelector(_cmd)] doubleValue]; }
static BOOL dyn_get_bool(id self, SEL _cmd) { return [[self _get:NSStringFromSelector(_cmd)] boolValue]; }
static NSString *dyn_key(SEL setter) {
    NSString *s = NSStringFromSelector(setter);                    /* setFooBar: -> fooBar */
    s = [s substringWithRange:NSMakeRange(3, s.length - 4)];
    return [[s substringToIndex:1].lowercaseString stringByAppendingString:[s substringFromIndex:1]];
}
static void dyn_set_obj(id self, SEL _cmd, id v) {
    objc_property_t p = class_getProperty([self class], dyn_key(_cmd).UTF8String);
    char *copy = p ? property_copyAttributeValue(p, "C") : NULL;
    if (copy) { free(copy); v = [v copy]; }
    [self _set:v forKey:dyn_key(_cmd)];
}
static void dyn_set_int(id self, SEL _cmd, long long v) { [self _set:@(v) forKey:dyn_key(_cmd)]; }
static void dyn_set_dbl(id self, SEL _cmd, double v) { [self _set:@(v) forKey:dyn_key(_cmd)]; }
static void dyn_set_bool(id self, SEL _cmd, BOOL v) { [self _set:@(v) forKey:dyn_key(_cmd)]; }
static BOOL resolve_dynamic(Class cls, SEL sel) {
    NSString *name = NSStringFromSelector(sel);
    BOOL setter = [name hasPrefix:@"set"] && [name hasSuffix:@":"] && name.length > 4;
    NSString *key = setter ? dyn_key(sel) : name;
    for (Class c = cls; c && c != [NSObject class]; c = class_getSuperclass(c)) {
        objc_property_t p = class_getProperty(c, key.UTF8String);
        if (!p) continue;
        char *t = property_copyAttributeValue(p, "T");
        char k = t ? t[0] : '@';
        free(t);
        IMP imp; const char *types;
        if (k == '@') { imp = setter ? (IMP)dyn_set_obj : (IMP)dyn_get_obj; types = setter ? "v@:@" : "@@:"; }
        else if (k == 'd' || k == 'f') { imp = setter ? (IMP)dyn_set_dbl : (IMP)dyn_get_dbl; types = setter ? "v@:d" : "d@:"; }
        else if (k == 'B' || k == 'c') { imp = setter ? (IMP)dyn_set_bool : (IMP)dyn_get_bool; types = setter ? "v@:B" : "B@:"; }
        else { imp = setter ? (IMP)dyn_set_int : (IMP)dyn_get_int; types = setter ? "v@:q" : "q@:"; }
        return class_addMethod(cls, sel, imp, types);
    }
    return NO;
}
#define DYNAMIC_PROPERTIES \
+ (BOOL)resolveInstanceMethod:(SEL)sel { return resolve_dynamic(self, sel) || [super resolveInstanceMethod:sel]; }

/* ---------------- custom types ---------------- */
@implementation INObject
VALUE_CLASS
DYNAMIC_PROPERTIES
- (instancetype)initWithIdentifier:(NSString *)identifier displayString:(NSString *)displayString pronunciationHint:(NSString *)hint subtitleString:(NSString *)subtitle displayImage:(INImage *)image {
    if ((self = [super init])) { SET("identifier", identifier); SET("displayString", displayString ?: @""); SET("pronunciationHint", hint); SET("subtitleString", subtitle); SET("displayImage", image); }
    return self;
}
- (instancetype)initWithIdentifier:(NSString *)identifier displayString:(NSString *)displayString pronunciationHint:(NSString *)hint {
    return [self initWithIdentifier:identifier displayString:displayString pronunciationHint:hint subtitleString:nil displayImage:nil];
}
- (instancetype)initWithIdentifier:(NSString *)identifier displayString:(NSString *)displayString { return [self initWithIdentifier:identifier displayString:displayString pronunciationHint:nil]; }
- (instancetype)initWithIdentifier:(NSString *)identifier displayString:(NSString *)displayString subtitleString:(NSString *)subtitle displayImage:(INImage *)image {
    return [self initWithIdentifier:identifier displayString:displayString pronunciationHint:nil subtitleString:subtitle displayImage:image];
}
OBJ(NSString *, identifier) OBJ(NSString *, pronunciationHint) OBJ(NSString *, subtitleString) OBJ(INImage *, displayImage) OBJ(NSArray *, alternativeSpeakableMatches)
- (NSString *)displayString { return [self _get:@"displayString"] ?: @""; }
- (void)setSubtitleString:(NSString *)s { SET("subtitleString", [s copy]); }
- (void)setDisplayImage:(INImage *)i { SET("displayImage", [i copy]); }
- (void)setAlternativeSpeakableMatches:(NSArray *)a { SET("alternativeSpeakableMatches", [a copy]); }
- (NSString *)spokenPhrase { return self.displayString; }
- (NSString *)vocabularyIdentifier { return self.identifier; }
@end

@implementation INObjectSection
VALUE_CLASS
- (instancetype)init { return [self initWithTitle:nil items:@[]]; }
- (instancetype)initWithTitle:(NSString *)title items:(NSArray *)items { if ((self = [super init])) { SET("title", title); SET("items", [items copy] ?: @[]); } return self; }
OBJ(NSString *, title)
- (NSArray *)items { return [self _get:@"items"] ?: @[]; }
@end
@implementation INObjectCollection
VALUE_CLASS
- (instancetype)init { return [self initWithSections:@[]]; }
- (instancetype)initWithSections:(NSArray *)sections { if ((self = [super init])) SET("sections", [sections copy] ?: @[]); return self; }
- (instancetype)initWithItems:(NSArray *)items { return [self initWithSections:@[[[INObjectSection alloc] initWithTitle:nil items:items]]]; }
- (NSArray *)sections { return [self _get:@"sections"] ?: @[]; }
- (NSArray *)allItems { NSMutableArray *a = [NSMutableArray array]; for (INObjectSection *s in self.sections) [a addObjectsFromArray:s.items]; return a; }
- (BOOL)usesIndexedCollation { return [self _int:@"usesIndexedCollation"] != 0; }
- (void)setUsesIndexedCollation:(BOOL)u { SETI("usesIndexedCollation", u); }
@end

@implementation INCurrencyAmount
VALUE_CLASS
- (instancetype)initWithAmount:(NSDecimalNumber *)amount currencyCode:(NSString *)code { if ((self = [super init])) { SET("amount", amount); SET("currencyCode", code); } return self; }
OBJ(NSDecimalNumber *, amount) OBJ(NSString *, currencyCode)
@end

/* ---------------- intents ---------------- */
@implementation INIntent
VALUE_CLASS
DYNAMIC_PROPERTIES
- (instancetype)init { if ((self = [super init])) [self _set:NSUUID.UUID.UUIDString forKey:@"identifier"]; return self; }
- (NSString *)identifier { return [self _get:@"identifier"] ?: @""; }
- (NSString *)intentDescription { return [NSString stringWithFormat:@"%@", NSStringFromClass(self.class)]; }
OBJ(NSString *, suggestedInvocationPhrase)
- (void)setSuggestedInvocationPhrase:(NSString *)p { SET("suggestedInvocationPhrase", p); }
+ (INIntent *)_isim_intentWithPlist:(NSDictionary *)p {
    id i = in_decode(p);
    return [i isKindOfClass:[INIntent class]] ? i : nil;
}
@end
@implementation INIntentResponse
VALUE_CLASS
DYNAMIC_PROPERTIES
OBJ(NSUserActivity *, userActivity)
- (void)setUserActivity:(NSUserActivity *)a { SET("userActivity", a); }
@end
#define RESPONSE(cls, codeType) \
@implementation cls \
- (instancetype)initWithCode:(codeType)code userActivity:(NSUserActivity *)a { if ((self = [super init])) { SETI("code", code); SET("userActivity", a); } return self; } \
- (instancetype)init { return [self initWithCode:(codeType)0 userActivity:nil]; } \
INT(codeType, code)
RESPONSE(INSendMessageIntentResponse, INSendMessageIntentResponseCode)
OBJ(INMessage *, sentMessage) OBJ(NSArray *, sentMessages)
- (void)setSentMessage:(INMessage *)m { SET("sentMessage", m); }
- (void)setSentMessages:(NSArray *)m { SET("sentMessages", m); }
@end
RESPONSE(INSearchForMessagesIntentResponse, INSearchForMessagesIntentResponseCode)
OBJ(NSArray *, messages)
- (void)setMessages:(NSArray *)m { SET("messages", m); }
@end
RESPONSE(INStartCallIntentResponse, INStartCallIntentResponseCode)
@end
RESPONSE(INPlayMediaIntentResponse, INPlayMediaIntentResponseCode)
OBJ(NSDictionary *, nowPlayingInfo)
- (void)setNowPlayingInfo:(NSDictionary *)n { SET("nowPlayingInfo", n); }
@end
RESPONSE(INAddTasksIntentResponse, INAddTasksIntentResponseCode)
OBJ(INTaskList *, modifiedTaskList) OBJ(NSArray *, addedTasks)
- (void)setModifiedTaskList:(INTaskList *)l { SET("modifiedTaskList", l); }
- (void)setAddedTasks:(NSArray *)t { SET("addedTasks", t); }
@end
RESPONSE(INEditMessageIntentResponse, INEditMessageIntentResponseCode)
@end
RESPONSE(INUnsendMessagesIntentResponse, INUnsendMessagesIntentResponseCode)
@end
RESPONSE(INAddMediaIntentResponse, INAddMediaIntentResponseCode)
@end
RESPONSE(INSearchForMediaIntentResponse, INSearchForMediaIntentResponseCode)
OBJ(NSArray *, mediaItems)
- (void)setMediaItems:(NSArray *)m { SET("mediaItems", [m copy]); }
@end
RESPONSE(INCreateNoteIntentResponse, INCreateNoteIntentResponseCode)
OBJ(INNote *, createdNote)
- (void)setCreatedNote:(INNote *)n { SET("createdNote", n); }
@end

/* ---------------- resolution results ---------------- */
@interface INIntentResolutionResult () {
@public NSString *_kind; id _value; NSArray *_options; NSInteger _reason;
}
+ (instancetype)_kind:(NSString *)k value:(id)v options:(NSArray *)o;
@end
@implementation INIntentResolutionResult
+ (instancetype)_kind:(NSString *)k value:(id)v options:(NSArray *)o { INIntentResolutionResult *r = [self new]; r->_kind = k; r->_value = v; r->_options = o; return r; }
+ (instancetype)needsValue { return [self _kind:@"needsValue" value:nil options:nil]; }
+ (instancetype)notRequired { return [self _kind:@"notRequired" value:nil options:nil]; }
+ (instancetype)unsupported { return [self _kind:@"unsupported" value:nil options:nil]; }
+ (instancetype)unsupportedWithReason:(NSInteger)reason { INIntentResolutionResult *r = [self unsupported]; r->_reason = reason; return r; }
+ (instancetype)confirmationRequiredWithItemToConfirm:(id)item forReason:(NSInteger)reason { INIntentResolutionResult *r = [self _kind:@"confirmationRequired" value:item options:nil]; r->_reason = reason; return r; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@ %@%@>", NSStringFromClass(self.class), _kind, _value ? [@" " stringByAppendingString:[_value description]] : @""]; }
/* isim-private (INSiriRunner.m) */
- (NSString *)_isim_kind { return _kind; }
- (id)_isim_value { return _value; }
- (NSArray *)_isim_options { return _options; }
- (NSInteger)_isim_reason { return _reason; }
@end
#define RESULT_SUCCESS(sel, type) + (instancetype)sel(type)v { return [self _kind:@"success" value:v options:nil]; }
#define RESULT_DISAMBIG(sel) + (instancetype)sel(NSArray *)o { return [self _kind:@"disambiguation" value:nil options:o]; }
#define RESULT_CONFIRM(sel, type) + (instancetype)sel(type)v { return [self _kind:@"confirmationRequired" value:v options:nil]; }
@implementation INPersonResolutionResult
RESULT_SUCCESS(successWithResolvedPerson:, INPerson *) RESULT_DISAMBIG(disambiguationWithPeopleToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithPersonToConfirm:, INPerson *)
@end
@implementation INStringResolutionResult
RESULT_SUCCESS(successWithResolvedString:, NSString *) RESULT_DISAMBIG(disambiguationWithStringsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithStringToConfirm:, NSString *)
@end
@implementation INSpeakableStringResolutionResult
RESULT_SUCCESS(successWithResolvedString:, INSpeakableString *) RESULT_DISAMBIG(disambiguationWithStringsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithStringToConfirm:, INSpeakableString *)
@end
@implementation INBooleanResolutionResult
+ (instancetype)successWithResolvedValue:(BOOL)v { return [self _kind:@"success" value:@(v) options:nil]; }
RESULT_CONFIRM(confirmationRequiredWithValueToConfirm:, NSNumber *)
@end
@implementation INIntegerResolutionResult
+ (instancetype)successWithResolvedValue:(NSInteger)v { return [self _kind:@"success" value:@(v) options:nil]; }
RESULT_CONFIRM(confirmationRequiredWithValueToConfirm:, NSNumber *)
@end
@implementation INDoubleResolutionResult
+ (instancetype)successWithResolvedValue:(double)v { return [self _kind:@"success" value:@(v) options:nil]; }
RESULT_CONFIRM(confirmationRequiredWithValueToConfirm:, NSNumber *)
@end
@implementation INURLResolutionResult
RESULT_SUCCESS(successWithResolvedURL:, NSURL *) RESULT_DISAMBIG(disambiguationWithURLsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithURLToConfirm:, NSURL *)
@end
@implementation INObjectResolutionResult
RESULT_SUCCESS(successWithResolvedObject:, INObject *) RESULT_DISAMBIG(disambiguationWithObjectsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithObjectToConfirm:, INObject *)
@end
@implementation INEnumResolutionResult
+ (instancetype)successWithResolvedValue:(NSInteger)v { return [self _kind:@"success" value:@(v) options:nil]; }
+ (instancetype)confirmationRequiredWithValueToConfirm:(NSInteger)v { return [self _kind:@"confirmationRequired" value:@(v) options:nil]; }
@end
@implementation INDateComponentsResolutionResult
RESULT_SUCCESS(successWithResolvedDateComponents:, NSDateComponents *) RESULT_DISAMBIG(disambiguationWithDateComponentsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithDateComponentsToConfirm:, NSDateComponents *)
@end
static void copy_result(INIntentResolutionResult *to, INIntentResolutionResult *from) {
    if (!from) return;
    to->_kind = from->_kind; to->_value = from->_value; to->_options = from->_options; to->_reason = from->_reason;
}
@implementation INSendMessageRecipientResolutionResult
+ (instancetype)unsupportedForReason:(INSendMessageRecipientUnsupportedReason)reason { return [self unsupportedWithReason:reason]; }
- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INStartCallContactResolutionResult
+ (instancetype)unsupportedForReason:(INStartCallContactUnsupportedReason)reason { return [self unsupportedWithReason:reason]; }
- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INMediaItemResolutionResult
RESULT_SUCCESS(successWithResolvedMediaItem:, INMediaItem *) RESULT_DISAMBIG(disambiguationWithMediaItemsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithMediaItemToConfirm:, INMediaItem *)
+ (NSArray *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)items {
    NSMutableArray *a = [NSMutableArray array];
    for (INMediaItem *m in items) [a addObject:[self successWithResolvedMediaItem:m]];
    return a;
}
@end
@implementation INPlayMediaMediaItemResolutionResult
+ (NSArray *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)items { return [super successesWithResolvedMediaItems:items]; }
+ (instancetype)unsupportedForReason:(INPlayMediaMediaItemUnsupportedReason)reason { return [self unsupportedWithReason:reason]; }
- (instancetype)initWithMediaItemResolutionResult:(INMediaItemResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INAddMediaMediaItemResolutionResult
+ (NSArray *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)items { return [super successesWithResolvedMediaItems:items]; }
+ (instancetype)unsupportedForReason:(INAddMediaMediaItemUnsupportedReason)reason { return [self unsupportedWithReason:reason]; }
- (instancetype)initWithMediaItemResolutionResult:(INMediaItemResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INSearchForMediaMediaItemResolutionResult
+ (NSArray *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)items { return [super successesWithResolvedMediaItems:items]; }
+ (instancetype)unsupportedForReason:(INSearchForMediaMediaItemUnsupportedReason)reason { return [self unsupportedWithReason:reason]; }
- (instancetype)initWithMediaItemResolutionResult:(INMediaItemResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INMediaDestinationResolutionResult
RESULT_SUCCESS(successWithResolvedMediaDestination:, INMediaDestination *) RESULT_DISAMBIG(disambiguationWithMediaDestinationsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithMediaDestinationToConfirm:, INMediaDestination *)
@end
@implementation INAddMediaMediaDestinationResolutionResult
+ (instancetype)unsupportedForReason:(INAddMediaMediaDestinationUnsupportedReason)reason { return [self unsupportedWithReason:reason]; }
- (instancetype)initWithMediaDestinationResolutionResult:(INMediaDestinationResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INCurrencyAmountResolutionResult
RESULT_SUCCESS(successWithResolvedCurrencyAmount:, INCurrencyAmount *) RESULT_DISAMBIG(disambiguationWithCurrencyAmountsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithCurrencyAmountToConfirm:, INCurrencyAmount *)
@end
@implementation INTaskListResolutionResult
RESULT_SUCCESS(successWithResolvedTaskList:, INTaskList *) RESULT_DISAMBIG(disambiguationWithTaskListsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithTaskListToConfirm:, INTaskList *)
@end
@implementation INAddTasksTargetTaskListResolutionResult
- (instancetype)initWithTaskListResolutionResult:(INTaskListResolutionResult *)r { if ((self = [super init])) copy_result(self, r); return self; }
@end
@implementation INNoteContentResolutionResult
RESULT_SUCCESS(successWithResolvedNoteContent:, INNoteContent *) RESULT_DISAMBIG(disambiguationWithNoteContentsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithNoteContentToConfirm:, INNoteContent *)
@end

/* ---------------- messages ---------------- */
@implementation INMessage
VALUE_CLASS
- (instancetype)initWithIdentifier:(NSString *)i content:(NSString *)c dateSent:(NSDate *)d sender:(INPerson *)s recipients:(NSArray *)r {
    return [self initWithIdentifier:i content:c dateSent:d sender:s recipients:r messageType:INMessageTypeText];
}
- (instancetype)initWithIdentifier:(NSString *)i content:(NSString *)c dateSent:(NSDate *)d sender:(INPerson *)s recipients:(NSArray *)r messageType:(INMessageType)t {
    if ((self = [self init])) { SET("identifier", i); SET("content", c); SET("dateSent", d); SET("sender", s); SET("recipients", r); SETI("messageType", t); }
    return self;
}
- (NSString *)identifier { return [self _get:@"identifier"] ?: @""; }
OBJ(NSString *, conversationIdentifier) OBJ(NSString *, content) OBJ(NSDate *, dateSent) OBJ(INPerson *, sender) OBJ(NSArray *, recipients) INT(INMessageType, messageType)
@end
@implementation INSendMessageIntent
- (instancetype)initWithRecipients:(NSArray *)r outgoingMessageType:(INOutgoingMessageType)t content:(NSString *)c speakableGroupName:(INSpeakableString *)g conversationIdentifier:(NSString *)ci serviceName:(NSString *)sn sender:(INPerson *)s attachments:(NSArray *)a {
    if ((self = [self init])) { SET("recipients", r); SETI("outgoingMessageType", t); SET("content", c); SET("speakableGroupName", g); SET("conversationIdentifier", ci); SET("serviceName", sn); SET("sender", s); }
    return self;
}
- (instancetype)initWithRecipients:(NSArray *)r outgoingMessageType:(INOutgoingMessageType)t content:(NSString *)c speakableGroupName:(INSpeakableString *)g conversationIdentifier:(NSString *)ci serviceName:(NSString *)sn sender:(INPerson *)s {
    return [self initWithRecipients:r outgoingMessageType:t content:c speakableGroupName:g conversationIdentifier:ci serviceName:sn sender:s attachments:nil];
}
OBJ(NSArray *, recipients) INT(INOutgoingMessageType, outgoingMessageType) OBJ(NSString *, content) OBJ(INSpeakableString *, speakableGroupName)
OBJ(NSString *, conversationIdentifier) OBJ(NSString *, serviceName) OBJ(INPerson *, sender)
- (NSString *)intentDescription { return [NSString stringWithFormat:@"Send a message%@", self.recipients.count ? [@" to " stringByAppendingString:[self.recipients.firstObject displayName]] : @""]; }
@end
@implementation INDateComponentsRange
VALUE_CLASS
- (instancetype)initWithStartDateComponents:(NSDateComponents *)s endDateComponents:(NSDateComponents *)e { if ((self = [self init])) { SET("startDateComponents", s); SET("endDateComponents", e); } return self; }
OBJ(NSDateComponents *, startDateComponents) OBJ(NSDateComponents *, endDateComponents)
@end
@implementation INSearchForMessagesIntent
- (instancetype)initWithRecipients:(NSArray *)r senders:(NSArray *)s searchTerms:(NSArray *)t attributes:(INMessageAttributeOptions)a dateTimeRange:(INDateComponentsRange *)d identifiers:(NSArray *)i notificationIdentifiers:(NSArray *)n speakableGroupNames:(NSArray *)g conversationIdentifiers:(NSArray *)c {
    if ((self = [self init])) { SET("recipients", r); SET("senders", s); SET("searchTerms", t); SETI("attributes", a); SET("dateTimeRange", d); SET("identifiers", i); SET("speakableGroupNames", g); SET("conversationIdentifiers", c); }
    return self;
}
OBJ(NSArray *, recipients) OBJ(NSArray *, senders) OBJ(NSArray *, searchTerms) INT(INMessageAttributeOptions, attributes) OBJ(INDateComponentsRange *, dateTimeRange)
OBJ(NSArray *, identifiers) OBJ(NSArray *, speakableGroupNames) OBJ(NSArray *, conversationIdentifiers)
- (NSString *)intentDescription { return @"Search for messages"; }
@end
@implementation INEditMessageIntent
- (instancetype)initWithMessageIdentifier:(NSString *)i editedContent:(NSString *)c { if ((self = [super init])) { SET("messageIdentifier", i); SET("editedContent", c); } return self; }
OBJ(NSString *, messageIdentifier) OBJ(NSString *, editedContent)
- (NSString *)intentDescription { return @"Edit a message"; }
@end
@implementation INUnsendMessagesIntent
- (instancetype)initWithMessageIdentifiers:(NSArray *)ids { if ((self = [super init])) SET("messageIdentifiers", [ids copy]); return self; }
OBJ(NSArray *, messageIdentifiers)
- (NSString *)intentDescription { return @"Unsend messages"; }
@end

/* ---------------- calls ---------------- */
@implementation INSendMessageIntent (UNNotificationContentProviding)
@end
@implementation INStartCallIntent (UNNotificationContentProviding)
@end
@implementation INStartCallIntent
- (instancetype)initWithCallRecordFilter:(id)f callRecordToCallBack:(id)cb audioRoute:(INCallAudioRoute)ar destinationType:(INCallDestinationType)dt contacts:(NSArray *)c callCapability:(INCallCapability)cap {
    if ((self = [self init])) { SETI("audioRoute", ar); SETI("destinationType", dt); SET("contacts", c); SETI("callCapability", cap); }
    return self;
}
- (instancetype)initWithAudioRoute:(INCallAudioRoute)ar destinationType:(INCallDestinationType)dt contacts:(NSArray *)c recordTypeForRedialing:(INCallRecordType)rt callCapability:(INCallCapability)cap {
    return [self initWithCallRecordFilter:nil callRecordToCallBack:nil audioRoute:ar destinationType:dt contacts:c callCapability:cap];
}
INT(INCallAudioRoute, audioRoute) INT(INCallDestinationType, destinationType) OBJ(NSArray *, contacts) INT(INCallCapability, callCapability)
- (NSString *)intentDescription { return [NSString stringWithFormat:@"Call%@", self.contacts.count ? [@" " stringByAppendingString:[self.contacts.firstObject displayName]] : @""]; }
@end

/* ---------------- media ---------------- */
@implementation INMediaItem
VALUE_CLASS
- (instancetype)initWithIdentifier:(NSString *)i title:(NSString *)t type:(INMediaItemType)ty artwork:(INImage *)a { return [self initWithIdentifier:i title:t type:ty artwork:a artist:nil]; }
- (instancetype)initWithIdentifier:(NSString *)i title:(NSString *)t type:(INMediaItemType)ty artwork:(INImage *)a artist:(NSString *)ar {
    if ((self = [self init])) { SET("identifier", i); SET("title", t); SETI("type", ty); SET("artwork", a); SET("artist", ar); }
    return self;
}
OBJ(NSString *, identifier) OBJ(NSString *, title) INT(INMediaItemType, type) OBJ(INImage *, artwork) OBJ(NSString *, artist)
@end
@implementation INMediaSearch
VALUE_CLASS
- (instancetype)initWithMediaType:(INMediaItemType)mt sortOrder:(INMediaSortOrder)so mediaName:(NSString *)mn artistName:(NSString *)an albumName:(NSString *)al genreNames:(NSArray *)g moodNames:(NSArray *)m releaseDate:(INDateComponentsRange *)rd reference:(INMediaReference)ref mediaIdentifier:(NSString *)mi {
    if ((self = [self init])) { SETI("mediaType", mt); SETI("sortOrder", so); SET("mediaName", mn); SET("artistName", an); SET("albumName", al); SET("genreNames", g); SET("moodNames", m); SETI("reference", ref); SET("mediaIdentifier", mi); }
    return self;
}
INT(INMediaItemType, mediaType) INT(INMediaSortOrder, sortOrder) INT(INMediaReference, reference) OBJ(NSString *, mediaName) OBJ(NSString *, artistName) OBJ(NSString *, albumName)
OBJ(NSArray *, genreNames) OBJ(NSArray *, moodNames) OBJ(NSString *, mediaIdentifier)
@end
@implementation INPlayMediaIntent
- (instancetype)initWithMediaItems:(NSArray *)items mediaContainer:(INMediaItem *)c playShuffled:(NSNumber *)sh playbackRepeatMode:(INPlaybackRepeatMode)rm resumePlayback:(NSNumber *)rp playbackQueueLocation:(INPlaybackQueueLocation)ql playbackSpeed:(NSNumber *)sp mediaSearch:(INMediaSearch *)ms {
    if ((self = [self init])) { SET("mediaItems", items); SET("mediaContainer", c); SET("playShuffled", sh); SETI("playbackRepeatMode", rm); SET("resumePlayback", rp); SETI("playbackQueueLocation", ql); SET("playbackSpeed", sp); SET("mediaSearch", ms); }
    return self;
}
OBJ(NSArray *, mediaItems) OBJ(INMediaItem *, mediaContainer) OBJ(NSNumber *, playShuffled) INT(INPlaybackRepeatMode, playbackRepeatMode) OBJ(NSNumber *, resumePlayback)
INT(INPlaybackQueueLocation, playbackQueueLocation) OBJ(NSNumber *, playbackSpeed) OBJ(INMediaSearch *, mediaSearch)
- (NSString *)intentDescription { return @"Play media"; }
@end
@implementation INMediaDestination
VALUE_CLASS
+ (instancetype)libraryDestination { INMediaDestination *d = [self new]; [d _set:@(INMediaDestinationTypeLibrary) forKey:@"mediaDestinationType"]; return d; }
+ (instancetype)playlistDestinationWithName:(NSString *)n {
    INMediaDestination *d = [self new]; [d _set:@(INMediaDestinationTypePlaylist) forKey:@"mediaDestinationType"]; [d _set:[n copy] ?: @"" forKey:@"playlistName"]; return d;
}
INT(INMediaDestinationType, mediaDestinationType) OBJ(NSString *, playlistName)
@end
@implementation INAddMediaIntent
- (instancetype)initWithMediaItems:(NSArray *)items mediaSearch:(INMediaSearch *)search mediaDestination:(INMediaDestination *)dest {
    if ((self = [super init])) { SET("mediaItems", [items copy]); SET("mediaSearch", [search copy]); SET("mediaDestination", [dest copy]); }
    return self;
}
OBJ(NSArray *, mediaItems) OBJ(INMediaSearch *, mediaSearch) OBJ(INMediaDestination *, mediaDestination)
- (NSString *)intentDescription { return @"Add media"; }
@end
@implementation INSearchForMediaIntent
- (instancetype)initWithMediaItems:(NSArray *)items mediaSearch:(INMediaSearch *)search { if ((self = [super init])) { SET("mediaItems", [items copy]); SET("mediaSearch", [search copy]); } return self; }
OBJ(NSArray *, mediaItems) OBJ(INMediaSearch *, mediaSearch)
- (NSString *)intentDescription { return @"Search for media"; }
@end

/* ---------------- lists and notes ---------------- */
@implementation INTask
VALUE_CLASS
- (instancetype)initWithTitle:(INSpeakableString *)t status:(INTaskStatus)s taskType:(INTaskType)ty spatialEventTrigger:(id)se temporalEventTrigger:(id)te createdDateComponents:(NSDateComponents *)c modifiedDateComponents:(NSDateComponents *)m identifier:(NSString *)i {
    return [self initWithTitle:t status:s taskType:ty spatialEventTrigger:se temporalEventTrigger:te createdDateComponents:c modifiedDateComponents:m identifier:i priority:INTaskPriorityUnknown];
}
- (instancetype)initWithTitle:(INSpeakableString *)t status:(INTaskStatus)s taskType:(INTaskType)ty spatialEventTrigger:(id)se temporalEventTrigger:(id)te createdDateComponents:(NSDateComponents *)c modifiedDateComponents:(NSDateComponents *)m identifier:(NSString *)i priority:(INTaskPriority)p {
    if ((self = [self init])) { SET("title", t); SETI("status", s); SETI("taskType", ty); SET("createdDateComponents", c); SET("modifiedDateComponents", m); SET("identifier", i); SETI("priority", p); }
    return self;
}
- (INSpeakableString *)title { return [self _get:@"title"] ?: [[INSpeakableString alloc] initWithSpokenPhrase:@""]; }
INT(INTaskStatus, status) INT(INTaskType, taskType) INT(INTaskPriority, priority) OBJ(NSDateComponents *, createdDateComponents) OBJ(NSDateComponents *, modifiedDateComponents) OBJ(NSString *, identifier)
@end
@implementation INTaskList
VALUE_CLASS
- (instancetype)initWithTitle:(INSpeakableString *)t tasks:(NSArray *)tasks groupName:(INSpeakableString *)g createdDateComponents:(NSDateComponents *)c modifiedDateComponents:(NSDateComponents *)m identifier:(NSString *)i {
    if ((self = [self init])) { SET("title", t); SET("tasks", tasks ?: @[]); SET("groupName", g); SET("createdDateComponents", c); SET("modifiedDateComponents", m); SET("identifier", i); }
    return self;
}
- (INSpeakableString *)title { return [self _get:@"title"] ?: [[INSpeakableString alloc] initWithSpokenPhrase:@""]; }
- (NSArray *)tasks { return [self _get:@"tasks"] ?: @[]; }
OBJ(INSpeakableString *, groupName) OBJ(NSDateComponents *, createdDateComponents) OBJ(NSDateComponents *, modifiedDateComponents) OBJ(NSString *, identifier)
@end
@implementation INAddTasksIntent
- (instancetype)initWithTargetTaskList:(INTaskList *)l taskTitles:(NSArray *)t spatialEventTrigger:(id)s temporalEventTrigger:(id)te priority:(INTaskPriority)p {
    if ((self = [self init])) { SET("targetTaskList", l); SET("taskTitles", t); SETI("priority", p); }
    return self;
}
- (instancetype)initWithTargetTaskList:(INTaskList *)l taskTitles:(NSArray *)t spatialEventTrigger:(id)s temporalEventTrigger:(id)te {
    return [self initWithTargetTaskList:l taskTitles:t spatialEventTrigger:s temporalEventTrigger:te priority:INTaskPriorityUnknown];
}
OBJ(INTaskList *, targetTaskList) OBJ(NSArray *, taskTitles) INT(INTaskPriority, priority)
- (NSString *)intentDescription { return @"Add tasks"; }
@end
@implementation INNoteContent
VALUE_CLASS
@end
@implementation INTextNoteContent
- (instancetype)initWithText:(NSString *)t { if ((self = [self init])) SET("text", t); return self; }
OBJ(NSString *, text)
@end
@implementation INNote
VALUE_CLASS
- (instancetype)initWithTitle:(INSpeakableString *)t contents:(NSArray *)c groupName:(INSpeakableString *)g createdDateComponents:(NSDateComponents *)cd modifiedDateComponents:(NSDateComponents *)md identifier:(NSString *)i {
    if ((self = [self init])) { SET("title", t); SET("contents", c ?: @[]); SET("groupName", g); SET("createdDateComponents", cd); SET("modifiedDateComponents", md); SET("identifier", i); }
    return self;
}
- (INSpeakableString *)title { return [self _get:@"title"] ?: [[INSpeakableString alloc] initWithSpokenPhrase:@""]; }
- (NSArray *)contents { return [self _get:@"contents"] ?: @[]; }
OBJ(INSpeakableString *, groupName) OBJ(NSDateComponents *, createdDateComponents) OBJ(NSDateComponents *, modifiedDateComponents) OBJ(NSString *, identifier)
@end
@implementation INCreateNoteIntent
- (instancetype)initWithTitle:(INSpeakableString *)t content:(INNoteContent *)c groupName:(INSpeakableString *)g {
    if ((self = [self init])) { SET("title", t); SET("content", c); SET("groupName", g); }
    return self;
}
OBJ(INSpeakableString *, title) OBJ(INNoteContent *, content) OBJ(INSpeakableString *, groupName)
- (NSString *)intentDescription { return @"Create a note"; }
@end

/* ---------------- payments, rides, workouts and photos (issue #411) ---------------- */
/* a read-write property kept with the values: copied objects, retained objects, scalars */
#define PROP(type, name, Name) OBJ(type, name) - (void)set##Name:(type)v { SET(#name, [(id)v copy]); }
#define PROPS(type, name, Name) OBJ(type, name) - (void)set##Name:(type)v { SET(#name, v); }
#define PROPI(type, name, Name) INT(type, name) - (void)set##Name:(type)v { SETI(#name, v); }
#define INTENT_ID(cls) NSString *const cls##Identifier = @#cls;
INTENT_ID(INSendPaymentIntent) INTENT_ID(INRequestPaymentIntent)
INTENT_ID(INListRideOptionsIntent) INTENT_ID(INRequestRideIntent) INTENT_ID(INGetRideStatusIntent)
INTENT_ID(INStartWorkoutIntent) INTENT_ID(INPauseWorkoutIntent) INTENT_ID(INResumeWorkoutIntent) INTENT_ID(INEndWorkoutIntent) INTENT_ID(INCancelWorkoutIntent)
INTENT_ID(INSearchForPhotosIntent) INTENT_ID(INStartPhotoPlaybackIntent)
#define WORKOUT_NAME(n, v) INWorkoutNameIdentifier const INWorkoutNameIdentifier##n = @v;
WORKOUT_NAME(Run, "Run") WORKOUT_NAME(Sit, "Sit") WORKOUT_NAME(Steps, "Steps") WORKOUT_NAME(Stand, "Stand") WORKOUT_NAME(Move, "Move")
WORKOUT_NAME(Walk, "Walk") WORKOUT_NAME(Yoga, "Yoga") WORKOUT_NAME(Dance, "Dance") WORKOUT_NAME(Crosstraining, "Crosstraining")
WORKOUT_NAME(Elliptical, "Elliptical") WORKOUT_NAME(Rower, "Rower") WORKOUT_NAME(Cycle, "Cycle") WORKOUT_NAME(Stairs, "Stairs")
WORKOUT_NAME(Other, "Other") WORKOUT_NAME(Indoorrun, "Indoorrun") WORKOUT_NAME(Indoorcycle, "Indoorcycle") WORKOUT_NAME(Indoorwalk, "Indoorwalk")
WORKOUT_NAME(Exercise, "Exercise") WORKOUT_NAME(Hike, "Hike") WORKOUT_NAME(HighIntensityIntervalTraining, "HighIntensityIntervalTraining") WORKOUT_NAME(Swim, "Swim")

/* what a response code means in each of these domains (the runner's outcomes, INInteraction.intentHandlingStatus):
   success | ready | inProgress | continueInApp | handleInApp | appLaunch | failure | unspecified; nil for other classes */
NSString *isim_in_code_meaning(NSString *cls, NSInteger code) {
    static NSDictionary *t;
    if (!t) {
        NSArray *pay = @[@"unspecified", @"ready", @"inProgress", @"success", @"failure", @"appLaunch"];           /* then failures */
        NSArray *ride = @[@"unspecified", @"ready", @"inProgress", @"success", @"failure", @"appLaunch", @"appLaunch", @"appLaunch", @"appLaunch", @"appLaunch", @"appLaunch"];
        NSArray *list = @[@"unspecified", @"ready", @"inProgress", @"success", @"failure", @"appLaunch", @"appLaunch", @"appLaunch", @"appLaunch", @"appLaunch", @"failure"];
        NSArray *cancel = @[@"unspecified", @"ready", @"success", @"failure"];
        NSArray *control = @[@"unspecified", @"ready", @"continueInApp", @"failure", @"appLaunch", @"failure", @"handleInApp", @"success"];
        NSArray *photos = @[@"unspecified", @"ready", @"continueInApp", @"failure", @"appLaunch", @"failure"];
        t = @{ @"INSendPaymentIntent": pay, @"INRequestPaymentIntent": pay,
               @"INRequestRideIntent": ride, @"INGetRideStatusIntent": ride, @"INListRideOptionsIntent": list,
               @"INCancelRideIntent": cancel, @"INSendRideFeedbackIntent": cancel,
               @"INStartWorkoutIntent": @[@"unspecified", @"ready", @"continueInApp", @"failure", @"appLaunch", @"failure", @"failure", @"success", @"handleInApp"],
               @"INPauseWorkoutIntent": control, @"INResumeWorkoutIntent": control, @"INEndWorkoutIntent": control, @"INCancelWorkoutIntent": control,
               @"INSearchForPhotosIntent": photos, @"INStartPhotoPlaybackIntent": photos };
    }
    NSArray *codes = t[cls];
    if (!codes) return nil;
    return code >= 0 && code < (NSInteger)codes.count ? codes[code] : @"failure";
}

/* payments */
@implementation INPaymentMethod
VALUE_CLASS
- (instancetype)initWithType:(INPaymentMethodType)type name:(NSString *)name identificationHint:(NSString *)hint icon:(INImage *)icon {
    if ((self = [super init])) { SETI("type", type); SET("name", [name copy]); SET("identificationHint", [hint copy]); SET("icon", [icon copy]); }
    return self;
}
+ (instancetype)applePayPaymentMethod { return [[self alloc] initWithType:INPaymentMethodTypeApplePay name:@"Apple Pay" identificationHint:nil icon:nil]; }
INT(INPaymentMethodType, type) OBJ(NSString *, name) OBJ(INImage *, icon) OBJ(NSString *, identificationHint)
@end
@implementation INPaymentRecord
VALUE_CLASS
- (instancetype)initWithPayee:(INPerson *)payee payer:(INPerson *)payer currencyAmount:(INCurrencyAmount *)amount paymentMethod:(INPaymentMethod *)method note:(NSString *)note status:(INPaymentStatus)status feeAmount:(INCurrencyAmount *)fee {
    if ((self = [super init])) {
        SET("payee", [payee copy]); SET("payer", [payer copy]); SET("currencyAmount", [amount copy]); SET("paymentMethod", [method copy]);
        SET("note", [note copy]); SETI("status", status); SET("feeAmount", [fee copy]);
    }
    return self;
}
- (instancetype)initWithPayee:(INPerson *)payee payer:(INPerson *)payer currencyAmount:(INCurrencyAmount *)amount paymentMethod:(INPaymentMethod *)method note:(NSString *)note status:(INPaymentStatus)status {
    return [self initWithPayee:payee payer:payer currencyAmount:amount paymentMethod:method note:note status:status feeAmount:nil];
}
OBJ(INPerson *, payee) OBJ(INPerson *, payer) OBJ(INCurrencyAmount *, currencyAmount) OBJ(NSString *, note) INT(INPaymentStatus, status)
OBJ(INPaymentMethod *, paymentMethod) OBJ(INCurrencyAmount *, feeAmount)
@end
@implementation INBalanceAmount
VALUE_CLASS
- (instancetype)initWithAmount:(NSDecimalNumber *)amount balanceType:(INBalanceType)type { if ((self = [super init])) { SET("amount", amount); SETI("balanceType", type); } return self; }
- (instancetype)initWithAmount:(NSDecimalNumber *)amount currencyCode:(NSString *)code {
    if ((self = [super init])) { SET("amount", amount); SETI("balanceType", INBalanceTypeMoney); SET("currencyCode", [code copy]); }
    return self;
}
OBJ(NSDecimalNumber *, amount) INT(INBalanceType, balanceType) OBJ(NSString *, currencyCode)
@end
@implementation INPaymentAmount
VALUE_CLASS
- (instancetype)initWithAmountType:(INAmountType)type amount:(INCurrencyAmount *)amount { if ((self = [super init])) { SETI("amountType", type); SET("amount", [amount copy]); } return self; }
OBJ(INCurrencyAmount *, amount) INT(INAmountType, amountType)
@end
@implementation INPaymentAccount
VALUE_CLASS
- (instancetype)initWithNickname:(INSpeakableString *)nickname number:(NSString *)number accountType:(INAccountType)type organizationName:(INSpeakableString *)org balance:(INBalanceAmount *)balance secondaryBalance:(INBalanceAmount *)secondary {
    if ((self = [super init])) {
        SET("nickname", [nickname copy]); SET("accountNumber", [number copy]); SETI("accountType", type); SET("organizationName", [org copy]);
        SET("balance", [balance copy]); SET("secondaryBalance", [secondary copy]);
    }
    return self;
}
- (instancetype)initWithNickname:(INSpeakableString *)nickname number:(NSString *)number accountType:(INAccountType)type organizationName:(INSpeakableString *)org {
    return [self initWithNickname:nickname number:number accountType:type organizationName:org balance:nil secondaryBalance:nil];
}
OBJ(INSpeakableString *, nickname) OBJ(NSString *, accountNumber) INT(INAccountType, accountType) OBJ(INSpeakableString *, organizationName)
OBJ(INBalanceAmount *, balance) OBJ(INBalanceAmount *, secondaryBalance)
@end
@implementation INSendPaymentIntent
- (instancetype)initWithPayee:(INPerson *)payee currencyAmount:(INCurrencyAmount *)amount note:(NSString *)note {
    if ((self = [self init])) { SET("payee", [payee copy]); SET("currencyAmount", [amount copy]); SET("note", [note copy]); }
    return self;
}
OBJ(INPerson *, payee) OBJ(INCurrencyAmount *, currencyAmount) OBJ(NSString *, note)
- (NSString *)intentDescription { return [NSString stringWithFormat:@"Send money%@", self.payee ? [@" to " stringByAppendingString:self.payee.displayName] : @""]; }
@end
@implementation INRequestPaymentIntent
- (instancetype)initWithPayer:(INPerson *)payer currencyAmount:(INCurrencyAmount *)amount note:(NSString *)note {
    if ((self = [self init])) { SET("payer", [payer copy]); SET("currencyAmount", [amount copy]); SET("note", [note copy]); }
    return self;
}
OBJ(INPerson *, payer) OBJ(INCurrencyAmount *, currencyAmount) OBJ(NSString *, note)
- (NSString *)intentDescription { return [NSString stringWithFormat:@"Request money%@", self.payer ? [@" from " stringByAppendingString:self.payer.displayName] : @""]; }
@end
RESPONSE(INSendPaymentIntentResponse, INSendPaymentIntentResponseCode)
PROP(INPaymentRecord *, paymentRecord, PaymentRecord)
@end
RESPONSE(INRequestPaymentIntentResponse, INRequestPaymentIntentResponseCode)
PROP(INPaymentRecord *, paymentRecord, PaymentRecord)
@end

/* rides */
@implementation INPriceRange
VALUE_CLASS
- (instancetype)initWithRangeBetweenPrice:(NSDecimalNumber *)first andPrice:(NSDecimalNumber *)second currencyCode:(NSString *)code {
    if ((self = [super init])) {
        BOOL asc = [first compare:second] != NSOrderedDescending;
        SET("minimumPrice", asc ? first : second); SET("maximumPrice", asc ? second : first); SET("currencyCode", [code copy]);
    }
    return self;
}
- (instancetype)initWithMaximumPrice:(NSDecimalNumber *)max currencyCode:(NSString *)code { if ((self = [super init])) { SET("maximumPrice", max); SET("currencyCode", [code copy]); } return self; }
- (instancetype)initWithMinimumPrice:(NSDecimalNumber *)min currencyCode:(NSString *)code { if ((self = [super init])) { SET("minimumPrice", min); SET("currencyCode", [code copy]); } return self; }
- (instancetype)initWithPrice:(NSDecimalNumber *)price currencyCode:(NSString *)code { return [self initWithRangeBetweenPrice:price andPrice:price currencyCode:code]; }
OBJ(NSDecimalNumber *, minimumPrice) OBJ(NSDecimalNumber *, maximumPrice)
- (NSString *)currencyCode { return [self _get:@"currencyCode"] ?: @""; }
@end
@implementation INRideFareLineItem
VALUE_CLASS
- (instancetype)initWithTitle:(NSString *)title price:(NSDecimalNumber *)price currencyCode:(NSString *)code {
    if ((self = [super init])) { SET("title", [title copy]); SET("price", price); SET("currencyCode", [code copy]); }
    return self;
}
OBJ(NSString *, title) OBJ(NSDecimalNumber *, price) OBJ(NSString *, currencyCode)
@end
@implementation INRidePartySizeOption
VALUE_CLASS
- (instancetype)initWithPartySizeRange:(NSRange)range sizeDescription:(NSString *)d priceRange:(INPriceRange *)price {
    if ((self = [super init])) { SETI("partySizeLocation", range.location); SETI("partySizeLength", range.length); SET("sizeDescription", [d copy]); SET("priceRange", [price copy]); }
    return self;
}
- (NSRange)partySizeRange { return NSMakeRange((NSUInteger)[self _int:@"partySizeLocation"], (NSUInteger)[self _int:@"partySizeLength"]); }
- (NSString *)sizeDescription { return [self _get:@"sizeDescription"] ?: @""; }
OBJ(INPriceRange *, priceRange)
@end
@implementation INRideOption
VALUE_CLASS
- (instancetype)initWithName:(NSString *)name estimatedPickupDate:(NSDate *)date { if ((self = [super init])) { SET("name", [name copy] ?: @""); SET("estimatedPickupDate", [date copy] ?: [NSDate date]); } return self; }
- (NSString *)name { return [self _get:@"name"] ?: @""; }
- (void)setName:(NSString *)n { SET("name", [n copy] ?: @""); }
- (NSDate *)estimatedPickupDate { return [self _get:@"estimatedPickupDate"] ?: [NSDate date]; }
- (void)setEstimatedPickupDate:(NSDate *)d { SET("estimatedPickupDate", [d copy]); }
PROP(INPriceRange *, priceRange, PriceRange) PROP(NSNumber *, usesMeteredFare, UsesMeteredFare) PROP(NSString *, disclaimerMessage, DisclaimerMessage)
PROP(NSArray *, availablePartySizeOptions, AvailablePartySizeOptions) PROP(NSString *, availablePartySizeOptionsSelectionPrompt, AvailablePartySizeOptionsSelectionPrompt)
PROP(NSString *, specialPricing, SpecialPricing) PROP(INImage *, specialPricingBadgeImage, SpecialPricingBadgeImage) PROP(NSArray *, fareLineItems, FareLineItems)
PROPS(NSUserActivity *, userActivityForBookingInApplication, UserActivityForBookingInApplication) PROP(NSString *, identifier, Identifier)
@end
@implementation INRideDriver
- (instancetype)initWithPhoneNumber:(NSString *)phone nameComponents:(NSPersonNameComponents *)n displayName:(NSString *)d image:(INImage *)i rating:(NSString *)rating {
    if ((self = [super initWithPersonHandle:[[INPersonHandle alloc] initWithValue:phone type:INPersonHandleTypePhoneNumber] nameComponents:n displayName:d image:i contactIdentifier:nil customIdentifier:nil])) {
        SET("phoneNumber", [phone copy]); SET("rating", [rating copy]);
    }
    return self;
}
- (instancetype)initWithHandle:(NSString *)h displayName:(NSString *)d image:(INImage *)i rating:(NSString *)rating phoneNumber:(NSString *)phone {
    return [self initWithPersonHandle:[[INPersonHandle alloc] initWithValue:h type:INPersonHandleTypeUnknown] nameComponents:nil displayName:d image:i rating:rating phoneNumber:phone];
}
- (instancetype)initWithHandle:(NSString *)h nameComponents:(NSPersonNameComponents *)n image:(INImage *)i rating:(NSString *)rating phoneNumber:(NSString *)phone {
    return [self initWithPersonHandle:[[INPersonHandle alloc] initWithValue:h type:INPersonHandleTypeUnknown] nameComponents:n displayName:nil image:i rating:rating phoneNumber:phone];
}
- (instancetype)initWithPersonHandle:(INPersonHandle *)h nameComponents:(NSPersonNameComponents *)n displayName:(NSString *)d image:(INImage *)i rating:(NSString *)rating phoneNumber:(NSString *)phone {
    if ((self = [self initWithPhoneNumber:phone ?: @"" nameComponents:n displayName:d image:i rating:rating])) SET("personHandle", h);
    return self;
}
OBJ(NSString *, rating) OBJ(NSString *, phoneNumber)
@end
@implementation INRideVehicle
VALUE_CLASS
PROP(id, location, Location) PROP(NSString *, registrationPlate, RegistrationPlate) PROP(NSString *, manufacturer, Manufacturer) PROP(NSString *, model, Model)
PROP(INImage *, mapAnnotationImage, MapAnnotationImage)
@end
@implementation INRideCompletionStatus
VALUE_CLASS
+ (instancetype)_kind:(NSString *)k amount:(INCurrencyAmount *)a {
    INRideCompletionStatus *s = [self new];
    [s _set:k forKey:@"kind"]; [s _set:[a copy] forKey:@"paymentAmount"];
    return s;
}
+ (instancetype)completed { return [self _kind:@"completed" amount:nil]; }
+ (instancetype)completedWithSettledPaymentAmount:(INCurrencyAmount *)a { return [self _kind:@"completed" amount:a]; }
+ (instancetype)completedWithOutstandingPaymentAmount:(INCurrencyAmount *)a { INRideCompletionStatus *s = [self _kind:@"completed" amount:a]; [s _set:@YES forKey:@"outstanding"]; return s; }
+ (instancetype)completedWithFeedbackType:(INRideFeedbackTypeOptions)f { INRideCompletionStatus *s = [self _kind:@"completed" amount:nil]; [s _set:@(f) forKey:@"feedbackType"]; return s; }
+ (instancetype)canceledByService { return [self _kind:@"canceled" amount:nil]; }
+ (instancetype)canceledByUser { return [self _kind:@"canceled" amount:nil]; }
+ (instancetype)canceledMissedPickup { INRideCompletionStatus *s = [self _kind:@"canceled" amount:nil]; [s _set:@YES forKey:@"missedPickup"]; return s; }
- (BOOL)isCompleted { return [[self _get:@"kind"] isEqual:@"completed"]; }
- (BOOL)isCanceled { return [[self _get:@"kind"] isEqual:@"canceled"]; }
- (BOOL)isMissedPickup { return [[self _get:@"missedPickup"] boolValue]; }
- (BOOL)isOutstanding { return [[self _get:@"outstanding"] boolValue]; }
OBJ(INCurrencyAmount *, paymentAmount) INT(INRideFeedbackTypeOptions, feedbackType)
PROPS(NSUserActivity *, completionUserActivity, CompletionUserActivity) PROP(NSSet *, defaultTippingOptions, DefaultTippingOptions)
@end
@implementation INRideStatus
VALUE_CLASS
PROP(NSString *, rideIdentifier, RideIdentifier) PROPI(INRidePhase, phase, Phase) PROP(INRideCompletionStatus *, completionStatus, CompletionStatus)
PROP(INRideVehicle *, vehicle, Vehicle) PROP(INRideDriver *, driver, Driver) PROP(NSDate *, estimatedPickupDate, EstimatedPickupDate)
PROP(NSDate *, estimatedDropOffDate, EstimatedDropOffDate) PROP(NSDate *, estimatedPickupEndDate, EstimatedPickupEndDate)
PROP(INDateComponentsRange *, scheduledPickupTime, ScheduledPickupTime) PROP(id, pickupLocation, PickupLocation) PROP(NSArray *, waypoints, Waypoints)
PROP(id, dropOffLocation, DropOffLocation) PROP(INRideOption *, rideOption, RideOption)
PROPS(NSUserActivity *, userActivityForCancelingInApplication, UserActivityForCancelingInApplication) PROP(NSArray *, additionalActionActivities, AdditionalActionActivities)
@end
@implementation INListRideOptionsIntent
- (instancetype)initWithPickupLocation:(id)pickup dropOffLocation:(id)dropOff { if ((self = [self init])) { SET("pickupLocation", [pickup copy]); SET("dropOffLocation", [dropOff copy]); } return self; }
OBJ(id, pickupLocation) OBJ(id, dropOffLocation)
- (NSString *)intentDescription { return @"List ride options"; }
@end
@implementation INRequestRideIntent
- (instancetype)initWithPickupLocation:(id)pickup dropOffLocation:(id)dropOff rideOptionName:(INSpeakableString *)option partySize:(NSNumber *)size paymentMethod:(INPaymentMethod *)method scheduledPickupTime:(INDateComponentsRange *)time {
    if ((self = [self init])) {
        SET("pickupLocation", [pickup copy]); SET("dropOffLocation", [dropOff copy]); SET("rideOptionName", [option copy]); SET("partySize", size);
        SET("paymentMethod", [method copy]); SET("scheduledPickupTime", [time copy]);
    }
    return self;
}
OBJ(id, pickupLocation) OBJ(id, dropOffLocation) OBJ(INSpeakableString *, rideOptionName) OBJ(NSNumber *, partySize) OBJ(INPaymentMethod *, paymentMethod)
OBJ(INDateComponentsRange *, scheduledPickupTime)
- (NSString *)intentDescription {
    id d = self.dropOffLocation;
    NSString *to = [d respondsToSelector:@selector(name)] ? [d valueForKey:@"name"] : nil;
    return to.length ? [@"Request a ride to " stringByAppendingString:to] : @"Request a ride";
}
@end
@implementation INGetRideStatusIntent
- (instancetype)init { return [super init]; }
- (NSString *)intentDescription { return @"Get ride status"; }
@end
@implementation INCancelRideIntent
- (instancetype)initWithRideIdentifier:(NSString *)ride { if ((self = [self init])) SET("rideIdentifier", [ride copy] ?: @""); return self; }
- (NSString *)rideIdentifier { return [self _get:@"rideIdentifier"] ?: @""; }
- (NSString *)intentDescription { return @"Cancel ride"; }
@end
@implementation INSendRideFeedbackIntent
- (instancetype)initWithRideIdentifier:(NSString *)ride { if ((self = [self init])) SET("rideIdentifier", [ride copy] ?: @""); return self; }
- (NSString *)rideIdentifier { return [self _get:@"rideIdentifier"] ?: @""; }
PROP(NSNumber *, rating, Rating) PROP(INCurrencyAmount *, tip, Tip)
- (NSString *)intentDescription { return @"Send ride feedback"; }
@end
RESPONSE(INListRideOptionsIntentResponse, INListRideOptionsIntentResponseCode)
PROP(NSArray *, rideOptions, RideOptions) PROP(NSArray *, paymentMethods, PaymentMethods) PROP(NSDate *, expirationDate, ExpirationDate)
@end
RESPONSE(INRequestRideIntentResponse, INRequestRideIntentResponseCode)
PROP(INRideStatus *, rideStatus, RideStatus)
@end
RESPONSE(INGetRideStatusIntentResponse, INGetRideStatusIntentResponseCode)
PROP(INRideStatus *, rideStatus, RideStatus)
@end
RESPONSE(INCancelRideIntentResponse, INCancelRideIntentResponseCode)
PROP(INCurrencyAmount *, cancellationFee, CancellationFee) PROP(NSDateComponents *, cancellationFeeThreshold, CancellationFeeThreshold)
@end
RESPONSE(INSendRideFeedbackIntentResponse, INSendRideFeedbackIntentResponseCode)
@end

/* workouts */
@implementation INStartWorkoutIntent
- (instancetype)initWithWorkoutName:(INSpeakableString *)name goalValue:(NSNumber *)goal workoutGoalUnitType:(INWorkoutGoalUnitType)unit workoutLocationType:(INWorkoutLocationType)loc isOpenEnded:(NSNumber *)open {
    if ((self = [self init])) { SET("workoutName", [name copy]); SET("goalValue", goal); SETI("workoutGoalUnitType", unit); SETI("workoutLocationType", loc); SET("isOpenEnded", open); }
    return self;
}
OBJ(INSpeakableString *, workoutName) OBJ(NSNumber *, goalValue) INT(INWorkoutGoalUnitType, workoutGoalUnitType) INT(INWorkoutLocationType, workoutLocationType) OBJ(NSNumber *, isOpenEnded)
- (NSString *)intentDescription { return self.workoutName.spokenPhrase.length ? [@"Start " stringByAppendingString:self.workoutName.spokenPhrase] : @"Start a workout"; }
@end
#define WORKOUT_CONTROL(Verb, verb) \
@implementation IN##Verb##WorkoutIntent \
- (instancetype)initWithWorkoutName:(INSpeakableString *)name { if ((self = [self init])) SET("workoutName", [name copy]); return self; } \
OBJ(INSpeakableString *, workoutName) \
- (NSString *)intentDescription { return @verb " workout"; } \
@end \
RESPONSE(IN##Verb##WorkoutIntentResponse, IN##Verb##WorkoutIntentResponseCode) \
@end
WORKOUT_CONTROL(Pause, "Pause") WORKOUT_CONTROL(Resume, "Resume") WORKOUT_CONTROL(End, "End") WORKOUT_CONTROL(Cancel, "Cancel")
RESPONSE(INStartWorkoutIntentResponse, INStartWorkoutIntentResponseCode)
@end

/* photos */
#define PHOTOS_INTENT(cls, desc) \
@implementation cls \
- (instancetype)initWithDateCreated:(INDateComponentsRange *)date locationCreated:(id)place albumName:(NSString *)album searchTerms:(NSArray *)terms includedAttributes:(INPhotoAttributeOptions)inc excludedAttributes:(INPhotoAttributeOptions)exc peopleInPhoto:(NSArray *)people { \
    if ((self = [self init])) { \
        SET("dateCreated", [date copy]); SET("locationCreated", [place copy]); SET("albumName", [album copy]); SET("searchTerms", [terms copy]); \
        SETI("includedAttributes", inc); SETI("excludedAttributes", exc); SET("peopleInPhoto", [people copy]); \
    } \
    return self; \
} \
OBJ(INDateComponentsRange *, dateCreated) OBJ(id, locationCreated) OBJ(NSString *, albumName) OBJ(NSArray *, searchTerms) INT(INConditionalOperator, searchTermsOperator) \
INT(INPhotoAttributeOptions, includedAttributes) INT(INPhotoAttributeOptions, excludedAttributes) OBJ(NSArray *, peopleInPhoto) INT(INConditionalOperator, peopleInPhotoOperator) \
- (NSString *)intentDescription { return @desc; } \
@end
PHOTOS_INTENT(INSearchForPhotosIntent, "Search for photos")
PHOTOS_INTENT(INStartPhotoPlaybackIntent, "Play a slideshow")
RESPONSE(INSearchForPhotosIntentResponse, INSearchForPhotosIntentResponseCode)
PROP(NSNumber *, searchResultsCount, SearchResultsCount)
@end
RESPONSE(INStartPhotoPlaybackIntentResponse, INStartPhotoPlaybackIntentResponseCode)
PROP(NSNumber *, searchResultsCount, SearchResultsCount)
@end

/* their resolution results */
@implementation INDateComponentsRangeResolutionResult
RESULT_SUCCESS(successWithResolvedDateComponentsRange:, INDateComponentsRange *) RESULT_DISAMBIG(disambiguationWithDateComponentsRangesToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithDateComponentsRangeToConfirm:, INDateComponentsRange *)
@end
@implementation INPlacemarkResolutionResult
RESULT_SUCCESS(successWithResolvedPlacemark:, id) RESULT_DISAMBIG(disambiguationWithPlacemarksToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithPlacemarkToConfirm:, id)
@end
@implementation INPaymentMethodResolutionResult
RESULT_SUCCESS(successWithResolvedPaymentMethod:, INPaymentMethod *) RESULT_DISAMBIG(disambiguationWithPaymentMethodsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithPaymentMethodToConfirm:, INPaymentMethod *)
@end
@implementation INPaymentAmountResolutionResult
RESULT_SUCCESS(successWithResolvedPaymentAmount:, INPaymentAmount *) RESULT_DISAMBIG(disambiguationWithPaymentAmountsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithPaymentAmountToConfirm:, INPaymentAmount *)
@end
@implementation INPaymentAccountResolutionResult
RESULT_SUCCESS(successWithResolvedPaymentAccount:, INPaymentAccount *) RESULT_DISAMBIG(disambiguationWithPaymentAccountsToDisambiguate:) RESULT_CONFIRM(confirmationRequiredWithPaymentAccountToConfirm:, INPaymentAccount *)
@end
#define RESULT_ENUM(cls, type, success, confirm) \
@implementation cls \
+ (instancetype)success:(type)v { return [self _kind:@"success" value:@(v) options:nil]; } \
+ (instancetype)confirm:(type)v { return [self _kind:@"confirmationRequired" value:@(v) options:nil]; } \
@end
RESULT_ENUM(INPaymentStatusResolutionResult, INPaymentStatus, successWithResolvedPaymentStatus, confirmationRequiredWithPaymentStatusToConfirm)
RESULT_ENUM(INWorkoutGoalUnitTypeResolutionResult, INWorkoutGoalUnitType, successWithResolvedWorkoutGoalUnitType, confirmationRequiredWithWorkoutGoalUnitTypeToConfirm)
RESULT_ENUM(INWorkoutLocationTypeResolutionResult, INWorkoutLocationType, successWithResolvedWorkoutLocationType, confirmationRequiredWithWorkoutLocationTypeToConfirm)
#define RESULT_REASONS(cls, reasonType, base, baseInit) \
@implementation cls \
+ (instancetype)unsupportedForReason:(reasonType)reason { return [self unsupportedWithReason:reason]; } \
- (instancetype)baseInit(base *)r { if ((self = [super init])) copy_result(self, r); return self; } \
@end
RESULT_REASONS(INSendPaymentPayeeResolutionResult, INSendPaymentPayeeUnsupportedReason, INPersonResolutionResult, initWithPersonResolutionResult:)
RESULT_REASONS(INRequestPaymentPayerResolutionResult, INRequestPaymentPayerUnsupportedReason, INPersonResolutionResult, initWithPersonResolutionResult:)
RESULT_REASONS(INSendPaymentCurrencyAmountResolutionResult, INSendPaymentCurrencyAmountUnsupportedReason, INCurrencyAmountResolutionResult, initWithCurrencyAmountResolutionResult:)
RESULT_REASONS(INRequestPaymentCurrencyAmountResolutionResult, INRequestPaymentCurrencyAmountUnsupportedReason, INCurrencyAmountResolutionResult, initWithCurrencyAmountResolutionResult:)

/* ---------------- interactions ---------------- */
static NSString *library_isim(NSString *file) {
    NSString *d = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:file];
}
static NSMutableArray *read_list(NSString *path, NSString *key) {
    NSArray *a = [NSDictionary dictionaryWithContentsOfFile:path][key];
    return [a isKindOfClass:[NSArray class]] ? [a mutableCopy] : [NSMutableArray array];
}
@implementation INInteraction
VALUE_CLASS
- (instancetype)initWithIntent:(INIntent *)intent response:(INIntentResponse *)response {
    if ((self = [super init])) {
        SET("intent", intent ?: [INIntent new]); SET("intentResponse", response); SET("identifier", NSUUID.UUID.UUIDString);
    }
    return self;
}
- (INIntent *)intent { return [self _get:@"intent"]; }
OBJ(INIntentResponse *, intentResponse) OBJ(NSString *, groupIdentifier)
- (NSString *)identifier { return [self _get:@"identifier"] ?: @""; }
- (void)setIdentifier:(NSString *)i { SET("identifier", i); }
- (void)setGroupIdentifier:(NSString *)g { SET("groupIdentifier", g); }
INT(INInteractionDirection, direction)
- (void)setDirection:(INInteractionDirection)d { SETI("direction", d); }
- (INIntentHandlingStatus)intentHandlingStatus {
    INIntentResponse *r = self.intentResponse;
    if (!r || ![r respondsToSelector:@selector(code)]) return INIntentHandlingStatusUnspecified;
    NSInteger code = [(id)r code];
    NSString *cls = NSStringFromClass(r.class);
    NSString *meaning = isim_in_code_meaning(NSStringFromClass(self.intent.class), code);
    if (meaning) {
        if ([meaning isEqualToString:@"success"]) return INIntentHandlingStatusSuccess;
        if ([meaning isEqualToString:@"ready"]) return INIntentHandlingStatusReady;
        if ([meaning isEqualToString:@"inProgress"]) return INIntentHandlingStatusInProgress;
        if ([meaning isEqualToString:@"continueInApp"] || [meaning isEqualToString:@"handleInApp"]) return INIntentHandlingStatusDeferredToApplication;
        if ([meaning isEqualToString:@"unspecified"]) return INIntentHandlingStatusUnspecified;
        return INIntentHandlingStatusFailure;
    }
    /* each domain's success code */
    NSInteger success = [cls isEqualToString:@"INPlayMediaIntentResponse"] || [cls isEqualToString:@"INSearchForMediaIntentResponse"] ? 4 : 3;
    if ([cls isEqualToString:@"INAddMediaIntentResponse"] && code == INAddMediaIntentResponseCodeHandleInApp) return INIntentHandlingStatusDeferredToApplication;
    if ([cls isEqualToString:@"INStartCallIntentResponse"]) return code == 2 ? INIntentHandlingStatusDeferredToApplication : code == 3 ? INIntentHandlingStatusUserConfirmationRequired : code >= 4 ? INIntentHandlingStatusFailure : code == 1 ? INIntentHandlingStatusReady : INIntentHandlingStatusUnspecified;
    if (code == success) return INIntentHandlingStatusSuccess;
    if (code == 1) return INIntentHandlingStatusReady;
    if (code == 2 && success == 3) return INIntentHandlingStatusInProgress;
    if (code > success) return INIntentHandlingStatusFailure;
    return INIntentHandlingStatusUnspecified;
}
- (void)donateInteractionWithCompletion:(void (^)(NSError *))completion {
    NSString *f = library_isim(@"Interactions.plist");
    NSMutableArray *list = read_list(f, @"interactions");
    if (![self _get:@"date"]) SET("date", [NSDate date]);
    NSMutableDictionary *e = [[self _isim_plist] mutableCopy];
    e[@"app"] = NSBundle.mainBundle.bundleIdentifier ?: @"";
    [list addObject:e];
    while (list.count > 100) [list removeObjectAtIndex:0];
    BOOL ok = [@{ @"interactions": list } writeToFile:f atomically:YES];
    NSLog(@"isim Intents: donated %@ (%@)", NSStringFromClass(self.intent.class), self.identifier);
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok ? nil : [NSError errorWithDomain:@"IntentsErrorDomain" code:1901 userInfo:nil]); });
}
static void delete_where(BOOL (^match)(NSDictionary *), void (^completion)(NSError *)) {
    NSString *f = library_isim(@"Interactions.plist");
    NSMutableArray *list = read_list(f, @"interactions");
    NSUInteger before = list.count;
    [list filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *b) { return !match(e); }]];
    [@{ @"interactions": list } writeToFile:f atomically:YES];
    NSLog(@"isim Intents: deleted %lu donated interaction(s)", (unsigned long)(before - list.count));
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
}
+ (void)deleteAllInteractionsWithCompletion:(void (^)(NSError *))completion { delete_where(^BOOL(NSDictionary *e) { return YES; }, completion); }
+ (void)deleteInteractionsWithIdentifiers:(NSArray<NSString *> *)ids completion:(void (^)(NSError *))completion {
    delete_where(^BOOL(NSDictionary *e) { return [ids containsObject:e[@"identifier"] ?: @""]; }, completion);
}
+ (void)deleteInteractionsWithGroupIdentifier:(NSString *)g completion:(void (^)(NSError *))completion {
    delete_where(^BOOL(NSDictionary *e) { return [e[@"groupIdentifier"] isEqual:g]; }, completion);
}
@end

/* NSUserActivity: Siri's continuation carries the interaction (Foundation keeps the plist's "interaction" entry as an
   associated object under this selector) */
static char kPhrase;
@implementation NSUserActivity (IntentsAdditions)
- (INInteraction *)interaction {
    id p = objc_getAssociatedObject(self, @selector(interaction));
    if ([p isKindOfClass:[INInteraction class]]) return p;
    if ([p isKindOfClass:[NSDictionary class]]) {
        INInteraction *i = in_decode(p);
        if ([i isKindOfClass:[INInteraction class]]) { objc_setAssociatedObject(self, @selector(interaction), i, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return i; }
    }
    return nil;
}
- (NSString *)suggestedInvocationPhrase { return objc_getAssociatedObject(self, &kPhrase); }
- (void)setSuggestedInvocationPhrase:(NSString *)p { objc_setAssociatedObject(self, &kPhrase, p, OBJC_ASSOCIATION_COPY_NONATOMIC); }
@end

/* ---------------- shortcuts and voice shortcuts ---------------- */
@implementation INShortcut
VALUE_CLASS
- (instancetype)initWithIntent:(INIntent *)intent { if (!intent) return nil; if ((self = [self init])) SET("intent", intent); return self; }
- (instancetype)initWithUserActivity:(NSUserActivity *)a { if ((self = [self init])) SET("userActivity", a); return self; }
OBJ(INIntent *, intent) OBJ(NSUserActivity *, userActivity)
@end
@implementation INVoiceShortcut
VALUE_CLASS
- (NSUUID *)identifier { return [self _get:@"identifier"] ?: [NSUUID UUID]; }
- (NSString *)invocationPhrase { return [self _get:@"invocationPhrase"] ?: @""; }
- (INShortcut *)shortcut { return [self _get:@"shortcut"]; }
@end
NSString *isim_in_voice_shortcuts_file(void) {
    NSString *d = [isim_data_dir() stringByAppendingPathComponent:@"Library/Siri"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:@"VoiceShortcuts.plist"];
}
/* the shortcut title shown in the Shortcuts app: the intent's suggested phrase / description or the activity's title */
static NSString *shortcut_title(INShortcut *s) {
    if (s.intent) return s.intent.suggestedInvocationPhrase ?: s.intent.intentDescription;
    return s.userActivity.title ?: s.userActivity.suggestedInvocationPhrase ?: s.userActivity.activityType;
}
INVoiceShortcut *isim_in_add_voice_shortcut(INShortcut *shortcut, NSString *phrase) {
    NSString *f = isim_in_voice_shortcuts_file();
    NSMutableArray *list = read_list(f, @"shortcuts");
    INVoiceShortcut *v = [INVoiceShortcut new];
    [v _set:[NSUUID UUID] forKey:@"identifier"]; [v _set:phrase forKey:@"invocationPhrase"]; [v _set:shortcut forKey:@"shortcut"];
    NSMutableDictionary *e = [[(id)v _isim_plist] mutableCopy];
    e[@"app"] = NSBundle.mainBundle.bundleIdentifier ?: @"";
    e[@"appName"] = app_display_name();
    e[@"title"] = shortcut_title(shortcut) ?: phrase;
    [list addObject:e];
    [@{ @"shortcuts": list } writeToFile:f atomically:YES];
    NSLog(@"isim Intents: added voice shortcut “%@” (%@)", phrase, e[@"title"]);
    return v;
}
void isim_in_update_voice_shortcut(NSUUID *ident, NSString *phrase, BOOL remove) {
    NSString *f = isim_in_voice_shortcuts_file();
    NSMutableArray *list = read_list(f, @"shortcuts");
    for (NSUInteger i = 0; i < list.count; i++) {
        NSDictionary *e = list[i];
        if (![[in_decode(e[@"identifier"]) UUIDString] isEqual:ident.UUIDString]) continue;
        if (remove) [list removeObjectAtIndex:i];
        else { NSMutableDictionary *m = [e mutableCopy]; m[@"invocationPhrase"] = phrase; list[i] = m; }
        break;
    }
    [@{ @"shortcuts": list } writeToFile:f atomically:YES];
}
@implementation INVoiceShortcutCenter
+ (INVoiceShortcutCenter *)sharedCenter { static INVoiceShortcutCenter *c; static dispatch_once_t once; dispatch_once(&once, ^{ c = [INVoiceShortcutCenter new]; }); return c; }
- (NSArray *)_mine {
    NSMutableArray *out = [NSMutableArray array];
    NSString *me = NSBundle.mainBundle.bundleIdentifier ?: @"";
    for (NSDictionary *e in read_list(isim_in_voice_shortcuts_file(), @"shortcuts")) {
        NSString *app = e[@"app"] ?: @"";
        if (![app isEqualToString:me] && ![me hasPrefix:[app stringByAppendingString:@"."]]) continue;   /* the app and its extensions */
        INVoiceShortcut *v = in_decode(e);
        if ([v isKindOfClass:[INVoiceShortcut class]]) [out addObject:v];
    }
    return out;
}
- (void)getAllVoiceShortcutsWithCompletion:(void (^)(NSArray *, NSError *))completion {
    NSArray *a = [self _mine];
    dispatch_async(dispatch_get_main_queue(), ^{ completion(a, nil); });
}
- (void)getVoiceShortcutWithIdentifier:(NSUUID *)ident completion:(void (^)(INVoiceShortcut *, NSError *))completion {
    INVoiceShortcut *found = nil;
    for (INVoiceShortcut *v in [self _mine]) if ([v.identifier isEqual:ident]) found = v;
    dispatch_async(dispatch_get_main_queue(), ^{ completion(found, found ? nil : [NSError errorWithDomain:@"IntentsErrorDomain" code:6002 userInfo:nil]); });
}
- (void)setShortcutSuggestions:(NSArray<INShortcut *> *)suggestions {
    NSMutableArray *list = [NSMutableArray array];
    for (INShortcut *s in suggestions) { NSMutableDictionary *e = [[s _isim_plist] mutableCopy]; e[@"title"] = shortcut_title(s) ?: @""; [list addObject:e]; }
    [@{ @"suggestions": list } writeToFile:library_isim(@"ShortcutSuggestions.plist") atomically:YES];
    NSLog(@"isim Intents: %lu shortcut suggestion(s)", (unsigned long)list.count);
}
@end

/* ---------------- relevant shortcuts ---------------- */
@implementation INRelevanceProvider
VALUE_CLASS
@end
@implementation INDateRelevanceProvider
- (instancetype)initWithStartDate:(NSDate *)start endDate:(NSDate *)end { if ((self = [super init])) { SET("startDate", [start copy] ?: [NSDate date]); SET("endDate", [end copy]); } return self; }
- (NSDate *)startDate { return [self _get:@"startDate"] ?: [NSDate distantPast]; }
OBJ(NSDate *, endDate)
@end
@implementation INLocationRelevanceProvider
- (instancetype)initWithRegion:(CLRegion *)region { if ((self = [super init])) SET("region", [(id)region copy]); return self; }
OBJ(CLRegion *, region)
@end
@implementation INDailyRoutineRelevanceProvider
- (instancetype)initWithSituation:(INDailyRoutineSituation)s { if ((self = [super init])) SETI("situation", s); return self; }
INT(INDailyRoutineSituation, situation)
@end
@implementation INDefaultCardTemplate
VALUE_CLASS
- (instancetype)init { return [self initWithTitle:@""]; }
- (instancetype)initWithTitle:(NSString *)t { if ((self = [super init])) SET("title", [t copy] ?: @""); return self; }
- (NSString *)title { return [self _get:@"title"] ?: @""; }
- (void)setTitle:(NSString *)t { SET("title", [t copy] ?: @""); }
OBJ(NSString *, subtitle) OBJ(INImage *, image)
- (void)setSubtitle:(NSString *)t { SET("subtitle", [t copy]); }
- (void)setImage:(INImage *)i { SET("image", [i copy]); }
@end
@implementation INRelevantShortcut
VALUE_CLASS
- (instancetype)init { return [self initWithShortcut:[INShortcut new]]; }
- (instancetype)initWithShortcut:(INShortcut *)s { if ((self = [super init])) SET("shortcut", [s copy]); return self; }
OBJ(INShortcut *, shortcut) OBJ(INDefaultCardTemplate *, watchTemplate) OBJ(NSString *, widgetKind)
- (NSArray *)relevanceProviders { return [self _get:@"relevanceProviders"] ?: @[]; }
- (void)setRelevanceProviders:(NSArray *)p { SET("relevanceProviders", [p copy]); }
- (void)setWatchTemplate:(INDefaultCardTemplate *)t { SET("watchTemplate", [t copy]); }
- (void)setWidgetKind:(NSString *)k { SET("widgetKind", [k copy]); }
INT(INRelevantShortcutRole, shortcutRole)
- (void)setShortcutRole:(INRelevantShortcutRole)r { SETI("shortcutRole", r); }
@end
@implementation INRelevantShortcutStore
+ (INRelevantShortcutStore *)defaultStore { static INRelevantShortcutStore *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [INRelevantShortcutStore new]; }); return s; }
- (void)setRelevantShortcuts:(NSArray<INRelevantShortcut *> *)shortcuts completionHandler:(void (^)(NSError *))completion {
    NSMutableArray *list = [NSMutableArray array];
    for (INRelevantShortcut *r in shortcuts) {
        NSMutableDictionary *e = [[r _isim_plist] mutableCopy];
        e[@"title"] = r.watchTemplate.title.length ? r.watchTemplate.title : shortcut_title(r.shortcut) ?: @"";
        if (r.watchTemplate.subtitle) e[@"subtitle"] = r.watchTemplate.subtitle;
        [list addObject:e];
    }
    BOOL ok = [@{ @"shortcuts": list } writeToFile:library_isim(@"RelevantShortcuts.plist") atomically:YES];
    NSLog(@"isim Intents: %lu relevant shortcut(s)", (unsigned long)list.count);
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok ? nil : [NSError errorWithDomain:@"IntentsErrorDomain" code:1901 userInfo:nil]); });
}
@end

/* ---------------- handling ---------------- */
@implementation INExtension
- (id)handlerForIntent:(INIntent *)intent { return self; }
@end
@implementation INParameter
VALUE_CLASS
+ (instancetype)parameterForClass:(Class)c keyPath:(NSString *)k { INParameter *p = [self new]; [p _set:NSStringFromClass(c) forKey:@"class"]; [p _set:k forKey:@"keyPath"]; return p; }
- (Class)parameterClass { return NSClassFromString([self _get:@"class"] ?: @"NSObject"); }
- (NSString *)parameterKeyPath { return [self _get:@"keyPath"] ?: @""; }
@end
