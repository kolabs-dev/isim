#pragma once
/* isim: the scene, window, screen and app members from the documentation sweep (#9): activation conditions,
   system protection, pointer lock, the status bar manager, windowing behaviours and control styles, activation
   actions and interactions, the window drag interaction, screen modes and display properties, the window's aspect-fit
   safe area guide, protected data, default-app checks and the Settings URLs. UISceneExtras.m. */
#import <UIKit/UIScene.h>
#import <UIKit/UIControl.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIOrientation.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIApplicationShortcutItem.h>
NS_ASSUME_NONNULL_BEGIN
@class UNNotificationResponse, CKShareMetadata, GCGameControllerActivationContext, CNContact, UITargetedPreview, UIGestureRecognizer, UILayoutGuide;

/* ---------------- UIApplication ---------------- */
/* the URL strings for Settings: the app's page, its notification settings, the default apps page */
UIKIT_EXTERN NSString *const UIApplicationOpenSettingsURLString NS_SWIFT_NAME(UIApplication.openSettingsURLString);
UIKIT_EXTERN NSString *const UIApplicationOpenNotificationSettingsURLString NS_SWIFT_NAME(UIApplication.openNotificationSettingsURLString) API_AVAILABLE(ios(16.0));
UIKIT_EXTERN NSString *const UIApplicationOpenDefaultApplicationsSettingsURLString NS_SWIFT_NAME(UIApplication.openDefaultApplicationsSettingsURLString) API_AVAILABLE(ios(18.3));
UIKIT_EXTERN NSExceptionName const UIApplicationInvalidInterfaceOrientationException NS_SWIFT_NAME(UIApplication.invalidInterfaceOrientationException);
typedef NSString *UIApplicationExtensionPointIdentifier NS_TYPED_ENUM NS_SWIFT_NAME(UIApplication.ExtensionPointIdentifier);
UIKIT_EXTERN UIApplicationExtensionPointIdentifier const UIApplicationKeyboardExtensionPointIdentifier NS_SWIFT_NAME(keyboard);
/* iOS 27: posted when systemPrefersReducedResourceUsage changes (isim: it follows Low Power Mode) */
UIKIT_EXTERN NSNotificationName const UIApplicationSystemPrefersReducedResourceUsageDidChangeNotification NS_SWIFT_NAME(UIApplication.systemPrefersReducedResourceUsageDidChangeNotification) API_AVAILABLE(ios(27.0));
/* iOS 18.2: is the app the default one of a category (isim: Settings > Apps > Default Apps, preference ISIMDefaultBrowser) */
typedef NS_ENUM(NSInteger, UIApplicationCategory) { UIApplicationCategoryWebBrowser = 1 } NS_SWIFT_NAME(UIApplication.Category) API_AVAILABLE(ios(18.2));
UIKIT_EXTERN NSErrorDomain const UIApplicationCategoryDefaultErrorDomain API_AVAILABLE(ios(18.2));
typedef NS_ERROR_ENUM(UIApplicationCategoryDefaultErrorDomain, UIApplicationCategoryDefaultErrorCode) {
    UIApplicationCategoryDefaultErrorRateLimited = 1 } API_AVAILABLE(ios(18.2));
UIKIT_EXTERN NSString *const UIApplicationCategoryDefaultStatusLastProvidedDateErrorKey API_AVAILABLE(ios(18.2));
UIKIT_EXTERN NSString *const UIApplicationCategoryDefaultRetryAvailabilityDateErrorKey API_AVAILABLE(ios(18.2));
@interface UIApplication (UISceneExtras)
/* NO while the device is locked (isim boot: script `lock`) */
@property (nonatomic, readonly, getter=isProtectedDataAvailable) BOOL protectedDataAvailable;
/* shaking the device offers undo / redo (UIKeyboard.m); NO turns it off */
@property (nonatomic) BOOL applicationSupportsShakeToEdit;
/* remote-control events (play / pause from the lock screen or headphones) go to the first responder (script `remote`) */
- (void)beginReceivingRemoteControlEvents;
- (void)endReceivingRemoteControlEvents;
@property (nonatomic, readonly) BOOL systemPrefersReducedResourceUsage API_AVAILABLE(ios(27.0));
- (BOOL)isDefaultForCategory:(UIApplicationCategory)category error:(NSError **)error NS_SWIFT_NAME(isDefault(_:)) __attribute__((swift_error(nonnull_error))) API_AVAILABLE(ios(18.2));
@end
@interface UIApplicationShortcutIcon (UISceneExtras)
/* the contact's picture, else a monogram of their initials */
+ (instancetype)iconWithContact:(CNContact *)contact NS_SWIFT_NAME(init(contact:));
@end

/* ---------------- scenes ---------------- */
UIKIT_EXTERN UISceneSessionRole const UIWindowSceneSessionRoleAssistiveAccessApplication NS_SWIFT_NAME(windowAssistiveAccessApplication) API_AVAILABLE(ios(26.0));
/* which scene opens content: a target content identifier (a user activity's, a shortcut item's) activates the scene
   whose prefers predicate matches it, else one whose can predicate matches (isim, iPad with several scenes) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UISceneActivationConditions : NSObject <NSSecureCoding>
@property (nonatomic, copy) NSPredicate *canActivateForTargetContentIdentifierPredicate;
@property (nonatomic, copy) NSPredicate *prefersToActivateForTargetContentIdentifierPredicate;
@end
/* iOS 18 locked and hidden apps: isim apps are never locked */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UIScene.SystemProtectionManager)
@interface UISceneSystemProtectionManager : NSObject
@property (nonatomic, readonly, getter=isUserAuthenticationEnabled) BOOL userAuthenticationEnabled;
@end
/* pointer lock (iPad): a full-screen scene whose view controller prefers the pointer locked */
UIKIT_EXTERN NSNotificationName const UIPointerLockStateDidChangeNotification NS_SWIFT_NAME(UIPointerLockState.didChangeNotification) API_AVAILABLE(ios(14.0));
UIKIT_EXTERN NSString *const UIPointerLockStateSceneUserInfoKey NS_SWIFT_NAME(UIPointerLockState.sceneUserInfoKey) API_AVAILABLE(ios(14.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.0))
@interface UIPointerLockState : NSObject
@property (nonatomic, readonly, getter=isLocked) BOOL locked;
@end
@interface UIScene (UISceneExtras)
@property (nonatomic, strong) UISceneActivationConditions *activationConditions;
@property (nonatomic, readonly, nullable) UISceneSystemProtectionManager *systemProtectionManager API_AVAILABLE(ios(18.0));
/* iPad scenes only (nil on iPhone) */
@property (nonatomic, readonly, nullable) UIPointerLockState *pointerLockState API_AVAILABLE(ios(14.0));
@end
@interface UISceneConnectionOptions (UISceneExtras)
/* the notification response when a tap on a notification launched the app */
@property (nullable, nonatomic, readonly) UNNotificationResponse *notificationResponse;
/* isim has no CloudKit sharing and no game controller activation: always nil */
@property (nullable, nonatomic, readonly) CKShareMetadata *cloudKitShareMetadata;
@property (nullable, nonatomic, readonly) GCGameControllerActivationContext *gameControllerActivationContext API_AVAILABLE(ios(18.0));
@end

/* windowing (iPad, Mac Catalyst): window buttons and the control style; isim stores them (no window chrome) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UISceneWindowingBehaviors : NSObject
@property (nonatomic, getter=isClosable) BOOL closable;
@property (nonatomic, getter=isMiniaturizable) BOOL miniaturizable;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(UIWindowScene.WindowingControlStyle)
@interface UISceneWindowingControlStyle : NSObject
@property (class, nonatomic, readonly) UISceneWindowingControlStyle *automaticStyle NS_SWIFT_NAME(automatic);
@property (class, nonatomic, readonly) UISceneWindowingControlStyle *minimalStyle NS_SWIFT_NAME(minimal);
@property (class, nonatomic, readonly) UISceneWindowingControlStyle *unifiedStyle NS_SWIFT_NAME(unified);
- (instancetype)init NS_UNAVAILABLE;
@end
/* the status bar of a window scene */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UIStatusBarManager : NSObject
@property (nonatomic, readonly) UIStatusBarStyle statusBarStyle;
@property (nonatomic, readonly, getter=isStatusBarHidden) BOOL statusBarHidden;
@property (nonatomic, readonly) CGRect statusBarFrame;
@end
typedef NS_ENUM(NSInteger, UIStatusBarAnimation) { UIStatusBarAnimationNone, UIStatusBarAnimationFade, UIStatusBarAnimationSlide };
@interface UIWindowScene (UISceneExtras)
@property (nonatomic, readonly, nullable) UISceneWindowingBehaviors *windowingBehaviors API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, nullable) UIStatusBarManager *statusBarManager;
@end
@interface UIWindowSceneGeometry (UISceneExtras)
/* the top view controller prefers its orientation locked (iOS 26) */
@property (nonatomic, readonly, getter=isInterfaceOrientationLocked) BOOL interfaceOrientationLocked API_AVAILABLE(ios(26.0));
@end
/* Mac geometry preferences: requesting them on iOS fails (UISceneErrorCodeGeometryRequestUnsupported) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UIWindowSceneGeometryPreferencesMac : UIWindowSceneGeometryPreferences
- (instancetype)initWithSystemFrame:(CGRect)systemFrame;
@property (nonatomic) CGRect systemFrame;
@end
@interface UIViewController (UISceneExtras)
/* iOS 26: rotating the device doesn't turn this controller's interface (setNeedsUpdateOf... after a change) */
@property (nonatomic, readonly) BOOL prefersInterfaceOrientationLocked API_AVAILABLE(ios(26.0));
- (void)setNeedsUpdateOfPrefersInterfaceOrientationLocked API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) BOOL prefersPointerLocked API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly, nullable) UIViewController *childViewControllerForPointerLock API_AVAILABLE(ios(14.0));
- (void)setNeedsUpdateOfPrefersPointerLocked API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly) UIStatusBarAnimation preferredStatusBarUpdateAnimation;
@end

/* ---- activating scenes from menus and pinches (iPad: a new window; iPhone: the error handler) ---- */
@class UIWindowSceneActivationRequestOptions;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(UIWindowScene.ActivationConfiguration)
@interface UIWindowSceneActivationConfiguration : NSObject
- (instancetype)initWithUserActivity:(NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, strong) NSUserActivity *userActivity;
@property (nullable, nonatomic, strong) UIWindowSceneActivationRequestOptions *options;
@property (nullable, nonatomic, strong) UITargetedPreview *preview;
@end
@class UIWindowSceneActivationAction;
typedef UIWindowSceneActivationConfiguration *_Nullable (^UIWindowSceneActivationActionConfigurationProvider)(UIWindowSceneActivationAction *action) NS_SWIFT_NAME(UIWindowSceneActivationAction.ConfigurationProvider) API_AVAILABLE(ios(17.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(UIWindowScene.ActivationAction)
@interface UIWindowSceneActivationAction : UIAction
+ (instancetype)actionWithIdentifier:(nullable NSString *)identifier alternateAction:(nullable UIAction *)alternateAction
                configurationProvider:(UIWindowSceneActivationActionConfigurationProvider)configurationProvider
    NS_SWIFT_NAME(init(identifier:alternate:configuration:));
+ (instancetype)actionWithIdentifier:(nullable NSString *)identifier alternateAction:(nullable UIAction *)alternateAction
                configurationProvider:(UIWindowSceneActivationActionConfigurationProvider)configurationProvider
                         errorHandler:(nullable void (^)(NSError *error))errorHandler
    NS_SWIFT_NAME(init(identifier:alternate:configuration:errorHandler:));
@end
@class UIWindowSceneActivationInteraction;
typedef UIWindowSceneActivationConfiguration *_Nullable (^UIWindowSceneActivationInteractionConfigurationProvider)(UIWindowSceneActivationInteraction *interaction, CGPoint location) NS_SWIFT_NAME(UIWindowSceneActivationInteraction.ConfigurationProvider) API_AVAILABLE(ios(17.0));
/* a pinch out on the view opens the configuration's activity in a new window */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(UIWindowScene.ActivationInteraction)
@interface UIWindowSceneActivationInteraction : NSObject <UIInteraction>
- (instancetype)initWithConfigurationProvider:(UIWindowSceneActivationInteractionConfigurationProvider)configurationProvider
                                 errorHandler:(void (^)(NSError *error))errorHandler NS_SWIFT_NAME(init(_:errorHandler:));
- (instancetype)init NS_UNAVAILABLE;
@end
/* iOS 26: a pan on the view moves the window (iPad windowing). isim's windows don't move: the pan is reported */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIWindowSceneDragInteraction : NSObject <UIInteraction>
@property (nonatomic, readonly) UIGestureRecognizer *gestureForFailureRelationships;
@end

/* ---------------- screens ---------------- */
NS_SWIFT_UI_ACTOR
@interface UIScreenMode : NSObject
@property (nonatomic, readonly) CGSize size;            /* pixels */
@property (nonatomic, readonly) CGFloat pixelAspectRatio;
@end
typedef NS_ENUM(NSInteger, UIScreenOverscanCompensation) { UIScreenOverscanCompensationScale, UIScreenOverscanCompensationInsetBounds,
    UIScreenOverscanCompensationNone };
typedef NS_ENUM(NSInteger, UIScreenReferenceDisplayModeStatus) { UIScreenReferenceDisplayModeStatusNotSupported = 0,
    UIScreenReferenceDisplayModeStatusNotEnabled, UIScreenReferenceDisplayModeStatusEnabled, UIScreenReferenceDisplayModeStatusLimited } API_AVAILABLE(ios(17.0));
@interface UIScreen (UISceneExtras)
@property (nonatomic, readonly, copy) NSArray<UIScreenMode *> *availableModes;
@property (nullable, nonatomic, readonly, strong) UIScreenMode *preferredMode;
@property (nullable, nonatomic, strong) UIScreenMode *currentMode;
/* the screen an external display mirrors (nil: the simulated external display shows its own scene) */
@property (nullable, nonatomic, readonly, strong) UIScreen *mirroredScreen NS_SWIFT_NAME(mirrored);
@property (nonatomic) UIScreenOverscanCompensation overscanCompensation;
@property (nonatomic, readonly) UIEdgeInsets overscanCompensationInsets;
@property (nonatomic, readonly) CFTimeInterval calibratedLatency;
/* isim draws standard dynamic range: 1 */
@property (nonatomic, readonly) CGFloat currentEDRHeadroom API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) CGFloat potentialEDRHeadroom API_AVAILABLE(ios(16.0));
/* portrait-up coordinates, whatever the interface orientation */
@property (nonatomic, readonly) id<UICoordinateSpace> fixedCoordinateSpace;
@property (nonatomic, readonly) UIScreenReferenceDisplayModeStatus referenceDisplayModeStatus API_AVAILABLE(ios(17.0));
@property (nonatomic) BOOL wantsSoftwareDimming;
@end

/* ---------------- windows ---------------- */
/* a layout guide that keeps an aspect ratio inside the safe area, centred (0: the whole safe area) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@protocol UILayoutGuideAspectFitting <NSObject>
@property (nonatomic) CGFloat aspectRatio;
@end
@interface UIWindow (UISceneExtras)
@property (nonatomic, readonly) UILayoutGuide<UILayoutGuideAspectFitting> *safeAreaAspectFitLayoutGuide API_AVAILABLE(ios(26.0));
/* Mac Catalyst: stored */
@property (nonatomic) BOOL canResizeToFitContent;
@end
NS_ASSUME_NONNULL_END
