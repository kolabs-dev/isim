/* isim UIKit: an app's integration with the system around it (ARC).
 *
 * - Home-screen quick actions: Info.plist UIApplicationShortcutItems + UIApplication.shortcutItems (saved in the app
 *   container, Library/isim/ShortcutItems.plist, where the home screen reads them). Choosing one in the icon's menu
 *   launches/activates the app with the isim-private URL "isim-shortcut:<type>".
 * - User activities: "isim-activity:<plist file>" (Spotlight results, handoff of NSUserActivity between processes)
 *   and "isim-universal:<https URL>" (universal links) arrive as NSUserActivity continuations.
 * - State restoration: stateRestorationActivity(for:) is saved when the scene goes to the background
 *   (Library/isim/SceneState.plist) and handed back on the next launch (session.stateRestorationActivity).
 * - Background work: beginBackgroundTask (expires after ISIM_BACKGROUND_TASK_SECONDS, default 30), launches into the
 *   background (ISIM_LAUNCH_BACKGROUND) and BackgroundTasks launches ("bgtask ID" from the shell, for submitted requests);
 *   what keeps the app running in the background (reported to the shell, which suspends the app otherwise).
 * - Remote notifications: registration (device token), payloads from the shell ("push FILE", or a launch for one),
 *   responses chosen under expanded notifications ("nc-action ..."), the app icon badge.
 * - Alternate app icons (Library/isim/AlternateIcon.plist), with the system alert.
 * UIApplication.m calls the isim_sys_* hooks at launch, on URL/system events and on lifecycle changes. */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#include <float.h>
#include <stdlib.h>
#include <dlfcn.h>

NSString *isim_data_dir(void);

/* ================= shortcut items ================= */
static NSString *symbol_for_icon_type(UIApplicationShortcutIconType t) {
    static NSString *const names[] = { @"square.and.pencil", @"play.fill", @"pause.fill", @"plus", @"location.fill", @"magnifyingglass",
        @"square.and.arrow.up", @"nosign", @"person.crop.circle", @"house.fill", @"mappin.and.ellipse", @"star.fill", @"heart.fill",
        @"cloud.fill", @"envelope.open.fill", @"checkmark.circle.fill", @"envelope.fill", @"message.fill", @"calendar", @"clock.fill",
        @"camera.fill", @"video.fill", @"circle", @"checkmark.circle", @"alarm.fill", @"book.fill", @"shuffle", @"speaker.wave.2.fill",
        @"arrow.clockwise" };
    return t >= 0 && (NSUInteger)t < sizeof names / sizeof *names ? names[t] : @"circle";
}
static UIApplicationShortcutIconType icon_type_named(NSString *n) {
    static NSString *const names[] = { @"Compose", @"Play", @"Pause", @"Add", @"Location", @"Search", @"Share", @"Prohibit", @"Contact", @"Home",
        @"MarkLocation", @"Favorite", @"Love", @"Cloud", @"Invitation", @"Confirmation", @"Mail", @"Message", @"Date", @"Time", @"CapturePhoto",
        @"CaptureVideo", @"Task", @"TaskCompleted", @"Alarm", @"Bookmark", @"Shuffle", @"Audio", @"Update" };
    NSString *s = [n hasPrefix:@"UIApplicationShortcutIconType"] ? [n substringFromIndex:29] : n;
    for (NSUInteger i = 0; i < sizeof names / sizeof *names; i++) if ([names[i] isEqualToString:s]) return (UIApplicationShortcutIconType)i;
    return -1;
}

@interface UIApplicationShortcutIcon ()
@property (nonatomic, readwrite, copy) NSString *_isim_symbolName;
@end
@implementation UIApplicationShortcutIcon
+ (instancetype)iconWithType:(UIApplicationShortcutIconType)type { UIApplicationShortcutIcon *i = [self new]; i._isim_symbolName = symbol_for_icon_type(type); return i; }
+ (instancetype)iconWithSystemImageName:(NSString *)name { UIApplicationShortcutIcon *i = [self new]; i._isim_symbolName = name; return i; }
+ (instancetype)iconWithTemplateImageName:(NSString *)name { UIApplicationShortcutIcon *i = [self new]; i._isim_symbolName = [@"asset:" stringByAppendingString:name]; return i; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UIApplicationShortcutIcon class]] && [((UIApplicationShortcutIcon *)o)._isim_symbolName isEqual:self._isim_symbolName]; }
- (NSUInteger)hash { return self._isim_symbolName.hash; }
@end

@interface UIApplicationShortcutItem () {
@protected
    NSString *_type, *_localizedTitle, *_localizedSubtitle;
    UIApplicationShortcutIcon *_icon;
    NSDictionary *_userInfo;
    id _targetContentIdentifier;
}
@end
@implementation UIApplicationShortcutItem
@synthesize type = _type, localizedTitle = _localizedTitle, localizedSubtitle = _localizedSubtitle, icon = _icon, userInfo = _userInfo, targetContentIdentifier = _targetContentIdentifier;
- (instancetype)initWithType:(NSString *)type localizedTitle:(NSString *)title localizedSubtitle:(NSString *)sub icon:(UIApplicationShortcutIcon *)icon userInfo:(NSDictionary *)info {
    if ((self = [super init])) { _type = [type copy]; _localizedTitle = [title copy]; _localizedSubtitle = [sub copy]; _icon = icon; _userInfo = [info copy]; }
    return self;
}
- (instancetype)initWithType:(NSString *)type localizedTitle:(NSString *)title { return [self initWithType:type localizedTitle:title localizedSubtitle:nil icon:nil userInfo:nil]; }
- (id)copyWithZone:(NSZone *)z { return [[UIApplicationShortcutItem alloc] initWithType:_type localizedTitle:_localizedTitle localizedSubtitle:_localizedSubtitle icon:_icon userInfo:_userInfo]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[UIMutableApplicationShortcutItem alloc] initWithType:_type localizedTitle:_localizedTitle localizedSubtitle:_localizedSubtitle icon:_icon userInfo:_userInfo]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[UIApplicationShortcutItem class]]) return NO;
    UIApplicationShortcutItem *x = o;
    return [x.type isEqual:_type] && [x.localizedTitle isEqual:_localizedTitle] && (x.localizedSubtitle == _localizedSubtitle || [x.localizedSubtitle isEqual:_localizedSubtitle]);
}
- (NSUInteger)hash { return _type.hash ^ _localizedTitle.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"<UIApplicationShortcutItem %@ “%@”>", _type, _localizedTitle]; }
@end
@implementation UIMutableApplicationShortcutItem
@dynamic type, localizedTitle, localizedSubtitle, icon, userInfo, targetContentIdentifier;
- (void)setType:(NSString *)t { _type = [t copy]; }
- (void)setLocalizedTitle:(NSString *)t { _localizedTitle = [t copy]; }
- (void)setLocalizedSubtitle:(NSString *)t { _localizedSubtitle = [t copy]; }
- (void)setIcon:(UIApplicationShortcutIcon *)i { _icon = i; }
- (void)setUserInfo:(NSDictionary *)u { _userInfo = [u copy]; }
- (void)setTargetContentIdentifier:(id)t { _targetContentIdentifier = t; }
- (NSString *)type { return _type; }
- (NSString *)localizedTitle { return _localizedTitle; }
- (NSString *)localizedSubtitle { return _localizedSubtitle; }
- (UIApplicationShortcutIcon *)icon { return _icon; }
- (NSDictionary *)userInfo { return _userInfo; }
- (id)targetContentIdentifier { return _targetContentIdentifier; }
@end

/* ================= scene connection payloads ================= */
@interface UISceneOpenURLOptions ()
@property (nonatomic, readwrite, copy) NSString *sourceApplication;
@property (nonatomic, readwrite) BOOL openInPlace;
@end
@implementation UISceneOpenURLOptions
- (id)annotation { return nil; }
@end
@interface UIOpenURLContext ()
@property (nonatomic, readwrite, copy) NSURL *URL;
@property (nonatomic, readwrite, strong) UISceneOpenURLOptions *options;
@end
@implementation UIOpenURLContext
- (NSString *)description { return [NSString stringWithFormat:@"<UIOpenURLContext %@>", _URL]; }
@end
static UIOpenURLContext *url_context(NSURL *url) {
    UIOpenURLContext *c = [UIOpenURLContext new]; c.URL = url; c.options = [UISceneOpenURLOptions new];
    return c;
}

@interface UISceneConnectionOptions ()
@property (nonatomic, readwrite, copy) NSSet *URLContexts;
@property (nonatomic, readwrite, copy) NSSet *userActivities;
@property (nonatomic, readwrite) NSString *sourceApplication, *handoffUserActivityType;
@property (nonatomic, readwrite) UIApplicationShortcutItem *shortcutItem;
@end
@implementation UISceneConnectionOptions
- (instancetype)init { if ((self = [super init])) { _URLContexts = [NSSet set]; _userActivities = [NSSet set]; } return self; }
@end

/* ================= paths and Info.plist ================= */
static NSString *isim_dir(void) {
    NSString *d = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return d;
}
static NSString *app_name(void) {
    NSBundle *b = NSBundle.mainBundle;
    return [b objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [b objectForInfoDictionaryKey:@"CFBundleName"] ?: @"App";
}
static void tell_home_screen(void) { isim_shell_request(ISIM_SHELL_SYSTEM, "reload-home", NULL, NULL); }

/* static items from Info.plist (titles localized from InfoPlist.strings) */
static NSArray<UIApplicationShortcutItem *> *static_items(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSBundle *b = NSBundle.mainBundle;
    for (NSDictionary *d in b.infoDictionary[@"UIApplicationShortcutItems"]) {
        if (![d isKindOfClass:[NSDictionary class]] || !d[@"UIApplicationShortcutItemType"]) continue;
        NSString *title = d[@"UIApplicationShortcutItemTitle"] ?: @"", *sub = d[@"UIApplicationShortcutItemSubtitle"];
        title = [b localizedStringForKey:title value:title table:@"InfoPlist"];
        if (sub) sub = [b localizedStringForKey:sub value:sub table:@"InfoPlist"];
        UIApplicationShortcutIcon *icon = nil;
        if (d[@"UIApplicationShortcutItemIconSymbolName"]) icon = [UIApplicationShortcutIcon iconWithSystemImageName:d[@"UIApplicationShortcutItemIconSymbolName"]];
        else if (d[@"UIApplicationShortcutItemIconFile"]) icon = [UIApplicationShortcutIcon iconWithTemplateImageName:d[@"UIApplicationShortcutItemIconFile"]];
        else if (d[@"UIApplicationShortcutItemIconType"] && icon_type_named(d[@"UIApplicationShortcutItemIconType"]) >= 0)
            icon = [UIApplicationShortcutIcon iconWithType:icon_type_named(d[@"UIApplicationShortcutItemIconType"])];
        [out addObject:[[UIApplicationShortcutItem alloc] initWithType:d[@"UIApplicationShortcutItemType"] localizedTitle:title localizedSubtitle:sub
                                                                  icon:icon userInfo:d[@"UIApplicationShortcutItemUserInfo"]]];
    }
    return out;
}
static NSArray<UIApplicationShortcutItem *> *dynamic_items;
static NSString *shortcuts_file(void) { return [isim_dir() stringByAppendingPathComponent:@"ShortcutItems.plist"]; }
static NSArray<UIApplicationShortcutItem *> *load_dynamic_items(void) {
    if (dynamic_items) return dynamic_items;
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in [NSDictionary dictionaryWithContentsOfFile:shortcuts_file()][@"items"]) {
        UIApplicationShortcutIcon *icon = d[@"symbol"] ? [UIApplicationShortcutIcon iconWithSystemImageName:d[@"symbol"]] : nil;
        if ([d[@"symbol"] hasPrefix:@"asset:"]) icon = [UIApplicationShortcutIcon iconWithTemplateImageName:[d[@"symbol"] substringFromIndex:6]];
        [out addObject:[[UIApplicationShortcutItem alloc] initWithType:d[@"type"] localizedTitle:d[@"title"] ?: @"" localizedSubtitle:d[@"subtitle"] icon:icon userInfo:d[@"userInfo"]]];
    }
    return dynamic_items = out;
}
static UIApplicationShortcutItem *shortcut_item_of_type(NSString *type) {
    for (UIApplicationShortcutItem *i in static_items()) if ([i.type isEqualToString:type]) return i;
    for (UIApplicationShortcutItem *i in load_dynamic_items()) if ([i.type isEqualToString:type]) return i;
    return [[UIApplicationShortcutItem alloc] initWithType:type localizedTitle:type];
}

@implementation UIApplication (UIApplicationShortcutItems)
- (NSArray<UIApplicationShortcutItem *> *)shortcutItems { return load_dynamic_items(); }
- (void)setShortcutItems:(NSArray<UIApplicationShortcutItem *> *)items {
    NSMutableArray *copies = [NSMutableArray array]; for (UIApplicationShortcutItem *i in items) [copies addObject:[i copy]];
    dynamic_items = copies;
    NSMutableArray *plist = [NSMutableArray array];
    for (UIApplicationShortcutItem *i in dynamic_items) {
        NSMutableDictionary *d = [@{ @"type": i.type ?: @"", @"title": i.localizedTitle ?: @"" } mutableCopy];
        if (i.localizedSubtitle) d[@"subtitle"] = i.localizedSubtitle;
        if (i.icon._isim_symbolName) d[@"symbol"] = i.icon._isim_symbolName;
        if (i.userInfo && [NSPropertyListSerialization propertyList:i.userInfo isValidForFormat:NSPropertyListXMLFormat_v1_0]) d[@"userInfo"] = i.userInfo;
        [plist addObject:d];
    }
    [@{ @"items": plist } writeToFile:shortcuts_file() atomically:YES];
    NSLog(@"isim: %lu dynamic quick action(s) saved for the home screen", (unsigned long)plist.count);
    tell_home_screen();
}
@end

/* ================= alternate icons ================= */
static NSDictionary *alternate_icons(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSDictionary *alts = info[@"CFBundleIcons"][@"CFBundleAlternateIcons"];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && info[@"CFBundleIcons~ipad"][@"CFBundleAlternateIcons"])
        alts = info[@"CFBundleIcons~ipad"][@"CFBundleAlternateIcons"];
    return [alts isKindOfClass:[NSDictionary class]] ? alts : @{};
}
static NSString *alt_icon_file(void) { return [isim_dir() stringByAppendingPathComponent:@"AlternateIcon.plist"]; }
@implementation UIApplication (UIAlternateApplicationIcons)
- (BOOL)supportsAlternateIcons { return alternate_icons().count > 0; }
- (NSString *)alternateIconName { return [NSDictionary dictionaryWithContentsOfFile:alt_icon_file()][@"name"]; }
- (void)setAlternateIconName:(NSString *)name completionHandler:(void (^)(NSError *))completion {
    void (^done)(NSError *) = ^(NSError *e) { if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(e); }); };
    if (name && !alternate_icons()[name]) {
        NSLog(@"isim: setAlternateIconName: no alternate icon named '%@' in CFBundleAlternateIcons", name);
        done([NSError errorWithDomain:NSCocoaErrorDomain code:4 userInfo:@{ NSLocalizedDescriptionKey: @"The file doesn’t exist." }]);
        return;
    }
    if (self.applicationState != UIApplicationStateActive) {
        done([NSError errorWithDomain:NSPOSIXErrorDomain code:35 userInfo:@{ NSLocalizedDescriptionKey: @"Resource temporarily unavailable" }]);
        return;
    }
    if ((name ?: @"").length == self.alternateIconName.length && (!name || [name isEqualToString:self.alternateIconName])) { done(nil); return; }
    if (name) [@{ @"name": name } writeToFile:alt_icon_file() atomically:YES];
    else [NSFileManager.defaultManager removeItemAtPath:alt_icon_file() error:NULL];
    NSLog(@"isim: app icon changed to %@", name ?: @"the primary icon");
    tell_home_screen();
    /* the system tells the user, like iOS */
    UIViewController *top = self.keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (top) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
            message:[NSString stringWithFormat:@"You have changed the icon for “%@”.", app_name()] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [top presentViewController:a animated:YES completion:nil];
    }
    done(nil);
}
@end

/* ================= background execution ================= */
const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid = 0;
UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsURLKey = @"UIApplicationLaunchOptionsURLKey",
    UIApplicationLaunchOptionsSourceApplicationKey = @"UIApplicationLaunchOptionsSourceApplicationKey",
    UIApplicationLaunchOptionsShortcutItemKey = @"UIApplicationLaunchOptionsShortcutItemKey",
    UIApplicationLaunchOptionsUserActivityDictionaryKey = @"UIApplicationLaunchOptionsUserActivityDictionaryKey",
    UIApplicationLaunchOptionsUserActivityTypeKey = @"UIApplicationLaunchOptionsUserActivityTypeKey",
    UIApplicationLaunchOptionsRemoteNotificationKey = @"UIApplicationLaunchOptionsRemoteNotificationKey",
    UIApplicationLaunchOptionsLocationKey = @"UIApplicationLaunchOptionsLocationKey";
NSString * const UIApplicationLaunchOptionsUserActivityKey = @"UIApplicationLaunchOptionsUserActivityKey";
UIApplicationOpenURLOptionsKey const UIApplicationOpenURLOptionsSourceApplicationKey = @"UIApplicationOpenURLOptionsSourceApplicationKey",
    UIApplicationOpenURLOptionsOpenInPlaceKey = @"UIApplicationOpenURLOptionsOpenInPlaceKey";
UIApplicationOpenExternalURLOptionsKey const UIApplicationOpenURLOptionUniversalLinksOnly = @"UIApplicationOpenURLOptionUniversalLinksOnly";
NSNotificationName const UIApplicationBackgroundRefreshStatusDidChangeNotification = @"UIApplicationBackgroundRefreshStatusDidChangeNotification";
const NSTimeInterval UIApplicationBackgroundFetchIntervalMinimum = 0, UIApplicationBackgroundFetchIntervalNever = DBL_MAX;

static NSMutableDictionary<NSNumber *, NSArray *> *bg_tasks;     /* id -> @[name, handler] */
static NSMutableSet<NSNumber *> *bg_expired;                     /* tasks whose expiration handler ran (they no longer keep the app running) */
void isim_sys_report_background(void);
static NSUInteger live_tasks(void) { NSUInteger n = 0; for (NSNumber *k in bg_tasks) if (![bg_expired containsObject:k]) n++; return n; }
static NSUInteger next_task_id = 1;
static double bg_entered;                                         /* isim_time() when the app went to the background */
static NSTimer *bg_timer;
static double bg_limit(void) { const char *e = getenv("ISIM_BACKGROUND_TASK_SECONDS"); return e && atof(e) > 0 ? atof(e) : 30; }
static void bg_expire(void) {
    bg_timer = nil;
    for (NSNumber *k in [bg_tasks.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSArray *t = bg_tasks[k];
        if (!t) continue;
        NSLog(@"isim: background task %@ (%@) expired", k, [t[0] length] ? t[0] : @"unnamed");
        if (!bg_expired) bg_expired = [NSMutableSet set];
        [bg_expired addObject:k];
        if (t.count > 1) ((void (^)(void))t[1])();
    }
    if (bg_tasks.count) NSLog(@"isim: %lu background task(s) still running after expiration (iOS would terminate the app; isim suspends it)", (unsigned long)bg_tasks.count);
    isim_sys_report_background();
}
static void bg_schedule(void) {
    [bg_timer invalidate]; bg_timer = nil;
    if (!bg_tasks.count || UIApplication.sharedApplication.applicationState != UIApplicationStateBackground) return;
    double left = bg_limit() - (isim_time() - bg_entered);
    bg_timer = [NSTimer scheduledTimerWithTimeInterval:MAX(0, left) repeats:NO block:^(NSTimer *t) { bg_expire(); }];
}
@implementation UIApplication (UIBackgroundTasks)
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:(void (^)(void))h { return [self beginBackgroundTaskWithName:nil expirationHandler:h]; }
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithName:(NSString *)name expirationHandler:(void (^)(void))h {
    if (!bg_tasks) bg_tasks = [NSMutableDictionary dictionary];
    UIBackgroundTaskIdentifier ident = next_task_id++;
    bg_tasks[@(ident)] = h ? @[name ?: @"", [h copy]] : @[name ?: @""];
    NSLog(@"isim: background task %lu (%@) began", (unsigned long)ident, name.length ? name : @"unnamed");
    bg_schedule();
    isim_sys_report_background();
    return ident;
}
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)ident {
    if (!bg_tasks[@(ident)]) return;
    [bg_tasks removeObjectForKey:@(ident)];
    [bg_expired removeObject:@(ident)];
    NSLog(@"isim: background task %lu ended", (unsigned long)ident);
    if (!bg_tasks.count) { [bg_timer invalidate]; bg_timer = nil; }
    isim_sys_report_background();
}
- (NSTimeInterval)backgroundTimeRemaining {
    if (self.applicationState != UIApplicationStateBackground) return DBL_MAX;
    return MAX(0, bg_limit() - (isim_time() - bg_entered));
}
- (UIBackgroundRefreshStatus)backgroundRefreshStatus { return UIBackgroundRefreshStatusAvailable; }
/* kept in the app's defaults so a background launch knows it (iOS's default is Never: no fetches) */
- (void)setMinimumBackgroundFetchInterval:(NSTimeInterval)i {
    [NSUserDefaults.standardUserDefaults setDouble:i forKey:@"_ISIMBackgroundFetchInterval"];
    [NSUserDefaults.standardUserDefaults synchronize];
    NSLog(@"isim: minimum background fetch interval %@ (fetches run on demand: script \"bgtask BUNDLE-ID --fetch\")", i >= UIApplicationBackgroundFetchIntervalNever ? @"never" : [NSString stringWithFormat:@"%g s", i]);
}
@end


/* ================= remote notifications, badges and background execution ================= */
/* push registration (adapted): like the Simulator (Xcode 14+), registering gives a device token, provided the app has
   the aps-environment entitlement; there is no APNs, so payloads come from `isim push`, the `push` script command or a
   .apns file dropped on the device (the home screen routes them). ISIM_PUSH_REGISTRATION=fail fails it (3010). */
static NSString *token_file(void) { return [isim_dir() stringByAppendingPathComponent:@"APNSDeviceToken"]; }
static NSString *registered_file(void) { return [isim_dir() stringByAppendingPathComponent:@"RemoteNotificationsRegistered"]; }
static BOOL has_aps_entitlement(void) {
    NSDictionary *ent = [NSDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]];
    return [ent[@"aps-environment"] isKindOfClass:[NSString class]];
}
void isim_sys_register_remote(void) {
    UIApplication *app = UIApplication.sharedApplication;
    const char *mode = getenv("ISIM_PUSH_REGISTRATION");
    NSError *e = nil;
    if (mode && !strcmp(mode, "fail"))
        e = [NSError errorWithDomain:NSCocoaErrorDomain code:3010 userInfo:@{ NSLocalizedDescriptionKey: @"remote notifications are not supported in the simulator" }];
    else if (!has_aps_entitlement())
        e = [NSError errorWithDomain:NSCocoaErrorDomain code:3000 userInfo:@{ NSLocalizedDescriptionKey: @"no valid “aps-environment” entitlement string found for application" }];
    if (e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"isim: registerForRemoteNotifications failed: %@", e.localizedDescription);
            id<UIApplicationDelegate> d = app.delegate;
            if ([d respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]) [d application:app didFailToRegisterForRemoteNotificationsWithError:e];
        });
        return;
    }
    NSData *token = [NSData dataWithContentsOfFile:token_file()];
    if (token.length != 32) {                                    /* one token per app and device data, like a real device */
        uint8_t b[32]; arc4random_buf(b, sizeof b);
        token = [NSData dataWithBytes:b length:sizeof b];
        [token writeToFile:token_file() atomically:YES];
    }
    [[NSData data] writeToFile:registered_file() atomically:YES];
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < token.length; i++) [hex appendFormat:@"%02x", ((const uint8_t *)token.bytes)[i]];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"isim: registered for remote notifications (device token %@); send one with: isim push %@ payload.apns", hex, NSBundle.mainBundle.bundleIdentifier ?: @"BUNDLE-ID");
        id<UIApplicationDelegate> d = app.delegate;
        if ([d respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]) [d application:app didRegisterForRemoteNotificationsWithDeviceToken:token];
    });
}
void isim_sys_unregister_remote(void) { [NSFileManager.defaultManager removeItemAtPath:registered_file() error:NULL]; NSLog(@"isim: unregistered for remote notifications"); }
BOOL isim_sys_remote_registered(void) { return [NSFileManager.defaultManager fileExistsAtPath:registered_file()]; }

/* the app icon badge: shown by the home screen when the app may badge (UNAuthorizationOptionBadge) */
static NSString *badge_file(void) { return [isim_dir() stringByAppendingPathComponent:@"Badge.plist"]; }
static BOOL badge_loaded; static NSInteger badge_value;
NSInteger isim_sys_badge(void) {
    if (!badge_loaded) { badge_loaded = YES; badge_value = [[NSDictionary dictionaryWithContentsOfFile:badge_file()][@"count"] integerValue]; }
    return badge_value;
}
static BOOL may_badge(void) {
    NSUserDefaults *u = NSUserDefaults.standardUserDefaults;
    NSInteger status = [u integerForKey:@"_ISIMNotificationAuthorization"], opts = [u integerForKey:@"_ISIMNotificationOptions"];
    return (status == 2 || status == 4) && (opts & 1);           /* authorized / ephemeral, with UNAuthorizationOptionBadge */
}
void isim_sys_set_badge(NSInteger n) {
    badge_loaded = YES;
    if (n == badge_value && [NSFileManager.defaultManager fileExistsAtPath:badge_file()]) return;
    if (n != 0 && !may_badge()) { NSLog(@"isim: badge %ld not shown: the app may not badge its icon (request UNAuthorizationOptionBadge)", (long)n); return; }
    badge_value = n;
    [@{ @"count": @(n) } writeToFile:badge_file() atomically:YES];
    NSLog(@"isim: app icon badge %ld", (long)n);
    char c[32]; snprintf(c, sizeof c, "%ld", (long)n);
    isim_shell_request(ISIM_SHELL_SYSTEM, "badge", NSBundle.mainBundle.bundlePath.UTF8String, c);
}

/* UserNotifications presents remote notifications and takes responses from the system UI; UIKit loads it on demand */
static void *un_symbol(const char *name) {
    void *f = dlsym(RTLD_DEFAULT, name);
    if (!f && dlopen("/System/Library/Frameworks/UserNotifications.framework/UserNotifications", RTLD_NOW)) f = dlsym(RTLD_DEFAULT, name);
    return f;
}
static BOOL has_background_mode(NSString *m) {
    NSArray *modes = NSBundle.mainBundle.infoDictionary[@"UIBackgroundModes"];
    return [modes isKindOfClass:[NSArray class]] && [modes containsObject:m];
}
/* a push payload file: { id, payload, attachments?, content? } from the home screen, or a bare payload */
static NSDictionary *read_push(NSString *file) {
    NSData *d = [NSData dataWithContentsOfFile:file];
    id j = [file.pathExtension isEqualToString:@"plist"] ? [NSDictionary dictionaryWithContentsOfFile:file] : d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL] : nil;
    if (![j isKindOfClass:[NSDictionary class]]) { NSLog(@"isim: cannot read the push payload %@", file); return nil; }
    if (![j[@"payload"] isKindOfClass:[NSDictionary class]]) j = @{ @"id": NSUUID.UUID.UUIDString, @"payload": j };
    return j;
}
static NSDictionary *launch_push;               /* ISIM_LAUNCH_URL isim-push:FILE / isim-push-open:FILE */
static BOOL launch_push_open;
/* mode 0: the running app got it, 1: launched in the background for it, 2: launched by tapping it */
static void deliver_remote(NSDictionary *w, int mode) {
    if (!w) return;
    NSDictionary *payload = w[@"payload"];
    NSDictionary *aps = [payload[@"aps"] isKindOfClass:[NSDictionary class]] ? payload[@"aps"] : @{};
    UIApplication *app = UIApplication.sharedApplication;
    BOOL bg = app.applicationState == UIApplicationStateBackground;
    NSLog(@"isim: remote notification %@ (%@)", w[@"id"], mode == 2 ? @"opened" : bg ? @"app in the background" : @"app in the foreground");
    void (*un)(NSDictionary *, int) = (void (*)(NSDictionary *, int))un_symbol("isim_un_remote_notification");
    if (un) un(w, mode);
    else NSLog(@"isim: remote notification: UserNotifications is not available");
    if (mode == 2) return;
    BOOL contentAvailable = [aps[@"content-available"] respondsToSelector:@selector(intValue)] && [aps[@"content-available"] intValue] == 1;
    if (bg && !(contentAvailable && has_background_mode(@"remote-notification"))) return;
    id<UIApplicationDelegate> d = app.delegate;
    if ([d respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
        __block UIBackgroundTaskIdentifier task = bg ? [app beginBackgroundTaskWithName:@"remote notification" expirationHandler:^{}] : UIBackgroundTaskInvalid;
        __block BOOL called = NO;
        [d application:app didReceiveRemoteNotification:payload fetchCompletionHandler:^(UIBackgroundFetchResult r) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (called) return;
                called = YES;
                NSLog(@"isim: didReceiveRemoteNotification finished (%@)", r == UIBackgroundFetchResultNewData ? @"newData" : r == UIBackgroundFetchResultNoData ? @"noData" : @"failed");
                if (task != UIBackgroundTaskInvalid) { [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; }
            });
        }];
    } else if (!bg && [d respondsToSelector:@selector(application:didReceiveRemoteNotification:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"    /* apps that only implement the iOS 3 method still get it */
        [(id)d application:app didReceiveRemoteNotification:payload];
#pragma clang diagnostic pop
    } else if (contentAvailable) NSLog(@"isim: background notification: the app delegate does not implement application(_:didReceiveRemoteNotification:fetchCompletionHandler:)");
}
/* "RECORD\x1fID\x1fACTION\x1fTEXT": a response chosen under an expanded notification (TEXT only for text input actions) */
static NSString *launch_action;
static void notification_action(NSString *args) {
    NSArray *p = [args componentsSeparatedByString:@"\x1f"];
    if (p.count < 3) return;
    void (*f)(NSString *, NSString *, NSString *, NSString *) = (void (*)(NSString *, NSString *, NSString *, NSString *))un_symbol("isim_un_notification_action");
    if (f) f(p[0], p[1], p[2], p.count > 3 ? p[3] : nil);
}

/* ---- background execution (adapted): under the shell an app in the background is suspended (SIGSTOP) a few seconds
   after it got there, unless something keeps it running: a background task (beginBackgroundTask, BackgroundTasks,
   remote notification fetches), audio playing with UIBackgroundModes audio and a playback session category, location
   updates with UIBackgroundModes location and allowsBackgroundLocationUpdates, transfers of a background URLSession
   (Foundation: running tasks, or events not handled yet). The app reports these reasons to the
   shell ("bg-assert"); frameworks answer the _IsimBackgroundQuery notification (AVFoundation: the session category,
   CoreLocation: background updates and the blue indicator). */
static NSString *last_reasons;
static NSTimer *reasons_timer;
static NSDictionary *query_frameworks(void) {
    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimBackgroundQuery" object:q];
    return q;
}
/* audio keeps playing in the background: UIBackgroundModes audio and a playback category (AVAudioSession) */
BOOL isim_sys_background_audio(void) {
    if (!has_background_mode(@"audio")) return NO;
    NSString *cat = query_frameworks()[@"audioCategory"];
    return [@[@"AVAudioSessionCategoryPlayback", @"AVAudioSessionCategoryPlayAndRecord", @"AVAudioSessionCategoryMultiRoute"] containsObject:cat ?: @""];
}
static NSUInteger live_tasks(void);
void isim_sys_report_background(void) {
    if (!isim_shell_present() || UIApplication.sharedApplication.applicationState != UIApplicationStateBackground) return;
    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"dev.isim.springboard"]) return;      /* the home screen is never suspended */
    NSMutableArray *r = [NSMutableArray array];
    NSDictionary *q = query_frameworks();
    if (live_tasks()) [r addObject:@"task"];
    if (isim_sys_background_audio() && isim_audio_active() > 0) [r addObject:@"audio"];
    if ([q[@"location"] boolValue]) [r addObject:[q[@"locationIndicator"] boolValue] ? @"location-indicator" : @"location"];
    if ([q[@"transfer"] boolValue]) [r addObject:@"transfer"];
    NSString *s = [r componentsJoinedByString:@","];
    if ([s isEqualToString:last_reasons]) return;
    last_reasons = s;
    NSLog(@"isim: running in the background: %@", s.length ? s : @"nothing (the app can be suspended)");
    isim_shell_request(ISIM_SHELL_SYSTEM, "bg-assert", s.UTF8String, NULL);
}
/* a background URLSession finished while the app was in the background (Foundation): the app delegate's
   handleEventsForBackgroundURLSession, then the session delivers its held events */
static void background_session_events(NSNotification *n) {
    NSString *ident = n.object;
    void (^done)(void) = n.userInfo[@"completion"], (^deliver)(void) = n.userInfo[@"deliver"];
    id<UIApplicationDelegate> d = UIApplication.sharedApplication.delegate;
    if ([d respondsToSelector:@selector(application:handleEventsForBackgroundURLSession:completionHandler:)]) {
        NSLog(@"isim: application:handleEventsForBackgroundURLSession: %@", ident);
        [d application:UIApplication.sharedApplication handleEventsForBackgroundURLSession:ident completionHandler:^{ if (done) done(); }];
    } else if (done) done();
    if (deliver) deliver();
}
__attribute__((constructor)) static void background_session_observer(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimBackgroundURLSessionEvents" object:nil queue:nil usingBlock:^(NSNotification *n) { background_session_events(n); }];
    });
}
static void reasons_start(void) {
    [reasons_timer invalidate];
    last_reasons = nil;
    isim_sys_report_background();
    reasons_timer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) { isim_sys_report_background(); }];
}
static void reasons_stop(void) { [reasons_timer invalidate]; reasons_timer = nil; last_reasons = nil; }

/* ================= multiple scenes ================= */
/* UIApplication (UIMultipleScenes): UIApplication.m */

/* ================= user activities on responders ================= */
static char kActivity;
@implementation UIResponder (UIActivityContinuation)
- (NSUserActivity *)userActivity { return objc_getAssociatedObject(self, &kActivity); }
- (void)setUserActivity:(NSUserActivity *)a {
    objc_setAssociatedObject(self, &kActivity, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!a) return;
    __weak UIResponder *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{               /* UIKit makes the responder's activity current */
        UIResponder *r = weakSelf;
        if (!r || r.userActivity != a) return;
        if (a.needsSave || [r respondsToSelector:@selector(updateUserActivityState:)]) [r updateUserActivityState:a];
        [a becomeCurrent];
    });
}
- (void)updateUserActivityState:(NSUserActivity *)a { a.needsSave = NO; }
- (void)restoreUserActivityState:(NSUserActivity *)a {}
@end

/* ================= launch payloads and continuations ================= */
static NSString *const kContinueNote = @"_IsimContinueUserActivity";     /* SwiftUI .onContinueUserActivity */

static NSUserActivity *activity_from_marker(NSString *s) {
    if ([s hasPrefix:@"isim-activity:"]) {
        NSString *path = [s substringFromIndex:14];
        NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:path];
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        return [NSUserActivity _isim_activityWithPlist:p];
    }
    if ([s hasPrefix:@"isim-universal:"]) {
        NSUserActivity *a = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
        a.webpageURL = [NSURL URLWithString:[s substringFromIndex:15]];
        return a.webpageURL ? a : nil;
    }
    return nil;
}

/* the launch payload (ISIM_LAUNCH_URL), parsed once */
static NSString *launch_url;
static UIApplicationShortcutItem *launch_shortcut;
static NSUserActivity *launch_activity;
static BOOL launch_parsed, scene_based, launch_finished_yes = YES;
static void parse_launch(void) {
    if (launch_parsed) return;
    launch_parsed = YES;
    const char *u = getenv("ISIM_LAUNCH_URL");
    if (!u || !*u) return;
    NSString *s = @(u);
    if ([s hasPrefix:@"isim-shortcut:"]) launch_shortcut = shortcut_item_of_type([s substringFromIndex:14]);
    else if ([s hasPrefix:@"isim-activity:"] || [s hasPrefix:@"isim-universal:"]) launch_activity = activity_from_marker(s);
    else if ([s hasPrefix:@"isim-push:"]) launch_push = read_push([s substringFromIndex:10]);
    else if ([s hasPrefix:@"isim-push-open:"]) { launch_push = read_push([s substringFromIndex:15]); launch_push_open = YES; }
    else if ([s hasPrefix:@"isim-nc-action:"]) launch_action = [s substringFromIndex:15];
    else if ([s hasPrefix:@"isim-"]) {}                          /* isim-bgtask:... (background launch) */
    else launch_url = s;
}
NSDictionary *isim_sys_launch_options(void) {
    parse_launch();
    NSMutableDictionary *o = [NSMutableDictionary dictionary];
    if (launch_shortcut) o[UIApplicationLaunchOptionsShortcutItemKey] = launch_shortcut;
    if (launch_activity) o[UIApplicationLaunchOptionsUserActivityDictionaryKey] = @{ UIApplicationLaunchOptionsUserActivityTypeKey: launch_activity.activityType,
                                                                                     UIApplicationLaunchOptionsUserActivityKey: launch_activity };
    if (launch_url) { NSURL *url = [NSURL URLWithString:launch_url]; if (url) o[UIApplicationLaunchOptionsURLKey] = url; }
    if (launch_push[@"payload"]) o[UIApplicationLaunchOptionsRemoteNotificationKey] = launch_push[@"payload"];
    if (launch_shortcut || launch_activity || launch_url || launch_push) NSLog(@"isim: launch options %@", [o.allKeys componentsJoinedByString:@", "]);
    return o.count ? o : nil;
}
void isim_sys_did_finish_launching(BOOL result) { launch_finished_yes = result; }

/* state restoration: the activity saved for the scene, unless the app was closed in the app switcher */
static NSString *scene_state_file(void) { return [isim_dir() stringByAppendingPathComponent:@"SceneState.plist"]; }
static NSUserActivity *saved_scene_activity(void) {
    return [NSUserActivity _isim_activityWithPlist:[NSDictionary dictionaryWithContentsOfFile:scene_state_file()][@"activity"]];
}
void isim_sys_configure_connection(UISceneConnectionOptions *options, UISceneSession *session) {
    parse_launch();
    scene_based = YES;
    if (launch_shortcut) options.shortcutItem = launch_shortcut;
    if (launch_activity) { options.userActivities = [NSSet setWithObject:launch_activity]; options.handoffUserActivityType = launch_activity.activityType; }
    if (launch_url) { NSURL *url = [NSURL URLWithString:launch_url]; if (url) options.URLContexts = [NSSet setWithObject:url_context(url)]; }
    session.stateRestorationActivity = saved_scene_activity();
    if (session.stateRestorationActivity) NSLog(@"isim: restoring scene state (%@)", session.stateRestorationActivity.activityType);
}
/* a scene connected for a user activity (requestSceneSessionActivation, UIApplication.m) */
void isim_sys_connection_activity(UISceneConnectionOptions *options, NSUserActivity *activity) {
    if (!activity) return;
    options.userActivities = [NSSet setWithObject:activity];
    options.handoffUserActivityType = activity.activityType;
}
void isim_sys_scene_connected(UIScene *scene) {
    NSUserActivity *a = scene.session.stateRestorationActivity;
    id<UISceneDelegate> sd = scene.delegate;
    if (a && [sd respondsToSelector:@selector(scene:restoreInteractionStateWithUserActivity:)]) [sd scene:scene restoreInteractionStateWithUserActivity:a];
    if (a) [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimRestoreSceneState" object:a];
}

/* continue an activity in the running app: scene delegates, else the app delegate; SwiftUI handlers via a notification */
static void continue_activity(NSUserActivity *a, BOOL launch) {
    if (!a) return;
    NSLog(@"isim: continuing user activity %@%@%@", a.activityType, a.webpageURL ? @" " : @"", a.webpageURL.absoluteString ?: @"");
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    BOOL handled = NO;
    if (!launch) for (UIScene *s in app.connectedScenes) {
        id<UISceneDelegate> sd = s.delegate;
        if ([sd respondsToSelector:@selector(scene:willContinueUserActivityWithType:)]) [sd scene:s willContinueUserActivityWithType:a.activityType];
        if ([sd respondsToSelector:@selector(scene:continueUserActivity:)]) { [sd scene:s continueUserActivity:a]; handled = YES; }
    }
    if (!handled && !scene_based && (!launch || launch_finished_yes)) {
        if ([d respondsToSelector:@selector(application:willContinueUserActivityWithType:)]) [d application:app willContinueUserActivityWithType:a.activityType];
        if ([d respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)])
            [d application:app continueUserActivity:a restorationHandler:^(NSArray *objects) { for (id<UIUserActivityRestoring> o in objects) [o restoreUserActivityState:a]; }];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:kContinueNote object:a];
}
static void perform_shortcut(UIApplicationShortcutItem *item, BOOL launch) {
    if (!item) return;
    NSLog(@"isim: quick action %@ (“%@”)", item.type, item.localizedTitle);
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    BOOL handled = NO;
    if (!launch) for (UIScene *s in app.connectedScenes) {
        id sd = s.delegate;
        if ([s isKindOfClass:[UIWindowScene class]] && [sd respondsToSelector:@selector(windowScene:performActionForShortcutItem:completionHandler:)]) {
            [sd windowScene:(UIWindowScene *)s performActionForShortcutItem:item completionHandler:^(BOOL ok) { NSLog(@"isim: quick action handled: %d", ok); }];
            handled = YES;
        }
    }
    if (!handled && !scene_based && (!launch || launch_finished_yes) && [d respondsToSelector:@selector(application:performActionForShortcutItem:completionHandler:)])
        [d application:app performActionForShortcutItem:item completionHandler:^(BOOL ok) { NSLog(@"isim: quick action handled: %d", ok); }];
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimShortcutItem" object:item];
}
static void open_url_in_scenes(NSURL *url) {
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        id<UISceneDelegate> sd = s.delegate;
        if ([sd respondsToSelector:@selector(scene:openURLContexts:)]) [sd scene:s openURLContexts:[NSSet setWithObject:url_context(url)]];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimOpenURL" object:url];        /* SwiftUI .onOpenURL */
}

/* the one continuation path (universal links from UIUniversalLinks.m, Spotlight, markers) */
void isim_sys_continue_activity(NSUserActivity *a) { continue_activity(a, NO); }

/* after didFinishLaunching (and the scene connection): deliver the launch payload. Returns YES if UIApplication.m
   should not deliver ISIM_LAUNCH_URL itself. */
BOOL isim_sys_deliver_launch(void) {
    parse_launch();
    if (launch_shortcut) { UIApplicationShortcutItem *i = launch_shortcut; dispatch_async(dispatch_get_main_queue(), ^{ perform_shortcut(i, YES); }); return YES; }
    if (launch_activity) { NSUserActivity *a = launch_activity; dispatch_async(dispatch_get_main_queue(), ^{ continue_activity(a, YES); }); return YES; }
    if (launch_push) { NSDictionary *w = launch_push; int m = launch_push_open ? 2 : 0; dispatch_async(dispatch_get_main_queue(), ^{ deliver_remote(w, m); }); return YES; }
    if (launch_action) { NSString *a = launch_action; dispatch_async(dispatch_get_main_queue(), ^{ notification_action(a); }); return YES; }
    if (launch_url && scene_based) {      /* scene apps get the URL in the connection options (scene(_:willConnectTo:options:)) */
        NSURL *url = [NSURL URLWithString:launch_url];
        dispatch_async(dispatch_get_main_queue(), ^{ NSLog(@"isim: opening URL %@ in the app", url); [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimOpenURL" object:url]; });
        return YES;
    }
    const char *u = getenv("ISIM_LAUNCH_URL");
    return u && !strncmp(u, "isim-", 5);              /* other markers (background launches) are not URLs to open */
}

/* a URL delivered to the running app (EV_OPEN_URL); returns YES when handled here */
BOOL isim_sys_open_url(NSString *s) {
    if ([s hasPrefix:@"isim-shortcut:"]) { perform_shortcut(shortcut_item_of_type([s substringFromIndex:14]), NO); return YES; }
    if ([s hasPrefix:@"isim-activity:"] || [s hasPrefix:@"isim-universal:"]) { continue_activity(activity_from_marker(s), NO); return YES; }
    if ([s hasPrefix:@"isim-bgtask:"] || [s hasPrefix:@"isim-push"] || [s hasPrefix:@"isim-nc-action:"]) return YES;
    NSURL *url = [NSURL URLWithString:s];
    if (!url) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) return NO;   /* web URLs: UIUniversalLinks.m */
    BOOL sceneHandles = NO;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) if ([sc.delegate respondsToSelector:@selector(scene:openURLContexts:)]) sceneHandles = YES;
    if (!sceneHandles) return NO;                                /* the app delegate's application(_:open:options:) */
    NSLog(@"isim: opening URL %@ in the app", s);
    open_url_in_scenes(url);
    return YES;
}

/* ---- background tasks (BackgroundTasks framework requests, saved by the app in Library/isim/BackgroundTaskRequests.plist) ---- */
static void run_background_task(NSString *ident) {
    UIApplication *app = UIApplication.sharedApplication;
    if ([ident isEqualToString:@"--fetch"]) {                    /* UIKit background fetch */
        id<UIApplicationDelegate> d = app.delegate;
        /* like iOS: only with UIBackgroundModes fetch and a minimum interval other than Never (the default) */
        if (![NSBundle.mainBundle.infoDictionary[@"UIBackgroundModes"] containsObject:@"fetch"]) { NSLog(@"isim: background fetch: no UIBackgroundModes fetch in Info.plist"); return; }
        NSNumber *interval = [NSUserDefaults.standardUserDefaults objectForKey:@"_ISIMBackgroundFetchInterval"];
        if (!interval || interval.doubleValue >= UIApplicationBackgroundFetchIntervalNever) { NSLog(@"isim: background fetch: the minimum interval is never (setMinimumBackgroundFetchInterval)"); return; }
        if ([d respondsToSelector:@selector(application:performFetchWithCompletionHandler:)]) {
            NSLog(@"isim: background fetch");
            __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithName:@"background fetch" expirationHandler:^{}];
            [d application:app performFetchWithCompletionHandler:^(UIBackgroundFetchResult r) {
                NSLog(@"isim: background fetch finished (%lu)", (unsigned long)r);
                dispatch_async(dispatch_get_main_queue(), ^{ if (task != UIBackgroundTaskInvalid) { [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; } });
            }];
        } else NSLog(@"isim: background fetch: the app delegate does not implement application(_:performFetchWithCompletionHandler:)");
        return;
    }
    NSString *f = [isim_dir() stringByAppendingPathComponent:@"BackgroundTaskRequests.plist"];
    NSMutableArray *reqs = [[NSDictionary dictionaryWithContentsOfFile:f][@"requests"] mutableCopy];
    NSDictionary *req = nil;
    for (NSDictionary *r in reqs) if ([r[@"identifier"] isEqual:ident]) { req = r; break; }
    if (!req) { NSLog(@"isim: background task %@: no pending request (submit a BGTaskRequest first)", ident); return; }
    [reqs removeObject:req];
    [@{ @"requests": reqs } writeToFile:f atomically:YES];
    NSLog(@"isim: launching background task %@ (%@)", ident, req[@"kind"] ?: @"refresh");
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimBackgroundTaskLaunch" object:ident userInfo:req];
}
BOOL isim_sys_background_launch(void) { const char *e = getenv("ISIM_LAUNCH_BACKGROUND"); return e && *e == '1'; }
void isim_sys_after_background_launch(void) {
    bg_entered = isim_time();
    parse_launch();
    const char *u = getenv("ISIM_LAUNCH_URL");
    if (u && !strncmp(u, "isim-bgtask:", 12)) { NSString *ident = @(u + 12); dispatch_async(dispatch_get_main_queue(), ^{ run_background_task(ident); }); }
    if (launch_push) { NSDictionary *w = launch_push; dispatch_async(dispatch_get_main_queue(), ^{ deliver_remote(w, 1); }); }
    if (launch_action) { NSString *a = launch_action; dispatch_async(dispatch_get_main_queue(), ^{ notification_action(a); }); }
    dispatch_async(dispatch_get_main_queue(), ^{ reasons_start(); });
}

/* ---- lifecycle ---- */
void isim_sys_mark_background(void) { bg_entered = isim_time(); }
void isim_sys_entered_background(void) {
    bg_schedule();
    reasons_start();
    /* state restoration: ask each scene for its activity */
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        id<UISceneDelegate> sd = s.delegate;
        if (![sd respondsToSelector:@selector(stateRestorationActivityForScene:)]) continue;
        NSUserActivity *a = [sd stateRestorationActivityForScene:s];
        s.session.stateRestorationActivity = a;
        if (a) { [@{ @"activity": [a _isim_plist] } writeToFile:scene_state_file() atomically:YES]; NSLog(@"isim: saved scene state (%@)", a.activityType); }
        else [NSFileManager.defaultManager removeItemAtPath:scene_state_file() error:NULL];
    }
    extern void isim_ui_scenes_save(void);
    isim_ui_scenes_save();
    extern void isim_ui_save_restoration_state(void);
    isim_ui_save_restoration_state();                   /* view controller state restoration (apps without scenes) */                              /* the open sessions (multiple scenes) with their state */
}
void isim_sys_entered_foreground(void) { [bg_timer invalidate]; bg_timer = nil; [bg_expired removeAllObjects]; reasons_stop(); }

/* EV_SYSTEM: "<verb> <arguments>" from the shell */
void isim_sys_event(const char *text) {
    NSString *t = @(text), *verb = t, *args = @"";
    NSRange sp = [t rangeOfString:@" "];
    if (sp.location != NSNotFound) { verb = [t substringToIndex:sp.location]; args = [t substringFromIndex:sp.location + 1]; }
    if ([verb isEqualToString:@"bgtask"]) run_background_task(args);
    else if ([verb isEqualToString:@"remote-notification"]) deliver_remote(read_push(args), 0);
    else if ([verb isEqualToString:@"nc-action"]) notification_action(args);
    else if ([verb isEqualToString:@"appearance"] || [verb isEqualToString:@"contrast"] || [verb isEqualToString:@"boldtext"]) {
        /* script "appearance light|dark", "contrast on|off", "boldtext on|off": the device setting, written to the global
           domain like Settings does (every app re-reads it), applied live */
        NSUserDefaults *g = [[NSUserDefaults alloc] initWithSuiteName:@".GlobalPreferences"];
        BOOL on = [args isEqualToString:@"dark"] || [args isEqualToString:@"on"];
        if ([verb isEqualToString:@"appearance"]) {
            unsetenv("ISIM_APPEARANCE");
            if (on) [g setObject:@"Dark" forKey:@"AppleInterfaceStyle"]; else [g removeObjectForKey:@"AppleInterfaceStyle"];
        } else {
            NSString *key = [verb isEqualToString:@"contrast"] ? @"ISIMIncreaseContrast" : @"ISIMBoldText";
            unsetenv([verb isEqualToString:@"contrast"] ? "ISIM_INCREASE_CONTRAST" : "ISIM_BOLD_TEXT");
            if (on) [g setBool:YES forKey:key]; else [g removeObjectForKey:key];
        }
        NSLog(@"isim: %@ %@", verb, args);
    }
    else if ([verb isEqualToString:@"memory-warning"]) {           /* Debug > Simulate Memory Warning */
        /* like iOS, memory-pressure dispatch sources hear it first (level: warn, critical or normal); warn and
           critical then reach the app delegate, the notification and the view controllers */
        extern void isim_ui_memory_warning(void);
        extern void isim_dispatch_memory_pressure(unsigned long level);
        unsigned long level = [args isEqualToString:@"critical"] ? 4 : [args isEqualToString:@"normal"] ? 1 : 2;
        isim_dispatch_memory_pressure(level);
        if (level != 1) isim_ui_memory_warning();
    }
    else if ([verb isEqualToString:@"discard-scenes"]) {          /* closed in the app switcher: no state restoration next time */
        [NSFileManager.defaultManager removeItemAtPath:scene_state_file() error:NULL];
        extern void isim_ui_discard_restoration_state(void);
        isim_ui_discard_restoration_state();
        extern void isim_ui_scenes_discarded(void);
        isim_ui_scenes_discarded();
        NSLog(@"isim: scene sessions discarded");
    } else [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimSystemEvent" object:t];
}

/* ---- snapshots (widgets and Live Activities are rendered this way by WidgetKit) ---- */
@implementation UIView (UISnapshotting)
- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates {
    if (afterUpdates) { [self setNeedsLayout]; [self layoutIfNeeded]; }            /* pending layout first (offscreen trees too) */
    CGRect f = self.frame;
    CGSize b = self.bounds.size;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx || b.width <= 0 || b.height <= 0) return NO;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(ctx, rect.size.width / b.width, rect.size.height / b.height);
    CGContextTranslateCTM(ctx, -f.origin.x, -f.origin.y);                         /* _isim_render draws at the view's frame origin */
    [self _isim_render];
    CGContextRestoreGState(ctx);
    return YES;
}
- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)after {
    CGSize b = self.bounds.size;
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, b.width, b.height)];
    if (b.width <= 0 || b.height <= 0) return iv;
    UIGraphicsBeginImageContextWithOptions(b, NO, UIScreen.mainScreen.scale);
    [self drawViewHierarchyInRect:CGRectMake(0, 0, b.width, b.height) afterScreenUpdates:after];
    iv.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return iv;
}
- (UIView *)resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)after withCapInsets:(UIEdgeInsets)caps {
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, rect.size.width, rect.size.height)];
    CGSize b = self.bounds.size;
    if (rect.size.width <= 0 || rect.size.height <= 0 || b.width <= 0 || b.height <= 0) return iv;
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, UIScreen.mainScreen.scale);
    [self drawViewHierarchyInRect:CGRectMake(-rect.origin.x, -rect.origin.y, b.width, b.height) afterScreenUpdates:after];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    iv.image = UIEdgeInsetsEqualToEdgeInsets(caps, UIEdgeInsetsZero) ? img : [img resizableImageWithCapInsets:caps];
    return iv;
}
@end

/* ---- opening URLs in other apps (custom schemes, universal links), under the shell ---- */
NSString *isim_ui_installed_apps_dir(void);
NSString *isim_ui_system_apps_dir(void);
static BOOL installed_app_handles(NSURL *url, BOOL *universal) {
    NSString *scheme = url.scheme.lowercaseString ?: @"", *host = url.host.lowercaseString ?: @"";
    *universal = NO;
    NSString *me = NSBundle.mainBundle.bundleIdentifier;
    for (NSString *dir in @[isim_ui_installed_apps_dir(), isim_ui_system_apps_dir()])
        for (NSString *n in [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL]) {
            if (![n hasSuffix:@".app"]) continue;
            NSString *app = [dir stringByAppendingPathComponent:n];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Info.plist"]];
            if ([scheme isEqualToString:@"https"]) {
                if ([info[@"CFBundleIdentifier"] isEqual:me]) continue;       /* a universal link to the app itself opens in the browser */
                NSDictionary *ent = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"]];
                for (NSString *d in ent[@"com.apple.developer.associated-domains"]) {
                    if (![d hasPrefix:@"applinks:"]) continue;
                    NSString *h = [[d substringFromIndex:9] componentsSeparatedByString:@"?"].firstObject.lowercaseString;
                    if ([h hasPrefix:@"*."] ? ([host hasSuffix:[h substringFromIndex:1]] || [host isEqualToString:[h substringFromIndex:2]]) : [h isEqualToString:host]) { *universal = YES; return YES; }
                }
                continue;
            }
            for (NSDictionary *t in info[@"CFBundleURLTypes"]) for (NSString *s in t[@"CFBundleURLSchemes"]) if ([s.lowercaseString isEqualToString:scheme]) return YES;
        }
    return NO;
}
BOOL isim_sys_can_open_url(NSURL *url) { BOOL u; return isim_shell_present() && installed_app_handles(url, &u) && !u; }
/* returns YES when the URL went to another app (or failed as universal-links-only) */
BOOL isim_sys_route_url(NSURL *url, NSDictionary *options, void (^completion)(BOOL)) {
    if (!isim_shell_present() || !url) return NO;
    BOOL universal = NO, handled = installed_app_handles(url, &universal);
    BOOL onlyUniversal = [options[UIApplicationOpenURLOptionUniversalLinksOnly] boolValue];
    if (!handled && !onlyUniversal) return NO;
    if (handled) {
        NSLog(@"isim: open URL %@ in another app%@", url.absoluteString, universal ? @" (universal link)" : @"");
        isim_shell_request(ISIM_SHELL_SYSTEM, "openurl", NULL, url.absoluteString.UTF8String);
    } else NSLog(@"isim: open URL %@: no app handles it as a universal link", url.absoluteString);
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(handled); });
    return YES;
}
