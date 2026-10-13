/* isim UserNotificationsUI: the NSExtensionContext additions for Notification Content extensions. The extension host
 * (UserNotifications.m, isim_un_extension_main) listens for them while the expanded notification is up: the actions
 * shown under it, the play / pause state, and the extension's own answers (open the app with the default action,
 * dismiss the notification). */
#import <UserNotificationsUI/UserNotificationsUI.h>
#import <objc/runtime.h>

static char kActions;
static void post(NSDictionary *info) {
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimContentExtensionEvent" object:nil userInfo:info];
}
@implementation NSExtensionContext (UNNotificationContentExtension)
- (NSArray<UNNotificationAction *> *)notificationActions { return objc_getAssociatedObject(self, &kActions) ?: @[]; }
- (void)setNotificationActions:(NSArray<UNNotificationAction *> *)a {
    objc_setAssociatedObject(self, &kActions, [a copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *ids = [NSMutableArray array], *plist = [NSMutableArray array];
    for (UNNotificationAction *x in a) {
        [ids addObject:x.identifier ?: @""];
        NSMutableDictionary *d = [@{ @"id": x.identifier ?: @"", @"title": x.title ?: @"", @"options": @(x.options) } mutableCopy];
        if ([x isKindOfClass:[UNTextInputNotificationAction class]]) {
            UNTextInputNotificationAction *t = (UNTextInputNotificationAction *)x;
            d[@"textInput"] = @YES; d[@"button"] = t.textInputButtonTitle ?: @"Send"; d[@"placeholder"] = t.textInputPlaceholder ?: @"";
        }
        [plist addObject:d];
    }
    NSLog(@"isim UserNotificationsUI: notificationActions = [%@]", [ids componentsJoinedByString:@", "]);
    post(@{ @"event": @"actions", @"actions": plist });
}
- (void)mediaPlayingStarted { NSLog(@"isim UserNotificationsUI: media playing started"); post(@{ @"event": @"media-started" }); }
- (void)mediaPlayingPaused { NSLog(@"isim UserNotificationsUI: media playing paused"); post(@{ @"event": @"media-paused" }); }
- (void)performNotificationDefaultAction { NSLog(@"isim UserNotificationsUI: performNotificationDefaultAction"); post(@{ @"event": @"default" }); }
- (void)dismissNotificationContentExtension { NSLog(@"isim UserNotificationsUI: dismissNotificationContentExtension"); post(@{ @"event": @"dismiss" }); }
@end
