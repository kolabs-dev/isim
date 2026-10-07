#pragma once
/* isim SDK (self-authored): UserNotificationsUI — Notification Content extensions.
 * isim runs a content extension (NSExtensionPointIdentifier com.apple.usernotifications.content-extension) as a helper
 * process when a notification of one of its UNNotificationExtensionCategory categories is expanded (long press in
 * Notification Center, on the lock screen or on a banner): the principal view controller gets didReceiveNotification:,
 * and its view is rendered into the expanded notification (an image: the custom UI is not interactive). The category's
 * actions are listed under it; responses go to the app (UNNotificationContentExtensionResponseOptionDismissAndForwardAction). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UNNotificationContentExtensionMediaPlayPauseButtonType) {
    UNNotificationContentExtensionMediaPlayPauseButtonTypeNone,
    UNNotificationContentExtensionMediaPlayPauseButtonTypeDefault,
    UNNotificationContentExtensionMediaPlayPauseButtonTypeOverlay,
};
typedef NS_ENUM(NSUInteger, UNNotificationContentExtensionResponseOption) {
    UNNotificationContentExtensionResponseOptionDoNotDismiss,
    UNNotificationContentExtensionResponseOptionDismiss,
    UNNotificationContentExtensionResponseOptionDismissAndForwardAction,
};

@protocol UNNotificationContentExtension <NSObject>
- (void)didReceiveNotification:(UNNotification *)notification;
@optional
- (void)didReceiveNotificationResponse:(UNNotificationResponse *)response completionHandler:(void (^)(UNNotificationContentExtensionResponseOption option))completion;
@property (nonatomic, readonly, assign) UNNotificationContentExtensionMediaPlayPauseButtonType mediaPlayPauseButtonType;
@property (nonatomic, readonly, assign) CGRect mediaPlayPauseButtonFrame;
@property (nonatomic, readonly, copy) UIColor *mediaPlayPauseButtonTintColor;
- (void)mediaPlay;
- (void)mediaPause;
@end

@interface NSExtensionContext (UNNotificationContentExtension)
/* isim: the actions shown under the expanded notification are the category's; changes made here are logged */
@property (nonatomic, copy) NSArray<UNNotificationAction *> *notificationActions API_AVAILABLE(ios(12.0));
- (void)mediaPlayingStarted;
- (void)mediaPlayingPaused;
- (void)performNotificationDefaultAction API_AVAILABLE(ios(12.0));
- (void)dismissNotificationContentExtension API_AVAILABLE(ios(12.0));
@end

NS_ASSUME_NONNULL_END
