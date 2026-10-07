/* isim UserNotificationsUI: the NSExtensionContext additions for Notification Content extensions (the extension host is
 * in UserNotifications.m, isim_un_extension_main). The rendered view is a snapshot, so these are recorded and logged. */
#import <UserNotificationsUI/UserNotificationsUI.h>
#import <objc/runtime.h>

static char kActions;
@implementation NSExtensionContext (UNNotificationContentExtension)
- (NSArray<UNNotificationAction *> *)notificationActions { return objc_getAssociatedObject(self, &kActions) ?: @[]; }
- (void)setNotificationActions:(NSArray<UNNotificationAction *> *)a {
    objc_setAssociatedObject(self, &kActions, [a copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *ids = [NSMutableArray array];
    for (UNNotificationAction *x in a) [ids addObject:x.identifier ?: @""];
    NSLog(@"isim UserNotificationsUI: notificationActions = [%@] (isim lists the category's actions)", [ids componentsJoinedByString:@", "]);
}
- (void)mediaPlayingStarted { NSLog(@"isim UserNotificationsUI: media playing started"); }
- (void)mediaPlayingPaused { NSLog(@"isim UserNotificationsUI: media playing paused"); }
- (void)performNotificationDefaultAction { NSLog(@"isim UserNotificationsUI: performNotificationDefaultAction (not available: the expanded view is a snapshot)"); }
- (void)dismissNotificationContentExtension { NSLog(@"isim UserNotificationsUI: dismissNotificationContentExtension"); }
@end
