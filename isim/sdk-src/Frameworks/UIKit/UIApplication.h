#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIResponder.h>
NS_ASSUME_NONNULL_BEGIN
@class UIApplication, UIWindow, UIScene, UISceneSession, UISceneConfiguration, UISceneConnectionOptions, UIEvent;
typedef NS_ENUM(NSInteger, UIApplicationState) { UIApplicationStateActive, UIApplicationStateInactive, UIApplicationStateBackground };
typedef NSString *UIApplicationLaunchOptionsKey NS_TYPED_ENUM;
typedef NSString *UIApplicationOpenURLOptionsKey NS_TYPED_ENUM;
typedef NSString *UIApplicationOpenExternalURLOptionsKey NS_TYPED_ENUM;
UIKIT_EXTERN NSNotificationName const UIApplicationDidFinishLaunchingNotification, UIApplicationDidBecomeActiveNotification,
    UIApplicationWillResignActiveNotification, UIApplicationDidEnterBackgroundNotification,
    UIApplicationWillEnterForegroundNotification, UIApplicationWillTerminateNotification;

@class NSUserActivity;
NS_SWIFT_UI_ACTOR
@protocol UIUserActivityRestoring <NSObject>
- (void)restoreUserActivityState:(NSUserActivity *)userActivity;
@end
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
/* universal links and other user activities (isim: `openurl https://...` for a domain in the app's applinks) */
- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType;
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *_Nullable restorableObjects))restorationHandler;
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

UIKIT_EXTERN int UIApplicationMain(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName);
NS_ASSUME_NONNULL_END
