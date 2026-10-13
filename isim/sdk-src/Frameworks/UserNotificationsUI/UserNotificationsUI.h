#pragma once
/* isim SDK (self-authored): UserNotificationsUI — Notification Content extensions.
 * isim runs a content extension (NSExtensionPointIdentifier com.apple.usernotifications.content-extension) as a helper
 * process when a notification of one of its UNNotificationExtensionCategory categories is expanded (long press in
 * Notification Center, on the lock screen or on a banner): the principal view controller gets didReceiveNotification:,
 * and its view is drawn in the expanded notification, rendered again whenever it changes. The helper lives as long as
 * the expanded notification: with UNNotificationExtensionUserInteractionEnabled, touches on the view reach the
 * extension's views; the media play / pause button (mediaPlayPauseButtonType, its frame and tint) is drawn over the
 * view and calls mediaPlay / mediaPause. The category's actions (or the ones set in notificationActions) are listed
 * under it; choosing one calls didReceiveNotificationResponse:completionHandler: when the extension implements it, and
 * its option keeps the notification, dismisses it, or dismisses it and forwards the action to the app (without the
 * method: forwarded). performNotificationDefaultAction opens the app; dismissNotificationContentExtension closes it. */
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
/* the actions shown under the expanded notification (initially the category's) */
@property (nonatomic, copy) NSArray<UNNotificationAction *> *notificationActions API_AVAILABLE(ios(12.0));
- (void)mediaPlayingStarted;
- (void)mediaPlayingPaused;
- (void)performNotificationDefaultAction API_AVAILABLE(ios(12.0));
- (void)dismissNotificationContentExtension API_AVAILABLE(ios(12.0));
@end

NS_ASSUME_NONNULL_END
