/* isim UserNotifications: local notifications (see the SDK header for what isim covers).
 *
 * State per app (NSUserDefaults, i.e. the app container): the authorization answer and the pending requests,
 * so requests survive relaunches. Triggers are timers on the main queue while the app runs. When one fires and
 * the app is in the foreground, the delegate's willPresent decides the presentation; a banner slides in at the
 * top (tap: didReceive with the default action, swipe up: dismiss). In the background under `isim boot` the
 * shell shows the banner over the home screen or the app in front; tapping it brings this app to the front
 * and calls didReceive. Apps that are not running do not get their notifications (no system scheduler).
 * Automation: ISIM_NOTIFICATION_PERMISSION=allow|deny answers the permission prompt without the alert. */
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>
#include <isim_host.h>
#include <time.h>

NSString * const UNErrorDomain = @"UNErrorDomain";
NSString * const UNNotificationDefaultActionIdentifier = @"com.apple.UNNotificationDefaultActionIdentifier";
NSString * const UNNotificationDismissActionIdentifier = @"com.apple.UNNotificationDismissActionIdentifier";

/* ---------------- model ---------------- */

@interface UNNotificationSound ()
@property (nonatomic, copy, nullable) NSString *isimName;
@property (nonatomic) BOOL isimCritical;
@end
@implementation UNNotificationSound
+ (UNNotificationSound *)defaultSound { return [super new]; }
+ (UNNotificationSound *)defaultCriticalSound { UNNotificationSound *s = [super new]; s.isimCritical = YES; return s; }
+ (instancetype)soundNamed:(UNNotificationSoundName)name { UNNotificationSound *s = [super new]; s.isimName = name; return s; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<UNNotificationSound: %@>", _isimName ?: @"default"]; }
@end

@implementation UNNotificationAttachment
+ (instancetype)attachmentWithIdentifier:(NSString *)identifier URL:(NSURL *)URL options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    if (error) *error = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeAttachmentInvalidURL
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Notification attachments are not supported on isim." }];
    return nil;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

#define CONTENT_FIELDS \
    NSString *_title, *_subtitle, *_body, *_categoryIdentifier, *_threadIdentifier, *_launchImageName, *_targetContentIdentifier, *_summaryArgument, *_filterCriteria; \
    NSNumber *_badge; UNNotificationSound *_sound; NSDictionary *_userInfo; NSArray *_attachments; NSUInteger _summaryArgumentCount; \
    UNNotificationInterruptionLevel _interruptionLevel; double _relevanceScore;

@implementation UNNotificationContent { @protected CONTENT_FIELDS }
- (instancetype)init {
    if ((self = [super init])) {
        _title = _subtitle = _body = _categoryIdentifier = _threadIdentifier = _launchImageName = _summaryArgument = @"";
        _userInfo = @{}; _attachments = @[]; _interruptionLevel = UNNotificationInterruptionLevelActive;
    }
    return self;
}
- (NSString *)title { return _title; }
- (NSString *)subtitle { return _subtitle; }
- (NSString *)body { return _body; }
- (NSNumber *)badge { return _badge; }
- (UNNotificationSound *)sound { return _sound; }
- (NSDictionary *)userInfo { return _userInfo; }
- (NSString *)categoryIdentifier { return _categoryIdentifier; }
- (NSString *)threadIdentifier { return _threadIdentifier; }
- (NSString *)launchImageName { return _launchImageName; }
- (NSString *)targetContentIdentifier { return _targetContentIdentifier; }
- (NSString *)summaryArgument { return _summaryArgument; }
- (NSUInteger)summaryArgumentCount { return _summaryArgumentCount; }
- (NSArray *)attachments { return _attachments; }
- (UNNotificationInterruptionLevel)interruptionLevel { return _interruptionLevel; }
- (double)relevanceScore { return _relevanceScore; }
- (NSString *)filterCriteria { return _filterCriteria; }
- (void)isim_copyTo:(UNNotificationContent *)c {
    c->_title = _title; c->_subtitle = _subtitle; c->_body = _body; c->_badge = _badge; c->_sound = _sound; c->_userInfo = _userInfo;
    c->_categoryIdentifier = _categoryIdentifier; c->_threadIdentifier = _threadIdentifier; c->_launchImageName = _launchImageName;
    c->_targetContentIdentifier = _targetContentIdentifier; c->_summaryArgument = _summaryArgument; c->_summaryArgumentCount = _summaryArgumentCount;
    c->_attachments = _attachments; c->_interruptionLevel = _interruptionLevel; c->_relevanceScore = _relevanceScore; c->_filterCriteria = _filterCriteria;
}
- (id)copyWithZone:(NSZone *)zone {
    if ([self isMemberOfClass:[UNNotificationContent class]]) return self;
    UNNotificationContent *c = [[UNNotificationContent alloc] init]; [self isim_copyTo:c]; return c;
}
- (id)mutableCopyWithZone:(NSZone *)zone { UNMutableNotificationContent *c = [[UNMutableNotificationContent alloc] init]; [self isim_copyTo:c]; return c; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@: title: %@, body: %@>", NSStringFromClass(self.class), _title, _body]; }
@end

@implementation UNMutableNotificationContent
@dynamic title, subtitle, body, badge, sound, userInfo, categoryIdentifier, threadIdentifier, launchImageName, targetContentIdentifier,
         summaryArgument, summaryArgumentCount, attachments, interruptionLevel, relevanceScore, filterCriteria;
- (void)setTitle:(NSString *)v { _title = [v copy] ?: @""; }
- (void)setSubtitle:(NSString *)v { _subtitle = [v copy] ?: @""; }
- (void)setBody:(NSString *)v { _body = [v copy] ?: @""; }
- (void)setBadge:(NSNumber *)v { _badge = v; }
- (void)setSound:(UNNotificationSound *)v { _sound = v; }
- (void)setUserInfo:(NSDictionary *)v { _userInfo = [v copy] ?: @{}; }
- (void)setCategoryIdentifier:(NSString *)v { _categoryIdentifier = [v copy] ?: @""; }
- (void)setThreadIdentifier:(NSString *)v { _threadIdentifier = [v copy] ?: @""; }
- (void)setLaunchImageName:(NSString *)v { _launchImageName = [v copy] ?: @""; }
- (void)setTargetContentIdentifier:(NSString *)v { _targetContentIdentifier = [v copy]; }
- (void)setSummaryArgument:(NSString *)v { _summaryArgument = [v copy] ?: @""; }
- (void)setSummaryArgumentCount:(NSUInteger)v { _summaryArgumentCount = v; }
- (void)setAttachments:(NSArray *)v { _attachments = [v copy] ?: @[]; }
- (void)setInterruptionLevel:(UNNotificationInterruptionLevel)v { _interruptionLevel = v; }
- (void)setRelevanceScore:(double)v { _relevanceScore = v; }
- (void)setFilterCriteria:(NSString *)v { _filterCriteria = [v copy]; }
@end

@interface UNNotificationTrigger ()
- (instancetype)initISIMBase;
@end
@implementation UNNotificationTrigger { @protected BOOL _repeats; }
- (instancetype)initISIMBase { return [super init]; }
- (BOOL)repeats { return _repeats; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation UNPushNotificationTrigger
@end

@implementation UNTimeIntervalNotificationTrigger { NSTimeInterval _interval; }
+ (instancetype)triggerWithTimeInterval:(NSTimeInterval)t repeats:(BOOL)repeats {
    if (!(t > 0)) [NSException raise:NSInternalInconsistencyException format:@"time interval must be greater than 0"];
    if (repeats && t < 60) [NSException raise:NSInternalInconsistencyException format:@"time interval must be at least 60 if repeating"];
    UNTimeIntervalNotificationTrigger *tr = [super alloc];
    tr->_interval = t; tr->_repeats = repeats;
    return tr;
}
- (NSTimeInterval)timeInterval { return _interval; }
- (NSDate *)nextTriggerDate { return [NSDate dateWithTimeIntervalSinceNow:_interval]; }
- (NSString *)description { return [NSString stringWithFormat:@"<UNTimeIntervalNotificationTrigger: repeats: %@, timeInterval: %g>", _repeats ? @"YES" : @"NO", _interval]; }
@end

/* next local time after `after` matching the components: units finer than the finest given one are 0,
   coarser units that are not given match anything (like Calendar.nextDate(after:matching:)) */
static double next_calendar_date(NSDictionary<NSString *, NSNumber *> *c, double after) {
    long v[6]; int given[6]; const char *names[6] = { "year", "month", "day", "hour", "minute", "second" };
    int finest = -1;
    for (int i = 0; i < 6; i++) { NSNumber *n = c[@(names[i])]; given[i] = n != nil; v[i] = n.longValue; if (given[i]) finest = i; }
    NSNumber *wd = c[@"weekday"];
    if (finest < 0 && !wd) return 0;
    if (finest < 3) finest = finest < 0 ? 2 : finest;            /* weekday-only: midnight */
    for (int i = finest + 1; i < 6; i++) if (!given[i]) { given[i] = 1; v[i] = 0; }
    time_t t0 = (time_t)after; struct tm base; localtime_r(&t0, &base);
    for (int dayOff = 0; dayOff < 366 * 8; dayOff++) {
        struct tm d = base; d.tm_mday += dayOff; d.tm_hour = 12; d.tm_min = d.tm_sec = 0; d.tm_isdst = -1;
        time_t noon = mktime(&d); struct tm day; localtime_r(&noon, &day);
        if (given[0] && day.tm_year + 1900 != v[0]) { if (day.tm_year + 1900 > v[0]) return 0; continue; }
        if (given[1] && day.tm_mon + 1 != v[1]) continue;
        if (given[2] && day.tm_mday != v[2]) continue;
        if (wd && day.tm_wday + 1 != wd.intValue) continue;
        for (int h = given[3] ? (int)v[3] : 0; h <= (given[3] ? v[3] : 23); h++)
            for (int m = given[4] ? (int)v[4] : 0; m <= (given[4] ? v[4] : 59); m++)
                for (int s = given[5] ? (int)v[5] : 0; s <= (given[5] ? v[5] : 59); s++) {
                    struct tm x = day; x.tm_hour = h; x.tm_min = m; x.tm_sec = s; x.tm_isdst = -1;
                    time_t when = mktime(&x);
                    if ((double)when > after) return (double)when;
                }
    }
    return 0;
}

@implementation UNCalendarNotificationTrigger { NSDictionary<NSString *, NSNumber *> *_values; }
- (instancetype)initWithComponentValues:(NSDictionary<NSString *, NSNumber *> *)values repeats:(BOOL)repeats {
    if ((self = [self initISIMBase])) { _values = [values copy] ?: @{}; _repeats = repeats; }
    return self;
}
- (NSDictionary *)componentValues { return _values; }
- (NSDate *)nextTriggerDate {
    double t = next_calendar_date(_values, [NSDate date].timeIntervalSince1970);
    return t > 0 ? [NSDate dateWithTimeIntervalSince1970:t] : nil;
}
- (NSString *)description { return [NSString stringWithFormat:@"<UNCalendarNotificationTrigger: repeats: %@, dateComponents: %@>", _repeats ? @"YES" : @"NO", _values]; }
@end

@implementation UNNotificationRequest { NSString *_identifier; UNNotificationContent *_content; UNNotificationTrigger *_trigger; }
+ (instancetype)requestWithIdentifier:(NSString *)identifier content:(UNNotificationContent *)content trigger:(UNNotificationTrigger *)trigger {
    UNNotificationRequest *r = [super alloc];
    r->_identifier = [identifier copy]; r->_content = [content copy]; r->_trigger = trigger;
    return r;
}
- (NSString *)identifier { return _identifier; }
- (UNNotificationContent *)content { return _content; }
- (UNNotificationTrigger *)trigger { return _trigger; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<UNNotificationRequest: identifier: %@, content: %@, trigger: %@>", _identifier, _content, _trigger]; }
@end

@implementation UNNotification { NSDate *_date; UNNotificationRequest *_request; }
+ (instancetype)isim_notificationWithRequest:(UNNotificationRequest *)r date:(NSDate *)d { UNNotification *n = [super alloc]; n->_request = r; n->_date = d; return n; }
- (NSDate *)date { return _date; }
- (UNNotificationRequest *)request { return _request; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation UNNotificationResponse { UNNotification *_notification; NSString *_action; }
+ (instancetype)isim_responseWithNotification:(UNNotification *)n action:(NSString *)a { UNNotificationResponse *r = [super alloc]; r->_notification = n; r->_action = a; return r; }
- (UNNotification *)notification { return _notification; }
- (NSString *)actionIdentifier { return _action; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation UNTextInputNotificationResponse
- (NSString *)userText { return @""; }
@end

@implementation UNNotificationAction { @protected NSString *_identifier, *_title; UNNotificationActionOptions _options; }
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options {
    UNNotificationAction *a = [super alloc]; a->_identifier = [identifier copy]; a->_title = [title copy]; a->_options = options; return a;
}
- (NSString *)identifier { return _identifier; }
- (NSString *)title { return _title; }
- (UNNotificationActionOptions)options { return _options; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation UNTextInputNotificationAction { NSString *_button, *_placeholder; }
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
                textInputButtonTitle:(NSString *)button textInputPlaceholder:(NSString *)placeholder {
    UNTextInputNotificationAction *a = [self actionWithIdentifier:identifier title:title options:options];
    a->_button = [button copy]; a->_placeholder = [placeholder copy]; return a;
}
- (NSString *)textInputButtonTitle { return _button; }
- (NSString *)textInputPlaceholder { return _placeholder; }
@end

@implementation UNNotificationCategory { NSString *_identifier; NSArray *_actions, *_intents; UNNotificationCategoryOptions _options; }
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions intentIdentifiers:(NSArray *)intents options:(UNNotificationCategoryOptions)options {
    UNNotificationCategory *c = [super alloc];
    c->_identifier = [identifier copy]; c->_actions = [actions copy]; c->_intents = [intents copy]; c->_options = options; return c;
}
- (NSString *)identifier { return _identifier; }
- (NSArray *)actions { return _actions; }
- (NSArray *)intentIdentifiers { return _intents; }
- (UNNotificationCategoryOptions)options { return _options; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSUInteger)hash { return _identifier.hash; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UNNotificationCategory class]] && [((UNNotificationCategory *)o)->_identifier isEqualToString:_identifier]; }
@end

@implementation UNNotificationSettings { UNAuthorizationStatus _status; UNAuthorizationOptions _opts; }
+ (instancetype)isim_settingsWithStatus:(UNAuthorizationStatus)s options:(UNAuthorizationOptions)o { UNNotificationSettings *x = [super alloc]; x->_status = s; x->_opts = o; return x; }
- (UNAuthorizationStatus)authorizationStatus { return _status; }
- (BOOL)isim_on { return _status == UNAuthorizationStatusAuthorized || _status == UNAuthorizationStatusProvisional || _status == UNAuthorizationStatusEphemeral; }
- (UNNotificationSetting)isim_setting:(UNAuthorizationOptions)o {
    if (_status == UNAuthorizationStatusNotDetermined) return UNNotificationSettingNotSupported;
    return [self isim_on] && (_opts & o) ? UNNotificationSettingEnabled : UNNotificationSettingDisabled;
}
- (UNNotificationSetting)soundSetting { return [self isim_setting:UNAuthorizationOptionSound]; }
- (UNNotificationSetting)badgeSetting { return [self isim_setting:UNAuthorizationOptionBadge]; }
- (UNNotificationSetting)alertSetting { return [self isim_setting:UNAuthorizationOptionAlert]; }
- (UNNotificationSetting)notificationCenterSetting { return [self isim_setting:UNAuthorizationOptionAlert]; }
- (UNNotificationSetting)lockScreenSetting { return [self isim_setting:UNAuthorizationOptionAlert]; }
- (UNNotificationSetting)carPlaySetting { return UNNotificationSettingNotSupported; }
- (UNAlertStyle)alertStyle { return [self isim_on] && (_opts & UNAuthorizationOptionAlert) ? UNAlertStyleBanner : UNAlertStyleNone; }
- (UNShowPreviewsSetting)showPreviewsSetting { return UNShowPreviewsSettingAlways; }
- (UNNotificationSetting)criticalAlertSetting { return [self isim_setting:UNAuthorizationOptionCriticalAlert]; }
- (BOOL)providesAppNotificationSettings { return (_opts & UNAuthorizationOptionProvidesAppNotificationSettings) != 0; }
- (UNNotificationSetting)announcementSetting { return UNNotificationSettingNotSupported; }
- (UNNotificationSetting)timeSensitiveSetting { return [self isim_setting:UNAuthorizationOptionTimeSensitive]; }
- (UNNotificationSetting)scheduledDeliverySetting { return [self isim_on] ? UNNotificationSettingDisabled : UNNotificationSettingNotSupported; }
- (UNNotificationSetting)directMessagesSetting { return UNNotificationSettingNotSupported; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

/* ---------------- persistence ---------------- */

static NSString *const kAuthKey = @"_ISIMNotificationAuthorization", *const kOptsKey = @"_ISIMNotificationOptions", *const kPendingKey = @"_ISIMPendingNotifications";

static id plist_safe(id v) {
    if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]]) return v;
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id x in v) { id y = plist_safe(x); if (y) [a addObject:y]; }
        return a;
    }
    if ([v isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id k in v) { if (![k isKindOfClass:[NSString class]]) continue; id y = plist_safe(v[k]); if (y) d[k] = y; }
        return d;
    }
    return nil;
}
static NSDictionary *encode_request(UNNotificationRequest *r, double fire) {
    UNNotificationContent *c = r.content;
    NSMutableDictionary *d = [@{ @"id": r.identifier, @"title": c.title, @"subtitle": c.subtitle, @"body": c.body,
                                 @"category": c.categoryIdentifier, @"thread": c.threadIdentifier, @"userInfo": plist_safe(c.userInfo) ?: @{} } mutableCopy];
    if (c.badge) d[@"badge"] = c.badge;
    if (c.sound) d[@"sound"] = c.sound.isimName ?: @"";
    UNNotificationTrigger *t = r.trigger;
    if ([t isKindOfClass:[UNTimeIntervalNotificationTrigger class]])
        d[@"trigger"] = @{ @"type": @"interval", @"interval": @(((UNTimeIntervalNotificationTrigger *)t).timeInterval), @"repeats": @(t.repeats), @"fire": @(fire) };
    else if ([t isKindOfClass:[UNCalendarNotificationTrigger class]])
        d[@"trigger"] = @{ @"type": @"calendar", @"components": ((UNCalendarNotificationTrigger *)t).componentValues, @"repeats": @(t.repeats) };
    return d;
}
static UNNotificationRequest *decode_request(NSDictionary *d, double *fire) {
    UNMutableNotificationContent *c = [[UNMutableNotificationContent alloc] init];
    c.title = d[@"title"]; c.subtitle = d[@"subtitle"]; c.body = d[@"body"]; c.categoryIdentifier = d[@"category"];
    c.threadIdentifier = d[@"thread"]; c.userInfo = d[@"userInfo"]; c.badge = d[@"badge"];
    if (d[@"sound"]) c.sound = [d[@"sound"] length] ? [UNNotificationSound soundNamed:d[@"sound"]] : [UNNotificationSound defaultSound];
    NSDictionary *t = d[@"trigger"]; UNNotificationTrigger *trigger = nil;
    if ([t[@"type"] isEqual:@"interval"]) {
        trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:[t[@"interval"] doubleValue] repeats:[t[@"repeats"] boolValue]];
        *fire = [t[@"fire"] doubleValue];
    } else if ([t[@"type"] isEqual:@"calendar"]) {
        trigger = [[UNCalendarNotificationTrigger alloc] initWithComponentValues:t[@"components"] repeats:[t[@"repeats"] boolValue]];
    }
    return [UNNotificationRequest requestWithIdentifier:d[@"id"] content:c trigger:trigger];
}

/* ---------------- banner ---------------- */

static NSString *app_name(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"App";
}
/* the app icon file (asset-catalog app icon, largest; else icon.png), like the home screen picks it */
static NSString *app_icon_path(void) {
    NSString *app = NSBundle.mainBundle.bundlePath;
    NSDictionary *assets = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"isim-assets.plist"]];
    NSDictionary *icons = assets[@"appIcons"];
    NSArray *files = icons[NSBundle.mainBundle.infoDictionary[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"] ?: @"AppIcon"] ?: icons.allValues.firstObject;
    NSString *best = nil; double bestPx = -1;
    for (NSDictionary *f in files) {
        if ([f[@"appearance"] length]) continue;
        double px = [[[f[@"size"] ?: @"1024x1024" componentsSeparatedByString:@"x"] firstObject] doubleValue] * ([f[@"scale"] doubleValue] ?: 1);
        if (px > bestPx) { bestPx = px; best = [app stringByAppendingPathComponent:f[@"file"]]; }
    }
    if (best) return best;
    NSString *plain = [app stringByAppendingPathComponent:@"icon.png"];
    return [NSFileManager.defaultManager fileExistsAtPath:plain] ? plain : nil;
}
static UIImage *app_icon(void) { NSString *p = app_icon_path(); return p ? [UIImage imageWithContentsOfFile:p] : nil; }

@interface ISIMNotificationBanner : NSObject
+ (void)show:(UNNotification *)n onTap:(void (^)(void))tap;
@end
@implementation ISIMNotificationBanner
static UIWindow *bannerWindow; static UIView *bannerCard; static void (^bannerTap)(void); static NSUInteger bannerGen;
+ (void)hide:(BOOL)animated {
    UIWindow *w = bannerWindow; UIView *card = bannerCard;
    bannerWindow = nil; bannerCard = nil; bannerTap = nil;
    if (!w) return;
    if (!animated) { w.hidden = YES; return; }
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        card.frame = CGRectMake(card.frame.origin.x, -card.frame.size.height - 12, card.frame.size.width, card.frame.size.height);
    } completion:^(BOOL f) { w.hidden = YES; }];
}
+ (void)tapped:(UITapGestureRecognizer *)g { void (^t)(void) = bannerTap; [self hide:YES]; if (t) t(); }
+ (void)panned:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded && [g translationInView:bannerCard].y < -10) [self hide:YES];
}
+ (void)show:(UNNotification *)n onTap:(void (^)(void))tap {
    [self hide:NO];
    CGRect screen = UIScreen.mainScreen.bounds;
    UIWindow *w = [[UIWindow alloc] initWithFrame:screen];
    w.windowLevel = 2100;                                          /* above alerts, like iOS banners */
    w.backgroundColor = UIColor.clearColor;
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = UIColor.clearColor;
    w.rootViewController = root;
    UNNotificationContent *c = n.request.content;
    CGFloat width = MIN(screen.size.width - 16, 400), x = (screen.size.width - width) / 2, textX = 60, textW = width - textX - 14;
    UILabel *title = [[UILabel alloc] init], *body = [[UILabel alloc] init], *when = [[UILabel alloc] init];
    title.text = c.title.length ? c.title : app_name();
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; title.textColor = UIColor.labelColor;
    NSString *text = c.subtitle.length ? [NSString stringWithFormat:@"%@\n%@", c.subtitle, c.body] : c.body;
    body.text = text; body.numberOfLines = 4; body.font = [UIFont systemFontOfSize:15]; body.textColor = UIColor.labelColor;
    when.text = @"now"; when.font = [UIFont systemFontOfSize:13]; when.textColor = UIColor.secondaryLabelColor; when.textAlignment = NSTextAlignmentRight;
    CGSize bs = [body sizeThatFits:CGSizeMake(textW, 400)];
    CGFloat height = MAX(68, 14 + 20 + (text.length ? ceil(bs.height) : 0) + 14);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, -height - 12, width, height)];
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 22;
    card.accessibilityIdentifier = @"isim-notification-banner";
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(12, (height - 38) / 2, 38, 38)];
    icon.layer.cornerRadius = 9; icon.clipsToBounds = YES;
    UIImage *img = app_icon();
    if (img) icon.image = img;
    else {
        icon.backgroundColor = UIColor.systemBlueColor;
        UILabel *letter = [[UILabel alloc] initWithFrame:icon.bounds];
        NSString *name = app_name();
        letter.text = [name substringToIndex:MIN((NSUInteger)1, name.length)].uppercaseString;
        letter.textAlignment = NSTextAlignmentCenter; letter.textColor = UIColor.whiteColor;
        letter.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
        [icon addSubview:letter];
    }
    title.frame = CGRectMake(textX, 13, textW - 40, 20);
    when.frame = CGRectMake(width - 54, 13, 40, 18);
    body.frame = CGRectMake(textX, 34, textW, ceil(bs.height));
    for (UIView *v in @[icon, title, when, body]) { v.userInteractionEnabled = NO; [card addSubview:v]; }
    [card addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)]];
    [card addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)]];
    [root.view addSubview:card];
    w.hidden = NO;
    bannerWindow = w; bannerCard = card; bannerTap = [tap copy];
    NSUInteger gen = ++bannerGen;
    CGFloat top = MAX(w.safeAreaInsets.top, 20) + 2;
    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{
        card.frame = CGRectMake(x, top, width, height);
    } completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (gen == bannerGen && bannerWindow == w) [self hide:YES];
    });
}
@end

/* ---------------- center ---------------- */

@implementation UNUserNotificationCenter {
    NSMutableArray<UNNotificationRequest *> *_pending;
    NSMutableDictionary<NSString *, NSNumber *> *_fire;          /* identifier -> next fire time (seconds since 1970) */
    NSMutableDictionary<NSString *, NSNumber *> *_generation;
    NSMutableArray<UNNotification *> *_delivered;
    NSSet<UNNotificationCategory *> *_categories;
    BOOL _asking;
    NSMutableArray *_authWaiters;
}

+ (UNUserNotificationCenter *)currentNotificationCenter {
    static UNUserNotificationCenter *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[self alloc] initISIMCenter]; });
    return c;
}
- (instancetype)initISIMCenter {
    if ((self = [super init])) {
        _pending = [NSMutableArray array]; _fire = [NSMutableDictionary dictionary]; _generation = [NSMutableDictionary dictionary];
        _delivered = [NSMutableArray array]; _categories = [NSSet set]; _authWaiters = [NSMutableArray array];
        for (NSDictionary *d in [NSUserDefaults.standardUserDefaults arrayForKey:kPendingKey]) {
            double fire = 0; UNNotificationRequest *r = decode_request(d, &fire);
            if (!r.identifier) continue;
            [_pending addObject:r]; if (fire > 0) _fire[r.identifier] = @(fire);
        }
        dispatch_async(dispatch_get_main_queue(), ^{ for (UNNotificationRequest *r in [self->_pending copy]) [self schedule:r]; });
        /* the shell's banner for a notification delivered in the background was tapped */
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimNotificationResponse" object:nil queue:nil usingBlock:^(NSNotification *note) {
            for (UNNotification *n in [self->_delivered copy])
                if ([n.request.identifier isEqualToString:note.object]) { [self respond:n action:UNNotificationDefaultActionIdentifier]; break; }
        }];
    }
    return self;
}
- (BOOL)supportsContentExtensions { return NO; }

static void on_background(void (^b)(void)) { dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), b); }

- (UNAuthorizationStatus)status { return (UNAuthorizationStatus)[NSUserDefaults.standardUserDefaults integerForKey:kAuthKey]; }
- (UNAuthorizationOptions)grantedOptions { return (UNAuthorizationOptions)[NSUserDefaults.standardUserDefaults integerForKey:kOptsKey]; }
- (BOOL)authorized { UNAuthorizationStatus s = [self status]; return s == UNAuthorizationStatusAuthorized || s == UNAuthorizationStatusProvisional; }
- (void)setStatus:(UNAuthorizationStatus)s options:(UNAuthorizationOptions)o {
    [NSUserDefaults.standardUserDefaults setInteger:s forKey:kAuthKey];
    [NSUserDefaults.standardUserDefaults setInteger:o forKey:kOptsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options completionHandler:(void (^)(BOOL, NSError *))completion {
    void (^done)(BOOL, NSError *) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        UNAuthorizationStatus s = [self status];
        if (s == UNAuthorizationStatusAuthorized || s == UNAuthorizationStatusDenied) {
            BOOL ok = s == UNAuthorizationStatusAuthorized;
            if (ok) [self setStatus:s options:[self grantedOptions] | options];
            on_background(^{ done(ok, nil); }); return;
        }
        if (options & UNAuthorizationOptionProvisional) {        /* provisional: granted quietly, no prompt (like iOS) */
            [self setStatus:UNAuthorizationStatusProvisional options:options];
            on_background(^{ done(YES, nil); }); return;
        }
        [self->_authWaiters addObject:^(BOOL ok) { done(ok, nil); }];
        if (self->_asking) return;
        self->_asking = YES;
        void (^answer)(BOOL) = ^(BOOL ok) {
            self->_asking = NO;
            [self setStatus:ok ? UNAuthorizationStatusAuthorized : UNAuthorizationStatusDenied options:ok ? options : 0];
            NSLog(@"isim UserNotifications: notifications %@ for %@", ok ? @"allowed" : @"not allowed", app_name());
            NSArray *waiters = [self->_authWaiters copy]; [self->_authWaiters removeAllObjects];
            on_background(^{ for (void (^w)(BOOL) in waiters) w(ok); });
        };
        const char *env = getenv("ISIM_NOTIFICATION_PERMISSION");
        if (env && *env) { answer(!strcmp(env, "allow") || !strcmp(env, "1")); return; }
        UIViewController *top = UIApplication.sharedApplication.keyWindow.rootViewController ?: UIApplication.sharedApplication.windows.firstObject.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        if (!top) { answer(NO); return; }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"“%@” Would Like to Send You Notifications", app_name()]
            message:@"Notifications may include alerts, sounds, and icon badges. These can be configured in Settings." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Don’t Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { answer(NO); }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Allow" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { answer(YES); }]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *))completion {
    UNNotificationSettings *s = [UNNotificationSettings isim_settingsWithStatus:[self status] options:[self grantedOptions]];
    void (^done)(UNNotificationSettings *) = [completion copy];
    on_background(^{ done(s); });
}
- (void)setNotificationCategories:(NSSet<UNNotificationCategory *> *)categories { @synchronized(self) { _categories = [categories copy]; } }
- (void)getNotificationCategoriesWithCompletionHandler:(void (^)(NSSet<UNNotificationCategory *> *))completion {
    NSSet *c; @synchronized(self) { c = _categories; }
    void (^done)(NSSet *) = [completion copy];
    on_background(^{ done(c); });
}

- (void)save {
    NSMutableArray *out = [NSMutableArray array];
    for (UNNotificationRequest *r in _pending) [out addObject:encode_request(r, _fire[r.identifier].doubleValue)];
    [NSUserDefaults.standardUserDefaults setObject:out forKey:kPendingKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError *))completion {
    void (^done)(NSError *) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSUInteger i = 0; i < self->_pending.count; i++)
            if ([self->_pending[i].identifier isEqualToString:request.identifier]) { [self->_pending removeObjectAtIndex:i]; break; }
        [self->_fire removeObjectForKey:request.identifier];
        if ([request.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]])
            self->_fire[request.identifier] = @([NSDate date].timeIntervalSince1970 + ((UNTimeIntervalNotificationTrigger *)request.trigger).timeInterval);
        [self->_pending addObject:request];
        [self save];
        [self schedule:request];
        if (done) on_background(^{ done(nil); });
    });
}

- (double)nextFire:(UNNotificationRequest *)r {
    if (!r.trigger) return [NSDate date].timeIntervalSince1970;     /* nil trigger: deliver right away */
    if ([r.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]]) return _fire[r.identifier].doubleValue;
    if ([r.trigger isKindOfClass:[UNCalendarNotificationTrigger class]]) {
        NSNumber *f = _fire[r.identifier];
        if (!f) { double t = next_calendar_date(((UNCalendarNotificationTrigger *)r.trigger).componentValues, [NSDate date].timeIntervalSince1970); if (t > 0) _fire[r.identifier] = f = @(t); }
        return f.doubleValue;
    }
    return 0;
}
- (void)schedule:(UNNotificationRequest *)r {
    double fire = [self nextFire:r];
    if (fire <= 0) return;
    NSUInteger gen = _generation[r.identifier].unsignedIntegerValue + 1;
    _generation[r.identifier] = @(gen);
    double delay = MAX(0, fire - [NSDate date].timeIntervalSince1970);
    NSString *ident = r.identifier;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_generation[ident].unsignedIntegerValue != gen) return;
        UNNotificationRequest *cur = nil;
        for (UNNotificationRequest *p in self->_pending) if ([p.identifier isEqualToString:ident]) cur = p;
        if (cur) [self fire:cur];
    });
}

- (void)fire:(UNNotificationRequest *)r {
    UNNotification *n = [UNNotification isim_notificationWithRequest:r date:[NSDate date]];
    if (r.trigger.repeats) {
        if ([r.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]])
            _fire[r.identifier] = @([NSDate date].timeIntervalSince1970 + ((UNTimeIntervalNotificationTrigger *)r.trigger).timeInterval);
        else [_fire removeObjectForKey:r.identifier];
        [self save];
        [self schedule:r];
    } else {
        [_pending removeObject:r]; [_fire removeObjectForKey:r.identifier];
        [self save];
    }
    if (![self authorized]) { NSLog(@"isim UserNotifications: “%@” not shown (notifications are not allowed for %@)", r.identifier, app_name()); return; }
    for (NSUInteger i = 0; i < _delivered.count; i++)
        if ([_delivered[i].request.identifier isEqualToString:r.identifier]) { [_delivered removeObjectAtIndex:i]; break; }
    [_delivered addObject:n];
    UIApplication *app = UIApplication.sharedApplication;
    if (app.applicationState == UIApplicationStateBackground) {
        NSLog(@"isim UserNotifications: delivered “%@” in the background", r.identifier);
        if (r.content.badge && ([self grantedOptions] & UNAuthorizationOptionBadge)) app.applicationIconBadgeNumber = r.content.badge.integerValue;
        if (isim_shell_present() && (([self grantedOptions] & UNAuthorizationOptionAlert) || [self status] == UNAuthorizationStatusProvisional)) {
            NSString *a = [NSString stringWithFormat:@"%@\x1f%@", r.identifier, app_icon_path() ?: @""];
            NSString *body = r.content.subtitle.length ? [NSString stringWithFormat:@"%@\n%@", r.content.subtitle, r.content.body] : r.content.body;
            isim_shell_request(ISIM_SHELL_NOTIFY, a.UTF8String, (r.content.title.length ? r.content.title : app_name()).UTF8String, body.UTF8String);
        }
        return;
    }
    id<UNUserNotificationCenterDelegate> d = self.delegate;
    void (^present)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions o) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UNAuthorizationOptions granted = [self grantedOptions];
            if ((o & UNNotificationPresentationOptionBadge) && r.content.badge && (granted & UNAuthorizationOptionBadge))
                app.applicationIconBadgeNumber = r.content.badge.integerValue;
            BOOL banner = (o & (UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionAlert)) != 0;
            NSLog(@"isim UserNotifications: delivered “%@” in the foreground (%@)", r.identifier, banner ? @"banner" : @"not presented");
            if ((o & UNNotificationPresentationOptionList) || banner) {      /* the shell's Notification Center lists it */
                NSString *a = [NSString stringWithFormat:@"%@\x1f%@", r.identifier, app_icon_path() ?: @""];
                NSString *tb = [NSString stringWithFormat:@"%@\x1f%@", r.content.title.length ? r.content.title : app_name(), r.content.body ?: @""];
                isim_shell_request(ISIM_SHELL_SYSTEM, "notified", a.UTF8String, tb.UTF8String);
            }
            if (banner && (granted & UNAuthorizationOptionAlert || [self status] == UNAuthorizationStatusProvisional))
                [ISIMNotificationBanner show:n onTap:^{ [self respond:n action:UNNotificationDefaultActionIdentifier]; }];
        });
    };
    if ([d respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)])
        [d userNotificationCenter:self willPresentNotification:n withCompletionHandler:present];
    else present(0);                                              /* iOS: no delegate, nothing shown in the foreground */
}

- (void)respond:(UNNotification *)n action:(NSString *)action {
    NSLog(@"isim UserNotifications: opened “%@”", n.request.identifier);
    id<UNUserNotificationCenterDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        [d userNotificationCenter:self didReceiveNotificationResponse:[UNNotificationResponse isim_responseWithNotification:n action:action] withCompletionHandler:^{}];
}

- (void)getPendingNotificationRequestsWithCompletionHandler:(void (^)(NSArray<UNNotificationRequest *> *))completion {
    void (^done)(NSArray *) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{ NSArray *p = [self->_pending copy]; on_background(^{ done(p); }); });
}
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString *> *)identifiers {
    NSArray *ids = [identifiers copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray *keep = [NSMutableArray array];
        for (UNNotificationRequest *r in self->_pending) {
            if ([ids containsObject:r.identifier]) { [self->_fire removeObjectForKey:r.identifier]; [self->_generation removeObjectForKey:r.identifier]; }
            else [keep addObject:r];
        }
        self->_pending = keep;
        [self save];
    });
}
- (void)removeAllPendingNotificationRequests {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_pending removeAllObjects]; [self->_fire removeAllObjects]; [self->_generation removeAllObjects];
        [self save];
    });
}
- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray<UNNotification *> *))completion {
    void (^done)(NSArray *) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{ NSArray *p = [self->_delivered copy]; on_background(^{ done(p); }); });
}
- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray<NSString *> *)identifiers {
    NSArray *ids = [identifiers copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray *keep = [NSMutableArray array];
        for (UNNotification *n in self->_delivered) if (![ids containsObject:n.request.identifier]) [keep addObject:n];
        self->_delivered = keep;
        isim_shell_request(ISIM_SHELL_SYSTEM, "nc-remove", NULL, [ids componentsJoinedByString:@"\x1f"].UTF8String);
    });
}
- (void)removeAllDeliveredNotifications {
    dispatch_async(dispatch_get_main_queue(), ^{ [self->_delivered removeAllObjects]; isim_shell_request(ISIM_SHELL_SYSTEM, "nc-remove", NULL, NULL); });
}
- (void)setBadgeCount:(NSInteger)count withCompletionHandler:(void (^)(NSError *))completion {
    void (^done)(NSError *) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication.sharedApplication.applicationIconBadgeNumber = count;
        if (done) on_background(^{ done(nil); });
    });
}
@end
