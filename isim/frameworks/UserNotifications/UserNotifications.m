/* isim UserNotifications: local and remote notifications (see the SDK header for what isim covers).
 *
 * State per app (NSUserDefaults, i.e. the app container): the authorization answer and the pending requests,
 * so requests survive relaunches. Triggers are timers on the main queue while the app runs (in the background the app
 * tells the shell when its next one is due, so a suspended app is woken to deliver it). When one fires and the app is
 * in the foreground, the delegate's willPresent decides the presentation; a banner slides in at the top (tap:
 * didReceive with the default action, swipe up: dismiss). In the background under `isim boot` the shell shows the
 * banner over the home screen or the app in front; tapping it brings this app to the front and calls didReceive.
 * Apps that are not running do not get their local notifications (no system scheduler).
 *
 * Remote notifications (push): the home screen ("SpringBoard", standing in for apsd) takes payloads from `isim push`,
 * the `push` script command or a dropped .apns file, runs the app's Notification Service extension, and hands the result
 * to the running app (UIKit calls isim_un_remote_notification) or shows it itself when the app is not running.
 *
 * Every delivered notification is recorded in the app container (Library/isim/Notifications/<id>.plist): the shell
 * lists it in Notification Center, the home screen reads it to expand the notification (category actions, Content
 * extension) and a response to it can reach the app even after a relaunch. Categories are saved next to it
 * (Library/isim/NotificationCategories.plist).
 * Automation: ISIM_NOTIFICATION_PERMISSION=allow|deny answers the permission prompt without the alert. */
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>
#include <isim_host.h>
#include <time.h>
#include <stdlib.h>
#include <ctype.h>

NSString * const UNErrorDomain = @"UNErrorDomain";
NSString * const UNNotificationDefaultActionIdentifier = @"com.apple.UNNotificationDefaultActionIdentifier";
NSString * const UNNotificationDismissActionIdentifier = @"com.apple.UNNotificationDismissActionIdentifier";
NSString * const UNNotificationAttachmentOptionsTypeHintKey = @"UNNotificationAttachmentOptionsTypeHintKey";
NSString * const UNNotificationAttachmentOptionsThumbnailHiddenKey = @"UNNotificationAttachmentOptionsThumbnailHiddenKey";
NSString * const UNNotificationAttachmentOptionsThumbnailClippingRectKey = @"UNNotificationAttachmentOptionsThumbnailClippingRectKey";
NSString * const UNNotificationAttachmentOptionsThumbnailTimeKey = @"UNNotificationAttachmentOptionsThumbnailTimeKey";

NSString *isim_data_dir(void);

/* ---------------- model ---------------- */

/* isim-private constructors, used across this file */
@interface UNNotification () + (instancetype)isim_notificationWithRequest:(UNNotificationRequest *)r date:(NSDate *)d; @end
@interface UNNotificationResponse () + (instancetype)isim_responseWithNotification:(UNNotification *)n action:(NSString *)a; @end
@interface UNTextInputNotificationResponse () + (instancetype)isim_responseWithNotification:(UNNotification *)n action:(NSString *)a text:(NSString *)text; @end
@interface UNNotificationAttachment () + (instancetype)isim_attachmentWithIdentifier:(NSString *)ident URL:(NSURL *)url type:(NSString *)type; @end
@interface UNNotificationActionIcon () - (NSString *)isim_name; @end
@interface UNNotificationSettings () + (instancetype)isim_settingsWithStatus:(UNAuthorizationStatus)s options:(UNAuthorizationOptions)o; @end

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

/* attachments: a file URL of a supported type, copied into the attachment store (<isim data>/Library/UserNotifications/Attachments) */
static NSString *attachment_type(NSString *ext, NSString *hint) {
    if (hint.length) return hint;
    NSDictionary *m = @{ @"png": @"public.png", @"jpg": @"public.jpeg", @"jpeg": @"public.jpeg", @"gif": @"com.compuserve.gif", @"heic": @"public.heic",
        @"aif": @"public.aiff-audio", @"aiff": @"public.aiff-audio", @"wav": @"com.microsoft.waveform-audio", @"mp3": @"public.mp3",
        @"m4a": @"com.apple.m4a-audio", @"mp4": @"public.mpeg-4", @"mov": @"com.apple.quicktime-movie", @"m4v": @"com.apple.m4v-video" };
    return m[ext.lowercaseString];
}
static BOOL type_is_image(NSString *t) { return [@[@"public.png", @"public.jpeg", @"com.compuserve.gif", @"public.heic", @"public.image"] containsObject:t ?: @""]; }
static BOOL type_is_audio(NSString *t) { return [@[@"public.aiff-audio", @"com.microsoft.waveform-audio", @"public.mp3", @"com.apple.m4a-audio", @"public.audio"] containsObject:t ?: @""]; }
@implementation UNNotificationAttachment { NSString *_identifier, *_type; NSURL *_URL; }
+ (instancetype)isim_attachmentWithIdentifier:(NSString *)ident URL:(NSURL *)url type:(NSString *)type {
    UNNotificationAttachment *a = [super alloc]; a->_identifier = [ident copy]; a->_URL = [url copy]; a->_type = [type copy]; return a;
}
+ (instancetype)attachmentWithIdentifier:(NSString *)identifier URL:(NSURL *)URL options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *path = URL.isFileURL ? URL.path : nil;
    BOOL dir = NO;
    if (!path || ![fm fileExistsAtPath:path isDirectory:&dir] || dir) {
        if (error) *error = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeAttachmentInvalidURL userInfo:@{ NSLocalizedDescriptionKey: @"Invalid attachment file URL" }];
        return nil;
    }
    NSString *type = attachment_type(path.pathExtension, options[UNNotificationAttachmentOptionsTypeHintKey]);
    if (!type) {
        if (error) *error = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeAttachmentUnrecognizedType userInfo:@{ NSLocalizedDescriptionKey: @"Unrecognized attachment file type" }];
        return nil;
    }
    NSData *bytes = [NSData dataWithContentsOfFile:path];
    unsigned long long size = bytes.length;
    unsigned long long limit = type_is_image(type) ? 10ull << 20 : type_is_audio(type) ? 5ull << 20 : 50ull << 20;   /* iOS limits */
    if (size > limit) {
        if (error) *error = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeAttachmentInvalidFileSize userInfo:@{ NSLocalizedDescriptionKey: @"Invalid attachment file size" }];
        return nil;
    }
    NSString *store = [isim_data_dir() stringByAppendingPathComponent:@"Library/UserNotifications/Attachments"];
    [fm createDirectoryAtPath:store withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *dst = [store stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, path.pathExtension]];
    if (!bytes || ![bytes writeToFile:dst atomically:YES]) {
        if (error) *error = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeAttachmentMoveIntoDataStoreFailed userInfo:@{ NSLocalizedDescriptionKey: @"Could not move the attachment into the data store" }];
        return nil;
    }
    return [self isim_attachmentWithIdentifier:identifier.length ? identifier : NSUUID.UUID.UUIDString URL:[NSURL fileURLWithPath:dst] type:type];
}
- (NSString *)identifier { return _identifier; }
- (NSURL *)URL { return _URL; }
- (NSString *)type { return _type; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<UNNotificationAttachment: %@, %@, %@>", _identifier, _type, _URL.path]; }
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
- (NSString *)description { return @"<UNPushNotificationTrigger: contentAvailable: NO, mutableContent: NO>"; }
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
- (NSString *)description { return [NSString stringWithFormat:@"<UNNotification: date: %@, request: %@>", _date, _request]; }
@end

@implementation UNNotificationResponse { UNNotification *_notification; NSString *_action; }
+ (instancetype)isim_responseWithNotification:(UNNotification *)n action:(NSString *)a { UNNotificationResponse *r = [super alloc]; r->_notification = n; r->_action = a; return r; }
- (UNNotification *)notification { return _notification; }
- (NSString *)actionIdentifier { return _action; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation UNTextInputNotificationResponse { NSString *_userText; }
+ (instancetype)isim_responseWithNotification:(UNNotification *)n action:(NSString *)a text:(NSString *)text {
    UNTextInputNotificationResponse *r = [self isim_responseWithNotification:n action:a]; r->_userText = [text copy]; return r;
}
- (NSString *)userText { return _userText ?: @""; }
@end

@implementation UNNotificationActionIcon { NSString *_name; BOOL _system; }
+ (instancetype)iconWithTemplateImageName:(NSString *)n { UNNotificationActionIcon *i = [super alloc]; i->_name = [n copy]; return i; }
+ (instancetype)iconWithSystemImageName:(NSString *)n { UNNotificationActionIcon *i = [super alloc]; i->_name = [n copy]; i->_system = YES; return i; }
- (NSString *)isim_name { return _name; }
- (BOOL)isim_system { return _system; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation UNNotificationAction { @protected NSString *_identifier, *_title; UNNotificationActionOptions _options; UNNotificationActionIcon *_icon; }
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options {
    UNNotificationAction *a = [super alloc]; a->_identifier = [identifier copy]; a->_title = [title copy]; a->_options = options; return a;
}
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options icon:(UNNotificationActionIcon *)icon {
    UNNotificationAction *a = [self actionWithIdentifier:identifier title:title options:options]; a->_icon = icon; return a;
}
- (NSString *)identifier { return _identifier; }
- (NSString *)title { return _title; }
- (UNNotificationActionOptions)options { return _options; }
- (UNNotificationActionIcon *)icon { return _icon; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation UNTextInputNotificationAction { NSString *_button, *_placeholder; }
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
                textInputButtonTitle:(NSString *)button textInputPlaceholder:(NSString *)placeholder {
    UNTextInputNotificationAction *a = [self actionWithIdentifier:identifier title:title options:options];
    a->_button = [button copy]; a->_placeholder = [placeholder copy]; return a;
}
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options icon:(UNNotificationActionIcon *)icon
                textInputButtonTitle:(NSString *)button textInputPlaceholder:(NSString *)placeholder {
    UNTextInputNotificationAction *a = [self actionWithIdentifier:identifier title:title options:options icon:icon];
    a->_button = [button copy]; a->_placeholder = [placeholder copy]; return a;
}
- (NSString *)textInputButtonTitle { return _button; }
- (NSString *)textInputPlaceholder { return _placeholder; }
@end

@implementation UNNotificationCategory { NSString *_identifier, *_placeholder, *_summary; NSArray *_actions, *_intents; UNNotificationCategoryOptions _options; }
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions intentIdentifiers:(NSArray *)intents options:(UNNotificationCategoryOptions)options {
    UNNotificationCategory *c = [super alloc];
    c->_identifier = [identifier copy]; c->_actions = [actions copy] ?: @[]; c->_intents = [intents copy] ?: @[]; c->_options = options;
    c->_placeholder = @""; c->_summary = @""; return c;
}
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions intentIdentifiers:(NSArray *)intents hiddenPreviewsBodyPlaceholder:(NSString *)placeholder options:(UNNotificationCategoryOptions)options {
    UNNotificationCategory *c = [self categoryWithIdentifier:identifier actions:actions intentIdentifiers:intents options:options];
    c->_placeholder = [placeholder copy] ?: @""; return c;
}
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions intentIdentifiers:(NSArray *)intents hiddenPreviewsBodyPlaceholder:(NSString *)placeholder
                 categorySummaryFormat:(NSString *)summary options:(UNNotificationCategoryOptions)options {
    UNNotificationCategory *c = [self categoryWithIdentifier:identifier actions:actions intentIdentifiers:intents hiddenPreviewsBodyPlaceholder:placeholder options:options];
    c->_summary = [summary copy] ?: @""; return c;
}
- (NSString *)identifier { return _identifier; }
- (NSArray *)actions { return _actions; }
- (NSArray *)intentIdentifiers { return _intents; }
- (UNNotificationCategoryOptions)options { return _options; }
- (NSString *)hiddenPreviewsBodyPlaceholder { return _placeholder; }
- (NSString *)categorySummaryFormat { return _summary; }
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
    if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSDate class]] || [v isKindOfClass:[NSData class]]) return v;
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

/* attachments <-> plist */
static NSArray *encode_attachments(NSArray<UNNotificationAttachment *> *atts) {
    NSMutableArray *a = [NSMutableArray array];
    for (UNNotificationAttachment *x in atts) if (x.URL.path) [a addObject:@{ @"id": x.identifier ?: @"", @"path": x.URL.path, @"type": x.type ?: @"" }];
    return a;
}
static NSArray *decode_attachments(NSArray *plist) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *d in plist) if ([d isKindOfClass:[NSDictionary class]] && d[@"path"])
        [a addObject:[UNNotificationAttachment isim_attachmentWithIdentifier:d[@"id"] URL:[NSURL fileURLWithPath:d[@"path"]] type:d[@"type"]]];
    return a;
}

/* the notification record (Library/isim/Notifications/<id>.plist in the app container) */
static NSString *record_path_in(NSString *home, NSString *ident) {
    NSString *safe = [[ident ?: @"" componentsSeparatedByString:@"/"] componentsJoinedByString:@"_"];
    return [[home stringByAppendingPathComponent:@"Library/isim/Notifications"] stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"plist"]];
}
static NSDictionary *record_of(UNNotification *n, BOOL push) {
    UNNotificationContent *c = n.request.content;
    NSMutableDictionary *d = [@{ @"id": n.request.identifier ?: @"", @"title": c.title, @"subtitle": c.subtitle, @"body": c.body,
        @"category": c.categoryIdentifier, @"thread": c.threadIdentifier, @"userInfo": plist_safe(c.userInfo) ?: @{},
        @"date": n.date ?: [NSDate date], @"attachments": encode_attachments(c.attachments), @"push": @(push),
        @"app": NSBundle.mainBundle.bundleIdentifier ?: @"" } mutableCopy];
    if (c.badge) d[@"badge"] = c.badge;
    if (c.targetContentIdentifier) d[@"targetContentIdentifier"] = c.targetContentIdentifier;
    return d;
}
static NSString *write_record(UNNotification *n, BOOL push) {
    NSString *p = record_path_in(NSHomeDirectory(), n.request.identifier);
    [NSFileManager.defaultManager createDirectoryAtPath:p.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    [record_of(n, push) writeToFile:p atomically:YES];
    return p;
}
/* a notification rebuilt from its record (a response after a relaunch, the content extension host) */
static UNNotification *notification_from_record(NSDictionary *d) {
    if (![d isKindOfClass:[NSDictionary class]] || !d[@"id"]) return nil;
    UNMutableNotificationContent *c = [[UNMutableNotificationContent alloc] init];
    c.title = d[@"title"]; c.subtitle = d[@"subtitle"]; c.body = d[@"body"]; c.categoryIdentifier = d[@"category"];
    c.threadIdentifier = d[@"thread"]; c.userInfo = d[@"userInfo"]; c.badge = d[@"badge"]; c.targetContentIdentifier = d[@"targetContentIdentifier"];
    c.attachments = decode_attachments(d[@"attachments"]);
    UNNotificationTrigger *trigger = [d[@"push"] boolValue] ? [[UNPushNotificationTrigger alloc] initISIMBase] : nil;
    UNNotificationRequest *r = [UNNotificationRequest requestWithIdentifier:d[@"id"] content:c trigger:trigger];
    return [UNNotification isim_notificationWithRequest:r date:[d[@"date"] isKindOfClass:[NSDate class]] ? d[@"date"] : [NSDate date]];
}

/* categories (Library/isim/NotificationCategories.plist): the home screen lists their actions under expanded notifications */
static NSDictionary *encode_category(UNNotificationCategory *c) {
    NSMutableArray *acts = [NSMutableArray array];
    for (UNNotificationAction *a in c.actions) {
        NSMutableDictionary *d = [@{ @"id": a.identifier ?: @"", @"title": a.title ?: @"", @"options": @(a.options) } mutableCopy];
        if ([a isKindOfClass:[UNTextInputNotificationAction class]]) {
            UNTextInputNotificationAction *t = (UNTextInputNotificationAction *)a;
            d[@"textInput"] = @YES; d[@"button"] = t.textInputButtonTitle ?: @"Send"; d[@"placeholder"] = t.textInputPlaceholder ?: @"";
        }
        if (a.icon) d[@"icon"] = [a.icon isim_name] ?: @"";
        [acts addObject:d];
    }
    return @{ @"id": c.identifier ?: @"", @"options": @(c.options), @"actions": acts, @"placeholder": c.hiddenPreviewsBodyPlaceholder ?: @"" };
}

/* ---------------- payloads (aps dictionaries) ---------------- */

static NSString *localized(NSString *key, NSArray *args) {
    if (![key isKindOfClass:[NSString class]]) return nil;
    NSString *f = [NSBundle.mainBundle localizedStringForKey:key value:key table:nil];
    NSMutableString *out = [NSMutableString string];
    NSUInteger ai = 0;
    for (NSUInteger i = 0; i < f.length; i++) {             /* %@ and %n$@ with the loc-args, in order */
        unichar ch = [f characterAtIndex:i];
        if (ch == '%' && i + 1 < f.length) {
            NSUInteger j = i + 1; NSUInteger pos = 0;
            while (j < f.length && isdigit([f characterAtIndex:j])) { pos = pos * 10 + ([f characterAtIndex:j] - '0'); j++; }
            if (j < f.length && [f characterAtIndex:j] == '$') j++; else pos = 0;
            if (j < f.length && [f characterAtIndex:j] == '@') {
                NSUInteger k = pos ? pos - 1 : ai++;
                [out appendString:k < args.count ? [args[k] description] : @""];
                i = j; continue;
            }
            if (j < f.length && [f characterAtIndex:j] == '%') { [out appendString:@"%"]; i = j; continue; }
        }
        [out appendFormat:@"%C", ch];
    }
    return out;
}
static UNMutableNotificationContent *content_from_payload(NSDictionary *payload, NSArray *attachments) {
    UNMutableNotificationContent *c = [[UNMutableNotificationContent alloc] init];
    NSDictionary *aps = [payload[@"aps"] isKindOfClass:[NSDictionary class]] ? payload[@"aps"] : @{};
    id alert = aps[@"alert"];
    if ([alert isKindOfClass:[NSString class]]) c.body = alert;
    else if ([alert isKindOfClass:[NSDictionary class]]) {
        NSDictionary *a = alert;
        c.title = [a[@"title"] isKindOfClass:[NSString class]] ? a[@"title"] : localized(a[@"title-loc-key"], a[@"title-loc-args"]) ?: @"";
        c.subtitle = [a[@"subtitle"] isKindOfClass:[NSString class]] ? a[@"subtitle"] : localized(a[@"subtitle-loc-key"], a[@"subtitle-loc-args"]) ?: @"";
        c.body = [a[@"body"] isKindOfClass:[NSString class]] ? a[@"body"] : localized(a[@"loc-key"], a[@"loc-args"]) ?: @"";
        if ([a[@"launch-image"] isKindOfClass:[NSString class]]) c.launchImageName = a[@"launch-image"];
    }
    if ([aps[@"badge"] isKindOfClass:[NSNumber class]]) c.badge = aps[@"badge"];
    id sound = aps[@"sound"];
    if ([sound isKindOfClass:[NSString class]]) c.sound = [sound isEqualToString:@"default"] ? UNNotificationSound.defaultSound : [UNNotificationSound soundNamed:sound];
    else if ([sound isKindOfClass:[NSDictionary class]]) {
        NSString *name = sound[@"name"];
        c.sound = [sound[@"critical"] boolValue] ? UNNotificationSound.defaultCriticalSound : ([name isKindOfClass:[NSString class]] && ![name isEqualToString:@"default"] ? [UNNotificationSound soundNamed:name] : UNNotificationSound.defaultSound);
    }
    if ([aps[@"category"] isKindOfClass:[NSString class]]) c.categoryIdentifier = aps[@"category"];
    if ([aps[@"thread-id"] isKindOfClass:[NSString class]]) c.threadIdentifier = aps[@"thread-id"];
    if ([aps[@"target-content-id"] isKindOfClass:[NSString class]]) c.targetContentIdentifier = aps[@"target-content-id"];
    if ([aps[@"filter-criteria"] isKindOfClass:[NSString class]]) c.filterCriteria = aps[@"filter-criteria"];
    if ([aps[@"relevance-score"] isKindOfClass:[NSNumber class]]) c.relevanceScore = [aps[@"relevance-score"] doubleValue];
    NSString *level = aps[@"interruption-level"];
    if ([level isKindOfClass:[NSString class]])
        c.interruptionLevel = [level isEqual:@"passive"] ? UNNotificationInterruptionLevelPassive : [level isEqual:@"time-sensitive"] ? UNNotificationInterruptionLevelTimeSensitive
                            : [level isEqual:@"critical"] ? UNNotificationInterruptionLevelCritical : UNNotificationInterruptionLevelActive;
    c.userInfo = payload ?: @{};
    c.attachments = decode_attachments(attachments);
    return c;
}
static BOOL content_has_alert(UNNotificationContent *c) { return c.title.length || c.subtitle.length || c.body.length; }
/* a content (a service extension's result) as plist */
static NSDictionary *encode_content(UNNotificationContent *c) {
    NSMutableDictionary *d = [@{ @"title": c.title ?: @"", @"subtitle": c.subtitle ?: @"", @"body": c.body ?: @"", @"category": c.categoryIdentifier ?: @"",
        @"thread": c.threadIdentifier ?: @"", @"userInfo": plist_safe(c.userInfo) ?: @{}, @"attachments": encode_attachments(c.attachments) } mutableCopy];
    if (c.badge) d[@"badge"] = c.badge;
    if (c.sound) d[@"sound"] = c.sound.isimCritical ? @"critical" : (c.sound.isimName ?: @"default");
    if (c.targetContentIdentifier) d[@"targetContentIdentifier"] = c.targetContentIdentifier;
    return d;
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
    /* CFBundleIconFiles names ("AppIcon60x60" -> AppIcon60x60@3x.png): the largest matching file */
    NSArray *names = NSBundle.mainBundle.infoDictionary[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    unsigned long long bestSize = 0;
    if ([names isKindOfClass:[NSArray class]])
        for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:app error:NULL])
            for (NSString *n in names) if ([f hasPrefix:n] && [f.pathExtension.lowercaseString isEqualToString:@"png"]) {
                unsigned long long sz = [NSData dataWithContentsOfFile:[app stringByAppendingPathComponent:f]].length;
                if (sz > bestSize) { bestSize = sz; best = [app stringByAppendingPathComponent:f]; }
            }
    if (best) return best;
    NSString *plain = [app stringByAppendingPathComponent:@"icon.png"];
    return [NSFileManager.defaultManager fileExistsAtPath:plain] ? plain : nil;
}
static UIImage *app_icon(void) { NSString *p = app_icon_path(); return p ? [UIImage imageWithContentsOfFile:p] : nil; }
static NSString *thumbnail_path(UNNotificationContent *c) {
    for (UNNotificationAttachment *a in c.attachments) if (type_is_image(a.type) && a.URL.path) return a.URL.path;
    return nil;
}

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
    NSString *thumb = thumbnail_path(c);
    CGFloat width = MIN(screen.size.width - 16, 400), x = (screen.size.width - width) / 2, textX = 60, textW = width - textX - 14 - (thumb ? 46 : 0);
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
    title.frame = CGRectMake(textX, 13, textW - 40 + (thumb ? 46 : 0), 20);
    when.frame = CGRectMake(width - 54, 13, 40, 18);
    body.frame = CGRectMake(textX, 34, textW, ceil(bs.height));
    NSMutableArray *parts = [@[icon, title, when, body] mutableCopy];
    if (thumb) {                                                   /* an image attachment's thumbnail on the right, like iOS */
        UIImageView *t = [[UIImageView alloc] initWithFrame:CGRectMake(width - 14 - 38, height - 14 - 38, 38, 38)];
        t.image = [UIImage imageWithContentsOfFile:thumb]; t.contentMode = UIViewContentModeScaleAspectFill;
        t.layer.cornerRadius = 6; t.clipsToBounds = YES; t.accessibilityIdentifier = @"isim-notification-thumbnail";
        [parts addObject:t];
    }
    for (UIView *v in parts) { v.userInteractionEnabled = NO; [card addSubview:v]; }
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
        /* the shell's banner (or Notification Center item) for a notification was tapped */
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimNotificationResponse" object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self isim_respondTo:note.object action:UNNotificationDefaultActionIdentifier text:nil record:nil];
        }];
        /* in the background: tell the shell when the next notification is due (it wakes a suspended app for it) */
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *n) { [self reportWake]; }];
    }
    return self;
}
- (BOOL)supportsContentExtensions { return YES; }

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
- (void)setNotificationCategories:(NSSet<UNNotificationCategory *> *)categories {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized(self) {
        _categories = [categories copy];
        for (UNNotificationCategory *c in _categories) [out addObject:encode_category(c)];
    }
    NSString *f = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/isim/NotificationCategories.plist"];
    [NSFileManager.defaultManager createDirectoryAtPath:f.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    [@{ @"categories": out } writeToFile:f atomically:YES];
    NSLog(@"isim UserNotifications: %lu notification categor%@ registered", (unsigned long)out.count, out.count == 1 ? @"y" : @"ies");
}
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
    [self reportWake];
}
/* the shell's wake-up time for this app while it is in the background (seconds since 1970; 0: none) */
- (void)reportWake {
    if (!isim_shell_present()) return;
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self reportWake]; }); return; }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateBackground) return;
    double next = 0;
    for (UNNotificationRequest *r in _pending) { double f = [self nextFire:r]; if (f > 0 && (next == 0 || f < next)) next = f; }
    char t[64]; snprintf(t, sizeof t, "%.3f", next);
    isim_shell_request(ISIM_SHELL_SYSTEM, "bg-wake", t, NULL);
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
    [self deliver:n push:NO];
}

/* shows a notification: the delegate decides in the foreground; in the background the shell shows the banner */
- (void)deliver:(UNNotification *)n push:(BOOL)push {
    UNNotificationRequest *r = n.request;
    if (![self authorized]) { NSLog(@"isim UserNotifications: “%@” not shown (notifications are not allowed for %@)", r.identifier, app_name()); return; }
    for (NSUInteger i = 0; i < _delivered.count; i++)
        if ([_delivered[i].request.identifier isEqualToString:r.identifier]) { [_delivered removeObjectAtIndex:i]; break; }
    [_delivered addObject:n];
    NSString *record = write_record(n, push);
    NSString *thumb = thumbnail_path(r.content) ?: @"";
    UIApplication *app = UIApplication.sharedApplication;
    UNAuthorizationOptions granted0 = [self grantedOptions];
    if (app.applicationState == UIApplicationStateBackground) {
        NSLog(@"isim UserNotifications: delivered “%@” in the background", r.identifier);
        if (r.content.badge && (granted0 & UNAuthorizationOptionBadge)) app.applicationIconBadgeNumber = r.content.badge.integerValue;
        if (r.content.sound && (granted0 & UNAuthorizationOptionSound)) NSLog(@"isim UserNotifications: sound “%@” (not played)", r.content.sound.isimName ?: @"default");
        if (isim_shell_present() && ((granted0 & UNAuthorizationOptionAlert) || [self status] == UNAuthorizationStatusProvisional)) {
            NSString *a = [NSString stringWithFormat:@"%@\x1f%@\x1f%@\x1f%@", r.identifier, app_icon_path() ?: @"", record ?: @"", thumb];
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
            if ((o & UNNotificationPresentationOptionSound) && r.content.sound && (granted & UNAuthorizationOptionSound))
                NSLog(@"isim UserNotifications: sound “%@” (not played)", r.content.sound.isimName ?: @"default");
            BOOL banner = (o & (UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionAlert)) != 0;
            NSLog(@"isim UserNotifications: delivered “%@” in the foreground (%@)", r.identifier, banner ? @"banner" : @"not presented");
            if ((o & UNNotificationPresentationOptionList) || banner) {      /* the shell's Notification Center lists it */
                NSString *a = [NSString stringWithFormat:@"%@\x1f%@\x1f%@\x1f%@", r.identifier, app_icon_path() ?: @"", record ?: @"", thumb];
                NSString *tb = [NSString stringWithFormat:@"%@\x1f%@", r.content.title.length ? r.content.title : app_name(), r.content.body ?: @""];
                isim_shell_request(ISIM_SHELL_SYSTEM, "notified", a.UTF8String, tb.UTF8String);
            }
            if (banner && (granted & UNAuthorizationOptionAlert || [self status] == UNAuthorizationStatusProvisional))
                [ISIMNotificationBanner show:n onTap:^{ [self respond:n action:UNNotificationDefaultActionIdentifier text:nil]; }];
        });
    };
    if ([d respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)])
        [d userNotificationCenter:self willPresentNotification:n withCompletionHandler:present];
    else present(0);                                              /* iOS: no delegate, nothing shown in the foreground */
}

- (void)respond:(UNNotification *)n action:(NSString *)action { [self respond:n action:action text:nil]; }
- (void)respond:(UNNotification *)n action:(NSString *)action text:(NSString *)text {
    if ([action isEqualToString:UNNotificationDefaultActionIdentifier]) NSLog(@"isim UserNotifications: opened “%@”", n.request.identifier);
    else NSLog(@"isim UserNotifications: action %@ on “%@”%@", action, n.request.identifier, text ? [NSString stringWithFormat:@" with text “%@”", text] : @"");
    id<UNUserNotificationCenterDelegate> d = self.delegate;
    if (![d respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) {
        NSLog(@"isim UserNotifications: no delegate handles the response (set UNUserNotificationCenter.delegate)");
        return;
    }
    UNNotificationResponse *resp = text ? [UNTextInputNotificationResponse isim_responseWithNotification:n action:action text:text]
                                        : [UNNotificationResponse isim_responseWithNotification:n action:action];
    UIApplication *app = UIApplication.sharedApplication;
    __block UIBackgroundTaskIdentifier task = UIBackgroundTaskInvalid;
    if (app.applicationState == UIApplicationStateBackground)       /* a background action runs until its completion handler */
        task = [app beginBackgroundTaskWithName:@"notification response" expirationHandler:^{ [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; }];
    [d userNotificationCenter:self didReceiveNotificationResponse:resp withCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{ if (task != UIBackgroundTaskInvalid) { [app endBackgroundTask:task]; task = UIBackgroundTaskInvalid; } });
    }];
}
/* a response from the system (banner tap, Notification Center, an action under an expanded notification): the delivered
   notification, else the record written when it was delivered (the app was relaunched since) */
- (void)isim_respondTo:(NSString *)ident action:(NSString *)action text:(NSString *)text record:(NSString *)recordPath {
    UNNotification *n = nil;
    for (UNNotification *x in _delivered) if ([x.request.identifier isEqualToString:ident]) n = x;
    if (!n) n = notification_from_record([NSDictionary dictionaryWithContentsOfFile:recordPath.length ? recordPath : record_path_in(NSHomeDirectory(), ident)]);
    if (!n) { NSLog(@"isim UserNotifications: no notification “%@” to respond to", ident); return; }
    if (![action isEqualToString:UNNotificationDismissActionIdentifier])
        for (NSUInteger i = 0; i < _delivered.count; i++) if (_delivered[i] == n) { [_delivered removeObjectAtIndex:i]; break; }
    [self respond:n action:action text:text];
}

/* a remote notification for this app: present it like a local one (no alert: a silent push, only the badge) */
- (void)isim_deliverRemote:(NSDictionary *)wrapper opened:(BOOL)opened {
    NSDictionary *payload = wrapper[@"payload"];
    NSString *ident = wrapper[@"id"] ?: NSUUID.UUID.UUIDString;
    UNMutableNotificationContent *c = content_from_payload(payload, wrapper[@"attachments"]);
    if ([wrapper[@"content"] isKindOfClass:[NSDictionary class]]) {      /* the Notification Service extension's content */
        NSDictionary *m = wrapper[@"content"];
        c.title = m[@"title"]; c.subtitle = m[@"subtitle"]; c.body = m[@"body"]; c.categoryIdentifier = m[@"category"]; c.threadIdentifier = m[@"thread"];
        if (m[@"badge"]) c.badge = m[@"badge"];
        if ([m[@"userInfo"] isKindOfClass:[NSDictionary class]] && [m[@"userInfo"] count]) c.userInfo = m[@"userInfo"];
        c.attachments = decode_attachments(m[@"attachments"]);
        if (m[@"targetContentIdentifier"]) c.targetContentIdentifier = m[@"targetContentIdentifier"];
    }
    UNNotificationRequest *r = [UNNotificationRequest requestWithIdentifier:ident content:c trigger:[[UNPushNotificationTrigger alloc] initISIMBase]];
    UNNotification *n = [UNNotification isim_notificationWithRequest:r date:[NSDate date]];
    if (opened) {                                               /* launched by tapping it: it was shown by the system */
        for (NSUInteger i = 0; i < _delivered.count; i++) if ([_delivered[i].request.identifier isEqualToString:ident]) { [_delivered removeObjectAtIndex:i]; break; }
        [self respond:n action:UNNotificationDefaultActionIdentifier text:nil];
        return;
    }
    if (!content_has_alert(c)) {
        NSLog(@"isim UserNotifications: remote notification “%@” has no alert (background notification)", ident);
        return;
    }
    NSLog(@"isim UserNotifications: remote notification “%@”%@", ident, wrapper[@"content"] ? @" (modified by the service extension)" : @"");
    [self deliver:n push:YES];
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
        NSError *e = nil;
        if (count < 0) e = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeBadgeInputInvalid userInfo:@{ NSLocalizedDescriptionKey: @"Invalid badge count" }];
        else UIApplication.sharedApplication.applicationIconBadgeNumber = count;     /* UIKit checks the badge permission and tells the home screen */
        if (done) on_background(^{ done(e); });
    });
}
@end

/* ---------------- entry points for UIKit (remote notifications, responses to system UI) ---------------- */

/* wrapper: { id, payload, attachments?, content? }; mode 0: the running app got it, 1: launched in the background for it,
   2: launched by tapping it (the system showed it) */
void isim_un_remote_notification(NSDictionary *wrapper, int mode) {
    [[UNUserNotificationCenter currentNotificationCenter] isim_deliverRemote:wrapper opened:mode == 2];
}
/* a response chosen in the system UI (an action under an expanded notification, or the default action): text for text input actions */
void isim_un_notification_action(NSString *record, NSString *ident, NSString *action, NSString *text) {
    [[UNUserNotificationCenter currentNotificationCenter] isim_respondTo:ident action:action.length ? action : UNNotificationDefaultActionIdentifier
                                                                    text:text record:record];
}

/* ---------------- Notification Service / Content extensions (helper processes) ----------------
 * NSExtensionMain (UIKit) calls isim_un_extension_main for the two notification extension points. The shell starts the
 * extension with ISIM_EXTENSION_REQUEST = a plist { mode = service | content; push = { id, payload } | record = path;
 * out = result plist path; width }, written by the home screen, which reads the result when the process exits. */

@implementation UNNotificationServiceExtension
- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *))contentHandler { contentHandler(request.content); }
- (void)serviceExtensionTimeWillExpire {}
@end

@protocol ISIMContentExtension <NSObject>
- (void)didReceiveNotification:(UNNotification *)notification;
@end

@interface __IsimNotificationExtensionHost : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation __IsimNotificationExtensionHost {
    NSDictionary *_req; NSString *_out; id _instance; BOOL _done;
}
static void finish_extension(NSDictionary *result, NSString *out) {
    [result writeToFile:out atomically:YES];
    fflush(NULL);
    dispatch_async(dispatch_get_main_queue(), ^{ exit(0); });
}
- (UIViewController *)makeViewController:(NSDictionary *)ext {
    Class cls = NSClassFromString(ext[@"NSExtensionPrincipalClass"] ?: @"");
    if ([cls isSubclassOfClass:[UIViewController class]]) return [cls new];
    NSString *sb = ext[@"NSExtensionMainStoryboard"];
    if (sb.length) return [[UIStoryboard storyboardWithName:sb bundle:NSBundle.mainBundle] instantiateInitialViewController];
    return nil;
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    const char *rp = getenv("ISIM_EXTENSION_REQUEST");
    _req = rp ? [NSDictionary dictionaryWithContentsOfFile:@(rp)] : nil;
    _out = _req[@"out"];
    NSDictionary *ext = NSBundle.mainBundle.infoDictionary[@"NSExtension"];
    if (!_req || !_out) { NSLog(@"isim: notification extension started without a request (ISIM_EXTENSION_REQUEST)"); exit(2); }
    if ([_req[@"mode"] isEqual:@"service"]) [self runService:ext];
    else [self runContent:ext];
    return YES;
}
- (void)runService:(NSDictionary *)ext {
    NSString *principal = ext[@"NSExtensionPrincipalClass"];
    Class cls = NSClassFromString(principal ?: @"");
    if (![cls isSubclassOfClass:[UNNotificationServiceExtension class]]) {
        NSLog(@"isim: Notification Service extension: principal class %@ is not a UNNotificationServiceExtension", principal ?: @"(none)");
        finish_extension(@{ @"error": @"no principal class" }, _out); return;
    }
    NSDictionary *push = _req[@"push"];
    NSString *ident = push[@"id"] ?: NSUUID.UUID.UUIDString;
    UNMutableNotificationContent *c = content_from_payload(push[@"payload"], nil);
    UNNotificationRequest *r = [UNNotificationRequest requestWithIdentifier:ident content:c trigger:[[UNPushNotificationTrigger alloc] initISIMBase]];
    UNNotificationServiceExtension *x = [cls new];
    _instance = x;
    NSString *out = _out;
    __block BOOL done = NO, expired = NO;
    void (^handler)(UNNotificationContent *) = ^(UNNotificationContent *content) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done) return;
            done = YES;
            NSLog(@"isim: Notification Service extension delivered “%@”%@ (title “%@”, %lu attachment(s))", ident, expired ? @" after serviceExtensionTimeWillExpire" : @"",
                  content.title ?: @"", (unsigned long)content.attachments.count);
            finish_extension(@{ @"content": encode_content(content ?: c), @"expired": @(expired) }, out);
        });
    };
    NSLog(@"isim: Notification Service extension %@ didReceive “%@”", principal, ident);
    [x didReceiveNotificationRequest:r withContentHandler:handler];
    const char *e = getenv("ISIM_NOTIFICATION_SERVICE_SECONDS");
    double limit = e && atof(e) > 0 ? atof(e) : 30;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(limit * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (done) return;
        expired = YES;
        NSLog(@"isim: Notification Service extension: serviceExtensionTimeWillExpire (after %g s)", limit);
        [x serviceExtensionTimeWillExpire];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (done) return;
            done = YES;
            NSLog(@"isim: Notification Service extension did not call the content handler; the original content is shown");
            finish_extension(@{ @"expired": @YES }, out);
        });
    });
}
- (void)runContent:(NSDictionary *)ext {
    UNNotification *n = notification_from_record([NSDictionary dictionaryWithContentsOfFile:_req[@"record"] ?: @""]);
    UIViewController *vc = [self makeViewController:ext];
    if (!n || !vc) {
        NSLog(@"isim: Notification Content extension: %@", !n ? @"no notification record" : @"no view controller (NSExtensionPrincipalClass / NSExtensionMainStoryboard)");
        finish_extension(@{ @"error": @"failed" }, _out); return;
    }
    NSDictionary *attrs = ext[@"NSExtensionAttributes"];
    CGFloat width = [_req[@"width"] doubleValue] ?: UIScreen.mainScreen.bounds.size.width - 16;
    double ratio = [attrs[@"UNNotificationExtensionInitialContentSizeRatio"] doubleValue] ?: 1;
    CGFloat height = ceil(width * ratio);
    _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    _window.rootViewController = vc;
    [_window makeKeyAndVisible];
    vc.view.frame = CGRectMake(0, 0, width, height);
    _instance = vc;
    if ([vc respondsToSelector:@selector(didReceiveNotification:)]) [(id<ISIMContentExtension>)vc didReceiveNotification:n];
    else NSLog(@"isim: Notification Content extension: %@ does not implement didReceiveNotification:", NSStringFromClass(vc.class));
    NSLog(@"isim: Notification Content extension %@ didReceive “%@”", NSStringFromClass(vc.class), n.request.identifier);
    NSString *out = _out;
    UIWindow *w = _window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGFloat h = vc.preferredContentSize.height > 0 ? vc.preferredContentSize.height : height;
        w.frame = CGRectMake(0, 0, width, h); vc.view.frame = w.bounds;
        [vc.view setNeedsLayout]; [vc.view layoutIfNeeded];
        CGFloat scale = UIScreen.mainScreen.scale ?: 2;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, h), YES, scale);
        [[UIColor colorWithWhite:0.96 alpha:1] setFill]; UIRectFill(CGRectMake(0, 0, width, h));
        [vc.view drawViewHierarchyInRect:CGRectMake(0, 0, width, h) afterScreenUpdates:YES];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSString *png = [out.stringByDeletingPathExtension stringByAppendingPathExtension:@"png"];
        [UIImagePNGRepresentation(img) writeToFile:png atomically:YES];
        NSLog(@"isim: Notification Content extension rendered %.0f x %.0f", width, h);
        finish_extension(@{ @"image": png, @"width": @(width), @"height": @(h),
                            @"defaultContentHidden": @([attrs[@"UNNotificationExtensionDefaultContentHidden"] boolValue]) }, out);
    });
}
@end

int isim_un_extension_main(int argc, char **argv) {
    return UIApplicationMain(argc, argv, nil, @"__IsimNotificationExtensionHost");
}
