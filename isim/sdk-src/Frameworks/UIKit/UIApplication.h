#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIView.h>
#import <UIKit/UIApplicationShortcutItem.h>
#import <_CKShareMetadata/_CKShareMetadata.h>   /* CKShareMetadata, which Swift resolves to CloudKit's CKShare.Metadata (#630) */
NS_ASSUME_NONNULL_BEGIN
@class UIApplication, UIWindow, UIScene, UISceneSession, UISceneConfiguration, UISceneConnectionOptions, UIEvent, UIViewController;
typedef NS_ENUM(NSInteger, UIApplicationState) { UIApplicationStateActive, UIApplicationStateInactive, UIApplicationStateBackground };
typedef NS_ENUM(NSUInteger, UIBackgroundFetchResult) { UIBackgroundFetchResultNewData, UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed };
typedef NSString *UIApplicationLaunchOptionsKey NS_TYPED_ENUM;
typedef NSString *UIApplicationOpenURLOptionsKey NS_TYPED_ENUM;
typedef NSString *UIApplicationOpenExternalURLOptionsKey NS_TYPED_ENUM;
/* system integration (isim UISystemIntegration.m): quick actions, user activities, background work, alternate icons */
typedef NS_ENUM(NSInteger, UIBackgroundRefreshStatus) { UIBackgroundRefreshStatusRestricted, UIBackgroundRefreshStatusDenied, UIBackgroundRefreshStatusAvailable };
typedef NSUInteger UIBackgroundTaskIdentifier NS_TYPED_ENUM;
UIKIT_EXTERN const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid;
/* the main run loop's mode while a scroll view is dragged or decelerates (one of its common modes) */
UIKIT_EXTERN NSRunLoopMode const UITrackingRunLoopMode NS_SWIFT_NAME(tracking);
UIKIT_EXTERN UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsURLKey, UIApplicationLaunchOptionsSourceApplicationKey,
    UIApplicationLaunchOptionsShortcutItemKey, UIApplicationLaunchOptionsUserActivityDictionaryKey, UIApplicationLaunchOptionsUserActivityTypeKey,
    UIApplicationLaunchOptionsRemoteNotificationKey, UIApplicationLaunchOptionsLocationKey;
UIKIT_EXTERN NSString * const UIApplicationLaunchOptionsUserActivityKey;   /* isim: the NSUserActivity in the activity dictionary */
/* the CKShareMetadata of a CloudKit share link that launched the app (an app that is not scene-based) */
UIKIT_EXTERN UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsCloudKitShareMetadataKey NS_SWIFT_NAME(cloudKitShareMetadata) API_AVAILABLE(ios(10.0));
UIKIT_EXTERN UIApplicationOpenURLOptionsKey const UIApplicationOpenURLOptionsSourceApplicationKey, UIApplicationOpenURLOptionsOpenInPlaceKey;
/* deprecated keys (isim: never in the options: no Bluetooth state restoration launches, no Newsstand, no annotation) */
UIKIT_EXTERN UIApplicationOpenURLOptionsKey const UIApplicationOpenURLOptionsAnnotationKey API_DEPRECATED("not used by UIScene apps", ios(9.0, 26.0));
UIKIT_EXTERN UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsNewsstandDownloadsKey API_DEPRECATED("Newsstand is gone", ios(5.0, 26.0));
UIKIT_EXTERN UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsBluetoothCentralsKey, UIApplicationLaunchOptionsBluetoothPeripheralsKey
    API_DEPRECATED("Use UIScene state restoration", ios(7.0, 26.0));
UIKIT_EXTERN UIApplicationOpenExternalURLOptionsKey const UIApplicationOpenURLOptionUniversalLinksOnly;
/* a UIEventAttribution for private click measurement (UIEventAttribution.h) */
UIKIT_EXTERN UIApplicationOpenExternalURLOptionsKey const UIApplicationOpenExternalURLOptionsEventAttributionKey API_AVAILABLE(ios(14.5));
UIKIT_EXTERN UIApplicationOpenURLOptionsKey const UIApplicationOpenURLOptionsEventAttributionKey API_AVAILABLE(ios(14.5));
UIKIT_EXTERN UIApplicationLaunchOptionsKey const UIApplicationLaunchOptionsEventAttributionKey API_AVAILABLE(ios(14.5));
UIKIT_EXTERN NSNotificationName const UIApplicationBackgroundRefreshStatusDidChangeNotification;
UIKIT_EXTERN const NSTimeInterval UIApplicationBackgroundFetchIntervalMinimum, UIApplicationBackgroundFetchIntervalNever;
UIKIT_EXTERN NSNotificationName const UIApplicationDidFinishLaunchingNotification, UIApplicationDidBecomeActiveNotification,
    UIApplicationWillResignActiveNotification, UIApplicationDidEnterBackgroundNotification,
    UIApplicationWillEnterForegroundNotification, UIApplicationWillTerminateNotification;
/* posted around an interface rotation (deprecated in iOS 13, still sent): userInfo UIApplicationStatusBarOrientationUserInfoKey,
   the new orientation (will change) or the old one (did change) */
UIKIT_EXTERN NSNotificationName const UIApplicationWillChangeStatusBarOrientationNotification API_DEPRECATED("Use viewWillTransitionToSize:withTransitionCoordinator: instead.", ios(2.0, 13.0));
UIKIT_EXTERN NSNotificationName const UIApplicationDidChangeStatusBarOrientationNotification API_DEPRECATED("Use viewWillTransitionToSize:withTransitionCoordinator: instead.", ios(2.0, 13.0));
UIKIT_EXTERN NSString *const UIApplicationStatusBarOrientationUserInfoKey API_DEPRECATED("Use viewWillTransitionToSize:withTransitionCoordinator: instead.", ios(2.0, 13.0));
/* isim: sent by Debug > Simulate Memory Warning (script command memorywarning) */
UIKIT_EXTERN NSNotificationName const UIApplicationDidReceiveMemoryWarningNotification;
/* isim: at local midnight and when the time zone changes (Settings > General > Date & Time) */
UIKIT_EXTERN NSNotificationName const UIApplicationSignificantTimeChangeNotification;
/* isim: script command `takescreenshot` (the Simulator's Device > Trigger Screenshot) */
UIKIT_EXTERN NSNotificationName const UIApplicationUserDidTakeScreenshotNotification API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSNotificationName const UIApplicationProtectedDataWillBecomeUnavailable NS_SWIFT_NAME(UIApplication.protectedDataWillBecomeUnavailableNotification);
UIKIT_EXTERN NSNotificationName const UIApplicationProtectedDataDidBecomeAvailable NS_SWIFT_NAME(UIApplication.protectedDataDidBecomeAvailableNotification);

@class NSUserActivity, INIntent, INIntentResponse;
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
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application;
- (void)applicationSignificantTimeChange:(UIApplication *)application;
/* the device was locked / unlocked (UIApplication.isProtectedDataAvailable) */
- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application;
- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application;
/* isim never remaps key commands for localized keyboards, nor asks for HealthKit access this way */
- (BOOL)applicationShouldAutomaticallyLocalizeKeyCommands:(UIApplication *)application API_AVAILABLE(ios(15.0));
- (void)applicationShouldRequestHealthAuthorization:(UIApplication *)application;
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options;
- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions;
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler;
- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType;
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable restorableObjects))restorationHandler;
/* the person opened a CloudKit share link of the app's container (https://www.icloud.com/share/…): accept it with
   CKAcceptSharesOperation or -[CKContainer acceptShareMetadata:completionHandler:]. isim: Objective-C apps (Swift sees this
   requirement only once CloudKit's types resolve for UIKit's headers; until then use the scene's or the launch options') */
- (void)application:(UIApplication *)application userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata API_AVAILABLE(ios(10.0));
- (void)application:(UIApplication *)application didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error;
- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity;
/* SiriKit (Intents): Siri asks the app for the handler of an intent it lists in INIntentsSupported (run in the
   background, isim's simulated Siri); handleIntent is for media intents answered with .handleInApp */
- (nullable id)application:(UIApplication *)application handlerForIntent:(INIntent *)intent API_AVAILABLE(ios(14.0));
- (void)application:(UIApplication *)application handleIntent:(INIntent *)intent completionHandler:(void (^)(INIntentResponse *intentResponse))completionHandler;
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler;
- (BOOL)application:(UIApplication *)application shouldSaveSecureApplicationState:(NSCoder *)coder;
- (BOOL)application:(UIApplication *)application shouldRestoreSecureApplicationState:(NSCoder *)coder;
- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder API_DEPRECATED_WITH_REPLACEMENT("application:shouldSaveSecureApplicationState:", ios(6.0, 13.2));
- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder API_DEPRECATED_WITH_REPLACEMENT("application:shouldRestoreSecureApplicationState:", ios(6.0, 13.2));
- (nullable UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray<NSString *> *)identifierComponents coder:(NSCoder *)coder;
- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder;
- (void)application:(UIApplication *)application didDecodeRestorableStateWithCoder:(NSCoder *)coder;
/* isim: there is no APNs; payloads come from `isim push` (in the foreground for every push, in the background for
   "content-available": 1 with UIBackgroundModes remote-notification, launching the app in the background if needed).
   isim's CloudKit also delivers subscription notifications here, in-process */
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo API_DEPRECATED("Use UserNotifications Framework's -[UNUserNotificationCenterDelegate willPresentNotification:withCompletionHandler:] or -[UNUserNotificationCenterDelegate didReceiveNotificationResponse:withCompletionHandler:] for user visible notifications and -[UIApplicationDelegate application:didReceiveRemoteNotification:fetchCompletionHandler:] for silent remote notifications", ios(3.0, 10.0));
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
/* openSettingsURLString: UIApplicationOpenSettingsURLString (UIWindowSceneExtras.h) */
@property (nonatomic, readonly) NSSet<UISceneSession *> *openSessions;
@property (nonatomic, readonly) BOOL supportsMultipleScenes;
/* isim: under `isim boot` with ISIM_AUTOLOCK=SECONDS the device locks after that long without input, unless the
   foreground app disabled the idle timer */
@property (nonatomic, getter=isIdleTimerDisabled) BOOL idleTimerDisabled;
/* isim: shown on the home-screen icon when the app may badge (UNAuthorizationOptionBadge) */
@property (nonatomic) NSInteger applicationIconBadgeNumber API_DEPRECATED("Use -[UNUserNotificationCenter setBadgeCount:withCompletionHandler:] instead.", ios(2.0, 17.0));
- (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender forEvent:(nullable UIEvent *)event;
- (void)sendEvent:(UIEvent *)event;
/* isim: like the Simulator (Xcode 14+), registration gives a device token (the app needs the aps-environment
   entitlement); ISIM_PUSH_REGISTRATION=fail makes it fail with NSCocoaErrorDomain 3010 */
- (void)registerForRemoteNotifications;
- (void)unregisterForRemoteNotifications;
@property (nonatomic, readonly, getter=isRegisteredForRemoteNotifications) BOOL registeredForRemoteNotifications;
- (void)beginIgnoringInteractionEvents;
- (void)endIgnoringInteractionEvents;
@end

/* quick actions: dynamic items, shown after the Info.plist UIApplicationShortcutItems (at most 4 in all) */
@interface UIApplication (UIRightToLeft)
@property (nonatomic, readonly) UIUserInterfaceLayoutDirection userInterfaceLayoutDirection;
@end
@interface UIApplication (UIApplicationShortcutItems)
@property (nullable, nonatomic, copy) NSArray<UIApplicationShortcutItem *> *shortcutItems;
@end
/* alternate app icons: Info.plist CFBundleIcons > CFBundleAlternateIcons (icon files or asset-catalog app icon sets) */
@interface UIApplication (UIAlternateApplicationIcons)
@property (nonatomic, readonly) BOOL supportsAlternateIcons;
- (void)setAlternateIconName:(nullable NSString *)alternateIconName completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
@property (nullable, nonatomic, readonly) NSString *alternateIconName;
@end
/* background execution. Under `isim boot` an app in the background is suspended a few seconds after it got there
   (ISIM_SUSPEND_SECONDS, default 5; ISIM_SUSPEND=0 never) unless a background task, background audio or background
   location updates keep it running; background tasks expire after backgroundTimeRemaining (30 s,
   ISIM_BACKGROUND_TASK_SECONDS) like iOS */
@interface UIApplication (UIBackgroundTasks)
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:(void (^ _Nullable)(void))handler;
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^ _Nullable)(void))handler;
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)identifier;
@property (nonatomic, readonly) NSTimeInterval backgroundTimeRemaining;
@property (nonatomic, readonly) UIBackgroundRefreshStatus backgroundRefreshStatus;
- (void)setMinimumBackgroundFetchInterval:(NSTimeInterval)minimumBackgroundFetchInterval;
@end
/* scenes on demand (iPad multiple windows, UIApplicationSupportsMultipleScenes). isim (adapted): up to two scenes are
   shown side by side (split view, widths after their size restrictions), a prominent one takes the screen, the
   others wait in the background; iPhone apps get UISceneErrorCodeMultipleScenesNotSupported for new scenes */
@class UISceneActivationRequestOptions, UISceneDestructionRequestOptions, UISceneSessionActivationRequest;
@interface UIApplication (UIMultipleScenes)
- (void)requestSceneSessionActivation:(nullable UISceneSession *)sceneSession userActivity:(nullable NSUserActivity *)userActivity
                              options:(nullable UISceneActivationRequestOptions *)options errorHandler:(nullable void (^)(NSError *error))errorHandler;
- (void)activateSceneSessionForRequest:(UISceneSessionActivationRequest *)request errorHandler:(nullable void (^)(NSError *error))errorHandler
    NS_SWIFT_NAME(activateSceneSession(for:errorHandler:)) API_AVAILABLE(ios(17.0));
- (void)requestSceneSessionDestruction:(UISceneSession *)sceneSession options:(nullable UISceneDestructionRequestOptions *)options errorHandler:(nullable void (^)(NSError *error))errorHandler;
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
