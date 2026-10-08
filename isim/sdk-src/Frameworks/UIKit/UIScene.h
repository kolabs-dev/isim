#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UITraitCollection.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIWindow, UIScreen, UISceneSession, UISceneConnectionOptions;
typedef NSString *UISceneSessionRole NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN UISceneSessionRole const UIWindowSceneSessionRoleApplication NS_SWIFT_NAME(windowApplication);
typedef NS_ENUM(NSInteger, UISceneActivationState) { UISceneActivationStateUnattached = -1, UISceneActivationStateForegroundActive, UISceneActivationStateForegroundInactive, UISceneActivationStateBackground };
UIKIT_EXTERN NSNotificationName const UISceneWillConnectNotification, UISceneDidActivateNotification, UISceneDidDisconnectNotification,
    UISceneWillDeactivateNotification, UISceneWillEnterForegroundNotification, UISceneDidEnterBackgroundNotification;
UIKIT_EXTERN UISceneSessionRole const UIWindowSceneSessionRoleExternalDisplayNonInteractive NS_SWIFT_NAME(windowExternalDisplayNonInteractive);
UIKIT_EXTERN NSErrorDomain const UISceneErrorDomain;
typedef NS_ERROR_ENUM(UISceneErrorDomain, UISceneErrorCode) {
    UISceneErrorCodeMultipleScenesNotSupported = 0, UISceneErrorCodeRequestDenied = 1,
    UISceneErrorCodeGeometryRequestUnsupported = 100, UISceneErrorCodeGeometryRequestDenied = 101 };
@class UISceneOpenExternalURLOptions;

NS_SWIFT_UI_ACTOR
@protocol UISceneDelegate <NSObject>
@optional
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions;
- (void)sceneDidDisconnect:(UIScene *)scene;
- (void)sceneDidBecomeActive:(UIScene *)scene;
- (void)sceneWillResignActive:(UIScene *)scene;
- (void)sceneWillEnterForeground:(UIScene *)scene;
- (void)sceneDidEnterBackground:(UIScene *)scene;
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts;
- (nullable NSUserActivity *)stateRestorationActivityForScene:(UIScene *)scene;
- (void)scene:(UIScene *)scene restoreInteractionStateWithUserActivity:(NSUserActivity *)stateRestorationActivity;
- (void)scene:(UIScene *)scene willContinueUserActivityWithType:(NSString *)userActivityType;
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;
- (void)scene:(UIScene *)scene didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error;
- (void)scene:(UIScene *)scene didUpdateUserActivity:(NSUserActivity *)userActivity;
@end

@interface UIScene : UIResponder
- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) UISceneSession *session;
@property (nullable, nonatomic, strong) id<UISceneDelegate> delegate;
@property (nonatomic, readonly) UISceneActivationState activationState;
@property (null_resettable, nonatomic, copy) NSString *title;
@property (null_resettable, nonatomic, copy) NSString *subtitle API_AVAILABLE(ios(15.0));
/* opens a URL like UIApplication's openURL:options:completionHandler: (another app's scheme or universal link, Settings) */
- (void)openURL:(NSURL *)url options:(nullable UISceneOpenExternalURLOptions *)options completionHandler:(void (^ _Nullable)(BOOL success))completion;
@end
NS_SWIFT_NAME(UIScene.OpenExternalURLOptions)
@interface UISceneOpenExternalURLOptions : NSObject
@property (nonatomic) BOOL universalLinksOnly;
@end

/* ---- multiple windows (iPad): activation and destruction requests ---- */
typedef NS_ENUM(NSInteger, UISceneCollectionJoinBehavior) { UISceneCollectionJoinBehaviorAutomatic, UISceneCollectionJoinBehaviorPreferred,
    UISceneCollectionJoinBehaviorDisallowed, UISceneCollectionJoinBehaviorPreferredWithoutActivating };
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIScene.ActivationRequestOptions)
@interface UISceneActivationRequestOptions : NSObject
@property (nullable, nonatomic, strong) UIScene *requestingScene;
@property (nonatomic) UISceneCollectionJoinBehavior collectionJoinBehavior;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIScene.DestructionRequestOptions)
@interface UISceneDestructionRequestOptions : NSObject
@end
/* iOS 17: what to activate — a new scene for a role, or an existing session */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UISceneSessionActivationRequest : NSObject <NSCopying>
+ (instancetype)request NS_SWIFT_NAME(init());
+ (instancetype)requestWithRole:(UISceneSessionRole)role NS_SWIFT_NAME(init(role:));
+ (nullable instancetype)requestWithSession:(UISceneSession *)session NS_SWIFT_NAME(init(session:));
@property (nonatomic, readonly) UISceneSessionRole role;
@property (nullable, nonatomic, readonly) UISceneSession *session;
@property (nullable, nonatomic, strong) NSUserActivity *userActivity;
@property (nullable, nonatomic, strong) UISceneActivationRequestOptions *options;
@end

NS_SWIFT_UI_ACTOR
@protocol UIWindowSceneDelegate <UISceneDelegate>
@optional
@property (nullable, nonatomic, strong) UIWindow *window;
- (void)windowScene:(UIWindowScene *)windowScene performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler;
/* the scene's size or orientation changed (split view, rotation) */
- (void)windowScene:(UIWindowScene *)windowScene didUpdateCoordinateSpace:(id<UICoordinateSpace>)previousCoordinateSpace interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation traitCollection:(UITraitCollection *)previousTraitCollection;
@end

/* iPad: the smallest / largest size the scene accepts (split view widths honour minimumSize) */
NS_SWIFT_UI_ACTOR
@interface UISceneSizeRestrictions : NSObject
@property (nonatomic) CGSize minimumSize;
@property (nonatomic) CGSize maximumSize;
@property (nonatomic) BOOL allowsFullScreen API_AVAILABLE(ios(16.0));
@end
typedef NS_ENUM(NSInteger, UIWindowScenePresentationStyle) { UIWindowScenePresentationStyleAutomatic, UIWindowScenePresentationStyleStandard,
    UIWindowScenePresentationStyleProminent } NS_SWIFT_NAME(UIWindowScene.PresentationStyle) API_AVAILABLE(ios(15.0));
typedef NS_ENUM(NSInteger, UIWindowSceneDismissalAnimation) { UIWindowSceneDismissalAnimationStandard = 1, UIWindowSceneDismissalAnimationCommit = 2,
    UIWindowSceneDismissalAnimationDecline = 3 } NS_SWIFT_NAME(UIWindowScene.DismissalAnimation);
/* isim (adapted): prominent scenes take the whole screen; standard ones go side by side (split view) */
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIWindowScene.ActivationRequestOptions)
@interface UIWindowSceneActivationRequestOptions : UISceneActivationRequestOptions
@property (nonatomic) UIWindowScenePresentationStyle preferredPresentationStyle API_AVAILABLE(ios(15.0));
@end
NS_SWIFT_UI_ACTOR
@interface UIWindowSceneDestructionRequestOptions : UISceneDestructionRequestOptions
@property (nonatomic) UIWindowSceneDismissalAnimation windowDismissalAnimation;
@end
/* the scene's frame and orientation (iOS 16) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0)) NS_SWIFT_NAME(UIWindowScene.Geometry)
@interface UIWindowSceneGeometry : NSObject <NSCopying>
@property (nonatomic, readonly) CGRect systemFrame;
@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly, getter=isInteractivelyResizing) BOOL interactivelyResizing API_AVAILABLE(ios(17.0));
@end
@interface UIWindowScene : UIScene
@property (nonatomic, readonly) UIScreen *screen;
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;
@property (nullable, nonatomic, readonly, strong) UIWindow *keyWindow;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
@property (nonatomic, readonly) id<UICoordinateSpace> coordinateSpace;
/* nil on iPhone (scenes are not resizable there) */
@property (nonatomic, readonly, nullable) UISceneSizeRestrictions *sizeRestrictions;
@property (nonatomic, readonly) UIWindowSceneGeometry *effectiveGeometry API_AVAILABLE(ios(16.0));
/* iOS 17: traits every window of the scene sees */
@property (nonatomic, readonly) id<UITraitOverrides> traitOverrides API_AVAILABLE(ios(17.0));
- (void)updateTraitsIfNeeded API_AVAILABLE(ios(17.0));
@end

NS_SWIFT_UI_ACTOR
@interface UISceneConfiguration : NSObject <NSCopying>
+ (instancetype)configurationWithName:(nullable NSString *)name sessionRole:(UISceneSessionRole)sessionRole;
- (instancetype)initWithName:(nullable NSString *)name sessionRole:(UISceneSessionRole)sessionRole NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly) UISceneSessionRole role;
@property (nonatomic, nullable) Class sceneClass;
@property (nonatomic, nullable) Class delegateClass;
@property (nonatomic, strong, nullable) id storyboard;
@end

NS_SWIFT_UI_ACTOR
@interface UISceneSession : NSObject
@property (nonatomic, readonly, nullable, weak) UIScene *scene;
@property (nonatomic, readonly) UISceneSessionRole role;
@property (nonatomic, readonly, copy) UISceneConfiguration *configuration;
@property (nonatomic, readonly) NSString *persistentIdentifier;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *userInfo;
/* the activity saved by stateRestorationActivity(for:) when the scene last went to the background (isim: kept in the
   app container across launches; discarded when the app is closed from the app switcher, like iOS) */
@property (nonatomic, strong, nullable) NSUserActivity *stateRestorationActivity;
@end

NS_SWIFT_UI_ACTOR
@interface UISceneConnectionOptions : NSObject
@property (nonatomic, readonly, copy) NSSet<UIOpenURLContext *> *URLContexts;
@property (nonatomic, readonly, copy) NSSet<NSUserActivity *> *userActivities;
@property (nullable, nonatomic, readonly) NSString *sourceApplication;
@property (nullable, nonatomic, readonly) NSString *handoffUserActivityType;
@property (nullable, nonatomic, readonly) UIApplicationShortcutItem *shortcutItem;
@end
NS_ASSUME_NONNULL_END
