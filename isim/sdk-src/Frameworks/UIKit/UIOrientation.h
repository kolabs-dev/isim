#pragma once
/* isim: interface orientations and rotation — supported orientations (Info.plist, app delegate, view controllers),
   device-orientation notifications, size transitions with a transition coordinator, scene geometry requests. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIScene.h>
#import <UIKit/UIPresentationController.h>   /* the transition coordinator protocols */
NS_ASSUME_NONNULL_BEGIN
/* UIInterfaceOrientation, UIInterfaceOrientationMask and the orientation helpers are declared in UIDevice.h */
UIKIT_EXTERN NSNotificationName const UIDeviceOrientationDidChangeNotification;
@interface UIDevice (UIDeviceOrientationNotifications)
@property (nonatomic, readonly, getter=isGeneratingDeviceOrientationNotifications) BOOL generatesDeviceOrientationNotifications;
- (void)beginGeneratingDeviceOrientationNotifications;
- (void)endGeneratingDeviceOrientationNotifications;
@end

@protocol UIContentContainer <NSObject>
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;
- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;
@end
@interface UIViewController (UIRotation) <UIContentContainer>
@property (nonatomic, readonly) UIInterfaceOrientationMask supportedInterfaceOrientations;
@property (nonatomic, readonly) UIInterfaceOrientation preferredInterfaceOrientationForPresentation;
@property (nonatomic, readonly) BOOL shouldAutorotate;
- (void)setNeedsUpdateOfSupportedInterfaceOrientations;
+ (void)attemptRotationToDeviceOrientation;
@end
@interface UIApplication (UIRotation)
@property (nonatomic, readonly) UIInterfaceOrientation statusBarOrientation;
- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window;
@end

NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIWindowScene.GeometryPreferences)
@interface UIWindowSceneGeometryPreferences : NSObject
@end
NS_SWIFT_UI_ACTOR      /* Swift: UIWindowScene.GeometryPreferences.iOS (a typealias in the UIKit overlay) */
@interface UIWindowSceneGeometryPreferencesIOS : UIWindowSceneGeometryPreferences
- (instancetype)initWithInterfaceOrientations:(UIInterfaceOrientationMask)interfaceOrientations;
@property (nonatomic) UIInterfaceOrientationMask interfaceOrientations;
@end
@interface UIWindowScene (UIRotation)
@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;
- (void)requestGeometryUpdateWithPreferences:(UIWindowSceneGeometryPreferences *)geometryPreferences errorHandler:(void (^_Nullable)(NSError *error))errorHandler;
@end
NS_ASSUME_NONNULL_END
