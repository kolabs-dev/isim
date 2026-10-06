#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIApplicationShortcutItem.h>
NS_ASSUME_NONNULL_BEGIN
@class UIApplication, UIWindow, UIScene, UISceneSession, UISceneConfiguration, UISceneConnectionOptions, UIEvent;
typedef NS_ENUM(NSInteger, UIApplicationState) { UIApplicationStateActive, UIApplicationStateInactive, UIApplicationStateBackground };
typedef NSString *UIApplicationLaunchOptionsKey NS_TYPED_ENUM;
typedef NSString *UIApplicationOpenURLOptionsKey NS_TYPED_ENUM;
typedef NSString *UIApplicationOpenExternalURLOptionsKey NS_TYPED_ENUM;
/* system integration (isim UISystemIntegration.m): quick actions, user activities, background work, alternate icons */
typedef NS_ENUM(NSUInteger, UIBackgroundFetchResult) { UIBackgroundFetchResultNewData, UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed };
typedef NS_ENUM(NSInteger, UIBackgroundRefreshStatus) { UIBackgroundRefreshStatusRestricted, UIBackgroundRefreshStatusDenied, UIBackgroundRefreshStatusAvailable };
typedef NSUInteger UIBackgroundTaskIdentifier NS_TYPED_ENUM;
UIKIT_EXTERN const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid;
UIKIT_EXTERN UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsURLKey, UIApplicationLaunchOptionsSourceApplicationKey,
    UIApplicationLaunchOptionsShortcutItemKey, UIApplicationLaunchOptionsUserActivityDictionaryKey, UIApplicationLaunchOptionsUserActivityTypeKey,
    UIApplicationLaunchOptionsRemoteNotificationKey, UIApplicationLaunchOptionsLocationKey;
UIKIT_EXTERN NSString * const UIApplicationLaunchOptionsUserActivityKey;   /* isim: the NSUserActivity in the activity dictionary */
UIKIT_EXTERN UIApplicationOpenURLOptionsKey const UIApplicationOpenURLOptionsSourceApplicationKey, UIApplicationOpenURLOptionsOpenInPlaceKey;
UIKIT_EXTERN UIApplicationOpenExternalURLOptionsKey const UIApplicationOpenURLOptionUniversalLinksOnly;
UIKIT_EXTERN NSNotificationName const UIApplicationBackgroundRefreshStatusDidChangeNotification;
UIKIT_EXTERN const NSTimeInterval UIApplicationBackgroundFetchIntervalMinimum, UIApplicationBackgroundFetchIntervalNever;
@protocol UIUserActivityRestoring <NSObject>
- (void)restoreUserActivityState:(NSUserActivity *)userActivity;
@end
UIKIT_EXTERN NSNotificationName const UIApplicationDidFinishLaunchingNotification, UIApplicationDidBecomeActiveNotification,
    UIApplicationWillResignActiveNotification, UIApplicationDidEnterBackgroundNotification,
    UIApplicationWillEnterForegroundNotification, UIApplicationWillTerminateNotification;

NS_SWIFT_UI_ACTOR
@protocol UIApplicationDelegate <NSObject>
@optional
- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions;
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions;
- (void)applicationDidFinishLaunching:(UIApplication *)application;
- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window;   /* UIInterfaceOrientationMask */
- (void)applicationDidBecomeActive:(UIApplication *)application;
- (void)applicationWillResignActive:(UIApplication *)application;
- (void)applicationDidEnterBackground:(UIApplication *)application;
- (void)applicationWillEnterForeground:(UIApplication *)application;
- (void)applicationWillTerminate:(UIApplication *)application;
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options;
- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions;
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler;
- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType;
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable restorableObjects))restorationHandler;
- (void)application:(UIApplication *)application didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error;
- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity;
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler;
- (BOOL)application:(UIApplication *)application shouldSaveSecureApplicationState:(NSCoder *)coder;
- (BOOL)application:(UIApplication *)application shouldRestoreSecureApplicationState:(NSCoder *)coder;
@property (nullable, nonatomic, strong) UIWindow *window;
@end

@interface UIApplication : UIResponder
@property (class, nonatomic, readonly) UIApplication *sharedApplication;
@property (nullable, nonatomic, assign) id<UIApplicationDelegate> delegate;
@property (nonatomic, readonly) UIApplicationState applicationState;
@property (nonatomic, readonly, getter=isStatusBarHidden) BOOL statusBarHidden;
- (void)_isim_setStatusBarHidden:(BOOL)hidden;      /* isim-private: SwiftUI statusBarHidden(_:) */
@property (nullable, nonatomic, readonly) UIWindow *keyWindow;
@property (nonatomic, readonly) NSArray<__kindof UIWindow *> *windows;
@property (nonatomic, readonly) NSSet<UIScene *> *connectedScenes;
/* isim: URLs are logged; with ISIM_OPEN_URLS=1, http(s)/mailto URLs open on the host desktop (xdg-open) */
- (BOOL)canOpenURL:(NSURL *)url;
- (void)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^ _Nullable)(BOOL success))completion;
@property (class, nonatomic, readonly) NSString *openSettingsURLString;
@property (nonatomic, readonly) NSSet<UISceneSession *> *openSessions;
@property (nonatomic, readonly) BOOL supportsMultipleScenes;
@property (nonatomic, getter=isIdleTimerDisabled) BOOL idleTimerDisabled;
@property (nonatomic) NSInteger applicationIconBadgeNumber;
- (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender forEvent:(nullable UIEvent *)event;
- (void)sendEvent:(UIEvent *)event;
/* isim: push notifications are not available; registration fails with NSCocoaErrorDomain 3010 */
- (void)registerForRemoteNotifications;
- (void)unregisterForRemoteNotifications;
@property (nonatomic, readonly, getter=isRegisteredForRemoteNotifications) BOOL registeredForRemoteNotifications;
- (void)beginIgnoringInteractionEvents;
- (void)endIgnoringInteractionEvents;
@end

/* quick actions: dynamic items, shown after the Info.plist UIApplicationShortcutItems (at most 4 in all) */
@interface UIApplication (UIApplicationShortcutItems)
@property (nullable, nonatomic, copy) NSArray<UIApplicationShortcutItem *> *shortcutItems;
@end
/* alternate app icons: Info.plist CFBundleIcons > CFBundleAlternateIcons (icon files or asset-catalog app icon sets) */
@interface UIApplication (UIAlternateApplicationIcons)
@property (nonatomic, readonly) BOOL supportsAlternateIcons;
- (void)setAlternateIconName:(nullable NSString *)alternateIconName completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
@property (nullable, nonatomic, readonly) NSString *alternateIconName;
@end
/* background execution. isim does not suspend apps; background tasks expire after backgroundTimeRemaining
   (30 s, ISIM_BACKGROUND_TASK_SECONDS) like iOS */
@interface UIApplication (UIBackgroundTasks)
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:(void (^ _Nullable)(void))handler;
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^ _Nullable)(void))handler;
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)identifier;
@property (nonatomic, readonly) NSTimeInterval backgroundTimeRemaining;
@property (nonatomic, readonly) UIBackgroundRefreshStatus backgroundRefreshStatus;
- (void)setMinimumBackgroundFetchInterval:(NSTimeInterval)minimumBackgroundFetchInterval;
@end
/* scenes on demand (iPad multiple windows) */
@interface UIApplication (UIMultipleScenes)
- (void)requestSceneSessionActivation:(nullable UISceneSession *)sceneSession userActivity:(nullable NSUserActivity *)userActivity
                              options:(nullable id)options errorHandler:(nullable void (^)(NSError *error))errorHandler;
- (void)requestSceneSessionDestruction:(UISceneSession *)sceneSession options:(nullable id)options errorHandler:(nullable void (^)(NSError *error))errorHandler;
- (void)requestSceneSessionRefresh:(UISceneSession *)sceneSession;
@end
/* user activities on responders (state restoration, Handoff, Spotlight) */
@interface UIResponder (UIActivityContinuation) <UIUserActivityRestoring>
@property (nullable, nonatomic, strong) NSUserActivity *userActivity;
- (void)updateUserActivityState:(NSUserActivity *)activity;
- (void)restoreUserActivityState:(NSUserActivity *)activity;
@end

UIKIT_EXTERN int UIApplicationMain(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName);
NS_ASSUME_NONNULL_END
