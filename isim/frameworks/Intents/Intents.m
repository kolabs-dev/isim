/* isim Intents (SiriKit): the value classes, intents, responses, resolution results, authorization, donations and
 * voice shortcuts (ARC). The conversation itself (resolve / confirm / handle) is INSiriRunner.m.
 *
 * Every value class keeps its properties in a dictionary (NSObject (INValues), VALUE_CLASS), which gives them copying, equality, secure
 * coding and a property-list form (_isim_plist) used between the simulated Siri (the home screen), Intents extensions
 * and apps. */
#import <Intents/Intents.h>
#import <objc/runtime.h>
#include <stdlib.h>

NSString *isim_data_dir(void);

/* ---------------- the property-list form ---------------- */
static id in_encode(id v);
static id in_decode(id v);
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
    if ((self = [self init])) { NSDictionary *p = [c decodeObjectForKey:@"isim"]; for (NSString *k in p) if (![k hasPrefix:@"$"]) { id x = in_decode(p[k]); if (x) self._in_values[k] = x; } } \
    return self; \
} \
- (NSDictionary *)_isim_plist { return values_plist(self); } \
+ (instancetype)_isim_fromPlist:(NSDictionary *)p { return values_from_plist(self, p); } \
- (NSString *)description { return [NSString stringWithFormat:@"<%@ %@>", NSStringFromClass([self class]), self._in_values]; }

static id in_encode(id v) {
    if (!v || v == NSNull.null) return nil;
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
    if ([cls isEqualToString:@"NSURL"]) return [NSURL URLWithString:v[@"url"]];
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

/* ---------------- intents ---------------- */
@implementation INIntent
VALUE_CLASS
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

/* ---------------- calls ---------------- */
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
    /* each domain's success code */
    NSInteger success = [cls isEqualToString:@"INPlayMediaIntentResponse"] ? 4 : 3;
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
