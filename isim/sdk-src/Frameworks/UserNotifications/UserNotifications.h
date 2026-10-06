#pragma once
/* isim SDK (self-authored): UserNotifications — local notifications.
 * isim: authorization asks with the iOS permission alert (remembered per app); time-interval and calendar
 * triggers fire while the app runs; in the foreground the delegate's willPresent decides whether a banner
 * shows (tapping it calls didReceive). Pending requests persist with the app's data. Push (APNs),
 * attachments, actions UI and notification extensions are not available. */
#import <Foundation/Foundation.h>
#ifndef NS_SWIFT_UNAVAILABLE
#define NS_SWIFT_UNAVAILABLE(_msg) __attribute__((availability(swift, unavailable, message=_msg)))
#endif
NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, UNAuthorizationOptions) {
    UNAuthorizationOptionBadge = (1 << 0),
    UNAuthorizationOptionSound = (1 << 1),
    UNAuthorizationOptionAlert = (1 << 2),
    UNAuthorizationOptionCarPlay = (1 << 3),
    UNAuthorizationOptionCriticalAlert = (1 << 4),
    UNAuthorizationOptionProvidesAppNotificationSettings = (1 << 5),
    UNAuthorizationOptionProvisional = (1 << 6),
    UNAuthorizationOptionAnnouncement = (1 << 7),
    UNAuthorizationOptionTimeSensitive = (1 << 8),
};
static const UNAuthorizationOptions UNAuthorizationOptionNone NS_SWIFT_UNAVAILABLE("Use [] instead.") = 0;
typedef NS_ENUM(NSInteger, UNAuthorizationStatus) {
    UNAuthorizationStatusNotDetermined = 0,
    UNAuthorizationStatusDenied,
    UNAuthorizationStatusAuthorized,
    UNAuthorizationStatusProvisional,
    UNAuthorizationStatusEphemeral,
};
typedef NS_ENUM(NSInteger, UNNotificationSetting) { UNNotificationSettingNotSupported = 0, UNNotificationSettingDisabled, UNNotificationSettingEnabled };
typedef NS_ENUM(NSInteger, UNAlertStyle) { UNAlertStyleNone = 0, UNAlertStyleBanner, UNAlertStyleAlert };
typedef NS_ENUM(NSInteger, UNShowPreviewsSetting) { UNShowPreviewsSettingAlways, UNShowPreviewsSettingWhenAuthenticated, UNShowPreviewsSettingNever };
typedef NS_OPTIONS(NSUInteger, UNNotificationPresentationOptions) {
    UNNotificationPresentationOptionBadge = (1 << 0),
    UNNotificationPresentationOptionSound = (1 << 1),
    UNNotificationPresentationOptionAlert = (1 << 2),
    UNNotificationPresentationOptionList = (1 << 3),
    UNNotificationPresentationOptionBanner = (1 << 4),
};
static const UNNotificationPresentationOptions UNNotificationPresentationOptionNone NS_SWIFT_UNAVAILABLE("Use [] instead.") = 0;
typedef NS_ENUM(NSUInteger, UNNotificationInterruptionLevel) {
    UNNotificationInterruptionLevelPassive,
    UNNotificationInterruptionLevelActive,
    UNNotificationInterruptionLevelTimeSensitive,
    UNNotificationInterruptionLevelCritical,
};
typedef NS_OPTIONS(NSUInteger, UNNotificationActionOptions) {
    UNNotificationActionOptionAuthenticationRequired = (1 << 0),
    UNNotificationActionOptionDestructive = (1 << 1),
    UNNotificationActionOptionForeground = (1 << 2),
};
typedef NS_OPTIONS(NSUInteger, UNNotificationCategoryOptions) {
    UNNotificationCategoryOptionCustomDismissAction = (1 << 0),
    UNNotificationCategoryOptionAllowInCarPlay = (1 << 1),
    UNNotificationCategoryOptionHiddenPreviewsShowTitle = (1 << 2),
    UNNotificationCategoryOptionHiddenPreviewsShowSubtitle = (1 << 3),
};

FOUNDATION_EXPORT NSString * const UNErrorDomain;
typedef NS_ENUM(NSInteger, UNErrorCode) {
    UNErrorCodeNotificationsNotAllowed = 1,
    UNErrorCodeAttachmentInvalidURL = 100,
    UNErrorCodeNotificationInvalidNoDate = 1400,
    UNErrorCodeNotificationInvalidNoContent = 1401,
};
FOUNDATION_EXPORT NSString * const UNNotificationDefaultActionIdentifier;
FOUNDATION_EXPORT NSString * const UNNotificationDismissActionIdentifier;

typedef NSString *UNNotificationSoundName NS_SWIFT_NAME(UNNotificationSoundName) NS_TYPED_EXTENSIBLE_ENUM;

@interface UNNotificationSound : NSObject <NSCopying>
@property (class, nonatomic, readonly, copy) UNNotificationSound *defaultSound NS_SWIFT_NAME(default);
@property (class, nonatomic, readonly, copy) UNNotificationSound *defaultCriticalSound;
+ (instancetype)soundNamed:(UNNotificationSoundName)name;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNNotificationAttachment : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, readonly, copy) NSString *type;
+ (nullable instancetype)attachmentWithIdentifier:(NSString *)identifier URL:(NSURL *)URL options:(nullable NSDictionary *)options error:(NSError *__autoreleasing _Nullable * _Nullable)error;
@end

@interface UNNotificationContent : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *subtitle;
@property (nonatomic, readonly, copy) NSString *body;
@property (nonatomic, readonly, copy, nullable) NSNumber *badge;
@property (nonatomic, readonly, copy, nullable) UNNotificationSound *sound;
@property (nonatomic, readonly, copy) NSDictionary *userInfo;
@property (nonatomic, readonly, copy) NSString *categoryIdentifier;
@property (nonatomic, readonly, copy) NSString *threadIdentifier;
@property (nonatomic, readonly, copy) NSString *launchImageName;
@property (nonatomic, readonly, copy, nullable) NSString *targetContentIdentifier;
@property (nonatomic, readonly, copy) NSString *summaryArgument;
@property (nonatomic, readonly) NSUInteger summaryArgumentCount;
@property (nonatomic, readonly, copy) NSArray<UNNotificationAttachment *> *attachments;
@property (nonatomic, readonly) UNNotificationInterruptionLevel interruptionLevel;
@property (nonatomic, readonly) double relevanceScore;
@property (nonatomic, readonly, copy, nullable) NSString *filterCriteria;
@end

@interface UNMutableNotificationContent : UNNotificationContent
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy, nullable) NSNumber *badge;
@property (nonatomic, copy, nullable) UNNotificationSound *sound;
@property (nonatomic, copy) NSDictionary *userInfo;
@property (nonatomic, copy) NSString *categoryIdentifier;
@property (nonatomic, copy) NSString *threadIdentifier;
@property (nonatomic, copy) NSString *launchImageName;
@property (nonatomic, copy, nullable) NSString *targetContentIdentifier;
@property (nonatomic, copy) NSString *summaryArgument;
@property (nonatomic) NSUInteger summaryArgumentCount;
@property (nonatomic, copy) NSArray<UNNotificationAttachment *> *attachments;
@property (nonatomic) UNNotificationInterruptionLevel interruptionLevel;
@property (nonatomic) double relevanceScore;
@property (nonatomic, copy, nullable) NSString *filterCriteria;
@end

@interface UNNotificationTrigger : NSObject <NSCopying>
@property (nonatomic, readonly) BOOL repeats;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNPushNotificationTrigger : UNNotificationTrigger
@end

@interface UNTimeIntervalNotificationTrigger : UNNotificationTrigger
@property (nonatomic, readonly) NSTimeInterval timeInterval;
/* raises NSInternalInconsistencyException for a non-positive interval, or one under 60 s that repeats (like iOS) */
+ (instancetype)triggerWithTimeInterval:(NSTimeInterval)timeInterval repeats:(BOOL)repeats;
- (nullable NSDate *)nextTriggerDate;
@end

/* Calendar triggers take DateComponents in Swift (see the UserNotifications overlay); the components are kept
 * as a dictionary of calendar units: era, year, month, day, hour, minute, second, weekday (1 = Sunday). */
@interface UNCalendarNotificationTrigger : UNNotificationTrigger
- (instancetype)initWithComponentValues:(NSDictionary<NSString *, NSNumber *> *)values repeats:(BOOL)repeats NS_REFINED_FOR_SWIFT;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSNumber *> *componentValues NS_REFINED_FOR_SWIFT;
- (nullable NSDate *)nextTriggerDate;
@end

@interface UNNotificationRequest : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) UNNotificationContent *content;
@property (nonatomic, readonly, copy, nullable) UNNotificationTrigger *trigger;
+ (instancetype)requestWithIdentifier:(NSString *)identifier content:(UNNotificationContent *)content trigger:(nullable UNNotificationTrigger *)trigger;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNNotification : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSDate *date;
@property (nonatomic, readonly, copy) UNNotificationRequest *request;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNNotificationResponse : NSObject <NSCopying>
@property (nonatomic, readonly, copy) UNNotification *notification;
@property (nonatomic, readonly, copy) NSString *actionIdentifier;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNTextInputNotificationResponse : UNNotificationResponse
@property (nonatomic, readonly, copy) NSString *userText;
@end

@interface UNNotificationAction : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly) UNNotificationActionOptions options;
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNTextInputNotificationAction : UNNotificationAction
@property (nonatomic, readonly, copy) NSString *textInputButtonTitle;
@property (nonatomic, readonly, copy) NSString *textInputPlaceholder;
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options textInputButtonTitle:(NSString *)textInputButtonTitle textInputPlaceholder:(NSString *)textInputPlaceholder;
@end

@interface UNNotificationCategory : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSArray<UNNotificationAction *> *actions;
@property (nonatomic, readonly, copy) NSArray<NSString *> *intentIdentifiers;
@property (nonatomic, readonly) UNNotificationCategoryOptions options;
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray<UNNotificationAction *> *)actions intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers options:(UNNotificationCategoryOptions)options;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface UNNotificationSettings : NSObject <NSCopying>
@property (nonatomic, readonly) UNAuthorizationStatus authorizationStatus;
@property (nonatomic, readonly) UNNotificationSetting soundSetting;
@property (nonatomic, readonly) UNNotificationSetting badgeSetting;
@property (nonatomic, readonly) UNNotificationSetting alertSetting;
@property (nonatomic, readonly) UNNotificationSetting notificationCenterSetting;
@property (nonatomic, readonly) UNNotificationSetting lockScreenSetting;
@property (nonatomic, readonly) UNNotificationSetting carPlaySetting;
@property (nonatomic, readonly) UNAlertStyle alertStyle;
@property (nonatomic, readonly) UNShowPreviewsSetting showPreviewsSetting;
@property (nonatomic, readonly) UNNotificationSetting criticalAlertSetting;
@property (nonatomic, readonly) BOOL providesAppNotificationSettings;
@property (nonatomic, readonly) UNNotificationSetting announcementSetting;
@property (nonatomic, readonly) UNNotificationSetting timeSensitiveSetting;
@property (nonatomic, readonly) UNNotificationSetting scheduledDeliverySetting;
@property (nonatomic, readonly) UNNotificationSetting directMessagesSetting;
- (instancetype)init NS_UNAVAILABLE;
@end

@class UNUserNotificationCenter;
@protocol UNUserNotificationCenterDelegate <NSObject>
@optional
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler;
- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(nullable UNNotification *)notification;
@end

@interface UNUserNotificationCenter : NSObject
@property (nonatomic, nullable, weak) id<UNUserNotificationCenterDelegate> delegate;
@property (nonatomic, readonly) BOOL supportsContentExtensions;
+ (UNUserNotificationCenter *)currentNotificationCenter NS_SWIFT_NAME(current());
- (instancetype)init NS_UNAVAILABLE;
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options completionHandler:(void (^)(BOOL granted, NSError *_Nullable error))completionHandler;
- (void)setNotificationCategories:(NSSet<UNNotificationCategory *> *)categories;
- (void)getNotificationCategoriesWithCompletionHandler:(void (^)(NSSet<UNNotificationCategory *> *categories))completionHandler;
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *settings))completionHandler;
- (void)addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)getPendingNotificationRequestsWithCompletionHandler:(void (^)(NSArray<UNNotificationRequest *> *requests))completionHandler;
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString *> *)identifiers;
- (void)removeAllPendingNotificationRequests;
- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray<UNNotification *> *notifications))completionHandler;
- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray<NSString *> *)identifiers;
- (void)removeAllDeliveredNotifications;
- (void)setBadgeCount:(NSInteger)newBadgeCount withCompletionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
@end

NS_ASSUME_NONNULL_END
