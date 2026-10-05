#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UITraitCollection.h>
NS_ASSUME_NONNULL_BEGIN
@class UIWindow, UIScreen, UISceneSession, UISceneConnectionOptions;
typedef NSString *UISceneSessionRole NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN UISceneSessionRole const UIWindowSceneSessionRoleApplication;
typedef NS_ENUM(NSInteger, UISceneActivationState) { UISceneActivationStateUnattached = -1, UISceneActivationStateForegroundActive, UISceneActivationStateForegroundInactive, UISceneActivationStateBackground };
UIKIT_EXTERN NSNotificationName const UISceneWillConnectNotification, UISceneDidActivateNotification;

NS_SWIFT_UI_ACTOR
@protocol UISceneDelegate <NSObject>
@optional
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions;
- (void)sceneDidDisconnect:(UIScene *)scene;
- (void)sceneDidBecomeActive:(UIScene *)scene;
- (void)sceneWillResignActive:(UIScene *)scene;
- (void)sceneWillEnterForeground:(UIScene *)scene;
- (void)sceneDidEnterBackground:(UIScene *)scene;
@end

@interface UIScene : UIResponder
- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) UISceneSession *session;
@property (nullable, nonatomic, strong) id<UISceneDelegate> delegate;
@property (nonatomic, readonly) UISceneActivationState activationState;
@property (null_resettable, nonatomic, copy) NSString *title;
@end

NS_SWIFT_UI_ACTOR
@protocol UIWindowSceneDelegate <UISceneDelegate>
@optional
@property (nullable, nonatomic, strong) UIWindow *window;
@end

@interface UIWindowScene : UIScene
@property (nonatomic, readonly) UIScreen *screen;
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;
@property (nullable, nonatomic, readonly, strong) UIWindow *keyWindow;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
@property (nonatomic, readonly) id coordinateSpace;
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
@property (nonatomic, readonly, nullable) UIScene *scene;
@property (nonatomic, readonly) UISceneSessionRole role;
@property (nonatomic, readonly, copy) UISceneConfiguration *configuration;
@property (nonatomic, readonly) NSString *persistentIdentifier;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *userInfo;
@end

NS_SWIFT_UI_ACTOR
@interface UISceneConnectionOptions : NSObject
@property (nonatomic, readonly, copy) NSSet *URLContexts;
@property (nonatomic, readonly, copy) NSSet *userActivities;
@end
NS_ASSUME_NONNULL_END
