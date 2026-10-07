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
 *   background (ISIM_LAUNCH_BACKGROUND) and BackgroundTasks launches ("bgtask ID" from the shell, for submitted requests).
 * - Alternate app icons (Library/isim/AlternateIcon.plist), with the system alert.
 * UIApplication.m calls the isim_sys_* hooks at launch, on URL/system events and on lifecycle changes. */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#include <float.h>
#include <stdlib.h>

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
        if (t.count > 1) ((void (^)(void))t[1])();
    }
    if (bg_tasks.count) NSLog(@"isim: %lu background task(s) still running after expiration (iOS would terminate the app; isim keeps it)", (unsigned long)bg_tasks.count);
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
    return ident;
}
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)ident {
    if (!bg_tasks[@(ident)]) return;
    [bg_tasks removeObjectForKey:@(ident)];
    NSLog(@"isim: background task %lu ended", (unsigned long)ident);
    if (!bg_tasks.count) { [bg_timer invalidate]; bg_timer = nil; }
}
- (NSTimeInterval)backgroundTimeRemaining {
    if (self.applicationState != UIApplicationStateBackground) return DBL_MAX;
    return MAX(0, bg_limit() - (isim_time() - bg_entered));
}
- (UIBackgroundRefreshStatus)backgroundRefreshStatus { return UIBackgroundRefreshStatusAvailable; }
- (void)setMinimumBackgroundFetchInterval:(NSTimeInterval)i { NSLog(@"isim: minimum background fetch interval %g (fetches run on demand: script \"bgtask BUNDLE-ID --fetch\")", i); }
@end

/* ================= multiple scenes ================= */
@implementation UIApplication (UIMultipleScenes)
- (void)requestSceneSessionActivation:(UISceneSession *)session userActivity:(NSUserActivity *)activity options:(id)options errorHandler:(void (^)(NSError *))errorHandler {
    NSLog(@"isim: requestSceneSessionActivation: isim shows one scene per app (activity %@)", activity.activityType ?: @"none");
    if (errorHandler) {
        NSError *e = [NSError errorWithDomain:@"UISceneErrorDomain" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"The application does not support multiple scenes." }];
        dispatch_async(dispatch_get_main_queue(), ^{ errorHandler(e); });
    }
}
- (void)requestSceneSessionDestruction:(UISceneSession *)session options:(id)options errorHandler:(void (^)(NSError *))errorHandler {
    NSLog(@"isim: requestSceneSessionDestruction: ignored (the app's only scene stays)");
}
- (void)requestSceneSessionRefresh:(UISceneSession *)session {}
@end

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
    if (launch_shortcut || launch_activity || launch_url) NSLog(@"isim: launch options %@", [o.allKeys componentsJoinedByString:@", "]);
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
    if ([s hasPrefix:@"isim-bgtask:"]) return YES;
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
        if ([d respondsToSelector:@selector(application:performFetchWithCompletionHandler:)]) {
            NSLog(@"isim: background fetch");
            [d application:app performFetchWithCompletionHandler:^(UIBackgroundFetchResult r) { NSLog(@"isim: background fetch finished (%lu)", (unsigned long)r); }];
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
    const char *u = getenv("ISIM_LAUNCH_URL");
    if (u && !strncmp(u, "isim-bgtask:", 12)) { NSString *ident = @(u + 12); dispatch_async(dispatch_get_main_queue(), ^{ run_background_task(ident); }); }
}

/* ---- lifecycle ---- */
void isim_sys_mark_background(void) { bg_entered = isim_time(); }
void isim_sys_entered_background(void) {
    bg_schedule();
    /* state restoration: ask each scene for its activity */
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        id<UISceneDelegate> sd = s.delegate;
        if (![sd respondsToSelector:@selector(stateRestorationActivityForScene:)]) continue;
        NSUserActivity *a = [sd stateRestorationActivityForScene:s];
        s.session.stateRestorationActivity = a;
        if (a) { [@{ @"activity": [a _isim_plist] } writeToFile:scene_state_file() atomically:YES]; NSLog(@"isim: saved scene state (%@)", a.activityType); }
        else [NSFileManager.defaultManager removeItemAtPath:scene_state_file() error:NULL];
    }
}
void isim_sys_entered_foreground(void) { [bg_timer invalidate]; bg_timer = nil; }

/* EV_SYSTEM: "<verb> <arguments>" from the shell */
void isim_sys_event(const char *text) {
    NSString *t = @(text), *verb = t, *args = @"";
    NSRange sp = [t rangeOfString:@" "];
    if (sp.location != NSNotFound) { verb = [t substringToIndex:sp.location]; args = [t substringFromIndex:sp.location + 1]; }
    if ([verb isEqualToString:@"bgtask"]) run_background_task(args);
    else if ([verb isEqualToString:@"discard-scenes"]) {          /* closed in the app switcher: no state restoration next time */
        [NSFileManager.defaultManager removeItemAtPath:scene_state_file() error:NULL];
        NSLog(@"isim: scene sessions discarded");
    } else [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimSystemEvent" object:t];
}

/* ---- snapshots (widgets and Live Activities are rendered this way by WidgetKit) ---- */
@implementation UIView (UISnapshotting)
- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates {
    if (afterUpdates) { [self setNeedsLayout]; [self layoutIfNeeded]; }
    CGRect f = self.frame;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return NO;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
    if (f.size.width > 0 && f.size.height > 0) CGContextScaleCTM(ctx, rect.size.width / f.size.width, rect.size.height / f.size.height);
    CGContextTranslateCTM(ctx, -f.origin.x, -f.origin.y);
    [self _isim_render];
    CGContextRestoreGState(ctx);
    return YES;
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
